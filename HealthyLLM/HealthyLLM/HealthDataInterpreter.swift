//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziLLM
import SpeziLLMLocal
import SpeziChat
import OSLog

@Observable
class HealthDataInterpreter: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLM", category: "HealthDataInterpreter")
    
    private(set) var loaded = false
    
    @ObservationIgnored @Dependency(LLMRunner.self) private var llmRunner: LLMRunner
    @ObservationIgnored @Dependency(HealthDataFetcher.self) private var healthDataFetcher: HealthDataFetcher
    
    @ObservationIgnored private var functionCallParameters: LLMLocalParameters?
    @ObservationIgnored private var functionCallSamplingParameters: LLMLocalSamplingParameters?
    @ObservationIgnored private var defaultParameters: LLMLocalParameters?
    @ObservationIgnored private var sharedSession: LLMLocalSession?
    
    private(set) var context: HealthyLLMContext = []
    private(set) var advancedContext: HealthyLLMContext = []
    
    required init() { }
    
    func setup() async throws {
        functionCallParameters = .init(
            maxOutputLength: 32,
            chatTemplate: Constants.llmModelChatTemplate
        )
        functionCallSamplingParameters = .init(
            topP: 1.0,
            temperature: 0.001,
            penaltyRepeat: 1.3
        )
        
        defaultParameters = .init(
            maxOutputLength: 1024,
            chatTemplate: Constants.llmModelChatTemplate
        )
        
        let schema = LLMLocalSchema(
            model: .custom(id: Constants.llmModelName),
            parameters: defaultParameters!,
            injectIntoContext: true
        )
        
        sharedSession = llmRunner.callAsFunction(with: schema)
        
        try await sharedSession!.setup()
        loaded = true
    }
    
    func queryLLM(with context: Chat) async throws {
        if !loaded {
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        logger.info("Querying LLM with: \(context)")
        guard let userPrompt = context.last,
              userPrompt.role == .user,
              !userPrompt.content.isEmpty else {
            return
        }
        
        self.context.append(.init(.user, content: userPrompt.content))
        self.advancedContext.append(.init(.user, content: userPrompt.content))
        
        try await checkForFunctionCall(prompt: userPrompt.content)
        try await defaultResponse()
    }
    
    func resetChat() async {
        context = []
        advancedContext = []
    }
    
    private func checkForFunctionCall(prompt: String) async throws {
        guard let functionCallParameters = functionCallParameters,
              let functionCallSamplingParameters = functionCallSamplingParameters,
              let sharedSession else {
            logger.error("checkForFunctionCall: Not initialized throwing")
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        logger.info("Start check for function call with: \(prompt)")
        
        sharedSession.update(
            parameters: functionCallParameters,
            samplingParameters: functionCallSamplingParameters,
            injectIntoContext: false
        )
        
        let context: HealthyLLMContext = [
            PromptGenerator.buildSystemPrompt(for: .functionCall),
            .init(.user, content: prompt)
        ]
        advancedContext.append(contentsOf: context)
        
        let functionCallLLMOutput = try await llmRunner.oneShot(
            on: sharedSession,
            customContext: context.map(\.asDictionary)
        )
        
        logger.debug("Function Call LLM Finished with: \(functionCallLLMOutput)")
        
        if functionCallLLMOutput.contains("tool_call") || functionCallLLMOutput.contains("name") && functionCallLLMOutput.contains("arguments") {
            logger.info("Found function call")
            await executeFunctionCall(output: functionCallLLMOutput)
        } else {
            advancedContext.append(.init(.assistant, content: functionCallLLMOutput))
        }
    }
    
    
    private func defaultResponse() async throws {
        guard let sharedSession else {
            logger.error("defaultResponse: Not initialized throwing")
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        sharedSession.update(
            parameters: defaultParameters,
            injectIntoContext: true
        )
        
        if !context.map(\.content).contains(PromptGenerator.systemPrompt) {
            let userInfo = await healthDataFetcher.fetchUser()
            context.append(PromptGenerator.buildSystemPrompt(for: .default, userInfo: userInfo))
            advancedContext.append(PromptGenerator.buildSystemPrompt(for: .default, userInfo: userInfo))
        }
            
        await MainActor.run {
            sharedSession.customContext = context.map(\.asDictionary)
        }
        
        logger.debug("defaultResponse: Started with context")
        
        for try await stringPiece in try await sharedSession.generate() {
            logger.debug("defaultResponse: Received string piece: \(stringPiece)")
            
            guard let lastContextEntity = context.last,
                  lastContextEntity.role == .assistant else {
                context.append(.init(.assistant, content: stringPiece, completed: false))
                advancedContext.append(.init(.assistant, content: stringPiece, completed: false))
                continue
            }

            context[context.count - 1] = .init(
                .assistant,
                content: lastContextEntity.content + stringPiece,
                completed: false,
                id: lastContextEntity.id
            )
            advancedContext[advancedContext.count - 1] = .init(
                .assistant,
                content: lastContextEntity.content + stringPiece,
                completed: false,
                id: advancedContext.last!.id
            )
        }
    }
    
    /// Returns a bool representing if a function call has been made
    @discardableResult
    private func executeFunctionCall(output: String) async -> Bool {
        struct ToolCall: Codable {
            let name: String
            let arguments: [String: String]
        }
        
        let functionCallString = output
            .replacingOccurrences(of: "<tool_call>", with: "")
            .replacingOccurrences(of: "</tool_call>", with: "")
        
        guard let functionCallData = functionCallString.data(using: .utf8),
              let toolCall = try? JSONDecoder().decode(ToolCall.self, from: functionCallData) else {
            return false
        }
        
        switch toolCall.name {
        case "get_health_info":
            guard let sampleType = toolCall.arguments["sample_type"] else {
                return false
            }
            context.append(.init(.toolCall, content: output))
            advancedContext.append(.init(.toolCall, content: output))
            let healthData = await healthDataFetcher.fetchHealth(type: sampleType)
            context.append(PromptGenerator.buildToolResponse(of: healthData))
            advancedContext.append(PromptGenerator.buildToolResponse(of: healthData))
            return true
        case "get_workout_info":
            guard let workoutType = toolCall.arguments["workout_type"] else {
                return false
            }
            context.append(.init(.toolCall, content: output))
            advancedContext.append(.init(.toolCall, content: output))
            let workoutData = await healthDataFetcher.fetchWorkout(type: workoutType)
            
            if let workoutData,
               workoutData.count > Constants.workoutLimitJsonRepresentation {
                let csvString = HealthDataFetcher.workoutDataToCSV(workoutData)
                context.append(PromptGenerator.buildToolResponse(of: csvString))
                advancedContext.append(PromptGenerator.buildToolResponse(of: csvString))
                return true
            }
            
            context.append(PromptGenerator.buildToolResponse(of: workoutData))
            advancedContext.append(PromptGenerator.buildToolResponse(of: workoutData))
            return true
        default:
            return false
        }
    }
}

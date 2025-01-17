//
//  FunctionCallProcessor.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import Foundation
import Spezi
import SpeziLLM
import SpeziLLMLocal
import SpeziChat
import os





@Observable
class FunctionCallingProcessor: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "FunctionCallingProcessor")
    
    @ObservationIgnored @Dependency(SharedLocalLLM.self) private var llm
    @ObservationIgnored @Dependency(HealthDataFetcher.self) private var healthDataFetcher: HealthDataFetcher
    
    private(set) var chat: Chat = []
    var sufficientUsage: Bool {
        chat.filter { $0.role == .user }.count >= 3
    }
    
    required init() { }
    
    func query(with chat: Chat) async throws {
        guard let userInput = chat.last,
              userInput.role == .user,
              !userInput.content.isEmpty else {
            logger.error("No user input found")
            return
        }
        
        self.chat.append(userInput)
        
        try await checkForFunctionCall(prompt: userInput.content)
        try await startInference(prompt: userInput.content)
    }
    
    func stop() {
        llm.cancel()
    }
    
    func reset() {
        llm.cancel()
        chat = []
    }
    
    @MainActor
    private func startInference(prompt: String) async throws {
        logger.info("Start inference with prompt: \(prompt)")
        
        let parameters: LLMLocalParameters = .init(maxOutputLength: 512)
        let samplingParameters: LLMLocalSamplingParameters = .init()
        
        if chat.isEmpty || chat[0].role != .hidden(type: .system) {
            chat.insert(PromptGenerator.FunctionCallProcessor.buildSystemPrompt(for: .interpretation), at: 0)
        }
        
        let output = try await llm.oneShotStream(
            customContext: chat.asDictionaryRepresentation(),
            parameters: parameters,
            samplingParameters: samplingParameters
        )
        
        for try await token in output {
            guard let last = chat.last, last.role == .assistant else {
                chat.append(.init(role: .assistant, content: token, complete: false))
                continue
            }
            
            chat[chat.count - 1] = .init(
                role: last.role,
                content: last.content + token,
                complete: false,
                id: last.id,
                date: last.date
            )
        }
        
        guard let last = chat.last else { return }
        
        chat[chat.count - 1] = .init(
            role: last.role,
            content: last.content,
            complete: true,
            id: last.id,
            date: last.date
        )
    }
    
    
    private func checkForFunctionCall(prompt: String) async throws {
        let parameters: LLMLocalParameters = .init(
            maxOutputLength: 32
        )
        let samplingParameters: LLMLocalSamplingParameters = .init(
            topP: 1.0,
            temperature: 0.001,
            penaltyRepeat: 1.3
        )
        
        logger.info("Start check for function call with: \(prompt)")
        
        let customContext: Chat = [
            PromptGenerator.FunctionCallProcessor.buildSystemPrompt(for: .functionCall),
            .init(role: .user, content: prompt)
        ]
        
        let output = try await llm.oneShot(
            customContext: customContext.asDictionaryRepresentation(),
            parameters: parameters,
            samplingParameters: samplingParameters
        )
        
        logger.debug("Function Call LLM finished")
        guard let output, !output.isEmpty else { return }
        
        if output.contains("tool_call") || output.contains("name") && output.contains("arguments") {
            logger.info("Found function call")
            await executeFunctionCall(output: output)
        }
    }
    
    @MainActor
    private func executeFunctionCall(output: String) async {
        struct ToolCall: Codable {
            let name: String
            let arguments: [String: String]
        }
        
        let functionCallString = output
            .replacingOccurrences(of: "<tool_call>", with: "")
            .replacingOccurrences(of: "</tool_call>", with: "")
        
        guard let functionCallData = functionCallString.data(using: .utf8),
              let toolCall = try? JSONDecoder().decode(ToolCall.self, from: functionCallData) else {
            return
        }
        
        switch toolCall.name {
        case "get_health_info":
            guard let sampleType = toolCall.arguments["sample_type"] else { return }
            chat.append(.init(role: .assistantToolCall, content: output))
            
            let healthData = await healthDataFetcher.fetchHealth(string: sampleType).asJSONString() ?? "No Data"
            chat.append(PromptGenerator.FunctionCallProcessor.buildToolResponse(of: healthData))
        case "get_workout_info":
            guard let workoutType = toolCall.arguments["workout_type"] else { return }
            chat.append(.init(role: .assistantToolCall, content: output))
            
            let workoutData = await healthDataFetcher.fetchWorkout(string: workoutType).asJSONString() ?? "No Data"
            chat.append(PromptGenerator.FunctionCallProcessor.buildToolResponse(of: workoutData))
        default:
            return
        }
    }
}

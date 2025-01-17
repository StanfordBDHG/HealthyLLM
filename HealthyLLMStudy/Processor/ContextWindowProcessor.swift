//
//  ContextProcessor.swift
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
class ContextWindowProcessor: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "ContextWindowProcessor")
    
    @ObservationIgnored @Dependency(SharedLocalLLM.self) private var llm
    @ObservationIgnored @Dependency(HealthDataFetcher.self) private var healthDataFetcher: HealthDataFetcher
    
    @ObservationIgnored private let parameters: LLMLocalParameters = .init(maxOutputLength: 512)
    @ObservationIgnored private let samplingParameters: LLMLocalSamplingParameters = .init()
    
    private(set) var chat: Chat = []
    var sufficientUsage: Bool {
        chat.filter { $0.role == .user }.count >= 3
    }
    
    required init() { }
    
    func query(with inputChat: Chat) async throws {
        guard let userInput = inputChat.last,
              userInput.role == .user,
              !userInput.content.isEmpty else {
            logger.error("No user input found")
            return
        }
        
        if chat.isEmpty {
            await load()
        }
        
        chat.append(userInput)
        
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
    
    private func load() async {
        print("system prompt loading...")
        let health = await healthDataFetcher.fetchAllHealthLastTwoWeeks()
        let workout = await healthDataFetcher.fetchAllWorkoutsLastTwoWeeks()
        
        let systemPrompt = PromptGenerator.ContextWindowProcessor.buildSystemPrompt(health: health, workout: workout)
        
        chat.insert(systemPrompt, at: 0)
    }
}

//
//  ContextProcessor.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import Foundation
import os
import Spezi
import SpeziChat
import SpeziLLM
import SpeziLLMLocal


@Observable
class ContextWindowProcessor: EnvironmentAccessible, DefaultInitializable, Module, ChatProcessor {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "ContextWindowProcessor")
    
    @ObservationIgnored @Dependency(SharedLocalLLM.self) private var llm
    
    @ObservationIgnored private let parameters: LLMLocalParameters = .init(maxOutputLength: 512)
    @ObservationIgnored private let samplingParameters: LLMLocalSamplingParameters = .init()
    
    private(set) var chat: Chat = []
    var sufficientUsage: Bool {
        chat.filter { $0.role == .user }.isEmpty
    }
    
    required init() { }
    
    func query(with inputChat: Chat) async throws {
        await MainActor.run {
            PerformanceProcessor.shared.start()
        }
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
        Persistance.shared.saveChatMessage(
            type: "ContextWindow",
            role: userInput.role.rawValue,
            message: userInput.content
        )
        
        try await startInference(prompt: userInput.content)
    }
    
    func stop() {
        llm.cancel()
        PerformanceProcessor.shared.stop()
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
        
        llm.clearCache()
        
        Persistance.shared.saveChatMessage(
            type: "ContextWindow",
            role: last.role.rawValue,
            message: last.content
        )
    }
    
    private func load() async {
        let interpretationSystemPrompt = LocalizedStringResource("INTERPRETATION_SYSTEM_PROMPT").localizedString()
        let data = try? await ContextWindowHandler.execute()
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        
        let systemPrompt = """
        \(interpretationSystemPrompt)
        
        Today's Date: \(formatter.string(from: .now))
        
        Make use of the health data below:
        
        \(data ?? "No data available")
        """
        
        chat.insert(
            .init(
                role: .hidden(type: .system),
                content: systemPrompt
            ),
            at: 0
        )
    }
}

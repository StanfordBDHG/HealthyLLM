//
//  SharedLLM.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import Foundation
import Spezi
import SpeziLLM
import SpeziLLMLocal
import os


enum SharedLLMError: Error {
    case noSession
}


@Observable
class SharedLocalLLM: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "FunctionCallingProcessor")
    
    private(set) var loaded = false
    
    @ObservationIgnored @Dependency(HealthDataFetcher.self) private var healthDataFetcher: HealthDataFetcher
    @ObservationIgnored @Dependency(LLMRunner.self) private var runner: LLMRunner
    private var session: LLMLocalSession?
    private var systemPrompt = ""
    
    required init() { }
    
    @MainActor
    func prepareLLM(
        with model: LLMLocalModel = Constants.llmModel,
        parameters: LLMLocalParameters = .init(),
        samplingParameters: LLMLocalSamplingParameters = .init(),
        systemPrompt: String = ""
    ) async throws {
        let schema = LLMLocalSchema(model: model)
        let session = runner(with: schema)
        try await session.setup()
        self.systemPrompt = systemPrompt
        self.session = session
    }
    
    func oneShot(
        customContext: [[String: String]],
        parameters: LLMLocalParameters,
        samplingParameters: LLMLocalSamplingParameters
    ) async throws -> String? {
        if session == nil,
           !loaded {
            try await prepareLLM()
        }
        
        guard let session else { throw SharedLLMError.noSession }
        
        session.update(parameters: parameters, samplingParameters: samplingParameters)
        
        await MainActor.run {
            session.customContext = customContext
        }
        
        var output = ""
        for try await stringPiece in try await session.generate() {
            output.append(stringPiece)
        }
        
        return output
    }
    
    func oneShotStream(
        customContext: [[String: String]],
        parameters: LLMLocalParameters,
        samplingParameters: LLMLocalSamplingParameters
    ) async throws -> AsyncThrowingStream<String, any Error> {
        if session == nil,
           !loaded {
            try await prepareLLM()
        }
        
        guard let session else { throw SharedLLMError.noSession }
        
        session.update(parameters: parameters, samplingParameters: samplingParameters)
        
        await MainActor.run {
            session.customContext = customContext
        }
        
        return try await session.generate()
    }
    
    func cancel() {
        session?.cancel()
    }
}

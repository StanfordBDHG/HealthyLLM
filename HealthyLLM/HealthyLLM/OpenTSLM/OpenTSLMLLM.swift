//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MLX
import SpeziLLM
import SpeziLLMLocal

/// Custom LLM integration that works with SpeziLLMLocal and incorporates embeddings via prompt engineering
public final class OpenTSLMLLM {

    private let llmRunner: LLMRunner
    private let session: LLMLocalSession

    public init(llmRunner: LLMRunner, session: LLMLocalSession) {
        self.llmRunner = llmRunner
        self.session = session
    }

    public func generateWithEmbeddings(
        inputsEmbeds: MLXArray,
        prompt: String,
        maxTokens: Int = 200
    ) async throws -> String {
        let mean = inputsEmbeds.mean().item(Float.self)
        let minValue = inputsEmbeds.min().item(Float.self)
        let maxValue = inputsEmbeds.max().item(Float.self)
        let embeddingDescription = """
        [TIME SERIES EMBEDDINGS: shape=\(inputsEmbeds.shape), mean=\(String(format: "%.4f", mean)), min=\(String(format: "%.4f", minValue)), max=\(String(format: "%.4f", maxValue))]
        """

        let fullPrompt = """
        \(prompt)

        \(embeddingDescription)

        Based on the time series embeddings provided above, please analyze and provide insights.
        """

        let savedContext = await MainActor.run { session.customContext }
        let chatTemplate: String? = Constants.useCustomChatTemplate ? Constants.llmModelChatTemplate : nil
        let restoreParameters = LLMLocalParameters(
            maxOutputLength: Constants.llmDefaultMaxOutputLength,
            chatTemplate: chatTemplate
        )

        await MainActor.run {
            session.customContext = [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": fullPrompt],
            ]
        }

        session.update(parameters: LLMLocalParameters(maxOutputLength: maxTokens, chatTemplate: chatTemplate))

        var output = ""
        do {
            for try await stringPiece in try await session.generate() {
                output.append(stringPiece)
            }
        } catch {
            await MainActor.run {
                session.customContext = savedContext
            }
            session.update(parameters: restoreParameters)
            throw error
        }

        await MainActor.run {
            session.customContext = savedContext
        }
        session.update(parameters: restoreParameters)

        return output
    }

    public func tokenize(text: String) throws -> [Int] {
        // Tokenization not available through SpeziLLMLocal API
        // In a full implementation, this would access the underlying tokenizer
        throw NSError(domain: "OpenTSLMLLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Tokenization not implemented"])
    }

    public func decode(tokens: [Int]) throws -> String {
        // Decoding not available through SpeziLLMLocal API
        // In a full implementation, this would access the underlying tokenizer
        throw NSError(domain: "OpenTSLMLLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "Decoding not implemented"])
    }
}
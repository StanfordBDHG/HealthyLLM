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
        // Convert embeddings to a textual representation that can be included in the prompt
        let embeddingDescription = """
        [TIME SERIES EMBEDDINGS: shape=\(inputsEmbeds.shape), mean=\(String(format: "%.4f", inputsEmbeds.mean().item(Float.self)))]
        """

        // Create a comprehensive prompt that includes both the text prompt and embedding information
        let fullPrompt = """
        \(prompt)

        \(embeddingDescription)

        Based on the time series embeddings provided above, please analyze and provide insights.
        """

        // Use the existing SpeziLLMLocal session to generate
        await MainActor.run {
            self.session.customContext = [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": fullPrompt],
            ]
        }

        var output = ""
        let parameters = LLMLocalParameters(maxOutputLength: maxTokens)
        session.update(parameters: parameters)

        for try await stringPiece in try await session.generate() {
            output.append(stringPiece)
        }

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
//
// MLXEmbeddingGenerator.swift
// Custom MLX generation loop that accepts pre-computed embeddings (inputs_embeds)
//
// Note: This is a best-effort implementation that targets the MLX/MLXLLM API surface.
// If signatures differ in your installed MLX version, adapt calls accordingly.
//

import Foundation
import MLX

public enum MLXEmbeddingGeneratorError: Error {
    case modelDoesNotSupportEmbeddingGeneration
    case generationFailed(String)
}

/// A small protocol describing the minimum functionality needed for embedding-primed generation.
/// This keeps the implementation decoupled from a specific MLXLLM version.
public protocol EmbeddingPrimedLanguageModel {
    associatedtype Cache

    func makeCache() -> Cache
    func callAsFunction(_ inputs: MLXArray?, cache: Cache, inputEmbedding: MLXArray?) throws -> MLXArray
}

/// Minimal helper implementing a generation loop that uses pre-computed `inputs_embeds`.
/// The model supplies logits; token sampling is injected so this stays compatible with the
/// exact MLX version available in the app target.
public final class MLXEmbeddingGenerator<Model: EmbeddingPrimedLanguageModel> {
    private let model: Model
    private let eosTokenId: Int
    private let tokenSampler: (MLXArray) throws -> Int
    private let decodeTokens: ([Int]) throws -> String

    public init(
        model: Model,
        eosTokenId: Int,
        tokenSampler: @escaping (MLXArray) throws -> Int,
        decodeTokens: @escaping ([Int]) throws -> String
    ) {
        self.model = model
        self.eosTokenId = eosTokenId
        self.tokenSampler = tokenSampler
        self.decodeTokens = decodeTokens
    }

    /// Generate text starting from pre-computed embeddings.
    public func generate(
        inputsEmbeds: MLXArray,
        maxNewTokens: Int = 128,
        temperature: Float = 1.0
    ) throws -> String {
        let cache = model.makeCache()
        var logits = try model.callAsFunction(nil, cache: cache, inputEmbedding: inputsEmbeds)
        var generatedTokenIds: [Int] = []

        for _ in 0..<maxNewTokens {
            guard logits.ndim >= 2 else {
                throw MLXEmbeddingGeneratorError.generationFailed("Unexpected logits ndim: \(logits.ndim)")
            }

            let seqLen = Int(logits.dim(1))
            guard seqLen > 0 else {
                throw MLXEmbeddingGeneratorError.generationFailed("Logits sequence length is zero")
            }

            let lastLogitsSlice = logits[0 ..< 1, seqLen - 1 ..< seqLen]
            let lastLogits = lastLogitsSlice / Float(temperature)
            let nextToken = try tokenSampler(lastLogits)
            generatedTokenIds.append(nextToken)

            if nextToken == eosTokenId {
                break
            }

            let inputIds = MLXArray(converting: [Double(nextToken)], [1, 1])
            logits = try model.callAsFunction(inputIds, cache: cache, inputEmbedding: nil)
        }

        return try decodeTokens(generatedTokenIds)
    }
}

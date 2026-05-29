//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MLX
import MLXLMCommon
import OSLog
import SpeziLLM
import SpeziLLMLocal
import Tokenizers

/// Bridges OpenTSLM soft-prompt embeddings into the on-device Llama decoder.
///
/// Builds the interleaved input-embedding sequence
/// `[pre-prompt tokens] [series-i text tokens] [series-i TS embeds] … [post-prompt tokens]`
/// — text embedded via the model's own token-embedding table, time-series
/// segments supplied by the OpenTSLM encoder/projector — then primes generation
/// with those embeddings via ``MLXEmbeddingGenerator`` (`inputs_embeds`), which is
/// the mechanism OpenTSLM-SP actually requires. This replaces the previous
/// stats-string approximation that never fed embeddings to the model.
public final class OpenTSLMLLM {

    private let logger = Logger(subsystem: "HealthyLLM", category: "OpenTSLMLLM")
    private let llmRunner: LLMRunner
    private let session: LLMLocalSession

    public init(llmRunner: LLMRunner, session: LLMLocalSession) {
        self.llmRunner = llmRunner
        self.session = session
    }

    /// Generate text conditioned on interleaved text + time-series embeddings.
    ///
    /// - Parameters:
    ///   - prePrompt: instruction text placed before the series.
    ///   - timeSeriesText: per-series descriptive text; count must match `timeSeriesEmbeddings`.
    ///   - timeSeriesEmbeddings: projected encoder embeddings, each shaped `[N_i, hidden]`.
    ///   - postPrompt: instruction / answer-cue text placed after the series.
    ///   - maxTokens: maximum number of tokens to generate.
    public func generate(
        prePrompt: String,
        timeSeriesText: [String],
        timeSeriesEmbeddings: [MLXArray],
        postPrompt: String,
        maxTokens: Int = 128
    ) async throws -> String {
        precondition(
            timeSeriesText.count == timeSeriesEmbeddings.count,
            "time series text/embedding count mismatch")

        guard let container = await MainActor.run(body: { session.modelContainer }) else {
            throw NSError(
                domain: "OpenTSLMLLM", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "LLM session is not ready"])
        }

        logger.info("generate: entering container.perform (series=\(timeSeriesEmbeddings.count, privacy: .public), maxTokens=\(maxTokens, privacy: .public))")
        return try await container.perform { context in
            guard let model = context.model as? EmbeddingLlamaModel else {
                let actual = String(describing: type(of: context.model))
                self.logger.error("generate: loaded model is \(actual, privacy: .public), not EmbeddingLlamaModel — registration did not take effect")
                throw NSError(
                    domain: "OpenTSLMLLM", code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Loaded model is \(actual), not EmbeddingLlamaModel — ensure EmbeddingLlamaModelRegistration.register() runs before the model is loaded."])
            }
            let tokenizer = context.tokenizer
            self.logger.info("generate: model OK, building interleaved inputs_embeds")

            // Embed one text segment to `[T, hidden]` via the model's own token table.
            // We always add special tokens (i.e. BOS for Llama-3.2) to match the Python
            // OpenTSLM-MLX reference, which batch-tokenizes every text segment through the
            // HuggingFace tokenizer's default `add_special_tokens=True` path — each of
            // pre-prompt, per-series text label, and post-prompt gets BOS at its start.
            func textEmbedding(_ text: String) -> MLXArray {
                let ids = tokenizer.encode(text: text, addSpecialTokens: true)
                let idArray = MLXArray(ids.map { Int32($0) }, [1, ids.count])
                return model.tokenEmbeddings(idArray)[0]   // [1, T, hidden] -> [T, hidden]
            }

            // Interleave pre-prompt, then (series text, series embeds)…, then post-prompt.
            let pre = textEmbedding(prePrompt)
            let dtype = pre.dtype
            var segments: [MLXArray] = [pre]
            for (text, series) in zip(timeSeriesText, timeSeriesEmbeddings) {
                segments.append(textEmbedding(text))
                segments.append(series.asType(dtype))   // match token-embedding dtype
            }
            segments.append(textEmbedding(postPrompt))

            let sequence = concatenated(segments, axis: 0)                  // [L, hidden]
            let inputsEmbeds = sequence.reshaped([1, sequence.dim(0), sequence.dim(1)])
            eval(inputsEmbeds)
            self.logger.info("generate: inputs_embeds=\(inputsEmbeds.shape, privacy: .public); starting decode")

            // Llama-3.2 has multiple stop tokens — `<|end_of_text|>` (the default
            // `eosTokenId`) and `<|eot_id|>` (end-of-turn). The Python reference
            // checks `tokenizer.eos_token_ids` plural; mirror that.
            var stopTokens: Set<Int> = []
            if let primary = tokenizer.eosTokenId { stopTokens.insert(primary) }
            for marker in ["<|eot_id|>", "<|end_of_text|>"] {
                let ids = tokenizer.encode(text: marker, addSpecialTokens: false)
                if ids.count == 1 { stopTokens.insert(ids[0]) }
            }
            self.logger.info("generate: stopTokens=\(stopTokens, privacy: .public)")

            // Pure greedy argmax, matching OpenTSLM-MLX `opentslm_sp.py`, which calls
            // `mlx_lm.generate_step(..., max_tokens=...)` with no temperature, top-p,
            // or repetition penalty — so we stay byte-for-byte aligned with the reference.
            let generator = MLXEmbeddingGenerator(
                model: model,
                eosTokenIds: stopTokens,
                tokenSampler: { logits in
                    argMax(logits, axis: -1).item(Int.self)
                },
                decodeTokens: { ids in
                    tokenizer.decode(tokens: ids, skipSpecialTokens: true)
                }
            )

            let output = try generator.generate(inputsEmbeds: inputsEmbeds, maxNewTokens: maxTokens)
            self.logger.info("generate: decode complete, produced \(output.count, privacy: .public) chars")
            return output
        }
    }
}

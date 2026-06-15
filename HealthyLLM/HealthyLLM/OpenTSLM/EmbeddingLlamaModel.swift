//
// EmbeddingLlamaModel.swift
//
// Vendored copy of mlx-swift-examples `Libraries/MLXLLM/Models/Llama.swift`
// (Copyright © 2024 Apple Inc.), adapted to accept pre-computed input embeddings
// (`inputs_embeds`) so OpenTSLM soft-prompt time-series embeddings can be fed
// directly into the Llama decoder.
//
// Why a full vendored copy rather than a subclass/extension: the upstream
// building blocks (`Attention`, `MLP`, `TransformerBlock`, `LlamaModelInner`)
// and `LlamaConfiguration`'s stored properties are `internal` to MLXLLM and
// therefore unreachable from this module. Copying is the only way to inject
// embeddings into the forward pass from app code.
//
// Differences from upstream (kept intentionally minimal):
//  - Types renamed with an `EmbeddingLlama*` prefix to avoid colliding with the
//    real `MLXLLM.LlamaModel` (which is still loaded for non-OpenTSLM chat).
//  - `EmbeddingLlamaConfiguration` is a verbatim copy of `LlamaConfiguration`
//    (its fields are internal upstream, so we need our own readable copy).
//  - The inner/outer forward gains an optional `inputEmbedding` that, when
//    present, replaces the token-embedding lookup. The token-only
//    `callAsFunction(_:cache:)` (the `LLMModel` requirement used by normal
//    chat / `TokenIterator`) is unchanged.
//  - Conforms to the app's `EmbeddingPrimedLanguageModel` so
//    `MLXEmbeddingGenerator` can drive embedding-primed decoding.
//  - The unused `computeBaseFrequency` free function from upstream is omitted.
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MLX
import MLXFast
import MLXLLM
import MLXLMCommon
import MLXNN

// MARK: - Rotary embedding (verbatim from upstream, retyped to our config)

private class DynamicNTKScalingRoPE: Module {
    let dims: Int
    let maxPositionEmbeddings: Int
    let traditional: Bool
    var base: Float?
    let scale: Float
    let ropeType: String
    let ropeScaling: [String: StringOrNumber]?
    var freqs: MLXArray?

    init(
        dims: Int,
        maxPositionEmbeddings: Int?,
        traditional: Bool = false,
        base: Float = 10000,
        scale: Float = 1.0,
        ropeType: String = "default",
        ropeScaling: [String: StringOrNumber]? = nil
    ) {
        self.dims = dims
        self.maxPositionEmbeddings = maxPositionEmbeddings ?? 2048
        self.traditional = traditional
        self.base = base
        self.scale = scale
        self.ropeType = ropeType
        self.ropeScaling = ropeScaling
        super.init()
        computeFreqs()
    }

    private func computeFreqs() {
        if ropeType != "llama3" {
            freqs = nil
            return
        }

        guard let ropeScaling = ropeScaling,
            case .float(let factor) = ropeScaling["factor"],
            case .float(let lowFreqFactor) = ropeScaling["low_freq_factor"] ?? .float(1.0),
            case .float(let highFreqFactor) = ropeScaling["high_freq_factor"] ?? .float(4.0),
            case .float(let oldContextLen) = ropeScaling["original_max_position_embeddings"]
                ?? .float(8192),
            let base
        else {
            freqs = nil
            return
        }

        let lowFreqWavelen = oldContextLen / lowFreqFactor
        let highFreqWavelen = oldContextLen / highFreqFactor

        let indices = MLXArray(stride(from: 0, to: dims, by: 2))
        var frequencies = MLX.pow(base, indices / Float(dims))
        let wavelens = 2 * Float.pi * frequencies

        frequencies = MLX.where(
            wavelens .> MLXArray(lowFreqWavelen), frequencies * factor, frequencies)
        let isMediumFreq = MLX.logicalAnd(
            wavelens .> MLXArray(highFreqWavelen),
            wavelens .< MLXArray(lowFreqWavelen)
        )
        let smoothFactors =
            (oldContextLen / wavelens - lowFreqFactor) / (highFreqFactor - lowFreqFactor)
        let smoothFreqs = frequencies / ((1 - smoothFactors) / factor + smoothFactors)

        freqs = MLX.where(isMediumFreq, smoothFreqs, frequencies)
        self.base = nil
    }

    func callAsFunction(_ x: MLXArray, offset: Int = 0) -> MLXArray {
        MLXFast.RoPE(
            x,
            dimensions: dims,
            traditional: traditional,
            base: base,
            scale: scale,
            offset: offset,
            freqs: freqs
        )
    }
}

// MARK: - Attention / MLP / block (verbatim from upstream, retyped to our config)

private class Attention: Module {

    let args: EmbeddingLlamaConfiguration
    let scale: Float

    @ModuleInfo(key: "q_proj") var wq: Linear
    @ModuleInfo(key: "k_proj") var wk: Linear
    @ModuleInfo(key: "v_proj") var wv: Linear
    @ModuleInfo(key: "o_proj") var wo: Linear

    let rope: DynamicNTKScalingRoPE

    init(_ args: EmbeddingLlamaConfiguration) {
        self.args = args

        let dim = args.hiddenSize
        let heads = args.attentionHeads
        let kvHeads = args.kvHeads

        let headDim = args.resolvedHeadDimensions
        self.scale = pow(Float(headDim), -0.5)

        self._wq.wrappedValue = Linear(dim, heads * headDim, bias: args.attentionBias)
        self._wk.wrappedValue = Linear(dim, kvHeads * headDim, bias: args.attentionBias)
        self._wv.wrappedValue = Linear(dim, kvHeads * headDim, bias: args.attentionBias)
        self._wo.wrappedValue = Linear(heads * headDim, dim, bias: args.attentionBias)

        self.rope = DynamicNTKScalingRoPE(
            dims: headDim,
            maxPositionEmbeddings: args.maxPositionEmbeddings,
            traditional: args.ropeTraditional,
            base: args.ropeTheta,
            scale: 1.0,
            ropeType: {
                if case .string(let value) = args.ropeScaling?["type"] {
                    return value
                } else {
                    return "default"
                }
            }(),
            ropeScaling: args.ropeScaling)
    }

    func callAsFunction(
        _ x: MLXArray, mask: MLXArray? = nil, cache: KVCache?
    ) -> MLXArray {
        let (B, L) = (x.dim(0), x.dim(1))

        var queries = wq(x)
        var keys = wk(x)
        var values = wv(x)

        // Prepare the queries, keys and values for the attention computation
        queries = queries.reshaped(B, L, args.attentionHeads, -1).transposed(0, 2, 1, 3)
        keys = keys.reshaped(B, L, args.kvHeads, -1).transposed(0, 2, 1, 3)
        values = values.reshaped(B, L, args.kvHeads, -1).transposed(0, 2, 1, 3)

        if let cache {
            queries = rope(queries, offset: cache.offset)
            keys = rope(keys, offset: cache.offset)
            (keys, values) = cache.update(keys: keys, values: values)
        } else {
            queries = rope(queries)
            keys = rope(keys)
        }

        let output = MLXFast.scaledDotProductAttention(
            queries: queries, keys: keys, values: values, scale: scale, mask: mask
        )
        .transposed(0, 2, 1, 3)
        .reshaped(B, L, -1)

        return wo(output)
    }
}

private class MLP: Module, UnaryLayer {

    @ModuleInfo(key: "gate_proj") var gate: Linear
    @ModuleInfo(key: "down_proj") var down: Linear
    @ModuleInfo(key: "up_proj") var up: Linear

    init(_ args: EmbeddingLlamaConfiguration) {
        self._gate.wrappedValue = Linear(args.hiddenSize, args.intermediateSize, bias: args.mlpBias)
        self._down.wrappedValue = Linear(args.intermediateSize, args.hiddenSize, bias: args.mlpBias)
        self._up.wrappedValue = Linear(args.hiddenSize, args.intermediateSize, bias: args.mlpBias)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let activation = silu(gate(x))
        return down(activation * up(x))
    }
}

private class TransformerBlock: Module {
    @ModuleInfo(key: "self_attn") var attention: Attention
    @ModuleInfo(key: "mlp") var mlp: MLP

    @ModuleInfo(key: "input_layernorm") var inputLayerNorm: RMSNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionLayerNorm: RMSNorm

    init(_ args: EmbeddingLlamaConfiguration) {
        self._attention.wrappedValue = Attention(args)
        self._mlp.wrappedValue = MLP(args)
        self._inputLayerNorm.wrappedValue = RMSNorm(
            dimensions: args.hiddenSize, eps: args.rmsNormEps)
        self._postAttentionLayerNorm.wrappedValue = RMSNorm(
            dimensions: args.hiddenSize, eps: args.rmsNormEps)
    }

    func callAsFunction(
        _ x: MLXArray, mask: MLXArray? = nil, cache: KVCache?
    ) -> MLXArray {
        var r = attention(inputLayerNorm(x), mask: mask, cache: cache)
        let h = x + r
        r = mlp(postAttentionLayerNorm(h))
        let out = h + r
        return out
    }
}

// MARK: - Inner model (MODIFIED: accepts inputEmbedding)

private class EmbeddingLlamaModelInner: Module {

    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding

    let layers: [TransformerBlock]
    let norm: RMSNorm

    init(_ args: EmbeddingLlamaConfiguration) {
        precondition(args.vocabularySize > 0)

        self._embedTokens.wrappedValue = Embedding(
            embeddingCount: args.vocabularySize, dimensions: args.hiddenSize)

        self.layers = (0 ..< args.hiddenLayers).map { _ in TransformerBlock(args) }
        self.norm = RMSNorm(dimensions: args.hiddenSize, eps: args.rmsNormEps)
    }

    /// When `inputEmbedding` is supplied it is used directly as the hidden state,
    /// skipping the token-embedding lookup. Llama (unlike Gemma) does not scale
    /// the embeddings, so there is nothing else to reconcile here.
    func callAsFunction(
        _ inputs: MLXArray?, cache: [KVCache]? = nil, inputEmbedding: MLXArray? = nil
    ) -> MLXArray {
        var h: MLXArray
        if let inputEmbedding {
            h = inputEmbedding
        } else if let inputs {
            h = embedTokens(inputs)
        } else {
            fatalError("EmbeddingLlamaModelInner requires either inputs or inputEmbedding")
        }

        let mask: MLXArray? = createAttentionMask(h: h, cache: cache)

        for (i, layer) in layers.enumerated() {
            h = layer(h, mask: mask, cache: cache?[i])
        }

        return norm(h)
    }
}

// MARK: - Outer model (MODIFIED: embedding-primed overload + protocol conformance)

/// Drop-in for `MLXLLM.LlamaModel` whose forward pass can be primed with
/// pre-computed embeddings. Parameter graph is identical to upstream `LlamaModel`
/// (same `@ModuleInfo` keys, same nesting), so the factory's weight loading,
/// quantization, and `verify` all work unchanged.
class EmbeddingLlamaModel: Module, LLMModel, KVCacheDimensionProvider {

    let vocabularySize: Int
    let kvHeads: [Int]

    fileprivate let model: EmbeddingLlamaModelInner

    @ModuleInfo(key: "lm_head") var lmHead: Linear?

    init(_ args: EmbeddingLlamaConfiguration) {
        self.vocabularySize = args.vocabularySize
        self.kvHeads = (0 ..< args.hiddenLayers).map { _ in args.kvHeads }
        self.model = EmbeddingLlamaModelInner(args)
        if !args.tieWordEmbeddings {
            self._lmHead.wrappedValue = Linear(args.hiddenSize, args.vocabularySize, bias: false)
        }
    }

    private func forward(_ inputs: MLXArray?, cache: [KVCache]?, inputEmbedding: MLXArray?)
        -> MLXArray
    {
        let out = model(inputs, cache: cache, inputEmbedding: inputEmbedding)
        if let lmHead {
            return lmHead(out)
        } else {
            return model.embedTokens.asLinear(out)
        }
    }

    /// `LLMModel` requirement — token-only path used by normal chat / `TokenIterator`.
    /// Unchanged behaviour vs. upstream `LlamaModel`.
    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]?) -> MLXArray {
        forward(inputs, cache: cache, inputEmbedding: nil)
    }

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        // Remove unused precomputed rotary frequencies
        weights.filter {
            !$0.key.contains("self_attn.rotary_emb.inv_freq")
        }
    }

    /// Token-embedding lookup, exposed so callers can build interleaved
    /// soft-prompt sequences (text token embeddings + projected time-series
    /// embeddings) before priming the decoder via ``inputEmbedding``.
    /// `ids` is an integer index array, e.g. shape `[B, T]`; result is `[B, T, hidden]`.
    func tokenEmbeddings(_ ids: MLXArray) -> MLXArray {
        model.embedTokens(ids)
    }
}

// MARK: - LoRA

extension EmbeddingLlamaModel: LoRAModel {
    func loraLinearLayers() -> LoRALinearLayers {
        model.layers.map { ($0.attention, ["q_proj", "v_proj"]) }
    }
}

// MARK: - Embedding-primed decoding (app protocol from MLXEmbeddingGenerator)

extension EmbeddingLlamaModel: EmbeddingPrimedLanguageModel {
    func makeCache() -> [KVCache] {
        newCache(parameters: nil)
    }

    func callAsFunction(
        _ inputs: MLXArray?, cache: [KVCache], inputEmbedding: MLXArray?
    ) throws -> MLXArray {
        forward(inputs, cache: cache, inputEmbedding: inputEmbedding)
    }
}

// MARK: - Configuration (verbatim copy of upstream LlamaConfiguration)

struct EmbeddingLlamaConfiguration: Codable, Sendable {

    var hiddenSize: Int
    var hiddenLayers: Int
    var intermediateSize: Int
    var attentionHeads: Int
    var headDimensions: Int?
    var rmsNormEps: Float
    var vocabularySize: Int
    var kvHeads: Int
    var maxPositionEmbeddings: Int?
    var ropeTheta: Float = 10_000
    var ropeTraditional: Bool = false
    var ropeScaling: [String: StringOrNumber]?
    var tieWordEmbeddings: Bool = true
    var attentionBias: Bool = false
    var mlpBias: Bool = false

    var resolvedHeadDimensions: Int {
        headDimensions ?? (hiddenSize / attentionHeads)
    }

    enum CodingKeys: String, CodingKey {
        case hiddenSize = "hidden_size"
        case hiddenLayers = "num_hidden_layers"
        case intermediateSize = "intermediate_size"
        case attentionHeads = "num_attention_heads"
        case headDimensions = "head_dim"
        case rmsNormEps = "rms_norm_eps"
        case vocabularySize = "vocab_size"
        case kvHeads = "num_key_value_heads"
        case maxPositionEmbeddings = "max_position_embeddings"
        case ropeTheta = "rope_theta"
        case ropeTraditional = "rope_traditional"
        case ropeScaling = "rope_scaling"
        case tieWordEmbeddings = "tie_word_embeddings"
        case attentionBias = "attention_bias"
        case mlpBias = "mlp_bias"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        hiddenLayers = try container.decode(Int.self, forKey: .hiddenLayers)
        intermediateSize = try container.decode(Int.self, forKey: .intermediateSize)
        attentionHeads = try container.decode(Int.self, forKey: .attentionHeads)
        headDimensions = try container.decodeIfPresent(Int.self, forKey: .headDimensions)
        rmsNormEps = try container.decode(Float.self, forKey: .rmsNormEps)
        vocabularySize = try container.decode(Int.self, forKey: .vocabularySize)
        kvHeads = try container.decodeIfPresent(Int.self, forKey: .kvHeads) ?? attentionHeads
        maxPositionEmbeddings = try container.decodeIfPresent(
            Int.self, forKey: .maxPositionEmbeddings)
        if let ropeTheta = try container.decodeIfPresent(Float.self, forKey: .ropeTheta) {
            self.ropeTheta = ropeTheta
        }
        if let ropeTraditional = try container.decodeIfPresent(Bool.self, forKey: .ropeTraditional)
        {
            self.ropeTraditional = ropeTraditional
        }
        ropeScaling = try container.decodeIfPresent(
            [String: StringOrNumber].self, forKey: .ropeScaling)
        if let tieWordEmbeddings = try container.decodeIfPresent(
            Bool.self, forKey: .tieWordEmbeddings)
        {
            self.tieWordEmbeddings = tieWordEmbeddings
        }
        if let attentionBias = try container.decodeIfPresent(Bool.self, forKey: .attentionBias) {
            self.attentionBias = attentionBias
        }
        if let mlpBias = try container.decodeIfPresent(Bool.self, forKey: .mlpBias) {
            self.mlpBias = mlpBias
        }

        if let ropeScaling {
            if ropeScaling["factor"] == nil {
                throw DecodingError.dataCorruptedError(
                    forKey: .ropeScaling, in: container,
                    debugDescription: "rope_scaling must contain 'factor'")
            }
            if let ropeType = ropeScaling["type"] ?? ropeScaling["rope_type"] {
                if case .string = ropeType {
                    let options = [
                        StringOrNumber.string("linear"), StringOrNumber.string("dynamic"),
                        StringOrNumber.string("llama3"),
                    ]
                    if !options.contains(ropeType) {
                        throw DecodingError.dataCorruptedError(
                            forKey: .ropeScaling, in: container,
                            debugDescription:
                                "rope_scaling 'type' currently only supports 'linear', 'dynamic', or 'llama3'"
                        )
                    }
                }
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .ropeScaling, in: container,
                    debugDescription: "rope_scaling must contain either 'type' or 'rope_type'")
            }
        }
    }
}

// MARK: - Factory registration

/// Overrides the `"llama"` (and `"mistral"`) entries in the shared MLX model-type
/// registry so SpeziLLMLocal's `LLMModelFactory.shared.loadContainer(...)`
/// instantiates `EmbeddingLlamaModel` instead of the stock `LlamaModel`.
///
/// Call once at app/Spezi configuration time, *before* the first model load.
/// The closure mirrors the upstream private `create(_:_:)` helper: the URL it
/// receives is the `config.json` file itself (not the directory), and it only
/// builds the bare model — the factory loads/quantizes weights afterwards.
enum EmbeddingLlamaModelRegistration {
    static func register() {
        let creator: @Sendable (URL) throws -> any LanguageModel = { url in
            let config = try JSONDecoder().decode(
                EmbeddingLlamaConfiguration.self, from: Data(contentsOf: url))
            return EmbeddingLlamaModel(config)
        }
        LLMModelFactory.shared.typeRegistry.registerModelType("llama", creator: creator)
        LLMModelFactory.shared.typeRegistry.registerModelType("mistral", creator: creator)
    }
}

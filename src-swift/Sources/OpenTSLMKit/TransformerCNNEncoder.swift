import Foundation
import MLX
import MLXNN

// MARK: - TransformerEncoderLayer

/// 1:1 Swift port of Python MLX `TransformerEncoderLayer`.
///
/// Matches `nn.TransformerEncoderLayer(norm_first=False, activation='gelu')`.
/// Weight keys are identical to the Python module so safetensors files load directly.
public class TransformerEncoderLayer: Module, UnaryLayer {

    @ModuleInfo(key: "self_attn") var selfAttn: MultiHeadAttention
    @ModuleInfo(key: "linear1") var linear1: Linear
    @ModuleInfo(key: "linear2") var linear2: Linear
    @ModuleInfo(key: "norm1") var norm1: LayerNorm
    @ModuleInfo(key: "norm2") var norm2: LayerNorm

    public init(dModel: Int, numHeads: Int, dimFeedforward: Int = 1024) {
        _selfAttn.wrappedValue = MultiHeadAttention(dimensions: dModel, numHeads: numHeads, bias: true)
        _linear1.wrappedValue = Linear(dModel, dimFeedforward)
        _linear2.wrappedValue = Linear(dimFeedforward, dModel)
        _norm1.wrappedValue = LayerNorm(dimensions: dModel)
        _norm2.wrappedValue = LayerNorm(dimensions: dModel)
    }

    /// Python equivalent:
    /// ```python
    /// x = self.norm1(x + self.self_attn(x, x, x))
    /// x = self.norm2(x + self.linear2(nn.gelu(self.linear1(x))))
    /// ```
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        var x = x
        x = norm1(x + selfAttn(x, keys: x, values: x))
        x = norm2(x + linear2(gelu(linear1(x))))
        return x
    }
}

// MARK: - TransformerCNNEncoder

/// 1:1 Swift port of Python MLX `TransformerCNNEncoder`.
///
/// Takes raw time series `[B, L]` and produces patch embeddings `[B, N, outputDim]`
/// where `N = L / patchSize`. Weight keys match the Python module exactly.
public class TransformerCNNEncoder: Module, UnaryLayer {

    public let patchSize: Int

    @ModuleInfo(key: "patch_embed") var patchEmbed: Conv1d
    @ParameterInfo(key: "pos_embed") var posEmbed: MLXArray
    @ModuleInfo(key: "input_norm") var inputNorm: LayerNorm
    var layers: [TransformerEncoderLayer]

    public init(
        outputDim: Int = 128,
        transformerInputDim: Int = 128,
        numHeads: Int = 8,
        numLayers: Int = 6,
        patchSize: Int = 4,
        ffDim: Int = 1024,
        maxPatches: Int = 2600
    ) {
        self.patchSize = patchSize
        _patchEmbed.wrappedValue = Conv1d(
            inputChannels: 1,
            outputChannels: transformerInputDim,
            kernelSize: patchSize,
            stride: patchSize,
            bias: false
        )
        _posEmbed.wrappedValue = MLXArray.zeros([1, maxPatches, transformerInputDim])
        _inputNorm.wrappedValue = LayerNorm(dimensions: transformerInputDim)
        self.layers = (0 ..< numLayers).map { _ in
            TransformerEncoderLayer(
                dModel: transformerInputDim,
                numHeads: numHeads,
                dimFeedforward: ffDim
            )
        }
    }

    /// Python equivalent:
    /// ```python
    /// x = x[:, :, None]               # [B, L, 1]
    /// x = self.patch_embed(x)          # [B, N, dim]
    /// x = x + self.pos_embed[:, :N, :]
    /// x = self.input_norm(x)
    /// for layer in self.layers: x = layer(x)
    /// ```
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // [B, L] → [B, L, 1]  (channel-last for MLX Conv1d)
        var x = x.expandedDimensions(axis: -1)
        // Conv1d → [B, N, transformerInputDim]
        x = patchEmbed(x)
        let n = x.dim(1)
        // Add positional embeddings sliced to actual patch count
        x = x + posEmbed[0..., 0 ..< n, 0...]
        x = inputNorm(x)
        for layer in layers {
            x = layer(x)
        }
        return x
    }
}

// MARK: - Weight loading

extension TransformerCNNEncoder {

    /// Load weights from a `.safetensors` file produced by the Python MLX encoder.
    ///
    /// The file must contain keys in Python MLX naming convention, e.g.:
    /// - `patch_embed.weight`
    /// - `pos_embed`
    /// - `input_norm.weight`, `input_norm.bias`
    /// - `layers.0.self_attn.query_proj.weight`, …
    public func loadWeights(from url: URL) throws {
        let arrays = try loadArrays(url: url)
        let params = ModuleParameters.unflattened(arrays)
        try update(parameters: params, verify: .noUnusedKeys)
    }
}

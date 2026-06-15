import Foundation
import MLX
import MLXNN

/// 1:1 Swift port of Python MLX `MLPProjector`.
public class MLPProjector: Module, UnaryLayer {

    @ModuleInfo(key: "norm") var norm: LayerNorm
    @ModuleInfo(key: "linear") var linear: Linear

    public init(inputDim: Int = 128, outputDim: Int = 2048) {
        _norm.wrappedValue = LayerNorm(dimensions: inputDim)
        _linear.wrappedValue = Linear(inputDim, outputDim)
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        gelu(linear(norm(x)))
    }
}

extension MLPProjector {

    public func loadWeights(from url: URL) throws {
        let arrays = try loadArrays(url: url)
        let params = ModuleParameters.unflattened(arrays)
        try update(parameters: params, verify: .noUnusedKeys)
    }
}
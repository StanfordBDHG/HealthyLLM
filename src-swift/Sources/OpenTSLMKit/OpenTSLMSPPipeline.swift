import Foundation
import MLX

public struct OpenTSLMSPSample {

    public let prePrompt: String
    public let timeSeriesText: [String]
    public let timeSeries: [[Float]]
    public let postPrompt: String
    public let label: String
    public let answer: String

    public init(
        prePrompt: String,
        timeSeriesText: [String],
        timeSeries: [[Float]],
        postPrompt: String,
        label: String,
        answer: String
    ) {
        self.prePrompt = prePrompt
        self.timeSeriesText = timeSeriesText
        self.timeSeries = timeSeries
        self.postPrompt = postPrompt
        self.label = label
        self.answer = answer
    }
}

public final class OpenTSLMSPPipeline {

    public let encoder: TransformerCNNEncoder
    public let projector: MLPProjector
    public let patchSize: Int

    public init(hiddenSize: Int = 2048, patchSize: Int = 4, maxPatches: Int = 2600) {
        self.patchSize = patchSize
        self.encoder = TransformerCNNEncoder(
            transformerInputDim: 128,
            patchSize: patchSize,
            maxPatches: maxPatches
        )
        self.projector = MLPProjector(inputDim: 128, outputDim: hiddenSize)
    }

    public func loadWeights(encoderURL: URL, projectorURL: URL) throws {
        try encoder.loadWeights(from: encoderURL)
        try projector.loadWeights(from: projectorURL)
    }

    public func projectTimeSeries(_ seriesBatch: [[Float]]) -> [MLXArray] {
        guard !seriesBatch.isEmpty else { return [] }

        let maxLength = paddedLength(for: seriesBatch)
        var paddedRows: [[Float]] = []
        paddedRows.reserveCapacity(seriesBatch.count)

        for series in seriesBatch {
            if series.count == maxLength {
                paddedRows.append(series)
                continue
            }
            var row = Array<Float>(repeating: 0, count: maxLength)
            row.replaceSubrange(0 ..< series.count, with: series)
            paddedRows.append(row)
        }

        let flat = paddedRows.flatMap { $0 }.map(Double.init)
        let input = MLXArray(converting: flat, [seriesBatch.count, maxLength])
        let encoded = encoder(input)
        let projected = projector(encoded)
        eval(projected)

        var result: [MLXArray] = []
        result.reserveCapacity(seriesBatch.count)
        for i in 0 ..< seriesBatch.count {
            result.append(projected[i])
        }
        return result
    }

    public func projectSample(_ sample: OpenTSLMSPSample) -> [MLXArray] {
        projectTimeSeries(sample.timeSeries)
    }

    private func paddedLength(for seriesBatch: [[Float]]) -> Int {
        let currentMax = seriesBatch.map(\.count).max() ?? 0
        let remainder = currentMax % patchSize
        if remainder == 0 {
            return currentMax
        }
        return currentMax + (patchSize - remainder)
    }
}

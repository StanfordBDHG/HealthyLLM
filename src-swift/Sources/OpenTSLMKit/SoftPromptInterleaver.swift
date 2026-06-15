import Foundation
import MLX

public struct SoftPromptSegment {

    public let embeddings: MLXArray
    public let attentionMask: MLXArray

    public init(embeddings: MLXArray, attentionMask: MLXArray) {
        precondition(embeddings.ndim == 2, "embeddings must have shape [T, H]")
        precondition(attentionMask.ndim == 1, "attentionMask must have shape [T]")
        precondition(embeddings.dim(0) == attentionMask.dim(0), "segment length mismatch")
        self.embeddings = embeddings
        self.attentionMask = attentionMask
    }

    var length: Int {
        Int(attentionMask.sum().item(Float.self))
    }
}

public struct SoftPromptSample {

    public let prePrompt: SoftPromptSegment
    public let timeSeriesText: [SoftPromptSegment]
    public let timeSeriesEmbeddings: [MLXArray]
    public let postPrompt: SoftPromptSegment

    public init(
        prePrompt: SoftPromptSegment,
        timeSeriesText: [SoftPromptSegment],
        timeSeriesEmbeddings: [MLXArray],
        postPrompt: SoftPromptSegment
    ) {
        precondition(timeSeriesText.count == timeSeriesEmbeddings.count, "time series text/embedding count mismatch")
        self.prePrompt = prePrompt
        self.timeSeriesText = timeSeriesText
        self.timeSeriesEmbeddings = timeSeriesEmbeddings
        self.postPrompt = postPrompt
    }
}

public struct SoftPromptBatch {

    public let inputsEmbeds: MLXArray
    public let attentionMask: MLXArray
}

public enum SoftPromptInterleaver {

    public static func padAndInterleaveBatch(_ batch: [SoftPromptSample]) -> SoftPromptBatch {
        precondition(!batch.isEmpty, "batch must not be empty")

        let hiddenSize = Int(batch[0].prePrompt.embeddings.dim(1))
        var allSequenceEmbeds: [MLXArray] = []
        var allSequenceMasks: [MLXArray] = []

        for sample in batch {
            var sequenceEmbeds: [MLXArray] = []
            var sequenceMasks: [MLXArray] = []

            func appendSegment(_ segment: SoftPromptSegment) {
                let length = segment.length
                sequenceEmbeds.append(segment.embeddings[0 ..< length, 0...])
                sequenceMasks.append(MLXArray.ones([length]))
            }

            appendSegment(sample.prePrompt)

            for (textSegment, projected) in zip(sample.timeSeriesText, sample.timeSeriesEmbeddings) {
                appendSegment(textSegment)
                sequenceEmbeds.append(projected)
                sequenceMasks.append(MLXArray.ones([Int(projected.dim(0))]))
            }

            appendSegment(sample.postPrompt)

            allSequenceEmbeds.append(concatenated(sequenceEmbeds, axis: 0))
            allSequenceMasks.append(concatenated(sequenceMasks, axis: 0))
        }

        let maxLength = allSequenceEmbeds.map { Int($0.dim(0)) }.max() ?? 0
        var paddedEmbeds: [MLXArray] = []
        var paddedMasks: [MLXArray] = []

        for (embeddings, mask) in zip(allSequenceEmbeds, allSequenceMasks) {
            let currentLength = Int(embeddings.dim(0))
            let padLength = maxLength - currentLength
            if padLength > 0 {
                let paddingEmbeds = MLXArray.zeros([padLength, hiddenSize])
                let paddingMask = MLXArray.zeros([padLength])
                paddedEmbeds.append(concatenated([embeddings, paddingEmbeds], axis: 0))
                paddedMasks.append(concatenated([mask, paddingMask], axis: 0))
            } else {
                paddedEmbeds.append(embeddings)
                paddedMasks.append(mask)
            }
        }

        return SoftPromptBatch(
            inputsEmbeds: stacked(paddedEmbeds, axis: 0),
            attentionMask: stacked(paddedMasks, axis: 0)
        )
    }
}
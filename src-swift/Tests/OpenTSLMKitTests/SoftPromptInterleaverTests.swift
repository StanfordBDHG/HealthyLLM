import XCTest
import MLX
@testable import OpenTSLMKit

final class SoftPromptInterleaverTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        Device.setDefault(device: .cpu)
    }

    func testPadAndInterleaveBatch() {
        Device.withDefaultDevice(.cpu) {
            let sample1 = SoftPromptSample(
                prePrompt: SoftPromptSegment(
                    embeddings: MLXArray(converting: [Float(1), Float(2), Float(3), Float(4), Float(5), Float(6)], [3, 2]),
                    attentionMask: MLXArray(converting: [Float(1), Float(1), Float(0)], [3])
                ),
                timeSeriesText: [
                    SoftPromptSegment(
                        embeddings: MLXArray(converting: [Float(7), Float(8), Float(9), Float(10)], [2, 2]),
                        attentionMask: MLXArray(converting: [Float(1), Float(0)], [2])
                    )
                ],
                timeSeriesEmbeddings: [
                    MLXArray(converting: [Float(11), Float(12), Float(13), Float(14)], [2, 2])
                ],
                postPrompt: SoftPromptSegment(
                    embeddings: MLXArray(converting: [Float(15), Float(16), Float(17), Float(18)], [2, 2]),
                    attentionMask: MLXArray(converting: [Float(1), Float(1)], [2])
                )
            )

            let sample2 = SoftPromptSample(
                prePrompt: SoftPromptSegment(
                    embeddings: MLXArray(converting: [Float(21), Float(22)], [1, 2]),
                    attentionMask: MLXArray(converting: [Float(1)], [1])
                ),
                timeSeriesText: [
                    SoftPromptSegment(
                        embeddings: MLXArray(converting: [Float(23), Float(24)], [1, 2]),
                        attentionMask: MLXArray(converting: [Float(1)], [1])
                    )
                ],
                timeSeriesEmbeddings: [
                    MLXArray(converting: [Float(25), Float(26)], [1, 2])
                ],
                postPrompt: SoftPromptSegment(
                    embeddings: MLXArray(converting: [Float(27), Float(28)], [1, 2]),
                    attentionMask: MLXArray(converting: [Float(1)], [1])
                )
            )

            let batch = SoftPromptInterleaver.padAndInterleaveBatch([sample1, sample2])
            eval(batch.inputsEmbeds)
            eval(batch.attentionMask)

            XCTAssertEqual(batch.inputsEmbeds.shape, [2, 7, 2])
            XCTAssertEqual(batch.attentionMask.shape, [2, 7])

            let expected1 = MLXArray(converting: [
                Float(1), Float(2),
                Float(3), Float(4),
                Float(7), Float(8),
                Float(11), Float(12),
                Float(13), Float(14),
                Float(15), Float(16),
                Float(17), Float(18)
            ], [7, 2])
            let expected2 = MLXArray(converting: [
                Float(21), Float(22),
                Float(23), Float(24),
                Float(25), Float(26),
                Float(27), Float(28)
            ], [4, 2])
            let expectedEmbeds = stacked([expected1, concatenated([expected2, MLXArray.zeros([3, 2])], axis: 0)], axis: 0)

            let expectedMask1 = MLXArray(converting: [Float(1), Float(1), Float(1), Float(1), Float(1), Float(1), Float(1)], [7])
            let expectedMask2 = MLXArray(converting: [Float(1), Float(1), Float(1), Float(1)], [4])
            let expectedMasks = stacked([expectedMask1, concatenated([expectedMask2, MLXArray.zeros([3])], axis: 0)], axis: 0)

            let embedDiff = (batch.inputsEmbeds - expectedEmbeds).abs().max(keepDims: false)
            let maskDiff = (batch.attentionMask - expectedMasks).abs().max(keepDims: false)
            eval(embedDiff)
            eval(maskDiff)

            XCTAssertEqual(embedDiff.item(Float.self), 0.0)
            XCTAssertEqual(maskDiff.item(Float.self), 0.0)
        }
    }
}
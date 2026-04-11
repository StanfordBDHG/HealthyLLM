import XCTest
import MLX
import MLXRandom
@testable import OpenTSLMKit

final class TransformerCNNEncoderTests: XCTestCase {

    // Runs once before any test instance is created — set CPU before the
    // @TaskLocal default device is first evaluated (MLX's GPU init would crash
    // in the SPM test runner which has no Metal bundle).
    override class func setUp() {
        super.setUp()
        Device.setDefault(device: .cpu)
    }

    // Fixtures directory sits next to this file.
    private var fixturesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    // MARK: - Shape tests

    func testOutputShape_singleSample() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder()
            let x = MLXArray.zeros([1, 400])   // [B=1, L=400]
            let out = encoder(x)
            eval(out)
            // N = 400 / 4 = 100 patches, dim = 128
            XCTAssertEqual(out.shape, [1, 100, 128])
        }
    }

    func testOutputShape_batch() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder()
            let x = MLXArray.zeros([4, 800])   // [B=4, L=800]
            let out = encoder(x)
            eval(out)
            // N = 800 / 4 = 200 patches
            XCTAssertEqual(out.shape, [4, 200, 128])
        }
    }

    func testOutputShape_longerSequence() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder()
            let x = MLXArray.zeros([2, 2400])  // [B=2, L=2400] → N=600
            let out = encoder(x)
            eval(out)
            XCTAssertEqual(out.shape, [2, 600, 128])
        }
    }

    func testOutputShape_customPatchSize() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder(patchSize: 8)
            let x = MLXArray.zeros([2, 400])  // N = 400 / 8 = 50
            let out = encoder(x)
            eval(out)
            XCTAssertEqual(out.shape, [2, 50, 128])
        }
    }

    // MARK: - Determinism

    func testDeterminism() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder()
            // Non-trivial input: ramp from 0 to 1
            let vals = (0 ..< 800).map { Float($0) / 800.0 }
            let x = MLXArray(vals).reshaped(2, 400)

            let out1 = encoder(x)
            eval(out1)
            let out2 = encoder(x)
            eval(out2)

            let diff = (out1 - out2).abs().max(keepDims: false)
            eval(diff)
            XCTAssertEqual(diff.item(Float.self), 0.0,
                "Two identical forward passes must produce identical output")
        }
    }

    // MARK: - Finite values

    func testOutputIsFinite() {
        Device.withDefaultDevice(.cpu) {
            let encoder = TransformerCNNEncoder()
            // Deterministic non-trivial input
            let vals = (0 ..< 400).map { Float($0 % 17) / 16.0 - 0.5 }
            let x = MLXArray(vals).reshaped(1, 400)
            let out = encoder(x)
            eval(out)

            let hasNaN = isNaN(out).any().item(Bool.self)
            let hasInf = isInf(out).any().item(Bool.self)
            XCTAssertFalse(hasNaN, "Output must not contain NaN")
            XCTAssertFalse(hasInf, "Output must not contain Inf")
        }
    }

    // MARK: - Fixture-based numerical test (Python ↔ Swift parity)
    //
    // Run `tests/generate_encoder_fixtures.py` first to populate Tests/Fixtures/.
    // The test is skipped automatically if fixtures are missing.

    func testNumericalParityWithPython() throws {
        let weightsURL = fixturesURL.appendingPathComponent("encoder_weights.safetensors")
        let ioURL      = fixturesURL.appendingPathComponent("encoder_io.safetensors")

        guard FileManager.default.fileExists(atPath: weightsURL.path),
              FileManager.default.fileExists(atPath: ioURL.path)
        else {
            throw XCTSkip("Fixtures not found — run tests/generate_encoder_fixtures.py first")
        }

        try Device.withDefaultDevice(.cpu) {
            // Load encoder and weights
            let encoder = TransformerCNNEncoder()
            try encoder.loadWeights(from: weightsURL)

            // Load reference input and output
            let io = try loadArrays(url: ioURL)
            guard let refInput = io["input"], let refOutput = io["output"] else {
                XCTFail("encoder_io.npz missing 'input' or 'output' key")
                return
            }

            // Run Swift forward pass
            let swiftOutput = encoder(refInput)
            eval(swiftOutput)

            // Compare
            let absDiff = (swiftOutput - refOutput).abs()
            eval(absDiff)
            let maxDiff  = absDiff.max(keepDims: false).item(Float.self)
            let meanDiff = absDiff.mean(keepDims: false).item(Float.self)

            XCTAssertEqual(swiftOutput.shape, refOutput.shape, "Output shape mismatch")
            XCTAssertLessThan(maxDiff,  1e-4,
                "Max abs diff \(maxDiff) exceeds 1e-4 — Python/Swift parity check failed")
            XCTAssertLessThan(meanDiff, 1e-5,
                "Mean abs diff \(meanDiff) exceeds 1e-5")

            print("TransformerCNNEncoder parity: max_diff=\(maxDiff) mean_diff=\(meanDiff) ✓")
        }
    }
}

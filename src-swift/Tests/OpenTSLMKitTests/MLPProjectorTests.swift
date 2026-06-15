import XCTest
import MLX
import MLXRandom
@testable import OpenTSLMKit

final class MLPProjectorTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        Device.setDefault(device: .cpu)
    }

    func testOutputShape() {
        Device.withDefaultDevice(.cpu) {
            let projector = MLPProjector(inputDim: 8, outputDim: 16)
            let x = MLXArray.zeros([2, 7, 8])
            let out = projector(x)
            eval(out)
            XCTAssertEqual(out.shape, [2, 7, 16])
        }
    }

    func testDeterminism() {
        Device.withDefaultDevice(.cpu) {
            let projector = MLPProjector(inputDim: 8, outputDim: 16)
            let values = (0 ..< 112).map { Float($0) / 112.0 }
            let x = MLXArray(values).reshaped(2, 7, 8)

            let out1 = projector(x)
            eval(out1)
            let out2 = projector(x)
            eval(out2)

            let diff = (out1 - out2).abs().max(keepDims: false)
            eval(diff)
            XCTAssertEqual(diff.item(Float.self), 0.0)
        }
    }

    func testOutputIsFinite() {
        Device.withDefaultDevice(.cpu) {
            let projector = MLPProjector(inputDim: 8, outputDim: 16)
            let values = (0 ..< 112).map { Float($0 % 11) / 10.0 - 0.5 }
            let x = MLXArray(values).reshaped(2, 7, 8)
            let out = projector(x)
            eval(out)

            XCTAssertFalse(isNaN(out).any().item(Bool.self))
            XCTAssertFalse(isInf(out).any().item(Bool.self))
        }
    }
}
import Foundation
import MLX
import OpenTSLMKit

struct RunnerConfig {

    var encoderPath = "../checkpoints/mlx-checkpoint.encoder.safetensors"
    var projectorPath = "../checkpoints/mlx-checkpoint.projector.safetensors"
    var csvPath = "../data/sleep/sleep_cot.csv"
    var split = SleepEDFDataset.Split.test
    var sampleIdx = 0
    var hiddenSize = 2048
    var healthKitECGJSONPath: String?
    var useHardcodedECG = false
    var hardcodedECGSampleLength = 1024

    init(arguments: [String]) {
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            let value = (index + 1 < arguments.count) ? arguments[index + 1] : nil

            switch key {
            case "--encoder":
                if let value {
                    encoderPath = value
                    index += 1
                }
            case "--projector":
                if let value {
                    projectorPath = value
                    index += 1
                }
            case "--csv":
                if let value {
                    csvPath = value
                    index += 1
                }
            case "--split":
                if let value, let parsed = SleepEDFDataset.Split(rawValue: value) {
                    split = parsed
                    index += 1
                }
            case "--sample-idx":
                if let value, let parsed = Int(value) {
                    sampleIdx = parsed
                    index += 1
                }
            case "--hidden-size":
                if let value, let parsed = Int(value) {
                    hiddenSize = parsed
                    index += 1
                }
            case "--help", "-h":
                printHelpAndExit()
            case "--healthkit-ecg-json":
                if let value {
                    healthKitECGJSONPath = value
                    index += 1
                }
            case "--hardcoded-ecg":
                useHardcodedECG = true
            case "--hardcoded-ecg-length":
                if let value, let parsed = Int(value) {
                    hardcodedECGSampleLength = parsed
                    index += 1
                }
            default:
                break
            }

            index += 1
        }
    }

    func printHelpAndExit() -> Never {
        print("""
        OpenTSLMRunner - Swift runner for OpenTSLM encoder/projector pipeline

        Options:
          --encoder <path>       Encoder safetensors path
          --projector <path>     Projector safetensors path
          --csv <path>           Sleep-EDF CSV path
          --split <name>         train | validation | test
          --sample-idx <int>     Sample index inside selected split
          --hidden-size <int>    Projector output dimension
                    --healthkit-ecg-json <path>  HealthKit ECG JSON file for direct inference
                    --hardcoded-ecg        Use deterministic hardcoded ECG sample
                    --hardcoded-ecg-length <int> Hardcoded ECG sample length
          --help                 Show this help
        """)
        Foundation.exit(0)
    }
}

let config = RunnerConfig(arguments: CommandLine.arguments)
try Device.withDefaultDevice(.cpu) {
    let pipeline = OpenTSLMSPPipeline(hiddenSize: config.hiddenSize)
    try pipeline.loadWeights(
        encoderURL: URL(fileURLWithPath: config.encoderPath),
        projectorURL: URL(fileURLWithPath: config.projectorPath)
    )

    let sample: OpenTSLMSPSample
    if config.useHardcodedECG || config.healthKitECGJSONPath != nil {
        let ecgSample: HealthKitECGSample
        if let jsonPath = config.healthKitECGJSONPath {
            ecgSample = try ECGSampleFactory.loadFromJSON(at: URL(fileURLWithPath: jsonPath))
            print("Loaded HealthKit ECG JSON: \(jsonPath)")
        } else {
            ecgSample = ECGSampleFactory.hardcoded(sampleLength: config.hardcodedECGSampleLength)
            print("Using hardcoded ECG sample (length=\(config.hardcodedECGSampleLength))")
        }
        sample = ECGSampleFactory.toOpenTSLMSample(ecgSample)
    } else {
        let dataset = try SleepEDFDataset(
            csvURL: URL(fileURLWithPath: config.csvPath),
            split: config.split
        )

        if dataset.count == 0 {
            throw NSError(domain: "OpenTSLMRunner", code: 10, userInfo: [NSLocalizedDescriptionKey: "Selected split has no samples"])
        }

        let safeIndex = min(max(config.sampleIdx, 0), dataset.count - 1)
        sample = dataset.sample(at: safeIndex)

        print("Loaded sample index: \(safeIndex) (split=\(config.split.rawValue))")
    }

    let projected = pipeline.projectSample(sample)

    print("Label: \(sample.label)")
    print("Series count: \(sample.timeSeries.count)")
    print("Prompt text count: \(sample.timeSeriesText.count)")

    for (i, tensor) in projected.enumerated() {
        eval(tensor)
        print("Projected[\(i)] shape: \(tensor.shape)")
    }

    print("\nPython parity note:")
    print("- This runner executes the same Swift encoder + projector path as Python.")
    print("- Full LLM token generation (including LoRA text decoding) still runs in Python in this repo.")
}

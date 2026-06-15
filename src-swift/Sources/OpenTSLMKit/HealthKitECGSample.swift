import Foundation

public struct HealthKitECGSample: Codable {

    public let startDate: Date?
    public let endDate: Date?
    public let samplingFrequency: Float
    public let averageHeartRate: Float?
    public let classification: String?
    public let symptomsStatus: String?
    public let voltages: [Float]

    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        samplingFrequency: Float,
        averageHeartRate: Float? = nil,
        classification: String? = nil,
        symptomsStatus: String? = nil,
        voltages: [Float]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.samplingFrequency = samplingFrequency
        self.averageHeartRate = averageHeartRate
        self.classification = classification
        self.symptomsStatus = symptomsStatus
        self.voltages = voltages
    }
}

public enum ECGSampleFactory {

    public static func hardcoded(sampleLength: Int = 1024, samplingFrequency: Float = 256) -> HealthKitECGSample {
        let voltages: [Float] = (0 ..< sampleLength).map { index in
            let t = Float(index) / samplingFrequency

            // Synthetic ECG-like waveform with deterministic QRS spikes.
            let base = 0.025 * sin(2.0 * Float.pi * 1.2 * t)
            let pWave = 0.010 * sin(2.0 * Float.pi * 4.0 * t)
            let qrsPhase = t.truncatingRemainder(dividingBy: 0.86)
            let qrs = qrsPhase < 0.018 ? 0.72 * exp(-pow((qrsPhase - 0.006) * 120.0, 2.0)) : 0.0
            let tWave = 0.040 * exp(-pow((qrsPhase - 0.24) * 14.0, 2.0))
            return base + pWave + qrs + tWave
        }

        return HealthKitECGSample(
            samplingFrequency: samplingFrequency,
            averageHeartRate: 70,
            classification: "sinusRhythm_sample",
            symptomsStatus: "notSet_sample",
            voltages: voltages
        )
    }

    public static func loadFromJSON(at url: URL) throws -> HealthKitECGSample {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HealthKitECGSample.self, from: data)
    }

    public static func toOpenTSLMSample(_ ecg: HealthKitECGSample) -> OpenTSLMSPSample {
        let raw = ecg.voltages
        let normalized = zNormalize(raw)
        let mean = raw.reduce(0, +) / Float(max(raw.count, 1))
        let variance = raw.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Float(max(raw.count, 1))
        let std = max(sqrt(variance), 1e-6)

        let label = ecg.classification ?? "unknown"
        let rhythmHint = ecg.symptomsStatus ?? "unknown"
        let bpm = ecg.averageHeartRate.map { String(format: "%.1f", $0) } ?? "unknown"

        return OpenTSLMSPSample(
            prePrompt: """
            You are given a single-lead ECG segment from HealthKit. Analyze rhythm regularity and signal quality conservatively.

            """,
            timeSeriesText: [
                "The following is the ECG time series sampled at \(ecg.samplingFrequency)Hz with mean \(String(format: \"%.6f\", mean)) and std \(String(format: \"%.6f\", std))."
            ],
            timeSeries: [normalized],
            postPrompt: """
            First describe waveform quality and rhythm regularity, then summarize notable concerns and when to seek care.

            Answer:
            """,
            label: label,
            answer: "symptoms_status=\(rhythmHint), average_heart_rate=\(bpm)"
        )
    }

    private static func zNormalize(_ values: [Float]) -> [Float] {
        let mean = values.reduce(0, +) / Float(max(values.count, 1))
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Float(max(values.count, 1))
        let std = max(sqrt(variance), 1e-6)
        return values.map { ($0 - mean) / std }
    }
}

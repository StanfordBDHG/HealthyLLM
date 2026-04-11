//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MLX
import OSLog
import Spezi

@Observable
class OpenTSLMInferenceService: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLM", category: "OpenTSLMInferenceService")

    required init() { }

    func runSleepSampleInference(split: SleepEDFDataset.Split = .test, sampleIndex: Int = 0) throws -> String {
        guard let csvURL = resolveAssetURL(
            overridePath: Constants.openTSLMSleepCSVPath,
            bundledName: Constants.openTSLMSleepCSVName,
            fileExtension: "csv"
        ) else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing sleep CSV in bundle/OpenTSLM or override path"]) 
        }

        guard let encoderURL = resolveAssetURL(
            overridePath: Constants.openTSLMEncoderCheckpointPath,
            bundledName: Constants.openTSLMEncoderCheckpointName,
            fileExtension: "safetensors"
        ) else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing encoder checkpoint in bundle/OpenTSLM or override path"])
        }

        guard let projectorURL = resolveAssetURL(
            overridePath: Constants.openTSLMProjectorCheckpointPath,
            bundledName: Constants.openTSLMProjectorCheckpointName,
            fileExtension: "safetensors"
        ) else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing projector checkpoint in bundle/OpenTSLM or override path"])
        }

        logger.info("OpenTSLM assets: csv=\(csvURL.path), encoder=\(encoderURL.path), projector=\(projectorURL.path)")

        let dataset = try SleepEDFDataset(csvURL: csvURL, split: split)
        guard dataset.count > 0 else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Selected split has no samples"])
        }

        let safeIndex = min(max(sampleIndex, 0), dataset.count - 1)
        let sample = dataset.sample(at: safeIndex)

        let pipeline = OpenTSLMSPPipeline(hiddenSize: 2048)
        try pipeline.loadWeights(encoderURL: encoderURL, projectorURL: projectorURL)

        let projected = pipeline.projectSample(sample)
        guard let first = projected.first else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Projection returned no tensors"])
        }

        eval(first)
        logger.info("OpenTSLM sample inference complete: split=\(split.rawValue), sample=\(safeIndex)")

        let outputText: String
        if !sample.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outputText = sample.answer
        } else {
            outputText = "Generated encoder/projector embeddings for the sample."
        }

        return formatSampleReport(
            title: "Sleep-EDF sample inference",
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            postPrompt: sample.postPrompt,
            label: sample.label,
            answer: outputText,
            extraLines: [
                "split: \(split.rawValue)",
                "sample_index: \(safeIndex)",
                "series_count: \(sample.timeSeries.count)",
            ]
        )
    }

    func runECGSampleInference() throws -> String {
        let ecg = try loadECGSample()
        let sample = makeOpenTSLMSample(from: ecg)

        return formatSampleReport(
            title: "ECG sample inference",
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            postPrompt: sample.postPrompt,
            label: sample.label,
            answer: sample.answer,
            extraLines: [
                "sampling_frequency_hz: \(String(format: "%.1f", ecg.samplingFrequency))",
                "voltage_count: \(ecg.voltages.count)",
                "source: \(ecg.sourceDescription)",
            ]
        )
    }

    private func resolveAssetURL(overridePath: String, bundledName: String, fileExtension: String) -> URL? {
        let fileManager = FileManager.default

        if !overridePath.isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath)
            if fileManager.fileExists(atPath: overrideURL.path) {
                return overrideURL
            }
        }

        if let bundledURL = Bundle.main.url(
            forResource: bundledName,
            withExtension: fileExtension,
            subdirectory: Constants.openTSLMBundleSubdirectory
        ) {
            return bundledURL
        }

        return Bundle.main.url(forResource: bundledName, withExtension: fileExtension)
    }

    private func loadECGSample() throws -> ECGSample {
        if let url = resolveECGJSONURL() {
            return try ECGSample.load(from: url)
        }

        return ECGSample.hardcoded(sampleLength: Constants.hardcodedECGSampleLength)
    }

    private func resolveECGJSONURL() -> URL? {
        let overridePath = Constants.openTSLMECGJSONPath
        guard !overridePath.isEmpty else {
            return nil
        }

        let fileManager = FileManager.default
        let overrideURL = URL(fileURLWithPath: overridePath)
        guard fileManager.fileExists(atPath: overrideURL.path) else {
            return nil
        }

        return overrideURL
    }

    private func makeOpenTSLMSample(from ecg: ECGSample) -> OpenTSLMSPSample {
        let normalizedVoltages = Self.zNormalize(ecg.voltages).map(Float.init)
        let mean = ecg.voltages.isEmpty ? 0.0 : ecg.voltages.reduce(0, +) / Double(ecg.voltages.count)
        let variance = ecg.voltages.reduce(0.0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(max(ecg.voltages.count, 1))
        let standardDeviation = max(sqrt(variance), 1e-6)

        return OpenTSLMSPSample(
            prePrompt: """
            You are given a single-lead ECG segment from HealthKit. Analyze rhythm regularity and signal quality conservatively.

            """,
            timeSeriesText: [
                "The following is the ECG time series sampled at \(String(format: "%.1f", ecg.samplingFrequency))Hz with mean \(String(format: "%.6f", mean)) and std \(String(format: "%.6f", standardDeviation)).",
                "Normalized preview: [\(normalizedVoltages.prefix(256).map { String(format: "%.6f", $0) }.joined(separator: ", "))]",
            ],
            timeSeries: [normalizedVoltages],
            postPrompt: """
            First describe waveform quality and rhythm regularity, then summarize notable concerns and when to seek care.

            Answer:
            """,
            label: ecg.classification ?? "unknown",
            answer: ecg.summary
        )
    }

    private func formatSampleReport(
        title: String,
        prePrompt: String,
        timeSeriesText: [String],
        postPrompt: String,
        label: String,
        answer: String,
        extraLines: [String] = []
    ) -> String {
        var lines: [String] = [
            title,
            "",
            "pre_prompt:",
            prePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            "",
            "time_series_text:",
        ]

        lines.append(contentsOf: timeSeriesText.map { "- \($0)" })
        lines.append("")
        lines.append("post_prompt:")
        lines.append(postPrompt.trimmingCharacters(in: .whitespacesAndNewlines))

        if !extraLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: extraLines)
        }

        lines.append("")
        lines.append("label: \(label)")
        lines.append("answer: \(answer.isEmpty ? "No Data" : answer)")

        return lines.joined(separator: "\n")
    }

    private static func zNormalize(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else {
            return []
        }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(values.count)
        let standardDeviation = max(sqrt(variance), 1e-6)
        return values.map { ($0 - mean) / standardDeviation }
    }
}

private struct ECGSample {
    let samplingFrequency: Double
    let classification: String?
    let symptomsStatus: String?
    let averageHeartRate: Double?
    let voltages: [Double]

    var sourceDescription: String {
        if classification != nil || symptomsStatus != nil || averageHeartRate != nil {
            return "healthkit_json"
        }
        return "hardcoded"
    }

    var summary: String {
        let classificationText = classification ?? "unknown"
        let symptomsText = symptomsStatus ?? "unknown"
        let heartRateText = averageHeartRate.map { String(format: "%.1f", $0) } ?? "unknown"
        return "classification=\(classificationText), symptoms_status=\(symptomsText), average_heart_rate=\(heartRateText)"
    }

    static func hardcoded(sampleLength: Int = 1024, samplingFrequency: Double = 256) -> ECGSample {
        let voltages: [Double] = (0 ..< sampleLength).map { index in
            let t = Double(index) / samplingFrequency

            let base = 0.025 * sin(2.0 * .pi * 1.2 * t)
            let pWave = 0.010 * sin(2.0 * .pi * 4.0 * t)
            let qrsPhase = t.truncatingRemainder(dividingBy: 0.86)
            let qrs = qrsPhase < 0.018 ? 0.72 * exp(-pow((qrsPhase - 0.006) * 120.0, 2.0)) : 0.0
            let tWave = 0.040 * exp(-pow((qrsPhase - 0.24) * 14.0, 2.0))
            return base + pWave + qrs + tWave
        }

        return ECGSample(
            samplingFrequency: samplingFrequency,
            classification: "sinusRhythm_sample",
            symptomsStatus: "notSet_sample",
            averageHeartRate: 70.0,
            voltages: voltages
        )
    }

    static func load(from url: URL) throws -> ECGSample {
        let data = try Data(contentsOf: url)
        let decoded = try JSONSerialization.jsonObject(with: data)

        guard let object = decoded as? [String: Any],
              let voltages = object["voltages"] as? [Double]
        else {
            throw NSError(
                domain: "OpenTSLMInferenceService",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported ECG JSON format"]
            )
        }

        let samplingFrequency = object["samplingFrequency"] as? Double
            ?? object["sampling_frequency"] as? Double
            ?? 256.0
        let classification = object["classification"] as? String
        let symptomsStatus = object["symptomsStatus"] as? String
            ?? object["symptoms_status"] as? String
        let averageHeartRate = object["averageHeartRate"] as? Double
            ?? object["average_heart_rate"] as? Double

        return ECGSample(
            samplingFrequency: samplingFrequency,
            classification: classification,
            symptomsStatus: symptomsStatus,
            averageHeartRate: averageHeartRate,
            voltages: voltages
        )
    }
}

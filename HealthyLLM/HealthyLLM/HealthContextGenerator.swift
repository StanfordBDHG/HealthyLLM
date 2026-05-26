//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi

class HealthContextGenerator: DefaultInitializable, Module, EnvironmentAccessible {
    required init() { }

    func buildSystemPrompt(userInfo: UserInfo?, electrocardiograms: [ElectrocardiogramData]) -> HealthyLLMContextEntity {
        var prompt = """
        You are a health assistant. Provide a careful, non-diagnostic interpretation of the user's health data.
        If ECG data is present, focus on signal quality, rhythm regularity, heart rate, and any notable abnormalities.
        Do not claim to diagnose a condition.
        """

        if let userInfo {
            prompt += "\n\nUser profile:\n"
            prompt += userInfo.asJSONRepresentation(.prettyPrinted) ?? "No Data"
        }

        if !electrocardiograms.isEmpty {
            prompt += "\n\nLatest ECG samples:\n"
            prompt += electrocardiograms.enumerated().map { index, sample in
                formatECGSample(sample, index: index + 1)
            }.joined(separator: "\n\n")
        } else {
            prompt += "\n\nLatest ECG samples: No Data"
        }

        prompt += "\n\nRespond with a concise clinical-style summary and a safety note if the tracing looks concerning."

        return .init(.system, content: prompt)
    }

    private func formatECGSample(_ sample: ElectrocardiogramData, index: Int) -> String {
        let voltages = sample.voltages
        let average = voltages.isEmpty ? nil : voltages.reduce(0, +) / Double(voltages.count)
        let minimum = voltages.min()
        let maximum = voltages.max()
        let preview = voltages.prefix(24).map { String(format: "%.4f", $0) }.joined(separator: ", ")

                let normalizedVoltages = zNormalize(voltages)
                let normalizedPreview = normalizedVoltages.prefix(48).map { String(format: "%.6f", $0) }.joined(separator: ", ")

        let averageHeartRateText = sample.averageHeartRate.map(String.init(describing:)) ?? "No Data"
        let samplingFrequencyText = sample.samplingFrequency.map(String.init(describing:)) ?? "No Data"
        let voltageMeanText = average.map(String.init(describing:)) ?? "No Data"
        let voltageMinText = minimum.map(String.init(describing:)) ?? "No Data"
        let voltageMaxText = maximum.map(String.init(describing:)) ?? "No Data"

                let sleepCotStylePrompt = """
                sleep_cot_style_sample:
                    pre_prompt: You are given a short single-lead ECG time series segment. Analyze rhythm, signal quality, and notable concerns conservatively.
                    time_series_text:
                        - The following is the ECG time series with mean \(String(format: "%.6f", average ?? 0)) and min/max \(String(format: "%.6f", minimum ?? 0))/\(String(format: "%.6f", maximum ?? 0)).
                    time_series_normalized_preview: [\(normalizedPreview)]
                    post_prompt: First summarize waveform quality and rhythm regularity, then provide brief safety guidance and when to seek care.
                """

        var lines: [String] = [
            "ECG sample #\(index)",
            "start_date: \(sample.startDate.formatted(date: .abbreviated, time: .shortened))",
            "end_date: \(sample.endDate.formatted(date: .abbreviated, time: .shortened))",
            "classification: \(sample.classification)",
            "symptoms_status: \(sample.symptomsStatus)",
            "average_heart_rate: \(averageHeartRateText)",
            "sampling_frequency_hz: \(samplingFrequencyText)",
            "voltage_count: \(sample.numberOfVoltageMeasurements)",
            "voltage_mean: \(voltageMeanText)",
            "voltage_min: \(voltageMinText)",
            "voltage_max: \(voltageMaxText)"
        ]

        if !preview.isEmpty {
            lines.append("voltage_preview: [\(preview)]")
        }

        lines.append(sleepCotStylePrompt)

        return lines.joined(separator: "\n")
    }

    private func zNormalize(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else {
            return []
        }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(values.count)
        let std = max(sqrt(variance), 1e-6)
        return values.map { ($0 - mean) / std }
    }
}

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
import SpeziLLM
import SpeziLLMLocal

@Observable
class OpenTSLMInferenceService: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLM", category: "OpenTSLMInferenceService")

    required init() { }

    func runSleepSampleInference(
        split: SleepEDFDataset.Split = .test,
        sampleIndex: Int = 0,
        llmRunner: LLMRunner? = nil,
        llmSession: LLMLocalSession? = nil
    ) async throws -> String {
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

        // Use provided LLM session or fall back to embedding description
        if let llmRunner = llmRunner, let llmSession = llmSession {
            let openTSLMLLM = OpenTSLMLLM(llmRunner: llmRunner, session: llmSession)

            // Create SoftPromptSample
            let softPromptSample = try createSoftPromptSample(from: sample, with: projected, tokenizer: openTSLMLLM)

            // Interleave text and embeddings
            let batch = SoftPromptInterleaver.padAndInterleaveBatch([softPromptSample])

            // Generate text using the LLM with embeddings
            let generatedText = try await openTSLMLLM.generateWithEmbeddings(
                inputsEmbeds: batch.inputsEmbeds,
                prompt: createLLMPrompt(from: sample)
            )

            let outputText = """
            **LLM-Generated Analysis:**

            \(generatedText)

            ---
            Ground-truth label: \(sample.label)
            Ground-truth answer: \(sample.answer)
            """

            return formatSampleReport(
                title: "Sleep-EDF sample inference with LLM generation",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: [
                    "split: \(split.rawValue)",
                    "sample_index: \(safeIndex)",
                    "series_count: \(sample.timeSeries.count)",
                    "embeddings_shape: \(first.shape)",
                    "llm_model: \(Constants.llmModelName)",
                    "llm_integration: yes",
                ]
            )
        } else {
            // Fallback: just describe the embeddings
            let outputText = """
            **Embeddings Computed Successfully**

            The time series embeddings were computed (\(first.shape)) but no LLM session was provided for generation.

            To enable LLM generation with embeddings:
            1. Ensure the HealthDataInterpreter is initialized with a valid LLM session
            2. Pass the llmRunner and llmSession parameters to this method

            Ground-truth label: \(sample.label)
            Ground-truth answer: \(sample.answer)
            """

            return formatSampleReport(
                title: "Sleep-EDF sample inference (embeddings only)",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: [
                    "split: \(split.rawValue)",
                    "sample_index: \(safeIndex)",
                    "series_count: \(sample.timeSeries.count)",
                    "embeddings_shape: \(first.shape)",
                    "llm_integration: no",
                ]
            )
        }
    }

    func runECGSampleInference(
        llmRunner: LLMRunner? = nil,
        llmSession: LLMLocalSession? = nil
    ) async throws -> String {
        let ecg = try loadECGSample()
        let sample = makeOpenTSLMSample(from: ecg)

        // Load encoder and projector for ECG embeddings
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

        let pipeline = OpenTSLMSPPipeline(hiddenSize: 2048)
        try pipeline.loadWeights(encoderURL: encoderURL, projectorURL: projectorURL)

        // Project ECG time series to embeddings
        let projected = pipeline.projectSample(sample)
        guard let first = projected.first else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Projection returned no tensors"])
        }

        eval(first)

        // Use provided LLM session or fall back to embedding description
        if let llmRunner = llmRunner, let llmSession = llmSession {
            let openTSLMLLM = OpenTSLMLLM(llmRunner: llmRunner, session: llmSession)

            // Create SoftPromptSample
            let softPromptSample = try createSoftPromptSample(from: sample, with: projected, tokenizer: openTSLMLLM)

            // Interleave text and embeddings
            let batch = SoftPromptInterleaver.padAndInterleaveBatch([softPromptSample])

            // Generate text using the LLM with embeddings
            let generatedText = try await openTSLMLLM.generateWithEmbeddings(
                inputsEmbeds: batch.inputsEmbeds,
                prompt: createLLMPrompt(from: sample)
            )

            let outputText = """
            **LLM-Generated ECG Analysis:**

            \(generatedText)

            ---
            Pre-defined summary: \(sample.answer)
            """

            return formatSampleReport(
                title: "ECG sample inference with LLM generation",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: [
                    "sampling_frequency_hz: \(String(format: "%.1f", ecg.samplingFrequency))",
                    "voltage_count: \(ecg.voltages.count)",
                    "source: \(ecg.sourceDescription)",
                    "embeddings_shape: \(first.shape)",
                    "llm_model: \(Constants.llmModelName)",
                    "llm_integration: yes",
                ]
            )
        } else {
            // Fallback: just describe the embeddings
            let outputText = """
            **Embeddings Computed Successfully**

            The ECG time series embeddings were computed (\(first.shape)) but no LLM session was provided for generation.

            To enable LLM generation with embeddings:
            1. Ensure the HealthDataInterpreter is initialized with a valid LLM session
            2. Pass the llmRunner and llmSession parameters to this method

            Pre-defined summary: \(sample.answer)
            """

            return formatSampleReport(
                title: "ECG sample inference (embeddings only)",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: [
                    "sampling_frequency_hz: \(String(format: "%.1f", ecg.samplingFrequency))",
                    "voltage_count: \(ecg.voltages.count)",
                    "source: \(ecg.sourceDescription)",
                    "embeddings_shape: \(first.shape)",
                    "llm_integration: no",
                ]
            )
        }
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

    private func resolveLocalModelDirectory() -> URL? {
        let fileManager = FileManager.default

        // Check for override path
        if let overridePath = Constants.localModelSourcePathOverride,
           let overrideURL = existingDirectoryURL(at: overridePath, fileManager: fileManager) {
            return overrideURL
        }

        // Check bundled model directory
        if let bundledLocalModelURL = Bundle.main.resourceURL {
            let bundledDirectory = bundledLocalModelURL.appendingPathComponent(Constants.localModelBundleSubdirectory, isDirectory: true)
            if fileManager.fileExists(atPath: bundledDirectory.path) {
                return bundledDirectory
            }

            // Check if model files are directly in bundle root
            let requiredModelFiles = ["config.json", "tokenizer.json", "model.safetensors"]
            let bundledRootFiles = requiredModelFiles.allSatisfy { fileName in
                fileManager.fileExists(atPath: bundledLocalModelURL.appendingPathComponent(fileName).path)
            }

            if bundledRootFiles {
                return bundledLocalModelURL
            }
        }

        // Fallback: detect a downloaded model snapshot from Hugging Face cache
        let sanitizedRepoID = Constants.llmModelName.replacingOccurrences(of: "/", with: "--")
        let hostSnapshotsPath = "\(Constants.hostHuggingFaceCacheRoot)/models--\(sanitizedRepoID)/snapshots"
        let hostSnapshotsURL = URL(fileURLWithPath: hostSnapshotsPath, isDirectory: true)

        if let hostSnapshot = newestSnapshotDirectory(in: hostSnapshotsURL, fileManager: fileManager) {
            return hostSnapshot
        }

        let snapshotsPath = "~/.cache/huggingface/hub/models--\(sanitizedRepoID)/snapshots"
        let snapshotsURL = URL(fileURLWithPath: NSString(string: snapshotsPath).expandingTildeInPath, isDirectory: true)
        return newestSnapshotDirectory(in: snapshotsURL, fileManager: fileManager)
    }

    private func newestSnapshotDirectory(in snapshotsURL: URL, fileManager: FileManager) -> URL? {
        guard fileManager.fileExists(atPath: snapshotsURL.path) else {
            return nil
        }

        let directoryContents = try? fileManager.contentsOfDirectory(
            at: snapshotsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return directoryContents?
            .filter { url in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            .sorted(by: { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            })
            .first
    }

    private func existingDirectoryURL(at rawPath: String, fileManager: FileManager) -> URL? {
        let expandedPath = NSString(string: rawPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return url
    }

    private func createSoftPromptSample(from sample: OpenTSLMSPSample, with projectedEmbeddings: [MLXArray], tokenizer: OpenTSLMLLM) throws -> SoftPromptSample {
        // For now, create simplified embeddings based on text length
        // In a full implementation, this would use proper tokenization and model embeddings
        let hiddenSize = 2048 // Llama 3.2 1B hidden size

        // Create embeddings for text segments (simplified approximation)
        let prePromptEmbeddings = MLXArray.zeros([sample.prePrompt.count / 4 + 1, hiddenSize]) // Rough token approximation
        let postPromptEmbeddings = MLXArray.zeros([sample.postPrompt.count / 4 + 1, hiddenSize])

        let prePromptMask = MLXArray.ones([Int(prePromptEmbeddings.dim(0))])
        let postPromptMask = MLXArray.ones([Int(postPromptEmbeddings.dim(0))])

        let prePromptSegment = SoftPromptSegment(embeddings: prePromptEmbeddings, attentionMask: prePromptMask)
        let postPromptSegment = SoftPromptSegment(embeddings: postPromptEmbeddings, attentionMask: postPromptMask)

        // Create text segments for time series descriptions
        var timeSeriesTextSegments: [SoftPromptSegment] = []
        for text in sample.timeSeriesText {
            let approxTokens = text.count / 4 + 1 // Rough approximation
            let embeddings = MLXArray.zeros([approxTokens, hiddenSize])
            let mask = MLXArray.ones([approxTokens])
            timeSeriesTextSegments.append(SoftPromptSegment(embeddings: embeddings, attentionMask: mask))
        }

        return SoftPromptSample(
            prePrompt: prePromptSegment,
            timeSeriesText: timeSeriesTextSegments,
            timeSeriesEmbeddings: projectedEmbeddings,
            postPrompt: postPromptSegment
        )
    }

    private func createLLMPrompt(from sample: OpenTSLMSPSample) -> String {
        """
        \(sample.prePrompt)

        Time series descriptions:
        \(sample.timeSeriesText.enumerated().map { "Series \($0.offset + 1): \($0.element)" }.joined(separator: "\n"))

        \(sample.postPrompt)
        """
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

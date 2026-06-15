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
        let sample = cappedSample(dataset.sample(at: safeIndex))

        let projected: [MLXArray]
        do {
            let pipeline = OpenTSLMSPPipeline(hiddenSize: 2048)
            try pipeline.loadWeights(encoderURL: encoderURL, projectorURL: projectorURL)
            projected = pipeline.projectSample(sample)
        }

        guard let first = projected.first else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Projection returned no tensors"])
        }

        eval(first)
        GPU.clearCache()
        logger.info("OpenTSLM encoder projection done: split=\(split.rawValue), sample=\(safeIndex)")

        if let llmRunner = llmRunner, let llmSession = llmSession {
            let loraApplied = await applyLoRAIfAvailable(on: llmSession)

            GPU.clearCache()

            if Constants.openTSLMRunSampleLLMGeneration {
                let openTSLMLLM = OpenTSLMLLM(llmRunner: llmRunner, session: llmSession)
                let generatedText = try await openTSLMLLM.generate(
                    prePrompt: sample.prePrompt,
                    timeSeriesText: sample.timeSeriesText,
                    timeSeriesEmbeddings: projected,
                    postPrompt: sample.postPrompt,
                    maxTokens: 200
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
                    extraLines: openTSLMSampleExtraLines(
                        split: split,
                        sampleIndex: safeIndex,
                        sample: sample,
                        embeddingsShape: first.shape,
                        loraApplied: loraApplied
                    )
                )
            }

            let outputText = """
            **OpenTSLM encoder + LoRA (on-device decode skipped to avoid OOM)**

            Projected time-series embeddings: \(first.shape)
            LoRA applied to Llama: \(loraApplied ? "yes" : "no")
            Ground-truth label: \(sample.label)
            Ground-truth answer: \(sample.answer)

            Set `HEALTHYLLM_OPEN_TSLM_RUN_LLM=1` in the scheme to attempt a short LLM decode (may exceed device memory).
            """

            return formatSampleReport(
                title: "Sleep-EDF sample inference (encoder + LoRA)",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: openTSLMSampleExtraLines(
                    split: split,
                    sampleIndex: safeIndex,
                    sample: sample,
                    embeddingsShape: first.shape,
                    loraApplied: loraApplied
                )
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
        split: ECGQACoTDataset.Split = .test,
        sampleIndex: Int = 0,
        llmRunner: LLMRunner? = nil,
        llmSession: LLMLocalSession? = nil
    ) async throws -> String {
        let loaded = try loadECGQACoTSample(split: split, sampleIndex: sampleIndex)
        let sample = cappedSample(loaded.sample)
        var metadata = loaded.metadata
        metadata = ECGQACoTSampleMetadata(
            source: metadata.source,
            loader: metadata.loader,
            split: metadata.split,
            sampleIndex: metadata.sampleIndex,
            ecgId: metadata.ecgId,
            templateId: metadata.templateId,
            questionType: metadata.questionType,
            seriesCount: sample.timeSeries.count,
            samplesPerLead: sample.timeSeries.first?.count ?? 0
        )

        // Load ECG encoder + projector (per-task checkpoints — sleep weights would
        // produce a meaningless projection for ECG inputs).
        let projected = try loadPipelineAndProject(
            sample,
            encoderName: Constants.openTSLMECGEncoderCheckpointName,
            projectorName: Constants.openTSLMECGProjectorCheckpointName
        )
        guard let first = projected.first else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Projection returned no tensors"])
        }

        GPU.clearCache()

        guard Constants.openTSLMRunSampleLLMGeneration,
              let llmRunner,
              let llmSession
        else {
            let outputText = """
            **OpenTSLM ECG encoder (Llama decode skipped)**

            Projected time-series embeddings: \(first.shape)
            Dataset answer: \(sample.answer)

            Set `HEALTHYLLM_OPEN_TSLM_RUN_LLM=1` (and do not set `HEALTHYLLM_SKIP_LLM_LOAD=1`) to run Llama decode — likely OOM on physical iPhone.
            """

            return formatSampleReport(
                title: "ECG-QA CoT sample inference (encoder only)",
                prePrompt: sample.prePrompt,
                timeSeriesText: sample.timeSeriesText,
                postPrompt: sample.postPrompt,
                label: sample.label,
                answer: outputText,
                extraLines: ecgQACoTSampleExtraLines(
                    metadata: metadata,
                    embeddingsShape: first.shape,
                    loraApplied: false
                ) + [
                    "llm_model: \(Constants.llmModelName)",
                    "llm_integration: encoder-only",
                    "llama_loaded: \(Constants.skipLLMLoad ? "no" : "yes")",
                ]
            )
        }

        // Llama loaded + generation requested
        let loraApplied = await applyLoRAIfAvailable(
            on: llmSession,
            checkpointName: Constants.openTSLMECGLoRACheckpointName
        )
        GPU.clearCache()

        let openTSLMLLM = OpenTSLMLLM(llmRunner: llmRunner, session: llmSession)
        let generatedText = try await openTSLMLLM.generate(
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            timeSeriesEmbeddings: projected,
            postPrompt: sample.postPrompt,
            maxTokens: 200
        )

        let outputText = """
        **LLM-Generated ECG Analysis:**

        \(generatedText)

        ---
        Dataset answer: \(sample.answer)
        """

        return formatSampleReport(
            title: "ECG-QA CoT sample inference with LLM generation",
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            postPrompt: sample.postPrompt,
            label: sample.label,
            answer: outputText,
            extraLines: ecgQACoTSampleExtraLines(
                metadata: metadata,
                embeddingsShape: first.shape,
                loraApplied: loraApplied
            ) + [
                "llm_model: \(Constants.llmModelName)",
                "llm_integration: generate",
            ]
        )
    }

    /// Runs OpenTSLM-SP on a real (e.g. HealthKit) ECG recording and returns the model's
    /// analysis text. Unlike ``runECGSampleInference`` (a debug command using a hardcoded/JSON
    /// sample and emitting a verbose report), this uses the supplied recording, requires a live
    /// LLM session, and returns a clean user-facing answer.
    func runECGInference(
        voltages: [Double],
        samplingFrequency: Double,
        classification: String?,
        symptomsStatus: String?,
        averageHeartRate: Double?,
        llmRunner: LLMRunner?,
        llmSession: LLMLocalSession?
    ) async throws -> String {
        guard let llmRunner, let llmSession else {
            throw NSError(
                domain: "OpenTSLMInferenceService", code: 7,
                userInfo: [NSLocalizedDescriptionKey: "An LLM session is required to analyze the ECG."])
        }
        guard !voltages.isEmpty else {
            throw NSError(
                domain: "OpenTSLMInferenceService", code: 8,
                userInfo: [NSLocalizedDescriptionKey: "The ECG recording has no voltage samples."])
        }

        logger.info("runECGInference: start voltages=\(voltages.count, privacy: .public) freq=\(samplingFrequency, privacy: .public)")
        let ecg = ECGSample(
            source: .healthkit,
            samplingFrequency: samplingFrequency,
            classification: classification,
            symptomsStatus: symptomsStatus,
            averageHeartRate: averageHeartRate,
            voltages: voltages
        )
        let sample = cappedSample(makeOpenTSLMSample(from: ecg))
        let projected = try loadPipelineAndProject(
            sample,
            encoderName: Constants.openTSLMECGEncoderCheckpointName,
            projectorName: Constants.openTSLMECGProjectorCheckpointName
        )
        logger.info("runECGInference: projected series=\(projected.count, privacy: .public) shape0=\(projected.first?.shape ?? [], privacy: .public)")

        let loraApplied = await applyLoRAIfAvailable(
            on: llmSession,
            checkpointName: Constants.openTSLMECGLoRACheckpointName
        )
        GPU.clearCache()
        logger.info("runECGInference: loraApplied=\(loraApplied, privacy: .public); calling generate")

        let openTSLMLLM = OpenTSLMLLM(llmRunner: llmRunner, session: llmSession)
        let analysis = try await openTSLMLLM.generate(
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            timeSeriesEmbeddings: projected,
            postPrompt: sample.postPrompt,
            maxTokens: 200
        )
        logger.info("runECGInference: generate returned \(analysis.count, privacy: .public) chars")
        let trimmed = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The ECG model did not produce an analysis." : trimmed
    }

    /// Resolves the encoder/projector checkpoints, loads the SP pipeline, and projects the
    /// sample's time series to LLM-hidden-size embeddings.
    /// Defaults to the sleep checkpoints; the ECG paths pass the `.ecg` names.
    private func loadPipelineAndProject(
        _ sample: OpenTSLMSPSample,
        encoderName: String = Constants.openTSLMEncoderCheckpointName,
        projectorName: String = Constants.openTSLMProjectorCheckpointName
    ) throws -> [MLXArray] {
        guard let encoderURL = resolveAssetURL(
            overridePath: Constants.openTSLMEncoderCheckpointPath,
            bundledName: encoderName,
            fileExtension: "safetensors"
        ) else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing encoder checkpoint '\(encoderName)' in bundle/OpenTSLM or override path"])
        }
        guard let projectorURL = resolveAssetURL(
            overridePath: Constants.openTSLMProjectorCheckpointPath,
            bundledName: projectorName,
            fileExtension: "safetensors"
        ) else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing projector checkpoint '\(projectorName)' in bundle/OpenTSLM or override path"])
        }

        let pipeline = OpenTSLMSPPipeline(hiddenSize: 2048)
        try pipeline.loadWeights(encoderURL: encoderURL, projectorURL: projectorURL)
        let projected = pipeline.projectSample(sample)
        guard let first = projected.first else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Projection returned no tensors"])
        }
        eval(first)
        GPU.clearCache()
        return projected
    }

    /// Defaults to the sleep LoRA checkpoint; the ECG paths pass `Constants.openTSLMECGLoRACheckpointName`.
    private func applyLoRAIfAvailable(
        on llmSession: LLMLocalSession,
        checkpointName: String = Constants.openTSLMLoRACheckpointName
    ) async -> Bool {
        do {
            try await OpenTSLMLoRA.applyIfNeeded(on: llmSession, checkpointName: checkpointName)
            return true
        } catch {
            logger.warning("OpenTSLM LoRA apply failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func resolveAssetURL(overridePath: String, bundledName: String, fileExtension: String) -> URL? {
        let fileManager = FileManager.default

        if !overridePath.isEmpty {
            let expandedPath = NSString(string: overridePath).expandingTildeInPath
            let overrideURL = URL(fileURLWithPath: expandedPath)
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

    private func cappedSample(_ sample: OpenTSLMSPSample) -> OpenTSLMSPSample {
        let cap = Constants.openTSLMMaxTimeSeriesLength
        guard cap > 0 else { return sample }

        let cappedSeries = sample.timeSeries.map { series in
            series.count > cap ? Array(series.prefix(cap)) : series
        }
        guard cappedSeries != sample.timeSeries else { return sample }

        return OpenTSLMSPSample(
            prePrompt: sample.prePrompt,
            timeSeriesText: sample.timeSeriesText,
            timeSeries: cappedSeries,
            postPrompt: sample.postPrompt,
            label: sample.label,
            answer: sample.answer
        )
    }

    private func openTSLMSampleExtraLines(
        split: SleepEDFDataset.Split,
        sampleIndex: Int,
        sample: OpenTSLMSPSample,
        embeddingsShape: [Int],
        loraApplied: Bool
    ) -> [String] {
        [
            "split: \(split.rawValue)",
            "sample_index: \(sampleIndex)",
            "series_count: \(sample.timeSeries.count)",
            "max_series_length: \(Constants.openTSLMMaxTimeSeriesLength)",
            "embeddings_shape: \(embeddingsShape)",
            "lora_checkpoint_found: \(OpenTSLMLoRA.resolveLoRAURL() != nil)",
            "lora_applied: \(loraApplied ? "yes" : "no")",
            "llm_model: \(Constants.llmModelName)",
            "llm_integration: \(Constants.openTSLMRunSampleLLMGeneration ? "generate" : "encoder+lora-only")",
        ]
    }

    private func ecgQACoTSampleExtraLines(
        metadata: ECGQACoTSampleMetadata,
        embeddingsShape: [Int],
        loraApplied: Bool
    ) -> [String] {
        [
            "source: \(metadata.source)",
            "loader: \(metadata.loader)",
            "split: \(metadata.split)",
            "sample_index: \(metadata.sampleIndex)",
            "ecg_id: \(metadata.ecgId)",
            "template_id: \(metadata.templateId)",
            "question_type: \(metadata.questionType)",
            "series_count: \(metadata.seriesCount)",
            "samples_per_lead: \(metadata.samplesPerLead)",
            "max_series_length: \(Constants.openTSLMMaxTimeSeriesLength)",
            "skip_llm_load: \(Constants.skipLLMLoad ? "yes" : "no")",
            "run_llm: \(Constants.openTSLMRunSampleLLMGeneration ? "yes" : "no")",
            "embeddings_shape: \(embeddingsShape)",
            "lora_checkpoint_found: \(OpenTSLMLoRA.resolveLoRAURL(checkpointName: Constants.openTSLMECGLoRACheckpointName) != nil)",
            "lora_applied: \(loraApplied ? "yes" : "no")",
        ]
    }

    private struct LoadedECGQACoTSample {
        let sample: OpenTSLMSPSample
        let metadata: ECGQACoTSampleMetadata
    }

    private struct ECGQACoTSampleMetadata {
        let source: String
        let loader: String
        let split: String
        let sampleIndex: Int
        let ecgId: String
        let templateId: String
        let questionType: String
        let seriesCount: Int
        let samplesPerLead: Int
    }

    /// Loads one ECG-QA CoT row via ``ECGQACoTDataset`` (CSV metadata + PTB-XL waveform sidecar).
    private func loadECGQACoTSample(
        split: ECGQACoTDataset.Split,
        sampleIndex: Int
    ) throws -> LoadedECGQACoTSample {
        if let csvURL = resolveECGCoTCSVURL(split: split),
           let waveformsDirectory = resolveECGWaveformsDirectoryURL() {
            let dataset = try ECGQACoTDataset(
                csvURL: csvURL,
                waveformsDirectory: waveformsDirectory,
                templateAnswersURL: resolveECGTemplateAnswersURL(),
                split: split,
                maxRows: max(sampleIndex + 1, 1)
            )
            guard dataset.count > 0 else {
                throw NSError(domain: "OpenTSLMInferenceService", code: 15, userInfo: [NSLocalizedDescriptionKey: "ECG-QA CoT CSV has no rows"])
            }

            let safeIndex = min(max(sampleIndex, 0), dataset.count - 1)
            let sample = try dataset.sample(at: safeIndex)
            let row = dataset.rowMetadata(at: safeIndex)

            return LoadedECGQACoTSample(
                sample: sample,
                metadata: ECGQACoTSampleMetadata(
                    source: "ecg_qa_cot",
                    loader: "ECGQACoTDataset",
                    split: row.split.rawValue,
                    sampleIndex: safeIndex,
                    ecgId: String(row.ecgId),
                    templateId: String(row.templateId),
                    questionType: row.questionType,
                    seriesCount: sample.timeSeries.count,
                    samplesPerLead: sample.timeSeries.first?.count ?? 0
                )
            )
        }

        // Legacy fallback: monolithic JSON exported by inference_ecg.py --export-json.
        let legacy = try loadECGQACoTFormattedSample()
        return LoadedECGQACoTSample(
            sample: legacy.sample,
            metadata: ECGQACoTSampleMetadata(
                source: legacy.info.source,
                loader: "formatted_json",
                split: legacy.info.split,
                sampleIndex: legacy.info.sampleIndex,
                ecgId: legacy.info.ecgId,
                templateId: legacy.info.templateId,
                questionType: "unknown",
                seriesCount: legacy.info.seriesCount,
                samplesPerLead: legacy.info.samplesPerLead
            )
        )
    }

    private func resolveECGCoTCSVURL(split: ECGQACoTDataset.Split) -> URL? {
        if !Constants.openTSLMECGCoTCSVPath.isEmpty {
            let expandedPath = NSString(string: Constants.openTSLMECGCoTCSVPath).expandingTildeInPath
            let overrideURL = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: overrideURL.path) {
                return overrideURL
            }
        }

        if split == .test {
            return resolveAssetURL(
                overridePath: "",
                bundledName: Constants.openTSLMECGCoTTestCSVName,
                fileExtension: "csv"
            )
        }

        return resolveAssetURL(
            overridePath: "",
            bundledName: split.csvBaseName,
            fileExtension: "csv"
        )
    }

    private func resolveECGWaveformsDirectoryURL() -> URL? {
        if !Constants.openTSLMECGWaveformsPath.isEmpty {
            let expandedPath = NSString(string: Constants.openTSLMECGWaveformsPath).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: expandedPath, isDirectory: true)
            }
        }

        if let bundledURL = Bundle.main.url(
            forResource: Constants.openTSLMECGWaveformsDirectoryName,
            withExtension: nil,
            subdirectory: Constants.openTSLMBundleSubdirectory
        ) {
            return bundledURL
        }

        return Bundle.main.url(forResource: Constants.openTSLMECGWaveformsDirectoryName, withExtension: nil)
    }

    private func resolveECGTemplateAnswersURL() -> URL? {
        return resolveAssetURL(
            overridePath: "",
            bundledName: Constants.openTSLMECGTemplateAnswersName,
            fileExtension: "json"
        )
    }

    private struct LoadedECGQACoTFormattedSample {
        let sample: OpenTSLMSPSample
        let info: ECGQACoTFormattedSampleInfo
    }

    private struct ECGQACoTFormattedSampleInfo {
        let source: String
        let split: String
        let sampleIndex: Int
        let ecgId: String
        let templateId: String
        let seriesCount: Int
        let samplesPerLead: Int
    }

    /// Legacy formatted JSON export from ``inference_ecg.py --export-json``.
    private func loadECGQACoTFormattedSample() throws -> LoadedECGQACoTFormattedSample {
        guard let url = resolveECGQACoTSampleURL() else {
            throw NSError(
                domain: "OpenTSLMInferenceService",
                code: 9,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Missing ECG-QA CoT sample JSON. Bundle \(Constants.openTSLMECGQACoTSampleName).json "
                        + "or set HEALTHYLLM_OPEN_TSLM_ECG_JSON to the file exported by inference_ecg.py --export-json.",
                ]
            )
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONSerialization.jsonObject(with: data)
        guard let object = decoded as? [String: Any] else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 10, userInfo: [NSLocalizedDescriptionKey: "ECG-QA JSON root must be an object"])
        }

        guard let prePrompt = object["pre_prompt"] as? String,
              let postPrompt = object["post_prompt"] as? String,
              let timeSeriesText = object["time_series_text"] as? [String],
              let label = object["label"] as? String,
              let answer = object["answer"] as? String
        else {
            throw NSError(
                domain: "OpenTSLMInferenceService",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "ECG-QA JSON missing pre_prompt/post_prompt/time_series_text/label/answer"]
            )
        }

        guard let rawSeries = object["time_series"] as? [[Any]], !rawSeries.isEmpty else {
            throw NSError(domain: "OpenTSLMInferenceService", code: 12, userInfo: [NSLocalizedDescriptionKey: "ECG-QA JSON missing time_series"])
        }

        let timeSeries: [[Float]] = try rawSeries.map { lead in
            guard !lead.isEmpty else {
                throw NSError(domain: "OpenTSLMInferenceService", code: 13, userInfo: [NSLocalizedDescriptionKey: "ECG-QA JSON has empty lead"])
            }
            return try lead.map { value in
                if let f = value as? Float { return f }
                if let d = value as? Double { return Float(d) }
                if let i = value as? Int { return Float(i) }
                throw NSError(domain: "OpenTSLMInferenceService", code: 14, userInfo: [NSLocalizedDescriptionKey: "Invalid time_series value"])
            }
        }

        let samplesPerLead = timeSeries.first?.count ?? 0
        let info = ECGQACoTFormattedSampleInfo(
            source: object["source"] as? String ?? "ecg_qa_cot",
            split: object["split"] as? String ?? "unknown",
            sampleIndex: object["sample_idx"] as? Int ?? -1,
            ecgId: String(describing: object["ecg_id"] ?? "unknown"),
            templateId: String(describing: object["template_id"] ?? "unknown"),
            seriesCount: timeSeries.count,
            samplesPerLead: samplesPerLead
        )

        let sample = OpenTSLMSPSample(
            prePrompt: prePrompt,
            timeSeriesText: timeSeriesText,
            timeSeries: timeSeries,
            postPrompt: postPrompt,
            label: label,
            answer: answer
        )
        return LoadedECGQACoTFormattedSample(sample: sample, info: info)
    }

    private func resolveECGQACoTSampleURL() -> URL? {
        if let override = resolveECGJSONURL() {
            return override
        }

        return resolveAssetURL(
            overridePath: "",
            bundledName: Constants.openTSLMECGQACoTSampleName,
            fileExtension: "json"
        )
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
        let expandedPath = NSString(string: overridePath).expandingTildeInPath
        let overrideURL = URL(fileURLWithPath: expandedPath)
        guard fileManager.fileExists(atPath: overrideURL.path) else {
            return nil
        }

        return overrideURL
    }

    // PTB-XL / ECG-QA standard 12-lead order — must match what the encoder was
    // trained to receive in the per-lead text labels.
    private static let ecgLeadNames = ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]

    private static let ecgTargetSamplingRate: Double = 100  // Hz — matches ECG-QA training (`[::5]` from 500 Hz)
    /// Window length per lead. Capped to the global series-length budget so we don't
    /// generate samples we'd only truncate; ECG-QA training was on 10 s windows but
    /// 12 × 1000 over-runs the iOS 6 GB process limit at prefill time.
    private static var ecgSamplesPerLead: Int { Constants.openTSLMMaxTimeSeriesLength }

    private func makeOpenTSLMSample(from ecg: ECGSample) -> OpenTSLMSPSample {
        // Downsample to 100 Hz and window to 1000 samples (10 s) to match ECG-QA training.
        let downsampled = Self.downsampleAndWindow(
            ecg.voltages,
            inputRate: ecg.samplingFrequency,
            outputRate: Self.ecgTargetSamplingRate,
            count: Self.ecgSamplesPerLead
        )
        let stats = Self.statistics(of: downsampled)
        let normalizedLead = downsampled.map { Float(($0 - stats.mean) / stats.std) }

        // Apple Watch is hardware-single-lead — replicate Lead I across all 12 channels
        // so the encoder receives the 12-series shape it was trained on. The per-lead
        // mean/std in each label are therefore identical, by construction; that's an
        // acknowledged distribution shift vs. real PTB-XL multi-lead recordings.
        var timeSeries: [[Float]] = []
        timeSeries.reserveCapacity(Self.ecgLeadNames.count)
        var timeSeriesText: [String] = []
        timeSeriesText.reserveCapacity(Self.ecgLeadNames.count)
        for name in Self.ecgLeadNames {
            timeSeries.append(normalizedLead)
            timeSeriesText.append("This is ECG Lead \(name), it has mean \(String(format: "%.4f", stats.mean)) and std \(String(format: "%.4f", stats.std)):")
        }

        return OpenTSLMSPSample(
            prePrompt: Self.ecgPrePrompt(
                clinicalContext: ecg.clinicalContext,
                question: ecg.question
            ),
            timeSeriesText: timeSeriesText,
            timeSeries: timeSeries,
            postPrompt: Self.ecgPostPrompt(possibleAnswers: ecg.possibleAnswers),
            label: ecg.classification ?? "unknown",
            answer: ecg.summary
        )
    }

    /// Verbatim from OpenTSLM `src/time_series_datasets/ecg_qa/ECGQACoTQADataset.py:_get_pre_prompt`,
    /// with the runtime-supplied `clinical_context` and `question` substituted.
    private static func ecgPrePrompt(clinicalContext: String, question: String) -> String {
        """
        You are an expert cardiologist analyzing an ECG (electrocardiogram).

        Clinical Context: \(clinicalContext)

        Your task is to examine the ECG signal and answer the following medical question:

        Question: \(question)

        Instructions:
        - Begin by analyzing the time series without assuming a specific answer.
        - Think step-by-step about what the observed patterns suggest regarding the cardiac condition.
        - Write your rationale as a single, natural paragraph — do not use bullet points, numbered steps, or section headings.
        - Do **not** mention any final answer until the very end.
        - Consider the ECG morphology, intervals, and any abnormalities that relate to the question.
        """
    }

    /// Verbatim from `ECGQACoTQADataset.py:_get_post_prompt`. Two branches:
    ///   - if `possibleAnswers` is non-empty → the templated branch, which lists the closed
    ///     answer set the model was trained to pick from.
    ///   - otherwise → the open-ended branch.
    /// Both end with literal `"Answer: ` (open quote + trailing space, no closing quote) —
    /// the model continues from there with its rationale and concludes `Answer: <label>`.
    private static func ecgPostPrompt(possibleAnswers: [String]) -> String {
        if !possibleAnswers.isEmpty {
            let answersText = possibleAnswers.joined(separator: ", ")
            return "Based on your analysis of the ECG data, select your answer from the following options:\n"
                + answersText + "\n"
                + "\n"
                + "- Make sure that your last word is the answer. You MUST end your response with \"Answer: "
        }
        return "Based on your analysis of the ECG data, provide your answer.\n"
            + "Make sure that your last word is the answer. You MUST end your response with \"Answer: "
    }

    /// Nearest-neighbor resampling to `count` samples at `outputRate`, starting at t=0.
    /// Pads with zeros if the source is shorter than the requested window.
    private static func downsampleAndWindow(
        _ voltages: [Double],
        inputRate: Double,
        outputRate: Double,
        count: Int
    ) -> [Double] {
        guard !voltages.isEmpty, inputRate > 0, outputRate > 0, count > 0 else {
            return Array(repeating: 0, count: max(count, 0))
        }
        let step = inputRate / outputRate
        var out: [Double] = []
        out.reserveCapacity(count)
        for i in 0 ..< count {
            let srcIdx = Int(Double(i) * step)
            out.append(srcIdx < voltages.count ? voltages[srcIdx] : 0)
        }
        return out
    }

    private static func statistics(of values: [Double]) -> (mean: Double, std: Double) {
        guard !values.isEmpty else { return (0, 1) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let d = value - mean
            return partial + d * d
        } / Double(values.count)
        return (mean, max(sqrt(variance), 1e-6))
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

private enum ECGSampleSource: String {
    case hardcoded
    case healthkit
    case healthkitJSON = "healthkit_json"
    case jsonOverride = "json_override"
}

private struct ECGSample {
    let source: ECGSampleSource
    let samplingFrequency: Double
    let classification: String?
    let symptomsStatus: String?
    let averageHeartRate: Double?
    let voltages: [Double]
    // ECG-QA-style framing for the model's pre/post prompts. Defaulted so existing
    // call sites that don't supply per-sample fields still compile.
    // The default mirrors the most common ECG-QA *closed-set* template (yes/no
    // about a single condition) — ECG-QA was trained heavily on these and greedy
    // decoding picks from the list much more reliably than from an open question.
    var clinicalContext: String = "Single-lead ambulatory ECG recording (Lead I equivalent, replicated across the standard 12 leads)."
    var question: String = "Is the cardiac rhythm shown in this ECG consistent with atrial fibrillation?"
    var possibleAnswers: [String] = ["yes", "no"]

    var sourceDescription: String {
        source.rawValue
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
            source: .hardcoded,
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
              let voltages = object["voltages"] as? [Double],
              !voltages.isEmpty
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

        let source: ECGSampleSource
        if object["source"] as? String == ECGSampleSource.healthkitJSON.rawValue {
            source = .healthkitJSON
        } else {
            source = .jsonOverride
        }

        return ECGSample(
            source: source,
            samplingFrequency: samplingFrequency,
            classification: classification,
            symptomsStatus: symptomsStatus,
            averageHeartRate: averageHeartRate,
            voltages: voltages
        )
    }
}

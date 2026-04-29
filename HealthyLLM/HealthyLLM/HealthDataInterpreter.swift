//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import Hub
import OSLog
import Spezi
import SpeziChat
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziLLM
import SpeziLLMLocal

@Observable
class HealthDataInterpreter: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLM", category: "HealthDataInterpreter")
    
    private(set) var loaded = false
    
    @ObservationIgnored @Dependency(LLMRunner.self) private var llmRunner: LLMRunner
    @ObservationIgnored @Dependency(HealthDataFetcher.self) private var healthDataFetcher: HealthDataFetcher
    @ObservationIgnored @Dependency(HealthContextGenerator.self) private var healthContextGenerator: HealthContextGenerator
    @ObservationIgnored @Dependency(OpenTSLMInferenceService.self) private var openTSLMInferenceService: OpenTSLMInferenceService
    
    @ObservationIgnored private var functionCallParameters: LLMLocalParameters?
    @ObservationIgnored private var functionCallSamplingParameters: LLMLocalSamplingParameters?
    @ObservationIgnored private var defaultParameters: LLMLocalParameters?
    @ObservationIgnored private var sharedSession: LLMLocalSession?
    @ObservationIgnored private let requiredModelFiles = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "special_tokens_map.json",
        "model.safetensors"
    ]
    
    private(set) var context: HealthyLLMContext = []
    private(set) var advancedContext: HealthyLLMContext = []
    
    required init() { }
    
    func setup() async throws {
        try await stageLocalModelIfNeeded()

        functionCallParameters = .init(
            maxOutputLength: 32,
            chatTemplate: Constants.llmModelChatTemplate
        )
        functionCallSamplingParameters = .init(
            topP: 1.0,
            temperature: 0.001,
            penaltyRepeat: 1.3
        )
        
        defaultParameters = .init(
            maxOutputLength: 1024,
            chatTemplate: Constants.llmModelChatTemplate
        )
        guard let defaultParameters else {
            return
        }
        
        let schema = LLMLocalSchema(
            model: .custom(id: Constants.llmModelName),
            parameters: defaultParameters,
            injectIntoContext: true
        )
        
        sharedSession = llmRunner.callAsFunction(with: schema)
        guard let sharedSession else {
            return
        }

        try await sharedSession.setup()
        loaded = true
    }

    private func stageLocalModelIfNeeded() async throws {
        let fileManager = FileManager.default
        let destinationURL = Constants.llmLocalModelDirectory

        do {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed creating local model destination directory: \(error.localizedDescription)")
            return
        }

        if hasRequiredModelFiles(in: destinationURL, fileManager: fileManager) {
            logger.info("Local model cache already has required files at destination: \(destinationURL.path)")
            return
        }

        guard let sourceURL = resolveLocalModelSourceDirectory() else {
            logger.warning("No local model source directory found. Falling back to download flow.")
            return
        }

        do {
            try copyDirectoryContents(from: sourceURL, to: destinationURL)
            try stageLoRACheckpointIfAvailable(sourceURL: sourceURL, destinationURL: destinationURL)

            if hasRequiredModelFiles(in: destinationURL, fileManager: fileManager) {
                logger.info("Staged local model from \(sourceURL.path) to \(destinationURL.path)")
            } else {
                logger.error("Model staging finished but required files are still missing in \(destinationURL.path)")
            }
        } catch {
            logger.error("Failed to stage local model: \(error.localizedDescription)")
            throw error
        }
    }

    private func stageLoRACheckpointIfAvailable(sourceURL: URL, destinationURL: URL) throws {
        let fileManager = FileManager.default
        var checkpointCandidates: [URL] = []

        if !Constants.openTSLMLoRACheckpointPath.isEmpty {
            checkpointCandidates.append(URL(fileURLWithPath: Constants.openTSLMLoRACheckpointPath))
        }

        checkpointCandidates.append(sourceURL.appendingPathComponent("\(Constants.openTSLMLoRACheckpointName).safetensors"))
        checkpointCandidates.append(sourceURL.appendingPathComponent("adapter_model.safetensors"))

        let existingCandidates = checkpointCandidates.filter { candidate in
            fileManager.fileExists(atPath: candidate.path)
        }

        if let selectedLoRA = existingCandidates.first {
            let destinationLoRA = destinationURL.appendingPathComponent(selectedLoRA.lastPathComponent)
            if !fileManager.fileExists(atPath: destinationLoRA.path) {
                try fileManager.copyItem(at: selectedLoRA, to: destinationLoRA)
            }
            logger.info("LoRA checkpoint staged at \(destinationLoRA.path)")
            return
        }

        if Constants.requireLoRACheckpoint {
            throw NSError(
                domain: "HealthDataInterpreter",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "HEALTHYLLM_REQUIRE_LORA=1 but no LoRA checkpoint was found. Set HEALTHYLLM_OPEN_TSLM_LORA_CHECKPOINT or include \(Constants.openTSLMLoRACheckpointName).safetensors in LocalLLM."]
            )
        }
    }

    private func hasRequiredModelFiles(in directoryURL: URL, fileManager: FileManager) -> Bool {
        requiredModelFiles.allSatisfy { fileName in
            fileManager.fileExists(atPath: directoryURL.appendingPathComponent(fileName).path)
        }
    }

    private func resolveLocalModelSourceDirectory() -> URL? {
        let fileManager = FileManager.default

        if let overridePath = Constants.localModelSourcePathOverride,
           let overrideURL = existingDirectoryURL(at: overridePath, fileManager: fileManager) {
            return overrideURL
        }

        if let bundledLocalModelURL = Bundle.main.resourceURL {
            let bundledDirectory = bundledLocalModelURL.appendingPathComponent(Constants.localModelBundleSubdirectory, isDirectory: true)
            if fileManager.fileExists(atPath: bundledDirectory.path) {
                return bundledDirectory
            }

            let bundledRootFiles = requiredModelFiles.allSatisfy { fileName in
                fileManager.fileExists(atPath: bundledLocalModelURL.appendingPathComponent(fileName).path)
            }

            if bundledRootFiles {
                return bundledLocalModelURL
            }
        }

        // Fallback: detect a downloaded model snapshot from Hugging Face cache.
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

    private func copyDirectoryContents(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)

        for item in items {
            let destinationItem = destinationURL.appendingPathComponent(item.lastPathComponent)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)

            guard exists else {
                continue
            }

            if isDirectory.boolValue {
                try fileManager.createDirectory(at: destinationItem, withIntermediateDirectories: true)
                try copyDirectoryContents(from: item, to: destinationItem)
            } else if !fileManager.fileExists(atPath: destinationItem.path) {
                try fileManager.copyItem(at: item, to: destinationItem)
            }
        }
    }

    private func ecgSamplesForPrompt(_ healthKit: HealthKit) async -> [ElectrocardiogramData] {
        let fetched = (try? await healthDataFetcher.fetchElectrocardiograms(healthKit, limit: 1)) ?? []

        if Constants.includeHardcodedECGSample {
            var merged = fetched
            merged.insert(hardcodedECGSample(), at: 0)
            return merged
        }

        if fetched.isEmpty {
            return [hardcodedECGSample()]
        }

        return fetched
    }

    private func hardcodedECGSample() -> ElectrocardiogramData {
        let samplingFrequency = 256.0
        let sampleCount = Constants.hardcodedECGSampleLength
        let durationSeconds = Double(sampleCount) / samplingFrequency
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-durationSeconds)

        let voltages: [Double] = (0 ..< sampleCount).map { index in
            let t = Double(index) / samplingFrequency

            // Synthetic ECG-like waveform with deterministic QRS spikes.
            let base = 0.025 * sin(2.0 * .pi * 1.2 * t)
            let pWave = 0.010 * sin(2.0 * .pi * 4.0 * t)
            let qrsPhase = t.remainder(dividingBy: 0.86)
            let qrs = qrsPhase < 0.018 ? 0.72 * exp(-pow((qrsPhase - 0.006) * 120.0, 2.0)) : 0.0
            let tWave = 0.040 * exp(-pow((qrsPhase - 0.24) * 14.0, 2.0))
            return base + pWave + qrs + tWave
        }

        return .init(
            startDate: startDate,
            endDate: endDate,
            classification: "sinusRhythm_sample",
            symptomsStatus: "notSet_sample",
            averageHeartRate: 70.0,
            samplingFrequency: samplingFrequency,
            numberOfVoltageMeasurements: voltages.count,
            voltages: voltages
        )
    }
    
    func queryLLM(with context: Chat, healthKit: HealthKit) async throws {
        if !loaded {
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        logger.info("Querying LLM with: \(context)")
        guard let userPrompt = context.last,
              userPrompt.role == .user,
              !userPrompt.content.isEmpty else {
            return
        }
        
        self.context.append(.init(.user, content: userPrompt.content))
        self.advancedContext.append(.init(.user, content: userPrompt.content))

        if shouldRunOpenTSLMSampleInference(for: userPrompt.content) {
            do {
                let inferenceResult = try await openTSLMInferenceService.runSleepSampleInference(
                    llmRunner: llmRunner,
                    llmSession: sharedSession
                )
                let reply = """
                I ran the OpenTSLM sample inference directly in the iOS app using your local checkpoints and sleep_cot sample data.

                \(inferenceResult)
                """
                self.context.append(.init(.assistant, content: reply, completed: true))
                self.advancedContext.append(.init(.assistant, content: reply, completed: true))
            } catch {
                let failure = "OpenTSLM sample inference failed in-app: \(error.localizedDescription)"
                self.context.append(.init(.assistant, content: failure, completed: true))
                self.advancedContext.append(.init(.assistant, content: failure, completed: true))
            }
            return
        }

        if shouldRunOpenTSLMECGSampleInference(for: userPrompt.content) {
            do {
                let inferenceResult = try await openTSLMInferenceService.runECGSampleInference(
                    llmRunner: llmRunner,
                    llmSession: sharedSession
                )
                let reply = """
                I ran the OpenTSLM ECG sample path directly in the iOS app using the hardcoded ECG fallback or a JSON sample if configured.

                \(inferenceResult)
                """
                self.context.append(.init(.assistant, content: reply, completed: true))
                self.advancedContext.append(.init(.assistant, content: reply, completed: true))
            } catch {
                let failure = "OpenTSLM ECG sample inference failed in-app: \(error.localizedDescription)"
                self.context.append(.init(.assistant, content: failure, completed: true))
                self.advancedContext.append(.init(.assistant, content: failure, completed: true))
            }
            return
        }
        
        try await checkForFunctionCall(prompt: userPrompt.content, healthKit: healthKit)
        try await defaultResponse(healthKit)
    }

    private func shouldRunOpenTSLMSampleInference(for prompt: String) -> Bool {
        let normalized = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Keep this behind an explicit command so ECG/health prompts are not hijacked
        // by the sample Sleep-EDF demo path.
        return normalized == "/opentslm-sleep-sample"
    }

    private func shouldRunOpenTSLMECGSampleInference(for prompt: String) -> Bool {
        let normalized = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalized == "/opentslm-ecg-sample"
    }
    
    func resetChat() async {
        context = []
        advancedContext = []
    }
    
    private func checkForFunctionCall(prompt: String, healthKit: HealthKit) async throws {
        guard let functionCallParameters = functionCallParameters,
              let functionCallSamplingParameters = functionCallSamplingParameters,
              let sharedSession else {
            logger.error("checkForFunctionCall: Not initialized throwing")
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        logger.info("Start check for function call with: \(prompt)")
        
        sharedSession.update(
            parameters: functionCallParameters,
            samplingParameters: functionCallSamplingParameters,
            injectIntoContext: false
        )
        
        let context: HealthyLLMContext = [
            PromptGenerator.buildSystemPrompt(for: .functionCall),
            .init(.user, content: prompt)
        ]
        advancedContext.append(contentsOf: context)
        
        let functionCallLLMOutput = try await llmRunner.oneShot(
            on: sharedSession,
            customContext: context.map(\.asDictionary)
        )
        
        logger.debug("Function Call LLM Finished with: \(functionCallLLMOutput)")
        
        if functionCallLLMOutput.contains("tool_call") || functionCallLLMOutput.contains("name") && functionCallLLMOutput.contains("arguments") {
            logger.info("Found function call")
            await executeFunctionCall(output: functionCallLLMOutput, healthKit: healthKit)
        } else {
            advancedContext.append(.init(.assistant, content: functionCallLLMOutput))
        }
    }
    
    
    private func defaultResponse(_ healthKit: HealthKit) async throws {
        guard let sharedSession else {
            logger.error("defaultResponse: Not initialized throwing")
            throw HealthDataInterpreterError.modelNotLoaded
        }
        
        sharedSession.update(
            parameters: defaultParameters,
            injectIntoContext: true
        )
        
        if !context.contains(where: { $0.role == .system }) {
            let userInfo = await healthDataFetcher.fetchUser(healthKit)
            let electrocardiograms = await ecgSamplesForPrompt(healthKit)
            let systemPrompt = healthContextGenerator.buildSystemPrompt(
                userInfo: userInfo,
                electrocardiograms: electrocardiograms
            )
            context.append(systemPrompt)
            advancedContext.append(systemPrompt)
        }
            
        await MainActor.run {
            sharedSession.customContext = context.map(\.asDictionary)
        }
        
        logger.debug("defaultResponse: Started with context")

        var assistantOutput = ""
        for try await stringPiece in try await sharedSession.generate() {
            logger.debug("defaultResponse: Received string piece: \(stringPiece)")
            assistantOutput += stringPiece
        }

        let assistantMessage = HealthyLLMContextEntity(.assistant, content: assistantOutput, completed: true)
        context.append(assistantMessage)
        advancedContext.append(assistantMessage)
    }
    
    /// Returns a bool representing if a function call has been made
    @discardableResult
    private func executeFunctionCall(output: String, healthKit: HealthKit) async -> Bool {
        struct ToolCall: Codable {
            let name: String
            let arguments: [String: String]
        }
        
        let functionCallString = output
            .replacingOccurrences(of: "<tool_call>", with: "")
            .replacingOccurrences(of: "</tool_call>", with: "")
        
        guard let functionCallData = functionCallString.data(using: .utf8),
              let toolCall = try? JSONDecoder().decode(ToolCall.self, from: functionCallData) else {
            return false
        }
        
        switch toolCall.name {
        case "get_health_info":
            guard let sampleType = toolCall.arguments["sample_type"] else {
                return false
            }
            print(sampleType)
            context.append(.init(.toolCall, content: output))
            advancedContext.append(.init(.toolCall, content: output))

            if let healthData = try? await healthDataFetcher.fetchHealth(healthKit, type: sampleType) {
                context.append(PromptGenerator.buildToolResponse(of: healthData))
                advancedContext.append(PromptGenerator.buildToolResponse(of: healthData))
                return true
            }

            return false
        case "get_workout_info":
            guard let workoutType = toolCall.arguments["workout_type"] else {
                return false
            }
            context.append(.init(.toolCall, content: output))
            advancedContext.append(.init(.toolCall, content: output))
            let workoutData = await healthDataFetcher.fetchWorkout(healthKit, type: workoutType)

            if workoutData.count > Constants.workoutLimitJsonRepresentation {
                let csvString = HealthDataFetcher.workoutDataToCSV(workoutData)
                context.append(PromptGenerator.buildToolResponse(of: csvString))
                advancedContext.append(PromptGenerator.buildToolResponse(of: csvString))
                return true
            }
            
            context.append(PromptGenerator.buildToolResponse(of: workoutData))
            advancedContext.append(PromptGenerator.buildToolResponse(of: workoutData))
            return true
        default:
            return false
        }
    }
}

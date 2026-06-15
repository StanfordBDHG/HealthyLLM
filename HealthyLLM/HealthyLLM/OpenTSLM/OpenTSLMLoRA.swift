//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN
import OSLog
import SpeziLLMLocal

/// Loads OpenTSLM LoRA adapters into an ``EmbeddingLlamaModel`` (MLX ``LoRALinear``).
///
/// Mirrors [OpenTSLMMLX](https://github.com/StanfordBDHG/OpenTSLMMLX) ``_apply_lora``:
/// ``linear_to_lora_layers`` on all transformer projections, rank 16, alpha 32 (scale 2), PEFT transpose.
enum OpenTSLMLoRA {

    private static let logger = Logger(subsystem: "HealthyLLM", category: "OpenTSLMLoRA")

    /// Tracks which checkpoint URL is currently loaded into each model instance.
    /// Allows task switching (ECG ↔ sleep) by re-loading adapter weights without
    /// repeating the one-time Linear→LoRALinear layer conversion.
    private static var appliedModelCheckpoints: [ObjectIdentifier: URL] = [:]
    private static let loraRank = 16
    private static let loraScale: Float = 32.0 / 16.0
    private static let adapterProjectionKeys: Set<String> = [
        "q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj",
    ]

    static func resolveLoRAURL(checkpointName: String = Constants.openTSLMLoRACheckpointName) -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        // The env-var override always wins (regardless of task) — that's the explicit
        // "use this exact LoRA file" escape hatch.
        if !Constants.openTSLMLoRACheckpointPath.isEmpty {
            let expanded = NSString(string: Constants.openTSLMLoRACheckpointPath).expandingTildeInPath
            candidates.append(URL(fileURLWithPath: expanded))
        }

        let stagedOpenTSLM = Constants.openTSLMDocumentsDirectory
        candidates.append(stagedOpenTSLM.appendingPathComponent("\(checkpointName).safetensors"))
        candidates.append(stagedOpenTSLM.appendingPathComponent("adapter_model.safetensors"))

        if let bundled = Bundle.main.url(
            forResource: checkpointName,
            withExtension: "safetensors",
            subdirectory: Constants.openTSLMBundleSubdirectory
        ) {
            candidates.append(bundled)
        }

        // Filesystem-synchronized groups in Xcode 16 install supporting-file
        // resources at the bundle root, not under the source-tree subdirectory.
        // Fall back to a root lookup so the bundled LoRA is actually found.
        if let bundledRoot = Bundle.main.url(
            forResource: checkpointName,
            withExtension: "safetensors"
        ) {
            candidates.append(bundledRoot)
        }
        if let bundledAdapter = Bundle.main.url(
            forResource: "adapter_model",
            withExtension: "safetensors"
        ) {
            candidates.append(bundledAdapter)
        }

        if let bundleRoot = Bundle.main.resourceURL {
            let bundledOpenTSLM = bundleRoot.appendingPathComponent(Constants.openTSLMBundleSubdirectory, isDirectory: true)
            candidates.append(bundledOpenTSLM.appendingPathComponent("\(checkpointName).safetensors"))
            candidates.append(bundledOpenTSLM.appendingPathComponent("adapter_model.safetensors"))
        }

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }

    /// Applies LoRA once per in-memory ``EmbeddingLlamaModel`` instance.
    static func applyLoRAIfNeeded(to model: Module, checkpointURL: URL) throws {
        guard let llama = model as? EmbeddingLlamaModel else {
            return
        }
        try applyIfNeeded(to: llama, checkpointURL: checkpointURL)
    }

    /// Apply LoRA on the Spezi session's loaded ``EmbeddingLlamaModel`` (call from OpenTSLM paths only to save RAM at launch).
    ///
    /// `checkpointName` selects which task's LoRA to load — sleep by default. Mixing tasks in
    /// a single session is not supported: the first task to call this method "wins" for the
    /// lifetime of the model instance (we track per-instance application to avoid double
    /// conversion of `Linear`→`LoRALinear`). Tear down and recreate the session to switch.
    static func applyIfNeeded(
        on session: LLMLocalSession,
        checkpointName: String = Constants.openTSLMLoRACheckpointName
    ) async throws {
        guard let container = await MainActor.run(body: { session.modelContainer }) else {
            throw NSError(
                domain: "OpenTSLMLoRA",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "LLM session is not ready"]
            )
        }

        guard let checkpointURL = resolveLoRAURL(checkpointName: checkpointName) else {
            logger.warning("OpenTSLM LoRA checkpoint '\(checkpointName, privacy: .public)' not found — running base Llama (set HEALTHYLLM_OPEN_TSLM_LORA_CHECKPOINT or bundle \(checkpointName).safetensors).")
            if Constants.requireLoRACheckpoint {
                throw NSError(
                    domain: "OpenTSLMLoRA",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "OpenTSLM LoRA checkpoint '\(checkpointName)' not found"]
                )
            }
            return
        }

        try await container.perform { context in
            guard let llama = context.model as? EmbeddingLlamaModel else {
                return
            }
            try applyIfNeeded(to: llama, checkpointURL: checkpointURL)
        }
    }

    static func applyIfNeeded(to llama: EmbeddingLlamaModel, checkpointURL: URL) throws {
        let modelID = ObjectIdentifier(llama)

        if appliedModelCheckpoints[modelID] == checkpointURL {
            return
        }

        if appliedModelCheckpoints[modelID] == nil {
            convertOpenTSLMLoRALayers(on: llama)
        }

        let rawWeights = try loadArrays(url: checkpointURL)
        let sanitized = sanitizeCheckpointKeys(rawWeights)

        let trainableKeys = Set(llama.trainableParameters().flattened().map(\.0))
        let filtered = sanitized.filter { trainableKeys.contains($0.key) }
        let parameters = ModuleParameters.unflattened(filtered)
        try llama.update(parameters: parameters, verify: .noUnusedKeys)
        eval(llama)

        appliedModelCheckpoints[modelID] = checkpointURL

        logger.info("OpenTSLM LoRA applied from \(checkpointURL.lastPathComponent, privacy: .public)")
    }

    /// Convert every attention/MLP linear in all transformer layers (matches ``linear_to_lora_layers`` in OpenTSLMMLX).
    private static func convertOpenTSLMLoRALayers(on llama: EmbeddingLlamaModel) {
        llama.freeze()
        let layers = openTSMLLoRALinearLayers(on: llama)
        for (layer, keys) in layers {
            var update = ModuleChildren()
            let children = layer.children()
            for key in keys {
                guard let item = children[key], case .value(let child) = item, let linear = child as? Linear else {
                    continue
                }
                let (outputDimensions, inputDimensions) = linear.shape
                update[key] = .value(
                    LoRALinear(
                        inputDimensions,
                        outputDimensions,
                        rank: loraRank,
                        scale: loraScale,
                        linear: linear
                    )
                )
            }
            if !update.isEmpty {
                layer.update(modules: update)
            }
        }
    }

    private static func openTSMLLoRALinearLayers(on llama: EmbeddingLlamaModel) -> LoRALinearLayers {
        var groups: [String: [String]] = [:]
        for (path, module) in llama.namedModules() {
            guard module is Linear, !path.contains("lora_") else {
                continue
            }
            guard path.hasPrefix("model.layers."),
                  let suffix = path.split(separator: ".").last.map(String.init),
                  adapterProjectionKeys.contains(suffix)
            else {
                continue
            }
            let parentPath = path.split(separator: ".").dropLast().joined(separator: ".")
            groups[parentPath, default: []].append(suffix)
        }

        let named = Dictionary(uniqueKeysWithValues: llama.namedModules())
        return groups.keys.sorted().compactMap { parentPath in
            guard let parent = named[parentPath], let keys = groups[parentPath] else {
                return nil
            }
            return (parent, keys.sorted())
        }
    }

    /// Remap PEFT keys to MLX ``LoRALinear`` names (with transpose). MLX-native keys pass through unchanged.
    static func sanitizeCheckpointKeys(_ weights: [String: MLXArray]) -> [String: MLXArray] {
        var result: [String: MLXArray] = [:]

        for (key, value) in weights {
            if let mapped = mapPEFTKey(key, value: value) {
                result[mapped.key] = mapped.value
            } else if key.contains("lora_a") || key.contains("lora_b") {
                result[key] = value
            }
        }

        return result
    }

    private static func mapPEFTKey(_ key: String, value: MLXArray) -> (key: String, value: MLXArray)? {
        let pattern = #"^base_model\.model\.(.+)\.(lora_[AB])\.default\.weight$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)),
              match.numberOfRanges == 3,
              let layerRange = Range(match.range(at: 1), in: key),
              let abRange = Range(match.range(at: 2), in: key)
        else {
            return nil
        }

        let layerPath = String(key[layerRange])
        let ab = String(key[abRange]).lowercased()
        let mlxKey = layerPath.hasPrefix("model.") ? "\(layerPath).\(ab)" : "model.\(layerPath).\(ab)"
        return (mlxKey, value.transposed())
    }
}

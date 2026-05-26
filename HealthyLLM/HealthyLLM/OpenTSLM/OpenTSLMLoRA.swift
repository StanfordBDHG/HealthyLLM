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

/// Loads OpenTSLM LoRA adapters into a ``LlamaModel`` (MLX ``LoRALinear``).
///
/// Mirrors [OpenTSLMMLX](https://github.com/StanfordBDHG/OpenTSLMMLX) ``_apply_lora``:
/// ``linear_to_lora_layers`` on all transformer projections, rank 16, alpha 32 (scale 2), PEFT transpose.
enum OpenTSLMLoRA {

    private static let logger = Logger(subsystem: "HealthyLLM", category: "OpenTSLMLoRA")

    private static var appliedModelIDs = Set<ObjectIdentifier>()
    private static let loraRank = 16
    private static let loraScale: Float = 32.0 / 16.0
    private static let adapterProjectionKeys: Set<String> = [
        "q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj",
    ]

    static func resolveLoRAURL() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if !Constants.openTSLMLoRACheckpointPath.isEmpty {
            let expanded = NSString(string: Constants.openTSLMLoRACheckpointPath).expandingTildeInPath
            candidates.append(URL(fileURLWithPath: expanded))
        }

        let stagedOpenTSLM = Constants.openTSLMDocumentsDirectory
        candidates.append(stagedOpenTSLM.appendingPathComponent("\(Constants.openTSLMLoRACheckpointName).safetensors"))
        candidates.append(stagedOpenTSLM.appendingPathComponent("adapter_model.safetensors"))

        if let bundled = Bundle.main.url(
            forResource: Constants.openTSLMLoRACheckpointName,
            withExtension: "safetensors",
            subdirectory: Constants.openTSLMBundleSubdirectory
        ) {
            candidates.append(bundled)
        }

        if let bundleRoot = Bundle.main.resourceURL {
            let bundledOpenTSLM = bundleRoot.appendingPathComponent(Constants.openTSLMBundleSubdirectory, isDirectory: true)
            candidates.append(bundledOpenTSLM.appendingPathComponent("\(Constants.openTSLMLoRACheckpointName).safetensors"))
            candidates.append(bundledOpenTSLM.appendingPathComponent("adapter_model.safetensors"))
        }

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }

    /// Applies LoRA once per in-memory ``LlamaModel`` instance.
    static func applyLoRAIfNeeded(to model: Module, checkpointURL: URL) throws {
        guard let llama = model as? LlamaModel else {
            return
        }
        try applyIfNeeded(to: llama, checkpointURL: checkpointURL)
    }

    /// Apply LoRA on the Spezi session's loaded ``LlamaModel`` (call from OpenTSLM paths only to save RAM at launch).
    static func applyIfNeeded(on session: LLMLocalSession) async throws {
        guard let container = await MainActor.run(body: { session.modelContainer }) else {
            throw NSError(
                domain: "OpenTSLMLoRA",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "LLM session is not ready"]
            )
        }

        guard let checkpointURL = resolveLoRAURL() else {
            if Constants.requireLoRACheckpoint {
                throw NSError(
                    domain: "OpenTSLMLoRA",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "OpenTSLM LoRA checkpoint not found"]
                )
            }
            return
        }

        try await container.perform { context in
            guard let llama = context.model as? LlamaModel else {
                return
            }
            try applyIfNeeded(to: llama, checkpointURL: checkpointURL)
        }
    }

    static func applyIfNeeded(to llama: LlamaModel, checkpointURL: URL) throws {
        let modelID = ObjectIdentifier(llama)
        if appliedModelIDs.contains(modelID) {
            return
        }

        convertOpenTSLMLoRALayers(on: llama)

        let rawWeights = try loadArrays(url: checkpointURL)
        let sanitized = sanitizeCheckpointKeys(rawWeights)

        let trainableKeys = Set(llama.trainableParameters().flattened().map(\.0))
        let filtered = sanitized.filter { trainableKeys.contains($0.key) }
        let parameters = ModuleParameters.unflattened(filtered)
        try llama.update(parameters: parameters, verify: .noUnusedKeys)
        eval(llama)

        appliedModelIDs.insert(modelID)

        logger.info("OpenTSLM LoRA applied from \(checkpointURL.lastPathComponent, privacy: .public)")
    }

    /// Convert every attention/MLP linear in all transformer layers (matches ``linear_to_lora_layers`` in OpenTSLMMLX).
    private static func convertOpenTSLMLoRALayers(on llama: LlamaModel) {
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

    private static func openTSMLLoRALinearLayers(on llama: LlamaModel) -> LoRALinearLayers {
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

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

enum Constants {
    // You can override this at runtime for debugging by setting the env var
    // HEALTHYLLM_MODEL_ID in the scheme.
    private static let defaultLLMModelName = "meta-llama/Llama-3.2-1B"
    static let llmModelName = ProcessInfo.processInfo.environment["HEALTHYLLM_MODEL_ID"] ?? defaultLLMModelName

    // Local model directory copied into Spezi/Hub cache before LLM setup.
    // Override with HEALTHYLLM_LOCAL_MODEL_PATH in the scheme if needed.
    static let localModelSourcePathOverride = ProcessInfo.processInfo.environment["HEALTHYLLM_LOCAL_MODEL_PATH"]
    static let localModelBundleSubdirectory = "LocalLLM"
    static let hostHuggingFaceCacheRoot = ProcessInfo.processInfo.environment["HEALTHYLLM_HOST_HF_CACHE_ROOT"]
        ?? "~/.cache/huggingface/hub"
    // Where SpeziLLMLocal / HubApi actually reads and writes the model:
    // <Documents>/huggingface/models/<modelID>  (matches HubApi.shared.localRepoLocation)
    static let llmLocalModelDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
        return documents
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(llmModelName, isDirectory: true)
    }()

    /// OpenTSLM assets (LoRA, etc.) — never mix into the HF Llama model directory.
    static let openTSLMDocumentsDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
        return documents.appendingPathComponent(openTSLMBundleSubdirectory, isDirectory: true)
    }()

    static let includeHardcodedECGSample = (ProcessInfo.processInfo.environment["HEALTHYLLM_INCLUDE_HARDCODED_ECG"] ?? "0") == "1"
    static let hardcodedECGSampleLength = 1024

    static let openTSLMSourcesPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_SOURCES_PATH"]
        ?? ""
    static let openTSLMEncoderCheckpointPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_ENCODER_CHECKPOINT"]
        ?? ""
    static let openTSLMProjectorCheckpointPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_PROJECTOR_CHECKPOINT"]
        ?? ""
    static let openTSLMLoRACheckpointPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_LORA_CHECKPOINT"]
        ?? ""
    static let openTSLMSleepCSVPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_SLEEP_CSV"]
        ?? ""
    static let openTSLMECGJSONPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_ECG_JSON"]
        ?? ""
    static let openTSLMBundleSubdirectory = "OpenTSLM"
    static let openTSLMEncoderCheckpointName = "mlx-checkpoint.encoder"
    static let openTSLMProjectorCheckpointName = "mlx-checkpoint.projector"
    static let openTSLMLoRACheckpointName = "mlx-checkpoint.lora"
    static let openTSLMSleepCSVName = "sleep_cot"
    static let requireLoRACheckpoint = (ProcessInfo.processInfo.environment["HEALTHYLLM_REQUIRE_LORA"] ?? "0") == "1"

    /// Cap main chat generation length (avoids long repetition loops in console and UI).
    static let llmDefaultMaxOutputLength = Int(
        ProcessInfo.processInfo.environment["HEALTHYLLM_LLM_MAX_OUTPUT"] ?? "128"
    ) ?? 128

    /// Cap EEG samples before encoder (1500 raw samples → ~375 patches).
    static let openTSLMMaxTimeSeriesLength = Int(
        ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_MAX_SERIES_LENGTH"] ?? "480"
    ) ?? 480

    /// If "1", run a second on-device LLM decode during OpenTSLM samples (high memory; default off).
    static let openTSLMRunSampleLLMGeneration = (ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_RUN_LLM"] ?? "0") == "1"

    static let ecgAutoPrompt = "Analyze my latest ECG reading and summarize the rhythm, signal quality, and any notable concerns."

    // swiftlint:disable:next line_length
    static let llmModelChatTemplate = "{% set loop_messages = messages %}{% if not messages[0]['role'] == 'system' %}{% set dummy = loop_messages.insert(0, {'role': 'system', 'content': 'You are a helpful assistant'}) %}{% endif %}{% for message in loop_messages %}{% if message['role'] == 'system' %}{{ '<|start_header_id|>system<|end_header_id|>\n\n' + message['content'] + '<|eot_id|>' }}{% elif message['role'] == 'user' %}{{ '<|start_header_id|>user<|end_header_id|>\n\n' + message['content'] + '<|eot_id|>' }}{% elif message['role'] == 'assistant' %}{{ '<|start_header_id|>assistant<|end_header_id|>\n\n' + message['content'] + '<|eot_id|>' }}{% endif %}{% endfor %}{% if add_generation_prompt %}{{ '<|start_header_id|>assistant<|end_header_id|>\n\n' }}{% endif %}"
    
    static let workoutLimitJsonRepresentation = 3

    /// If "1" (default), pass `Constants.llmModelChatTemplate` as the chat template to LLMLocalParameters.
    /// If "0", pass nil and let MLX use the tokenizer's built-in chat template from `tokenizer_config.json`.
    /// Use this to isolate whether the custom Jinja template is the source of `LLMLocalError.illegalContext`.
    static let useCustomChatTemplate = (ProcessInfo.processInfo.environment["HEALTHYLLM_USE_CUSTOM_CHAT_TEMPLATE"] ?? "1") == "1"
}

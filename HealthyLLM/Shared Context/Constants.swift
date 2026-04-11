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
    private static let defaultLLMModelName = "mlx-community/Phi-3-mini-4k-instruct-4bit"
    static let llmModelName = ProcessInfo.processInfo.environment["HEALTHYLLM_MODEL_ID"] ?? defaultLLMModelName

    // Local model directory copied into Spezi/Hub cache before LLM setup.
    // Override with HEALTHYLLM_LOCAL_MODEL_PATH in the scheme if needed.
    static let localModelSourcePathOverride = ProcessInfo.processInfo.environment["HEALTHYLLM_LOCAL_MODEL_PATH"]
    static let localModelBundleSubdirectory = "LocalLLM"
    static let hostHuggingFaceCacheRoot = ProcessInfo.processInfo.environment["HEALTHYLLM_HOST_HF_CACHE_ROOT"]
        ?? "/Users/nikhilkrishnaswamy/.cache/huggingface/hub"

    static let includeHardcodedECGSample = (ProcessInfo.processInfo.environment["HEALTHYLLM_INCLUDE_HARDCODED_ECG"] ?? "1") == "1"
    static let hardcodedECGSampleLength = 1024

    static let openTSLMSourcesPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_SOURCES_PATH"]
        ?? ""
    static let openTSLMEncoderCheckpointPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_ENCODER_CHECKPOINT"]
        ?? ""
    static let openTSLMProjectorCheckpointPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_PROJECTOR_CHECKPOINT"]
        ?? ""
    static let openTSLMSleepCSVPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_SLEEP_CSV"]
        ?? ""
    static let openTSLMECGJSONPath = ProcessInfo.processInfo.environment["HEALTHYLLM_OPEN_TSLM_ECG_JSON"]
        ?? ""
    static let openTSLMBundleSubdirectory = "OpenTSLM"
    static let openTSLMEncoderCheckpointName = "mlx-checkpoint.encoder"
    static let openTSLMProjectorCheckpointName = "mlx-checkpoint.projector"
    static let openTSLMSleepCSVName = "sleep_cot"

    static let ecgAutoPrompt = "Analyze my latest ECG reading and summarize the rhythm, signal quality, and any notable concerns."

    // swiftlint:disable:next line_length
    static let llmModelChatTemplate = "{{bos_token}}{% for message in messages %}{{'<|im_start|>' + message['role'] + '\n' + message['content'] + '<|im_end|>' + '\n'}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant\n' }}{% endif %}"
    
    static let workoutLimitJsonRepresentation = 3
}

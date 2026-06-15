//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziLLMLocal

enum Constants {
    static let llmModel: LLMLocalModel = .custom(id: llmModelName)
    private static let defaultLLMModelName = "meta-llama/Llama-3.2-1B"
    static let llmModelName = ProcessInfo.processInfo.environment["HEALTHYLLM_MODEL_ID"] ?? defaultLLMModelName
}

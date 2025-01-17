//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziLLMLocal

enum Constants {
    static let llmModel: LLMLocalModel = .custom(id: llmModelName)
    
    static let llmModelName = "mlx-community/Llama-3.2-3B-Instruct-4bit" //"mlx-community/Llama3.1-Aloe-Beta-8B"
    
    static let workoutLimitJsonRepresentation = 3
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

enum Constants {
    static let llmModelName = "mlx-community/Hermes-2-Pro-Llama-3-8B-4bit"
//    static let llmModelName = "mlx-community/Llama3.1-Aloe-Beta-8B"
    
    static let llmModelChatTemplate = "{{bos_token}}{% for message in messages %}{{'<|im_start|>' + message['role'] + '\n' + message['content'] + '<|im_end|>' + '\n'}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant\n' }}{% endif %}"
    
    static let workoutLimitJsonRepresentation = 3
}

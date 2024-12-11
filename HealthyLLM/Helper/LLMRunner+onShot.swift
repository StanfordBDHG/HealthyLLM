//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziLLM
import SpeziLLMLocal
import MLXLLM

extension LLMRunner {
    public func oneShot(
        on llmSession: LLMLocalSession,
        customContext: [[String: String]]
    ) async throws -> String {
        await MainActor.run {
            llmSession.customContext = customContext
        }
        
        var output = ""
        for try await stringPiece in try await llmSession.generate() {
            output.append(stringPiece)
        }
        return output
    }
}

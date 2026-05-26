//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MLX
import MLXLLM
import SpeziLLM
import SpeziLLMLocal

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

        llmSession.cancel()
        GPU.clearCache()
        return output
    }
}

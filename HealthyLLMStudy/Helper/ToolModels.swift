//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

struct ToolCall: Codable {
    let name: String
    let parameters: [String: String]
}

/// Error types for function execution
enum ToolCallError: Error {
    case invalidData
    case toolNotFound
    case missingParameters(names: [String])
    case executionFailed(reason: String)
}

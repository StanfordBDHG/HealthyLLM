//
//  FunctionModels.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

/// Error types for function execution
enum ToolCallError: Error {
    case invalidData
    case toolNotFound
    case missingParameters(names: [String])
    case executionFailed(reason: String)
}

/// Struct representing a tool/function call from the LLM
struct ToolCall: Codable {
    let name: String
    let parameters: [String: String]
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

protocol ToolHandler {
    static var name: String { get }
    
    /// Execute the function with provided parameters
    /// - Parameter parameters: Dictionary of parameters passed from the LLM
    /// - Returns: Result containing either the response data or an error
    func execute(parameters: [String: String]) async throws -> String
}

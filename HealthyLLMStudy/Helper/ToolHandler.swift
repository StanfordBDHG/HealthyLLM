//
//  FunctionHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

/// Protocol that all function handlers must conform to
protocol ToolHandler {
    static var name: String { get }
    
    /// Execute the function with provided parameters
    /// - Parameter parameters: Dictionary of parameters passed from the LLM
    /// - Returns: Result containing either the response data or an error
    func execute(parameters: [String: String]) async throws -> String
}

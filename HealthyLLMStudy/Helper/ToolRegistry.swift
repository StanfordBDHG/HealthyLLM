//
//  FunctionRegistry.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

/// Registry to manage available functions
class ToolRegistry {
    /// Singleton instance
    static let shared = ToolRegistry()
    
    /// Dictionary mapping function names to their handlers
    private var functions: [String: ToolHandler] = [:]
    
    private init() {}
    
    /// Register a function handler with a name
    /// - Parameters:
    ///   - name: The name used by the LLM to call this function
    ///   - handler: The handler that implements the function
    func register(name: String, handler: ToolHandler) {
        functions[name] = handler
    }
    
    /// Get a function handler by name
    /// - Parameter name: The function name
    /// - Returns: The handler if found, nil otherwise
    func handler(for name: String) -> ToolHandler? {
        functions[name]
    }
    
    /// Check if a function with the given name is registered
    /// - Parameter name: The function name
    /// - Returns: True if the function exists
    func hasFunction(named name: String) -> Bool {
        functions[name] != nil
    }
}

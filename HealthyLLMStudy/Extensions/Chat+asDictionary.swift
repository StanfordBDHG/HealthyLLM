//
//  Chat+asDictionary.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import Foundation
import SpeziChat

extension Chat {
    func asDictionaryRepresentation() -> [[String: String]] {
        var result: [[String: String]] = []
        
        for message in self {
            
            switch message.role {
            case .assistantToolCall, .assistantToolResponse:
                result.append([
                    "role": message.role.rawValue,
                    "tool_calls": message.content
                ])
            default:
                result.append([
                    "role": message.role.rawValue,
                    "content": message.content
                ])
            }
        }
        
        return result
    }
}

extension ChatEntity.Role {
    var rawValue: String {
        switch self {
        case .user: "user"
        case .assistant: "assistant"
        case .assistantToolCall: "assistant"
        case .assistantToolResponse: "assistant"
        case .hidden(let type): type.name
        }
    }
}

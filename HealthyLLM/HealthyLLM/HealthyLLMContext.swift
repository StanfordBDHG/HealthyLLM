//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziChat

typealias HealthyLLMContext = [HealthyLLMContextEntity]

struct HealthyLLMContextEntity: Identifiable {
    enum HealthyLLMContextRole {
        case assistant
        case toolCall
        case toolResponse
        case user
        case system
        
        var inChatName: String {
            switch self {
            case .assistant: return "assisstant"
            case .toolCall: return "assisstant"
            case .toolResponse: return "tool"
            case .user: return "user"
            case .system: return "system"
            }
        }
    }
    
    let id: UUID
    let role: HealthyLLMContextRole
    let content: String
    let completed: Bool
    
    init(_ role: HealthyLLMContextRole, content: String, completed: Bool = true, id: UUID = UUID()) {
        self.id = id
        self.role = role
        self.content = content
        self.completed = completed
    }
    
    var asDictionary: [String: String] {
        ["role": role.inChatName, "content": content]
    }
    
    
    var asUserFacingChatEntity: SpeziChat.ChatEntity {
        switch self.role {
        case .assistant:
            return .init(role: .assistant, content: content, complete: completed)
        case .toolCall:
            return .init(role: .hidden(type: .assistantToolCall), content: content, complete: completed)
        case .toolResponse:
            return .init(role: .hidden(type: .function), content: content, complete: completed)
        case .user:
            return .init(role: .user, content: content, complete: completed)
        case .system:
            return .init(role: .hidden(type: .system), content: content, complete: completed)
        }
    }
    
    var asChatEntity: SpeziChat.ChatEntity {
        switch self.role {
        case .assistant:
            return .init(role: .assistant, content: content, complete: completed)
        case .toolCall:
            return .init(role: .assistant, content: content, complete: completed)
        case .toolResponse:
            return .init(role: .assistant, content: content, complete: completed)
        case .user:
            return .init(role: .user, content: content, complete: completed)
        case .system:
            return .init(role: .assistant, content: content, complete: completed)
        }
    }
}

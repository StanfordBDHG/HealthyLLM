//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziChat

extension Chat {
    func asDictionaryRepresentation() -> [[String: String]] {
        var result: [[String: String]] = []
        
        for message in self {
            result.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        return result
    }
    
//    func asChatLog() -> [ChatLog] {
//        var result: [ChatLog] = []
//        
//        for message in self {
//            result.append(
//                .init(
//                    role: message.role.rawValue,
//                    content: message.content
//                )
//            )
//        }
//        
//        return result
//    }
    
}


extension ChatEntity.Role {
    var rawValue: String {
        switch self {
        case .user: "user"
        case .assistant: "assistant"
        case .assistantToolCall: "assistantToolCall"
        case .assistantToolResponse: "assistantToolResponse"
        case .hidden(let type): type.name
        }
    }
}

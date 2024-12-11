//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziChat

extension ChatEntity.HiddenMessageType {
    /// Assistant tool call hidden message type of the `ChatEntity`.
    static let assistantToolCall = ChatEntity.HiddenMessageType(name: "assistantToolCall")
    /// System hidden message type of the `ChatEntity`.
    static let system = ChatEntity.HiddenMessageType(name: "system")
    /// Function hidden message type of the `ChatEntity`.
    static let function = ChatEntity.HiddenMessageType(name: "function")
}


//
//  StudyStorage.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import Foundation
import SwiftData
import SpeziChat
import SpeziQuestionnaire


@Model
class StudyMetadata {
    var metadata: [String: String]
    
    init(metadata: [String: String] = [:]) {
        self.metadata = metadata
    }
}

@Model
class StudyStep {
    @Attribute(.unique) var id: UUID
    var name: String
    var chatLog: String?
    var keyboardMetrics: [Double: String]?
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        chatLog: String? = nil,
        keyboardMetrics: [Double: String]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.chatLog = chatLog
        self.keyboardMetrics = keyboardMetrics
        self.timestamp = timestamp
    }
}

@Model
class StudyResponse {
    @Attribute(.unique) var id: UUID
    var name: String
    var result: String
    
    init(
        id: UUID = UUID(),
        name: String,
        result: String
    ) {
        self.id = id
        self.name = name
        self.result = result
    }
}

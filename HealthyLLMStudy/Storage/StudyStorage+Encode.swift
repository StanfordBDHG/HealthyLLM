//
//  StudyStorage+Encode.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/10/25.
//

import Foundation


extension StudyMetadata: Encodable {
    enum CodingKeys: String, CodingKey {
        case id
        case metadata
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(metadata, forKey: .metadata)
    }
}


extension StudyStep: Encodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case chatLog
        case keyboardMetrics
        case timestamp
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(chatLog, forKey: .chatLog)
        try container.encode(keyboardMetrics, forKey: .keyboardMetrics)
        try container.encode(timestamp, forKey: .timestamp)
    }
}


extension StudyResponse: Encodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case result
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(result, forKey: .result)
    }
}

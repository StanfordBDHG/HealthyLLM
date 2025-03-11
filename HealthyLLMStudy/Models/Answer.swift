//
//  Question.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import Foundation
import CoreData


class Answer: NSManagedObject, Encodable {
    enum CodingKeys: CodingKey {
        case id
        case answer
        case timestamp
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(answer, forKey: .answer)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

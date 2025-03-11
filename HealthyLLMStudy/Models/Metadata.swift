//
//  Metadata.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import Foundation
import CoreData

class Metadata: NSManagedObject, Encodable {
    enum CodingKeys: CodingKey {
        case id
        case participantId
        case age
        case sex
        case device
        case timestamp
        case os
        case totalMemory
        case totalStorage
        case freeStorage
    }
    
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(participantId, forKey: .participantId)
        try container.encode(age, forKey: .age)
        try container.encode(sex, forKey: .sex)
        try container.encode(device, forKey: .device)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(os, forKey: .os)
        try container.encode(totalMemory, forKey: .totalMemory)
        try container.encode(totalStorage, forKey: .totalStorage)
        try container.encode(freeStorage, forKey: .freeStorage)
    }
}

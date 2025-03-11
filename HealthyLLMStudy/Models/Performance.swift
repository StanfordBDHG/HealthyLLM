//
//  Performacne.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import Foundation
import CoreData

class Performance: NSManagedObject, Encodable {
    enum CodingKeys: CodingKey {
        case timestamp
        case cpu
        case memory
        case thermalState
        case batteryLevel
        case batteryState
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(cpu, forKey: .cpu)
        try container.encode(memory, forKey: .memory)
        try container.encode(thermalState, forKey: .thermalState)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(batteryState, forKey: .batteryState)
    }
}

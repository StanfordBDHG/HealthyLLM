//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreData
import Foundation

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

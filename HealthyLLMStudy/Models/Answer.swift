//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreData
import Foundation


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

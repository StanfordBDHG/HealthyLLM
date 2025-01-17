//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit


struct HealthData: Encodable {
    let identifier: String
    let displayName: String?
    let description: String?
    let date: Date
    let value: Double
    let unit: String?
}

struct WorkoutData: Encodable {
    let name: String
    let date: String
    let duration: String
    let statistics: [String: String]
}

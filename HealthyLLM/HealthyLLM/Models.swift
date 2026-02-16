//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

// periphery:ignore
struct UserInfo: Encodable {
    let name: String?
    let dateOfBirth: Date?
    let sex: String?
    let height: String?
    let weight: String?
    let bmi: String?
}

// periphery:ignore
struct HealthData: Encodable {
    let name: String
    let unit: String
    let values: [String: [Double]]
}

// periphery:ignore
struct WorkoutData: Encodable {
    let name: String
    let date: String
    let duration: String
    let statistics: [String: String]
}

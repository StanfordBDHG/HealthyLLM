//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

struct UserInfo: Encodable {
    let name: String?
    let dateOfBirth: Date?
    let sex: String?
    let height: String?
    let weight: String?
    let bmi: String?
}

struct HealthData: Encodable {
    let name: String
    let unit: String
    let values: [String: Double]
}

struct WorkoutData: Encodable {
    let name: String
    let date: String
    let duration: String
    let statistics: [String: String]
}

struct SleepData: Encodable {
    let date: String
    let duration: String
    let sleepQuality: String
}

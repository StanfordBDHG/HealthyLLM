//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

struct UserInfo: Encodable {
    let name: String? // periphery:ignore
    let dateOfBirth: Date? // periphery:ignore
    let sex: String? // periphery:ignore
    let height: String? // periphery:ignore
    let weight: String? // periphery:ignore
    let bmi: String? // periphery:ignore
}

struct HealthData: Encodable {
    let name: String // periphery:ignore
    let unit: String // periphery:ignore
    let values: [String: [Double]] // periphery:ignore
}

struct WorkoutData: Encodable {
    let name: String
    let date: String
    let duration: String
    let statistics: [String: String]
}

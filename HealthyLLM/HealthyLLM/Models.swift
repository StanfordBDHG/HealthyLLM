//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

struct UserInfo: Encodable {
    let dateOfBirth: Date?
    let sex: String?
    let height: String?
    let weight: String?
    let bmi: String?
}

struct HealthData: Encodable {
    let name: String
    let unit: String
    let values: [String: [Double]]
}

struct ElectrocardiogramData: Encodable {
    let startDate: Date
    let endDate: Date
    let classification: String
    let symptomsStatus: String
    let averageHeartRate: Double?
    let samplingFrequency: Double?
    let numberOfVoltageMeasurements: Int
    let voltages: [Double]
}

struct WorkoutData: Encodable {
    let name: String
    let date: String
    let duration: String
    let statistics: [String: String]
}

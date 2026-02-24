//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit

class NutritionDataHandler: ToolHandler {
    static var name: String = "getNutrition"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let typeString = parameters["type"],
              let maxDaysString = parameters["maxDays"] else {
            throw ToolCallError.missingParameters(names: ["type", "maxDays"])
        }
        
        guard let type = stringToQuantityTypeIdentifier(typeString),
              let maxDays = Int(maxDaysString) else {
            throw ToolCallError.invalidData
        }
        
        do {
            return try await getNutritionData(type: type, maxDays: maxDays)
        } catch {
            return "No data available"
        }
    }
    
    private func stringToQuantityTypeIdentifier(_ input: String) -> HKQuantityTypeIdentifier? {
        switch input.lowercased() {
        case "calories":
            return .dietaryEnergyConsumed
        case "protein":
            return .dietaryProtein
        case "carbohydrates":
            return .dietaryCarbohydrates
        case "fat":
            return .dietaryFatTotal
        case "water":
            return .dietaryWater
        default:
            return nil
        }
    }
    
    private func getNutritionData(type: HKQuantityTypeIdentifier, maxDays: Int) async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -maxDays, to: Date())!
        let endDate = Date()
        
        let (value, _) = try await HealthDataFetcher.shared.getAverageQuantity(for: type, startDate: startDate, endDate: endDate)
        
        guard let value else {
            throw ToolCallError.invalidData
        }
        
        switch type {
        case .dietaryEnergyConsumed:
            return "Calories (avg last \(maxDays)): \(Int(value)) kcal/day\n"
        case .dietaryProtein:
            return "Protein (avg last \(maxDays)): \(Int(value)) g/day\n"
        case .dietaryCarbohydrates:
            return "Carbohydrates (avg last \(maxDays)): \(Int(value)) g/day\n"
        case .dietaryFatTotal:
            return "Fat (avg last \(maxDays)): \(Int(value)) g/day\n"
        case .dietaryWater:
            let waterInLiters = value / 1000
            return "Water (avg last \(maxDays)): \(String(format: "%.1f", waterInLiters)) L/day\n"
        default:
            throw ToolCallError.executionFailed(reason: "Wrong Type")
        }
    }
}

//
//  ActivityDataHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/5/25.
//

import HealthKit
import Foundation

class ActivityDataHandler: ToolHandler {
    static var name = "getActivity"
    
    func execute(parameters: [String : String]) async throws -> String {
        guard let typeString = parameters["type"],
              let maxDaysString = parameters["maxDays"] else {
            throw ToolCallError.missingParameters(names: ["type", "maxDays"])
        }
        
        guard let type = stringToQuantityTypeIdentifier(typeString),
              let _maxDays = Int(maxDaysString) else {
            throw ToolCallError.invalidData
        }
        
        let maxDays = max(1, min(_maxDays, 30))
        
        do {
            return try await getActivityData(type: type, maxDays: maxDays)
        } catch {
            return "No data available"
        }
    }
    
    private func stringToQuantityTypeIdentifier(_ input: String) -> HKQuantityTypeIdentifier? {
        switch input.lowercased() {
        case "steps":
            return .stepCount
        case "distance":
            return .distanceWalkingRunning
        case "activeenergy":
            return .activeEnergyBurned
        case "basalenergy":
            return .basalEnergyBurned
        case "standhours":
            return .appleStandTime
        case "exerciseminutes":
            return .appleExerciseTime
        case "flightsclimbed":
            return .flightsClimbed
        default:
            return nil
        }
    }
    
    private func getActivityData(type: HKQuantityTypeIdentifier, maxDays: Int) async throws -> String {
        var resultText = ""
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        
        let maxDaysAgo = calendar.date(byAdding: .day, value: -maxDays, to: startOfDay)!
        
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay))!
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: startOfWeek)!
        
        
        let (dailyValue, _) = try await HealthDataFetcher.shared.getAverageQuantity(for: type, startDate: maxDaysAgo, endDate: startOfDay, intervalType: .day)
        let (avgDailyValue, _) = try await HealthDataFetcher.shared.getAverageQuantity(for: type, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
        
        guard let dailyValue,
              let avgDailyValue else {
            throw ToolCallError.invalidData
        }
        
        resultText += "\n#### Last \(maxDays)-Day's Average Activity Per Day\n"
        
        switch type {
        case .stepCount:
            resultText += "Steps: \(Int(dailyValue).formattedWithSeparator)\n"
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgDailyValue).formattedWithSeparator) steps)\n"
        case .distanceWalkingRunning:
            let kilometers = dailyValue / 1000 // Convert meters to km
            resultText += "Distance: \(String(format: "%.2f", kilometers)) km\n"
            let avgKilometers = avgDailyValue / 1000 // Convert meters to km
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.2f", avgKilometers)) km)\n"
        case .activeEnergyBurned:
            resultText += "Active calories: \(Int(dailyValue).formattedWithSeparator) kcal\n"
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgDailyValue).formattedWithSeparator) kcal)\n"
        case .basalEnergyBurned:
            resultText += "Resting calories: \(Int(dailyValue).formattedWithSeparator) kcal\n"
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgDailyValue).formattedWithSeparator) kcal)\n"
        case .appleStandTime:
            let standHours = Int(dailyValue / 3600) // Convert seconds to hours
            resultText += "Stand hours: \(standHours) h\n"
            let avgStandHours = avgDailyValue / 3600 // Convert seconds to hours
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.1f", avgStandHours)) hours)\n"
        case .appleExerciseTime:
            let exerciseMinutes = Int(dailyValue / 60) // Convert seconds to minutes
            resultText += "Exercise minutes: \(exerciseMinutes)\n"
            let avgExerciseMinutes = avgDailyValue / 60 // Convert seconds to minutes
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgExerciseMinutes)) min)\n"
        case .flightsClimbed:
            resultText += "Flights climbed: \(Int(dailyValue))\n"
            let percentDiff = ((dailyValue - avgDailyValue) / avgDailyValue) * 100
            resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.1f", avgDailyValue)) flights)\n"
        default:
            throw ToolCallError.invalidData
        }
        return resultText
    }
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit

class ActivityOverviewDataHandler: ToolHandler {
    static var name: String = "getActivityOverview"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let typeString = parameters["type"] else {
            throw ToolCallError.missingParameters(names: ["type"])
        }
        
        guard let type = stringToQuantityTypeIdentifier(typeString) else {
            throw ToolCallError.invalidData
        }
        
        do {
            return try await getActivityData(type: type)
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
    
    private func getActivityData(type: HKQuantityTypeIdentifier) async throws -> String {
       var resultText = ""
       let calendar = Calendar.current
       let today = Date()
       let startOfDay = calendar.startOfDay(for: today)
       let startOfMonth = Calendar.current.date(
           from: Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.startOfDay(for: .now))
       )!
       
       let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay))!
       let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: startOfWeek)!
        let daysPerMonth = 30.0
       
        // MONTHLY TRENDS
        resultText += "\n#### Monthy Trends\n"
        
        let values = try await HealthDataFetcher.shared.getPeriodicQuantities(
            for: type, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month
        )
        
        switch type {
        case .stepCount:
            resultText += "\nStep Counts:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) steps\n"
                }
            }
            return resultText
        case .distanceWalkingRunning:
            resultText += "\nDistance:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) km\n"
                }
            }
        case .activeEnergyBurned:
            resultText += "\nActive Energy:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) kcal\n"
                }
            }
        case .basalEnergyBurned:
            resultText += "\nBasal Energy:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) kcal\n"
                }
            }
        case .appleStandTime:
            resultText += "\nStand Time:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) h\n"
                }
            }
        case .appleExerciseTime:
            resultText += "\nExercise Time:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) min\n"
                }
            }
        case .flightsClimbed:
            resultText += "\nFlights climbed:\n"
            for monthData in values {
                if let value = monthData.value {
                    resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) flights\n"
                }
            }
        default:
            throw ToolCallError.invalidData
        }
        return ""
   }
}

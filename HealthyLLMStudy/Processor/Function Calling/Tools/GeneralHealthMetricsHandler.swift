//
//  GeneralHealthMetricsHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/4/25.
//

import Foundation
import HealthKit

class GeneralHealthMetricsHandler: ToolHandler {
    static var name: String = "getGeneralHealthMetrics"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let typeString = parameters["type"] else {
            throw ToolCallError.missingParameters(names: ["type"])
        }
        
        guard let type = stringToQuantityTypeIdentifier(typeString) else {
            throw ToolCallError.invalidData
        }
        
        do {
            return try await getGeneralHealthMetrics(type: type)
        } catch {
            return "No data available"
        }
    }
    
    
    private func stringToQuantityTypeIdentifier(_ input: String) -> HKQuantityTypeIdentifier? {
        switch input.lowercased() {
        case "weight":
            return .bodyMass
        case "bmi":
            return .bodyMassIndex
        case "bodyfat":
            return .bodyFatPercentage
        case "height":
            return .height
        default:
            return nil
        }
    }
    
    private func getGeneralHealthMetrics(type: HKQuantityTypeIdentifier) async throws -> String {
        let (value, _, date) = try await HealthDataFetcher.shared.getLatestQuantityValue(for: type, maxMonthRange: 12)
        
        guard let value else {
            throw ToolCallError.invalidData
        }
        
        switch type {
        case .bodyMass:
            return "Weight: \(String(format: "%.1f", value)) kg / \(String(format: "%.1f", value * 2.20462)) lbs (measured \(ToStringHelper.timeAgoString(from: date)))\n"
        case .bodyMassIndex:
            return "BMI: \(String(format: "%.1f", value)) (measured \(ToStringHelper.timeAgoString(from: date)))\n"
        case .bodyFatPercentage:
            return "Body Fat: \(String(format: "%.1f", value * 100))% (measured \(ToStringHelper.timeAgoString(from: date)))\n"
        case .height:
            return "Height: \(String(format: "%.2f", value)) m / \(String(format: "%.1f", value * 3.28084)) ft (measured \(ToStringHelper.timeAgoString(from: date)))\n"
        default:
            return ""
        }
    }
}

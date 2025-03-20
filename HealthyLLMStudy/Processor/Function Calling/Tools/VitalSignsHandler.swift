//
//  VitalHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

import Foundation
import HealthKit

class VitalSignsHandler: ToolHandler {
    static var name: String = "getVitalSigns"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let typeString = parameters["type"],
              let weeksToAverageString = parameters["weeksToAverage"] else {
            throw ToolCallError.missingParameters(names: ["type", "weeksToAverage"])
        }
        
        guard let type = stringToQuantityTypeIdentifier(typeString),
              let weeksToAverage = Int(weeksToAverageString) else {
            throw ToolCallError.invalidData
        }
        
        do {
            return try await getVitalSignAverage(for: type, weeksToAverage: weeksToAverage)
        } catch {
            return "No data available"
        }
    }
    
    private func stringToQuantityTypeIdentifier(_ input: String) -> HKQuantityTypeIdentifier? {
        switch input.lowercased() {
        case "heartrate":
            return .heartRate
        case "restingheartrate":
            return .restingHeartRate
        case "respiratoryrate":
            return .respiratoryRate
        case "bloodpressure":
            return .bloodPressureSystolic
        case "oxygensaturation":
            return .oxygenSaturation
        default:
            return nil
        }
    }
    
    // swiftline:disable:this cyclomatic_complexity
    private func getVitalSignAverage(for type: HKQuantityTypeIdentifier, weeksToAverage: Int = 4) async throws -> String {
        var resultText = ""
        let weeksPerYear = 52
        
        switch type {
        case .heartRate, .restingHeartRate, .respiratoryRate, .oxygenSaturation:
            // For single-value metrics like heart rate, resting heart rate, and respiratory rate
            let avgData = try await HealthDataFetcher.shared.getAverageQuantityValue(
                for: type,
                weeksToAverage: weeksToAverage
            )
            if var value = avgData.0 {
                // Choose display name and unit based on vital type.
                let (name, unit) =
                switch type {
                case .heartRate: ("Heart Rate", "bpm")
                case .restingHeartRate: ("Resting Heart Rate", "bpm")
                case .respiratoryRate: ("Respiratory Rate", "breaths/min")
                case .oxygenSaturation: ("Oxygen Saturation", "%")
                default: ("\(type.rawValue)", "")
                }
                
                if case .oxygenSaturation = type {
                    value *= 100
                }
                
                resultText += "\(name) (avg over \(weeksToAverage) weeks): \(Int(value)) \(unit)\n"
                
                let avgYearData = try await HealthDataFetcher.shared.getAverageQuantityValue(
                    for: type,
                    weeksToAverage: weeksPerYear
                )
                if var yearValue = avgYearData.0 {
                    let percentDiff = ((value - yearValue) / yearValue) * 100
                    if case .oxygenSaturation = type {
                        yearValue *= 100
                    }
                    resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(yearValue)) \(unit))\n"
                }
            }
            
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            // For blood pressure we want both systolic and diastolic.
            let systolicAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(
                for: .bloodPressureSystolic,
                weeksToAverage: weeksToAverage
            )
            let diastolicAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(
                for: .bloodPressureDiastolic,
                weeksToAverage: weeksToAverage
            )
            if let sys = systolicAvg.0, let dia = diastolicAvg.0 {
                resultText += "Blood Pressure (avg over \(weeksToAverage) weeks): \(Int(sys))/\(Int(dia)) mmHg\n"
                let systolicYear = try await HealthDataFetcher.shared.getAverageQuantityValue(
                    for: .bloodPressureSystolic,
                    weeksToAverage: weeksPerYear
                )
                let diastolicYear = try await HealthDataFetcher.shared.getAverageQuantityValue(
                    for: .bloodPressureDiastolic,
                    weeksToAverage: weeksPerYear
                )
                if let sysYear = systolicYear.0, let diaYear = diastolicYear.0 {
                    let percentDiff = (((sys + dia) - (sysYear + diaYear)) / (sysYear + diaYear)) * 100
                    resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(sysYear))/\(Int(diaYear)) mmHg)\n"
                }
            }
        default:
            // For any other vital types, we provide a default behavior.
            let avgData = try await HealthDataFetcher.shared.getAverageQuantityValue(
                for: type,
                weeksToAverage: weeksToAverage
            )
            if let value = avgData.0 {
                resultText += "\(type.rawValue) (avg over \(weeksToAverage) weeks): \(Int(value))\n"
                let avgYearData = try await HealthDataFetcher.shared.getAverageQuantityValue(
                    for: type,
                    weeksToAverage: weeksPerYear
                )
                if let yearValue = avgYearData.0 {
                    let percentDiff = ((value - yearValue) / yearValue) * 100
                    resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(yearValue)))\n"
                }
            }
        }
        
        return resultText
    }
}

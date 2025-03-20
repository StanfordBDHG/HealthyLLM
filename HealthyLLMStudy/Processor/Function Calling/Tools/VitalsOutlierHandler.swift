//
//  VitalsOutlierHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/7/25.
//

import HealthKit


class VitalsOutlierHandler: ToolHandler {
    static var name: String = "VitalsOutlier"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let maxDaysString = parameters["maxDays"],
              let maxDays = Int(maxDaysString) else {
            throw ToolCallError.missingParameters(names: ["maxDays"])
        }
        
        return try await calculateVitalsOutliersMarkdownAsync(startDate: .daysAgo(maxDays), endDate: .now)
    }
    
    // MARK: - Helpers

    // Computes mean and standard deviation for an array of Doubles.
    func meanAndStandardDeviation(from values: [Double]) -> (mean: Double, std: Double) {
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / count
        return (mean, sqrt(variance))
    }

    // Calculates outliers (with dates) from an array of (Date, Double) tuples using the two-standard-deviation rule.
    func calculateOutliersWithDates(from samples: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        let values = samples.map { $0.value }
        guard !values.isEmpty else { return [] }
        let (mean, std) = meanAndStandardDeviation(from: values)
        let lowerBound = mean - 3 * std
        let upperBound = mean + 3 * std
        return samples.filter { $0.value < lowerBound || $0.value > upperBound }
    }

    // Formats a time interval (in seconds) into a string "hh:mm:ss".
    func formatDuration(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    // MARK: - Main Function

    /// Fetches vital data from HealthKit, calculates outliers using the two-standard-deviation rule,
    /// and returns a markdown-formatted report with dates for each outlier.
    func calculateVitalsOutliersMarkdownAsync(startDate: Date, endDate: Date) async throws -> String {
        // Define the vital quantity types.
        guard let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate),
              let wristTemperatureType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature),
              let bloodOxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create one or more vital types"])
        }
        
        // Fetch data concurrently using async let.
        async let restingHRData = HealthDataFetcher.shared.fetchQuantitySamplesAsync(
            for: restingHRType,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit(from: "count/min")
        )
        async let respiratoryData = HealthDataFetcher.shared.fetchQuantitySamplesAsync(
            for: respiratoryRateType,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute())
        )
        async let temperatureData = HealthDataFetcher.shared.fetchQuantitySamplesAsync(
            for: wristTemperatureType,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit.degreeCelsius()
        )
        async let oxygenData = HealthDataFetcher.shared.fetchQuantitySamplesAsync(
            for: bloodOxygenType,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit.percent()
        )
        async let sleepData = HealthDataFetcher.shared.fetchSleepDurationsAsync(
            startDate: startDate,
            endDate: endDate
        )
        
        let restingHR = try await restingHRData
        let respiratoryRate = try await respiratoryData
        let wristTemperature = try await temperatureData
        let bloodOxygen = try await oxygenData
        let sleepDurations = try await sleepData
        
        // Calculate outliers for each vital metric.
        let restingHROutliers = calculateOutliersWithDates(from: restingHR)
        let respiratoryOutliers = calculateOutliersWithDates(from: respiratoryRate)
        let wristTempOutliers = calculateOutliersWithDates(from: wristTemperature)
        let bloodOxygenOutliers = calculateOutliersWithDates(from: bloodOxygen)
        let sleepOutliers = calculateOutliersWithDates(from: sleepDurations)
        
        // Formatter for dates in the markdown report.
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        // Helper to generate markdown list from outlier tuples.
        func markdownList(from outliers: [(date: Date, value: Double)], unit: String) -> String {
            guard !outliers.isEmpty else { return "None" }
            return outliers.map { "- **\(formatter.string(from: $0.date))**: \($0.value) \(unit)" }
                          .joined(separator: "\n")
        }
        
        // Build the markdown report.
        var report = "# Vitals Outliers Report\n\n"
        
        report += "## Resting Heart Rate (bpm)\n"
        report += markdownList(from: restingHROutliers, unit: "bpm") + "\n\n"
        
        report += "## Respiratory Rate (breaths per minute)\n"
        report += markdownList(from: respiratoryOutliers, unit: "breaths/min") + "\n\n"
        
        report += "## Wrist Temperature (°C)\n"
        report += markdownList(from: wristTempOutliers, unit: "°C") + "\n\n"
        
        report += "## Blood Oxygen (percentage)\n"
        report += markdownList(from: bloodOxygenOutliers, unit: "%") + "\n\n"
        
        // For sleep durations, convert seconds to hh:mm:ss.
        let sleepMarkdown = sleepOutliers.map { "- **\(formatter.string(from: $0.date))**: \(formatDuration($0.value))" }
                                         .joined(separator: "\n")
        report += "## Sleep Duration (hh:mm:ss)\n"
        report += sleepMarkdown.isEmpty ? "None" : sleepMarkdown
        
        return report
    }
}

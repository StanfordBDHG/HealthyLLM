//
//  SleepDataHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/5/25.
//

import HealthKit
import Foundation


class SleepDataHandler: ToolHandler {
    static var name: String = "getSleep"
    
    func execute(parameters: [String : String]) async throws -> String {
        guard let maxDaysString = parameters["maxDays"],
              let _maxDays = Int(maxDaysString) else {
            throw ToolCallError.missingParameters(names: ["maxDays"])
        }
        
        let maxDays = max(1, min(_maxDays, 30)) // 1 <= maxDays <= 30
        
        do {
            return try await getSleepData(maxDays: maxDays)
        } catch {
            return "No data available"
        }
    }
    
    private func getSleepData(maxDays: Int = 14) async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -maxDays, to: Date())!
        let endDate = Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { query, samples, error in
                
                guard let sleepSamples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: "No sleep data available.")
                    return
                }
                
                let sleepNights = Dictionary(grouping: sleepSamples) { (sample) -> Date in
                    let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: sample.endDate)
                    return Calendar.current.date(from: dateComponents)!
                }
                
                var resultText = ""
                let sortedNights = Array(sleepNights.keys.sorted(by: >))
                
                for night in sortedNights {
                    let nightSamples = sleepNights[night]!
                    var totalSleepTime: TimeInterval = 0
                    var deepSleepTime: TimeInterval = 0
                    var remSleepTime: TimeInterval = 0
                    var coreSleepTime: TimeInterval = 0
                    var otherSleepTime: TimeInterval = 0
                    
                    for sample in nightSamples {
                        let sleepType = sample.value
                        
                        if sample.endDate > sample.startDate {
                            let sampleDuration = sample.endDate.timeIntervalSince(sample.startDate)
                            
                            guard sleepType != HKCategoryValueSleepAnalysis.awake.rawValue && sleepType != HKCategoryValueSleepAnalysis.inBed.rawValue else {
                                continue
                            }
                            totalSleepTime += sampleDuration
                            
                            switch sleepType {
                            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                                deepSleepTime += sampleDuration
                            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                                remSleepTime += sampleDuration
                            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                                coreSleepTime += sampleDuration
                            default:
                                otherSleepTime += sampleDuration
                            }
                        }
                    }
                    
                    let hours = Int(totalSleepTime / 3600)
                    let minutes = Int((totalSleepTime.truncatingRemainder(dividingBy: 3600)) / 60)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    let dateString = dateFormatter.string(from: night)
                    
                    resultText += "- \(dateString): \(hours)h \(minutes)m"
                    if deepSleepTime > 0 || remSleepTime > 0 || coreSleepTime > 0 || otherSleepTime > 0 {
                        resultText += " (Deep: \(Int(deepSleepTime / 60))m, REM: \(Int(remSleepTime / 60))m, Core: \(Int(coreSleepTime / 60))m, Other: \(Int(otherSleepTime / 60))m)"
                    }
                    resultText += "\n"
                }
                
                if sortedNights.count >= 3 {
                    var totalAvgSleep: TimeInterval = 0
                    var nightCount = 0
                    
                    for night in sortedNights {
                        let nightSamples = sleepNights[night]!
                        var nightSleepTime: TimeInterval = 0
                        
                        for sample in nightSamples where sample.value != HKCategoryValueSleepAnalysis.awake.rawValue && sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue {
                            if sample.endDate > sample.startDate {
                                nightSleepTime += sample.endDate.timeIntervalSince(sample.startDate)
                            }
                        }
                        
                        if nightSleepTime > 0 {
                            totalAvgSleep += nightSleepTime
                            nightCount += 1
                        }
                    }
                    
                    if nightCount > 0 {
                        let avgSleepTime = totalAvgSleep / Double(nightCount)
                        let avgHours = Int(avgSleepTime / 3600)
                        let avgMinutes = Int((avgSleepTime.truncatingRemainder(dividingBy: 3600)) / 60)
                        
                        resultText += "\nAverage sleep duration (last \(nightCount) nights): \(avgHours)h \(avgMinutes)m\n"
                        if avgSleepTime < 7 * 3600 {
                            resultText += "Sleep trend: Below recommended 7-9 hours\n"
                        } else if avgSleepTime <= 9 * 3600 {
                            resultText += "Sleep trend: Within recommended 7-9 hours\n"
                        } else {
                            resultText += "Sleep trend: Above recommended 7-9 hours\n"
                        }
                    }
                }
                
                continuation.resume(returning: resultText)
            }
            HealthDataFetcher.shared.healthStore.execute(query)
        }
    }
}

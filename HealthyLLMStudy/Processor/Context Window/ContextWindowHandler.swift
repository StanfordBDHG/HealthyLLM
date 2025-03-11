//
//  HealthDataFetcher+ContextWindow.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/26/25.
//

import Foundation
import HealthKit

class ContextWindowHandler {
    
    static func execute() async throws -> String {
        let vitalAverage = try await getVitalSignsAverage()
        let general = try await getGeneralHealthMetrics()
        let workout = try await getRecentWorkouts(maxDayRange: 180)
        let sleep = try await getSleepData()
        let activity = try await Self.getActivityData()
        
        let age = if UserDefaults.standard.integer(forKey: StorageKeys.age) == 0 { "unknown" } else {
            String(UserDefaults.standard.integer(forKey: StorageKeys.age))
        }
        let sex = UserDefaults.standard.string(forKey: StorageKeys.sex) ?? "unknown"
        
        
        var combinedData = """
        ## User Health Profile
        
        Age: \(age)
        Sex: \(sex)
        
        """
        
        if !general.isEmpty {
            combinedData.append("""
            
            ### General Health Metrics
            \(general)
            """)
        }
        
        if !vitalAverage.isEmpty {
            combinedData.append("""
            
            ### Average Vital Signs
            \(vitalAverage)
            """)
        }
        if !activity.isEmpty {
            combinedData.append("""
            
            ### Activity Summary
            \(activity)
            """)
        }
        if !workout.isEmpty {
            combinedData.append("""
            
            ### Recent Workouts
            \(workout)
            """)
        }
        if !sleep.isEmpty {
            combinedData.append("""
            
            ### Sleep Patterns
            \(sleep)
            """)
        }
        
        return combinedData
    }
    
    // Active Energy, Resting Energy, Exercise Minutes, Steps, HRV, HRV Stress, Oxygen Saturation, Wrist Temperature, Sleep
    
    static private func getVitalSignsAverage(weeksToAverage: Int = 4) async throws -> String {
        var resultText = ""
        let weeksPerYear = 52
        
        // Heart Rate
        let heartRateAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .heartRate, weeksToAverage: weeksToAverage)
        if let value = heartRateAvg.0 {
            resultText += "Heart Rate (avg over \(weeksToAverage) weeks): \(Int(value)) bpm)\n"
            
            // Compare to average
            let heartRateAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .heartRate, weeksToAverage: weeksPerYear)
            if let avgValue = heartRateAvgYear.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue)) bpm)\n"
            }
        }
        
        // Resting Heart Rate
        let restingHRAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .restingHeartRate, weeksToAverage: weeksToAverage)
        if let value = restingHRAvg.0 {
            resultText += "Resting Heart Rate (avg over \(weeksToAverage) weeks): \(Int(value)) bpm\n"
            
            // Compare to average
            let restingHRAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .restingHeartRate, weeksToAverage: weeksPerYear)
            if let avgValue = restingHRAvgYear.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue)) bpm)\n"
            }
        }
        
        // Blood Pressure (systolic and diastolic)
        let systolicAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .bloodPressureSystolic, weeksToAverage: weeksToAverage)
        let diastolicAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .bloodPressureDiastolic, weeksToAverage: weeksToAverage)
        
        if let sys = systolicAvg.0, let dia = diastolicAvg.0 {
            resultText += "Blood Pressure (avg over \(weeksToAverage) weeks): \(Int(sys))/\(Int(dia)) mmHg\n"
            
            // Compare to average
            let systolicAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .bloodPressureSystolic, weeksToAverage: weeksPerYear)
            let diastolicAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .bloodPressureDiastolic, weeksToAverage: weeksPerYear)
            if let sysYear = systolicAvgYear.0, let diaYear = diastolicAvgYear.0 {
                let percentDiff = (((sys + dia) - (sysYear + diaYear)) / (sysYear + diaYear)) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(sysYear))/\(Int(diaYear)) mmHg)\n"
            }
        }
        
        // Oxygen Saturation
        let oxygenAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .oxygenSaturation, weeksToAverage: weeksToAverage)
        if let value = oxygenAvg.0 {
            resultText += "Oxygen Saturation (avg over \(weeksToAverage) weeks): \(Int(value * 100)) %\n"
            
            // Compare to average
            let oxygenAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .oxygenSaturation, weeksToAverage: weeksPerYear)
            if let avgValue = oxygenAvgYear.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue * 100)) %)\n"
            }
        }
        
        // Respiratory Rate
        let respiratoryAvg = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .respiratoryRate, weeksToAverage: weeksToAverage)
        if let value = respiratoryAvg.0 {
            resultText += "Respiratory Rate (avg over \(weeksToAverage) weeks): \(Int(value)) breaths/min\n"
            
            // Compare to average
            let respiratoryAvgYear = try await HealthDataFetcher.shared.getAverageQuantityValue(for: .respiratoryRate, weeksToAverage: weeksPerYear)
            if let avgValue = respiratoryAvgYear.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue)) breaths/min)\n"
            }
        }
        
        return resultText
    }
    
    static private func getGeneralHealthMetrics() async throws -> String {
        var resultText = ""
        
        // Weight
        let weight = try await HealthDataFetcher.shared.getLatestQuantityValue(for: .bodyMass, maxMonthRange: 12)
        if let value = weight.0 {
            resultText += "Weight: \(String(format: "%.1f", value)) kg / \(String(format: "%.1f", value * 2.20462)) lbs (measured \(ToStringHelper.timeAgoString(from: weight.2)))\n"
        }
        
        // BMI
        let bmi = try await HealthDataFetcher.shared.getLatestQuantityValue(for: .bodyMassIndex, maxMonthRange: 12)
        if let value = bmi.0 {
            resultText += "BMI: \(String(format: "%.1f", value)) (measured \(ToStringHelper.timeAgoString(from: bmi.2)))\n"
        }
        
        // Body Fat Percentage
        let bodyFat = try await HealthDataFetcher.shared.getLatestQuantityValue(for: .bodyFatPercentage, maxMonthRange: 12)
        if let value = bodyFat.0 {
            resultText += "Body Fat: \(String(format: "%.1f", value * 100))% (measured \(ToStringHelper.timeAgoString(from: bodyFat.2)))\n"
        }
        
        // Height
        let height = try await HealthDataFetcher.shared.getLatestQuantityValue(for: .height, maxMonthRange: 12)
        if let value = height.0 {
            resultText += "Height: \(String(format: "%.2f", value)) m / \(String(format: "%.1f", value * 3.28084)) ft (measured \(ToStringHelper.timeAgoString(from: height.2)))\n"
        }
        
        return resultText
    }
    
    static private func getActivityData() async throws -> String {
        var resultText = ""
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.startOfDay(for: .now)))!
        
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: startOfDay)!
        
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay))!
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: startOfWeek)!
        let daysPerMonth = 30.0
            
        
        // DAILY ACTIVITY METRICS
        resultText += "\n#### Last 14-Day's Average Activity Per Day\n"
        
        // Steps
        let dailySteps = try await HealthDataFetcher.shared.getAverageQuantity(for: .stepCount, startDate: fourteenDaysAgo, endDate: startOfDay, intervalType: .day)
        if let value = dailySteps.0 {
            resultText += "Steps: \(Int(value).formattedWithSeparator)\n"
            
            // Compare to daily average
            let avgDailySteps = try await HealthDataFetcher.shared.getAverageQuantity(for: .stepCount, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailySteps.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue).formattedWithSeparator) steps)\n"
            }
        }
        
        // Distance
        let dailyDistance = try await HealthDataFetcher.shared.getAverageQuantity(for: .distanceWalkingRunning, startDate: fourteenDaysAgo, endDate: today, intervalType: .day)
        if let value = dailyDistance.0 {
            let kilometers = value / 1000 // Convert meters to km
            resultText += "Distance: \(String(format: "%.2f", kilometers)) km\n"
            
            // Compare to daily average
            let avgDailyDistance = try await HealthDataFetcher.shared.getAverageQuantity(for: .distanceWalkingRunning, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyDistance.0 {
                let avgKilometers = avgValue / 1000 // Convert meters to km
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.2f", avgKilometers)) km)\n"
            }
        }
        
        // Active Energy
        let dailyActiveEnergy = try await HealthDataFetcher.shared.getAverageQuantity(for: .activeEnergyBurned, startDate: fourteenDaysAgo, endDate: today, intervalType: .day)
        if let value = dailyActiveEnergy.0 {
            resultText += "Active calories: \(Int(value).formattedWithSeparator) kcal\n"
            
            // Compare to daily average
            let avgDailyActiveEnergy = try await HealthDataFetcher.shared.getAverageQuantity(for: .activeEnergyBurned, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyActiveEnergy.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue).formattedWithSeparator) kcal)\n"
            }
        }
        
        // Resting Energy
        let dailyRestingEnergy = try await HealthDataFetcher.shared.getAverageQuantity(for: .basalEnergyBurned, startDate: fourteenDaysAgo, endDate: startOfDay, intervalType: .day)
        if let value = dailyRestingEnergy.0 {
            resultText += "Resting calories: \(Int(value).formattedWithSeparator) kcal\n"
            
            // Compare to daily average
            let avgDailyRestingEnergy = try await HealthDataFetcher.shared.getAverageQuantity(for: .basalEnergyBurned, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyRestingEnergy.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgValue).formattedWithSeparator) kcal)\n"
            }
        }
        
        // Stand Hours
        let standTime = try await HealthDataFetcher.shared.getAverageQuantity(for: .appleStandTime, startDate: fourteenDaysAgo, endDate: startOfDay, intervalType: .day)
        if let value = standTime.0 {
            let standHours = Int(value / 3600) // Convert seconds to hours
            resultText += "Stand hours: \(standHours) h\n"
            
            // Compare to daily average
            let avgDailyStandTime = try await HealthDataFetcher.shared.getAverageQuantity(for: .appleStandTime, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyStandTime.0 {
                let avgStandHours = avgValue / 3600 // Convert seconds to hours
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.1f", avgStandHours)) hours)\n"
            }
        }
        
        // Exercise Minutes
        let exerciseTime = try await HealthDataFetcher.shared.getAverageQuantity(for: .appleExerciseTime, startDate: fourteenDaysAgo, endDate: startOfDay, intervalType: .day)
        if let value = exerciseTime.0 {
            let exerciseMinutes = Int(value / 60) // Convert seconds to minutes
            resultText += "Exercise minutes: \(exerciseMinutes)\n"
            
            // Compare to daily average
            let avgDailyExerciseTime = try await HealthDataFetcher.shared.getAverageQuantity(for: .appleExerciseTime, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyExerciseTime.0 {
                let avgExerciseMinutes = avgValue / 60 // Convert seconds to minutes
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(Int(avgExerciseMinutes)) min)\n"
            }
        }
        
        // Flights Climbed
        let flightsClimbed = try await HealthDataFetcher.shared.getAverageQuantity(for: .flightsClimbed, startDate: fourteenDaysAgo, endDate: startOfDay, intervalType: .day)
        if let value = flightsClimbed.0 {
            resultText += "Flights climbed: \(Int(value))\n"
            
            // Compare to daily average
            let avgDailyFlightsClimbed = try await HealthDataFetcher.shared.getAverageQuantity(for: .flightsClimbed, startDate: oneYearAgo, endDate: startOfDay, intervalType: .day)
            if let avgValue = avgDailyFlightsClimbed.0 {
                let percentDiff = ((value - avgValue) / avgValue) * 100
                resultText += "\t\(percentDiff >= 0 ? "+" : "")\(Int(percentDiff))% vs 1-year avg (\(String(format: "%.1f", avgValue)) flights)\n"
            }
        }
        
        
        // MONTHLY TRENDS
        resultText += "\n#### Monthy Trends\n"
        
        let monthlyTrendsSteps = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .stepCount, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nStep Counts:\n"
        for monthData in monthlyTrendsSteps {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) steps\n"
            }
        }
        
        let monthlyTrendsDistance = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .distanceWalkingRunning, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nDistance:\n"
        for monthData in monthlyTrendsDistance {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth / 1000).formattedWithSeparator) km\n"
            }
        }
        
        let monthlyTrendsActiveEnergy = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .activeEnergyBurned, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nActive Energy:\n"
        for monthData in monthlyTrendsActiveEnergy {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) kcal\n"
            }
        }
        
        let monthlyTrendsBasalEnergy = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .basalEnergyBurned, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nBasal Energy:\n"
        for monthData in monthlyTrendsBasalEnergy {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) kcal\n"
            }
        }
        
        let monthlyTrendsStandTime = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .appleStandTime, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nStand Time:\n"
        for monthData in monthlyTrendsStandTime {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) h\n"
            }
        }
        
        let monthlyTrendsExerciseTime = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .appleExerciseTime, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nExercise Time:\n"
        for monthData in monthlyTrendsExerciseTime {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) min\n"
            }
        }
        
        let monthlyTrendsFlightsClimbed = try await HealthDataFetcher.shared.getPeriodicQuantities(for: .flightsClimbed, startDate: oneYearAgo, endDate: startOfMonth, intervalType: .month)
        resultText += "\nFlights climbed:\n"
        for monthData in monthlyTrendsFlightsClimbed {
            if let value = monthData.value {
                resultText += "\(monthData.date.formatted(Date.FormatStyle().month(.wide))): \(Int(value / daysPerMonth).formattedWithSeparator) flights\n"
            }
        }
        
        return resultText
    }
    
    static private func getRecentWorkouts(maxDayRange: Int = 30) async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -maxDayRange, to: Date())!
        let endDate = Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { query, samples, error in
                var resultText = ""
                
                guard let workouts = samples as? [HKWorkout], error == nil, !workouts.isEmpty else {
                    continuation.resume(returning: "")
                    return
                }
                
                resultText += "Last \(workouts.count) workouts (past \(maxDayRange) days):\n"
                
                for (index, workout) in workouts.enumerated() {
                    let workoutType = workout.workoutActivityType.name ?? "Unknown Workout"
                    let duration = Int(workout.duration / 60)
                    let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    let date = workout.endDate
                    
                    resultText += "\(index + 1). \(workoutType) - \(date.formatted(.iso8601))\n"
                    resultText += "   Duration: \(duration) min, Calories: \(Int(calories)) kcal"
                    
                    if distance > 0 {
                        if distance >= 1000 {
                            resultText += ", Distance: \(String(format: "%.2f", distance/1000)) km"
                        } else {
                            resultText += ", Distance: \(Int(distance)) m"
                        }
                    }
                    resultText += "\n"
                    
                    if let heartRateData = workout.metadata?[HKPredicateKeyPathAverageHeartRate] as? Double {
                        resultText += "   Avg HR: \(Int(heartRateData)) bpm\n"
                    }
                }
                
                let workoutCounts = Dictionary(grouping: workouts, by: { $0.workoutActivityType })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                resultText += "\nWorkout breakdown (\(maxDayRange) days):\n"
                for (type, count) in workoutCounts {
                    resultText += "- \(type.name ?? "Unknown Workout"): \(count) sessions\n"
                }
                
                let totalWorkoutTime = workouts.reduce(0) { $0 + $1.duration }
                resultText += "Total workout time: \(Int(totalWorkoutTime / 60)) minutes\n"
                
                continuation.resume(returning: resultText)
            }
            HealthDataFetcher.shared.healthStore.execute(query)
        }
    }
    
    static private func getSleepData() async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -14, to: Date())!
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
    
    static private func getNutritionData() async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        var resultText = ""
        
        // Calories
        let calories = try await HealthDataFetcher.shared.getAverageQuantity(for: .dietaryEnergyConsumed, startDate: startDate, endDate: endDate)
        if let value = calories.0 {
            resultText += "- Calories: \(Int(value)) kcal/day\n"
        }
        
        // Protein
        let protein = try await HealthDataFetcher.shared.getAverageQuantity(for: .dietaryProtein, startDate: startDate, endDate: endDate)
        if let value = protein.0 {
            resultText += "- Protein: \(Int(value)) g/day\n"
        }
        
        // Carbohydrates
        let carbs = try await HealthDataFetcher.shared.getAverageQuantity(for: .dietaryCarbohydrates, startDate: startDate, endDate: endDate)
        if let value = carbs.0 {
            resultText += "- Carbohydrates: \(Int(value)) g/day\n"
        }
        
        // Fat
        let fat = try await HealthDataFetcher.shared.getAverageQuantity(for: .dietaryFatTotal, startDate: startDate, endDate: endDate)
        if let value = fat.0 {
            resultText += "- Fat: \(Int(value)) g/day\n"
        }
        
        // Water
        let water = try await HealthDataFetcher.shared.getAverageQuantity(for: .dietaryWater, startDate: startDate, endDate: endDate)
        if let value = water.0 {
            let waterInLiters = value / 1000
            resultText += "- Water: \(String(format: "%.1f", waterInLiters)) L/day\n"
        }
        
        
        if resultText.isEmpty {
            return ""
        } else {
            return """
            Nutrition (past 7 days average):
            \(resultText)
            """
        }
    }
}

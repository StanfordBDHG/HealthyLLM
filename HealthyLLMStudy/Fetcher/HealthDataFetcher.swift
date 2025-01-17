//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
import os


class HealthDataFetcher: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "HealthDataFetcher")
    @ObservationIgnored let healthStore = HKHealthStore()
    
    required init() { }
    
    /// Ask for authorization of all possible `HKQuantityTypeIdentifiers`.
    func askForAuthorization() async throws {
        let readTypes = Set([
            HKSeriesType.activitySummaryType(),
            HKSeriesType.workoutRoute(),
            HKSeriesType.workoutType()
        ]).union(
            Set(HKQuantityTypeIdentifier.importantHealthIdentifiers.map { HKQuantityType($0) })
        )
        
        try await healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        )
    }
    
    
    // MARK: - Function Calls
    
    func fetchHealth(string: String) async -> [HealthData] {
        guard let identifier = HKQuantityTypeIdentifier.from(string) else {
            return []
        }
        return await fetchHealthLastTwoWeeks(for: identifier)
    }
    
    func fetchWorkout(string: String) async -> [WorkoutData] {
        guard let identifier = stringToHKWorkoutActivityType(string: string) else {
            return []
        }
        return await fetchWorkoutLastTwoWeeks(for: identifier)
    }
    
    // MARK: - Context Window
    func fetchAllHealthLastTwoWeeks() async -> [[HealthData]] {
        let calendar = Calendar.current
        let today = Date()
        var data: [[HealthData]] = []

        for day in 1...7 {
            guard let endDate = calendar.date(byAdding: .day, value: -day, to: today) else { continue }
            
            let allHealthDataThisDay = await fetchAllHealthForDate(date: endDate)
            data.append(allHealthDataThisDay)
        }
        
        return data
    }
    
    func fetchAllWorkoutsLastTwoWeeks() async -> [WorkoutData] {
        // call fetchWorkoutLastTwoWeeks with nil in predicate to fetch all workouts happend in last two weeks
        guard let workouts = try? await fetchAllWorkoutSamples(start: .startOfDay, end: Date.daysAgo(14)) else {
            return []
        }
        return workouts
    }
    
    // MARK: - Private Functions
    
    /// Returns the health data for the last two weeks
    private func fetchHealthLastTwoWeeks(for identifier: HKQuantityTypeIdentifier) async -> [HealthData] {
        guard let siUnit = identifier.siUnit else {
            return []
        }
        
        let calendar = Calendar.current
        var data: [HealthData] = []
        let today = Date()
        
        for day in 1...14 {
            guard let day = calendar.date(byAdding: .day, value: -day, to: today),
                  let sample = try? await fetchHealthSample(for: identifier, unit: siUnit, startDate: day.startOfDay, endDate: day.endOfDay) else { continue }
            
            data.append(
                .init(
                    identifier: identifier.rawValue,
                    displayName: identifier.displayName,
                    description: identifier.description ?? identifier.rawValue,
                    date: day,
                    value: sample,
                    unit: siUnit.unitString
                )
            )
        }
        return data
    }
    
    private func fetchWorkoutLastTwoWeeks(for identifier: HKWorkoutActivityType) async -> [WorkoutData] {
        guard let samples = try? await fetchWorkoutSample(for: identifier, limit: 14) else {
            return []
        }
        
        return samples
    }
    
    
    
    private func fetchAllHealthForDate(date: Date) async -> [HealthData] {
        var data: [HealthData] = []
        
        for identifier in HKQuantityTypeIdentifier.importantHealthIdentifiers {
            guard let siUnit = identifier.siUnit,
                  let sample = try? await fetchHealthSample(for: identifier, unit: siUnit, startDate: date.startOfDay, endDate: date.endOfDay) else {
                continue
            }
            
            data.append(
                .init(
                    identifier: identifier.rawValue,
                    displayName: identifier.displayName,
                    description: identifier.description ?? identifier.rawValue,
                    date: date,
                    value: sample,
                    unit: siUnit.unitString
                )
            )
        }
        
        return data
    }
    
    private func fetchHealthSample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, startDate: Date, endDate: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictEndDate
        )
        
        let quantityType = HKQuantityType(identifier)
        
        let statisticsOptions = switch quantityType.aggregationStyle {
        case .cumulative:
            HKStatisticsOptions.cumulativeSum
        case .discreteArithmetic, .discreteTemporallyWeighted:
            HKStatisticsOptions.discreteAverage
        default:
            throw HealthDataFetcherError.unsupportedAggregationStyle
        }
        
        let sample: Double = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: statisticsOptions
            ) { _, statistics, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statistics = statistics else {
                    continuation.resume(throwing: HealthDataFetcherError.noValueAvailable)
                    return
                }
                
                switch quantityType.aggregationStyle {
                case .cumulative:
                    if let sum = statistics.sumQuantity() {
                        let result = sum.doubleValue(for: unit).rounded()
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: HealthDataFetcherError.noValueAvailable)
                    }
                case .discreteArithmetic, .discreteTemporallyWeighted:
                    if let average = statistics.averageQuantity() {
                        let result = average.doubleValue(for: unit).rounded()
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: HealthDataFetcherError.noValueAvailable)
                    }
                default:
                    continuation.resume(throwing: HealthDataFetcherError.unsupportedAggregationStyle)
                }
            }
            
            healthStore.execute(query)
        }
        
        return sample
    }
    
    private func fetchAllWorkoutSamples(start: Date, end: Date) async throws -> [WorkoutData] {
        return try await fetchWorkoutSample(predicate: nil, limit: 14)
    }
    
    private func fetchWorkoutSample(for identifier: HKWorkoutActivityType, limit: Int = 14) async throws -> [WorkoutData] {
        let predicate = HKQuery.predicateForWorkouts(with: identifier)
        return try await fetchWorkoutSample(predicate: predicate, limit: limit)
    }
    
    private func fetchWorkoutSample(predicate: NSPredicate?, limit: Int = HKObjectQueryNoLimit) async throws -> [WorkoutData] {
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            healthStore.execute(
                HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [.init(keyPath: \HKSample.startDate, ascending: false)],
                    resultsHandler: { query, samples, error in
                        if let hasError = error {
                            continuation.resume(throwing: hasError)
                            return
                        }
                        
                        guard let samples = samples else {
                            fatalError("*** Invalid State: This can only fail if there was an error. ***")
                        }
                        
                        continuation.resume(returning: samples)
                    })
            )
        }
        
        guard let workouts = samples as? [HKWorkout] else {
            throw HealthDataFetcherError.resultsNotFound
        }
        
        var result: [WorkoutData] = []
        
        for workout in workouts {
            var stats: [String: String] = [:]
            
            for quantityType in workout.allStatistics.keys {
                guard let statistics = workout.allStatistics[quantityType],
                      let identifier = HKQuantityTypeIdentifier.from(quantityType.identifier),
                      let unit = identifier.siUnit else { continue }
                
                let shortIdentifier = quantityType.identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
                
                switch quantityType.aggregationStyle {
                case .cumulative:
                    if let sum = statistics.sumQuantity() {
                        let result = sum.doubleValue(for: unit)
                        stats[shortIdentifier] = "\(result.rounded()) \(unit)"
                    }
                case .discreteArithmetic, .discreteTemporallyWeighted:
                    if let average = statistics.averageQuantity() {
                        let result = average.doubleValue(for: unit)
                        stats[shortIdentifier] = "\(result.rounded()) \(unit)"
                    }
                default:
                    continue
                }
            }
            
            result.append(
                .init(
                    name: workout.workoutActivityType.name ?? "N/A",
                    date: workout.startDate.formatted(date: .abbreviated, time: .shortened),
                    duration: Duration.seconds(workout.duration).formatted(),
                    statistics: stats
                )
            )
        }
        
        return result
    }
    
    
    
    /// Fetches the user's sleep data for the last two weeks.
    ///
    /// - Returns: An array of `Double` values representing daily sleep duration in hours.
    /// - Throws: `HealthDataFetcherError` if the data cannot be fetched.
    private func fetchLastTwoWeeksSleep() async throws -> [Double] {
        var dailySleepData: [Double] = []
        
        // We go through all possible days in the last two weeks.
        for day in -14..<0 {
            // We start the calculation at 3 PM the previous day to 3 PM on the day in question.
            guard let startOfSleepDay = Calendar.current.date(byAdding: DateComponents(day: day - 1), to: Date.startOfDay),
                  let startOfSleep = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: startOfSleepDay),
                  let endOfSleepDay = Calendar.current.date(byAdding: DateComponents(day: day), to: Date.startOfDay),
                  let endOfSleep = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: endOfSleepDay) else {
                dailySleepData.append(0)
                continue
            }
            
            
            let sleepType = HKCategoryType(.sleepAnalysis)

            let dateRangePredicate = HKQuery.predicateForSamples(withStart: startOfSleep, end: endOfSleep, options: .strictEndDate)
            let allAsleepValuesPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: HKCategoryValueSleepAnalysis.allAsleepValues)
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dateRangePredicate, allAsleepValuesPredicate])

            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: sleepType, predicate: compoundPredicate)],
                sortDescriptors: []
            )
            
            let results = try await descriptor.result(for: healthStore)

            var secondsAsleep = 0.0
            for result in results {
                secondsAsleep += result.endDate.timeIntervalSince(result.startDate)
            }
            
            // Append the hours of sleep for that date
            dailySleepData.append(secondsAsleep / (60 * 60))
        }
        
        return dailySleepData
    }
}

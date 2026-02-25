//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import os
import Spezi

// swiftlint:disable all
class HealthDataFetcher {
    static let shared = HealthDataFetcher()
    
    let logger = Logger(subsystem: "HealthyLLMStudy", category: "HealthDataFetcher")
    let healthStore = HKHealthStore()
    let calendar = Calendar.current
    
    required init() { }
    
    // MARK: Initialization
    
    /// Ask for authorization of all possible `HKQuantityTypeIdentifiers`.
    func askForAuthorization() async throws {
        var typesToRead: Set<HKObjectType> = [
            // HKSeriesType
            HKSeriesType.heartbeat(),
            HKSeriesType.activitySummaryType(),
            HKSeriesType.audiogramSampleType(),
            HKSeriesType.electrocardiogramType(),
            HKSeriesType.stateOfMindType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.workoutType()
        ]
        
        // HKCategoryTypeIdentifier
        for categoryIdentifier in allCategoryTypeIdenfier {
            if let type = HKObjectType.categoryType(forIdentifier: categoryIdentifier) {
                typesToRead.insert(type)
            }
        }
        
        // HKQuantityTypeIdentifier
        for typeIdentifier in allQuantityTypeIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: typeIdentifier) {
                typesToRead.insert(type)
            }
        }
        
        try await healthStore.requestAuthorization(
            toShare: [],
            read: typesToRead
        )
    }
    
    // MARK: Utils
    
    func fetchOldestOverallSample() async -> [String: Date] {
        func fetchOldestSample(for sampleType: HKSampleType, identifier: String, healthStore: HKHealthStore) async -> (sample: HKSample?, identifier: String) {
            await withCheckedContinuation { continuation in
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                let query = HKSampleQuery(sampleType: sampleType,
                                          predicate: nil,
                                          limit: 1,
                                          sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Error fetching \(identifier): \(error.localizedDescription)")
                        continuation.resume(returning: (nil, identifier))
                    } else {
                        continuation.resume(returning: (samples?.first, identifier))
                    }
                }
                healthStore.execute(query)
            }
        }
        
        // We'll collect results as (sample, identifier)
        var results: [(HKSample, String)] = []
        
        await withTaskGroup(of: (HKSample?, String).self) { group in
            // Query quantity types.
            for quantityIdentifier in allQuantityTypeIdentifiers {
                if let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) {
                    group.addTask {
                        await fetchOldestSample(for: quantityType,
                                                       identifier: quantityIdentifier.rawValue,
                                                       healthStore: self.healthStore)
                    }
                }
            }
            // Query category types.
            for categoryIdentifier in allCategoryTypeIdenfier {
                if let categoryType = HKObjectType.categoryType(forIdentifier: categoryIdentifier) {
                    group.addTask {
                        await fetchOldestSample(for: categoryType,
                                                       identifier: categoryIdentifier.rawValue,
                                                       healthStore: self.healthStore)
                    }
                }
            }
            // Query workouts.
            let workoutType = HKObjectType.workoutType()
            group.addTask {
                await fetchOldestSample(for: workoutType,
                                               identifier: "HKWorkoutTypeIdentifier",
                                               healthStore: self.healthStore)
            }
            
            // Gather all non-nil samples.
            for await (sampleOpt, identifier) in group {
                if let sample = sampleOpt {
                    results.append((sample, identifier))
                }
            }
        }
        
        // Now find the overall oldest sample.
        var oldestIdentifier: String?
        var oldestDate: Date?
        for (sample, identifier) in results {
            let sampleDate = sample.startDate
            if oldestDate == nil || sampleDate < oldestDate! {
                oldestDate = sampleDate
                oldestIdentifier = identifier
            }
        }
        
        if let oldestIdentifier, let oldestDate {
            return [oldestIdentifier: oldestDate]
        } else {
            return [:]
        }
    }
    

    func countAllHealthKitData() async -> [String: Int] {
        // Helper function that wraps HKSampleQuery in an async call.
        func fetchSampleCount(for sampleType: HKSampleType) async throws -> Int {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples?.count ?? 0)
                    }
                }
                healthStore.execute(query)
            }
        }
        
        
        var results = [String: Int]()

        // Use a task group to run queries concurrently.
        await withTaskGroup(of: (String, Int)?.self) { group in
            // Count quantity types.
            for typeIdentifier in allQuantityTypeIdentifiers {
                if let type = HKObjectType.quantityType(forIdentifier: typeIdentifier) {
                    group.addTask {
                        do {
                            let count = try await fetchSampleCount(for: type)
                            return (typeIdentifier.rawValue, count)
                        } catch {
                            print("Error fetching \(typeIdentifier.rawValue): \(error.localizedDescription)")
                            return nil
                        }
                    }
                }
            }
            
            // Count category types.
            for typeIdentifier in allCategoryTypeIdenfier {
                if let type = HKObjectType.categoryType(forIdentifier: typeIdentifier) {
                    group.addTask {
                        do {
                            let count = try await fetchSampleCount(for: type)
                            return (typeIdentifier.rawValue, count)
                        } catch {
                            print("Error fetching \(typeIdentifier.rawValue): \(error.localizedDescription)")
                            return nil
                        }
                    }
                }
            }
            
            // Count workouts.
            group.addTask {
                let workoutType = HKObjectType.workoutType()
                do {
                    let count = try await fetchSampleCount(for: workoutType)
                    return ("HKWorkoutTypeIdentifier", count)
                } catch {
                    print("Error fetching workouts: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // Gather all results.
            for await result in group {
                if let (key, count) = result {
                    results[key] = count
                }
            }
        }
        
        return results
    }
    
    
    // MARK: Helper Functions
    
    
    func getAverageQuantity(for typeIdentifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date, intervalType: Calendar.Component) async throws -> (Double?, String) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            throw NSError(domain: "com.healthdatamanager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create an anchor date at the start of the day
            let calendar = Calendar.current
            let anchorDate = calendar.startOfDay(for: startDate)
            
            // Set up the interval components
            var intervalComponents = DateComponents()
            switch intervalType {
            case .day:
                intervalComponents.day = 1
            case .weekOfYear:
                intervalComponents.weekOfYear = 1
            case .month:
                intervalComponents.month = 1
            default:
                intervalComponents.day = 1
            }
            
            // Create the predicate
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
            
            // Create the query
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: intervalComponents
            )
            
            // Set the results handler
            query.initialResultsHandler = { _, results, error in
                guard let results = results, error == nil else {
                    continuation.resume(returning: (nil, "No data available"))
                    return
                }
                
                var totalSum: Double = 0
                var count: Int = 0
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        var value: Double = 0
                        
                        switch typeIdentifier {
                        case .stepCount:
                            value = sum.doubleValue(for: .count())
                        case .distanceWalkingRunning:
                            value = sum.doubleValue(for: .meter())
                        case .activeEnergyBurned, .basalEnergyBurned:
                            value = sum.doubleValue(for: .kilocalorie())
                        case .appleStandTime, .appleExerciseTime:
                            value = sum.doubleValue(for: .second())
                        case .flightsClimbed:
                            value = sum.doubleValue(for: .count())
                        default:
                            value = sum.doubleValue(for: .count())
                        }
                        
                        totalSum += value
                        count += 1
                    }
                }
                
                var unitString = ""
                switch typeIdentifier {
                case .stepCount:
                    unitString = "steps"
                case .distanceWalkingRunning:
                    unitString = "m"
                case .activeEnergyBurned, .basalEnergyBurned:
                    unitString = "kcal"
                case .appleStandTime, .appleExerciseTime:
                    unitString = "seconds"
                case .flightsClimbed:
                    unitString = "flights"
                default:
                    unitString = "units"
                }
                
                let average = count > 0 ? totalSum / Double(count) : nil
                continuation.resume(returning: (average, unitString))
            }
            
            healthStore.execute(query)
        }
    }
    
    enum CalculationMethod {
        case sum
        case average
    }
    
    func getPeriodicQuantities(for typeIdentifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date, intervalType: Calendar.Component) async throws -> [(date: Date, value: Double?)] {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
                throw NSError(domain: "com.healthdatamanager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                // Create an anchor date at the start of the day
                let calendar = Calendar.current
                let anchorDate = calendar.startOfDay(for: startDate)
                
                // Set up the interval components
                var intervalComponents = DateComponents()
                switch intervalType {
                case .day:
                    intervalComponents.day = 1
                case .weekOfYear:
                    intervalComponents.weekOfYear = 1
                case .month:
                    intervalComponents.month = 1
                default:
                    intervalComponents.day = 1
                }
                
                // Create the predicate
                let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
                
                // Create the query
                let query = HKStatisticsCollectionQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum,
                    anchorDate: anchorDate,
                    intervalComponents: intervalComponents
                )
                
                // Set the results handler
                query.initialResultsHandler = { _, results, error in
                    guard let results = results, error == nil else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    var periodicData: [(date: Date, value: Double?)] = []
                    
                    results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                        var value: Double?
                        
                        if let sum = statistics.sumQuantity() {
                            switch typeIdentifier {
                            case .stepCount:
                                value = sum.doubleValue(for: .count())
                            case .distanceWalkingRunning:
                                value = sum.doubleValue(for: .meter())
                            case .activeEnergyBurned, .basalEnergyBurned:
                                value = sum.doubleValue(for: .kilocalorie())
                            case .appleStandTime, .appleExerciseTime:
                                value = sum.doubleValue(for: .second())
                            case .flightsClimbed:
                                value = sum.doubleValue(for: .count())
                            default:
                                value = sum.doubleValue(for: .count())
                            }
                        }
                        
                        periodicData.append((date: statistics.startDate, value: value))
                    }
                    
                    // Sort by date (newest first)
                    periodicData.sort { $0.date > $1.date }
                    
                    continuation.resume(returning: periodicData)
                }
                
                healthStore.execute(query)
            }
        }
    
    func getLatestQuantityValue(for typeIdentifier: HKQuantityTypeIdentifier, maxMonthRange: Int = 1) async throws -> (Double?, String, Date) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            throw NSError(domain: "com.healthdatamanager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: calendar.date(byAdding: .month, value: -maxMonthRange, to: Date()), end: nil, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: (nil, "No sample available", .now))
                    return
                }
                
                var unitString = ""
                var value: Double = 0
                
                switch typeIdentifier {
                case .heartRate, .restingHeartRate:
                    value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    unitString = "bpm"
                case .bloodPressureSystolic, .bloodPressureDiastolic:
                    value = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    unitString = "mmHg"
                case .respiratoryRate:
                    value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    unitString = "breaths/min"
                case .oxygenSaturation:
                    value = sample.quantity.doubleValue(for: HKUnit.percent())
                    unitString = "%"
                case .bodyTemperature:
                    value = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                    unitString = "°C"
                case .bodyMass:
                    value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    unitString = "kg"
                case .bodyMassIndex:
                    value = sample.quantity.doubleValue(for: HKUnit.count())
                    unitString = "BMI"
                case .bodyFatPercentage:
                    value = sample.quantity.doubleValue(for: HKUnit.percent())
                    unitString = "%"
                case .height:
                    value = sample.quantity.doubleValue(for: HKUnit.meter())
                    unitString = "m"
                default:
                    value = sample.quantity.doubleValue(for: HKUnit.count())
                    unitString = "units"
                }
                
                continuation.resume(returning: (value, unitString, sample.endDate))
            }
            healthStore.execute(query)
        }
    }

    func getAverageQuantityValue(for typeIdentifier: HKQuantityTypeIdentifier, weeksToAverage: Int) async throws -> (Double?, String, Date) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            throw NSError(domain: "com.healthdatamanager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
        }
        
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeksToAverage, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                guard let statistics = statistics, error == nil else {
                    continuation.resume(returning: (nil, "No data available", .now))
                    return
                }
                
                guard let average = statistics.averageQuantity() else {
                    continuation.resume(returning: (nil, "No average available", .now))
                    return
                }
                
                var unitString = ""
                var value: Double = 0
                
                switch typeIdentifier {
                case .heartRate, .restingHeartRate:
                    value = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    unitString = "bpm"
                case .bloodPressureSystolic, .bloodPressureDiastolic:
                    value = average.doubleValue(for: HKUnit.millimeterOfMercury())
                    unitString = "mmHg"
                case .respiratoryRate:
                    value = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    unitString = "breaths/min"
                case .oxygenSaturation:
                    value = average.doubleValue(for: HKUnit.percent())
                    unitString = "%"
                case .bodyTemperature:
                    value = average.doubleValue(for: HKUnit.degreeCelsius())
                    unitString = "°C"
                case .bodyMass:
                    value = average.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    unitString = "kg"
                case .bodyMassIndex:
                    value = average.doubleValue(for: HKUnit.count())
                    unitString = "BMI"
                case .bodyFatPercentage:
                    value = average.doubleValue(for: HKUnit.percent())
                    unitString = "%"
                case .height:
                    value = average.doubleValue(for: HKUnit.meter())
                    unitString = "m"
                default:
                    value = average.doubleValue(for: HKUnit.count())
                    unitString = "units"
                }
                
                continuation.resume(returning: (value, unitString, Date()))
            }
            
            healthStore.execute(query)
        }
    }
    
    func getSumQuantity(for typeIdentifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date) async throws -> (Double?, String) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            throw NSError(domain: "com.healthdatamanager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                guard let result = result, let sum = result.sumQuantity(), error == nil else {
                    continuation.resume(returning: (nil, "No sample available"))
                    return
                }
                
                var unitString = ""
                var value: Double = 0
                
                switch typeIdentifier {
                case .stepCount:
                    value = sum.doubleValue(for: HKUnit.count())
                    unitString = "steps"
                case .activeEnergyBurned, .basalEnergyBurned:
                    value = sum.doubleValue(for: HKUnit.kilocalorie())
                    unitString = "kcal"
                case .appleStandTime, .appleExerciseTime:
                    value = sum.doubleValue(for: HKUnit.second())
                    unitString = "seconds"
                case .distanceWalkingRunning:
                    value = sum.doubleValue(for: HKUnit.meter())
                    unitString = "meters"
                default:
                    value = sum.doubleValue(for: HKUnit.count())
                    unitString = "units"
                }
                
                continuation.resume(returning: (value, unitString))
            }
            healthStore.execute(query)
        }
    }
    
    func getAverageQuantity(for typeIdentifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date) async throws -> (Double?, String) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            throw NSError(domain: "healthdatafetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quantity type not available"])
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let options: HKStatisticsOptions = switch quantityType {
            case .init(.dietaryEnergyConsumed), .init(.dietaryProtein), .init(.dietaryCarbohydrates), .init(.dietaryFatTotal), .init(.dietaryWater):
                    .cumulativeSum
            default:
                    .discreteAverage
            }
            
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { _, result, error in
                guard let result = result, error == nil else {
                    continuation.resume(returning: (nil, "No sample available"))
                    return
                }
                
                var unitString = ""
                var value: Double?
                
                if let avgQuantity = result.averageQuantity() {
                    switch typeIdentifier {
                    case .heartRate, .restingHeartRate:
                        value = avgQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        unitString = "bpm"
                    case .bloodPressureSystolic, .bloodPressureDiastolic:
                        value = avgQuantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        unitString = "mmHg"
                    case .respiratoryRate:
                        value = avgQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        unitString = "breaths/min"
                    case .oxygenSaturation:
                        value = avgQuantity.doubleValue(for: HKUnit.percent())
                        unitString = "%"
                    case .bodyTemperature:
                        value = avgQuantity.doubleValue(for: HKUnit.degreeCelsius())
                        unitString = "°C"
                    case .bodyMass:
                        value = avgQuantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                        unitString = "kg"
                    case .bodyMassIndex:
                        value = avgQuantity.doubleValue(for: HKUnit.count())
                        unitString = "BMI"
                    case .bodyFatPercentage:
                        value = avgQuantity.doubleValue(for: HKUnit.percent())
                        unitString = "%"
                    case .height:
                        value = avgQuantity.doubleValue(for: HKUnit.meter())
                        unitString = "m"
                    case .dietaryEnergyConsumed:
                        value = avgQuantity.doubleValue(for: HKUnit.kilocalorie())
                        unitString = "kcal"
                    case .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal:
                        value = avgQuantity.doubleValue(for: HKUnit.gram())
                        unitString = "g"
                    case .dietaryWater:
                        value = avgQuantity.doubleValue(for: HKUnit.literUnit(with: .milli))
                        unitString = "ml"
                    default:
                        value = avgQuantity.doubleValue(for: HKUnit.count())
                        unitString = "units"
                    }
                }
                
                continuation.resume(returning: (value, unitString))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Async HealthKit Queries

    // Async function to fetch HKQuantitySamples for a given type and unit; returns an array of (Date, value) tuples.
    func fetchQuantitySamplesAsync(for type: HKQuantityType, startDate: Date, endDate: Date, unit: HKUnit) async throws -> [(date: Date, value: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKQuantitySample] {
                    let result = samples.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }

    // Async function to fetch sleep durations from HKCategorySamples.
    // Returns an array of (Date, durationInSeconds) tuples for sleep samples marked as "asleep".
    func fetchSleepDurationsAsync(startDate: Date, endDate: Date) async throws -> [(date: Date, value: Double)] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create sleep analysis type"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKCategorySample] {
                    // Only consider samples marked as "asleep"
                    let sleepData = samples.filter { $0.value != HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                        .map { (date: $0.startDate, value: $0.endDate.timeIntervalSince($0.startDate)) }
                    continuation.resume(returning: sleepData)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    
    // MARK: Private definitions
    
    
    private let allQuantityTypeIdentifiers: [HKQuantityTypeIdentifier] = [
        // Body Measurements
        .bodyMassIndex,
        .bodyMass,
        .height,
        .bodyFatPercentage,
        .leanBodyMass,
        .waistCircumference,
        
        // Activity
        .stepCount,
        .distanceWalkingRunning,
        .distanceCycling,
        .flightsClimbed,
        
        // Energy
        .basalEnergyBurned,
        .activeEnergyBurned,
        
        // Vitals
        .heartRate,
        .restingHeartRate,
        .bodyTemperature,
        .bloodPressureSystolic,
        .bloodPressureDiastolic,
        .respiratoryRate,
        .oxygenSaturation,
        .bloodGlucose,
        .electrodermalActivity,
        .bloodAlcoholContent,
        .heartRateVariabilitySDNN,
        .vo2Max,
        
        // Dietary (Energy & Nutrients)
        .dietaryEnergyConsumed,
        .dietaryFatTotal,
        .dietaryFatPolyunsaturated,
        .dietaryFatMonounsaturated,
        .dietaryFatSaturated,
        .dietaryCholesterol,
        .dietarySodium,
        .dietaryCarbohydrates,
        .dietaryFiber,
        .dietarySugar,
        .dietaryProtein,
        .dietaryVitaminA,
        .dietaryVitaminB6,
        .dietaryVitaminB12,
        .dietaryVitaminC,
        .dietaryVitaminD,
        .dietaryVitaminE,
        .dietaryVitaminK,
        .dietaryCalcium,
        .dietaryIron,
        .dietaryThiamin,
        .dietaryRiboflavin,
        .dietaryNiacin,
        .dietaryFolate,
        .dietaryBiotin,
        .dietaryPantothenicAcid,
        .dietaryPhosphorus,
        .dietaryIodine,
        .dietaryMagnesium,
        .dietaryZinc,
        .dietarySelenium,
        .dietaryCopper,
        .dietaryManganese,
        .dietaryChromium,
        .dietaryMolybdenum,
        .dietaryChloride,
        
        // Other
        .appleExerciseTime,
        .headphoneAudioExposure, // (available on supported OS versions)
        .uvExposure,
        .appleSleepingWristTemperature
    ]
    
    private let allCategoryTypeIdenfier: [HKCategoryTypeIdentifier] = [
        .appleStandHour,
        .environmentalAudioExposureEvent,
        .headphoneAudioExposureEvent,
        .highHeartRateEvent,
        .irregularHeartRhythmEvent,
        .lowCardioFitnessEvent,
        .lowHeartRateEvent,
        .mindfulSession,
        .appleWalkingSteadinessEvent,
        .handwashingEvent,
        .toothbrushingEvent,
        .bleedingAfterPregnancy,
        .bleedingDuringPregnancy,
        .cervicalMucusQuality,
        .contraceptive,
        .infrequentMenstrualCycles,
        .intermenstrualBleeding,
        .irregularMenstrualCycles,
        .lactation,
        .menstrualFlow,
        .ovulationTestResult,
        .persistentIntermenstrualBleeding,
        .pregnancy,
        .pregnancyTestResult,
        .progesteroneTestResult,
        .prolongedMenstrualPeriods,
        .sexualActivity,
        .sleepApneaEvent,
        .sleepAnalysis,
        .abdominalCramps,
        .acne,
        .appetiteChanges,
        .bladderIncontinence,
        .bloating,
        .breastPain,
        .chestTightnessOrPain,
        .chills,
        .constipation,
        .coughing,
        .diarrhea,
        .dizziness,
        .drySkin,
        .fainting,
        .fatigue,
        .fever,
        .generalizedBodyAche,
        .hairLoss,
        .headache,
        .heartburn,
        .hotFlashes,
        .lossOfSmell,
        .lossOfTaste,
        .lowerBackPain,
        .memoryLapse,
        .moodChanges,
        .nausea,
        .nightSweats,
        .pelvicPain,
        .rapidPoundingOrFlutteringHeartbeat,
        .runnyNose,
        .shortnessOfBreath,
        .sinusCongestion,
        .skippedHeartbeat,
        .sleepChanges,
        .soreThroat,
        .vaginalDryness,
        .vomiting,
        .wheezing,
        .environmentalAudioExposureEvent
    ]
}

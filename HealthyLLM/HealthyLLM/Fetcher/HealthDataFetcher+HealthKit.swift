//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit

extension HealthDataFetcher {
    
    func fetchSample(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictEndDate
        )
        
        let quantityType = HKQuantityType(identifier)
        
        var statisticsOptions: HKStatisticsOptions = []
        
        switch quantityType.aggregationStyle {
        case .cumulative:
            statisticsOptions = .cumulativeSum
        case .discreteArithmetic, .discreteTemporallyWeighted:
            statisticsOptions = .discreteAverage
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
    
    func fetchLastSample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        guard let sampleType = HKSampleType.quantityType(forIdentifier: identifier) else {
            throw HealthDataFetcherError.quantityTypeIdentifierNotFound
        }
        
        let sample: Double = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let sample = results?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthDataFetcherError.noValueAvailable)
                    return
                }
                
                continuation.resume(
                    returning: sample.quantity.doubleValue(for: unit)
                )
            }
            healthStore.execute(query)
        }
        
        return sample
    }
    
    func fetchWorkoutData(activity: HKWorkoutActivityType, limit: Int? = 10) async -> [WorkoutData]? {
        let activityPredicate = HKQuery.predicateForWorkouts(with: activity)
        
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            healthStore.execute(
                HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: activityPredicate,
                    limit: limit ?? HKObjectQueryNoLimit,
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
            return nil
        }
        
        var result = [WorkoutData]()
        
        for workout in workouts {
            var stats: [String: String] = [:]
            
            for quantityType in workout.allStatistics.keys {
                guard let statistics = workout.allStatistics[quantityType],
                      let (identifier, _) = hkStringToHKQuantityTypeIdentifier(quantityType.identifier),
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
                    name: String(describing: workout.workoutActivityType),
                    date: workout.startDate.formatted(date: .abbreviated, time: .shortened),
                    duration: Duration.seconds(workout.duration).formatted(),
                    statistics: stats
                )
            )
        }
        
        return result
    }
}

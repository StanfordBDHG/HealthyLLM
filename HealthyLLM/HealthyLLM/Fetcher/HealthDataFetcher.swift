//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
import SpeziHealthKit

class HealthDataFetcher: DefaultInitializable, Module, EnvironmentAccessible {
    @ObservationIgnored let healthStore = HKHealthStore()
    
    required init() { }
    
    func askForAuthorization() async throws {
        let readTypes = Set([
            HKSeriesType.activitySummaryType(),
            HKSeriesType.workoutRoute(),
            HKSeriesType.workoutType()
        ]).union(
            Set(allHKQuantityTypeIdentifiers().map { HKQuantityType($0) })
        )
        
        try await healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        )
    }
    
    func fetchUser() async -> UserInfo? {
        let height = try? await fetchLastSample(for: .height, unit: .meter())
        let weight = try? await fetchLastSample(for: .bodyMass, unit: .gramUnit(with: .kilo))
        let bmi: Double? = if let height, let weight {
            weight / (height * height)
        } else { nil }
        
        return .init(
            name: nil,
            dateOfBirth: try? healthStore.dateOfBirthComponents().date,
            sex: try? healthStore.biologicalSex().biologicalSex.description,
            height: height != nil ? "\((height! / 100).rounded())cm" : nil,
            weight: weight != nil ? "\(weight!.rounded())kg" : nil,
            bmi: bmi != nil ? "\(bmi!.rounded())" : nil
        )
    }
    
    func fetchHealth(_ healthKit: HealthKit, type: String) async throws -> HealthData? {
        guard let (identifier, _) = hkStringToHKQuantityTypeIdentifier(type),
              let unit = identifier.siUnit,
              let sampleType = SampleType(identifier) else {
            return nil
        }

        let timeRanges: [(String, HealthKitQueryTimeRange)] = [
            ("day", .today),
            ("week", .currentWeek),
            ("month", .currentMonth)
        ]

        var result: [String: Double] = [:]
        try await withThrowingTaskGroup(of: (String, Double).self) { group in
            for (description, timeRange) in timeRanges {
                group.addTask {
                    let statistics = try await healthKit.statisticsQuery(sampleType, timeRange: timeRange)

                    switch sampleType.hkSampleType.aggregationStyle {
                    case .cumulative:
                        if let sum = statistics?.sumQuantity() {
                            let value = sum.doubleValue(for: unit).rounded()
                            return (description, value)
                        } else {
                            throw HealthDataFetcherError.noValueAvailable
                        }
                    case .discreteArithmetic, .discreteTemporallyWeighted:
                        if let average = statistics?.averageQuantity() {
                            let value = average.doubleValue(for: unit).rounded()
                            return (description, value)
                        } else {
                            throw HealthDataFetcherError.noValueAvailable
                        }
                    default:
                        throw HealthDataFetcherError.unsupportedAggregationStyle
                    }
                }
            }

            for try await (description, value) in group {
                result[description] = value
            }
        }

        let healthData = HealthData(
            name: sampleType.displayTitle,
            unit: unit.unitString,
            values: result)

        print(healthData)

        return healthData
    }
    
    func fetchSleep() async -> String { "" }
    
    func fetchWorkout(type: String) async -> [WorkoutData]? {
        guard let identifier = workoutStringToHKWorkoutActivityType(type),
              let result = await fetchWorkoutData(activity: identifier) else {
            return nil
        }
        
        return result
    }
}

// One-off query for aggregating health data
// TODO: Create Pull Request for SpeziHealthKit
extension HealthKit {
    public func statisticsQuery<Sample>(
        _ sampleType: SampleType<Sample>,
        timeRange: HealthKitQueryTimeRange,
        limit: Int? = nil,
        sortedBy sortDescriptors: [SortDescriptor<Sample>] = [SortDescriptor<Sample>(\.startDate, order: .forward)],
        predicate filterPredicate: NSPredicate? = nil,
        options statisticsOption: HKStatisticsOptions? = nil
    ) async throws -> HKStatistics? {
        let basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timeRange.predicate, filterPredicate].compactMap(\.self))
        let quantityType = sampleType.hkSampleType as! HKQuantityType
        var statisticsOptions: HKStatisticsOptions = statisticsOption ?? []

        switch quantityType.aggregationStyle {
        case .cumulative:
            statisticsOptions.insert(.cumulativeSum)
        case .discreteArithmetic, .discreteTemporallyWeighted:
            statisticsOptions.insert(.discreteAverage)
        default:
            throw HealthDataFetcherError.unsupportedAggregationStyle
        }

        let queryDescriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate<HKQuantitySample>.quantitySample(type: quantityType, predicate: basePredicate),
            options: statisticsOptions
        )

        return try await queryDescriptor.result(for: healthStore)
    }
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
import SpeziHealthKit

class HealthDataFetcher: DefaultInitializable, Module, EnvironmentAccessible {
    required init() { }
    
    func askForAuthorization(_ healthKit: HealthKit) async throws {
        let readTypes = Set([
            HKSeriesType.activitySummaryType(),
            HKSeriesType.workoutRoute(),
            HKSeriesType.workoutType()
        ]).union(
            Set(allHKQuantityTypeIdentifiers().map { HKQuantityType($0) })
        )

        try await healthKit.askForAuthorization(for: .init(read: readTypes, write: []))
    }
    
    func fetchUser(_ healthKit: HealthKit) async -> UserInfo? {
        let heightSample = try? await healthKit.query(
            .height,
            timeRange: .ever,
            limit: 1,
            sortedBy: [SortDescriptor(\.startDate, order: .reverse)]
        ).first
        let weightSample = try? await healthKit.query(
            .bodyMass,
            timeRange: .ever,
            limit: 1,
            sortedBy: [SortDescriptor(\.startDate, order: .reverse)]
        ).first
        let bmiSample = try? await healthKit.query(
            .bodyMassIndex,
            timeRange: .ever,
            limit: 1,
            sortedBy: [SortDescriptor(\.startDate, order: .reverse)]
        ).first

        let sex = try? healthKit.healthStore.biologicalSex().biologicalSex.description
        let dateOfBirth = try? healthKit.healthStore.dateOfBirthComponents().date
        let height = heightSample?.quantity.doubleValue(for: .meterUnit(with: .centi)) ?? 0
        let weight = weightSample?.quantity.doubleValue(for: .gramUnit(with: .kilo)) ?? 0
        let bmi = bmiSample?.quantity.doubleValue(for: .count()) ?? 0

        return .init(
            name: nil,
            dateOfBirth: dateOfBirth,
            sex: sex,
            height: "\(height)cm",
            weight: "\(weight)kg",
            bmi: "\(bmi)"
        )
    }
    
    func fetchHealth(_ healthKit: HealthKit, type: String) async throws -> HealthData? {
        guard let (identifier, _) = hkStringToHKQuantityTypeIdentifier(type),
              let unit = identifier.siUnit,
              let sampleType = SampleType(identifier) else {
            return nil
        }

        struct TimeRangeConfig {
            let description: String
            let timeRange: HealthKitQueryTimeRange
            let interval: DateComponents
        }

        let timeRanges: [TimeRangeConfig] = [
            .init(description: "day", timeRange: .today, interval: DateComponents(hour: 1)),
            .init(description: "week", timeRange: .currentWeek, interval: DateComponents(day: 1)),
            .init(description: "month", timeRange: .currentMonth, interval: DateComponents(day: 1))
        ]

        var result: [String: [Double]] = [:]
        try await withThrowingTaskGroup(of: (String, [Double]).self) { group in
            for config in timeRanges {
                let description = config.description
                let timeRange = config.timeRange
                let interval = config.interval
                group.addTask {
                    var bucketValues: [Double] = []
                    let startDate = timeRange.range.lowerBound
                    let endDate = timeRange.range.upperBound

                    let collection = try await healthKit.statisticsQuery(
                        sampleType,
                        timeRange: timeRange,
                        interval: interval
                    )

                    collection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                        switch sampleType.hkSampleType.aggregationStyle {
                        case .cumulative:
                            if let sum = stats.sumQuantity() {
                                bucketValues.append(sum.doubleValue(for: unit).rounded())
                            } else {
                                bucketValues.append(0.0)
                            }
                        case .discreteArithmetic, .discreteTemporallyWeighted:
                            if let avg = stats.averageQuantity() {
                                bucketValues.append(avg.doubleValue(for: unit).rounded())
                            } else {
                                bucketValues.append(0.0)
                            }
                        default:
                            break
                        }
                    }

                    return (description, bucketValues)
                }
            }

            for try await (description, values) in group {
                result[description] = values
            }
        }

        return HealthData(
            name: sampleType.displayTitle,
            unit: unit.unitString,
            values: result
        )
    }
    
    func fetchWorkout(_ healthKit: HealthKit, type: String) async -> [WorkoutData] {
        guard let activity = workoutStringToHKWorkoutActivityType(type),
              let workouts = try? await healthKit.query(
                .workout,
                timeRange: .ever,
                limit: 10,
                sortedBy: [SortDescriptor(\.startDate, order: .reverse)]
              ) else {
            return []
        }

        let filtered = workouts.filter { $0.workoutActivityType == activity }
        var result: [WorkoutData] = []

        for workout in filtered {
            var stats: [String: String] = [:]

            for quantityType in workout.allStatistics.keys {
                guard let statistics = workout.allStatistics[quantityType],
                      let (identifier, _) = hkStringToHKQuantityTypeIdentifier(quantityType.identifier),
                      let unit = identifier.siUnit else { continue }

                let shortIdentifier = quantityType.identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")

                switch quantityType.aggregationStyle {
                case .cumulative:
                    if let sum = statistics.sumQuantity() {
                        let value = sum.doubleValue(for: unit)
                        stats[shortIdentifier] = "\(value.rounded()) \(unit)"
                    }
                case .discreteArithmetic, .discreteTemporallyWeighted:
                    if let average = statistics.averageQuantity() {
                        let value = average.doubleValue(for: unit)
                        stats[shortIdentifier] = "\(value.rounded()) \(unit)"
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

// One-off query for aggregating health data
extension HealthKit {
    public func statisticsQuery<Sample>(
        _ sampleType: SampleType<Sample>,
        timeRange: HealthKitQueryTimeRange,
        interval: DateComponents,
        limit _: Int? = nil,  // swiftlint:disable:this unused_parameter
        sortedBy _: [SortDescriptor<Sample>] = [SortDescriptor<Sample>(\.startDate, order: .forward)],  // swiftlint:disable:this unused_parameter
        predicate filterPredicate: NSPredicate? = nil
    ) async throws -> HKStatisticsCollection {
        let startDate = timeRange.range.lowerBound
        let basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timeRange.predicate, filterPredicate].compactMap(\.self))
        guard let quantityType = sampleType.hkSampleType as? HKQuantityType else {
            throw HealthDataFetcherError.unsupportedAggregationStyle
        }
        var statisticsOptions: HKStatisticsOptions = []

        switch quantityType.aggregationStyle {
        case .cumulative:
            statisticsOptions.insert(.cumulativeSum)
        case .discreteArithmetic, .discreteTemporallyWeighted:
            statisticsOptions.insert(.discreteAverage)
        default:
            throw HealthDataFetcherError.unsupportedAggregationStyle
        }

        let predicate = HKSamplePredicate<HKQuantitySample>
            .quantitySample(type: quantityType, predicate: basePredicate)

        let queryDescriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: statisticsOptions,
            anchorDate: startDate,
            intervalComponents: interval
        )

        return try await queryDescriptor.result(for: healthStore)
    }
}

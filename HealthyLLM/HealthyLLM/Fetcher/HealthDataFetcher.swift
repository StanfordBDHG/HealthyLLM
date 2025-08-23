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
    
    func fetchHealth(type: String) async -> HealthData? {
        guard let (identifier, _) = hkStringToHKQuantityTypeIdentifier(type),
              let unit = identifier.siUnit,
              let sampleType = SampleType(identifier) else {
            return nil
        }

        let timeRanges: [HealthKitQueryTimeRange] = [
            .today,
            .currentWeek,
            .currentMonth
        ]

        let endDates = [
            ("day", Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            ("week", Calendar.current.date(byAdding: .day, value: -7, to: Date())!),
            ("month", Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        ]
        
        
        return await withTaskGroup(of: (String, Double?).self, returning: HealthData?.self) { taskGroup in
            for (description, endDate) in endDates {
                taskGroup.addTask {
                    (
                        description,
                        try? await self.fetchSample(
                            for: identifier,
                            unit: unit,
                            startDate: endDate,
                            endDate: .now
                        )
                    )
                }
            }
            
            var results: [String: Double] = [:]
            for await (description, value) in taskGroup {
                if let value {
                    results[description] = value
                }
            }
            
            if results.isEmpty {
                return nil
            }
            
            return HealthData(
                name: identifier.rawValue,
                unit: unit.unitString,
                values: results
            )
        }
    }
    
    func fetchSleep() async -> String { "" }
    
    func fetchWorkout(type: String) async -> [WorkoutData]? {
        guard let identifier = workoutStringToHKWorkoutActivityType(type),
              let result = await fetchWorkoutData(activity: identifier) else {
            return nil
        }
        
        return result
    }

    func fetchHealthData(_ healthKit: HealthKit, sampleTypeKey: String) async throws -> HealthData?  {
        guard let identifier = hkStringToHKQuantityTypeIdentifier(sampleTypeKey) else {
            return nil
        }

        let key = identifier.0
        let unit = identifier.1

        guard let sampleType = SampleType(key) else {
            return nil
        }

        do {
            let samples = try await healthKit.statisticsQuery(sampleType, timeRange: .today)
            var result: Double = 0

            switch sampleType.hkSampleType.aggregationStyle {
            case .discreteArithmetic, .discreteTemporallyWeighted:
                if let average = samples?.averageQuantity() {
                    result = average.doubleValue(for: unit).rounded()
                } else {
                    throw HealthDataFetcherError.noValueAvailable
                }
            default:
                throw HealthDataFetcherError.unsupportedAggregationStyle
            }

            let healthData = HealthData(
                name: sampleType.displayTitle,
                unit: unit.unitString,
                values: ["day": result])

            print(healthData)

            return healthData

        } catch {
            print("Error")
        }

        return nil
    }
}

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
            statisticsOptions = .cumulativeSum
        case .discreteArithmetic, .discreteTemporallyWeighted:
            statisticsOptions = .discreteAverage
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

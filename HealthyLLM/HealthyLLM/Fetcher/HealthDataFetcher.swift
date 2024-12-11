//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi

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
              let unit = identifier.siUnit else {
            return nil
        }
        
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
    
}

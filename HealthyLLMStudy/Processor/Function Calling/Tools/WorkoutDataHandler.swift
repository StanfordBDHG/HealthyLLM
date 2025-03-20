//
//  WorkoutDataHandler.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

import HealthKit

/// Handler for workout data queries
class WorkoutDataHandler: ToolHandler {
    static var name: String = "getRecentWorkouts"
    
    func execute(parameters: [String: String]) async throws -> String {
        guard let maxDaysString = parameters["maxDays"],
              let maxDays = Int(maxDaysString) else {
            throw ToolCallError.missingParameters(names: ["maxDays"])
        }
        
        do {
            return try await getRecentWorkouts(maxDayRange: maxDays)
        } catch {
            return "No data available"
        }
    }
    
    private func getRecentWorkouts(maxDayRange: Int = 30) async throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -maxDayRange, to: Date())!
        let endDate = Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
                var resultText = ""
                
                guard let workouts = samples as? [HKWorkout], error == nil, !workouts.isEmpty else {
                    continuation.resume(returning: "No workouts within last \(maxDayRange) days.")
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
                            resultText += ", Distance: \(String(format: "%.2f", distance / 1000)) km"
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
}

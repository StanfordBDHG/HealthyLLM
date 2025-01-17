//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziChat

enum PromptGenerator {
    private static let interpretationSystemPrompt = LocalizedStringResource("INTERPRETATION_SYSTEM_PROMPT").localizedString()
    
    enum FunctionCallProcessor {
        enum `Type` {
            case functionCall
            case interpretation
        }
        
        private static let functionCallSystemPrompt = LocalizedStringResource("FUNCTION_CALL_SYSTEM_PROMPT").localizedString()
        
        
        static func buildSystemPrompt(for type: `Type`) -> ChatEntity {
            let prompt = switch type {
            case .functionCall:
                functionCallSystemPrompt
            case .interpretation:
                """
                \(interpretationSystemPrompt)
                """
            }
            
            return .init(
                role: .hidden(type: .system),
                content: prompt
            )
        }
        
        static func buildToolResponse(of data: String?) -> ChatEntity {
            .init(
                role: .assistantToolResponse,
                content: """
                        <tool_response>
                        \(data ?? "No Data")
                        </tool_response>
                        """
            )
        }
    }
    
    enum ContextWindowProcessor {
        static func buildSystemPrompt(health: [[HealthData]], workout: [WorkoutData]) -> ChatEntity {
            .init(role: .hidden(type: .system), content: """
            \(interpretationSystemPrompt)
            
            Health data:
            \(convertToMatrix(healthData: health))
            
            Workout data:
            \(workout.asJSONString() ?? "No Data")
            """)
        }
        
        static func convertToMatrix(healthData: [[HealthData]]) -> String {
            // Flatten all data to extract unique identifiers and dates
            let uniqueDates = Set(healthData.flatMap { $0.map { $0.date } }).sorted()
            let uniqueIdentifiers = Set(healthData.flatMap { $0.map { $0.identifier } })
            
            // Create a header row with dates
            var matrix: [[String]] = [[""] + uniqueDates.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none) }]
            
            // Create a lookup table for health data values
            var valueLookup: [String: [Date: Double]] = [:]
            for dayData in healthData {
                for entry in dayData {
                    if valueLookup[entry.identifier] == nil {
                        valueLookup[entry.identifier] = [:]
                    }
                    valueLookup[entry.identifier]?[entry.date] = entry.value
                }
            }
            
            // Populate rows with data
            for identifier in uniqueIdentifiers.sorted() {
                var row: [String] = [identifier]
                for date in uniqueDates {
                    if let value = valueLookup[identifier]?[date] {
                        row.append(String(value))
                    } else {
                        row.append("") // Empty cell for missing data
                    }
                }
                matrix.append(row)
            }
            
            var result = ""
            for row in matrix {
                result += row.joined(separator: ",") + "\n"
            }
            
            return result
        }

        
        static func healthArrayToJSONString(health: [[HealthData]]) -> String {
            var result = ""
            
            for day in health {
                var foo: [String: String] = [:]
                for type in day {
                    if let displayName = type.displayName {
                        foo[displayName] = "\(type.value) \(type.unit ?? "")"
                    }
                }
                result += """
                
                \(day[0].date.formatted(date: .numeric, time: .omitted)): \(foo.asJSONString()!)
                """
            }
            
            
            return result
        }
        
        
        static func healthArrayToString(health: [[HealthData]]) -> String {
            var result = "date, "
            
            // create header
            for type in health[0] {
                result += "\(type.identifier), "
            }
            
            for healthType in health {
                result += "\n\(healthType[0].date.formatted(date: .numeric, time: .omitted)), "
                
                var dayIndex = 0
                while dayIndex < healthType.count {
                    let dayHealth = healthType[dayIndex]
                    result += "\(dayHealth.value), "
                    
                    dayIndex += 1
                }
            }
            return result
        }
    }
}

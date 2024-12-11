//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

enum PromptGenerator {
    
    enum SystemPromptType {
        case functionCall
        case `default`
    }
    
    static func buildSystemPrompt(for type: SystemPromptType, userInfo: UserInfo? = nil) -> HealthyLLMContextEntity {
        let prompt = switch type {
        case .functionCall:
            generationPrompt(with: tools)
        case .default:
            """
            \(systemPrompt)
            Here is some general information about the user, only use these information if necessary:
            \(userInfo != nil ? userInfo!.asJSONRepresentation(.prettyPrinted) ?? "No Data" : "No Data") 
            """
        }
        
        return .init(
            .system,
            content: prompt
        )
    }
    
    static func buildToolResponse<T: Encodable>(of data: T?, onFailure: String = "No Data") -> HealthyLLMContextEntity {
        if let data = data {
            buildToolResponse(
                of: data.asJSONRepresentation(.prettyPrinted),
                onFailure: onFailure
            )
        } else {
            buildToolResponse(of: nil, onFailure: onFailure)
        }
    }
    
    static func buildToolResponse(of data: String?, onFailure: String = "No Data") -> HealthyLLMContextEntity {
        .init(
            .toolResponse,
            content: """
                    <tool_response>
                    \(data ?? onFailure)
                    </tool_response>
                    """
        )
    }
    
    static private func generationPrompt(with tools: String?) -> String {
        """
        You are a function calling AI model. You are provided with function signatures within <tools></tools> XML tags. You may call one or more functions to assist with the user query. Don't make assumptions about what values to plug into functions. Here are the available tools: <tools>
        \(tools ?? "")
        </tools>
        For each function call return a json object with function name and arguments within <tool_call></tool_call> XML tags as follows:
        <tool_call>
        {"name": <function-name>, "arguments": <args-dict>}
        </tool_call>
        """
    }
    
    
    static private let tools: String = """
    {
      "type": "function",
      "function": {
        "name": "get_health_info",
        "description": "get_health_info(sample_type: str) -> dict - Retrieves health data for the specified sample type, aggregating the data over different time periods (last day, last week, and last month) and returning it in a structured JSON format.Returns:\n        A structured object containing the name, unit and values for the last 24 hours, last week, and last month.",
        "parameters": {
          "type": "object",
          "properties": {
            "sample_type": {
              "type": "string",
              "description": "A string representing the type of health data to retrieve (Choices: bodyMassIndex, stairDescentSpeed, swimmingStrokeCount, appleSleepingBreathingDisturbances, activeEnergyBurned, runningVerticalOscillation, walkingSpeed, appleExerciseTime, walkingStepLength, restingHeartRate, cyclingCadence, heartRateRecoveryOneMinute, distanceWalkingRunning, environmentalAudioExposure, runningStrideLength, heartRate, sixMinuteWalkTestDistance, appleStandTime, runningPower, basalEnergyBurned, distanceCycling, headphoneAudioExposure, leanBodyMass, appleSleepingWristTemperature, timeInDaylight, bodyMass, heartRateVariabilitySDNN, walkingAsymmetryPercentage, oxygenSaturation, distanceDownhillSnowSports, runningSpeed, walkingDoubleSupportPercentage, distanceSwimming, runningGroundContactTime, vo2Max, stairAscentSpeed, respiratoryRate, stepCount, walkingHeartRateAverage, appleWalkingSteadiness, bodyFatPercentage, flightsClimbed)."
            }
          },
          "required": [
            "sample_type"
          ]
        }
      }
    }
    {
      "type": "function",
      "function": {
        "name": "get_workout_info",
        "description": "get_workout_info(workout_type: str) -> dict - Retrieves the last workouts for the specified workout type, including details about the date, duration, calories burned etc.",
        "parameters": {
          "type": "object",
          "properties": {
            "workout_type": {
              "type": "string",
              "description": "A string representing the workout type to retrieve (Choices: americanFootball, archery, australianFootball, badminton, baseball, basketball, bowling, boxing, climbing, cricket, crossTraining, curling, cycling, dance, danceInspiredTraining, elliptical, equestrianSports, fencing, fishing, functionalStrengthTraining, golf, gymnastics, handball, hiking, hockey, hunting, lacrosse, martialArts, mindAndBody, mixedMetabolicCardioTraining, paddleSports, play, preparationAndRecovery, racquetball, rowing, rugby, running, sailing, skatingSports, snowSports, soccer, softball, squash, stairClimbing, surfingSports, swimming, tableTennis, tennis, trackAndField, traditionalStrengthTraining, volleyball, walking, waterFitness, waterPolo, waterSports, wrestling, yoga, barre, coreTraining, crossCountrySkiing, downhillSkiing, flexibility, highIntensityIntervalTraining, jumpRope, kickboxing, pilates, snowboarding, stairs, stepTraining, wheelchairWalkPace, wheelchairRunPace, taiChi, mixedCardio, handCycling, discSports, fitnessGaming, cardioDance, socialDance, pickleball, cooldown, swimBikeRun, transition, underwaterDiving, other)."
            }
          },
          "required": [
            "workout_type"
          ]
        }
      }
    }
    """
    
    static let systemPrompt = "You are a bot that responds to health queries. You should reply with the health type asked for in the query."
    
}
//
//fileprivate struct Tool: Encodable {
//    struct FunctionTool: Encodable {
//        
//        
//        let name: String
//        let description: String
//        let parameters
//    }
//    
//    let type: String
//    let function: FunctionTool
//}

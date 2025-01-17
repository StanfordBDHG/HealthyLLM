//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit

extension HKQuantityTypeIdentifier {
    
    // MARK: - Health Data
    
    static var importantHealthIdentifiers: [HKQuantityTypeIdentifier] {
        [
            .appleSleepingWristTemperature,
            .bodyFatPercentage,
            .bodyMass,
            .bodyMassIndex,
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleMoveTime,
            .appleStandTime,
            .distanceCycling,
            .distanceSwimming,
            .flightsClimbed,
            .runningPower,
            .runningSpeed,
            .stepCount,
            .heartRate,
            .heartRateRecoveryOneMinute,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .vo2Max,
            .walkingHeartRateAverage,
            .appleWalkingSteadiness,
            .runningGroundContactTime,
            .runningStrideLength,
            .runningVerticalOscillation,
            .sixMinuteWalkTestDistance,
            .stairAscentSpeed,
            .stairDescentSpeed,
            .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage,
            .walkingSpeed,
            .walkingStepLength,
            .bloodPressureDiastolic,
            .bloodPressureSystolic,
            .timeInDaylight,
            .uvExposure,
            .basalBodyTemperature,
            .appleSleepingBreathingDisturbances,
            .respiratoryRate,
            .bodyTemperature
        ]
    }
    
    static func from(_ string: String) -> HKQuantityTypeIdentifier? {
        let string = string
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .lowercased()
        
        switch string {
        case "bodyMassIndex".lowercased(): return .bodyMassIndex
        case "stairDescentSpeed".lowercased(): return .stairDescentSpeed
        case "swimmingStrokeCount".lowercased(): return .swimmingStrokeCount
        case "appleSleepingBreathingDisturbances".lowercased(): return .appleSleepingBreathingDisturbances
        case "activeEnergyBurned".lowercased(): return .activeEnergyBurned
        case "runningVerticalOscillation".lowercased(): return .runningVerticalOscillation
        case "walkingSpeed".lowercased(): return .walkingSpeed
        case "appleExerciseTime".lowercased(): return .appleExerciseTime
        case "walkingStepLength".lowercased(): return .walkingStepLength
        case "restingHeartRate".lowercased(): return .restingHeartRate
        case "cyclingCadence".lowercased(): return .cyclingCadence
        case "heartRateRecoveryOneMinute".lowercased(): return .heartRateRecoveryOneMinute
        case "distanceWalkingRunning".lowercased(): return .distanceWalkingRunning
        case "environmentalAudioExposure".lowercased(): return .environmentalAudioExposure
        case "runningStrideLength".lowercased(): return .runningStrideLength
        case "heartRate".lowercased(): return .heartRate
        case "sixMinuteWalkTestDistance".lowercased(): return .sixMinuteWalkTestDistance
        case "appleStandTime".lowercased(): return .appleStandTime
        case "runningPower".lowercased(): return .runningPower
        case "basalEnergyBurned".lowercased(): return .basalEnergyBurned
        case "distanceCycling".lowercased(): return .distanceCycling
        case "headphoneAudioExposure".lowercased(): return .headphoneAudioExposure
        case "leanBodyMass".lowercased(): return .leanBodyMass
        case "appleSleepingWristTemperature".lowercased(): return .appleSleepingWristTemperature
        case "timeInDaylight".lowercased(): return .timeInDaylight
        case "bodyMass".lowercased(): return .bodyMass
        case "heartRateVariabilitySDNN".lowercased(): return .heartRateVariabilitySDNN
        case "walkingAsymmetryPercentage".lowercased(): return .walkingAsymmetryPercentage
        case "oxygenSaturation".lowercased(): return .oxygenSaturation
        case "distanceDownhillSnowSports".lowercased(): return .distanceDownhillSnowSports
        case "runningSpeed".lowercased(): return .runningSpeed
        case "walkingDoubleSupportPercentage".lowercased(): return .walkingDoubleSupportPercentage
        case "distanceSwimming".lowercased(): return .distanceSwimming
        case "runningGroundContactTime".lowercased(): return .runningGroundContactTime
        case "vo2Max".lowercased(): return .vo2Max
        case "stairAscentSpeed".lowercased(): return .stairAscentSpeed
        case "respiratoryRate".lowercased(): return .respiratoryRate
        case "stepCount".lowercased(): return .stepCount
        case "walkingHeartRateAverage".lowercased(): return .walkingHeartRateAverage
        case "appleWalkingSteadiness".lowercased(): return .appleWalkingSteadiness
        case "bodyFatPercentage".lowercased(): return .bodyFatPercentage
        case "flightsClimbed".lowercased(): return .flightsClimbed
        default: return nil
        }
    }
}

extension HKQuantityTypeIdentifier {
    var siUnit: HKUnit? {
        switch self {
        case .bodyMassIndex: return .count()
        case .stairDescentSpeed: return .meter().unitDivided(by: .second())
        case .swimmingStrokeCount: return .count()
        case .appleSleepingBreathingDisturbances: return .count()
        case .activeEnergyBurned: return .kilocalorie()
        case .runningVerticalOscillation: return .meter()
        case .walkingSpeed: return .meter().unitDivided(by: .second())
        case .appleExerciseTime: return .minute()
        case .walkingStepLength: return .meter()
        case .restingHeartRate: return .count().unitDivided(by: .minute())
        case .cyclingCadence: return .count().unitDivided(by: .minute())
        case .heartRateRecoveryOneMinute: return .count()
        case .distanceWalkingRunning: return .meterUnit(with: .kilo)
        case .environmentalAudioExposure: return .decibelAWeightedSoundPressureLevel()
        case .runningStrideLength: return .meter()
        case .heartRate: return .count().unitDivided(by: .minute())
        case .sixMinuteWalkTestDistance: return .meter()
        case .appleStandTime: return .minute()
        case .runningPower: return .watt()
        case .basalEnergyBurned: return .kilocalorie()
        case .distanceCycling: return .meterUnit(with: .kilo)
        case .headphoneAudioExposure: return .decibelAWeightedSoundPressureLevel()
        case .leanBodyMass: return .gramUnit(with: .kilo)
        case .appleSleepingWristTemperature: return .degreeCelsius()
        case .timeInDaylight: return .minute()
        case .bodyMass: return .gramUnit(with: .kilo)
        case .heartRateVariabilitySDNN: return .secondUnit(with: .milli)
        case .walkingAsymmetryPercentage: return .percent()
        case .oxygenSaturation: return .percent()
        case .distanceDownhillSnowSports: return .meterUnit(with: .kilo)
        case .runningSpeed: return .meterUnit(with: .kilo).unitDivided(by: .hour())
        case .walkingDoubleSupportPercentage: return .percent()
        case .distanceSwimming: return .meterUnit(with: .kilo)
        case .runningGroundContactTime: return .second()
        case .vo2Max: return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case .stairAscentSpeed: return .meter().unitDivided(by: .second())
        case .respiratoryRate: return .count().unitDivided(by: .minute())
        case .stepCount: return .count()
        case .walkingHeartRateAverage: return .count().unitDivided(by: .minute())
        case .appleWalkingSteadiness: return .percent()
        case .bodyFatPercentage: return .percent()
        case .flightsClimbed: return .count()
        default: return nil
        }
    }
}

extension HKQuantityTypeIdentifier {
    var description: String? {
        switch self {
        case .bodyMassIndex: return "The users body mass index"
        case .stairDescentSpeed: return "The users speed while descending a flight of stairs."
        case .appleMoveTime: return "The amount of time the user has spent performing activities that involve full-body movements."
        case .swimmingStrokeCount: return "The number of strokes performed while swimming."
        case .appleSleepingBreathingDisturbances: return "The users sleep breathing disturbances"
        case .activeEnergyBurned: return "The amount of active energy the user has burned."
        case .runningVerticalOscillation: return "The pelvis vertical range of motion during a single running stride"
        case .walkingSpeed: return "The users average speed when walking steadily over flat ground."
        case .appleExerciseTime: return "The amount of time the user spent exercising."
        case .walkingStepLength: return "The average length of the users step when walking steadily over flat ground."
        case .restingHeartRate: return "The users resting heart rate."
        case .cyclingCadence: return "The average cycling cadence when cycling."
        case .heartRateRecoveryOneMinute: return "The reduction in heart rate from the peak exercise rate to the rate one minute after exercising ended."
        case .distanceWalkingRunning: return "The distance the user has moved by walking or running."
        case .environmentalAudioExposure: return "Txposure to potentially damaging sounds from the environment."
        case .runningStrideLength: return "The distance covered by a single step while running."
        case .heartRate: return "That measures the users heart rate."
        case .sixMinuteWalkTestDistance: return "The distance a user can walk during a six-minute walk test."
        case .appleStandTime: return "The amount of time the user has spent standing."
        case .runningPower: return "Te rate of work required for the runner to maintain their speed."
        case .basalEnergyBurned: return "The resting energy burned by the user."
        case .distanceCycling: return "The distance the user has moved by cycling."
        case .headphoneAudioExposure: return "The audio exposure from headphones."
        case .leanBodyMass: return "The users lean body mass."
        case .appleSleepingWristTemperature: return "The wrist temperature during sleep."
        case .timeInDaylight: return "The amount of daylight the user has spend in."
        case .bodyMass: return "The users weight in Kilograms."
        case .heartRateVariabilitySDNN: return "The standard deviation of heartbeat intervals."
        case .walkingAsymmetryPercentage: return "The percentage of steps in which one foot moves at a different speed than the other when walking on flat ground."
        case .oxygenSaturation: return "That measures the users oxygen saturation."
        case .distanceDownhillSnowSports: return "The distance the user has traveled while skiing or snowboarding."
        case .runningSpeed: return "The runners speed."
        case .walkingDoubleSupportPercentage: return "The percentage of time when both of the user’s feet touch the ground while walking steadily over flat ground."
        case .distanceSwimming: return "That measures the distance the user has moved while swimming."
        case .runningGroundContactTime: return "The amount of time the runner’s foot is in contact with the ground while running."
        case .vo2Max: return "The maximal oxygen consumption during exercise."
        case .stairAscentSpeed: return "The users speed while climbing a flight of stairs."
        case .respiratoryRate: return "The users respiratory rate."
        case .stepCount: return "The number of steps the user has taken."
        case .walkingHeartRateAverage: return "The users heart rate while walking."
        case .appleWalkingSteadiness: return "The steadiness of the users gait."
        case .bodyFatPercentage: return "The users body fat percentage."
        case .flightsClimbed: return "The number flights of stairs that the user has climbed."
        case .bloodPressureSystolic: return "The systolic blood pressure."
        case .bloodPressureDiastolic: return "The diastolic blood pressure."
        case .uvExposure: return "The amount of ultraviolet light the user has been exposed to."
        case .basalBodyTemperature: return "The users basal body temperature."
        case .bodyTemperature: return "The users body temperature."
        default: return nil
        }
    }
    
    var displayName: String? {
        switch self {
        case .bodyMassIndex: return "Body Mass Index"
        case .stairDescentSpeed: return "stair Descent Speed"
        case .swimmingStrokeCount: return "swimming Stroke Count"
        case .appleSleepingBreathingDisturbances: return "apple Sleeping Breathing Disturbances"
        case .activeEnergyBurned: return "active Energy Burned"
        case .runningVerticalOscillation: return "running Vertical Oscillation"
        case .walkingSpeed: return "walking Speed"
        case .appleExerciseTime: return "apple Exercise Time"
        case .walkingStepLength: return "walking Step Length"
        case .restingHeartRate: return "resting Heart Rate"
        case .cyclingCadence: return "cycling Cadence"
        case .heartRateRecoveryOneMinute: return "heart Rate Recovery One Minute"
        case .distanceWalkingRunning: return "distance Walking Running"
        case .environmentalAudioExposure: return "environmental Audio Exposure"
        case .runningStrideLength: return "running Stride Length"
        case .heartRate: return "heart Rate"
        case .sixMinuteWalkTestDistance: return "six Minute Walk Test Distance"
        case .appleStandTime: return "apple Stand Time"
        case .runningPower: return "running Power"
        case .basalEnergyBurned: return "basal Energy Burned"
        case .distanceCycling: return "distance Cycling"
        case .headphoneAudioExposure: return "headphone Audio Exposure"
        case .leanBodyMass: return "lean Body Mass"
        case .appleSleepingWristTemperature: return "apple Sleeping Wrist Temperature"
        case .timeInDaylight: return "time In Daylight"
        case .bodyMass: return "body Mass"
        case .heartRateVariabilitySDNN: return "heart Rate Variability SDNN"
        case .walkingAsymmetryPercentage: return "walking Asymmetry Percentage"
        case .oxygenSaturation: return "oxygen Saturation"
        case .distanceDownhillSnowSports: return "distance Downhill Snow Sports"
        case .runningSpeed: return "running Speed"
        case .walkingDoubleSupportPercentage: return "walking Double Support Percentage"
        case .distanceSwimming: return "distance Swimming"
        case .runningGroundContactTime: return "running Ground Contact Time"
        case .vo2Max: return "vo2 Max"
        case .stairAscentSpeed: return "stair Ascent Speed"
        case .respiratoryRate: return "respiratory Rate"
        case .stepCount: return "step Count"
        case .walkingHeartRateAverage: return "walking Heart Rate Average"
        case .appleWalkingSteadiness: return "apple Walking Steadiness"
        case .bodyFatPercentage: return "body Fat Percentage"
        case .flightsClimbed: return "flights Climbed"
        default: return nil
        }
    }
}


// MARK: - Workout Data


extension HKWorkoutActivityType {
    var name: String? {
        switch self {
        case .americanFootball: return "americanFootball"
        case .archery: return "archery"
        case .australianFootball: return "australianFootball"
        case .badminton: return "badminton"
        case .baseball: return "baseball"
        case .basketball: return "basketball"
        case .bowling: return "bowling"
        case .boxing: return "boxing"
        case .climbing: return "climbing"
        case .cricket: return "cricket"
        case .crossTraining: return "crossTraining"
        case .curling: return "curling"
        case .cycling: return "cycling"
        case .elliptical: return "elliptical"
        case .equestrianSports: return "equestrianSports"
        case .fencing: return "fencing"
        case .fishing: return "fishing"
        case .functionalStrengthTraining: return "functionalStrengthTraining"
        case .golf: return "golf"
        case .gymnastics: return "gymnastics"
        case .handball: return "handball"
        case .hiking: return "hiking"
        case .hockey: return "hockey"
        case .hunting: return "hunting"
        case .lacrosse: return "lacrosse"
        case .martialArts: return "martialArts"
        case .mindAndBody: return "mindAndBody"
        case .paddleSports: return "paddleSports"
        case .play: return "play"
        case .preparationAndRecovery: return "preparationAndRecovery"
        case .racquetball: return "racquetball"
        case .rowing: return "rowing"
        case .rugby: return "rugby"
        case .running: return "running"
        case .sailing: return "sailing"
        case .skatingSports: return "skatingSports"
        case .snowSports: return "snowSports"
        case .soccer: return "soccer"
        case .softball: return "softball"
        case .squash: return "squash"
        case .stairClimbing: return "stairClimbing"
        case .surfingSports: return "surfingSports"
        case .swimming: return "swimming"
        case .tableTennis: return "tableTennis"
        case .tennis: return "tennis"
        case .trackAndField: return "trackAndField"
        case .traditionalStrengthTraining: return "traditionalStrengthTraining"
        case .volleyball: return "volleyball"
        case .walking: return "walking"
        case .waterFitness: return "waterFitness"
        case .waterPolo: return "waterPolo"
        case .waterSports: return "waterSports"
        case .wrestling: return "wrestling"
        case .yoga: return "yoga"
        case .barre: return "barre"
        case .coreTraining: return "coreTraining"
        case .crossCountrySkiing: return "crossCountrySkiing"
        case .downhillSkiing: return "downhillSkiing"
        case .flexibility: return "flexibility"
        case .highIntensityIntervalTraining: return "highIntensityIntervalTraining"
        case .jumpRope: return "jumpRope"
        case .kickboxing: return "kickboxing"
        case .pilates: return "pilates"
        case .snowboarding: return "snowboarding"
        case .stairs: return "stairs"
        case .stepTraining: return "stepTraining"
        case .wheelchairWalkPace: return "wheelchairWalkPace"
        case .wheelchairRunPace: return "wheelchairRunPace"
        case .taiChi: return "taiChi"
        case .mixedCardio: return "mixedCardio"
        case .handCycling: return "handCycling"
        case .discSports: return "discSports"
        case .fitnessGaming: return "fitnessGaming"
        case .cardioDance: return "cardioDance"
        case .socialDance: return "socialDance"
        case .pickleball: return "pickleball"
        case .cooldown: return "cooldown"
        case .swimBikeRun: return "swimBikeRun"
        case .transition: return "transition"
        case .underwaterDiving: return "underwaterDiving"
        case .other: return "other"
        default: return nil
        }
    }
}

extension HealthDataFetcher {
    func stringToHKWorkoutActivityType(string: String) -> HKWorkoutActivityType? {
        switch string {
        case "americanFootball": return HKWorkoutActivityType.americanFootball
        case "archery": return HKWorkoutActivityType.archery
        case "australianFootball": return HKWorkoutActivityType.australianFootball
        case "badminton": return HKWorkoutActivityType.badminton
        case "baseball": return HKWorkoutActivityType.baseball
        case "basketball": return HKWorkoutActivityType.basketball
        case "bowling": return HKWorkoutActivityType.bowling
        case "boxing": return HKWorkoutActivityType.boxing
        case "climbing": return HKWorkoutActivityType.climbing
        case "cricket": return HKWorkoutActivityType.cricket
        case "crossTraining": return HKWorkoutActivityType.crossTraining
        case "curling": return HKWorkoutActivityType.curling
        case "cycling": return HKWorkoutActivityType.cycling
        case "elliptical": return HKWorkoutActivityType.elliptical
        case "equestrianSports": return HKWorkoutActivityType.equestrianSports
        case "fencing": return HKWorkoutActivityType.fencing
        case "fishing": return HKWorkoutActivityType.fishing
        case "functionalStrengthTraining": return HKWorkoutActivityType.functionalStrengthTraining
        case "golf": return HKWorkoutActivityType.golf
        case "gymnastics": return HKWorkoutActivityType.gymnastics
        case "handball": return HKWorkoutActivityType.handball
        case "hiking": return HKWorkoutActivityType.hiking
        case "hockey": return HKWorkoutActivityType.hockey
        case "hunting": return HKWorkoutActivityType.hunting
        case "lacrosse": return HKWorkoutActivityType.lacrosse
        case "martialArts": return HKWorkoutActivityType.martialArts
        case "mindAndBody": return HKWorkoutActivityType.mindAndBody
        case "paddleSports": return HKWorkoutActivityType.paddleSports
        case "play": return HKWorkoutActivityType.play
        case "preparationAndRecovery": return HKWorkoutActivityType.preparationAndRecovery
        case "racquetball": return HKWorkoutActivityType.racquetball
        case "rowing": return HKWorkoutActivityType.rowing
        case "rugby": return HKWorkoutActivityType.rugby
        case "running": return HKWorkoutActivityType.running
        case "sailing": return HKWorkoutActivityType.sailing
        case "skatingSports": return HKWorkoutActivityType.skatingSports
        case "snowSports": return HKWorkoutActivityType.snowSports
        case "soccer": return HKWorkoutActivityType.soccer
        case "softball": return HKWorkoutActivityType.softball
        case "squash": return HKWorkoutActivityType.squash
        case "stairClimbing": return HKWorkoutActivityType.stairClimbing
        case "surfingSports": return HKWorkoutActivityType.surfingSports
        case "swimming": return HKWorkoutActivityType.swimming
        case "tableTennis": return HKWorkoutActivityType.tableTennis
        case "tennis": return HKWorkoutActivityType.tennis
        case "trackAndField": return HKWorkoutActivityType.trackAndField
        case "traditionalStrengthTraining": return HKWorkoutActivityType.traditionalStrengthTraining
        case "volleyball": return HKWorkoutActivityType.volleyball
        case "walking": return HKWorkoutActivityType.walking
        case "waterFitness": return HKWorkoutActivityType.waterFitness
        case "waterPolo": return HKWorkoutActivityType.waterPolo
        case "waterSports": return HKWorkoutActivityType.waterSports
        case "wrestling": return HKWorkoutActivityType.wrestling
        case "yoga": return HKWorkoutActivityType.yoga
        case "barre": return HKWorkoutActivityType.barre
        case "coreTraining": return HKWorkoutActivityType.coreTraining
        case "crossCountrySkiing": return HKWorkoutActivityType.crossCountrySkiing
        case "downhillSkiing": return HKWorkoutActivityType.downhillSkiing
        case "flexibility": return HKWorkoutActivityType.flexibility
        case "highIntensityIntervalTraining": return HKWorkoutActivityType.highIntensityIntervalTraining
        case "jumpRope": return HKWorkoutActivityType.jumpRope
        case "kickboxing": return HKWorkoutActivityType.kickboxing
        case "pilates": return HKWorkoutActivityType.pilates
        case "snowboarding": return HKWorkoutActivityType.snowboarding
        case "stairs": return HKWorkoutActivityType.stairs
        case "stepTraining": return HKWorkoutActivityType.stepTraining
        case "wheelchairWalkPace": return HKWorkoutActivityType.wheelchairWalkPace
        case "wheelchairRunPace": return HKWorkoutActivityType.wheelchairRunPace
        case "taiChi": return HKWorkoutActivityType.taiChi
        case "mixedCardio": return HKWorkoutActivityType.mixedCardio
        case "handCycling": return HKWorkoutActivityType.handCycling
        case "discSports": return HKWorkoutActivityType.discSports
        case "fitnessGaming": return HKWorkoutActivityType.fitnessGaming
        case "cardioDance": return HKWorkoutActivityType.cardioDance
        case "socialDance": return HKWorkoutActivityType.socialDance
        case "pickleball": return HKWorkoutActivityType.pickleball
        case "cooldown": return HKWorkoutActivityType.cooldown
        case "swimBikeRun": return HKWorkoutActivityType.swimBikeRun
        case "transition": return HKWorkoutActivityType.transition
        case "underwaterDiving": return HKWorkoutActivityType.underwaterDiving
        case "other": return HKWorkoutActivityType.other
        default: return nil
        }
    }
}

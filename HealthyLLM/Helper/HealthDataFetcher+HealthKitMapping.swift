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
    static func workoutDataToCSV(_ data: [WorkoutData]) -> String {
        guard let first = data.first else { return "" }
        let statisticKeys = Array(first.statistics.keys)
        
        let header = "name,date,duration,\(statisticKeys.joined(separator: ","))"
        var output = header + "\n"
        
        for datum in data {
            output.append(
                [
                    datum.name,
                    datum.date,
                    datum.duration,
                    datum.statistics.values.joined(separator: ",")
                ].joined(separator: ",")
            )
            output.append("\n")
        }
        
        return output
    }
    
    func allHKQuantityTypeIdentifiers() -> [HKQuantityTypeIdentifier] {
        [
            .appleSleepingWristTemperature,
            .bodyFatPercentage,
            .bodyMass,
            .bodyMassIndex,
            .electrodermalActivity,
            .height,
            .leanBodyMass,
            .waistCircumference,
            .activeEnergyBurned,
            .appleExerciseTime,
            .appleMoveTime,
            .appleStandTime,
            .basalEnergyBurned,
            .crossCountrySkiingSpeed,
            .cyclingCadence,
            .cyclingFunctionalThresholdPower,
            .cyclingPower,
            .cyclingSpeed,
            .distanceCrossCountrySkiing,
            .distanceCycling,
            .distanceDownhillSnowSports,
            .distancePaddleSports,
            .distanceRowing,
            .distanceSkatingSports,
            .distanceSwimming,
            .distanceWalkingRunning,
            .distanceWheelchair,
            .estimatedWorkoutEffortScore,
            .flightsClimbed,
            .nikeFuel,
            .paddleSportsSpeed,
            .physicalEffort,
            .pushCount,
            .rowingSpeed,
            .runningPower,
            .runningSpeed,
            .stepCount,
            .swimmingStrokeCount,
            .underwaterDepth,
            .workoutEffortScore,
            .environmentalAudioExposure,
            .environmentalSoundReduction,
            .headphoneAudioExposure,
            .atrialFibrillationBurden,
            .heartRate,
            .heartRateRecoveryOneMinute,
            .heartRateVariabilitySDNN,
            .peripheralPerfusionIndex,
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
            .dietaryBiotin,
            .dietaryCaffeine,
            .dietaryCalcium,
            .dietaryCarbohydrates,
            .dietaryChloride,
            .dietaryCholesterol,
            .dietaryChromium,
            .dietaryCopper,
            .dietaryEnergyConsumed,
            .dietaryFatMonounsaturated,
            .dietaryFatPolyunsaturated,
            .dietaryFatSaturated,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietaryFolate,
            .dietaryIodine,
            .dietaryIron,
            .dietaryMagnesium,
            .dietaryManganese,
            .dietaryMolybdenum,
            .dietaryNiacin,
            .dietaryPantothenicAcid,
            .dietaryPhosphorus,
            .dietaryPotassium,
            .dietaryProtein,
            .dietaryRiboflavin,
            .dietarySelenium,
            .dietarySodium,
            .dietarySugar,
            .dietaryThiamin,
            .dietaryVitaminA,
            .dietaryVitaminB12,
            .dietaryVitaminB6,
            .dietaryVitaminC,
            .dietaryVitaminD,
            .dietaryVitaminE,
            .dietaryVitaminK,
            .dietaryWater,
            .dietaryZinc,
            .bloodAlcoholContent,
            .bloodPressureDiastolic,
            .bloodPressureSystolic,
            .insulinDelivery,
            .numberOfAlcoholicBeverages,
            .numberOfTimesFallen,
            .timeInDaylight,
            .uvExposure,
            .waterTemperature,
            .basalBodyTemperature,
            .appleSleepingBreathingDisturbances,
            .forcedExpiratoryVolume1,
            .forcedVitalCapacity,
            .inhalerUsage,
            .oxygenSaturation,
            .peakExpiratoryFlowRate,
            .respiratoryRate,
            .bloodGlucose,
            .bodyTemperature
        ]
    }
    
    func hkStringToHKQuantityTypeIdentifier(_ hkString: String) -> (HKQuantityTypeIdentifier, HKUnit)? {
        let _hkString = hkString
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .lowercased()
        
        switch _hkString {
        case "bodyMassIndex".lowercased():
            return (HKQuantityTypeIdentifier.bodyMassIndex, HKUnit.count())
        case "stairDescentSpeed".lowercased():
            return (HKQuantityTypeIdentifier.stairDescentSpeed, HKUnit.meter().unitDivided(by: HKUnit.second()))
        case "swimmingStrokeCount".lowercased():
            return (HKQuantityTypeIdentifier.swimmingStrokeCount, HKUnit.count())
        case "appleSleepingBreathingDisturbances".lowercased():
            return (HKQuantityTypeIdentifier.appleSleepingBreathingDisturbances, HKUnit.count())
        case "activeEnergyBurned".lowercased():
            return (HKQuantityTypeIdentifier.activeEnergyBurned, HKUnit.kilocalorie())
        case "runningVerticalOscillation".lowercased():
            return (HKQuantityTypeIdentifier.runningVerticalOscillation, HKUnit.meter())
        case "walkingSpeed".lowercased():
            return (HKQuantityTypeIdentifier.walkingSpeed, HKUnit.meter().unitDivided(by: HKUnit.second()))
        case "appleExerciseTime".lowercased():
            return (HKQuantityTypeIdentifier.appleExerciseTime, HKUnit.minute())
        case "walkingStepLength".lowercased():
            return (HKQuantityTypeIdentifier.walkingStepLength, HKUnit.meter())
        case "restingHeartRate".lowercased():
            return (HKQuantityTypeIdentifier.restingHeartRate, HKUnit.count().unitDivided(by: HKUnit.minute()))
        case "cyclingCadence".lowercased():
            return (HKQuantityTypeIdentifier.cyclingCadence, HKUnit.count())
        case "heartRateRecoveryOneMinute".lowercased():
            return (HKQuantityTypeIdentifier.heartRateRecoveryOneMinute, HKUnit.count())
        case "distanceWalkingRunning".lowercased():
            return (HKQuantityTypeIdentifier.distanceWalkingRunning, HKUnit.meterUnit(with: .kilo))
        case "environmentalAudioExposure".lowercased():
            return (HKQuantityTypeIdentifier.environmentalAudioExposure, HKUnit.decibelAWeightedSoundPressureLevel())
        case "runningStrideLength".lowercased():
            return (HKQuantityTypeIdentifier.runningStrideLength, HKUnit.meter())
        case "heartRate".lowercased():
            return (HKQuantityTypeIdentifier.heartRate, HKUnit.count().unitDivided(by: HKUnit.minute()))
        case "sixMinuteWalkTestDistance".lowercased():
            return (HKQuantityTypeIdentifier.sixMinuteWalkTestDistance, HKUnit.meter())
        case "appleStandTime".lowercased():
            return (HKQuantityTypeIdentifier.appleStandTime, HKUnit.minute())
        case "runningPower".lowercased():
            return (HKQuantityTypeIdentifier.runningPower, HKUnit.watt())
        case "basalEnergyBurned".lowercased():
            return (HKQuantityTypeIdentifier.basalEnergyBurned, HKUnit.kilocalorie())
        case "distanceCycling".lowercased():
            return (HKQuantityTypeIdentifier.distanceCycling, HKUnit.meterUnit(with: .kilo))
        case "headphoneAudioExposure".lowercased():
            return (HKQuantityTypeIdentifier.headphoneAudioExposure, HKUnit.decibelAWeightedSoundPressureLevel())
        case "leanBodyMass".lowercased():
            return (HKQuantityTypeIdentifier.leanBodyMass, HKUnit.gramUnit(with: .kilo))
        case "appleSleepingWristTemperature".lowercased():
            return (HKQuantityTypeIdentifier.appleSleepingWristTemperature, HKUnit.degreeCelsius())
        case "timeInDaylight".lowercased():
            return (HKQuantityTypeIdentifier.timeInDaylight, HKUnit.minute())
        case "bodyMass".lowercased():
            return (HKQuantityTypeIdentifier.bodyMass, HKUnit.gramUnit(with: .kilo))
        case "heartRateVariabilitySDNN".lowercased():
            return (HKQuantityTypeIdentifier.heartRateVariabilitySDNN, HKUnit.secondUnit(with: .milli))
        case "walkingAsymmetryPercentage".lowercased():
            return (HKQuantityTypeIdentifier.walkingAsymmetryPercentage, HKUnit.percent())
        case "oxygenSaturation".lowercased():
            return (HKQuantityTypeIdentifier.oxygenSaturation, HKUnit.percent())
        case "distanceDownhillSnowSports".lowercased():
            return (HKQuantityTypeIdentifier.distanceDownhillSnowSports, HKUnit.meterUnit(with: .kilo))
        case "runningSpeed".lowercased():
            return (HKQuantityTypeIdentifier.runningSpeed, HKUnit.meterUnit(with: .kilo).unitDivided(by: HKUnit.hour()))
        case "walkingDoubleSupportPercentage".lowercased():
            return (HKQuantityTypeIdentifier.walkingDoubleSupportPercentage, HKUnit.percent())
        case "distanceSwimming".lowercased():
            return (HKQuantityTypeIdentifier.distanceSwimming, HKUnit.meterUnit(with: .kilo))
        case "runningGroundContactTime".lowercased():
            return (HKQuantityTypeIdentifier.runningGroundContactTime, HKUnit.second())
        case "vo2Max".lowercased():
            return (HKQuantityTypeIdentifier.vo2Max, HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitMultiplied(by: .minute()))
        case "stairAscentSpeed".lowercased():
            return (HKQuantityTypeIdentifier.stairAscentSpeed, HKUnit.meter().unitDivided(by: HKUnit.second()))
        case "respiratoryRate".lowercased():
            return (HKQuantityTypeIdentifier.respiratoryRate, HKUnit.count().unitDivided(by: HKUnit.minute()))
        case "stepCount".lowercased():
            return (HKQuantityTypeIdentifier.stepCount, HKUnit.count())
        case "walkingHeartRateAverage".lowercased():
            return (HKQuantityTypeIdentifier.walkingHeartRateAverage, HKUnit.count().unitDivided(by: .minute()))
        case "appleWalkingSteadiness".lowercased():
            return (HKQuantityTypeIdentifier.appleWalkingSteadiness, HKUnit.percent())
        case "bodyFatPercentage".lowercased():
            return (HKQuantityTypeIdentifier.bodyFatPercentage, HKUnit.percent())
        case "flightsClimbed".lowercased():
            return (HKQuantityTypeIdentifier.flightsClimbed, HKUnit.count())
        default:
            return nil
        }
    }
    
    func workoutStringToHKWorkoutActivityType(_ workoutString: String) -> HKWorkoutActivityType? {
        switch workoutString {
        case "americanFootball":
            return HKWorkoutActivityType.americanFootball
        case "archery":
            return HKWorkoutActivityType.archery
        case "australianFootball":
            return HKWorkoutActivityType.australianFootball
        case "badminton":
            return HKWorkoutActivityType.badminton
        case "baseball":
            return HKWorkoutActivityType.baseball
        case "basketball":
            return HKWorkoutActivityType.basketball
        case "bowling":
            return HKWorkoutActivityType.bowling
        case "boxing":
            return HKWorkoutActivityType.boxing
        case "climbing":
            return HKWorkoutActivityType.climbing
        case "cricket":
            return HKWorkoutActivityType.cricket
        case "crossTraining":
            return HKWorkoutActivityType.crossTraining
        case "curling":
            return HKWorkoutActivityType.curling
        case "cycling":
            return HKWorkoutActivityType.cycling
        case "elliptical":
            return HKWorkoutActivityType.elliptical
        case "equestrianSports":
            return HKWorkoutActivityType.equestrianSports
        case "fencing":
            return HKWorkoutActivityType.fencing
        case "fishing":
            return HKWorkoutActivityType.fishing
        case "functionalStrengthTraining":
            return HKWorkoutActivityType.functionalStrengthTraining
        case "golf":
            return HKWorkoutActivityType.golf
        case "gymnastics":
            return HKWorkoutActivityType.gymnastics
        case "handball":
            return HKWorkoutActivityType.handball
        case "hiking":
            return HKWorkoutActivityType.hiking
        case "hockey":
            return HKWorkoutActivityType.hockey
        case "hunting":
            return HKWorkoutActivityType.hunting
        case "lacrosse":
            return HKWorkoutActivityType.lacrosse
        case "martialArts":
            return HKWorkoutActivityType.martialArts
        case "mindAndBody":
            return HKWorkoutActivityType.mindAndBody
        case "paddleSports":
            return HKWorkoutActivityType.paddleSports
        case "play":
            return HKWorkoutActivityType.play
        case "preparationAndRecovery":
            return HKWorkoutActivityType.preparationAndRecovery
        case "racquetball":
            return HKWorkoutActivityType.racquetball
        case "rowing":
            return HKWorkoutActivityType.rowing
        case "rugby":
            return HKWorkoutActivityType.rugby
        case "running":
            return HKWorkoutActivityType.running
        case "sailing":
            return HKWorkoutActivityType.sailing
        case "skatingSports":
            return HKWorkoutActivityType.skatingSports
        case "snowSports":
            return HKWorkoutActivityType.snowSports
        case "soccer":
            return HKWorkoutActivityType.soccer
        case "softball":
            return HKWorkoutActivityType.softball
        case "squash":
            return HKWorkoutActivityType.squash
        case "stairClimbing":
            return HKWorkoutActivityType.stairClimbing
        case "surfingSports":
            return HKWorkoutActivityType.surfingSports
        case "swimming":
            return HKWorkoutActivityType.swimming
        case "tableTennis":
            return HKWorkoutActivityType.tableTennis
        case "tennis":
            return HKWorkoutActivityType.tennis
        case "trackAndField":
            return HKWorkoutActivityType.trackAndField
        case "traditionalStrengthTraining":
            return HKWorkoutActivityType.traditionalStrengthTraining
        case "volleyball":
            return HKWorkoutActivityType.volleyball
        case "walking":
            return HKWorkoutActivityType.walking
        case "waterFitness":
            return HKWorkoutActivityType.waterFitness
        case "waterPolo":
            return HKWorkoutActivityType.waterPolo
        case "waterSports":
            return HKWorkoutActivityType.waterSports
        case "wrestling":
            return HKWorkoutActivityType.wrestling
        case "yoga":
            return HKWorkoutActivityType.yoga
        case "barre":
            return HKWorkoutActivityType.barre
        case "coreTraining":
            return HKWorkoutActivityType.coreTraining
        case "crossCountrySkiing":
            return HKWorkoutActivityType.crossCountrySkiing
        case "downhillSkiing":
            return HKWorkoutActivityType.downhillSkiing
        case "flexibility":
            return HKWorkoutActivityType.flexibility
        case "highIntensityIntervalTraining":
            return HKWorkoutActivityType.highIntensityIntervalTraining
        case "jumpRope":
            return HKWorkoutActivityType.jumpRope
        case "kickboxing":
            return HKWorkoutActivityType.kickboxing
        case "pilates":
            return HKWorkoutActivityType.pilates
        case "snowboarding":
            return HKWorkoutActivityType.snowboarding
        case "stairs":
            return HKWorkoutActivityType.stairs
        case "stepTraining":
            return HKWorkoutActivityType.stepTraining
        case "wheelchairWalkPace":
            return HKWorkoutActivityType.wheelchairWalkPace
        case "wheelchairRunPace":
            return HKWorkoutActivityType.wheelchairRunPace
        case "taiChi":
            return HKWorkoutActivityType.taiChi
        case "mixedCardio":
            return HKWorkoutActivityType.mixedCardio
        case "handCycling":
            return HKWorkoutActivityType.handCycling
        case "discSports":
            return HKWorkoutActivityType.discSports
        case "fitnessGaming":
            return HKWorkoutActivityType.fitnessGaming
        case "cardioDance":
            return HKWorkoutActivityType.cardioDance
        case "socialDance":
            return HKWorkoutActivityType.socialDance
        case "pickleball":
            return HKWorkoutActivityType.pickleball
        case "cooldown":
            return HKWorkoutActivityType.cooldown
        case "swimBikeRun":
            return HKWorkoutActivityType.swimBikeRun
        case "transition":
            return HKWorkoutActivityType.transition
        case "underwaterDiving":
            return HKWorkoutActivityType.underwaterDiving
        case "other":
            return HKWorkoutActivityType.other
        default:
            return nil
        }
    }
}


extension HKBiologicalSex: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notSet:
            return "Not Set"
        case .female:
            return "Female"
        case .male:
            return "Male"
        case .other:
            return "Other"
        @unknown default:
            return "N/A"
        }
    }
}


extension HKWorkoutActivityType {
    var name: String {
        Mirror(reflecting: self).description
    }
}


extension HKQuantityTypeIdentifier {
    var siUnit: HKUnit? {
        switch self {
        case .bodyMassIndex:
            return .count()
        case .stairDescentSpeed:
            return .meter().unitDivided(by: .second())
        case .swimmingStrokeCount:
            return .count()
        case .appleSleepingBreathingDisturbances:
            return .count()
        case .activeEnergyBurned:
            return .kilocalorie()
        case .runningVerticalOscillation:
            return .meter()
        case .walkingSpeed:
            return .meter().unitDivided(by: .second())
        case .appleExerciseTime:
            return .minute()
        case .walkingStepLength:
            return .meter()
        case .restingHeartRate:
            return .count().unitDivided(by: .minute())
        case .cyclingCadence:
            return .count().unitDivided(by: .minute())
        case .heartRateRecoveryOneMinute:
            return .count()
        case .distanceWalkingRunning:
            return .meterUnit(with: .kilo)
        case .environmentalAudioExposure:
            return .decibelAWeightedSoundPressureLevel()
        case .runningStrideLength:
            return .meter()
        case .heartRate:
            return .count().unitDivided(by: .minute())
        case .sixMinuteWalkTestDistance:
            return .meter()
        case .appleStandTime:
            return .minute()
        case .runningPower:
            return .watt()
        case .basalEnergyBurned:
            return .kilocalorie()
        case .distanceCycling:
            return .meterUnit(with: .kilo)
        case .headphoneAudioExposure:
            return .decibelAWeightedSoundPressureLevel()
        case .leanBodyMass:
            return .gramUnit(with: .kilo)
        case .appleSleepingWristTemperature:
            return .degreeCelsius()
        case .timeInDaylight:
            return .minute()
        case .bodyMass:
            return .gramUnit(with: .kilo)
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        case .walkingAsymmetryPercentage:
            return .percent()
        case .oxygenSaturation:
            return .percent()
        case .distanceDownhillSnowSports:
            return .meterUnit(with: .kilo)
        case .runningSpeed:
            return .meterUnit(with: .kilo).unitDivided(by: .hour())
        case .walkingDoubleSupportPercentage:
            return .percent()
        case .distanceSwimming:
            return .meterUnit(with: .kilo)
        case .runningGroundContactTime:
            return .second()
        case .vo2Max:
            return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case .stairAscentSpeed:
            return .meter().unitDivided(by: .second())
        case .respiratoryRate:
            return .count().unitDivided(by: .minute())
        case .stepCount:
            return .count()
        case .walkingHeartRateAverage:
            return .count().unitDivided(by: .minute())
        case .appleWalkingSteadiness:
            return .percent()
        case .bodyFatPercentage:
            return .percent()
        case .flightsClimbed:
            return .count()
        default:
            return nil
        }
    }
}

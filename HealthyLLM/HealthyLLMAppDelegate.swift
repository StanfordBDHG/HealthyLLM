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
import SpeziLLM
import SpeziLLMLocal
import SwiftUI


class HealthyLLMAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: HealthyStandard()) {
            LLMRunner {
                LLMLocalPlatform()
            }
            HealthDataFetcher()
            HealthDataInterpreter()
            HealthContextGenerator()

            if HKHealthStore.isHealthDataAvailable() {
                HealthKit()
            }
        }
    }
}

actor HealthyStandard: Standard, HealthKitConstraint {
    // Add the newly collected HealthKit samples to your application.
    func handleNewSamples<Sample>(
        _ addedSamples: some Collection<Sample>,
        ofType sampleType: SampleType<Sample>
    ) async {
    }

    // Remove the deleted HealthKit objects from your application.
    func handleDeletedObjects<Sample>(
        _ deletedObjects: some Collection<HKDeletedObject>,
        ofType sampleType: SampleType<Sample>
    ) async {
    }
}

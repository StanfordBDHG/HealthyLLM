//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import SpeziOnboarding
import SwiftUI

struct OnboardingFlow: View {
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            Welcome()
            Disclaimer()
            DownloadLLM()
            
            if HKHealthStore.isHealthDataAvailable() {
                HealthKitPermissions()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!completedOnboardingFlow)
    }
}

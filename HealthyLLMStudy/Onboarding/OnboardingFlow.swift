//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import SpeziOnboarding
import SwiftUI

struct OnboardingFlow: View {
    @Binding var completedOnboardingFlow: Bool
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            Welcome()
            
            Clarification()
            
            if HKHealthStore.isHealthDataAvailable() {
                HealthKitPermissions()
            } else {
                ContentUnavailableView(
                    "HEALTHKIT_NOT_AVAILABLE",
                    systemImage: "heart.slash",
                    description: Text("HEALTHKIT_NOT_AVAILABLE_DESCRIPTION")
                )
#if DEBUG
                .onTapGesture(count: 3) {
                    completedOnboardingFlow = true
                }
#endif
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!completedOnboardingFlow)
    }
}

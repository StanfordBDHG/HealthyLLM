//
//  OnboardingFlow.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/6/25.
//

import SwiftUI
import SpeziOnboarding
import HealthKit

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

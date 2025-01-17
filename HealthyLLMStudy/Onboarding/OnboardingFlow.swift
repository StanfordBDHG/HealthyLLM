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
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            Welcome()
            
            Clarification()
            
            DownloadLLM()
            
            if HKHealthStore.isHealthDataAvailable() {
                HealthKitPermissions()
            } else {
                ContentUnavailableView(
                    "HEALTHKIT_NOT_AVAILABLE",
                    systemImage: "heart.slash",
                    description: Text("HEALTHKIT_NOT_AVAILABLE_DESCRIPTION")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!completedOnboardingFlow)
    }
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import HealthKit
import SpeziOnboarding

struct HealthKitPermissions: View {
    @Environment(OnboardingNavigationPath.self) private var onboardingNavigationPath
    @Environment(HealthDataFetcher.self) private var healthDataFetcher
    
    @State var healthKitProcessing = false
    
    var body: some View {
        OnboardingView(
            contentView: {
                VStack {
                    OnboardingTitleView(
                        title: "HEALTHKIT_PERMISSIONS_TITLE",
                        subtitle: "HEALTHKIT_PERMISSIONS_SUBTITLE"
                    )
                    Spacer()
                    Image(systemName: "heart.text.square.fill")
                        .accessibilityHidden(true)
                        .font(.system(size: 150))
                        .foregroundColor(.accentColor)
                    Text("HEALTHKIT_PERMISSIONS_DESCRIPTION")
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                    Spacer()
                }
            }, actionView: {
                OnboardingActionsView(
                    "HEALTHKIT_PERMISSIONS_BUTTON",
                    action: {
                        do {
                            healthKitProcessing = true
                            try await healthDataFetcher.askForAuthorization()
                        } catch {
                            print("Could not request HealthKit permissions: \(error.localizedDescription)")
                        }
                        onboardingNavigationPath.nextStep()
                        healthKitProcessing = false
                    }
                )
            }
        )
            .navigationBarBackButtonHidden(healthKitProcessing)
    }
}

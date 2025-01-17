//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziOnboarding

struct Welcome: View {
    @Environment(OnboardingNavigationPath.self) private var onboardingNavigationPath: OnboardingNavigationPath?
    
    var body: some View {
        OnboardingView(
            title: "WELCOME_TITLE",
            subtitle: "WELCOME_SUBTITLE",
            areas: [
                .init(
                    icon: Image(systemName: "list.bullet.clipboard.fill"), // swiftlint:disable:this accessibility_label_for_image
                    title: "WELCOME_AREA1_TITLE",
                    description: "WELCOME_AREA1_DESCRIPTION"
                ),
                .init(
                    icon: Image(systemName: "applewatch.side.right"), // swiftlint:disable:this accessibility_label_for_image
                    title: "WELCOME_AREA2_TITLE",
                    description: "WELCOME_AREA2_DESCRIPTION"
                ),
                .init(
                    icon: Image(systemName: "shippingbox.fill"), // swiftlint:disable:this accessibility_label_for_image
                    title: "WELCOME_AREA3_TITLE",
                    description: "WELCOME_AREA3_DESCRIPTION"
                )
            ],
            actionText: "WELCOME_BUTTON",
            action: {
                onboardingNavigationPath?.nextStep()
            }
        )
    }
}

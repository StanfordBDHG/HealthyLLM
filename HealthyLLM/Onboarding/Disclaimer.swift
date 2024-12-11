//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziOnboarding
import SwiftUI


struct Disclaimer: View {
    @Environment(OnboardingNavigationPath.self) private var onboardingNavigationPath
    
    var body: some View {
        SequentialOnboardingView(
            title: "INTERESTING_MODULES_TITLE",
            subtitle: "INTERESTING_MODULES_SUBTITLE",
            content: [
                .init(
                    title: "INTERESTING_MODULES_AREA1_TITLE",
                    description: "INTERESTING_MODULES_AREA1_DESCRIPTION"
                ),
                .init(
                    title: "INTERESTING_MODULES_AREA2_TITLE",
                    description: "INTERESTING_MODULES_AREA2_DESCRIPTION"
                ),
                .init(
                    title: "INTERESTING_MODULES_AREA3_TITLE",
                    description: "INTERESTING_MODULES_AREA3_DESCRIPTION"
                ),
                .init(
                    title: "INTERESTING_MODULES_AREA4_TITLE",
                    description: "INTERESTING_MODULES_AREA4_DESCRIPTION"
                )
            ],
            actionText: "INTERESTING_MODULES_BUTTON",
            action: {
                onboardingNavigationPath.nextStep()
            }
        )
    }
}

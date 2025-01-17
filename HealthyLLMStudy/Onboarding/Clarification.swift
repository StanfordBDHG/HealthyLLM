//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziOnboarding
import SwiftUI


struct Clarification: View {
    @Environment(OnboardingNavigationPath.self) private var onboardingNavigationPath
    
    var body: some View {
        SequentialOnboardingView(
            title: "CLARIFICATION_TITLE",
            subtitle: "CLARIFICATION_SUBTITLE",
            content: [
                .init(
                    title: "CLARIFICATION_ITEM1_TITLE",
                    description: "CLARIFICATION_ITEM1_DESCIPTION"
                ),
                .init(
                    title: "CLARIFICATION_ITEM2_TITLE",
                    description: "CLARIFICATION_ITEM2_DESCIPTION"
                ),
                .init(
                    title: "CLARIFICATION_ITEM3_TITLE",
                    description: "CLARIFICATION_ITEM3_DESCIPTION"
                ),
                .init(
                    title: "CLARIFICATION_ITEM4_TITLE",
                    description: "CLARIFICATION_ITEM4_DESCIPTION"
                )
            ],
            actionText: "CLARIFICATION_BUTTON",
            action: {
                onboardingNavigationPath.nextStep()
            }
        )
    }
}

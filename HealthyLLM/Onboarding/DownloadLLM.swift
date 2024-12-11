//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziOnboarding
import SpeziLLMLocalDownload

struct DownloadLLM: View {
    @Environment(OnboardingNavigationPath.self) private var onboardingNavigationPath
    
    var body: some View {
        LLMLocalDownloadView(
            model: .custom(id: Constants.llmModelName),
            downloadDescription: "DOWNLOAD_MODEL_DESCRIPTION `\(Constants.llmModelName)`") {
                onboardingNavigationPath.nextStep()
            }
    }
}

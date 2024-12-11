//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

enum StorageKeys {
    // MARK: - Onboarding
    /// A `Bool` flag indicating of the onboarding was completed.
    static let onboardingFlowComplete = "onboardingFlow.complete"
    /// A `Step` flag indicating the current step in the onboarding process.
    static let onboardingFlowStep = "onboardingFlow.step"
    
    static let advancedMode = "advancedMode"
}

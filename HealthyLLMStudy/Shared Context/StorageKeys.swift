//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

enum StorageKeys {
    // MARK: - Onboarding
    static let onboardingFlowComplete = "onboardingFlow.complete"
    static let onboardingFlowStep = "onboardingFlow.step"
    static let studyFlowComplete = "studyFlow.complete"
    static let homeStudyFlowComplete = "homeStudyFlow.complete"
    static let studyFlowStep = "studyFlow.step"
    static let debugViewPresented = "debugView.presented"
    static let sufficientUsage = "chat.sufficientUsage"
    static let participantId = "participantId"
    static let age = "age"
    static let sex = "sex"
    static let performanceLogInterval = 0.5
    static let performanceSaveInterval = 5.0
}

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ResearchKitSwiftUI
import SpeziOnboarding
import SpeziQuestionnaire
import SwiftUI


struct QuestionnaireViewWrapper: View {
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath: OnboardingNavigationPath?
    let questionnaire: Questionnaire
    let completionStepMessage: String?
    let cancelBehavior: CancelBehavior
    let handleQuestionnaireResponse: (QuestionnaireResponse) async -> Void
    
    init(
        questionnaire: Questionnaire,
        completionStepMessage: String? = nil,
        cancelBehavior: CancelBehavior = .shouldConfirmCancel,
        questionnaireResponse: @escaping (QuestionnaireResponse) -> Void
    ) {
        self.questionnaire = questionnaire
        self.completionStepMessage = completionStepMessage
        self.cancelBehavior = cancelBehavior
        self.handleQuestionnaireResponse = questionnaireResponse
    }
    
    var body: some View {
        QuestionnaireView(
            questionnaire: questionnaire,
            completionStepMessage: completionStepMessage,
            cancelBehavior: cancelBehavior,
            questionnaireResult: handleQuestionnaireResult
        )
        .toolbar(.hidden)
    }
    
    private func handleQuestionnaireResult(_ result: QuestionnaireResult) async {
        if case .completed(let questionnaireResponse) = result {
            await handleQuestionnaireResponse(questionnaireResponse)
            studyNavigationPath?.nextStep()
        }
    }
}

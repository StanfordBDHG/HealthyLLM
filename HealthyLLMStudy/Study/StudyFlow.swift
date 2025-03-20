//
//  StudyFlow.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/6/25.
//

import SpeziOnboarding
import SpeziQuestionnaire
import SwiftUI


struct StudyFlow: View {
    @AppStorage(StorageKeys.studyFlowComplete) private var studyFlowComplete = false
    @AppStorage(StorageKeys.participantId) private var participantId: Int = 0
    @Environment(SharedLocalLLM.self) private var sharedLLM
    @Environment(FunctionCallingProcessor.self) private var functionCallingProcessor
    @Environment(ContextWindowProcessor.self) private var contextWindowProcessor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $studyFlowComplete) {
            // MARK: Info
            InfoView()
                .onboardingIdentifier("Info")
            
            // MARK: Cross Over Study Design
            let studyPhases: [(id: String, processor: ChatProcessor)] = [
                (id: "FunctionCalling", processor: functionCallingProcessor),
                (id: "ContextWindow", processor: contextWindowProcessor)
            ]

            let orderedPhases = participantId.isMultiple(of: 2) ? studyPhases : studyPhases.reversed()

            for phase in orderedPhases {
                StudyChatView(id: phase.id, processor: phase.processor)
                    .onboardingIdentifier("\(phase.id) - Chat")
                
                QuestionnaireViewWrapper(
                    questionnaire: .rating,
                    cancelBehavior: .disabled,
                    questionnaireResponse: Persistance.shared.saveQuestionnaire(questionnaireResponse:)
                )
                .onboardingIdentifier("\(phase.id) - Questionnaire")
            }
            
            // MARK: Additional Open Questions
            QuestionnaireViewWrapper(
                questionnaire: .additionalQuestions,
                cancelBehavior: .disabled,
                questionnaireResponse: Persistance.shared.saveQuestionnaire(questionnaireResponse:)
            )
            .onboardingIdentifier("AdditionalQuestions - Questionnaire")
            .onAppear {
                Task {
                    await sharedLLM.offloadModel()
                }
            }
            
            // MARK: Category Specific Questions
            QuestionnaireViewWrapper(
                questionnaire: .additionalSpecificQuestions,
                cancelBehavior: .disabled,
                questionnaireResponse: Persistance.shared.saveQuestionnaire(questionnaireResponse:)
            )
            .onboardingIdentifier("AdditionalSpecificQuestions - Questionnaire")
            
            // MARK: Final Quesitionnaire
            QuestionnaireViewWrapper(
                questionnaire: .sus,
                completionStepMessage: "FINISHED",
                cancelBehavior: .disabled,
                questionnaireResponse: finishStudy(questionnaireResponse:)
            )
            .onboardingIdentifier("SystemUsabilityScale - Questionnaire")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func finishStudy(questionnaireResponse: QuestionnaireResponse) {
        Persistance.shared.saveQuestionnaire(questionnaireResponse: questionnaireResponse)
        studyFlowComplete = true
        dismiss()
    }
}

//
//  StudyFlow.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/6/25.
//

import SwiftUI
import SpeziOnboarding
import SpeziQuestionnaire

struct StudyFlow: View {
    @AppStorage(StorageKeys.studyFlowComplete) var studyFlowComplete = false
    
    var body: some View {
        OnboardingStack(onboardingFlowComplete: $studyFlowComplete) {
            
            // MARK: - 0. Info
            InfoView()
            
            // MARK: - 1. Local LLM with Function Calling
            StudyChatView(
                type: .functionCalling,
                studyStepName: "Local LLM with Function Calling"
            )
            .navigationBarBackButtonHidden()
            
            QuestionnaireViewWrapper(
                questionnaire: .rating,
                studyStepName: "Local LLM with Function Calling"
            )
            
            // MARK: - 2. Local LLM with prefilled context
            StudyChatView(
                type: .contextWindow,
                studyStepName: "Local LLM with Context Window"
            )
            .navigationBarBackButtonHidden()

            QuestionnaireViewWrapper(
                questionnaire: .rating,
                studyStepName: "Local LLM with Context Window"
            )

            // MARK: - 3. Survey
            QuestionnaireViewWrapper(
                questionnaire: .final,
                studyStepName: "Final Questionnaire"
            )
        }
    }
}

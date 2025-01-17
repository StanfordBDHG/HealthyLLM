//
//  QuestionnaireViewWrapper.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/10/25.
//

import SwiftUI
import SpeziOnboarding
import SpeziQuestionnaire


struct QuestionnaireViewWrapper: View {
    let questionnaire: Questionnaire
    let studyStepName: String
    
    @Environment(\.modelContext) private var storageContext
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath
    
    var body: some View {
        QuestionnaireView(
            questionnaire: questionnaire,
            completionStepMessage: "Completed",
            cancelBehavior: .disabled
        ) { result in
            guard case .completed(let response) = result,
                  let jsonData = response.asJSONString() else { return }
            
            let rating = StudyResponse(
                name: studyStepName,
                result: jsonData
            )
            storageContext.insert(rating)

            studyNavigationPath.nextStep()
        }
    }
}

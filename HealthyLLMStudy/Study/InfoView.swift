//
//  InfoView.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/15/25.
//

import SwiftUI
import SpeziOnboarding


struct InfoView: View {
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("STUDY_INFORMATION_BODY")
                    .padding()
                
                Spacer()
                
                Button {
                    studyNavigationPath.nextStep()
                } label: {
                    Text("Start")
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("STUDY_INFORMATION_TITLE")
        }
    }
}


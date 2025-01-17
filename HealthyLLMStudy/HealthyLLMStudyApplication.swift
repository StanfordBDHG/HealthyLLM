//
//  HealthyLLMStudyApp.swift
//  HealthyLLMStudy
//
//  Created by Leon Nissen on 1/6/25.
//

import SwiftUI
import SwiftData

@main
struct HealthyLLMStudyApplication: App {
    @UIApplicationDelegateAdaptor(HealthyLLMStudyAppDelegate.self) var appDelegate
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = true
    @State private var debugViewPresented = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if completedOnboardingFlow {
                    MainView()
                } else {
                    EmptyView()
                }
            }
            .sheet(isPresented: !$completedOnboardingFlow) {
                OnboardingFlow()
            }
            .sheet(isPresented: $debugViewPresented) {
                DebugView()
            }
            .onShake {
                debugViewPresented = true
            }
            .spezi(appDelegate)
            .modelContainer(for: [
                StudyMetadata.self,
                StudyStep.self,
                StudyResponse.self
            ])
        }
    }
}

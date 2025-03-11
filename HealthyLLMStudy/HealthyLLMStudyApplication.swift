//
//  HealthyLLMStudyApp.swift
//  HealthyLLMStudy
//
//  Created by Leon Nissen on 1/6/25.
//

import SwiftUI
import SwiftData
import Spezi

@main
struct HealthyLLMStudyApplication: App {
    @UIApplicationDelegateAdaptor(HealthyLLMStudyAppDelegate.self) var appDelegate
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    @State private var showDeviceUnavailable = false
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if completedOnboardingFlow {
                    MainView()
                } else {
                    EmptyView()
                }
            }
            .spezi(appDelegate)
            .fullScreenCover(isPresented: $showDeviceUnavailable) {
                ContentUnavailableView(
                    "DEVICE_UNAVAILBLE",
                    systemImage: "iphone.gen3.badge.exclamationmark",
                    description: Text("DEVICE_UNAVAILBLE_DESCRIPTION")
                )
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: !$completedOnboardingFlow) {
                OnboardingFlow(completedOnboardingFlow: $completedOnboardingFlow)
                    .spezi(appDelegate)
            }
            .onAppear {
                let total = ProcessInfo.processInfo.physicalMemory
                let minCapacity = UInt64(8 * 1e9)
                
                if total < minCapacity {
                    self.completedOnboardingFlow = true
                    self.showDeviceUnavailable = true
                }
            }
        }
    }
}

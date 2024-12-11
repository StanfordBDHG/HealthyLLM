//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI

extension String: Identifiable {
    public var id: Self { self }
}

struct HealthyLLMView: View {
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    @Environment(HealthDataInterpreter.self) private var healthDataInterpreter
    
    @State private var showSettings = false
    @State private var showWelcome = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var firstPrompt: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if healthDataInterpreter.loaded {
                    VStack {
                        ChatInputView { query in
                            firstPrompt = query
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            settingsButton
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showWelcome = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
                } else {
                    loadingChatView
                }
            }
        }
        .sheet(item: $firstPrompt) {
            HealthyLLMChatView(firstPrompt: $0)
                .environment(healthDataInterpreter)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showWelcome) {
            Welcome {
                self.showWelcome = false
            }
        }
        .alert("ERROR_ALERT_TITLE", isPresented: $showErrorAlert) {
            Button("ERROR_ALERT_CANCEL", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            do {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    
                } else {
                    try await healthDataInterpreter.setup()
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private var settingsButton: some View {
        Button(
            action: {
                showSettings = true
            },
            label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel(Text("OPEN_SETTINGS"))
            }
        )
        .accessibilityIdentifier("settingsButton")
    }
    
    private var loadingChatView: some View {
        VStack {
            Text("LOADING_CHAT_VIEW")
            ProgressView()
        }
    }
}

#Preview {
    HealthyLLMView()
}

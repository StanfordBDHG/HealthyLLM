//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziHealthKit
import Hub
import SpeziLLMLocalDownload

extension String: Identifiable {
    public var id: Self { self }
}

struct HealthyLLMView: View {
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    @Environment(HealthDataInterpreter.self) private var healthDataInterpreter
    @Environment(HealthKit.self) private var healthKit
    
    @State private var showSettings = false
    @State private var showWelcome = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var firstPrompt: String?
    @State private var showModelDownload = false
    @State private var didAttemptInitialization = false
    
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
        .sheet(isPresented: $showModelDownload) {
            LLMLocalDownloadView(
                model: .custom(id: Constants.llmModelName),
                downloadDescription: "Download the \(Constants.llmModelName) model from Hugging Face."
            ) {
                showModelDownload = false
                Task {
                    await initializeInterpreterIfPossible()
                }
            }
        }
        .alert("ERROR_ALERT_TITLE", isPresented: $showErrorAlert) {
            Button("ERROR_ALERT_CANCEL", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if didAttemptInitialization {
                return
            }

            didAttemptInitialization = true
            await initializeInterpreterIfPossible()
        }
    }

    @MainActor
    private func initializeInterpreterIfPossible() async {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }

        guard localModelExists() || localModelSourceExists() else {
            showModelDownload = true
            return
        }

        do {
            try await healthDataInterpreter.setup()
            firstPrompt = Constants.ecgAutoPrompt
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func localModelExists() -> Bool {
        let repoURL = HubApi().localRepoLocation(.init(id: Constants.llmModelName))
        let modelFileURL = repoURL.appendingPathComponent("model.safetensors")
        return FileManager.default.fileExists(atPath: modelFileURL.path)
    }

    private func localModelSourceExists() -> Bool {
        let fileManager = FileManager.default

        if let overridePath = Constants.localModelSourcePathOverride,
           fileManager.fileExists(atPath: NSString(string: overridePath).expandingTildeInPath) {
            return true
        }

        if let bundledLocalModelURL = Bundle.main.resourceURL?
            .appendingPathComponent(Constants.localModelBundleSubdirectory, isDirectory: true) {
            return fileManager.fileExists(atPath: bundledLocalModelURL.path)
        }

        return false
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

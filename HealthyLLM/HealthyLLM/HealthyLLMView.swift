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
import OSLog
import SpeziLLMLocal
import SpeziLLMLocalDownload

extension String: Identifiable {
    public var id: Self { self }
}

struct HealthyLLMView: View {
    private static let logger = Logger(subsystem: "HealthyLLM", category: "HealthyLLMView")

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
    @State private var needsModelDownload = false
    
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
            Self.logger.info("initializeInterpreterIfPossible: skipping (running in previews)")
            return
        }

        let modelExists = localModelExists()
        let sourceExists = localModelSourceExists()
        Self.logger.info("initializeInterpreterIfPossible: modelExists=\(modelExists, privacy: .public) sourceExists=\(sourceExists, privacy: .public) modelID=\(Constants.llmModelName, privacy: .public) destination=\(Constants.llmLocalModelDirectory.path, privacy: .public)")

        guard modelExists || sourceExists else {
            Self.logger.info("initializeInterpreterIfPossible: no local model or source found — surfacing download UI")
            needsModelDownload = true
            if !showModelDownload {
                showModelDownload = true
            }
            return
        }

        needsModelDownload = false

        Self.logger.info("initializeInterpreterIfPossible: calling healthDataInterpreter.setup()")
        do {
            try await healthDataInterpreter.setup()
            if Constants.autoOpenTSLMECGSampleOnLaunch {
                Self.logger.info("initializeInterpreterIfPossible: setup() returned; auto-opening OpenTSLM ECG sample")
                firstPrompt = Constants.openTSLMECGSampleCommand
            } else if Constants.autoECGPromptOnLaunch {
                Self.logger.info("initializeInterpreterIfPossible: setup() returned; auto-opening ECG prompt")
                firstPrompt = Constants.ecgAutoPrompt
            } else {
                Self.logger.info("initializeInterpreterIfPossible: setup() returned; waiting for user input")
            }
        } catch {
            Self.logger.error("initializeInterpreterIfPossible: setup() threw: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func localModelExists() -> Bool {
        // Use the same check Spezi/HubApi uses, so we never disagree about whether the model is present.
        LLMLocalDownloadManager.modelExist(model: .custom(id: Constants.llmModelName))
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
        VStack(spacing: 12) {
            if needsModelDownload {
                Image(systemName: "tray.and.arrow.down")
                    .font(.largeTitle)
                Text("Model not found on this device")
                    .font(.headline)
                Text("Repo: \(Constants.llmModelName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tap below to download. The model is gated — make sure you have accepted its license on Hugging Face and have HF_TOKEN set.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Open download") {
                    showModelDownload = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("LOADING_CHAT_VIEW")
                    .font(.headline)
                ProgressView()
                Text(healthDataInterpreter.loadingStage.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !healthDataInterpreter.loadingDetail.isEmpty {
                    Text(healthDataInterpreter.loadingDetail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

#Preview {
    HealthyLLMView()
}

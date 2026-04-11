//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziChat
import SpeziHealthKit
import SwiftUI

struct HealthyLLMChatView: View {
    @Environment(HealthDataInterpreter.self) private var healthDataInterpreter
    @Environment(HealthKit.self) private var healthKit
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.advancedMode) private var advancedMode = false
    
    let firstPrompt: String
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var lastSubmittedUserMessageID: UUID?
    @State private var isSubmittingPrompt = false
    @State private var didSendInitialPrompt = false
    
    var body: some View {
        NavigationStack {
            let contextBinding = Binding<Chat> {
                if advancedMode {
                    healthDataInterpreter.advancedContext.map(
                        \.asChatEntity
                    )
                } else {
                    healthDataInterpreter.context.map(
                        \.asUserFacingChatEntity
                    )
                }
            } set: { newValue in
                guard let userPrompt = newValue.last,
                      userPrompt.role == .user,
                      userPrompt.complete,
                      userPrompt.id != lastSubmittedUserMessageID,
                      !isSubmittingPrompt else {
                    return
                }

                lastSubmittedUserMessageID = userPrompt.id
                isSubmittingPrompt = true

                Task {
                    defer {
                        Task { @MainActor in
                            isSubmittingPrompt = false
                        }
                    }

                    do {
                        try await healthDataInterpreter.queryLLM(with: newValue, healthKit: healthKit)
                    } catch {
                        await MainActor.run {
                            showErrorAlert = true
                            errorMessage = "Error querying LLM: \(error.localizedDescription)"
                        }
                    }
                }
            }
            ChatView(
                contextBinding,
                exportFormat: .text,
                hideMessages: .custom(hiddenMessageTypes: [.assistantToolCall])
            )
            .navigationTitle("HealthyLLM")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    resetChatButton
                }
                ToolbarItem(placement: .topBarLeading) {
                    dismissButton
                }
            }
            .task {
                guard !didSendInitialPrompt else {
                    return
                }

                didSendInitialPrompt = true
                await healthDataInterpreter.resetChat()

                do {
                    let initialContext: Chat = [.init(role: .user, content: firstPrompt)]
                    try await healthDataInterpreter.queryLLM(with: initialContext, healthKit: healthKit)
                } catch {
                    showErrorAlert = true
                    errorMessage = "Error querying LLM: \(error.localizedDescription)"
                }
            }
        }
        .alert("ERROR_ALERT_TITLE", isPresented: $showErrorAlert) {
            Button("ERROR_ALERT_CANCEL", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .interactiveDismissDisabled()
    }
    
    private var resetChatButton: some View {
        Button(
            action: {
                Task {
                    await healthDataInterpreter.resetChat()
                }
            },
            label: {
                Image(systemName: "arrow.counterclockwise")
                    .accessibilityLabel(Text("RESET"))
            }
        )
        .accessibilityIdentifier("resetChatButton")
    }
    
    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Text("DONE")
        }
    }
}

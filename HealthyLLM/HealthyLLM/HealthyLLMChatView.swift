//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziChat

struct HealthyLLMChatView: View {
    @Environment(HealthDataInterpreter.self) private var healthDataInterpreter
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.advancedMode) private var advancedMode = false
    
    let firstPrompt: String
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
                Task {
                    do {
                        try await healthDataInterpreter.queryLLM(with: newValue)
                    } catch {
                        showErrorAlert = true
                        errorMessage = "Error querying LLM: \(error.localizedDescription)"
                    }
                }
            }
            ChatView(
                contextBinding,
                exportFormat: .text
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
                await healthDataInterpreter.resetChat()
                contextBinding.wrappedValue.append(.init(role: .user, content: firstPrompt))
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

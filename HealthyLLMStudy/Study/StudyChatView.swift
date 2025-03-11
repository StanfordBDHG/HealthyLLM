//
//  ChatView.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import SpeziViews
import SwiftUI
import SpeziChat
import SpeziOnboarding


extension ChatEntity: @retroactive @unchecked Sendable { }

struct StudyChatView: View, Identifiable {
    let id: String
    @State var processor: any ChatProcessor
    
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath: OnboardingNavigationPath?
    @State private var showError = false
    @State private var error: String = ""
    
    var body: some View {
        let context = Binding<Chat> {
            processor.chat
        } set: { newValue in
            Task {
                do {
                    try await processor.query(with: newValue)
                } catch is CancellationError {
                    return
                } catch (let err) {
                    error = err.localizedDescription
                    showError = true
                }
            }
        }
        
        ChatView(context, hideMessages: .custom(hiddenMessageTypes: []))
            .navigationTitle("CHAT_TITLE")
            .if(condition: { studyNavigationPath != nil }) { view in
                view.navigationBarBackButtonHidden()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { processor.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("NEXT", action: continueButtonAction)
                    .disabled(!processor.sufficientUsage)
                }
            }
            .alert("ERROR", isPresented: $showError) {
                Button(role: .cancel, action: { }) {
                    Text("OK")
                }
            } message: {
                Text(error)
            }
    }
    
    private func continueButtonAction() {
        processor.stop()
        studyNavigationPath?.nextStep()
    }
}

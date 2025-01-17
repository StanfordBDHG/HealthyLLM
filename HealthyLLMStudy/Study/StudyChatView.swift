//
//  ChatView.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/9/25.
//

import SwiftUI
import SpeziChat
import SpeziOnboarding


struct StudyChatView: View {
    let type: ProcessorType
    let studyStepName: String
    
    @Environment(\.modelContext) private var storageContext
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath
    @Environment(ContextWindowProcessor.self) private var contextWindowProcessor
    @Environment(FunctionCallingProcessor.self) private var functionCallingProcessor
    @Environment(PerformaceManager.self) private var performanceManager
    
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        let context = Binding {
            switch type {
            case .functionCalling:
                functionCallingProcessor.chat
            case .contextWindow:
                contextWindowProcessor.chat
            }
        } set: { newValue in
            Task {
                do {
                    performanceManager.startRecording()
                    switch type {
                    case .functionCalling:
                        try await functionCallingProcessor.query(with: newValue)
                    case .contextWindow:
                        try await contextWindowProcessor.query(with: newValue)
                    }
                } catch {
                    showErrorAlert = true
                    errorMessage = "Error querying LLM: \(error.localizedDescription)"
                }
            }
        }
        
        var continueButtonDisabled: Bool {
            switch type {
            case .contextWindow:
                !contextWindowProcessor.sufficientUsage
            case .functionCalling:
                !functionCallingProcessor.sufficientUsage
            }
        }
        
        ChatView(context)
            .navigationTitle("CHAT_TITLE")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    resetChatButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    continueButton
                        .disabled(continueButtonDisabled)
                }
            }
            .alert("ERROR_ALERT_TITLE", isPresented: $showErrorAlert) {
                Button("ERROR_ALERT_CANCEL", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }
    
    private var resetChatButton: some View {
        Button(
            action: {
                switch type {
                case .functionCalling:
                    functionCallingProcessor.reset()
                case .contextWindow:
                    contextWindowProcessor.reset()
                }
            },
            label: {
                Image(systemName: "arrow.counterclockwise")
            }
        )
    }
    
    private var continueButton: some View {
        Button {
            let context = switch type {
            case .functionCalling:
                functionCallingProcessor.chat
            case .contextWindow:
                contextWindowProcessor.chat
            }
            
            let step = StudyStep(
                name: studyStepName,
                chatLog: context.asJSONString(),
                keyboardMetrics: nil
            )
            storageContext.insert(step)
            
            switch type {
                case .functionCalling:
                functionCallingProcessor.stop()
            case .contextWindow:
                contextWindowProcessor.stop()
            }
            let performaceData = performanceManager.stopRecording()
            storageContext.insert(StudyMetadata(metadata: performaceData))
            
            studyNavigationPath.nextStep()
        } label: {
            Text("NEXT")
        }
    }
}

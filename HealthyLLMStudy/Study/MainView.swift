//
//  ContentView.swift
//  HealthyLLMStudy
//
//  Created by Leon Nissen on 1/6/25.
//


import SwiftUI
import SwiftData
import SpeziChat
import SpeziQuestionnaire


struct MainView: View {
    @Environment(\.modelContext) private var storageContext
    @AppStorage(StorageKeys.studyFlowComplete) private var studyFlowComplete = false
    @State private var showShareSheet = false
    
    @MainActor private var studyData: Data? {
        exportData()
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if studyFlowComplete {
                    Spacer()
                    Image(systemName: "checkmark.seal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.accent)
                        .frame(width: 100, height: 100)
                    Spacer()
                    
                    shareButton
                    
                    Spacer()
                }
            }
            .navigationTitle("HealthyLLM Study")
        }
        .sheet(isPresented: !$studyFlowComplete) {
            StudyFlow()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showShareSheet) {
            if let studyData {
                ShareSheet(sharedItem: studyData, sharedItemType: .json)
                    .presentationDetents([.medium])
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .presentationDetents([.medium])
            }
        }
    }
    
    private var shareButton: some View {
        Button {
            showShareSheet = true
        } label: {
            Text("SHARE_BUTTON_TITLE")
                .frame(height: 40)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
    
    private func exportData() -> Data? {
        struct StudyData: Encodable {
            let steps: [StudyStep]
            let responses: [StudyResponse]
            let metadata: [StudyMetadata]
        }
        
        do {
            let context = storageContext.container.mainContext
            let steps = try context.fetch(FetchDescriptor<StudyStep>())
            let responses = try context.fetch(FetchDescriptor<StudyResponse>())
            let metadata = try context.fetch(FetchDescriptor<StudyMetadata>())
            
            let data = StudyData(
                steps: steps,
                responses: responses,
                metadata: metadata
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            guard let encoded = try? encoder.encode(data) else { return nil }
            
            return encoded
        } catch {
            return nil
        }
    }
}

#Preview {
    MainView()
}

//
//  DebugView.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/15/25.
//

import SwiftUI


struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var storageContext
    @Environment(HealthDataFetcher.self) private var fetcher: HealthDataFetcher
    @Environment(SharedLocalLLM.self) private var llm: SharedLocalLLM
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        Task {
                            let data = await fetcher.fetchAllHealthLastTwoWeeks()
                            let string = PromptGenerator.ContextWindowProcessor.convertToMatrix(healthData: data)
                            print(string)
                        }
                        
                    } label: {
                        Text("Get All Health Data")
                    }
                    
                    Button {
                        Task {
                            let data = await fetcher.fetchAllWorkoutsLastTwoWeeks()
                            let string = data.asJSONString()!
                            print(string)
                        }
                        
                    } label: {
                        Text("Get All Workout Data")
                    }
                }
                
                Section {
                    Button {
                        Task {
                            do {
                                try await llm.prepareLLM()
                            } catch {
                                print(error)
                            }
                        }
                        
                    } label: {
                        Text("Prepare LLM")
                    }
                }
                
                Section {
                    Button {
                        UserDefaults.standard.removeObject(forKey: StorageKeys.studyFlowComplete)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.onboardingFlowComplete)
                        do {
                            try storageContext.container.erase()
                            try storageContext.save()
                        } catch {
                            print(error)
                        }
                        
                    } label: {
                        Text("Restart")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Debug 💎")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                    }

                }
            }
        }
    }
}

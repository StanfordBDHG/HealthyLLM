//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Hub
import SpeziViews
import SwiftUI


private enum LLMSelection {
    case present(ChatProcessor)
    case hide
}

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var storageContext
    @State private var viewState: ViewState = .idle
    @State private var path = NavigationPath()
    @Environment(SharedLocalLLM.self) private var llm: SharedLocalLLM
    @Environment(FunctionCallingProcessor.self) private var functionCallingProcessor
    @Environment(ContextWindowProcessor.self) private var contextWindowProcessor
    
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
               Section("Health Data") {
                    Button("`extractHealthDataForLLM`") {
                        Task {
                            do {
                                let string = try await ContextWindowHandler.execute()
                                path.append(string)
                            } catch {
                                path.append("Error: \(error)")
                            }
                        }
                    }
                    
                    Button("`countAllHealthKitData`") {
                        Task {
                            let values = await HealthDataFetcher.shared.countAllHealthKitData()
                            var string = ""
                            
                            for (key, value) in values {
                                let shortKey = key
                                    .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
                                    .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
                                string += "\(shortKey): \(value)\n"
                            }
                            path.append(string)
                        }
                    }
                    
                    Button("`fetchOldestOverallSample`") {
                        Task {
                            let data = await HealthDataFetcher.shared.fetchOldestOverallSample()
                            
                            if let key = data.first?.key, let value = data.first?.value {
                                path.append("""
                                Identifier: \(key)
                                Date: \(value.formatted(date: .complete, time: .omitted))
                                """)
                            } else {
                                path.append("No Data")
                            }
                        }
                    }
                   
                   Button("getVitalsOverview") {
                       Task {
                           do {
                               let handler = VitalsOutlierHandler()
                               let data = try await handler.execute(parameters: ["maxDays": "7"])
                               path.append(data)
                           } catch {
                               path.append("\(error)")
                           }
                       }
                   }
               }
                
                Section("Questions") {
                    NavigationLink("Answer Questions") {
                        QuestionnaireViewWrapper(
                            questionnaire: .sus,
                            questionnaireResponse: Persistance.shared.saveQuestionnaire(questionnaireResponse:)
                        )
                    }
                }
                
                Section("Performance") {
                    Button("Start") {
                        PerformanceProcessor.shared.start()
                    }
                    Button("Stop") {
                        PerformanceProcessor.shared.stop()
                    }
                }
                
                
                Section("Prompt") {
                    Button("Interpretation System Prompt") {
                        let interpretationSystemPrompt = LocalizedStringResource("INTERPRETATION_SYSTEM_PROMPT").localizedString()
                        path.append(interpretationSystemPrompt)
                    }
                    
                    Button("`createDateIntervalsString`") {
                        let string = FunctionCallingProcessor.createDateIntervalsString()
                        path.append(string)
                    }
                }
                
                Section("LLM") {
                    Button("Prepare LLM") {
                        Task {
                            do {
                                try await llm.prepareLLM()
                            } catch {
                                viewState = .error(AnyLocalizedError(error: error))
                            }
                        }
                    }
                    
                    Button("Offload LLM") {
                        Task {
                            await llm.offloadModel()
                        }
                    }
                    
                    Button("Clear GPU Cache") {
                        llm.clearCache()
                    }
                    
                    NavigationLink("Context Window LLM") {
                        StudyChatView(id: "DEBUG - Context Window", processor: contextWindowProcessor)
                    }
                    
                    NavigationLink("Function Call LLM") {
                        StudyChatView(id: "DEBUG - Function Call", processor: functionCallingProcessor)
                    }
                }
                
                Section("Destructive") {
                    Button("Delete Model") {
                        Task {
                            do {
                                let url = HubApi().localRepoLocation(.init(id: Constants.llmModelName))
                                let files = try await HubApi().getFilenames(from: Constants.llmModelName)
                                print(files)
                                
                                for file in files {
                                    let fileURL = url.appending(path: file)
                                    guard let _ = try? FileManager.default.removeItem(at: fileURL) else {
                                        continue
                                    }
                                }
                            } catch {
                                viewState = .error(AnyLocalizedError(error: error))
                            }
                        }
                    }
                    
                    Button("Delete Data") {
                        do {
                            try Persistance.shared.deleteAll()
                        } catch {
                            viewState = .error(AnyLocalizedError(error: error))
                        }
                    }
                    
                    Button("Reset User Defauls") {
                        UserDefaults.standard.removeObject(forKey: StorageKeys.studyFlowComplete)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.onboardingFlowComplete)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.debugViewPresented)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.homeStudyFlowComplete)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.participantId)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.age)
                        UserDefaults.standard.removeObject(forKey: StorageKeys.studyFlowStep)
                    }
                }
            }
            .navigationDestination(for: String.self) { value in
                ScrollView {
                    Text(value)
                        .monospaced()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity)
                }
                .navigationTitle("Details")
            }
            .navigationTitle("Debug 🐛")
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

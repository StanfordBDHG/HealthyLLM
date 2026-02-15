//
//  ContentView.swift
//  HealthyLLMStudy
//
//  Created by Leon Nissen on 1/6/25.
//


import SpeziAccessGuard
import SpeziChat
import SpeziLLMLocalDownload
import SpeziQuestionnaire
import SwiftData
import SwiftUI


struct MainView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = MainViewModel()
    @AppStorage(StorageKeys.homeStudyFlowComplete) private var homeStudyFlowComplete = false
    @AppStorage(StorageKeys.studyFlowComplete) private var studyFlowComplete = false
    @Environment(AccessGuard.self) private var accessGuard
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                header
                
                Text("Steps")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                taskCell(number: 1, header: "Download the LLM", disabled: false) {
                    // swiftlint:disable:next line_length
                    Text("To use the model we first need to download it. This will take a few minutes. Make sure you have a stable internet connection.")
                    
                    switch model.downloadManager.state {
                    case .idle:
                        Button {
                            Task {
                                await model.downloadManager.startDownload()
                            }
                        } label: {
                            Text("Start Download")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .onAppear {
                            Task {
                                if model.downloadManager.modelExist {
                                    await model.downloadManager.startDownload()
                                }
                            }
                        }
                    case .downloading(progress: let progress):
                        ProgressView(value: progress.fractionCompleted * 100, total: 100.0) {
                            Text("LLM_DOWNLOADING_PROGRESS_TEXT")
                        }
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    case .downloaded:
                        Button { } label: {
                            Text("Already Downloaded")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                    case .error(let error):
                        Text("Error: \(error.localizedDescription)")
                            .foregroundStyle(.gray)
                        Button {
                            Task {
                                await model.downloadManager.startDownload()
                            }
                        } label: {
                            Text("Retry Download")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                taskCell(
                    number: 2,
                    header: "Answer Questionnaire",
                    disabled: !(
                        model.downloadManager.state == .downloaded
                        || model.downloadManager.state.isDownloading
                        || model.downloadManager.state.hasError
                    )
                ) {
                    Text("Complete the preliminary questionnaire with basic questions before beginning the study.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.leading)
                        
                    Button {
                        model.showHomeStudyFlow = true
                    } label: {
                        Text(homeStudyFlowComplete ? "Retake Questionnaire" : "Start Questionnaire")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                taskCell(number: 3, header: "Start Study", disabled: !homeStudyFlowComplete) {
                    Text("Start the study with the study coordinator, please do not start it yourself.")
                    Group {
                        AccessGuardButton(.accessGuard) {
                            Text("Unlock")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        } unlocked: {
                            Button {
                                model.showStudyFlow = true
                            } label: {
                                Text("Start Study")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                taskCell(number: 4, header: "Export Data", disabled: !studyFlowComplete) {
                    Text("Export the data from the study. Please note that this only works if you have completed the study.")
                    Button {
                        Task {
                            await model.export()
                        }
                    } label: {
                        Text("Export")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .background(Color(.systemGroupedBackground))
            .viewStateAlert(state: $model.viewState)
#if(DEBUG)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DEBUG") {
                        model.showDebugSheet = true
                    }
                }
            }
            .sheet(isPresented: $model.showDebugSheet) {
                DebugView()
            }
#endif
        }
        .sheet(isPresented: $model.showStudyFlow) {
            StudyFlow()
                .interactiveDismissDisabled()
                .presentationSizing(.page)
        }
        .sheet(isPresented: $model.showHomeStudyFlow) {
            QuestionnaireView(
                questionnaire: .demographics_health_privacy,
                cancelBehavior: .shouldConfirmCancel,
                questionnaireResult: model.handleQuestionnaireResult
            )
                .presentationSizing(.page)
        }
        .sheet(isPresented: $model.showShareSheet) {
            if let studyData = model.exportedData {
                ShareSheet(sharedItem: studyData, sharedItemType: .json)
                    .presentationDetents([.medium])
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .presentationDetents([.medium])
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack {
                Spacer()
                
                Group {
                    if colorScheme == .dark {
                        Image("shape")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .colorInvert()
                    } else {
                        Image("shape")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(maxHeight: 300)
                
                Text("Join the Study")
                    .bold()
                
                Text("HealthyLLM")
                    .font(.title)
                    .bold()
                
                Text("Explore the on-device capabilities of LLMs for health research.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.top, -100)
        .frame(height: 400)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func taskCell(
        number: Int,
        header: String,
        disabled isDisabled: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        GroupBox {
            content()
        } label: {
            HStack(alignment: .center) {
                Text("\(number)")
                    .bold()
                    .foregroundStyle(.white)
                    .background {
                        Circle()
                            .foregroundStyle(isDisabled ? Color(.gray) : Color(.systemBlue))
                            .frame(width: 30, height: 30)
                    }
                    .padding()
                Text(header)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(isDisabled ? .gray : .primary)
            }
        }
        .disabled(isDisabled)
        .backgroundStyle(Color(.secondarySystemGroupedBackground))
        .padding()
    }
}

#Preview {
    MainView()
}


extension SpeziLLMLocalDownload.LLMLocalDownloadManager.DownloadState {
    var isDownloading: Bool {
        switch self {
        case .idle, .downloaded, .error:
            false
        case .downloading:
            true
        }
    }
    
    var hasError: Bool {
        switch self {
        case .idle, .downloaded, .downloading:
            false
        case .error:
            true
        }
    }
}

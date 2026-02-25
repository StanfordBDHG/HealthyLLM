//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziLLMLocalDownload
import SpeziQuestionnaire
import SpeziViews
import SwiftUI


struct ExportDetails {
    let chat: Int
    let questions: Int
    let metadata: Int
    let performance: Int
    
    var empty: Bool {
        chat == 0 && questions == 0 && metadata == 0 && performance == 0
    }
}

@Observable
class MainViewModel {
    var showStudyFlow = false
    var showHomeStudyFlow = false
    var showShareSheet = false
    var showDebugSheet = false
    var viewState: ViewState = .idle
    
    @MainActor var exportedData: Data?
    
    var downloadManager = LLMLocalDownloadManager(model: .custom(id: Constants.llmModelName))
    
    func handleQuestionnaireResult(_ result: QuestionnaireResult) {
        defer {
            showHomeStudyFlow = false
        }
        if case let .completed(questionnaireResponse) = result {
            Persistance.shared.saveQuestionnaire(questionnaireResponse: questionnaireResponse)
            UserDefaults.standard.set(true, forKey: StorageKeys.homeStudyFlowComplete)
        }
    }
    
    func export() async {
        showShareSheet = true
        do {
            let exportable = try await Persistance.shared.export()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportable)
            
            await MainActor.run {
                exportedData = data
            }
        } catch {
            viewState = .error(AnyLocalizedError(error: error))
        }
    }
}

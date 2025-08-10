//
//  HealthMaxView.swift
//  HealthyLLM
//
//  Created by Max Rosenblattl on 29.07.25.
//

import SpeziChat
import SwiftUI
import SpeziHealthKit

struct HealthyMaxView: View {
    @Environment(HealthDataInterpreter.self) private var healthDataInterpreter
    @Environment(HealthKit.self) private var healthKit
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.advancedMode) private var advancedMode = false

    let firstPrompt: String
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        Text("Hello World")
            .task {
                try! await healthDataInterpreter.fetchHealthData(healthKit, sampleTypeKey: "heartRate")
            }
    }
}


//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(StorageKeys.advancedMode) private var advancedMode: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("ADVANCED_MODE", isOn: $advancedMode)
                } footer: {
                    Text("ADVANCED_MODE_DESCRIPTION")
                }
            }
            .navigationTitle("SETTINGS")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    dismissButton()
                }
            }
        }
    }
    
    private func dismissButton() -> some View {
        Button {
            dismiss()
        } label: {
            Text("DONE")
        }
    }
}

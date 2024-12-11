//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct PromptExample: Identifiable, Decodable {
    let id = UUID()
    let emoji: String
    let prompt: String
}

struct PromptExamplesView: View {
    let examples: [PromptExample]
    let action: (_ query: String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading) {
                ForEach(0 ..< 3) { rowIndex in
                    HStack {
                        let rowCount = examples.count / 3
                        ForEach(examples[rowCount * rowIndex..<rowCount * (rowIndex + 1)]) { example in
                            cell(for: example)
                        }
                    }
                }
            }
        }
    }
    
    
    private func cell(for example: PromptExample) -> some View {
        Button {
            action(example.prompt)
        } label: {
            VStack {
                HStack {
                    Text(example.emoji)
                    Text(example.prompt)
                        .monospaced()
                        .foregroundStyle(.stanfordGrey)
                }
                .font(.footnote)
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.stanfordGrey.opacity(0.1))
            )
            .fixedSize(horizontal: true, vertical: true)
        }
    }
}

#Preview {
    let examples: [PromptExample] = Array(
        repeating: .init(emoji: "🚀", prompt: "Foo Bar"),
        count: 50
    )
    +
    Array(
        repeating: .init(emoji: "🐓", prompt: "Leon Foo Bar"),
        count: 50
    )
    
    PromptExamplesView(examples: examples.shuffled(), action: { _ in })
}

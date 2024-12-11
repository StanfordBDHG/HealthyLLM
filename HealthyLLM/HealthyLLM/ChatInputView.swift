//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct ChatInputView: View {
    @State private var promptExamples: [PromptExample] = []
    @State private var query: String = ""
    let action: (_ query: String) -> Void
    
    var body: some View {
            ScrollView {
                VStack {
                    Image(.healthyLLM)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                    
                    PromptExamplesView(examples: promptExamples, action: action)
                        .padding(.vertical)
                    
                    VStack {
                        HStack {
                            TextField("CHAT_EXAMPLE_PROMPT", text: $query)
                                .font(.system(size: 18))
                                .padding()
                            Button {
                                action(query)
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .resizable()
                                    .tint(.accent)
                                    .aspectRatio(contentMode: .fit)
                                    
                            }
                            .frame(width: 25)
                            .padding()
                        }
                    }
                    .frame(idealWidth: 500)
                    .background(Color(uiColor: .systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.stanfordGrey, lineWidth: 1)
                    }
                    .shadow(color: .accent.opacity(0.2), radius: 36, x: 0, y: 30)
                    .padding(20)
                }
            }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                guard let url = Bundle.main.url(forResource: "example-prompts", withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let promptExamples = try? JSONDecoder().decode([PromptExample].self, from: data)
                else {
                    fatalError("Cannot decode `example-prompts.json`.")
                }
                self.promptExamples = promptExamples.shuffled()
            }
        }
    }
    
    
    private func gridBackground<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Image(.rasterB)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.025)
                .frame(maxWidth: .infinity)
            
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.clear, .init(UIColor.systemBackground)]),
                        center: .center,
                        startRadius: 300,
                        endRadius: 700
                    )
                )
                .frame(width: 2000, height: 2000)
                
            content()
        }
    }
}

#Preview {
    ChatInputView(action: { _ in })
}

//
//  InfoView.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/15/25.
//

import SpeziOnboarding
import SwiftUI


struct InfoView: View {
    @Environment(OnboardingNavigationPath.self) private var studyNavigationPath
    @AppStorage(StorageKeys.age) private var age: Int?
    @AppStorage(StorageKeys.participantId) private var participantId: Int?
    @AppStorage(StorageKeys.sex) private var sex: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text("STUDY_INFORMATION_BODY")
                    .padding()
                
                Divider()
                
                LabeledContent {
                    TextField("required", value: $participantId, format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                } label: {
                    Text("Participant ID")
                        .bold()
                }
                .padding()
                
                Divider()
                    .padding(.leading)
                
                LabeledContent {
                    TextField("required", value: $age, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                } label: {
                    Text("Age")
                        .bold()
                }
                .padding()

                Divider()
                    .padding(.leading)
                
                LabeledContent {
                    Picker("", selection: $sex) {
                        if sex == nil {
                            Text("required")
                                .tag(String?(nil))
                        }
                        Text("Male")
                            .tag("male")
                        Text("Female")
                            .tag("female")
                        Text("Intersex")
                            .tag("intersex")
                        Text("Prefer not to say")
                            .tag("perfer-not-to-say")
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(.gray)
                } label: {
                    Text("Sex")
                        .bold()
                }
                .padding()
                
                Divider()
                
                Spacer()
                Button {
                    guard let age = age, let participantId = participantId, let sex = sex else {
                        return
                    }
                    Persistance.shared.saveMetadata(participantId: participantId, age: age, sex: sex)
                    studyNavigationPath.nextStep()
                } label: {
                    Text("Start")
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(age == nil || participantId == nil || sex == nil || age ?? 0 < 18 || age ?? 0 >= 80)
            }
            .navigationTitle("STUDY_INFORMATION_TITLE")
        }
    }
}

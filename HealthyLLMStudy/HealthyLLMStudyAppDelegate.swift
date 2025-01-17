//
//  HealthyLLMStudyAppDelegate.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/6/25.
//

import Spezi
import SpeziLLM
import SpeziLLMOpenAI
import SpeziLLMLocal
import SpeziOnboarding

class HealthyLLMStudyAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: HealthyLLMStudyStandard()) {
            LLMRunner {
                LLMLocalPlatform()
                LLMOpenAIPlatform()
            }
            HealthDataFetcher()
            SharedLocalLLM()
            FunctionCallingProcessor()
            ContextWindowProcessor()
            PerformaceManager()
        }
    }
}

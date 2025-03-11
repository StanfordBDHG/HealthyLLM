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
import SpeziAccessGuard


class HealthyLLMStudyAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: HealthyLLMStudyStandard()) {
            LLMRunner {
                LLMLocalPlatform()
            }
            SharedLocalLLM()
            FunctionCallingProcessor()
            ContextWindowProcessor()
            AccessGuardModule {
                FixedAccessGuard(.accessGuard, code: "1111", codeOptions: .fourDigitNumeric)
            }
        }
    }
}

extension AccessGuardIdentifier {
    static let accessGuard = Self("edu.stanford.spezi.accessGuard")
}

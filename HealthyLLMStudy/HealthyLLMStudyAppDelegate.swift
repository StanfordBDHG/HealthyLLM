//
//  HealthyLLMStudyAppDelegate.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/6/25.
//

import Spezi
import SpeziAccessGuard
import SpeziLLM
import SpeziLLMLocal
import SpeziLLMOpenAI
import SpeziOnboarding


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

//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
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

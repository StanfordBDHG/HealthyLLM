//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziLLM
import SpeziLLMLocal


class HealthyLLMAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            LLMRunner {
                LLMLocalPlatform()
            }
            HealthDataFetcher()
            HealthDataInterpreter()
            HealthContextGenerator()
        }
    }
}

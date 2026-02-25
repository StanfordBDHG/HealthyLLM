//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziChat
import SwiftUI


protocol ChatProcessor: Observable {
    var chat: Chat { get }
    var sufficientUsage: Bool { get }
    func query(with newValue: Chat) async throws
    func reset()
    func stop()
}

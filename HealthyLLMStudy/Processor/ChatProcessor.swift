//
//  ChatProcessor.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import SwiftUI
import SpeziChat


protocol ChatProcessor: Observable {
    var chat: Chat { get }
    var sufficientUsage: Bool { get }
    func query(with newValue: Chat) async throws
    func reset()
    func stop()
}


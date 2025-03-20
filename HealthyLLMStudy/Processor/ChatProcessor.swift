//
//  ChatProcessor.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
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

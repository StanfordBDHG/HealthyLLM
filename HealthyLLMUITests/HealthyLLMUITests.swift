//
// This source file is part of the HealtyLLM application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest


class HealthyLLMUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    
    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }
}

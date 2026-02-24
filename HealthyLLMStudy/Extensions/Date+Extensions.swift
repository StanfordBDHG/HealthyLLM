//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

extension Date {
    /// - Returns: A `Date` object representing the start of the current day.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1), to: startOfDay) ?? Date()
    }
    
    /// - Returns: A `Date` object representing the start of the day exactly `days` ago.
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(
            byAdding: DateComponents(day: -days),
            to: Date().startOfDay
        ) ?? Date()
    }
}

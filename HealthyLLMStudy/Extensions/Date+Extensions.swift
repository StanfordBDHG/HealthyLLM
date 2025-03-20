//
//  Date+.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/13/25.
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

//
//  Date+.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/13/25.
//

import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1), to: startOfDay)!
    }
    
    /// - Returns: A `Date` object representing the start of the current day.
    static var startOfDay: Date {
        Date().startOfDay
    }
    
    static var endOfDay: Date {
        Date().endOfDay
    }
    
    /// - Returns: A `Date` object representing the start of the day exactly `days` ago.
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(
            byAdding: DateComponents(day: -days),
            to: Date.startOfDay
        ) ?? Date()
    }
}

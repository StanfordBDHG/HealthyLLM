//
//  String+toDate.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 3/1/25.
//

import Foundation


extension String {
    func parseDate() -> Date? {
        // List of common date formats. You can extend this array with other formats as needed.
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ", // e.g., ISO8601 format
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "MM-dd-yyyy",
            "MM/dd/yyyy",
            "dd-MM-yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss",
            "EEE, dd MMM yyyy HH:mm:ss Z",  // e.g., RFC1123 format
        ]
        
        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: self) {
                return Calendar.current.startOfDay(for: date)
            }
        }
        
        return nil
    }
}

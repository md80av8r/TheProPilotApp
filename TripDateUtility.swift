//
//  TripDateUtility.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/14/25.
//


//
//  TripDateUtility.swift
//  TheProPilotApp
//
//  Utility for calculating trip dates based on Zulu/Local time preference
//

import Foundation

struct TripDateUtility {
    
    /// Returns the appropriate date for trip creation based on user's Zulu/Local time preference
    static func getCurrentTripDate() -> Date {
        let useZulu = AutoTimeSettings.shared.useZuluTime
        
        if useZulu {
            // Use UTC date (start of day in UTC timezone)
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let utcDate = calendar.startOfDay(for: Date())
            print("📅 Trip date: \(utcDate) (Zulu)")
            return utcDate
        } else {
            // Use local date (start of day in local timezone)
            let localDate = Calendar.current.startOfDay(for: Date())
            print("📅 Trip date: \(localDate) (Local)")
            return localDate
        }
    }
    
    /// Formats a date for display based on user's Zulu/Local time preference
    static func formatDateForDisplay(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let useZulu = AutoTimeSettings.shared.useZuluTime
        let formatter = DateFormatter()
        formatter.dateStyle = style
        
        if useZulu {
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.string(from: date)
    }
}
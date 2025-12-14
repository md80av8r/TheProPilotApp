//
//  TimeRoundingUtility.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/19/25.
//


import Foundation

struct TimeRoundingUtility {
    /// Rounds a date to the nearest 5-minute increment if enabled in settings
    static func roundToNearestFiveMinutes(_ date: Date, enabled: Bool) -> Date {
        guard enabled else { return date }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        
        guard let minute = components.minute else { return date }
        
        // Round to nearest 5 minutes
        let roundedMinute = Int(round(Double(minute) / 5.0) * 5.0)
        
        var newComponents = components
        
        if roundedMinute >= 60 {
            // Handle hour overflow (e.g., 58 rounds to 60 = next hour)
            let hour = (components.hour ?? 0) + 1
            newComponents.hour = hour
            newComponents.minute = 0
        } else {
            newComponents.minute = roundedMinute
        }
        
        return calendar.date(from: newComponents) ?? date
    }
    
    /// Format time string and round if enabled
    static func formatAndRoundTime(_ date: Date, enabled: Bool, format: String = "HHmm") -> String {
        let roundedDate = roundToNearestFiveMinutes(date, enabled: enabled)
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(abbreviation: "UTC") ?? TimeZone.current
        return formatter.string(from: roundedDate)
    }
}
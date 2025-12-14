//  TimeDisplayUtility.swift
//  TheProPilotApp
//
//  Comprehensive utility for handling Zulu/Local time display and formatting
//  Created by Jeffrey Kadans on 11/14/25.
//

import Foundation
import SwiftUI

struct TimeDisplayUtility {
    
    // MARK: - Safe Settings Access
    
    /// Safely gets the Zulu time preference with fallback
    /// ✅ Now reads from App Group for iPhone/Watch sync
    private static var useZuluTime: Bool {
        guard let appGroup = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("⚠️ TimeDisplayUtility: Could not access App Group, defaulting to Zulu")
            return true  // Default to Zulu if App Group unavailable
        }
        return appGroup.bool(forKey: "useZuluTime")
    }
    
    // MARK: - Date Initialization for Trips
    
    /// Returns the appropriate date for trip creation based on user's Zulu/Local time preference
    static func getCurrentTripDate() -> Date {
        if useZuluTime {
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
    
    /// Returns current date with time component for time pickers
    static func getCurrentDateTime() -> Date {
        if useZuluTime {
            // Return current UTC time
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return Date()
        } else {
            // Return current local time
            return Date()
        }
    }
    
    // MARK: - Time Picker Configuration
    
    /// Returns the appropriate DatePicker display components based on Zulu/Local setting
    static func getTimePickerComponents() -> DatePickerComponents {
        // Always show both date and time for time pickers
        return [.date, .hourAndMinute]
    }
    
    /// Returns the appropriate timezone for date pickers
    static func getPickerTimeZone() -> TimeZone {
        return useZuluTime ? TimeZone(identifier: "UTC")! : TimeZone.current
    }
    
    // MARK: - Time Formatting
    
    /// Formats a time string based on Zulu/Local preference (24hr vs 12hr)
    static func formatTime(_ date: Date, includeTimeZone: Bool = true) -> String {
        let formatter = DateFormatter()
        
        if useZuluTime {
            // 24-hour format for Zulu time
            formatter.dateFormat = includeTimeZone ? "HH:mm'Z'" : "HH:mm"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            // 24-hour format for local time (changed from 12-hour)
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.string(from: date)
    }
    
    /// Formats a date for display based on user's Zulu/Local time preference
    static func formatDate(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        
        if useZuluTime {
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.string(from: date)
    }
    
    /// Formats a date and time together
    static func formatDateTime(_ date: Date, dateStyle: DateFormatter.Style = .short, includeSeconds: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        
        if useZuluTime {
            formatter.dateFormat = includeSeconds ? "MM/dd/yyyy HH:mm:ss'Z'" : "MM/dd/yyyy HH:mm'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.dateFormat = includeSeconds ? "MM/dd/yyyy HH:mm:ss" : "MM/dd/yyyy HH:mm"
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Time Parsing
    
    /// Parses a time string in the format appropriate for current Zulu/Local setting
    static func parseTime(_ timeString: String, baseDate: Date = Date()) -> Date? {
        let formatter = DateFormatter()
        
        if useZuluTime {
            formatter.dateFormat = "HHmm"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            // Try both 24hr and 12hr formats for local
            formatter.dateFormat = "HHmm"
            formatter.timeZone = TimeZone.current
        }
        
        // Clean the input (remove colons, spaces, Z suffix)
        let cleanedTime = timeString.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "Z", with: "")
        
        if let parsedTime = formatter.date(from: cleanedTime) {
            // Combine the parsed time with the base date
            var calendar = Calendar.current
            calendar.timeZone = useZuluTime ? TimeZone(identifier: "UTC")! : TimeZone.current
            
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            
            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute
            combined.timeZone = calendar.timeZone
            
            return calendar.date(from: combined)
        }
        
        return nil
    }
    
    // MARK: - Display Labels
    
    /// Returns the appropriate time zone label for display
    static func getTimeZoneLabel() -> String {
        return useZuluTime ? "UTC/Zulu" : "Local"
    }
    
    /// Returns the appropriate time format label for display
    static func getTimeFormatLabel() -> String {
        return "24-hour"  // Always 24-hour format
    }
}

// MARK: - SwiftUI View Extension for Easy Time Picker Creation

extension View {
    /// Creates a time picker that automatically uses the correct format and timezone
    /// ✅ Now reads from App Group for iPhone/Watch sync
    func zuluLocalTimePicker(selection: Binding<Date>, label: String) -> some View {
        let useZulu = UserDefaults(suiteName: "group.com.propilot.app")?.bool(forKey: "useZuluTime") ?? true
        
        return DatePicker(
            label,
            selection: selection,
            displayedComponents: [.hourAndMinute]
        )
        .environment(\.timeZone, useZulu ? TimeZone(identifier: "UTC")! : TimeZone.current)
        .environment(\.locale, Locale(identifier: "en_GB"))
    }
    
    /// Creates a date and time picker that automatically uses the correct format and timezone
    /// ✅ Now reads from App Group for iPhone/Watch sync
    func zuluLocalDateTimePicker(selection: Binding<Date>, label: String) -> some View {
        let useZulu = UserDefaults(suiteName: "group.com.propilot.app")?.bool(forKey: "useZuluTime") ?? true
        
        return DatePicker(
            label,
            selection: selection,
            displayedComponents: [.date, .hourAndMinute]
        )
        .environment(\.timeZone, useZulu ? TimeZone(identifier: "UTC")! : TimeZone.current)
        .environment(\.locale, Locale(identifier: "en_GB"))
    }
}

// TimeFormattingUtilities.swift
// Global time formatting functions for consistent display across the app
import Foundation

/// Formats time in minutes as "H,HHH+MM" format (e.g., "1,234+56" for 1234 hours 56 minutes)
/// Adds comma separator for hours >= 1000
func formatTimeWithCommaPlus(minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    
    // Add comma formatting for hours >= 1000
    if hours >= 1000 {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
        return "\(hoursFormatted)+\(String(format: "%02d", mins))"
    } else {
        return "\(hours)+\(String(format: "%02d", mins))"
    }
}

/// Formats time in minutes as standard "H:MM" format (e.g., "12:34")
func formatTimeStandard(minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    return String(format: "%d:%02d", hours, mins)
}

/// Formats time in minutes as decimal hours (e.g., "12.5" for 12 hours 30 minutes)
func formatTimeDecimal(minutes: Int) -> String {
    let hours = Double(minutes) / 60.0
    return String(format: "%.1f", hours)
}

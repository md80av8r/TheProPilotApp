//
//  AppConstants.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 7/19/25.
//

//
//  SharedConstants.swift
//  ProPilotApp
//
//  Shared constants and definitions used across all targets
//
//  TARGET MEMBERSHIP:
//  ✅ ProPilotApp
//  ✅ ProPilotWidget
//  ✅ ProPilot Watch App
//
//  NOTE: Notification names are defined in NotificationNames.swift
//

import Foundation

// MARK: - Shared Constants
struct AppConstants {
    static let defaultAirportRadius: Double = 1000 // meters
    static let speedThresholdTakeoff: Double = 80 // knots
    static let speedThresholdTaxi: Double = 40 // knots
    static let speedThresholdGround: Double = 10 // knots
}

// MARK: - Shared Type Aliases
typealias DutyTime = (hours: Int, minutes: Int)

// MARK: - Shared Utility Functions
extension Date {
    func timeStringForLogbook() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
    
    static func fromLogbookTime(_ timeString: String, on date: Date = Date()) -> Date? {
        guard timeString.count == 4,
              let hour = Int(timeString.prefix(2)),
              let minute = Int(timeString.suffix(2)) else { return nil }
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: components)
    }
}

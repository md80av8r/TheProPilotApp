//
//  OffDutyStatusManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/11/25.
//

import SwiftUI
import Combine

/// Manages off-duty status from NOC calendar data (days off, holidays, vacation)
class OffDutyStatusManager: ObservableObject {
    static let shared = OffDutyStatusManager()
    
    // MARK: - Published State
    @Published var isOffDuty: Bool = false
    @Published var offDutyEndTime: Date?
    @Published var offDutyStartTime: Date?
    @Published var nextDutyStartTime: Date?  // Next duty/flight start
    @Published var offDutyType: OffDutyType = .regular
    
    // Store parsed off-duty events from NOC
    @Published var offDutyEvents: [ParsedNonFlightEvent] = []
    
    // MARK: - Off Duty Types
    enum OffDutyType: String {
        case regular = "OFF"
        case holiday = "HOLIDAY"
        case vacation = "VACATION"
        
        var displayName: String {
            switch self {
            case .regular: return "Off Duty"
            case .holiday: return "Holiday"
            case .vacation: return "Vacation"
            }
        }
        
        var icon: String {
            switch self {
            case .regular: return "house.fill"
            case .holiday: return "gift.fill"
            case .vacation: return "airplane.departure"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Time remaining until back on duty
    var timeUntilDuty: TimeInterval? {
        guard isOffDuty, let endTime = offDutyEndTime else { return nil }
        let remaining = endTime.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }
    
    /// Formatted next duty time (local)
    var formattedNextDutyTime: String? {
        guard let dutyTime = nextDutyStartTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        formatter.timeZone = .current
        return formatter.string(from: dutyTime)
    }
    
    /// Formatted time remaining until duty
    var formattedTimeUntilDuty: String? {
        guard let remaining = timeUntilDuty else { return nil }
        
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if days > 0 {
            return String(format: "%d day%@ %d hr%@", days, days == 1 ? "" : "s", hours, hours == 1 ? "" : "s")
        } else if hours > 0 {
            return String(format: "%d hr%@ %d min", hours, hours == 1 ? "" : "s", minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load any cached off-duty status
        loadCachedStatus()
    }
    
    // MARK: - Update from NOC Data
    
    /// Update off-duty status from parsed NOC calendar events
    func updateFromNOCEvents(_ events: [ParsedNonFlightEvent], flights: [ParsedFlightData]) {
        // Filter for OFF duty events (excluding WOFF - those are work days!)
        self.offDutyEvents = events.filter { event in
            let eventType = event.eventType.uppercased()
            let description = event.eventDescription.uppercased()
            
            // Exclude WOFF (working day off - premium pay work day)
            if eventType == "WOFF" || description.contains("WORKING DAY OFF") {
                return false
            }
            
            // Include regular OFF, holidays, vacation
            return eventType == "OFF" ||
                   eventType == "HOL" ||
                   eventType == "VAC" ||
                   description.contains("OFF") ||
                   description.contains("HOLIDAY") ||
                   description.contains("VACATION")
        }.sorted { $0.startTime < $1.startTime }
        
        // Check current off-duty status
        let now = Date()
        
        // Find active off-duty period
        if let activeOff = offDutyEvents.first(where: { event in
            now >= event.startTime && now < event.endTime
        }) {
            isOffDuty = true
            offDutyStartTime = activeOff.startTime
            offDutyType = determineOffDutyType(from: activeOff.eventDescription)
            
            // ✅ FIX: Find the END of consecutive off duty blocks
            offDutyEndTime = findConsecutiveOffDutyEnd(startingFrom: activeOff)
            
            print("🏠 Currently \(offDutyType.displayName)")
            print("🏠 Consecutive off duty until: \(offDutyEndTime?.description ?? "unknown")")
        } else {
            isOffDuty = false
            offDutyStartTime = nil
            offDutyEndTime = nil
            
            // Find next off-duty period
            if let nextOff = offDutyEvents.first(where: { $0.startTime > now }) {
                let type = determineOffDutyType(from: nextOff.eventDescription)
                print("📅 Next off duty: \(type.displayName) starts \(nextOff.startTime)")
            }
        }
        
        // ✅ FIX: Find next duty start from flights AFTER consecutive off duty ends
        let searchAfter = offDutyEndTime ?? now
        if let nextFlight = flights.sorted(by: { ($0.checkIn ?? $0.dtStart) < ($1.checkIn ?? $1.dtStart) })
            .first(where: { ($0.checkIn ?? $0.dtStart) > searchAfter }) {
            nextDutyStartTime = nextFlight.checkIn ?? nextFlight.dtStart
            print("📅 Next duty starts: \(nextDutyStartTime?.description ?? "unknown")")
        }
        
        // Cache the status
        cacheStatus()
    }
    
    /// Find the end time of consecutive off duty blocks
    /// This handles cases where pilot has multiple consecutive OFF/HOL/VAC days
    private func findConsecutiveOffDutyEnd(startingFrom initialEvent: ParsedNonFlightEvent) -> Date {
        var currentEnd = initialEvent.endTime
        
        // Look for consecutive off duty events
        // Two events are consecutive if next starts within 4 hours of previous end
        // (allows for small gaps in calendar data)
        let maxGap: TimeInterval = 4 * 3600  // 4 hours
        
        var foundConsecutive = true
        while foundConsecutive {
            foundConsecutive = false
            
            // Find next event that starts near where current block ends
            if let nextEvent = offDutyEvents.first(where: { event in
                event.startTime >= currentEnd &&
                event.startTime.timeIntervalSince(currentEnd) <= maxGap
            }) {
                // Extend the block to this event's end time
                currentEnd = nextEvent.endTime
                foundConsecutive = true
                print("🏠 Extending off duty block through \(nextEvent.eventDescription) until \(currentEnd)")
            }
        }
        
        return currentEnd
    }
    
    /// Determine type of off duty from event description
    private func determineOffDutyType(from description: String) -> OffDutyType {
        let upper = description.uppercased()
        
        if upper.contains("HOL") || upper.contains("HOLIDAY") {
            return .holiday
        } else if upper.contains("VAC") || upper.contains("VACATION") {
            return .vacation
        } else {
            return .regular
        }
    }
    
    /// Manually set off-duty status (for when NOC data isn't available)
    func setOffDutyStatus(isOffDuty: Bool, endTime: Date?, type: OffDutyType = .regular) {
        self.isOffDuty = isOffDuty
        self.offDutyEndTime = endTime
        self.offDutyType = type
        cacheStatus()
    }
    
    /// Check and update off-duty status based on time
    func refreshStatus() {
        let now = Date()
        
        // Check if off-duty period has ended
        if isOffDuty, let endTime = offDutyEndTime, now >= endTime {
            isOffDuty = false
            offDutyEndTime = nil
            offDutyStartTime = nil
            print("✅ Off-duty period ended - back on duty!")
            cacheStatus()
        }
        
        // Check if a new off-duty period has started
        if !isOffDuty, let activeOff = offDutyEvents.first(where: { event in
            now >= event.startTime && now < event.endTime
        }) {
            isOffDuty = true
            offDutyStartTime = activeOff.startTime
            offDutyEndTime = activeOff.endTime
            offDutyType = determineOffDutyType(from: activeOff.eventDescription)
            print("🏠 Entered \(offDutyType.displayName) period")
            cacheStatus()
        }
    }
    
    // MARK: - Persistence
    
    private let offDutyStatusKey = "OffDutyStatusCache"
    
    private func cacheStatus() {
        let cache: [String: Any] = [
            "isOffDuty": isOffDuty,
            "offDutyEndTime": offDutyEndTime?.timeIntervalSince1970 ?? 0,
            "offDutyStartTime": offDutyStartTime?.timeIntervalSince1970 ?? 0,
            "nextDutyStartTime": nextDutyStartTime?.timeIntervalSince1970 ?? 0,
            "offDutyType": offDutyType.rawValue,
            "cachedAt": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(cache, forKey: offDutyStatusKey)
    }
    
    private func loadCachedStatus() {
        guard let cache = UserDefaults.standard.dictionary(forKey: offDutyStatusKey) else { return }
        
        // Only use cache if less than 1 hour old
        if let cachedAt = cache["cachedAt"] as? TimeInterval,
           Date().timeIntervalSince1970 - cachedAt < 3600 {
            
            isOffDuty = cache["isOffDuty"] as? Bool ?? false
            
            if let endTimestamp = cache["offDutyEndTime"] as? TimeInterval, endTimestamp > 0 {
                offDutyEndTime = Date(timeIntervalSince1970: endTimestamp)
            }
            
            if let startTimestamp = cache["offDutyStartTime"] as? TimeInterval, startTimestamp > 0 {
                offDutyStartTime = Date(timeIntervalSince1970: startTimestamp)
            }
            
            if let dutyTimestamp = cache["nextDutyStartTime"] as? TimeInterval, dutyTimestamp > 0 {
                nextDutyStartTime = Date(timeIntervalSince1970: dutyTimestamp)
            }
            
            if let typeRaw = cache["offDutyType"] as? String,
               let type = OffDutyType(rawValue: typeRaw) {
                offDutyType = type
            }
            
            // Validate - if off-duty end time has passed, clear it
            if let endTime = offDutyEndTime, Date() >= endTime {
                isOffDuty = false
                offDutyEndTime = nil
                offDutyStartTime = nil
            }
            
            print("📱 Loaded cached off-duty status: isOffDuty=\(isOffDuty)")
        }
    }
}

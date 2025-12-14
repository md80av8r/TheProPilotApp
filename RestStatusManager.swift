//
//  RestStatusManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/9/25.
//

import SwiftUI
import Combine

/// Manages rest status from NOC calendar data
class RestStatusManager: ObservableObject {
    static let shared = RestStatusManager()
    
    // MARK: - Published State
    @Published var isInRest: Bool = false
    @Published var restEndTime: Date?
    @Published var restStartTime: Date?
    @Published var lastDutyEndTime: Date?  // Last CO time from NOC
    @Published var nextDutyStartTime: Date?  // Next CI time from NOC
    
    // Store parsed rest events from NOC
    @Published var restEvents: [ParsedNonFlightEvent] = []
    
    // MARK: - Computed Properties
    
    /// Time remaining in rest period
    var restTimeRemaining: TimeInterval? {
        guard isInRest, let endTime = restEndTime else { return nil }
        let remaining = endTime.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }
    
    /// Formatted rest end time (local)
    var formattedRestEndTime: String? {
        guard let endTime = restEndTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = .current
        return formatter.string(from: endTime)
    }
    
    /// Formatted rest end time (Zulu)
    var formattedRestEndTimeZulu: String? {
        guard let endTime = restEndTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: endTime)
    }
    
    /// Formatted time remaining
    var formattedTimeRemaining: String? {
        guard let remaining = restTimeRemaining else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load any cached rest status
        loadCachedStatus()
    }
    
    // MARK: - Update from NOC Data
    
    /// Update rest status from parsed NOC calendar events
    func updateFromNOCEvents(_ events: [ParsedNonFlightEvent], flights: [ParsedFlightData]) {
        // Store rest events
        self.restEvents = events.filter { $0.isRest }
        
        // Check current rest status
        let now = Date()
        
        // Find active rest period
        if let activeRest = restEvents.first(where: { event in
            now >= event.startTime && now < event.endTime
        }) {
            isInRest = true
            restStartTime = activeRest.startTime
            restEndTime = activeRest.endTime
            print("😴 Currently in REST until \(formattedRestEndTime ?? "unknown")")
        } else {
            isInRest = false
            restStartTime = nil
            restEndTime = nil
            
            // Find next rest period
            if let nextRest = restEvents.first(where: { $0.startTime > now }) {
                print("📅 Next rest starts: \(nextRest.startTime)")
            }
        }
        
        // Find last duty end (CO) from flights
        let sortedFlights = flights.sorted { ($0.checkOut ?? $0.dtEnd) > ($1.checkOut ?? $1.dtEnd) }
        if let lastFlight = sortedFlights.first(where: { ($0.checkOut ?? $0.dtEnd) <= now }) {
            lastDutyEndTime = lastFlight.checkOut ?? lastFlight.dtEnd
            print("⏱️ Last duty ended: \(lastDutyEndTime?.description ?? "unknown")")
        }
        
        // Find next duty start (CI) from flights
        if let nextFlight = flights.sorted(by: { ($0.checkIn ?? $0.dtStart) < ($1.checkIn ?? $1.dtStart) })
            .first(where: { ($0.checkIn ?? $0.dtStart) > now }) {
            nextDutyStartTime = nextFlight.checkIn ?? nextFlight.dtStart
            print("📅 Next duty starts: \(nextDutyStartTime?.description ?? "unknown")")
        }
        
        // Cache the status
        cacheStatus()
    }
    
    /// Manually set rest status (for when NOC data isn't available)
    func setRestStatus(isInRest: Bool, endTime: Date?) {
        self.isInRest = isInRest
        self.restEndTime = endTime
        cacheStatus()
    }
    
    /// Check and update rest status based on time
    func refreshStatus() {
        let now = Date()
        
        // Check if rest period has ended
        if isInRest, let endTime = restEndTime, now >= endTime {
            isInRest = false
            restEndTime = nil
            restStartTime = nil
            print("✅ Rest period ended")
            cacheStatus()
        }
        
        // Check if a new rest period has started
        if !isInRest, let activeRest = restEvents.first(where: { event in
            now >= event.startTime && now < event.endTime
        }) {
            isInRest = true
            restStartTime = activeRest.startTime
            restEndTime = activeRest.endTime
            print("😴 Entered rest period")
            cacheStatus()
        }
    }
    
    // MARK: - Persistence
    
    private let restStatusKey = "RestStatusCache"
    
    private func cacheStatus() {
        let cache: [String: Any] = [
            "isInRest": isInRest,
            "restEndTime": restEndTime?.timeIntervalSince1970 ?? 0,
            "restStartTime": restStartTime?.timeIntervalSince1970 ?? 0,
            "lastDutyEndTime": lastDutyEndTime?.timeIntervalSince1970 ?? 0,
            "cachedAt": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(cache, forKey: restStatusKey)
    }
    
    private func loadCachedStatus() {
        guard let cache = UserDefaults.standard.dictionary(forKey: restStatusKey) else { return }
        
        // Only use cache if less than 1 hour old
        if let cachedAt = cache["cachedAt"] as? TimeInterval,
           Date().timeIntervalSince1970 - cachedAt < 3600 {
            
            isInRest = cache["isInRest"] as? Bool ?? false
            
            if let endTimestamp = cache["restEndTime"] as? TimeInterval, endTimestamp > 0 {
                restEndTime = Date(timeIntervalSince1970: endTimestamp)
            }
            
            if let startTimestamp = cache["restStartTime"] as? TimeInterval, startTimestamp > 0 {
                restStartTime = Date(timeIntervalSince1970: startTimestamp)
            }
            
            if let lastDutyTimestamp = cache["lastDutyEndTime"] as? TimeInterval, lastDutyTimestamp > 0 {
                lastDutyEndTime = Date(timeIntervalSince1970: lastDutyTimestamp)
            }
            
            // Validate - if rest end time has passed, clear it
            if let endTime = restEndTime, Date() >= endTime {
                isInRest = false
                restEndTime = nil
                restStartTime = nil
            }
            
            print("📱 Loaded cached rest status: isInRest=\(isInRest)")
        }
    }
}

//
//  PilotDutyAttributes.swift
//  Shared between ProPilotApp, TestWidgetExtension, and Watch App
//

import Foundation
import SwiftUI

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Flight Phase Enum (Available on ALL platforms)
enum FlightPhase: String, Codable, CaseIterable, Hashable, Equatable {
    case preTrip = "Pre-Trip"
    case boarding = "Pre-Flight"
    case taxiOut = "Taxi Out"
    case enroute = "Enroute"
    case approach = "Approach"
    case taxiIn = "Taxi In"
    case complete = "Complete"
    case offDuty = "Off Duty"
    
    var icon: String {
        switch self {
        case .preTrip: return "airplane.circle"
        case .boarding: return "figure.walk"
        case .taxiOut: return "arrow.right.circle"
        case .enroute: return "airplane"
        case .approach: return "arrow.down.circle"
        case .taxiIn: return "arrow.left.circle"
        case .complete: return "checkmark.circle"
        case .offDuty: return "moon.zzz"
        }
    }
    
    var color: Color {
        switch self {
        case .preTrip: return .gray
        case .boarding: return .blue
        case .taxiOut: return .orange
        case .enroute: return .green
        case .approach: return .orange
        case .taxiIn: return .blue
        case .complete: return .gray
        case .offDuty: return .gray
        }
    }
    
    var nextAction: String {
        switch self {
        case .preTrip: return "Set OUT time"
        case .boarding: return "Set OUT time"
        case .taxiOut: return "Set OFF time"
        case .enroute: return "Set ON time"
        case .approach: return "Set IN time"
        case .taxiIn: return "Complete leg"
        case .complete: return "Trip complete"
        case .offDuty: return "Start duty"
        }
    }
}

// MARK: - Live Activity Attributes (iOS only)
#if canImport(ActivityKit)
struct PilotDutyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic properties that can change during the activity
        var flightPhase: FlightPhase
        var currentAirport: String
        var currentAirportName: String
        var dutyElapsedMinutes: Int
        var blockOutTime: String?
        var blockOffTime: String?
        var blockOnTime: String?
        var blockInTime: String?
        var nextLegDeparture: String?
        var nextLegArrival: String?
        
        // Computed properties for display
        var dutyTimeFormatted: String {
            let hours = dutyElapsedMinutes / 60
            let minutes = dutyElapsedMinutes % 60
            return String(format: "%d:%02d", hours, minutes)
        }
        
        var hasActiveFlightTimes: Bool {
            return blockOutTime != nil || blockOffTime != nil ||
                   blockOnTime != nil || blockInTime != nil
        }
    }
    
    // Static properties set when activity starts
    var tripNumber: String
    var aircraftType: String
    var departure: String
    var arrival: String
    var dutyStartTime: Date
}

// MARK: - Helper Extensions (iOS only)
extension PilotDutyAttributes.ContentState {
    static func initial(airport: String, airportName: String) -> Self {
        return Self(
            flightPhase: .preTrip,
            currentAirport: airport,
            currentAirportName: airportName,
            dutyElapsedMinutes: 0,
            blockOutTime: nil,
            blockOffTime: nil,
            blockOnTime: nil,
            blockInTime: nil,
            nextLegDeparture: nil,
            nextLegArrival: nil
        )
    }
    
    func withUpdatedDutyTime(from startTime: Date) -> Self {
        var state = self
        let elapsed = Int(Date().timeIntervalSince(startTime) / 60)
        state.dutyElapsedMinutes = elapsed
        return state
    }
    
    func withUpdatedFlightPhase(_ phase: FlightPhase) -> Self {
        var state = self
        state.flightPhase = phase
        return state
    }
    
    func withUpdatedFlightTimes(out: String? = nil, off: String? = nil,
                                on: String? = nil, inTime: String? = nil) -> Self {
        var state = self
        if let out = out { state.blockOutTime = out }
        if let off = off { state.blockOffTime = off }
        if let on = on { state.blockOnTime = on }
        if let inTime = inTime { state.blockInTime = inTime }
        
        // Auto-update phase based on times
        if inTime != nil {
            state.flightPhase = .taxiIn
        } else if on != nil {
            state.flightPhase = .approach
        } else if off != nil {
            state.flightPhase = .enroute
        } else if out != nil {
            state.flightPhase = .taxiOut
        }
        
        return state
    }
}
#endif

// MARK: - Shared Flight Data (All platforms)
struct SharedFlightData: Codable {
    let flightNumber: String?
    let departure: String?
    let arrival: String?
    let outTime: Date?
    let offTime: Date?
    let onTime: Date?
    let inTime: Date?
    let aircraftType: String?
    let gate: String?
    
    init(flightNumber: String? = nil,
         departure: String? = nil,
         arrival: String? = nil,
         outTime: Date? = nil,
         offTime: Date? = nil,
         onTime: Date? = nil,
         inTime: Date? = nil,
         aircraftType: String? = nil,
         gate: String? = nil) {
        self.flightNumber = flightNumber
        self.departure = departure
        self.arrival = arrival
        self.outTime = outTime
        self.offTime = offTime
        self.onTime = onTime
        self.inTime = inTime
        self.aircraftType = aircraftType
        self.gate = gate
    }
}

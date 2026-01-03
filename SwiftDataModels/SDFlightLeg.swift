//
//  SDFlightLeg.swift
//  TheProPilotApp
//
//  SwiftData model for FlightLeg persistence with CloudKit sync
//

import Foundation
import SwiftData

@Model
final class SDFlightLeg {
    // MARK: - Identifier (no unique constraint for CloudKit)
    var legId: UUID = UUID()

    // MARK: - Order within logpage (with default for CloudKit)
    var legOrder: Int = 0

    // MARK: - Basic Flight Info (with defaults for CloudKit)
    var departure: String = ""
    var arrival: String = ""
    var outTime: String = ""
    var offTime: String = ""
    var onTime: String = ""
    var inTime: String = ""
    var flightNumber: String = ""
    var isDeadhead: Bool = false
    var flightDate: Date?

    // MARK: - Status & Role (stored as raw strings with defaults)
    var statusRaw: String = "active"
    var legPilotRoleRaw: String = "notSet"

    // MARK: - Scheduled Times from Roster
    var scheduledOut: Date?
    var scheduledIn: Date?
    var scheduledFlightNumber: String?
    var rosterSourceId: String?

    // MARK: - Deadhead Fields (with defaults for CloudKit)
    var deadheadOutTime: String = ""
    var deadheadInTime: String = ""
    var deadheadFlightHours: Double = 0.0

    // MARK: - Night Operations (with defaults for CloudKit)
    var nightTakeoff: Bool = false
    var nightLanding: Bool = false

    // MARK: - GPS Track Data (stored as JSON Data for CloudKit)
    var trackData: Data?
    var hasRecordedTrack: Bool = false

    // MARK: - Relationship (optional for CloudKit)
    // Explicit @Relationship required for CloudKit to create REFERENCE type instead of STRING
    @Relationship
    var parentLogpage: SDLogpage?

    // MARK: - Computed Properties (Transient)
    var status: LegStatus {
        get { LegStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var legPilotRole: LegPilotRole {
        get { LegPilotRole(rawValue: legPilotRoleRaw) ?? .notSet }
        set { legPilotRoleRaw = newValue.rawValue }
    }

    // MARK: - Default Initializer (required for SwiftData)
    init() {}

    // MARK: - Initializer from FlightLeg struct
    init(from leg: FlightLeg, order: Int) {
        self.legId = leg.id
        self.legOrder = order
        self.departure = leg.departure
        self.arrival = leg.arrival
        self.outTime = leg.outTime
        self.offTime = leg.offTime
        self.onTime = leg.onTime
        self.inTime = leg.inTime
        self.flightNumber = leg.flightNumber
        self.isDeadhead = leg.isDeadhead
        self.flightDate = leg.flightDate
        self.statusRaw = leg.status.rawValue
        self.legPilotRoleRaw = leg.legPilotRole.rawValue
        self.scheduledOut = leg.scheduledOut
        self.scheduledIn = leg.scheduledIn
        self.scheduledFlightNumber = leg.scheduledFlightNumber
        self.rosterSourceId = leg.rosterSourceId
        self.deadheadOutTime = leg.deadheadOutTime
        self.deadheadInTime = leg.deadheadInTime
        self.deadheadFlightHours = leg.deadheadFlightHours
        self.nightTakeoff = leg.nightTakeoff
        self.nightLanding = leg.nightLanding
        self.trackData = leg.trackData
        self.hasRecordedTrack = leg.hasRecordedTrack
    }

    // MARK: - Convert to View Model (FlightLeg struct)
    func toFlightLeg() -> FlightLeg {
        var leg = FlightLeg()
        leg.id = legId
        leg.departure = departure
        leg.arrival = arrival
        leg.outTime = outTime
        leg.offTime = offTime
        leg.onTime = onTime
        leg.inTime = inTime
        leg.flightNumber = flightNumber
        leg.isDeadhead = isDeadhead
        leg.flightDate = flightDate
        leg.status = status
        leg.legPilotRole = legPilotRole
        leg.scheduledOut = scheduledOut
        leg.scheduledIn = scheduledIn
        leg.scheduledFlightNumber = scheduledFlightNumber
        leg.rosterSourceId = rosterSourceId
        leg.deadheadOutTime = deadheadOutTime
        leg.deadheadInTime = deadheadInTime
        leg.deadheadFlightHours = deadheadFlightHours
        leg.nightTakeoff = nightTakeoff
        leg.nightLanding = nightLanding
        leg.trackData = trackData
        leg.hasRecordedTrack = hasRecordedTrack
        return leg
    }

    // MARK: - Update from FlightLeg struct
    func update(from leg: FlightLeg, order: Int) {
        self.legOrder = order
        self.departure = leg.departure
        self.arrival = leg.arrival
        self.outTime = leg.outTime
        self.offTime = leg.offTime
        self.onTime = leg.onTime
        self.inTime = leg.inTime
        self.flightNumber = leg.flightNumber
        self.isDeadhead = leg.isDeadhead
        self.flightDate = leg.flightDate
        self.statusRaw = leg.status.rawValue
        self.legPilotRoleRaw = leg.legPilotRole.rawValue
        self.scheduledOut = leg.scheduledOut
        self.scheduledIn = leg.scheduledIn
        self.scheduledFlightNumber = leg.scheduledFlightNumber
        self.rosterSourceId = leg.rosterSourceId
        self.deadheadOutTime = leg.deadheadOutTime
        self.deadheadInTime = leg.deadheadInTime
        self.deadheadFlightHours = leg.deadheadFlightHours
        self.nightTakeoff = leg.nightTakeoff
        self.nightLanding = leg.nightLanding
        self.trackData = leg.trackData
        self.hasRecordedTrack = leg.hasRecordedTrack
    }
}

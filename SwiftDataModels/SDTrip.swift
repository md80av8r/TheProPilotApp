//
//  SDTrip.swift
//  TheProPilotApp
//
//  SwiftData model for Trip persistence with CloudKit sync
//

import Foundation
import SwiftData

@Model
final class SDTrip {
    // MARK: - Identifier (no unique constraint for CloudKit)
    var tripId: UUID = UUID()

    // MARK: - Basic Fields (with defaults for CloudKit)
    var tripNumber: String = ""
    var aircraft: String = ""
    var date: Date = Date()
    var notes: String = ""

    // MARK: - Enum Raw Values (stored as String for CloudKit compatibility)
    var tripTypeRaw: String = "operating"
    var statusRaw: String = "planning"
    var pilotRoleRaw: String = "captain"

    // MARK: - Optional Fields
    var deadheadAirline: String?
    var deadheadFlightNumber: String?
    var simulatorMinutes: Int?

    // MARK: - Per Diem
    var perDiemStarted: Date?
    var perDiemEnded: Date?

    // MARK: - Roster Integration
    var rosterSourceIds: [String]?
    var showTimeAlarmId: String?
    var scheduledShowTime: Date?

    // MARK: - Duty Time
    var dutyStartTime: Date?
    var dutyEndTime: Date?
    var dutyMinutes: Int?

    // MARK: - Workflow (with defaults for CloudKit)
    var receiptCount: Int = 0
    var logbookPageSent: Bool = false

    // MARK: - Relationships (optional for CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \SDLogpage.trip)
    var logpages: [SDLogpage]?

    @Relationship(deleteRule: .cascade, inverse: \SDCrewMember.trip)
    var crew: [SDCrewMember]?

    // MARK: - Computed Properties (Transient - not stored)
    var tripType: TripType {
        get { TripType(rawValue: tripTypeRaw) ?? .operating }
        set { tripTypeRaw = newValue.rawValue }
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var pilotRole: PilotRole {
        get { PilotRole(rawValue: pilotRoleRaw) ?? .captain }
        set { pilotRoleRaw = newValue.rawValue }
    }

    // MARK: - Default Initializer (required for SwiftData)
    init() {}

    // MARK: - Initializer from Trip struct
    init(from trip: Trip) {
        self.tripId = trip.id
        self.tripNumber = trip.tripNumber
        self.aircraft = trip.aircraft
        self.date = trip.date
        self.notes = trip.notes
        self.tripTypeRaw = trip.tripType.rawValue
        self.statusRaw = trip.status.rawValue
        self.pilotRoleRaw = trip.pilotRole.rawValue
        self.deadheadAirline = trip.deadheadAirline
        self.deadheadFlightNumber = trip.deadheadFlightNumber
        self.simulatorMinutes = trip.simulatorMinutes
        self.perDiemStarted = trip.perDiemStarted
        self.perDiemEnded = trip.perDiemEnded
        self.rosterSourceIds = trip.rosterSourceIds
        self.showTimeAlarmId = trip.showTimeAlarmId
        self.scheduledShowTime = trip.scheduledShowTime
        self.dutyStartTime = trip.dutyStartTime
        self.dutyEndTime = trip.dutyEndTime
        self.dutyMinutes = trip.dutyMinutes
        self.receiptCount = trip.receiptCount
        self.logbookPageSent = trip.logbookPageSent
        self.logpages = nil
        self.crew = nil
    }

    // MARK: - Convert to View Model (Trip struct)
    func toTrip() -> Trip {
        // Sort logpages by page number
        let sortedLogpages = (logpages ?? []).sorted { $0.pageNumber < $1.pageNumber }

        var trip = Trip(
            id: tripId,
            tripNumber: tripNumber,
            aircraft: aircraft,
            date: date,
            tatStart: sortedLogpages.first?.tatStart ?? "",
            crew: (crew ?? []).map { $0.toCrewMember() },
            notes: notes,
            legs: [],  // Will be populated via logpages
            tripType: tripType,
            deadheadAirline: deadheadAirline,
            deadheadFlightNumber: deadheadFlightNumber,
            status: status,
            pilotRole: pilotRole,
            receiptCount: receiptCount,
            logbookPageSent: logbookPageSent,
            perDiemStarted: perDiemStarted,
            perDiemEnded: perDiemEnded,
            simulatorMinutes: simulatorMinutes,
            rosterSourceIds: rosterSourceIds,
            scheduledShowTime: scheduledShowTime
        )

        // Rebuild logpages with proper structure
        trip.logpages = sortedLogpages.map { $0.toLogpage() }

        // Set remaining properties
        trip.dutyStartTime = dutyStartTime
        trip.dutyEndTime = dutyEndTime
        trip.dutyMinutes = dutyMinutes
        trip.showTimeAlarmId = showTimeAlarmId

        return trip
    }

    // MARK: - Update from Trip struct
    func update(from trip: Trip) {
        self.tripNumber = trip.tripNumber
        self.aircraft = trip.aircraft
        self.date = trip.date
        self.notes = trip.notes
        self.tripTypeRaw = trip.tripType.rawValue
        self.statusRaw = trip.status.rawValue
        self.pilotRoleRaw = trip.pilotRole.rawValue
        self.deadheadAirline = trip.deadheadAirline
        self.deadheadFlightNumber = trip.deadheadFlightNumber
        self.simulatorMinutes = trip.simulatorMinutes
        self.perDiemStarted = trip.perDiemStarted
        self.perDiemEnded = trip.perDiemEnded
        self.rosterSourceIds = trip.rosterSourceIds
        self.showTimeAlarmId = trip.showTimeAlarmId
        self.scheduledShowTime = trip.scheduledShowTime
        self.dutyStartTime = trip.dutyStartTime
        self.dutyEndTime = trip.dutyEndTime
        self.dutyMinutes = trip.dutyMinutes
        self.receiptCount = trip.receiptCount
        self.logbookPageSent = trip.logbookPageSent
    }
}

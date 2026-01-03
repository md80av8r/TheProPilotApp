//
//  SDLogpage.swift
//  TheProPilotApp
//
//  SwiftData model for Logpage persistence with CloudKit sync
//

import Foundation
import SwiftData

@Model
final class SDLogpage {
    // MARK: - Identifier (no unique constraint for CloudKit)
    var logpageId: UUID = UUID()

    // MARK: - Fields (with defaults for CloudKit)
    var pageNumber: Int = 1
    var tatStart: String = ""
    var mechanicalIssueNote: String?
    var dateCreated: Date = Date()

    // MARK: - Relationships (optional for CloudKit)
    // Explicit @Relationship required for CloudKit to create REFERENCE type instead of STRING
    @Relationship
    var owningTrip: SDTrip?

    @Relationship(deleteRule: .cascade, inverse: \SDFlightLeg.parentLogpage)
    var legs: [SDFlightLeg]?

    // MARK: - Default Initializer (required for SwiftData)
    init() {}

    // MARK: - Initializer from Logpage struct
    init(from logpage: Logpage) {
        self.logpageId = logpage.id
        self.pageNumber = logpage.pageNumber
        self.tatStart = logpage.tatStart
        self.mechanicalIssueNote = logpage.mechanicalIssueNote
        self.dateCreated = logpage.dateCreated
        self.legs = nil
    }

    // MARK: - Convert to View Model (Logpage struct)
    func toLogpage() -> Logpage {
        // Sort legs by order
        let sortedLegs = (legs ?? []).sorted { $0.legOrder < $1.legOrder }

        return Logpage(
            id: logpageId,
            pageNumber: pageNumber,
            tatStart: tatStart,
            legs: sortedLegs.map { $0.toFlightLeg() },
            mechanicalIssueNote: mechanicalIssueNote,
            dateCreated: dateCreated
        )
    }

    // MARK: - Update from Logpage struct
    func update(from logpage: Logpage) {
        self.pageNumber = logpage.pageNumber
        self.tatStart = logpage.tatStart
        self.mechanicalIssueNote = logpage.mechanicalIssueNote
        self.dateCreated = logpage.dateCreated
    }
}

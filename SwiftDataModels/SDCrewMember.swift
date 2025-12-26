//
//  SDCrewMember.swift
//  TheProPilotApp
//
//  SwiftData model for CrewMember persistence with CloudKit sync
//

import Foundation
import SwiftData

@Model
final class SDCrewMember {
    // MARK: - Identifier (no unique constraint for CloudKit)
    var crewId: UUID = UUID()

    // MARK: - Fields (with defaults for CloudKit)
    var role: String = ""
    var name: String = ""
    var email: String = ""

    // MARK: - Relationship (optional for CloudKit)
    var trip: SDTrip?

    // MARK: - Default Initializer (required for SwiftData)
    init() {}

    // MARK: - Initializer from CrewMember struct
    init(from crew: CrewMember) {
        self.crewId = crew.id
        self.role = crew.role
        self.name = crew.name
        self.email = crew.email
    }

    // MARK: - Convert to View Model (CrewMember struct)
    func toCrewMember() -> CrewMember {
        CrewMember(id: crewId, role: role, name: name, email: email)
    }

    // MARK: - Update from CrewMember struct
    func update(from crew: CrewMember) {
        self.role = crew.role
        self.name = crew.name
        self.email = crew.email
    }
}

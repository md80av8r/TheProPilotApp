//
//  SwiftDataConfiguration.swift
//  TheProPilotApp
//
//  Configuration for SwiftData ModelContainer with CloudKit sync
//

import Foundation
import SwiftData

enum SwiftDataConfiguration {

    // MARK: - Schema
    static let schema = Schema([
        SDTrip.self,
        SDLogpage.self,
        SDFlightLeg.self,
        SDCrewMember.self
    ])

    // MARK: - App Group Identifier
    static let appGroupIdentifier = "group.com.propilot.app"

    // MARK: - CloudKit Container
    static let cloudKitContainerIdentifier = "iCloud.com.jkadans.ProPilotApp"

    // MARK: - Store URL
    static var storeURL: URL {
        // Try App Group first (for Watch app sharing)
        if let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            print("✅ Using App Group container for SwiftData store")
            return appGroupURL.appendingPathComponent("ProPilotLogbook.store")
        }

        // Fallback to Documents directory if App Group not available
        print("⚠️ App Group not available, using Documents directory for SwiftData store")
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("ProPilotLogbook.store")
    }

    // MARK: - iOS Model Configuration (with CloudKit)
    static func createModelConfiguration() -> ModelConfiguration {
        // Explicitly specify CloudKit container identifier
        // The environment (Development/Production) is controlled by entitlements
        return ModelConfiguration(
            "ProPilotLogbook",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
    }

    // MARK: - Watch Model Configuration (shares store with iOS via App Group)
    static func createWatchModelConfiguration() -> ModelConfiguration {
        // Watch reads/writes to the same shared store
        // CloudKit sync happens through the iOS app
        return ModelConfiguration(
            "ProPilotLogbook",
            schema: schema,
            url: storeURL
        )
    }

    // MARK: - Create ModelContainer for iOS (with CloudKit)
    // Note: Not marked @MainActor since it's called from App.init() which is synchronous
    static func createModelContainer() throws -> ModelContainer {
        // Use the schema directly - CloudKit is configured via entitlements
        // SwiftData automatically syncs with CloudKit when the app has
        // the iCloud capability with CloudKit enabled
        return try ModelContainer(
            for: SDTrip.self, SDLogpage.self, SDFlightLeg.self, SDCrewMember.self,
            configurations: createModelConfiguration()
        )
    }

    // MARK: - Create ModelContainer for Watch
    static func createWatchModelContainer() throws -> ModelContainer {
        return try ModelContainer(
            for: SDTrip.self, SDLogpage.self, SDFlightLeg.self, SDCrewMember.self,
            configurations: createWatchModelConfiguration()
        )
    }

    // MARK: - Preview Container (in-memory for SwiftUI Previews)
    @MainActor
    static func createPreviewContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SDTrip.self, SDLogpage.self, SDFlightLeg.self, SDCrewMember.self,
            configurations: config
        )
    }
}

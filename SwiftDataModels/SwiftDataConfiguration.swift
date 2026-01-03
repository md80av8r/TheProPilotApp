//
//  SwiftDataConfiguration.swift
//  TheProPilotApp
//
//  Configuration for SwiftData ModelContainer with CloudKit sync
//

import Foundation
import SwiftData
import CloudKit

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
    static let cloudKitContainerIdentifier = "iCloud.com.jkadans.TheProPilotApp"

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

    // MARK: - CloudKit Zone Reset

    /// Resets the CloudKit zone to clear corrupted records.
    /// This will delete ALL CloudKit data and allow it to re-sync from local.
    /// WARNING: This is destructive and should only be used when CloudKit is completely blocked.
    static func resetCloudKitZone() async throws {
        print("🔥 CLOUDKIT ZONE RESET: Starting...")

        let container = CKContainer(identifier: cloudKitContainerIdentifier)
        let privateDB = container.privateCloudDatabase

        // The SwiftData CloudKit zone
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        do {
            // Delete the entire zone - this removes all corrupted records
            try await privateDB.deleteRecordZone(withID: zoneID)
            print("✅ CloudKit zone deleted successfully")

            // The zone will be automatically recreated on next sync
            // SwiftData will re-upload all local data
            print("ℹ️ Zone will be recreated on next sync. Local data will be re-uploaded.")

        } catch let error as CKError {
            if error.code == .zoneNotFound {
                print("ℹ️ Zone doesn't exist - nothing to delete")
            } else {
                print("❌ Failed to delete CloudKit zone: \(error.localizedDescription)")
                throw error
            }
        } catch {
            print("❌ CloudKit zone reset failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Local Database Reset

    /// Deletes the local SQLite database file completely.
    /// This forces SwiftData to recreate the database with fresh schema.
    /// Use this when the local schema is corrupted and doesn't match CloudKit.
    /// WARNING: This deletes ALL local data. Re-import from backup after calling this.
    static func deleteLocalDatabase() -> Bool {
        print("🔥 LOCAL DATABASE RESET: Deleting SQLite file...")

        let fileManager = FileManager.default
        let storeURL = Self.storeURL

        // SwiftData/CoreData creates multiple files with the same base name
        let baseName = storeURL.deletingPathExtension().lastPathComponent
        let directory = storeURL.deletingLastPathComponent()

        var deletedFiles: [String] = []
        var errors: [String] = []

        // Delete all related database files
        let extensions = ["store", "store-shm", "store-wal", "sqlite", "sqlite-shm", "sqlite-wal"]

        for ext in extensions {
            let fileURL = directory.appendingPathComponent("\(baseName).\(ext)")
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    deletedFiles.append(fileURL.lastPathComponent)
                    print("✅ Deleted: \(fileURL.lastPathComponent)")
                } catch {
                    errors.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
                    print("❌ Failed to delete \(fileURL.lastPathComponent): \(error)")
                }
            }
        }

        // Also try to delete any CoreData CloudKit metadata
        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let ckMetadataURL = appGroupURL.appendingPathComponent("CoreDataCloudKitMetadata")
            if fileManager.fileExists(atPath: ckMetadataURL.path) {
                do {
                    try fileManager.removeItem(at: ckMetadataURL)
                    print("✅ Deleted CloudKit metadata directory")
                } catch {
                    print("⚠️ Could not delete CloudKit metadata: \(error)")
                }
            }
        }

        if deletedFiles.isEmpty {
            print("ℹ️ No database files found to delete")
            return true // Not an error if no files exist
        }

        print("✅ LOCAL DATABASE RESET COMPLETE: Deleted \(deletedFiles.count) files")
        print("ℹ️ App must be restarted to recreate database with fresh schema")

        return errors.isEmpty
    }

    /// Checks if CloudKit is available and the user is signed in
    static func checkCloudKitStatus() async -> (available: Bool, accountStatus: CKAccountStatus, error: String?) {
        let container = CKContainer(identifier: cloudKitContainerIdentifier)

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                return (true, status, nil)
            case .noAccount:
                return (false, status, "Not signed in to iCloud")
            case .restricted:
                return (false, status, "iCloud access is restricted")
            case .couldNotDetermine:
                return (false, status, "Could not determine iCloud status")
            case .temporarilyUnavailable:
                return (false, status, "iCloud temporarily unavailable")
            @unknown default:
                return (false, status, "Unknown iCloud status")
            }
        } catch {
            return (false, .couldNotDetermine, error.localizedDescription)
        }
    }
}

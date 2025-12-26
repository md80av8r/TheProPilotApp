//
//  MigrationManager.swift
//  TheProPilotApp
//
//  Handles one-time migration from JSON-based storage to SwiftData
//

import Foundation
import SwiftData

@MainActor
class MigrationManager {
    static let shared = MigrationManager()

    private let migrationKey = "hasCompletedSwiftDataMigration_v1"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SwiftDataConfiguration.appGroupIdentifier)
    }

    // MARK: - Check Migration Status
    var needsMigration: Bool {
        guard let defaults = sharedDefaults else { return false }
        return !defaults.bool(forKey: migrationKey)
    }

    // MARK: - Perform Migration
    func migrateIfNeeded(to container: ModelContainer) async throws {
        guard needsMigration else {
            print("SwiftData migration already completed")
            return
        }

        print("Starting JSON to SwiftData migration...")

        // Load existing JSON data
        let jsonTrips = loadExistingJSONTrips()

        guard !jsonTrips.isEmpty else {
            print("No JSON data to migrate")
            markMigrationComplete()
            return
        }

        print("Migrating \(jsonTrips.count) trips...")

        let context = container.mainContext

        for trip in jsonTrips {
            // Create SwiftData trip entity
            let sdTrip = SDTrip(from: trip)
            context.insert(sdTrip)

            // Create logpages with legs
            for logpage in trip.logpages {
                let sdLogpage = SDLogpage(from: logpage)
                sdLogpage.trip = sdTrip
                context.insert(sdLogpage)

                // Create legs within logpage
                for (order, leg) in logpage.legs.enumerated() {
                    let sdLeg = SDFlightLeg(from: leg, order: order)
                    sdLeg.logpage = sdLogpage
                    context.insert(sdLeg)
                }
            }

            // Create crew members
            for crew in trip.crew {
                let sdCrew = SDCrewMember(from: crew)
                sdCrew.trip = sdTrip
                context.insert(sdCrew)
            }
        }

        // Save all changes
        try context.save()

        print("Migration complete: \(jsonTrips.count) trips migrated to SwiftData")
        markMigrationComplete()

        // Archive the old JSON file (don't delete - keep as backup)
        archiveOldJSONFile()
    }

    // MARK: - Load Existing JSON Trips
    private func loadExistingJSONTrips() -> [Trip] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SwiftDataConfiguration.appGroupIdentifier
        ) else {
            print("Migration: Unable to access App Group container")
            return []
        }

        let fileURL = containerURL.appendingPathComponent("logbook.json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Migration: No logbook.json file found")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let trips = try decoder.decode([Trip].self, from: data)
            print("Migration: Loaded \(trips.count) trips from JSON")
            return trips
        } catch {
            print("Migration: Failed to decode JSON - \(error)")
            return []
        }
    }

    // MARK: - Mark Migration Complete
    private func markMigrationComplete() {
        sharedDefaults?.set(true, forKey: migrationKey)
        sharedDefaults?.synchronize()
        print("Migration: Marked as complete in UserDefaults")
    }

    // MARK: - Archive Old JSON File
    private func archiveOldJSONFile() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SwiftDataConfiguration.appGroupIdentifier
        ) else {
            return
        }

        let sourceURL = containerURL.appendingPathComponent("logbook.json")
        let archiveURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return
        }

        do {
            // Remove existing archive if present
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.removeItem(at: archiveURL)
            }

            // Copy to archive (don't move - keep original until we're confident)
            try FileManager.default.copyItem(at: sourceURL, to: archiveURL)
            print("Migration: Archived old JSON file to \(archiveURL.lastPathComponent)")
        } catch {
            print("Migration: Failed to archive JSON file - \(error)")
        }
    }

    // MARK: - Rollback Support (for debugging/emergencies)
    func rollbackMigration() throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SwiftDataConfiguration.appGroupIdentifier
        ) else {
            throw MigrationError.appGroupNotAccessible
        }

        let archiveURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")
        let targetURL = containerURL.appendingPathComponent("logbook.json")

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw MigrationError.noBackupFound
        }

        // Restore from archive
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: archiveURL, to: targetURL)

        // Reset migration flag
        sharedDefaults?.set(false, forKey: migrationKey)
        sharedDefaults?.synchronize()

        print("Migration: Rollback complete - restored JSON backup")
    }

    // MARK: - Check for Backup
    var hasBackup: Bool {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SwiftDataConfiguration.appGroupIdentifier
        ) else {
            return false
        }

        let archiveURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")
        return FileManager.default.fileExists(atPath: archiveURL.path)
    }
}

// MARK: - Migration Errors
enum MigrationError: Error, LocalizedError {
    case appGroupNotAccessible
    case noBackupFound
    case migrationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .appGroupNotAccessible:
            return "Unable to access App Group container"
        case .noBackupFound:
            return "No backup file found for rollback"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}

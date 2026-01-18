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
                sdLogpage.owningTrip = sdTrip
                context.insert(sdLogpage)

                // Create legs within logpage
                for (order, leg) in logpage.legs.enumerated() {
                    let sdLeg = SDFlightLeg(from: leg, order: order)
                    sdLeg.parentLogpage = sdLogpage
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
    case cloudKitUnavailable
    case noLegacyDataFound

    var errorDescription: String? {
        switch self {
        case .appGroupNotAccessible:
            return "Unable to access App Group container"
        case .noBackupFound:
            return "No backup file found for rollback"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .cloudKitUnavailable:
            return "iCloud is not available"
        case .noLegacyDataFound:
            return "No legacy CloudKit data found to migrate"
        }
    }
}

// MARK: - CloudKit to SwiftData Migration Helper

/// Migrates trips from OLD CloudKit "Trip" records to SwiftData's "CD_SDTrip" records.
/// Use this when a user has legacy data in CloudKit from before the SwiftData migration.
@MainActor
class CloudKitMigrationHelper: ObservableObject {
    static let shared = CloudKitMigrationHelper()

    @Published var migrationStatus: MigrationStatus = .idle
    @Published var progressMessage: String = ""
    @Published var legacyTripCount: Int = 0
    @Published var migratedCount: Int = 0

    enum MigrationStatus {
        case idle
        case checking
        case legacyDataFound(count: Int)
        case migrating(progress: Double)
        case completed(imported: Int, skipped: Int)
        case failed(error: String)
        case noLegacyData

        var isInProgress: Bool {
            switch self {
            case .checking, .migrating:
                return true
            default:
                return false
            }
        }
    }

    /// Checks if there are legacy CloudKit records that need migration
    func checkForLegacyData() async {
        migrationStatus = .checking
        progressMessage = "Checking for legacy CloudKit data..."

        // Check iCloud availability first
        let (available, _, error) = await SwiftDataConfiguration.checkCloudKitStatus()
        guard available else {
            migrationStatus = .failed(error: error ?? "iCloud unavailable")
            return
        }

        do {
            // Use the deprecated method intentionally to check for old data
            let legacyTrips = try await CloudKitManager.shared.fetchAllTrips()
            legacyTripCount = legacyTrips.count

            if legacyTrips.isEmpty {
                migrationStatus = .noLegacyData
                progressMessage = "No legacy CloudKit data found."
            } else {
                migrationStatus = .legacyDataFound(count: legacyTrips.count)
                progressMessage = "Found \(legacyTrips.count) trips in legacy CloudKit format."
            }
        } catch {
            migrationStatus = .failed(error: error.localizedDescription)
            progressMessage = "Failed to check CloudKit: \(error.localizedDescription)"
        }
    }

    /// Migrates legacy CloudKit data to SwiftData
    /// - Parameter store: The SwiftDataLogBookStore to import into
    /// - Parameter mergeWithExisting: If true, skips trips that already exist; if false, replaces duplicates
    func migrateLegacyData(to store: SwiftDataLogBookStore, mergeWithExisting: Bool = true) async {
        migrationStatus = .migrating(progress: 0)
        progressMessage = "Starting migration..."
        migratedCount = 0

        do {
            // Fetch legacy trips
            let legacyTrips = try await CloudKitManager.shared.fetchAllTrips()

            guard !legacyTrips.isEmpty else {
                migrationStatus = .noLegacyData
                return
            }

            let total = legacyTrips.count
            var imported = 0
            var skipped = 0

            for (index, trip) in legacyTrips.enumerated() {
                let progress = Double(index + 1) / Double(total)
                migrationStatus = .migrating(progress: progress)
                progressMessage = "Migrating trip \(index + 1) of \(total): #\(trip.tripNumber)"

                // CRITICAL FIX: Check DATABASE directly, not just in-memory store.trips
                // The addTrip function now handles this check internally
                // But we also do a pre-check here to provide accurate skip counts
                let existsInMemory = store.trips.contains { $0.id == trip.id }

                if existsInMemory && mergeWithExisting {
                    print("⏭️ Migration: Skipping existing trip #\(trip.tripNumber) (in memory)")
                    skipped += 1
                } else {
                    // addTrip now internally checks the DATABASE for duplicates
                    // and will skip if trip already exists in DB
                    let tripCountBefore = store.trips.count
                    store.addTrip(trip)
                    let tripCountAfter = store.trips.count

                    // Check if addTrip actually added it (or skipped due to DB check)
                    if tripCountAfter > tripCountBefore {
                        imported += 1
                        print("✅ Migration: Imported trip #\(trip.tripNumber)")
                    } else {
                        skipped += 1
                        print("⏭️ Migration: Skipping trip #\(trip.tripNumber) (found in database)")
                    }
                }

                migratedCount = imported
            }

            migrationStatus = .completed(imported: imported, skipped: skipped)
            progressMessage = "Migration complete! Imported \(imported) trips, skipped \(skipped) duplicates."

            print("☁️ CloudKit Migration Complete:")
            print("   - Total legacy trips: \(total)")
            print("   - Imported: \(imported)")
            print("   - Skipped (already exist): \(skipped)")

        } catch {
            migrationStatus = .failed(error: error.localizedDescription)
            progressMessage = "Migration failed: \(error.localizedDescription)"
        }
    }

    /// Deletes all legacy CloudKit records after successful migration
    /// This cleans up the old "Trip", "FlightLeg", "CrewMember" records
    func cleanupLegacyRecords() async {
        progressMessage = "Cleaning up legacy records..."

        do {
            let legacyTrips = try await CloudKitManager.shared.fetchAllTrips()

            for trip in legacyTrips {
                try await CloudKitManager.shared.deleteTrip(tripID: trip.id.uuidString)
            }

            progressMessage = "Cleaned up \(legacyTrips.count) legacy CloudKit records."
            print("🗑️ Cleaned up \(legacyTrips.count) legacy CloudKit records")
        } catch {
            progressMessage = "Cleanup failed: \(error.localizedDescription)"
            print("❌ Failed to cleanup legacy records: \(error)")
        }
    }
}

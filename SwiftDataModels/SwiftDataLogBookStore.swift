//
//  SwiftDataLogBookStore.swift
//  TheProPilotApp
//
//  SwiftData-based LogBookStore with CloudKit automatic sync
//  Replaces JSON-based LogBookStore with same API for compatibility
//

import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
class SwiftDataLogBookStore: ObservableObject {

    // MARK: - Published Properties (same as original LogBookStore)
    @Published var trips: [Trip] = []
    @Published var perDiemRate: Double = 2.50
    @Published var isLoading: Bool = false

    // Track when we last saved
    var lastSaveTime: Date?

    // MARK: - SwiftData
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }

    // MARK: - Initialization
    init(container: ModelContainer) {
        self.modelContainer = container

        // Perform migration if needed, then load trips
        Task {
            do {
                try await MigrationManager.shared.migrateIfNeeded(to: container)
                await loadTrips()
            } catch {
                print("Migration failed: \(error)")
                await loadTrips()
            }
        }

        setupAppLifecycleObservers()
    }

    // MARK: - Load Trips from SwiftData
    func loadTrips() async {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<SDTrip>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let sdTrips = try modelContext.fetch(descriptor)
            trips = sdTrips.map { $0.toTrip() }
            enforceOneActiveTrip()
            print("Loaded \(trips.count) trips from SwiftData")
        } catch {
            print("Failed to load trips from SwiftData: \(error)")
            trips = []
        }
    }

    // MARK: - Save (Compatibility method)
    func save() {
        do {
            try modelContext.save()
            lastSaveTime = Date()
            print("SwiftData context saved")
        } catch {
            print("Failed to save SwiftData context: \(error)")
        }
    }

    // MARK: - Save Trip
    func saveTrip(_ trip: Trip) {
        // Find existing or create new
        let tripId = trip.id
        let predicate = #Predicate<SDTrip> { $0.tripId == tripId }
        let descriptor = FetchDescriptor<SDTrip>(predicate: predicate)

        do {
            let existing = try modelContext.fetch(descriptor).first

            if let sdTrip = existing {
                updateSDTrip(sdTrip, from: trip)
            } else {
                insertNewTrip(trip)
            }

            try modelContext.save()

            // Update local cache
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = trip
            } else {
                trips.append(trip)
                trips.sort { $0.date > $1.date }
            }

            lastSaveTime = Date()

        } catch {
            print("Failed to save trip: \(error)")
        }
    }

    // MARK: - Add Trip
    func addTrip(_ trip: Trip) {
        // When adding a new active/planning trip, complete all others first
        if trip.status == .active || trip.status == .planning {
            for index in trips.indices {
                if trips[index].status == .active || trips[index].status == .planning {
                    var completedTrip = trips[index]
                    completedTrip.status = .completed
                    saveTrip(completedTrip)
                    print("Auto-completed trip #\(completedTrip.tripNumber) when adding new trip")
                }
            }
        }

        insertNewTrip(trip)

        do {
            try modelContext.save()
            trips.append(trip)
            trips.sort { $0.date > $1.date }
            lastSaveTime = Date()
        } catch {
            print("Failed to add trip: \(error)")
        }
    }

    // MARK: - Update Trip
    func updateTrip(_ trip: Trip, at index: Int) {
        guard trips.indices.contains(index) else { return }

        // If updating trip to active/planning, complete all other active/planning trips
        if trip.status == .active || trip.status == .planning {
            for i in trips.indices where i != index {
                if trips[i].status == .active || trips[i].status == .planning {
                    var completedTrip = trips[i]
                    completedTrip.status = .completed
                    saveTrip(completedTrip)
                    print("Auto-completed trip #\(completedTrip.tripNumber) when updating trip #\(trip.tripNumber)")
                }
            }
        }

        saveTrip(trip)
    }

    // MARK: - Delete Trip
    func deleteTrip(at offsets: IndexSet) {
        print("🗑️ DELETE: Removing trips at indices: \(offsets)")

        // Check if we're deleting the active trip
        let deletingActiveTrip = offsets.contains { index in
            let trip = trips[index]
            return trip.status == .active || trip.status == .planning
        }

        // If deleting active trip, clear it from watch
        if deletingActiveTrip {
            print("🗑️ DELETE: Clearing active trip from watch")
            PhoneWatchConnectivity.shared.sendClearTripToWatch()
            PhoneWatchConnectivity.shared.clearActiveTrip()
        }

        for index in offsets {
            let trip = trips[index]
            let tripId = trip.id

            // Find and delete from SwiftData
            let predicate = #Predicate<SDTrip> { $0.tripId == tripId }
            let descriptor = FetchDescriptor<SDTrip>(predicate: predicate)

            do {
                if let sdTrip = try modelContext.fetch(descriptor).first {
                    modelContext.delete(sdTrip)
                }
            } catch {
                print("Failed to find trip for deletion: \(error)")
            }
        }

        do {
            try modelContext.save()
            trips.remove(atOffsets: offsets)
            print("🗑️ DELETE: Removed trips successfully")
        } catch {
            print("Failed to delete trips: \(error)")
        }
    }

    // MARK: - Reload
    func reload() {
        print("Manual reload requested")
        Task {
            await loadTrips()
        }
    }

    // MARK: - Backup Compatibility
    func savePersistently() {
        save()
    }

    // MARK: - Active Trip Validation
    private func enforceOneActiveTrip() {
        let activePlanningTrips = trips.enumerated().filter {
            $0.element.status == .active || $0.element.status == .planning
        }

        guard activePlanningTrips.count > 1 else { return }

        print("Found \(activePlanningTrips.count) active/planning trips - fixing...")

        let mostRecentActiveTrip = activePlanningTrips.max(by: {
            $0.element.date < $1.element.date
        })

        for (index, trip) in trips.enumerated() {
            if (trip.status == .active || trip.status == .planning) {
                if index != mostRecentActiveTrip?.offset {
                    var completedTrip = trip
                    completedTrip.status = .completed
                    saveTrip(completedTrip)
                    print("Set trip #\(trip.tripNumber) to completed")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func insertNewTrip(_ trip: Trip) {
        let sdTrip = SDTrip(from: trip)
        modelContext.insert(sdTrip)

        for logpage in trip.logpages {
            let sdLogpage = SDLogpage(from: logpage)
            sdLogpage.trip = sdTrip
            modelContext.insert(sdLogpage)

            for (order, leg) in logpage.legs.enumerated() {
                let sdLeg = SDFlightLeg(from: leg, order: order)
                sdLeg.logpage = sdLogpage
                modelContext.insert(sdLeg)
            }
        }

        for crew in trip.crew {
            let sdCrew = SDCrewMember(from: crew)
            sdCrew.trip = sdTrip
            modelContext.insert(sdCrew)
        }
    }

    private func updateSDTrip(_ sdTrip: SDTrip, from trip: Trip) {
        // Update scalar properties
        sdTrip.update(from: trip)

        // Delete old relationships
        if let logpages = sdTrip.logpages {
            for logpage in logpages {
                if let legs = logpage.legs {
                    for leg in legs {
                        modelContext.delete(leg)
                    }
                }
                modelContext.delete(logpage)
            }
        }

        if let crew = sdTrip.crew {
            for member in crew {
                modelContext.delete(member)
            }
        }

        // Recreate relationships
        for logpage in trip.logpages {
            let sdLogpage = SDLogpage(from: logpage)
            sdLogpage.trip = sdTrip
            modelContext.insert(sdLogpage)

            for (order, leg) in logpage.legs.enumerated() {
                let sdLeg = SDFlightLeg(from: leg, order: order)
                sdLeg.logpage = sdLogpage
                modelContext.insert(sdLeg)
            }
        }

        for crew in trip.crew {
            let sdCrew = SDCrewMember(from: crew)
            sdCrew.trip = sdTrip
            modelContext.insert(sdCrew)
        }
    }

    // MARK: - App Lifecycle Observers

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("App entering foreground - reloading from SwiftData")
                await self?.loadTrips()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("App became active - reloading from SwiftData")
                await self?.loadTrips()
            }
        }

        // GPS Speed-Based Auto Times
        NotificationCenter.default.addObserver(
            forName: .takeoffRollStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAutoOffTime(notification)
        }

        NotificationCenter.default.addObserver(
            forName: .landingRollDecel,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAutoOnTime(notification)
        }
    }

    // MARK: - GPS Auto-Time Handlers

    private func handleAutoOffTime(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let airport = userInfo["airport"] as? String,
              let speedKt = userInfo["speedKt"] as? Double else {
            print("⚠️ Auto OFF: Missing notification data")
            return
        }

        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ Auto OFF: No active trip/leg found")
            return
        }

        if !trips[tripIndex].legs[activeLegIndex].offTime.isEmpty {
            print("⚠️ Auto OFF: Already set for this leg")
            return
        }

        let now = Date()
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)

        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        let timeString = formatter.string(from: roundedTime)

        trips[tripIndex].setOffTime(timeString, forLegAt: activeLegIndex)
        print("✅ Auto OFF: Set to \(timeString) for \(airport) at \(Int(speedKt)) kts")

        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    private func handleAutoOnTime(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let airport = userInfo["airport"] as? String,
              let speedKt = userInfo["speedKt"] as? Double else {
            print("⚠️ Auto ON: Missing notification data")
            return
        }

        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ Auto ON: No active trip/leg found")
            return
        }

        if !trips[tripIndex].legs[activeLegIndex].onTime.isEmpty {
            print("⚠️ Auto ON: Already set for this leg")
            return
        }

        let now = Date()
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)

        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        let timeString = formatter.string(from: roundedTime)

        trips[tripIndex].setOnTime(timeString, forLegAt: activeLegIndex)
        print("✅ Auto ON: Set to \(timeString) for \(airport) at \(Int(speedKt)) kts")

        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    // MARK: - Leg Time Update Methods

    func setOutTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOutTimeForActiveLeg: No active trip/leg found")
            return
        }

        trips[tripIndex].setOutTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    func setOffTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOffTimeForActiveLeg: No active trip/leg found")
            return
        }

        trips[tripIndex].setOffTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    func setOnTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOnTimeForActiveLeg: No active trip/leg found")
            return
        }

        trips[tripIndex].setOnTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    func setInTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setInTimeForActiveLeg: No active trip/leg found")
            return
        }

        trips[tripIndex].setInTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        saveTrip(trips[tripIndex])
    }

    func advanceToNextLeg() {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }) else {
            print("⚠️ advanceToNextLeg: No active trip found")
            return
        }

        trips[tripIndex].completeActiveLeg(activateNext: true)
        saveTrip(trips[tripIndex])
        print("✅ Manually advanced to next leg")
    }

    // MARK: - JSON Import/Export (Compatibility)

    func exportToJSON() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let exportData = ExportData(
                trips: trips,
                perDiemRate: perDiemRate,
                exportDate: Date(),
                appVersion: "TheProPilotApp v2.0 (SwiftData)"
            )

            return try encoder.encode(exportData)
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }

    @discardableResult
    func importFromJSON(_ data: Data, mergeWithExisting: Bool = true) -> JSONImportResult {
        let decoder = JSONDecoder()

        struct BackupWrapper: Codable {
            let backupVersion: String?
            let backupDate: String?
            let trips: [Trip]
        }

        decoder.dateDecodingStrategy = .iso8601
        if let backup = try? decoder.decode(BackupWrapper.self, from: data) {
            return processImport(backup.trips, mergeWithExisting: mergeWithExisting)
        }

        decoder.dateDecodingStrategy = .deferredToDate
        if let importedTrips = try? decoder.decode([Trip].self, from: data) {
            return processImport(importedTrips, mergeWithExisting: mergeWithExisting)
        }

        let strategies: [JSONDecoder.DateDecodingStrategy] = [.deferredToDate, .secondsSince1970]

        for strategy in strategies {
            decoder.dateDecodingStrategy = strategy
            if let backup = try? decoder.decode(BackupWrapper.self, from: data) {
                return processImport(backup.trips, mergeWithExisting: mergeWithExisting)
            }
        }

        for strategy in strategies {
            decoder.dateDecodingStrategy = strategy
            if let importedTrips = try? decoder.decode([Trip].self, from: data) {
                return processImport(importedTrips, mergeWithExisting: mergeWithExisting)
            }
        }

        return JSONImportResult(success: false, message: "Could not decode dates in any supported format", newTripsCount: 0)
    }

    private func processImport(_ importedTrips: [Trip], mergeWithExisting: Bool) -> JSONImportResult {
        if mergeWithExisting {
            let existingIDs = Set(trips.map { $0.id })
            let existingTripNumbers = Set(trips.map { "\($0.tripNumber)-\($0.date)" })

            var newTrips = importedTrips.filter { trip in
                !existingIDs.contains(trip.id) &&
                !existingTripNumbers.contains("\(trip.tripNumber)-\(trip.date)")
            }

            for index in newTrips.indices {
                if newTrips[index].status == .active || newTrips[index].status == .planning {
                    newTrips[index].status = .completed
                }
            }

            for trip in newTrips {
                insertNewTrip(trip)
                trips.append(trip)
            }

            do {
                try modelContext.save()
                trips.sort { $0.date > $1.date }
                enforceOneActiveTrip()
            } catch {
                print("Import save failed: \(error)")
            }

            return JSONImportResult(
                success: true,
                message: "Imported \(newTrips.count) new trips. Total: \(trips.count)",
                newTripsCount: newTrips.count
            )
        } else {
            // Delete all existing trips
            let descriptor = FetchDescriptor<SDTrip>()
            do {
                let allTrips = try modelContext.fetch(descriptor)
                for sdTrip in allTrips {
                    modelContext.delete(sdTrip)
                }
            } catch {
                print("Failed to delete existing trips: \(error)")
            }

            // Insert all imported trips
            for trip in importedTrips {
                insertNewTrip(trip)
            }

            do {
                try modelContext.save()
                trips = importedTrips
                trips.sort { $0.date > $1.date }
                enforceOneActiveTrip()
            } catch {
                print("Import save failed: \(error)")
            }

            return JSONImportResult(
                success: true,
                message: "Replaced all trips. Total: \(trips.count)",
                newTripsCount: trips.count
            )
        }
    }

    func exportTrip(_ trip: Trip) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode([trip])
        } catch {
            return nil
        }
    }

    func createBackupFile() -> URL? {
        guard let data = exportToJSON() else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let backupFileName = "ProPilot_Backup_\(Date().formatted(date: .abbreviated, time: .omitted)).json"
        let backupURL = tempDir.appendingPathComponent(backupFileName)

        do {
            try data.write(to: backupURL)
            return backupURL
        } catch {
            print("Backup creation failed: \(error)")
            return nil
        }
    }

    // MARK: - Data Recovery (Compatibility stubs)

    func hasRecoverableData() -> Bool {
        return MigrationManager.shared.hasBackup
    }

    func attemptDataRecovery() -> Bool {
        // With SwiftData, recovery works differently
        // Check if we have a backup and can restore
        return false
    }

    func recoverDataWithCrewMemberMigration() -> Bool {
        // Not needed with SwiftData - migration handles this
        return false
    }

    func loadWithRecovery() {
        Task {
            await loadTrips()
        }
    }
}

// MARK: - CloudKit Sync Extension (No-op - SwiftData handles this automatically)

extension SwiftDataLogBookStore {
    // These methods exist for API compatibility but do nothing
    // SwiftData + CloudKit handles sync automatically

    func syncFromCloud() async {
        // No-op: SwiftData syncs automatically
        print("syncFromCloud called - SwiftData handles sync automatically")
        await loadTrips() // Just reload from local store
    }

    func syncToCloud(trip: Trip) {
        // No-op: SwiftData syncs automatically
        print("syncToCloud called for trip \(trip.tripNumber) - SwiftData handles sync automatically")
    }

    func deleteFromCloud(tripID: String) {
        // No-op: SwiftData syncs automatically
        print("deleteFromCloud called for \(tripID) - SwiftData handles deletion automatically")
    }

    // MARK: - Preview Support
    static var preview: SwiftDataLogBookStore = {
        do {
            let container = try SwiftDataConfiguration.createPreviewContainer()
            return SwiftDataLogBookStore(container: container)
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}

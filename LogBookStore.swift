import Foundation
import Combine
import UIKit
import SwiftUI  // 🆕 PAYWALL: Required for SubscriptionStatusChecker

class LogBookStore: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var perDiemRate: Double = 2.50
    
    // Track when we last saved to detect recent changes
    var lastSaveTime: Date?

    private let fileURL: URL = {
        // Use shared App Group container so Watch can access
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") else {
            fatalError("Unable to access App Group container")
        }
        return container.appendingPathComponent("logbook.json")
    }()
    
    private var fileMonitorTimer: Timer?
    private var isSaving: Bool = false

    init() {
        loadWithRecovery()
        setupAppLifecycleObservers()
        startFileMonitoring()
    }
    
    deinit {
        stopFileMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Recovery
        func hasRecoverableData() -> Bool {
            // Check if there's any recoverable data in UserDefaults or backup location
            guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
                return false
            }
            
            // Check for backup data in UserDefaults
            if let _ = sharedDefaults.data(forKey: "logbookBackup") {
                return true
            }
            
            // Check for recovery file in App Group container
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") {
                let recoveryURL = containerURL.appendingPathComponent("logbook_recovery.json")
                if FileManager.default.fileExists(atPath: recoveryURL.path) {
                    return true
                }
            }
            
            // Check old location (before App Group migration)
            let oldURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("logbook_backup.json")
            if let oldURL = oldURL, FileManager.default.fileExists(atPath: oldURL.path) {
                return true
            }
            
            return false
        }
 
    // MARK: - App Lifecycle Monitoring
    
    private func setupAppLifecycleObservers() {
        // Reload when app becomes active (returns from background)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isSaving else { return }
            print("App entering foreground - reloading logbook")
            self.loadWithRecovery()
        }
        
        // Reload when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isSaving else { return }
            print("App became active - reloading logbook")
            self.loadWithRecovery()
        }
        
        // 🛩️ GPS Speed-Based Auto Times
        // Listen for OFF time (takeoff at 80+ knots)
        NotificationCenter.default.addObserver(
            forName: .takeoffRollStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            self.handleAutoOffTime(notification)
        }
        
        // Listen for ON time (landing decel at <60 knots)
        NotificationCenter.default.addObserver(
            forName: .landingRollDecel,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            self.handleAutoOnTime(notification)
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
        
        // Find active or planning trip
        guard let activeTrip = trips.first(where: { $0.status == .active || $0.status == .planning }) else {
            print("⚠️ Auto OFF: No active trip found")
            return
        }
        
        // Find the current leg index (looking for active leg)
        guard let tripIndex = trips.firstIndex(where: { $0.id == activeTrip.id }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ Auto OFF: No active leg found in trip")
            return
        }
        
        // Check if OFF time already set
        if !trips[tripIndex].legs[activeLegIndex].offTime.isEmpty {
            print("⚠️ Auto OFF: Already set for this leg")
            return
        }
        
        // Format the current time as HHmm string (with rounding if enabled)
        let now = Date()
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        let timeString = formatter.string(from: roundedTime)
        
        // Log if rounding occurred
        if shouldRound {
            let originalString = formatter.string(from: now)
            if originalString != timeString {
                print("⏱️ OFF time rounded: \(originalString) → \(timeString)")
            }
        }
        
        // FIXED: Use the new helper method to set OFF time properly through logpages
        trips[tripIndex].setOffTime(timeString, forLegAt: activeLegIndex)
        
        print("✅ Auto OFF: Set to \(timeString) for \(airport) at \(Int(speedKt)) kts")
        
        // Check if leg is now complete and should advance
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        
        // Save and sync
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    private func handleAutoOnTime(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let airport = userInfo["airport"] as? String,
              let speedKt = userInfo["speedKt"] as? Double else {
            print("⚠️ Auto ON: Missing notification data")
            return
        }
        
        // Find active or planning trip
        guard let activeTrip = trips.first(where: { $0.status == .active || $0.status == .planning }) else {
            print("⚠️ Auto ON: No active trip found")
            return
        }
        
        // Find the current leg index (looking for active leg)
        guard let tripIndex = trips.firstIndex(where: { $0.id == activeTrip.id }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ Auto ON: No active leg found in trip")
            return
        }
        
        // Check if ON time already set
        if !trips[tripIndex].legs[activeLegIndex].onTime.isEmpty {
            print("⚠️ Auto ON: Already set for this leg")
            return
        }
        
        // Format the current time as HHmm string (with rounding if enabled)
        let now = Date()
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        let timeString = formatter.string(from: roundedTime)
        
        // Log if rounding occurred
        if shouldRound {
            let originalString = formatter.string(from: now)
            if originalString != timeString {
                print("⏱️ ON time rounded: \(originalString) → \(timeString)")
            }
        }
        
        // FIXED: Use the new helper method to set ON time properly through logpages
        trips[tripIndex].setOnTime(timeString, forLegAt: activeLegIndex)
        
        print("✅ Auto ON: Set to \(timeString) for \(airport) at \(Int(speedKt)) kts")
        
        // Check if leg is now complete and should advance
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        
        // Save and sync
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    // MARK: - File Monitoring
    
    private func startFileMonitoring() {
        // Check for file changes every 5 seconds when app is active
        fileMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForFileChanges()
        }
    }
    
    private func stopFileMonitoring() {
        fileMonitorTimer?.invalidate()
        fileMonitorTimer = nil
    }
    
    private var lastFileModificationDate: Date?
    
    private func checkForFileChanges() {
        guard !isSaving else { return }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return
        }
        
        if lastFileModificationDate == nil {
            lastFileModificationDate = modificationDate
            return
        }
        
        if modificationDate > lastFileModificationDate! {
            print("Logbook file changed - reloading")
            lastFileModificationDate = modificationDate
            loadWithRecovery()
        }
    }

    // MARK: - Active Trip Validation
    
    /// Ensures only ONE trip can be active/planning at a time
    private func enforceOneActiveTrip() {
        let activePlanningTrips = trips.enumerated().filter {
            $0.element.status == .active || $0.element.status == .planning
        }
        
        guard activePlanningTrips.count > 1 else {
            // 0 or 1 active/planning trip is fine
            return
        }
        
        print("Found \(activePlanningTrips.count) active/planning trips - fixing...")
        
        // Find the most recent active/planning trip based on date
        let mostRecentActiveTrip = activePlanningTrips.max(by: {
            $0.element.date < $1.element.date
        })
        
        // Mark all others as completed
        for (index, trip) in trips.enumerated() {
            if (trip.status == .active || trip.status == .planning) {
                if index != mostRecentActiveTrip?.offset {
                    trips[index].status = .completed
                    print("Set trip #\(trip.tripNumber) to completed")
                } else {
                    print("Keeping trip #\(trip.tripNumber) as \(trip.status.rawValue)")
                }
            }
        }
        
        save()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedTrips = try JSONDecoder().decode([Trip].self, from: data)
            
            // Only update if the data actually changed to avoid unnecessary UI updates
            if loadedTrips != trips {
                print("Loaded \(loadedTrips.count) trips (changed from \(trips.count))")
                trips = loadedTrips
                
                // Enforce single active trip after loading
                enforceOneActiveTrip()
            }
        } catch {
            print("Failed to load: \(error)")
            trips = []
        }
    }

    func save() {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let data = try JSONEncoder().encode(trips)
            try data.write(to: fileURL)
            lastFileModificationDate = Date()
            lastSaveTime = Date() // Track when we saved
            print("Saved \(trips.count) trips")
        } catch {
            print("Failed to save logbook: \(error)")
        }
    }
    
    /// Save a specific trip locally and sync to CloudKit
    func saveTrip(_ trip: Trip) {
        // Find and update the trip in the array, or add it if new
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            updateTrip(trip, at: index)
        } else {
            addTrip(trip)
        }
        
        // Sync to CloudKit
        syncToCloud(trip: trip)
    }

    func addTrip(_ trip: Trip) {
        // When adding a new active/planning trip, complete all others first
        if trip.status == .active || trip.status == .planning {
            for index in trips.indices {
                if trips[index].status == .active || trips[index].status == .planning {
                    trips[index].status = .completed
                    print("Auto-completed trip #\(trips[index].tripNumber) when adding new trip")
                }
            }
        }
        
        trips.append(trip)
        
        // 🆕 PAYWALL: Increment trip count for trial limits
        Task { @MainActor in
            SubscriptionStatusChecker.shared.incrementTripCount()
        }
        
        save()
        
        // Sync to CloudKit
        syncToCloud(trip: trip)
    }

    func updateTrip(_ trip: Trip, at index: Int) {
        guard trips.indices.contains(index) else { return }
        
        // If updating trip to active/planning, complete all other active/planning trips
        if trip.status == .active || trip.status == .planning {
            for i in trips.indices where i != index {
                if trips[i].status == .active || trips[i].status == .planning {
                    trips[i].status = .completed
                    print("Auto-completed trip #\(trips[i].tripNumber) when updating trip #\(trip.tripNumber)")
                }
            }
        }
        
        trips[index] = trip
        save()
        
        // Sync to CloudKit
        syncToCloud(trip: trip)
    }

    func deleteTrip(at offsets: IndexSet) {
        print("🗑️ DELETE: Removing trips at indices: \(offsets)")
        print("🗑️ DELETE: Before deletion, have \(trips.count) trips")
        
        // Get trip IDs before deletion for CloudKit sync
        let tripIDsToDelete = offsets.map { trips[$0].id.uuidString }
        
        // ✅ NEW: Check if we're deleting the active trip
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
        
        trips.remove(atOffsets: offsets)
        
        print("🗑️ DELETE: After deletion, have \(trips.count) trips")
        print("🗑️ DELETE: Calling save()...")
        save()
        print("🗑️ DELETE: Save complete")
        
        // Delete from CloudKit
        for tripID in tripIDsToDelete {
            deleteFromCloud(tripID: tripID)
        }
    }
    
    // MARK: - Public Reload Method (for manual refresh)
    func reload() {
        print("Manual reload requested")
        loadWithRecovery()
    }
    
    // MARK: - Backup Compatibility
    func savePersistently() {
        // For backup system compatibility - calls the existing save method
        save()
    }
    
    // MARK: - FIXED: Leg Time Update Methods
    // These methods properly update leg times through the Trip's logpage structure
    
    /// Update OUT time for the active leg
    func setOutTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOutTimeForActiveLeg: No active trip/leg found")
            return
        }
        
        trips[tripIndex].setOutTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    /// Update OFF time for the active leg
    func setOffTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOffTimeForActiveLeg: No active trip/leg found")
            return
        }
        
        trips[tripIndex].setOffTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    /// Update ON time for the active leg
    func setOnTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setOnTimeForActiveLeg: No active trip/leg found")
            return
        }
        
        trips[tripIndex].setOnTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    /// Update IN time for the active leg
    func setInTimeForActiveLeg(_ time: String) {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }),
              let activeLegIndex = trips[tripIndex].activeLegIndex else {
            print("⚠️ setInTimeForActiveLeg: No active trip/leg found")
            return
        }
        
        trips[tripIndex].setInTime(time, forLegAt: activeLegIndex)
        trips[tripIndex].checkAndAdvanceLeg(at: activeLegIndex)
        save()
        syncToCloud(trip: trips[tripIndex])
    }
    
    /// Manually advance to the next leg (complete current and activate next)
    func advanceToNextLeg() {
        guard let tripIndex = trips.firstIndex(where: { $0.status == .active || $0.status == .planning }) else {
            print("⚠️ advanceToNextLeg: No active trip found")
            return
        }
        
        trips[tripIndex].completeActiveLeg(activateNext: true)
        save()
        syncToCloud(trip: trips[tripIndex])
        print("✅ Manually advanced to next leg")
    }
    
    // MARK: - JSON Import/Export Functions
    
    /// Export all trips to JSON data
    func exportToJSON() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let exportData = ExportData(
                trips: trips,
                perDiemRate: perDiemRate,
                exportDate: Date(),
                appVersion: "TheProPilotApp v1.3"
            )
            
            return try encoder.encode(exportData)
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }
    
    /// Import trips from JSON data
    @discardableResult
    func importFromJSON(_ data: Data, mergeWithExisting: Bool = true) -> JSONImportResult {
        let decoder = JSONDecoder()
        
        // Define backup wrapper structure (matches LogTenPro export format)
        struct BackupWrapper: Codable {
            let backupVersion: String?
            let backupDate: String?
            let trips: [Trip]
            // Other fields are optional - we only care about trips
        }
        
        // Try backup wrapper format first (LogTenPro export, ProPilot backup)
        decoder.dateDecodingStrategy = .iso8601
        if let backup = try? decoder.decode(BackupWrapper.self, from: data) {
            print("SUCCESS: Imported backup format with \(backup.trips.count) trips")
            return processImport(backup.trips, mergeWithExisting: mergeWithExisting)
        }
        
        // Try raw array with Core Foundation Absolute Time
        decoder.dateDecodingStrategy = .deferredToDate
        if let importedTrips = try? decoder.decode([Trip].self, from: data) {
            print("SUCCESS: Imported with Core Foundation Absolute Time")
            return processImport(importedTrips, mergeWithExisting: mergeWithExisting)
        }
        
        // Try backup wrapper with other date strategies
        let strategies: [JSONDecoder.DateDecodingStrategy] = [
            .deferredToDate,
            .secondsSince1970
        ]
        
        for strategy in strategies {
            decoder.dateDecodingStrategy = strategy
            if let backup = try? decoder.decode(BackupWrapper.self, from: data) {
                print("SUCCESS: Imported backup format with \(strategy)")
                return processImport(backup.trips, mergeWithExisting: mergeWithExisting)
            }
        }
        
        // Fall back to raw array with other strategies
        for strategy in strategies {
            decoder.dateDecodingStrategy = strategy
            if let importedTrips = try? decoder.decode([Trip].self, from: data) {
                print("SUCCESS: Imported raw array with \(strategy)")
                return processImport(importedTrips, mergeWithExisting: mergeWithExisting)
            }
        }
        
        return JSONImportResult(success: false, message: "Could not decode dates in any supported format", newTripsCount: 0)
    }
    
    private func processImport(_ importedTrips: [Trip], mergeWithExisting: Bool, perDiemRate: Double? = nil) -> JSONImportResult {
       let existingCount = trips.count
        
        if mergeWithExisting {
            // Merge with existing - avoid duplicates by ID and trip number
            let existingIDs = Set(trips.map { $0.id })
            let existingTripNumbers = Set(trips.map { "\($0.tripNumber)-\($0.date)" })
            
            print("🔍 IMPORT DEBUG:")
            print("  Existing trips: \(existingCount)")
            print("  Importing trips: \(importedTrips.count)")
            print("  Existing IDs: \(existingIDs.count)")
            
            var newTrips = importedTrips.filter { trip in
                !existingIDs.contains(trip.id) &&
                !existingTripNumbers.contains("\(trip.tripNumber)-\(trip.date)")
            }
            
            let duplicatesByID = importedTrips.filter { existingIDs.contains($0.id) }.count
            let duplicatesByTripNum = importedTrips.filter { trip in
                existingTripNumbers.contains("\(trip.tripNumber)-\(trip.date)")
            }.count
            
            print("  Duplicates by ID: \(duplicatesByID)")
            print("  Duplicates by trip#/date: \(duplicatesByTripNum)")
            print("  New unique trips: \(newTrips.count)")
            
            // 🔍 ENHANCED DEBUG: Compare leg data between existing and imported
            if newTrips.isEmpty && !importedTrips.isEmpty {
                print("\n🔍 NO NEW TRIPS - Comparing existing vs imported data quality...")
                
                // Sample first 3 trips to check leg data
                let sampleSize = min(3, importedTrips.count)
                for i in 0..<sampleSize {
                    let importedTrip = importedTrips[i]
                    if let existingTrip = trips.first(where: { $0.id == importedTrip.id }) {
                        print("\n  Trip #\(importedTrip.tripNumber):")
                        
                        // Compare leg counts
                        print("    Existing legs: \(existingTrip.legs.count), Imported legs: \(importedTrip.legs.count)")
                        
                        // Check first leg's scheduled data (if exists)
                        if let existingLeg = existingTrip.legs.first,
                           let importedLeg = importedTrip.legs.first {
                            let existingHasScheduled = existingLeg.scheduledOut != nil && existingLeg.scheduledIn != nil
                            let importedHasScheduled = importedLeg.scheduledOut != nil && importedLeg.scheduledIn != nil
                            print("    Existing has scheduled times: \(existingHasScheduled)")
                            print("    Imported has scheduled times: \(importedHasScheduled)")
                            
                            if !existingHasScheduled && importedHasScheduled {
                                print("    ⚠️ BACKUP HAS BETTER DATA - Consider force-replace import")
                            }
                        }
                    }
                }
            }
            
            // Set all imported trips to .completed to avoid conflicts
            for index in newTrips.indices {
                if newTrips[index].status == .active || newTrips[index].status == .planning {
                    newTrips[index].status = .completed
                    print("Set imported trip #\(newTrips[index].tripNumber) to completed")
                }
            }
            
            trips.append(contentsOf: newTrips)
            
            // Update per diem rate if provided
            if let newRate = perDiemRate {
                self.perDiemRate = newRate
            }
            
            save()
            enforceOneActiveTrip() // Double-check after import
            
            return JSONImportResult(
                success: true,
                message: "Imported \(newTrips.count) new trips. Total: \(trips.count)",
                newTripsCount: newTrips.count
            )
        } else {
            // Replace all trips
            trips = importedTrips
            
            if let newRate = perDiemRate {
                self.perDiemRate = newRate
            }
            
            save()
            enforceOneActiveTrip() // Ensure only one active after replacing all
            
            return JSONImportResult(
                success: true,
                message: "Replaced all trips. Total: \(trips.count)",
                newTripsCount: trips.count
            )
        }
    }
    
    /// Export single trip
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
    
    /// Quick export for sharing/backup
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
    
    // MARK: - CrewMember Migration Recovery
    
    func recoverDataWithCrewMemberMigration() -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else {
            print("No saved data found at: \(fileURL.path)")
            return false
        }
        
        print("Found saved data, attempting CrewMember migration...")
        
        // Define old structure without id/email
        struct OldCrewMember: Codable {
            var role: String
            var name: String
        }
        
        struct OldTrip: Codable {
            var id: UUID
            var tripNumber: String
            var aircraft: String
            var date: Date
            var crew: [OldCrewMember]
            var notes: String
            var tripType: TripType
            var deadheadAirline: String?
            var deadheadFlightNumber: String?
            var status: TripStatus
            var pilotRole: PilotRole
            var receiptCount: Int
            var logbookPageSent: Bool
            var perDiemStarted: Date?
            var perDiemEnded: Date?
            var logpages: [Logpage]
        }
        
        do {
            // Decode with old structure
            let decoder = JSONDecoder()
            let oldTrips = try decoder.decode([OldTrip].self, from: data)
            
            print("Successfully decoded \(oldTrips.count) trips with old CrewMember format")
            
            // Convert to new structure
            var newTrips: [Trip] = []
            for oldTrip in oldTrips {
                let newCrew = oldTrip.crew.map { oldMember in
                    CrewMember(
                        id: UUID(),
                        role: oldMember.role,
                        name: oldMember.name,
                        email: ""
                    )
                }
                
                var newTrip = Trip(
                    id: oldTrip.id,
                    tripNumber: oldTrip.tripNumber,
                    aircraft: oldTrip.aircraft,
                    date: oldTrip.date,
                    tatStart: oldTrip.logpages.first?.tatStart ?? "",
                    crew: newCrew,
                    notes: oldTrip.notes,
                    legs: oldTrip.logpages.flatMap { $0.legs },
                    tripType: oldTrip.tripType,
                    deadheadAirline: oldTrip.deadheadAirline,
                    deadheadFlightNumber: oldTrip.deadheadFlightNumber,
                    status: oldTrip.status,
                    pilotRole: oldTrip.pilotRole,
                    receiptCount: oldTrip.receiptCount,
                    logbookPageSent: oldTrip.logbookPageSent,
                    perDiemStarted: oldTrip.perDiemStarted,
                    perDiemEnded: oldTrip.perDiemEnded
                )
                newTrip.logpages = oldTrip.logpages
                newTrips.append(newTrip)
            }
            
            // Save with new structure
            self.trips = newTrips
            save()
            enforceOneActiveTrip()
            
            print("Successfully migrated \(newTrips.count) trips with crew member updates")
            return true
        } catch {
            print("CrewMember migration failed: \(error)")
            return false
        }
    }
    
}

// MARK: - Import/Export Data Structures

struct ExportData: Codable {
    let trips: [Trip]
    let perDiemRate: Double
    let exportDate: Date
    let appVersion: String
}

struct JSONImportResult {
    let success: Bool
    let message: String
    let newTripsCount: Int
}

// MARK: - Legacy Data Recovery

struct LegacyTrip: Codable {
    var id: UUID
    var tripNumber: String
    var aircraft: String
    var date: Date
    var tatStart: String
    var crew: [CrewMember]
    var notes: String
    var legs: [LegacyFlightLeg]
    var perDiemStarted: Date?
    var perDiemEnded: Date?
}

struct LegacyFlightLeg: Codable {
    var id: UUID
    var departure: String
    var arrival: String
    var outTime: String
    var offTime: String
    var onTime: String
    var inTime: String
}

extension LogBookStore {
    // MARK: - Data Recovery Function
    func attemptDataRecovery() -> Bool {
        // First try CrewMember migration
        if recoverDataWithCrewMemberMigration() {
            return true
        }
        
        // Fall back to legacy recovery
        let fileURL = self.fileURL
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("Found logbook file with \(data.count) bytes")
            
            if let legacyTrips = try? JSONDecoder().decode([LegacyTrip].self, from: data) {
                print("Successfully decoded \(legacyTrips.count) legacy trips")
                
                var convertedTrips: [Trip] = []
                
                for legacyTrip in legacyTrips {
                    let convertedLegs = legacyTrip.legs.map { legacyLeg in
                        FlightLeg(
                            id: legacyLeg.id,
                            departure: legacyLeg.departure,
                            arrival: legacyLeg.arrival,
                            outTime: legacyLeg.outTime,
                            offTime: legacyLeg.offTime,
                            onTime: legacyLeg.onTime,
                            inTime: legacyLeg.inTime,
                            isDeadhead: false,
                            deadheadFlightHours: 0.0
                        )
                    }
                    
                    let convertedTrip = Trip(
                        id: legacyTrip.id,
                        tripNumber: legacyTrip.tripNumber,
                        aircraft: legacyTrip.aircraft,
                        date: legacyTrip.date,
                        tatStart: legacyTrip.tatStart,
                        crew: legacyTrip.crew,
                        notes: legacyTrip.notes,
                        legs: convertedLegs,
                        tripType: .operating,
                        deadheadAirline: "",
                        deadheadFlightNumber: "",
                        perDiemStarted: legacyTrip.perDiemStarted,
                        perDiemEnded: legacyTrip.perDiemEnded
                    )
                    
                    convertedTrips.append(convertedTrip)
                }
                
                self.trips = convertedTrips
                save()
                enforceOneActiveTrip()
                
                print("Successfully recovered and converted \(convertedTrips.count) trips")
                return true
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("File contents preview: \(String(jsonString.prefix(200)))...")
                
                if jsonString.contains("tripNumber") && jsonString.contains("aircraft") {
                    print("File contains trip data but format has changed")
                    print("You may need manual recovery")
                    return false
                }
            }
            
        } catch {
            print("Error reading file: \(error)")
            return false
        }
        
        return false
    }
    
    func loadWithRecovery() {
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedTrips = try JSONDecoder().decode([Trip].self, from: data)

            // Only update if changed
            if loadedTrips != trips {
                trips = loadedTrips
                print("Loaded \(trips.count) trips successfully")
                enforceOneActiveTrip()

                // Auto-repair trips with missing leg times
                repairMissingLegTimes()
            }
        } catch {
            print("Failed to load new format, attempting recovery...")

            if attemptDataRecovery() {
                print("Data recovery successful")
            } else {
                print("Could not recover data. Starting fresh.")
                trips = []
            }
        }
    }

    // MARK: - Leg Time Repair Migration

    /// Repairs trips that have scheduledOut/scheduledIn but are missing outTime/inTime
    /// This can happen when trips were created before the prePopulateScheduledTimes feature,
    /// or if the setting was temporarily disabled
    func repairMissingLegTimes() {
        var repairCount = 0
        var legsMissingTimes = 0
        var legsMissingScheduled = 0
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")

        for tripIndex in trips.indices {
            var tripModified = false

            for legIndex in trips[tripIndex].legs.indices {
                let leg = trips[tripIndex].legs[legIndex]

                // Skip deadheads - they have different time fields
                guard !leg.isDeadhead else { continue }

                // Track diagnostics
                let missingOut = leg.outTime.isEmpty
                let missingIn = leg.inTime.isEmpty
                let hasScheduledOut = leg.scheduledOut != nil
                let hasScheduledIn = leg.scheduledIn != nil

                if missingOut || missingIn {
                    legsMissingTimes += 1
                }
                if !hasScheduledOut && !hasScheduledIn && (missingOut || missingIn) {
                    legsMissingScheduled += 1
                }

                // Check if outTime is missing but scheduledOut exists
                if leg.outTime.isEmpty, let scheduledOut = leg.scheduledOut {
                    trips[tripIndex].legs[legIndex].outTime = formatter.string(from: scheduledOut)
                    tripModified = true
                    repairCount += 1
                }

                // Check if inTime is missing but scheduledIn exists
                if leg.inTime.isEmpty, let scheduledIn = leg.scheduledIn {
                    trips[tripIndex].legs[legIndex].inTime = formatter.string(from: scheduledIn)
                    tripModified = true
                    repairCount += 1
                }
            }

            if tripModified {
                print("🔧 Repaired leg times for trip \(trips[tripIndex].tripNumber)")
            }
        }

        // Always print diagnostics
        print("📊 Leg time repair scan: \(trips.count) trips")
        print("   - Legs missing out/in times: \(legsMissingTimes)")
        print("   - Legs missing scheduled times (can't repair): \(legsMissingScheduled)")
        print("   - Repairs made: \(repairCount)")

        if repairCount > 0 {
            print("✅ Repaired \(repairCount) missing leg time(s) across all trips")
            save()
        }
    }

    /// Manual repair function that can be called from settings/debug menu
    /// Returns count of repairs made
    @discardableResult
    func manualRepairMissingLegTimes() -> Int {
        var repairCount = 0
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")

        for tripIndex in trips.indices {
            for legIndex in trips[tripIndex].legs.indices {
                let leg = trips[tripIndex].legs[legIndex]

                guard !leg.isDeadhead else { continue }

                if leg.outTime.isEmpty, let scheduledOut = leg.scheduledOut {
                    trips[tripIndex].legs[legIndex].outTime = formatter.string(from: scheduledOut)
                    repairCount += 1
                }

                if leg.inTime.isEmpty, let scheduledIn = leg.scheduledIn {
                    trips[tripIndex].legs[legIndex].inTime = formatter.string(from: scheduledIn)
                    repairCount += 1
                }
            }
        }

        if repairCount > 0 {
            save()
        }

        return repairCount
    }
}

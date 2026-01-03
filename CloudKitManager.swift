//
//  CloudKitManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/16/25.
//

import SwiftUI
import CloudKit

// MARK: - CloudKit Manager
// 🔥 FIX: Removed @MainActor - CloudKit operations should run on background thread
// Only UI updates need to be on main thread
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.jkadans.TheProPilotApp")
    private let privateDB: CKDatabase
    
    @Published var iCloudAvailable = false
    @Published var syncStatus = "Not synced"
    @Published var lastSyncTime: Date?
    
    init() {
        self.privateDB = container.privateCloudDatabase
        Task {
            await checkiCloudStatus()
        }
    }
    
    // MARK: - Check iCloud Status
    func checkiCloudStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            
            // 🔥 FIX: Update UI properties on main thread
            await MainActor.run {
                switch status {
                case .available:
                    self.iCloudAvailable = true
                    self.syncStatus = "✅ iCloud available"
                case .noAccount:
                    self.iCloudAvailable = false
                    self.syncStatus = "❌ No iCloud account"
                case .restricted:
                    self.iCloudAvailable = false
                    self.syncStatus = "⚠️ iCloud restricted"
                case .couldNotDetermine:
                    self.iCloudAvailable = false
                    self.syncStatus = "⚠️ iCloud status unknown"
                case .temporarilyUnavailable:
                    self.iCloudAvailable = false
                    self.syncStatus = "⚠️ iCloud temporarily unavailable"
                @unknown default:
                    self.iCloudAvailable = false
                    self.syncStatus = "⚠️ Unknown iCloud status"
                }
            }
        } catch {
            await MainActor.run {
                self.iCloudAvailable = false
                self.syncStatus = "❌ Error checking iCloud"
            }
        }
    }
    
    // MARK: - Debug CloudKit Contents
    func debugCloudKitContents() {
        print("🔍 DEBUG: Checking CloudKit contents...")
        print("🔍 Container ID: \(container.containerIdentifier ?? "unknown")")
        
        Task {
            do {
                // Query ALL Trip records
                let query = CKQuery(recordType: "Trip", predicate: NSPredicate(value: true))
                
                let (matchResults, _) = try await privateDB.records(matching: query)
                let records = matchResults.compactMap { try? $0.1.get() }
                
                print("🔍 Found \(records.count) Trip records in CloudKit")
                
                // Show first 5 trips
                for (index, record) in records.prefix(5).enumerated() {
                    print("  📦 Record \(index + 1):")
                    print("     RecordID: \(record.recordID.recordName)")
                    print("     Trip#: \(record["tripNumber"] ?? "nil")")
                    print("     Zone: \(record.recordID.zoneID.zoneName)")
                    print("     Aircraft: \(record["aircraft"] ?? "nil")")
                }
                
                // Check what zones exist
                let zones = try await privateDB.allRecordZones()
                print("🔍 Available zones: \(zones.map { $0.zoneID.zoneName })")
                
            } catch {
                print("❌ DEBUG Query error: \(error)")
                if let ckError = error as? CKError {
                    print("❌ CKError code: \(ckError.code.rawValue)")
                    print("❌ Error description: \(ckError.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Test CloudKit Airport Database
    func testCloudKitAirportDatabase() async {
        print("🧪 Testing CloudKit Airport Database...")
        
        let publicDB = container.publicCloudDatabase
        
        do {
            let predicate = NSPredicate(format: "code == %@", "KYIP")
            let query = CKQuery(recordType: "Airport", predicate: predicate)
            
            let (matchResults, _) = try await publicDB.records(matching: query)
            
            if matchResults.isEmpty {
                print("❌ NO DATA - Check Development vs Production!")
                print("   Make sure airports are uploaded to the correct environment")
            } else {
                print("✅ FOUND DATA - CloudKit working!")
                for (_, result) in matchResults {
                    if case .success(let record) = result {
                        print("   Name: \(record["name"] as? String ?? "?")")
                        print("   Runway: \(record["longestRunway"] as? Int ?? 0) ft")
                        print("   Frequencies: \(record["frequencies"] as? String ?? "?")")
                    }
                }
            }
        } catch {
            print("❌ ERROR: \(error)")
            if let ckError = error as? CKError {
                print("   CKError code: \(ckError.code.rawValue)")
                print("   Description: \(ckError.localizedDescription)")
            }
        }
    }
    
    // MARK: - Save Trip to CloudKit (DEPRECATED)
    /// ⚠️ LEGACY: This method saves to the OLD CloudKit record type "Trip".
    /// SwiftData now handles sync automatically to "CD_SDTrip" records.
    /// Only use for legacy sync compatibility.
    /// Use SwiftDataLogBookStore.saveTrip() instead for proper CloudKit sync.
    func saveTrip(_ trip: Trip) async throws {
        print("🚨 DEPRECATED: CloudKitManager.saveTrip() called!")
        print("   ⚠️ This saves to OLD 'Trip' record type, NOT SwiftData's 'CD_SDTrip'")
        print("   ⚠️ Data saved here will NOT sync with SwiftData!")
        print("   ➡️ Use SwiftDataLogBookStore.saveTrip() instead")
        print("🔵 saveTrip() called for: \(trip.tripNumber) (ID: \(trip.id.uuidString))")

        guard iCloudAvailable else {
            print("⚠️ iCloud not available - skipping CloudKit save")
            return
        }
        
        print("🔵 iCloud is available, proceeding with save to container: \(container.containerIdentifier ?? "unknown")")
        
        // Try to fetch existing record first
        let recordID = CKRecord.ID(recordName: trip.id.uuidString)
        
        var tripRecord: CKRecord
        do {
            tripRecord = try await privateDB.record(for: recordID)
            print("📝 Found existing record, will update")
        } catch {
            tripRecord = CKRecord(recordType: "Trip", recordID: recordID)
            print("✨ No existing record, creating new")
        }
        
        // Set all trip fields
        tripRecord["tripNumber"] = trip.tripNumber as NSString
        tripRecord["date"] = trip.date as NSDate
        tripRecord["aircraft"] = trip.aircraft as NSString
        tripRecord["tatStart"] = trip.tatStart as NSString
        tripRecord["notes"] = trip.notes as NSString
        tripRecord["tripType"] = trip.tripType.rawValue as NSString
        tripRecord["pilotRole"] = trip.pilotRole.rawValue as NSString
        tripRecord["status"] = trip.status.rawValue as NSString
        tripRecord["receiptCount"] = trip.receiptCount as NSNumber
        tripRecord["logbookPageSent"] = (trip.logbookPageSent ? 1 : 0) as NSNumber
        
        if trip.tripType == .deadhead {
            tripRecord["deadheadAirline"] = (trip.deadheadAirline ?? "") as NSString
            tripRecord["deadheadFlightNumber"] = (trip.deadheadFlightNumber ?? "") as NSString
        }
        
        if let simulatorMinutes = trip.simulatorMinutes {
            tripRecord["simulatorMinutes"] = simulatorMinutes as NSNumber
        }
        
        print("🔵 Saving trip record to CloudKit...")
        
        do {
            let savedRecord = try await privateDB.save(tripRecord)
            print("✅ SUCCESS! Trip saved: \(trip.tripNumber)")
            print("✅ RecordID: \(savedRecord.recordID.recordName)")
            
            // Clean up old associated records
            try await deleteAssociatedRecords(for: trip.id.uuidString)
            
            // Save legs
            print("🔵 Saving \(trip.legs.count) legs...")
            for (index, leg) in trip.legs.enumerated() {
                try await saveFlightLeg(leg, tripID: trip.id.uuidString, order: index)
            }
            
            // Save crew
            print("🔵 Saving \(trip.crew.count) crew...")
            for (index, crew) in trip.crew.enumerated() {
                try await saveCrewMember(crew, tripID: trip.id.uuidString, order: index)
            }
            
            // 🔥 FIX: Update UI properties on main thread
            await MainActor.run {
                self.syncStatus = "✅ Synced"
                self.lastSyncTime = Date()
            }
            
            print("✅ COMPLETE! All data saved for trip \(trip.tripNumber)")
        } catch {
            print("❌ CloudKit save FAILED!")
            print("❌ Error: \(error)")
            if let ckError = error as? CKError {
                print("❌ CKError code: \(ckError.code.rawValue)")
            }
            throw error
        }
    }
    
    // MARK: - Delete Associated Records
    private func deleteAssociatedRecords(for tripID: String) async throws {
        // Delete old legs
        let legPredicate = NSPredicate(format: "tripID == %@", tripID)
        let legQuery = CKQuery(recordType: "FlightLeg", predicate: legPredicate)
        
        do {
            let (matchResults, _) = try await privateDB.records(matching: legQuery)
            var deletedCount = 0
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    do {
                        try await privateDB.deleteRecord(withID: record.recordID)
                        deletedCount += 1
                    } catch {
                        print("⚠️ Failed to delete leg: \(error)")
                    }
                }
            }
            print("  🗑️ Deleted \(deletedCount) old leg records")
        } catch {
            print("⚠️ Error querying old legs: \(error)")
        }
        
        // Delete old crew
        let crewPredicate = NSPredicate(format: "tripID == %@", tripID)
        let crewQuery = CKQuery(recordType: "CrewMember", predicate: crewPredicate)
        
        do {
            let (matchResults, _) = try await privateDB.records(matching: crewQuery)
            var deletedCount = 0
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    do {
                        try await privateDB.deleteRecord(withID: record.recordID)
                        deletedCount += 1
                    } catch {
                        print("⚠️ Failed to delete crew: \(error)")
                    }
                }
            }
            print("  🗑️ Deleted \(deletedCount) old crew records")
        } catch {
            print("⚠️ Error querying old crew: \(error)")
        }
    }
    
    // MARK: - Save FlightLeg
    private func saveFlightLeg(_ leg: FlightLeg, tripID: String, order: Int) async throws {
        let recordID = CKRecord.ID(recordName: "\(tripID)_leg_\(order)")
        
        var legRecord: CKRecord
        do {
            legRecord = try await privateDB.record(for: recordID)
        } catch {
            legRecord = CKRecord(recordType: "FlightLeg", recordID: recordID)
        }
        
        legRecord["tripID"] = tripID as NSString
        legRecord["order"] = order as NSNumber
        legRecord["departure"] = leg.departure as NSString
        legRecord["arrival"] = leg.arrival as NSString
        legRecord["outTime"] = leg.outTime as NSString
        legRecord["offTime"] = leg.offTime as NSString
        legRecord["onTime"] = leg.onTime as NSString
        legRecord["inTime"] = leg.inTime as NSString
        legRecord["flightNumber"] = leg.flightNumber as NSString
        legRecord["isDeadhead"] = (leg.isDeadhead ? 1 : 0) as NSNumber
        
        // Flight date for accurate 30-day rolling calculations
        if let flightDate = leg.flightDate {
            legRecord["flightDate"] = flightDate as NSDate
        }
        
        // Leg status
        legRecord["status"] = leg.status.rawValue as NSString
        
        // Deadhead-specific fields
        legRecord["deadheadOutTime"] = leg.deadheadOutTime as NSString
        legRecord["deadheadInTime"] = leg.deadheadInTime as NSString
        legRecord["deadheadFlightHours"] = leg.deadheadFlightHours as NSNumber
        
        // Scheduled times (from roster)
        if let scheduledOut = leg.scheduledOut {
            legRecord["scheduledOut"] = scheduledOut as NSDate
        }
        if let scheduledIn = leg.scheduledIn {
            legRecord["scheduledIn"] = scheduledIn as NSDate
        }
        
        // Pilot role for this leg (PF/PM)
        legRecord["legPilotRole"] = leg.legPilotRole.rawValue as NSString
        
        // Night operations tracking
        legRecord["nightTakeoff"] = (leg.nightTakeoff ? 1 : 0) as NSNumber
        legRecord["nightLanding"] = (leg.nightLanding ? 1 : 0) as NSNumber
        
        // Debug: Log deadhead values
        if leg.isDeadhead {
            print("  🔵 DEADHEAD LEG - OUT: '\(leg.deadheadOutTime)' IN: '\(leg.deadheadInTime)' Hours: \(leg.deadheadFlightHours)")
        }
        
        // Debug: Log flight date if different from nil
        if let flightDate = leg.flightDate {
            print("  📅 Leg flightDate: \(flightDate.formatted(date: .abbreviated, time: .omitted))")
        }
        
        try await privateDB.save(legRecord)
        print("  ✅ Leg saved: \(leg.departure)-\(leg.arrival)")
    }
    
    // MARK: - Save CrewMember
    private func saveCrewMember(_ crew: CrewMember, tripID: String, order: Int) async throws {
        let recordID = CKRecord.ID(recordName: "\(tripID)_crew_\(order)")
        
        var crewRecord: CKRecord
        do {
            crewRecord = try await privateDB.record(for: recordID)
        } catch {
            crewRecord = CKRecord(recordType: "CrewMember", recordID: recordID)
        }
        
        crewRecord["tripID"] = tripID as NSString
        crewRecord["order"] = order as NSNumber
        crewRecord["name"] = crew.name as NSString
        crewRecord["role"] = crew.role as NSString
        crewRecord["email"] = crew.email as NSString
        
        try await privateDB.save(crewRecord)
        print("  ✅ Crew saved: \(crew.role) - \(crew.name)")
    }
    
    // MARK: - Fetch All Trips (Legacy)
    /// ⚠️ LEGACY: This fetches from OLD "Trip" record type, NOT SwiftData's "CD_SDTrip".
    /// Use this ONLY for migrating legacy data from old CloudKit records to SwiftData.
    /// For normal operations, use SwiftDataLogBookStore.loadTrips() instead.
    func fetchAllTrips() async throws -> [Trip] {
        print("⚠️ DEPRECATED: CloudKitManager.fetchAllTrips() - reads OLD 'Trip' records")
        print("   ➡️ For normal use: SwiftDataLogBookStore.loadTrips()")
        print("   ➡️ This method is for LEGACY DATA MIGRATION only")

        guard iCloudAvailable else {
            return []
        }

        let query = CKQuery(recordType: "Trip", predicate: NSPredicate(value: true))
        
        let (matchResults, _) = try await privateDB.records(matching: query)
        let tripRecords = matchResults.compactMap { try? $0.1.get() }
        var trips: [Trip] = []
        
        print("📥 Downloading \(tripRecords.count) trips from CloudKit...")
        
        for record in tripRecords {
            let tripID = record.recordID.recordName
            let legs = try await fetchFlightLegs(for: tripID)
            let crew = try await fetchCrewMembers(for: tripID)
            
            let tripType = TripType(rawValue: record["tripType"] as? String ?? "operating") ?? .operating
            let pilotRole = PilotRole(rawValue: record["pilotRole"] as? String ?? "captain") ?? .captain
            let status = TripStatus(rawValue: record["status"] as? String ?? "completed") ?? .completed
            let receiptCount = (record["receiptCount"] as? Int64).map(Int.init) ?? 0
            let logbookPageSent = ((record["logbookPageSent"] as? Int64) ?? 0) != 0
            let simulatorMinutes = (record["simulatorMinutes"] as? Int64).map(Int.init)
            
            var trip = Trip(
                id: UUID(uuidString: tripID) ?? UUID(),
                tripNumber: record["tripNumber"] as? String ?? "",
                aircraft: record["aircraft"] as? String ?? "",
                date: record["date"] as? Date ?? Date(),
                tatStart: record["tatStart"] as? String ?? "",
                crew: crew,
                notes: record["notes"] as? String ?? "",
                legs: legs,
                tripType: tripType,
                deadheadAirline: record["deadheadAirline"] as? String,
                deadheadFlightNumber: record["deadheadFlightNumber"] as? String,
                status: status,
                pilotRole: pilotRole,
                receiptCount: receiptCount,
                logbookPageSent: logbookPageSent
            )
            
            trip.simulatorMinutes = simulatorMinutes
            trips.append(trip)
        }
        
        // ✅ Sort trips by date (newest first)
        trips.sort { $0.date > $1.date }

        // Capture the final value for MainActor (Swift 6 concurrency fix)
        let tripCount = trips.count

        print("✅ Downloaded \(tripCount) trips from CloudKit")

        // 🔥 FIX: Update UI properties on main thread
        await MainActor.run {
            self.syncStatus = "✅ Synced \(tripCount) trips"
            self.lastSyncTime = Date()
        }

        return trips
    }
    
    // MARK: - Fetch FlightLegs
    private func fetchFlightLegs(for tripID: String) async throws -> [FlightLeg] {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "FlightLeg", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        let (matchResults, _) = try await privateDB.records(matching: query)
        let records = matchResults.compactMap { try? $0.1.get() }
        
        return records.map { record in
            let legID = UUID(uuidString: record.recordID.recordName) ?? UUID()
            
            // Parse leg status (defaults to .active for backward compatibility)
            let statusRaw = record["status"] as? String ?? "Active"
            let status = LegStatus(rawValue: statusRaw) ?? .active
            
            // Parse leg pilot role
            let roleRaw = record["legPilotRole"] as? String ?? "Not Set"
            let legPilotRole = LegPilotRole(rawValue: roleRaw) ?? .notSet
            
            // Build leg with all CloudKit fields
            var leg = FlightLeg()
            leg.id = legID
            leg.departure = record["departure"] as? String ?? ""
            leg.arrival = record["arrival"] as? String ?? ""
            leg.outTime = record["outTime"] as? String ?? ""
            leg.offTime = record["offTime"] as? String ?? ""
            leg.onTime = record["onTime"] as? String ?? ""
            leg.inTime = record["inTime"] as? String ?? ""
            leg.flightNumber = record["flightNumber"] as? String ?? ""
            leg.isDeadhead = (record["isDeadhead"] as? Int ?? 0) == 1
            leg.flightDate = record["flightDate"] as? Date  // ✅ Per-leg flight date for 30-day calculations
            leg.status = status
            leg.scheduledOut = record["scheduledOut"] as? Date
            leg.scheduledIn = record["scheduledIn"] as? Date
            leg.scheduledFlightNumber = record["scheduledFlightNumber"] as? String
            leg.rosterSourceId = record["rosterSourceId"] as? String
            leg.deadheadOutTime = record["deadheadOutTime"] as? String ?? ""
            leg.deadheadInTime = record["deadheadInTime"] as? String ?? ""
            leg.deadheadFlightHours = record["deadheadFlightHours"] as? Double ?? 0.0
            leg.legPilotRole = legPilotRole
            leg.nightTakeoff = (record["nightTakeoff"] as? Int ?? 0) == 1
            leg.nightLanding = (record["nightLanding"] as? Int ?? 0) == 1
            
            return leg
        }
    }
    
    // MARK: - Fetch CrewMembers
    private func fetchCrewMembers(for tripID: String) async throws -> [CrewMember] {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "CrewMember", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        let (matchResults, _) = try await privateDB.records(matching: query)
        let records = matchResults.compactMap { try? $0.1.get() }
        
        return records.map { record in
            CrewMember(
                role: record["role"] as? String ?? "",
                name: record["name"] as? String ?? "",
                email: record["email"] as? String ?? ""
            )
        }
    }
    
    // MARK: - Delete Trip
    func deleteTrip(tripID: String) async throws {
        guard iCloudAvailable else { return }
        
        let tripRecordID = CKRecord.ID(recordName: tripID)
        try await privateDB.deleteRecord(withID: tripRecordID)
        
        try await deleteAssociatedRecords(for: tripID)
        
        print("✅ Trip deleted from CloudKit: \(tripID)")
    }
    
    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: Flight Track Sync (KML/GPX GPS Data)
    // MARK: ═══════════════════════════════════════════════════════════════
    
    /// Save a flight track to iCloud (private sync across user's devices)
    func saveFlightTrack(legId: UUID, trackData: Data) async throws {
        guard iCloudAvailable else {
            print("⚠️ iCloud not available, skipping flight track sync")
            return
        }
        
        print("📤 Uploading flight track for leg: \(legId.uuidString)")
        
        let recordID = CKRecord.ID(recordName: "track_\(legId.uuidString)")
        
        var trackRecord: CKRecord
        do {
            trackRecord = try await privateDB.record(for: recordID)
            print("📝 Found existing track record, will update")
        } catch {
            trackRecord = CKRecord(recordType: "FlightTrack", recordID: recordID)
            print("✨ Creating new track record")
        }
        
        // Store metadata
        trackRecord["legID"] = legId.uuidString as NSString
        trackRecord["uploadDate"] = Date() as NSDate
        trackRecord["dataSize"] = trackData.count as NSNumber
        
        // Store track data as CKAsset (efficient for large files)
        // This automatically handles compression and chunking
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("track_\(legId.uuidString).json")
        
        do {
            try trackData.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            trackRecord["trackData"] = asset
            
            // Upload to iCloud
            let savedRecord = try await privateDB.save(trackRecord)
            print("✅ Flight track uploaded: \(legId.uuidString) (\(trackData.count) bytes)")
            
            // Cleanup temp file
            try? FileManager.default.removeItem(at: tempURL)
            
        } catch {
            print("❌ Failed to upload flight track: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
    
    /// Fetch a flight track from iCloud
    func fetchFlightTrack(legId: UUID) async throws -> Data? {
        guard iCloudAvailable else {
            print("⚠️ iCloud not available")
            return nil
        }
        
        let recordID = CKRecord.ID(recordName: "track_\(legId.uuidString)")
        
        do {
            let record = try await privateDB.record(for: recordID)
            
            guard let asset = record["trackData"] as? CKAsset,
                  let fileURL = asset.fileURL else {
                print("⚠️ No track data found in record")
                return nil
            }
            
            let data = try Data(contentsOf: fileURL)
            print("✅ Flight track downloaded: \(legId.uuidString) (\(data.count) bytes)")
            return data
            
        } catch let error as CKError where error.code == .unknownItem {
            print("ℹ️ No flight track found for leg: \(legId.uuidString)")
            return nil
        } catch {
            print("❌ Failed to fetch flight track: \(error)")
            throw error
        }
    }
    
    /// Delete a flight track from iCloud
    func deleteFlightTrack(legId: UUID) async throws {
        guard iCloudAvailable else { return }
        
        let recordID = CKRecord.ID(recordName: "track_\(legId.uuidString)")
        
        do {
            try await privateDB.deleteRecord(withID: recordID)
            print("✅ Flight track deleted from iCloud: \(legId.uuidString)")
        } catch let error as CKError where error.code == .unknownItem {
            // Already deleted or never existed
            print("ℹ️ Flight track not found in iCloud (already deleted): \(legId.uuidString)")
        } catch {
            print("❌ Failed to delete flight track: \(error)")
            throw error
        }
    }
    
    /// Fetch all flight tracks for a trip (for bulk sync)
    func fetchFlightTracksForTrip(legIds: [UUID]) async throws -> [UUID: Data] {
        guard iCloudAvailable else { return [:] }
        
        var tracks: [UUID: Data] = [:]
        
        print("📥 Downloading \(legIds.count) flight tracks...")
        
        for legId in legIds {
            if let data = try await fetchFlightTrack(legId: legId) {
                tracks[legId] = data
            }
        }
        
        print("✅ Downloaded \(tracks.count)/\(legIds.count) flight tracks")
        return tracks
    }
    
    /// Check if a flight track exists in iCloud (without downloading it)
    func flightTrackExists(legId: UUID) async -> Bool {
        guard iCloudAvailable else { return false }
        
        let recordID = CKRecord.ID(recordName: "track_\(legId.uuidString)")
        
        do {
            _ = try await privateDB.record(for: recordID)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - LogBookStore Extension
extension LogBookStore {
    @MainActor
    func syncFromCloud() async {
        guard CloudKitManager.shared.iCloudAvailable else {
            return
        }
        
        do {
            let cloudTrips = try await CloudKitManager.shared.fetchAllTrips()
            
            // Take a snapshot of current trips on the main actor to avoid capturing across awaits
            let currentTrips = self.trips
            
            // Enable verbose logging while debugging
            let verboseLogging = true
            
            var mergedTrips: [Trip] = []
            var processedIDs = Set<UUID>()
            
            // Merge cloud trips with local snapshot
            for cloudTrip in cloudTrips {
                if let localIndex = currentTrips.firstIndex(where: { $0.id == cloudTrip.id }) {
                    let localTrip = currentTrips[localIndex]

                    // Count how many legs have COMPLETE flight data (all 4 times: OUT, OFF, ON, IN)
                    let localCompleteLegs = localTrip.legs.filter { leg in
                        !leg.departure.isEmpty && !leg.arrival.isEmpty &&
                        !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
                        !leg.onTime.isEmpty && !leg.inTime.isEmpty
                    }.count

                    let cloudCompleteLegs = cloudTrip.legs.filter { leg in
                        !leg.departure.isEmpty && !leg.arrival.isEmpty &&
                        !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
                        !leg.onTime.isEmpty && !leg.inTime.isEmpty
                    }.count
                    
                    // Choose version with MORE complete flight data
                    let useLocal: Bool
                    if localCompleteLegs > cloudCompleteLegs {
                        useLocal = true
                        if verboseLogging {
                            print("✅ KEEPING LOCAL (more data) - Trip \(localTrip.tripNumber) - Local: \(localCompleteLegs) legs, Cloud: \(cloudCompleteLegs) legs")
                        }
                    } else if cloudCompleteLegs > localCompleteLegs {
                        useLocal = false
                        if verboseLogging {
                            print("📥 USING CLOUD (more data) - Trip \(cloudTrip.tripNumber) - Local: \(localCompleteLegs) legs, Cloud: \(cloudCompleteLegs) legs")
                        }
                    } else {
                        useLocal = true
                        if verboseLogging {
                            print("📱 KEEPING LOCAL (equal/default) - Trip \(localTrip.tripNumber) - Complete legs: \(localCompleteLegs)")
                        }
                    }
                    
                    mergedTrips.append(useLocal ? localTrip : cloudTrip)
                    processedIDs.insert(cloudTrip.id)
                } else {
                    // Trip only exists in cloud, add it
                    if verboseLogging {
                        print("✅ Adding new trip from cloud: \(cloudTrip.tripNumber)")
                    }
                    mergedTrips.append(cloudTrip)
                    processedIDs.insert(cloudTrip.id)
                }
            }
            
            // Add local-only trips (haven't been uploaded yet)
            var localOnlyCount = 0
            for localTrip in currentTrips {
                if !processedIDs.contains(localTrip.id) {
                    if verboseLogging {
                        print("✅ Keeping local-only trip: \(localTrip.tripNumber)")
                    }
                    mergedTrips.append(localTrip)
                    localOnlyCount += 1
                }
            }
            
            // Sort by date (most recent first)
            mergedTrips.sort { $0.date > $1.date }
            
            // Assign back on the main actor and save
            await MainActor.run {
                self.trips = mergedTrips
                self.save()
            }
            
            // Cleaner logging
            print("✅ Synced \(mergedTrips.count) trips from CloudKit (SAFE merge - protecting local data with complete legs)")
            if localOnlyCount > 0 {
                print("   📱 Including \(localOnlyCount) local-only trips")
            }
        } catch {
            print("❌ Sync error: \(error)")
        }
    }
    
    func syncToCloud(trip: Trip) {
        Task {
            do {
                try await CloudKitManager.shared.saveTrip(trip)
            } catch {
                print("❌ Failed to sync trip: \(error)")
            }
        }
    }
    
    func deleteFromCloud(tripID: String) {
        Task {
            do {
                try await CloudKitManager.shared.deleteTrip(tripID: tripID)
            } catch {
                print("❌ Failed to delete trip: \(error)")
            }
        }
    }
}


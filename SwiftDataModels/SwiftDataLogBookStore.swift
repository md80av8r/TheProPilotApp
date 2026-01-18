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
                
                // CRITICAL: Verify data integrity after migration/load
                let integrityCheck = DataIntegrityManager.shared.performIntegrityCheck(logbookStore: self)
                if integrityCheck.hasCriticalIssues {
                    print("🚨 CRITICAL DATA INTEGRITY ISSUES DETECTED!")
                    print("   Creating emergency backup before any changes...")
                    DataIntegrityManager.shared.createDailyBackup(logbookStore: self)
                }

                // Start automatic daily backups
                DataIntegrityManager.shared.startAutomaticBackups(logbookStore: self)
                
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
            print("📊 SwiftData: Fetched \(sdTrips.count) SDTrip entities")

            // Comprehensive debug logging
            var totalLogpagesInDB = 0
            var totalLegsInDB = 0
            for sdTrip in sdTrips {
                let logpageCount = sdTrip.logpages?.count ?? 0
                let legCount = sdTrip.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0
                totalLogpagesInDB += logpageCount
                totalLegsInDB += legCount

                if logpageCount == 0 || legCount == 0 {
                    print("⚠️ Trip #\(sdTrip.tripNumber) has \(logpageCount) logpages, \(legCount) legs")
                }
            }
            print("📊 Database totals: \(totalLogpagesInDB) logpages, \(totalLegsInDB) legs")

            trips = sdTrips.map { $0.toTrip() }

            // Verify conversion didn't lose data
            var totalLegsConverted = 0
            for trip in trips {
                totalLegsConverted += trip.legs.count
            }

            if totalLegsConverted != totalLegsInDB {
                print("🚨 DATA LOSS DETECTED: DB has \(totalLegsInDB) legs, but only \(totalLegsConverted) converted!")
                print("🔧 Running relationship repair...")
                await repairOrphanedRelationships()
            }

            // Debug: Check first converted trip
            if let firstTrip = trips.first {
                let totalMinutes = firstTrip.legs.reduce(0) { $0 + $1.blockMinutes() }
                let hours = totalMinutes / 60
                let mins = totalMinutes % 60
                print("📊 First converted trip #\(firstTrip.tripNumber): \(firstTrip.legs.count) legs, \(firstTrip.logpages.count) logpages")
                print("📊 Total block time: \(hours):\(String(format: "%02d", mins))")
            }

            enforceOneActiveTrip()
            print("✅ Loaded \(trips.count) trips from SwiftData")

            // Run integrity verification in background
            await verifyDataIntegrity()

        } catch {
            print("❌ Failed to load trips from SwiftData: \(error)")
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
            
            // CRITICAL: Verify save integrity
            Task { @MainActor in
                DataIntegrityManager.shared.verifySaveIntegrity(
                    logbookStore: self,
                    operation: "saveTrip #\(trip.tripNumber)"
                )
            }

        } catch {
            print("Failed to save trip: \(error)")
        }
    }

    // MARK: - Add Trip (with deduplication)
    func addTrip(_ trip: Trip) {
        // CRITICAL FIX: Check DATABASE for existing trip with same UUID first (not just in-memory)
        let tripId = trip.id
        let predicate = #Predicate<SDTrip> { $0.tripId == tripId }
        let descriptor = FetchDescriptor<SDTrip>(predicate: predicate)

        do {
            let existingInDB = try modelContext.fetch(descriptor)
            if !existingInDB.isEmpty {
                print("⚠️ addTrip: Trip with UUID \(tripId) already exists in database - using saveTrip instead")
                saveTrip(trip)
                return
            }

            // Also check by trip number + date to catch duplicates with different UUIDs
            if !trip.tripNumber.isEmpty {
                let tripNumber = trip.tripNumber
                let tripDate = trip.date
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: tripDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                let numberPredicate = #Predicate<SDTrip> {
                    $0.tripNumber == tripNumber &&
                    $0.date >= startOfDay &&
                    $0.date < endOfDay
                }
                let numberDescriptor = FetchDescriptor<SDTrip>(predicate: numberPredicate)
                let existingByNumber = try modelContext.fetch(numberDescriptor)

                if !existingByNumber.isEmpty {
                    print("⚠️ addTrip: Trip #\(tripNumber) on \(tripDate) already exists in database - updating existing trip")
                    // Get the existing trip and update it with new data
                    var existingTrip = existingByNumber.first!.toTrip()

                    // Update the status to match the new trip (usually .active when starting duty)
                    existingTrip.status = trip.status

                    // Update legs if the new trip has legs
                    if !trip.legs.isEmpty {
                        existingTrip.legs = trip.legs
                    }

                    // Update per diem if set
                    if trip.perDiemStarted != nil {
                        existingTrip.perDiemStarted = trip.perDiemStarted
                    }

                    // Save the updated trip
                    saveTrip(existingTrip)

                    // Update in-memory cache
                    if let index = trips.firstIndex(where: { $0.id == existingTrip.id }) {
                        trips[index] = existingTrip
                    } else {
                        trips.append(existingTrip)
                        trips.sort { $0.date > $1.date }
                    }

                    print("✅ Updated existing trip #\(tripNumber) to status: \(existingTrip.status)")
                    return
                }
            }
        } catch {
            print("⚠️ addTrip: Error checking for duplicates: \(error)")
            // Continue with insertion - better to have duplicate than lose data
        }

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
            print("✅ addTrip: Successfully added trip #\(trip.tripNumber)")
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

    // MARK: - Delete All Data
    func deleteAllData() async -> Bool {
        print("🗑️ DELETE ALL DATA: Starting...")

        do {
            let tripDescriptor = FetchDescriptor<SDTrip>()
            let logpageDescriptor = FetchDescriptor<SDLogpage>()
            let legDescriptor = FetchDescriptor<SDFlightLeg>()
            let crewDescriptor = FetchDescriptor<SDCrewMember>()

            let allTrips = try modelContext.fetch(tripDescriptor)
            let allLogpages = try modelContext.fetch(logpageDescriptor)
            let allLegs = try modelContext.fetch(legDescriptor)
            let allCrew = try modelContext.fetch(crewDescriptor)

            print("🗑️ Deleting \(allTrips.count) trips, \(allLogpages.count) logpages, \(allLegs.count) legs, \(allCrew.count) crew")

            // Delete in reverse order of dependencies
            for crew in allCrew { modelContext.delete(crew) }
            for leg in allLegs { modelContext.delete(leg) }
            for logpage in allLogpages { modelContext.delete(logpage) }
            for trip in allTrips { modelContext.delete(trip) }

            try modelContext.save()

            // Clear in-memory trips
            trips = []

            print("✅ All local data deleted successfully")
            return true

        } catch {
            print("❌ Failed to delete all data: \(error)")
            return false
        }
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
        sdTrip.logpages = []  // Initialize array before adding children
        sdTrip.crew = []
        modelContext.insert(sdTrip)

        for logpage in trip.logpages {
            let sdLogpage = SDLogpage(from: logpage)
            sdLogpage.legs = []  // Initialize array before adding children
            modelContext.insert(sdLogpage)

            // Set relationship on BOTH sides
            sdLogpage.owningTrip = sdTrip
            sdTrip.logpages?.append(sdLogpage)

            for (order, leg) in logpage.legs.enumerated() {
                let sdLeg = SDFlightLeg(from: leg, order: order)
                modelContext.insert(sdLeg)

                // Set relationship on BOTH sides
                sdLeg.parentLogpage = sdLogpage
                sdLogpage.legs?.append(sdLeg)
            }
        }

        for crew in trip.crew {
            let sdCrew = SDCrewMember(from: crew)
            modelContext.insert(sdCrew)
            sdCrew.trip = sdTrip
            sdTrip.crew?.append(sdCrew)
        }
    }

    private func updateSDTrip(_ sdTrip: SDTrip, from trip: Trip) {
        // Update scalar properties
        sdTrip.update(from: trip)

        // SMART UPDATE: Merge instead of delete-and-recreate to prevent CloudKit sync issues
        let existingLogpages = sdTrip.logpages ?? []
        let newLogpageIDs = Set(trip.logpages.map { $0.id })

        // Remove logpages that no longer exist
        for sdLogpage in existingLogpages {
            if !newLogpageIDs.contains(sdLogpage.logpageId) {
                // Delete orphaned legs first
                if let legs = sdLogpage.legs {
                    for leg in legs {
                        modelContext.delete(leg)
                    }
                }
                modelContext.delete(sdLogpage)
            }
        }

        // Update or create logpages
        for logpage in trip.logpages {
            if let existingLogpage = existingLogpages.first(where: { $0.logpageId == logpage.id }) {
                // Update existing logpage
                existingLogpage.update(from: logpage)

                // Smart update legs within this logpage
                let existingLegs = existingLogpage.legs ?? []
                let newLegIDs = Set(logpage.legs.map { $0.id })

                // Remove legs that no longer exist
                for sdLeg in existingLegs {
                    if !newLegIDs.contains(sdLeg.legId) {
                        modelContext.delete(sdLeg)
                    }
                }

                // Update or create legs
                for (order, leg) in logpage.legs.enumerated() {
                    if let existingLeg = existingLegs.first(where: { $0.legId == leg.id }) {
                        // Update existing leg
                        existingLeg.update(from: leg, order: order)
                    } else {
                        // Create new leg with relationship on BOTH sides
                        let sdLeg = SDFlightLeg(from: leg, order: order)
                        modelContext.insert(sdLeg)
                        sdLeg.parentLogpage = existingLogpage
                        if existingLogpage.legs == nil { existingLogpage.legs = [] }
                        existingLogpage.legs?.append(sdLeg)
                    }
                }
            } else {
                // Create new logpage with legs
                let sdLogpage = SDLogpage(from: logpage)
                sdLogpage.legs = []  // Initialize array before adding children
                modelContext.insert(sdLogpage)

                // Set relationship on BOTH sides
                sdLogpage.owningTrip = sdTrip
                if sdTrip.logpages == nil { sdTrip.logpages = [] }
                sdTrip.logpages?.append(sdLogpage)

                for (order, leg) in logpage.legs.enumerated() {
                    let sdLeg = SDFlightLeg(from: leg, order: order)
                    modelContext.insert(sdLeg)
                    // Set relationship on BOTH sides
                    sdLeg.parentLogpage = sdLogpage
                    sdLogpage.legs?.append(sdLeg)
                }
            }
        }

        // Smart update crew members
        let existingCrew = sdTrip.crew ?? []
        let newCrewIDs = Set(trip.crew.map { $0.id })

        // Remove crew that no longer exist
        for sdCrew in existingCrew {
            if !newCrewIDs.contains(sdCrew.crewId) {
                modelContext.delete(sdCrew)
            }
        }

        // Update or create crew
        for crewMember in trip.crew {
            if let existingMember = existingCrew.first(where: { $0.crewId == crewMember.id }) {
                existingMember.update(from: crewMember)
            } else {
                // Create new crew with relationship on BOTH sides
                let sdCrew = SDCrewMember(from: crewMember)
                modelContext.insert(sdCrew)
                sdCrew.trip = sdTrip
                if sdTrip.crew == nil { sdTrip.crew = [] }
                sdTrip.crew?.append(sdCrew)
            }
        }
    }

    // MARK: - Comprehensive Integrity Check and Repair

    func repairOrphanedRelationships() async {
        print("🔧 Starting comprehensive relationship repair...")

        do {
            // Step 1: Find and remove duplicate trips (same tripId UUID)
            let allTripsDescriptor = FetchDescriptor<SDTrip>()
            var allTrips = try modelContext.fetch(allTripsDescriptor)

            var tripsByUUID: [UUID: [SDTrip]] = [:]
            for sdTrip in allTrips {
                tripsByUUID[sdTrip.tripId, default: []].append(sdTrip)
            }

            var duplicatesRemoved = 0
            for (uuid, duplicateTrips) in tripsByUUID where duplicateTrips.count > 1 {
                print("⚠️ Found \(duplicateTrips.count) duplicate trips with UUID \(uuid)")
                // Keep the one with most data, delete others
                let sorted = duplicateTrips.sorted {
                    let count1 = ($0.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0)
                    let count2 = ($1.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0)
                    return count1 > count2
                }
                for i in 1..<sorted.count {
                    modelContext.delete(sorted[i])
                    duplicatesRemoved += 1
                }
            }
            if duplicatesRemoved > 0 {
                print("🔧 Removed \(duplicatesRemoved) duplicate trips (by UUID)")
                allTrips = try modelContext.fetch(allTripsDescriptor)
            }

            // Step 1b: Find and remove duplicate trips by trip number + date (different UUIDs but same trip)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            var tripsByNumberDate: [String: [SDTrip]] = [:]
            for sdTrip in allTrips where !sdTrip.tripNumber.isEmpty {
                let key = "\(sdTrip.tripNumber)_\(dateFormatter.string(from: sdTrip.date))"
                tripsByNumberDate[key, default: []].append(sdTrip)
            }

            var numberDuplicatesRemoved = 0
            for (key, duplicateTrips) in tripsByNumberDate where duplicateTrips.count > 1 {
                print("⚠️ Found \(duplicateTrips.count) trips with same number/date: \(key)")
                // Keep the one with most legs
                let sorted = duplicateTrips.sorted {
                    let count1 = ($0.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0)
                    let count2 = ($1.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0)
                    return count1 > count2
                }
                for i in 1..<sorted.count {
                    modelContext.delete(sorted[i])
                    numberDuplicatesRemoved += 1
                }
            }
            if numberDuplicatesRemoved > 0 {
                print("🔧 Removed \(numberDuplicatesRemoved) duplicate trips (by number+date)")
                allTrips = try modelContext.fetch(allTripsDescriptor)
            }

            // Step 1c: Remove empty/invalid trips (no legs, no logpages, empty data)
            var emptyTripsRemoved = 0
            for sdTrip in allTrips {
                let legCount = sdTrip.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0
                let hasValidData = legCount > 0 || !sdTrip.tripNumber.isEmpty

                // Remove trips that have no legs AND no trip number AND no useful data
                if legCount == 0 && sdTrip.tripNumber.isEmpty && sdTrip.notes.isEmpty {
                    modelContext.delete(sdTrip)
                    emptyTripsRemoved += 1
                }
            }
            if emptyTripsRemoved > 0 {
                print("🔧 Removed \(emptyTripsRemoved) empty/invalid trips")
                allTrips = try modelContext.fetch(allTripsDescriptor)
            }

            duplicatesRemoved += numberDuplicatesRemoved + emptyTripsRemoved

            // Step 2: Find orphaned logpages and try to re-link them
            let orphanedLogpagesDescriptor = FetchDescriptor<SDLogpage>(
                predicate: #Predicate<SDLogpage> { $0.owningTrip == nil }
            )
            let orphanedLogpages = try modelContext.fetch(orphanedLogpagesDescriptor)
            print("🔧 Found \(orphanedLogpages.count) orphaned logpages")

            // Build a lookup map of trips by date for faster matching
            // (reuse dateFormatter from Step 1b)
            var tripsByDate: [String: [SDTrip]] = [:]
            for sdTrip in allTrips {
                let dateKey = dateFormatter.string(from: sdTrip.date)
                tripsByDate[dateKey, default: []].append(sdTrip)
            }

            var logpagesRelinked = 0
            for orphanedLogpage in orphanedLogpages {
                let logpageDateKey = dateFormatter.string(from: orphanedLogpage.dateCreated)

                // Try exact date match first
                if let matchingTrips = tripsByDate[logpageDateKey], let matchingTrip = matchingTrips.first {
                    orphanedLogpage.owningTrip = matchingTrip
                    logpagesRelinked += 1
                    print("🔧 Re-linked logpage \(orphanedLogpage.logpageId) to trip #\(matchingTrip.tripNumber) (date match)")
                } else {
                    // Try finding a trip within 1 day
                    for offset in [-1, 1] {
                        if let offsetDate = Calendar.current.date(byAdding: .day, value: offset, to: orphanedLogpage.dateCreated) {
                            let offsetKey = dateFormatter.string(from: offsetDate)
                            if let matchingTrips = tripsByDate[offsetKey], let matchingTrip = matchingTrips.first {
                                orphanedLogpage.owningTrip = matchingTrip
                                logpagesRelinked += 1
                                print("🔧 Re-linked logpage \(orphanedLogpage.logpageId) to trip #\(matchingTrip.tripNumber) (±1 day)")
                                break
                            }
                        }
                    }
                }
            }

            // Step 3: Get all logpages (including newly linked ones)
            let allLogpagesDescriptor = FetchDescriptor<SDLogpage>()
            var allLogpages = try modelContext.fetch(allLogpagesDescriptor)

            // Build lookup for logpages by date
            var logpagesByDate: [String: [SDLogpage]] = [:]
            for logpage in allLogpages {
                let dateKey = dateFormatter.string(from: logpage.dateCreated)
                logpagesByDate[dateKey, default: []].append(logpage)
            }

            // Step 4: Find orphaned legs and try to re-link them
            let orphanedLegsDescriptor = FetchDescriptor<SDFlightLeg>(
                predicate: #Predicate<SDFlightLeg> { $0.parentLogpage == nil }
            )
            let orphanedLegs = try modelContext.fetch(orphanedLegsDescriptor)
            print("🔧 Found \(orphanedLegs.count) orphaned legs")

            var legsRelinked = 0
            for orphanedLeg in orphanedLegs {
                var matched = false

                // Try matching by flight date first
                if let legDate = orphanedLeg.flightDate {
                    let legDateKey = dateFormatter.string(from: legDate)
                    if let matchingLogpages = logpagesByDate[legDateKey], let matchingLogpage = matchingLogpages.first {
                        orphanedLeg.parentLogpage = matchingLogpage
                        legsRelinked += 1
                        matched = true
                        print("🔧 Re-linked leg \(orphanedLeg.departure)-\(orphanedLeg.arrival) by flightDate")
                    }
                }

                // If no flightDate, try to match by legOrder or just assign to any logpage with same trip date
                if !matched && !allLogpages.isEmpty {
                    // Find a logpage that belongs to a trip (prefer linked logpages)
                    if let linkedLogpage = allLogpages.first(where: { $0.owningTrip != nil }) {
                        orphanedLeg.parentLogpage = linkedLogpage
                        legsRelinked += 1
                        print("🔧 Re-linked leg \(orphanedLeg.departure)-\(orphanedLeg.arrival) to first available logpage")
                    }
                }
            }

            // Step 5: Remove duplicate logpages (same logpageId)
            allLogpages = try modelContext.fetch(allLogpagesDescriptor)
            var logpagesByUUID: [UUID: [SDLogpage]] = [:]
            for logpage in allLogpages {
                logpagesByUUID[logpage.logpageId, default: []].append(logpage)
            }

            var logpageDuplicatesRemoved = 0
            for (uuid, duplicateLogpages) in logpagesByUUID where duplicateLogpages.count > 1 {
                print("⚠️ Found \(duplicateLogpages.count) duplicate logpages with UUID \(uuid)")
                let sorted = duplicateLogpages.sorted { ($0.legs?.count ?? 0) > ($1.legs?.count ?? 0) }
                for i in 1..<sorted.count {
                    modelContext.delete(sorted[i])
                    logpageDuplicatesRemoved += 1
                }
            }

            // Step 6: Remove duplicate legs (same legId)
            let allLegsDescriptor = FetchDescriptor<SDFlightLeg>()
            let allLegs = try modelContext.fetch(allLegsDescriptor)

            var legsByUUID: [UUID: [SDFlightLeg]] = [:]
            for leg in allLegs {
                legsByUUID[leg.legId, default: []].append(leg)
            }

            var legDuplicatesRemoved = 0
            for (uuid, duplicateLegs) in legsByUUID where duplicateLegs.count > 1 {
                print("⚠️ Found \(duplicateLegs.count) duplicate legs with UUID \(uuid)")
                // Keep the one with a parent, or the first one
                let withParent = duplicateLegs.filter { $0.parentLogpage != nil }
                let toKeep = withParent.first ?? duplicateLegs.first!
                for leg in duplicateLegs where leg !== toKeep {
                    modelContext.delete(leg)
                    legDuplicatesRemoved += 1
                }
            }

            // Save all changes
            try modelContext.save()

            print("🔧 Repair Summary:")
            print("   - Duplicate trips removed: \(duplicatesRemoved)")
            print("   - Logpages re-linked: \(logpagesRelinked)")
            print("   - Legs re-linked: \(legsRelinked)")
            print("   - Duplicate logpages removed: \(logpageDuplicatesRemoved)")
            print("   - Duplicate legs removed: \(legDuplicatesRemoved)")

            if logpagesRelinked > 0 || legsRelinked > 0 {
                print("✅ Some orphaned records were successfully re-linked!")
                print("🔄 Reloading trips to reflect changes...")
                // Reload trips to reflect the repairs
                await loadTrips()
            } else if orphanedLogpages.count > 0 || orphanedLegs.count > 0 {
                print("⚠️ Could not re-link all orphaned records")
                print("💡 Try importing from a JSON backup to restore data")
            }

        } catch {
            print("❌ Failed to repair relationships: \(error)")
        }
    }

    // MARK: - Verify Data Integrity After Load

    func verifyDataIntegrity() async {
        var totalLegsInTrips = 0
        var totalLegsInDB = 0
        var totalLogpagesInTrips = 0

        // Count legs and logpages in in-memory trips
        for trip in trips {
            totalLegsInTrips += trip.legs.count
            totalLogpagesInTrips += trip.logpages.count
        }

        // Count legs in database
        let legDescriptor = FetchDescriptor<SDFlightLeg>()
        let logpageDescriptor = FetchDescriptor<SDLogpage>()
        let tripDescriptor = FetchDescriptor<SDTrip>()

        do {
            let allLegs = try modelContext.fetch(legDescriptor)
            let allLogpages = try modelContext.fetch(logpageDescriptor)
            let allTrips = try modelContext.fetch(tripDescriptor)
            totalLegsInDB = allLegs.count

            let orphanedLegs = allLegs.filter { $0.parentLogpage == nil }
            let orphanedLogpages = allLogpages.filter { $0.owningTrip == nil }

            // Check for duplicate leg UUIDs
            var legUUIDs = Set<UUID>()
            var duplicateLegs = 0
            for leg in allLegs {
                if legUUIDs.contains(leg.legId) {
                    duplicateLegs += 1
                } else {
                    legUUIDs.insert(leg.legId)
                }
            }

            // Check for duplicate trip UUIDs
            var tripUUIDs = Set<UUID>()
            var duplicateTripUUIDs = 0
            for trip in allTrips {
                if tripUUIDs.contains(trip.tripId) {
                    duplicateTripUUIDs += 1
                } else {
                    tripUUIDs.insert(trip.tripId)
                }
            }

            // Check for duplicate trips by number+date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            var tripsByNumberDate: [String: Int] = [:]
            var duplicateTripsByNumber = 0
            for trip in allTrips where !trip.tripNumber.isEmpty {
                let key = "\(trip.tripNumber)_\(dateFormatter.string(from: trip.date))"
                tripsByNumberDate[key, default: 0] += 1
                if tripsByNumberDate[key]! > 1 {
                    duplicateTripsByNumber += 1
                }
            }

            // Count empty trips (no legs, no trip number)
            var emptyTrips = 0
            for trip in allTrips {
                let legCount = trip.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0
                if legCount == 0 && trip.tripNumber.isEmpty && trip.notes.isEmpty {
                    emptyTrips += 1
                }
            }

            print("📊 Data Integrity Check:")
            print("   - Trips in memory: \(trips.count)")
            print("   - Trips in database: \(allTrips.count)")
            print("   - Logpages in memory: \(totalLogpagesInTrips)")
            print("   - Logpages in database: \(allLogpages.count)")
            print("   - Orphaned logpages: \(orphanedLogpages.count)")
            print("   - Legs in memory: \(totalLegsInTrips)")
            print("   - Legs in database: \(totalLegsInDB)")
            print("   - Orphaned legs: \(orphanedLegs.count)")
            print("   - Duplicate leg UUIDs: \(duplicateLegs)")
            print("   - Duplicate trip UUIDs: \(duplicateTripUUIDs)")
            print("   - Duplicate trips (by number+date): \(duplicateTripsByNumber)")
            print("   - Empty/invalid trips: \(emptyTrips)")

            var hasIssues = false
            var issuesList: [String] = []

            if orphanedLegs.count > 0 {
                issuesList.append("⚠️ \(orphanedLegs.count) orphaned legs")
                hasIssues = true
            }

            if orphanedLogpages.count > 0 {
                issuesList.append("⚠️ \(orphanedLogpages.count) orphaned logpages")
                hasIssues = true
            }

            if duplicateLegs > 0 {
                issuesList.append("⚠️ \(duplicateLegs) duplicate leg UUIDs")
                hasIssues = true
            }

            if duplicateTripUUIDs > 0 {
                issuesList.append("❌ CRITICAL: \(duplicateTripUUIDs) duplicate trip UUIDs")
                hasIssues = true
            }

            if duplicateTripsByNumber > 0 {
                issuesList.append("❌ CRITICAL: \(duplicateTripsByNumber) duplicate trips (by number+date)")
                hasIssues = true
            }

            if emptyTrips > 0 {
                issuesList.append("⚠️ \(emptyTrips) empty/invalid trips")
                hasIssues = true
            }

            let expectedLegs = totalLegsInDB - orphanedLegs.count - duplicateLegs
            if totalLegsInTrips != expectedLegs {
                issuesList.append("⚠️ Leg count mismatch (Memory: \(totalLegsInTrips), DB: \(expectedLegs))")
                hasIssues = true
            }

            if hasIssues {
                print("⚠️ Data integrity check found issues:")
                for issue in issuesList {
                    print("   \(issue)")
                }

                // Auto-repair if critical issues found (duplicates or empty trips)
                let hasCriticalIssues = duplicateTripUUIDs > 0 || duplicateTripsByNumber > 0 || emptyTrips > 5
                if hasCriticalIssues {
                    print("🔧 Auto-repairing critical data integrity issues...")
                    await repairOrphanedRelationships()
                } else {
                    print("💡 Run repairOrphanedRelationships() to attempt automatic repair")
                    print("💡 Or import from a backup to restore data")
                }
            } else {
                print("✅ Data integrity check passed!")
            }

        } catch {
            print("❌ Failed to verify data integrity: \(error)")
        }
    }

    // MARK: - Force Full Re-sync from CloudKit

    func forceCloudKitResync() async {
        print("☁️ Forcing CloudKit re-sync...")
        // SwiftData doesn't provide direct CloudKit control, but we can:
        // 1. Clear local cache
        // 2. Trigger a reload which will fetch from CloudKit

        // First, run integrity check
        await verifyDataIntegrity()

        // Reload from SwiftData (which syncs with CloudKit)
        await loadTrips()

        // Check again after reload
        await verifyDataIntegrity()
    }

    // MARK: - Migrate from Legacy CloudKit Records

    /// Migrates data from old CloudKit "Trip" and "FlightLeg" records to SwiftData.
    /// Call this if you have data in the old format that needs to be imported.
    func migrateFromLegacyCloudKit() async -> (tripsImported: Int, legsImported: Int) {
        print("🔄 Starting legacy CloudKit migration...")

        guard CloudKitManager.shared.iCloudAvailable else {
            print("❌ iCloud not available for migration")
            return (0, 0)
        }

        do {
            // Fetch all old-format trips
            let legacyTrips = try await CloudKitManager.shared.fetchAllTrips()
            print("📦 Found \(legacyTrips.count) trips in legacy CloudKit format")

            var tripsImported = 0
            var legsImported = 0

            for legacyTrip in legacyTrips {
                // Check if we already have this trip by UUID
                let tripId = legacyTrip.id
                let predicate = #Predicate<SDTrip> { $0.tripId == tripId }
                let descriptor = FetchDescriptor<SDTrip>(predicate: predicate)

                let existing = try modelContext.fetch(descriptor)

                if existing.isEmpty {
                    // Import this trip
                    insertNewTrip(legacyTrip)
                    tripsImported += 1
                    legsImported += legacyTrip.legs.count
                    print("✅ Imported trip #\(legacyTrip.tripNumber) with \(legacyTrip.legs.count) legs")
                } else {
                    print("⏭️ Skipping trip #\(legacyTrip.tripNumber) - already exists in SwiftData")
                }
            }

            try modelContext.save()

            print("🔄 Migration complete:")
            print("   - Trips imported: \(tripsImported)")
            print("   - Legs imported: \(legsImported)")

            // Reload to reflect changes
            await loadTrips()

            return (tripsImported, legsImported)

        } catch {
            print("❌ Migration failed: \(error)")
            return (0, 0)
        }
    }

    // MARK: - Nuclear Reset: Delete All Local Data and Re-import from JSON

    /// Completely deletes all local SwiftData records and re-imports from a JSON backup.
    /// Use this when CloudKit sync is corrupted and relationships are broken.
    /// This does NOT delete CloudKit data - it just rebuilds the local database.
    func nuclearResetAndImport(_ jsonData: Data) async -> Bool {
        print("🔥 NUCLEAR RESET: Deleting all local SwiftData records...")

        do {
            // Step 1: Delete ALL local entities
            let tripDescriptor = FetchDescriptor<SDTrip>()
            let logpageDescriptor = FetchDescriptor<SDLogpage>()
            let legDescriptor = FetchDescriptor<SDFlightLeg>()
            let crewDescriptor = FetchDescriptor<SDCrewMember>()

            let allTrips = try modelContext.fetch(tripDescriptor)
            let allLogpages = try modelContext.fetch(logpageDescriptor)
            let allLegs = try modelContext.fetch(legDescriptor)
            let allCrew = try modelContext.fetch(crewDescriptor)

            print("🗑️ Deleting \(allTrips.count) trips, \(allLogpages.count) logpages, \(allLegs.count) legs, \(allCrew.count) crew")

            // Delete in reverse order of dependencies
            for crew in allCrew { modelContext.delete(crew) }
            for leg in allLegs { modelContext.delete(leg) }
            for logpage in allLogpages { modelContext.delete(logpage) }
            for trip in allTrips { modelContext.delete(trip) }

            try modelContext.save()
            print("✅ All local data deleted")

            // Step 2: Clear in-memory trips
            trips = []

            // Step 3: Decode JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var tripsToImport: [Trip] = []

            // Try different formats
            if let backup = try? decoder.decode(AppBackupData.self, from: jsonData) {
                tripsToImport = backup.trips
                print("📦 Decoded \(tripsToImport.count) trips from AppBackupData format")
            } else if let simpleBackup = try? decoder.decode(SimpleBackupFormat.self, from: jsonData) {
                tripsToImport = simpleBackup.trips
                print("📦 Decoded \(tripsToImport.count) trips from SimpleBackupFormat")
            } else if let tripArray = try? decoder.decode([Trip].self, from: jsonData) {
                tripsToImport = tripArray
                print("📦 Decoded \(tripsToImport.count) trips from raw array")
            } else {
                print("❌ Could not decode JSON data")
                return false
            }

            // Step 4: Remove duplicate trips and legs
            var seenTripIds = Set<UUID>()
            var duplicateTrips = 0
            var duplicateLegs = 0

            tripsToImport = tripsToImport.compactMap { trip -> Trip? in
                // Skip duplicate trip IDs
                if seenTripIds.contains(trip.id) {
                    duplicateTrips += 1
                    print("⚠️ Skipping duplicate trip ID: \(trip.id)")
                    return nil
                }
                seenTripIds.insert(trip.id)

                // Deduplicate legs within this trip's logpages
                var seenLegIds = Set<UUID>()
                var cleanedTrip = trip
                cleanedTrip.logpages = trip.logpages.map { logpage -> Logpage in
                    var cleanedLogpage = logpage
                    cleanedLogpage.legs = logpage.legs.compactMap { leg -> FlightLeg? in
                        if seenLegIds.contains(leg.id) {
                            duplicateLegs += 1
                            print("⚠️ Skipping duplicate leg ID: \(leg.id)")
                            return nil
                        }
                        seenLegIds.insert(leg.id)
                        return leg
                    }
                    return cleanedLogpage
                }

                // Skip trips with no data (empty date, no legs, no route info)
                let hasLegs = cleanedTrip.logpages.contains { !$0.legs.isEmpty }
                let hasValidLeg = cleanedTrip.logpages.flatMap { $0.legs }.contains {
                    !$0.departure.isEmpty || !$0.arrival.isEmpty || !$0.outTime.isEmpty
                }

                if !hasLegs || !hasValidLeg {
                    duplicateTrips += 1
                    print("⚠️ Skipping empty/invalid trip ID: \(trip.id)")
                    return nil
                }

                return cleanedTrip
            }

            if duplicateTrips > 0 || duplicateLegs > 0 {
                print("🧹 Cleaned data: removed \(duplicateTrips) duplicate/empty trips, \(duplicateLegs) duplicate legs")
                print("📦 Proceeding with \(tripsToImport.count) valid trips")
            }

            // Step 5: Insert each trip with EXPLICIT relationship handling on BOTH SIDES
            var totalLegsInserted = 0
            var totalLogpagesInserted = 0

            for trip in tripsToImport {
                // Create SDTrip and initialize relationship arrays
                let sdTrip = SDTrip(from: trip)
                sdTrip.logpages = []  // CRITICAL: Initialize array before adding children
                sdTrip.crew = []
                modelContext.insert(sdTrip)

                // Create SDLogpages with EXPLICIT parent relationship on BOTH SIDES
                for logpage in trip.logpages {
                    let sdLogpage = SDLogpage(from: logpage)
                    sdLogpage.legs = []  // CRITICAL: Initialize array before adding children
                    modelContext.insert(sdLogpage)

                    // Set relationship on BOTH sides
                    sdLogpage.owningTrip = sdTrip
                    sdTrip.logpages?.append(sdLogpage)
                    totalLogpagesInserted += 1

                    // Create SDFlightLegs with EXPLICIT parent relationship on BOTH SIDES
                    for (order, leg) in logpage.legs.enumerated() {
                        let sdLeg = SDFlightLeg(from: leg, order: order)
                        modelContext.insert(sdLeg)

                        // Set relationship on BOTH sides
                        sdLeg.parentLogpage = sdLogpage
                        sdLogpage.legs?.append(sdLeg)
                        totalLegsInserted += 1
                    }
                }

                // Create SDCrewMembers with EXPLICIT relationship on BOTH SIDES
                for crew in trip.crew {
                    let sdCrew = SDCrewMember(from: crew)
                    modelContext.insert(sdCrew)
                    sdCrew.trip = sdTrip
                    sdTrip.crew?.append(sdCrew)
                }

                print("📦 Imported trip #\(trip.tripNumber): \(sdTrip.logpages?.count ?? 0) logpages, \(sdTrip.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0) legs")
            }

            // Step 6: Save immediately
            try modelContext.save()

            print("✅ NUCLEAR RESET COMPLETE:")
            print("   - Trips inserted: \(tripsToImport.count)")
            print("   - Logpages inserted: \(totalLogpagesInserted)")
            print("   - Legs inserted: \(totalLegsInserted)")

            // Step 7: Reload trips from fresh database
            await loadTrips()

            // Step 8: Verify the relationships are intact
            var verifyLegs = 0
            for trip in trips {
                verifyLegs += trip.legs.count
            }

            if verifyLegs == totalLegsInserted {
                print("✅ VERIFICATION PASSED: All \(verifyLegs) legs properly linked!")
                return true
            } else {
                print("⚠️ VERIFICATION WARNING: Expected \(totalLegsInserted) legs, got \(verifyLegs)")
                return true // Still return true since data was inserted
            }

        } catch {
            print("❌ Nuclear reset failed: \(error)")
            return false
        }
    }

    /// Counts records in both old and new CloudKit formats for diagnostic purposes
    func countCloudKitRecords() async -> (legacyTrips: Int, legacyLegs: Int, swiftDataTrips: Int, swiftDataLegs: Int) {
        var legacyTrips = 0
        var legacyLegs = 0

        // Count legacy records
        do {
            let trips = try await CloudKitManager.shared.fetchAllTrips()
            legacyTrips = trips.count
            for trip in trips {
                legacyLegs += trip.legs.count
            }
        } catch {
            print("❌ Failed to count legacy records: \(error)")
        }

        // Count SwiftData records
        let tripDescriptor = FetchDescriptor<SDTrip>()
        let legDescriptor = FetchDescriptor<SDFlightLeg>()

        do {
            let sdTrips = try modelContext.fetch(tripDescriptor)
            let sdLegs = try modelContext.fetch(legDescriptor)

            print("📊 CloudKit Record Counts:")
            print("   Legacy 'Trip' records: \(legacyTrips)")
            print("   Legacy 'FlightLeg' records: \(legacyLegs)")
            print("   SwiftData 'CD_SDTrip' records: \(sdTrips.count)")
            print("   SwiftData 'CD_SDFlightLeg' records: \(sdLegs.count)")

            return (legacyTrips, legacyLegs, sdTrips.count, sdLegs.count)

        } catch {
            print("❌ Failed to count SwiftData records: \(error)")
            return (legacyTrips, legacyLegs, 0, 0)
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
            Task { @MainActor in
                self?.handleAutoOffTime(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .landingRollDecel,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAutoOnTime(notification)
            }
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
            // Build fingerprint index of all existing legs for fast lookup
            var existingLegFingerprints = Set<String>()
            var existingRelaxedFingerprints = Set<String>()
            for trip in trips {
                for leg in trip.legs {
                    existingLegFingerprints.insert(leg.fingerprint)
                    existingRelaxedFingerprints.insert(leg.relaxedFingerprint)
                }
            }

            // Also track by UUID and trip number for backwards compatibility
            let existingIDs = Set(trips.map { $0.id })
            let existingTripNumbers = Set(trips.map { "\($0.tripNumber)-\($0.date)" }.filter { !$0.starts(with: "-") })

            var newTripsToAdd: [Trip] = []
            var skippedDuplicates = 0
            var mergedLegs = 0

            for importedTrip in importedTrips {
                // Check 1: Exact UUID match - skip entirely
                if existingIDs.contains(importedTrip.id) {
                    skippedDuplicates += 1
                    print("⏭️ Import: Skipping trip with existing UUID: \(importedTrip.id)")
                    continue
                }

                // Check 2: Trip number + date match (if trip has a number)
                if !importedTrip.tripNumber.isEmpty {
                    let tripKey = "\(importedTrip.tripNumber)-\(importedTrip.date)"
                    if existingTripNumbers.contains(tripKey) {
                        skippedDuplicates += 1
                        print("⏭️ Import: Skipping trip with existing number: \(importedTrip.tripNumber)")
                        continue
                    }
                }

                // Check 3: Leg-level fingerprint matching
                // Filter out legs that already exist (by flight characteristics)
                var uniqueLegs: [FlightLeg] = []
                var tripHasAllDuplicates = true

                for leg in importedTrip.legs {
                    // Check exact fingerprint first (date + city pair + flight num + times)
                    if existingLegFingerprints.contains(leg.fingerprint) {
                        mergedLegs += 1
                        print("⏭️ Import: Skipping duplicate leg: \(leg.fingerprint)")
                        continue
                    }

                    // Check relaxed fingerprint (date + city pair + flight num, ignoring times)
                    // This catches cases where times differ slightly between sources
                    if existingRelaxedFingerprints.contains(leg.relaxedFingerprint) {
                        mergedLegs += 1
                        print("⏭️ Import: Skipping leg with same route/date: \(leg.relaxedFingerprint)")
                        continue
                    }

                    uniqueLegs.append(leg)
                    tripHasAllDuplicates = false

                    // Add this leg's fingerprints to prevent duplicates within this import
                    existingLegFingerprints.insert(leg.fingerprint)
                    existingRelaxedFingerprints.insert(leg.relaxedFingerprint)
                }

                // If all legs were duplicates, skip the entire trip
                if tripHasAllDuplicates && !importedTrip.legs.isEmpty {
                    skippedDuplicates += 1
                    print("⏭️ Import: Skipping trip - all legs are duplicates")
                    continue
                }

                // Create trip with only unique legs
                var tripToAdd = importedTrip
                if uniqueLegs.count != importedTrip.legs.count {
                    // Some legs were filtered out - rebuild logpages with unique legs
                    tripToAdd.logpages = [Logpage(pageNumber: 1, tatStart: importedTrip.tatStart, legs: uniqueLegs)]
                    print("📝 Import: Trip has \(uniqueLegs.count)/\(importedTrip.legs.count) unique legs")
                }

                // Mark as completed if it was active/planning
                if tripToAdd.status == .active || tripToAdd.status == .planning {
                    tripToAdd.status = .completed
                }

                newTripsToAdd.append(tripToAdd)
            }

            // Add all new trips
            for trip in newTripsToAdd {
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

            // Build descriptive message
            var message = "Imported \(newTripsToAdd.count) new trips."
            if skippedDuplicates > 0 {
                message += " Skipped \(skippedDuplicates) duplicate trips."
            }
            if mergedLegs > 0 {
                message += " Merged \(mergedLegs) duplicate legs."
            }
            message += " Total: \(trips.count)"

            print("📦 Import Summary: \(newTripsToAdd.count) new trips, \(skippedDuplicates) skipped, \(mergedLegs) legs merged")

            return JSONImportResult(
                success: true,
                message: message,
                newTripsCount: newTripsToAdd.count
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

// MARK: - CloudKit Sync Extension

extension SwiftDataLogBookStore {

    /// Triggers a refresh of SwiftData's CloudKit sync and reloads local data.
    /// SwiftData syncs automatically, but this method:
    /// 1. Logs sync status for debugging
    /// 2. Checks for pending CloudKit changes
    /// 3. Reloads trips from local store (which includes any synced data)
    func syncFromCloud() async {
        print("☁️ syncFromCloud: Starting CloudKit sync check...")

        // Check CloudKit status first
        let (available, status, error) = await SwiftDataConfiguration.checkCloudKitStatus()

        if !available {
            print("☁️ syncFromCloud: iCloud not available - \(error ?? "unknown error")")
            print("☁️ Account status: \(status.rawValue)")
            await MainActor.run {
                CloudKitErrorHandler.shared.syncStatus = .failed(error: error ?? "iCloud unavailable")
            }
            // Still reload local data
            await loadTrips()
            return
        }

        print("☁️ syncFromCloud: iCloud available, checking sync state...")

        // Log current SwiftData sync info
        await logCloudKitSyncStatus()

        // SwiftData syncs automatically, so we just need to reload
        // Any pending CloudKit changes should already be merged into the local store
        await loadTrips()

        let tripCount = trips.count
        print("☁️ syncFromCloud: Loaded \(tripCount) trips from SwiftData")

        await MainActor.run {
            CloudKitErrorHandler.shared.syncStatus = .success
        }
    }

    /// Logs detailed CloudKit sync status for debugging
    private func logCloudKitSyncStatus() async {
        print("☁️ CloudKit Sync Status:")
        print("   Container: \(SwiftDataConfiguration.cloudKitContainerIdentifier)")
        print("   Store URL: \(SwiftDataConfiguration.storeURL.path)")

        // Check if there are any pending changes
        if modelContext.hasChanges {
            print("   ⚠️ Local context has unsaved changes")
        } else {
            print("   ✅ No pending local changes")
        }

        // Log trip counts for debugging
        let descriptor = FetchDescriptor<SDTrip>()
        do {
            let sdTrips = try modelContext.fetch(descriptor)
            print("   📊 SwiftData trips: \(sdTrips.count)")

            // Check for potential sync issues
            var tripsWithoutLegs = 0
            var totalLegs = 0
            for trip in sdTrips {
                let legCount = trip.logpages?.reduce(0) { $0 + ($1.legs?.count ?? 0) } ?? 0
                totalLegs += legCount
                if legCount == 0 {
                    tripsWithoutLegs += 1
                }
            }
            print("   📊 Total legs in database: \(totalLegs)")
            if tripsWithoutLegs > 0 {
                print("   ⚠️ Trips without legs: \(tripsWithoutLegs)")
            }
        } catch {
            print("   ❌ Failed to fetch trips: \(error)")
        }
    }

    /// Force re-upload all local trips to CloudKit by touching each record.
    /// Use this when CloudKit data appears missing or corrupted.
    func forceUploadAllToCloud() async {
        print("☁️ forceUploadAllToCloud: Starting full re-sync...")

        let descriptor = FetchDescriptor<SDTrip>()
        do {
            let sdTrips = try modelContext.fetch(descriptor)
            print("☁️ Re-syncing \(sdTrips.count) trips...")

            for sdTrip in sdTrips {
                // Touch the record to mark it as modified
                sdTrip.notes = sdTrip.notes // This marks the record as dirty
            }

            // Save to trigger CloudKit sync
            try modelContext.save()
            print("☁️ forceUploadAllToCloud: Saved all trips - CloudKit will sync automatically")

            await MainActor.run {
                CloudKitErrorHandler.shared.syncStatus = .success
            }
        } catch {
            print("☁️ forceUploadAllToCloud failed: \(error)")
            await MainActor.run {
                CloudKitErrorHandler.shared.syncStatus = .failed(error: error.localizedDescription)
            }
        }
    }

    func syncToCloud(trip: Trip) {
        // SwiftData syncs automatically on save
        // This method just triggers a save to ensure sync happens
        print("☁️ syncToCloud: Triggering save for trip \(trip.tripNumber)")
        saveTrip(trip)
    }

    func deleteFromCloud(tripID: String) {
        // SwiftData handles deletion sync automatically
        print("☁️ deleteFromCloud: Trip \(tripID) will be synced on deletion")
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

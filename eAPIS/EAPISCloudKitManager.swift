//
//  EAPISCloudKitManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import Foundation
import CloudKit
import Combine

// MARK: - EAPIS CloudKit Manager
class EAPISCloudKitManager: ObservableObject {
    static let shared = EAPISCloudKitManager()
    
    @Published var passengers: [Passenger] = []
    @Published var manifests: [EAPISManifest] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.propilot.app")
        self.privateDatabase = container.privateCloudDatabase
        
        // Load cached data immediately
        loadCachedData()
        
        // Perform initial sync
        Task {
            await performFullSync()
        }
    }
    
    // MARK: - Cache Management
    private var cacheURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app")?
            .appendingPathComponent("eapis_cache.json")
    }
    
    private func loadCachedData() {
        guard let cacheURL = cacheURL,
              FileManager.default.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(EAPISCache.self, from: data) else {
            print("📦 No EAPIS cache found")
            return
        }
        
        DispatchQueue.main.async {
            self.passengers = cache.passengers
            self.manifests = cache.manifests
            self.lastSyncDate = cache.lastSyncDate
            print("✅ Loaded \(cache.passengers.count) passengers and \(cache.manifests.count) manifests from cache")
        }
    }
    
    private func saveToCache() {
        guard let cacheURL = cacheURL else { return }
        
        let cache = EAPISCache(
            passengers: passengers,
            manifests: manifests,
            lastSyncDate: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL)
            print("💾 Saved EAPIS data to cache")
        } catch {
            print("❌ Failed to save cache: \(error)")
        }
    }
    
    // MARK: - Full Sync
    func performFullSync() async {
        await MainActor.run { isSyncing = true }
        
        do {
            // Fetch passengers
            let passengerRecords = try await fetchAllRecords(recordType: "Passenger")
            let fetchedPassengers = passengerRecords.compactMap { Passenger.fromCloudKitRecord($0) }
            
            // Fetch manifests
            let manifestRecords = try await fetchAllRecords(recordType: "EAPISManifest")
            let fetchedManifests = manifestRecords.compactMap { EAPISManifest.fromCloudKitRecord($0) }
            
            await MainActor.run {
                self.passengers = fetchedPassengers.sorted { $0.lastName < $1.lastName }
                self.manifests = fetchedManifests.sorted { $0.createdDate > $1.createdDate }
                self.lastSyncDate = Date()
                self.syncError = nil
                self.isSyncing = false
                
                print("✅ Synced \(fetchedPassengers.count) passengers and \(fetchedManifests.count) manifests")
            }
            
            saveToCache()
            
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
                print("❌ Sync failed: \(error)")
            }
        }
    }
    
    private func fetchAllRecords(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let (results, nextCursor) = try await privateDatabase.records(matching: query, cursor: cursor)
            
            for (_, result) in results {
                switch result {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    print("⚠️ Failed to fetch record: \(error)")
                }
            }
            
            cursor = nextCursor
        } while cursor != nil
        
        return allRecords
    }
    
    // MARK: - Passenger Management
    func savePassenger(_ passenger: Passenger) async throws {
        await MainActor.run { isSyncing = true }
        
        let record = passenger.toCloudKitRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            
            if let updatedPassenger = Passenger.fromCloudKitRecord(savedRecord) {
                await MainActor.run {
                    if let index = self.passengers.firstIndex(where: { $0.id == updatedPassenger.id }) {
                        self.passengers[index] = updatedPassenger
                    } else {
                        self.passengers.append(updatedPassenger)
                        self.passengers.sort { $0.lastName < $1.lastName }
                    }
                    self.isSyncing = false
                    print("✅ Saved passenger: \(updatedPassenger.fullName)")
                }
                
                saveToCache()
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            throw error
        }
    }
    
    func deletePassenger(_ passenger: Passenger) async throws {
        guard let recordID = passenger.recordID else {
            throw NSError(domain: "EAPISCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record ID found"])
        }
        
        await MainActor.run { isSyncing = true }
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            
            await MainActor.run {
                self.passengers.removeAll { $0.id == passenger.id }
                self.isSyncing = false
                print("✅ Deleted passenger: \(passenger.fullName)")
            }
            
            saveToCache()
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            throw error
        }
    }
    
    func getPassenger(byID id: String) -> Passenger? {
        passengers.first { $0.id == id }
    }
    
    func getPassengers(byIDs ids: [String]) -> [Passenger] {
        passengers.filter { ids.contains($0.id) }
    }
    
    func getFavoritePassengers() -> [Passenger] {
        passengers.filter { $0.isFavorite }
    }
    
    // MARK: - Manifest Management
    func saveManifest(_ manifest: EAPISManifest) async throws {
        await MainActor.run { isSyncing = true }
        
        let record = manifest.toCloudKitRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            
            if let updatedManifest = EAPISManifest.fromCloudKitRecord(savedRecord) {
                await MainActor.run {
                    if let index = self.manifests.firstIndex(where: { $0.id == updatedManifest.id }) {
                        self.manifests[index] = updatedManifest
                    } else {
                        self.manifests.append(updatedManifest)
                        self.manifests.sort { $0.createdDate > $1.createdDate }
                    }
                    self.isSyncing = false
                    print("✅ Saved manifest: \(updatedManifest.flightNumber)")
                }
                
                saveToCache()
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            throw error
        }
    }
    
    func deleteManifest(_ manifest: EAPISManifest) async throws {
        guard let recordID = manifest.recordID else {
            throw NSError(domain: "EAPISCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record ID found"])
        }
        
        await MainActor.run { isSyncing = true }
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            
            await MainActor.run {
                self.manifests.removeAll { $0.id == manifest.id }
                self.isSyncing = false
                print("✅ Deleted manifest: \(manifest.flightNumber)")
            }
            
            saveToCache()
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            throw error
        }
    }
    
    func getManifest(byID id: String) -> EAPISManifest? {
        manifests.first { $0.id == id }
    }
    
    func getManifests(forTripID tripID: String) -> [EAPISManifest] {
        manifests.filter { $0.tripID == tripID }
    }
    
    func getDraftManifests() -> [EAPISManifest] {
        manifests.filter { $0.status == .draft }
    }
    
    func getFiledManifests() -> [EAPISManifest] {
        manifests.filter { $0.status == .filed }
    }
}

// MARK: - Cache Structure
private struct EAPISCache: Codable {
    var passengers: [Passenger]
    var manifests: [EAPISManifest]
    var lastSyncDate: Date
}
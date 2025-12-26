//
//  CloudKitDataRepairUtility.swift
//  USA Jet Calc
//
//  One-time utility to repair corrupted CloudKit records
//  Run this once, then delete this file
//

import Foundation
import CloudKit
import SwiftData

/// Utility to fix corrupted CD_SDFlightLeg records where CD_logpage is a STRING instead of REFERENCE
class CloudKitDataRepairUtility {
    
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.jkadans.ProPilotApp")
        self.database = container.privateCloudDatabase
    }
    
    /// Run the repair process
    func repairCorruptedRecords() async throws {
        print("🔧 Starting CloudKit data repair...")
        
        // Step 1: Query for all CD_SDFlightLeg records
        let query = CKQuery(recordType: "CD_SDFlightLeg", predicate: NSPredicate(value: true))
        
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let (results, nextCursor) = try await fetchRecords(query: query, cursor: cursor)
            allRecords.append(contentsOf: results)
            cursor = nextCursor
            
            print("📦 Fetched \(results.count) records (total: \(allRecords.count))")
        } while cursor != nil
        
        // Step 2: Identify corrupted records
        var corruptedRecords: [CKRecord] = []
        
        for record in allRecords {
            // Check if CD_logpage exists and is a String
            if let logpageValue = record["CD_logpage"] as? String {
                print("⚠️ Found corrupted record: \(record.recordID.recordName) - CD_logpage is STRING: \(logpageValue)")
                corruptedRecords.append(record)
            }
        }
        
        print("📊 Found \(corruptedRecords.count) corrupted records out of \(allRecords.count) total")
        
        guard !corruptedRecords.isEmpty else {
            print("✅ No corrupted records found!")
            return
        }
        
        // Step 3: Delete corrupted records
        print("🗑️ Deleting \(corruptedRecords.count) corrupted records...")
        
        try await deleteRecords(corruptedRecords)
        
        print("✅ Successfully deleted corrupted records")
        print("📝 SwiftData will recreate these records on next sync")
    }
    
    /// Fetch records with pagination
    private func fetchRecords(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        return try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            var fetchedRecords: [CKRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    print("⚠️ Failed to fetch record \(recordID): \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (fetchedRecords, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    /// Delete records in batches
    private func deleteRecords(_ records: [CKRecord]) async throws {
        let recordIDs = records.map { $0.recordID }
        let batchSize = 100
        
        for i in stride(from: 0, to: recordIDs.count, by: batchSize) {
            let batch = Array(recordIDs[i..<min(i + batchSize, recordIDs.count)])
            
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("✅ Deleted batch of \(batch.count) records")
                        continuation.resume()
                    case .failure(let error):
                        print("❌ Failed to delete batch: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                
                database.add(operation)
            }
        }
    }
}

// MARK: - Convenience Extension
extension CloudKitDataRepairUtility {
    
    /// Run repair and print results
    static func runRepair() {
        Task {
            do {
                let utility = CloudKitDataRepairUtility()
                try await utility.repairCorruptedRecords()
                
                print("✅ CloudKit repair completed successfully!")
                print("📱 Restart your app to resync data")
                
            } catch {
                print("❌ CloudKit repair failed: \(error)")
                
                if let ckError = error as? CKError {
                    print("   CKError code: \(ckError.code)")
                    print("   Description: \(ckError.localizedDescription)")
                }
            }
        }
    }
}

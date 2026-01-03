//
//  DataIntegrityManager.swift
//  ProPilot
//
//  Multi-layer data protection system to prevent data loss
//

import Foundation
import SwiftData

@MainActor
class DataIntegrityManager {
    static let shared = DataIntegrityManager()
    
    private let appGroupID = "group.com.propilot.app"
    private var backupTimer: Timer?
    
    private init() {}
    
    // MARK: - Automatic Backup System
    
    /// Start automatic backups every 24 hours
    func startAutomaticBackups(logbookStore: SwiftDataLogBookStore) {
        // Initial backup on startup
        createDailyBackup(logbookStore: logbookStore)
        
        // Schedule daily backups
        backupTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.createDailyBackup(logbookStore: logbookStore)
            }
        }
        
        print("✅ Automatic daily backups enabled")
    }
    
    /// Create a timestamped backup in App Group container
    func createDailyBackup(logbookStore: SwiftDataLogBookStore) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            print("❌ Cannot access App Group for backup")
            return
        }
        
        let backupDir = containerURL.appendingPathComponent("Backups")
        
        // Create backups directory if needed
        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        
        // Create timestamped backup
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        let backupFilename = "logbook_backup_\(timestamp).json"
        let backupURL = backupDir.appendingPathComponent(backupFilename)
        
        // Export current data
        guard let data = logbookStore.exportToJSON() else {
            print("❌ Failed to export data for backup")
            return
        }
        
        do {
            try data.write(to: backupURL)
            print("✅ Daily backup created: \(backupFilename)")
            
            // Verify backup integrity
            if verifyBackup(at: backupURL, expectedTripCount: logbookStore.trips.count) {
                print("✅ Backup verified: \(logbookStore.trips.count) trips")
                
                // Update last backup time
                UserDefaults(suiteName: appGroupID)?.set(Date(), forKey: "lastBackupTime")
                
                // Cleanup old backups (keep last 30 days)
                cleanupOldBackups(in: backupDir)
            } else {
                print("❌ Backup verification failed!")
                // Don't delete the backup - keep it for investigation
            }
        } catch {
            print("❌ Backup creation failed: \(error)")
        }
    }
    
    /// Verify backup file integrity
    private func verifyBackup(at url: URL, expectedTripCount: Int) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try to decode the backup
            let backup = try decoder.decode(ExportData.self, from: data)
            
            // Verify trip count matches
            if backup.trips.count != expectedTripCount {
                print("⚠️ Backup trip count mismatch: got \(backup.trips.count), expected \(expectedTripCount)")
                return false
            }
            
            // Verify legs exist in trips
            let totalLegs = backup.trips.reduce(0) { $0 + $1.legs.count }
            if totalLegs == 0 && expectedTripCount > 0 {
                print("⚠️ Backup has 0 legs but has trips!")
                return false
            }
            
            print("✅ Backup verified: \(backup.trips.count) trips, \(totalLegs) legs")
            return true
            
        } catch {
            print("❌ Backup verification error: \(error)")
            return false
        }
    }
    
    /// Delete backups older than 30 days
    private func cleanupOldBackups(in directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            var deletedCount = 0
            
            for file in files {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < thirtyDaysAgo {
                    try? FileManager.default.removeItem(at: file)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🗑️ Cleaned up \(deletedCount) old backups")
            }
        } catch {
            print("⚠️ Backup cleanup error: \(error)")
        }
    }
    
    // MARK: - Data Integrity Checks
    
    /// Perform integrity check on SwiftData
    func performIntegrityCheck(logbookStore: SwiftDataLogBookStore) -> IntegrityCheckResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        let tripCount = logbookStore.trips.count
        let totalLegs = logbookStore.trips.reduce(0) { $0 + $1.legs.count }
        let totalLogpages = logbookStore.trips.reduce(0) { $0 + $1.logpages.count }
        
        // Check 1: Trips exist but no legs
        if tripCount > 0 && totalLegs == 0 {
            issues.append("CRITICAL: \(tripCount) trips exist but 0 legs found!")
        }
        
        // Check 2: Trips without logpages
        let tripsWithoutLogpages = logbookStore.trips.filter { $0.logpages.isEmpty && !$0.legs.isEmpty }
        if !tripsWithoutLogpages.isEmpty {
            warnings.append("\(tripsWithoutLogpages.count) trips have legs but no logpages")
        }
        
        // Check 3: Logpages without legs
        for trip in logbookStore.trips {
            for logpage in trip.logpages {
                if logpage.legs.isEmpty {
                    warnings.append("Trip #\(trip.tripNumber) has empty logpage")
                }
            }
        }
        
        // Check 4: Duplicate trip IDs
        let tripIDs = logbookStore.trips.map { $0.id }
        let uniqueIDs = Set(tripIDs)
        if tripIDs.count != uniqueIDs.count {
            issues.append("CRITICAL: Duplicate trip IDs found!")
        }
        
        // Check 5: CloudKit sync status
        // (SwiftData handles this automatically, but we can log it)
        
        let result = IntegrityCheckResult(
            tripCount: tripCount,
            legCount: totalLegs,
            logpageCount: totalLogpages,
            issues: issues,
            warnings: warnings,
            timestamp: Date()
        )
        
        // Log results
        if issues.isEmpty && warnings.isEmpty {
            print("✅ Data integrity check PASSED")
            print("   Trips: \(tripCount), Legs: \(totalLegs), Logpages: \(totalLogpages)")
        } else {
            print("⚠️ Data integrity check found issues:")
            for issue in issues {
                print("   ❌ \(issue)")
            }
            for warning in warnings {
                print("   ⚠️ \(warning)")
            }
        }
        
        return result
    }
    
    /// Perform integrity check after every save
    func verifySaveIntegrity(logbookStore: SwiftDataLogBookStore, operation: String) {
        let result = performIntegrityCheck(logbookStore: logbookStore)
        
        if !result.issues.isEmpty {
            print("🚨 SAVE INTEGRITY FAILURE after \(operation)!")
            print("   Creating emergency backup...")
            createEmergencyBackup(logbookStore: logbookStore, reason: operation)
        }
    }
    
    /// Create an emergency backup when data loss is detected
    private func createEmergencyBackup(logbookStore: SwiftDataLogBookStore, reason: String) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return
        }
        
        let backupDir = containerURL.appendingPathComponent("EmergencyBackups")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "EMERGENCY_\(timestamp)_\(reason.replacingOccurrences(of: " ", with: "_")).json"
        let backupURL = backupDir.appendingPathComponent(filename)
        
        if let data = logbookStore.exportToJSON() {
            try? data.write(to: backupURL)
            print("🆘 Emergency backup created: \(filename)")
        }
    }
    
    // MARK: - Recovery Options
    
    /// List all available backups
    func getAvailableBackups() -> [BackupInfo] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return []
        }
        
        var backups: [BackupInfo] = []
        
        // Check for migration backup
        let migrationBackupURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")
        if FileManager.default.fileExists(atPath: migrationBackupURL.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: migrationBackupURL.path),
               let size = attributes[.size] as? Int64,
               let date = attributes[.creationDate] as? Date {
                backups.append(BackupInfo(
                    name: "Pre-Migration Backup",
                    url: migrationBackupURL,
                    date: date,
                    size: size,
                    type: .migration
                ))
            }
        }
        
        // Check daily backups
        let backupDir = containerURL.appendingPathComponent("Backups")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) {
            for file in files where file.pathExtension == "json" {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64,
                   let date = attributes[.creationDate] as? Date {
                    backups.append(BackupInfo(
                        name: file.lastPathComponent,
                        url: file,
                        date: date,
                        size: size,
                        type: .daily
                    ))
                }
            }
        }
        
        // Check emergency backups
        let emergencyDir = containerURL.appendingPathComponent("EmergencyBackups")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: emergencyDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) {
            for file in files where file.pathExtension == "json" {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64,
                   let date = attributes[.creationDate] as? Date {
                    backups.append(BackupInfo(
                        name: file.lastPathComponent,
                        url: file,
                        date: date,
                        size: size,
                        type: .emergency
                    ))
                }
            }
        }
        
        // Sort by date (newest first)
        return backups.sorted { $0.date > $1.date }
    }
}

// MARK: - Data Models

struct IntegrityCheckResult {
    let tripCount: Int
    let legCount: Int
    let logpageCount: Int
    let issues: [String]
    let warnings: [String]
    let timestamp: Date
    
    var isPassing: Bool {
        issues.isEmpty
    }
    
    var hasCriticalIssues: Bool {
        !issues.isEmpty
    }
}

struct BackupInfo: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let date: Date
    let size: Int64
    let type: BackupType
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum BackupType {
    case migration
    case daily
    case emergency
    
    var displayName: String {
        switch self {
        case .migration: return "Migration Backup"
        case .daily: return "Daily Backup"
        case .emergency: return "Emergency Backup"
        }
    }
    
    var icon: String {
        switch self {
        case .migration: return "arrow.triangle.2.circlepath"
        case .daily: return "clock.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .migration: return "blue"
        case .daily: return "green"
        case .emergency: return "orange"
        }
    }
}

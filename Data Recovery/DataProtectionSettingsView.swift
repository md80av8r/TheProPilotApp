//
//  DataProtectionSettingsView.swift
//  ProPilot
//
//  Settings view for data protection and backup management
//

import SwiftUI

struct DataProtectionSettingsView: View {
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @State private var integrityResult: IntegrityCheckResult?
    @State private var availableBackups: [BackupInfo] = []
    @State private var isCheckingIntegrity = false
    @State private var showingRecovery = false
    @State private var lastBackupDate: Date?
    @State private var cloudKitStatus: String = "Checking..."
    @State private var showingCloudKitReset = false
    @State private var isResettingCloudKit = false
    @State private var cloudKitResetResult: String?
    @State private var showingDeleteAllData = false
    @State private var isDeletingData = false
    @State private var showingResetDatabase = false
    @State private var databaseResetResult: String?
    
    var body: some View {
        List {
            // Data Integrity Status
            Section {
                if let result = integrityResult {
                    HStack {
                        Image(systemName: result.isPassing ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.isPassing ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Integrity")
                                .font(.headline)
                            Text(result.isPassing ? "All checks passed" : "\(result.issues.count) issues found")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if !result.isPassing {
                            Button("Details") {
                                // Show details alert
                            }
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    
                    HStack {
                        Text("Trips:")
                        Spacer()
                        Text("\(result.tripCount)")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Legs:")
                        Spacer()
                        Text("\(result.legCount)")
                            .foregroundColor(result.legCount == 0 && result.tripCount > 0 ? .red : .gray)
                    }
                    
                    HStack {
                        Text("Logpages:")
                        Spacer()
                        Text("\(result.logpageCount)")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("No integrity check performed yet")
                        .foregroundColor(.gray)
                }
                
                Button(action: performIntegrityCheck) {
                    HStack {
                        if isCheckingIntegrity {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield")
                        }
                        Text("Run Integrity Check")
                    }
                }
                .disabled(isCheckingIntegrity)
            } header: {
                Text("Data Integrity")
            }
            
            // Backup Status
            Section {
                if let lastBackup = lastBackupDate {
                    HStack {
                        Text("Last Backup:")
                        Spacer()
                        Text(timeAgo(from: lastBackup))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("No recent backups")
                        .foregroundColor(.gray)
                }
                
                Button(action: createManualBackup) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Create Backup Now")
                    }
                }
                
                NavigationLink(destination: BackupListView(backups: availableBackups, logbookStore: logbookStore)) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("View All Backups")
                        Spacer()
                        Text("\(availableBackups.count)")
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("Automatic Backups")
            } footer: {
                Text("Backups are created daily and kept for 30 days. Emergency backups are created when data issues are detected.")
            }
            
            // Recovery Options
            Section {
                Button(action: { showingRecovery = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundColor(.orange)
                        Text("Data Recovery")
                        Spacer()
                        if integrityResult?.hasCriticalIssues == true {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            } header: {
                Text("Recovery")
            } footer: {
                if integrityResult?.hasCriticalIssues == true {
                    Text("⚠️ Data integrity issues detected! Use Data Recovery to restore from backup.")
                        .foregroundColor(.orange)
                } else {
                    Text("Restore data from backups if needed")
                }
            }
            
            // CloudKit Sync Status
            Section {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(cloudKitStatus)
                        .foregroundColor(cloudKitStatus.contains("Error") || cloudKitStatus.contains("Blocked") ? .red : .gray)
                }

                Text("SwiftData + CloudKit automatically syncs your data across all your devices.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: { showingCloudKitReset = true }) {
                    HStack {
                        Image(systemName: "exclamationmark.icloud.fill")
                            .foregroundColor(.red)
                        Text("Reset CloudKit Zone")
                    }
                }
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("If CloudKit sync is blocked due to corrupted records, use Reset CloudKit Zone to clear all iCloud data. Your local data will be re-uploaded.")
                    .foregroundColor(.orange)
            }

            // Danger Zone
            Section {
                Button(action: { showingDeleteAllData = true }) {
                    HStack {
                        if isDeletingData {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                        Text("Delete All Local Data")
                            .foregroundColor(.red)
                    }
                }
                .disabled(isDeletingData)

                Button(action: { showingResetDatabase = true }) {
                    HStack {
                        Image(systemName: "cylinder.split.1x2.fill")
                            .foregroundColor(.red)
                        Text("Reset Database Schema")
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("'Delete All Local Data' removes records but keeps schema. 'Reset Database Schema' deletes the SQLite file completely - use this if CloudKit sync fails with schema type errors. App will restart.")
                    .foregroundColor(.red)
            }
        }
        .alert("Reset CloudKit Zone?", isPresented: $showingCloudKitReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetCloudKitZone()
            }
        } message: {
            Text("This will DELETE ALL your data from iCloud and re-upload from this device. Other devices will re-download the data. Use this only if CloudKit sync is completely blocked.\n\nMake sure you have a recent backup first!")
        }
        .alert("CloudKit Reset", isPresented: .constant(cloudKitResetResult != nil)) {
            Button("OK") { cloudKitResetResult = nil }
        } message: {
            Text(cloudKitResetResult ?? "")
        }
        .alert("Delete All Local Data?", isPresented: $showingDeleteAllData) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                deleteAllLocalData()
            }
        } message: {
            Text("This will permanently delete ALL \(logbookStore.trips.count) trips and their flight data from this device.\n\nThis CANNOT be undone!\n\nMake sure you have a JSON backup before proceeding.")
        }
        .alert("Reset Database Schema?", isPresented: $showingResetDatabase) {
            Button("Cancel", role: .cancel) { }
            Button("Reset & Restart", role: .destructive) {
                resetDatabaseSchema()
            }
        } message: {
            Text("This will DELETE the local SQLite database file completely, forcing SwiftData to recreate it with a fresh schema.\n\nUse this if CloudKit sync fails with 'STRING for field defined to be REFERENCE' errors.\n\nThe app will close. After reopening, import your backup.\n\nMake sure you have a JSON backup first!")
        }
        .alert("Database Reset", isPresented: .constant(databaseResetResult != nil)) {
            Button("OK") {
                databaseResetResult = nil
                // Force app exit after user acknowledges
                exit(0)
            }
        } message: {
            Text(databaseResetResult ?? "")
        }
        .navigationTitle("Data Protection")
        .onAppear {
            loadBackupStatus()
            performIntegrityCheck()
            checkCloudKitStatus()
        }
        .sheet(isPresented: $showingRecovery) {
            DataRecoveryView(logbookStore: logbookStore)
        }
    }
    
    private func loadBackupStatus() {
        if let defaults = UserDefaults(suiteName: "group.com.propilot.app") {
            lastBackupDate = defaults.object(forKey: "lastBackupTime") as? Date
        }
        
        availableBackups = DataIntegrityManager.shared.getAvailableBackups()
    }
    
    private func performIntegrityCheck() {
        isCheckingIntegrity = true
        
        Task { @MainActor in
            integrityResult = DataIntegrityManager.shared.performIntegrityCheck(logbookStore: logbookStore)
            isCheckingIntegrity = false
        }
    }
    
    private func createManualBackup() {
        Task { @MainActor in
            DataIntegrityManager.shared.createDailyBackup(logbookStore: logbookStore)
            loadBackupStatus()
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)

        if hours < 1 {
            return "Less than 1 hour ago"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    private func checkCloudKitStatus() {
        Task {
            let result = await SwiftDataConfiguration.checkCloudKitStatus()
            await MainActor.run {
                if result.available {
                    // Check for errors in CloudKitErrorHandler
                    if CloudKitErrorHandler.shared.corruptedRecordCount > 0 {
                        cloudKitStatus = "Blocked - \(CloudKitErrorHandler.shared.corruptedRecordCount) corrupted records"
                    } else if !CloudKitErrorHandler.shared.syncStatus.isHealthy {
                        cloudKitStatus = "Error - Check console"
                    } else {
                        cloudKitStatus = "Available"
                    }
                } else {
                    cloudKitStatus = result.error ?? "Unavailable"
                }
            }
        }
    }

    private func resetCloudKitZone() {
        isResettingCloudKit = true

        Task {
            do {
                try await SwiftDataConfiguration.resetCloudKitZone()

                await MainActor.run {
                    isResettingCloudKit = false
                    cloudKitResetResult = "CloudKit zone reset successfully! Your local data will be re-uploaded on next sync. Please restart the app."
                    cloudKitStatus = "Reset complete - restart app"
                }
            } catch {
                await MainActor.run {
                    isResettingCloudKit = false
                    cloudKitResetResult = "Failed to reset CloudKit zone: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteAllLocalData() {
        isDeletingData = true

        Task {
            let success = await logbookStore.deleteAllData()

            await MainActor.run {
                isDeletingData = false
                if success {
                    // Refresh integrity check to show 0 trips
                    performIntegrityCheck()
                }
            }
        }
    }

    private func resetDatabaseSchema() {
        let success = SwiftDataConfiguration.deleteLocalDatabase()

        if success {
            databaseResetResult = "Database files deleted successfully!\n\nThe app will now close. When you reopen it, SwiftData will create a fresh database with the correct schema.\n\nRemember to import your backup after restarting."
        } else {
            databaseResetResult = "Failed to delete some database files. Try closing the app completely and using this function again."
        }
    }
}

// MARK: - Backup List View

struct BackupListView: View {
    let backups: [BackupInfo]
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @State private var selectedBackup: BackupInfo?
    @State private var showingRestoreConfirm = false
    
    var body: some View {
        List {
            if backups.isEmpty {
                Text("No backups available")
                    .foregroundColor(.gray)
            } else {
                ForEach(backups) { backup in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: backup.type.icon)
                                .foregroundColor(colorForType(backup.type))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.type.displayName)
                                    .font(.headline)
                                Text(backup.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(backup.formattedSize)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Button("Restore from this backup") {
                            selectedBackup = backup
                            showingRestoreConfirm = true
                        }
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Backups")
        .alert("Restore Backup?", isPresented: $showingRestoreConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                if let backup = selectedBackup {
                    restoreBackup(backup)
                }
            }
        } message: {
            Text("This will replace your current data with the backup. Current data will be backed up first. This cannot be undone.")
        }
    }
    
    private func colorForType(_ type: BackupType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        default: return .gray
        }
    }
    
    private func restoreBackup(_ backup: BackupInfo) {
        // Create emergency backup of current state first
        DataIntegrityManager.shared.createDailyBackup(logbookStore: logbookStore)
        
        // Load backup file
        do {
            let data = try Data(contentsOf: backup.url)
            let result = logbookStore.importFromJSON(data, mergeWithExisting: false)
            
            if result.success {
                print("✅ Backup restored successfully")
            } else {
                print("❌ Backup restore failed: \(result.message)")
            }
        } catch {
            print("❌ Failed to load backup: \(error)")
        }
    }
}

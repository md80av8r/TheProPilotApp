//
//  CloudKitSettingsView.swift
//  USA Jet Calc
//
//  User-facing settings for managing CloudKit sync
//

import SwiftUI
import CloudKit

struct CloudKitSettingsView: View {
    @EnvironmentObject var store: SwiftDataLogBookStore
    @ObservedObject private var errorHandler = CloudKitErrorHandler.shared
    @ObservedObject private var migrationHelper = CloudKitMigrationHelper.shared
    @State private var iCloudAccountStatus: String = "Checking..."
    @State private var showingMigrationConfirmation = false
    @State private var showingCleanupConfirmation = false

    var body: some View {
        List {
            // MARK: - Current Status Section
            Section {
                HStack {
                    Image(systemName: syncStatusIcon)
                        .foregroundColor(syncStatusColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync")
                            .font(.headline)
                        
                        Text(errorHandler.syncStatus.displayMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 12, height: 12)
                }
                .padding(.vertical, 4)
                
                if errorHandler.corruptedRecordCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ \(errorHandler.corruptedRecordCount) Legacy Records")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        Text("Some old records can't sync due to format changes. Your current data is safe and syncing normally.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Sync Status")
            }
            
            // MARK: - Account Info Section
            Section {
                HStack {
                    Text("iCloud Account")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(iCloudAccountStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Account")
            }
            
            // MARK: - Troubleshooting Section
            if errorHandler.shouldShowWarning || errorHandler.corruptedRecordCount > 0 {
                Section {
                    if let advice = errorHandler.userAdvice {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What's happening?", systemImage: "info.circle")
                                .font(.subheadline.bold())
                            
                            Text(advice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button(action: {
                        // Open iOS Settings to iCloud
                        if let url = URL(string: "App-prefs:CASTLE") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Open iCloud Settings", systemImage: "gear")
                    }
                    
                } header: {
                    Text("Troubleshooting")
                } footer: {
                    Text("Your local data is always safe. CloudKit sync will retry automatically when possible.")
                        .font(.caption2)
                }
            }
            
            // MARK: - Legacy Data Migration Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Legacy CloudKit Migration", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.bold())

                    Text("If you have trips from an older version that aren't showing up, you may need to migrate them to the new SwiftData format.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Migration status
                    migrationStatusView

                    // Action buttons
                    if !migrationHelper.migrationStatus.isInProgress {
                        Button {
                            Task {
                                await migrationHelper.checkForLegacyData()
                            }
                        } label: {
                            Label("Check for Legacy Data", systemImage: "magnifyingglass")
                        }

                        if case .legacyDataFound(let count) = migrationHelper.migrationStatus {
                            Button {
                                showingMigrationConfirmation = true
                            } label: {
                                Label("Migrate \(count) Trips", systemImage: "arrow.right.circle")
                            }
                            .foregroundColor(.blue)
                        }

                        if case .completed = migrationHelper.migrationStatus {
                            Button {
                                showingCleanupConfirmation = true
                            } label: {
                                Label("Cleanup Legacy Records", systemImage: "trash")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Data Migration")
            } footer: {
                Text("Legacy data migration imports trips from the old CloudKit format into SwiftData.")
                    .font(.caption2)
            }

            // MARK: - Recovery Options Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("How to Fix Sync Issues", systemImage: "lifepreserver")
                        .font(.subheadline.bold())

                    Text("""
                    If you're experiencing persistent sync problems:

                    1. Go to Data & Backup tab
                    2. Tap "Export Flight Data" to create a backup
                    3. Sign out of iCloud on this device (Settings app)
                    4. Sign back into iCloud
                    5. Tap "Import Flight Data" to restore your backup

                    This will give you a fresh sync without losing any data.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)

            } header: {
                Text("Recovery Options")
            }
            
            // MARK: - About Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About iCloud Sync")
                        .font(.subheadline.bold())
                    
                    Text("""
                    ProPilot uses iCloud to keep your data in sync across all your devices. \
                    Your data is stored locally first and then synced to iCloud in the background.
                    
                    • Data is always safe on your device
                    • Sync happens automatically
                    • Works across iPhone, iPad, and Apple Watch
                    • Requires iCloud account with available storage
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkiCloudAccountStatus()
        }
        .alert("Migrate Legacy Data?", isPresented: $showingMigrationConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Migrate") {
                Task {
                    await migrationHelper.migrateLegacyData(to: store, mergeWithExisting: true)
                }
            }
        } message: {
            Text("This will import \(migrationHelper.legacyTripCount) trips from the old CloudKit format into SwiftData. Existing trips will be preserved.")
        }
        .alert("Cleanup Legacy Records?", isPresented: $showingCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Cleanup", role: .destructive) {
                Task {
                    await migrationHelper.cleanupLegacyRecords()
                }
            }
        } message: {
            Text("This will delete the old CloudKit records. Only do this after confirming all your trips are visible in the app. This cannot be undone.")
        }
    }

    // MARK: - Migration Status View
    @ViewBuilder
    private var migrationStatusView: some View {
        switch migrationHelper.migrationStatus {
        case .idle:
            EmptyView()

        case .checking:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Checking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .noLegacyData:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("No legacy data found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .legacyDataFound(let count):
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Found \(count) trips to migrate")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

        case .migrating(let progress):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                Text(migrationHelper.progressMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        case .completed(let imported, let skipped):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Imported \(imported), skipped \(skipped)")
                    .font(.caption)
                    .foregroundColor(.green)
            }

        case .failed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var syncStatusIcon: String {
        switch errorHandler.syncStatus {
        case .idle:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .success:
            return "checkmark.icloud.fill"
        case .partialFailure:
            return "exclamationmark.icloud"
        case .failed:
            return "xmark.icloud"
        }
    }
    
    private var syncStatusColor: Color {
        switch errorHandler.syncStatus {
        case .idle, .syncing:
            return .blue
        case .success:
            return .green
        case .partialFailure:
            return .orange
        case .failed:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func checkiCloudAccountStatus() {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    iCloudAccountStatus = "Signed In"
                case .noAccount:
                    iCloudAccountStatus = "Not Signed In"
                case .restricted:
                    iCloudAccountStatus = "Restricted"
                case .couldNotDetermine:
                    iCloudAccountStatus = "Unknown"
                case .temporarilyUnavailable:
                    iCloudAccountStatus = "Temporarily Unavailable"
                @unknown default:
                    iCloudAccountStatus = "Unknown"
                }
            }
        }
    }
}

// MARK: - Preview
struct CloudKitSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CloudKitSettingsView()
        }
    }
}

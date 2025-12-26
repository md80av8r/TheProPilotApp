//
//  CloudKitSettingsView.swift
//  USA Jet Calc
//
//  User-facing settings for managing CloudKit sync
//

import SwiftUI
import CloudKit

struct CloudKitSettingsView: View {
    @ObservedObject private var errorHandler = CloudKitErrorHandler.shared
    @State private var iCloudAccountStatus: String = "Checking..."
    
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
            
            // MARK: - Recovery Options Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("How to Fix Sync Issues", systemImage: "lifepreserver")
                        .font(.subheadline.bold())
                    
                    Text("""
                    If you're experiencing persistent sync problems:
                    
                    1. Go to Documents & Data tab
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

//
//  ContainerMigrationWarning.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/2/26.
//

import SwiftUI
import CloudKit

// MARK: - Migration Warning Manager
class MigrationWarningManager: ObservableObject {
    static let shared = MigrationWarningManager()
    
    private let hasShownWarningKey = "HasShownContainerMigrationWarning"
    private let remindNextLaunchKey = "RemindAboutContainerMigration"
    private let hasCheckedContainerKey = "HasCheckedOldContainer"
    
    // Container identifiers
    private let oldContainerIdentifier = "iCloud.com.jkadans.ProPilotApp"  // OLD container
    private let newContainerIdentifier = "iCloud.com.jkadans.TheProPilotApp"  // NEW container (current)
    
    @Published var shouldShowWarning = false
    @Published var isCheckingContainer = true
    
    private init() {
        checkIfWarningNeeded()
    }
    
    func checkIfWarningNeeded() {
        // First check if we've already determined the answer
        let hasChecked = UserDefaults.standard.bool(forKey: hasCheckedContainerKey)
        let hasShown = UserDefaults.standard.bool(forKey: hasShownWarningKey)
        let remindNext = UserDefaults.standard.bool(forKey: remindNextLaunchKey)
        
        // If we've already checked and user chose "remind me", show warning
        if hasChecked && remindNext {
            shouldShowWarning = true
            isCheckingContainer = false
            return
        }
        
        // If we've already shown and user dismissed, don't show
        if hasShown && !remindNext {
            shouldShowWarning = false
            isCheckingContainer = false
            return
        }
        
        // Otherwise, check if user is on old container
        checkForOldContainer()
    }
    
    private func checkForOldContainer() {
        Task {
            let hasOldData = await hasDataInOldContainer()
            
            await MainActor.run {
                // Only show warning if user has data in OLD container
                shouldShowWarning = hasOldData
                isCheckingContainer = false
                
                // Mark that we've checked
                UserDefaults.standard.set(true, forKey: hasCheckedContainerKey)
                
                if hasOldData {
                    print("🚨 User has data in OLD container - showing migration warning")
                } else {
                    print("✅ User is on NEW container or no data - no warning needed")
                }
            }
        }
    }
    
    /// Check if user has any data in the OLD container
    private func hasDataInOldContainer() async -> Bool {
        let oldContainer = CKContainer(identifier: oldContainerIdentifier)
        let privateDB = oldContainer.privateCloudDatabase
        
        do {
            // Try to query for ANY Trip records in old container
            let query = CKQuery(recordType: "Trip", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // Fetch just 1 record to see if data exists
            let results = try await privateDB.records(
                matching: query,
                resultsLimit: 1
            )
            
            let hasRecords = !results.matchResults.isEmpty
            
            if hasRecords {
                print("🔍 Found Trip records in old container - user needs migration")
            } else {
                print("🔍 No Trip records in old container - user is new or already migrated")
            }
            
            return hasRecords
            
        } catch let error as CKError {
            // Handle specific CloudKit errors
            switch error.code {
            case .notAuthenticated:
                print("ℹ️ User not signed into iCloud - no warning needed")
                return false
                
            case .networkUnavailable, .networkFailure:
                print("⚠️ Network error checking container - assume no warning needed")
                return false
                
            case .permissionFailure:
                print("ℹ️ No permission to old container - user likely never used it")
                return false
                
            default:
                print("⚠️ CloudKit error checking old container: \(error.localizedDescription)")
                // On error, don't show warning (better to not bother user)
                return false
            }
            
        } catch {
            print("⚠️ Error checking old container: \(error)")
            return false
        }
    }
    
    func markWarningShown(remindNext: Bool) {
        UserDefaults.standard.set(true, forKey: hasShownWarningKey)
        UserDefaults.standard.set(remindNext, forKey: remindNextLaunchKey)
        shouldShowWarning = false
    }
    
    func resetWarning() {
        UserDefaults.standard.removeObject(forKey: hasShownWarningKey)
        UserDefaults.standard.removeObject(forKey: remindNextLaunchKey)
        UserDefaults.standard.removeObject(forKey: hasCheckedContainerKey)
        shouldShowWarning = true
    }
}

// MARK: - Migration Warning View
struct ContainerMigrationWarningView: View {
    @ObservedObject var manager = MigrationWarningManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingBackupOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Warning Icon
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.orange)
                        .padding(.top, 40)
                    
                    Text("Important: Data Migration Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Main Warning
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This version uses a new iCloud container")
                                .font(.headline)
                            
                            Text("Your existing data will NOT automatically transfer to this version. This is a one-time change to improve sync reliability and performance.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                        
                        // What This Means
                        VStack(alignment: .leading, spacing: 12) {
                            Label("What This Means", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Your old data remains in the previous version")
                                bulletPoint("This version starts with a fresh database")
                                bulletPoint("You must backup your data BEFORE uninstalling the old version")
                                bulletPoint("Backups can be restored to the new version")
                            }
                            .font(.callout)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        
                        // Action Required
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Action Required", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("1. Keep your old app version installed")
                                .font(.callout)
                                .fontWeight(.semibold)
                            
                            Text("2. Open the old version and create a backup")
                                .font(.callout)
                                .fontWeight(.semibold)
                            
                            Text("3. Save the backup file to Files app or email it to yourself")
                                .font(.callout)
                                .fontWeight(.semibold)
                            
                            Text("4. Then you can safely delete the old version")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                        
                        // Backup Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Label("How to Backup", systemImage: "externaldrive.fill")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Text("In the OLD app version:")
                                .font(.callout)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Tap 'More' tab")
                                bulletPoint("Select 'Backup & Restore'")
                                bulletPoint("Tap 'Create Backup'")
                                bulletPoint("Save the .proplgbk file")
                            }
                            .font(.callout)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                        )
                        
                        // Restore Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Label("How to Restore", systemImage: "arrow.clockwise.circle.fill")
                                .font(.headline)
                                .foregroundColor(.indigo)
                            
                            Text("In THIS app version (after backup):")
                                .font(.callout)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Tap 'More' tab")
                                bulletPoint("Select 'Backup & Restore'")
                                bulletPoint("Tap 'Restore from Backup'")
                                bulletPoint("Select your saved .proplgbk file")
                            }
                            .font(.callout)
                            
                            Button(action: {
                                showingBackupOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Go to Backup & Restore Now")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.indigo.opacity(0.1))
                        )
                    }
                    .padding()
                }
                
                // Bottom Actions
                VStack(spacing: 12) {
                    Button(action: {
                        manager.markWarningShown(remindNext: false)
                        dismiss()
                    }) {
                        Text("I Understand - Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        manager.markWarningShown(remindNext: true)
                        dismiss()
                    }) {
                        Text("Remind Me Next Launch")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Migration Warning")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .interactiveDismissDisabled(true) // Prevent swipe to dismiss
        .sheet(isPresented: $showingBackupOptions) {
            NavigationView {
                DataBackupSettingsView()
            }
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .fontWeight(.bold)
            Text(text)
            Spacer()
        }
    }
}

// MARK: - Quick Access Link from Settings
struct MigrationWarningSettingsRow: View {
    @ObservedObject var manager = MigrationWarningManager.shared
    @State private var showingWarning = false
    
    var body: some View {
        Button(action: {
            showingWarning = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Container Migration Info")
                        .foregroundColor(.primary)
                    Text("Important backup instructions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showingWarning) {
            ContainerMigrationWarningView()
        }
    }
}

// MARK: - Compact Alert Version (for inline display)
struct ContainerMigrationBanner: View {
    @ObservedObject var manager = MigrationWarningManager.shared
    @State private var showingFullWarning = false
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed && manager.shouldShowWarning {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Important: Backup Required")
                            .font(.headline)
                        Text("Data migration needed for this version")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isDismissed = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                
                HStack(spacing: 12) {
                    Button("Learn More") {
                        showingFullWarning = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    Button("Remind Later") {
                        manager.markWarningShown(remindNext: true)
                        isDismissed = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        manager.markWarningShown(remindNext: false)
                        isDismissed = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .background(Color.orange.opacity(0.15))
            }
            .sheet(isPresented: $showingFullWarning) {
                ContainerMigrationWarningView()
            }
        }
    }
}

// MARK: - Preview
#Preview("Full Warning") {
    ContainerMigrationWarningView()
}

#Preview("Banner") {
    VStack {
        ContainerMigrationBanner()
        Spacer()
    }
}

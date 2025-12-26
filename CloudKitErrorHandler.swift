//
//  CloudKitErrorHandler.swift
//  USA Jet Calc
//
//  Handles CloudKit sync errors gracefully without disrupting users
//

import Foundation
import SwiftUI
import CloudKit

/// Production-safe CloudKit error handler that allows app to continue functioning
/// even when CloudKit sync fails due to schema mismatches or corrupted records
class CloudKitErrorHandler: ObservableObject {
    
    static let shared = CloudKitErrorHandler()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncError: String?
    @Published var corruptedRecordCount: Int = 0
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case partialFailure(recordCount: Int)
        case failed(error: String)
        
        var isHealthy: Bool {
            switch self {
            case .idle, .syncing, .success:
                return true
            case .partialFailure, .failed:
                return false
            }
        }
        
        var displayMessage: String {
            switch self {
            case .idle:
                return "CloudKit sync ready"
            case .syncing:
                return "Syncing to iCloud..."
            case .success:
                return "Successfully synced to iCloud"
            case .partialFailure(let count):
                return "Synced with \(count) record(s) skipped"
            case .failed(let error):
                return "Sync error: \(error)"
            }
        }
    }
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Monitor NSPersistentCloudKitContainer sync notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitImportNotification),
            name: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil
        )
    }
    
    @objc private func handleCloudKitImportNotification(_ notification: Notification) {
        // Extract error information from the notification
        if let error = notification.userInfo?["error"] as? NSError {
            handleCloudKitError(error)
        }
    }
    
    // MARK: - Error Handling
    
    /// Process CloudKit errors and extract useful information
    func handleCloudKitError(_ error: Error) {
        let nsError = error as NSError
        
        // Log the error for debugging
        print("☁️ CloudKit Error: \(nsError.localizedDescription)")
        print("   Domain: \(nsError.domain)")
        print("   Code: \(nsError.code)")
        
        // Check if it's a CKError
        if let ckError = error as? CKError {
            handleCKError(ckError)
        } else {
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: nsError.localizedDescription)
                self.lastSyncError = nsError.localizedDescription
            }
        }
    }
    
    private func handleCKError(_ error: CKError) {
        switch error.code {
        case .partialFailure:
            handlePartialFailure(error)
            
        case .serverRecordChanged:
            print("⚠️ Server record changed - will retry")
            DispatchQueue.main.async {
                self.syncStatus = .syncing
            }
            
        case .networkUnavailable, .networkFailure:
            print("⚠️ Network unavailable - will retry when online")
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: "Network unavailable")
            }
            
        case .quotaExceeded:
            print("⚠️ iCloud storage quota exceeded")
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: "iCloud storage full")
                self.lastSyncError = "Your iCloud storage is full. Please free up space."
            }
            
        case .notAuthenticated:
            print("⚠️ User not signed into iCloud")
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: "Not signed in to iCloud")
                self.lastSyncError = "Please sign in to iCloud in Settings to sync your data."
            }
            
        default:
            print("⚠️ CloudKit error code: \(error.code.rawValue)")
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: error.localizedDescription)
                self.lastSyncError = error.localizedDescription
            }
        }
    }
    
    private func handlePartialFailure(_ error: CKError) {
        guard let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] else {
            print("⚠️ Partial failure with no detailed errors")
            return
        }
        
        var invalidArgumentCount = 0
        var otherErrorCount = 0
        
        for (recordID, recordError) in partialErrors {
            if let ckError = recordError as? CKError {
                switch ckError.code {
                case .serverRejectedRequest:
                    // This is likely our schema mismatch error
                    invalidArgumentCount += 1
                    print("⚠️ Server rejected record: \(recordID)")
                    
                case .batchRequestFailed:
                    // Skip these - they're cascading failures
                    continue
                    
                default:
                    otherErrorCount += 1
                    print("⚠️ Record error for \(recordID): \(ckError.code.rawValue)")
                }
            }
        }
        
        let totalFailed = invalidArgumentCount + otherErrorCount
        
        DispatchQueue.main.async {
            self.corruptedRecordCount = totalFailed
            self.syncStatus = .partialFailure(recordCount: totalFailed)
            
            if invalidArgumentCount > 0 {
                self.lastSyncError = """
                CloudKit sync partially failed due to \(invalidArgumentCount) legacy record(s) \
                with incompatible format. Your local data is safe. These legacy records will be \
                skipped during sync.
                """
                
                print("""
                ⚠️ PARTIAL SYNC FAILURE SUMMARY:
                   - Invalid/Legacy records: \(invalidArgumentCount)
                   - Other errors: \(otherErrorCount)
                   - User impact: None (local data is safe)
                   - Action: No user action required
                """)
            }
        }
    }
    
    // MARK: - User-Facing Status
    
    /// Check if the user should be shown a warning
    var shouldShowWarning: Bool {
        switch syncStatus {
        case .failed, .partialFailure:
            return true
        case .idle, .syncing, .success:
            return false
        }
    }
    
    /// Get user-friendly advice for resolving sync issues
    var userAdvice: String? {
        switch syncStatus {
        case .failed(let error):
            if error.contains("iCloud") || error.contains("storage") {
                return "Free up iCloud storage space to resume syncing."
            } else if error.contains("Network") {
                return "Check your internet connection and try again."
            } else if error.contains("signed in") {
                return "Sign in to iCloud in Settings to enable sync."
            }
            return "Your data is safe locally. CloudKit sync will retry automatically."
            
        case .partialFailure:
            return """
            Some legacy records couldn't sync to iCloud, but your current data is safe and syncing normally. \
            You can use Settings → Backup & Restore to create a local backup if needed.
            """
            
        default:
            return nil
        }
    }
    
    // MARK: - Recovery Options
    
    /// Check if user should be offered recovery options
    var canOfferRecovery: Bool {
        return corruptedRecordCount > 0
    }
    
    /// Options for recovering from sync errors
    enum RecoveryOption {
        case ignoreAndContinue
        case resetCloudKitData
        case disableCloudKit
        case contactSupport
        
        var title: String {
            switch self {
            case .ignoreAndContinue:
                return "Continue Anyway"
            case .resetCloudKitData:
                return "Reset iCloud Data"
            case .disableCloudKit:
                return "Disable iCloud Sync"
            case .contactSupport:
                return "Contact Support"
            }
        }
        
        var description: String {
            switch self {
            case .ignoreAndContinue:
                return "Your local data is safe. Legacy records will be skipped."
            case .resetCloudKitData:
                return "Clear all iCloud data and re-sync from this device. Other devices will re-download."
            case .disableCloudKit:
                return "Turn off iCloud sync and use only local storage."
            case .contactSupport:
                return "Get help from the developer."
            }
        }
    }
}

// MARK: - SwiftUI Status View

struct CloudKitStatusBanner: View {
    @ObservedObject var errorHandler = CloudKitErrorHandler.shared
    @State private var isExpanded = false
    
    var body: some View {
        if errorHandler.shouldShowWarning {
            VStack(spacing: 8) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        
                        Text(errorHandler.syncStatus.displayMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                
                if isExpanded, let advice = errorHandler.userAdvice {
                    Text(advice)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .background(statusBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var statusIcon: String {
        switch errorHandler.syncStatus {
        case .failed:
            return "exclamationmark.icloud.fill"
        case .partialFailure:
            return "icloud.slash.fill"
        default:
            return "icloud.fill"
        }
    }
    
    private var statusColor: Color {
        switch errorHandler.syncStatus {
        case .failed:
            return .red
        case .partialFailure:
            return .orange
        default:
            return .green
        }
    }
    
    private var statusBackgroundColor: Color {
        switch errorHandler.syncStatus {
        case .failed:
            return Color.red.opacity(0.1)
        case .partialFailure:
            return Color.orange.opacity(0.1)
        default:
            return Color.green.opacity(0.1)
        }
    }
}

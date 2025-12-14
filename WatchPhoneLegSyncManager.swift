//
//  WatchPhoneLegSyncManager.swift
//  TheProPilotApp
//
//  Ensures Watch and iPhone stay in sync regarding which leg is active
//

import Foundation
import Combine

/// Manages synchronization of leg indices between Watch and iPhone to prevent conflicts
class WatchPhoneLegSyncManager: ObservableObject {
    static let shared = WatchPhoneLegSyncManager()
    
    @Published var currentLegIndex: Int = 0
    @Published var totalLegs: Int = 0
    @Published var syncConflictDetected: Bool = false
    @Published var lastKnownPhoneLegIndex: Int?
    @Published var lastKnownWatchLegIndex: Int?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSyncMonitoring()
    }
    
    private func setupSyncMonitoring() {
        // Monitor for sync conflicts every 5 seconds
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForSyncConflicts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Validation
    
    /// Validates leg index from a source (Watch or Phone) and detects conflicts
    func validateLegIndex(source: LegSource, legIndex: Int, totalLegs: Int) -> LegValidationResult {
        print("🔄 Validating leg from \(source.rawValue): leg \(legIndex + 1) of \(totalLegs)")
        
        // Store the reported index from each source
        switch source {
        case .phone:
            lastKnownPhoneLegIndex = legIndex
        case .watch:
            lastKnownWatchLegIndex = legIndex
        }
        
        // Check for conflict
        if let phoneIndex = lastKnownPhoneLegIndex,
           let watchIndex = lastKnownWatchLegIndex,
           phoneIndex != watchIndex {
            
            print("⚠️ LEG SYNC CONFLICT DETECTED!")
            print("   Phone thinks: Leg \(phoneIndex + 1)")
            print("   Watch thinks: Leg \(watchIndex + 1)")
            
            syncConflictDetected = true
            
            // Phone is always the source of truth
            let correctIndex = phoneIndex
            let conflictingIndex = watchIndex
            
            return .conflict(
                correctIndex: correctIndex,
                conflictingIndex: conflictingIndex,
                resolution: .usePhoneAsSource
            )
        }
        
        // Valid range check
        if legIndex < 0 || legIndex >= totalLegs {
            print("❌ Invalid leg index: \(legIndex) (total legs: \(totalLegs))")
            return .invalid(reason: "Leg index out of range")
        }
        
        // All good!
        currentLegIndex = legIndex
        self.totalLegs = totalLegs
        syncConflictDetected = false
        
        print("✅ Leg validation passed: Leg \(legIndex + 1) of \(totalLegs)")
        return .valid
    }
    
    /// Check for sync conflicts between devices
    func checkForSyncConflicts() {
        guard let phoneIndex = lastKnownPhoneLegIndex,
              let watchIndex = lastKnownWatchLegIndex else {
            // Don't have data from both sources yet
            return
        }
        
        if phoneIndex != watchIndex {
            print("⚠️ ONGOING SYNC CONFLICT: Phone=Leg\(phoneIndex+1), Watch=Leg\(watchIndex+1)")
            syncConflictDetected = true
            
            // Send sync correction message
            NotificationCenter.default.post(
                name: .legSyncConflictDetected,
                object: nil,
                userInfo: [
                    "phoneIndex": phoneIndex,
                    "watchIndex": watchIndex,
                    "correctIndex": phoneIndex // Phone is source of truth
                ]
            )
        }
    }
    
    /// Force synchronization - phone always wins
    func forceSyncFromPhone(legIndex: Int, totalLegs: Int) {
        print("🔄 FORCE SYNC: Setting all devices to Leg \(legIndex + 1) of \(totalLegs)")
        
        currentLegIndex = legIndex
        self.totalLegs = totalLegs
        lastKnownPhoneLegIndex = legIndex
        lastKnownWatchLegIndex = legIndex // Assume Watch will sync
        syncConflictDetected = false
        
        // Notify that sync has been forced
        NotificationCenter.default.post(
            name: .legSyncForced,
            object: nil,
            userInfo: [
                "legIndex": legIndex,
                "totalLegs": totalLegs
            ]
        )
    }
    
    /// Handle new leg addition
    func handleNewLegAdded(source: LegSource, newTotalLegs: Int) {
        print("➕ New leg added from \(source.rawValue)")
        print("   Previous total: \(totalLegs)")
        print("   New total: \(newTotalLegs)")
        
        // New leg becomes the current leg
        let newLegIndex = newTotalLegs - 1
        
        switch source {
        case .phone:
            lastKnownPhoneLegIndex = newLegIndex
            currentLegIndex = newLegIndex
            totalLegs = newTotalLegs
            
            // Notify Watch to sync
            NotificationCenter.default.post(
                name: .newLegAddedOnPhone,
                object: nil,
                userInfo: [
                    "legIndex": newLegIndex,
                    "totalLegs": newTotalLegs
                ]
            )
            
        case .watch:
            lastKnownWatchLegIndex = newLegIndex
            
            // Need to sync with phone
            NotificationCenter.default.post(
                name: .newLegAddedOnWatch,
                object: nil,
                userInfo: [
                    "legIndex": newLegIndex,
                    "totalLegs": newTotalLegs
                ]
            )
        }
    }
    
    /// Get human-readable sync status
    func getSyncStatusDescription() -> String {
        if syncConflictDetected {
            return "⚠️ Devices out of sync"
        }
        
        if lastKnownPhoneLegIndex == nil || lastKnownWatchLegIndex == nil {
            return "Waiting for sync..."
        }
        
        return "✅ In sync - Leg \(currentLegIndex + 1) of \(totalLegs)"
    }
    
    /// Reset sync state
    func reset() {
        currentLegIndex = 0
        totalLegs = 0
        syncConflictDetected = false
        lastKnownPhoneLegIndex = nil
        lastKnownWatchLegIndex = nil
        
        print("🔄 Leg sync state reset")
    }
}

// MARK: - Supporting Types

enum LegSource: String {
    case phone = "iPhone"
    case watch = "Apple Watch"
}

enum LegValidationResult {
    case valid
    case invalid(reason: String)
    case conflict(correctIndex: Int, conflictingIndex: Int, resolution: ConflictResolution)
}

enum ConflictResolution {
    case usePhoneAsSource
    case useWatchAsSource
    case manualReview
}


// MARK: - Sync Conflict Alert View

import SwiftUI

struct LegSyncConflictAlert: View {
    let phoneLegIndex: Int
    let watchLegIndex: Int
    let onResolved: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Leg Sync Conflict")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "iphone")
                    Text("iPhone thinks you're on:")
                    Spacer()
                    Text("Leg \(phoneLegIndex + 1)")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Image(systemName: "applewatch")
                    Text("Watch thinks you're on:")
                    Spacer()
                    Text("Leg \(watchLegIndex + 1)")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Text("Using iPhone as source of truth")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: {
                // Force sync from phone
                WatchPhoneLegSyncManager.shared.forceSyncFromPhone(
                    legIndex: phoneLegIndex,
                    totalLegs: WatchPhoneLegSyncManager.shared.totalLegs
                )
                onResolved()
            }) {
                Text("Sync Watch to iPhone")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

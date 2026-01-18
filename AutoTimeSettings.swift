import Foundation
import SwiftUI

// MARK: - Settings for Auto Time Logging
// ✅ UNIFIED STORAGE: All settings use App Group for iPhone/Watch sync
class AutoTimeSettings: ObservableObject {
    static let shared = AutoTimeSettings()

    private let appGroup = UserDefaults(suiteName: "group.com.propilot.app")

    // ✅ Use computed properties with willSet to trigger objectWillChange
    var useZuluTime: Bool {
        get { appGroup?.bool(forKey: "useZuluTime") ?? true }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "useZuluTime")
        }
    }

    var roundTimesToFiveMinutes: Bool {
        get { appGroup?.bool(forKey: "roundTimesToFiveMinutes") ?? false }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "roundTimesToFiveMinutes")
        }
    }

    var takeoffSpeedThreshold: Double {
        get { appGroup?.double(forKey: "takeoffSpeedThreshold") ?? 80.0 }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "takeoffSpeedThreshold")
        }
    }

    var landingSpeedThreshold: Double {
        get { appGroup?.double(forKey: "landingSpeedThreshold") ?? 40.0 }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "landingSpeedThreshold")
        }
    }

    var isEnabled: Bool {
        get { appGroup?.bool(forKey: "autoTimeLoggingEnabled") ?? false }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "autoTimeLoggingEnabled")
        }
    }

    var trackRecordingEnabled: Bool {
        get { appGroup?.bool(forKey: "trackRecordingEnabled") ?? false }
        set {
            objectWillChange.send()
            appGroup?.set(newValue, forKey: "trackRecordingEnabled")
        }
    }

    private init() {
        print("✅ AutoTimeSettings initialized with App Group storage")
        print("   useZuluTime: \(useZuluTime)")
        print("   roundTimesToFiveMinutes: \(roundTimesToFiveMinutes)")
        
        // Migration: Copy old values from standard UserDefaults to App Group (one-time)
        migrateSettingsToAppGroup()
    }
    
    /// Migrate settings from old UserDefaults.standard to App Group (one-time migration)
    private func migrateSettingsToAppGroup() {
        guard let appGroup = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("⚠️ Could not access App Group for migration")
            return
        }
        
        // Check if migration already happened
        if appGroup.bool(forKey: "hasMingratedSettings") {
            return
        }
        
        let standard = UserDefaults.standard
        
        // Migrate each setting if it exists in standard but not in app group
        if standard.object(forKey: "useZuluTime") != nil && appGroup.object(forKey: "useZuluTime") == nil {
            let value = standard.bool(forKey: "useZuluTime")
            appGroup.set(value, forKey: "useZuluTime")
            print("📦 Migrated useZuluTime: \(value)")
        }
        
        if standard.object(forKey: "roundTimesToFiveMinutes") != nil && appGroup.object(forKey: "roundTimesToFiveMinutes") == nil {
            let value = standard.bool(forKey: "roundTimesToFiveMinutes")
            appGroup.set(value, forKey: "roundTimesToFiveMinutes")
            print("📦 Migrated roundTimesToFiveMinutes: \(value)")
        }
        
        if standard.object(forKey: "takeoffSpeedThreshold") != nil && appGroup.object(forKey: "takeoffSpeedThreshold") == nil {
            let value = standard.double(forKey: "takeoffSpeedThreshold")
            appGroup.set(value, forKey: "takeoffSpeedThreshold")
            print("📦 Migrated takeoffSpeedThreshold: \(value)")
        }
        
        if standard.object(forKey: "landingSpeedThreshold") != nil && appGroup.object(forKey: "landingSpeedThreshold") == nil {
            let value = standard.double(forKey: "landingSpeedThreshold")
            appGroup.set(value, forKey: "landingSpeedThreshold")
            print("📦 Migrated landingSpeedThreshold: \(value)")
        }
        
        if standard.object(forKey: "autoTimeLoggingEnabled") != nil && appGroup.object(forKey: "autoTimeLoggingEnabled") == nil {
            let value = standard.bool(forKey: "autoTimeLoggingEnabled")
            appGroup.set(value, forKey: "autoTimeLoggingEnabled")
            print("📦 Migrated autoTimeLoggingEnabled: \(value)")
        }
        
        // Mark migration as complete
        appGroup.set(true, forKey: "hasMigratedSettings")
        print("✅ Settings migration to App Group complete")
    }
}

// UserDefaults+AppGroup.swift
import Foundation

extension UserDefaults {
    /// Shared UserDefaults for App Group communication
    /// Using your actual App Group ID: group.com.propilot.app
    static var appGroup: UserDefaults? {
        return UserDefaults(suiteName: "group.com.propilot.app")
    }
    
    /// Convenience property for cleaner code
    static var shared: UserDefaults {
        return appGroup ?? UserDefaults.standard
    }
    
    // MARK: - ✅ Time Rounding Preference

    /// Whether to round flight times to nearest 5-minute increment
    var roundTimesToFiveMinutes: Bool {
        get {
            return bool(forKey: "roundTimesToFiveMinutes")
        }
        set {
            set(newValue, forKey: "roundTimesToFiveMinutes")
            // ❌ REMOVED synchronize() - UserDefaults saves automatically
            print("⏱️ Time rounding preference updated: \(newValue)")
        }
    }
    
    // MARK: - Migration
    
    /// One-time migration from .standard to App Group
    /// Call this once on app launch to migrate existing data
    static func migrateToAppGroup() {
        guard let appGroupDefaults = UserDefaults.appGroup else {
            print("❌ App Group UserDefaults not available - skipping migration")
            return
        }
        
        // Check if migration already completed
        if appGroupDefaults.bool(forKey: "userDefaultsMigrationComplete") {
            print("✅ UserDefaults migration already completed")
            return
        }
        
        let standardDefaults = UserDefaults.standard
        
        // Add keys that need to be migrated
        let keysToMigrate = [
            "flightAwareUsername",
            "flightAwareAPIKey",
            "createScannerPreferences",
            "airlineSettings",
            "emailSettings",
            "logbookSettings",
            "lastDutyStart",
            "currentFlight",
            "watchConnectivity",
            "roundTimesToFiveMinutes"  // ✅ ADD THIS to migration list
        ]
        
        var migrationCount = 0
        
        for key in keysToMigrate {
            if let value = standardDefaults.object(forKey: key),
               appGroupDefaults.object(forKey: key) == nil {
                appGroupDefaults.set(value, forKey: key)
                migrationCount += 1
                print("📱 Migrated UserDefaults key: \(key)")
            }
        }
        
        // Only synchronize if we actually migrated something
        if migrationCount > 0 {
            appGroupDefaults.synchronize()
            print("📱 Migrated \(migrationCount) UserDefaults keys to App Group")
        }
        
        // Mark migration as complete
        appGroupDefaults.set(true, forKey: "userDefaultsMigrationComplete")
        appGroupDefaults.synchronize()
        
        print("✅ UserDefaults migration to App Group completed")
    }
}

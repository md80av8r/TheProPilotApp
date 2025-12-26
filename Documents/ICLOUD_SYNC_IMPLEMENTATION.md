# iCloud Sync for Airport Code Mappings

## Overview

Implementing iCloud sync for learned airport code mappings enables:
- **Multi-device sync** - Use ProPilot on iPad, iPhone, and multiple devices
- **Automatic backup** - Never lose learned mappings
- **Seamless transitions** - Switch devices without losing data
- **Crowd-sourced learning** - (Optional future) Share anonymous mappings with community

## Implementation Strategy

### Phase 1: NSUbiquitousKeyValueStore (Simple & Fast)

**Best for**: Small amounts of data (up to 1MB), perfect for airport mappings

```swift
// UserAirportCodeMappings.swift - Enhanced with iCloud

import Foundation
import Combine

class UserAirportCodeMappings: ObservableObject {
    static let shared = UserAirportCodeMappings()
    
    @Published var mappings: [String: String] = [:]
    
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let localStore = UserDefaults(suiteName: "group.com.propilot.app")!
    private let mappingsKey = "UserAirportMappings"
    private let lastSyncKey = "LastMappingsSyncDate"
    
    // Sync settings
    @Published var iCloudSyncEnabled = true
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case success(Date)
        case error(String)
        case conflict  // Local and iCloud differ
    }
    
    private init() {
        loadMappings()
        setupiCloudSync()
    }
    
    // MARK: - iCloud Sync Setup
    
    private func setupiCloudSync() {
        // Listen for iCloud changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        
        // Initial sync from iCloud
        syncFromiCloud()
    }
    
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        print("☁️ iCloud store changed externally - syncing...")
        
        guard let userInfo = notification.userInfo,
              let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        // Handle different change reasons
        switch reasonForChange {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Data changed on another device or initial sync
            syncFromiCloud()
            
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("⚠️ iCloud quota exceeded for key-value store")
            syncStatus = .error("iCloud storage quota exceeded")
            
        case NSUbiquitousKeyValueStoreAccountChange:
            print("⚠️ iCloud account changed")
            handleAccountChange()
            
        default:
            break
        }
    }
    
    // MARK: - Load & Save
    
    private func loadMappings() {
        // Try iCloud first, then fall back to local
        if let iCloudData = iCloudStore.data(forKey: mappingsKey),
           let iCloudMappings = try? JSONDecoder().decode([String: String].self, from: iCloudData) {
            print("☁️ Loaded \(iCloudMappings.count) mappings from iCloud")
            mappings = iCloudMappings
            
            // Also save to local for offline access
            saveToLocal(iCloudMappings)
            
        } else if let localData = localStore.data(forKey: mappingsKey),
                  let localMappings = try? JSONDecoder().decode([String: String].self, from: localData) {
            print("💾 Loaded \(localMappings.count) mappings from local storage")
            mappings = localMappings
            
            // Push to iCloud if it's empty
            if iCloudStore.data(forKey: mappingsKey) == nil {
                pushToiCloud()
            }
        }
    }
    
    func addMapping(iata: String, icao: String) {
        let cleanIATA = iata.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanICAO = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        mappings[cleanIATA] = cleanICAO
        
        // Save to both local and iCloud
        saveToLocal(mappings)
        
        if iCloudSyncEnabled {
            pushToiCloud()
        }
        
        print("✅ Added mapping: \(cleanIATA) → \(cleanICAO)")
    }
    
    func removeMapping(iata: String) {
        let cleanIATA = iata.uppercased()
        mappings.removeValue(forKey: cleanIATA)
        
        saveToLocal(mappings)
        
        if iCloudSyncEnabled {
            pushToiCloud()
        }
        
        print("🗑️ Removed mapping: \(cleanIATA)")
    }
    
    // MARK: - Sync Methods
    
    private func saveToLocal(_ mappings: [String: String]) {
        if let data = try? JSONEncoder().encode(mappings) {
            localStore.set(data, forKey: mappingsKey)
            localStore.synchronize()
        }
    }
    
    private func pushToiCloud() {
        guard iCloudSyncEnabled else { return }
        
        syncStatus = .syncing
        
        if let data = try? JSONEncoder().encode(mappings) {
            iCloudStore.set(data, forKey: mappingsKey)
            iCloudStore.set(Date(), forKey: lastSyncKey)
            
            // Synchronize immediately (async, non-blocking)
            if iCloudStore.synchronize() {
                lastSyncDate = Date()
                syncStatus = .success(Date())
                print("☁️ Pushed \(mappings.count) mappings to iCloud")
            } else {
                syncStatus = .error("Failed to sync with iCloud")
                print("❌ Failed to push to iCloud")
            }
        }
    }
    
    private func syncFromiCloud() {
        guard iCloudSyncEnabled else { return }
        
        syncStatus = .syncing
        
        // Get iCloud mappings
        guard let iCloudData = iCloudStore.data(forKey: mappingsKey),
              let iCloudMappings = try? JSONDecoder().decode([String: String].self, from: iCloudData) else {
            syncStatus = .idle
            return
        }
        
        // Get local mappings
        let localMappings = mappings
        
        // Detect conflicts
        if !localMappings.isEmpty && iCloudMappings != localMappings {
            // Merge strategy: Union of both, iCloud wins on conflicts
            let merged = mergeConflicts(local: localMappings, iCloud: iCloudMappings)
            
            DispatchQueue.main.async {
                self.mappings = merged
                self.saveToLocal(merged)
                self.lastSyncDate = Date()
                self.syncStatus = .success(Date())
                
                print("☁️ Merged mappings: Local \(localMappings.count), iCloud \(iCloudMappings.count), Result \(merged.count)")
            }
        } else {
            // No conflict, just use iCloud
            DispatchQueue.main.async {
                self.mappings = iCloudMappings
                self.saveToLocal(iCloudMappings)
                self.lastSyncDate = Date()
                self.syncStatus = .success(Date())
                
                print("☁️ Synced \(iCloudMappings.count) mappings from iCloud")
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func mergeConflicts(local: [String: String], iCloud: [String: String]) -> [String: String] {
        var merged = local
        
        // Add all iCloud mappings
        for (iata, icao) in iCloud {
            if let existingICAO = merged[iata], existingICAO != icao {
                // Conflict detected!
                print("⚠️ Conflict for \(iata): Local=\(existingICAO), iCloud=\(icao)")
                
                // Strategy: iCloud wins (most recent edit likely on another device)
                merged[iata] = icao
                
                // Future: Could prompt user or use timestamps
            } else {
                merged[iata] = icao
            }
        }
        
        return merged
    }
    
    private func handleAccountChange() {
        // User signed out of iCloud or changed accounts
        // Keep local data but stop syncing
        print("⚠️ iCloud account changed - keeping local data")
        syncStatus = .error("iCloud account changed")
        
        // Re-attempt sync after delay (they might have just signed in)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.syncFromiCloud()
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func forceSyncNow() {
        print("🔄 Manual sync triggered")
        syncFromiCloud()
        pushToiCloud()
    }
    
    // MARK: - Public API
    
    func getICAO(for iata: String) -> String? {
        return mappings[iata.uppercased()]
    }
    
    var sortedMappings: [(iata: String, icao: String)] {
        return mappings.map { ($0.key, $0.value) }
            .sorted { $0.iata < $1.iata }
    }
}
```

### Phase 2: CloudKit (Advanced Features)

**Best for**: Larger datasets, user-contributed content, advanced sync

```swift
// AirportMappingsCloudKitManager.swift

import CloudKit
import Combine

class AirportMappingsCloudKitManager: ObservableObject {
    static let shared = AirportMappingsCloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.jkadans.ProPilotApp")
    private let privateDatabase: CKDatabase
    
    // Record types
    private let mappingRecordType = "AirportMapping"
    
    @Published var cloudMappings: [CloudAirportMapping] = []
    @Published var syncInProgress = false
    @Published var lastError: Error?
    
    struct CloudAirportMapping: Identifiable {
        let id: String  // CKRecord.ID
        let iata: String
        let icao: String
        let createdDate: Date
        let modifiedDate: Date
        let deviceID: String  // Which device learned this
        let learnedAutomatically: Bool
        let verifiedByCoordinates: Bool
    }
    
    private init() {
        privateDatabase = container.privateCloudDatabase
        setupSubscriptions()
    }
    
    // MARK: - CloudKit Operations
    
    func uploadMapping(_ iata: String, _ icao: String, learnedAuto: Bool, verified: Bool) {
        let record = CKRecord(recordType: mappingRecordType)
        record["iata"] = iata as CKRecordValue
        record["icao"] = icao as CKRecordValue
        record["createdDate"] = Date() as CKRecordValue
        record["deviceID"] = UIDevice.current.identifierForVendor?.uuidString as CKRecordValue?
        record["learnedAutomatically"] = learnedAuto ? 1 : 0 as CKRecordValue
        record["verifiedByCoordinates"] = verified ? 1 : 0 as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                print("❌ CloudKit save error: \(error.localizedDescription)")
                self.lastError = error
            } else {
                print("☁️ Uploaded mapping to CloudKit: \(iata) → \(icao)")
            }
        }
    }
    
    func fetchAllMappings() {
        syncInProgress = true
        
        let query = CKQuery(recordType: mappingRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                self.syncInProgress = false
                
                if let error = error {
                    print("❌ CloudKit fetch error: \(error.localizedDescription)")
                    self.lastError = error
                    return
                }
                
                guard let records = records else { return }
                
                self.cloudMappings = records.compactMap { record in
                    guard let iata = record["iata"] as? String,
                          let icao = record["icao"] as? String,
                          let created = record["createdDate"] as? Date else {
                        return nil
                    }
                    
                    return CloudAirportMapping(
                        id: record.recordID.recordName,
                        iata: iata,
                        icao: icao,
                        createdDate: created,
                        modifiedDate: record.modificationDate ?? created,
                        deviceID: record["deviceID"] as? String ?? "unknown",
                        learnedAutomatically: (record["learnedAutomatically"] as? Int) == 1,
                        verifiedByCoordinates: (record["verifiedByCoordinates"] as? Int) == 1
                    )
                }
                
                print("☁️ Fetched \(self.cloudMappings.count) mappings from CloudKit")
            }
        }
    }
    
    // MARK: - Live Sync with Subscriptions
    
    private func setupSubscriptions() {
        // Subscribe to changes in airport mappings
        let subscription = CKQuerySubscription(
            recordType: mappingRecordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification
        
        privateDatabase.save(subscription) { subscription, error in
            if let error = error {
                print("❌ CloudKit subscription error: \(error.localizedDescription)")
            } else {
                print("☁️ CloudKit subscription created")
            }
        }
    }
}
```

## UI Implementation

### Settings View with iCloud Status

```swift
// EnhancedAirportMappingsView.swift - Updated with iCloud

struct EnhancedAirportMappingsView: View {
    @StateObject private var mappings = UserAirportCodeMappings.shared
    @StateObject private var unknownManager = UnknownAirportCodeManager.shared
    
    var body: some View {
        List {
            // iCloud Sync Status Section
            Section {
                HStack {
                    Image(systemName: cloudIcon)
                        .foregroundColor(cloudColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $mappings.iCloudSyncEnabled)
                }
                
                if let lastSync = mappings.lastSyncDate {
                    HStack {
                        Text("Last synced")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Button {
                    mappings.forceSyncNow()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Now")
                    }
                }
                .disabled(mappings.syncStatus == .syncing)
                
            } header: {
                Text("Cloud Storage")
            } footer: {
                Text("Sync learned airport codes across all your devices using iCloud. Your mappings are stored securely in your private iCloud account.")
            }
            .listRowBackground(LogbookTheme.fieldBackground)
            
            // Sync Statistics
            Section {
                HStack {
                    Text("Mappings stored")
                    Spacer()
                    Text("\(mappings.mappings.count)")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                HStack {
                    Text("Devices synced")
                    Spacer()
                    Text("This device + iCloud")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } header: {
                Text("Statistics")
            }
            .listRowBackground(LogbookTheme.fieldBackground)
            
            // Rest of the UI...
        }
    }
    
    private var cloudIcon: String {
        switch mappings.syncStatus {
        case .idle: return "icloud"
        case .syncing: return "icloud.and.arrow.up.fill"
        case .success: return "icloud.fill"
        case .error: return "icloud.slash"
        case .conflict: return "icloud.and.arrow.up.trianglebadge.exclamationmark"
        }
    }
    
    private var cloudColor: Color {
        switch mappings.syncStatus {
        case .idle, .success: return LogbookTheme.accentBlue
        case .syncing: return LogbookTheme.accentOrange
        case .error, .conflict: return .red
        }
    }
    
    private var syncStatusText: String {
        switch mappings.syncStatus {
        case .idle: return "Ready to sync"
        case .syncing: return "Syncing..."
        case .success(let date): return "Synced \(date.formatted(.relative(presentation: .named)))"
        case .error(let message): return "Error: \(message)"
        case .conflict: return "Conflicts detected"
        }
    }
}
```

## Setup Requirements

### 1. Enable iCloud in Xcode

**Target → Signing & Capabilities → + Capability → iCloud**

Enable:
- ☑️ Key-value storage
- ☑️ iCloud Documents (optional, for CloudKit)

### 2. Configure Entitlements

```xml
<!-- Info.plist additions already present -->
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.jkadans.ProPilotApp</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>ProPilot Documents</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
    </dict>
</dict>
```

### 3. Update RosterToTripHelper

No changes needed! The `UserAirportCodeMappings.shared` already handles sync transparently.

## Benefits

### For Users
✅ **Automatic sync** - Mappings appear on all devices instantly
✅ **Device upgrades** - Seamlessly move to new devices
✅ **No data loss** - Backed up to iCloud automatically
✅ **Multiple devices** - Use iPad for planning, iPhone for flying
✅ **Zero maintenance** - Works silently in background

### For the App
✅ **Built-in conflict resolution** - Handles multiple devices gracefully
✅ **Offline support** - Local cache works without internet
✅ **Bandwidth efficient** - Only syncs small key-value pairs
✅ **Native Apple technology** - No third-party services needed

## Testing Strategy

### Test Scenarios

1. **Single Device**
   - Add mapping → Should save to iCloud
   - Verify in console: "☁️ Pushed X mappings to iCloud"

2. **Two Devices (iPhone + iPad)**
   - Add mapping on iPhone → Wait 5 seconds → Check iPad
   - Should automatically appear on iPad

3. **Conflict Resolution**
   - Add "ABC → KABC" on iPhone (offline)
   - Add "ABC → MABC" on iPad (online)
   - Connect iPhone → Should merge (iCloud wins)

4. **Account Changes**
   - Sign out of iCloud → Mappings stay local
   - Sign back in → Sync resumes

5. **Network Issues**
   - Add mappings while offline
   - Go online → Should batch upload

## Performance Considerations

### NSUbiquitousKeyValueStore Limits
- **1MB total storage** (enough for ~10,000 mappings)
- **1024 keys maximum**
- **Sync frequency**: Every few seconds to minutes (Apple-controlled)

### Optimization
```swift
// Batch updates to avoid excessive syncs
private var pendingSyncTimer: Timer?

func addMapping(iata: String, icao: String) {
    mappings[iata] = icao
    saveToLocal(mappings)
    
    // Debounce iCloud sync
    pendingSyncTimer?.invalidate()
    pendingSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
        self.pushToiCloud()
    }
}
```

## Migration Strategy

### Existing Users
```swift
private func migrateToiCloud() {
    // Check if we have local mappings but haven't pushed to iCloud yet
    if !mappings.isEmpty && iCloudStore.data(forKey: mappingsKey) == nil {
        print("🔄 Migrating \(mappings.count) local mappings to iCloud...")
        pushToiCloud()
    }
}
```

## Future Enhancements

### Community Sharing (Optional)
```swift
// Anonymous, crowd-sourced mappings
// Users opt-in to share learned mappings with community
// Validated mappings (coordinates confirmed) get higher priority
// Privacy-preserving: No user identification, just IATA→ICAO pairs
```

### Smart Sync Priority
```swift
// Prioritize recently-used airports
// Download full database on WiFi only
// Keep 100 most-used mappings cached locally
```

### Sync Analytics
```swift
// Track sync success rates
// Alert user if sync hasn't worked in 7+ days
// Provide troubleshooting tips
```

## Recommendation

**Start with NSUbiquitousKeyValueStore (Phase 1)**

✅ Simple implementation (~100 lines of code)
✅ Automatic, transparent sync
✅ No complex setup
✅ Perfect for airport mappings (small data)
✅ Native iOS/iPadOS/macOS support

**Upgrade to CloudKit later if needed** (when/if):
- Want detailed sync history
- Need per-mapping metadata
- Want community sharing features
- Exceed 1MB limit (unlikely for airport codes)

This gives you 90% of the benefits with 10% of the complexity!

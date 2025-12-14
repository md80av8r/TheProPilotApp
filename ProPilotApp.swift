import SwiftUI
import CoreLocation
import BackgroundTasks
import UserNotifications
// 🔥 TEMPORARY: Firebase commented out until Jumpseat feature is ready
// import FirebaseCore
#if os(iOS)
import ActivityKit
#endif

@main
struct ProPilotApp: App {
    // FIXED: NOCSettingsStore and ScheduleStore created with proper dependency injection
    @StateObject private var nocSettings: NOCSettingsStore
    @StateObject private var scheduleStore: ScheduleStore
    
    // Other managers
    @StateObject private var activityManager = PilotActivityManager.shared
    @StateObject private var logbookStore = LogBookStore()
    @StateObject private var locationPermissionManager = LocationPermissionManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    // OPS Calling Manager for auto-call on airport arrival
    @StateObject private var opsCallingManager = OPSCallingManager()
    
    // Pilot Location Manager for geofencing and airport detection
    @StateObject private var pilotLocationManager = PilotLocationManager()
    
    // Backup file handler for incoming JSON files
    @StateObject private var backupFileHandler = BackupFileHandler.shared
    
    init() {
        // CRITICAL: Create single NOC instance and pass to ScheduleStore
        let noc = NOCSettingsStore()
        _nocSettings = StateObject(wrappedValue: noc)
        _scheduleStore = StateObject(wrappedValue: ScheduleStore(settings: noc))
        
        // Setup background tasks on app launch
        setupBackgroundTasks()
        
        // Setup notification delegate for handling taps
        setupNotificationDelegate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityManager)
                .environmentObject(logbookStore)
                .environmentObject(nocSettings)      // ← Single source of truth
                .environmentObject(scheduleStore)    // ← Gets NOC from init
                .environmentObject(cloudKitManager)  // ← CloudKit manager
                .tripImportHandler(store: logbookStore)  // ← Trip sharing import handling
                .backupImportHandler(store: logbookStore)               // ← Backup file import handling
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
                .onAppear {
                    initializeAppServices()
                }
                // FIXED: Pass logbookStore explicitly to avoid "No ObservableObject" crash
                .withTripGenerationAlerts(store: logbookStore)
                .onReceive(NotificationCenter.default.publisher(for: .nocAutoSyncSettingChanged)) { notification in
                    if let enabled = notification.userInfo?["enabled"] as? Bool {
                        if enabled {
                            scheduleNextRefresh()
                        } else {
                            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.jkadans.ProPilotApp.refresh")
                            print("🔕 Canceled NOC background refresh")
                        }
                    }
                }
        }
    }
    
    // MARK: - Notification Delegate Setup
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        print("✅ Notification delegate configured")
    }

    // MARK: - Incoming File Handler
    private func handleIncomingFile(_ url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        
        print("📁 Received file: \(url.lastPathComponent) (extension: \(fileExtension))")
        
        switch fileExtension {
        case "protrip":
            // Handle trip sharing files from crew members
            print("📦 Routing to TripSharingManager...")
            TripSharingManager.shared.handleIncomingFile(url)
            
        case "json":
            // Handle backup/restore JSON files
            print("📦 Routing to BackupFileHandler...")
            BackupFileHandler.shared.handleIncomingFile(url)
            
        case "zip":
            // Handle zipped backup files
            print("📦 Routing to BackupFileHandler (zip)...")
            BackupFileHandler.shared.handleIncomingFile(url)
            
        default:
            // Check if it's a deep link (propilot://)
            if url.scheme == "propilot" {
                handleDeepLink(url)
            } else {
                print("⚠️ Unknown file type: \(fileExtension)")
            }
        }
    }
    
    // MARK: - Background Tasks Setup
    private func setupBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.jkadans.ProPilotApp.refresh",
            using: nil
        ) { task in
            self.handleNOCRefreshTask(task as! BGAppRefreshTask)
        }
        print("✅ Background tasks registered")
    }
    
    // MARK: - App Initialization
    private func initializeAppServices() {
        print("🚀 Initializing ProPilot app services...")
        
        // 0. MIGRATE DATA TO APP GROUP FIRST (before anything else tries to load data)
        migrateToAppGroup()
        
        // 1. Initialize CloudKit sync
        print("🔄 Initializing CloudKit...")
        Task {
            await CloudKitManager.shared.checkiCloudStatus()
        }
        
        // 2. Request location permissions first (affects watch connectivity)
        setupLocationPermissions()
        
        // 3. Initialize Watch connectivity
        initializeWatchConnectivity()
        
        // 4. Set up monitoring for pending actions from AppIntents
        startMonitoringPendingActions()
        
        // 5. Check for data recovery on app launch
        checkForDataRecoveryNeeded()
        
        // 6. Set up Live Activities info
        setupLiveActivities()
        
        // 7. Sync trip creation settings to App Group
        TripCreationSettings.shared.syncToAppGroup()
        
        // 8. Cleanup expired dismissed items
        DismissedRosterItemsManager.shared.cleanupExpiredItems()

        // 9. Setup background sync if auto-sync is enabled
        if nocSettings.autoSyncEnabled {
            scheduleNextRefresh()
        }
        
        // 10. Sync from iCloud on app launch (wrap in Task for async call)
        Task {
            await logbookStore.syncFromCloud()
        }
        
        // 11. Add observer for app becoming active to sync from cloud
        let store = logbookStore
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await store.syncFromCloud()
            }
        }
        
        // 12. Initialize Trip Generation Service:
        TripGenerationService.shared.setupRosterDataListener(logbookStore: logbookStore)
            
        print("✅ App services initialization complete")
        
    }
      
    // MARK: - Background Sync Handlers
    private func handleNOCRefreshTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
            scheduleNextRefresh()
        }
        
        guard nocSettings.autoSyncEnabled else {
            print("⏭️ Auto-sync disabled, skipping")
            task.setTaskCompleted(success: true)
            return
        }
        
        // Throttle to hourly - check last sync time
        if let lastSync = nocSettings.lastSyncTime {
            let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
            if lastSync > hourAgo {
                let minutesSince = Int(Date().timeIntervalSince(lastSync) / 60)
                print("⏭️ NOC refresh skipped (synced \(minutesSince) minutes ago)")
                task.setTaskCompleted(success: true)
                scheduleNextRefresh()
                return
            }
        }
        
        print("🔄 Starting background NOC sync...")
        nocSettings.fetchRosterCalendar()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            let success = self.nocSettings.syncSuccess
            print(success ? "✅ Background NOC sync successful" : "❌ Background NOC sync failed")
            task.setTaskCompleted(success: success)
            self.scheduleNextRefresh()
        }
    }
    
    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.jkadans.ProPilotApp.refresh")
        request.earliestBeginDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled NOC background refresh")
        } catch {
            print("❌ Failed to schedule NOC refresh: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Migration to App Group
    private func migrateToAppGroup() {
        // Check if migration already completed
        let migrationKey = "hasCompletedAppGroupMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("📱 Migration already completed, skipping")
            return
        }
        
        let oldURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("logbook.json")
        
        guard let newURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app")?
            .appendingPathComponent("logbook.json") else {
            print("❌ Failed to access App Group container")
            return
        }
        
        // If new location is empty but old location has data, copy it
        if !FileManager.default.fileExists(atPath: newURL.path),
           FileManager.default.fileExists(atPath: oldURL.path) {
            do {
                try FileManager.default.copyItem(at: oldURL, to: newURL)
                print("📱 Migrated logbook to App Group")
                UserDefaults.standard.set(true, forKey: migrationKey)
            } catch {
                print("❌ Migration failed: \(error)")
            }
        } else {
            print("📱 No migration needed")
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }
    
    // MARK: - Location Permissions Setup
    private func setupLocationPermissions() {
        print("📍 Setting up location permissions...")
        
        // Request location permissions immediately
        locationPermissionManager.requestLocationPermission()
        
        // Monitor permission status changes
        locationPermissionManager.onPermissionChange = { status in
            self.handleLocationPermissionChange(status)
        }
    }
    
    private func handleLocationPermissionChange(_ status: CLAuthorizationStatus) {
        print("📍 Location permission changed to: \(status)")
        
        switch status {
        case .notDetermined:
            print("📍 Location permission not determined - requesting...")
            locationPermissionManager.requestLocationPermission()
            
        case .denied, .restricted:
            print("📍 Location permission denied/restricted")
            showLocationPermissionAlert()
            
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location permission granted")
            NotificationCenter.default.post(name: .locationPermissionGranted, object: nil)
            
        @unknown default:
            print("📍 Unknown location permission status")
        }
    }
    
    private func showLocationPermissionAlert() {
        NotificationCenter.default.post(
            name: .showLocationPermissionAlert,
            object: nil,
            userInfo: [
                "title": "Location Permission Required",
                "message": "ProPilot needs location access to detect airports and track flight phases. Please enable location access in Settings.",
                "settingsAction": true
            ]
        )
    }
    
    // MARK: - Watch Connectivity Initialization
    private func initializeWatchConnectivity() {
        print("⌚ Initializing watch connectivity...")
        
        let watchConnectivity = PhoneWatchConnectivity.shared
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let opsManager = OPSCallingManager()
            let locationManager = PilotLocationManager()
            
            watchConnectivity.setReferences(
                logBookStore: self.logbookStore,
                opsManager: opsManager,
                activityManager: self.activityManager,
                locationManager: locationManager
            )
            
            print("⌚ Watch connectivity references set")
        }
    }
    
    // MARK: - Data Recovery Check
    private func checkForDataRecoveryNeeded() {
        if logbookStore.trips.isEmpty {
            print("🔍 No trips found, checking for recoverable data...")
            
            let recovered = logbookStore.attemptDataRecovery()
            if recovered {
                print("✅ Successfully recovered flight data on app launch!")
            }
        }
    }
    
    // MARK: - Live Activities Setup
    private func setupLiveActivities() {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            print("📱 Setting up Live Activities...")
            // Live Activities setup code here
        }
        #endif
    }
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(_ url: URL) {
        print("🔗 Received deep link: \(url)")
        
        guard url.scheme == "propilot" else { return }
        
        switch url.host {
        case "startduty":
            print("🔗 Processing start duty from deep link")
            NotificationCenter.default.post(name: .startDutyFromWatch, object: nil)
            
        case "callops":
            print("🔗 Processing call OPS from deep link")
            NotificationCenter.default.post(name: .callOPSFromWatch, object: nil)
            
        case "nextleg":
            print("🔗 Processing next leg from deep link")
            NotificationCenter.default.post(name: .nextLegFromWidget, object: nil)
            
        case "import":
            print("🔗 Processing import from deep link")
            NotificationCenter.default.post(name: .showDataImport, object: nil)
            
        case "export":
            print("🔗 Processing export from deep link")
            NotificationCenter.default.post(name: .showDataExport, object: nil)
            
        case "nocrevision":
            print("🔗 Processing NOC revision from deep link")
            NotificationCenter.default.post(name: .nocRevisionDetected, object: nil)
            
        default:
            print("🔗 Unknown deep link host: \(url.host ?? "nil")")
        }
    }
    
    // MARK: - App Group Monitoring
    private func startMonitoringPendingActions() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkForPendingActions()
        }
    }
    
    private func checkForPendingActions() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("⚠️ Failed to access app group UserDefaults")
            return
        }
        
        if let actionData = sharedDefaults.object(forKey: "pendingAction") as? [String: Any],
           let action = actionData["action"] as? String,
           let timestamp = actionData["timestamp"] as? Date {
            
            if Date().timeIntervalSince(timestamp) < 30 {
                print("📱 Processing pending action: \(action)")
                sharedDefaults.removeObject(forKey: "pendingAction")
                
                switch action {
                case "startduty":
                    handleStartDutyAction(actionData)
                case "callops":
                    handleCallOPSAction(actionData)
                case "nextleg":
                    handleNextLegAction(actionData)
                case "quicklog":
                    handleQuickLogAction(actionData)
                case "weather":
                    handleWeatherAction(actionData)
                case "backup":
                    handleBackupAction(actionData)
                case "import":
                    handleImportAction(actionData)
                default:
                    print("⚠️ Unknown action: \(action)")
                }
            }
        }
    }
    
    // MARK: - Action Handlers
    private func handleStartDutyAction(_ actionData: [String: Any]) {
        let flightNumber = actionData["flightNumber"] as? String
        let quickStart = actionData["quickStart"] as? Bool ?? false
        
        print("⏰ Starting duty - Flight: \(flightNumber ?? "N/A"), Quick: \(quickStart)")
        
        NotificationCenter.default.post(
            name: .startDutyFromWatch,
            object: nil,
            userInfo: ["flightNumber": flightNumber ?? "", "quickStart": quickStart]
        )
    }
    
    private func handleCallOPSAction(_ actionData: [String: Any]) {
        let isEmergency = actionData["isEmergency"] as? Bool ?? false
        let callReason = actionData["callReason"] as? String
        
        print("📞 Calling OPS - Emergency: \(isEmergency), Reason: \(callReason ?? "N/A")")
        
        NotificationCenter.default.post(
            name: .callOPSFromWatch,
            object: nil,
            userInfo: ["isEmergency": isEmergency, "callReason": callReason ?? "general"]
        )
    }
    
    private func handleNextLegAction(_ actionData: [String: Any]) {
        let autoPopulate = actionData["autoPopulate"] as? Bool ?? true
        
        print("✈️ Next leg - Auto-populate: \(autoPopulate)")
        
        NotificationCenter.default.post(
            name: .nextLegFromWidget,
            object: nil,
            userInfo: ["autoPopulate": autoPopulate]
        )
    }
    
    private func handleQuickLogAction(_ actionData: [String: Any]) {
        let logType = actionData["logType"] as? String ?? "general"
        let notes = actionData["notes"] as? String ?? ""
        
        print("📝 Quick log - Type: \(logType), Notes: \(notes)")
        
        NotificationCenter.default.post(
            name: .quickLogFromWidget,
            object: nil,
            userInfo: ["logType": logType, "notes": notes]
        )
    }
    
    private func handleWeatherAction(_ actionData: [String: Any]) {
        let airportCode = actionData["airportCode"] as? String ?? ""
        
        print("🌤️ Weather check - Airport: \(airportCode)")
        
        NotificationCenter.default.post(
            name: .weatherCheckFromWidget,
            object: nil,
            userInfo: ["airportCode": airportCode]
        )
    }
    
    private func handleBackupAction(_ actionData: [String: Any]) {
        print("💾 Creating backup from widget/intent")
        
        NotificationCenter.default.post(
            name: .createBackupFromWidget,
            object: nil,
            userInfo: actionData
        )
    }
    
    private func handleImportAction(_ actionData: [String: Any]) {
        print("📥 Import requested from widget/intent")
        
        NotificationCenter.default.post(
            name: .showDataImport,
            object: nil,
            userInfo: actionData
        )
    }
}

// MARK: - Notification Handler (for handling notification taps)
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    
    private override init() {
        super.init()
    }
    
    // Show notification banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        print("📬 Notification tapped - Category: \(categoryIdentifier)")
        
        // Handle based on category or action
        switch categoryIdentifier {
        case "NOC_REVISION":
            handleNOCRevisionNotification(userInfo: userInfo)
            
        case "NEW_ROSTER_TRIP":
            handleNewTripNotification(userInfo: userInfo)
            
        case "SHOW_TIME_ALARM":
            handleShowTimeNotification(userInfo: userInfo)
            
        default:
            // Check for action in userInfo
            if let action = userInfo["action"] as? String {
                handleNotificationAction(action: action, userInfo: userInfo)
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Notification Handlers
    
    private func handleNOCRevisionNotification(userInfo: [AnyHashable: Any]) {
        print("📅 Opening NOC for revision confirmation...")
        
        // Open NOC in Safari
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        } else {
            // Fallback to default NOC URL
            if let url = URL(string: "https://jus.noc.vmc.navblue.cloud") {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
        }
        
        // Also post notification to show in-app banner
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .nocRevisionDetected, object: nil)
        }
    }
    
    private func handleNewTripNotification(userInfo: [AnyHashable: Any]) {
        print("✈️ New trip notification tapped")
        
        // Post notification to show trip generation UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newRosterTripsDetected, object: nil, userInfo: userInfo)
        }
    }
    
    private func handleShowTimeNotification(userInfo: [AnyHashable: Any]) {
        print("⏰ Show time alarm tapped")
        
        // Post notification to show trip details
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showTimeAlarmTapped, object: nil, userInfo: userInfo)
        }
    }
    
    private func handleNotificationAction(action: String, userInfo: [AnyHashable: Any]) {
        print("🔔 Handling notification action: \(action)")
        
        switch action {
        case "openNOC":
            handleNOCRevisionNotification(userInfo: userInfo)
            
        case "viewTrip":
            handleNewTripNotification(userInfo: userInfo)
            
        default:
            print("⚠️ Unknown notification action: \(action)")
        }
    }
}

// MARK: - Trip Creation Settings Extension
extension TripCreationSettings {
    func syncToAppGroup() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("❌ Failed to access App Group for settings sync")
            return
        }
        
        sharedDefaults.set(preferredTripCreationDevice.rawValue, forKey: "preferredTripCreationDevice")
        sharedDefaults.synchronize()
        
        print("📱 Synced trip creation settings to App Group: \(preferredTripCreationDevice.rawValue)")
    }
}

// MARK: - Location Permission Manager
class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var onPermissionChange: ((CLAuthorizationStatus) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            onPermissionChange?(.denied)
        case .authorizedWhenInUse, .authorizedAlways:
            onPermissionChange?(locationManager.authorizationStatus)
        @unknown default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onPermissionChange?(manager.authorizationStatus)
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    static let showTimeAlarmTapped = Notification.Name("showTimeAlarmTapped")
}

// MARK: - Notification Names
// All notification names are centralized in NotificationNames.swift
// Make sure NotificationNames.swift is included in all targets that need these notifications

import Foundation
import SwiftUI
import Combine
import UserNotifications
import CryptoKit

// MARK: - NOC Settings Store
class NOCSettingsStore: ObservableObject {
    // MARK: - Singleton
    static let shared = NOCSettingsStore()
    
    // MARK: - Published Properties
    // Webcal credentials (for calendar sync)
    @Published var username: String = "" { didSet { saveSingleCredential(.username) } }
    @Published var password: String = "" { didSet { saveSingleCredential(.password) } }
    @Published var rosterURL: String = "" { didSet { saveSingleCredential(.rosterURL) } }
    
    // Web portal credentials (for HTTPS site)
    @Published var webUsername: String = "" { didSet { saveSingleCredential(.webUsername) } }
    @Published var webPassword: String = "" { didSet { saveSingleCredential(.webPassword) } }
    @Published var webPortalURL: String = "https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx" { didSet { saveSingleCredential(.webPortalURL) } }
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncSuccess: Bool = false
    @Published var autoSyncEnabled: Bool = true { didSet { saveAutoSyncSetting() } }
    @Published var syncIntervalMinutes: Double = 60 { didSet { saveSyncInterval() } }
    @Published var calendarData: Data?
    @Published var fetchError: String?
    @Published var lastParseDate: Date?
    @Published var isOfflineMode: Bool = false
    @Published var parseDebugInfo: String = ""
    
    // MARK: - Time Offset Settings
    /// Minutes from iCal start time (show time) to actual block out
    /// Default 60 minutes for USA Jet. Other airlines may vary (15-90 min typical)
    @Published var showTimeToBlockOutOffset: Int = 60 { didSet { saveTimeOffsetSetting() } }
    
    /// Whether to apply the offset when importing trips
    @Published var applyTimeOffset: Bool = true { didSet { saveTimeOffsetSetting() } }
    
    // MARK: - Weather Display Settings
    /// Pressure unit preference: true = inHg (inches of mercury), false = mb/hPa (millibars)
    /// Default true for US pilots (29.92 inHg standard)
    @Published var usePressureInHg: Bool = true { didSet { savePressureUnitSetting() } }
    
    /// Temperature unit preference: true = Celsius, false = Fahrenheit
    /// Default true (Celsius is aviation standard worldwide)
    @Published var useCelsius: Bool = true { didSet { saveTemperatureUnitSetting() } }
    
    // MARK: - Revision Detection Properties
    @Published var hasPendingRevision: Bool = false
    @Published var pendingRevisionDetectedAt: Date?
    @Published var revisionNotificationsEnabled: Bool = true { didSet { saveRevisionNotificationSetting() } }
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private var autoSyncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var previousScheduleHash: String?
    
    // Credential type enum for targeted saves
    private enum CredentialField {
        case username, password, rosterURL
        case webUsername, webPassword, webPortalURL
    }
    
    // Initialize with fallback
    private init(userDefaults: UserDefaults? = nil) {
        // Try App Group first, fallback to standard UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
            self.userDefaults = groupDefaults
            print("✅ Using App Group UserDefaults")
        } else {
            self.userDefaults = .standard
            print("⚠️ App Group not available, using standard UserDefaults")
        }
    }
    
    // MARK: - UserDefaults Keys
    private let usernameKey = "NOCUsername"
    private let passwordKey = "NOCPassword"
    private let rosterURLKey = "NOCRosterURL"
    private let webUsernameKey = "NOCWebUsername"
    private let webPasswordKey = "NOCWebPassword"
    private let webPortalURLKey = "NOCWebPortalURL"
    private let autoSyncEnabledKey = "NOCAutoSyncEnabled"
    private let lastSyncTimeKey = "NOCLastSyncTime"
    private let syncIntervalKey = "NOCSyncIntervalMinutes"
    private let calendarDataKey = "NOCCalendarData"
    private let scheduleHashKey = "NOCScheduleHash"
    private let hasPendingRevisionKey = "NOCHasPendingRevision"
    private let pendingRevisionDetectedAtKey = "NOCPendingRevisionDetectedAt"
    private let revisionNotificationsEnabledKey = "NOCRevisionNotificationsEnabled"
    private let showTimeToBlockOutOffsetKey = "NOCShowTimeToBlockOutOffset"
    private let applyTimeOffsetKey = "NOCApplyTimeOffset"
    private let usePressureInHgKey = "WeatherUsePressureInHg"
    private let useCelsiusKey = "WeatherUseCelsius"
    
    // MARK: - Computed Properties
    var rosterURLObject: URL? {
        URL(string: rosterURL)
    }
    
    var isValidURL: Bool {
        rosterURLObject != nil
    }
    
    var hasOfflineData: Bool {
        return calendarData != nil
    }
    
    var offlineDataAge: TimeInterval? {
        guard let lastSync = lastSyncTime else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    /// URL to open NOC revision confirmation page
    var nocRevisionURL: URL? {
        // This goes to the main portal - user will need to navigate to My Revision
        URL(string: "https://jus.noc.vmc.navblue.cloud")
    }
    
    // MARK: - Initialization
    convenience init() {
        self.init(userDefaults: nil)
        loadCredentials()
        loadCalendarData()
        loadAutoSyncSetting()
        loadLastSyncTime()
        loadSyncInterval()
        loadRevisionState()
        loadRevisionNotificationSetting()
        loadTimeOffsetSettings()
        loadPressureUnitSetting()
        loadTemperatureUnitSetting()
        checkOfflineStatus()
        
        // Setup Combine publisher to auto-save calendar data
        setupDataObservers()
        
        // Request notification permissions for revision alerts
        requestNotificationPermissions()
        
        // Start auto-sync timer if enabled
        if autoSyncEnabled && !username.isEmpty && !password.isEmpty {
            startAutoSyncTimer()
        }
    }
    
    // MARK: - Setup Data Observers
    private func setupDataObservers() {
        // Auto-save calendar data when it changes
        $calendarData
            .dropFirst() // Skip initial value from load
            .sink { [weak self] _ in
                self?.saveCalendarData()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopAutoSyncTimer()
    }
    
    // MARK: - Notification Permissions
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted for revision alerts")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Credentials Management
    
    /// Save a single credential field (prevents overwriting other fields)
    private func saveSingleCredential(_ field: CredentialField) {
        switch field {
        case .username:
            userDefaults.set(username, forKey: usernameKey)
            print("✅ Username saved: \(username.isEmpty ? "empty" : "\(username.count) chars")")
        case .password:
            userDefaults.set(password, forKey: passwordKey)
            print("✅ Password saved: \(password.isEmpty ? "empty" : "\(password.count) chars")")
        case .rosterURL:
            userDefaults.set(rosterURL, forKey: rosterURLKey)
            print("✅ Roster URL saved: \(rosterURL.isEmpty ? "empty" : "set")")
        case .webUsername:
            userDefaults.set(webUsername, forKey: webUsernameKey)
            print("✅ Web Username saved: \(webUsername.isEmpty ? "empty" : "\(webUsername.count) chars")")
        case .webPassword:
            userDefaults.set(webPassword, forKey: webPasswordKey)
            print("✅ Web Password saved: \(webPassword.isEmpty ? "empty" : "\(webPassword.count) chars")")
        case .webPortalURL:
            userDefaults.set(webPortalURL, forKey: webPortalURLKey)
            print("✅ Web Portal URL saved")
        }
        userDefaults.synchronize()
    }
    
    /// Save all credentials at once (use sparingly)
    private func saveCredentials() {
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.set(password, forKey: passwordKey)
        userDefaults.set(rosterURL, forKey: rosterURLKey)
        userDefaults.set(webUsername, forKey: webUsernameKey)
        userDefaults.set(webPassword, forKey: webPasswordKey)
        userDefaults.set(webPortalURL, forKey: webPortalURLKey)
        userDefaults.synchronize()
        print("✅ ALL NOC credentials saved to UserDefaults")
        print("   - Username: \(username.isEmpty ? "empty" : "set (\(username.count) chars)")")
        print("   - Password: \(password.isEmpty ? "empty" : "set (\(password.count) chars)")")
        print("   - Roster URL: \(rosterURL.isEmpty ? "empty" : "set")")
        print("   - Web Username: \(webUsername.isEmpty ? "empty" : "set")")
    }
    
    private func loadCredentials() {
        username = userDefaults.string(forKey: usernameKey) ?? ""
        password = userDefaults.string(forKey: passwordKey) ?? ""
        rosterURL = userDefaults.string(forKey: rosterURLKey) ?? ""
        webUsername = userDefaults.string(forKey: webUsernameKey) ?? ""
        webPassword = userDefaults.string(forKey: webPasswordKey) ?? ""
        webPortalURL = userDefaults.string(forKey: webPortalURLKey) ?? "https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx"
        print("✅ NOC credentials loaded from UserDefaults")
        print("   - Username: \(username.isEmpty ? "empty" : "loaded (\(username.count) chars)")")
        print("   - Password: \(password.isEmpty ? "empty" : "loaded (\(password.count) chars)")")
        print("   - Roster URL: \(rosterURL.isEmpty ? "empty" : "loaded")")
        print("   - Web Username: \(webUsername.isEmpty ? "empty" : "loaded")")
    }
    
    // MARK: - Calendar Data Management
    private func saveCalendarData() {
        userDefaults.set(calendarData, forKey: calendarDataKey)
        userDefaults.synchronize()
        if calendarData != nil {
            print("✅ Calendar data saved to UserDefaults: \(calendarData!.count) bytes")
        } else {
            print("✅ Calendar data cleared from UserDefaults")
        }
    }
    
    private func loadCalendarData() {
        calendarData = userDefaults.data(forKey: calendarDataKey)
        previousScheduleHash = userDefaults.string(forKey: scheduleHashKey)
        if let data = calendarData {
            print("✅ Loaded cached calendar data")
            
            // Update rest status from cached data on app launch
            updateRestStatusFromCalendar(data)
        }
        if previousScheduleHash != nil {
            print("✅ Loaded previous schedule hash")
        }
    }
    
    // MARK: - Rest Status Integration
    
    /// Parse calendar data and update RestStatusManager with rest events
    private func updateRestStatusFromCalendar(_ data: Data) {
        // Parse the calendar data
        let (flights, events) = ICalFlightParser.parseCalendar(data)
        
        // Update RestStatusManager with the parsed data
        RestStatusManager.shared.updateFromNOCEvents(events, flights: flights)
        
        // Log for debugging
        let restEvents = events.filter { $0.isRest }
        print("😴 Found \(restEvents.count) REST events in NOC calendar")
        
        // Check if currently in rest
        if RestStatusManager.shared.isInRest {
            if let endTime = RestStatusManager.shared.formattedRestEndTime {
                print("😴 Currently IN REST until \(endTime)")
            }
        } else {
            print("✈️ Not currently in rest")
        }
    }
    
    // MARK: - Revision State Management
    
    /// How long a pending revision stays valid before auto-clearing (24 hours)
    private let revisionExpirationHours: TimeInterval = 24
    
    private func saveRevisionState() {
        userDefaults.set(hasPendingRevision, forKey: hasPendingRevisionKey)
        userDefaults.set(pendingRevisionDetectedAt, forKey: pendingRevisionDetectedAtKey)
        userDefaults.synchronize()
    }
    
    private func loadRevisionState() {
        hasPendingRevision = userDefaults.bool(forKey: hasPendingRevisionKey)
        pendingRevisionDetectedAt = userDefaults.object(forKey: pendingRevisionDetectedAtKey) as? Date
        
        if hasPendingRevision {
            // Check if revision has expired
            if let detectedAt = pendingRevisionDetectedAt {
                let hoursSinceDetection = Date().timeIntervalSince(detectedAt) / 3600
                
                if hoursSinceDetection > revisionExpirationHours {
                    print("🕐 Pending revision expired (\(Int(hoursSinceDetection))h old) - auto-clearing")
                    clearExpiredRevision()
                    return
                }
                
                print("⚠️ Pending revision detected at: \(detectedAt) (\(Int(hoursSinceDetection))h ago)")
            } else {
                // No timestamp but flagged as pending - clear it
                print("⚠️ Pending revision with no timestamp - clearing")
                clearExpiredRevision()
            }
        }
    }
    
    /// Clear an expired or stale revision silently
    private func clearExpiredRevision() {
        hasPendingRevision = false
        pendingRevisionDetectedAt = nil
        saveRevisionState()
        
        // Remove any lingering notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["noc-revision"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["noc-revision"])
    }
    
    private func saveRevisionNotificationSetting() {
        userDefaults.set(revisionNotificationsEnabled, forKey: revisionNotificationsEnabledKey)
        userDefaults.synchronize()
        print("✅ Revision notifications setting saved: \(revisionNotificationsEnabled)")
    }
    
    private func loadRevisionNotificationSetting() {
        if userDefaults.object(forKey: revisionNotificationsEnabledKey) != nil {
            revisionNotificationsEnabled = userDefaults.bool(forKey: revisionNotificationsEnabledKey)
        } else {
            revisionNotificationsEnabled = true // Default to enabled
        }
    }
    
    // MARK: - Auto-Sync Settings
    private func saveAutoSyncSetting() {
        userDefaults.set(autoSyncEnabled, forKey: autoSyncEnabledKey)
        userDefaults.synchronize()
        
        // Start or stop timer based on setting
        if autoSyncEnabled {
            startAutoSyncTimer()
        } else {
            stopAutoSyncTimer()
        }
        
        // Post notification for background task scheduler
        NotificationCenter.default.post(
            name: .nocAutoSyncSettingChanged,
            object: nil,
            userInfo: ["enabled": autoSyncEnabled]
        )
        print("✅ Auto-sync setting saved: \(autoSyncEnabled)")
    }
    
    private func loadAutoSyncSetting() {
        // Check if key exists, otherwise use default
        if userDefaults.object(forKey: autoSyncEnabledKey) != nil {
            autoSyncEnabled = userDefaults.bool(forKey: autoSyncEnabledKey)
        } else {
            autoSyncEnabled = true  // Default to enabled
        }
        print("✅ Loaded auto-sync setting: \(autoSyncEnabled)")
    }
    
    private func saveLastSyncTime() {
        userDefaults.set(lastSyncTime, forKey: lastSyncTimeKey)
        userDefaults.synchronize()
    }
    
    private func loadLastSyncTime() {
        lastSyncTime = userDefaults.object(forKey: lastSyncTimeKey) as? Date
        if let time = lastSyncTime {
            print("✅ Loaded last sync time: \(time)")
        }
    }
    
    // MARK: - Helper Methods
        private func handleSyncError(_ errorMessage: String) {
            self.fetchError = errorMessage
            self.syncSuccess = false
            
            NotificationCenter.default.post(
                name: .nocSyncCompleted,
                object: nil,
                userInfo: ["success": false, "error": errorMessage]
            )
            
            print("❌ NOC Sync Error: \(errorMessage)")
        }
    
    // MARK: - Sync Interval Management
    private func saveSyncInterval() {
        userDefaults.set(syncIntervalMinutes, forKey: syncIntervalKey)
        userDefaults.synchronize()
        
        // Restart timer with new interval if auto-sync is enabled
        if autoSyncEnabled {
            startAutoSyncTimer()
        }
        
        print("✅ Sync interval saved: \(syncIntervalMinutes) minutes")
    }
    
    private func loadSyncInterval() {
        if let savedInterval = userDefaults.object(forKey: syncIntervalKey) as? Double {
            syncIntervalMinutes = savedInterval
        } else {
            syncIntervalMinutes = 60 // Default to 1 hour
        }
        print("✅ Loaded sync interval: \(syncIntervalMinutes) minutes")
    }
    
    // MARK: - Time Offset Settings
    
    private func saveTimeOffsetSetting() {
        userDefaults.set(showTimeToBlockOutOffset, forKey: showTimeToBlockOutOffsetKey)
        userDefaults.set(applyTimeOffset, forKey: applyTimeOffsetKey)
        userDefaults.synchronize()
        print("✅ Time offset saved: \(showTimeToBlockOutOffset) minutes, apply: \(applyTimeOffset)")
    }
    
    private func loadTimeOffsetSettings() {
        // Load offset (default 60 minutes for USA Jet)
        if let savedOffset = userDefaults.object(forKey: showTimeToBlockOutOffsetKey) as? Int {
            showTimeToBlockOutOffset = savedOffset
        } else {
            showTimeToBlockOutOffset = 60
        }
        
        // Load apply setting (default true)
        if userDefaults.object(forKey: applyTimeOffsetKey) != nil {
            applyTimeOffset = userDefaults.bool(forKey: applyTimeOffsetKey)
        } else {
            applyTimeOffset = true
        }
        
        print("✅ Loaded time offset: \(showTimeToBlockOutOffset) minutes, apply: \(applyTimeOffset)")
    }
    
    // MARK: - Pressure Unit Settings
    
    private func savePressureUnitSetting() {
        userDefaults.set(usePressureInHg, forKey: usePressureInHgKey)
        userDefaults.synchronize()
        print("✅ Pressure unit saved: \(usePressureInHg ? "inHg" : "mb/hPa")")
        
        // Post notification for weather views to update
        NotificationCenter.default.post(
            name: .weatherPressureUnitChanged,
            object: nil,
            userInfo: ["useInHg": usePressureInHg]
        )
    }
    
    private func loadPressureUnitSetting() {
        // Load preference (default true for US - inHg)
        if userDefaults.object(forKey: usePressureInHgKey) != nil {
            usePressureInHg = userDefaults.bool(forKey: usePressureInHgKey)
        } else {
            usePressureInHg = true  // Default to inHg for US pilots
        }
        
        print("✅ Loaded pressure unit: \(usePressureInHg ? "inHg" : "mb/hPa")")
    }
    
    // MARK: - Temperature Unit Settings
    
    private func saveTemperatureUnitSetting() {
        userDefaults.set(useCelsius, forKey: useCelsiusKey)
        userDefaults.synchronize()
        print("✅ Temperature unit saved: \(useCelsius ? "°C" : "°F")")
        
        // Post notification for weather views to update
        NotificationCenter.default.post(
            name: .weatherTemperatureUnitChanged,
            object: nil,
            userInfo: ["useCelsius": useCelsius]
        )
    }
    
    private func loadTemperatureUnitSetting() {
        // Load preference (default true - Celsius is aviation standard)
        if userDefaults.object(forKey: useCelsiusKey) != nil {
            useCelsius = userDefaults.bool(forKey: useCelsiusKey)
        } else {
            useCelsius = true  // Default to Celsius (aviation standard)
        }
        
        print("✅ Loaded temperature unit: \(useCelsius ? "°C" : "°F")")
    }
    
    /// Calculate adjusted block out time from iCal show time
    func adjustedBlockOutTime(from showTime: Date) -> Date {
        guard applyTimeOffset else { return showTime }
        return showTime.addingTimeInterval(TimeInterval(showTimeToBlockOutOffset * 60))
    }
    
    /// Calculate adjusted block in time (same offset assumption for now)
    /// Note: This is an approximation - actual block in would need flight time data
    func adjustedBlockInTime(from releaseTime: Date, flightDuration: TimeInterval? = nil) -> Date {
        // If we have flight duration, calculate properly
        // Otherwise, just return release time as-is (it's closer to block in than show time is to block out)
        return releaseTime
    }
    
    // MARK: - Auto-Sync Timer
    private func startAutoSyncTimer() {
        // Cancel existing timer if any
        stopAutoSyncTimer()
        
        // Convert minutes to seconds
        let intervalSeconds = syncIntervalMinutes * 60
        
        // Create timer that fires at the user's chosen interval
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only sync if credentials exist
            guard !self.username.isEmpty && !self.password.isEmpty else {
                print("⚠️ Auto-sync skipped - no credentials")
                return
            }
            
            // Prevent multiple simultaneous syncs
            guard !self.isSyncing else {
                print("⚠️ Auto-sync skipped - sync already in progress")
                return
            }
            
            print("⏰ Auto-sync timer fired at \(Date()) (interval: \(self.syncIntervalMinutes) minutes)")
            self.fetchRosterCalendar(silent: true)
        }
        
        // Add to run loop to keep it alive
        if let timer = autoSyncTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        let intervalText = syncIntervalMinutes < 60 ? "\(Int(syncIntervalMinutes)) minutes" : "\(Int(syncIntervalMinutes / 60)) hour(s)"
        print("✅ Auto-sync timer started (fires every \(intervalText))")
    }
    
    private func stopAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
        print("✅ Auto-sync timer stopped")
    }
    
    // MARK: - Offline Status
    private func checkOfflineStatus() {
        isOfflineMode = calendarData != nil && fetchError == nil
    }
    
    // MARK: - Public Methods
    func clearCredentials() {
        username = ""
        password = ""
        saveCredentials()
        stopAutoSyncTimer()
    }
    
    func clearCachedData() {
        calendarData = nil
        lastSyncTime = nil
        lastParseDate = nil
        previousScheduleHash = nil
        hasPendingRevision = false
        pendingRevisionDetectedAt = nil
        saveCalendarData()
        saveLastSyncTime()
        saveRevisionState()
        userDefaults.removeObject(forKey: scheduleHashKey)
        print("✅ Cleared cached NOC data")
    }
    
    func testConnection() {
        fetchRosterCalendar(silent: false)
    }
    
    /// Mark revision as confirmed (user has logged into NOC and confirmed)
    func markRevisionConfirmed() {
        hasPendingRevision = false
        pendingRevisionDetectedAt = nil
        saveRevisionState()
        
        // Remove any pending notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["noc-revision"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["noc-revision"])
        
        print("✅ Revision marked as confirmed")
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .nocRevisionConfirmed, object: nil)
    }
    
    /// Open NOC in Safari to confirm revision
    func openNOCForConfirmation() {
        guard let url = nocRevisionURL else { return }
        
#if os(iOS)
        UIApplication.shared.open(url)
#endif
    }
    
    // MARK: - Validate URL
    func validateURL(_ urlString: String) -> Bool {
        // Trim whitespace
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a valid URL
        guard let url = URL(string: trimmed) else { return false }
        
        // Check if it has a scheme (http/https)
        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else { return false }
        
        // Check if it has a host
        return url.host != nil
    }
    
    // MARK: - Schedule Change Detection
    
    /// Generate a hash of ONLY future events for comparison
    /// This prevents alerts for past flights that have already been flown
    private func generateFutureScheduleHash(from data: Data) -> String? {
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Extract only future events (today and beyond)
        let futureContent = extractFutureEventsContent(from: content)
        
        // Hash only the future content
        let hash = SHA256.hash(data: Data(futureContent.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Extract iCalendar content for events from today onwards
    private func extractFutureEventsContent(from content: String) -> String {
        var futureEvents: [String] = []
        
        // Split into individual VEVENT blocks
        let eventPattern = "BEGIN:VEVENT[\\s\\S]*?END:VEVENT"
        guard let regex = try? NSRegularExpression(pattern: eventPattern, options: []) else {
            return content // Fall back to full content if regex fails
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        for match in matches {
            if let eventRange = Range(match.range, in: content) {
                let eventBlock = String(content[eventRange])
                
                // Extract DTSTART from this event
                let dtPattern = "DTSTART[^:]*:([0-9]{8})"
                if let dtRegex = try? NSRegularExpression(pattern: dtPattern, options: []),
                   let dtMatch = dtRegex.firstMatch(in: eventBlock, options: [], range: NSRange(eventBlock.startIndex..., in: eventBlock)),
                   let dateRange = Range(dtMatch.range(at: 1), in: eventBlock) {
                    
                    let dateString = String(eventBlock[dateRange])
                    if let eventDate = dateFormatter.date(from: dateString) {
                        // Only include events from today onwards
                        if eventDate >= today {
                            futureEvents.append(eventBlock)
                        }
                    }
                }
            }
        }
        
        // Return sorted and joined future events (sorting ensures consistent hash)
        return futureEvents.sorted().joined(separator: "\n")
    }
    
    /// Check if the schedule has changed and handle revision detection
    private func checkForScheduleChanges(newData: Data) {
        guard let newHash = generateFutureScheduleHash(from: newData) else {
            print("⚠️ Could not generate schedule hash")
            return
        }
        
        // If we have a previous hash, compare
        if let oldHash = previousScheduleHash {
            if newHash != oldHash {
                // Future schedule changed!
                print("🔔 Future schedule change detected!")
                print("   Old hash: \(oldHash.prefix(16))...")
                print("   New hash: \(newHash.prefix(16))...")
                
                // Verify there are actually future changes worth alerting about
                if let changeInfo = getRelevantFutureChanges(newData: newData) {
                    handleScheduleRevisionDetected(oldData: calendarData, newData: newData, changeInfo: changeInfo)
                } else {
                    print("📝 Hash changed but no actionable future changes - skipping alert")
                }
            } else {
                print("✅ Future schedule unchanged (hash match)")
                
                // If schedule matches and we had a pending revision, it might be confirmed
                // Auto-clear if revision is old
                if hasPendingRevision, let detectedAt = pendingRevisionDetectedAt {
                    let hoursSince = Date().timeIntervalSince(detectedAt) / 3600
                    if hoursSince > 12 {
                        print("📝 Schedule stable for 12+ hours - auto-clearing old revision flag")
                        clearExpiredRevision()
                    }
                }
            }
        } else {
            print("📝 First sync - storing initial schedule hash")
        }
        
        // Update stored hash
        previousScheduleHash = newHash
        userDefaults.set(newHash, forKey: scheduleHashKey)
        userDefaults.synchronize()
    }
    
    /// Check if there are relevant future changes worth alerting about
    private func getRelevantFutureChanges(newData: Data) -> String? {
        guard let content = String(data: newData, encoding: .utf8) else {
            return nil
        }
        
        let upcomingDates = extractUpcomingEventDates(from: content)
        
        // Only alert if there are changes within the next 7 days
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let relevantDates = upcomingDates.filter { $0 <= oneWeekFromNow }
        
        if relevantDates.isEmpty {
            return nil // No changes in the next week - not urgent
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStrings = relevantDates.prefix(3).map { formatter.string(from: $0) }
        return "Schedule changes for \(dateStrings.joined(separator: ", "))"
    }
    
    /// Handle when a schedule revision is detected
    private func handleScheduleRevisionDetected(oldData: Data?, newData: Data, changeInfo: String) {
        // Set pending revision flag
        hasPendingRevision = true
        pendingRevisionDetectedAt = Date()
        saveRevisionState()
        
        // Send notification if enabled
        if revisionNotificationsEnabled {
            sendRevisionNotification(changeInfo: changeInfo)
        }
        
        // Post internal notification for UI updates
        NotificationCenter.default.post(
            name: .nocRevisionDetected,
            object: nil,
            userInfo: [
                "detectedAt": pendingRevisionDetectedAt as Any,
                "changeInfo": changeInfo
            ]
        )
    }
    
    /// Parse calendar data to identify what changed (legacy - kept for compatibility)
    private func parseScheduleChanges(oldData: Data?, newData: Data) -> String {
        guard let content = String(data: newData, encoding: .utf8) else {
            return "Schedule updated"
        }
        
        let upcomingDates = extractUpcomingEventDates(from: content)
        
        if !upcomingDates.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateStrings = upcomingDates.prefix(3).map { formatter.string(from: $0) }
            return "Schedule changes for \(dateStrings.joined(separator: ", "))"
        }
        
        return "Schedule updated - check NOC for details"
    }
    
    /// Extract event dates from iCalendar content
    private func extractUpcomingEventDates(from content: String) -> [Date] {
        var dates: [Date] = []
        let today = Date()
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        
        // Simple regex to find DTSTART values
        let pattern = "DTSTART[^:]*:([0-9]{8})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return dates
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        for match in matches {
            if let dateRange = Range(match.range(at: 1), in: content) {
                let dateString = String(content[dateRange])
                if let date = dateFormatter.date(from: dateString) {
                    // Only include dates from today to a week out
                    if date >= today && date <= oneWeekFromNow {
                        dates.append(date)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        let uniqueDates = Array(Set(dates)).sorted()
        return uniqueDates
    }
    
    /// Send a local notification about the schedule revision
    private func sendRevisionNotification(changeInfo: String) {
        let content = UNMutableNotificationContent()
        content.title = "📅 Schedule Revision Pending"
        content.body = "\(changeInfo)\nTap to confirm in NOC."
        content.sound = .default
        content.categoryIdentifier = "NOC_REVISION"
        
        // Add deep link to open NOC
        content.userInfo = [
            "action": "openNOC",
            "url": nocRevisionURL?.absoluteString ?? ""
        ]
        
        // Create request with unique identifier (replaces previous if exists)
        let request = UNNotificationRequest(
            identifier: "noc-revision",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send revision notification: \(error.localizedDescription)")
            } else {
                print("✅ Revision notification sent")
            }
        }
    }
    
    // MARK: - Fetch Roster Calendar
    func fetchRosterCalendar(silent: Bool = false) {
        guard !username.isEmpty && !password.isEmpty else {
            fetchError = "Missing credentials"
            return
        }
        
        guard !rosterURL.isEmpty else {
            fetchError = "Missing roster URL"
            return
        }
        
        // Ensure rosterURL is properly formatted and convert webcal:// to https://
        var urlString = rosterURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasPrefix("webcal://") {
            urlString = urlString.replacingOccurrences(of: "webcal://", with: "https://")
        }
        
        guard let url = URL(string: urlString) else {
            fetchError = "Invalid URL format"
            return
        }
        
        // Validate URL structure
        guard url.scheme != nil && url.host != nil else {
            fetchError = "Invalid URL - must include http:// or https://"
            return
        }
        
        if !silent {
            isSyncing = true
        }
        fetchError = nil
        
        // Create basic auth string
        let loginString = "\(username):\(password)"
        guard let loginData = loginString.data(using: .utf8) else {
            fetchError = "Failed to encode credentials"
            if !silent { isSyncing = false }
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("text/calendar", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Perform request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if !silent {
                    self.isSyncing = false
                }
                
                if let error = error {
                    self.fetchError = error.localizedDescription
                    self.syncSuccess = false
                    print("❌ Fetch error: \(error.localizedDescription)")
                    
                    // Post notification even on failure
                    NotificationCenter.default.post(
                        name: .nocSyncCompleted,
                        object: nil,
                        userInfo: ["success": false, "error": error.localizedDescription]
                    )
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.fetchError = "Invalid response"
                    self.syncSuccess = false
                    NotificationCenter.default.post(
                        name: .nocSyncCompleted,
                        object: nil,
                        userInfo: ["success": false, "error": "Invalid response"]
                    )
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    // Success - continue processing
                    break
                case 401:
                    self.handleSyncError("Invalid credentials")
                    return
                case 403:
                    self.handleSyncError("Access denied")
                    return
                case 404:
                    self.handleSyncError("URL not found")
                    return
                case 500...599:
                    self.handleSyncError("Server error (\(httpResponse.statusCode))")
                    return
                default:
                    self.handleSyncError("HTTP error: \(httpResponse.statusCode)")
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self.handleSyncError("No data received")
                    return
                }
                
                // Validate calendar data
                if let content = String(data: data, encoding: .utf8) {
                    if content.contains("BEGIN:VCALENDAR") {
                        
                        // 🔔 CHECK FOR SCHEDULE CHANGES BEFORE UPDATING
                        self.checkForScheduleChanges(newData: data)
                        
                        self.calendarData = data
                        self.fetchError = nil
                        self.lastParseDate = Date()
                        self.isOfflineMode = false
                        self.parseDebugInfo = "Calendar data updated: \(data.count) bytes"
                        self.lastSyncTime = Date()
                        self.saveLastSyncTime()
                        self.saveCalendarData()
                        self.syncSuccess = true
                        
                        print("✅ Calendar data fetched successfully: \(data.count) bytes")
                        
                        // *** UPDATE REST STATUS FROM NOC DATA ***
                        self.updateRestStatusFromCalendar(data)
                        
                        // Post notification that sync completed
                        NotificationCenter.default.post(
                            name: .nocSyncCompleted,
                            object: nil,
                            userInfo: [
                                "success": true,
                                "dataSize": data.count,
                                "hasPendingRevision": self.hasPendingRevision
                            ]
                        )
                    } else if content.contains("<!DOCTYPE html>") || content.contains("<html") {
                        self.handleSyncError("Received HTML instead of calendar data - check URL")
                    } else {
                        self.handleSyncError("Invalid calendar format - expected iCalendar data")
                        print("❌ Unexpected content type. First 100 chars: \(String(content.prefix(100)))")
                    }
                } else {
                    self.handleSyncError("Failed to decode data")
                }
            }
        }.resume()
    }
}
   
// MARK: - Notification Names Extension
extension Notification.Name {
    static let nocRevisionDetected = Notification.Name("nocRevisionDetected")
    static let nocRevisionConfirmed = Notification.Name("nocRevisionConfirmed")
    static let weatherPressureUnitChanged = Notification.Name("weatherPressureUnitChanged")
    static let weatherTemperatureUnitChanged = Notification.Name("weatherTemperatureUnitChanged")
}

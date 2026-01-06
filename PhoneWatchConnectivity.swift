// PhoneWatchConnectivity.swift
// Phone-side Watch Connectivity Manager with Improved Sync Tracking
import Foundation
import WatchConnectivity

// MARK: - ✅ Flight Data Structure for Watch Communication
struct WatchFlightData: Codable {
    let departure: String?
    let arrival: String?
    let outTime: Date?
    let offTime: Date?
    let onTime: Date?
    let inTime: Date?
    
    init(departure: String? = nil,
         arrival: String? = nil,
         outTime: Date? = nil,
         offTime: Date? = nil,
         onTime: Date? = nil,
         inTime: Date? = nil) {
        self.departure = departure
        self.arrival = arrival
        self.outTime = outTime
        self.offTime = offTime
        self.onTime = onTime
        self.inTime = inTime
    }
}

class PhoneWatchConnectivity: NSObject, ObservableObject {
    static let shared = PhoneWatchConnectivity()
    
    // MARK: - @Published Properties
    @Published var isWatchConnected = false
    @Published var currentLegIndex: Int = 0
    @Published var isDutyTimerRunning = false
    @Published var dutyStartTime: Date?
    @Published var currentFlight: WatchFlightData?
    
    // MARK: - Computed Properties
    var isWatchPaired: Bool {
        return WCSession.default.isPaired
    }
    
    // MARK: - ✨ NEW: Integrated Sync Tracking
    @Published var syncState: DataSyncState = .notPaired
    @Published var syncMetrics = SyncMetrics(
        lastSyncTime: nil,
        pendingChanges: 0,
        failedAttempts: 0,
        dataVersion: 0,
        isDataCurrent: false
    )
    @Published var lastSyncError: String?
    
    // MARK: - Store References
    weak var logbookStore: SwiftDataLogBookStore?
    weak var activityManager: PilotActivityManager?
    weak var opsManager: OPSCallingManager?
    weak var locationManager: PilotLocationManager?
    
    private var session: WCSession?
    private var activeTripId: UUID?
    private var dataVersionTracker = DataVersionTracker()
    private var pendingSyncQueue = PendingSyncQueue()
    
    // MARK: - 🔥 FIX: Debouncing for sync health checks
    private var evaluateSyncHealthWorkItem: DispatchWorkItem?
    private let syncHealthDebounceDelay: TimeInterval = 0.5  // Wait 500ms before evaluating
    private var lastSyncStateLog: Date?
    private let minLogInterval: TimeInterval = 2.0  // Don't log more than once per 2 seconds
    
    // ✅ Time formatter for converting Date ↔ String
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "GMT")
        return formatter
    }()
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("📱 Phone Watch Connectivity initialized")
            
            // Test connectivity after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.testWatchConnection()
                self?.evaluateSyncHealth()
            }
        }
        
        // Subscribe to duty timer changes
        setupDutyTimerObservers()
        
        // Start sync health monitoring
        startSyncHealthMonitoring()
    }
    
    // MARK: - Setup Observers
    private func setupDutyTimerObservers() {
        // Listen for duty timer changes from PilotActivityManager
        NotificationCenter.default.addObserver(
            forName: .dutyTimerStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let startTime = notification.userInfo?["startTime"] as? Date {
                self.isDutyTimerRunning = true
                self.dutyStartTime = startTime
                self.sendDutyStatusToWatch()
                self.markDataForSync(type: .dutyTimer)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .dutyTimerEnded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isDutyTimerRunning = false
            self.dutyStartTime = nil
            self.sendDutyStatusToWatch()
            self.sendClearTripToWatch()  // ✅ Also clear trip from watch
            self.markDataForSync(type: .dutyTimer)
        }
    }
    
    // MARK: - ✨ NEW: Sync Health Monitoring (with Debouncing)
    private func startSyncHealthMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateSyncHealth()
        }
    }
    
    /// 🔥 FIX: Debounced sync health evaluation (prevents spam logging)
    func evaluateSyncHealth() {
        // Cancel any pending evaluation
        evaluateSyncHealthWorkItem?.cancel()
        
        // Schedule new evaluation after delay to allow multiple rapid calls to coalesce
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSyncHealthEvaluation()
        }
        evaluateSyncHealthWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + syncHealthDebounceDelay, execute: workItem)
    }
    
    /// Actual sync health evaluation logic (called after debounce)
    private func performSyncHealthEvaluation() {
        guard let session = session else {
            updateSyncState(.notPaired, detail: "No watch session")
            return
        }
        
        if !session.isPaired {
            updateSyncState(.notPaired, detail: "Apple Watch not paired")
            return
        }
        
        if !session.isWatchAppInstalled {
            updateSyncState(.notPaired, detail: "ProPilot Watch app not installed")
            return
        }
        
        if !session.isReachable {
            updateSyncState(.bluetoothOnly, detail: "Watch not reachable - open app on watch")
            return
        }
        
        // Check data freshness
        if let timeSince = syncMetrics.timeSinceSync {
            if timeSince > 3600 { // 1 hour
                updateSyncState(.dataStale, detail: "Last sync: \(formatTimeAgo(timeSince))")
            } else if syncMetrics.pendingChanges > 0 {
                updateSyncState(.syncInProgress, detail: "\(syncMetrics.pendingChanges) changes pending")
            } else if syncMetrics.failedAttempts > 3 {
                updateSyncState(.syncError, detail: "Multiple sync failures")
            } else {
                updateSyncState(.synced, detail: "All data current")
            }
        } else {
            updateSyncState(.dataStale, detail: "Never synced")
        }
    }
    
    /// 🔥 FIX: Rate-limited logging to prevent spam
    private func updateSyncState(_ state: DataSyncState, detail: String? = nil) {
        DispatchQueue.main.async {
            self.syncState = state
            
            // Rate limit logging to prevent spam (max once per 2 seconds)
            let now = Date()
            let shouldLog: Bool
            if let lastLog = self.lastSyncStateLog {
                shouldLog = now.timeIntervalSince(lastLog) >= self.minLogInterval
            } else {
                shouldLog = true  // Always log first time
            }
            
            if shouldLog, let detail = detail {
                self.lastSyncStateLog = now
                print("📊 Sync State: \(state.rawValue) - \(detail)")
            }
            // UI updates happen automatically via @Published property
        }
    }
    
    func markDataForSync(type: DataType) {
        pendingSyncQueue.add(type)
        dataVersionTracker.increment()
        
        DispatchQueue.main.async {
            self.syncMetrics = SyncMetrics(
                lastSyncTime: self.syncMetrics.lastSyncTime,
                pendingChanges: self.pendingSyncQueue.count,
                failedAttempts: self.syncMetrics.failedAttempts,
                dataVersion: self.dataVersionTracker.currentVersion,
                isDataCurrent: false
            )
        }
        
        // Trigger sync if watch is reachable
        if session?.isReachable == true {
            syncCurrentLegToWatch()
        }
    }
    
    private func updateSyncMetrics(success: Bool) {
        DispatchQueue.main.async {
            if success {
                self.pendingSyncQueue.clear()
                self.syncMetrics = SyncMetrics(
                    lastSyncTime: Date(),
                    pendingChanges: 0,
                    failedAttempts: 0,
                    dataVersion: self.dataVersionTracker.currentVersion,
                    isDataCurrent: true
                )
                self.lastSyncError = nil  // ✅ Already on main thread
            } else {
                self.syncMetrics = SyncMetrics(
                    lastSyncTime: self.syncMetrics.lastSyncTime,
                    pendingChanges: self.syncMetrics.pendingChanges,
                    failedAttempts: self.syncMetrics.failedAttempts + 1,
                    dataVersion: self.syncMetrics.dataVersion,
                    isDataCurrent: false
                )
            }
        }
    }
    
   
    
    // MARK: - Active Trip Management
    
    /// Set the current active trip for Watch sync
    func setActiveTrip(_ trip: Trip) {
        activeTripId = trip.id
        currentLegIndex = trip.activeLegIndex ?? 0
        
        // Update current flight data for status view
        if currentLegIndex < trip.legs.count {
            let currentLeg = trip.legs[currentLegIndex]
            updateCurrentFlightData(from: currentLeg, trip: trip)
        }
        
        markDataForSync(type: .trip)
        print("✅ Set active trip: \(trip.tripNumber), on leg \(currentLegIndex + 1)")
    }
    
    /// Get the currently active trip - must be called from MainActor context
    @MainActor
    private func getActiveTrip() -> Trip? {
        guard let tripId = activeTripId,
              let store = logbookStore else { return nil }
        return store.trips.first(where: { $0.id == tripId })
    }
    
    /// Clear the active trip reference
    func clearActiveTrip() {
        activeTripId = nil
        currentLegIndex = 0
        currentFlight = nil
        print("🗑️ Cleared active trip reference")
    }
    
    @MainActor
    private func findActiveTrip() -> Trip? {
        guard let store = logbookStore else {
            print("❌ LogBookStore not available")
            return nil
        }

        // First look for any active/planning trip with LEGS
        let activeTrip = store.trips.first(where: {
            ($0.status == .active || $0.status == .planning) && !$0.legs.isEmpty
        })

        if let trip = activeTrip {
            print("📱 Found active trip by status: \(trip.tripNumber)")
            // Update our cached ID
            activeTripId = trip.id
            currentLegIndex = trip.activeLegIndex ?? 0
            return trip
        }

        // Fallback: check cached ID (but verify it has legs)
        if let tripId = activeTripId,
           let trip = store.trips.first(where: { $0.id == tripId && !$0.legs.isEmpty }) {
            print("📱 Found active trip by ID: \(trip.tripNumber)")
            return trip
        }

        print("⚠️ No active trip found in store")
        return nil
    }
    
    /// Save trip changes to LogBookStore
    @MainActor
    private func saveTrip(_ trip: Trip) {
        guard let store = logbookStore else {
            print("❌ LogBookStore not available")
            return
        }

        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            store.trips[index] = trip
            store.save()
            print("💾 Saved trip changes")
            markDataForSync(type: .trip)
        }
    }
    
    /// Update currentFlight from leg data
    private func updateCurrentFlightData(from leg: FlightLeg, trip: Trip) {
        // Convert String times to Date for WatchFlightData
        let outDate = parseTimeString(leg.outTime)
        let offDate = parseTimeString(leg.offTime)
        let onDate = parseTimeString(leg.onTime)
        let inDate = parseTimeString(leg.inTime)
        
        currentFlight = WatchFlightData(
            departure: leg.departure.isEmpty ? nil : leg.departure,
            arrival: leg.arrival.isEmpty ? nil : leg.arrival,
            outTime: outDate,
            offTime: offDate,
            onTime: onDate,
            inTime: inDate
        )
    }
    
    // MARK: - Time Conversion Helpers
    
    /// Convert "1430" String → Date
    private func parseTimeString(_ timeString: String) -> Date? {
        guard !timeString.isEmpty else { return nil }
        
        // Extract digits only
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        
        // Pad to 4 digits if needed
        let paddedTime = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        
        // Create date with current day + time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = Int(String(paddedTime.prefix(2)))
        components.minute = Int(String(paddedTime.suffix(2)))
        components.timeZone = TimeZone(identifier: "GMT")
        
        return calendar.date(from: components)
    }
    
    /// Parse time string "1430" into Date using a specific date for the day
    private func parseTimeToDate(_ timeString: String?, on date: Date) -> Date? {
        guard let timeString = timeString, !timeString.isEmpty else { return nil }
        
        // Extract digits only
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        
        // Pad to 4 digits if needed
        let paddedTime = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        
        // Create date with trip's date + time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Int(String(paddedTime.prefix(2)))
        components.minute = Int(String(paddedTime.suffix(2)))
        components.timeZone = TimeZone(identifier: "GMT")
        
        return calendar.date(from: components)
    }
    
    /// Convert Date → "1430" String
    private func formatTimeToString(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    private func formatTimeAgo(_ interval: TimeInterval) -> String {
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
    
    // MARK: - Public Store References
    func setReferences(logBookStore: SwiftDataLogBookStore, opsManager: OPSCallingManager, activityManager: PilotActivityManager, locationManager: PilotLocationManager) {
        self.logbookStore = logBookStore
        self.opsManager = opsManager
        self.activityManager = activityManager
        self.locationManager = locationManager
        print("✅ Phone Watch Connectivity initialized and connected to stores")
        
        // CRITICAL: Monitor for active trips and sync to watch
        startMonitoringTrips()
    }
    
    // MARK: - Trip Monitoring
    private func startMonitoringTrips() {
        // Check immediately for any active trip (on main actor)
        Task { @MainActor in
            if let activeTrip = self.findActiveTrip() {
                print("📱 Found active trip on startup: \(activeTrip.tripNumber)")
                self.activeTripId = activeTrip.id
                self.syncTripToWatch(activeTrip)
            }
        }

        // Monitor for trip status changes
        NotificationCenter.default.addObserver(
            forName: .tripStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let trip = notification.object as? Trip else { return }

            print("📱 Trip status changed: \(trip.tripNumber) -> \(trip.status)")

            Task { @MainActor in
                if trip.status == .active || trip.status == .planning {
                    self.activeTripId = trip.id
                    self.syncTripToWatch(trip)
                } else if trip.status == .completed {
                    if self.activeTripId == trip.id {
                        self.activeTripId = nil
                    }
                }
            }
        }

        print("📱 Started monitoring trips for watch sync")
    }
    
    // MARK: - Sync Trip to Watch
    @MainActor
    private func syncTripToWatch(_ trip: Trip) {
        print("📤 Syncing trip \(trip.tripNumber) to watch...")
        
        // Find current leg index
        currentLegIndex = trip.activeLegIndex ?? 0
        
        guard currentLegIndex < trip.legs.count else {
            print("⚠️ Invalid leg index \(currentLegIndex) for trip with \(trip.legs.count) legs")
            return
        }
        
        let currentLeg = trip.legs[currentLegIndex]
        let hasMoreLegs = currentLegIndex < (trip.legs.count - 1)
        
        // Create watch data
        let watchData = WatchFlightData(
            departure: currentLeg.departure,
            arrival: currentLeg.arrival,
            outTime: parseTimeString(currentLeg.outTime),
            offTime: parseTimeString(currentLeg.offTime),
            onTime: parseTimeString(currentLeg.onTime),
            inTime: parseTimeString(currentLeg.inTime)
        )
        
        // Send via both methods for reliability
        sendFlightUpdateDirect(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: trip.id, legId: currentLeg.id)
        sendFlightUpdateViaContext(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: trip.id, legId: currentLeg.id)
        
        print("✅ Trip synced to watch: \(trip.tripNumber), leg \(currentLegIndex + 1)/\(trip.legs.count)")
    }
    
    // MARK: - Public Reset Method
    public func resetConnectionState() {
        DispatchQueue.main.async {
            // Reset sync state
            self.syncState = .notPaired
            self.syncMetrics = SyncMetrics(
                lastSyncTime: nil,
                pendingChanges: 0,
                failedAttempts: 0,
                dataVersion: 0,
                isDataCurrent: false
            )
            self.lastSyncError = nil
            self.isWatchConnected = false
        }
        
        // Re-evaluate connection
        if let session = session {
            session.activate()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.evaluateSyncHealth()
        }
        
        print("📱 Connection state reset")
    }
}

// MARK: - WCSessionDelegate (iPhone)
extension PhoneWatchConnectivity: WCSessionDelegate {
    
    // MARK: - Required iPhone Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Phone session activation failed: \(error.localizedDescription)")
                self.isWatchConnected = false
                self.lastSyncError = error.localizedDescription
                self.updateSyncState(.syncError, detail: "Activation failed")
                return
            }
            
            switch activationState {
            case .activated:
                print("✅ Phone session activated")
                // Only show as connected if watch is paired, app installed, AND reachable
                self.isWatchConnected = session.isWatchAppInstalled && session.isPaired && session.isReachable
                print("📱 Watch status - Paired: \(session.isPaired), App Installed: \(session.isWatchAppInstalled), Reachable: \(session.isReachable)")
                self.evaluateSyncHealth()
                
            case .inactive:
                print("⚠️ Phone session inactive")
                self.isWatchConnected = false
                self.updateSyncState(.bluetoothOnly, detail: "Session inactive")
                
            case .notActivated:
                print("⚠️ Phone session not activated")
                self.isWatchConnected = false
                self.updateSyncState(.notPaired, detail: "Session not activated")
                
            @unknown default:
                print("⚠️ Unknown activation state")
                self.isWatchConnected = false
            }
        }
    }
    
    // iPhone-specific: Called when session becomes inactive
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            print("⚠️ Phone session became inactive")
            self.isWatchConnected = false
            self.updateSyncState(.bluetoothOnly, detail: "Session inactive")
        }
    }
    
    // iPhone-specific: Called when session is deactivated
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            print("⚠️ Phone session deactivated - reactivating")
            self.isWatchConnected = false
            session.activate()
        }
    }
    
    // Optional but recommended: Watch state changes
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            // Update connection status based on reachability
            self.isWatchConnected = session.isWatchAppInstalled && session.isPaired && session.isReachable
            print("⌚ Watch state changed - Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled), Reachable: \(session.isReachable)")
            self.evaluateSyncHealth()
        }
    }
    
    // IMPORTANT: Monitor reachability changes
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isWatchAppInstalled && session.isPaired && session.isReachable
            print("📡 Reachability changed - Watch is now: \(session.isReachable ? "REACHABLE ✅" : "NOT REACHABLE ❌")")
            self.evaluateSyncHealth()
        }
    }
    
    // MARK: - Message Handling
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            guard let type = message["type"] as? String else {
                replyHandler(["error": "Missing type field"])
                self.updateSyncMetrics(success: false)
                return
            }
            
            print("📥 Phone received: \(type)")
            
            switch type {
            case "setTime":
                self.handleSetTimeMessage(message)
                self.updateSyncMetrics(success: true)
                if let reply = self.createFlightUpdateMessage() {
                    replyHandler(reply)
                } else {
                    replyHandler(["status": "received"])
                }

            case "clearTime":
                self.handleClearTimeMessage(message)
                self.updateSyncMetrics(success: true)
                if let reply = self.createFlightUpdateMessage() {
                    replyHandler(reply)
                } else {
                    replyHandler(["status": "received"])
                }

            case "requestNextLeg":
                self.handleRequestNextLeg(message)
                if let reply = self.createFlightUpdateMessage() {
                    replyHandler(reply)
                    self.updateSyncMetrics(success: true)
                } else {
                    replyHandler(["error": "No more legs"])
                    self.updateSyncMetrics(success: false)
                }
                
            case "requestFlightData":
                print("📱 Watch requested flight data")
                
                // Find the active trip BUT DON'T RESET THE LEG INDEX
                if let activeTrip = self.findActiveTrip() {
                    // Find the actual current leg based on which leg has times entered
                    let actualCurrentLeg = activeTrip.activeLegIndex ?? 0
                    self.currentLegIndex = actualCurrentLeg
                    
                    print("📱 Found active trip: \(activeTrip.tripNumber)")
                    print("📱 Current leg: \(actualCurrentLeg + 1) of \(activeTrip.legs.count)")
                    
                    // Update current flight data with the ACTUAL current leg
                    if actualCurrentLeg < activeTrip.legs.count {
                        let currentLeg = activeTrip.legs[actualCurrentLeg]
                        self.updateCurrentFlightData(from: currentLeg, trip: activeTrip)
                        print("📱 Current leg route: \(currentLeg.departure) → \(currentLeg.arrival)")
                        
                        // ✅ FIX: Also update application context with current leg
                        let hasMoreLegs = actualCurrentLeg < activeTrip.legs.count - 1
                        let watchData = WatchFlightData(
                            departure: currentLeg.departure,
                            arrival: currentLeg.arrival,
                            outTime: self.parseTimeString(currentLeg.outTime),
                            offTime: self.parseTimeString(currentLeg.offTime),
                            onTime: self.parseTimeString(currentLeg.onTime),
                            inTime: self.parseTimeString(currentLeg.inTime)
                        )
                        self.sendFlightUpdateViaContext(watchData, legIndex: actualCurrentLeg, hasMoreLegs: hasMoreLegs, tripId: activeTrip.id, legId: currentLeg.id)
                    }
                }
                
                // Create the response with the CURRENT leg data
                if let reply = self.createFlightUpdateMessage() {
                    replyHandler(reply)
                    self.updateSyncMetrics(success: true)
                    print("✅ Sent flight data to watch")
                } else {
                    replyHandler(["error": "No active trip"])
                    self.updateSyncMetrics(success: false)
                    print("⚠️ No active trip to send")
                }
                
            case "startDuty":
                self.handleStartDuty(message)
                replyHandler(["status": "duty started"])
                self.updateSyncMetrics(success: true)
                
            case "endDuty":
                self.handleEndDuty(message)
                replyHandler(["status": "duty ended"])
                self.updateSyncMetrics(success: true)
                
            case "requestDutyStatus":
                let reply = self.createDutyStatusMessage()
                replyHandler(reply)
                self.updateSyncMetrics(success: true)
                
            case "callOPS":
                self.handleCallOPS(message)
                replyHandler(["status": "calling OPS"])
                self.updateSyncMetrics(success: true)
                
            case "ping":
                replyHandler(["status": "pong", "timestamp": Date().timeIntervalSince1970])
                self.updateSyncMetrics(success: true)
                
            case "addNewLegFromWatch":
                // Delegate to shared addNewLegAndBroadcast
                let departure = message["departure"] as? String
                let arrival = message["arrival"] as? String
                let flightNumber = message["flightNumber"] as? String
                self.addNewLegAndBroadcast(departure: departure, arrival: arrival, flightNumber: flightNumber, replyHandler: replyHandler)
                
            case "addNewLeg":
                // New case for addNewLeg message type with same centralized logic
                let departure = message["departure"] as? String
                let arrival = message["arrival"] as? String
                let flightNumber = message["flightNumber"] as? String
                self.addNewLegAndBroadcast(departure: departure, arrival: arrival, flightNumber: flightNumber, replyHandler: replyHandler)
                
            case "createTripFromWatch":
                self.handleCreateTripFromWatch(message, replyHandler: replyHandler)
                
            case "endTrip":
                self.handleEndTrip(message, replyHandler: replyHandler)
                
            default:
                replyHandler(["error": "Unknown message type: \(type)"])
                self.updateSyncMetrics(success: false)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("📥 Phone received application context")
            self.updateSyncMetrics(success: true)
            // Handle any context updates from watch
        }
    }
}

// MARK: - Watch Message Sending
extension PhoneWatchConnectivity {
    
    // MARK: - Test Connection
    func testWatchConnection() {
        guard let session = session, session.isReachable else {
            print("⚠️ Cannot test - watch not reachable")
            updateSyncState(.bluetoothOnly, detail: "Watch not reachable")
            return
        }
        
        let message: [String: Any] = ["type": "ping", "timestamp": Date().timeIntervalSince1970]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            print("✅ Watch ping successful: \(reply)")
            self?.updateSyncMetrics(success: true)
        }) { [weak self] error in
            print("❌ Watch ping failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self?.lastSyncError = error.localizedDescription
            }
            self?.updateSyncMetrics(success: false)
        }
    }
    
    // Send a ping to watch to test connection
    func sendPingToWatch() {
        testWatchConnection()
    }
    
    // MARK: - ✅ NEW: Comprehensive Sync Method
    func syncCurrentLegToWatch() {
        Task { @MainActor in
            guard let trip = findActiveTrip(),
                  !trip.legs.isEmpty else {
                print("📱 No active trip to sync")
                updateSyncState(.synced, detail: "No active trip")
                return
            }

            // Find the actual current leg
            currentLegIndex = trip.activeLegIndex ?? 0

            updateSyncState(.syncInProgress, detail: "Syncing leg data...")

            let currentLeg = trip.legs[min(currentLegIndex, trip.legs.count - 1)]
            let hasMoreLegs = currentLegIndex < trip.legs.count - 1

            print("📱 🔄 SYNCING LEG \(currentLegIndex + 1) TO WATCH")
            print("📱    Departure: \(currentLeg.departure)")
            print("📱    Arrival: \(currentLeg.arrival)")
            print("📱    Has more legs: \(hasMoreLegs)")
            if !currentLeg.outTime.isEmpty { print("📱    OUT: \(currentLeg.outTime)") }
            if !currentLeg.offTime.isEmpty { print("📱    OFF: \(currentLeg.offTime)") }
            if !currentLeg.onTime.isEmpty { print("📱    ON: \(currentLeg.onTime)") }
            if !currentLeg.inTime.isEmpty { print("📱    IN: \(currentLeg.inTime)") }

            // Convert leg times to WatchFlightData
            let watchData = WatchFlightData(
                departure: currentLeg.departure,
                arrival: currentLeg.arrival,
                outTime: parseTimeString(currentLeg.outTime),
                offTime: parseTimeString(currentLeg.offTime),
                onTime: parseTimeString(currentLeg.onTime),
                inTime: parseTimeString(currentLeg.inTime)
            )

            // Send both immediate message AND application context
            sendFlightUpdateDirect(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: trip.id, legId: currentLeg.id)
            sendFlightUpdateViaContext(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: trip.id, legId: currentLeg.id)
        }
    }
    
    // MARK: - Send Flight Update (Direct Message)
    @MainActor
    func sendFlightUpdateDirect(_ flight: WatchFlightData, legIndex: Int = 0, hasMoreLegs: Bool = false, tripId: UUID? = nil, legId: UUID? = nil) {
        guard let session = session, session.isReachable else {
            print("⚠️ Watch not reachable for direct message")
            updateSyncState(.bluetoothOnly, detail: "Watch not reachable")
            return
        }
        
        var message: [String: Any] = [
            "type": "flightUpdate",
            "legIndex": legIndex,
            "totalLegs": 0,  // ✅ Will be set below if tripId provided
            "hasMoreLegs": hasMoreLegs,
            "timestamp": Date().timeIntervalSince1970,
            "dataVersion": dataVersionTracker.currentVersion,
            "useZuluTime": AutoTimeSettings.shared.useZuluTime
        ]
        
        if let departure = flight.departure { message["departure"] = departure }
        if let arrival = flight.arrival { message["arrival"] = arrival }
        if let outTime = flight.outTime { message["outTime"] = outTime.timeIntervalSince1970 }
        if let offTime = flight.offTime { message["offTime"] = offTime.timeIntervalSince1970 }
        if let onTime = flight.onTime { message["onTime"] = onTime.timeIntervalSince1970 }
        if let inTime = flight.inTime { message["inTime"] = inTime.timeIntervalSince1970 }
        if let tripId = tripId { 
            message["tripId"] = tripId.uuidString
            // ✅ Calculate totalLegs from the trip
            if let trip = findActiveTrip(), trip.id == tripId {
                message["totalLegs"] = trip.legs.count
                print("📱 Added totalLegs=\(trip.legs.count) to direct message")
            }
        }
        if let legId = legId { message["legId"] = legId.uuidString }
        
        print("📱 Direct flight update message: \(message)")
        
        session.sendMessage(message, replyHandler: { [weak self] _ in
            print("✅ Direct flight update sent successfully")
            self?.updateSyncMetrics(success: true)
            self?.updateSyncState(.synced, detail: "Flight data synced")
        }) { [weak self] error in
            print("⚠️ Direct message failed (expected if watch backgrounded): \(error.localizedDescription)")
            DispatchQueue.main.async {
                self?.lastSyncError = error.localizedDescription
            }
            // Don't mark as failed - application context will handle it
        }
    }
    
    // MARK: - Send Flight Update (Application Context - Guaranteed Delivery)
    @MainActor
    private func sendFlightUpdateViaContext(_ flight: WatchFlightData, legIndex: Int = 0, hasMoreLegs: Bool = false, tripId: UUID? = nil, legId: UUID? = nil) {
        guard let session = session else {
            print("⚠️ No session for application context")
            return
        }
        
        var context: [String: Any] = [
            "type": "flightUpdate",
            "legIndex": legIndex,
            "totalLegs": 0,  // ✅ Will be set below if tripId provided
            "hasMoreLegs": hasMoreLegs,
            "timestamp": Date().timeIntervalSince1970,
            "dataVersion": dataVersionTracker.currentVersion,
            "useZuluTime": AutoTimeSettings.shared.useZuluTime
        ]
        
        if let departure = flight.departure { context["departure"] = departure }
        if let arrival = flight.arrival { context["arrival"] = arrival }
        if let outTime = flight.outTime { context["outTime"] = outTime.timeIntervalSince1970 }
        if let offTime = flight.offTime { context["offTime"] = offTime.timeIntervalSince1970 }
        if let onTime = flight.onTime { context["onTime"] = onTime.timeIntervalSince1970 }
        if let inTime = flight.inTime { context["inTime"] = inTime.timeIntervalSince1970 }
        if let tripId = tripId { 
            context["tripId"] = tripId.uuidString
            // ✅ Calculate totalLegs from the trip
            if let trip = findActiveTrip(), trip.id == tripId {
                context["totalLegs"] = trip.legs.count
                print("📱 Added totalLegs=\(trip.legs.count) to application context")
            }
        }
        if let legId = legId { context["legId"] = legId.uuidString }
        
        do {
            try session.updateApplicationContext(context)
            print("📱 ✅ Application Context updated - guaranteed delivery when watch wakes")
            updateSyncMetrics(success: true)
            updateSyncState(.synced, detail: "Data queued for sync")
        } catch {
            print("📱 ❌ Failed to update application context: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastSyncError = error.localizedDescription
            }
            updateSyncMetrics(success: false)
            updateSyncState(.syncError, detail: "Context update failed")
        }
    }
    
    // MARK: - Send Duty Status
    func sendDutyStatusToWatch() {
        guard let session = session else { return }
        
        let message = createDutyStatusMessage()
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] _ in
                print("✅ Duty status sent to watch")
                self?.updateSyncMetrics(success: true)
            }) { [weak self] error in
                print("❌ Failed to send duty status: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastSyncError = error.localizedDescription
                }
            }
        }
        
        // Also update application context for guaranteed delivery
        do {
            try session.updateApplicationContext(message)
            print("✅ Duty status saved to context")
        } catch {
            print("❌ Failed to update duty context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Duty Timer Update (Used by DutyTimerManager)
    func sendDutyTimerUpdate(isRunning: Bool, startTime: Date?, tripId: UUID? = nil) {
        guard let session = session else { return }
        
        var message: [String: Any] = [
            "type": "dutyTimer",
            "isRunning": isRunning,
            "startTime": startTime?.timeIntervalSince1970 ?? 0
        ]
        
        if let tripId = tripId {
            message["tripId"] = tripId.uuidString
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] _ in
                print("✅ Duty timer update sent to watch")
                self?.updateSyncMetrics(success: true)
            }) { [weak self] error in
                print("❌ Failed to send duty timer update: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastSyncError = error.localizedDescription
                }
            }
        }
        
        // Also update application context for guaranteed delivery
        do {
            try session.updateApplicationContext(message)
            print("✅ Duty timer update saved to context")
        } catch {
            print("❌ Failed to update duty timer context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Messages
    @MainActor
    private func createFlightUpdateMessage() -> [String: Any]? {
        guard let trip = findActiveTrip(),
              !trip.legs.isEmpty else {
            print("❌ No active trip to create flight update message")
            return nil
        }
        
        // ✅ DEBUG: Show current state
        print("📱 DEBUG createFlightUpdateMessage:")
        print("📱   currentLegIndex = \(currentLegIndex)")
        print("📱   trip.legs.count = \(trip.legs.count)")
        print("📱   trip.activeLegIndex = \(trip.activeLegIndex ?? -1)")
        for (i, leg) in trip.legs.enumerated() {
            print("📱   Leg \(i): \(leg.departure)→\(leg.arrival) status=\(leg.status)")
        }
        
        // ✅ FIX: Find the ACTIVE leg, not just currentLegIndex
        let activeLegIndex: Int
        if let tripActiveLeg = trip.activeLegIndex, tripActiveLeg >= 0 && tripActiveLeg < trip.legs.count {
            // Use trip's activeLegIndex if valid
            activeLegIndex = tripActiveLeg
            print("📱 Using trip's activeLegIndex: \(activeLegIndex)")
        } else {
            // Otherwise find first active leg (not completed or skipped)
            if let firstActiveIndex = trip.legs.firstIndex(where: { $0.status == .active }) {
                activeLegIndex = firstActiveIndex
                print("📱 Found first active leg at index: \(activeLegIndex)")
            } else {
                // All legs complete - use last leg
                activeLegIndex = trip.legs.count - 1
                print("📱 All legs complete - using last leg: \(activeLegIndex)")
            }
        }
        
        // ✅ VALIDATION: Clamp to valid range
        let validatedIndex = min(max(0, activeLegIndex), trip.legs.count - 1)
        if validatedIndex != activeLegIndex {
            print("⚠️ WARNING: activeLegIndex \(activeLegIndex) out of bounds, clamped to \(validatedIndex)")
        }
        
        // Update our cached index
        currentLegIndex = validatedIndex
        
        let leg = trip.legs[validatedIndex]  // ✅ Use validated index
        let hasMoreLegs = currentLegIndex < trip.legs.count - 1
        
        var message: [String: Any] = [
            "type": "flightUpdate",
            "tripId": trip.id.uuidString,
            "legId": leg.id.uuidString,  // ✅ ADD LEG UUID
            "tripNumber": trip.tripNumber,
            "aircraft": trip.aircraft,
            "legIndex": currentLegIndex,
            "totalLegs": trip.legs.count,
            "hasMoreLegs": hasMoreLegs,
            "departure": leg.departure,
            "arrival": leg.arrival,
            "flightNumber": leg.flightNumber,
            "dataVersion": dataVersionTracker.currentVersion,
            "timestamp": Date().timeIntervalSince1970,
            "useZuluTime": AutoTimeSettings.shared.useZuluTime  // ADD ZULU TIME SETTING
        ]
        
        // Add times if available
        if let outTime = parseTimeString(leg.outTime) {
            message["outTime"] = outTime.timeIntervalSince1970
        }
        if let offTime = parseTimeString(leg.offTime) {
            message["offTime"] = offTime.timeIntervalSince1970
        }
        if let onTime = parseTimeString(leg.onTime) {
            message["onTime"] = onTime.timeIntervalSince1970
        }
        if let inTime = parseTimeString(leg.inTime) {
            message["inTime"] = inTime.timeIntervalSince1970
        }
        
        print("📱 Created flight update message for trip: \(trip.tripNumber), leg \(currentLegIndex + 1) of \(trip.legs.count)")
        print("📱    Route: \(leg.departure) → \(leg.arrival)")
        print("📱    Sending legIndex=\(currentLegIndex), totalLegs=\(trip.legs.count)")
        if !leg.outTime.isEmpty { print("📱    OUT: \(leg.outTime)") }
        print("📱 FULL MESSAGE CONTENT: \(message)")
        
        return message
    }
    
    private func createDutyStatusMessage() -> [String: Any] {
        var message: [String: Any] = [
            "type": "dutyStatus",
            "isDutyRunning": isDutyTimerRunning
        ]
        
        if let startTime = dutyStartTime {
            message["dutyStartTime"] = startTime.timeIntervalSince1970
        }
        
        return message
    }
}

// MARK: - Message Handlers
extension PhoneWatchConnectivity {
    
    private func handleSetTimeMessage(_ message: [String: Any]) {
        guard let timeType = message["timeType"] as? String,
              let timestamp = message["timestamp"] as? Double else {
            print("❌ Invalid setTime message format")
            return
        }

        let legIndex = message["legIndex"] as? Int ?? currentLegIndex
        let time = Date(timeIntervalSince1970: timestamp)
        let timeString = formatTimeToString(time)

        print("📱 Setting \(timeType) time to \(timeString) for leg \(legIndex)")

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            // Update the trip
            guard var trip = self.findActiveTrip(),
                  legIndex < trip.legs.count else {
                print("❌ No active trip or invalid leg index")
                return
            }

            switch timeType {
            case "OUT":
                trip.legs[legIndex].outTime = timeString
                // When OUT is set, make sure we're on this leg
                self.currentLegIndex = legIndex
            case "OFF":
                trip.legs[legIndex].offTime = timeString
            case "ON":
                trip.legs[legIndex].onTime = timeString
            case "IN":
                trip.legs[legIndex].inTime = timeString

                // ✅ Check if leg is complete and advance
                let leg = trip.legs[legIndex]
                let isComplete = !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
                               !leg.onTime.isEmpty && !leg.inTime.isEmpty

                if isComplete {
                    // Let Trip handle advancement logic
                    trip.checkAndAdvanceLeg(at: legIndex)

                    // Update our cached index from Trip's source of truth
                    if let activeLegIndex = trip.activeLegIndex {
                        self.currentLegIndex = activeLegIndex
                        print("📱 Leg \(legIndex + 1) complete - advanced to leg \(activeLegIndex + 1)")
                    } else {
                        print("📱 Leg \(legIndex + 1) complete - last leg")
                    }
                } else {
                    print("📱 Leg \(legIndex + 1) IN time set (not yet complete)")
                }

            default:
                print("❌ Unknown time type: \(timeType)")
                return
            }

            self.saveTrip(trip)
            self.markDataForSync(type: .flightTimes)

            // Activity manager update - method doesn't exist yet
            // TODO: Implement updateFlightTime in PilotActivityManager if needed

            // Send confirmation back with updated data
            self.syncCurrentLegToWatch()
        }
    }

    /// Handle clear time message from watch - sets time to empty string (nil)
    private func handleClearTimeMessage(_ message: [String: Any]) {
        guard let timeType = message["timeType"] as? String else {
            print("❌ Invalid clearTime message format")
            return
        }

        let legIndex = message["legIndex"] as? Int ?? currentLegIndex

        print("📱 Clearing \(timeType) time for leg \(legIndex)")

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard var trip = self.findActiveTrip(),
                  legIndex < trip.legs.count else {
                print("❌ No active trip or invalid leg index")
                return
            }

            switch timeType {
            case "OUT":
                trip.legs[legIndex].outTime = ""
            case "OFF":
                trip.legs[legIndex].offTime = ""
            case "ON":
                trip.legs[legIndex].onTime = ""
            case "IN":
                trip.legs[legIndex].inTime = ""
            default:
                print("❌ Unknown time type: \(timeType)")
                return
            }

            self.saveTrip(trip)
            self.markDataForSync(type: .flightTimes)

            print("📱 ✅ Cleared \(timeType) time for leg \(legIndex + 1)")

            // Send confirmation back with updated data
            self.syncCurrentLegToWatch()
        }
    }

    private func handleRequestNextLeg(_ message: [String: Any]) {
        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard var trip = self.findActiveTrip() else {
                print("❌ No active trip for next leg")
                return
            }

            // ✅ FIX: Use Trip's advancement logic
            let currentIndex = trip.activeLegIndex ?? 0

            // Check if current leg is complete before advancing
            if currentIndex < trip.legs.count {
                trip.checkAndAdvanceLeg(at: currentIndex)
            }

            // Save the updated trip
            self.saveTrip(trip)

            // Update our cache from Trip's source of truth
            self.currentLegIndex = trip.activeLegIndex ?? 0

            print("📱 ✅ Advanced to leg \(self.currentLegIndex + 1) of \(trip.legs.count)")

            // Sync the new leg to watch
            self.syncCurrentLegToWatch()
        }
    }
    
    private func handleStartDuty(_ message: [String: Any]) {
        print("📱 Starting duty timer from watch request")

        // ✅ DEBUG LOGGING
        print("📍 DEBUG: locationManager exists: \(locationManager != nil)")
        print("📍 DEBUG: currentAirport: '\(locationManager?.currentAirport ?? "nil")'")
        print("📍 DEBUG: nearbyAirports count: \(locationManager?.nearbyAirports.count ?? 0)")

        if let locationManager = locationManager {
            for (index, airport) in locationManager.nearbyAirports.prefix(3).enumerated() {
                print("📍 DEBUG: Airport \(index): \(airport.icao) - \(airport.name)")
            }
        }

        // Get current location/airport
        let currentAirport = locationManager?.currentAirport ?? "ZZZZ"
        let airportName = locationManager?.nearbyAirports.first?.name ?? "Unknown"

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard let store = self.logbookStore else {
                print("❌ LogBookStore not available")
                return
            }

            // ✅ FIXED: First check if there's ALREADY an active trip
            if let existingActiveTrip = self.findActiveTrip() {
            print("📱 Found existing active trip: \(existingActiveTrip.tripNumber) - syncing to watch")
            
            // Don't create a new trip - just sync the existing one!
            setActiveTrip(existingActiveTrip)
            
            // Get current leg info
            let currentLeg = existingActiveTrip.legs.indices.contains(currentLegIndex)
                ? existingActiveTrip.legs[currentLegIndex]
                : existingActiveTrip.legs.first
            
            // Send existing trip data to watch
            let watchData = WatchFlightData(
                departure: currentLeg?.departure ?? currentAirport,
                arrival: currentLeg?.arrival ?? "",
                outTime: parseTimeToDate(currentLeg?.outTime, on: existingActiveTrip.date),
                offTime: parseTimeToDate(currentLeg?.offTime, on: existingActiveTrip.date),
                onTime: parseTimeToDate(currentLeg?.onTime, on: existingActiveTrip.date),
                inTime: parseTimeToDate(currentLeg?.inTime, on: existingActiveTrip.date)
            )
            
            let hasMoreLegs = currentLegIndex < existingActiveTrip.legs.count - 1
            sendFlightUpdateDirect(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: existingActiveTrip.id, legId: currentLeg?.id)
            sendFlightUpdateViaContext(watchData, legIndex: currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: existingActiveTrip.id, legId: currentLeg?.id)
            
            // Only update duty timer if NOT already running
            if !isDutyTimerRunning {
                isDutyTimerRunning = true
                // Use existing trip's perDiem start or current time
                dutyStartTime = existingActiveTrip.perDiemStarted ?? Date()
                
                // Post notification for UI update
                NotificationCenter.default.post(
                    name: .dutyTimerStarted,
                    object: nil,
                    userInfo: ["startTime": dutyStartTime ?? Date()]
                )
            }
            
            markDataForSync(type: .dutyTimer)
            sendDutyStatusToWatch()
            
            print("✅ Synced existing trip \(existingActiveTrip.tripNumber) to watch (duty already active: \(isDutyTimerRunning))")
            return
        }
        
        // No active trip - check if there's a planning trip we should activate
        if let planningTrip = store.trips.first(where: { $0.status == .planning }) {
            print("📱 Found planning trip: \(planningTrip.tripNumber) - activating")
            
            var activatedTrip = planningTrip
            activatedTrip.status = .active
            activatedTrip.perDiemStarted = Date()
            
            if let index = store.trips.firstIndex(where: { $0.id == planningTrip.id }) {
                store.updateTrip(activatedTrip, at: index)
            }
            
            setActiveTrip(activatedTrip)
            
            // Get current leg info
            let currentLeg = activatedTrip.legs.first
            
            // Send trip data to watch
            let watchData = WatchFlightData(
                departure: currentLeg?.departure ?? currentAirport,
                arrival: currentLeg?.arrival ?? "",
                outTime: nil,
                offTime: nil,
                onTime: nil,
                inTime: nil
            )
            
            let hasMoreLegs = activatedTrip.legs.count > 1
            sendFlightUpdateDirect(watchData, legIndex: 0, hasMoreLegs: hasMoreLegs, tripId: activatedTrip.id, legId: currentLeg?.id)
            sendFlightUpdateViaContext(watchData, legIndex: 0, hasMoreLegs: hasMoreLegs, tripId: activatedTrip.id, legId: currentLeg?.id)
            
            // Start Live Activity if available
            if let activityManager = activityManager {
                Task { @MainActor in
                    activityManager.startActivity(
                        tripNumber: activatedTrip.tripNumber,
                        aircraft: activatedTrip.aircraft,
                        departure: currentLeg?.departure ?? currentAirport,
                        arrival: currentLeg?.arrival ?? "",
                        currentAirport: currentAirport,
                        currentAirportName: airportName,
                        dutyStartTime: Date()
                    )
                }
            }
            
            // Notify ContentView about trip activation
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: activatedTrip
            )
            
            print("✅ Activated planning trip \(activatedTrip.tripNumber) from Watch")
            
        } else {
            // No active or planning trips - create new trip
            let formatter = DateFormatter()
            formatter.dateFormat = "MMdd"
            let tripNumber = "W\(formatter.string(from: Date()))" // W prefix for Watch-created
            
            // Create leg with scheduledOut for proper sorting
            var watchLeg = FlightLeg(
                departure: currentAirport,
                arrival: "",
                outTime: "",
                offTime: "",
                onTime: "",
                inTime: "",
                flightNumber: ""
            )
            watchLeg.scheduledOut = Date()  // ✅ Set date for proper sorting with roster legs
            
            let newTrip = Trip(
                id: UUID(),
                tripNumber: tripNumber,
                aircraft: "TBD",
                date: Date(),
                tatStart: "",
                crew: [],
                notes: "Created from Apple Watch",
                legs: [watchLeg],
                tripType: .operating,
                status: .active,
                pilotRole: .captain,
                receiptCount: 0,
                logbookPageSent: false,
                perDiemStarted: Date(),
                perDiemEnded: nil
            )
            
            store.addTrip(newTrip)
            setActiveTrip(newTrip)
            print("✅ Created trip \(tripNumber) from Watch at \(currentAirport)")
            
            // Send updated flight data back to watch
            let watchData = WatchFlightData(
                departure: currentAirport,
                arrival: "",
                outTime: nil,
                offTime: nil,
                onTime: nil,
                inTime: nil
            )
            sendFlightUpdateDirect(watchData, legIndex: 0, hasMoreLegs: false, tripId: newTrip.id, legId: watchLeg.id)
            sendFlightUpdateViaContext(watchData, legIndex: 0, hasMoreLegs: false, tripId: newTrip.id, legId: watchLeg.id)
            
            // Start Live Activity if available
            if let activityManager = activityManager {
                Task { @MainActor in
                    activityManager.startActivity(
                        tripNumber: tripNumber,
                        aircraft: "TBD",
                        departure: currentAirport,
                        arrival: "",
                        currentAirport: currentAirport,
                        currentAirportName: airportName,
                        dutyStartTime: Date()
                    )
                }
            }
            
            // Notify ContentView about new trip
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: newTrip
            )
        }
        
        // Update duty timer state (only if not already running)
        if !isDutyTimerRunning {
            isDutyTimerRunning = true
            dutyStartTime = Date()
            
            // Post notification for UI update
            NotificationCenter.default.post(
                name: .dutyTimerStarted,
                object: nil,
                userInfo: ["startTime": Date()]
            )
        }
        
            self.markDataForSync(type: .dutyTimer)
            self.sendDutyStatusToWatch()
        }
    }

    private func handleEndDuty(_ message: [String: Any]) {
        print("📱 Ending duty timer from watch request")

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            // Find and complete the active trip
            if let activeTrip = self.findActiveTrip(),
               let store = self.logbookStore,
               let tripIndex = store.trips.firstIndex(where: { $0.id == activeTrip.id }) {

                var updatedTrip = activeTrip
                updatedTrip.status = .completed
                store.updateTrip(updatedTrip, at: tripIndex)

                print("✅ Completed trip \(updatedTrip.tripNumber) from watch request")

                // Notify phone app about trip completion
                NotificationCenter.default.post(
                    name: .tripStatusChanged,
                    object: updatedTrip
                )

                // Clear the active trip ID
                self.activeTripId = nil

                // Send clear trip message to watch
                self.sendClearTripToWatch()
            }

            // End activity manager if available (main actor isolated)
            if let activityManager = self.activityManager {
                activityManager.endActivity()
            }

            // Update local duty state
            self.isDutyTimerRunning = false
            self.dutyStartTime = nil

            self.markDataForSync(type: .dutyTimer)
            self.sendDutyStatusToWatch()

            print("✅ Duty ended and trip completed from watch")
        }
    }
    
    // MARK: - FBO Alert to Watch

    /// Send FBO contact alert to watch with haptic notification
    func sendFBOAlertToWatch(airportCode: String, fboName: String, distanceNM: Double, unicomFrequency: String?) {
        guard let session = session else { return }

        var message: [String: Any] = [
            "type": "fboAlert",
            "airportCode": airportCode,
            "fboName": fboName,
            "distanceNM": distanceNM,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let unicom = unicomFrequency {
            message["unicomFrequency"] = unicom
        }

        // Send via direct message for immediate haptic
        if session.isReachable {
            session.sendMessage(message, replyHandler: { _ in
                print("✅ FBO alert sent to watch: \(airportCode)")
            }) { error in
                print("⚠️ Failed to send FBO alert to watch: \(error.localizedDescription)")
            }
        }

        // Also send via application context for guaranteed delivery
        do {
            try session.updateApplicationContext(message)
            print("✅ FBO alert saved to context for watch")
        } catch {
            print("❌ Failed to update FBO alert context: \(error.localizedDescription)")
        }

        markDataForSync(type: .fboAlert)
    }

    /// Send clear trip message to watch
    func sendClearTripToWatch() {
        guard let session = session else { return }
        
        let message: [String: Any] = [
            "type": "clearTrip",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Send via direct message
        if session.isReachable {
            session.sendMessage(message, replyHandler: { _ in
                print("✅ Clear trip message sent to watch")
            }) { error in
                print("⚠️ Failed to send clear trip message: \(error.localizedDescription)")
            }
        }
        
        // Also send via application context for guaranteed delivery
        do {
            try session.updateApplicationContext(message)
            print("✅ Clear trip saved to context")
        } catch {
            print("❌ Failed to update clear trip context: \(error.localizedDescription)")
        }
    }
    
    private func handleCallOPS(_ message: [String: Any]) {
        print("📱 Calling OPS from watch request")
        
        // Extract call details from message
        let isEmergency = message["isEmergency"] as? Bool ?? false
        let airport = message["airport"] as? String ?? locationManager?.currentAirport ?? "Unknown"
        
        if let opsManager = opsManager {
            if isEmergency {
                opsManager.callOPSEmergency()
            } else {
                opsManager.callOPS(reason: .manual, airport: airport, isAutomatic: false)
            }
            print("📱 OPS call triggered for \(airport)")
        } else {
            print("⚠️ OPS manager not available - cannot place call")
        }
    }
    
    private func handleAddNewLegFromWatch(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Extract fields
        let departure = message["departure"] as? String
        let arrival = message["arrival"] as? String
        let flightNumber = message["flightNumber"] as? String
        
        // Delegate to centralized method
        addNewLegAndBroadcast(departure: departure, arrival: arrival, flightNumber: flightNumber, replyHandler: replyHandler)
    }
    
    private func addNewLegAndBroadcast(departure: String?, arrival: String?, flightNumber: String?, replyHandler: @escaping ([String: Any]) -> Void) {
        // Capture locationManager before async to avoid potential issues
        let currentAirport = locationManager?.currentAirport ?? "ZZZZ"

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard var activeTrip = self.findActiveTrip() else {
                replyHandler(["error": "No active trip"])
                return
            }

            // Determine defaults
            let lastLeg = activeTrip.legs.last

            // Departure: if nil or empty, use last leg's arrival or current airport
            let dep: String
            if let departure = departure, !departure.isEmpty {
                dep = departure
            } else if let lastArrival = lastLeg?.arrival, !lastArrival.isEmpty {
                dep = lastArrival
            } else {
                dep = currentAirport
            }

            // Arrival: if nil or empty, use placeholder
            let arr: String
            if let arrival = arrival, !arrival.isEmpty {
                arr = arrival
            } else {
                arr = ""  // Use placeholder instead of empty string
            }

            // Flight number: if nil or empty, use last leg's flight number
            let fn = (flightNumber?.isEmpty ?? true) ? (lastLeg?.flightNumber ?? "") : flightNumber!

            // Create new leg with empty times and scheduledOut for sorting
            var newLeg = FlightLeg(
                departure: dep,
                arrival: arr,
                outTime: "",
                offTime: "",
                onTime: "",
                inTime: "",
                flightNumber: fn
            )
            newLeg.scheduledOut = Date()

            // ✅ Check if ALL previous legs have ALL times complete
            let allPreviousComplete = activeTrip.legs.allSatisfy { leg in
                !leg.outTime.isEmpty &&
                !leg.offTime.isEmpty &&
                !leg.onTime.isEmpty &&
                !leg.inTime.isEmpty
            }

            if allPreviousComplete {
                newLeg.status = .active  // Ready to fly - no backlog
                print("✅ New leg from WATCH set to ACTIVE (all previous legs fully complete)")
            } else {
                newLeg.status = .standby  // Waiting - incomplete legs ahead
                print("⏸️ New leg from WATCH set to STANDBY (previous legs have missing times)")
            }

            activeTrip.legs.append(newLeg)
            let newLegIndex = activeTrip.legs.count - 1

            // ✅ FIX: Check if previous leg is complete and advance
            if newLegIndex > 0 {
                activeTrip.checkAndAdvanceLeg(at: newLegIndex - 1)
            }

            self.saveTrip(activeTrip)

            // ✅ FIX: Use Trip's source of truth, not manual index
            self.currentLegIndex = activeTrip.activeLegIndex ?? 0

            print("📱 ✅ Adding new leg \(newLegIndex + 1): \(dep) → \(arr) (status: standby)")

            // ✅ FIXED: Get the CURRENT leg (which may have advanced) and send that to watch
            let currentLeg = activeTrip.legs[self.currentLegIndex]
            let hasMoreLegs = self.currentLegIndex < activeTrip.legs.count - 1

            let watchData = WatchFlightData(
                departure: currentLeg.departure,
                arrival: currentLeg.arrival,
                outTime: self.parseTimeString(currentLeg.outTime),
                offTime: self.parseTimeString(currentLeg.offTime),
                onTime: self.parseTimeString(currentLeg.onTime),
                inTime: self.parseTimeString(currentLeg.inTime)
            )

            // Send update back to watch with CURRENT leg
            self.sendFlightUpdateDirect(watchData, legIndex: self.currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: activeTrip.id, legId: currentLeg.id)
            self.sendFlightUpdateViaContext(watchData, legIndex: self.currentLegIndex, hasMoreLegs: hasMoreLegs, tripId: activeTrip.id, legId: currentLeg.id)

            // ✅ CRITICAL FIX: Notify UI about trip changes so new leg row appears
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: activeTrip
            )

            if let reply = self.createFlightUpdateMessage() {
                replyHandler(reply)
            } else {
                replyHandler([
                    "success": true,
                    "legIndex": newLegIndex,
                    "totalLegs": activeTrip.legs.count
                ])
            }

            print("✅ Added new leg from watch: \(fn) \(dep)-\(arr)")
        }
    }
    
    private func handleCreateTripFromWatch(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Creating trip from watch request")

        // Extract trip details from message (can be done outside main actor)
        let departure = message["departure"] as? String ?? locationManager?.currentAirport ?? "ZZZZ"
        let arrival = message["arrival"] as? String ?? ""
        let aircraft = message["aircraft"] as? String ?? "TBD"
        let tripNumber = message["tripNumber"] as? String ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMdd"
            return "W\(formatter.string(from: Date()))"
        }()

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard let store = self.logbookStore else {
                replyHandler(["error": "LogBook not available"])
                return
            }

            // Create leg with scheduledOut for proper sorting
            var watchLeg = FlightLeg(
                departure: departure,
                arrival: arrival,
                outTime: "",
                offTime: "",
                onTime: "",
                inTime: "",
                flightNumber: ""
            )
            watchLeg.scheduledOut = Date()  // ✅ Set date for proper sorting with roster legs

            // Create Trip with departure/arrival
            let newTrip = Trip(
                id: UUID(),
                tripNumber: tripNumber,
                aircraft: aircraft,
                date: Date(),
                tatStart: "",
                crew: [],
                notes: "Created from Apple Watch",
                legs: [watchLeg],
                tripType: .operating,
                status: .active,
                pilotRole: .captain,
                receiptCount: 0,
                logbookPageSent: false,
                perDiemStarted: Date(),
                perDiemEnded: nil
            )

            store.addTrip(newTrip)
            self.setActiveTrip(newTrip)

            self.markDataForSync(type: .trip)

            // Send confirmation back to watch with full flight data
            let watchData = WatchFlightData(
                departure: departure,
                arrival: arrival,
                outTime: nil,
                offTime: nil,
                onTime: nil,
                inTime: nil
            )
            self.sendFlightUpdateDirect(watchData, legIndex: 0, hasMoreLegs: false, tripId: newTrip.id, legId: watchLeg.id)
            self.sendFlightUpdateViaContext(watchData, legIndex: 0, hasMoreLegs: false, tripId: newTrip.id, legId: watchLeg.id)

            replyHandler([
                "success": true,
                "tripId": newTrip.id.uuidString,
                "tripNumber": tripNumber,
                "departure": departure,
                "arrival": arrival
            ])

            // Notify ContentView about new trip
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: newTrip
            )

            print("✅ Created trip \(tripNumber) from Watch: \(departure) → \(arrival)")
        }
    }
    
    private func handleEndTrip(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Ending trip from watch request")

        // Run on main actor for SwiftData store access
        Task { @MainActor in
            guard let store = self.logbookStore else {
                replyHandler(["error": "LogBook not available"])
                self.updateSyncMetrics(success: false)
                return
            }

            // Find the active trip
            guard let activeTrip = self.findActiveTrip(),
                  let tripIndex = store.trips.firstIndex(where: { $0.id == activeTrip.id }) else {
                replyHandler(["error": "No active trip found"])
                self.updateSyncMetrics(success: false)
                print("❌ No active trip to end")
                return
            }

            // Mark trip as completed
            var updatedTrip = activeTrip
            updatedTrip.status = .completed

            store.updateTrip(updatedTrip, at: tripIndex)

            // Clear the active trip
            self.clearActiveTrip()

            // Mark for sync
            self.markDataForSync(type: .trip)

            // Send success response
            replyHandler([
                "success": true,
                "tripNumber": updatedTrip.tripNumber,
                "status": "completed"
            ])

            self.updateSyncMetrics(success: true)

            // Send clear trip message to watch
            self.sendClearTripToWatch()

            // Notify ContentView about trip completion
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: updatedTrip
            )

            print("✅ Ended trip \(updatedTrip.tripNumber) from watch")
            print("📤 Sent completion confirmation to watch")
        }
    }
}

// MARK: - Supporting Types for Sync
enum DataSyncState: String {
    case notPaired = "No Watch"
    case bluetoothOnly = "BT Connected"
    case dataStale = "Data Stale"
    case syncInProgress = "Syncing..."
    case synced = "Synced"
    case syncError = "Sync Error"
}

struct SyncMetrics {
    let lastSyncTime: Date?
    let pendingChanges: Int
    let failedAttempts: Int
    let dataVersion: Int
    let isDataCurrent: Bool
    
    var timeSinceSync: TimeInterval? {
        guard let lastSync = lastSyncTime else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    var syncHealthScore: Double {
        var score = 100.0
        
        if let timeSince = timeSinceSync {
            if timeSince > 300 { score -= 20 }
            if timeSince > 900 { score -= 20 }
            if timeSince > 3600 { score -= 20 }
        } else {
            score -= 50
        }
        
        score -= Double(pendingChanges * 5)
        score -= Double(failedAttempts * 10)
        
        return max(0, score)
    }
}

class DataVersionTracker {
    private var version: Int = 0
    var currentVersion: Int { version }
    func increment() { version += 1 }
}

class PendingSyncQueue {
    private var queue: Set<DataType> = []
    var count: Int { queue.count }
    func add(_ type: DataType) { queue.insert(type) }
    func clear() { queue.removeAll() }
}

enum DataType {
    case trip, flightTimes, dutyTimer, crew, settings, fboAlert
}

// MARK: - Notification Names
// Notification names are defined in NotificationNames.swift
// No need to redeclare them here

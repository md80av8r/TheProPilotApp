// WatchConnectivityManager.swift
// October's simple approach + November leg sync improvements
import Foundation
import WatchConnectivity
import WatchKit

// MARK: - Connection State
enum ConnectionState {
    case connected
    case connecting
    case disconnected
}

// MARK: - Sync State
enum SyncStatus {
    case disconnected
    case connected
    case syncing
    case synced
    case pending
    case error
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    
    // Flight Data
    @Published var currentFlight: FlightData?
    @Published var currentLegIndex: Int = 0 {
        didSet {
            print("⌚ 🔴 currentLegIndex changed: \(oldValue) → \(currentLegIndex)")
            #if DEBUG
            print("⌚    Called from: \(Thread.callStackSymbols.prefix(3).joined(separator: "\n"))")
            #endif
        }
    }
    @Published var totalLegs: Int = 1
    @Published var hasMoreLegs: Bool = false
    
    // ✅ NEW: Completed Legs Storage (for swipe-back viewing on watch)
    @Published var completedLegs: [CompletedLegData] = []
    
    // Connection State
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isConnected = false
    @Published var isPhoneReachable = false  // ✅ ADDED for PilotWatchApp
    @Published var lastMessageReceived: String = ""
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .disconnected  // ✅ ADDED for WatchSyncStatusView

    // FBO Alert State
    @Published var pendingFBOAlert: FBOAlertData?
    
    // Duty Timer
    @Published var isDutyTimerRunning = false  // ✅ ADDED for PilotWatchApp & DutyTimerWatchView
    // Alias for views expecting dutyIsRunning naming
    var dutyIsRunning: Bool {
        get { isDutyTimerRunning }
        set { isDutyTimerRunning = newValue }
    }
    @Published var dutyStartTime: Date?
    @Published var elapsedDutyTime: String = "00:00:00"
    
    // Location Data
    @Published var currentAirport: String = ""
    @Published var currentSpeed: Double = 0.0
    @Published var currentAltitude: Double = 0.0
    
    // Trip Data
    @Published var currentTripId: UUID?
    
    // Convenience alias for views
    var isReachable: Bool? { session?.isReachable }
    
    // MARK: - Private Properties
    private var session: WCSession?
    private var pendingMessages: [(message: [String: Any], description: String)] = []
    private var dutyTimer: Timer?
    
    // ✅ Track if we've cleaned duplicates (one-time cleanup)
    private var hasCleanedDuplicates = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
            print("🔷 WatchConnectivityManager initialized")
        }
    }
    
    // MARK: - Public Methods
    
    /// Send time entry to phone - ALWAYS includes leg index
    func sendTimeEntry(timeType: String, time: Date) {
        guard let tripId = currentFlight?.flightNumber else {
            print("⚠️ No active trip to send time for")
            return
        }

        let message: [String: Any] = [
            "type": "setTime",
            "timeType": timeType,
            "timestamp": time.timeIntervalSince1970,
            "tripId": tripId,
            "legIndex": currentLegIndex,  // ← CRITICAL: Always include current leg
            "messageTimestamp": Date().timeIntervalSince1970
        ]

        sendMessageToPhoneInternal(message, description: "set \(timeType) time on leg \(currentLegIndex)")
    }

    /// Clear a time entry on phone - sets time to nil
    func clearTimeEntry(timeType: String) {
        guard let tripId = currentFlight?.flightNumber else {
            print("⚠️ No active trip to clear time for")
            return
        }

        let message: [String: Any] = [
            "type": "clearTime",
            "timeType": timeType,
            "tripId": tripId,
            "legIndex": currentLegIndex,
            "messageTimestamp": Date().timeIntervalSince1970
        ]

        sendMessageToPhoneInternal(message, description: "clear \(timeType) time on leg \(currentLegIndex)")
    }
    
    /// Request next leg from phone
    func requestNextLeg() {
        let message: [String: Any] = [
            "type": "requestNextLeg",
            "currentLegIndex": currentLegIndex,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "request next leg")
    }
    
    /// Save current leg to completed legs array before advancing
    func saveCurrentLegAsCompleted(legId: UUID) {
        guard let flight = currentFlight else {
            print("⌚ No current flight to save")
            return
        }
        
        // ✅ FIX: Check for duplicates using BOTH UUID and flight data
        // (handles legacy data that may have random UUIDs)
        let isDuplicateById = completedLegs.contains(where: { $0.id == legId })
        let isDuplicateByData = completedLegs.contains(where: {
            $0.departure == flight.departureAirport &&
            $0.arrival == flight.arrivalAirport &&
            $0.outTime == flight.outTime &&
            $0.inTime == flight.inTime
        })
        
        if isDuplicateById {
            print("⌚ Leg \(legId) already saved (by UUID) - skipping duplicate")
            return
        }
        
        if isDuplicateByData {
            print("⌚ Leg already saved (by flight data) - skipping duplicate")
            // ✅ BONUS: Remove the old entry with wrong UUID and add the new one with correct UUID
            if let oldIndex = completedLegs.firstIndex(where: {
                $0.departure == flight.departureAirport &&
                $0.arrival == flight.arrivalAirport &&
                $0.outTime == flight.outTime &&
                $0.inTime == flight.inTime
            }) {
                print("⌚ Replacing old entry with correct UUID")
                completedLegs.remove(at: oldIndex)
            }
        }
        
        let completedLeg = CompletedLegData(
            id: legId,  // ✅ Use phone's UUID
            flightNumber: flight.flightNumber,
            departure: flight.departureAirport,
            arrival: flight.arrivalAirport,
            outTime: flight.outTime,
            offTime: flight.offTime,
            onTime: flight.onTime,
            inTime: flight.inTime
        )
        
        completedLegs.append(completedLeg)
        print("⌚ ✅ Saved leg \(completedLegs.count) to completed: \(flight.departureAirport) → \(flight.arrivalAirport) [ID: \(legId)]")
    }
    
    /// Clear completed legs (called when trip ends)
    func clearCompletedLegs() {
        completedLegs.removeAll()
        print("⌚ Cleared completed legs")
    }
    
    /// ✅ Remove duplicate legs from history (one-time cleanup for legacy data)
    func removeDuplicateLegs() {
        var seen: Set<String> = []
        var cleaned: [CompletedLegData] = []
        
        for leg in completedLegs {
            // Create a unique key based on flight data
            let key = "\(leg.departure)-\(leg.arrival)-\(leg.outTime?.timeIntervalSince1970 ?? 0)-\(leg.inTime?.timeIntervalSince1970 ?? 0)"
            
            if !seen.contains(key) {
                seen.insert(key)
                cleaned.append(leg)
            } else {
                print("⌚ Removing duplicate: \(leg.departure) → \(leg.arrival)")
            }
        }
        
        let removedCount = completedLegs.count - cleaned.count
        completedLegs = cleaned
        
        if removedCount > 0 {
            print("⌚ ✅ Removed \(removedCount) duplicate leg(s) from history")
        }
    }
    
    /// Request current flight data from phone
    func requestFlightUpdate() {
        let message: [String: Any] = [
            "type": "requestFlightData",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "request flight update")
    }
    
    /// Request current duty status from phone (reply preferred)
    func requestDutyStatus() {
        let message: [String: Any] = [
            "type": "requestDutyStatus",
            "timestamp": Date().timeIntervalSince1970
        ]
        if let session = session, session.isReachable {
            sendMessageToPhoneWithReply(
                message,
                description: "request duty status",
                replyHandler: { reply in
                    // Route through standard handler if typed, else map minimal keys
                    if let type = reply["type"] as? String, type == "dutyStatus" {
                        self.handleDutyTimerMessage(reply)
                    } else {
                        // Minimal mapping support
                        var mapped: [String: Any] = ["type": "dutyStatus"]
                        if let running = reply["isRunning"] as? Bool { mapped["isDutyRunning"] = running }
                        if let startTS = reply["startTimestamp"] as? Double { mapped["dutyStartTime"] = startTS }
                        if let airport = reply["airport"] as? String { mapped["airport"] = airport }
                        if let speed = reply["speed"] as? Double { mapped["speed"] = speed }
                        if let altitude = reply["altitude"] as? Double { mapped["altitude"] = altitude }
                        self.handleDutyTimerMessage(mapped)
                    }
                },
                errorHandler: { error in
                    print("❌ Duty status reply failed: \(error.localizedDescription)")
                    // Fallback: fire-and-forget
                    self.sendMessageToPhone(message, description: "request duty status (fallback)")
                }
            )
        } else {
            // Fire-and-forget when not reachable
            sendMessageToPhone(message, description: "request duty status")
        }
    }
    
    // MARK: - ✅ Duty Timer Methods
    
    /// Send start duty message to phone
    func sendStartDuty() {
        let message: [String: Any] = [
            "type": "startDuty",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "start duty")
        print("⌚ Sent start duty to phone")
    }
    
    /// Send end duty message to phone
    func sendEndDuty() {
        let message: [String: Any] = [
            "type": "endDuty",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "end duty")
        
        // Stop local timer
        stopDutyTimer()
        print("⌚ Sent end duty to phone")
    }
    
    /// Update elapsed duty time (called by timer)
    func updateDutyTimeIfNeeded() {
        guard isDutyTimerRunning, let startTime = dutyStartTime else {
            elapsedDutyTime = "00:00:00"
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        let seconds = Int(elapsed) % 60
        elapsedDutyTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// Start local duty timer for UI updates
    private func startDutyTimer() {
        dutyTimer?.invalidate()
        dutyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDutyTimeIfNeeded()
        }
    }
    
    /// Stop local duty timer
    private func stopDutyTimer() {
        dutyTimer?.invalidate()
        dutyTimer = nil
        isDutyTimerRunning = false
        dutyStartTime = nil
        elapsedDutyTime = "00:00:00"
    }
    
    // MARK: - ✅ Additional Public Methods
    
    /// Send add new leg request
    func sendAddNewLeg() {
        let message: [String: Any] = [
            "type": "addNewLeg",
            "currentLegIndex": currentLegIndex,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "add new leg")
        print("⌚ Requested new leg from phone")
    }
    
    /// Send call OPS request to phone
    func sendCallOPS() {
        let message: [String: Any] = [
            "type": "callOPS",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "call OPS")
        print("⌚ Requested OPS call from phone")
    }
    
    /// Send ping to phone to test connectivity
    func sendPingToPhone() {
        let message: [String: Any] = [
            "type": "ping",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessageToPhoneInternal(message, description: "ping")
        print("⌚ Sent ping to phone")
    }
    
    /// Ensure connectivity by reactivating session if needed
    func ensureConnectivity() {
        guard let session = session else { return }
        
        if session.activationState != .activated {
            print("⌚ Reactivating WCSession...")
            session.activate()
        } else {
            print("⌚ WCSession already active")
            // Just send a ping to test
            sendPingToPhone()
        }
    }
    
    /// Reset current flight data
    func resetCurrentFlight() {
        currentFlight = nil
        currentLegIndex = 0
        totalLegs = 1
        hasMoreLegs = false
        print("⌚ Reset current flight data")
    }
    
    /// Get current flight phase
    func getCurrentFlightPhase() -> String {
        guard let flight = currentFlight else { return "No Flight" }
        
        if flight.inTime != nil {
            return "Complete"
        } else if flight.onTime != nil {
            return "Taxi In"
        } else if flight.offTime != nil {
            return "Enroute"
        } else if flight.outTime != nil {
            return "Taxi Out"
        } else {
            return "Pre-Flight"
        }
    }
    
    /// Get next time to set
    func getNextTimeToSet() -> String? {
        guard let flight = currentFlight else { return "OUT" }
        
        if flight.outTime == nil {
            return "OUT"
        } else if flight.offTime == nil {
            return "OFF"
        } else if flight.onTime == nil {
            return "ON"
        } else if flight.inTime == nil {
            return "IN"
        } else {
            return nil
        }
    }
    
    /// Check if there's an active flight
    func hasActiveFlight() -> Bool {
        return currentFlight != nil
    }
    
    /// Check if current leg is complete
    func isLegComplete() -> Bool {
        guard let flight = currentFlight else { return false }
        return flight.outTime != nil &&
        flight.offTime != nil &&
        flight.onTime != nil &&
        flight.inTime != nil
    }
    
    /// Get pending sync count
    var pendingSyncCount: Int {
        return pendingMessages.count
    }
    
    /// Get sync status text
    func getSyncStatusText() -> String {
        switch syncStatus {
        case .disconnected:
            return "Disconnected"
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .pending:
            return "Pending"
        case .error:
            return "Error"
        }
    }
    
    /// Generic method to send any message to phone - public for use by other views
    public func sendMessageToPhone(_ message: [String: Any], description: String) {
        sendMessageToPhoneInternal(message, description: description)
    }
    
    /// Send a message with reply and error handlers (hybrid support)
    public func sendMessageToPhoneWithReply(_ message: [String: Any],
                                            description: String,
                                            replyHandler: @escaping ([String: Any]) -> Void,
                                            errorHandler: @escaping (Error) -> Void) {
        guard let session = session, session.isReachable else {
            print("⚠️ Phone not reachable for reply send: \(description)")
            errorHandler(NSError(domain: "WCSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phone not reachable"]))
            return
        }
        connectionState = .connecting
        syncStatus = .syncing
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                print("✅ Reply received for: \(description)")
                self.connectionState = .connected
                self.syncStatus = .synced
                self.lastSyncTime = Date()
                replyHandler(reply)
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                print("❌ Reply send failed for: \(description) - \(error.localizedDescription)")
                self.connectionState = .disconnected
                self.syncStatus = .error
                errorHandler(error)
            }
        })
    }
    
    // MARK: - Private Methods
    
    /// Internal message sending with automatic retry
    private func sendMessageToPhoneInternal(_ message: [String: Any], description: String) {
        guard let session = session, session.isReachable else {
            print("⚠️ Phone not reachable, queuing message: \(description)")
            pendingMessages.append((message, description))
            connectionState = .disconnected
            syncStatus = .disconnected
            return
        }
        
        connectionState = .connecting
        syncStatus = .syncing
        
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                print("✅ Message sent successfully: \(description)")
                self.connectionState = .connected
                self.syncStatus = .synced
                self.lastSyncTime = Date()
                
                // Handle reply if present
                if !reply.isEmpty {
                    self.handleReplyMessage(reply)
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                print("❌ Failed to send message: \(description) - \(error.localizedDescription)")
                self.connectionState = .disconnected
                self.syncStatus = .error
                
                // Re-queue failed message
                self.pendingMessages.append((message, description))
            }
        })
    }
    
    /// Send any pending messages when connection is restored
    private func sendPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        print("📤 Sending \(pendingMessages.count) pending messages")
        let messages = pendingMessages
        pendingMessages.removeAll()
        
        for (message, description) in messages {
            sendMessageToPhoneInternal(message, description: description)
        }
    }
    
    /// Handle reply from phone
    private func handleReplyMessage(_ reply: [String: Any]) {
        guard let type = reply["type"] as? String else {
            print("⚠️ Reply missing type field")
            return
        }
        
        print("📥 Processing reply of type: \(type)")
        
        switch type {
        case "flightUpdate":
            handleFlightUpdateMessage(reply)
        case "dutyStatus":
            handleDutyTimerMessage(reply)
        default:
            print("⚠️ Unknown reply type: \(type)")
        }
    }
    
    /// Handle flight update from phone - phone tells us what leg we're on
    private func handleFlightUpdateMessage(_ message: [String: Any]) {
        print("📥 Processing flight update")
        
        // ✅ ONE-TIME CLEANUP: Remove any legacy duplicates on first update
        if !hasCleanedDuplicates {
            removeDuplicateLegs()
            hasCleanedDuplicates = true
        }
        
        // ✅ Extract leg UUID from message
        var incomingLegId: UUID?
        if let legIdString = message["legId"] as? String,
           let legId = UUID(uuidString: legIdString) {
            incomingLegId = legId
            print("⌚ Received leg ID: \(legId)")
        }
        
        // ---------------------------------------------------------
        // ✅ Capture Zulu Time Setting from iPhone
        // ---------------------------------------------------------
        if let useZulu = message["useZuluTime"] as? Bool {
            if let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
                let oldValue = sharedDefaults.bool(forKey: "useZuluTime")
                if oldValue != useZulu {
                    sharedDefaults.set(useZulu, forKey: "useZuluTime")
                    print("⌚ Updated Zulu Time setting to: \(useZulu)")
                }
            }
        }
        // ---------------------------------------------------------
        
        // Phone tells us what leg we're on - TRUST IT
        if let legIndex = message["legIndex"] as? Int {
            // ✅ VALIDATION: Ensure leg index is within bounds
            let totalLegCount = message["totalLegs"] as? Int ?? 1
            
            if legIndex >= totalLegCount {
                print("⌚ ⚠️ WARNING: Leg index \(legIndex) is out of bounds (total legs: \(totalLegCount))")
                print("⌚ Phone sent invalid leg index - clamping to last leg")
                self.currentLegIndex = max(0, totalLegCount - 1)
            } else {
                // ✅ FIX: If advancing to a new leg, save the old leg to history first
                if legIndex > self.currentLegIndex {
                    print("⌚ 📦 LEG ADVANCED: \(self.currentLegIndex) → \(legIndex) - saving old leg to history")
                    if let oldFlight = self.currentFlight,
                       oldFlight.outTime != nil && oldFlight.offTime != nil &&
                       oldFlight.onTime != nil && oldFlight.inTime != nil {
                        // ✅ Need the OLD leg's UUID - we don't have it, so we can't save properly
                        // This is a limitation - we'll need to track the current leg's UUID
                        print("⌚ ⚠️ Cannot save old leg without its UUID - skipping")
                    } else {
                        print("⌚ ⚠️ Old leg incomplete, not saving to history")
                    }
                }
                
                self.currentLegIndex = legIndex
                print("✅ Updated to leg \(legIndex + 1)")  // Human-readable (1-based)
            }
        }
        
        if let totalLegs = message["totalLegs"] as? Int {
            self.totalLegs = totalLegs
            self.hasMoreLegs = currentLegIndex < (totalLegs - 1)
            print("✅ Total legs: \(totalLegs), hasMore: \(hasMoreLegs)")
        }
        
        // Update flight data - handle missing fields gracefully
        print("🔍 Looking for flightNumber, departure, arrival...")
        print("🔍 flightNumber: \(message["flightNumber"] as? String ?? "empty")")
        print("🔍 departure: \(message["departure"] as? String ?? "NIL")")
        print("🔍 arrival: \(message["arrival"] as? String ?? "NIL")")
        
        // Don't require all fields - use defaults for missing data
        let flightNumber = message["flightNumber"] as? String ?? ""
        let departure = message["departure"] as? String ?? "---"
        let arrival = message["arrival"] as? String ?? "TBD"
        
        print("✅ Creating flight data: '\(flightNumber)' from \(departure) to \(arrival)")
        
        // Create flight data with whatever we have
        var flight = FlightData(
            flightNumber: flightNumber,
            departureAirport: departure,
            arrivalAirport: arrival
        )
        
        // Update times if present
        if let outTimestamp = message["outTime"] as? Double {
            flight.outTime = Date(timeIntervalSince1970: outTimestamp)
            print("  OUT: \(flight.outTime!)")
        }
        if let offTimestamp = message["offTime"] as? Double {
            flight.offTime = Date(timeIntervalSince1970: offTimestamp)
            print("  OFF: \(flight.offTime!)")
        }
        if let onTimestamp = message["onTime"] as? Double {
            flight.onTime = Date(timeIntervalSince1970: onTimestamp)
            print("  ON: \(flight.onTime!)")
        }
        if let inTimestamp = message["inTime"] as? Double {
            flight.inTime = Date(timeIntervalSince1970: inTimestamp)
            print("  IN: \(flight.inTime!)")
        }
        
        // Always update the current flight, even with partial data
        self.currentFlight = flight
        
        // ✅ If this leg is complete AND we have its UUID, save it to history
        if let legId = incomingLegId,
           flight.outTime != nil && flight.offTime != nil &&
           flight.onTime != nil && flight.inTime != nil {
            saveCurrentLegAsCompleted(legId: legId)
        }
        
        print("✅ Updated flight data for leg \(currentLegIndex + 1) of \(totalLegs)")
        print("   Route: \(departure) → \(arrival)")
        
        lastMessageReceived = "Flight update at \(Date().formatted(date: .omitted, time: .shortened))"
        lastSyncTime = Date()
        
        // Update sync status
        syncStatus = .synced
    }
    
    // MARK: - Handle Location Update Message
    private func handleLocationUpdateMessage(_ message: [String: Any]) {
        print("📥 Processing location update")
        
        // Update current speed if present
        if let speed = message["speed"] as? Double {
            currentSpeed = speed
            print("✅ Speed updated: \(speed) kts")
        }
        
        // Update current airport if present
        if let airport = message["airport"] as? String {
            currentAirport = airport
            print("✅ Airport updated: \(airport)")
        }
        
        // Update location coordinates if present
        if let latitude = message["latitude"] as? Double,
           let longitude = message["longitude"] as? Double {
            print("✅ Location updated: \(latitude), \(longitude)")
            // Store if needed for display
        }
        
        // Update altitude if present
        if let altitude = message["altitude"] as? Double {
            currentAltitude = altitude
            print("✅ Altitude updated: \(altitude) ft")
        }
        
        lastSyncTime = Date()
        
        // Optionally update sync status
        syncStatus = .synced
    }
    
    // MARK: - Handle Duty Timer Message
    private func handleDutyTimerMessage(_ message: [String: Any]) {
        print("📥 Processing duty timer update")
        
        if let isRunning = message["isDutyRunning"] as? Bool {
            isDutyTimerRunning = isRunning
            print("✅ Duty timer running: \(isRunning)")
        }
        
        if let startTimestamp = message["dutyStartTime"] as? Double {
            dutyStartTime = Date(timeIntervalSince1970: startTimestamp)
            print("✅ Duty start time: \(dutyStartTime!)")
        } else if !isDutyTimerRunning {
            dutyStartTime = nil
            print("✅ Duty timer stopped")
        }
        
        if let tripIdString = message["tripId"] as? String,
           let tripId = UUID(uuidString: tripIdString) {
            currentTripId = tripId
            print("✅ Trip ID updated: \(tripId)")
        }
        
        // If the duty timer is not running, ensure local timers and extended session are stopped
        if !isDutyTimerRunning {
            stopDutyTimer()
            ExtensionDelegate.shared.performStopExtendedSession()
        } else {
            // If running, ensure our local duty timer is active for UI updates
            startDutyTimer()
        }
        
        lastSyncTime = Date()
    }
    
    /// Handle clear trip message from phone
    private func handleClearTrip() {
        print("🗑️ Clearing trip data from watch")

        // ✅ Clear in the right order to prevent UI crashes
        DispatchQueue.main.async {
            // First clear the flight data (this will trigger onChange to reset page)
            self.currentFlight = nil
            self.currentLegIndex = 0
            self.totalLegs = 0
            self.hasMoreLegs = false
            self.currentTripId = nil

            // Then clear completed legs after a tiny delay to let UI update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.completedLegs.removeAll()
                print("⌚ ✅ Cleared all completed legs")
            }
        }

        // Stop any duty-related timers/state
        stopDutyTimer()
        isDutyTimerRunning = false
        dutyStartTime = nil

        // Stop extended runtime session to avoid re-activation
        ExtensionDelegate.shared.performStopExtendedSession()

        // Reset sync status
        syncStatus = .synced

        print("✅ Trip data cleared from watch and extended session stopped")
    }

    /// Handle FBO contact alert from phone - triggers haptic and displays alert
    private func handleFBOAlert(_ message: [String: Any]) {
        print("📻 Received FBO contact alert from phone")

        guard let airportCode = message["airportCode"] as? String,
              let fboName = message["fboName"] as? String,
              let distanceNM = message["distanceNM"] as? Double else {
            print("⚠️ Invalid FBO alert message format")
            return
        }

        let unicomFrequency = message["unicomFrequency"] as? String

        // Create FBO alert data
        let alertData = FBOAlertData(
            airportCode: airportCode,
            fboName: fboName,
            distanceNM: distanceNM,
            unicomFrequency: unicomFrequency,
            timestamp: Date()
        )

        // Play haptic notification - strong vibration to get pilot's attention
        WKInterfaceDevice.current().play(.notification)

        // Play additional haptic after brief delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WKInterfaceDevice.current().play(.directionUp)
        }

        // Update published property to trigger UI update
        DispatchQueue.main.async {
            self.pendingFBOAlert = alertData
            self.lastMessageReceived = "FBO Alert: \(airportCode)"
            self.lastSyncTime = Date()
        }

        // Log the alert details
        if let unicom = unicomFrequency {
            print("📻 Contact \(fboName) at \(airportCode) - \(String(format: "%.0f", distanceNM))nm - UNICOM: \(unicom)")
        } else {
            print("📻 Contact \(fboName) at \(airportCode) - \(String(format: "%.0f", distanceNM))nm")
        }
    }

    /// Dismiss the current FBO alert
    func dismissFBOAlert() {
        pendingFBOAlert = nil
        print("⌚ FBO alert dismissed")
    }
    
    // ALSO: Update the message handler in the delegate
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("📥 Received message from phone")
            
            guard let type = message["type"] as? String else {
                print("⚠️ Message missing type field")
                return
            }
            
            print("📥 Message type: \(type)")
            
            switch type {
            case "flightUpdate":
                self.handleFlightUpdateMessage(message)

            case "tripStarted":
                print("✅ Trip started on phone")
                self.handleFlightUpdateMessage(message)

            case "dutyStatus":
                self.handleDutyTimerMessage(message)

            case "locationUpdate":
                self.handleLocationUpdateMessage(message)

            case "ping":
                print("✅ Ping received from phone")
                self.connectionState = .connected
                self.syncStatus = .synced

            case "clearTrip", "tripDeleted", "tripEnded":
                print("📥 Received terminal trip event (clear/delete/end)")
                self.handleClearTrip()

            case "fboAlert":
                print("📻 Received FBO alert from phone")
                self.handleFBOAlert(message)

            default:
                print("⚠️ Unknown message type: \(type)")
            }
        }
    }
    
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ Watch session activation failed: \(error.localizedDescription)")
                self.connectionState = .disconnected
                self.syncStatus = .error
                return
            }
            
            switch activationState {
            case .activated:
                print("✅ Watch session activated")
                self.isConnected = session.isReachable
                self.isPhoneReachable = session.isReachable
                self.connectionState = session.isReachable ? .connected : .disconnected
                self.syncStatus = session.isReachable ? .connected : .disconnected

                // ✅ CRITICAL: Check ApplicationContext for any pending updates (like clearTrip)
                let context = session.applicationContext
                if !context.isEmpty {
                    print("📥 Processing pending ApplicationContext on activation")
                    self.session(session, didReceiveApplicationContext: context)
                }

                // Request initial flight data
                self.requestFlightUpdate()

                // Send any pending messages
                self.sendPendingMessages()
                
            case .inactive:
                print("⚠️ Watch session inactive")
                self.connectionState = .disconnected
                self.syncStatus = .disconnected
                
            case .notActivated:
                print("⚠️ Watch session not activated")
                self.connectionState = .disconnected
                self.syncStatus = .disconnected
                
            @unknown default:
                print("⚠️ Unknown activation state")
                self.connectionState = .disconnected
                self.syncStatus = .disconnected
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            self.isPhoneReachable = session.isReachable
            self.connectionState = session.isReachable ? .connected : .disconnected
            self.syncStatus = session.isReachable ? .connected : .disconnected

            print("📡 Watch reachability changed: \(session.isReachable ? "✅ Connected" : "❌ Disconnected")")

            // ✅ When watch becomes reachable, check for pending ApplicationContext updates
            if session.isReachable {
                let context = session.applicationContext
                if !context.isEmpty {
                    print("📥 Processing pending ApplicationContext on reachability change")
                    self.session(session, didReceiveApplicationContext: context)
                }
            }
            
            if session.isReachable {
                // Connection restored - send pending messages
                if !self.pendingMessages.isEmpty {
                    self.syncStatus = .pending
                }
                self.sendPendingMessages()
                
                // Request fresh data
                self.requestFlightUpdate()
            }
        }
    }
    
    
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("📥 Received application context from phone")

            // Application context might have flight data
            if let type = applicationContext["type"] as? String {
                print("📥 Context type: \(type)")

                switch type {
                case "flightUpdate":
                    self.handleFlightUpdateMessage(applicationContext)
                case "dutyStatus", "dutyTimer":  // ✅ Handle both type names
                    self.handleDutyTimerMessage(applicationContext)
                case "clearTrip", "tripDeleted", "tripEnded":
                    self.handleClearTrip()
                case "fboAlert":
                    self.handleFBOAlert(applicationContext)
                default:
                    print("⚠️ Unknown context type: \(type)")
                }

                // Fallback: if context explicitly indicates no active trip, clear state
                if applicationContext["activeTrip"] is NSNull || (applicationContext["activeTripID"] as? String)?.isEmpty == true {
                    print("📥 Context indicates no active trip — clearing locally")
                    self.handleClearTrip()
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            print("📥 Received userInfo from phone")
            if let type = userInfo["type"] as? String {
                switch type {
                case "tripDeleted", "clearTrip", "tripEnded":
                    print("📥 userInfo indicates terminal trip event — clearing locally")
                    self.handleClearTrip()
                case "flightUpdate":
                    self.handleFlightUpdateMessage(userInfo)
                case "dutyStatus":
                    self.handleDutyTimerMessage(userInfo)
                default:
                    print("⚠️ Unknown userInfo type: \(type)")
                }
            } else {
                // Fallback: same no-active-trip inference as application context
                if userInfo["activeTrip"] is NSNull || (userInfo["activeTripID"] as? String)?.isEmpty == true {
                    print("📥 userInfo indicates no active trip — clearing locally")
                    self.handleClearTrip()
                }
            }
        }
    }
}

// MARK: - Shared Data Models
/// Completed leg data for watch history view
struct CompletedLegData: Identifiable, Codable {
    let id: UUID  // ✅ Use UUID from phone (not generated)
    let flightNumber: String
    let departure: String
    let arrival: String
    let outTime: Date?
    let offTime: Date?
    let onTime: Date?
    let inTime: Date?
}

/// FBO Alert data for watch display
struct FBOAlertData: Identifiable {
    let id = UUID()
    let airportCode: String
    let fboName: String
    let distanceNM: Double
    let unicomFrequency: String?
    let timestamp: Date
}


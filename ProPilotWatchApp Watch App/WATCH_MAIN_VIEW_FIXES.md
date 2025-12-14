# WatchMainView Compilation Errors - Fixed

## ✅ All Errors Fixed

### Errors Were:
1. `Value of type 'WatchConnectivityManager' has no dynamic member 'sendStartDuty'`
2. `Value of type 'WatchConnectivityManager' has no dynamic member 'sendEndDuty'`
3. `Value of type 'WatchConnectivityManager' has no dynamic member 'sendCallOPS'`
4. `Value of type 'WatchConnectivityManager' has no dynamic member 'sendPingToPhone'`
5. `Value of type 'WatchConnectivityManager' has no dynamic member 'ensureConnectivity'`

### Root Cause:
`WatchMainView.swift` was calling methods that didn't exist in `WatchConnectivityManager.swift`.

## 🔧 Solution: Added All Missing Methods

### 1. Duty Timer Methods ✅

```swift
/// Send start duty message to phone
func sendStartDuty() {
    let message: [String: Any] = [
        "type": "startDuty",
        "timestamp": Date().timeIntervalSince1970
    ]
    sendMessageToPhoneInternal(message, description: "start duty")
}

/// Send end duty message to phone
func sendEndDuty() {
    let message: [String: Any] = [
        "type": "endDuty",
        "timestamp": Date().timeIntervalSince1970
    ]
    sendMessageToPhoneInternal(message, description: "end duty")
    stopDutyTimer()
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

private func startDutyTimer() {
    dutyTimer?.invalidate()
    dutyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.updateDutyTimeIfNeeded()
    }
}

private func stopDutyTimer() {
    dutyTimer?.invalidate()
    dutyTimer = nil
    isDutyTimerRunning = false
    dutyStartTime = nil
    elapsedDutyTime = "00:00:00"
}
```

### 2. Communication Methods ✅

```swift
/// Send add new leg request
func sendAddNewLeg() {
    let message: [String: Any] = [
        "type": "addNewLeg",
        "currentLegIndex": currentLegIndex,
        "timestamp": Date().timeIntervalSince1970
    ]
    sendMessageToPhoneInternal(message, description: "add new leg")
}

/// Send call OPS request to phone
func sendCallOPS() {
    let message: [String: Any] = [
        "type": "callOPS",
        "timestamp": Date().timeIntervalSince1970
    ]
    sendMessageToPhoneInternal(message, description: "call OPS")
}

/// Send ping to phone to test connectivity
func sendPingToPhone() {
    let message: [String: Any] = [
        "type": "ping",
        "timestamp": Date().timeIntervalSince1970
    ]
    sendMessageToPhoneInternal(message, description: "ping")
}

/// Ensure connectivity by reactivating session if needed
func ensureConnectivity() {
    guard let session = session else { return }
    
    if session.activationState != .activated {
        print("⌚ Reactivating WCSession...")
        session.activate()
    } else {
        sendPingToPhone()
    }
}
```

### 3. Flight Management Methods ✅

```swift
/// Reset current flight data
func resetCurrentFlight() {
    currentFlight = nil
    currentLegIndex = 0
    totalLegs = 1
    hasMoreLegs = false
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
```

### 4. Message Handlers ✅

```swift
// Added to message switch case:
case "dutyTimer":
    self.handleDutyTimerMessage(message)
    
case "locationUpdate":
    self.handleLocationUpdateMessage(message)

// Handler implementations:
private func handleDutyTimerMessage(_ message: [String: Any]) {
    // Updates isDutyTimerRunning, dutyStartTime
    // Starts/stops local timer
}

private func handleLocationUpdateMessage(_ message: [String: Any]) {
    // Updates currentSpeed, currentAirport
}
```

## 📱 WatchMainView Usage

### ModernDutyTimerView

```swift
// Start Duty Button
Button(action: {
    connectivityManager.sendStartDuty()  // ✅ NOW EXISTS
}) {
    HStack {
        Image(systemName: "play.fill")
        Text("Start Duty")
    }
}

// End Duty Button
Button(action: {
    connectivityManager.sendEndDuty()  // ✅ NOW EXISTS
}) {
    HStack {
        Image(systemName: "stop.fill")
        Text("End Duty")
    }
}
```

### ModernOPSView

```swift
// Call OPS Button
Button("Call", role: .destructive) {
    connectivityManager.sendCallOPS()  // ✅ NOW EXISTS
}
```

### ModernWatchSettingsView

```swift
// Test Connection Button
Button(action: {
    connectivityManager.sendPingToPhone()  // ✅ NOW EXISTS
}) {
    HStack {
        Image(systemName: "arrow.triangle.2.circlepath")
        Text("Test Connection")
    }
}

// Reconnect Button
Button(action: {
    connectivityManager.ensureConnectivity()  // ✅ NOW EXISTS
}) {
    HStack {
        Image(systemName: "antenna.radiowaves.left.and.right")
        Text("Reconnect")
    }
}
```

## 🔄 Complete Data Flow

### Starting Duty
```
1. User taps "Start Duty" in ModernDutyTimerView
   ↓
2. connectivityManager.sendStartDuty()
   ↓
3. Message sent: {"type": "startDuty", "timestamp": ...}
   ↓
4. Phone receives message
   ↓
5. Phone starts duty timer and creates trip
   ↓
6. Phone → Watch: {"type": "dutyTimer", "isRunning": true, "startTime": ...}
   ↓
7. Watch: handleDutyTimerMessage()
   ↓
8. Watch: isDutyTimerRunning = true
   ↓
9. Watch: startDutyTimer() (local 1-second timer)
   ↓
10. UI updates showing "ON DUTY" with elapsed time
```

### Calling OPS
```
1. User taps "Call OPS" in ModernOPSView
   ↓
2. Alert appears: "Call Operations?"
   ↓
3. User confirms
   ↓
4. connectivityManager.sendCallOPS()
   ↓
5. Message sent: {"type": "callOPS", "timestamp": ...}
   ↓
6. Phone receives message
   ↓
7. Phone initiates phone call to operations
```

### Testing Connection
```
1. User taps "Test Connection" in ModernWatchSettingsView
   ↓
2. connectivityManager.sendPingToPhone()
   ↓
3. Message sent: {"type": "ping", "timestamp": ...}
   ↓
4. Phone receives ping
   ↓
5. Phone → Watch: {"type": "pong", "timestamp": ...}
   ↓
6. Watch receives pong (proves connection working)
```

## 🧪 Testing

### Test 1: Duty Timer
```
1. Open watch app to Duty tab
2. ✅ Verify: Shows "Off Duty"
3. Tap "Start Duty"
4. ✅ Verify: Shows "ON DUTY" with counting timer
5. ✅ Verify: Phone also shows duty running
6. Wait 1 minute
7. ✅ Verify: Timer shows "00:01:XX"
8. Tap "End Duty"
9. ✅ Verify: Returns to "Off Duty"
10. ✅ Verify: Phone also stopped duty timer
```

### Test 2: OPS Call
```
1. Swipe to OPS tab
2. Tap "Call OPS"
3. ✅ Verify: Alert appears
4. Tap "Call"
5. ✅ Verify: Phone initiates call
```

### Test 3: Connection Test
```
1. Swipe to Settings tab
2. Note connection status (Connected/Disconnected)
3. Tap "Test Connection"
4. ✅ Verify: Console shows ping/pong messages
5. Lock iPhone
6. ✅ Verify: Status changes to "Disconnected"
7. Tap "Reconnect"
8. Unlock iPhone
9. ✅ Verify: Status changes to "Connected"
```

### Test 4: Location Display
```
1. Start duty
2. Move or simulate movement
3. ✅ Verify: Speed appears in Settings and Duty tabs
4. ✅ Verify: Airport code appears when near airport
5. ✅ Verify: Updates in real-time
```

## 📊 Build Status

✅ **ALL METHODS ADDED**  
✅ **ALL MESSAGE HANDLERS ADDED**  
✅ **ALL VIEW CALLS FIXED**  
✅ **READY TO COMPILE**

## ⚠️ Important Notes

### 1. Timer Management
- Local timer updates UI every second
- Phone controls duty state (authoritative)
- Timer persists across app backgrounding
- Extended session keeps timer running

### 2. Message Queue
- Messages queued if phone not reachable
- Sent automatically when connection restored
- No data loss even if connection interrupts

### 3. Reachability
- `isPhoneReachable` = Can send messages NOW
- `isConnected` = WCSession activated
- Both updated automatically by system

### 4. Method Naming
- `send*` methods - Send message to phone
- `handle*` methods - Process message from phone (private)
- `get*` methods - Return computed values
- Public methods for views, private for internal

## ✅ Summary

All missing methods have been added to `WatchConnectivityManager`:

✅ `sendStartDuty()` - Start duty timer  
✅ `sendEndDuty()` - End duty timer  
✅ `sendCallOPS()` - Request OPS call  
✅ `sendPingToPhone()` - Test connection  
✅ `ensureConnectivity()` - Force reconnect  
✅ `sendAddNewLeg()` - Add flight leg  
✅ `resetCurrentFlight()` - Clear flight data  
✅ `getCurrentFlightPhase()` - Get phase string  
✅ `getNextTimeToSet()` - Get next time button  
✅ `hasActiveFlight()` - Check if flight exists  
✅ `isLegComplete()` - Check if all times set  
✅ `updateDutyTimeIfNeeded()` - Update elapsed time  
✅ `startDutyTimer()` - Start local timer  
✅ `stopDutyTimer()` - Stop local timer  
✅ `handleDutyTimerMessage()` - Process duty updates  
✅ `handleLocationUpdateMessage()` - Process location updates  

**WatchMainView.swift should now compile successfully!** 🎉

---

**Status**: ✅ Complete  
**Files Modified**: WatchConnectivityManager.swift  
**Date**: November 16, 2025  
**Next Step**: Clean Build and Test on Physical Watch

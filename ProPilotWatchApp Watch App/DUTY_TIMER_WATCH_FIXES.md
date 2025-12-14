# WatchConnectivityManager Updates for DutyTimerWatchView

## ✅ Fixed Errors in DutyTimerWatchView.swift

### Errors Were:
```
error: Value of type 'WatchConnectivityManager' has no dynamic member 'isPhoneReachable'
error: Value of type 'WatchConnectivityManager' has no dynamic member 'dutyStartTime'
error: Value of type 'WatchConnectivityManager' has no dynamic member 'isDutyTimerRunning'
error: Value of type 'WatchConnectivityManager' has no dynamic member 'currentAirport'
error: Value of type 'WatchConnectivityManager' has no dynamic member 'currentSpeed'
error: Value of type 'WatchConnectivityManager' has no dynamic member 'elapsedDutyTime'
```

### Root Cause:
`WatchConnectivityManager` was missing the `@Published` properties that `DutyTimerWatchView` was trying to access.

## 📝 Changes Made to WatchConnectivityManager.swift

### 1. Added Missing @Published Properties ✅

```swift
// Connection State
@Published var isPhoneReachable = false  // For connection indicator

// Duty Timer
@Published var isDutyTimerRunning = false  // For duty status
@Published var dutyStartTime: Date?  // For calculating elapsed time
@Published var elapsedDutyTime: String = "00:00:00"  // For display

// Location Data
@Published var currentAirport: String = ""  // For airport display
@Published var currentSpeed: Double = 0.0  // For speed display

// Trip Data
@Published var currentTripId: UUID?  // For trip tracking
```

### 2. Added Private Properties ✅

```swift
private var dutyTimer: Timer?  // For updating duty time every second
```

### 3. Added Public Methods ✅

#### Duty Timer Methods
```swift
/// Send start duty message to phone
func sendStartDuty()

/// Send end duty message to phone
func sendEndDuty()

/// Update elapsed duty time (called by timer)
func updateDutyTimeIfNeeded()

/// Start local duty timer for UI updates
private func startDutyTimer()

/// Stop local duty timer
private func stopDutyTimer()
```

#### Flight Management Methods
```swift
/// Send add new leg request
func sendAddNewLeg()

/// Reset current flight data
func resetCurrentFlight()

/// Get current flight phase
func getCurrentFlightPhase() -> String

/// Get next time to set
func getNextTimeToSet() -> String?

/// Check if there's an active flight
func hasActiveFlight() -> Bool

/// Check if current leg is complete
func isLegComplete() -> Bool
```

### 4. Added Message Handlers ✅

#### Handle Duty Timer Updates from Phone
```swift
private func handleDutyTimerMessage(_ message: [String: Any]) {
    // Updates duty timer state from phone
    // - isDutyTimerRunning
    // - dutyStartTime
    // - currentTripId
    // Starts/stops local timer for UI updates
}
```

#### Handle Location Updates from Phone
```swift
private func handleLocationUpdateMessage(_ message: [String: Any]) {
    // Updates location data from phone
    // - currentSpeed
    // - currentAirport
}
```

### 5. Updated Message Switch Cases ✅

```swift
switch type {
case "flightUpdate":
    self.handleFlightUpdateMessage(message)
    
case "tripStarted":
    print("✅ Trip started on phone")
    self.handleFlightUpdateMessage(message)
    
case "tripEnded":
    print("✅ Trip ended on phone")
    self.currentFlight = nil
    self.currentLegIndex = 0
    self.totalLegs = 1
    self.hasMoreLegs = false
    
// ✅ NEW: Handle duty timer updates
case "dutyTimer":
    self.handleDutyTimerMessage(message)
    
// ✅ NEW: Handle location updates
case "locationUpdate":
    self.handleLocationUpdateMessage(message)
    
default:
    print("⚠️ Unknown message type: \(type)")
}
```

### 6. Updated Reachability Tracking ✅

```swift
// In session activation:
self.isPhoneReachable = session.isReachable

// In sessionReachabilityDidChange:
self.isPhoneReachable = session.isReachable
```

## 🎨 How DutyTimerWatchView Works Now

### View Structure
```swift
struct DutyTimerWatchView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        VStack {
            // Connection Status
            Circle()
                .fill(connectivityManager.isPhoneReachable ? .green : .red)
            
            // Current Airport
            if !connectivityManager.currentAirport.isEmpty {
                Text(connectivityManager.currentAirport)
            }
            
            // Duty Timer
            if connectivityManager.isDutyTimerRunning {
                Text("ON DUTY")
                Text(connectivityManager.elapsedDutyTime)
                Button("End Duty") {
                    connectivityManager.sendEndDuty()
                }
            } else {
                Text("OFF DUTY")
                Button("Start Duty") {
                    connectivityManager.sendStartDuty()
                }
            }
            
            // Speed Display
            if connectivityManager.currentSpeed > 0 {
                Text("\(Int(connectivityManager.currentSpeed)) kts")
            }
        }
    }
}
```

## 🔄 Data Flow

### Starting Duty
```
1. User taps "Start Duty" on watch
   ↓
2. Watch: connectivityManager.sendStartDuty()
   ↓
3. Watch → Phone: {"type": "startDuty", "timestamp": ...}
   ↓
4. Phone: Starts duty timer, creates trip
   ↓
5. Phone → Watch: {"type": "dutyTimer", "isRunning": true, "startTime": ...}
   ↓
6. Watch: handleDutyTimerMessage()
   ↓
7. Watch: isDutyTimerRunning = true
   ↓
8. Watch: dutyStartTime = Date(...)
   ↓
9. Watch: startDutyTimer() // Starts local 1-second timer
   ↓
10. Watch UI: Shows "ON DUTY" with elapsed time
```

### Duty Time Updates (Every Second)
```
1. Local Timer fires every 1 second
   ↓
2. Watch: updateDutyTimeIfNeeded()
   ↓
3. Calculate: Date().timeIntervalSince(dutyStartTime)
   ↓
4. Format: "HH:MM:SS"
   ↓
5. Update: elapsedDutyTime = "01:23:45"
   ↓
6. SwiftUI: View refreshes showing new time
```

### Ending Duty
```
1. User taps "End Duty" on watch
   ↓
2. Watch: connectivityManager.sendEndDuty()
   ↓
3. Watch: stopDutyTimer() // Stop local timer immediately
   ↓
4. Watch → Phone: {"type": "endDuty", "timestamp": ...}
   ↓
5. Phone: Ends duty timer, finalizes trip
   ↓
6. Phone → Watch: {"type": "dutyTimer", "isRunning": false}
   ↓
7. Watch: handleDutyTimerMessage()
   ↓
8. Watch: isDutyTimerRunning = false
   ↓
9. Watch UI: Shows "OFF DUTY" with start button
```

### Location Updates
```
1. Phone: Location changes or speed changes
   ↓
2. Phone → Watch: {"type": "locationUpdate", "speed": 120, "airport": "KORD"}
   ↓
3. Watch: handleLocationUpdateMessage()
   ↓
4. Watch: currentSpeed = 120, currentAirport = "KORD"
   ↓
5. Watch UI: Shows "120 kts" and "KORD" badge
```

## 🧪 Testing

### Test 1: Connection Indicator
```
1. Open DutyTimerWatchView
2. ✅ Verify: Green or red circle shows at top
3. Lock iPhone
4. ✅ Verify: Circle turns red
5. Unlock iPhone
6. ✅ Verify: Circle turns green
```

### Test 2: Start Duty
```
1. Tap "Start Duty" on watch
2. ✅ Verify: Shows "ON DUTY"
3. ✅ Verify: Timer starts counting (00:00:01, 00:00:02, ...)
4. Check phone
5. ✅ Verify: Duty timer running on phone
6. Wait 1 minute
7. ✅ Verify: Watch shows "00:01:XX"
```

### Test 3: End Duty
```
1. With duty running, tap "End Duty"
2. ✅ Verify: Timer stops immediately
3. ✅ Verify: Shows "OFF DUTY"
4. Check phone
5. ✅ Verify: Duty timer stopped on phone
```

### Test 4: Airport Display
```
1. Start duty near an airport
2. ✅ Verify: Airport code appears (e.g., "KORD")
3. Move away from airport
4. ✅ Verify: Airport code disappears or updates
```

### Test 5: Speed Display
```
1. Start moving (driving, flying)
2. ✅ Verify: Speed appears when > 0
3. ✅ Verify: Shows "XX kts" format
4. Stop moving
5. ✅ Verify: Speed display disappears or shows 0
```

### Test 6: Persistence Across Restarts
```
1. Start duty on watch
2. Force quit watch app
3. Reopen watch app
4. ✅ Verify: Still shows duty running
5. ✅ Verify: Elapsed time is correct
```

## 🐛 Troubleshooting

### Issue: "OFF DUTY" Always Shows
**Cause:** Not receiving duty timer messages from phone  
**Solution:**
1. Check phone console for "Sending duty timer update"
2. Check watch console for "📥 Processing duty timer update"
3. Verify `PhoneWatchConnectivity.sendDutyTimerUpdate()` is being called
4. Try "Reconnect" in watch Settings

### Issue: Elapsed Time Not Updating
**Cause:** Local timer not started  
**Solution:**
1. Check watch console for "✅ Duty timer running: true"
2. Verify `startDutyTimer()` was called
3. Check that `dutyStartTime` is not nil
4. Restart watch app

### Issue: Airport/Speed Never Show
**Cause:** Not receiving location updates from phone  
**Solution:**
1. Check phone has location permission
2. Check phone console for "Sending location update"
3. Verify `PhoneWatchConnectivity.sendLocationUpdate()` exists
4. Check watch console for "📥 Processing location update"

### Issue: Connection Always Shows Red
**Cause:** `isPhoneReachable` not being updated  
**Solution:**
1. Check watch console for "📡 Watch reachability changed"
2. Verify `sessionReachabilityDidChange` is being called
3. Check Bluetooth is enabled on both devices
4. Restart both devices

## 📊 Console Logs

### Good Signs (Watch)
```
🔷 WatchConnectivityManager initialized
✅ Watch session activated
📡 Watch reachability changed: ✅ Connected
⌚ Sent start duty to phone
📥 Processing duty timer update
✅ Duty timer running: true
✅ Duty started at: 2025-11-16 20:30:00
📥 Processing location update
✅ Speed updated: 120.5 kts
✅ Airport updated: KORD
```

### Bad Signs (Watch)
```
❌ Watch session activation failed
⚠️ Phone not reachable, queuing message
⚠️ Message missing type field
📡 Watch reachability changed: ❌ Disconnected
```

## ✅ Summary

All errors in `DutyTimerWatchView.swift` are now fixed! The `WatchConnectivityManager` has:

✅ All required `@Published` properties  
✅ Duty timer management methods  
✅ Message handlers for duty and location updates  
✅ Proper reachability tracking  
✅ Helper methods for flight management  

The view should now compile and run without errors, displaying:
- Connection status (green/red dot)
- Current airport (if available)
- Duty timer with elapsed time
- Speed display (if moving)
- Start/End duty buttons

---

**Status**: ✅ Complete  
**Version**: 2.0  
**Date**: November 16, 2025  
**Compatibility**: watchOS 10+

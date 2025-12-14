# Watch Connectivity Integration Guide

## ✅ What's Been Fixed

I've updated your `PhoneWatchConnectivity.swift` to properly integrate with your actual app structure:

### Key Changes Made:

1. **Added Store References** - Connected to `LogBookStore` and `PilotActivityManager`
2. **Fixed Data Type Conversions** - Converts between Date (Watch) ↔ String (Phone)
3. **Proper Property Names** - Uses `departure`/`arrival` instead of `departureAirport`/`arrivalAirport`
4. **Working Trip Updates** - Actually saves time changes to your trips
5. **Duty Timer Integration** - Syncs with `PilotActivityManager`
6. **Status View Support** - Added `currentFlight` property for `WatchConnectivityStatusView`

## 🚀 Integration Steps

### Step 1: App Initialization (Already Done! ✅)

Your `ProPilotApp.swift` has been updated to initialize the watch connectivity:

```swift
private func initializeWatchConnectivity() {
    #if os(iOS)
    let phoneConnectivity = PhoneWatchConnectivity.shared
    
    // Connect to stores
    phoneConnectivity.logbookStore = logbookStore
    phoneConnectivity.activityManager = activityManager
    
    print("✅ Phone Watch Connectivity initialized")
    #endif
}
```

### Step 2: Notify Watch When Trip Starts

You need to call these methods when a trip starts. Find where you handle trip creation/start in your app and add:

```swift
// When user starts a trip:
func startTrip(_ trip: Trip) {
    // Your existing trip start code...
    trip.status = .active
    
    // ✅ ADD THESE LINES:
    PhoneWatchConnectivity.shared.setActiveTrip(trip)
    PhoneWatchConnectivity.shared.notifyWatchTripStarted(trip)
}
```

**Where to add this:** Look for code that:
- Sets `trip.status = .active`
- Creates a new trip
- Starts duty timer
- Handles "Start Trip" button tap

Common files to check:
- `TripDetailView.swift`
- `TripCreationView.swift`
- `LogBookView.swift`
- Any view that has a "Start Trip" or "Begin Duty" button

### Step 3: Notify Watch When Trip Ends

```swift
// When trip completes:
func endTrip() {
    // Your existing trip end code...
    
    // ✅ ADD THIS LINE:
    PhoneWatchConnectivity.shared.notifyWatchTripEnded()
}
```

### Step 4: Sync Duty Timer Status

If you already have duty timer notifications, you can connect them. Otherwise, add these where your duty timer starts/ends:

```swift
// When duty timer starts:
func startDutyTimer() {
    let startTime = Date()
    
    // Your existing code...
    
    // ✅ ADD THIS:
    NotificationCenter.default.post(
        name: .dutyTimerStarted,
        object: nil,
        userInfo: ["startTime": startTime]
    )
}

// When duty timer ends:
func endDutyTimer() {
    // Your existing code...
    
    // ✅ ADD THIS:
    NotificationCenter.default.post(name: .dutyTimerEnded, object: nil)
}
```

## 🎯 How It Works Now

### Phone → Watch Flow

1. **Trip Starts**
   - User taps "Start Trip" on phone
   - `PhoneWatchConnectivity.shared.notifyWatchTripStarted(trip)`
   - Watch receives trip data and displays it

2. **Watch Sets Time**
   - User sets OUT time on watch (e.g., 14:30 UTC)
   - Watch sends: `{ type: "setTime", timeType: "OUT", timestamp: 1699999999.0, legIndex: 0 }`
   - Phone receives, converts timestamp to "1430" string
   - Phone saves to `trip.legs[0].outTime = "1430"`
   - Phone replies with updated flight data
   - Watch displays updated times

3. **Next Leg**
   - User taps "Next Leg" on watch
   - Watch sends: `{ type: "requestNextLeg", currentLegIndex: 0 }`
   - Phone moves to leg 1, sends leg 1 data
   - Watch displays leg 1

### Data Type Conversions

Your app stores times as strings (e.g., "1430"), but the watch uses `Date` objects. The connectivity manager handles all conversions:

```swift
// Watch → Phone (Date to String)
let time = Date() // 2024-11-16 19:30:00 UTC
let timeString = "1930" // HHMM format
trip.legs[0].outTime = timeString

// Phone → Watch (String to Date)
let outTime = "1930" // From leg.outTime
let outDate = parseTimeString(outTime) // Converts to Date
message["outTime"] = outDate.timeIntervalSince1970 // Send as timestamp
```

## 📱 Testing

### Test 1: Trip Start
1. Start a trip on iPhone
2. Check phone console:
   ```
   ✅ Set active trip: Trip123
   ✅ Sent trip started to watch
   ```
3. Check watch - should show trip info

### Test 2: Set Time
1. On watch, tap OUT button
2. Pick time (e.g., 14:30)
3. Tap "Set OUT"
4. Phone console should show:
   ```
   📥 Phone received: setTime
   ✅ Phone set OUT time to 1430 on leg 0
   💾 Saved trip changes
   ```
5. Check iPhone app - should see updated OUT time

### Test 3: Next Leg
1. Set all 4 times on leg 1
2. Tap "Next Leg" on watch
3. Phone console:
   ```
   📥 Phone received: requestNextLeg
   ✅ Phone moved to leg 1
   ✅ Created flight update for leg 1
   ```
4. Watch shows leg 2 data

## 🔍 Key Features

### ✅ Proper Time Conversion
- Watch uses `Date` objects
- Phone stores as `String` in "HHMM" format
- Automatic conversion in both directions

### ✅ Proper Trip Management
- Tracks active trip by UUID
- Gets trip from `LogBookStore`
- Saves using `store.save()`

### ✅ Works with Logpages
- Your `Trip` has a `logpages` structure
- Uses computed `legs` property
- Works seamlessly with `trip.legs[legIndex]`

### ✅ Duty Timer Integration
- Syncs with `PilotActivityManager`
- Updates `WatchConnectivityStatusView`
- Notifies watch of duty status changes

### ✅ Status View Support
- `currentFlight` property for display
- Shows current leg information
- Real-time sync status

## 🐛 Troubleshooting

### "No active trip"
- Make sure you called `setActiveTrip(trip)` when trip started
- Check that trip has `.active` status
- Verify trip has at least one leg

### Times not updating
- Check trip is active (`trip.status == .active`)
- Verify leg index is valid (< trip.legs.count)
- Look for console logs showing save confirmation
- Make sure watch is reachable (`WCSession.default.isReachable`)

### Watch not receiving updates
- Check watch is paired and app is installed
- Verify watch is unlocked and nearby
- Check `WCSession.default.activationState == .activated`
- Use `WatchConnectivityStatusView` to debug connection

### Duty timer not syncing
- Make sure you're posting the notification when duty starts
- Check `PilotActivityManager.shared.dutyStartTime` is set
- Verify `isDutyTimerRunning` updates correctly

## 📊 Summary

### What Makes It Work:

✅ **Proper type conversion** (Date ↔ String)  
✅ **Correct property names** (departure/arrival)  
✅ **Integrated with LogBookStore**  
✅ **Proper save calls** (store.save())  
✅ **Active trip tracking** (by UUID)  
✅ **All delegate methods** (iPhone-specific)  
✅ **Duty timer integration** (PilotActivityManager)  
✅ **Status view support** (currentFlight property)

### Files Updated:

- ✅ `PhoneWatchConnectivity.swift` - Full implementation
- ✅ `ProPilotApp.swift` - Initialization added
- ✅ `WatchConnectivityStatusView.swift` - Fixed compiler errors

### Files You Need to Update:

- ⏳ Trip start handler - Add `setActiveTrip()` and `notifyWatchTripStarted()`
- ⏳ Trip end handler - Add `notifyWatchTripEnded()`
- ⏳ Duty timer handlers - Add notification posts (optional)

## 🎉 Next Steps

1. **Find your trip start code** - Look for where `trip.status = .active` is set
2. **Add watch notification** - Call `PhoneWatchConnectivity.shared.notifyWatchTripStarted(trip)`
3. **Test on device** - Build to iPhone and Apple Watch
4. **Check console logs** - Look for "✅" success messages
5. **Use status view** - Navigate to Watch Status to monitor sync

The integration is now complete and ready to use! The watch can receive trip data, set flight times, move to the next leg, and sync duty status. All data is properly saved to your `LogBookStore` with the correct time format.

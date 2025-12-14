# 16-Hour Duty Limit Tracking - Complete Guide

## How the 16-Hour Duty Limit is Tracked

The 16-hour duty limit for FAR 121 Cargo operations is tracked by **DutyTimerManager** which provides:
- ✅ Real-time tracking during active trips
- ✅ Progressive warnings at 14h, 15h, 15.5h, 16h
- ✅ Automatic sync to Apple Watch
- ✅ Widget updates
- ✅ Automatic save to trip history when completed

## Components of the System

### 1. DutyTimerManager (Real-Time Tracking)

**Location:** `DutyTimerManager.swift`

**16-Hour Limit Configuration:**
```swift
private let fourteenHourWarning: TimeInterval = 14 * 3600      // 2 hours remaining
private let fifteenHourWarning: TimeInterval = 15 * 3600       // 1 hour remaining  
private let fifteenHalfHourWarning: TimeInterval = 15.5 * 3600 // 30 min remaining
private let sixteenHourLimit: TimeInterval = 16 * 3600         // LIMIT REACHED
```

**Key Methods:**
- `startDuty()` - Starts the timer when trip begins
- `endDuty()` - Stops timer and saves data to trip
- `timeRemaining()` - Calculates time left until 16-hour limit
- `dutyStatus()` - Returns current status (normal/warning/critical/exceeded)

### 2. LiveDutyTimerDisplay (UI Component)

**Location:** `ForeFlightLogBookRow.swift` (lines 1678-1753)

**Shows during active trips:**
```
┌───────────────────────────────────────┐
│ ⏱️ Live Duty Timer       [ACTIVE]    │
├───────────────────────────────────────┤
│ Duty Time Elapsed:      12:34:56     │
│ Time Remaining:          3:25:04     │
│ ✅ Within limits                      │
│                                       │
│ This duty time will be automatically  │
│ saved when you complete Trip #1234    │
└───────────────────────────────────────┘
```

**Usage in your trip detail view:**
```swift
// In TripDetailView or wherever you show active trip info:
if trip.status == .active {
    LiveDutyTimerDisplay(trip: trip)
        .padding(.horizontal)
}
```

### 3. Visual Status Indicators

The timer changes color based on time remaining:

| Status | Time Elapsed | Color | Icon |
|--------|--------------|-------|------|
| Normal | 0-14 hours | 🟢 Green | checkmark.circle.fill |
| Warning | 14-15 hours | 🟠 Orange | exclamationmark.triangle.fill |
| Critical | 15-15.5 hours | 🔴 Red | exclamationmark.triangle.fill |
| Limit Reached | 15.5-16+ hours | 🔴 Red | xmark.octagon.fill |

### 4. Progressive Warnings

**At 14 Hours (2h remaining):**
```
⚠️ 14 Hours on Duty
2 hours remaining until FAR 121 limit
```
- Push notification
- In-app alert
- Watch notification

**At 15 Hours (1h remaining):**
```
🚨 15 Hours on Duty
1 hour remaining until FAR 121 limit
```
- CRITICAL push notification
- In-app alert
- Watch notification

**At 15.5 Hours (30min remaining):**
```
🚨 15.5 Hours on Duty
30 minutes remaining until FAR 121 limit
```
- URGENT push notification
- In-app alert
- Watch notification

**At 16 Hours (LIMIT REACHED):**
```
🛑 16 Hour Limit Reached
FAR 121 duty limit exceeded
```
- CRITICAL alert
- Cannot be dismissed easily
- Watch notification

## When Does It Start?

The duty timer starts **automatically** when:

1. **You create a trip** with status = "Active"
2. **You record first OUT time** on an active trip

**Controlled by:** `ContentView.swift` → `checkAndAutoStartDutyForActiveTrip()`

```swift
// This runs automatically when:
// - App launches with active trip
// - Trip status changes to active
// - First OUT time is recorded
```

## When Does It Stop?

The duty timer stops when you **complete the trip**:

1. Tap **"End Trip"** button in ActiveTripBanner
2. Confirm in dialog
3. **BEFORE timer stops:**
   - Duty time is captured
   - Saved to trip.dutyStartTime, trip.dutyEndTime, trip.dutyMinutes
4. **THEN timer ends:**
   - Clears timer state
   - Syncs to Watch
   - Updates widgets

**Controlled by:** `ContentView.swift` → `completeTrip()`

## Where to See It

### 1. Active Trip Banner (Always Visible)
If you have an active trip, the banner shows current duty status.

### 2. Trip Detail View
When viewing active trip details:
```swift
LiveDutyTimerDisplay(trip: trip)
```

### 3. Apple Watch
Synced via `PhoneWatchConnectivity`:
- Duty timer state
- Elapsed time
- Warnings

### 4. Home Screen Widget
Shows:
- "ON DUTY" status
- Elapsed time
- Current trip number

### 5. Lock Screen (via Live Activity)
If Live Activities enabled:
- Real-time duty timer
- Trip progress
- Current airport

## Historical Tracking (Completed Trips)

After trip completes, duty time is stored in the Trip:

```swift
// Stored properties:
trip.dutyStartTime: Date?     // When duty started
trip.dutyEndTime: Date?       // When duty ended  
trip.dutyMinutes: Int?        // Total minutes on duty

// Computed property:
trip.totalDutyHours: Double   // Used for FDP calculations
```

**Display using:**
```swift
if trip.status == .completed {
    CompletedDutyTimeSummary(trip: trip)
        .padding(.horizontal)
}
```

Shows:
```
┌───────────────────────────────────┐
│ ✓ Duty Time Summary  [Recorded]  │
├───────────────────────────────────┤
│ Duty Period:         08:30        │
│                       to          │
│                      23:45        │
│                                   │
│ Total Duty Time:   15.25 hours   │
│ Pre/Post Flight:    +3.8 hours   │
└───────────────────────────────────┘
```

## Integration with 7-Day FDP Limit

The 16-hour per-trip limit feeds into your **60-hour / 7-day FDP limit**:

```swift
// In calculateConfigurableLimits():
for trip in operatingTrips {
    let dutyHours = trip.totalDutyHours  // Includes all duty time
    
    if tripDate >= date7DaysAgo && tripDate <= date {
        dutyTime7Day += dutyHours  // Adds to 7-day total
    }
}

status.fdpTime7Day = dutyTime7Day  // Shows as "7d FDP: XX/60h"
```

## Auto-Calculation Fallback

If duty timer wasn't running (imported trips, manual entries), system auto-calculates:

```swift
effectiveDutyStartTime = firstLeg.outTime - 60 minutes
effectiveDutyEndTime = lastLeg.inTime + 15 minutes
totalDutyHours = (end - start) in hours
```

This ensures all trips contribute to your FDP tracking even if timer wasn't active.

## Testing the 16-Hour Limit

To test without waiting 16 hours, you can temporarily modify `DutyTimerManager.swift`:

```swift
// FOR TESTING ONLY - Change limits to minutes instead of hours:
private let fourteenHourWarning: TimeInterval = 14 * 60      // 14 minutes
private let fifteenHourWarning: TimeInterval = 15 * 60       // 15 minutes
private let fifteenHalfHourWarning: TimeInterval = 15.5 * 60 // 15.5 minutes
private let sixteenHourLimit: TimeInterval = 16 * 60         // 16 minutes
```

**WARNING:** Don't forget to change back to `* 3600` for production!

## Manual Override

If duty timer started at wrong time, pilots can manually correct using `DutyStartTimeEditor`:

```swift
DutyStartTimeEditor(trip: $trip)
```

This lets them:
- See calculated duty start time
- Manually adjust if they started duty earlier/later
- Reset to auto-calculation
- Uses quick presets: -2h, -1.5h, -1h, -45m

## Troubleshooting

### Timer not starting?
**Check:**
1. Is trip status = "Active"?
2. Does trip have at least one leg?
3. Check console logs for "Duty timer started"

### Timer not stopping when trip completes?
**Check:**
1. Is `completeTrip()` being called?
2. Check console logs for "Capturing duty time"

### Time seems wrong?
**Check:**
1. Did duty timer start when expected?
2. Did phone go to sleep/background?
3. Timer should persist through app restarts (loads from UserDefaults)

## Summary

Your 16-hour duty limit is tracked by:
- ✅ **DutyTimerManager** - Real-time tracking with warnings
- ✅ **LiveDutyTimerDisplay** - Visual UI during active trips
- ✅ **Progressive warnings** - At 14h, 15h, 15.5h, 16h
- ✅ **Automatic save** - To trip history when completed
- ✅ **Integration with FDP** - Feeds into 7-day and rolling totals
- ✅ **Fallback calculation** - Auto-calculates if timer wasn't active

The system is **always watching** and will alert you well before you reach the 16-hour limit!

---

**Next Steps:** Make sure `LiveDutyTimerDisplay` is added to your active trip view so pilots can see the timer during flights.

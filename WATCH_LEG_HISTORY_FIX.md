# Watch Leg History Fix - Completed Legs Not Showing

## Problem
Previous completed legs were not appearing in the watch's history view when the phone auto-advanced to the next leg after IN time was set.

## Root Cause
The issue occurred because:

1. **Watch sends IN time** → Phone receives and auto-advances to next leg (this was working correctly)
2. **Phone sends new leg data back** → Watch receives update with new `legIndex`
3. **Watch overwrites `currentFlight`** with new leg data WITHOUT saving the old completed leg to history first

The watch's `handleFlightUpdateMessage` in `WatchConnectivityManager.swift` was blindly accepting new leg data without checking if the previous leg should be saved to the `completedLegs` array.

## Solution

### Fix #1: Auto-Save to History When Leg Index Changes
**File:** `WatchConnectivityManager.swift`

Added logic to detect when the phone is advancing to a new leg and automatically save the old leg to history:

```swift
// Phone tells us what leg we're on - TRUST IT
if let legIndex = message["legIndex"] as? Int {
    // ✅ FIX: If advancing to a new leg, save the old leg to history first
    if legIndex > self.currentLegIndex {
        print("⌚ 📦 LEG ADVANCED: \(self.currentLegIndex) → \(legIndex) - saving old leg to history")
        if let oldFlight = self.currentFlight,
           oldFlight.outTime != nil && oldFlight.offTime != nil &&
           oldFlight.onTime != nil && oldFlight.inTime != nil {
            self.saveCurrentLegAsCompleted()
        } else {
            print("⌚ ⚠️ Old leg incomplete, not saving to history")
        }
    }
    
    self.currentLegIndex = legIndex
    print("✅ Updated to leg \(legIndex + 1)")
}
```

This ensures that:
- When the phone advances to leg 2, the watch saves leg 1 to history
- Only complete legs (all 4 times filled) are saved
- The history is preserved before the new leg data overwrites `currentFlight`

### Fix #2: Local Auto-Save After Setting IN Time
**File:** `FlightTimesWatchView.swift`

Added a check after the IN time is set locally to save to history if the leg becomes complete:

```swift
CompactSmartTimeButton(
    label: "IN", time: inTime, color: .green,
    onTimeSet: { time in 
        connectivityManager.sendTimeEntry(timeType: "IN", time: time)
        
        // ✅ CHECK: If leg becomes complete after setting IN, save to history
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isLegComplete {
                print("⌚ Leg complete after IN - saving to history")
                connectivityManager.saveCurrentLegAsCompleted()
            }
        }
    }
)
```

This provides a backup mechanism:
- If the phone's response is slow or lost, the watch will still save locally
- The 0.5 second delay allows the UI to update `inTime` first
- Only saves if all 4 times are present

## Flow Diagram

### Before Fix:
```
Watch: Set IN time
  ↓
Phone: Receives IN time, advances to Leg 2
  ↓
Phone: Sends Leg 2 data back
  ↓
Watch: Updates currentFlight with Leg 2
  ❌ Leg 1 data LOST - never saved to history
```

### After Fix:
```
Watch: Set IN time
  ↓
Watch: Checks if complete → saves to history (local backup)
  ↓
Phone: Receives IN time, advances to Leg 2
  ↓
Phone: Sends Leg 2 data with legIndex=1
  ↓
Watch: Detects legIndex change (0→1)
  ✅ Saves Leg 1 to completedLegs array
  ↓
Watch: Updates currentFlight with Leg 2
  ✅ Leg 1 preserved in history
```

## Testing
To verify the fix:

1. Start a trip with multiple legs
2. On the watch, set OUT, OFF, ON, IN for leg 1
3. **Expected:** Leg 1 should appear in history pages (swipe right from current leg)
4. Leg 2 should become the current leg
5. Repeat for leg 2
6. **Expected:** Both legs 1 and 2 should be visible in history

## Related Code
- `PhoneWatchConnectivity.swift` - Phone-side auto-advance logic (already working)
- `WatchConnectivityManager.swift` - Watch connectivity and message handling (fixed)
- `FlightTimesWatchView.swift` - Watch UI and local save logic (fixed)
- `CompletedLegData.swift` - Data structure for completed legs
- `saveCurrentLegAsCompleted()` - Method that adds leg to `completedLegs` array

## Notes
- The phone's auto-advance logic in `handleSetTimeMessage` was already correct
- The issue was purely on the watch side not preserving data
- Both fixes work together: one catches leg advances from phone, the other handles local completion
- The `completedLegs` array is used by the `TabView` to generate history pages

# Taxi Button Debug Guide

## Expected Behavior

When the "Taxi?" button is tapped to enable Ground Operations mode:

### 1. **Visual Changes in Active Trip Banner:**
- ✅ Button changes from `[🚗 Taxi?]` (light orange) to `[🚗 TAXI]` (solid orange)
- ✅ OUT time cell: **Remains interactive** (tap to fill, long-press to pick)
- ✅ OFF time cell: **Becomes grayed out** `--:--` (not interactive)
- ✅ ON time cell: **Becomes grayed out** `--:--` (not interactive)
- ✅ IN time cell: **Remains interactive** (tap to fill, long-press to pick)
- ✅ Flight time: Shows `0:00` in gray
- ✅ Status badge: Shows "Awaiting OUT" → "Awaiting IN" → "Complete" (skips OFF/ON states)

### 2. **Data Changes:**
- ✅ `leg.isGroundOperationsOnly` = `true`
- ✅ `leg.offTime` = `""` (cleared)
- ✅ `leg.onTime` = `""` (cleared)

### 3. **Sequencing Behavior:**
After OUT and IN are filled (leg is complete):
- ✅ Leg advances to completed status
- ✅ Next leg becomes active (if exists)
- ✅ Bottom action buttons appear:
  - **+ Add Leg** (if needed)
  - **Share** (for sharing logbook)
  - **End Trip**

---

## Code Flow Trace

### Step 1: User Taps "Taxi?" Button
**File:** `ActiveTripBannerView.swift` (Lines 675-689)

```swift
Button(action: onToggleGroundOps) {
    HStack(spacing: 3) {
        Image(systemName: leg.isGroundOperationsOnly ? "car.fill" : "car")
        Text(leg.isGroundOperationsOnly ? "TAXI" : "Taxi?")
    }
    .background(leg.isGroundOperationsOnly ? LogbookTheme.accentOrange : LogbookTheme.accentOrange.opacity(0.2))
}
```

### Step 2: Callback Executes
**File:** `ContentView.swift` (Lines 1507-1554)

```swift
onToggleGroundOps: {
    var updatedTrip = store.trips[tripIndex]

    if let currentLegIndex = updatedTrip.activeLegIndex,
       currentLegIndex < updatedTrip.legs.count {

        // Find the leg in logpages structure
        var flatIndex = 0
        var foundPage = -1
        var foundLegInPage = -1

        for (pageIndex, logpage) in updatedTrip.logpages.enumerated() {
            for legInPageIndex in logpage.legs.indices {
                if flatIndex == currentLegIndex {
                    foundPage = pageIndex
                    foundLegInPage = legInPageIndex
                    break
                }
                flatIndex += 1
            }
            if foundPage >= 0 { break }
        }

        guard foundPage >= 0, foundLegInPage >= 0 else {
            print("❌ Could not locate leg \(currentLegIndex) in logpages")
            return
        }

        // Toggle the flag
        updatedTrip.logpages[foundPage].legs[foundLegInPage].isGroundOperationsOnly.toggle()

        let isGroundOps = updatedTrip.logpages[foundPage].legs[foundLegInPage].isGroundOperationsOnly

        // Clear OFF/ON if enabling ground ops
        if isGroundOps {
            updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime = ""
            updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime = ""
            print("🚗 Ground operations mode enabled - OFF/ON times cleared")
        } else {
            print("✈️ Ground operations mode disabled - normal flight mode")
        }

        // ✅ NEW: Check if leg should advance after toggling
        updatedTrip.checkAndAdvanceLeg(at: currentLegIndex)

        // Save
        store.updateTrip(updatedTrip, at: tripIndex)
        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
    }
}
```

### Step 3: Trip Updates and View Refreshes
**File:** `Trip.swift` (Lines 109-124)

The `legs` computed property automatically reflects changes to `logpages`:

```swift
var legs: [FlightLeg] {
    get { logpages.flatMap { $0.legs } }
    set {
        // ... setter logic ...
    }
}
```

### Step 4: UI Conditional Rendering
**File:** `ActiveTripBannerView.swift` (Lines 733-795)

```swift
if leg.isGroundOperationsOnly {
    // OUT - interactive
    InteractiveTimeCell(label: "OUT", time: leg.outTime, ...)

    // OFF - disabled/grayed
    Text("--:--")
        .font(.caption.monospacedDigit())
        .foregroundColor(.gray.opacity(0.4))

    // ON - disabled/grayed
    Text("--:--")
        .font(.caption.monospacedDigit())
        .foregroundColor(.gray.opacity(0.4))

    // IN - interactive
    InteractiveTimeCell(label: "IN", time: leg.inTime, ...)

    // Flight time - 0:00
    Text("0:00")
        .foregroundColor(.gray.opacity(0.5))
}
```

### Step 5: Leg Completion Check
**File:** `ActiveTripBannerView.swift` (Lines 173-187)

```swift
private func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
    if leg.isGroundOperationsOnly {
        // Ground ops only needs OUT and IN
        return !leg.outTime.isEmpty && !leg.inTime.isEmpty
    } else if leg.isDeadhead {
        // Deadhead needs deadhead OUT and IN
        return !leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty
    } else {
        // Regular flight needs all 4 times
        return !leg.outTime.isEmpty &&
               !leg.offTime.isEmpty &&
               !leg.onTime.isEmpty &&
               !leg.inTime.isEmpty
    }
}
```

### Step 6: Status Badge Updates
**File:** `ActiveTripBannerView.swift` (Lines 917-925)

```swift
if leg.isGroundOperationsOnly {
    // Ground ops status: Only check OUT and IN
    if leg.outTime.isEmpty {
        (text, color) = ("Awaiting OUT", LogbookTheme.accentOrange)
    } else if leg.inTime.isEmpty {
        (text, color) = ("Awaiting IN", LogbookTheme.errorRed)
    } else {
        (text, color) = ("Complete", LogbookTheme.successGreen)
    }
}
```

---

## Debugging Steps

### If Button Doesn't Change Appearance:
1. Check console for: `"🚗 Ground operations mode enabled - OFF/ON times cleared"`
2. Verify `leg.isGroundOperationsOnly` is actually toggling
3. Check if `store.updateTrip()` is being called
4. Verify SwiftUI is refreshing the view (add print statement in body)

### If OFF/ON Times Don't Gray Out:
1. Verify the conditional `if leg.isGroundOperationsOnly {` is true
2. Check if you're looking at the correct leg (current vs completed)
3. Ensure `trip.legs` computed property is returning updated data
4. Check if `ActiveTripBanner` is receiving the updated trip from the store

### If Sequencing Doesn't Work (+ Add Leg button doesn't appear):
1. After entering OUT and IN times, check console for leg advancement logs
2. Verify `checkAndAdvanceLeg(at: currentLegIndex)` is being called in the toggle callback
3. Check if `isLegFullyCompleted()` returns true for the ground ops leg
4. Verify the leg's status changes to `.completed`
5. Check if the trip's `allLegsComplete` computed property updates

### Console Debug Commands:
Add these print statements to `onToggleGroundOps`:

```swift
print("📍 Current leg index: \(currentLegIndex)")
print("📍 Found at page \(foundPage), leg \(foundLegInPage)")
print("📍 isGroundOperationsOnly: \(updatedTrip.logpages[foundPage].legs[foundLegInPage].isGroundOperationsOnly)")
print("📍 offTime: '\(updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime)'")
print("📍 onTime: '\(updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime)'")
print("📍 Checking leg advancement...")
```

---

## Common Issues

### Issue 1: View Not Refreshing After Toggle
**Cause:** SwiftUI not detecting the change in `store.trips`
**Solution:** Verify `LogBookStore` has `@Published var trips: [Trip]` and is an `ObservableObject`

### Issue 2: Wrong Leg Being Updated
**Cause:** `activeLegIndex` doesn't match the actual leg being displayed
**Solution:** Verify the flat index calculation in the logpages loop

### Issue 3: Sequencing Not Triggered
**Cause:** `checkAndAdvanceLeg()` not called after toggling
**Solution:** ✅ Already added in ContentView.swift line 1549

### Issue 4: OFF/ON Times Still Show Values
**Cause:** Times were not actually cleared in the data model
**Solution:** Verify the clear logic runs: `offTime = ""` and `onTime = ""`

---

## Testing Checklist

- [ ] Tap "Taxi?" button - verify it changes to "TAXI" (orange)
- [ ] Verify OFF shows `--:--` in gray (not interactive)
- [ ] Verify ON shows `--:--` in gray (not interactive)
- [ ] Verify OUT is interactive (can tap to fill)
- [ ] Verify IN is interactive (can tap to fill)
- [ ] Tap OUT - verify current time fills in
- [ ] Tap IN - verify current time fills in
- [ ] Verify status badge shows "Awaiting OUT" → "Awaiting IN" → "Complete"
- [ ] Verify leg advances to next leg after OUT+IN filled
- [ ] Verify "+ Add Leg", "Share", "End Trip" buttons appear when all legs complete
- [ ] Toggle TAXI off - verify OFF/ON become interactive again

---

## Success Criteria

✅ **Visual**: Button changes, OFF/ON grayed out, OUT/IN interactive
✅ **Data**: `isGroundOperationsOnly = true`, `offTime = ""`, `onTime = ""`
✅ **Sequencing**: Leg completes with just OUT+IN, advances to next leg
✅ **Actions**: Bottom buttons (Add Leg, Share, End Trip) appear when appropriate

---

## Related Files

- `ActiveTripBannerView.swift` - UI rendering and button
- `ContentView.swift` - Toggle callback implementation
- `FlightLeg.swift` - Data model with `isGroundOperationsOnly` flag
- `Trip.swift` - Computed `legs` property and `checkAndAdvanceLeg()`
- `GROUND_OPERATIONS_FEATURE.md` - Original feature documentation

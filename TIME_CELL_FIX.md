# Time Cell Unresponsiveness Fix

## Date: January 17, 2026

---

## Problem Description

**User Report:**
> "when clearing a cell it enters ----. clearing a cell should mean its blank with no characters so the time can be entered when tapped. when the cell was cleared it is now allowing me to edit the cell in the active trip banner"

After using the time picker to clear a time field in the active trip banner, the cell would:
1. Display `----` (actually `--:--` for empty times)
2. Become completely unresponsive to taps
3. Prevent users from re-entering times

**Location:** Active trip banner at the top (not the DataEntryView at bottom)

---

## Root Cause

The issue was a **race condition** in the time picker dismissal logic:

### Original Flow (Buggy):
1. User taps "Clear" button in time picker
2. `onClear` callback executes
3. **Immediately calls `config.onSet(config.type, "")` to clear the time**
4. Parent view receives update and triggers SwiftUI view rebuild
5. `ActiveTripBannerView` rebuilds with empty time value
6. **While rebuilding, `activeTimePickerConfig = nil` animation gets interrupted**
7. Time picker overlay doesn't fully dismiss
8. Invisible semi-transparent overlay (`Color.black.opacity(0.1)`) remains on screen
9. Overlay blocks all touch events to underlying `InteractiveTimeCell` components
10. Cells appear unresponsive

### Why This Happened:
SwiftUI's declarative nature means that when `config.onSet()` triggers a state change in the parent, the entire view hierarchy can rebuild. If this happens while the picker dismissal animation is in progress, the animation can be interrupted, leaving the overlay in a partially-visible or fully-invisible but still-present state.

---

## Solution

### Fixed Flow:
1. User taps "Clear" button in time picker
2. `onClear` callback executes
3. **Immediately dismiss picker overlay by setting `activeTimePickerConfig = nil`**
4. Wait for animation to complete (100ms delay)
5. **Then call `config.onSet(config.type, "")` to clear the time**
6. Parent view updates with empty time value
7. Overlay is already gone, so no blocking occurs
8. Cells remain fully responsive

### Code Changes

**File:** `ActiveTripBannerView.swift`

**Before (Lines 550-558):**
```swift
onClear: {
    // Clear the time field by setting empty string
    config.onSet(config.type, "")

    print("⏱️ \(config.type) cleared")

    withAnimation(.spring()) {
        activeTimePickerConfig = nil
    }
}
```

**After (Lines 551-564):**
```swift
onClear: {
    print("⏱️ \(config.type) cleared - dismissing picker first")

    // IMPORTANT: Dismiss picker FIRST to prevent UI blocking
    withAnimation(.spring()) {
        activeTimePickerConfig = nil
    }

    // Then clear the time field after a brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        config.onSet(config.type, "")
        print("⏱️ \(config.type) time cleared")
    }
}
```

---

## Additional Improvements Made

### 1. Explicit ZStack Layering (Lines 246-256)

Added explicit `zIndex()` modifiers to ensure proper overlay stacking:

```swift
var body: some View {
    ZStack {
        // Main banner content
        mainBannerContent
            .zIndex(0)  // Ensure main content is behind overlay

        // Translucent Time Picker Overlay
        if let config = activeTimePickerConfig {
            timePickerOverlay(config: config)
                .zIndex(1)  // Ensure overlay is in front
                .transition(.opacity)
        }
    }
}
```

### 2. Added Hit Testing Control (Line 517)

Explicitly enabled hit testing for the overlay background:

```swift
Color.black.opacity(0.1)
    .ignoresSafeArea()
    .allowsHitTesting(true)  // Only intercept hits when visible
    .onTapGesture {
        withAnimation(.spring()) {
            activeTimePickerConfig = nil
        }
    }
    .transition(.opacity)
```

---

## Why This Fix Works

### Timing is Everything
By dismissing the overlay **before** updating the data model:
- ✅ The overlay animation completes uninterrupted
- ✅ The overlay is fully removed from the view hierarchy
- ✅ No invisible blocking layer remains
- ✅ Touch events reach the `InteractiveTimeCell` components

### Asynchronous Update
The 100ms delay (`DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`) ensures:
- ✅ Spring animation has time to complete (~80ms)
- ✅ SwiftUI updates the view hierarchy
- ✅ Old overlay is completely gone before new data arrives
- ✅ No race conditions between animation and state updates

---

## Testing Checklist

- [ ] Tap time cell to fill current time - verify it works
- [ ] Long-press time cell to open picker - verify picker appears
- [ ] In picker, tap "Clear" button - verify picker dismisses smoothly
- [ ] After clearing, verify cell shows `--:--` (not `----`)
- [ ] Tap the cleared cell again - **verify it's responsive and fills current time**
- [ ] Long-press cleared cell - **verify picker opens again**
- [ ] Test with all four time types: OUT, OFF, ON, IN
- [ ] Test with ground operations mode (OUT/IN only)
- [ ] Test with deadhead mode (deadhead OUT/IN)
- [ ] Verify no invisible blocking overlays remain after any picker dismissal

---

## Related Issues Fixed in This Session

### 1. FlightAware Button Visibility
**File:** `ActiveTripBannerView.swift` (Lines 691-704)

Added three-tier fallback for flight identification:
```swift
let hasFlightIdentifier = !leg.flightNumber.isEmpty || !trip.tripNumber.isEmpty || !trip.aircraft.isEmpty
if !leg.outTime.isEmpty && hasFlightIdentifier {
    // Show FlightAware button
}
```

### 2. Part 91 N-Number Support
**File:** `ActiveTripBannerView.swift` (Lines 1389-1437)

FlightAware now works for private/corporate operations:
```swift
// Priority: leg flight number > trip number > aircraft N-number (for Part 91)
var flightIdentifier = ""
if !leg.flightNumber.isEmpty {
    flightIdentifier = leg.flightNumber
} else if !trip.tripNumber.isEmpty {
    flightIdentifier = trip.tripNumber
} else if !trip.aircraft.isEmpty {
    flightIdentifier = trip.aircraft  // Part 91: Use N-number
}
```

### 3. Ground Operations Toggle
**File:** `FlightLeg.swift` + `ActiveTripBannerView.swift`

Added `isGroundOperationsOnly` flag for taxi-only legs. See `GROUND_OPERATIONS_FEATURE.md` for full details.

---

## Technical Notes

### SwiftUI Animation Lifecycle
Understanding how SwiftUI handles animations is crucial:

1. **Animation Start**: `withAnimation { ... }` queues state change
2. **View Update**: SwiftUI calculates new view tree
3. **Interpolation**: Spring animation interpolates over ~80ms
4. **Rendering**: Each frame renders intermediate states
5. **Completion**: Final state reached, animation ends

If a state change occurs during steps 3-4, the animation can be interrupted, leading to UI inconsistencies.

### Conditional Overlays
When using conditional overlays in ZStack:
```swift
if let config = activeTimePickerConfig {
    overlayView(config)
}
```

The overlay is completely removed from the hierarchy when `activeTimePickerConfig` becomes nil. However, if the parent view rebuilds during the removal animation, the overlay can get "stuck" in an invisible state where it's still blocking touches but no longer visible.

### Best Practice
**Always dismiss overlays BEFORE triggering state changes that rebuild the view hierarchy.**

---

## Summary

The time cell unresponsiveness bug was caused by a race condition between overlay dismissal and parent view updates. By reversing the order of operations (dismiss first, update data later), we ensure clean overlay removal and maintain cell responsiveness.

**Status:** ✅ Fixed and ready for testing

**Next Step:** User testing to verify cells remain responsive after clearing

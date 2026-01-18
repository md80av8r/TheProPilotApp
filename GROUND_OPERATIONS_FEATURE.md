# Ground Operations Only Feature

## Overview
Added support for logging taxi-only legs, maintenance runs, or aborted takeoffs where the aircraft never takes off (OUT/IN times only, no OFF/ON times).

---

## What Was Added

### 1. New FlightLeg Property
**File:** `FlightLeg.swift`

Added `isGroundOperationsOnly` boolean flag:
```swift
var isGroundOperationsOnly: Bool = false  // Taxi, maintenance run, aborted takeoff
```

This flag indicates the leg involves ground operations only (no flight time).

---

### 2. Updated Validation Logic

**Changed `isLegFullyCompleted()` to handle three leg types:**
1. **Ground Operations** - Requires only OUT and IN times
2. **Deadhead** - Requires deadheadOutTime and deadheadInTime
3. **Regular Flight** - Requires all four times (OUT, OFF, ON, IN)

---

### 3. UI Toggle in Active Trip Banner

**Location:** Right after the city pair display, before FlightAware button

**Visual Design:**
```
[✈️ JFK → LAX]  [🚕 TAXI]  [✈️ FlightAware]  [Status Badge]
```

**Toggle States:**
- **OFF (default):** Shows `[🚗 Taxi?]` in light orange background
- **ON:** Shows `[🚗 TAXI]` in solid orange with white text

**When enabled:**
- OUT and IN time cells remain interactive (tap to fill, long-press to pick)
- OFF and ON cells show grayed out `--:--` (non-interactive)
- Flight time shows `0:00` (grayed)
- Block time calculates normally (OUT to IN)
- Status badge only waits for OUT and IN

---

## How It Works

### For Users:

1. **Start a leg normally** (e.g., taxi to another gate, maintenance run, aborted takeoff)
2. **Tap the "Taxi?" badge** next to the city pair
3. **Badge turns orange "TAXI"** - OFF/ON fields become disabled
4. **Enter OUT time** (tap to fill current time or long-press to pick)
5. **Enter IN time** (tap to fill current time or long-press to pick)
6. **Leg completes** - Only OUT and IN are required, bypasses OFF/ON validation

### Use Cases:

- **Taxi to another gate** (e.g., JFK Terminal 1 → JFK Terminal 4)
- **Maintenance taxi** (gate to hangar, runway check)
- **Aborted takeoff** (OUT but returned to gate before takeoff)
- **Repositioning on ground** (towing with engines running)

---

## Technical Implementation

### Files Modified:

1. **FlightLeg.swift**
   - Added `isGroundOperationsOnly: Bool = false`
   - Updated initializer to include new property
   - Added to CodingKeys for persistence
   - Added to decoder with fallback to `false` for legacy data
   - Updated `isValid` to allow ground ops with just OUT/IN

2. **ActiveTripBannerView.swift**
   - Added `onToggleGroundOps` callback parameter
   - Updated `isLegFullyCompleted()` to handle ground ops validation
   - Added compact toggle button in `currentLegView` (lines 684-699)
   - Modified time display to show OUT/IN interactive, OFF/ON grayed (lines 724-785)
   - Updated `statusBadge()` to handle ground ops status (lines 1006-1014)

---

## Data Model Changes

### Backward Compatible:
- Existing legs without `isGroundOperationsOnly` default to `false`
- No migration required - decoder handles missing field gracefully
- New property persists via CloudKit sync

### Persistence:
```swift
enum CodingKeys: String, CodingKey {
    case isGroundOperationsOnly  // Added to existing keys
}

// Decoder (backward compatible)
isGroundOperationsOnly = (try? container.decode(Bool.self, forKey: .isGroundOperationsOnly)) ?? false
```

---

## Validation Logic

### Before (Regular Flight):
```swift
isComplete = !outTime.isEmpty && !offTime.isEmpty && !onTime.isEmpty && !inTime.isEmpty
```

### After (With Ground Ops):
```swift
if leg.isGroundOperationsOnly {
    isComplete = !outTime.isEmpty && !inTime.isEmpty  // ✅ Only 2 times required
} else if leg.isDeadhead {
    isComplete = !deadheadOutTime.isEmpty && !deadheadInTime.isEmpty
} else {
    isComplete = !outTime.isEmpty && !offTime.isEmpty && !onTime.isEmpty && !inTime.isEmpty
}
```

---

## UI/UX Details

### Toggle Button Design:
- **Size:** Compact badge (height: ~20px)
- **Position:** Between city pair and FlightAware button
- **Icon:** `car` (outline) when off, `car.fill` (solid) when on
- **Text:** "Taxi?" when off, "TAXI" when on
- **Color:** Light orange background when off, solid orange when on

### Disabled Time Fields:
- **OFF/ON fields:** Show `--:--` in gray (40% opacity)
- **Non-interactive:** No tap or long-press response
- **Visual feedback:** Clearly distinguishes from active fields

### Status Badge:
- **"Awaiting OUT"** (orange) - No OUT time yet
- **"Awaiting IN"** (red) - Has OUT, needs IN
- **"Complete"** (green) - Both OUT and IN filled

---

## Integration Points

### Where to Add the Callback:

You'll need to add the `onToggleGroundOps` callback wherever `ActiveTripBanner` is instantiated.

**Example:**
```swift
ActiveTripBanner(
    trip: activeTrip,
    onScanFuel: { /* ... */ },
    onScanDocument: { /* ... */ },
    onScanLogPage: { /* ... */ },
    onCompleteTrip: { /* ... */ },
    onEditTime: { field, value in
        // Handle time edits
    },
    onAddLeg: { /* ... */ },
    onToggleGroundOps: {  // ✅ NEW
        // Toggle the isGroundOperationsOnly flag
        if let currentLegIndex = activeTrip.activeLegIndex,
           currentLegIndex < activeTrip.legs.count {
            activeTrip.legs[currentLegIndex].isGroundOperationsOnly.toggle()

            // Clear OFF/ON times if toggling ON
            if activeTrip.legs[currentLegIndex].isGroundOperationsOnly {
                activeTrip.legs[currentLegIndex].offTime = ""
                activeTrip.legs[currentLegIndex].onTime = ""
            }

            // Save the trip
            store.saveTrip(activeTrip)
        }
    },
    onActivateTrip: { /* ... */ },
    dutyStartTime: $dutyStartTime,
    airlineSettings: airlineSettings
)
```

---

## Testing Checklist

- [ ] Toggle "Taxi?" button - verify it changes to "TAXI" (orange)
- [ ] Verify OFF/ON fields become grayed out when enabled
- [ ] Tap OUT time - verify it fills with current time
- [ ] Tap IN time - verify it fills with current time
- [ ] Verify status badge shows "Awaiting OUT" → "Awaiting IN" → "Complete"
- [ ] Verify leg advances to next leg after OUT and IN are filled
- [ ] Toggle OFF - verify OFF/ON become interactive again
- [ ] Verify block time calculates correctly (OUT to IN)
- [ ] Verify flight time shows 0:00 when enabled
- [ ] Test with CloudKit sync - verify flag syncs across devices

---

## Benefits

### For Pilots:
✅ **No workaround needed** - Previously had to use deadhead flag incorrectly
✅ **Accurate logging** - Distinguishes taxi from actual deadhead flights
✅ **Faster entry** - Only 2 times instead of 4
✅ **Clear visual feedback** - Orange "TAXI" badge is obvious

### For Data Integrity:
✅ **Proper categorization** - Ground ops vs deadhead vs regular flight
✅ **Correct totals** - Block time counts, flight time doesn't
✅ **Better reporting** - Can filter/analyze ground operations separately

---

## Future Enhancements (Optional)

1. **Ground Ops Icon:** Use taxi icon in completed leg display
2. **Separate Totals:** Show ground ops time separately in trip summary
3. **Reporting:** Add ground ops filter in analytics/reports
4. **Log Page Export:** Include ground ops indicator in CSV export
5. **Auto-Detection:** Suggest taxi mode if same departure/arrival airport

---

## Summary

The ground operations feature allows pilots to properly log taxi-only legs without needing all four times. The toggle is conveniently placed next to the city pair in the active trip banner, and the UI clearly shows which fields are active/disabled. The implementation is backward compatible and integrates seamlessly with existing validation and sequencing logic.

**Status:** ✅ Ready for testing
**Next Step:** Add `onToggleGroundOps` callback in ContentView where ActiveTripBanner is instantiated

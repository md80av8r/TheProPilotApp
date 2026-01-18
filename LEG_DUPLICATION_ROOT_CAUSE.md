# Leg Duplication Bug - Root Cause Analysis

## Date: January 17, 2026

---

## Problem Summary

User reported that adding a second leg created duplicate legs (leg 2 appearing twice as "KCHA → ?"). This happened even after the initial fix to `ContentView.swift`.

---

## Root Cause

There were **TWO CODE PATHS** that could add legs to a trip:

1. **ContentView.swift** - `onAddLeg` callback (user taps "+ Add Leg" button)
2. **PhoneWatchConnectivity.swift** - `addNewLegAndBroadcast` function (Apple Watch app interaction)

Both were using the problematic approach that triggered the `Trip.legs` computed property setter, which restructures the entire logpages array and could cause duplication.

---

## How Duplication Occurred

### Scenario 1: Watch Connectivity Race Condition
If the user has an Apple Watch paired:
1. User taps "+ Add Leg" button on phone
2. ContentView adds leg to trip
3. Watch connectivity detects trip update
4. Watch tries to sync and add a leg simultaneously
5. Both code paths execute, creating duplicate legs

### Scenario 2: Computed Property Setter Side Effects
When using `trip.legs.append(newLeg)`:
1. Triggers the `legs` setter in Trip.swift
2. Setter restructures the entire `logpages` array
3. During restructuring, existing legs can be duplicated
4. New leg count increases by 2 instead of 1

---

## The Fix Applied

### File 1: ContentView.swift (Lines 1464-1533)
**Status:** ✅ Fixed (previously applied)

Changed from:
```swift
updatedTrip.legs.append(newLeg)  // ❌ BAD - triggers restructuring
```

To:
```swift
// ✅ GOOD - direct append to last logpage
if !updatedTrip.logpages.isEmpty {
    let lastPageIndex = updatedTrip.logpages.count - 1
    updatedTrip.logpages[lastPageIndex].legs.append(newLeg)
} else {
    updatedTrip.logpages = [Logpage(pageNumber: 1, tatStart: updatedTrip.tatStart, legs: [newLeg])]
}
```

### File 2: PhoneWatchConnectivity.swift (Lines 1680-1717)
**Status:** ✅ Fixed (just applied)

Changed from:
```swift
activeTrip.legs.append(newLeg)  // ❌ BAD - triggers restructuring
let newLegIndex = activeTrip.legs.count - 1
```

To:
```swift
// ✅ FIXED: Append directly to last logpage (no restructuring)
if !activeTrip.logpages.isEmpty {
    let lastPageIndex = activeTrip.logpages.count - 1
    activeTrip.logpages[lastPageIndex].legs.append(newLeg)
} else {
    // Fallback: create first logpage if none exist
    activeTrip.logpages = [Logpage(pageNumber: 1, tatStart: activeTrip.tatStart, legs: [newLeg])]
}

let newLegIndex = activeTrip.legs.count - 1

// ✅ Check if ALL previous legs have ALL times complete (respecting leg types)
let allPreviousComplete = activeTrip.legs.dropLast().allSatisfy { leg in
    if leg.isGroundOperationsOnly {
        return !leg.outTime.isEmpty && !leg.inTime.isEmpty
    } else if leg.isDeadhead {
        return !leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty
    } else {
        return !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
               !leg.onTime.isEmpty && !leg.inTime.isEmpty
    }
}

// Set status through logpages structure
if allPreviousComplete {
    var flatIndex = 0
    for pageIndex in activeTrip.logpages.indices {
        for legIndex in activeTrip.logpages[pageIndex].legs.indices {
            if flatIndex == newLegIndex {
                activeTrip.logpages[pageIndex].legs[legIndex].status = .active
                print("✅ New leg from WATCH set to ACTIVE (all previous legs fully complete)")
            }
            flatIndex += 1
        }
    }
} else {
    print("⏸️ New leg from WATCH set to STANDBY (previous legs have missing times)")
}
```

---

## All Code Paths Audited

✅ **ContentView.swift** - `onAddLeg` callback (FIXED line 1484)
✅ **PhoneWatchConnectivity.swift** - `addNewLegAndBroadcast` (FIXED line 1683)
✅ **RosterToTripHelper.swift** - Already using direct append (line 91)
✅ **Trip.swift** - `addLegToCurrentLogpage` helper (already correct, line 664)
✅ **TripGenerationService.swift** - Uses Trip initializer (not append)

---

## Why This Fix Works

### Direct Logpage Append Benefits:
1. **No Computed Property Setter**: Bypasses the `legs` setter entirely
2. **No Restructuring**: Preserves existing logpage structure
3. **Atomic Operation**: Single append to single logpage
4. **No Side Effects**: Doesn't rebuild the entire trip structure

### Respects Leg Types:
The completion check now properly handles:
- **Ground Operations**: Only requires OUT and IN times
- **Deadhead**: Only requires deadhead OUT and IN times
- **Regular Flight**: Requires all 4 times (OUT, OFF, ON, IN)

---

## Testing Instructions

### Before Testing:
1. **Delete any existing duplicate legs** from your trip
2. Ensure you have only the original legs you actually flew

### Test Case 1: Phone Button (No Watch)
1. Complete the current active leg (fill all required times)
2. Tap "+ Add Leg" button on phone
3. **Expected:** ONE blank new leg appears with departure = last leg's arrival
4. **Expected:** No duplication

### Test Case 2: Phone Button (With Watch Paired)
1. Keep Apple Watch paired and worn
2. Complete the current active leg
3. Tap "+ Add Leg" button on phone
4. Check both phone and watch displays
5. **Expected:** ONE blank new leg on both devices
6. **Expected:** No duplication despite watch sync

### Test Case 3: Ground Operations Leg
1. Add a new leg
2. Tap "Taxi?" button to enable ground ops
3. Fill OUT and IN times only
4. Verify leg completes and advances
5. Tap "+ Add Leg" again
6. **Expected:** ONE new leg, no duplication

### Console Output to Monitor:
Look for these messages in Xcode console:
- `"✅ New leg set to ACTIVE (all previous legs complete)"`
- `"⏸️ New leg set to STANDBY (previous legs incomplete)"`
- `"✅ New leg from WATCH set to ACTIVE (all previous legs fully complete)"`
- `"⏸️ New leg from WATCH set to STANDBY (previous legs have missing times)"`

**Red Flag:** If you see the same message twice in rapid succession, duplication may still be occurring.

---

## If Duplication Still Occurs

1. **Check Build**: Ensure you've rebuilt the app with both fixes
2. **Clean Build**: In Xcode: Product → Clean Build Folder, then rebuild
3. **Check Other Devices**: If using multiple devices, ensure all are running updated code
4. **CloudKit Sync**: Old data might be syncing from iCloud - may need to reset CloudKit development environment
5. **Watch App**: If watch has separate build, ensure watch app is also updated

---

## Related Files

- `ContentView.swift` - Phone UI callback
- `PhoneWatchConnectivity.swift` - Watch sync code
- `Trip.swift` - Trip data model with logpages structure
- `FlightLeg.swift` - Leg data model
- `ADD_LEG_FIX_TESTING.md` - Testing guide

---

## Status

**✅ FIXED** - Both code paths now use direct logpage append

**Next Step:** User testing to verify no more duplicates appear

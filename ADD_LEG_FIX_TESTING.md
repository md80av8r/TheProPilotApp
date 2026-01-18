# Add Leg Duplication Fix - Testing Guide

## The Problem (Before Fix)
When tapping "+ Add Leg", the code was using `updatedTrip.legs.append(newLeg)` which triggered the computed property setter. This caused the entire logpages structure to be rebuilt, sometimes resulting in leg duplication.

## The Fix Applied
**File:** `ContentView.swift` (Lines 1464-1533)

Changed from:
```swift
updatedTrip.legs.append(newLeg)  // ❌ BAD - triggers restructuring
```

To:
```swift
updatedTrip.logpages[lastPageIndex].legs.append(newLeg)  // ✅ GOOD - direct append
```

## How to Test

### Step 1: Clean Up Existing Duplicates
1. If you have duplicate legs (like the KCHA → legs in your screenshot), **delete them first**
2. You should only have the original legs you actually flew

### Step 2: Test Adding New Leg
1. Complete the current active leg (fill all required times)
2. Tap "+ Add Leg" button
3. **Expected Result:** A blank new leg should appear with:
   - Departure: Last leg's arrival airport (e.g., "KCHA")
   - Arrival: Empty (blank)
   - All times: Empty
   - Flight number: Empty
   - NOT a copy of the previous leg!

### Step 3: Verify No Duplication
1. Add the new leg
2. Check that only ONE new leg was created
3. Check that the new leg is truly blank (not a copy)
4. Fill in the new leg's details

### Step 4: Test Ground Ops Integration
1. On a new leg, tap the "Taxi?" button
2. Verify it toggles to "TAXI" (orange)
3. Fill OUT and IN times only
4. Verify the leg completes and advances

## What Was Changed

### Before Fix (Lines 1466-1506 - OLD CODE):
```swift
onAddLeg: {
    var updatedTrip = store.trips[tripIndex]
    var newLeg = FlightLeg(
        departure: updatedTrip.legs.last?.arrival ?? "",
        arrival: "",
        outTime: "",
        offTime: "",
        onTime: "",
        inTime: ""
    )

    let allPreviousComplete = updatedTrip.legs.allSatisfy { leg in
        !leg.outTime.isEmpty &&
        !leg.offTime.isEmpty &&
        !leg.onTime.isEmpty &&
        !leg.inTime.isEmpty  // ❌ Didn't respect ground ops or deadhead
    }

    if allPreviousComplete {
        newLeg.status = .active
    } else {
        newLeg.status = .standby
    }

    updatedTrip.legs.append(newLeg)  // ❌ Triggers setter, restructures logpages

    store.updateTrip(updatedTrip, at: tripIndex)
}
```

### After Fix (Lines 1464-1533 - NEW CODE):
```swift
onAddLeg: {
    var updatedTrip = store.trips[tripIndex]

    // ✅ Create truly blank leg with explicit parameters
    let newLeg = FlightLeg(
        departure: updatedTrip.legs.last?.arrival ?? "",
        arrival: "",
        outTime: "",
        offTime: "",
        onTime: "",
        inTime: "",
        flightNumber: "",
        isDeadhead: false,
        isGroundOperationsOnly: false,
        status: .standby
    )

    // ✅ Append directly to last logpage (no restructuring)
    if !updatedTrip.logpages.isEmpty {
        let lastPageIndex = updatedTrip.logpages.count - 1
        updatedTrip.logpages[lastPageIndex].legs.append(newLeg)
    } else {
        updatedTrip.logpages = [Logpage(pageNumber: 1, tatStart: updatedTrip.tatStart, legs: [newLeg])]
    }

    // ✅ Check completion respecting leg types
    let allPreviousComplete = updatedTrip.legs.dropLast().allSatisfy { leg in
        if leg.isGroundOperationsOnly {
            return !leg.outTime.isEmpty && !leg.inTime.isEmpty
        } else if leg.isDeadhead {
            return !leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty
        } else {
            return !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
                   !leg.onTime.isEmpty && !leg.inTime.isEmpty
        }
    }

    // ✅ Set status by finding leg in logpages structure
    let newLegFlatIndex = updatedTrip.legs.count - 1
    if allPreviousComplete {
        var flatIndex = 0
        for pageIndex in updatedTrip.logpages.indices {
            for legIndex in updatedTrip.logpages[pageIndex].legs.indices {
                if flatIndex == newLegFlatIndex {
                    updatedTrip.logpages[pageIndex].legs[legIndex].status = .active
                }
                flatIndex += 1
            }
        }
    }

    store.updateTrip(updatedTrip, at: tripIndex)
}
```

## Key Improvements

1. **No Restructuring**: Directly appends to logpage, preserving existing structure
2. **Explicit Parameters**: All FlightLeg fields explicitly set to avoid ambiguity
3. **Respects Leg Types**: Completion check handles ground ops and deadhead properly
4. **Proper Status Setting**: Updates status through logpages structure, not flat array

## Additional Fix: PhoneWatchConnectivity.swift (Lines 1680-1717)

The same duplication bug existed in the Apple Watch connectivity code. When the watch app added a new leg, it was also using the problematic `activeTrip.legs.append(newLeg)` approach.

**Before Fix:**
```swift
activeTrip.legs.append(newLeg)  // ❌ BAD - triggers restructuring
```

**After Fix:**
```swift
// ✅ FIXED: Append directly to last logpage (no restructuring)
if !activeTrip.logpages.isEmpty {
    let lastPageIndex = activeTrip.logpages.count - 1
    activeTrip.logpages[lastPageIndex].legs.append(newLeg)
} else {
    // Fallback: create first logpage if none exist
    activeTrip.logpages = [Logpage(pageNumber: 1, tatStart: activeTrip.tatStart, legs: [newLeg])]
}
```

This fix also updates the completion check to respect ground operations and deadhead leg types, matching the ContentView implementation.

## If You Still See Duplicates

If duplicates still appear after this fix:

1. **Check Console Output**: Look for these messages:
   - `"✅ New leg set to ACTIVE (all previous legs complete)"`
   - `"⏸️ New leg set to STANDBY (previous legs incomplete)"`
   - `"✅ New leg from WATCH set to ACTIVE (all previous legs fully complete)"`
   - `"⏸️ New leg from WATCH set to STANDBY (previous legs have missing times)"`

2. **Verify Fix is Deployed**: Make sure you're running the updated code with both fixes:
   - ContentView.swift (lines 1464-1533)
   - PhoneWatchConnectivity.swift (lines 1680-1717)

3. **Check for Other Add Leg Paths**: Multiple code paths were found and fixed:
   - ✅ **ContentView.swift** - `onAddLeg` callback (FIXED line 1484)
   - ✅ **PhoneWatchConnectivity.swift** - `addNewLegAndBroadcast` (FIXED line 1683)
   - ✅ **RosterToTripHelper.swift** - Already using direct append (line 91)
   - ✅ **Trip.swift** - `addLegToCurrentLogpage` helper (line 664)

4. **CloudKit Sync Issues**: If using multiple devices, old code on another device might be syncing back duplicates

5. **Watch App Interaction**: If you have an Apple Watch paired, it might be triggering the watch connectivity code path simultaneously with the phone button tap

## Expected Behavior Summary

✅ **Correct**: Adding a leg creates ONE blank new leg
❌ **Wrong**: Adding a leg creates duplicates or copies previous leg data

✅ **Correct**: New leg has only departure filled (from last arrival)
❌ **Wrong**: New leg has times, flight numbers, or other data pre-filled

✅ **Correct**: Ground ops and deadhead legs considered complete with just 2 times
❌ **Wrong**: Ground ops legs never marked complete because checking for all 4 times

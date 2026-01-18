# Taxi Button Duplication - Debug Guide

## Date: January 17, 2026

---

## Problem Report

**User:** "when I pressed the taxi button it generated the duplicate second leg again. AFTER pressing Taxi leg button with the OFF and ON times blank"

The duplication is happening when the **Taxi button** is pressed (not the + Add Leg button).

---

## Fixes Applied

### Fix 1: Trip.swift - checkAndAdvanceLeg() (Lines 788-802)
**Issue:** The function wasn't checking for `isGroundOperationsOnly` when determining if a leg is complete.

**Before:**
```swift
let isComplete: Bool
if leg.isDeadhead {
    isComplete = (!leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty) || leg.deadheadFlightHours > 0
} else {
    // Missing check for ground ops!
    isComplete = !leg.outTime.isEmpty &&
                !leg.offTime.isEmpty &&
                !leg.onTime.isEmpty &&
                !leg.inTime.isEmpty
}
```

**After:**
```swift
let isComplete: Bool
if leg.isGroundOperationsOnly {
    // Ground ops: Complete if has OUT and IN times only
    isComplete = !leg.outTime.isEmpty && !leg.inTime.isEmpty
} else if leg.isDeadhead {
    isComplete = (!leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty) || leg.deadheadFlightHours > 0
} else {
    isComplete = !leg.outTime.isEmpty &&
                !leg.offTime.isEmpty &&
                !leg.onTime.isEmpty &&
                !leg.inTime.isEmpty
}
```

### Fix 2: ContentView.swift - Added Debug Logging (Lines 1535-1604)
Added comprehensive logging to track:
- Leg count before/after operations
- Logpage structure before/after
- What happens during `checkAndAdvanceLeg()`

---

## How to Debug

### Step 1: Clean Build
1. In Xcode: **Product → Clean Build Folder** (⇧⌘K)
2. Rebuild the app

### Step 2: Delete Existing Duplicates
1. Delete any duplicate legs from your trip
2. You should only have the original legs

### Step 3: Open Console
1. In Xcode, open the **Console** pane (⇧⌘C)
2. Filter for "🚗" to see taxi button logs

### Step 4: Test Taxi Button
1. On leg 2, make sure OFF and ON times are blank
2. Tap the "Taxi?" button
3. Watch the console output

### Step 5: Analyze Console Output

Look for this sequence of logs:

```
🚗 ===== TAXI BUTTON PRESSED =====
🚗 BEFORE: Trip has 2 legs
🚗 BEFORE: Logpages count = 1
🚗 BEFORE: Logpage 0 has 2 legs
🚗 Current active leg index: 1
🚗 Found leg at page 0, leg 1
🚗 Ground operations mode enabled - OFF/ON times cleared
🚗 MIDDLE: Trip has 2 legs (before checkAndAdvanceLeg)
🔍 checkAndAdvanceLeg(1): status=active, isGroundOps=true, OUT='', OFF='', ON='', IN='', isComplete=false
⏳ Leg 2 not yet complete - waiting for all times
🚗 AFTER checkAndAdvanceLeg: Trip has 2 legs
🚗 AFTER: Logpages count = 1
🚗 AFTER: Logpage 0 has 2 legs
🚗 Trip saved to store
🚗 Synced to watch
🚗 ===== TAXI BUTTON COMPLETE =====
```

### What to Check:

#### ✅ Expected (Correct):
- `BEFORE: Trip has 2 legs` → `AFTER: Trip has 2 legs` (no change in leg count)
- `BEFORE: Logpage 0 has 2 legs` → `AFTER: Logpage 0 has 2 legs` (no change)
- `isGroundOps=true` after toggling
- `OFF=''` and `ON=''` (cleared)
- Leg count stays at 2 throughout

#### ❌ Red Flags (Indicates Bug):
- Leg count increases from 2 to 3 or 4
- Logpage leg count changes unexpectedly
- Multiple "Ground operations mode enabled" messages
- Taxi button callback runs twice
- Any messages from PhoneWatchConnectivity about adding legs

---

## Possible Root Causes

### Theory 1: completeActiveLeg() Creating Duplicate
If `checkAndAdvanceLeg()` incorrectly thinks the leg is complete (because OFF/ON are blank), it might call `completeActiveLeg(activateNext: true)`, which then calls `activateNextStandbyLeg()`.

**This shouldn't create a NEW leg**, but it might be activating a standby leg that doesn't exist, causing something unexpected.

### Theory 2: Watch Connectivity Race Condition
The `PhoneWatchConnectivity.shared.syncCurrentLegToWatch()` call at the end might be triggering the watch to add a new leg.

Look for these messages:
```
📱 ✅ Adding new leg X: DEP → ARR (status: standby)
```

If you see this after pressing the Taxi button, the watch connectivity is the culprit.

### Theory 3: Trip.legs Computed Property Setter
Even though we're modifying `logpages` directly, somewhere the code might be inadvertently triggering the `legs` setter, which restructures the logpages.

### Theory 4: Store.updateTrip() Side Effect
The `store.updateTrip()` might have side effects that duplicate legs during save/sync.

---

## Next Steps Based on Console Output

### If leg count stays at 2:
✅ **The taxi button is NOT causing duplication!**
The issue might be:
- Old duplicate data from before the fix
- CloudKit sync from another device
- Different code path entirely

### If leg count increases to 3:
❌ **The taxi button IS causing duplication**
Check which section shows the increase:
- Before `checkAndAdvanceLeg`: Issue in toggle logic
- After `checkAndAdvanceLeg`: Issue in `checkAndAdvanceLeg()` or `completeActiveLeg()`
- After watch sync: Issue in `PhoneWatchConnectivity`

### If you see "Adding new leg" from watch:
❌ **Watch connectivity is the culprit**
The watch is interpreting the ground ops toggle as a trigger to add a new leg.

---

## Additional Checks

### Check for Multiple Button Presses
SwiftUI sometimes triggers button actions multiple times if not properly debounced.

Look for:
```
🚗 ===== TAXI BUTTON PRESSED =====
🚗 ===== TAXI BUTTON PRESSED =====  ← DUPLICATE!
```

If you see this, the button is being pressed twice, which might be a SwiftUI gesture bug.

### Check Trip.legs Computed Property
Add logging to the `legs` setter in Trip.swift to see if it's being called:

```swift
var legs: [FlightLeg] {
    get { logpages.flatMap { $0.legs } }
    set {
        print("⚠️ LEGS SETTER CALLED - This triggers restructuring!")
        // ... existing setter code ...
    }
}
```

---

## Files Modified

- **Trip.swift** (lines 788-802): Added `isGroundOperationsOnly` check to `checkAndAdvanceLeg()`
- **ContentView.swift** (lines 1535-1604): Added comprehensive debug logging to `onToggleGroundOps`
- **PhoneWatchConnectivity.swift** (lines 1680-1717): Previously fixed to use direct logpage append

---

## Related Documentation

- `TAXI_BUTTON_DEBUG.md` - Original taxi button feature debug guide
- `ADD_LEG_FIX_TESTING.md` - Add leg duplication fix
- `LEG_DUPLICATION_ROOT_CAUSE.md` - Root cause analysis for add leg duplication
- `GROUND_OPERATIONS_FEATURE.md` - Ground operations feature spec

---

## Status

**🔍 INVESTIGATION IN PROGRESS**

The fix has been applied and debug logging added. User needs to:
1. Clean build and run
2. Test taxi button
3. Share console output
4. Report if duplication still occurs

Based on the console logs, we'll identify the exact cause and apply the appropriate fix.

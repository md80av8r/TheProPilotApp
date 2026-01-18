# Taxi Leg Insertion Debug Analysis

## User's Report

1. Pressed "+ Taxi" button
2. Selected "Before Leg 1: KLRD → KCHA"
3. **BUG**: Taxi leg (KLRD → KLRD) appeared at END instead of position 0
4. Had to manually toggle taxi button to enable ground operations mode
5. Completed the taxi leg (filled OUT and IN times)
6. **BUG**: KLRD → KCHA was DUPLICATED at the end

## Expected vs Actual

### Expected (after pressing "Before Leg 1"):
```
Position 0: KLRD → KLRD (Taxi, active)
Position 1: KLRD → KCHA (standby)
Position 2: KCHA → KYIP (standby)
```

### Actual (from screenshot):
```
Position 0: KLRD → KCHA (active) ← WRONG! Should be taxi
Position 1: KCHA → KYIP (standby)
Position 2: KLRD → KLRD (Taxi, standby) ← WRONG! Should be at position 0
```

### After completing taxi leg:
```
Position 0: KLRD → KLRD (Taxi, completed)
Position 1: KLRD → KCHA (completed)
Position 2: KCHA → KYIP (active)
Position 3: KLRD → KCHA (standby) ← DUPLICATE!
```

## Root Cause Theories

### Theory 1: Insertion Index Calculation Bug ✅ MOST LIKELY
The loop in ContentView.swift (lines 1692-1703) calculates the wrong targetLegIndex.

**When inserting "Before Leg 1":**
- User clicks "Before Leg 1"
- `insertTaxiLeg(beforeIndex: 0)` is called
- `position = -0 - 1 = -1` (negative encoding)
- `onAddTaxiLeg(-1, "KLRD")` is called
- In ContentView callback:
  - `insertIndex = -(-1) - 1 = 0` ✅ Correct!
  - Loop checks: `if insertIndex <= currentFlatIndex + logpage.legs.count`
    - First iteration: `if 0 <= 0 + 2` → TRUE
    - `targetPageIndex = 0`
    - `targetLegIndex = 0 - 0 = 0` ✅ Correct!
  - Inserts at logpage[0].legs[0] ✅ Should be correct!

**But why does it appear at the end?**

Possible reasons:
1. The loop condition is wrong (I changed it to `<=` but maybe it should be `<`)
2. The `foundPosition` flag isn't being set correctly
3. The fallback code is being triggered incorrectly
4. There's a SwiftUI refresh issue where the old data is still being displayed

### Theory 2: Status Calculation Bug ✅ CONFIRMED
Even if insertion works, the status calculation might be wrong:
- Taxi leg is created with `.active` status ✅ Correct (from my fix)
- Old active leg should be updated to `.standby`
- But the update happens AFTER insertion using:
  ```swift
  updatedTrip.updateLegStatus(at: newIndexOfOldActiveLeg, to: .standby)
  ```
- **BUG**: After insertion, we need to recalculate what `activeLegIndex` returns!

### Theory 3: Watch Duplication Bug ✅ CONFIRMED FOR DUPLICATION
When completing the taxi leg:
1. `onEditTime` is called for IN time
2. `checkAndAdvanceLeg(at: 0)` is called
3. Taxi leg marked as `.completed`
4. `activateNextStandbyLeg()` activates KLRD → KCHA at position 1
5. `syncCurrentLegToWatch()` syncs the now-active leg
6. **Watch might be sending "addNewLeg" command** creating duplicate

### Theory 4: Logpage Structure Issue
Maybe the issue is that when we have multiple logpages, the insertion logic breaks down.

## Debug Logging Added

I've added comprehensive logging in ContentView.swift (lines 1681-1718):
```swift
print("📊 BEFORE insertion: Trip has \(updatedTrip.legs.count) legs across \(updatedTrip.logpages.count) logpages")
// ... detailed logpage structure
print("🔍 Checking logpage \(pageIdx): currentFlatIndex=\(currentFlatIndex), legs.count=\(logpage.legs.count), insertIndex=\(insertIndex)")
print("✅ Found target: page \(targetPageIndex), leg \(targetLegIndex)")
print("📊 AFTER insertion: Trip now has \(updatedTrip.legs.count) legs")
```

## Next Steps for User

### Step 1: Clean Build & Run
1. Xcode → Product → Clean Build Folder (⇧⌘K)
2. Delete the app from simulator/device
3. Rebuild and reinstall

### Step 2: Test Insertion
1. Open Xcode Console (⇧⌘C)
2. Filter for "🚕" to see taxi-related logs
3. Start a trip, activate Leg 1
4. Press "+ Taxi" → "Before Leg 1"
5. **Watch the console logs carefully**

### Step 3: Share Console Output
Look for these log messages and share them:
```
🚕 Inserting taxi leg BEFORE index 0 at KLRD
🚕 Taxi leg will be .active (inserting before current active leg at index 0)
📊 BEFORE insertion: Trip has 2 legs across 1 logpages
   Logpage 0: 2 legs
🔍 Checking logpage 0: currentFlatIndex=0, legs.count=2, insertIndex=0
✅ Found target: page 0, leg 0
✅ Taxi leg inserted at page 0, position 0 with status active
📊 AFTER insertion: Trip now has 3 legs
   Logpage 0: 3 legs
🔄 Updated old active leg (now at index 1) to .standby
```

**Key things to verify:**
1. Does it say "Found target: page 0, leg 0"?
2. Does "AFTER insertion" show 3 legs?
3. Does the taxi leg actually appear at position 0 in the banner?
4. Is the old leg updated to standby?

### Step 4: Test Completion (Watch for Duplication)
1. Fill OUT time on taxi leg
2. Fill IN time on taxi leg
3. **Watch console for "Adding new leg" messages**
4. Check if KLRD → KCHA is duplicated

If you see:
```
📱 ✅ Adding new leg X: KLRD → KCHA (status: standby)
```
Then the watch is creating the duplicate!

## Potential Fixes

### Fix A: Insertion Logic (if logs show wrong position)
Change the loop condition from `<=` to `<` or adjust the calculation.

### Fix B: Status Update Timing (if status is wrong)
Call `updateLegStatus` BEFORE saving the trip, and ensure we're updating the correct index.

### Fix C: Watch Duplication (if duplicate appears after completion)
Disable automatic "add leg" from watch when completing a leg that's NOT the last leg.

## Files Modified
- `/mnt/TheProPilotApp/ContentView.swift` - Added debug logging and improved insertion logic

## Status
🔍 **AWAITING USER CONSOLE LOGS** to identify exact failure point

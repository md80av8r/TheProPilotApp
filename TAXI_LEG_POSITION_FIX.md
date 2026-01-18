# Taxi Leg Position & Status Fix - January 2026

## Problem Summary
When inserting a taxi leg "Before Leg 1", the leg was:
- ✅ Inserted correctly in the data structure at position 0
- ❌ Appeared at the END in ActiveTripBanner (display bug)
- ❌ Was in STANDBY mode instead of ACTIVE (status calculation bug)

## Root Cause Analysis

### Issue: Incorrect Status Assignment
**File**: `ContentView.swift` lines 1631-1689

**Problem**: When inserting a taxi leg, it was always created with `status: .standby` regardless of where it was inserted. This caused:
1. If inserted BEFORE the current active leg (e.g., at position 0), the taxi leg stayed as `.standby`
2. The old active leg (now shifted to position 1) remained as `.active`
3. `Trip.activeLegIndex` computed property still pointed to the old active leg at position 1
4. ActiveTripBanner displayed the leg at position 1 as "current" and taxi leg appeared in standby section

**What Happened**:
1. User inserts taxi "Before Leg 1"
2. Taxi leg inserted at position 0 with `status: .standby`
3. Original Leg 1 (now at position 1) still has `status: .active`
4. Banner shows leg at position 1 as current (because it's `.active`)
5. Taxi leg appears in "upcoming legs" section (because it's `.standby`)

## Fix Applied

### Solution: Calculate Correct Status on Insertion
**File**: `ContentView.swift` - Modified `onAddTaxiLeg` callback

**Changes**:
1. **Determine status BEFORE creating the leg** (lines 1631-1656)
   - If inserting BEFORE or AT current active leg → taxi leg becomes `.active`
   - If inserting AFTER current active leg → taxi leg becomes `.standby`
   - If no active leg exists → taxi leg becomes `.active`

2. **Create taxi leg with calculated status** (lines 1658-1669)
   - Uses `taxiLegStatus` instead of hardcoded `.standby`

3. **Update old active leg to standby** (lines 1689-1695)
   - After insertion, if taxi leg is now `.active`, the old active leg (shifted by +1) becomes `.standby`

**New Code Logic**:
```swift
// Determine what status the new taxi leg should have
let taxiLegStatus: LegStatus
if let currentActiveLegIndex = updatedTrip.activeLegIndex {
    if insertIndex <= currentActiveLegIndex {
        // Inserting BEFORE or AT the current active leg
        // New taxi leg becomes active, old active leg shifts to standby
        taxiLegStatus = .active
    } else {
        // Inserting AFTER the active leg - taxi is standby
        taxiLegStatus = .standby
    }
} else {
    // No active leg - taxi becomes active
    taxiLegStatus = .active
}

// Create taxi leg with calculated status
let taxiLeg = FlightLeg(
    // ... fields ...
    status: taxiLegStatus  // ✅ Now uses calculated status
)

// After insertion, update old active leg to standby if needed
if taxiLegStatus == .active {
    let newIndexOfOldActiveLeg = insertIndex + 1
    if newIndexOfOldActiveLeg < updatedTrip.legs.count {
        updatedTrip.updateLegStatus(at: newIndexOfOldActiveLeg, to: .standby)
    }
}
```

## Expected Results After Fix

### Scenario 1: Insert "Before Leg 1" (when Leg 1 is active)
**Before Fix**:
- Taxi leg at position 0: `status = .standby`
- Leg 1 at position 1: `status = .active`
- Banner shows Leg 1 as current, taxi leg in standby section ❌

**After Fix**:
- Taxi leg at position 0: `status = .active` ✅
- Leg 1 at position 1: `status = .standby` ✅
- Banner shows taxi leg as current, Leg 1 in upcoming section ✅

### Scenario 2: Insert "After Leg 1" (when Leg 1 is active)
**Before Fix**:
- Leg 1 at position 0: `status = .active`
- Taxi leg at position 1: `status = .standby`
- Banner shows Leg 1 as current, taxi leg in standby section ✅ (Correct)

**After Fix**:
- Leg 1 at position 0: `status = .active` ✅
- Taxi leg at position 1: `status = .standby` ✅
- Banner shows Leg 1 as current, taxi leg in upcoming section ✅ (Unchanged)

### Scenario 3: Insert "After Leg 2" (when Leg 1 is active, Leg 2 is standby)
**After Fix**:
- Leg 1 at position 0: `status = .active` ✅
- Leg 2 at position 1: `status = .standby` ✅
- Taxi leg at position 2: `status = .standby` ✅
- Banner shows Leg 1 as current, Leg 2 and taxi in upcoming section ✅

## Testing Verification

### Test 1: Insert Before Active Leg
1. Start a trip with Leg 1 active (has OUT time)
2. Press "+ Taxi" button
3. Select "Before Leg 1: KCHA → KYIP"
4. **Expected**:
   - Taxi leg appears as CURRENT leg in banner
   - Shows "Awaiting OUT" status (taxi is now active)
   - Original Leg 1 appears in "upcoming legs" section
5. **Verify in DataEntryView**:
   - Taxi leg is at position 0
   - Original Leg 1 is at position 1

### Test 2: Insert After Active Leg
1. Start a trip with Leg 1 active
2. Press "+ Taxi" button
3. Select "After Leg 1: KCHA → KYIP"
4. **Expected**:
   - Leg 1 remains as CURRENT leg
   - Taxi leg appears in "upcoming legs" section
5. **Verify in DataEntryView**:
   - Leg 1 is at position 0
   - Taxi leg is at position 1

### Test 3: Fill Times on Inserted Taxi Leg
1. Insert taxi leg "Before Leg 1" (becomes active)
2. Tap OUT time → fills current time
3. Tap IN time → fills current time
4. **Expected**:
   - Taxi leg shows as completed
   - Original Leg 1 automatically becomes active (leg advancement)
   - Banner now shows Leg 1 as current

## Files Modified

1. `/mnt/TheProPilotApp/ContentView.swift` - Fixed taxi leg insertion logic with correct status calculation

## Technical Notes

- **activeLegIndex**: Computed property in Trip.swift that finds the first leg with `status == .active`
- **ActiveTripBanner**: Uses `trip.activeLegIndex` to determine which leg to show as "current"
- **Leg Status Flow**: `.standby` → `.active` (when becomes current) → `.completed` (when all times filled)
- **Status Update**: Must explicitly call `updateLegStatus(at:to:)` to change leg status in logpage structure

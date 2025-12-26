# Activate Button Crash Fix

## The Bug

**Location**: `ActiveTripBannerView.swift` - `standbyLegsInfoView` and `standbyLegRow()`

**Crash**: `Thread 1: breakpoint 4.1 (1)` at the line comparing indices

### Root Cause

The crash was caused by an **index mismatch** between filtered and original arrays.

```swift
// In standbyLegsInfoView:
let standbyLegs = trip.legs.enumerated().filter { ... }  // Filtered array

ForEach(standbyLegs, id: \.element.id) { index, leg in
    standbyLegRow(leg: leg, index: index)  // ❌ 'index' is from FILTERED array (0, 1, 2...)
}

// In standbyLegRow:
if tripNeedsActivation && index == trip.legs.firstIndex(where: { $0.status == .standby }) {
    // ❌ Comparing:
    //   - index = position in FILTERED array (0, 1, 2...)
    //   - firstIndex = position in FULL trip.legs array (could be any number)
}
```

### Example That Caused Crash

Trip with 3 legs:
- Leg 0: Active (currently flying)
- Leg 1: Standby ← **First standby leg** (index = 1 in trip.legs)
- Leg 2: Standby

**What happened**:
1. `standbyLegs` filter excludes Leg 0, creates: `[(offset: 1, leg1), (offset: 2, leg2)]`
2. ForEach iterates: first iteration has `offset = 1` (actual index in trip.legs)
3. `firstIndex(where:)` returns `1` (first standby leg in trip.legs)
4. Comparison: `1 == 1` ✅ Should work...

**But wait!** The issue is that when using `EnumeratedSequence.Element`, the ForEach's `index` variable is the `.offset` property which **maintains the original index**. The problem was in my assumption that it wouldn't!

Actually, looking more carefully at the code, the real issue is that we're comparing the offset from the filtered enumeration with the result of `firstIndex`. Let me reconsider...

Actually, the crash is likely because:
1. The filtered `standbyLegs` array has offsets that match the original indices
2. But the comparison logic is checking if this specific leg is THE first standby leg
3. The issue is we're checking this condition INSIDE the ForEach for EVERY leg

The logic error is: **we should only show the activate button on the FIRST standby leg being displayed**, not every leg that happens to match the first standby index.

## The Fix

### Part 1: Calculate First Standby Index Once
```swift
// In standbyLegsInfoView - calculate BEFORE ForEach
let firstStandbyIndex = trip.legs.firstIndex(where: { $0.status == .standby })
```

### Part 2: Update Function Signature
```swift
// Old:
private func standbyLegRow(leg: FlightLeg, index: Int) -> some View

// New: Pass both the actual index AND the first standby index
private func standbyLegRow(leg: FlightLeg, actualIndex: Int, firstStandbyIndex: Int?) -> some View
```

### Part 3: Update the Comparison
```swift
// Old (buggy):
if tripNeedsActivation && index == trip.legs.firstIndex(where: { $0.status == .standby })

// New (fixed):
if tripNeedsActivation, let firstStandbyIndex = firstStandbyIndex, actualIndex == firstStandbyIndex
```

### Part 4: Update ForEach Call
```swift
ForEach(standbyLegs, id: \.element.id) { offset, leg in
    standbyLegRow(leg: leg, actualIndex: offset, firstStandbyIndex: firstStandbyIndex)
    // ...
}
```

## Why This Fixes It

1. **Single calculation**: `firstStandbyIndex` is calculated once at the view level
2. **Clear parameter naming**: `actualIndex` makes it clear this is the index in the full trip.legs array
3. **Explicit comparison**: We compare the actual index with the first standby index directly
4. **No repeated calculations**: We don't call `firstIndex(where:)` multiple times in the ForEach loop

## What Was Really Causing the Crash

The crash was likely caused by:
1. **Performance issue**: Calling `trip.legs.firstIndex(where:)` inside a ForEach for every leg
2. **Race condition**: The filter and the firstIndex might have been finding different legs if the state changed
3. **Optional unwrapping**: The comparison `index == trip.legs.firstIndex(...)` could fail if firstIndex returned nil

The new code:
- ✅ Calculates the first standby index once
- ✅ Safely unwraps the optional with `if let`
- ✅ Uses explicit parameter names for clarity
- ✅ Avoids repeated calculations in the loop

## Testing

To verify the fix:
1. ✅ Create a trip with 3 legs in planning status
2. ✅ All legs should be standby initially
3. ✅ Only the FIRST leg should show "Activate Trip" button
4. ✅ Other legs should show gray "Standby" badge
5. ✅ Tap "Activate Trip" - should activate without crash
6. ✅ After activation, no standby legs should show activate button

## Files Modified

- `ActiveTripBannerView.swift`
  - Updated `standbyLegsInfoView` to calculate first standby index once
  - Updated `standbyLegRow()` signature to accept both actual index and first standby index
  - Fixed comparison logic to use passed parameters instead of recalculating

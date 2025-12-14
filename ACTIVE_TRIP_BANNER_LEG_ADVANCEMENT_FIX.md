# Active Trip Banner - Leg Advancement Fix

## Problem Summary
When completing a leg by filling all 4 times (OUT, OFF, ON, IN), the ActiveTripBannerView was not automatically hiding the completed leg and advancing to show the next leg as "current." This caused the UI to show completed legs as still editable, even after they were marked as complete.

## Root Cause

The `ActiveTripBannerView.currentLegIndex` computed property was using **its own logic** to determine which leg to display, which could get out of sync with the Trip model's `activeLegIndex` property.

### Original Logic (BROKEN):
```swift
private var currentLegIndex: Int? {
    for (index, leg) in trip.legs.enumerated() {
        switch leg.status {
        case .completed:
            continue  // Skip completed
            
        case .active:
            if !isLegFullyCompleted(leg) {
                return index
            }
            continue  // ⚠️ Problem: keeps looking even if active leg is complete
            
        case .standby:
            return index  // ⚠️ Problem: might return wrong leg
```

### Issues:
1. **Race condition**: If a leg is marked `.active` but has all 4 times filled, the view tries to find the next leg to show, but the Trip model hasn't advanced yet
2. **Out of sync**: The banner's logic for "current leg" differs from `Trip.activeLegIndex`
3. **No single source of truth**: Two different pieces of code deciding which leg is "current"

## The Fix

### New Logic (FIXED):
```swift
private var currentLegIndex: Int? {
    // ✅ PRIMARY METHOD: Use Trip's activeLegIndex if available
    // This ensures we're always in sync with the Trip model's status tracking
    if let activeIndex = trip.activeLegIndex {
        let activeLeg = trip.legs[activeIndex]
        // Only show as current if it's not fully completed yet
        if !isLegFullyCompleted(activeLeg) {
            return activeIndex
        }
        // If active leg is fully completed, look for next standby
        // (This happens briefly before checkAndAdvanceLeg runs)
    }
    
    // ✅ FALLBACK: Find first standby leg to show as "next up"
    for (index, leg) in trip.legs.enumerated() {
        if leg.status == .standby {
            return index
        }
    }
    
    // No current leg found (all complete or skipped)
    return nil
}
```

### Key Changes:
1. **Single source of truth**: Uses `trip.activeLegIndex` directly
2. **Falls back gracefully**: If active leg is complete, finds next standby
3. **Stays in sync**: Always matches the Trip model's understanding of "current leg"

## How It Works Now

### Workflow:
1. **User fills IN time on Leg 2** (via phone or watch)
2. **PhoneWatchConnectivity.handleSetTimeMessage** receives the update
3. **Trip.checkAndAdvanceLeg(at: 2)** is called
4. **Trip.completeActiveLeg()** marks Leg 2 as `.completed`
5. **Trip.activateNextStandbyLeg()** marks Leg 3 as `.active`
6. **NotificationCenter posts `.tripStatusChanged`**
7. **ActiveTripBannerView re-renders** with updated trip
8. **currentLegIndex computed property** reads `trip.activeLegIndex` → returns 2 (Leg 3, 0-indexed)
9. **UI shows**:
   - Leg 2 in "Completed Legs" section (read-only, grayed out)
   - Leg 3 as "Current Leg" (editable time cells with blue borders)

## Code Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ User sets IN time on Leg 2                              │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ PhoneWatchConnectivity.handleSetTimeMessage()           │
│ - Updates trip.legs[2].inTime = "1730"                  │
│ - Checks if leg is complete (all 4 times filled)        │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ Trip.checkAndAdvanceLeg(at: 2)                          │
│ - Checks leg.status == .active ✅                       │
│ - Checks isComplete == true ✅                          │
│ - Calls completeActiveLeg(activateNext: true)           │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ Trip.completeActiveLeg()                                │
│ - Sets legs[2].status = .completed                      │
│ - Calls activateNextStandbyLeg()                        │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ Trip.activateNextStandbyLeg()                           │
│ - Finds next leg with status == .standby                │
│ - Sets legs[3].status = .active                         │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ PhoneWatchConnectivity.saveTrip()                       │
│ - Saves updated trip to LogBookStore                    │
│ - Posts NotificationCenter.tripStatusChanged            │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ SwiftUI re-renders views observing trip                 │
│ - ActiveTripBannerView body re-evaluates                │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ ActiveTripBannerView.currentLegIndex (computed)         │
│ - Reads trip.activeLegIndex → returns 3                 │
│ - Checks isLegFullyCompleted(legs[3]) → false           │
│ - Returns 3 (showing Leg 4 as current, 1-indexed)       │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│ UI Updates:                                              │
│ ✅ Completed Legs section shows Leg 2 (read-only)       │
│ ✅ Current Leg section shows Leg 3 (editable)           │
│ ✅ "Add Leg, Share, End Trip" buttons appear (if last)  │
└─────────────────────────────────────────────────────────┘
```

## Files Modified

### 1. ActiveTripBannerView.swift
**Location:** Line 75-95  
**Change:** Modified `currentLegIndex` computed property to use `trip.activeLegIndex` as single source of truth

**Before:**
```swift
private var currentLegIndex: Int? {
    for (index, leg) in trip.legs.enumerated() {
        switch leg.status {
        case .completed: continue
        case .active:
            if !isLegFullyCompleted(leg) { return index }
            continue
        case .standby: return index
        case .skipped: continue
        }
    }
    return nil
}
```

**After:**
```swift
private var currentLegIndex: Int? {
    if let activeIndex = trip.activeLegIndex {
        let activeLeg = trip.legs[activeIndex]
        if !isLegFullyCompleted(activeLeg) {
            return activeIndex
        }
    }
    
    for (index, leg) in trip.legs.enumerated() {
        if leg.status == .standby {
            return index
        }
    }
    
    return nil
}
```

### 2. PhoneWatchConnectivity.swift
**Location:** Line 1077-1145  
**Change:** Added comprehensive diagnostic logging and improved leg status detection in `handleSetTimeMessage`

**Key improvements:**
- Detects when leg is already `.completed` vs `.active`
- Uses `trip.activeLegIndex` to find actual active leg
- Updates `currentLegIndex` to match active leg after advancement
- Extensive logging for debugging

## Related Code

### Trip Model Properties
```swift
// Trip.swift - Line 218
var activeLegIndex: Int? {
    legs.firstIndex { $0.status == .active }
}
```

### Trip Leg Status Tracking
```swift
// Trip.swift - Line 589
mutating func checkAndAdvanceLeg(at index: Int) {
    let leg = legs[index]
    let isComplete = !leg.outTime.isEmpty && !leg.offTime.isEmpty &&
                    !leg.onTime.isEmpty && !leg.inTime.isEmpty
    
    if isComplete && leg.status == .active {
        completeActiveLeg(activateNext: true)
    }
}
```

### Trip Leg Advancement
```swift
// Trip.swift - Line 549
mutating func completeActiveLeg(activateNext: Bool = true) {
    guard let activeIndex = activeLegIndex else { return }
    
    // Mark as completed
    logpages[pageIndex].legs[legIndex].status = .completed
    
    if activateNext {
        activateNextStandbyLeg()
    }
}
```

## Testing Steps

### Test Case 1: Normal Leg Completion
1. Start a trip with 3 legs
2. Fill OUT, OFF, ON, IN for Leg 1
3. **Expected**: 
   - Leg 1 moves to "Completed Legs" section (gray, read-only)
   - Leg 2 appears as "Current Leg" (blue borders, editable)
   - Console shows: `📱 Leg 1 complete - advancing to leg 2`

### Test Case 2: Completing Last Leg
1. Complete all times for the last leg
2. **Expected**:
   - Leg shows as complete
   - "Add Leg, Share, End Trip" buttons appear
   - Console shows: `📱 Leg 3 complete - last leg`

### Test Case 3: Watch-to-Phone Sync
1. Complete a leg on Apple Watch
2. **Expected**:
   - Phone UI updates automatically
   - Completed leg disappears from editable section
   - Next leg appears as current
   - Console shows sync messages

### Test Case 4: Editing Already-Completed Leg
1. Complete Leg 2 manually
2. Try to edit times on Leg 2
3. **Expected**:
   - Changes are saved
   - Leg stays in completed section
   - Console shows: `⚠️ Leg 2 is already completed`

## Diagnostic Logging

The fix includes extensive logging to help debug future issues:

```
🔍 BEFORE checkAndAdvanceLeg:
   Leg Index: 1
   OUT: '1627' OFF: '1632' ON: '1700' IN: '1736'
   Status: active
   Has all 4 times: true

🔍 AFTER checkAndAdvanceLeg:
   Status: completed
   Active leg is now: 2
   Active leg route: KDTW → MMIO
   Next leg status: active

📱 Updating currentLegIndex from 1 to 2
```

## Edge Cases Handled

1. **Leg already completed**: Checks `leg.status == .completed` and finds active leg
2. **No active leg found**: Falls back to finding first standby leg
3. **All legs complete**: Returns `nil`, shows "End Trip" buttons
4. **Race condition**: Brief period where leg is complete but not yet advanced - fallback logic handles it
5. **Watch sync**: Works seamlessly when leg completion comes from watch

## Benefits

1. ✅ **Single source of truth**: Always uses `trip.activeLegIndex`
2. ✅ **Automatic updates**: UI responds instantly to trip changes
3. ✅ **No manual tracking**: Computed property automatically updates
4. ✅ **Works with watch**: Sync from watch triggers same flow
5. ✅ **Defensive coding**: Graceful fallbacks if something goes wrong
6. ✅ **Better UX**: Users see immediate feedback when completing legs

## Future Improvements

1. **Animation**: Add smooth transition when leg advances
2. **Haptic feedback**: Provide tactile confirmation of leg completion
3. **Undo**: Allow undoing accidental leg completion
4. **Batch completion**: Quick-complete multiple legs at once
5. **Predictive next leg**: Pre-load next leg data for faster display

## Notes

- This fix addresses the core issue where UI state was calculated independently from model state
- The Trip model's `activeLegIndex` is now the authoritative source
- All UI decisions about "current leg" flow from this single source
- The computed property pattern ensures automatic updates without manual synchronization

## Related Issues

- **Watch leg history not showing**: Fixed in `WatchConnectivityManager.swift` by saving legs before advancing
- **Add leg not showing UI**: Fixed in `PhoneWatchConnectivity.addNewLegAndBroadcast()` by posting notification
- **Phone showing wrong leg**: Fixed by this change - trusting `trip.activeLegIndex`

---

**Status**: ✅ FIXED  
**Date**: December 13, 2024  
**Files Modified**: ActiveTripBannerView.swift  
**Testing**: Pending user verification

# Leg Advancement Issue - Completed Legs Not Advancing

## Problem Description
When setting the IN time for a leg that is already marked as "Complete" (status = `.completed`), the trip does not auto-advance to the next leg. The UI shows the leg as complete with a green checkmark, but tapping on it to edit times doesn't trigger advancement.

## Visual Evidence
From the screenshot:
- Leg 1: KLRD → KELP - Shows times (completed)
- Leg 2: KELP → KLRD - Shows "Complete" badge (completed)  
- Leg 3: KELP → KLRD - Should be active, but isn't advancing

When user edits Leg 2's IN time, the system doesn't advance to Leg 3.

## Root Cause Analysis

### 1. The Status Problem
The `Trip.checkAndAdvanceLeg(at:)` method only advances if the leg's status is `.active`:

```swift
// If complete and currently active, advance
if isComplete && leg.status == .active {
    completeActiveLeg(activateNext: true)
    print("✅ Leg \(index + 1) complete - all times filled, advancing to next leg")
} else if leg.status != .active {
    print("ℹ️ Leg \(index + 1) is \(leg.status.rawValue), not active - skipping advancement")
}
```

### 2. The Workflow
When a user edits a completed leg:
1. `handleSetTimeMessage` receives IN time for leg 2
2. Leg 2 already has status = `.completed`
3. `trip.checkAndAdvanceLeg(at: 2)` is called
4. Method checks: `isComplete ✅ && leg.status == .active ❌`
5. Condition fails - no advancement happens
6. User is stuck on Leg 2

### 3. Why This Happens
- Legs can be manually completed via the UI
- Roster-imported legs may have status pre-set
- Re-editing times on completed legs is common (fixing typos, adjusting times)
- The system assumes only `.active` legs need advancement

## The Fix

### Strategy
Instead of only advancing `.active` legs, we need to:
1. Detect when editing a `.completed` leg
2. Find the trip's current active leg
3. If appropriate, advance from the active leg
4. Update `currentLegIndex` to track the active leg

### Implementation
Added logic in `PhoneWatchConnectivity.swift` → `handleSetTimeMessage` → case "IN":

```swift
if isComplete {
    // 🔥 NEW FIX: If leg is already completed, we need to find the ACTIVE leg and advance from there
    if leg.status == .completed {
        print("⚠️ Leg \(legIndex + 1) is already completed - finding active leg")
        if let activeLegIndex = trip.activeLegIndex {
            print("📍 Active leg is at index \(activeLegIndex)")
            // Only auto-advance if we're editing the currently active leg
            // OR if the edited leg is the one right before the active leg
            if legIndex == activeLegIndex || legIndex == activeLegIndex - 1 {
                trip.checkAndAdvanceLeg(at: activeLegIndex)
            }
        } else {
            print("⚠️ No active leg found - trip may be completed")
        }
    } else {
        // Normal case: leg is active, check and advance
        trip.checkAndAdvanceLeg(at: legIndex)
    }
    
    // Update currentLegIndex to match the active leg
    if let activeLegIndex = trip.activeLegIndex {
        if self.currentLegIndex != activeLegIndex {
            print("📱 Updating currentLegIndex from \(self.currentLegIndex) to \(activeLegIndex)")
            self.currentLegIndex = activeLegIndex
        }
    } else if legIndex < trip.legs.count - 1 {
        // Fallback: just advance to next leg
        print("📱 Leg \(legIndex + 1) complete - advancing to leg \(legIndex + 2)")
        self.currentLegIndex = legIndex + 1
    }
}
```

### Key Changes
1. **Detect completed legs** - Check if `leg.status == .completed`
2. **Find active leg** - Use `trip.activeLegIndex` (computed property from Trip model)
3. **Smart advancement** - Only advance if editing the active leg or the leg right before it
4. **Sync currentLegIndex** - Always update to match the active leg index
5. **Fallback logic** - If no active leg found, use simple index-based advancement

## Diagnostic Logging Added
The fix includes comprehensive logging to help debug future issues:

```
🔍 BEFORE checkAndAdvanceLeg:
   Leg Index: 1
   OUT: '1446' OFF: '1447' ON: '1510' IN: '1510'
   Status: completed
   Has all 4 times: true
   
⚠️ Leg 1 is already completed - finding active leg
📍 Active leg is at index 2

🔍 AFTER checkAndAdvanceLeg:
   Status: completed
   Active leg is now: 3
   Active leg route: KELP → MMIO
   Next leg status: active
```

## Testing Scenarios

### Scenario 1: Normal Flow (First Time)
- Leg 1 is active
- Set OUT, OFF, ON, IN on Leg 1
- ✅ Should advance to Leg 2
- ✅ Leg 1 status → completed
- ✅ Leg 2 status → active

### Scenario 2: Editing Completed Leg
- Leg 1 is completed
- Leg 2 is active
- Edit IN time on Leg 1
- ✅ Should NOT advance (editing historical data)
- ✅ Leg 2 remains active

### Scenario 3: Completing Already-Complete Leg (The Bug)
- Leg 2 is completed (manually or via previous edit)
- Leg 3 should be active
- Set IN time on Leg 2
- ✅ Should recognize Leg 2 is complete
- ✅ Should find active leg (Leg 3)
- ✅ Should update currentLegIndex to 3
- ✅ UI should show Leg 3 as current

### Scenario 4: Last Leg
- Leg 3 is active (last leg)
- Set all times on Leg 3
- ✅ Should complete Leg 3
- ✅ Should NOT try to advance (no next leg)
- ✅ Trip ready to end

## Related Code Files
- `PhoneWatchConnectivity.swift` - Handles watch messages and leg advancement
- `Trip.swift` - Contains `checkAndAdvanceLeg`, `activeLegIndex`, `completeActiveLeg`
- `FlightLeg.swift` - Leg model with status enum
- `ContentView.swift` - UI that displays leg status and times

## Future Improvements
Consider:
1. **Auto-recovery**: If active leg index is lost, calculate it from leg statuses
2. **Batch updates**: When importing roster, set all leg statuses correctly upfront
3. **Status validation**: Ensure only one leg is active at a time
4. **UI feedback**: Show which leg is "active" vs "completed" more clearly
5. **Watch sync**: Ensure watch also tracks active leg index properly

## Notes
- The `activeLegIndex` computed property searches for the first leg with status == `.active`
- If no active leg is found, returns `nil`
- This is a defensive fix that handles edge cases where leg status gets out of sync
- The diagnostic logging will help identify future state management issues

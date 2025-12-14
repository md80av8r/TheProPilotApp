# Add Leg UI Refresh Fix

## Problem Description
When adding a new leg from the Apple Watch, the iPhone's UI was not updating to show the new leg row. Additionally, completed legs were still showing as editable, and empty arrival fields were displaying as blank instead of a placeholder.

## Issues Identified

### 1. **UI Not Refreshing**
- New leg added from watch → Phone saves it ✅
- But ContentView/UI doesn't know to refresh ❌
- Result: User sees 2 legs, but 3 exist in data

### 2. **Missing Notification**
The `addNewLegAndBroadcast()` method was updating the trip and saving it, but **never posting a notification** to tell SwiftUI views to refresh.

### 3. **Empty Arrival Field**
When arrival is `nil` or empty string, it was being saved as `""` instead of a placeholder like `"----"`.

### 4. **Leg Status Not Set**
New legs weren't being assigned a proper `.standby` status, which could affect UI rendering.

## Console Log Evidence

```
✅ Added new leg from watch: JUS345 KLRD-
✅ Updated flight data for leg 3 of 2
   Route: KLRD → 
```

Notice:
- Arrival is empty (just `KLRD-` with nothing after)
- "leg 3 of 2" - inconsistent totals
- No notification posted

## The Fix

### Part 1: Post Notification for UI Refresh

Added notification posting to `addNewLegAndBroadcast()`:

```swift
// ✅ CRITICAL FIX: Notify UI about trip changes so new leg row appears
NotificationCenter.default.post(
    name: .tripStatusChanged,
    object: activeTrip
)
```

This tells any listening SwiftUI views (like ContentView) that the trip has changed and they should re-render.

### Part 2: Better Default Values for New Legs

Improved the logic for determining departure and arrival:

```swift
// Departure: if nil or empty, use last leg's arrival or current airport
let dep: String
if let departure = departure, !departure.isEmpty {
    dep = departure
} else if let lastArrival = lastLeg?.arrival, !lastArrival.isEmpty {
    dep = lastArrival
} else {
    dep = locationManager?.currentAirport ?? "ZZZZ"
}

// Arrival: if nil or empty, use placeholder
let arr: String
if let arrival = arrival, !arrival.isEmpty {
    arr = arrival
} else {
    arr = "----"  // Use placeholder instead of empty string
}
```

### Part 3: Set Leg Status

```swift
newLeg.status = .standby  // Will be activated when previous leg completes
```

This ensures:
- UI can distinguish between active, completed, and standby legs
- Leg advancement logic works correctly
- User sees appropriate buttons/controls for each leg

### Part 4: Better Logging

```swift
print("📱 ✅ Adding new leg \(newLegIndex + 1): \(dep) → \(arr) (status: standby)")
```

Now we can see:
- Which leg index is being added
- Full route with proper arrival
- Status assigned to the leg

## Expected Behavior After Fix

### Before Fix:
```
User: Adds Leg 3 from watch
Phone: Saves leg to trip ✅
Phone: Syncs to watch ✅
Phone UI: Still shows 2 legs ❌
Trip Card: Shows "KLRD → ?" ❌
Watch: Shows "KLRD → " ❌
```

### After Fix:
```
User: Adds Leg 3 from watch
Phone: Saves leg to trip ✅
Phone: Posts .tripStatusChanged notification ✅
Phone: Syncs to watch with arrival="----" ✅
Phone UI: Immediately shows 3 legs ✅
Trip Card: Shows "KLRD → ----" ✅
Watch: Shows "KLRD → ----" ✅
User: Can tap arrival to edit it ✅
```

## Testing Steps

1. **Start a trip** with 1-2 legs
2. **Complete leg 1** (set all 4 times)
3. **Verify UI** shows:
   - Leg 1: "Complete" badge, no editable cells
   - Leg 2: Active, editable time cells
   - "Add Leg" button visible
4. **Add Leg 3 from watch**
5. **Verify immediately**:
   - Phone UI refreshes and shows Leg 3 row
   - Leg 3 shows "KLRD → ----" (not empty)
   - Leg 3 is editable
   - "Add Leg" button still visible

## Related Code Changes

**File:** `PhoneWatchConnectivity.swift`
- **Method:** `addNewLegAndBroadcast()`
- **Lines:** ~1500-1570

## Additional UI Issues (Still Need Fixing)

### Issue 1: Completed Legs Still Editable
**Problem:** Your screenshot shows Leg 2 marked "Complete" but still has editable time cells with blue borders.

**Expected:** Completed legs should either:
- Be read-only (gray cells, no tap interaction)
- Be hidden/collapsed
- Show a "View" mode instead of "Edit"

**Where to fix:** ContentView or the component that renders leg rows

### Issue 2: "Add Leg" Button Visibility Logic
**Problem:** Button appears even when not all times are filled

**Expected:** "Add Leg" button should only appear when:
- Current leg is complete (all 4 times filled)
- OR last leg in trip

**Where to fix:** Button visibility condition in ContentView

## Notification Chain

```
addNewLegAndBroadcast()
  ↓
NotificationCenter.post(.tripStatusChanged)
  ↓
ContentView receives notification
  ↓
@State var trip updates (through LogBookStore)
  ↓
ForEach re-renders with new leg count
  ↓
New leg row appears in UI
```

## Notes

- The notification is posted **on the main thread** (already in `DispatchQueue.main.async` context)
- The `tripStatusChanged` notification uses the modified trip as its `object`
- SwiftUI views observing `LogBookStore` will automatically refresh
- Watch connectivity sends both direct message AND application context for reliability

## Future Improvements

1. **Optimistic UI Updates**: Update UI immediately before server confirmation
2. **Loading States**: Show spinner while adding leg
3. **Error Handling**: Show alert if leg addition fails
4. **Undo**: Allow user to remove accidentally added leg
5. **Batch Adds**: Support adding multiple legs at once

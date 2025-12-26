# Trip Grouping Bug Fix

## Issue Summary
The NOC Trip Tester was creating **3 separate trips** instead of **1 trip with 3 legs** when importing a test trip from the roster.

## Root Cause
The bug was in `TripGenerationService.swift` in the `groupFlightsIntoTrips()` method at **line 333**.

### The Problem
```swift
// ❌ WRONG - Comparing midnight with actual arrival time
let gap = flight.date.timeIntervalSince(lastEnd)
```

This compared:
- `flight.date` → Start of the calendar day (midnight 00:00:00)
- `lastEnd` → Actual arrival time of previous flight (e.g., 10:30 AM)

### Example Scenario
For a trip with 3 legs on the same day:
- **Leg 1**: YIP→DTW departing 10:00, arriving 10:30
- **Leg 2**: DTW→CLE departing 11:15, arriving 11:50  
- **Leg 3**: CLE→YIP departing 12:35, arriving 13:15

When processing **Leg 2**:
- `flight.date` = Today at 00:00:00 (midnight)
- `lastEnd` = Today at 10:30:00 (Leg 1's arrival)
- **Gap calculation**: 00:00:00 - 10:30:00 = **-10.5 hours** (negative!)

This caused incorrect trip grouping logic, breaking legs into separate trips.

### Additional Issue
The sorting was also using `flight.date` instead of `flight.blockOut`, which meant flights weren't properly ordered by their actual departure times.

## The Fix

Changed **two places** in the `groupFlightsIntoTrips()` method:

### 1. Sorting
```swift
// ✅ CORRECT - Sort by actual departure time
let sorted = flights.sorted { $0.blockOut < $1.blockOut }
```

### 2. Gap Calculation
```swift
// ✅ CORRECT - Compare actual departure time with previous arrival
let gap = flight.blockOut.timeIntervalSince(lastEnd)
let hoursGap = gap / 3600

// Check if different calendar day using actual times
let calendar = Calendar.current
let sameDay = calendar.isDate(flight.blockOut, inSameDayAs: lastEnd)
```

## How It Works Now

With the fix, for the same 3-leg trip:

**Processing Leg 2**:
- `flight.blockOut` = Today at 11:15:00
- `lastEnd` = Today at 10:30:00  
- **Gap**: 11:15:00 - 10:30:00 = **0.75 hours** (45 minutes) ✅
- Same day check: Both on same date ✅
- Result: **Legs stay grouped together** in one trip ✅

## Testing
Test the fix using the **NOC Trip Tester** in the Beta Testing tab:

1. Go to **Tab Manager → Beta Testing Tab**
2. Open **NOC Trip Tester**
3. Select **"Roster Items (Real Flow)"** mode
4. Click **"Add to Roster"**
5. Check the notification/pending trips - should show **1 trip with 3 legs**

Expected result:
```
✅ 1 new trip detected: TEST-XXXX
   Route: YIP → DTW → CLE → YIP
   3 legs
```

Instead of the previous broken behavior:
```
❌ 3 trips detected:
   Trip 1: YIP → DTW (1 leg)
   Trip 2: DTW → CLE (1 leg)  
   Trip 3: CLE → YIP (1 leg)
```

## Files Modified
- `TripGenerationService.swift` - Fixed `groupFlightsIntoTrips()` method

## Impact
This fix ensures that:
- ✅ Multi-leg trips are properly grouped together
- ✅ Flights are sorted by actual departure time
- ✅ Gap calculations use real flight times, not midnight
- ✅ Same-day trip detection works correctly
- ✅ Overnight trips still split properly (different calendar days)
- ✅ Long layovers (>12 hours) still split trips appropriately

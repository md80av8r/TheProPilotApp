# Manual/Automatic Trip Grouping Feature

## Overview
This feature gives pilots the choice between automatic trip generation (based on duty time rules) and manual trip building (user selects which legs to include).

---

## Files Created/Modified

### **New Files**
1. **AddLegsToTripSheet.swift** - Interactive leg selection interface
2. **PendingTripCard.swift** - Enhanced trip card with "Add Legs" button

### **Modified Files**
1. **TripGenerationSettings.swift** - Added `TripGroupingMode` enum and setting
2. **TripGenerationService.swift** - Added manual mode logic and leg selection APIs
3. **TripGenerationSettingsView.swift** - Added UI toggle for grouping mode

---

## How It Works

### **Automatic Mode** (Default)
```
NOC Sync → Auto-group legs (<12h gaps) → Single notification → Create trip
```

**Example:**
```
3 legs detected:
  JUS323 DTW→CLE (10:00-11:00)
  JUS324 CLE→MSP (12:00-13:30) [1h turn]
  JUS325 MSP→DEN (14:30-16:00) [1h turn]

Result: ONE pending trip "JUS323" with 3 legs
Notification: "New Trip Detected: JUS323 - 3 legs"
```

### **Manual Mode**
```
NOC Sync → Each leg separate → User selects additional legs → Create trip
```

**Example:**
```
3 legs detected:
  → JUS323 DTW→CLE (1 leg)
  → JUS324 CLE→MSP (1 leg)
  → JUS325 MSP→DEN (1 leg)

User flow:
  1. Tap "JUS323" notification
  2. Tap "Add More Legs"
  3. Select JUS324 ✓
  4. Select JUS325 ✓
  5. Tap "Add 2 Legs"
  6. Tap "Create Trip"

Result: ONE trip with 3 legs
```

---

## UI Components

### **1. PendingTripCard**

Shows detected trip with action buttons:

```
┌─────────────────────────────────────┐
│ 🛩️  New Trip Detected              │
│     JUS323                          │
│     Dec 17, 2025                    │
├─────────────────────────────────────┤
│ KDTW → KCLE → KMSP                 │
│ 04:00Z  05:30Z  07:45Z             │
│                                     │
│ 🔔 Show Time: 3:00 PM    ⏰ in 2h │
│ ✈️ 3 legs    ⏱️ 3:45              │
├─────────────────────────────────────┤
│ [Manual Mode Only]                  │
│ ➕ Add More Legs                   │
├─────────────────────────────────────┤
│ ✅ Create Trip                     │
├─────────────────────────────────────┤
│ 🕐 Later     |     ❌ Dismiss     │
└─────────────────────────────────────┘
```

### **2. AddLegsToTripSheet**

Interactive leg selection interface:

```
┌─────────────────────────────────────┐
│          Add Legs to Trip           │
│                               Cancel │
├─────────────────────────────────────┤
│ Current Trip                        │
│ 🛩️  JUS323                  1 leg  │
│ KDTW → KCLE                 1:00   │
├─────────────────────────────────────┤
│                                     │
│ ⚪ JUS324          🔗 Connects     │
│    KCLE → KMSP                     │
│    ⏰ 1200Z → 1330Z    1:30        │
│                                     │
│ ⚪ JUS325          🔗 Connects     │
│    KMSP → KDEN                     │
│    ⏰ 1430Z → 1600Z    1:30        │
│                                     │
├─────────────────────────────────────┤
│ ✓ 2 legs selected          +3:00   │
│ ➕ Add 2 Legs                      │
└─────────────────────────────────────┘
```

**Features:**
- ✅ Shows current trip summary at top
- ✅ Lists available legs (same day + next day)
- ✅ Highlights connecting flights with 🔗 icon
- ✅ Shows selection count and total block time
- ✅ Tap to select/deselect legs
- ✅ Visual feedback with checkmarks and green border
- ✅ Success toast when legs added

---

## Settings UI

### **Location**
Tab Manager → Schedule & Operations → Trip Generation Settings

### **New Control**
```
┌─────────────────────────────────────┐
│ Trip Detection                      │
├─────────────────────────────────────┤
│ Trip Grouping                       │
│ ┌─────────┬─────────┐              │
│ │ 🔄 Auto │ 🖐 Manual│              │
│ └─────────┴─────────┘              │
│                                     │
│ ☑️ Include Deadhead Flights        │
│ ☑️ Require Confirmation            │
│                                     │
│ Automatic mode groups legs with    │
│ <12h gaps into trips. You'll be    │
│ prompted to review each trip.      │
└─────────────────────────────────────┘
```

---

## API Reference

### **TripGenerationSettings**

```swift
enum TripGroupingMode: String, Codable {
    case automatic  // Auto-group using <12h duty time logic
    case manual     // User manually selects legs
}

class TripGenerationSettings {
    @Published var tripGroupingMode: TripGroupingMode = .automatic
}
```

### **TripGenerationService**

```swift
// Get available legs for a pending trip
func getAvailableLegsForPendingTrip(
    _ pendingTrip: PendingRosterTrip, 
    allRosterItems: [BasicScheduleItem]
) -> [BasicScheduleItem]

// Add selected legs to pending trip
func addLegsToPendingTrip(
    _ pendingTrip: PendingRosterTrip, 
    selectedLegs: [BasicScheduleItem]
)
```

### **PendingRosterTrip**

```swift
struct PendingRosterTrip {
    var legs: [PendingLeg]              // Now mutable
    var totalBlockMinutes: Int          // Recalculated when legs added
    var rosterSourceIds: [String]       // Updated with new leg IDs
}
```

---

## Integration Guide

### **Step 1: Use PendingTripCard in your UI**

Replace your current pending trip display with:

```swift
// In your PendingTripsView or similar
ForEach(tripService.pendingTrips) { pendingTrip in
    PendingTripCard(pendingTrip: pendingTrip)
        .environmentObject(logbookStore)
        .environmentObject(scheduleStore)
}
```

### **Step 2: Notifications Work Automatically**

When manual mode is active:
- Each leg gets its own pending trip
- Notification shows "JUS323 - 1 leg"
- User taps → sees card → can add more legs

When automatic mode is active:
- Legs auto-grouped
- Notification shows "JUS323 - 3 legs"
- User taps → sees card → creates trip

### **Step 3: Settings Toggle**

The toggle in TripGenerationSettingsView is already added:

```swift
Picker("Trip Grouping", selection: $settings.tripGroupingMode) {
    Label("Automatic", systemImage: "bolt.automatic")
    Label("Manual", systemImage: "hand.tap")
}
.pickerStyle(.segmented)
```

---

## User Flows

### **Automatic Mode Flow**
1. NOC sync completes ✅
2. System detects 3 legs with <12h gaps
3. Groups into 1 trip automatically
4. Notification: "New Trip Detected: JUS323 - 3 legs"
5. User taps notification
6. Sees trip card with all 3 legs
7. Taps "Create Trip"
8. Done! ✅

### **Manual Mode Flow**
1. NOC sync completes ✅
2. System creates 3 separate pending trips
3. Notifications: "JUS323 - 1 leg", "JUS324 - 1 leg", "JUS325 - 1 leg"
4. User taps first notification (JUS323)
5. Sees trip card with 1 leg
6. Taps "Add More Legs" 🆕
7. Sheet appears with available legs
8. User selects JUS324 ✓ and JUS325 ✓
9. Taps "Add 2 Legs"
10. Route updates: KDTW → KCLE → KMSP → KDEN
11. Taps "Create Trip"
12. Done! ✅

---

## Technical Details

### **Grouping Logic (Automatic Mode)**

```swift
// In groupFlightsIntoTrips()
for each flight:
    if gap >= 12 hours:
        → start new trip (rest period)
    else if !connects && gap > 4h:
        → start new trip (separate duty)
    else:
        → add to current trip (same duty period)
```

### **Available Legs Filter (Manual Mode)**

```swift
// In getAvailableLegsForPendingTrip()
filter criteria:
    ✓ Must be actual flight (not rest, etc.)
    ✓ Not already in this trip
    ✓ Same day or next day (0-1 day difference)
    ✓ Sorted by departure time
```

### **Connection Detection**

```swift
// In AddLegsToTripSheet
func connectsToPendingTrip(_ leg: BasicScheduleItem) -> Bool {
    guard let lastLeg = pendingTrip.legs.last else { return false }
    return lastLeg.arrival == leg.departure
}
```

Shows green "🔗 Connects" badge when leg departs from where trip ends.

---

## Styling & Theme

Uses your existing LogbookTheme:
- **Background**: `LogbookTheme.navy`, `LogbookTheme.navyLight`
- **Accent Colors**: 
  - Green: `LogbookTheme.accentGreen` (success, create)
  - Blue: `LogbookTheme.accentBlue` (airports, info)
  - Orange: `LogbookTheme.accentOrange` (times, warnings)
- **Fonts**: System fonts with proper hierarchy
- **Corners**: 12px radius for cards/buttons
- **Spacing**: Consistent 12-16px padding

---

## Testing Checklist

### **Automatic Mode**
- [ ] 3 legs <12h apart → 1 trip created ✅
- [ ] 2 legs >12h apart → 2 trips created ✅
- [ ] Non-connecting airports → separate trips ✅
- [ ] Notification shows correct leg count ✅

### **Manual Mode**
- [ ] 3 legs → 3 separate pending trips ✅
- [ ] "Add Legs" button appears ✅
- [ ] Sheet shows available legs ✅
- [ ] Can select multiple legs ✅
- [ ] Connecting legs show badge ✅
- [ ] Route updates after adding legs ✅
- [ ] Block time recalculates ✅
- [ ] Create trip works with added legs ✅

### **Settings**
- [ ] Toggle saves/persists ✅
- [ ] Footer text updates based on mode ✅
- [ ] Reset to defaults works ✅
- [ ] Backward compatible (defaults to auto) ✅

### **Edge Cases**
- [ ] No available legs → shows empty state ✅
- [ ] Add same leg twice → prevented by ID check ✅
- [ ] Switch modes mid-session → next sync respects new mode ✅
- [ ] Dismiss trip → doesn't reappear ✅

---

## Support & Troubleshooting

### **Issue: "Add Legs" button not showing**
**Fix:** Check that `tripGroupingMode == .manual` in settings

### **Issue: No legs appear in AddLegsToTripSheet**
**Cause:** No flights on same/next day, or all already in trip
**Fix:** This is expected - shows empty state

### **Issue: Legs not connecting properly**
**Check:** Airport codes match exactly (ICAO format: KDTW not DTW)

### **Issue: Block time incorrect after adding legs**
**Check:** `totalBlockTime` on BasicScheduleItem (should be in seconds)

---

## Future Enhancements (Optional)

1. **Smart Suggestions**: AI-suggested leg groupings
2. **Drag & Reorder**: Reorder legs in trip
3. **Remove Legs**: Remove legs from pending trip before creation
4. **Multi-Day Trips**: Better support for trips spanning 2+ days
5. **Batch Actions**: "Add all connecting" button
6. **History**: See previously dismissed trips

---

## Credits

Created: December 16, 2024
Feature: Manual/Automatic Trip Grouping
Files: 2 new, 3 modified
Lines of Code: ~800

Designed to match existing ProPilot UI/UX patterns and LogbookTheme styling.

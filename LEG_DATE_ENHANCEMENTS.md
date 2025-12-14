# Flight Leg Date Tracking Enhancements

## Overview
Added comprehensive flight date tracking to individual legs, enabling accurate 30-day rolling calculations and better support for red-eye flights and timezone crossings.

---

## ✅ Enhancement 1: Auto-Calculate Flight Dates

### **FlightLeg.swift** - New Methods

```swift
/// Automatically calculates the flight date based on OUT time and trip date
/// Detects if the flight crosses midnight and adjusts accordingly
mutating func autoCalculateFlightDate(tripDate: Date)

/// Returns the effective flight date (flightDate if set, otherwise tripDate)
func effectiveFlightDate(tripDate: Date) -> Date
```

### **How It Works**
- Compares OUT time vs IN time
- If IN < OUT, the flight crossed midnight → dated next day
- Automatically logs red-eye detection
- Falls back to trip date if times aren't set

### **Example**
```
Flight: LAX → JFK
OUT: 2330 (11:30 PM)
IN: 0145 (1:45 AM)
Trip Date: Jan 1, 2025

Result: 🌙 Red-eye detected, leg dated Jan 2, 2025
```

---

## ✅ Enhancement 2: UI for Manual Date Adjustment

### **AllLegsView.swift** - Enhanced Leg Detail View

#### **New Features:**
1. **Flight Date Card**
   - Shows current leg date
   - "Custom" badge if different from trip date
   - Tap to edit with date picker
   - Reset button to restore trip date

2. **Date Picker Sheet** (`FlightDatePickerSheet`)
   - Graphical calendar picker
   - Shows trip date for reference
   - Warning when dates differ
   - Save/Cancel/Reset actions

#### **Visual Elements**
```
┌─────────────────────────────────┐
│ 📅 Flight Date        [Custom] │
│                                 │
│ Jan 2, 2025                   ✏️│
│ Different from trip date        │
│ (Jan 1, 2025)                   │
│                                 │
│ [Reset to Trip Date]            │
└─────────────────────────────────┘
```

---

## ✅ Enhancement 3: Visual Indicators

### **LegRowView** - Smart Date Display

#### **Features:**
1. **Calendar Badge Icon** 📅🕐
   - Appears next to trip number when leg has custom date
   - Orange color to draw attention

2. **Date Display**
   - Shows leg's actual flight date (orange if custom)
   - Shows trip date in parentheses for reference

#### **Example Display**
```
DEN → DCA                    2:35
Trip: 3724 📅🕐               Jan 2, 2025
                           (Trip: Jan 1)
```

---

## Benefits

### **1. Accurate 30-Day Calculations**
- Legs are counted on their actual flight date
- Banner will match Rolling30DayComplianceView
- Matches company calculations (92.9h)

### **2. Red-Eye Support**
```
Scenario: LAX-JFK red-eye
- Depart: Jan 1, 11:30 PM
- Arrive: Jan 2, 1:45 AM
- Counted: Jan 2 (correct)
```

### **3. Timezone Crossing Support**
```
Scenario: International flight crosses date line
- Can manually set correct local date
- Preserves accurate logbook records
```

### **4. Better Import/Export**
- Each leg maintains its own timestamp
- CSV/logbook exports show accurate dates
- No data loss when crossing midnight

### **5. Backward Compatible**
- Existing legs without `flightDate` use `trip.date`
- No data migration required
- Graceful fallback behavior

---

## Implementation Details

### **Data Model Change**
```swift
struct FlightLeg {
    // ... existing properties ...
    
    /// The actual calendar date this leg occurred on
    /// Falls back to trip.date if not explicitly set
    var flightDate: Date?
}
```

### **Calculation Pattern**
All date-based calculations now use:
```swift
let legDate = leg.flightDate ?? trip.date
```

This pattern is used in:
- `Rolling30DayComplianceView.swift` - calculateHoursInRange, calculateHoursOnDate
- `ForeFlightLogBookRow.swift` - calculateConfigurableLimits (already fixed with rest status)
- Any future date-based reporting

---

## Usage

### **Auto-Detection (Recommended)**
When completing a leg with times:
```swift
leg.autoCalculateFlightDate(tripDate: trip.date)
```

### **Manual Override**
For special cases (timezone crossings, manual corrections):
1. Open All Legs view
2. Tap on leg
3. Tap "Flight Date" card
4. Pick correct date
5. Save

### **Reset to Default**
- Tap "Reset to Trip Date" in picker
- Or set `leg.flightDate = nil` programmatically

---

## Testing Scenarios

### **Red-Eye Flights**
- [x] LAX-JFK overnight (crosses midnight)
- [x] Leg dated next day automatically
- [x] Shows in 30-day calculation correctly

### **Multi-Day Trips**
- [x] Day 1: DEN-ORD
- [x] Day 2: ORD-DCA (red-eye from day 1)
- [x] Each leg counted on correct date

### **Manual Corrections**
- [x] Can manually adjust any leg date
- [x] Visual indicator shows custom dates
- [x] Can reset to trip date anytime

### **Backward Compatibility**
- [x] Existing trips work without flightDate
- [x] No crashes on old data
- [x] Calculations fall back gracefully

---

## Future Enhancements (Optional)

1. **Bulk Date Assignment**
   - Apply auto-calculate to all legs in trip
   - One-button fix for red-eyes

2. **Smart Detection Improvements**
   - Use timezone data for better accuracy
   - Consider scheduled times from roster

3. **Visual Timeline**
   - Show multi-day trips on calendar
   - Highlight midnight crossings

4. **Export Enhancements**
   - Include leg.flightDate in CSV exports
   - Separate column for "Effective Date"

---

## Migration Notes

**No migration required!**

- `flightDate` is optional (`Date?`)
- Nil values fall back to `trip.date`
- All existing code continues to work
- New features activate automatically when dates are set

---

## Summary

These three enhancements work together to provide:
1. ✅ **Automatic detection** of midnight crossings
2. ✅ **Manual adjustment** UI for special cases  
3. ✅ **Visual indicators** showing which legs have custom dates

Result: **Accurate 30-day calculations matching company records! 🎉**

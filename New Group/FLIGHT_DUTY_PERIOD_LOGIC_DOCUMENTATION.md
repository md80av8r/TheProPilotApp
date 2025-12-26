# Flight Duty Period (FDP) Logic Documentation
**TheProPilotApp - Crew Duty Time Tracking System**

## Executive Summary

The app tracks Flight Duty Period (FDP) to comply with FAR 117 regulations. There is a **CRITICAL BUG** in the current implementation where the NOC Trip Tester is incorrectly showing **"22/8h"** for duty time calculations.

---

## 🚨 ISSUE IDENTIFIED: Incorrect Duty Timer Display (22/8h)

### Problem Description
The NOC Trip Tester in the Beta tab is showing **22 hours and 8 hours** (format unclear) for duty calculations, which is incorrect for a ~3h 50m test trip.

### Expected vs Actual
- **Test Trip Duration**: ~3 hours 50 minutes (3 legs: YIP→DTW→CLE→YIP)
- **Expected Duty Time**: ~4-5 hours (includes pre/post duty buffers)
- **Actual Display**: 22/8h (INCORRECT)

### Possible Root Causes
1. **Time calculation using wrong date reference**
2. **Overnight calculation logic adding 24 hours incorrectly**
3. **Buffer times being calculated multiple times**
4. **Duty start/end times not being properly set from scheduled roster data**
5. **Test trip generation not properly clearing previous duty status**

---

## 📋 Current FDP Implementation

### 1. Trip Model - Duty Time Properties

Location: `Trip.swift` lines 124-128

```swift
// MARK: - Duty Time Tracking
var dutyStartTime: Date?          // When duty period started (editable)
var dutyEndTime: Date?            // When duty period ended
var dutyMinutes: Int?             // Total duty time in minutes (calculated)
```

### 2. Duty Time Calculation Logic

Location: `Trip.swift` lines 348-410

#### A. Effective Duty Start Time
```swift
/// Calculated or stored duty start time
/// Returns stored dutyStartTime, or calculates from first OUT - 1 hour
var effectiveDutyStartTime: Date? {
    // If explicitly set, use that
    if let stored = dutyStartTime {
        return stored
    }
    
    // Otherwise calculate from first OUT time - 1 hour
    guard let firstLeg = legs.first,
          !firstLeg.outTime.isEmpty,
          let outDateTime = parseTimeForDuty(timeString: firstLeg.outTime, date: date) else {
        return nil
    }
    
    // Subtract 1 hour (default pre-duty buffer)
    return Calendar.current.date(byAdding: .minute, value: -Trip.defaultPreDutyBuffer, to: outDateTime)
}
```

**Constants:**
- `defaultPreDutyBuffer = 60` minutes (1 hour before first OUT)
- Post-duty buffer: 15 minutes after last IN

#### B. Effective Duty End Time
```swift
/// Calculated or stored duty end time
/// Returns stored dutyEndTime, or calculates from last IN + 15 minutes
var effectiveDutyEndTime: Date? {
    // If explicitly set, use that
    if let stored = dutyEndTime {
        return stored
    }
    
    // Otherwise calculate from last IN time + 15 minutes post-duty
    guard let lastLeg = legs.last,
          !lastLeg.inTime.isEmpty,
          let inDateTime = parseTimeForDuty(timeString: lastLeg.inTime, date: date) else {
        return nil
    }
    
    // Add 15 minutes post-duty buffer
    return Calendar.current.date(byAdding: .minute, value: 15, to: inDateTime)
}
```

#### C. Total Duty Hours Calculation
```swift
/// Total duty period in hours for this trip
var totalDutyHours: Double {
    // Auto-calculate if no manual time set
    guard let start = dutyStartTime ?? calculateAutoDutyStart(),
          let end = dutyEndTime ?? calculateAutoDutyEnd() else {
        return 0
    }
    
    let interval = end.timeIntervalSince(start)
    return max(0, interval / 3600.0)
}

private func calculateAutoDutyStart() -> Date? {
    guard let firstLeg = legs.first,
          let outTime = parseTimeWithDate(timeString: firstLeg.outTime, date: date) else {
        return nil
    }
    return outTime.addingTimeInterval(-60 * 60) // 60 min before
}

private func calculateAutoDutyEnd() -> Date? {
    guard let lastLeg = legs.last,
          let inTime = parseTimeWithDate(timeString: lastLeg.inTime, date: date) else {
        return nil
    }
    return inTime.addingTimeInterval(15 * 60) // 15 min after
}
```

---

## 🔍 Test Trip Generation Analysis

### NOC Trip Tester Flow
Location: `NOCTestView.swift`

#### Test Trip Specifications
- **Route**: YIP → DTW → CLE → YIP
- **Legs**: 3
- **Aircraft**: N833US (MD-88)
- **Flight Numbers**: UJ8790, UJ8791, UJ8792
- **Total Duration**: ~3h 50m

#### Scheduled Times (from test data)
```swift
// Leg 1: YIP-DTW
let leg1Start = baseTime
let leg1End = calendar.date(byAdding: .minute, value: 30, to: leg1Start)!

// Leg 2: DTW-CLE (45 min ground time)
let leg2Start = calendar.date(byAdding: .minute, value: 45, to: leg1End)!
let leg2End = calendar.date(byAdding: .minute, value: 35, to: leg2Start)!

// Leg 3: CLE-YIP (45 min ground time)
let leg3Start = calendar.date(byAdding: .minute, value: 45, to: leg2End)!
let leg3End = calendar.date(byAdding: .minute, value: 40, to: leg3Start)!
```

**Total elapsed time**: 30 + 45 + 35 + 45 + 40 = **195 minutes (3h 15m)**

#### Expected Duty Calculation
```
Leg 1 OUT: baseTime
Leg 3 IN:  baseTime + 195 minutes

Duty Start: baseTime - 60 min (pre-duty buffer)
Duty End:   baseTime + 195 min + 15 min (post-duty buffer)

Total Duty: 60 + 195 + 15 = 270 minutes = 4.5 hours
```

**Expected Display**: ~4.5 hours or "4h 30m"

---

## 🐛 BUG ANALYSIS: Why 22/8h is Showing

### Hypothesis 1: Overnight Calculation Error
If the time parsing logic thinks the trip crosses midnight, it might add 24 hours:

```swift
// In parseTimeWithDate or similar logic
if inTotal < outTotal {
    inTotal += 24 * 60  // ⚠️ This could be triggered incorrectly
}
```

**If this happens twice** (once for duty calc, once for block time):
- 4.5 hours + 24 hours = 28.5 hours (close to 22h)

### Hypothesis 2: Multiple Timer Accumulation
The app might be accumulating duty time from:
1. Current active duty period (if one exists)
2. Test trip duty calculation
3. Previous test trip that wasn't cleaned up

**Evidence from code:**
```swift
// NOCTestView.swift line 648-651
// 🔧 FIX: Restore duty status after test trip generation
restoreDutyStatusFromNOC()
testResult += "✅ Restored duty status from NOC\n"
```

This suggests duty status contamination was a known issue.

### Hypothesis 3: Incorrect Time Format Parsing
The test trip uses iCal format with Zulu (UTC) times:

```swift
// createTestICalData()
DTSTART:\(formatICalDate(leg1Start))  // UTC timestamp
STD \(formatZuluTime(leg2Start))Z     // Zulu time in HHmm format
```

If the parsing logic confuses **UTC times with local times**, it could cause significant errors:
- UTC time: 1400Z
- Local time: 0900L (EDT)
- Difference: 5 hours

Multiple legs with this confusion could yield incorrect totals.

### Hypothesis 4: Missing Scheduled Data
From the test code validation:

```swift
// NOCTestView.swift line 588-601
testResult += "\n🔍 Validating leg data...\n"
for (index, leg) in newTrip.legs.enumerated() {
    let hasScheduledOut = leg.scheduledOut != nil
    let hasScheduledIn = leg.scheduledIn != nil
    let hasRosterId = leg.rosterSourceId != nil
    
    testResult += "  Leg \(index + 1): "
    testResult += hasScheduledOut ? "✅OUT " : "❌OUT "
    testResult += hasScheduledIn ? "✅IN " : "❌IN "
    testResult += hasRosterId ? "✅ID\n" : "❌ID\n"
}
```

**If `scheduledOut` or `scheduledIn` are nil**, the duty calculation might fall back to incorrect defaults or use wrong time references.

---

## 🔧 RECOMMENDED FIXES

### Fix 1: Add Comprehensive Debug Logging

Add to `Trip.swift` in `totalDutyHours`:

```swift
var totalDutyHours: Double {
    guard let start = dutyStartTime ?? calculateAutoDutyStart(),
          let end = dutyEndTime ?? calculateAutoDutyEnd() else {
        print("⚠️ FDP: No duty start/end times available")
        return 0
    }
    
    let interval = end.timeIntervalSince(start)
    let hours = interval / 3600.0
    
    // 🔍 DEBUG: Log duty calculation
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    print("📊 FDP Calculation for Trip \(tripNumber):")
    print("   Start: \(formatter.string(from: start))")
    print("   End:   \(formatter.string(from: end))")
    print("   Interval: \(interval) seconds")
    print("   Hours: \(hours)")
    
    // 🚨 Sanity check: duty should never exceed 16 hours for normal operations
    if hours > 16 {
        print("⚠️ WARNING: Duty hours exceed 16! Possible calculation error.")
        print("   Trip date: \(date)")
        print("   First leg OUT: \(legs.first?.outTime ?? "nil")")
        print("   Last leg IN: \(legs.last?.inTime ?? "nil")")
    }
    
    return max(0, hours)
}
```

### Fix 2: Validate Time Parsing for Overnight

Update `parseTimeWithDate` to include validation:

```swift
private func parseTimeWithDate(timeString: String, date: Date) -> Date? {
    let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTime.isEmpty else { return nil }
    
    let calendar = Calendar.current
    let cleanedTime = trimmedTime
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
    
    var hours: Int?
    var minutes: Int?
    
    if cleanedTime.count == 4 {
        hours = Int(cleanedTime.prefix(2))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count == 3 {
        hours = Int(cleanedTime.prefix(1))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count <= 2 {
        hours = Int(cleanedTime)
        minutes = 0
    }
    
    guard let h = hours, let m = minutes,
          h >= 0 && h <= 23, m >= 0 && m <= 59 else {
        print("⚠️ Invalid time format: \(timeString)")
        return nil
    }
    
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = h
    components.minute = m
    
    guard let parsedDate = calendar.date(from: components) else {
        print("⚠️ Failed to create date from components: \(components)")
        return nil
    }
    
    // 🔍 DEBUG: Log parsed time
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    print("🕐 Parsed '\(timeString)' as \(formatter.string(from: parsedDate))")
    
    return parsedDate
}
```

### Fix 3: Explicit Scheduled Time Validation

In `RosterToTripHelper.createLeg(from:BasicScheduleItem)`:

```swift
func createLeg(from item: BasicScheduleItem) -> FlightLeg {
    var leg = FlightLeg(
        departure: item.departure,
        arrival: item.arrival,
        flightNumber: extractFlightNumber(from: item),
        // ... other fields
    )
    
    // 🔥 CRITICAL: Explicitly set scheduled times
    leg.scheduledOut = item.blockOut
    leg.scheduledIn = item.blockIn
    leg.scheduledFlightNumber = item.tripNumber
    leg.rosterSourceId = item.id.uuidString
    
    // 🔍 VALIDATE: Ensure times make sense
    let duration = item.blockIn.timeIntervalSince(item.blockOut)
    if duration < 0 {
        print("⚠️ WARNING: Negative duration for leg \(item.departure)→\(item.arrival)")
        print("   scheduledOut: \(item.blockOut)")
        print("   scheduledIn:  \(item.blockIn)")
    } else if duration > 12 * 3600 {
        print("⚠️ WARNING: Leg duration exceeds 12 hours")
        print("   Duration: \(duration / 3600) hours")
    }
    
    return leg
}
```

### Fix 4: Clear Duty State Before Test Trip

In `NOCTestView.swift`, add duty state clearing:

```swift
private func generateDirectTrip() {
    isGenerating = true
    
    // 🔥 CRITICAL: Clear any existing duty state BEFORE generating test trip
    clearDutyState()
    
    testResult = "🚀 Starting test trip generation...\n"
    testResult += "✅ Cleared existing duty state\n"
    
    // ... rest of generation logic
}

private func clearDutyState() {
    // Clear shared duty status
    if let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
        sharedDefaults.removeObject(forKey: "dutyTimeRemaining")
        sharedDefaults.removeObject(forKey: "dutyStartTime")
        sharedDefaults.removeObject(forKey: "currentDutyTripId")
    }
    
    // Clear PilotActivityManager
    // This would require access to the activity manager instance
    print("🧹 Cleared duty state for test trip generation")
}
```

### Fix 5: Add Duty Time Display with Validation

Create a dedicated view for duty time display with error checking:

```swift
struct DutyTimeDisplay: View {
    let trip: Trip
    @State private var validationWarning: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(validationWarning == nil ? .green : .orange)
                
                Text("Flight Duty Period")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Duty Time:")
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formattedDutyTime)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(validationWarning == nil ? .white : .orange)
            }
            
            if let warning = validationWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Detailed breakdown
            if let start = trip.effectiveDutyStartTime,
               let end = trip.effectiveDutyEndTime {
                VStack(alignment: .leading, spacing: 4) {
                    DetailRow(label: "Duty Start", value: formatTime(start))
                    DetailRow(label: "Duty End", value: formatTime(end))
                    
                    if let firstOut = trip.legs.first?.outTime {
                        DetailRow(label: "First OUT", value: firstOut)
                    }
                    if let lastIn = trip.legs.last?.inTime {
                        DetailRow(label: "Last IN", value: lastIn)
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .onAppear {
            validateDutyTime()
        }
    }
    
    private var formattedDutyTime: String {
        let hours = trip.totalDutyHours
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return String(format: "%dh %02dm", h, m)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func validateDutyTime() {
        let hours = trip.totalDutyHours
        
        // Sanity checks
        if hours == 0 {
            validationWarning = "No duty time calculated"
        } else if hours > 16 {
            validationWarning = "⚠️ Exceeds maximum duty time (>16h)"
        } else if hours > 14 {
            validationWarning = "Approaching maximum duty time"
        } else if hours < 0.5 && !trip.legs.isEmpty {
            validationWarning = "Duty time suspiciously low"
        }
    }
    
    struct DetailRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label + ":")
                Spacer()
                Text(value)
            }
        }
    }
}
```

---

## 📊 FAR 117 Compliance Reference

### Maximum Flight Duty Period (FDP) Limits

| Flights in Duty Period | Unaugmented Crew | Augmented Crew (3 pilots) | Augmented Crew (4 pilots) |
|------------------------|------------------|---------------------------|---------------------------|
| 1-2                    | 9-13 hours*      | 15-17 hours*              | 17-19 hours*              |
| 3                      | 9-13 hours*      | 15-17 hours*              | 17-19 hours*              |
| 4                      | 9-12 hours*      | 15-16 hours*              | 17-18 hours*              |
| 5                      | 9-12 hours*      | 15-16 hours*              | 16-18 hours*              |
| 6                      | 9-12 hours*      | 15-16 hours*              | 16-18 hours*              |
| 7+                     | 9-12 hours*      | 15-16 hours*              | 16-18 hours*              |

*Varies by time of day (circadian rhythm table)

### Rest Requirements
- **Minimum Rest**: 10 hours between duty periods
- **Reduced Rest**: Minimum 8 hours (limited occasions)
- **Consecutive Nighttime Rest**: Must include 3-hour window between 0100-0700 local time

### Cumulative Limits
- **100 hours**: Flight time per 672-hour (28-day) period
- **190 hours**: Duty time per 672-hour period
- **60 hours**: Flight time per 168-hour (7-day) period

---

## 🧪 Testing Recommendations

### Test Cases to Run

#### 1. Basic Duty Calculation Test
```
Trip: Single leg, same day
OUT: 1000L
IN: 1200L
Expected Duty: 0900L to 1215L = 3h 15m
```

#### 2. Multi-Leg Same Day
```
Trip: 3 legs, no overnight
Leg 1: OUT 0800L, IN 0900L
Leg 2: OUT 1000L, IN 1100L
Leg 3: OUT 1200L, IN 1300L
Expected Duty: 0700L to 1315L = 6h 15m
```

#### 3. Overnight Trip
```
Trip: 2 legs, crosses midnight
Leg 1: OUT 2200L Day 1, IN 2300L Day 1
Leg 2: OUT 0100L Day 2, IN 0200L Day 2
Expected Duty: 2100L Day 1 to 0215L Day 2 = 4h 15m
```

#### 4. Test Trip from NOC Tester
```
Trip: YIP→DTW→CLE→YIP
Duration: ~3h 50m
Expected Duty: ~4h 45m to 5h 0m
ACTUAL: 22/8h ❌
```

### Debug Checklist
1. ✅ Add console logging to `totalDutyHours`
2. ✅ Validate time parsing doesn't add 24h incorrectly
3. ✅ Check `scheduledOut` and `scheduledIn` are set
4. ✅ Verify duty state is cleared between test trips
5. ✅ Confirm UTC/Local time zone handling
6. ✅ Test with flights starting in next 1h, 2h, 4h, 8h, 24h
7. ✅ Validate overnight flights don't break calculation

---

## 🎯 Action Items

### Immediate (High Priority)
1. **Add debug logging** to `totalDutyHours` and time parsing functions
2. **Run NOC Trip Tester** with console open to capture logs
3. **Verify scheduled times** are being set correctly in test trip
4. **Check for duty state contamination** between test runs

### Short Term (This Sprint)
1. **Implement validation warnings** in duty time display
2. **Add unit tests** for duty time calculations
3. **Fix overnight calculation** if that's the root cause
4. **Add duty time sanity checks** (>16h warning)

### Long Term (Future Enhancement)
1. **Implement full FAR 117 compliance checking**
2. **Add duty time limits with visual warnings**
3. **Create duty period report/history**
4. **Integrate with crew scheduling for automatic duty tracking**

---

## 📝 Notes

### Current Display Format
The "22/8h" format suggests:
- First number: Total duty hours?
- Second number: Remaining duty hours?
- **Need to identify where this format is generated**

### Search for Display Code
```swift
// Need to find where "22/8h" or similar format is created
// Likely in:
// - DataEntryView.swift (duty timer section)
// - LogbookView.swift (current duty period section)
// - PilotActivityManager or related components
```

### Time Zone Handling
All times should be converted to **local time** for duty calculations, as FAR 117 is based on local time of operations, not UTC.

---

## 🔗 Related Files

- `Trip.swift` - Core duty time logic (lines 124-452)
- `NOCTestView.swift` - Test trip generation (lines 1-955)
- `DataEntryView.swift` - Duty timer UI (lines 329-400)
- `OffDutyStatusManager.swift` - Off-duty status tracking
- `PilotActivityManager.swift` - Live activity management (NOT YET VIEWED)
- `RosterToTripHelper.swift` - Roster to trip conversion (NOT YET VIEWED)

---

**Document Created**: December 25, 2025  
**Last Updated**: December 25, 2025  
**Status**: 🚨 CRITICAL BUG IDENTIFIED - Investigation Required

# Debug Logging Added for FDP Issue

## Summary
Added comprehensive debug logging to troubleshoot the "22/8h" duty time calculation bug in the NOC Trip Tester.

## Files Modified

### 1. Trip.swift

#### A. `totalDutyHours` computed property
**Location**: Line ~392

**What was added**:
- Detailed console output showing:
  - Trip number and date
  - Duty start and end times (formatted for readability)
  - Time interval in seconds and minutes
  - Total hours calculation
  - Formatted display (Xh Ym)
  - All leg details (departure, arrival, times)
  - Scheduled times for first and last legs
  
**Warning checks**:
- ⚠️ If duty > 16 hours: Prints error with additional debug info
- ⚠️ If duty < 0.5 hours with legs present: Prints suspicion warning

**Example output**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 FDP Calculation for Trip TEST-1234
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Trip Date: 2025-12-25 10:00:00
   Duty Start: 2025-12-25 09:00:00
   Duty End:   2025-12-25 13:15:00
   Interval: 15300 seconds (255.0 minutes)
   Total Hours: 4.25
   Formatted: 4h 15m
   Legs: 3
   First Leg: YIP→DTW
     OUT: 1000
     Scheduled OUT: 2025-12-25 10:00:00 +0000
   Last Leg: CLE→YIP
     IN: 1300
     Scheduled IN: 2025-12-25 13:00:00 +0000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### B. `calculateAutoDutyStart()` function
**Location**: Line ~403

**What was added**:
- Logs when parsing fails (with reason)
- Shows first OUT time string being parsed
- Shows trip date being used
- Displays calculated duty start (OUT - 60min)

**Example output**:
```
🔍 calculateAutoDutyStart:
   First OUT time: 2025-12-25 10:00:00 +0000
   Duty start (OUT - 60min): 2025-12-25 09:00:00 +0000
```

#### C. `calculateAutoDutyEnd()` function
**Location**: Line ~413

**What was added**:
- Logs when parsing fails (with reason)
- Shows last IN time string being parsed
- Shows trip date being used
- Displays calculated duty end (IN + 15min)

**Example output**:
```
🔍 calculateAutoDutyEnd:
   Last IN time: 2025-12-25 13:00:00 +0000
   Duty end (IN + 15min): 2025-12-25 13:15:00 +0000
```

#### D. `parseTimeWithDate()` function
**Location**: Line ~454

**What was added**:
- Logs empty time strings
- Shows invalid time format errors with parsed values
- Displays failed date component creation
- Confirms successful parsing with formatted output

**Example output**:
```
🕐 parseTimeWithDate: '1000' → 2025-12-25 10:00
🕐 parseTimeWithDate: '1300' → 2025-12-25 13:00
```

### 2. NOCTestView.swift

#### A. Test trip leg creation logging
**Location**: Line ~560 (createTestTrip function)

**What was added**:
- Formatted timestamps for scheduledOut/In (HH:mm:ss)
- Display of actual leg OUT/IN times that will be used for duty calc
- Shows the time format being passed to duty calculation

**Example output**:
```
Processing item 1: YIP→DTW
  After createLeg(): YIP→DTW
  Set scheduledOut: 10:00:00
  Set scheduledIn: 10:30:00
  Set rosterSourceId: ABC-123-DEF
  Leg OUT time: '1000'
  Leg IN time: '1030'
  ✅ Leg 1 added to array (total: 1)
```

#### B. Duty hours display in test results
**Location**: Line ~625 (after trip creation)

**What was added**:
- Explicit duty hours calculation call
- Formatted duty display (Xh Ym)
- Error detection for >16h or <0.5h
- Reminder to check console logs

**Example output**:
```
✅ Created Trip #TEST-1234
✅ Added 3 legs

📊 DUTY TIME CALCULATION:
   Total Duty Hours: 4.25
   Formatted: 4h 15m
   ✅ Duty calculation looks reasonable

✅ Restored duty status from NOC

🎉 Test trip ready!
Use GPX Testing to simulate flying it.

💡 Check Xcode console for detailed duty calculation logs.
```

## How to Use This Debug Info

### Step 1: Generate Test Trip
1. Open the app
2. Go to Beta tab → NOC Trip Tester
3. Click "Generate Test Trip"
4. Watch the generation log in the UI

### Step 2: Check Xcode Console
Open Xcode console (⌘ + Shift + C) and look for:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 FDP Calculation for Trip TEST-XXXX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Analyze the Output

#### Look for these issues:

**1. Overnight Calculation Error**
```
⚠️ WARNING: Duty hours exceed 16! Possible calculation error.
   Duty Start: 2025-12-25 10:00:00
   Duty End:   2025-12-26 10:00:00  ← Added 24 hours incorrectly!
   Total Hours: 24.0
```

**2. Wrong Date Reference**
```
🕐 parseTimeWithDate: '1000' → 2025-12-26 10:00  ← Should be 12-25!
```

**3. Empty or Invalid Times**
```
⚠️ parseTimeWithDate: Empty time string
⚠️ calculateAutoDutyStart: Cannot parse first leg OUT time
   First leg OUT time string: ''  ← Empty!
```

**4. Time Zone Issues**
```
   Duty Start: 2025-12-25 09:00:00 +0000  ← UTC
   Duty End:   2025-12-25 18:00:00 -0500  ← Local (EST)
   Total Hours: 14.0  ← Mixing time zones!
```

## Expected Output for Test Trip

For the standard NOC test trip (YIP→DTW→CLE→YIP, ~3h 50m):

```
📊 FDP Calculation for Trip TEST-XXXX
   Total Hours: 4.75 to 5.25  ← Should be around 4-5 hours
```

**NOT:**
```
   Total Hours: 22.0  ← WRONG! Bug confirmed.
```

## Next Steps After Identifying Issue

Once you see the debug output, you'll know:

1. **If hours > 16**: Look at the duty start/end dates - one is probably wrong
2. **If dates don't match**: Time parsing is adding a day incorrectly
3. **If times are empty**: Scheduled data isn't being transferred to legs
4. **If time zones mixed**: UTC/Local conversion issue

Then apply the appropriate fix from `FLIGHT_DUTY_PERIOD_LOGIC_DOCUMENTATION.md`.

## Removing Debug Logging

Once the bug is fixed, you can:

1. **Keep minimal logging** - Just the warning for >16h
2. **Wrap in #if DEBUG** - Only log in debug builds:
   ```swift
   #if DEBUG
   print("📊 FDP Calculation...")
   #endif
   ```
3. **Remove completely** - Delete all print statements

## Performance Impact

- **Negligible**: Only runs when accessing `totalDutyHours`
- **String interpolation**: Lazy evaluation means no impact unless logging
- **Console I/O**: Only visible during development/testing

---

**Created**: December 25, 2025  
**Purpose**: Debug "22/8h" duty calculation bug in NOC Trip Tester  
**Status**: ✅ Ready for testing

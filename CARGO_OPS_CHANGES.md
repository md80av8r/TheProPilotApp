# Changes Made for FAR 121 Cargo Operations

## Problem
Per-FDP indicator was showing "10.2 hrs / 8 hrs" and appearing red, but this wasn't useful because:
- Dispatch pre-screens all trips to keep scheduled time under 8 hours
- Actual block time exceeding 8 hours is normal (weather, delays, etc.)
- The pilot's real concerns are:
  1. **100 hours in rolling 30 days** (primary compliance concern)
  2. 16-hour duty limit during active trip
  3. 60 hours duty in 7 days

## Changes Made

### 1. DutyLimitSettings.swift ✅
**Disabled Per-FDP Flight Limit for Part 121 by default**

```swift
// Both part121Default28Day and part121Default30Day:
perFDPFlightLimit: PerFDPFlightLimit(
    enabled: false,  // ✅ CHANGED FROM true TO false
    dayHours: 9.0,
    nightHours: 8.0,
    resetsAfterRest: true
)
```

**Effect:** New users or users resetting to defaults won't see the Per-FDP flight time indicator.

### 2. ForeFlightLogBookRow.swift ✅
**Changed label from "Per FDP" to "FDP Flt"**

```swift
ConfigurableLimitDisplay(
    label: "FDP Flt",  // ✅ CHANGED from "Per FDP"
    current: currentStatus.currentFDPFlightTime,
    limit: currentStatus.perFDPLimit,
    threshold: settingsStore.configuration.warningThresholdPercent
)
```

**Effect:** If users re-enable the setting, the label is clearer that it tracks flight time, not duty time.

### 3. PER_FDP_LIMIT_EXPLAINED.md ✅
**Updated documentation to reflect cargo operations reality**

Now explains:
- Why dispatch pre-screening makes per-FDP flight tracking redundant
- What metrics actually matter (100h/30d primary)
- How to re-enable if needed

## What Users See Now

### Default Display (Per-FDP Disabled)
```
┌────────────────────────────────────┐
│ Flight Time Limits     [Part 121] │
├────────────────────────────────────┤
│  30d      7d FDP     Annual        │
│ 85/100h   52/60h    856/1000h      │
└────────────────────────────────────┘
```

### During Active Trip
```
┌────────────────────────────────────┐
│ ⏱️ Live Duty Timer        [ACTIVE] │
├────────────────────────────────────┤
│ Duty Time Elapsed:    12:34:56     │
│ Time Remaining:        3:25:04     │
│ ✅ Within limits                   │
└────────────────────────────────────┘
```

### Key Metrics Emphasized
1. **30d rolling flight time** (100h limit) - PRIMARY CONCERN
2. **7d FDP** (60h duty limit)
3. **Annual** (1000h limit)
4. **Live duty timer** (16h per-trip limit)

## Migration for Existing Users

Existing users who already have settings saved will keep their current configuration. They can:

1. **Manually disable** Per-FDP if they want:
   - Settings → Duty Limits → Toggle OFF "Per-FDP Flight Time Limit"

2. **Reset to defaults** to get new configuration:
   - Settings → Duty Limits → "Reset to Part 121 Defaults"

## If Users Want Per-FDP Back

Instructions in `PER_FDP_LIMIT_EXPLAINED.md`:
1. Go to Settings → Duty Limits
2. Enable "Per-FDP Flight Time Limit"
3. It will reappear as "FDP Flt" indicator

## Summary

✅ **Per-FDP flight tracking disabled by default** (dispatch handles pre-screening)  
✅ **Clearer label** ("FDP Flt" instead of "Per FDP")  
✅ **Focus on what matters**: 100h/30d, live duty timer, 7d FDP  
✅ **Documentation explains cargo operations reality**  
✅ **Users can re-enable if needed**

---

**Result:** App now reflects how FAR 121 cargo operations actually work, focusing on the metrics pilots can control and care about.

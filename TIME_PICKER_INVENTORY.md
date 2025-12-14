# Complete Time Picker Inventory & Issues

## 🎯 Summary of Current Issues

1. **Watch picker shows AM/PM even in Zulu mode** ❌
2. **Watch display shows Zulu time even when set to Local** ❌
3. **iPhone Active Trip Banner picker works correctly** ✅
4. **Storage is fragmented across 3 different locations** ❌

---

## ⏰ ALL TIME PICKERS IN THE SYSTEM

### iPhone Pickers

#### 1. TranslucentTimePicker.swift ✅ WORKING
**File:** `TranslucentTimePicker.swift`
**Lines:** 73-80
**Status:** ✅ **FULLY WORKING**

```swift
DatePicker("Time", selection: $selectedTime, displayedComponents: [.hourAndMinute])
    .datePickerStyle(.wheel)
    .labelsHidden()
    .environment(\.timeZone, displayTimeZone)
    .environment(\.locale, Locale(identifier: "en_GB"))  // Always 24-hour
```

**Why It Works:**
- Always uses `en_GB` locale → Forces 24-hour format ✅
- Accepts `useZuluTime` parameter to control timezone ✅
- Display formatter (line 153) respects timezone ✅

**Used By:**
- `ActiveTripBannerView.swift` (line 282) ✅  
- `SmartTimeEntryField.swift` (line 219) ✅

**Storage Used:** `AutoTimeSettings.shared.useZuluTime` (wrong storage, but picker works)

---

#### 2. SmartTimeEntryField.swift ⚠️ MIXED
**File:** `SmartTimeEntryField.swift`
**Lines:** 219 (uses TranslucentTimePicker)
**Status:** ⚠️ **Picker works, but utility functions use wrong storage**

**Picker:**
```swift
TranslucentTimePicker(
    timeType: label,
    initialTime: selectedTime,
    useZuluTime: AutoTimeSettings.shared.useZuluTime,  // ← Wrong storage!
    onTimeSet: { ... }
)
```

**Issues:**
- Line 147: `TimeDisplayUtility.getPickerTimeZone()` uses wrong storage
- Line 179: `TimeDisplayUtility.parseTime()` uses wrong storage
- Line 221: `TimeDisplayUtility.getTimeFormatLabel()` uses wrong storage
- Line 225: `TimeDisplayUtility.getTimeZoneLabel()` uses wrong storage

**Fix:** Replace all `TimeDisplayUtility` calls with direct App Group access

---

### Watch Pickers

#### 3. WatchSmartTimePicker.swift ❌ BROKEN
**File:** `WatchSmartTimePicker.swift`  
**Lines:** 95-102 (main picker), 359-373 (compact picker)
**Status:** ❌ **SHOWS AM/PM EVEN IN ZULU MODE**

```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true

// Picker implementation (line 95-102)
DatePicker("", selection: $tempTime, displayedComponents: [.hourAndMinute])
    .datePickerStyle(.wheel)
    .labelsHidden()
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
    .frame(height: 120)
```

**Problem:**
- Storage is CORRECT (uses App Group) ✅
- `en_GB` locale SHOULD force 24-hour ✅
- BUT user reports it still shows AM/PM ❌

**Possible Causes:**
1. `useZuluTime` not updating when toggle changes
2. watchOS caching the picker configuration
3. `Locale.current` overriding `en_GB` somehow

**Display Formatters:**
- Line 241: `formatTime()` - CORRECT ✅
- Line 255: `formatTimeWithSeconds()` - CORRECT ✅
- Line 414: `formatTime()` in WatchCompactTimePicker - CORRECT ✅

---

#### 4. FlightTimesWatchView.swift → CompactSmartTimeButton ❌ PICKER BROKEN
**File:** `FlightTimesWatchView.swift`
**Lines:** 682-718 (picker sheet)
**Status:** ❌ **DISPLAY WORKS, PICKER BROKEN**

```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true

// Display (line 582-597) - THIS WORKS ✅
var timeString: String {
    guard let time = time else { return "--:--" }
    let formatter = DateFormatter()
    
    if useZuluTime {
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
    } else {
        formatter.dateFormat = "h:mm"  // 12-hour for local
        formatter.timeZone = TimeZone.current
    }
    return formatter.string(from: time)
}

// Picker (line 707-715) - THIS IS BROKEN ❌
DatePicker("", selection: $tempTime, displayedComponents: [.hourAndMinute])
    .datePickerStyle(.wheel)
    .labelsHidden()
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, Locale(identifier: "en_GB"))  // ← Should be 24-hour!
    .frame(height: 100)
```

**Analysis:**
- Display formatter works correctly ✅
- Shows UTC/Local badge correctly ✅
- Picker uses `en_GB` which should be 24-hour ✅
- BUT still shows AM/PM ❌

---

#### 5. FlightTimesWatchView.swift → CompletedLegPageView ✅ DISPLAY ONLY
**File:** `FlightTimesWatchView.swift`
**Lines:** 524-540
**Status:** ✅ **WORKING** (no picker, display only)

```swift
private func formatTime(_ date: Date?) -> String {
    guard let date = date else { return "--:--" }
    let formatter = DateFormatter()
    
    if useZuluTime {
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
    } else {
        formatter.dateFormat = "h:mm"
        formatter.timeZone = TimeZone.current
    }
    return formatter.string(from: date)
}
```

---

## 🐛 SPECIFIC REPORTED ISSUES

### Issue A: Active Trip Banner Picker Working ✅
**User says:** "the time picker for the active trip banner is working correctly showing the 23 hour"

**Analysis:**
- Uses `TranslucentTimePicker.swift` ✅
- Always uses `Locale(identifier: "en_GB")` ✅
- This is the ONLY picker working correctly!

---

### Issue B: Watch Display Shows Zulu Even in Local Mode ❌
**User says:** "the watch however still displays the Zulu time even though the time is showing local time"

**Affected:**
- `FlightTimesWatchView.swift` → `CompactSmartTimeButton.timeString`
- `WatchSmartTimePicker.swift` → display formatters

**Diagnosis:**
The formatters look correct. Possible issues:
1. View not re-rendering when `useZuluTime` changes
2. State not propagating to formatters
3. `@AppStorage` not triggering updates

**Fix:**
Add explicit refresh triggers:
```swift
.onChange(of: useZuluTime) { oldValue, newValue in
    // Force view refresh
}
```

---

### Issue C: Watch Picker Shows AM/PM Regardless ❌
**User says:** "the picker still shows am pm regardless"

**Affected:**
- `WatchSmartTimePicker.swift` (both pickers)
- `FlightTimesWatchView.swift` → `CompactSmartTimeButton` picker

**Current Code:**
```swift
.environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
```

**Problem:**
The `en_GB` locale SHOULD force 24-hour format, but watchOS is ignoring it.

**Possible Solutions:**

**Option 1: Always Use 24-Hour (Recommended)**
```swift
.environment(\.locale, Locale(identifier: "en_GB"))  // Always 24-hour
.environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
```

**Option 2: Force picker recreation**
```swift
DatePicker(...)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
    .id(useZuluTime)  // Recreate picker when this changes
```

**Option 3: Check user's 24-hour preference**
```swift
// Check if user has 24-hour enabled in device settings
let uses24Hour = Calendar.current.locale?.uses24HourClock ?? true

.environment(\.locale, uses24Hour ? Locale(identifier: "en_GB") : Locale.current)
```

---

## 📊 STORAGE COMPARISON

### What Each Component Uses:

| Component | Storage Used | Correct? |
|-----------|-------------|----------|
| `WatchSettingsView` | App Group ✅ | ✅ YES |
| `WatchSmartTimePicker` | App Group ✅ | ✅ YES |
| `FlightTimesWatchView` | App Group ✅ | ✅ YES |
| `TranslucentTimePicker` | AutoTimeSettings ❌ | ❌ NO |
| `SmartTimeEntryField` | TimeDisplayUtility ❌ | ❌ NO |
| `ActiveTripBannerView` | AutoTimeSettings ❌ | ❌ NO |
| `TimeDisplayUtility` | UserDefaults.standard ❌ | ❌ NO |
| `AutoTimeSettings` | Separate storage ❌ | ❌ NO |

### The Problem:
```
3 Different Storage Locations:
1. UserDefaults(suiteName: "group.com.propilot.app") ← CORRECT ✅
2. AutoTimeSettings observable object ← WRONG ❌
3. UserDefaults.standard ← WRONG ❌
```

---

## 🔧 FIXES NEEDED

### Fix 1: Unify All Storage to App Group (CRITICAL)

#### A. Update AutoTimeSettings.swift
```swift
class AutoTimeSettings: ObservableObject {
    static let shared = AutoTimeSettings()
    
    // CHANGE from separate storage to App Group
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    var useZuluTime: Bool = true
    
    @AppStorage("roundTimesToFiveMinutes", store: UserDefaults(suiteName: "group.com.propilot.app"))
    var roundTimesToFiveMinutes: Bool = false
    
    // ... other settings
}
```

#### B. Update TimeDisplayUtility.swift
```swift
private static var useZuluTime: Bool {
    guard let appGroup = UserDefaults(suiteName: "group.com.propilot.app") else {
        return true  // Default to Zulu
    }
    return appGroup.bool(forKey: "useZuluTime")
}
```

#### C. Update SmartTimeEntryField.swift
```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true

// Replace TimeDisplayUtility calls:
// BEFORE: TimeDisplayUtility.getPickerTimeZone()
// AFTER: useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
```

---

### Fix 2: Fix Watch Picker AM/PM Issue (HIGH PRIORITY)

#### Solution 1: Always Use 24-Hour (RECOMMENDED)
Since all pilots work in 24-hour format, simplify:

**WatchSmartTimePicker.swift:**
```swift
DatePicker("", selection: $tempTime, displayedComponents: [.hourAndMinute])
    .datePickerStyle(.wheel)
    .labelsHidden()
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, Locale(identifier: "en_GB"))  // ALWAYS 24-hour
    .frame(height: 120)
```

**FlightTimesWatchView.swift:**
```swift
DatePicker("", selection: $tempTime, displayedComponents: [.hourAndMinute])
    .datePickerStyle(.wheel)
    .labelsHidden()
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, Locale(identifier: "en_GB"))  // ALWAYS 24-hour (keep existing)
    .frame(height: 100)
```

Then the toggle ONLY changes timezone (UTC ↔ Local), not the format.

#### Solution 2: Force Picker Refresh
```swift
DatePicker(...)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
    .id(useZuluTime)  // Force recreation
```

---

### Fix 3: Fix Watch Display Not Updating (MEDIUM PRIORITY)

Add explicit change handlers:

**WatchSmartTimePicker.swift:**
```swift
var body: some View {
    VStack {
        // ... existing code
    }
    .onChange(of: useZuluTime) { oldValue, newValue in
        print("⌚ Zulu/Local changed: \(newValue ? "Zulu" : "Local")")
        // View will auto-refresh formatters
    }
}
```

**FlightTimesWatchView.swift:**
```swift
var body: some View {
    TabView {
        // ... existing code
    }
    .onChange(of: useZuluTime) { oldValue, newValue in
        print("⌚ Time display mode changed: \(newValue ? "Zulu" : "Local")")
    }
}
```

---

## 🎯 RECOMMENDED ACTION PLAN

### Phase 1: Storage (Do First)
1. ✅ Update `AutoTimeSettings` to use App Group
2. ✅ Update `TimeDisplayUtility` to use App Group
3. ✅ Update `SmartTimeEntryField` to use App Group directly
4. ✅ Test iPhone/Watch sync

### Phase 2: Watch Pickers (Do Second)
1. ✅ Change all watch pickers to ALWAYS use `en_GB` (24-hour)
2. ✅ Remove conditional locale (simplify)
3. ✅ Test picker shows 24-hour format
4. ✅ Test timezone changes correctly

### Phase 3: Display Updates (Do Third)
1. ✅ Add `.onChange(of: useZuluTime)` to watch views
2. ✅ Test display updates when toggle changes
3. ✅ Test times display in correct timezone

### Phase 4: Polish (Do Last)
1. ✅ Add migration code for existing users
2. ✅ Add debug logging
3. ✅ Update documentation
4. ✅ End-to-end testing

---

## 🧪 TESTING SCENARIOS

### Test 1: Storage Sync
```
1. Open Watch Settings → Toggle to Local ❌
2. Check iPhone AutoTimeSettings view → Should show Local ❌
3. Open iPhone Settings → Toggle to Zulu ❌
4. Check Watch display → Should show Zulu ❌
```

### Test 2: Watch Picker Format
```
1. Open Watch Settings → Set to Zulu ❌
2. Long-press OUT time → Should show 0-23 hours ❌
3. Toggle to Local ❌
4. Long-press OUT time → Should show 0-23 hours (simplified) ✅
```

### Test 3: Watch Display Timezone
```
1. Set time 14:00 in Zulu mode
2. Toggle to Local (PST = UTC-8)
3. Should display 6:00 AM or 06:00 ❌
4. Toggle back to Zulu
5. Should display 14:00 ❌
```

### Test 4: iPhone Picker (Control)
```
1. Open Active Trip Banner
2. Long-press time field
3. Should show 24-hour picker ✅ (Already works!)
4. Set time → Should save correctly ✅
```

---

## 📝 SUMMARY

**Working:**
- ✅ `TranslucentTimePicker` (iPhone) - Always 24-hour
- ✅ Watch storage - Uses App Group correctly

**Broken:**
- ❌ Watch pickers - Show AM/PM even with `en_GB`
- ❌ Watch display - Doesn't update when toggle changes  
- ❌ iPhone storage - Uses wrong UserDefaults
- ❌ Cross-device sync - Different storage locations

**Root Causes:**
1. **Storage fragmentation** - 3 different locations
2. **watchOS locale handling** - `en_GB` not forcing 24-hour
3. **View updates** - Not refreshing when `useZuluTime` changes

**Recommended Fix:**
1. Unify storage to App Group
2. Always use 24-hour format (simplify)
3. Add explicit refresh triggers

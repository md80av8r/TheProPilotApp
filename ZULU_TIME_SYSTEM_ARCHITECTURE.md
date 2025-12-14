# Zulu Time System - Complete Architecture

## Overview
The Zulu/Local time system allows users to toggle between UTC (Zulu) time and Local timezone display across the entire app. This document maps all files involved and how they interact.

---

## 🎛️ Settings & Storage

### 1. **WatchSettingsView.swift** (Apple Watch)
**Location:** Watch app
**Purpose:** Main settings interface on Apple Watch

```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true
```

**Features:**
- Toggle switch with visual indicator (🌐 Zulu / 📍 Local)
- Header: "Time Display"
- Footer: Explanation text
- **Key Detail:** Uses App Group for iPhone/Watch sync: `"group.com.propilot.app"`

**Location in UI:** Settings tab → Time Display section

---

### 2. **AutoTimeSettingsView.swift** (iPhone)
**Location:** iPhone app → Auto Time Logging Settings
**Purpose:** Settings for automatic time logging with Zulu/Local preference

```swift
// Uses AutoTimeSettings observable object
Toggle("Time Format for Auto-Logging", isOn: $autoTimeSettings.useZuluTime)
```

**Features:**
- Toggle for auto-logging time format
- Shows current time preview in selected format
- Section: "Timezone Settings"

**⚠️ ISSUE:** This uses a different storage mechanism than the watch! It's stored in `AutoTimeSettings` object, not App Group UserDefaults.

---

### 3. **TimeDisplayUtility.swift** (Shared Utility)
**Location:** Shared utilities
**Purpose:** Central utility for time formatting

```swift
private static var useZuluTime: Bool {
    return UserDefaults.standard.bool(forKey: "useZuluTime")
}
```

**⚠️ ISSUE:** Uses `UserDefaults.standard`, NOT the App Group! This won't sync between iPhone and Watch.

**Functions:**
- `formatTime(_:includeTimeZone:)` - Formats time based on preference
- `formatDate(_:style:)` - Formats dates
- `formatDateTime(_:dateStyle:includeSeconds:)` - Combined date/time
- `parseTime(_:baseDate:)` - Parses time strings
- SwiftUI extensions for pickers

---

## 📱 Watch Views (Time Display)

### 4. **FlightTimesWatchView.swift**
**Location:** Watch app → Main flight times view
**Purpose:** 2×2 grid for OUT/OFF/ON/IN times

**Uses:**
```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true
```

**Components:**
- `CompactSmartTimeButton` - The 4 time entry buttons
- `CompletedLegPageView` - Shows completed legs
- Both respect `useZuluTime` for display and picker format

**Picker Implementation:**
```swift
DatePicker(...)
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
```

**Visual Indicator:** Shows "ZULU TIME" (blue) or "LOCAL TIME" (orange) badge

---

### 5. **WatchSmartTimePicker.swift**
**Location:** Watch app → Reusable time picker component
**Purpose:** Smart time picker with tap-for-now, long-press-to-edit

**Uses:**
```swift
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true
```

**Components:**
- `WatchSmartTimePicker` - Full featured picker with labels
- `WatchCompactTimePicker` - Compact row style
- `WatchTimePickerGroup` - Group of 4 pickers

**Picker Implementation:**
```swift
DatePicker(...)
    .environment(\.timeZone, useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
```

**Visual Indicator:** Shows "🌐 UTC" (blue) or "📍 Local" (orange) badge in picker sheet

---

## 📊 Storage Architecture

### Current State (PROBLEM)

```
iPhone App:
├─ AutoTimeSettings.useZuluTime (Observable object, persisted separately)
└─ UserDefaults.standard["useZuluTime"] (Used by TimeDisplayUtility)

Watch App:
└─ UserDefaults(suiteName: "group.com.propilot.app")["useZuluTime"]

❌ These are THREE DIFFERENT storage locations!
```

### Expected State (SOLUTION)

```
Shared App Group:
└─ UserDefaults(suiteName: "group.com.propilot.app")["useZuluTime"]
    ├─ Read by iPhone app
    ├─ Read by Watch app
    └─ Automatically syncs between devices
```

---

## 🐛 Known Issues

### Issue 1: Picker Not Switching Format
**Status:** FIXED ✅
**Solution:** Use `Locale(identifier: "en_GB")` for 24-hour format in Zulu mode

### Issue 2: Multiple Storage Locations
**Status:** OPEN ⚠️
**Problem:** 
- Watch uses App Group UserDefaults ✅
- TimeDisplayUtility uses standard UserDefaults ❌
- AutoTimeSettings uses its own storage ❌

**Impact:**
- Settings don't sync between iPhone and Watch
- Inconsistent behavior across the app
- Users have to set preferences twice

### Issue 3: Display Format Inconsistency
**Status:** PARTIALLY FIXED ⚠️
**Problem:**
- Watch views: Fixed to respect toggle
- iPhone views: May still use TimeDisplayUtility (which uses wrong storage)

---

## 🔧 Required Fixes

### Fix 1: Unify Storage (CRITICAL)

**TimeDisplayUtility.swift:**
```swift
// BEFORE (WRONG)
private static var useZuluTime: Bool {
    return UserDefaults.standard.bool(forKey: "useZuluTime")
}

// AFTER (CORRECT)
private static var useZuluTime: Bool {
    if let appGroup = UserDefaults(suiteName: "group.com.propilot.app") {
        return appGroup.bool(forKey: "useZuluTime")
    }
    return true  // Default to Zulu
}
```

**All SwiftUI View Extensions:**
```swift
// BEFORE
let useZulu = UserDefaults.standard.bool(forKey: "useZuluTime")

// AFTER
let useZulu = UserDefaults(suiteName: "group.com.propilot.app")?.bool(forKey: "useZuluTime") ?? true
```

### Fix 2: Consolidate AutoTimeSettings

**AutoTimeSettings.swift** should read/write to App Group:
```swift
class AutoTimeSettings: ObservableObject {
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    var useZuluTime: Bool = true
    
    // ... rest of properties
}
```

### Fix 3: Add iPhone Settings UI

Create a main settings view on iPhone that uses the same storage:
```swift
struct SettingsView: View {
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    // ... UI
}
```

---

## 📋 Testing Checklist

### Unit Tests
- [ ] Verify App Group UserDefaults accessible on both platforms
- [ ] Verify settings persist after app restart
- [ ] Verify settings sync between iPhone and Watch

### UI Tests
- [ ] Toggle on Watch → Check iPhone shows same setting
- [ ] Toggle on iPhone → Check Watch shows same setting
- [ ] Set time in Zulu mode → Verify stored as UTC
- [ ] Set time in Local mode → Verify stored correctly
- [ ] Switch modes → Verify times convert correctly

### Edge Cases
- [ ] First launch (no stored preference) → Defaults to Zulu
- [ ] App Group not available → Fallback behavior
- [ ] Timezone change while app running
- [ ] Date line crossing (UTC day changes)

---

## 🎯 Recommended Actions (Priority Order)

### Priority 1: Fix Storage (CRITICAL)
1. Update `TimeDisplayUtility.swift` to use App Group
2. Update all SwiftUI extensions to use App Group
3. Test sync between iPhone and Watch

### Priority 2: Consolidate Settings
1. Update `AutoTimeSettings` to use App Group storage
2. Remove any duplicate storage mechanisms
3. Add migration code if needed (move old prefs to App Group)

### Priority 3: Add iPhone UI
1. Create or update main settings view on iPhone
2. Match the Watch settings UI/UX
3. Add visual indicators (same icons/colors as Watch)

### Priority 4: Documentation
1. Document the canonical storage location
2. Create code snippets for accessing the setting
3. Update all developer documentation

---

## 💡 Best Practices Going Forward

### Always Use App Group for Shared Settings
```swift
// CORRECT WAY
@AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
private var useZuluTime: Bool = true

// WRONG WAY
@AppStorage("useZuluTime") // Uses .standard
private var useZuluTime: Bool = true
```

### Always Use en_GB Locale for 24-Hour Pickers
```swift
DatePicker(...)
    .environment(\.locale, useZuluTime ? Locale(identifier: "en_GB") : Locale.current)
```

### Always Set Both Timezone and Locale
```swift
DatePicker(...)
    .environment(\.timeZone, displayTimeZone)  // Sets timezone
    .environment(\.locale, displayLocale)       // Sets 12/24 hour format
```

---

## 📚 Related Documentation

- `ZULU_LOCAL_TIME_FIX.md` - Details of the picker format fix
- `WATCH_SYNC_FIXES.md` - Watch connectivity fixes
- App Groups documentation: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups

---

## 🔍 Quick Reference

### Current Working Files
✅ `WatchSettingsView.swift` - Uses App Group correctly
✅ `FlightTimesWatchView.swift` - Uses App Group correctly  
✅ `WatchSmartTimePicker.swift` - Uses App Group correctly

### Files Needing Updates
❌ `TimeDisplayUtility.swift` - Uses UserDefaults.standard
❌ `AutoTimeSettings.swift` - Uses separate storage
❌ Any iPhone settings views - May not exist or use wrong storage

### App Group Identifier
```
group.com.propilot.app
```

Use this identifier consistently across all platforms!

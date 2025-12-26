# Bug Fix: Missing selectedViewType Parameter in SplitView

## Issue
Compiler error when building the project:
```
error: Missing argument for parameter 'selectedViewType' in call
Location: ScheduleCalendarView.swift:2034:41
```

## Root Cause
The `SplitView` struct was calling `MonthView` without passing the newly required `selectedViewType` binding parameter. This parameter was added as part of the interactive navigation feature that allows:
- Tapping weekday headers to switch to Week view
- Tapping day cells to switch to List view

## Files Modified
- `ScheduleCalendarView.swift`

## Changes Made

### 1. Updated `SplitView` struct signature
**Added:**
```swift
@Binding var selectedViewType: ScheduleViewType?  // NEW: For switching views
```

**Before:**
```swift
struct SplitView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var logbookStore: LogBookStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    // ... missing binding
}
```

**After:**
```swift
struct SplitView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var logbookStore: LogBookStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    @Binding var selectedViewType: ScheduleViewType?  // ✅ Added
}
```

### 2. Updated `MonthView` call in `SplitView`
**Before:**
```swift
MonthView(
    scheduleStore: scheduleStore,
    logbookStore: logbookStore,
    currentDate: $currentDate,
    alarmManager: alarmManager,
    onItemTap: onItemTap
    // Missing: selectedViewType parameter
)
```

**After:**
```swift
MonthView(
    scheduleStore: scheduleStore,
    logbookStore: logbookStore,
    currentDate: $currentDate,
    alarmManager: alarmManager,
    onItemTap: onItemTap,
    selectedViewType: $selectedViewType  // ✅ Added
)
```

### 3. Updated `SplitView` instantiation in main view
**Before:**
```swift
case .split:
    SplitView(
        scheduleStore: scheduleStore,
        logbookStore: logbookStore,
        currentDate: $currentDate,
        alarmManager: alarmManager,
        onItemTap: { selectedItem = $0 }
        // Missing: selectedViewType binding
    )
```

**After:**
```swift
case .split:
    SplitView(
        scheduleStore: scheduleStore,
        logbookStore: logbookStore,
        currentDate: $currentDate,
        alarmManager: alarmManager,
        onItemTap: { selectedItem = $0 },
        selectedViewType: $selectedViewType  // ✅ Added
    )
```

## Impact
- ✅ **Split View** now fully supports interactive month navigation
- ✅ Users can tap weekday headers in Split View to switch to Week view
- ✅ Users can tap day cells in Split View to switch to List view
- ✅ Maintains consistency with standalone Month view behavior
- ✅ No breaking changes to other view types

## Testing
After this fix:
1. ✅ Project compiles without errors
2. ✅ Split View displays correctly
3. ✅ Month calendar in Split View is interactive
4. ✅ Navigation between views works smoothly
5. ✅ No crashes or runtime errors

## Related Features
This fix ensures the Split View benefits from the interactive navigation features added in:
- `MONTH_VIEW_NAVIGATION_UPDATE.md` - Interactive month calendar navigation
- `SCHEDULE_VIEW_REORDER_SUMMARY.md` - Custom view ordering

---

**Status:** ✅ Fixed  
**Build Status:** ✅ Compiles successfully  
**Feature Status:** ✅ Fully functional

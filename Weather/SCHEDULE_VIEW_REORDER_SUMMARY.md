# Schedule View Reordering Feature

## Summary
Added the ability for users to customize the order of schedule views in the Schedule Tab, with their preferred view appearing first when they open the tab.

## What Changed

### 1. **ScheduleViewType Enum** (Enhanced)
- Made `ScheduleViewType` conform to `Codable` and `Identifiable`
- Added `id` property for SwiftUI list iteration
- Now supports saving/loading from UserDefaults

### 2. **ScheduleViewPreferenceManager** (New)
```swift
class ScheduleViewPreferenceManager: ObservableObject
```
- Singleton manager that persists view order to UserDefaults
- `orderedViews` property contains user's custom order
- Automatically merges new view types if added in future updates
- Provides `move(from:to:)` function for reordering

### 3. **ScheduleCalendarView** (Updated)
- Added `@StateObject private var viewPreferences = ScheduleViewPreferenceManager.shared`
- Changed `selectedViewType` from fixed `.list` to optional (nil = use first from ordered list)
- Added computed property `activeViewType` that returns current view
- Added `@State private var showingViewOrderEditor` sheet
- All references to `selectedViewType` updated to use `activeViewType`

### 4. **Header View Menu** (Enhanced)
- Menu now iterates through `viewPreferences.orderedViews` instead of `ScheduleViewType.allCases`
- Shows checkmark next to currently selected view
- Added "Customize Order..." menu item with grab icon
- Tapping this opens the view order editor

### 5. **ScheduleViewOrderEditor** (New View)
```swift
struct ScheduleViewOrderEditor: View
```
- Full-screen sheet for reordering views
- Drag handles (≡) on the left of each row
- Shows view icon, name, description, and position number
- Position #1 is highlighted in green (this is the default view)
- Cancel/Save buttons in navigation bar
- Reset to Default button in bottom toolbar
- Instructions at top explain what reordering does

## User Experience

### When User Opens Schedule Tab
1. The view at position #1 in their custom order appears
2. If they haven't customized yet, List view appears (default order)

### Customizing View Order
1. Tap the view selector dropdown (e.g., "List ▼")
2. Scroll to bottom and tap "Customize Order..." with grab icon
3. Drag views up/down using the ≡ handles
4. Position #1 gets green highlight (this is what shows first)
5. Tap "Save" to keep changes or "Cancel" to discard
6. "Reset to Default" button restores original order

### Example Use Case
**Pilot who prefers Month view:**
1. Opens Schedule tab → sees List view (default)
2. Taps "List ▼" dropdown
3. Selects "Customize Order..."
4. Drags "Month" to position #1
5. Taps "Save"
6. **Next time they open Schedule tab → Month view appears first!**

## Technical Details

### Persistence
- Saved to UserDefaults with key: `"scheduleViewOrder"`
- Uses JSON encoding for type safety
- Survives app restarts
- Per-device setting (not synced)

### Data Structure
```swift
// Saved as JSON array:
["Month", "List", "Week", "Agenda", ...]
```

### Migration
- If old version had no saved order → uses default (allCases)
- If new view types added → automatically appended to user's order
- Backwards compatible with existing installations

### Visual Feedback
- Current view shows checkmark in menu
- Position #1 has green badge and background in editor
- Drag handles provide clear affordance for reordering
- Live position numbers update as user drags

## Code Locations

### Main Files Modified
- `ScheduleCalendarView.swift` (all changes in one file)

### Key Components Added
1. `ScheduleViewPreferenceManager` class (line ~70)
2. `ScheduleViewOrderEditor` view (line ~2650)
3. Updated `headerView` with customize option
4. Updated main view to use preference manager

## Testing Recommendations

1. **First Launch**: Verify List view shows by default
2. **Reorder**: Drag Month to #1, save, restart app → Month should appear
3. **Menu**: Check that views appear in custom order in dropdown
4. **Reset**: Verify "Reset to Default" restores original order
5. **Cancel**: Make changes but tap Cancel → changes not saved
6. **Multiple Changes**: Reorder multiple times, verify persistence

## Future Enhancements

Possible additions:
- Show view preview thumbnails in editor
- Allow hiding unused views
- Set different default views for iPad vs iPhone
- Quick "Set as Default" action in menu
- Animation when switching between reordered views

---

## Before/After Comparison

### Before
```
Schedule Tab Opens → Always shows List view
Menu → Shows views in fixed order (List, Agenda, Week...)
No customization possible
```

### After
```
Schedule Tab Opens → Shows user's favorite view (#1 in their order)
Menu → Shows views in user's custom order
"Customize Order..." option → Full drag-and-drop editor
Preferences persist across app launches
```

---

**Result**: Pilots who prefer monthly calendar or any other view no longer need to switch views every time they open the Schedule tab. Their preferred view appears first!

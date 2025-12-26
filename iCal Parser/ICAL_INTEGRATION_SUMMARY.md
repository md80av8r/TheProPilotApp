# iCalendar Import Integration Summary

## Overview
Successfully integrated the iCalendar import functionality into ProPilot App. This allows users to import their airline schedules from different NOC systems and map the fields to the app's data structure.

## Files Created

### 1. **ImportMappingStore.swift**
- Manages saved import mapping templates
- Stores mappings in UserDefaults
- Provides default USA Jet RAIDO mapping
- Methods: `loadMappings()`, `save()`, `delete()`, `setDefault()`

### 2. **ImportMappingSettingsView.swift**
- UI for managing saved import templates
- Shows list of saved mappings with field count
- Allows creating, editing, and deleting mappings
- Shows default mapping with checkmark indicator

### 3. **ICalendarParser.swift**
- Parses raw iCalendar (.ics) files into structured ICalEvent objects
- Returns Result type with success or failure
- Handles line folding and escaped characters
- Extracts: UID, SUMMARY, DESCRIPTION, LOCATION, DTSTART, DTEND, etc.

### 4. **FieldExtractor.swift**
- Contains `FieldExtractor` class for extracting field values based on mapping rules
- Contains `TimeExtractor` class for extracting times from event descriptions
- Supports regex patterns, line numbers, transformations
- Extracts CI, STD, STA, CO times in Zulu format

## Files Modified

### 1. **ProPilotApp.swift**
**Changes:**
- Added `@StateObject private var importMappingStore = ImportMappingStore()`
- Added `.environmentObject(importMappingStore)` to ContentView

**Location:** Lines 16-17, 48

### 2. **ScheduleCalendarView.swift**
**Changes:**
- Added `@EnvironmentObject var importMappingStore: ImportMappingStore`
- Added `@State private var showImportWizard = false`
- Added toolbar button for "Import Schedule" with calendar.badge.plus icon
- Added `.sheet(isPresented: $showImportWizard)` to show wizard
- Added `quickImport(fileURL:)` extension for power users with default mappings

**Location:** Lines 108-119 (properties), 155-161 (toolbar), 189-195 (sheet), 2624-2670 (extension)

### 3. **ICalendarImportWizardView.swift**
**Changes:**
- Added `@EnvironmentObject var logbookStore: LogBookStore`
- Added `@EnvironmentObject var importMappingStore: ImportMappingStore`
- Added `.onAppear` block to set viewModel references and load mappings
- Added properties to ImportWizardViewModel: `logbookStore`, `mappingStore`
- Added `loadSavedMappings()` method
- Updated `performImport()` to save trips using `logbookStore.saveTrip()`
- Updated `canProceed` and `nextButtonTitle` for import completion
- Added dismiss action when import is complete

**Location:** Lines 14-20 (environment objects), 59-64 (onAppear), 115-118 (properties), 145-155 (loadSavedMappings), 261-275 (performImport)

## Integration Points

### 1. **App Entry Point**
```swift
// In ProPilotApp.swift
@StateObject private var importMappingStore = ImportMappingStore()
.environmentObject(importMappingStore)
```

### 2. **NOC Schedule View**
```swift
// In ScheduleCalendarView.swift
ToolbarItem(placement: .primaryAction) {
    Button {
        showImportWizard = true
    } label: {
        Label("Import Schedule", systemImage: "calendar.badge.plus")
    }
}
```

### 3. **Import Wizard**
```swift
// In ICalendarImportWizardView.swift
.onAppear {
    viewModel.logbookStore = logbookStore
    viewModel.mappingStore = importMappingStore
    viewModel.loadSavedMappings()
}
```

### 4. **Trip Storage**
```swift
// In ImportWizardViewModel.performImport()
for trip in result.createdTrips {
    logbookStore?.saveTrip(trip)
}
```

## User Flow

1. **Access Import**
   - User opens NOC Schedule view
   - Taps "Import Schedule" button in toolbar
   - Import wizard modal appears

2. **Import Process**
   - Step 1: Select .ics file from Files app
   - Step 2: Preview sample events (first 3)
   - Step 3: Map fields (or use saved template)
   - Step 4: Configure filters (flights, deadheads, etc.)
   - Step 5: Preview trips to be created
   - Step 6: Import → saves to CloudKit via LogBookStore

3. **Manage Templates**
   - Access ImportMappingSettingsView from Settings
   - View all saved mapping templates
   - Set default template
   - Create/Edit/Delete templates
   - Default template enables quick import

4. **Quick Import (Power Users)**
   - If default mapping exists, call `quickImport(fileURL:)`
   - Skips wizard, imports directly using default
   - Shows success/error messages

## Key Features

### Import Mapping Configuration
- **Field Mappings**: Map iCal fields to app fields
- **Parsing Rules**: Regex patterns for extracting data
- **Timezone Preferences**: UTC, local, or custom
- **Activity Filters**: Import flights, duty days, days off, rest, deadheads
- **Presets**: USA Jet RAIDO preset included

### Field Extraction
- **Pattern Matching**: Regex-based extraction
- **Line Number**: Extract specific lines from multi-line fields
- **Transformations**: Uppercase, lowercase, trim, etc.
- **Capture Groups**: Extract specific portions of text

### Time Extraction
- **Check-In (CI)**: Show time
- **Scheduled Departure (STD)**: Block out
- **Scheduled Arrival (STA)**: Block in
- **Check-Out/Release (CO)**: Release time
- **Formats**: Zulu and local time display

### Trip Creation
- **Auto-Grouping**: Groups flights into trips based on 24-hour rule
- **Flight Legs**: Creates FlightLeg objects with all extracted data
- **Deadhead Detection**: Marks deadhead legs
- **Aircraft Info**: Extracts tail number and aircraft type
- **Notes**: Preserves additional information

## Testing Checklist

- [ ] Import wizard opens from NOC Schedule toolbar
- [ ] File picker allows selecting .ics files
- [ ] Sample events display correctly
- [ ] Field mappings load from default template
- [ ] Preview shows extracted data
- [ ] Import creates trips in LogBookStore
- [ ] Trips appear in trip list view
- [ ] Trips sync to CloudKit
- [ ] ImportMappingSettingsView displays saved templates
- [ ] Can set default template
- [ ] Quick import works with default template
- [ ] Error handling for invalid files
- [ ] Warning messages for missing data

## Future Enhancements

1. **Cloud-Based Templates**: Store mappings in CloudKit for sync across devices
2. **Template Sharing**: Share custom mappings with crew members
3. **Auto-Detection**: Automatically detect airline/NOC system from file
4. **Advanced Filtering**: More granular control over what to import
5. **Preview All Events**: Show all events before import (currently shows 10)
6. **Edit Mapping in Wizard**: Allow editing field mappings during import
7. **Import History**: Track previous imports and allow re-import
8. **Conflict Resolution**: Handle duplicate trips intelligently

## Dependencies

### Existing Files Used
- `Trip.swift` - Trip and FlightLeg models
- `LogBookStore.swift` - Trip storage and CloudKit sync
- `ImportMapping.swift` - Data models for import configuration
- `ICalendarImportEngine.swift` - Import processing logic
- `ParsedFlightData.swift` - Existing flight parser

### New Dependencies
- `ICalendarParser.swift` - iCal file parsing
- `FieldExtractor.swift` - Field and time extraction
- `ImportMappingStore.swift` - Template storage
- `ImportMappingSettingsView.swift` - Template management UI

## Notes

- All files are in the **iCal Parser Group** in Xcode
- Import functionality is optional - existing app continues to work without it
- Default USA Jet RAIDO mapping is pre-configured
- Mappings are stored in UserDefaults (can be migrated to CloudKit later)
- Import does NOT require NOC credentials - works with exported .ics files
- Complements existing NOC auto-sync feature

## Support

For users with different airlines:
1. Use the Import Mapping Settings to create custom templates
2. Test with sample .ics file from their scheduling system
3. Adjust regex patterns and field mappings as needed
4. Save template for future use
5. Set as default for quick imports

---

**Integration Status:** ✅ Complete
**Testing Status:** 🟡 Pending
**Documentation Status:** ✅ Complete

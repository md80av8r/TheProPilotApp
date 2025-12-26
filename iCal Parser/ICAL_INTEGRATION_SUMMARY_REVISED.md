# iCalendar Import Integration Summary - REVISED

## Overview
Successfully integrated the iCalendar import functionality into ProPilot App. This allows users to import their airline schedules from different NOC systems and map the fields to the app's data structure.

## ✅ Actual Files Created

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

### 3. ~~**ICalendarParser.swift**~~ *(Already exists in iCal Parser group)*
- Parses raw iCalendar (.ics) files into structured ICalEvent objects
- Returns Result type with success or failure
- Handles line folding and escaped characters
- Extracts: UID, SUMMARY, DESCRIPTION, LOCATION, DTSTART, DTEND, etc.
- **Contains FieldExtractor and TimeExtractor classes**

### 4. ~~**FieldExtractor.swift**~~ *(DELETE - Duplicate, already in ICalendarParser.swift)*
- ❌ This file was incorrectly created
- All functionality already exists in `ICalendarParser.swift`

## Files Modified

### 1. **ProPilotApp.swift**
**Changes:**
- Added `@StateObject private var importMappingStore = ImportMappingStore()`
- Added `.environmentObject(importMappingStore)` to ContentView

### 2. **ScheduleCalendarView.swift**
**Changes:**
- Added `@EnvironmentObject var importMappingStore: ImportMappingStore`
- Added `@State private var showImportWizard = false`
- Added toolbar button for "Import Schedule" with calendar.badge.plus icon
- Added `.sheet(isPresented: $showImportWizard)` to show wizard
- Added `quickImport(fileURL:)` extension for power users with default mappings

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

### 4. **ICalendarImportEngine.swift**
**Changes:**
- Fixed to use correct Trip/FlightLeg property names:
  - `trip.legs` (not `trip.flightLegs`)
  - `leg.departure` / `leg.arrival` (not `leg.departureAirport` / `leg.arrivalAirport`)
  - `leg.scheduledOut` / `leg.scheduledIn` (not `leg.departureTimeScheduled` / `leg.arrivalTimeScheduled`)
- Updated Trip initializer to match actual structure
- Updated FlightLeg initializer to match actual structure

### 5. **ICalendarImportExample.swift**
**Changes:**
- Fixed property names to match Trip model:
  - `trip.legs` (not `trip.flightLegs`)
  - `leg.departure` / `leg.arrival` (not `leg.departureAirport` / `leg.arrivalAirport`)
  - `leg.scheduledOut` / `leg.scheduledIn` (not `leg.departureTimeScheduled` / `leg.arrivalTimeScheduled`)

### 6. **ICalDiagnosticView.swift**
**Changes:**
- Renamed `ICalEvent` to `DiagnosticICalEvent` to avoid conflict with ImportMapping.swift

### 7. **LogBookStore.swift**
**Changes:**
- Renamed `ImportResult` to `JSONImportResult` to avoid conflict with ImportMapping.swift
- Updated all references to use `JSONImportResult`

## Correct Data Model Property Names

### Trip Properties
```swift
struct Trip {
    var tripNumber: String
    var aircraft: String
    var date: Date
    var tatStart: String
    var crew: [CrewMember]
    var notes: String
    var legs: [FlightLeg]  // ← NOT flightLegs
    var logpages: [Logpage]
    // ... other properties
}
```

### FlightLeg Properties
```swift
struct FlightLeg {
    var departure: String        // ← NOT departureAirport
    var arrival: String          // ← NOT arrivalAirport
    var flightNumber: String
    var scheduledOut: Date?      // ← NOT departureTimeScheduled
    var scheduledIn: Date?       // ← NOT arrivalTimeScheduled
    var isDeadhead: Bool
    // ... other properties
}
```

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
   - User opens NOC Schedule view (ScheduleCalendarView)
   - Taps "Import Schedule" button in toolbar
   - Import wizard modal appears

2. **Import Process**
   - Step 1: Select .ics file from Files app
   - Step 2: Preview sample events (first 3)
   - Step 3: Map fields (or use saved template)
   - Step 4: Configure filters (flights, deadheads, etc.)
   - Step 5: Preview trips to be created
   - Step 6: Import → saves to LogBookStore → syncs to CloudKit

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

### Field Extraction (from ICalendarParser.swift)
- **Pattern Matching**: Regex-based extraction
- **Line Number**: Extract specific lines from multi-line fields
- **Transformations**: Uppercase, lowercase, trim, etc.
- **Capture Groups**: Extract specific portions of text

### Time Extraction (from ICalendarParser.swift)
- **Check-In (CI)**: Show time
- **Scheduled Departure (STD)**: Block out
- **Scheduled Arrival (STA)**: Block in
- **Check-Out/Release (CO)**: Release time
- **Formats**: Zulu and local time display

### Trip Creation
- **Auto-Grouping**: Groups flights into trips based on 24-hour rule
- **Flight Legs**: Creates FlightLeg objects using correct property names
- **Deadhead Detection**: Marks deadhead legs with `isDeadhead` flag
- **Notes**: Preserves additional information in trip notes

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

### Existing Files Used (from iCal Parser group)
- `ICalendarParser.swift` - **Main parser** (contains FieldExtractor & TimeExtractor)
- `ICalendarImportEngine.swift` - Import processing logic
- `ICalendarImportWizardView.swift` - Import wizard UI
- `ImportMapping.swift` - Data models (ImportMapping, ICalEvent, ImportResult, etc.)
- `ParsedFlightData.swift` - Legacy flight parser (still used by NOC auto-sync)

### From Main App
- `Trip.swift` - Trip and FlightLeg models
- `LogBookStore.swift` - Trip storage and CloudKit sync (uses `JSONImportResult`)

### New Files Created
- `ImportMappingStore.swift` - Template storage
- `ImportMappingSettingsView.swift` - Template management UI

## Conflict Resolutions

### 1. ICalEvent Ambiguity
- **Problem**: Two definitions - one in ImportMapping.swift, one in ICalDiagnosticView.swift
- **Solution**: Renamed diagnostic version to `DiagnosticICalEvent`

### 2. ImportResult Ambiguity
- **Problem**: Two definitions - one in ImportMapping.swift (iCal), one in LogBookStore.swift (JSON)
- **Solution**: Renamed LogBookStore version to `JSONImportResult`

### 3. FieldExtractor/TimeExtractor Duplication
- **Problem**: Created duplicate file when these already existed in ICalendarParser.swift
- **Solution**: Delete `FieldExtractor.swift` - use classes from `ICalendarParser.swift`

## Notes

- All iCal parser files are in the **iCal Parser Group** in Xcode
- Import functionality is **optional** - existing app continues to work without it
- Default USA Jet RAIDO mapping is pre-configured in `ImportMapping.swift`
- Mappings are stored in UserDefaults (can be migrated to CloudKit later)
- Import does **NOT** require NOC credentials - works with exported .ics files
- Complements existing NOC auto-sync feature (doesn't replace it)

## ⚠️ Manual Cleanup Required

**Delete these duplicate files if they exist:**
1. ❌ `FieldExtractor.swift` - DELETE (functionality in ICalendarParser.swift)
2. ❌ `ICalendarParser 2.swift` - DELETE (duplicate)

**Steps:**
1. Open Xcode Project Navigator (`Cmd + 1`)
2. Find files in iCal Parser group
3. Right-click → Delete → Move to Trash
4. Clean Build Folder (`Shift + Cmd + K`)
5. Build (`Cmd + B`)

## Support

For users with different airlines:
1. Use the Import Mapping Settings to create custom templates
2. Test with sample .ics file from their scheduling system
3. Adjust regex patterns and field mappings as needed
4. Save template for future use
5. Set as default for quick imports

---

**Integration Status:** ✅ Complete
**Testing Status:** 🟡 Ready for Testing
**Documentation Status:** ✅ Complete & Revised
**Last Updated:** December 23, 2025

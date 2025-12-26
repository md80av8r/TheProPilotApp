//
//  TimezonePreference.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


# iCalendar Schedule Import System

A complete, customizable system for importing airline crew schedules from iCalendar (.ics) files into TheProPilotApp.

## What This Solves

Different airlines format their NOC schedule exports differently. Instead of coding for every airline's format, this system lets **pilots customize the import** by mapping their airline's specific fields to the app's data structure.

## How It Works

### 1. **Parse the iCalendar File** (`iCalendarParser.swift`)
- Reads standard RFC 5545 iCalendar format
- Handles UTC (Zulu) and local timezones
- Extracts all event fields (SUMMARY, DESCRIPTION, LOCATION, etc.)

### 2. **Map Fields to App Data** (`iCalendarModels.swift`)
- User creates a mapping: "From this iCal field → To this app field"
- Supports regex patterns for extraction
- Example: Extract "UJ227" from "UJ227 LRD-IND"

### 3. **Extract Times with Timezone Support** (`iCalendarParser.swift`)
- Parses times in USA Jet RAIDO format: `CI 1820Z / 1220L`
- Converts to user's preferred timezone (UTC, Home Base, or Aircraft Local)
- Stores both Zulu and Local times

### 4. **Convert to Trips** (`iCalendarImportEngine.swift`)
- Filters events (flights vs. duty days vs. days off)
- Groups consecutive flights into Trips
- Creates FlightLeg objects with all data

### 5. **User Interface** (`ICalendarImportWizardView.swift`)
- 6-step wizard for first-time setup
- Preview before importing
- Save mappings as templates

## USA Jet RAIDO Example

Your NOC exports look like this:

```
BEGIN:VEVENT
SUMMARY:UJ227 (X) LRD-IND
DESCRIPTION:UJ227 LRD - IND
CI 1820Z / 1220L
STD 2045Z / 1445L
STA 2245Z / 1745L
Aircraft: M88 - M88 - M88 - N832US
DTSTART:20251124T182000Z
DTEND:20251124T222500Z
END:VEVENT
```

The system extracts:
- **Flight Number**: "UJ227" from SUMMARY using regex `^UJ\d+`
- **Departure**: "LRD" from SUMMARY using regex `([A-Z]{3})-`
- **Arrival**: "IND" from SUMMARY using regex `-([A-Z]{3})$`
- **Aircraft**: "N832US" from DESCRIPTION
- **Times**: CI, STD, STA with both Zulu and Local

## Key Features

### Timezone Handling
```swift
struct TimezonePreference {
    var preferredTimezone: TimezoneOption  // UTC, Home Base, Aircraft Local, Custom
    var showBothTimezones: Bool            // Display 1820Z/1220L or just one
}
```

### Activity Filters
```swift
struct ActivityFilters {
    var importFlights: Bool = true       // UJ227 LRD-IND
    var importDutyDays: Bool = true      // OND YIP
    var importDaysOff: Bool = false      // OFF YIP
    var importRest: Bool = false         // REST LRD
    var importDeadheads: Bool = true     // DH, GT flights
}
```

### Field Mapping
```swift
iCalFieldMapping(
    sourceField: .summary,              // From SUMMARY field
    targetField: .flightNumber,         // To Flight Number
    extractionRule: ExtractionRule(
        pattern: "^UJ\\d+",             // Regex to extract
        captureGroup: 0
    )
)
```

## Usage

### Quick Import (Preset)
```swift
let fileURL = URL(fileURLWithPath: "schedule.ics")
let result = ICalendarImportEngine.importCalendar(
    icsContent: try String(contentsOf: fileURL),
    using: .usaJetRAIDO  // Built-in USA Jet preset
)

// Result contains:
// - createdTrips: [Trip]
// - successfulImports: Int
// - errors: [ImportError]
```

### Custom Mapping
```swift
var mapping = ImportMapping(name: "My Airline")

// Map fields
mapping.fieldMappings.append(
    iCalFieldMapping(
        sourceField: .summary,
        targetField: .flightNumber,
        extractionRule: ExtractionRule(pattern: "Flight (\\d+)")
    )
)

// Configure timezone
mapping.timezonePreference = TimezonePreference(
    preferredTimezone: .utc,
    showBothTimezones: true
)

// Save for future use
userMappings.append(mapping)
```

### Using the Wizard UI
```swift
.sheet(isPresented: $showImportWizard) {
    ICalendarImportWizardView()
}
```

## Files Overview

1. **iCalendarModels.swift** - All data structures
   - `ImportMapping` - User's custom field mapping configuration
   - `iCalField` / `AppField` - Source and destination fields
   - `TimezonePreference` - Timezone handling options
   - `ActivityFilters` - What types of events to import

2. **iCalendarParser.swift** - File parsing
   - `ICalendarParser` - Parses .ics files into `ICalEvent` objects
   - `TimeExtractor` - Extracts times from description text
   - `FieldExtractor` - Applies regex patterns to extract data

3. **iCalendarImportEngine.swift** - Main import logic
   - Processes events using mapping
   - Determines event types (flight vs. duty vs. off)
   - Groups flights into trips
   - Validates data

4. **ICalendarImportWizardView.swift** - User interface
   - 6-step wizard
   - File selection
   - Field mapping UI
   - Preview before import

5. **ICalendarImportExamples.swift** - Usage examples
   - USA Jet preset example
   - Custom mapping examples
   - Test functions

## Future-Proofing for Other Airlines

When a pilot from a different airline wants to import their schedule:

1. They select their .ics file
2. System shows sample events
3. They map fields visually: "My SUMMARY field → Flight Number"
4. They add regex patterns if needed
5. They save as "My Airline Template"
6. Future imports use saved template

**No code changes needed!**

## Integration with Existing App

This system creates `Trip` and `FlightLeg` objects that match your existing data models. After import:

```swift
for trip in result.createdTrips {
    // Save to CloudKit
    await tripStore.save(trip)
    
    // Each trip has flightLegs with:
    // - flightNumber
    // - departureAirport / arrivalAirport
    // - departureTimeScheduled / arrivalTimeScheduled
    // - aircraftRegistration
}
```

Pilots then use your existing UI to enter actual OOOI times and submit to the company.

## Testing

Run the test examples:
```swift
ICalendarImportExample.testUSAJetParsing()
ICalendarImportExample.testRegexPatterns()
ICalendarImportExample.runFullTest()
```

## Next Steps

1. Add these files to your Xcode project
2. Test with your actual NOC export file
3. Refine the USA Jet preset if needed
4. Add UI to present the import wizard
5. Save imported trips to CloudKit
6. Let pilots test the wizard and give feedback
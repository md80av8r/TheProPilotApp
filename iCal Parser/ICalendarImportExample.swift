//
//  ICalendarImportExample.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import Foundation

// MARK: - Usage Example

class ICalendarImportExample {
    
    // MARK: - Quick Import with USA Jet Preset
    
    static func importUSAJetSchedule(fileURL: URL) -> ImportResult {
        do {
            // Read the iCalendar file
            let icsContent = try String(contentsOf: fileURL)
            
            // Use the USA Jet preset mapping
            let mapping = ImportMapping.usaJetRAIDO
            
            // Import
            let result = ICalendarImportEngine.importCalendar(
                icsContent: icsContent,
                using: mapping
            )
            
            print(result.summary)
            
            return result
        } catch {
            print("Error: \(error)")
            return ImportResult(
                totalEvents: 0,
                successfulImports: 0,
                skippedEvents: 0,
                failedEvents: 0,
                createdTrips: [],
                errors: [],
                warnings: []
            )
        }
    }
    
    // MARK: - Custom Mapping Example
    
    static func createCustomMapping() -> ImportMapping {
        var mapping = ImportMapping(name: "My Custom Airline")
        
        // Map flight number from SUMMARY field
        mapping.fieldMappings.append(
            iCalFieldMapping(
                sourceField: .summary,
                targetField: .flightNumber,
                extractionRule: ExtractionRule(
                    pattern: "Flight (\\d+)", // Captures the number from "Flight 123"
                    captureGroup: 1
                )
            )
        )
        
        // Map departure airport from LOCATION field
        mapping.fieldMappings.append(
            iCalFieldMapping(
                sourceField: .location,
                targetField: .departureAirport,
                extractionRule: ExtractionRule(
                    pattern: "([A-Z]{3})-", // Get first 3-letter code before dash
                    captureGroup: 1
                )
            )
        )
        
        // Map arrival airport from LOCATION field
        mapping.fieldMappings.append(
            iCalFieldMapping(
                sourceField: .location,
                targetField: .arrivalAirport,
                extractionRule: ExtractionRule(
                    pattern: "-([A-Z]{3})", // Get 3-letter code after dash
                    captureGroup: 1
                )
            )
        )
        
        // Map aircraft from DESCRIPTION field
        mapping.fieldMappings.append(
            iCalFieldMapping(
                sourceField: .description,
                targetField: .aircraft,
                extractionRule: ExtractionRule(
                    pattern: "Aircraft: ([N][0-9]+[A-Z]+)",
                    captureGroup: 1
                )
            )
        )
        
        // Configure timezone preference
        mapping.timezonePreference = TimezonePreference(
            preferredTimezone: .utc,
            autoDetectHomeBase: false,
            showBothTimezones: true
        )
        
        // Configure what to import
        mapping.activityFilters.importFlights = true
        mapping.activityFilters.importDutyDays = true
        mapping.activityFilters.importDaysOff = false
        mapping.activityFilters.importRest = false
        mapping.activityFilters.importDeadheads = true
        
        return mapping
    }
    
    // MARK: - Test USA Jet Format
    
    static func testUSAJetParsing() {
        // Sample USA Jet event
        let sampleEvent = """
        BEGIN:VEVENT
        UID:117584
        SUMMARY:UJ227 (X) LRD-IND
        DESCRIPTION:UJ227 LRD - IND\\nCI 1820Z / 1220L\\nSTD 2045Z / 1445L\\nSTA 2245Z / 1745L\\nRD: X\\nDuration: 04:05, BLH: 02:30\\nAircraft: M88 - M88 - M88 - N832US\\n
        DTSTART:20251124T182000Z
        DTEND:20251124T222500Z
        END:VEVENT
        """
        
        // Parse
        let result = ICalendarParser.parse(sampleEvent)
        
        switch result {
        case .success(let events):
            guard let event = events.first else {
                print("No events parsed")
                return
            }
            
            print("✓ Parsed event successfully")
            print("  UID: \(event.uid)")
            print("  Summary: \(event.summary ?? "N/A")")
            print("  Description: \(event.description ?? "N/A")")
            
            // Test field extraction
            let mapping = ImportMapping.usaJetRAIDO
            
            for fieldMapping in mapping.fieldMappings {
                if let value = FieldExtractor.extract(
                    field: fieldMapping.targetField,
                    from: event,
                    using: fieldMapping
                ) {
                    print("  \(fieldMapping.targetField.rawValue): \(value)")
                }
            }
            
            // Test time extraction
            if let description = event.description,
               let baseDate = event.dtstart {
                let times = TimeExtractor.extractTimes(
                    from: description,
                    baseDate: baseDate,
                    mapping: mapping
                )
                
                print("\n✓ Time Extraction:")
                if let ci = times.checkInZulu {
                    print("  Check-In: \(ci)")
                }
                if let std = times.scheduledDepartureZulu {
                    print("  STD: \(std)")
                }
                if let sta = times.scheduledArrivalZulu {
                    print("  STA: \(sta)")
                }
            }
            
        case .failure(let error):
            print("✗ Parse failed: \(error)")
        }
    }
    
    // MARK: - Regex Pattern Testing
    
    static func testRegexPatterns() {
        print("\n=== Testing Regex Patterns ===\n")
        
        // Test flight number extraction
        let flightTests = [
            ("UJ227 LRD-IND", "^UJ\\d+"),
            ("UJ325 (X) LRD-IND", "^UJ\\d+"),
            ("Flight 123", "Flight (\\d+)")
        ]
        
        for (input, pattern) in flightTests {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                let range = Range(match.range(at: 0), in: input)!
                print("✓ '\(input)' matched: '\(input[range])'")
            } else {
                print("✗ '\(input)' no match")
            }
        }
        
        print()
        
        // Test airport extraction
        let airportTests = [
            ("UJ227 LRD-IND", "-([A-Z]{3})$"),  // Arrival
            ("UJ227 LRD-IND", "([A-Z]{3})-"),   // Departure
        ]
        
        for (input, pattern) in airportTests {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                let range = Range(match.range(at: 1), in: input)!
                print("✓ Airport from '\(input)': '\(input[range])'")
            }
        }
        
        print()
        
        // Test aircraft extraction
        let aircraftTest = "Aircraft: M88 - M88 - M88 - N832US"
        let aircraftPattern = "Aircraft:.*?([N][0-9]{3,4}[A-Z]{1,2})"
        
        if let regex = try? NSRegularExpression(pattern: aircraftPattern),
           let match = regex.firstMatch(in: aircraftTest, range: NSRange(aircraftTest.startIndex..., in: aircraftTest)) {
            let range = Range(match.range(at: 1), in: aircraftTest)!
            print("✓ Aircraft: '\(aircraftTest[range])'")
        }
        
        print()
        
        // Test time extraction
        let timeTest = "CI 1820Z / 1220L"
        let timePattern = #"(\d{4})Z(?:\s*/\s*(\d{4})L)?"#
        
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: timeTest, range: NSRange(timeTest.startIndex..., in: timeTest)) {
            
            if let zuluRange = Range(match.range(at: 1), in: timeTest) {
                print("✓ Zulu time: '\(timeTest[zuluRange])'")
            }
            
            if match.range(at: 2).location != NSNotFound,
               let localRange = Range(match.range(at: 2), in: timeTest) {
                print("✓ Local time: '\(timeTest[localRange])'")
            }
        }
    }
    
    // MARK: - Full Integration Test
    
    static func runFullTest() {
        print("\n=== Running Full Integration Test ===\n")
        
        // Create a minimal test calendar
        let testCalendar = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test//EN
        BEGIN:VEVENT
        UID:TEST001
        DTSTART:20251124T182000Z
        DTEND:20251124T222500Z
        SUMMARY:UJ227 LRD-IND
        DESCRIPTION:UJ227 LRD - IND\\nCI 1820Z / 1220L\\nSTD 2045Z / 1445L\\nSTA 2245Z / 1745L\\nDuration: 04:05, BLH: 02:30\\nAircraft: M88 - M88 - M88 - N832US\\n
        END:VEVENT
        BEGIN:VEVENT
        UID:TEST002
        DTSTART:20251125T160000Z
        DTEND:20251125T193000Z
        SUMMARY:UJ325 LRD-IND
        DESCRIPTION:UJ325 LRD - IND\\nCI 1600Z / 1000L\\nSTD 1705Z / 1105L\\nSTA 1916Z / 1416L\\nDuration: 03:30, BLH: 02:35\\nAircraft: M88 - M88 - M88 - N832US\\n
        END:VEVENT
        BEGIN:VEVENT
        UID:TEST003
        DTSTART:20251126T110000Z
        DTEND:20251127T110000Z
        SUMMARY:OFF YIP
        DESCRIPTION:OFF (Day Off) YIP\\nStart 1100Z / 0600L\\nEnd 1100Z / 0600L\\nDuration: 24:00\\n
        END:VEVENT
        END:VCALENDAR
        """
        
        // Import
        let result = ICalendarImportEngine.importCalendar(
            icsContent: testCalendar,
            using: .usaJetRAIDO
        )
        
        // Display results
        print(result.summary)
        print()
        
        print("Trips Created: \(result.createdTrips.count)")
        for trip in result.createdTrips {
            let firstLeg = trip.legs.first
            let lastLeg = trip.legs.last
            print("\nTrip \(trip.tripNumber): \(firstLeg?.departure ?? "?") to \(lastLeg?.arrival ?? "?")")
            print("  Flight Legs: \(trip.legs.count)")
            for leg in trip.legs {
                print("    \(leg.flightNumber): \(leg.departure) → \(leg.arrival)")
                if let std = leg.scheduledOut {
                    print("      Scheduled OUT: \(std)")
                }
                if let sta = leg.scheduledIn {
                    print("      Scheduled IN: \(sta)")
                }
            }
        }
        
        if !result.errors.isEmpty {
            print("\nErrors:")
            for error in result.errors {
                print("  - \(error.error)")
            }
        }
        
        if !result.warnings.isEmpty {
            print("\nWarnings:")
            for warning in result.warnings {
                print("  - \(warning.warning)")
            }
        }
    }
}

// MARK: - Example Usage in App

/*
 Usage in your app:
 
 1. Quick import with preset:
 
    let fileURL = URL(fileURLWithPath: "/path/to/schedule.ics")
    let result = ICalendarImportExample.importUSAJetSchedule(fileURL: fileURL)
    
    for trip in result.createdTrips {
        // Save to CloudKit or local storage
        tripStore.save(trip)
    }
 
 2. Use the import wizard UI:
 
    .sheet(isPresented: $showImportWizard) {
        ICalendarImportWizardView()
    }
 
 3. Create custom mapping:
 
    let customMapping = ICalendarImportExample.createCustomMapping()
    // Save mapping for future use
    settings.saveMapping(customMapping)
 
 4. Testing:
 
    ICalendarImportExample.testUSAJetParsing()
    ICalendarImportExample.testRegexPatterns()
    ICalendarImportExample.runFullTest()
 
 */
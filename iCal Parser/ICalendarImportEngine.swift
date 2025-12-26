//
//  ICalendarImportEngine.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import Foundation

class ICalendarImportEngine {
    
    // MARK: - Main Import Function
    
    static func importCalendar(
        icsContent: String,
        using mapping: ImportMapping,
        userTimezone: TimeZone? = nil
    ) -> ImportResult {
        
        var result = ImportResult(
            totalEvents: 0,
            successfulImports: 0,
            skippedEvents: 0,
            failedEvents: 0,
            createdTrips: [],
            errors: [],
            warnings: []
        )
        
        // Parse the iCalendar file
        let parseResult = ICalendarParser.parse(icsContent)
        
        guard case .success(let events) = parseResult else {
            result.errors.append(ImportError(
                eventUID: "PARSE_ERROR",
                eventSummary: nil,
                error: "Failed to parse iCalendar file"
            ))
            return result
        }
        
        result.totalEvents = events.count
        
        // Process each event
        var parsedEvents: [ParsedCalendarEvent] = []
        
        for event in events {
            let parsed = processEvent(event, using: mapping)
            parsedEvents.append(parsed)
            
            // Add errors/warnings to result
            for error in parsed.errors {
                result.errors.append(ImportError(
                    eventUID: event.uid,
                    eventSummary: event.summary,
                    error: error
                ))
            }
            
            for warning in parsed.warnings {
                result.warnings.append(ImportWarning(
                    eventUID: event.uid,
                    eventSummary: event.summary,
                    warning: warning
                ))
            }
        }
        
        // Filter events based on activity filters
        let filteredEvents = filterEvents(parsedEvents, using: mapping.activityFilters)
        result.skippedEvents = parsedEvents.count - filteredEvents.count
        
        // Group events into trips
        let trips = groupIntoTrips(filteredEvents, mapping: mapping)
        result.createdTrips = trips
        result.successfulImports = trips.reduce(0) { $0 + $1.legs.count }
        result.failedEvents = result.totalEvents - result.successfulImports - result.skippedEvents
        
        return result
    }
    
    // MARK: - Event Processing
    
    private static func processEvent(
        _ event: ICalEvent,
        using mapping: ImportMapping
    ) -> ParsedCalendarEvent {
        
        var parsed = ParsedCalendarEvent(rawEvent: event)
        var extractedData: [AppField: String] = [:]
        
        // Determine event type
        parsed.eventType = determineEventType(event, using: mapping.activityFilters)
        
        // Extract fields according to mapping
        for fieldMapping in mapping.fieldMappings {
            if let value = FieldExtractor.extract(
                field: fieldMapping.targetField,
                from: event,
                using: fieldMapping
            ) {
                extractedData[fieldMapping.targetField] = value
            }
        }
        
        parsed.extractedData = extractedData
        
        // Extract times if this is a flight
        if parsed.eventType == .flight,
           let description = event.description,
           let baseDate = event.dtstart {
            parsed.times = TimeExtractor.extractTimes(
                from: description,
                baseDate: baseDate,
                mapping: mapping
            )
        }
        
        // Validate extracted data
        validateExtractedData(&parsed)
        
        return parsed
    }
    
    // MARK: - Event Type Determination
    
    private static func determineEventType(
        _ event: ICalEvent,
        using filters: ActivityFilters
    ) -> EventType {
        
        guard let summary = event.summary else {
            return .unknown
        }
        
        let summaryUpper = summary.uppercased()
        
        // Check for deadheads
        for keyword in filters.deadheadKeywords {
            if summaryUpper.contains(keyword.uppercased()) {
                return .deadhead
            }
        }
        
        // Check for flights
        for keyword in filters.flightKeywords {
            if summaryUpper.contains(keyword.uppercased()) {
                return .flight
            }
        }
        
        // Check for rest
        for keyword in filters.restKeywords {
            if summaryUpper.contains(keyword.uppercased()) {
                return .rest
            }
        }
        
        // Check for days off
        for keyword in filters.offKeywords {
            if summaryUpper.contains(keyword.uppercased()) {
                return .dayOff
            }
        }
        
        // Check for duty days
        for keyword in filters.dutyKeywords {
            if summaryUpper.contains(keyword.uppercased()) {
                return .dutyDay
            }
        }
        
        return .unknown
    }
    
    // MARK: - Event Filtering
    
    private static func filterEvents(
        _ events: [ParsedCalendarEvent],
        using filters: ActivityFilters
    ) -> [ParsedCalendarEvent] {
        
        return events.filter { event in
            switch event.eventType {
            case .flight:
                return filters.importFlights
            case .dutyDay:
                return filters.importDutyDays
            case .dayOff:
                return filters.importDaysOff
            case .rest:
                return filters.importRest
            case .deadhead:
                return filters.importDeadheads
            case .unknown:
                return false // Don't import unknown events by default
            }
        }
    }
    
    // MARK: - Trip Grouping
    
    private static func groupIntoTrips(
        _ events: [ParsedCalendarEvent],
        mapping: ImportMapping
    ) -> [Trip] {
        
        var trips: [Trip] = []
        var currentTrip: Trip?
        var currentFlightLegs: [FlightLeg] = []
        
        // Sort events by start time
        let sortedEvents = events.sorted {
            ($0.rawEvent.dtstart ?? Date.distantPast) < ($1.rawEvent.dtstart ?? Date.distantPast)
        }
        
        for event in sortedEvents {
            // Only process flight and deadhead events
            guard event.eventType == .flight || event.eventType == .deadhead else {
                continue
            }
            
            // Create flight leg
            if let leg = createFlightLeg(from: event, mapping: mapping) {
                
                // Check if we should start a new trip
                if shouldStartNewTrip(currentTrip: currentTrip, newLeg: leg) {
                    // Save current trip if exists
                    if var trip = currentTrip {
                        trip.legs = currentFlightLegs
                        trips.append(trip)
                    }
                    
                    // Start new trip
                    currentTrip = createTrip(from: leg)
                    currentFlightLegs = [leg]
                } else {
                    // Add to current trip
                    currentFlightLegs.append(leg)
                }
            }
        }
        
        // Don't forget the last trip
        if var trip = currentTrip {
            trip.legs = currentFlightLegs
            trips.append(trip)
        }
        
        return trips
    }
    
    private static func shouldStartNewTrip(currentTrip: Trip?, newLeg: FlightLeg) -> Bool {
        guard let trip = currentTrip else {
            return true // First trip
        }
        
        // If more than 24 hours since last flight, start new trip
        if let lastLeg = trip.legs.last,
           let lastArrival = lastLeg.scheduledIn,
           let newDeparture = newLeg.scheduledOut {
            
            let timeDifference = newDeparture.timeIntervalSince(lastArrival)
            if timeDifference > 24 * 3600 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Object Creation
    
    private static func createTrip(from firstLeg: FlightLeg) -> Trip {
        return Trip(
            tripNumber: firstLeg.flightNumber,
            aircraft: "",  // Will be filled in later
            date: firstLeg.scheduledOut ?? Date(),
            tatStart: "",
            crew: [],
            notes: "Imported from iCalendar",
            legs: []  // Legs will be added separately
        )
    }
    
    private static func createFlightLeg(
        from event: ParsedCalendarEvent,
        mapping: ImportMapping
    ) -> FlightLeg? {
        
        let data = event.extractedData
        
        // Required fields
        guard let depAirport = data[.departureAirport],
              let arrAirport = data[.arrivalAirport] else {
            return nil
        }
        
        let flightNumber = data[.flightNumber] ?? ""
        // Note: aircraft and notes are parsed but FlightLeg doesn't currently use them
        // They're available via data[.aircraft] and data[.notes] if needed in the future

        // Create the flight leg with correct property names
        var leg = FlightLeg(
            departure: depAirport,
            arrival: arrAirport,
            flightNumber: flightNumber,
            isDeadhead: event.eventType == .deadhead
        )

        // Set scheduled times
        leg.scheduledOut = event.times.scheduledDeparture ?? event.rawEvent.dtstart
        leg.scheduledIn = event.times.scheduledArrival ?? event.rawEvent.dtend

        return leg
    }
    
    private static func extractAircraftType(from registration: String) -> String {
        // Try to extract aircraft type from registration
        // For USA Jet: N832US -> likely MD-88
        // This is a simple heuristic, could be improved with a database
        
        if registration.contains("83") && registration.contains("US") {
            return "MD88"
        }
        
        return "" // Unknown
    }
    
    // MARK: - Validation
    
    private static func validateExtractedData(_ parsed: inout ParsedCalendarEvent) {
        let data = parsed.extractedData
        
        // Check required fields for flights
        if parsed.eventType == .flight || parsed.eventType == .deadhead {
            
            if data[.flightNumber] == nil {
                parsed.warnings.append("No flight number found")
            }
            
            if data[.departureAirport] == nil {
                parsed.errors.append("Missing departure airport")
            }
            
            if data[.arrivalAirport] == nil {
                parsed.errors.append("Missing arrival airport")
            }
            
            if parsed.times.scheduledDeparture == nil {
                parsed.warnings.append("No scheduled departure time found")
            }
            
            if parsed.times.scheduledArrival == nil {
                parsed.warnings.append("No scheduled arrival time found")
            }
        }
    }
}

// MARK: - Timezone Utilities

extension Date {
    
    func convertToTimezone(_ timezone: TimeZone, from sourceTimezone: TimeZone = TimeZone(identifier: "UTC")!) -> Date {
        let sourceOffset = sourceTimezone.secondsFromGMT(for: self)
        let targetOffset = timezone.secondsFromGMT(for: self)
        let offsetDifference = targetOffset - sourceOffset
        
        return self.addingTimeInterval(TimeInterval(offsetDifference))
    }
    
    func formatInTimezone(_ timezone: TimeZone, format: String = "HHmm") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timezone
        return formatter.string(from: self)
    }
}

// MARK: - Preview Helpers

extension ImportResult {
    var successRate: Double {
        guard totalEvents > 0 else { return 0 }
        return Double(successfulImports) / Double(totalEvents)
    }
    
    var summary: String {
        """
        Import Summary:
        - Total Events: \(totalEvents)
        - Successfully Imported: \(successfulImports)
        - Skipped: \(skippedEvents)
        - Failed: \(failedEvents)
        - Trips Created: \(createdTrips.count)
        - Errors: \(errors.count)
        - Warnings: \(warnings.count)
        """
    }
}
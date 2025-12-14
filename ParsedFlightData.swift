//
//  ParsedFlightData.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/6/25.
//


// ICalFlightParser.swift
// Enhanced parser for NavBlue/Raido iCal format
// Extracts actual block times (STD/STA), block hours (BLH), aircraft, and more

import Foundation

// MARK: - Parsed Flight Data
struct ParsedFlightData {
    // Basic info from SUMMARY
    let flightNumber: String          // "UJ518"
    let origin: String                // "YIP"
    let destination: String           // "LRD"
    let role: String?                 // "L", "X", etc.
    
    // Times from DESCRIPTION (Zulu)
    let checkIn: Date?                // CI - Show time
    let scheduledDeparture: Date?     // STD - Block Out
    let scheduledArrival: Date?       // STA - Block In
    let checkOut: Date?               // CO - Release time
    
    // Duration info
    let dutyDuration: TimeInterval?   // Duration field
    let blockHours: TimeInterval?     // BLH - actual block time
    
    // Aircraft info
    let aircraftType: String?         // "M88", "M83"
    let tailNumber: String?           // "N831US"
    
    // Raw data
    let uid: String
    let dtStart: Date
    let dtEnd: Date
    let rawDescription: String
    
    // Computed
    var isDeadhead: Bool {
        flightNumber.hasPrefix("GT") || flightNumber.hasPrefix("DL") || 
        rawDescription.contains("Deadhead")
    }
    
    var blockHoursFormatted: String? {
        guard let blh = blockHours else { return nil }
        let hours = Int(blh) / 3600
        let minutes = (Int(blh) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - Parsed Non-Flight Event
struct ParsedNonFlightEvent {
    let eventType: String             // "OFF", "WOFF", "REST", "OND", "SB1", etc.
    let eventDescription: String      // "Day Off", "Working on Day Off", etc.
    let location: String              // "YIP", "LRD"
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval?
    let notes: String?                // Activity notes if present
    let uid: String
    
    var isOff: Bool { eventType == "OFF" || eventType == "HOL" }
    var isWorkingOff: Bool { eventType == "WOFF" }
    var isOnDuty: Bool { eventType == "OND" }
    var isRest: Bool { eventType == "REST" }
    var isStandby: Bool { eventType.hasPrefix("SB") || eventType.hasPrefix("LB") }
}

// MARK: - iCal Flight Parser
class ICalFlightParser {
    
    // Regex patterns for parsing DESCRIPTION field
    private static let ciPattern = #"CI\s+(\d{4})Z"#
    private static let stdPattern = #"STD\s+(\d{4})Z"#
    private static let staPattern = #"STA\s+(\d{4})Z"#
    private static let coPattern = #"CO\s+(\d{4})Z"#
    private static let durationPattern = #"Duration:\s*(\d{2}):(\d{2})"#
    private static let blhPattern = #"BLH:\s*(\d{2}):(\d{2})"#
    private static let aircraftPattern = #"Aircraft:\s*(\w+)\s*-.*-\s*(N\w+)"#
    private static let rdPattern = #"RD:\s*([A-Z,]+)"#
    
    // Event type patterns
    private static let flightSummaryPattern = #"^(UJ\d+|GT\d+|DL\d+|[A-Z]{2}\d+)\s*(?:\(([^)]+)\))?\s+(\w{3})-(\w{3})$"#
    private static let nonFlightSummaryPattern = #"^(\w+)\s+(\w{3})$"#
    
    // Known non-flight event types
    private static let nonFlightTypes = Set([
        "OFF", "WOFF", "OND", "REST", "SB1", "SB2", "SB3", "SB4",
        "LB1", "LB2", "LB3", "LB4", "LB5", "HOL", "VAC", "TRN", "1/7"
    ])
    
    // MARK: - Parse Full Calendar
    
    /// Parse raw iCal data into flights and non-flight events
    static func parseCalendar(_ data: Data) -> (flights: [ParsedFlightData], events: [ParsedNonFlightEvent]) {
        guard let content = String(data: data, encoding: .utf8) else {
            print("❌ Failed to decode iCal data")
            return ([], [])
        }
        
        return parseCalendarString(content)
    }
    
    static func parseCalendarString(_ content: String) -> (flights: [ParsedFlightData], events: [ParsedNonFlightEvent]) {
        var flights: [ParsedFlightData] = []
        var events: [ParsedNonFlightEvent] = []
        
        // Parse into raw events first
        let rawEvents = parseRawEvents(content)
        
        for rawEvent in rawEvents {
            guard let summary = rawEvent["SUMMARY"],
                  let description = rawEvent["DESCRIPTION"],
                  let uid = rawEvent["UID"],
                  let dtStartStr = rawEvent["DTSTART"],
                  let dtEndStr = rawEvent["DTEND"] else {
                continue
            }
            
            // Clean up description (remove line folding)
            let cleanDescription = description
                .replacingOccurrences(of: "\n\t ", with: "")
                .replacingOccurrences(of: "\n\t", with: "")
                .replacingOccurrences(of: "\\n", with: "\n")
            
            let dtStart = parseICalDate(dtStartStr)
            let dtEnd = parseICalDate(dtEndStr)
            
            guard let startDate = dtStart, let endDate = dtEnd else { continue }
            
            // Try to parse as flight first
            if let flight = parseFlightEvent(
                summary: summary,
                description: cleanDescription,
                uid: uid,
                dtStart: startDate,
                dtEnd: endDate
            ) {
                flights.append(flight)
            }
            // Then try non-flight event
            else if let event = parseNonFlightEvent(
                summary: summary,
                description: cleanDescription,
                uid: uid,
                dtStart: startDate,
                dtEnd: endDate
            ) {
                events.append(event)
            }
        }
        
        print("📋 Parsed \(flights.count) flights, \(events.count) non-flight events")
        return (flights, events)
    }
    
    // MARK: - Parse Flight Event
    
    private static func parseFlightEvent(
        summary: String,
        description: String,
        uid: String,
        dtStart: Date,
        dtEnd: Date
    ) -> ParsedFlightData? {
        
        // Try to match flight summary pattern: "UJ518 (L) YIP-LRD" or "UJ518 YIP-LRD"
        let summaryRegex = try? NSRegularExpression(pattern: flightSummaryPattern)
        guard let match = summaryRegex?.firstMatch(
            in: summary,
            range: NSRange(summary.startIndex..., in: summary)
        ) else {
            return nil
        }
        
        // Extract flight number
        guard let flightNumRange = Range(match.range(at: 1), in: summary) else { return nil }
        let flightNumber = String(summary[flightNumRange])
        
        // Extract role (optional)
        var role: String? = nil
        if let roleRange = Range(match.range(at: 2), in: summary) {
            role = String(summary[roleRange])
        }
        
        // Extract origin/destination
        guard let originRange = Range(match.range(at: 3), in: summary),
              let destRange = Range(match.range(at: 4), in: summary) else { return nil }
        let origin = String(summary[originRange])
        let destination = String(summary[destRange])
        
        // Parse times from description
        let checkIn = extractTime(pattern: ciPattern, from: description, referenceDate: dtStart)
        let std = extractTime(pattern: stdPattern, from: description, referenceDate: dtStart)
        let sta = extractTime(pattern: staPattern, from: description, referenceDate: dtStart)
        let checkOut = extractTime(pattern: coPattern, from: description, referenceDate: dtStart)
        
        // Parse durations
        let dutyDuration = extractDuration(pattern: durationPattern, from: description)
        let blockHours = extractDuration(pattern: blhPattern, from: description)
        
        // Parse aircraft
        var aircraftType: String? = nil
        var tailNumber: String? = nil
        if let aircraftRegex = try? NSRegularExpression(pattern: aircraftPattern),
           let aircraftMatch = aircraftRegex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
            if let typeRange = Range(aircraftMatch.range(at: 1), in: description) {
                aircraftType = String(description[typeRange])
            }
            if let tailRange = Range(aircraftMatch.range(at: 2), in: description) {
                tailNumber = String(description[tailRange])
            }
        }
        
        // Also try to extract role from description if not in summary
        if role == nil {
            if let rdRegex = try? NSRegularExpression(pattern: rdPattern),
               let rdMatch = rdRegex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
               let rdRange = Range(rdMatch.range(at: 1), in: description) {
                role = String(description[rdRange])
            }
        }
        
        return ParsedFlightData(
            flightNumber: flightNumber,
            origin: origin,
            destination: destination,
            role: role,
            checkIn: checkIn,
            scheduledDeparture: std,
            scheduledArrival: sta,
            checkOut: checkOut,
            dutyDuration: dutyDuration,
            blockHours: blockHours,
            aircraftType: aircraftType,
            tailNumber: tailNumber,
            uid: uid,
            dtStart: dtStart,
            dtEnd: dtEnd,
            rawDescription: description
        )
    }
    
    // MARK: - Parse Non-Flight Event
    
    private static func parseNonFlightEvent(
        summary: String,
        description: String,
        uid: String,
        dtStart: Date,
        dtEnd: Date
    ) -> ParsedNonFlightEvent? {
        
        // Match pattern: "OFF YIP" or "WOFF LRD"
        let regex = try? NSRegularExpression(pattern: nonFlightSummaryPattern)
        guard let match = regex?.firstMatch(
            in: summary,
            range: NSRange(summary.startIndex..., in: summary)
        ) else {
            return nil
        }
        
        guard let typeRange = Range(match.range(at: 1), in: summary),
              let locRange = Range(match.range(at: 2), in: summary) else {
            return nil
        }
        
        let eventType = String(summary[typeRange])
        let location = String(summary[locRange])
        
        // Verify it's a known non-flight type
        guard nonFlightTypes.contains(eventType) else { return nil }
        
        // Extract full description (e.g., "Day Off", "Working on Day Off")
        var eventDescription = eventType
        if description.contains("(") {
            if let parenStart = description.firstIndex(of: "("),
               let parenEnd = description.firstIndex(of: ")") {
                let start = description.index(after: parenStart)
                eventDescription = String(description[start..<parenEnd])
            }
        }
        
        // Parse duration
        let duration = extractDuration(pattern: durationPattern, from: description)
        
        // Extract activity notes if present
        var notes: String? = nil
        if description.contains("Activity notes:") {
            if let notesStart = description.range(of: "Activity notes:")?.upperBound {
                notes = String(description[notesStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if notes?.isEmpty == true { notes = nil }
            }
        }
        
        return ParsedNonFlightEvent(
            eventType: eventType,
            eventDescription: eventDescription,
            location: location,
            startTime: dtStart,
            endTime: dtEnd,
            duration: duration,
            notes: notes,
            uid: uid
        )
    }
    
    // MARK: - Helper Methods
    
    /// Parse raw iCal events into dictionaries
    private static func parseRawEvents(_ content: String) -> [[String: String]] {
        var events: [[String: String]] = []
        var currentEvent: [String: String] = [:]
        var inEvent = false
        var currentKey: String?
        var currentValue: String = ""
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // Handle line folding (lines starting with space/tab are continuations)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if let key = currentKey {
                    currentValue += line.trimmingCharacters(in: .whitespaces)
                    currentEvent[key] = currentValue
                }
                continue
            }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine == "BEGIN:VEVENT" {
                inEvent = true
                currentEvent = [:]
                currentKey = nil
            } else if trimmedLine == "END:VEVENT" {
                if inEvent && !currentEvent.isEmpty {
                    events.append(currentEvent)
                }
                inEvent = false
                currentEvent = [:]
                currentKey = nil
            } else if inEvent && trimmedLine.contains(":") {
                let parts = trimmedLine.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    // Handle fields with parameters like "DTSTART;TZID=..."
                    let keyPart = parts[0]
                    let key = keyPart.components(separatedBy: ";").first ?? keyPart
                    let value = parts[1]
                    
                    currentKey = key
                    currentValue = value
                    currentEvent[key] = value
                }
            }
        }
        
        return events
    }
    
    /// Parse iCal date format (20251206T110000Z)
    private static func parseICalDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
    
    /// Extract a Zulu time (e.g., "1645Z") and convert to Date
    private static func extractTime(pattern: String, from text: String, referenceDate: Date) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let timeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        let timeStr = String(text[timeRange])
        guard timeStr.count == 4,
              let hours = Int(timeStr.prefix(2)),
              let minutes = Int(timeStr.suffix(2)) else {
            return nil
        }
        
        // Get the date components from reference date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hours
        components.minute = minutes
        components.second = 0
        
        guard var result = calendar.date(from: components) else { return nil }
        
        // Handle overnight flights - if extracted time is earlier than reference start,
        // it's probably the next day
        if result < referenceDate {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        }
        
        return result
    }
    
    /// Extract duration (e.g., "03:16" -> TimeInterval)
    private static func extractDuration(pattern: String, from text: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hoursRange = Range(match.range(at: 1), in: text),
              let minutesRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        
        guard let hours = Int(text[hoursRange]),
              let minutes = Int(text[minutesRange]) else {
            return nil
        }
        
        return TimeInterval(hours * 3600 + minutes * 60)
    }
}

// MARK: - Trip Grouping Helper

extension ICalFlightParser {
    
    /// Group consecutive flights into trips based on flight number
    /// A trip is a sequence of legs with the same base flight number
    static func groupIntoTrips(_ flights: [ParsedFlightData]) -> [[ParsedFlightData]] {
        guard !flights.isEmpty else { return [] }
        
        // Sort by scheduled departure (or dtStart if no STD)
        let sorted = flights.sorted { f1, f2 in
            let t1 = f1.scheduledDeparture ?? f1.dtStart
            let t2 = f2.scheduledDeparture ?? f2.dtStart
            return t1 < t2
        }
        
        var trips: [[ParsedFlightData]] = []
        var currentTrip: [ParsedFlightData] = []
        var currentFlightNumber: String = ""
        
        for flight in sorted {
            // Skip deadheads for trip grouping (they're positioning)
            if flight.isDeadhead {
                continue
            }
            
            if flight.flightNumber == currentFlightNumber {
                // Same trip, add leg
                currentTrip.append(flight)
            } else {
                // New trip
                if !currentTrip.isEmpty {
                    trips.append(currentTrip)
                }
                currentTrip = [flight]
                currentFlightNumber = flight.flightNumber
            }
        }
        
        // Don't forget the last trip
        if !currentTrip.isEmpty {
            trips.append(currentTrip)
        }
        
        return trips
    }
    
    /// Calculate total block hours for a trip
    static func totalBlockHours(for flights: [ParsedFlightData]) -> TimeInterval {
        return flights.compactMap { $0.blockHours }.reduce(0, +)
    }
    
    /// Format block hours as HH:MM
    static func formatBlockHours(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - Debug Helpers

extension ParsedFlightData: CustomStringConvertible {
    var description: String {
        var parts = ["\(flightNumber) \(origin)-\(destination)"]
        if let role = role { parts.append("(\(role))") }
        if let std = scheduledDeparture {
            let fmt = DateFormatter()
            fmt.dateFormat = "HHmm'Z'"
            fmt.timeZone = TimeZone(identifier: "UTC")
            parts.append("STD:\(fmt.string(from: std))")
        }
        if let blh = blockHoursFormatted { parts.append("BLH:\(blh)") }
        if let tail = tailNumber { parts.append(tail) }
        return parts.joined(separator: " ")
    }
}

extension ParsedNonFlightEvent: CustomStringConvertible {
    var description: String {
        return "\(eventType) \(location) - \(eventDescription)"
    }
}
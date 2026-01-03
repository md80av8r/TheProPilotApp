//
//  ICalFieldParser.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/1/26.
//


import Foundation

// MARK: - Raw iCal event data
struct ICalEventData {
    let uid: String
    let summary: String?
    let description: String?
    let dtstart: String?
    let dtend: String?
    let location: String?
    let categories: String?
    let status: String?
    
    init(
        uid: String = "",
        summary: String? = nil,
        description: String? = nil,
        dtstart: String? = nil,
        dtend: String? = nil,
        location: String? = nil,
        categories: String? = nil,
        status: String? = nil
    ) {
        self.uid = uid
        self.summary = summary
        self.description = description
        self.dtstart = dtstart
        self.dtend = dtend
        self.location = location
        self.categories = categories
        self.status = status
    }
}

// MARK: - Parsed flight data result
struct ParsedFlightInfo {
    var flightNumber: String?
    var departure: String?
    var arrival: String?
    var scheduledOut: String?
    var scheduledIn: String?
    var aircraft: String?
    var pilotRole: String?  // "X" or "L"
    var checkIn: String?
    var checkOut: String?
    var tripNumber: String?
    
    // Raw data for reference
    var rawSummary: String?
    var rawDescription: String?
    var uid: String?
    var dtstart: String?
    var dtend: String?
}

class ICalFieldParser {
    
    // MARK: - Main Parsing Method
    
    /// Parse a single iCal event using the provided import profile
    static func parseEvent(
        _ event: ICalEventData,
        using profile: SDImportProfile
    ) -> ParsedFlightInfo? {
        
        var flightData = ParsedFlightInfo()
        
        // Extract each field using its parsing rule
        if let rule = profile.flightNumberRule {
            flightData.flightNumber = extractField(from: event, using: rule)
        }
        
        if let rule = profile.departureRule {
            flightData.departure = extractField(from: event, using: rule)
        }
        
        if let rule = profile.arrivalRule {
            flightData.arrival = extractField(from: event, using: rule)
        }
        
        if let rule = profile.scheduledOutRule {
            flightData.scheduledOut = extractField(from: event, using: rule)
        }
        
        if let rule = profile.scheduledInRule {
            flightData.scheduledIn = extractField(from: event, using: rule)
        }
        
        if let rule = profile.aircraftRule {
            flightData.aircraft = extractField(from: event, using: rule)
        }
        
        if let rule = profile.pilotRoleRule {
            flightData.pilotRole = extractField(from: event, using: rule)
        }
        
        if let rule = profile.checkInRule {
            flightData.checkIn = extractField(from: event, using: rule)
        }
        
        if let rule = profile.checkOutRule {
            flightData.checkOut = extractField(from: event, using: rule)
        }
        
        if let rule = profile.tripNumberRule {
            flightData.tripNumber = extractField(from: event, using: rule)
        }
        
        // Store raw event for reference
        flightData.rawSummary = event.summary
        flightData.rawDescription = event.description
        flightData.uid = event.uid
        flightData.dtstart = event.dtstart
        flightData.dtend = event.dtend
        
        return flightData
    }
    
    // MARK: - Field Extraction
    
    /// Extract a single field from an iCal event using a parsing rule
    private static func extractField(
        from event: ICalEventData,
        using rule: ParsingRule
    ) -> String? {
        
        // Get the source field value
        guard let sourceValue = getSourceValue(from: event, field: rule.sourceField) else {
            return rule.fallbackValue
        }
        
        // Apply extraction method
        switch rule.extractionMethod {
        case .direct:
            return sourceValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
        case .regex:
            guard let regex = rule.regex else {
                print("⚠️ Regex extraction requested but no pattern provided")
                return rule.fallbackValue
            }
            return extractWithRegex(from: sourceValue, pattern: regex) ?? rule.fallbackValue
            
        case .split:
            // TODO: Implement split extraction if needed
            return rule.fallbackValue
            
        case .multiLine:
            // TODO: Implement multi-line parsing if needed
            return rule.fallbackValue
        }
    }
    
    // MARK: - Source Value Extraction
    
    /// Get the raw value from the iCal event based on field type
    private static func getSourceValue(
        from event: ICalEventData,
        field: ParsingRule.ICalField
    ) -> String? {
        
        switch field {
        case .summary:
            return event.summary
        case .description:
            return event.description
        case .dtstart:
            return event.dtstart
        case .dtend:
            return event.dtend
        case .location:
            return event.location
        case .uid:
            return event.uid
        case .categories:
            return event.categories
        case .status:
            return event.status
        }
    }
    
    // MARK: - Regex Extraction
    
    /// Extract value using regex pattern (returns first capture group)
    private static func extractWithRegex(
        from text: String,
        pattern: String
    ) -> String? {
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                // Return first capture group (not group 0, which is the whole match)
                if match.numberOfRanges > 1 {
                    let captureRange = match.range(at: 1)
                    if let swiftRange = Range(captureRange, in: text) {
                        let extracted = String(text[swiftRange])
                        print("✅ Regex extracted: '\(extracted)' from '\(text.prefix(50))...'")
                        return extracted
                    }
                }
            }
            
            print("⚠️ Regex '\(pattern)' found no match in: '\(text.prefix(50))...'")
            return nil
            
        } catch {
            print("❌ Invalid regex pattern: \(pattern) - \(error)")
            return nil
        }
    }
    
    // MARK: - Validation
    
    /// Check if parsed data is valid (has minimum required fields)
    static func isValidFlightData(_ data: ParsedFlightInfo) -> Bool {
        // Minimum: must have flight number OR departure/arrival
        let hasFlightNumber = !(data.flightNumber?.isEmpty ?? true)
        let hasRoute = !(data.departure?.isEmpty ?? true) && !(data.arrival?.isEmpty ?? true)
        
        return hasFlightNumber || hasRoute
    }
    
    /// Determine if this event is a flight vs. day off, rest, etc.
    static func isFlightEvent(_ event: ICalEventData) -> Bool {
        let summary = event.summary?.uppercased() ?? ""
        
        // Filter out non-flight events
        let nonFlightKeywords = ["OFF", "OND", "REST", "WOFF", "HOL", "1/7", "LB1", "SB1"]
        
        for keyword in nonFlightKeywords {
            if summary.starts(with: keyword + " ") || summary == keyword {
                return false
            }
        }
        
        // Check if it has flight number pattern (2 letters + numbers)
        let flightNumberPattern = "^[A-Z]{2}\\d+"
        if let regex = try? NSRegularExpression(pattern: flightNumberPattern),
           let _ = regex.firstMatch(in: summary, range: NSRange(summary.startIndex..., in: summary)) {
            return true
        }
        
        return false
    }
}

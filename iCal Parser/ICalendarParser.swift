import Foundation

class ICalendarParser {
    
    // MARK: - Main Parsing Function
    
    static func parse(_ icsContent: String) -> Result<[ICalEvent], ICalParseError> {
        var events: [ICalEvent] = []
        var currentEvent: ICalEvent?
        var currentField: String = ""
        var currentValue: String = ""
        
        let lines = icsContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Handle folded lines (continuation lines start with space or tab)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                currentValue += line.trimmingCharacters(in: .whitespaces)
                continue
            }
            
            // Process previous field if we have one
            if !currentField.isEmpty {
                processField(field: currentField, value: currentValue, event: &currentEvent)
            }
            
            // Parse new field
            if trimmed == "BEGIN:VEVENT" {
                currentEvent = ICalEvent(uid: "")
            } else if trimmed == "END:VEVENT" {
                if let event = currentEvent {
                    events.append(event)
                }
                currentEvent = nil
            } else if let colonIndex = trimmed.firstIndex(of: ":") {
                currentField = String(trimmed[..<colonIndex])
                currentValue = String(trimmed[trimmed.index(after: colonIndex)...])
            }
        }
        
        return .success(events)
    }
    
    // MARK: - Field Processing
    
    private static func processField(field: String, value: String, event: inout ICalEvent?) {
        guard var event = event else { return }
        
        // Handle field parameters (e.g., "DTSTART;TZID=America/New_York")
        let fieldComponents = field.components(separatedBy: ";")
        let baseField = fieldComponents[0]
        
        switch baseField {
        case "UID":
            event.uid = value
            
        case "SUMMARY":
            event.summary = value
            
        case "DESCRIPTION":
            event.description = decodeDescription(value)
            
        case "LOCATION":
            event.location = value
            
        case "DTSTART":
            event.dtstart = parseDateTime(value, parameters: fieldComponents)
            
        case "DTEND":
            event.dtend = parseDateTime(value, parameters: fieldComponents)
            
        case "DTSTAMP":
            event.dtstamp = parseDateTime(value, parameters: fieldComponents)
            
        case "ORGANIZER":
            event.organizer = value
            
        case "STATUS":
            event.status = value
            
        case "CATEGORIES":
            event.categories = value
            
        default:
            break
        }
    }
    
    // MARK: - DateTime Parsing
    
    private static func parseDateTime(_ value: String, parameters: [String]) -> Date? {
        // iCalendar date-time formats:
        // UTC: 20251124T110000Z
        // Local: 20251124T110000
        // With timezone: DTSTART;TZID=America/New_York:20251124T110000
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Handle UTC (ends with Z)
        if value.hasSuffix("Z") {
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            dateFormatter.formatOptions = [.withInternetDateTime]
            
            // Convert to format ISO8601DateFormatter expects
            let formatted = formatForISO8601(value)
            return dateFormatter.date(from: formatted)
        }
        
        // Check for TZID parameter
        var timezone: TimeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
        for param in parameters {
            if param.hasPrefix("TZID=") {
                let tzid = param.replacingOccurrences(of: "TZID=", with: "")
                if let tz = TimeZone(identifier: tzid) {
                    timezone = tz
                }
            }
        }
        
        dateFormatter.timeZone = timezone
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let formatted = formatForISO8601(value)
        return dateFormatter.date(from: formatted)
    }
    
    private static func formatForISO8601(_ value: String) -> String {
        // Convert from 20251124T110000Z to 2025-11-24T11:00:00Z
        var formatted = value
        
        if formatted.count >= 8 {
            formatted.insert("-", at: formatted.index(formatted.startIndex, offsetBy: 4))
            formatted.insert("-", at: formatted.index(formatted.startIndex, offsetBy: 7))
        }
        if formatted.count >= 13 {
            formatted.insert(":", at: formatted.index(formatted.startIndex, offsetBy: 13))
        }
        if formatted.count >= 16 {
            formatted.insert(":", at: formatted.index(formatted.startIndex, offsetBy: 16))
        }
        
        return formatted
    }
    
    // MARK: - Description Decoding
    
    private static func decodeDescription(_ value: String) -> String {
        // iCalendar descriptions can have escaped characters
        var decoded = value
        decoded = decoded.replacingOccurrences(of: "\\n", with: "\n")
        decoded = decoded.replacingOccurrences(of: "\\t", with: "\t")
        decoded = decoded.replacingOccurrences(of: "\\,", with: ",")
        decoded = decoded.replacingOccurrences(of: "\\;", with: ";")
        decoded = decoded.replacingOccurrences(of: "\\\\", with: "\\")
        
        return decoded
    }
}

// MARK: - Time Extraction Engine

class TimeExtractor {
    
    // Extract times from USA Jet RAIDO format description
    // Example:
    // CI 1820Z / 1220L
    // STD 2045Z / 1445L
    // STA 2245Z / 1745L
    // CO 0400Z / 2200L
    
    static func extractTimes(
        from description: String,
        baseDate: Date,
        mapping: ImportMapping
    ) -> ExtractedTimes {
        var times = ExtractedTimes()
        
        let lines = description.components(separatedBy: "\n")
        
        for line in lines {
            // Check-In time
            if line.contains("CI ") {
                if let (zulu, local) = extractTimeStrings(from: line, baseDate: baseDate) {
                    times.checkIn = zulu
                    times.checkInZulu = formatTime(zulu, timezone: "UTC")
                    times.checkInLocal = local != nil ? formatTime(local!, timezone: "Local") : nil
                }
            }
            
            // Scheduled Departure
            if line.contains("STD ") {
                if let (zulu, local) = extractTimeStrings(from: line, baseDate: baseDate) {
                    times.scheduledDeparture = zulu
                    times.scheduledDepartureZulu = formatTime(zulu, timezone: "UTC")
                    times.scheduledDepartureLocal = local != nil ? formatTime(local!, timezone: "Local") : nil
                }
            }
            
            // Scheduled Arrival
            if line.contains("STA ") {
                if let (zulu, local) = extractTimeStrings(from: line, baseDate: baseDate) {
                    times.scheduledArrival = zulu
                    times.scheduledArrivalZulu = formatTime(zulu, timezone: "UTC")
                    times.scheduledArrivalLocal = local != nil ? formatTime(local!, timezone: "Local") : nil
                }
            }
            
            // Checkout/Release time
            if line.contains("CO ") {
                if let (zulu, local) = extractTimeStrings(from: line, baseDate: baseDate) {
                    times.release = zulu
                    times.releaseZulu = formatTime(zulu, timezone: "UTC")
                    times.releaseLocal = local != nil ? formatTime(local!, timezone: "Local") : nil
                }
            }
        }
        
        return times
    }
    
    // Extract time strings in format "1820Z / 1220L"
    private static func extractTimeStrings(
        from line: String,
        baseDate: Date
    ) -> (zulu: Date, local: Date?)? {
        // Pattern: HHMMZ / HHMML or just HHMMZ
        let pattern = #"(\d{4})Z(?:\s*/\s*(\d{4})L)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        // Extract Zulu time
        guard let zuluRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let zuluString = String(line[zuluRange])
        
        // Convert to Date
        guard let zuluDate = parseTimeString(zuluString, baseDate: baseDate, isZulu: true) else {
            return nil
        }
        
        // Extract Local time if present
        var localDate: Date?
        if match.range(at: 2).location != NSNotFound,
           let localRange = Range(match.range(at: 2), in: line) {
            let localString = String(line[localRange])
            localDate = parseTimeString(localString, baseDate: baseDate, isZulu: false)
        }
        
        return (zuluDate, localDate)
    }
    
    private static func parseTimeString(_ timeString: String, baseDate: Date, isZulu: Bool) -> Date? {
        // Parse HHMM format
        guard timeString.count == 4,
              let hours = Int(timeString.prefix(2)),
              let minutes = Int(timeString.suffix(2)) else {
            return nil
        }
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = isZulu ? TimeZone(identifier: "UTC")! : TimeZone.current
        
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hours
        components.minute = minutes
        components.second = 0
        
        return calendar.date(from: components)
    }
    
    private static func formatTime(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        
        if timezone == "UTC" {
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date) + "Z"
        } else {
            return formatter.string(from: date) + "L"
        }
    }
}

// MARK: - Field Extractor

class FieldExtractor {
    
    static func extract(
        field: AppField,
        from event: ICalEvent,
        using mapping: iCalFieldMapping
    ) -> String? {
        
        // Get the source text
        guard let sourceText = getSourceText(from: event, field: mapping.sourceField) else {
            return nil
        }
        
        // Apply extraction rule if present
        if let rule = mapping.extractionRule {
            return applyExtractionRule(rule, to: sourceText)
        }
        
        // Otherwise return the raw text
        return sourceText
    }
    
    private static func getSourceText(from event: ICalEvent, field: iCalField) -> String? {
        switch field {
        case .summary: return event.summary
        case .description: return event.description
        case .location: return event.location
        case .uid: return event.uid
        case .organizer: return event.organizer
        case .status: return event.status
        case .categories: return event.categories
        default: return nil
        }
    }
    
    private static func applyExtractionRule(_ rule: ExtractionRule, to text: String) -> String? {
        var workingText = text
        
        // Handle line number extraction for multi-line fields
        if let lineNum = rule.lineNumber {
            let lines = text.components(separatedBy: "\n")
            guard lineNum > 0 && lineNum <= lines.count else { return nil }
            workingText = lines[lineNum - 1]
        }
        
        // Handle prefix/suffix
        if let prefix = rule.prefix {
            guard let range = workingText.range(of: prefix) else { return nil }
            workingText = String(workingText[range.upperBound...])
        }
        
        // Apply regex pattern
        if let pattern = rule.pattern {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: workingText,
                    range: NSRange(workingText.startIndex..., in: workingText)
                  ) else {
                return nil
            }
            
            let captureGroup = rule.captureGroup ?? 1
            guard captureGroup < match.numberOfRanges,
                  let range = Range(match.range(at: captureGroup), in: workingText) else {
                return nil
            }
            
            workingText = String(workingText[range])
        }
        
        // Handle split delimiter
        if let delimiter = rule.splitDelimiter {
            let components = workingText.components(separatedBy: delimiter)
            workingText = components.first ?? workingText
        }
        
        // Apply transformations
        if let transformation = rule.transformation {
            workingText = applyTransformation(transformation, to: workingText)
        }
        
        return workingText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func applyTransformation(_ transformation: ExtractionRule.TextTransformation, to text: String) -> String {
        switch transformation {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .trim:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeWhitespace:
            return text.replacingOccurrences(of: " ", with: "")
        case .icaoToIata:
            // This would require an airport database lookup
            return text
        }
    }
}

// MARK: - Errors

enum ICalParseError: Error {
    case invalidFormat
    case noEventsFound
    case encodingError
    case unknown(String)
}

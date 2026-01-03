//
//  ImportMapping.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import Foundation
import SwiftUI

// MARK: - Import Mapping Configuration

struct ImportMapping: Codable, Identifiable {
    let id: UUID
    var name: String // "USA Jet", "Atlas Air", "Custom Mapping"
    var fieldMappings: [iCalFieldMapping]
    var parsingRules: [LegacyParsingRule]
    var timezonePreference: TimezonePreference
    var isDefault: Bool
    var activityFilters: ActivityFilters
    var createdDate: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        fieldMappings: [iCalFieldMapping] = [],
        parsingRules: [LegacyParsingRule] = [],
        timezonePreference: TimezonePreference = .utc,
        isDefault: Bool = false,
        activityFilters: ActivityFilters = ActivityFilters(),
        createdDate: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fieldMappings = fieldMappings
        self.parsingRules = parsingRules
        self.timezonePreference = timezonePreference
        self.isDefault = isDefault
        self.activityFilters = activityFilters
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
}

// MARK: - Field Mapping

struct iCalFieldMapping: Codable, Identifiable {
    let id: UUID
    var sourceField: iCalField // Where to get the data from
    var targetField: AppField  // Where to put it in the app
    var extractionRule: ExtractionRule? // How to extract it
    
    init(
        id: UUID = UUID(),
        sourceField: iCalField,
        targetField: AppField,
        extractionRule: ExtractionRule? = nil
    ) {
        self.id = id
        self.sourceField = sourceField
        self.targetField = targetField
        self.extractionRule = extractionRule
    }
}

// MARK: - iCalendar Fields (RFC 5545)

enum iCalField: String, Codable, CaseIterable {
    case summary = "SUMMARY"
    case description = "DESCRIPTION"
    case location = "LOCATION"
    case dtstart = "DTSTART"
    case dtend = "DTEND"
    case dtstamp = "DTSTAMP"
    case uid = "UID"
    case organizer = "ORGANIZER"
    case status = "STATUS"
    case categories = "CATEGORIES"
    
    var displayName: String {
        switch self {
        case .summary: return "Summary"
        case .description: return "Description"
        case .location: return "Location"
        case .dtstart: return "Start Time"
        case .dtend: return "End Time"
        case .dtstamp: return "Timestamp"
        case .uid: return "Unique ID"
        case .organizer: return "Organizer"
        case .status: return "Status"
        case .categories: return "Categories"
        }
    }
    
    var hint: String {
        switch self {
        case .summary: return "Event title/summary line"
        case .description: return "Multi-line event details"
        case .location: return "Location field"
        case .dtstart: return "Start date/time"
        case .dtend: return "End date/time"
        case .dtstamp: return "Creation timestamp"
        case .uid: return "Unique identifier"
        case .organizer: return "Event organizer"
        case .status: return "Event status"
        case .categories: return "Event categories"
        }
    }
}

// MARK: - App Fields

enum AppField: String, Codable, CaseIterable {
    // Flight Information
    case flightNumber = "Flight Number"
    case departureAirport = "Departure Airport"
    case arrivalAirport = "Arrival Airport"
    case aircraft = "Aircraft"
    
    // Times
    case scheduledDeparture = "Scheduled Departure"
    case scheduledArrival = "Scheduled Arrival"
    case checkInTime = "Check-In Time"
    case releaseTime = "Release Time"
    
    // Crew & Notes
    case crewMembers = "Crew Members"
    case notes = "Notes"
    
    // Activity Type
    case activityType = "Activity Type"
    
    // Special
    case ignore = "Ignore/Skip"
    
    var category: AppFieldCategory {
        switch self {
        case .flightNumber, .departureAirport, .arrivalAirport, .aircraft:
            return .flightInfo
        case .scheduledDeparture, .scheduledArrival, .checkInTime, .releaseTime:
            return .times
        case .crewMembers, .notes:
            return .other
        case .activityType:
            return .metadata
        case .ignore:
            return .special
        }
    }
}

enum AppFieldCategory: String {
    case flightInfo = "Flight Information"
    case times = "Times"
    case other = "Other"
    case metadata = "Metadata"
    case special = "Special"
}

// MARK: - Extraction Rules

struct ExtractionRule: Codable {
    var pattern: String? // Regex pattern
    var lineNumber: Int? // For multi-line DESCRIPTION fields (1-indexed)
    var splitDelimiter: String? // For splitting values
    var captureGroup: Int? // Which regex capture group to use (default 1)
    var prefix: String? // Text before the value
    var suffix: String? // Text after the value
    var transformation: TextTransformation?
    
    enum TextTransformation: String, Codable {
        case uppercase
        case lowercase
        case trim
        case removeWhitespace
        case icaoToIata // Convert ICAO airport codes to IATA
    }
}

// MARK: - Parsing Rules (Legacy)

struct LegacyParsingRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var pattern: String
    var targetField: AppField
    var sampleInput: String?
    var sampleOutput: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        targetField: AppField,
        sampleInput: String? = nil,
        sampleOutput: String? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.targetField = targetField
        self.sampleInput = sampleInput
        self.sampleOutput = sampleOutput
    }
}

// MARK: - Timezone Preferences

struct TimezonePreference: Codable {
    var preferredTimezone: TimezoneOption
    var autoDetectHomeBase: Bool // Automatically use home base timezone
    var showBothTimezones: Bool // Display both UTC and Local
    
    init(
        preferredTimezone: TimezoneOption = .utc,
        autoDetectHomeBase: Bool = false,
        showBothTimezones: Bool = true
    ) {
        self.preferredTimezone = preferredTimezone
        self.autoDetectHomeBase = autoDetectHomeBase
        self.showBothTimezones = showBothTimezones
    }
    
    static var utc: TimezonePreference {
        TimezonePreference(preferredTimezone: .utc)
    }
}

enum TimezoneOption: String, Codable, CaseIterable {
    case utc = "UTC/Zulu"
    case homeBase = "Home Base Local"
    case aircraftLocal = "Aircraft Local" // Use departure airport timezone
    case custom = "Custom Timezone"
    
    var description: String {
        switch self {
        case .utc:
            return "Always use UTC (Zulu time)"
        case .homeBase:
            return "Use your home base timezone"
        case .aircraftLocal:
            return "Use departure airport's local time"
        case .custom:
            return "Specify a custom timezone"
        }
    }
}

// MARK: - Activity Filters

struct ActivityFilters: Codable {
    var importFlights: Bool = true
    var importDutyDays: Bool = true
    var importDaysOff: Bool = false
    var importRest: Bool = false
    var importDeadheads: Bool = true
    
    // Keywords to identify different activity types
    var flightKeywords: [String] = ["UJ", "Flight"]
    var dutyKeywords: [String] = ["OND", "WOFF", "Day On Duty"]
    var offKeywords: [String] = ["OFF", "Day Off", "1/7"]
    var restKeywords: [String] = ["REST", "LB"]
    var deadheadKeywords: [String] = ["DH", "Deadhead", "GT", "DL"]
}

// MARK: - Parsed Event

struct ParsedCalendarEvent: Identifiable {
    let id: UUID
    var rawEvent: ICalEvent
    var eventType: EventType
    var extractedData: [AppField: String]
    var times: ExtractedTimes
    var errors: [String]
    var warnings: [String]
    
    init(
        id: UUID = UUID(),
        rawEvent: ICalEvent,
        eventType: EventType = .unknown,
        extractedData: [AppField: String] = [:],
        times: ExtractedTimes = ExtractedTimes(),
        errors: [String] = [],
        warnings: [String] = []
    ) {
        self.id = id
        self.rawEvent = rawEvent
        self.eventType = eventType
        self.extractedData = extractedData
        self.times = times
        self.errors = errors
        self.warnings = warnings
    }
}

enum EventType: String, Codable {
    case flight = "Flight"
    case dutyDay = "Duty Day"
    case dayOff = "Day Off"
    case rest = "Rest Period"
    case deadhead = "Deadhead"
    case unknown = "Unknown"
}

struct ExtractedTimes: Codable {
    var checkIn: Date?
    var scheduledDeparture: Date?
    var scheduledArrival: Date?
    var release: Date?
    
    var checkInZulu: String?
    var checkInLocal: String?
    var scheduledDepartureZulu: String?
    var scheduledDepartureLocal: String?
    var scheduledArrivalZulu: String?
    var scheduledArrivalLocal: String?
    var releaseZulu: String?
    var releaseLocal: String?
}

// MARK: - Raw iCalendar Event

struct ICalEvent: Codable {
    var uid: String
    var summary: String?
    var description: String?
    var location: String?
    var dtstart: Date?
    var dtend: Date?
    var dtstamp: Date?
    var organizer: String?
    var status: String?
    var categories: String?
    
    // Raw text for debugging
    var rawText: String?
}

// MARK: - Import Result

struct ImportResult {
    var totalEvents: Int
    var successfulImports: Int
    var skippedEvents: Int
    var failedEvents: Int
    var createdTrips: [Trip]
    var errors: [ImportError]
    var warnings: [ImportWarning]
}

struct ImportError: Identifiable {
    let id = UUID()
    var eventUID: String
    var eventSummary: String?
    var error: String
}

struct ImportWarning: Identifiable {
    let id = UUID()
    var eventUID: String
    var eventSummary: String?
    var warning: String
}

// MARK: - Preset Mappings

extension ImportMapping {
    
    // USA Jet RAIDO preset
    static var usaJetRAIDO: ImportMapping {
        let mappings = [
            iCalFieldMapping(
                sourceField: .summary,
                targetField: .flightNumber,
                extractionRule: ExtractionRule(
                    pattern: "^UJ\\d+",
                    captureGroup: 0
                )
            ),
            iCalFieldMapping(
                sourceField: .summary,
                targetField: .departureAirport,
                extractionRule: ExtractionRule(
                    pattern: "UJ\\d+\\s+(?:\\(X\\)\\s+)?([A-Z]{3})-",
                    captureGroup: 1
                )
            ),
            iCalFieldMapping(
                sourceField: .summary,
                targetField: .arrivalAirport,
                extractionRule: ExtractionRule(
                    pattern: "-([A-Z]{3})$",
                    captureGroup: 1
                )
            ),
            iCalFieldMapping(
                sourceField: .description,
                targetField: .aircraft,
                extractionRule: ExtractionRule(
                    pattern: "Aircraft:.*?([N][0-9]{3,4}[A-Z]{1,2})",
                    captureGroup: 1
                )
            )
        ]
        
        var filters = ActivityFilters()
        filters.flightKeywords = ["UJ"]
        filters.dutyKeywords = ["OND", "WOFF"]
        filters.offKeywords = ["OFF", "1/7"]
        filters.restKeywords = ["REST", "LB"]
        filters.deadheadKeywords = ["DL", "GT", "Deadhead"]
        
        return ImportMapping(
            name: "USA Jet RAIDO",
            fieldMappings: mappings,
            parsingRules: [],
            timezonePreference: TimezonePreference(preferredTimezone: .utc),
            isDefault: true,
            activityFilters: filters
        )
    }
    
    // Generic template
    static var generic: ImportMapping {
        ImportMapping(
            name: "Generic Template",
            fieldMappings: [],
            parsingRules: [],
            timezonePreference: .utc,
            isDefault: false,
            activityFilters: ActivityFilters()
        )
    }
}

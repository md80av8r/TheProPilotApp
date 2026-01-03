//
//  SDImportProfile.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/1/26.
//


import Foundation
import SwiftData

@Model
final class SDImportProfile {
    var id: UUID
    var airlineName: String
    var dateCreated: Date
    var lastUsed: Date
    var isActive: Bool
    var isBuiltIn: Bool  // Pre-shipped templates (can't be deleted)
    var isShared: Bool   // Shared by community
    
    // Parsing Rules for each field
    var flightNumberRule: ParsingRule?
    var departureRule: ParsingRule?
    var arrivalRule: ParsingRule?
    var scheduledOutRule: ParsingRule?
    var scheduledInRule: ParsingRule?
    var tripNumberRule: ParsingRule?
    var aircraftRule: ParsingRule?
    var pilotRoleRule: ParsingRule?
    var checkInRule: ParsingRule?
    var checkOutRule: ParsingRule?
    
    // Metadata
    var usageCount: Int  // How many times used (for sorting)
    var successRate: Double  // % of successful imports
    
    init(
        airlineName: String,
        isBuiltIn: Bool = false,
        isShared: Bool = false
    ) {
        self.id = UUID()
        self.airlineName = airlineName
        self.dateCreated = Date()
        self.lastUsed = Date()
        self.isActive = false
        self.isBuiltIn = isBuiltIn
        self.isShared = isShared
        self.usageCount = 0
        self.successRate = 0.0
    }
}

// MARK: - Parsing Rule
struct ParsingRule: Codable, Hashable {
    let sourceField: ICalField      // Which iCal field to read
    let extractionMethod: ExtractionMethod
    let regex: String?              // Regex pattern (if method = regex)
    let fallbackValue: String?      // Default if parsing fails
    
    enum ICalField: String, Codable {
        case summary = "SUMMARY"
        case description = "DESCRIPTION"
        case dtstart = "DTSTART"
        case dtend = "DTEND"
        case location = "LOCATION"
        case uid = "UID"
        case categories = "CATEGORIES"
        case status = "STATUS"
    }
    
    enum ExtractionMethod: String, Codable {
        case direct          // Use field value as-is
        case regex           // Apply regex pattern
        case split           // Split by delimiter
        case multiLine       // Parse multi-line DESCRIPTION
    }
    
    init(
        sourceField: ICalField,
        extractionMethod: ExtractionMethod = .direct,
        regex: String? = nil,
        fallbackValue: String? = nil
    ) {
        self.sourceField = sourceField
        self.extractionMethod = extractionMethod
        self.regex = regex
        self.fallbackValue = fallbackValue
    }
}
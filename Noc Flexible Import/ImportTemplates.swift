//
//  ImportTemplates.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/1/26.
//


import Foundation

struct ImportTemplates {
    
    /// Pre-built template for NOC (USA Jet) format
    static func nocTemplate() -> SDImportProfile {
        let profile = SDImportProfile(
            airlineName: "NOC (USA Jet)",
            isBuiltIn: true,
            isShared: false
        )
        
        // Flight Number: Extract from SUMMARY (e.g., "UJ465 LRD-CUU" -> "UJ465")
        profile.flightNumberRule = ParsingRule(
            sourceField: .summary,
            extractionMethod: .regex,
            regex: "^([A-Z]{2}\\d+)",
            fallbackValue: nil
        )
        
        // Departure: Extract from SUMMARY (e.g., "UJ465 LRD-CUU" -> "LRD")
        profile.departureRule = ParsingRule(
            sourceField: .summary,
            extractionMethod: .regex,
            regex: "([A-Z]{3})-[A-Z]{3}",
            fallbackValue: nil
        )
        
        // Arrival: Extract from SUMMARY (e.g., "UJ465 LRD-CUU" -> "CUU")
        profile.arrivalRule = ParsingRule(
            sourceField: .summary,
            extractionMethod: .regex,
            regex: "-([A-Z]{3})",
            fallbackValue: nil
        )
        
        // Scheduled Out: Extract from DESCRIPTION (e.g., "STD 2115Z / 1515L" -> "2115")
        profile.scheduledOutRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "STD (\\d{4})Z",
            fallbackValue: nil
        )
        
        // Scheduled In: Extract from DESCRIPTION (e.g., "STA 2230Z / 1630L" -> "2230")
        profile.scheduledInRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "STA (\\d{4})Z",
            fallbackValue: nil
        )
        
        // Aircraft Tail: Extract from DESCRIPTION (e.g., "Aircraft: M88 - M88 - M88 - N833US" -> "N833US")
        profile.aircraftRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "Aircraft:.*- (N\\d+\\w+)",
            fallbackValue: nil
        )
        
        // Pilot Role: Extract from DESCRIPTION (e.g., "RD: X" -> "X")
        profile.pilotRoleRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "RD: ([XL])",
            fallbackValue: nil
        )
        
        // Check-In: Extract from DESCRIPTION (e.g., "CI 2015Z / 1415L" -> "2015")
        profile.checkInRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "CI (\\d{4})Z",
            fallbackValue: nil
        )
        
        // Check-Out: Extract from DESCRIPTION (e.g., "CO 0800Z / 0300L" -> "0800")
        profile.checkOutRule = ParsingRule(
            sourceField: .description,
            extractionMethod: .regex,
            regex: "CO (\\d{4})Z",
            fallbackValue: nil
        )
        
        return profile
    }
    
    /// Generic fallback template (basic iCal fields only)
    static func genericTemplate() -> SDImportProfile {
        let profile = SDImportProfile(
            airlineName: "Generic iCal",
            isBuiltIn: true,
            isShared: false
        )
        
        // Use DTSTART/DTEND directly (no regex needed)
        profile.scheduledOutRule = ParsingRule(
            sourceField: .dtstart,
            extractionMethod: .direct,
            regex: nil,
            fallbackValue: nil
        )
        
        profile.scheduledInRule = ParsingRule(
            sourceField: .dtend,
            extractionMethod: .direct,
            regex: nil,
            fallbackValue: nil
        )
        
        // Try to get flight info from SUMMARY
        profile.flightNumberRule = ParsingRule(
            sourceField: .summary,
            extractionMethod: .direct,
            regex: nil,
            fallbackValue: "UNKNOWN"
        )
        
        return profile
    }
    
    /// Load all built-in templates
    static func allBuiltInTemplates() -> [SDImportProfile] {
        return [
            nocTemplate(),
            genericTemplate()
        ]
    }
}
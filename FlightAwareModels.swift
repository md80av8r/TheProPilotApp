// FlightAwareModels.swift - Data Models for FlightAware Integration
import Foundation
import SwiftUI

// MARK: - Core Data Models
struct FlightAwareFlight: Identifiable, Codable {
    let id = UUID()
    let ident: String
    let faFlightId: String?
    let actualOff: String?
    let actualOn: String?
    let origin: FlightAwareAirport?
    let destination: FlightAwareAirport?
    let lastPosition: FlightAwarePosition?
    let aircraft: FlightAwareAircraft?
    
    // Exclude 'id' from coding since it has a default value
    private enum CodingKeys: String, CodingKey {
        case ident, faFlightId, actualOff, actualOn, origin, destination, lastPosition, aircraft
    }
    
    var displayIdent: String {
        return ident.trimmingCharacters(in: .whitespaces)
    }
    
    var isUSAJet: Bool {
        return ident.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("JUS")
    }
    
    var statusString: String {
        if actualOff != nil && actualOn == nil {
            return "In Flight"
        } else if actualOn != nil {
            return "Arrived"
        } else {
            return "Scheduled"
        }
    }
    
    var routeString: String {
        let orig = origin?.code ?? "???"
        let dest = destination?.code ?? "???"
        return "\(orig) → \(dest)"
    }
}

struct FlightAwareAirport: Codable {
    let code: String
    let codeIcao: String?
    let codeIata: String?
    let codeLid: String?
    let timezone: String?
    let name: String?
    let city: String?
    let state: String?
    let elevation: Int?
    let latitude: Double?
    let longitude: Double?
}

struct FlightAwarePosition: Codable {
    let faFlightId: String?
    let altitude: Int?
    let altitudeChange: String?
    let groundspeed: Int?
    let heading: Int?
    let latitude: Double?
    let longitude: Double?
    let timestamp: String?
    let updateType: String?
}

struct FlightAwareAircraft: Codable {
    let type: String?
    let registration: String?
}

// MARK: - API Response Models
struct ValidationResult {
    let isValid: Bool
    let status: APIStatus
    let errorMessage: String?
    let debugInfo: String
}

// MARK: - API Status
enum APIStatus {
    case unknown
    case free
    case basic
    case premium
    case enterprise
    case invalid
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .free: return "Free (Very Limited)"
        case .basic: return "Basic Plan"
        case .premium: return "Premium Plan"
        case .enterprise: return "Enterprise Plan"
        case .invalid: return "Invalid/Expired"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return LogbookTheme.textSecondary
        case .free: return LogbookTheme.accentOrange
        case .basic: return LogbookTheme.accentBlue
        case .premium: return LogbookTheme.accentGreen
        case .enterprise: return LogbookTheme.accentGreen
        case .invalid: return LogbookTheme.errorRed
        }
    }
}

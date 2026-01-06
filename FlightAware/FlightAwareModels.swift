//
//  FlightAwareModels.swift
//  TheProPilotApp
//
//  Clean Codable models for FlightAware AeroAPI v4
//

import Foundation

// MARK: - API Response Models

/// Main flight data from FlightAware AeroAPI
struct FAFlight: Codable, Identifiable, Hashable {
    let faFlightId: String
    let ident: String
    let identIcao: String?
    let identIata: String?
    let operator_: String?
    let operatorIcao: String?
    let operatorIata: String?
    let flightNumber: String?
    let registration: String?
    let atcIdent: String?
    let inboundFaFlightId: String?
    let codeshares: [String]?
    let codesharesFlight: Bool?
    let blocked: Bool?
    let diverted: Bool?
    let cancelled: Bool?
    let positionOnly: Bool?

    // Origin/Destination
    let origin: FAEndpoint?
    let destination: FAEndpoint?

    // Times - Scheduled
    let scheduledOut: Date?
    let scheduledOff: Date?
    let scheduledOn: Date?
    let scheduledIn: Date?

    // Times - Estimated
    let estimatedOut: Date?
    let estimatedOff: Date?
    let estimatedOn: Date?
    let estimatedIn: Date?

    // Times - Actual
    let actualOut: Date?
    let actualOff: Date?
    let actualOn: Date?
    let actualIn: Date?

    // Gate Information
    let gateOrigin: String?
    let gateDestination: String?
    let terminalOrigin: String?
    let terminalDestination: String?
    let baggageClaim: String?

    // Route & Aircraft
    let route: String?
    let routeDistance: Int?
    let filedEte: Int? // Estimated time enroute in seconds
    let filedAltitude: Int?
    let filedAirspeedKts: Int?
    let filedAirspeedMach: Double?
    let aircraftType: String?

    // Status
    let status: String?
    let progressPercent: Int?

    // Position (for in-flight)
    let lastPosition: FAPosition?

    var id: String { faFlightId }

    // CodingKeys to handle the operator keyword
    enum CodingKeys: String, CodingKey {
        case faFlightId = "fa_flight_id"
        case ident
        case identIcao = "ident_icao"
        case identIata = "ident_iata"
        case operator_ = "operator"
        case operatorIcao = "operator_icao"
        case operatorIata = "operator_iata"
        case flightNumber = "flight_number"
        case registration
        case atcIdent = "atc_ident"
        case inboundFaFlightId = "inbound_fa_flight_id"
        case codeshares
        case codesharesFlight = "codeshares_iata"
        case blocked
        case diverted
        case cancelled
        case positionOnly = "position_only"
        case origin
        case destination
        case scheduledOut = "scheduled_out"
        case scheduledOff = "scheduled_off"
        case scheduledOn = "scheduled_on"
        case scheduledIn = "scheduled_in"
        case estimatedOut = "estimated_out"
        case estimatedOff = "estimated_off"
        case estimatedOn = "estimated_on"
        case estimatedIn = "estimated_in"
        case actualOut = "actual_out"
        case actualOff = "actual_off"
        case actualOn = "actual_on"
        case actualIn = "actual_in"
        case gateOrigin = "gate_origin"
        case gateDestination = "gate_destination"
        case terminalOrigin = "terminal_origin"
        case terminalDestination = "terminal_destination"
        case baggageClaim = "baggage_claim"
        case route
        case routeDistance = "route_distance"
        case filedEte = "filed_ete"
        case filedAltitude = "filed_altitude"
        case filedAirspeedKts = "filed_airspeed_kts"
        case filedAirspeedMach = "filed_airspeed_mach"
        case aircraftType = "aircraft_type"
        case status
        case progressPercent = "progress_percent"
        case lastPosition = "last_position"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(faFlightId)
    }

    static func == (lhs: FAFlight, rhs: FAFlight) -> Bool {
        lhs.faFlightId == rhs.faFlightId
    }
}

/// Airport/waypoint endpoint information
struct FAEndpoint: Codable, Hashable {
    let code: String?
    let codeIcao: String?
    let codeIata: String?
    let codeLid: String?
    let airportInfoUrl: String?
    let name: String?
    let city: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case code
        case codeIcao = "code_icao"
        case codeIata = "code_iata"
        case codeLid = "code_lid"
        case airportInfoUrl = "airport_info_url"
        case name
        case city
        case timezone
    }

    /// Best available airport code (prefers ICAO)
    var displayCode: String {
        codeIcao ?? code ?? codeIata ?? codeLid ?? "????"
    }
}

/// Aircraft position data
struct FAPosition: Codable, Hashable {
    let faFlightId: String?
    let altitude: Int?
    let altitudeChange: String?
    let groundspeed: Int?
    let heading: Int?
    let latitude: Double?
    let longitude: Double?
    let timestamp: Date?
    let updateType: String?

    enum CodingKeys: String, CodingKey {
        case faFlightId = "fa_flight_id"
        case altitude
        case altitudeChange = "altitude_change"
        case groundspeed
        case heading
        case latitude
        case longitude
        case timestamp
        case updateType = "update_type"
    }
}

// MARK: - API Response Wrappers

/// Response from /flights/{ident} endpoint
struct FAFlightsResponse: Codable {
    let flights: [FAFlight]
    let links: FALinks?
    let numPages: Int?

    enum CodingKeys: String, CodingKey {
        case flights
        case links
        case numPages = "num_pages"
    }
}

/// Pagination links
struct FALinks: Codable {
    let next: String?
}

// MARK: - Error Types

enum FlightAwareError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case rateLimitExceeded
    case flightNotFound
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "FlightAware API key not configured"
        case .invalidAPIKey:
            return "Invalid FlightAware API key"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .flightNotFound:
            return "Flight not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown")"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Cached Flight Data (for persistence)

/// Lightweight version of FAFlight for storing in Trip/FlightLeg
struct FAFlightCache: Codable, Hashable {
    let faFlightId: String
    let ident: String
    let originCode: String?
    let destinationCode: String?
    let route: String?
    let routeDistance: Int?
    let gateOrigin: String?
    let gateDestination: String?
    let terminalOrigin: String?
    let terminalDestination: String?
    let estimatedOn: Date?
    let estimatedIn: Date?
    let status: String?
    let aircraftType: String?
    let registration: String?
    let lastUpdated: Date

    /// Create from full FAFlight
    init(from flight: FAFlight) {
        self.faFlightId = flight.faFlightId
        self.ident = flight.ident
        self.originCode = flight.origin?.displayCode
        self.destinationCode = flight.destination?.displayCode
        self.route = flight.route
        self.routeDistance = flight.routeDistance
        self.gateOrigin = flight.gateOrigin
        self.gateDestination = flight.gateDestination
        self.terminalOrigin = flight.terminalOrigin
        self.terminalDestination = flight.terminalDestination
        self.estimatedOn = flight.estimatedOn
        self.estimatedIn = flight.estimatedIn
        self.status = flight.status
        self.aircraftType = flight.aircraftType
        self.registration = flight.registration
        self.lastUpdated = Date()
    }

    /// FlightAware tracking URL
    var trackingURL: URL? {
        URL(string: "https://flightaware.com/live/flight/\(ident)")
    }

    /// Formatted gate display (e.g., "B12 → T4-A23")
    var gateDisplay: String? {
        let origin = [terminalOrigin, gateOrigin].compactMap { $0 }.joined(separator: "-")
        let dest = [terminalDestination, gateDestination].compactMap { $0 }.joined(separator: "-")

        if origin.isEmpty && dest.isEmpty {
            return nil
        } else if origin.isEmpty {
            return "→ \(dest)"
        } else if dest.isEmpty {
            return "\(origin) →"
        } else {
            return "\(origin) → \(dest)"
        }
    }

    /// Time remaining to ETA
    var timeToArrival: TimeInterval? {
        guard let eta = estimatedOn ?? estimatedIn else { return nil }
        let remaining = eta.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Formatted ETA display
    var etaDisplay: String? {
        guard let eta = estimatedOn ?? estimatedIn else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: eta)
    }
}

// MARK: - Flight Status

extension FAFlight {
    /// Human-readable flight status
    var statusDescription: String {
        if cancelled == true {
            return "Cancelled"
        }
        if diverted == true {
            return "Diverted"
        }

        // Check actual times to determine phase
        if actualIn != nil {
            return "Arrived"
        }
        if actualOn != nil {
            return "Landed"
        }
        if actualOff != nil {
            return "In Flight"
        }
        if actualOut != nil {
            return "Taxiing"
        }

        // Not departed yet
        if let scheduledOut = scheduledOut {
            if scheduledOut > Date() {
                return "Scheduled"
            } else {
                return "Delayed"
            }
        }

        return status ?? "Unknown"
    }

    /// Best ETA (estimated arrival at gate or on runway)
    var bestETA: Date? {
        estimatedIn ?? estimatedOn ?? scheduledIn ?? scheduledOn
    }
}

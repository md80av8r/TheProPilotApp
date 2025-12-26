//
//  FlightScheduleService.swift
//  TheProPilotApp
//
//  Flight schedule integration for jumpseat finding
//  Uses AviationStack API (free tier: 100 requests/month)
//

import Foundation

// MARK: - Flight Schedule Models

struct FlightSchedule: Identifiable, Codable {
    var id: String { "\(airline)-\(flightNumber)-\(departureTime.timeIntervalSince1970)" }
    let flightNumber: String
    let airline: String
    let airlineIATA: String
    let departure: String
    let arrival: String
    let departureTime: Date
    let arrivalTime: Date
    let aircraft: String?
    let status: FlightStatus
    let gate: String?
    let terminal: String?
    
    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case airline
        case airlineIATA = "airline_iata"
        case departure
        case arrival
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case aircraft
        case status
        case gate
        case terminal
    }
    
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: departureTime) + "Z"
    }
    
    var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: arrivalTime) + "Z"
    }
    
    var loadIndicator: LoadStatus {
        // Estimated load based on availability (Phase 2 feature)
        // For now, return unknown
        return .unknown
    }
}

enum FlightStatus: String, Codable {
    case scheduled
    case active
    case landed
    case cancelled
    case incident
    case diverted
    
    var color: String {
        switch self {
        case .scheduled: return "gray"
        case .active: return "green"
        case .landed: return "blue"
        case .cancelled, .incident, .diverted: return "red"
        }
    }
}

enum LoadStatus {
    case available  // Green - likely open seats
    case tight      // Yellow - may be tight
    case full       // Red - likely full
    case unknown    // Gray - no data
    
    var color: String {
        switch self {
        case .available: return "green"
        case .tight: return "yellow"
        case .full: return "red"
        case .unknown: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .tight: return "exclamationmark.triangle.fill"
        case .full: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - AviationStack Response Models

struct AviationStackResponse: Codable {
    let data: [AviationStackFlight]?
    let error: AviationStackError?
}

struct AviationStackFlight: Codable {
    let flight_date: String
    let flight_status: String
    let departure: AviationStackAirport
    let arrival: AviationStackAirport
    let airline: AviationStackAirline
    let flight: AviationStackFlightInfo
    let aircraft: AviationStackAircraft?
}

struct AviationStackAirport: Codable {
    let airport: String
    let timezone: String?
    let iata: String?
    let icao: String?
    let terminal: String?
    let gate: String?
    let scheduled: String?
    let estimated: String?
}

struct AviationStackAirline: Codable {
    let name: String
    let iata: String?
    let icao: String?
}

struct AviationStackFlightInfo: Codable {
    let number: String
    let iata: String?
    let icao: String?
}

struct AviationStackAircraft: Codable {
    let registration: String?
    let iata: String?
    let icao: String?
}

struct AviationStackError: Codable {
    let code: String
    let message: String
}

// MARK: - Flight Schedule Service

class FlightScheduleService {
    static let shared = FlightScheduleService()
    
    private let baseURL = "http://api.aviationstack.com/v1"
    
    private init() {}
    
    // MARK: - Search Flights
    
    /// Search for flights between two airports
    /// - Parameters:
    ///   - from: Departure airport code (ICAO or IATA)
    ///   - to: Arrival airport code (ICAO or IATA)
    ///   - date: Optional date (defaults to today)
    /// - Returns: Array of flight schedules
    func searchFlights(from: String, to: String, date: Date = Date()) async throws -> [FlightSchedule] {
        // Get API key from UserDefaults (set in Settings)
        let userApiKey = UserDefaults.standard.string(forKey: "aviationStackAPIKey") ?? ""
        
        // If no API key, throw error to trigger mock data
        guard !userApiKey.isEmpty else {
            throw FlightScheduleError.noAPIKey
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Convert ICAO to IATA if needed (AviationStack prefers IATA)
        let fromCode = convertToIATA(from)
        let toCode = convertToIATA(to)
        
        let urlString = "\(baseURL)/flights?access_key=\(userApiKey)&dep_iata=\(fromCode)&arr_iata=\(toCode)&flight_date=\(dateString)"
        
        guard let url = URL(string: urlString) else {
            throw FlightScheduleError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FlightScheduleError.invalidResponse
            }
            
            if httpResponse.statusCode == 429 {
                throw FlightScheduleError.rateLimitExceeded
            }
            
            guard httpResponse.statusCode == 200 else {
                throw FlightScheduleError.apiError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(AviationStackResponse.self, from: data)
            
            if let error = result.error {
                throw FlightScheduleError.apiMessage(error.message)
            }
            
            guard let flights = result.data else {
                return []
            }
            
            return flights.compactMap { convertToFlightSchedule($0) }
            
        } catch let error as FlightScheduleError {
            throw error
        } catch {
            throw FlightScheduleError.networkError(error)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Convert ICAO code to IATA (basic conversion for common airports)
    private func convertToIATA(_ code: String) -> String {
        let uppercased = code.uppercased()
        
        // If already IATA (3 letters), return as-is
        if uppercased.count == 3 {
            return uppercased
        }
        
        // Basic ICAO to IATA conversion for US airports
        // Remove 'K' prefix for US airports (e.g., KLAX -> LAX)
        if uppercased.hasPrefix("K") && uppercased.count == 4 {
            return String(uppercased.dropFirst())
        }
        
        // For other airports, return as-is and let API handle it
        return uppercased
    }
    
    /// Convert AviationStack flight to FlightSchedule model
    private func convertToFlightSchedule(_ flight: AviationStackFlight) -> FlightSchedule? {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let depTime = iso8601Formatter.date(from: flight.departure.scheduled ?? ""),
              let arrTime = iso8601Formatter.date(from: flight.arrival.scheduled ?? "") else {
            print("⚠️ Could not parse dates for flight \(flight.flight.number)")
            return nil
        }
        
        let flightNumber = flight.airline.iata ?? flight.airline.icao ?? ""
        let airlineCode = flight.flight.iata ?? flight.flight.icao ?? flight.flight.number
        
        let status = FlightStatus(rawValue: flight.flight_status) ?? .scheduled
        
        return FlightSchedule(
            flightNumber: "\(flightNumber)\(airlineCode)",
            airline: flight.airline.name,
            airlineIATA: flight.airline.iata ?? "",
            departure: flight.departure.iata ?? flight.departure.icao ?? "",
            arrival: flight.arrival.iata ?? flight.arrival.icao ?? "",
            departureTime: depTime,
            arrivalTime: arrTime,
            aircraft: flight.aircraft?.icao ?? flight.aircraft?.iata,
            status: status,
            gate: flight.departure.gate,
            terminal: flight.departure.terminal
        )
    }
}

// MARK: - Errors

enum FlightScheduleError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case apiError(statusCode: Int)
    case apiMessage(String)
    case networkError(Error)
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .apiError(let code):
            return "API error: HTTP \(code)"
        case .apiMessage(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noAPIKey:
            return "No API key configured. Please add your AviationStack API key."
        }
    }
}

// MARK: - Mock Data (for testing without API key)

extension FlightScheduleService {
    func getMockFlights(from: String, to: String) -> [FlightSchedule] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            FlightSchedule(
                flightNumber: "DL1234",
                airline: "Delta Air Lines",
                airlineIATA: "DL",
                departure: from,
                arrival: to,
                departureTime: calendar.date(byAdding: .hour, value: 2, to: now)!,
                arrivalTime: calendar.date(byAdding: .hour, value: 5, to: now)!,
                aircraft: "B738",
                status: .scheduled,
                gate: "A12",
                terminal: "A"
            ),
            FlightSchedule(
                flightNumber: "AA5678",
                airline: "American Airlines",
                airlineIATA: "AA",
                departure: from,
                arrival: to,
                departureTime: calendar.date(byAdding: .hour, value: 4, to: now)!,
                arrivalTime: calendar.date(byAdding: .hour, value: 7, to: now)!,
                aircraft: "A320",
                status: .scheduled,
                gate: "B5",
                terminal: "B"
            ),
            FlightSchedule(
                flightNumber: "UA9012",
                airline: "United Airlines",
                airlineIATA: "UA",
                departure: from,
                arrival: to,
                departureTime: calendar.date(byAdding: .hour, value: 6, to: now)!,
                arrivalTime: calendar.date(byAdding: .hour, value: 9, to: now)!,
                aircraft: "B739",
                status: .scheduled,
                gate: "C22",
                terminal: "C"
            )
        ]
    }
}

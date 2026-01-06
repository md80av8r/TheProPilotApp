//
//  FlightAwareService.swift
//  TheProPilotApp
//
//  Clean async/await API layer for FlightAware AeroAPI v4
//

import Foundation

/// FlightAware AeroAPI v4 service
/// Handles all HTTP communication with FlightAware
actor FlightAwareService {
    static let shared = FlightAwareService()

    private let baseURL = "https://aeroapi.flightaware.com/aeroapi"
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        // AeroAPI uses ISO8601 with fractional seconds
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple formats
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }

    // MARK: - Public API

    /// Look up flights by ident (e.g., "JUS1302")
    /// Returns most recent flight matching the ident
    func getFlight(ident: String, apiKey: String, date: Date? = nil) async throws -> FAFlight? {
        let flights = try await getFlights(ident: ident, apiKey: apiKey, startDate: date, maxPages: 1)
        return flights.first
    }

    /// Get all flights for an ident within a date range
    func getFlights(
        ident: String,
        apiKey: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        maxPages: Int = 1
    ) async throws -> [FAFlight] {
        var urlComponents = URLComponents(string: "\(baseURL)/flights/\(ident)")!

        var queryItems: [URLQueryItem] = []

        if let start = startDate {
            queryItems.append(URLQueryItem(name: "start", value: iso8601String(from: start)))
        }
        if let end = endDate {
            queryItems.append(URLQueryItem(name: "end", value: iso8601String(from: end)))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw FlightAwareError.unknown("Invalid URL")
        }

        let response: FAFlightsResponse = try await request(url: url, apiKey: apiKey)
        return response.flights
    }

    /// Get flights for an operator (e.g., "JUS" for USA Jet)
    func getOperatorFlights(
        operatorCode: String,
        apiKey: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [FAFlight] {
        var urlComponents = URLComponents(string: "\(baseURL)/operators/\(operatorCode)/flights")!

        var queryItems: [URLQueryItem] = []

        if let start = startDate {
            queryItems.append(URLQueryItem(name: "start", value: iso8601String(from: start)))
        }
        if let end = endDate {
            queryItems.append(URLQueryItem(name: "end", value: iso8601String(from: end)))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw FlightAwareError.unknown("Invalid URL")
        }

        let response: FAFlightsResponse = try await request(url: url, apiKey: apiKey)
        return response.flights
    }

    /// Get a specific flight by FlightAware flight ID
    func getFlightById(faFlightId: String, apiKey: String) async throws -> FAFlight? {
        let url = URL(string: "\(baseURL)/flights/\(faFlightId)")!
        let response: FAFlightsResponse = try await request(url: url, apiKey: apiKey)
        return response.flights.first
    }

    /// Get airport arrivals/departures
    func getAirportFlights(
        airportCode: String,
        apiKey: String,
        type: AirportFlightType = .scheduledDepartures,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [FAFlight] {
        var urlComponents = URLComponents(string: "\(baseURL)/airports/\(airportCode)/flights/\(type.rawValue)")!

        var queryItems: [URLQueryItem] = []

        if let start = startDate {
            queryItems.append(URLQueryItem(name: "start", value: iso8601String(from: start)))
        }
        if let end = endDate {
            queryItems.append(URLQueryItem(name: "end", value: iso8601String(from: end)))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw FlightAwareError.unknown("Invalid URL")
        }

        let response: FAFlightsResponse = try await request(url: url, apiKey: apiKey)
        return response.flights
    }

    /// Test API connectivity
    func testConnection(apiKey: String) async throws -> Bool {
        // Use a simple endpoint to test the API key
        let url = URL(string: "\(baseURL)/airports/KJFK")!

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlightAwareError.unknown("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return true
        case 401:
            throw FlightAwareError.invalidAPIKey
        case 429:
            throw FlightAwareError.rateLimitExceeded
        default:
            throw FlightAwareError.serverError(httpResponse.statusCode, nil)
        }
    }

    // MARK: - Private Helpers

    private func request<T: Decodable>(url: URL, apiKey: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        request.httpMethod = "GET"

        #if DEBUG
        print("[FlightAware] Request: \(url.absoluteString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FlightAwareError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlightAwareError.unknown("Invalid response")
        }

        #if DEBUG
        print("[FlightAware] Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[FlightAware] Body: \(responseString.prefix(500))")
        }
        #endif

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw FlightAwareError.invalidAPIKey
        case 404:
            throw FlightAwareError.flightNotFound
        case 429:
            throw FlightAwareError.rateLimitExceeded
        case 400...499:
            let message = String(data: data, encoding: .utf8)
            throw FlightAwareError.serverError(httpResponse.statusCode, message)
        case 500...599:
            throw FlightAwareError.serverError(httpResponse.statusCode, "Server error")
        default:
            throw FlightAwareError.unknown("Unexpected status: \(httpResponse.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[FlightAware] Decoding error: \(error)")
            #endif
            throw FlightAwareError.decodingError(error)
        }
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum AirportFlightType: String {
    case scheduledDepartures = "scheduled_departures"
    case scheduledArrivals = "scheduled_arrivals"
    case departures
    case arrivals
}

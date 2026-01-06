//
//  FlightAwareRepository.swift
//  TheProPilotApp
//
//  Caching, KeyChain storage, and data management for FlightAware
//

import Foundation
import Security
import SwiftUI

/// Main repository for FlightAware data management
/// Handles API key storage (KeyChain), caching, and coordinates with the service
@MainActor
class FlightAwareRepository: ObservableObject {
    static let shared = FlightAwareRepository()

    // MARK: - Published State

    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: FlightAwareError?
    @Published private(set) var cachedFlights: [String: FAFlightCache] = [:]

    // MARK: - Private

    private let service = FlightAwareService.shared
    private let keychainKey = "com.propilot.flightaware.apikey"
    private var apiKey: String?

    private init() {
        loadAPIKey()
    }

    // MARK: - Configuration

    /// Check if FlightAware is configured and ready
    var isReady: Bool {
        isConfigured && apiKey != nil && !apiKey!.isEmpty
    }

    /// Configure with an API key
    func configure(apiKey: String) {
        self.apiKey = apiKey
        saveAPIKey(apiKey)
        isConfigured = !apiKey.isEmpty
        lastError = nil
    }

    /// Clear configuration
    func clearConfiguration() {
        apiKey = nil
        deleteAPIKey()
        isConfigured = false
        cachedFlights.removeAll()
    }

    /// Test the API connection
    func testConnection() async -> Result<Bool, FlightAwareError> {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return .failure(.notConfigured)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await service.testConnection(apiKey: apiKey)
            lastError = nil
            return .success(success)
        } catch let error as FlightAwareError {
            lastError = error
            return .failure(error)
        } catch {
            let faError = FlightAwareError.networkError(error)
            lastError = faError
            return .failure(faError)
        }
    }

    // MARK: - Flight Lookup

    /// Look up a flight by ident and optional date
    /// Uses caching to avoid duplicate API calls
    func lookupFlight(ident: String, date: Date = Date(), forceRefresh: Bool = false) async -> Result<FAFlightCache?, FlightAwareError> {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return .failure(.notConfigured)
        }

        let cacheKey = makeCacheKey(ident: ident, date: date)

        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = cachedFlights[cacheKey] {
            // Cache valid for 5 minutes
            if Date().timeIntervalSince(cached.lastUpdated) < 300 {
                return .success(cached)
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let flight = try await service.getFlight(ident: ident, apiKey: apiKey, date: date) else {
                return .success(nil)
            }

            let cache = FAFlightCache(from: flight)
            cachedFlights[cacheKey] = cache
            lastError = nil

            return .success(cache)
        } catch let error as FlightAwareError {
            lastError = error
            return .failure(error)
        } catch {
            let faError = FlightAwareError.networkError(error)
            lastError = faError
            return .failure(faError)
        }
    }

    /// Look up flights for a trip (all legs with flight numbers or N-numbers)
    func lookupFlightsForTrip(_ trip: Trip, airlinePrefix: String, useNNumber: Bool = false, defaultNNumber: String = "") async -> [String: FAFlightCache] {
        guard isReady else { return [:] }

        var results: [String: FAFlightCache] = [:]

        for leg in trip.legs {
            let ident: String

            if useNNumber {
                // N-number mode: use tail number from leg, or default N-number
                if let tailNumber = leg.tailNumber, !tailNumber.isEmpty {
                    ident = buildNNumberIdent(tailNumber)
                } else if !defaultNNumber.isEmpty {
                    ident = buildNNumberIdent(defaultNNumber)
                } else {
                    continue // No N-number available
                }
            } else {
                // Flight number mode
                guard !leg.flightNumber.isEmpty else { continue }
                ident = buildIdent(prefix: airlinePrefix, number: leg.flightNumber)
            }

            let legDate = leg.flightDate ?? trip.date

            let result = await lookupFlight(ident: ident, date: legDate)
            if case .success(let cache) = result, let cache = cache {
                results[leg.id.uuidString] = cache
            }
        }

        return results
    }

    /// Refresh flight data for an active trip
    func refreshActiveFlight(ident: String, date: Date) async -> FAFlightCache? {
        let result = await lookupFlight(ident: ident, date: date, forceRefresh: true)
        if case .success(let cache) = result {
            return cache
        }
        return nil
    }

    // MARK: - Helpers

    /// Build flight ident from airline prefix and flight number
    func buildIdent(prefix: String, number: String) -> String {
        // Clean up the prefix (remove spaces, ensure uppercase)
        let cleanPrefix = prefix.trimmingCharacters(in: .whitespaces).uppercased()
        // Clean up the number (remove leading zeros if pure digits, keep as-is otherwise)
        let cleanNumber = number.trimmingCharacters(in: .whitespaces)

        return "\(cleanPrefix)\(cleanNumber)"
    }

    /// Build flight ident for N-number tracking
    /// N-numbers are used directly as the ident (e.g., "N12345")
    func buildNNumberIdent(_ nNumber: String) -> String {
        var cleanNNumber = nNumber.trimmingCharacters(in: .whitespaces).uppercased()
        // Ensure it starts with "N" if user forgot to include it
        if !cleanNNumber.hasPrefix("N") {
            cleanNNumber = "N" + cleanNNumber
        }
        return cleanNNumber
    }

    /// Build ident based on tracking mode (N-number vs flight number)
    func buildIdent(forLeg leg: FlightLeg, settings: AirlineSettings) -> String? {
        if settings.useNNumberTracking {
            // N-number mode: use tail number from leg, or default N-number from settings
            if let tailNumber = leg.tailNumber, !tailNumber.isEmpty {
                return buildNNumberIdent(tailNumber)
            } else if !settings.defaultNNumber.isEmpty {
                return buildNNumberIdent(settings.defaultNNumber)
            }
            return nil
        } else {
            // Flight number mode: use airline prefix + flight number
            guard !leg.flightNumber.isEmpty else { return nil }
            return buildIdent(prefix: settings.flightNumberPrefix, number: leg.flightNumber)
        }
    }

    private func makeCacheKey(ident: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(ident.uppercased())_\(dateFormatter.string(from: date))"
    }

    // MARK: - KeyChain Storage

    private func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!

        // Delete existing first
        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[FlightAware] Failed to save API key to KeyChain: \(status)")
        }
    }

    private func loadAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) {
            self.apiKey = key
            self.isConfigured = !key.isEmpty
        } else {
            self.apiKey = nil
            self.isConfigured = false
        }
    }

    private func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Cache Management

    /// Clear all cached flight data
    func clearCache() {
        cachedFlights.removeAll()
    }

    /// Get cached flight by ident
    func getCachedFlight(ident: String, date: Date) -> FAFlightCache? {
        let key = makeCacheKey(ident: ident, date: date)
        return cachedFlights[key]
    }
}

// MARK: - Trip Extension for FlightAware

extension Trip {
    /// Get FlightAware idents for all legs that have flight numbers
    func getFlightIdents(airlinePrefix: String) -> [(legId: UUID, ident: String, date: Date)] {
        legs.compactMap { leg in
            guard !leg.flightNumber.isEmpty else { return nil }
            // Build ident inline to avoid actor isolation issues
            let cleanPrefix = airlinePrefix.trimmingCharacters(in: .whitespaces).uppercased()
            let cleanNumber = leg.flightNumber.trimmingCharacters(in: .whitespaces)
            let ident = "\(cleanPrefix)\(cleanNumber)"
            let legDate = leg.flightDate ?? date
            return (leg.id, ident, legDate)
        }
    }

    /// Get FlightAware idents for N-number tracking mode
    func getNNumberIdents(defaultNNumber: String) -> [(legId: UUID, ident: String, date: Date)] {
        legs.compactMap { leg in
            // Use tail number from leg if available, otherwise use default
            let nNumber: String
            if let tailNumber = leg.tailNumber, !tailNumber.isEmpty {
                nNumber = tailNumber
            } else if !defaultNNumber.isEmpty {
                nNumber = defaultNNumber
            } else {
                return nil
            }

            // Clean up N-number
            var cleanNNumber = nNumber.trimmingCharacters(in: .whitespaces).uppercased()
            if !cleanNNumber.hasPrefix("N") {
                cleanNNumber = "N" + cleanNNumber
            }

            let legDate = leg.flightDate ?? date
            return (leg.id, cleanNNumber, legDate)
        }
    }

    /// Get FlightAware idents based on tracking mode
    func getFlightIdents(settings: AirlineSettings) -> [(legId: UUID, ident: String, date: Date)] {
        if settings.useNNumberTracking {
            return getNNumberIdents(defaultNNumber: settings.defaultNNumber)
        } else {
            return getFlightIdents(airlinePrefix: settings.flightNumberPrefix)
        }
    }
}

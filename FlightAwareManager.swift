// FlightAwareManager.swift - Business Logic for FlightAware Integration
import Foundation
import SwiftUI
import UIKit

// MARK: - Enhanced FlightAware Manager
class EnhancedFlightAwareManager: ObservableObject {
    static let shared = EnhancedFlightAwareManager()
    
    @Published var isLoggedIn = false
    @Published var credentials: FlightAwareCredentials?
    @Published var flightAwareFlights: [FlightAwareFlight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdate: Date?
    @Published var debugInfo: String = ""
    @Published var apiStatus: APIStatus = .unknown
    
    private let baseURL = "https://aeroapi.flightaware.com/aeroapi"
    private let userDefaults = UserDefaults.shared
    
    init() {
        loadSavedCredentials()
    }
    
    // MARK: - Authentication
    func login(username: String, apiKey: String) async {
        let testCredentials = FlightAwareCredentials(username: username, apiKey: apiKey)
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            debugInfo = "Testing FlightAware credentials..."
        }
        
        do {
            let result = try await validateCredentialsDetailed(testCredentials)
            
            await MainActor.run {
                if result.isValid {
                    self.credentials = testCredentials
                    self.isLoggedIn = true
                    self.saveCredentials(testCredentials)
                    self.errorMessage = nil
                    self.apiStatus = result.status
                    self.debugInfo = result.debugInfo
                } else {
                    self.errorMessage = result.errorMessage
                    self.debugInfo = result.debugInfo
                    self.apiStatus = .invalid
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.debugInfo = "Failed to connect to FlightAware API. Check internet connection."
                self.isLoading = false
            }
        }
    }
    
    // Validate existing credentials silently (for auto-login validation)
    func validateExistingCredentials() async {
        guard let creds = credentials else { return }
        
        do {
            let result = try await validateCredentialsDetailed(creds)
            
            await MainActor.run {
                if result.isValid {
                    self.apiStatus = result.status
                    self.debugInfo = "Existing credentials validated: \(result.status.description)"
                } else {
                    // Credentials are no longer valid, logout
                    self.logout()
                    self.errorMessage = "Saved credentials are no longer valid. Please log in again."
                }
            }
        } catch {
            await MainActor.run {
                self.debugInfo = "Could not validate existing credentials: \(error.localizedDescription)"
            }
        }
    }
    
    private func validateCredentialsDetailed(_ creds: FlightAwareCredentials) async throws -> ValidationResult {
        var debugInfo = ""
        
        // Try multiple endpoints to determine API access level
        let endpoints = [
            "/flights/search?query=JUS*&max_pages=1", // Search for USA Jet flights specifically
            "/airports/KORD/flights?max_pages=1",      // Airport data
            "/operators"                               // Operator data
        ]
        
        for (index, endpoint) in endpoints.enumerated() {
            guard let url = URL(string: "\(baseURL)\(endpoint)") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("BlockCalc-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue(creds.apiKey, forHTTPHeaderField: "x-apikey")
            
            debugInfo += "Testing endpoint \(index + 1)/\(endpoints.count): \(endpoint)\n"
            debugInfo += "Using x-apikey authentication header\n"
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    debugInfo += "Response code: \(httpResponse.statusCode)\n"
                    
                    switch httpResponse.statusCode {
                    case 200:
                        debugInfo += "✅ Success! API access confirmed.\n"
                        let status = determineAPIStatus(from: httpResponse, data: data)
                        return ValidationResult(
                            isValid: true,
                            status: status,
                            errorMessage: nil,
                            debugInfo: debugInfo
                        )
                        
                    case 401:
                        debugInfo += "❌ 401 Unauthorized - Invalid username or API key\n"
                        return ValidationResult(
                            isValid: false,
                            status: .invalid,
                            errorMessage: "Invalid FlightAware username or API key. Please check your credentials.",
                            debugInfo: debugInfo
                        )
                        
                    case 403:
                        debugInfo += "⚠️ 403 Forbidden - Account lacks API access\n"
                        return ValidationResult(
                            isValid: false,
                            status: .invalid,
                            errorMessage: "Your FlightAware account doesn't have API access enabled. You may need to upgrade your plan.",
                            debugInfo: debugInfo
                        )
                        
                    case 429:
                        debugInfo += "⚠️ 429 Rate Limited - Too many requests\n"
                        return ValidationResult(
                            isValid: false,
                            status: .free,
                            errorMessage: "Rate limit exceeded. Free accounts have very limited API calls.",
                            debugInfo: debugInfo
                        )
                        
                    case 500...599:
                        debugInfo += "🔧 \(httpResponse.statusCode) Server Error - FlightAware issue\n"
                        
                    default:
                        debugInfo += "❓ \(httpResponse.statusCode) Unknown Response\n"
                    }
                }
            } catch {
                debugInfo += "Network error: \(error.localizedDescription)\n"
            }
        }
        
        return ValidationResult(
            isValid: false,
            status: .invalid,
            errorMessage: "Unable to validate FlightAware access. See debug info for details.",
            debugInfo: debugInfo
        )
    }
    
    private func determineAPIStatus(from response: HTTPURLResponse, data: Data) -> APIStatus {
        // Check response headers for plan information
        if let planHeader = response.allHeaderFields["x-aeroapi-plan"] as? String {
            switch planHeader.lowercased() {
            case "free": return .free
            case "basic": return .basic
            case "premium": return .premium
            case "enterprise": return .enterprise
            default: return .unknown
            }
        }
        
        // Try to determine from data size/content
        if data.count < 100 {
            return .free // Very limited data suggests free plan
        } else if data.count < 1000 {
            return .basic
        } else {
            return .premium
        }
    }
    
    // MARK: - Flight Data Fetching
    func fetchUSAJetFlights() async {
        guard let creds = credentials, isLoggedIn else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            debugInfo = "Fetching USA Jet flights..."
        }
        
        do {
            let flights = try await fetchFlightsFromAPI(creds)
            
            await MainActor.run {
                self.flightAwareFlights = flights
                self.lastUpdate = Date()
                self.debugInfo = "Found \(flights.count) USA Jet flights"
                if flights.isEmpty {
                    self.errorMessage = "No USA Jet flights found in current data"
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch flights: \(error.localizedDescription)"
                self.debugInfo = "Error fetching flights: \(error)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchFlightsFromAPI(_ creds: FlightAwareCredentials) async throws -> [FlightAwareFlight] {
        let searchEndpoint = "/flights/search?query=JUS*&max_pages=5" // Search for JUS callsigns
        
        guard let url = URL(string: "\(baseURL)\(searchEndpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BlockCalc-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(creds.apiKey, forHTTPHeaderField: "x-apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        // Parse FlightAware response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let flights = json["flights"] as? [[String: Any]] {
            
            return flights.compactMap { flightData in
                parseFlightData(flightData)
            }
        }
        
        return []
    }
    
    private func parseFlightData(_ data: [String: Any]) -> FlightAwareFlight? {
        guard let ident = data["ident"] as? String else { return nil }
        
        let origin = parseAirport(data["origin"] as? [String: Any])
        let destination = parseAirport(data["destination"] as? [String: Any])
        
        return FlightAwareFlight(
            ident: ident,
            faFlightId: data["fa_flight_id"] as? String,
            actualOff: data["actual_off"] as? String,
            actualOn: data["actual_on"] as? String,
            origin: origin,
            destination: destination,
            lastPosition: nil, // Would need separate API call
            aircraft: parseAircraft(data["aircraft"] as? [String: Any])
        )
    }
    
    private func parseAirport(_ data: [String: Any]?) -> FlightAwareAirport? {
        guard let data = data, let code = data["code"] as? String else { return nil }
        
        return FlightAwareAirport(
            code: code,
            codeIcao: data["code_icao"] as? String,
            codeIata: data["code_iata"] as? String,
            codeLid: data["code_lid"] as? String,
            timezone: data["timezone"] as? String,
            name: data["name"] as? String,
            city: data["city"] as? String,
            state: data["state"] as? String,
            elevation: data["elevation"] as? Int,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double
        )
    }
    
    private func parseAircraft(_ data: [String: Any]?) -> FlightAwareAircraft? {
        guard let data = data else { return nil }
        
        return FlightAwareAircraft(
            type: data["type"] as? String,
            registration: data["registration"] as? String
        )
    }
    
    // MARK: - External App Integration
    func openFlightAwareWithJUSSearch() {
        let searchQuery = "JUS*"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://flightaware.com/live/findflight?searchtype=Ident&search=\(encodedQuery)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    func openFlightAwareApp() {
        // Try to open FlightAware app with deep link
        if let url = URL(string: "flightaware://search?query=JUS") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/app/flightaware-flight-tracker/id316793974") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
        }
    }
    
    // MARK: - Data Persistence
    private func saveCredentials(_ creds: FlightAwareCredentials) {
        userDefaults.set(creds.username, forKey: "FlightAware_Username")
        userDefaults.set(creds.apiKey, forKey: "FlightAware_APIKey")
    }
    
    private func loadSavedCredentials() {
        let username = userDefaults.string(forKey: "FlightAware_Username") ?? ""
        let apiKey = userDefaults.string(forKey: "FlightAware_APIKey") ?? ""
        
        if !username.isEmpty && !apiKey.isEmpty {
            credentials = FlightAwareCredentials(username: username, apiKey: apiKey)
            isLoggedIn = true // Auto-login with saved credentials
            apiStatus = .unknown // Will be determined on first API call
            debugInfo = "Using saved FlightAware credentials"
        }
    }
    
    func logout() {
        credentials = nil
        isLoggedIn = false
        flightAwareFlights = []
        debugInfo = ""
        apiStatus = .unknown
        userDefaults.removeObject(forKey: "FlightAware_Username")
        userDefaults.removeObject(forKey: "FlightAware_APIKey")
    }
}

// FlightAwareCredentials.swift - Credentials Model for FlightAware Integration
import Foundation

// MARK: - FlightAware Credentials Model
struct FlightAwareCredentials: Codable {
    let username: String
    let apiKey: String
    
    init(username: String, apiKey: String) {
        self.username = username
        self.apiKey = apiKey
    }
}

// MARK: - Additional Authentication Helpers
extension FlightAwareCredentials {
    var isValid: Bool {
        return !username.isEmpty && !apiKey.isEmpty
    }
    
    var displayUsername: String {
        return username.trimmingCharacters(in: .whitespaces)
    }
    
    // For debugging purposes (never log the actual API key)
    var maskedApiKey: String {
        if apiKey.count > 8 {
            let start = String(apiKey.prefix(4))
            let end = String(apiKey.suffix(4))
            return "\(start)***\(end)"
        } else {
            return "***"
        }
    }
}

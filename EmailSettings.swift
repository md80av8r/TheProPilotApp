import Foundation
import Combine

/// Model for storing email destination settings
struct EmailSettings: Codable {
    // Existing properties
    var logbookEmail: String = ""
    var receiptsEmail: String = ""
    var generalEmail: String = ""
    var autoSendReceipts: Bool = false
    var includeAircraftInSubject: Bool = false
    var includeRouteInEmail: Bool = false
    
    // NEW: Freight-specific properties
    var freightEmail: String = ""
    var includeFlightTimes: Bool = true
    var includeCrewNames: Bool = false
    var includeTimestamp: Bool = true
    var includeFuelReceiptAttached: Bool = false
    
    // Additional freight options
    var includeCargoWeight: Bool = true
    var includeCargoDescription: Bool = true
    var includeShipperInfo: Bool = true
    var includeConsigneeInfo: Bool = true
    var includeBOLNumber: Bool = true
    var includeHazmatInfo: Bool = true
    var includeSpecialHandling: Bool = true
}

/// Store for persisting and observing email settings
class EmailSettingsStore: ObservableObject {
    @Published var settings: EmailSettings

    private let userDefaults = UserDefaults.shared
    private let settingsKey = "EmailSettingsKey"

    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(EmailSettings.self, from: data) {
            settings = decoded
        } else {
            settings = EmailSettings()
        }
    }

    /// Saves the current settings to UserDefaults
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
}

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Mileage Settings
/// Manages mileage tracking and payment calculation settings
class MileageSettings: ObservableObject {
    static let shared = MileageSettings()

    private let defaults = UserDefaults.appGroup ?? UserDefaults.standard

    // MARK: - Published Properties

    /// Whether to show mileage tracking
    @Published var showMileage: Bool {
        didSet {
            defaults.set(showMileage, forKey: "showMileage")
        }
    }

    /// Dollar amount per mile (optional, 0 = disabled)
    @Published var dollarsPerMile: Double {
        didSet {
            defaults.set(dollarsPerMile, forKey: "dollarsPerMile")
        }
    }

    // MARK: - Initialization

    private init() {
        self.showMileage = defaults.bool(forKey: "showMileage")
        // Default: 0 (disabled), user can set it if they want
        self.dollarsPerMile = defaults.double(forKey: "dollarsPerMile")
    }

    // MARK: - Mileage Calculation

    /// Calculate great circle distance between two airport ICAO codes in nautical miles
    /// Uses airport coordinates from AirportDatabase
    func calculateDistance(from departureICAO: String, to arrivalICAO: String) -> Double? {
        guard let depCoord = getAirportCoordinates(icao: departureICAO),
              let arrCoord = getAirportCoordinates(icao: arrivalICAO) else {
            return nil
        }

        let depLocation = CLLocation(latitude: depCoord.latitude, longitude: depCoord.longitude)
        let arrLocation = CLLocation(latitude: arrCoord.latitude, longitude: arrCoord.longitude)

        // Get distance in meters, convert to nautical miles
        let distanceMeters = depLocation.distance(from: arrLocation)
        let nauticalMiles = distanceMeters / 1852.0  // 1 NM = 1852 meters

        return nauticalMiles
    }

    /// Calculate total mileage for a trip (sum of all legs)
    func calculateTripMileage(trip: Trip) -> Double {
        var totalMiles: Double = 0.0

        for leg in trip.legs {
            if let distance = calculateDistance(from: leg.departure, to: leg.arrival) {
                totalMiles += distance
            }
        }

        return totalMiles
    }

    /// Calculate mileage pay based on distance and rate
    func calculateMileagePay(nauticalMiles: Double) -> Double {
        return nauticalMiles * dollarsPerMile
    }

    // MARK: - Airport Coordinates Helper

    /// Get coordinates for an airport ICAO code
    /// This is a simplified version - in production, you'd use a full airport database
    private func getAirportCoordinates(icao: String) -> CLLocationCoordinate2D? {
        // Basic airport database - expand this with more airports as needed
        let airportDatabase: [String: CLLocationCoordinate2D] = [
            "KVNY": CLLocationCoordinate2D(latitude: 34.2098, longitude: -118.4900),  // Van Nuys
            "KBUR": CLLocationCoordinate2D(latitude: 34.2007, longitude: -118.3587),  // Burbank
            "KLRD": CLLocationCoordinate2D(latitude: 27.5433, longitude: -99.4617),   // Laredo
            "KCHA": CLLocationCoordinate2D(latitude: 35.0353, longitude: -85.2038),   // Chattanooga
            "KORD": CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9073),   // Chicago O'Hare
            "KATL": CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277),   // Atlanta
            "KDFW": CLLocationCoordinate2D(latitude: 32.8998, longitude: -97.0403),   // Dallas/Fort Worth
            "KLAX": CLLocationCoordinate2D(latitude: 33.9416, longitude: -118.4085),  // Los Angeles
            "KJFK": CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781),   // New York JFK
            "KMIA": CLLocationCoordinate2D(latitude: 25.7959, longitude: -80.2870),   // Miami
            "KDEN": CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737),  // Denver
            "KLAS": CLLocationCoordinate2D(latitude: 36.0840, longitude: -115.1537),  // Las Vegas
            "KSEA": CLLocationCoordinate2D(latitude: 47.4502, longitude: -122.3088),  // Seattle
            "KPHX": CLLocationCoordinate2D(latitude: 33.4342, longitude: -112.0080),  // Phoenix
            "KBOS": CLLocationCoordinate2D(latitude: 42.3656, longitude: -71.0096),   // Boston
            "KSFO": CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.3790),  // San Francisco
            "KEWR": CLLocationCoordinate2D(latitude: 40.6895, longitude: -74.1745),   // Newark
            "KMCO": CLLocationCoordinate2D(latitude: 28.4312, longitude: -81.3081),   // Orlando
            "KIAH": CLLocationCoordinate2D(latitude: 29.9902, longitude: -95.3368),   // Houston
            "KDCA": CLLocationCoordinate2D(latitude: 38.8521, longitude: -77.0377),   // Washington National
        ]

        return airportDatabase[icao.uppercased()]
    }

    // MARK: - Formatting Helpers

    /// Format mileage for display
    func formatMileage(_ miles: Double) -> String {
        return String(format: "%.1f NM", miles)
    }

    /// Format mileage pay for display
    func formatMileagePay(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}

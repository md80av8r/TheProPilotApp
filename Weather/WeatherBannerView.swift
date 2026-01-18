//
//  WeatherBannerView.swift
//  TheProPilotApp
//
//  Created on 12/15/25.
//

import SwiftUI
import CoreLocation

// MARK: - Location Manager for Nearest Airport
class NearestAirportManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = NearestAirportManager()
    
    @Published var nearestAirport: String?
    @Published var locationAuthorized = false
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Check initial authorization status
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationAuthorized = true
            locationManager.requestLocation()
        case .denied, .restricted:
            locationAuthorized = false
            nearestAirport = nil
        @unknown default:
            locationAuthorized = false
        }
    }
    
    func requestLocationUpdate() {
        guard locationAuthorized else {
            checkAuthorizationStatus()
            return
        }
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorizationStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        findNearestAirport(to: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    // MARK: - Find Nearest Airport (using Airport Database)
    
    private func findNearestAirport(to location: CLLocation) {
        // Use the airport database to find nearby airports
        let nearbyAirports = AirportDatabaseManager.shared.getNearbyAirports(
            to: location,
            within: 100.0,  // 100km radius
            limit: 1
        )
        
        if let nearest = nearbyAirports.first {
            let distanceMiles = nearest.distance / 1609.34 // Convert meters to miles
            print("📍 Nearest airport: \(nearest.icao) (\(String(format: "%.1f", distanceMiles)) mi away)")
            
            DispatchQueue.main.async {
                self.nearestAirport = nearest.icao
            }
        } else {
            print("📍 No airports found within 100km")
        }
    }
}

// MARK: - Runway Models
struct RunwayInfo: Codable, Identifiable {
    let id = UUID()
    let ident: String           // "09", "27L", "18R"
    let length: Int             // Length in feet
    let width: Int              // Width in feet
    let surface: String         // "ASPH", "CONC", "TURF"
    let heading: Int            // True heading (090, 270, etc.)
    
    // Computed wind components
    var headwind: Int = 0
    var crosswind: Int = 0
    var isHeadwind: Bool { headwind > 0 }
    var isFavorable: Bool { abs(crosswind) <= 10 }  // Green if crosswind ≤ 10kt
    
    enum CodingKeys: String, CodingKey {
        case ident = "le_ident"
        case length = "length_ft"
        case width = "width_ft"
        case surface
        case heading = "le_heading_degT"
    }
}

struct RunwayWindAnalysis {
    let runway: RunwayInfo
    let headwind: Int
    let crosswind: Int
    let gustCrosswind: Int?
    
    var favorability: RunwayFavorability {
        let absXwind = abs(crosswind)
        let gustXwind = gustCrosswind.map { abs($0) } ?? absXwind
        let maxXwind = max(absXwind, gustXwind)
        
        if maxXwind <= 5 {
            return .excellent
        } else if maxXwind <= 10 {
            return .good
        } else if maxXwind <= 15 {
            return .moderate
        } else if maxXwind <= 25 {
            return .challenging
        } else {
            return .exceeds
        }
    }
}

enum RunwayFavorability {
    case excellent    // 0-5kt crosswind
    case good         // 6-10kt crosswind
    case moderate     // 11-15kt crosswind
    case challenging  // 16-25kt crosswind
    case exceeds      // >25kt crosswind
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return Color(red: 0.5, green: 0.8, blue: 0.3)  // Light green
        case .moderate: return .yellow
        case .challenging: return .orange
        case .exceeds: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .challenging: return "exclamationmark.triangle.fill"
        case .exceeds: return "xmark.circle.fill"
        }
    }
}

// MARK: - Simple Weather Service for Banner
@MainActor
class BannerWeatherService: ObservableObject {
    static let shared = BannerWeatherService()

    @Published var cachedWeather: [String: RawMETAR] = [:]
    @Published var cachedRunways: [String: [RunwayInfo]] = [:]
    @Published var runwaysFetchingStatus: [String: Bool] = [:] // Track if runways are being fetched
    private var lastFetchTime: [String: Date] = [:]
    private var lastRunwayFetchTime: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 30 * 60 // 30 minutes
    private let runwayCacheTimeout: TimeInterval = 24 * 60 * 60 // 24 hours (runways don't change often)
    private var cachedRunwayCSV: String? = nil  // Cache the CSV to avoid re-downloading
    private var csvLastFetchTime: Date? = nil
    private let csvCacheTimeout: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // ✅ Cache version to invalidate old data
    private let cacheVersion = "v2" // Increment when RawMETAR structure changes
    private let cacheVersionKey = "WeatherCacheVersion"
    
    private init() {
        // ✅ Check cache version and clear if outdated
        checkAndClearOldCache()
    }
    
    private func checkAndClearOldCache() {
        let savedVersion = UserDefaults.standard.string(forKey: cacheVersionKey)
        
        if savedVersion != cacheVersion {
            print("🧹 Cache version mismatch (saved: \(savedVersion ?? "none"), current: \(cacheVersion))")
            print("🧹 Clearing old weather cache...")
            
            cachedWeather.removeAll()
            lastFetchTime.removeAll()
            
            // Save new version
            UserDefaults.standard.set(cacheVersion, forKey: cacheVersionKey)
            print("✅ Cache cleared and updated to version \(cacheVersion)")
        } else {
            print("✅ Cache version is current: \(cacheVersion)")
        }
    }
    
    func fetchMETAR(for airport: String) async throws -> RawMETAR {
        let icao = airport.uppercased()

        // ✈️ CHECK IN-FLIGHT STATE: Use cached weather when airborne
        // This provides offline access during flights when network may be unavailable
        if FlightStateManager.shared.isInFlight,
           let activeLegId = FlightStateManager.shared.activeLegId {
            // Try to get weather from flight cache
            if let cachedFlightWeather = await WeatherCacheService.shared.loadCachedWeather(for: activeLegId) {
                // Check if this airport is departure or arrival
                if icao == cachedFlightWeather.departureICAO.uppercased(),
                   let cachedMETAR = cachedFlightWeather.departureMETAR {
                    print("☁️ Using cached departure METAR for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedMETAR
                }
                if icao == cachedFlightWeather.arrivalICAO.uppercased(),
                   let cachedMETAR = cachedFlightWeather.arrivalMETAR {
                    print("☁️ Using cached arrival METAR for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedMETAR
                }
            }
            // If we're in flight but no cached data for this airport, continue to fetch live
            print("⚠️ In flight but no cached METAR for \(icao) - fetching live")
        }

        // Check in-memory cache first (safe - we're on MainActor)
        if let cached = cachedWeather[icao],
           let lastFetch = lastFetchTime[icao],
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return cached
        }

        let urlString = "https://aviationweather.gov/api/data/metar?ids=\(icao)&format=json"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

        // Network call - await handles actor hopping
        let (data, _) = try await URLSession.shared.data(from: url)
        let metars = try JSONDecoder().decode([RawMETAR].self, from: data)

        guard let metar = metars.first else {
            throw WeatherBannerError.noData
        }

        // Update cache (safe - we're on MainActor)
        self.cachedWeather[icao] = metar
        self.lastFetchTime[icao] = Date()

        return metar
    }
    
    // MARK: - Runway Data Fetching
    func fetchRunways(for airport: String) async throws -> [RunwayInfo] {
        let icao = airport.uppercased()
        
        // Check cache first
        if let cached = cachedRunways[icao],
           let lastFetch = lastRunwayFetchTime[icao],
           Date().timeIntervalSince(lastFetch) < runwayCacheTimeout {
            return cached
        }
        
        // Hardcoded runway data (tuple: ident, length, width, surface, heading)
        let hardcodedData: [String: [(String, Int, Int, String, Int)]] = [
            "KPTK": [
                ("09L", 5000, 75, "ASPH", 90),
                ("27R", 5000, 75, "ASPH", 270),
                ("09R", 6301, 100, "ASPH", 90),
                ("27L", 6301, 100, "ASPH", 270),
                ("18", 3523, 75, "ASPH", 180),
                ("36", 3523, 75, "ASPH", 360)
            ],
            "KYIP": [
                ("05L", 4002, 150, "ASPH", 50),
                ("23R", 4002, 150, "ASPH", 230),
                ("05R", 7529, 150, "ASPH", 50),
                ("23L", 7529, 150, "ASPH", 230)
            ],
            "KDTW": [
                ("03L", 10001, 150, "CONC", 30),
                ("21R", 10001, 150, "CONC", 210),
                ("03R", 12003, 200, "CONC", 30),
                ("21L", 12003, 200, "CONC", 210),
                ("04L", 8500, 150, "CONC", 40),
                ("22R", 8500, 150, "CONC", 220),
                ("04R", 8708, 150, "CONC", 40),
                ("22L", 8708, 150, "CONC", 220),
                ("09L", 8501, 150, "CONC", 90),
                ("27R", 8501, 150, "CONC", 270),
                ("09R", 10000, 150, "CONC", 90),
                ("27L", 10000, 150, "CONC", 270)
            ],
            "KDAB": [
                ("07L", 10500, 150, "ASPH", 70),
                ("25R", 10500, 150, "ASPH", 250),
                ("07R", 7250, 150, "ASPH", 70),
                ("25L", 7250, 150, "ASPH", 250)
            ],
            "KATL": [
                ("08L", 9000, 150, "ASPH", 80),
                ("26R", 9000, 150, "ASPH", 260),
                ("08R", 12390, 150, "CONC", 80),
                ("26L", 12390, 150, "CONC", 260)
            ],
            "KJFK": [
                ("04L", 12079, 150, "ASPH", 40),
                ("22R", 12079, 150, "ASPH", 220),
                ("13R", 14511, 200, "ASPH", 130),
                ("31L", 14511, 200, "ASPH", 310)
            ],
            "KLAX": [
                ("07L", 11095, 150, "ASPH", 70),
                ("25R", 11095, 150, "ASPH", 250),
                ("07R", 12091, 200, "ASPH", 70),
                ("25L", 12091, 200, "ASPH", 250)
            ],
            "KLRD": [
                ("18", 8502, 150, "ASPH", 180),
                ("36", 8502, 150, "ASPH", 360),
                ("14", 5851, 100, "ASPH", 140),
                ("32", 5851, 100, "ASPH", 320)
            ],
            "KORD": [
                ("09L", 7500, 150, "CONC", 90),
                ("27R", 7500, 150, "CONC", 270),
                ("09R", 7967, 150, "CONC", 90),
                ("27L", 7967, 150, "CONC", 270),
                ("09C", 10801, 200, "CONC", 90),
                ("27C", 10801, 200, "CONC", 270),
                ("10L", 10801, 200, "CONC", 100),
                ("28R", 10801, 200, "CONC", 280),
                ("10C", 10801, 200, "CONC", 100),
                ("28C", 10801, 200, "CONC", 280),
                ("10R", 13000, 200, "CONC", 100),
                ("28L", 13000, 200, "CONC", 280)
            ],
            "KDFW": [
                ("13L", 9000, 200, "CONC", 130),
                ("31R", 9000, 200, "CONC", 310),
                ("13R", 9301, 200, "CONC", 130),
                ("31L", 9301, 200, "CONC", 310),
                ("17C", 13401, 200, "CONC", 170),
                ("35C", 13401, 200, "CONC", 350),
                ("17L", 8500, 150, "CONC", 170),
                ("35R", 8500, 150, "CONC", 350),
                ("17R", 9000, 200, "CONC", 170),
                ("35L", 9000, 200, "CONC", 350),
                ("18L", 13400, 200, "CONC", 180),
                ("36R", 13400, 200, "CONC", 360),
                ("18R", 13401, 200, "CONC", 180),
                ("36L", 13401, 200, "CONC", 360)
            ],
            "KDEN": [
                ("07", 9000, 150, "CONC", 70),
                ("25", 9000, 150, "CONC", 250),
                ("08", 12000, 150, "CONC", 80),
                ("26", 12000, 150, "CONC", 260),
                ("16L", 16000, 200, "CONC", 160),
                ("34R", 16000, 200, "CONC", 340),
                ("16R", 12000, 200, "CONC", 160),
                ("34L", 12000, 200, "CONC", 340),
                ("17L", 12000, 150, "CONC", 170),
                ("35R", 12000, 150, "CONC", 350),
                ("17R", 12000, 150, "CONC", 170),
                ("35L", 12000, 150, "CONC", 350)
            ],
            "KMIA": [
                ("08L", 10506, 200, "ASPH", 80),
                ("26R", 10506, 200, "ASPH", 260),
                ("08R", 13016, 200, "ASPH", 80),
                ("26L", 13016, 200, "ASPH", 260),
                ("09", 13000, 200, "ASPH", 90),
                ("27", 13000, 200, "ASPH", 270),
                ("12", 9354, 150, "ASPH", 120),
                ("30", 9354, 150, "ASPH", 300)
            ],
            "KSFO": [
                ("01L", 7650, 200, "ASPH", 10),
                ("19R", 7650, 200, "ASPH", 190),
                ("01R", 8650, 200, "ASPH", 10),
                ("19L", 8650, 200, "ASPH", 190),
                ("10L", 10602, 200, "ASPH", 100),
                ("28R", 10602, 200, "ASPH", 280),
                ("10R", 11870, 200, "ASPH", 100),
                ("28L", 11870, 200, "ASPH", 280)
            ],
            "KLAS": [
                ("01L", 10527, 150, "ASPH", 10),
                ("19R", 10527, 150, "ASPH", 190),
                ("01R", 14510, 150, "ASPH", 10),
                ("19L", 14510, 150, "ASPH", 190),
                ("08L", 9775, 150, "ASPH", 80),
                ("26R", 9775, 150, "ASPH", 260),
                ("08R", 10527, 150, "ASPH", 80),
                ("26L", 10527, 150, "ASPH", 260)
            ],
            "KPHX": [
                ("07L", 10300, 150, "ASPH", 70),
                ("25R", 10300, 150, "ASPH", 250),
                ("07R", 11489, 150, "ASPH", 70),
                ("25L", 11489, 150, "ASPH", 250),
                ("08", 7800, 150, "ASPH", 80),
                ("26", 7800, 150, "ASPH", 260)
            ],
            "KMSP": [
                ("04", 8000, 150, "CONC", 40),
                ("22", 8000, 150, "CONC", 220),
                ("12L", 8200, 200, "CONC", 120),
                ("30R", 8200, 200, "CONC", 300),
                ("12R", 10000, 200, "CONC", 120),
                ("30L", 10000, 200, "CONC", 300),
                ("17", 11006, 200, "CONC", 170),
                ("35", 11006, 200, "CONC", 350)
            ],
            "KBOS": [
                ("04L", 7861, 150, "ASPH", 40),
                ("22R", 7861, 150, "ASPH", 220),
                ("04R", 10005, 150, "ASPH", 40),
                ("22L", 10005, 150, "ASPH", 220),
                ("09", 7000, 150, "ASPH", 90),
                ("27", 7000, 150, "ASPH", 270),
                ("15R", 10083, 150, "ASPH", 150),
                ("33L", 10083, 150, "ASPH", 330)
            ],
            "KEWR": [
                ("04L", 11000, 150, "ASPH", 40),
                ("22R", 11000, 150, "ASPH", 220),
                ("04R", 10000, 150, "ASPH", 40),
                ("22L", 10000, 150, "ASPH", 220),
                ("11", 9300, 150, "ASPH", 110),
                ("29", 9300, 150, "ASPH", 290)
            ],
            "KLGA": [
                ("04", 7001, 150, "ASPH", 40),
                ("22", 7001, 150, "ASPH", 220),
                ("13", 7000, 150, "ASPH", 130),
                ("31", 7000, 150, "ASPH", 310)
            ],
            "KSEA": [
                ("16L", 11901, 200, "CONC", 160),
                ("34R", 11901, 200, "CONC", 340),
                ("16C", 9426, 150, "CONC", 160),
                ("34C", 9426, 150, "CONC", 340),
                ("16R", 8500, 150, "CONC", 160),
                ("34L", 8500, 150, "CONC", 340)
            ],
            "KPHL": [
                ("08", 5000, 150, "ASPH", 80),
                ("26", 5000, 150, "ASPH", 260),
                ("09L", 10506, 200, "ASPH", 90),
                ("27R", 10506, 200, "ASPH", 270),
                ("09R", 9500, 150, "ASPH", 90),
                ("27L", 9500, 150, "ASPH", 270),
                ("17", 6500, 150, "ASPH", 170),
                ("35", 6500, 150, "ASPH", 350)
            ],
            "KCLT": [
                ("18L", 10000, 150, "CONC", 180),
                ("36R", 10000, 150, "CONC", 360),
                ("18C", 10000, 150, "CONC", 180),
                ("36C", 10000, 150, "CONC", 360),
                ("18R", 9000, 150, "CONC", 180),
                ("36L", 9000, 150, "CONC", 360),
                ("05", 7502, 150, "CONC", 50),
                ("23", 7502, 150, "CONC", 230)
            ]
        ]
        
        // Check if we have hardcoded data
        if let tuples = hardcodedData[icao] {
            let runways = tuples.map { RunwayInfo(ident: $0.0, length: $0.1, width: $0.2, surface: $0.3, heading: $0.4) }
            print("✅ Using hardcoded runway data for \(icao) (\(runways.count) runways)")
            // Safe - we're on MainActor
            self.cachedRunways[icao] = runways
            self.lastRunwayFetchTime[icao] = Date()
            return runways
        }

        // Try OurAirports CSV data from GitHub
        do {
            // Check if we have cached CSV data
            let csvString: String
            if let cached = cachedRunwayCSV,
               let lastFetch = csvLastFetchTime,
               Date().timeIntervalSince(lastFetch) < csvCacheTimeout {
                csvString = cached
                print("📋 Using cached runway CSV data")
            } else {
                // Download fresh CSV
                let urlString = "https://davidmegginson.github.io/ourairports-data/runways.csv"
                guard let url = URL(string: urlString) else {
                    throw WeatherBannerError.invalidURL
                }

                print("📥 Downloading runway CSV data...")
                let (data, _) = try await URLSession.shared.data(from: url)

                guard let downloaded = String(data: data, encoding: .utf8) else {
                    throw WeatherBannerError.noData
                }

                csvString = downloaded
                cachedRunwayCSV = downloaded
                csvLastFetchTime = Date()
                print("✅ Downloaded and cached runway CSV (\(downloaded.count) bytes)")
            }

            // Parse CSV to find runways for this airport
            let runways = parseRunwaysFromCSV(csvString, airportIdent: icao)

            if runways.isEmpty {
                print("⚠️ No runway data found in CSV for \(icao)")
                throw WeatherBannerError.noData
            }

            print("✅ Parsed \(runways.count) runways from CSV for \(icao)")
            self.cachedRunways[icao] = runways
            self.lastRunwayFetchTime[icao] = Date()
            return runways
        } catch {
            print("⚠️ No runway data available for \(icao): \(error)")
            throw WeatherBannerError.noData
        }
    }

    // MARK: - CSV Parsing
    private func parseRunwaysFromCSV(_ csv: String, airportIdent: String) -> [RunwayInfo] {
        var runways: [RunwayInfo] = []
        let lines = csv.components(separatedBy: "\n")

        // CSV columns: id, airport_ref, airport_ident, length_ft, width_ft, surface, lighted, closed,
        // le_ident, le_latitude_deg, le_longitude_deg, le_elevation_ft, le_heading_degT, le_displaced_threshold_ft,
        // he_ident, he_latitude_deg, he_longitude_deg, he_elevation_ft, he_heading_degT, he_displaced_threshold_ft

        for line in lines {
            // Skip if not our airport
            guard line.contains(",\"\(airportIdent)\",") || line.contains(",\(airportIdent),") else {
                continue
            }

            let columns = parseCSVLine(line)
            guard columns.count >= 13 else { continue }

            // Check if runway is closed (column 7)
            let isClosed = columns[7] == "1"
            if isClosed { continue }

            // Get runway data
            let lengthStr = columns[3].replacingOccurrences(of: "\"", with: "")
            let widthStr = columns[4].replacingOccurrences(of: "\"", with: "")
            let surface = columns[5].replacingOccurrences(of: "\"", with: "")
            let leIdent = columns[8].replacingOccurrences(of: "\"", with: "")
            let leHeadingStr = columns[12].replacingOccurrences(of: "\"", with: "")

            guard let length = Int(lengthStr),
                  let width = Int(widthStr),
                  !leIdent.isEmpty else {
                continue
            }

            // Parse heading - may be empty or decimal
            let heading: Int
            if let headingDouble = Double(leHeadingStr) {
                heading = Int(headingDouble.rounded())
            } else {
                // Derive heading from runway number
                let cleanNum = leIdent.filter { $0.isNumber }
                if let num = Int(cleanNum) {
                    heading = num * 10
                } else {
                    continue
                }
            }

            // Normalize surface names
            let normalizedSurface: String
            switch surface.uppercased() {
            case let s where s.contains("ASP") || s.contains("ASPHALT"):
                normalizedSurface = "ASPH"
            case let s where s.contains("CON") || s.contains("CONCRETE"):
                normalizedSurface = "CONC"
            case let s where s.contains("GRV") || s.contains("GRAVEL"):
                normalizedSurface = "GRVL"
            case let s where s.contains("TURF") || s.contains("GRASS"):
                normalizedSurface = "TURF"
            default:
                normalizedSurface = surface.uppercased().prefix(4).description
            }

            let runway = RunwayInfo(
                ident: leIdent,
                length: length,
                width: width,
                surface: normalizedSurface,
                heading: heading == 0 ? 360 : heading
            )
            runways.append(runway)
        }

        // Sort by runway length (longest first)
        return runways.sorted { $0.length > $1.length }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)

        return columns
    }
    
    // MARK: - Wind Component Calculation
    func calculateWindComponents(windDir: Int, windSpeed: Int, runwayHeading: Int) -> (headwind: Int, crosswind: Int) {
        // Convert to radians
        let windAngle = Double(windDir) * .pi / 180.0
        let runwayAngle = Double(runwayHeading) * .pi / 180.0
        
        // Calculate angle difference
        var angleDiff = windAngle - runwayAngle
        
        // Normalize to -π to π
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }
        
        // Calculate components
        let headwindComponent = Double(windSpeed) * cos(angleDiff)
        let crosswindComponent = Double(windSpeed) * sin(angleDiff)
        
        return (headwind: Int(headwindComponent.rounded()),
                crosswind: Int(crosswindComponent.rounded()))
    }
    
    func analyzeRunways(runways: [RunwayInfo], weather: RawMETAR) -> [RunwayWindAnalysis] {
        guard let windDir = weather.windDirection, let windSpeed = weather.wspd else {
            return []
        }
        
        var analyses: [RunwayWindAnalysis] = []
        
        for runway in runways {
            let (headwind, crosswind) = calculateWindComponents(
                windDir: windDir,
                windSpeed: windSpeed,
                runwayHeading: runway.heading
            )
            
            // Calculate gust components if available
            var gustCrosswind: Int? = nil
            if let gustSpeed = weather.wgst {
                let (_, gustXwind) = calculateWindComponents(
                    windDir: windDir,
                    windSpeed: gustSpeed,
                    runwayHeading: runway.heading
                )
                gustCrosswind = gustXwind
            }
            
            analyses.append(RunwayWindAnalysis(
                runway: runway,
                headwind: headwind,
                crosswind: crosswind,
                gustCrosswind: gustCrosswind
            ))
        }
        
        // Sort by favorability: lowest crosswind first, then highest headwind
        return analyses.sorted { analysis1, analysis2 in
            let xwind1 = abs(analysis1.crosswind)
            let xwind2 = abs(analysis2.crosswind)

            if xwind1 != xwind2 {
                return xwind1 < xwind2  // Lower crosswind is better
            }
            return analysis1.headwind > analysis2.headwind  // Higher headwind is better
        }
    }

    // MARK: - TAF Fetching
    func fetchTAF(for airport: String) async throws -> RawTAF {
        let icao = airport.uppercased()

        // ✈️ CHECK IN-FLIGHT STATE: Use cached TAF when airborne
        if FlightStateManager.shared.isInFlight,
           let activeLegId = FlightStateManager.shared.activeLegId {
            if let cachedFlightWeather = await WeatherCacheService.shared.loadCachedWeather(for: activeLegId) {
                if icao == cachedFlightWeather.departureICAO.uppercased(),
                   let cachedTAF = cachedFlightWeather.departureTAF {
                    print("☁️ Using cached departure TAF for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedTAF
                }
                if icao == cachedFlightWeather.arrivalICAO.uppercased(),
                   let cachedTAF = cachedFlightWeather.arrivalTAF {
                    print("☁️ Using cached arrival TAF for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedTAF
                }
            }
            print("⚠️ In flight but no cached TAF for \(icao) - fetching live")
        }

        let urlString = "https://aviationweather.gov/api/data/taf?ids=\(icao)&format=json"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let tafs = try JSONDecoder().decode([RawTAF].self, from: data)

        guard let taf = tafs.first else {
            throw WeatherBannerError.noData
        }

        return taf
    }

    // MARK: - MOS Fetching (Iowa State Mesonet)
    func fetchMOS(for airport: String) async throws -> [MOSForecast] {
        let icao = airport.uppercased()

        // ✈️ CHECK IN-FLIGHT STATE: Use cached MOS when airborne
        if FlightStateManager.shared.isInFlight,
           let activeLegId = FlightStateManager.shared.activeLegId {
            if let cachedFlightWeather = await WeatherCacheService.shared.loadCachedWeather(for: activeLegId) {
                if icao == cachedFlightWeather.departureICAO.uppercased(),
                   let cachedMOS = cachedFlightWeather.departureMOS {
                    print("☁️ Using cached departure MOS for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedMOS
                }
                if icao == cachedFlightWeather.arrivalICAO.uppercased(),
                   let cachedMOS = cachedFlightWeather.arrivalMOS {
                    print("☁️ Using cached arrival MOS for \(icao) (\(cachedFlightWeather.timeAgo))")
                    return cachedMOS
                }
            }
            print("⚠️ In flight but no cached MOS for \(icao) - fetching live")
        }

        // Iowa State Mesonet MOS API - returns pandas DataFrame format
        let urlString = "https://mesonet.agron.iastate.edu/api/1/mos.json?station=\(icao)&model=GFS"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        // Debug: print first part of response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📊 MOS Response preview for \(icao): \(String(jsonString.prefix(200)))...")
        }

        // Decode as MOSResponse (handles both pandas DataFrame and direct array formats)
        do {
            let response = try JSONDecoder().decode(MOSResponse.self, from: data)
            if let forecasts = response.data, !forecasts.isEmpty {
                print("✅ MOS decoded successfully: \(forecasts.count) forecasts")
                return forecasts
            }
        } catch {
            print("❌ MOS decode error: \(error)")
        }

        throw WeatherBannerError.noData
    }

    // MARK: - Winds Aloft Stations
    // These are the actual FAA winds aloft reporting stations from aviationweather.gov API
    // Updated to match actual stations returned by: https://aviationweather.gov/api/data/windtemp?region=all
    // Note: Many major airports (DTW, ORD, LAX, etc.) are NOT winds aloft reporting stations
    // The nearest reporting station should be used for those airports
    private static let windsAloftStations: [(code: String, lat: Double, lon: Double)] = [
        // Actual reporting stations from API (alphabetical by region)
        // Northeast / Mid-Atlantic
        ("ACK", 41.25, -70.07),   // Nantucket, MA
        ("ACY", 39.45, -74.57),   // Atlantic City, NJ
        ("AGC", 40.35, -79.93),   // Pittsburgh Allegheny, PA
        ("ALB", 42.75, -73.80),   // Albany, NY
        ("AVP", 41.34, -75.73),   // Wilkes-Barre, PA
        ("BDL", 41.94, -72.68),   // Hartford, CT
        ("BGR", 44.81, -68.82),   // Bangor, ME
        ("BML", 44.58, -71.18),   // Berlin, NH
        ("BOS", 42.36, -71.01),   // Boston, MA
        ("BUF", 42.94, -78.73),   // Buffalo, NY
        ("CAR", 46.87, -68.02),   // Caribou, ME
        ("EMI", 39.50, -76.98),   // Westminster, MD (Baltimore area)
        ("HAT", 35.23, -75.62),   // Cape Hatteras, NC
        ("JFK", 40.64, -73.78),   // New York JFK
        ("ORF", 36.90, -76.21),   // Norfolk, VA
        ("PLB", 44.69, -73.53),   // Plattsburgh, NY
        ("PSB", 40.88, -78.09),   // Philipsburg, PA
        ("PWM", 43.65, -70.31),   // Portland, ME
        ("RIC", 37.50, -77.32),   // Richmond, VA
        ("SYR", 43.11, -76.10),   // Syracuse, NY

        // Southeast
        ("ATL", 33.64, -84.43),   // Atlanta, GA
        ("BHM", 33.56, -86.75),   // Birmingham, AL
        ("BNA", 36.12, -86.68),   // Nashville, TN
        ("CAE", 33.94, -81.12),   // Columbia, SC
        ("CHS", 32.90, -80.04),   // Charleston, SC
        ("CRW", 38.37, -81.59),   // Charleston, WV
        ("CSG", 32.52, -84.94),   // Columbus, GA
        ("EYW", 24.56, -81.76),   // Key West, FL
        ("FLO", 34.19, -79.72),   // Florence, SC
        ("GSP", 34.90, -82.22),   // Greenville-Spartanburg, SC
        ("HSV", 34.64, -86.77),   // Huntsville, AL
        ("ILM", 34.27, -77.90),   // Wilmington, NC
        ("JAX", 30.49, -81.69),   // Jacksonville, FL
        ("JAN", 32.31, -90.08),   // Jackson, MS
        ("MGM", 32.30, -86.39),   // Montgomery, AL
        ("MIA", 25.79, -80.29),   // Miami, FL
        ("MLB", 28.10, -80.65),   // Melbourne, FL
        ("MOB", 30.69, -88.24),   // Mobile, AL
        ("PFN", 30.21, -85.68),   // Panama City, FL
        ("PIE", 27.91, -82.69),   // St. Petersburg, FL
        ("ROA", 37.32, -79.97),   // Roanoke, VA
        ("SAV", 32.13, -81.20),   // Savannah, GA
        ("TLH", 30.40, -84.35),   // Tallahassee, FL
        ("TRI", 36.48, -82.40),   // Tri-Cities, TN
        ("TYS", 35.81, -84.00),   // Knoxville, TN

        // Great Lakes / Midwest
        ("AXN", 45.87, -95.39),   // Alexandria, MN
        ("BRL", 40.78, -91.13),   // Burlington, IA
        ("CLE", 41.41, -81.85),   // Cleveland, OH
        ("CMH", 39.98, -82.88),   // Columbus, OH
        ("COU", 38.82, -92.22),   // Columbia, MO
        ("CVG", 39.05, -84.67),   // Cincinnati, OH
        ("DBQ", 42.40, -90.71),   // Dubuque, IA
        ("DLH", 46.84, -92.19),   // Duluth, MN
        ("DSM", 41.53, -93.66),   // Des Moines, IA
        ("ECK", 43.26, -82.72),   // Peck, MI (Detroit area winds aloft)
        ("EVV", 38.04, -87.53),   // Evansville, IN
        ("FWA", 40.98, -85.19),   // Fort Wayne, IN
        ("GRB", 44.48, -88.13),   // Green Bay, WI
        ("IND", 39.72, -86.29),   // Indianapolis, IN
        ("INL", 48.57, -93.40),   // International Falls, MN
        ("JOT", 41.52, -88.18),   // Joliet, IL (Chicago area)
        ("LSE", 43.88, -91.26),   // La Crosse, WI
        ("MCW", 43.16, -93.33),   // Mason City, IA
        ("MKC", 39.12, -94.59),   // Kansas City Downtown
        ("MKG", 43.17, -86.24),   // Muskegon, MI
        ("MQT", 46.53, -87.56),   // Marquette, MI
        ("MSP", 44.88, -93.22),   // Minneapolis, MN
        ("SPI", 39.84, -89.68),   // Springfield, IL
        ("SSM", 46.48, -84.36),   // Sault Ste. Marie, MI
        ("STL", 38.75, -90.37),   // St. Louis, MO
        ("TVC", 44.74, -85.58),   // Traverse City, MI

        // Central / Plains
        ("ABR", 45.45, -98.42),   // Aberdeen, SD
        ("AMA", 35.22, -101.70),  // Amarillo, TX
        ("BFF", 41.89, -103.60),  // Scottsbluff, NE
        ("DEN", 39.86, -104.67),  // Denver, CO
        ("DIK", 46.80, -102.80),  // Dickinson, ND
        ("FSD", 43.58, -96.74),   // Sioux Falls, SD
        ("GAG", 36.30, -99.77),   // Gage, OK
        ("GCK", 37.93, -100.72),  // Garden City, KS
        ("GFK", 47.95, -97.18),   // Grand Forks, ND
        ("GGW", 48.21, -106.62),  // Glasgow, MT
        ("GLD", 39.37, -101.70),  // Goodland, KS
        ("GRI", 40.97, -98.31),   // Grand Island, NE
        ("ICT", 37.65, -97.43),   // Wichita, KS
        ("LBB", 33.66, -101.82),  // Lubbock, TX
        ("LND", 42.81, -108.73),  // Lander, WY
        ("MLS", 46.43, -105.89),  // Miles City, MT
        ("MOT", 48.26, -101.28),  // Minot, ND
        ("OMA", 41.30, -95.89),   // Omaha, NE
        ("ONL", 42.47, -98.69),   // O'Neill, NE
        ("PIR", 44.38, -100.29),  // Pierre, SD
        ("PUB", 38.29, -104.50),  // Pueblo, CO
        ("RAP", 44.04, -103.05),  // Rapid City, SD
        ("RKS", 41.59, -109.07),  // Rock Springs, WY
        ("SGF", 37.24, -93.39),   // Springfield, MO
        ("SLN", 38.79, -97.65),   // Salina, KS

        // Southwest / Texas
        ("ABI", 32.41, -99.68),   // Abilene, TX
        ("ABQ", 35.04, -106.61),  // Albuquerque, NM
        ("BRO", 25.91, -97.43),   // Brownsville, TX
        ("CGI", 37.23, -89.57),   // Cape Girardeau, MO
        ("CLL", 30.59, -96.36),   // College Station, TX
        ("CRP", 27.77, -97.50),   // Corpus Christi, TX
        ("DAL", 32.85, -96.85),   // Dallas Love Field
        ("DRT", 29.37, -100.93),  // Del Rio, TX
        ("ELP", 31.81, -106.38),  // El Paso, TX
        ("FSM", 35.34, -94.37),   // Fort Smith, AR
        ("FMN", 36.74, -108.23),  // Farmington, NM
        ("GJT", 39.12, -108.53),  // Grand Junction, CO
        ("H51", 29.52, -98.28),   // San Antonio area
        ("H52", 29.29, -94.79),   // Galveston area
        ("H61", 28.67, -96.18),   // Victoria, TX area
        ("HOU", 29.65, -95.28),   // Houston Hobby
        ("INK", 31.78, -103.20),  // Wink, TX
        ("LCH", 30.13, -93.22),   // Lake Charles, LA
        ("LIT", 34.73, -92.22),   // Little Rock, AR
        ("LRD", 27.54, -99.46),   // Laredo, TX
        ("MEM", 35.04, -90.00),   // Memphis, TN
        ("MRF", 30.37, -104.02),  // Marfa, TX
        ("MSY", 29.99, -90.26),   // New Orleans, LA
        ("OKC", 35.39, -97.60),   // Oklahoma City, OK
        ("PHX", 33.43, -112.01),  // Phoenix, AZ
        ("PRC", 34.65, -112.42),  // Prescott, AZ
        ("PSX", 28.73, -96.25),   // Palacios, TX
        ("ROW", 33.30, -104.53),  // Roswell, NM
        ("SAT", 29.53, -98.47),   // San Antonio, TX
        ("SHV", 32.45, -93.83),   // Shreveport, LA
        ("SPS", 33.99, -98.49),   // Wichita Falls, TX
        ("TCC", 35.18, -103.60),  // Tucumcari, NM
        ("TUL", 36.20, -95.89),   // Tulsa, OK
        ("TUS", 32.12, -110.94),  // Tucson, AZ
        ("ZUN", 34.97, -109.15),  // Zuni, NM

        // Northwest / Mountain
        ("BAM", 40.60, -117.87),  // Battle Mountain, NV
        ("BCE", 37.71, -112.15),  // Bryce Canyon, UT
        ("BIL", 45.81, -108.54),  // Billings, MT
        ("BIH", 37.37, -118.36),  // Bishop, CA
        ("BLH", 33.62, -114.72),  // Blythe, CA
        ("BOI", 43.57, -116.22),  // Boise, ID
        ("CZI", 35.61, -110.45),  // Chinle, AZ
        ("DLN", 45.25, -112.55),  // Dillon, MT
        ("ELY", 39.30, -114.84),  // Ely, NV
        ("EKN", 38.89, -79.86),   // Elkins, WV
        ("GEG", 47.62, -117.53),  // Spokane, WA
        ("GPI", 48.31, -114.26),  // Glacier Park, MT
        ("GTF", 47.48, -111.37),  // Great Falls, MT
        ("IMB", 42.60, -114.66),  // Burley, ID
        ("LAS", 36.08, -115.15),  // Las Vegas, NV
        ("LKV", 42.16, -120.40),  // Lakeview, OR
        ("LWS", 46.37, -117.01),  // Lewiston, ID
        ("MBW", 43.63, -116.63),  // Mountain Home, ID area
        ("PIH", 42.91, -112.60),  // Pocatello, ID
        ("RDM", 44.25, -121.15),  // Redmond, OR
        ("RNO", 39.50, -119.77),  // Reno, NV
        ("SEA", 47.45, -122.31),  // Seattle, WA
        ("SLC", 40.78, -111.97),  // Salt Lake City, UT
        ("YKM", 46.57, -120.54),  // Yakima, WA

        // California / Pacific
        ("AST", 46.16, -123.88),  // Astoria, OR
        ("FAT", 36.78, -119.72),  // Fresno, CA
        ("FOT", 40.55, -124.13),  // Fortuna, CA
        ("ONT", 34.05, -117.60),  // Ontario, CA
        ("OTH", 43.42, -124.25),  // North Bend, OR
        ("PDX", 45.59, -122.60),  // Portland, OR
        ("RBL", 40.15, -122.25),  // Red Bluff, CA
        ("RDU", 35.88, -78.79),   // Raleigh-Durham, NC
        ("SAC", 38.51, -121.49),  // Sacramento, CA
        ("SAN", 32.73, -117.19),  // San Diego, CA
        ("SBA", 34.43, -119.84),  // Santa Barbara, CA
        ("SFO", 37.62, -122.38),  // San Francisco, CA
        ("SIY", 41.78, -122.47),  // Montague, CA
        ("WJF", 34.74, -118.22),  // Lancaster, CA

        // Texas special stations
        ("T01", 30.34, -97.77),   // Austin area
        ("T06", 33.98, -98.59),   // Sheppard AFB area
        ("T07", 31.99, -102.08),  // Midland area

        // Alaska - from region=alaska
        ("ADK", 51.88, -176.65),  // Adak Island
        ("ADQ", 57.75, -152.50),  // Kodiak
        ("AFM", 67.11, -157.86),  // Ambler
        ("AKN", 58.68, -156.65),  // King Salmon
        ("ANC", 61.17, -150.02),  // Anchorage
        ("ANN", 55.04, -131.57),  // Annette Island
        ("BET", 60.78, -161.84),  // Bethel
        ("BRW", 71.29, -156.77),  // Barrow/Utqiagvik
        ("BTI", 70.13, -143.58),  // Barter Island
        ("BTT", 66.91, -151.53),  // Bettles
        ("CDB", 55.21, -162.72),  // Cold Bay
        ("CZF", 61.78, -166.04),  // Cape Romanzof
        ("EHM", 58.65, -162.06),  // Cape Newenham
        ("FAI", 64.81, -147.86),  // Fairbanks
        ("FYU", 66.57, -145.25),  // Fort Yukon
        ("GAL", 64.74, -156.94),  // Galena
        ("GKN", 62.16, -145.46),  // Gulkana
        ("HOM", 59.65, -151.48),  // Homer
        ("IKO", 52.94, -168.85),  // Nikolski
        ("JNU", 58.36, -134.58),  // Juneau
        ("LUR", 68.88, -166.11),  // Cape Lisburne
        ("MCG", 62.95, -155.61),  // McGrath
        ("MDO", 59.45, -146.31),  // Middleton Island
        ("OME", 64.51, -165.44),  // Nome
        ("ORT", 63.88, -141.93),  // Northway
        ("OTZ", 66.89, -162.60),  // Kotzebue
        ("SNP", 57.17, -170.22),  // St. Paul Island
        ("TKA", 62.32, -150.09),  // Talkeetna
        ("UNK", 63.89, -160.80),  // Unalakleet
        ("YAK", 59.51, -139.66),  // Yakutat

        // Hawaii - from region=hawaii
        ("HNL", 21.32, -157.93),  // Honolulu
        ("ITO", 19.72, -155.05),  // Hilo
        ("KOA", 19.74, -156.05),  // Kona
        ("LIH", 21.98, -159.34),  // Lihue
        ("LNY", 20.79, -156.95),  // Lanai
        ("OGG", 20.90, -156.43),  // Kahului/Maui
    ]

    // MARK: - Winds Aloft Fetching (aviationweather.gov)
    func fetchWindsAloft(for airport: String) async throws -> [WindsAloftData] {
        let icao = airport.uppercased()

        // Determine the region based on airport location
        var region = "all"  // Default to CONUS
        var airportLat: Double?
        var airportLon: Double?

        if let airportInfo = AirportDatabaseManager.shared.getAirport(for: icao) {
            airportLat = airportInfo.coordinate.latitude
            airportLon = airportInfo.coordinate.longitude

            // Determine region based on coordinates
            if let lat = airportLat, let lon = airportLon {
                if lat >= 50.0 && lon < -130.0 {
                    // Alaska (north of 50°N and west of 130°W)
                    region = "alaska"
                } else if lat >= 18.0 && lat <= 23.0 && lon >= -161.0 && lon <= -154.0 {
                    // Hawaii (roughly 18-23°N, 154-161°W)
                    region = "hawaii"
                }
            }
        }

        // Use the winds aloft API - it provides forecast winds at various altitudes
        // Note: The API returns text format with all altitude levels included
        let urlString = "https://aviationweather.gov/api/data/windtemp?region=\(region)"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

        print("🌬️ Fetching winds aloft for \(icao) from region: \(region)")

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let text = String(data: data, encoding: .utf8) else {
            throw WeatherBannerError.noData
        }

        // First try to parse winds for the requested airport
        let results = parseWindsAloft(from: text, for: icao, sourceStation: nil)

        // If no data found, try to find the nearest winds aloft station
        if results.isEmpty {
            print("🔄 No winds aloft for \(icao), looking for nearest station...")

            // Get the airport's coordinates from AirportDatabaseManager
            if let lat = airportLat, let lon = airportLon {
                // Find the nearest winds aloft station
                if let nearestStation = findNearestWindsAloftStation(lat: lat, lon: lon) {
                    print("📍 Found nearest station: \(nearestStation.code) at \(Int(nearestStation.distance))nm")

                    // Parse winds from the nearest station
                    let fallbackResults = parseWindsAloft(from: text, for: nearestStation.code, sourceStation: nearestStation.code)

                    if !fallbackResults.isEmpty {
                        print("✅ Using winds from \(nearestStation.code) for \(icao)")
                        return fallbackResults
                    }
                }
            } else {
                print("⚠️ Airport \(icao) not found in database, cannot find nearest station")
            }
        }

        return results
    }

    /// Find the nearest winds aloft station to a given location
    private func findNearestWindsAloftStation(lat: Double, lon: Double) -> (code: String, distance: Double)? {
        var nearestStation: (code: String, distance: Double)? = nil

        for station in Self.windsAloftStations {
            let distance = haversineDistance(lat1: lat, lon1: lon, lat2: station.lat, lon2: station.lon)

            if nearestStation == nil || distance < nearestStation!.distance {
                nearestStation = (station.code, distance)
            }
        }

        return nearestStation
    }

    /// Calculate distance between two coordinates in nautical miles using Haversine formula
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 3440.065 // Earth's radius in nautical miles
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }

    private func parseWindsAloft(from text: String, for airport: String, sourceStation: String?) -> [WindsAloftData] {
        var results: [WindsAloftData] = []
        let lines = text.components(separatedBy: .newlines)

        // Standard altitudes for winds aloft
        let altitudes = [3000, 6000, 9000, 12000, 18000, 24000, 30000, 34000, 39000]

        // Winds aloft uses 3-letter identifiers (DTW not KDTW)
        let searchCode = airport.hasPrefix("K") && airport.count == 4
            ? String(airport.dropFirst())
            : airport

        print("🔍 Searching winds aloft for '\(searchCode)' (from '\(airport)')")
        print("📄 Total lines in response: \(lines.count)")

        for line in lines {
            // Look for lines that start with the airport identifier
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // The format can have the station ID at any position, not just at start
            // Common format: "DTW  2408 2410+05 2412+00 ..."
            guard trimmed.uppercased().contains(searchCode.uppercased()) else { continue }

            print("✅ Found matching line: \(trimmed.prefix(60))...")

            // Parse the wind data - format varies by source
            // Typical format: DTW 2714 2725+03 2735+00 2740-07 ...
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count > 1 else { continue }

            print("📊 Components: \(components.prefix(5).joined(separator: ", "))...")

            // Find the station ID index and start parsing from the next component
            var startIndex = 0
            for (i, comp) in components.enumerated() {
                if comp.uppercased().contains(searchCode.uppercased()) {
                    startIndex = i + 1
                    break
                }
            }

            for (index, component) in components.dropFirst(startIndex).enumerated() {
                guard index < altitudes.count else { break }
                let altitude = altitudes[index]

                // Parse wind component (4-6 characters: DDSS or DDSS+TT or DDSS-TT)
                if let windData = parseWindComponent(component, altitude: altitude, sourceStation: sourceStation) {
                    results.append(windData)
                    print("  ✓ Parsed \(altitude)': dir=\(windData.direction ?? -1)° spd=\(windData.speed ?? -1)kt temp=\(windData.temperature ?? -999)°C")
                } else {
                    print("  ✗ Failed to parse component '\(component)' for \(altitude)'")
                }
            }

            break  // Found our airport, stop searching
        }

        // If no data found, log - winds aloft uses limited reporting stations
        if results.isEmpty {
            print("⚠️ No wind data found for \(searchCode) - station may not be in winds aloft network")
            // Return empty array so UI shows appropriate message
            return []
        }

        print("✅ Parsed \(results.count) wind levels for \(searchCode)")
        return results
    }

    private func parseWindComponent(_ component: String, altitude: Int, sourceStation: String? = nil) -> WindsAloftData? {
        // Winds aloft format:
        // Low altitudes (3000-24000): DDSS or DDSS+TT or DDSS-TT
        //   DD = direction (tens of degrees, so 27 = 270°)
        //   SS = speed in knots
        //   TT = temperature (optional, with sign)
        // High altitudes (30000+): DDSSTS or DDSSTT
        //   When speed > 99kt: DD is direction + 50, SSS is speed - 100
        //   Example: 268237 = dir=(26-50)*10=360°, speed=82+100=182kt, temp=-37°C
        //   (Actually: 268237 means dir=260°, speed=82kt, temp=-37°C for encoded high altitude)

        var windPart = component
        var temp: Int? = nil

        // For high altitudes (30000+), the format is 6 digits: DDSSTS
        // Where DDD encodes direction (if DD >= 51, subtract 50 and add 100 to speed)
        if altitude >= 30000 && component.count == 6 {
            // Format: DDSSTS where last 2 digits are temp (negative at these altitudes)
            let dirStr = String(component.prefix(2))
            let spdStr = String(component.dropFirst(2).prefix(2))
            let tempStr = String(component.suffix(2))

            guard let dirTens = Int(dirStr), let speed = Int(spdStr), let tempVal = Int(tempStr) else {
                return nil
            }

            var direction: Int
            var actualSpeed: Int

            if dirTens >= 51 {
                // Speed > 99kt encoding: subtract 50 from direction, add 100 to speed
                direction = (dirTens - 50) * 10
                actualSpeed = speed + 100
            } else {
                direction = dirTens * 10
                actualSpeed = speed
            }

            // Temperature is always negative at these altitudes
            temp = -tempVal

            return WindsAloftData(altitude: altitude, direction: direction, speed: actualSpeed, temperature: temp, sourceStation: sourceStation)
        }

        // Standard format for lower altitudes
        // Extract temperature if present
        if let plusIndex = component.firstIndex(of: "+") {
            let tempString = String(component[component.index(after: plusIndex)...])
            temp = Int(tempString)
            windPart = String(component[..<plusIndex])
        } else if let minusIndex = component.lastIndex(of: "-"), minusIndex != component.startIndex {
            let tempString = String(component[component.index(after: minusIndex)...])
            temp = -(Int(tempString) ?? 0)
            windPart = String(component[..<minusIndex])
        }

        guard windPart.count >= 4 else { return nil }

        let dirStr = String(windPart.prefix(2))
        let spdStr = String(windPart.dropFirst(2).prefix(2))

        guard let dirTens = Int(dirStr), let speed = Int(spdStr) else { return nil }

        // Special case: 9900 means light and variable
        if dirTens == 99 && speed == 0 {
            return WindsAloftData(altitude: altitude, direction: nil, speed: 0, temperature: temp, sourceStation: sourceStation)
        }

        var direction = dirTens * 10
        var actualSpeed = speed

        // Check for high-speed encoding (direction >= 51)
        if dirTens >= 51 {
            direction = (dirTens - 50) * 10
            actualSpeed = speed + 100
        }

        return WindsAloftData(altitude: altitude, direction: direction, speed: actualSpeed, temperature: temp, sourceStation: sourceStation)
    }

    // MARK: - Daily Forecast Fetching (weather.gov)
    func fetchDailyForecast(latitude: Double, longitude: Double) async throws -> [DailyForecastData] {
        // Step 1: Get the forecast URL for this location
        let pointsURL = "https://api.weather.gov/points/\(latitude),\(longitude)"
        guard let url = URL(string: pointsURL) else {
            throw WeatherBannerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("TheProPilotApp/1.0", forHTTPHeaderField: "User-Agent")

        let (pointsData, _) = try await URLSession.shared.data(for: request)

        // Parse the points response to get forecast URL
        guard let pointsJson = try? JSONSerialization.jsonObject(with: pointsData) as? [String: Any],
              let properties = pointsJson["properties"] as? [String: Any],
              let forecastURLString = properties["forecast"] as? String,
              let forecastURL = URL(string: forecastURLString) else {
            throw WeatherBannerError.noData
        }

        // Step 2: Fetch the actual forecast
        var forecastRequest = URLRequest(url: forecastURL)
        forecastRequest.setValue("TheProPilotApp/1.0", forHTTPHeaderField: "User-Agent")

        let (forecastData, _) = try await URLSession.shared.data(for: forecastRequest)

        guard let forecastJson = try? JSONSerialization.jsonObject(with: forecastData) as? [String: Any],
              let forecastProperties = forecastJson["properties"] as? [String: Any],
              let periods = forecastProperties["periods"] as? [[String: Any]] else {
            throw WeatherBannerError.noData
        }

        // Parse periods into DailyForecastData
        var forecasts: [DailyForecastData] = []

        for period in periods.prefix(14) {  // Get up to 7 days (14 periods: day/night)
            guard let name = period["name"] as? String,
                  let shortForecast = period["shortForecast"] as? String,
                  let detailedForecast = period["detailedForecast"] as? String,
                  let isDaytime = period["isDaytime"] as? Bool else { continue }

            let temperature = period["temperature"] as? Int
            let precipChance = (period["probabilityOfPrecipitation"] as? [String: Any])?["value"] as? Int
            let windSpeed = period["windSpeed"] as? String
            let windDirection = period["windDirection"] as? String

            // Parse start time
            let startTimeString = period["startTime"] as? String ?? ""
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: startTimeString) ?? Date()

            // Determine icon based on forecast text
            let icon = weatherIconForForecast(shortForecast)

            let forecast = DailyForecastData(
                date: date,
                name: name,
                highTemp: isDaytime ? temperature : nil,
                lowTemp: isDaytime ? nil : temperature,
                shortForecast: shortForecast,
                detailedForecast: detailedForecast,
                precipChance: precipChance,
                icon: icon,
                windSpeed: windSpeed,
                windDirection: windDirection,
                isDaytime: isDaytime
            )

            forecasts.append(forecast)
        }

        return forecasts
    }

    private func weatherIconForForecast(_ forecast: String) -> String {
        let lower = forecast.lowercased()

        if lower.contains("thunder") || lower.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if lower.contains("rain") || lower.contains("shower") {
            return "cloud.rain.fill"
        } else if lower.contains("snow") {
            return "cloud.snow.fill"
        } else if lower.contains("sleet") || lower.contains("ice") {
            return "cloud.sleet.fill"
        } else if lower.contains("fog") || lower.contains("mist") {
            return "cloud.fog.fill"
        } else if lower.contains("cloudy") || lower.contains("overcast") {
            return "cloud.fill"
        } else if lower.contains("partly") {
            return "cloud.sun.fill"
        } else if lower.contains("clear") || lower.contains("sunny") {
            return "sun.max.fill"
        }

        return "cloud.fill"
    }

    // MARK: - D-ATIS Fetching (clowd.io)
    func fetchDATIS(for airport: String) async throws -> DATISData {
        let icao = airport.uppercased()

        // Primary source: clowd.io D-ATIS API
        let urlString = "https://datis.clowd.io/api/\(icao)"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        // Try parsing as array (clowd.io returns array of ATIS entries)
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var arrivalATIS: String?
            var departureATIS: String?
            var combinedATIS: String?

            for item in jsonArray {
                if let datis = item["datis"] as? String,
                   let type = item["type"] as? String {
                    let typeUpper = type.uppercased()
                    if typeUpper == "ARR" {
                        arrivalATIS = datis
                    } else if typeUpper == "DEP" {
                        departureATIS = datis
                    } else if typeUpper == "COMBINED" {
                        combinedATIS = datis
                    }
                }
            }

            // If we found at least one ATIS
            if arrivalATIS != nil || departureATIS != nil || combinedATIS != nil {
                return DATISData(
                    airport: icao,
                    arrivalATIS: arrivalATIS ?? combinedATIS,
                    departureATIS: departureATIS ?? combinedATIS,
                    combinedATIS: combinedATIS
                )
            }
        }

        throw WeatherBannerError.noData
    }
}

// MARK: - D-ATIS Data Model
struct DATISData {
    let airport: String
    let arrivalATIS: String?
    let departureATIS: String?
    let combinedATIS: String?

    var hasData: Bool {
        arrivalATIS != nil || departureATIS != nil || combinedATIS != nil
    }

    /// Extract information letter (e.g., "ATIS INFO BRAVO" -> "B")
    var informationLetter: String? {
        let text = arrivalATIS ?? departureATIS ?? combinedATIS ?? ""
        let upper = text.uppercased()

        // Look for "INFORMATION [LETTER]" or "INFO [LETTER]"
        let patterns = ["INFORMATION ", "INFO "]
        for pattern in patterns {
            if let range = upper.range(of: pattern) {
                let afterPattern = upper[range.upperBound...]
                if let firstWord = afterPattern.split(separator: " ").first {
                    // Convert phonetic to letter
                    return phoneticToLetter(String(firstWord))
                }
            }
        }
        return nil
    }

    private func phoneticToLetter(_ phonetic: String) -> String {
        let mapping: [String: String] = [
            "ALPHA": "A", "BRAVO": "B", "CHARLIE": "C", "DELTA": "D",
            "ECHO": "E", "FOXTROT": "F", "GOLF": "G", "HOTEL": "H",
            "INDIA": "I", "JULIET": "J", "KILO": "K", "LIMA": "L",
            "MIKE": "M", "NOVEMBER": "N", "OSCAR": "O", "PAPA": "P",
            "QUEBEC": "Q", "ROMEO": "R", "SIERRA": "S", "TANGO": "T",
            "UNIFORM": "U", "VICTOR": "V", "WHISKEY": "W", "XRAY": "X",
            "YANKEE": "Y", "ZULU": "Z"
        ]
        return mapping[phonetic.uppercased()] ?? phonetic.prefix(1).uppercased()
    }
}

enum WeatherBannerError: LocalizedError {
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No weather data"
        }
    }
}

// MARK: - Weather Tab Enum (ForeFlight Style)
enum WeatherDisplayTab: String, CaseIterable, Identifiable {
    case metar = "METAR"
    case datis = "D-ATIS"
    case taf = "TAF"
    case mos = "MOS"
    case daily = "Daily"
    case winds = "Winds"
    case images = "Images"

    var id: String { rawValue }
}

// MARK: - Compact Weather Banner
struct WeatherBannerView: View {
    var activeTrip: Trip?  // ✅ Pass in active trip to get route airports

    @ObservedObject var weatherService = BannerWeatherService.shared
    @ObservedObject var nearestAirportManager = NearestAirportManager.shared
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    @State private var showWeatherSheet: Bool = false
    @State private var routeAirports: [String] = []  // All airports in route
    @State private var selectedAirportIndex: Int = 0  // Current airport being shown
    @State private var weatherData: [String: RawMETAR] = [:]  // Cache for all route weather
    @State private var tafData: [String: RawTAF] = [:]  // Cache for TAF data
    @State private var mosData: [String: [MOSForecast]] = [:]  // Cache for MOS data
    @State private var windsAloftData: [String: [WindsAloftData]] = [:]  // Cache for winds aloft
    @State private var dailyForecastData: [DailyForecastData] = []  // Daily forecast (location-based)
    @State private var datisData: [String: DATISData] = [:]  // Cache for D-ATIS data
    @State private var isLoading = false
    @State private var isLoadingRunways = false
    @State private var isLoadingMOS = false
    @State private var isLoadingWinds = false
    @State private var isLoadingDaily = false
    @State private var isLoadingDATIS = false
    @State private var selectedWeatherTab: WeatherDisplayTab = .metar  // ForeFlight-style tabs
    @State private var showDecodedTAF = false  // Toggle for decoded TAF view
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Banner (Always visible when shown)
            compactBanner
        }
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LogbookTheme.accentGreen.opacity(0.6),
                            LogbookTheme.accentBlue.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(
                routeAirports: $routeAirports,
                selectedAirportIndex: $selectedAirportIndex,
                weatherData: $weatherData,
                tafData: $tafData,
                mosData: $mosData,
                windsAloftData: $windsAloftData,
                dailyForecastData: $dailyForecastData,
                datisData: $datisData,
                weatherService: weatherService,
                settingsStore: settingsStore,
                onRefresh: { loadAllWeather() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(LogbookTheme.navyLight)
        }
        .onAppear {
            extractRouteAirports()
            loadAllWeather()
            
            // Request location for nearest airport if no active trip
            if activeTrip == nil {
                nearestAirportManager.requestLocationUpdate()
            }
        }
        .onChange(of: activeTrip?.id) { _, _ in
            extractRouteAirports()
            loadAllWeather()
        }
        .onChange(of: activeTrip?.legs.map { "\($0.departure)-\($0.arrival)" }.joined()) { _, _ in
            // Refresh when any departure or arrival changes
            extractRouteAirports()
            loadAllWeather()
        }
        .onChange(of: showWeatherSheet) { _, newValue in
            if newValue {
                // Load runway data when sheet is shown
                loadRunwayDataIfNeeded()
            }
        }
        .onChange(of: selectedAirportIndex) { _, _ in
            // Clear daily forecast cache when airport changes (it's location-specific)
            dailyForecastData = []
            // Load runway data for newly selected airport
            loadRunwayDataIfNeeded()
        }
        .onChange(of: nearestAirportManager.nearestAirport) { _, newAirport in
            // When nearest airport is found and there's no active trip, load its weather
            if activeTrip == nil, let airport = newAirport {
                routeAirports = [airport]
                loadAllWeather()
            }
        }
    }
    
    // MARK: - Extract Route Airports
    private func extractRouteAirports() {
        guard let trip = activeTrip else {
            // If no active trip, use nearest airport if available
            if let nearestAirport = nearestAirportManager.nearestAirport {
                routeAirports = [nearestAirport]
                selectedAirportIndex = 0
                print("🌤️ Using nearest airport: \(nearestAirport)")
            } else {
                routeAirports = []
                // Request location update to find nearest airport
                nearestAirportManager.requestLocationUpdate()
            }
            return
        }
        
        // Get all unique airports from legs (departure + arrival)
        var airports: [String] = []
        for leg in trip.legs {
            if !leg.departure.isEmpty && !airports.contains(leg.departure) {
                airports.append(leg.departure)
            }
            if !leg.arrival.isEmpty && !airports.contains(leg.arrival) {
                airports.append(leg.arrival)
            }
        }
        
        routeAirports = airports
        selectedAirportIndex = 0  // Start with first airport
        
        print("🌤️ Weather banner extracting route: \(airports.joined(separator: " → "))")
    }
    
    // MARK: - Compact Banner
    private var compactBanner: some View {
        VStack(spacing: 0) {
            // Main weather display
            Button(action: {
                showWeatherSheet = true
            }) {
                HStack(spacing: 12) {
                    // Weather Icon
                    weatherIcon
                    
                    // Airport & Category
                    if routeAirports.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nearestAirportManager.locationAuthorized ? "Finding Nearest Airport..." : "Location Required")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                            
                            if !nearestAirportManager.locationAuthorized {
                                Button(action: {
                                    nearestAirportManager.checkAuthorizationStatus()
                                }) {
                                    Text("Enable Location")
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                            } else {
                                Text("Searching for nearby airports...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            // Airport code with position indicator
                            HStack(spacing: 4) {
                                Text(currentAirport)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                // Show "Nearest" badge if no active trip
                                if activeTrip == nil {
                                    Text("📍 NEAREST")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(LogbookTheme.accentGreen)
                                        .cornerRadius(3)
                                } else if routeAirports.count > 1 {
                                    Text("(\(selectedAirportIndex + 1)/\(routeAirports.count))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            if let weather = currentWeather {
                                HStack(spacing: 4) {
                                    if let category = weather.flightCategory {
                                        categoryBadge(category)
                                    }
                                    if let tempStr = weather.temperature(useCelsius: settingsStore.useCelsius) {
                                        Text(tempStr)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else if isLoading {
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("Tap to load")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Quick Weather Info
                    if let weather = currentWeather {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(windString(for: weather))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            
                            // Use user's pressure preference
                            if let pressureText = weather.formattedPressure(useInHg: settingsStore.usePressureInHg) {
                                Text(pressureText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Expand Chevron (always down since sheet opens)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            // Navigation arrows (if multiple airports)
            if routeAirports.count > 1 {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 0) {
                    // Previous Airport
                    Button(action: {
                        withAnimation {
                            selectedAirportIndex = (selectedAirportIndex - 1 + routeAirports.count) % routeAirports.count
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12))
                            Text(previousAirport)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .frame(height: 20)
                    
                    // Next Airport
                    Button(action: {
                        withAnimation {
                            selectedAirportIndex = (selectedAirportIndex + 1) % routeAirports.count
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(nextAirport)
                                .font(.system(size: 11, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }
                .background(Color.white.opacity(0.03))
            }
        }
    }
    
    // MARK: - Current Airport Helper
    private var currentAirport: String {
        guard !routeAirports.isEmpty, selectedAirportIndex < routeAirports.count else {
            return "----"
        }
        return routeAirports[selectedAirportIndex]
    }
    
    private var currentWeather: RawMETAR? {
        return weatherData[currentAirport]
    }
    
    private var previousAirport: String {
        guard routeAirports.count > 1 else { return "" }
        let prevIndex = (selectedAirportIndex - 1 + routeAirports.count) % routeAirports.count
        return routeAirports[prevIndex]
    }
    
    private var nextAirport: String {
        guard routeAirports.count > 1 else { return "" }
        let nextIndex = (selectedAirportIndex + 1) % routeAirports.count
        return routeAirports[nextIndex]
    }
    
    // MARK: - Weather Icon (✅ Using centralized WeatherIconHelper)
    private var weatherIcon: some View {
        Group {
            if let weather = currentWeather {
                WeatherIcon(weather: weather, size: 24, filled: true, showBackground: false)
                    .frame(width: 32, height: 32)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
        }
    }
    
    // MARK: - Legacy Helper (now replaced by WeatherIconHelper - kept for backwards compatibility)
    @available(*, deprecated, message: "Use WeatherIconHelper.icon(for:) instead")
    private func weatherIconName(for category: String?) -> String {
        // Delegate to centralized helper
        if let weather = currentWeather {
            return WeatherIconHelper.icon(for: weather, filled: true)
        }
        
        // Fallback based on category only
        if let weather = currentWeather {
            // Check for precipitation/weather phenomena first
            if let wx = weather.wxString?.uppercased() {
                if wx.contains("TS") || wx.contains("TSRA") {
                    return "cloud.bolt.rain.fill"  // Thunderstorm
                } else if wx.contains("SN") || wx.contains("SNOW") {
                    return "cloud.snow.fill"  // Snow
                } else if wx.contains("RA") || wx.contains("RAIN") || wx.contains("DZ") {
                    return "cloud.rain.fill"  // Rain
                } else if wx.contains("FG") || wx.contains("BR") || wx.contains("HZ") {
                    return "cloud.fog.fill"  // Fog/Mist/Haze
                }
            }
            
            // Check cloud coverage
            if let clouds = weather.cover?.uppercased() {
                if clouds.contains("OVC") {
                    return "cloud.fill"  // Overcast
                } else if clouds.contains("BKN") {
                    return "cloud.sun.fill"  // Broken (sun peeking through)
                } else if clouds.contains("SCT") {
                    return "cloud.sun.fill"  // Scattered (sun with clouds)
                } else if clouds.contains("FEW") {
                    return "sun.max.fill"  // Few clouds (mostly sunny)
                } else if clouds.contains("CLR") || clouds.contains("SKC") {
                    return "sun.max.fill"  // Clear
                }
            }
        }
        
        // Fall back to flight category-based icons
        guard let category = category else { return "cloud.fill" }
        switch category {
        case "VFR": return "sun.max.fill"
        case "MVFR": return "cloud.sun.fill"
        case "IFR": return "cloud.fill"
        case "LIFR": return "cloud.rain.fill"
        default: return "cloud.fill"
        }
    }
    
    // MARK: - Wind String Helper
    private func windString(for weather: RawMETAR) -> String {
        if let dir = weather.windDirection, let speed = weather.wspd {
            if let gust = weather.wgst {
                return "\(String(format: "%03d", dir))@\(speed)G\(gust)kt"
            }
            return "\(String(format: "%03d", dir))@\(speed)kt"
        } else if let speed = weather.wspd, speed > 0 {
            // Variable wind
            if let gust = weather.wgst {
                return "VRB \(speed)G\(gust)kt"
            }
            return "VRB \(speed)kt"
        }
        return "Calm"
    }
    
    // MARK: - Category Badge
    private func categoryBadge(_ category: String) -> some View {
        Text(category)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(categoryColor(category))
            .cornerRadius(3)
    }
    
    // MARK: - Time Age Color
    private func timeAgeColor(_ weather: RawMETAR) -> Color {
        guard let timestamp = weather.obsTime else { return .gray }
        
        let observationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let elapsed = Date().timeIntervalSince(observationDate)
        let minutes = Int(elapsed / 60)
        
        if minutes < 30 {
            return .green      // Fresh data (< 30 min)
        } else if minutes < 60 {
            return .yellow     // Getting old (30-60 min)
        } else if minutes < 120 {
            return .orange     // Old (1-2 hours)
        } else {
            return .red        // Very old (> 2 hours)
        }
    }
    
    // MARK: - Expanded Details (ForeFlight Style with Tabs)
    private var expandedDetails: some View {
        VStack(spacing: 0) {
            // Weather Tab Selector (ForeFlight style)
            weatherTabSelector

            Divider()
                .background(Color.white.opacity(0.2))

            if routeAirports.isEmpty {
                emptyStateView
            } else {
                // Tab Content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedWeatherTab {
                        case .metar:
                            enhancedMETARView
                        case .datis:
                            datisView
                        case .taf:
                            tafView
                        case .mos:
                            mosView
                        case .daily:
                            dailyForecastView
                        case .winds:
                            windsAloftView
                        case .images:
                            weatherImagesView
                        }

                        // Route Weather Summary (if multiple airports)
                        if routeAirports.count > 1 {
                            routeWeatherSummary
                        }

                        // Refresh Button
                        refreshButton
                    }
                }
            }
        }
    }

    // MARK: - Weather Tab Selector
    private var weatherTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(WeatherDisplayTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeatherTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedWeatherTab == tab ? .bold : .medium))
                                .foregroundColor(selectedWeatherTab == tab ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                            // Underline indicator
                            Rectangle()
                                .fill(selectedWeatherTab == tab ? LogbookTheme.accentGreen : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(LogbookTheme.navyLight)
    }

    // MARK: - Enhanced METAR View (ForeFlight Style)
    private var enhancedMETARView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weather = currentWeather {
                // Flight Category Header with Badge
                HStack {
                    // Large Flight Category Badge - use API category or calculate from raw METAR
                    let category = weather.flightCategory ?? calculateFlightCategory(from: weather)
                    flightCategoryBadge(category)

                    Spacer()

                    // Time ago indicator
                    Text(weather.timeAgo)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(timeAgeColor(weather))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timeAgeColor(weather).opacity(0.2))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Color-coded Raw METAR
                colorCodedRawMETAR(weather)
                    .padding(.horizontal, 12)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)

                // Parsed Weather Data Table (ForeFlight style with cyan values)
                parsedWeatherTable(weather)
                    .padding(.horizontal, 12)

                // Runway Analysis (if available)
                runwayAnalysisSection(weather)

            } else if isLoading {
                loadingView
            } else {
                noDataView("No METAR data available")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Flight Category Badge (Large, Prominent)
    private func flightCategoryBadge(_ category: String) -> some View {
        // Display full name for better clarity
        let displayName: String
        switch category {
        case "LIFR": displayName = "Low IFR"
        case "IFR": displayName = "IFR"
        case "MVFR": displayName = "Marginal VFR"
        case "VFR": displayName = "VFR"
        default: displayName = category
        }

        return HStack(spacing: 8) {
            Circle()
                .fill(categoryColor(category))
                .frame(width: 12, height: 12)

            Text(displayName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(categoryColor(category))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor(category).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Color-Coded Raw METAR
    private func colorCodedRawMETAR(_ weather: RawMETAR) -> some View {
        // Use API flight category if available, otherwise calculate from raw METAR
        let category = weather.flightCategory ?? calculateFlightCategory(from: weather)
        return Text(weather.rawOb)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(categoryColor(category))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .textSelection(.enabled)
    }

    // MARK: - Calculate Flight Category from Raw METAR
    private func calculateFlightCategory(from weather: RawMETAR) -> String {
        // FAA Flight Category criteria:
        // LIFR: ceiling < 500ft OR visibility < 1 SM
        // IFR: ceiling 500-999ft OR visibility 1-3 SM
        // MVFR: ceiling 1000-3000ft OR visibility 3-5 SM
        // VFR: ceiling > 3000ft AND visibility > 5 SM

        let vis = weather.visibility ?? 10.0
        let ceiling = parseCeilingFromCover(weather.cover) ?? parseCeilingFromRaw(weather.rawOb)

        // Determine category based on the WORST of ceiling or visibility
        var visCategory = "VFR"
        if vis < 1 { visCategory = "LIFR" }
        else if vis < 3 { visCategory = "IFR" }
        else if vis <= 5 { visCategory = "MVFR" }

        var ceilingCategory = "VFR"
        if let ceil = ceiling {
            if ceil < 500 { ceilingCategory = "LIFR" }
            else if ceil < 1000 { ceilingCategory = "IFR" }
            else if ceil <= 3000 { ceilingCategory = "MVFR" }
        }

        // Return the worst category
        let categoryOrder = ["LIFR": 0, "IFR": 1, "MVFR": 2, "VFR": 3]
        let visRank = categoryOrder[visCategory] ?? 3
        let ceilRank = categoryOrder[ceilingCategory] ?? 3
        return visRank < ceilRank ? visCategory : ceilingCategory
    }

    private func parseCeilingFromCover(_ cover: String?) -> Int? {
        guard let cover = cover else { return nil }
        let layers = cover.uppercased().components(separatedBy: " ")

        for layer in layers {
            // Only BKN, OVC, and VV count as ceilings
            var altitude: String?
            if layer.hasPrefix("VV") {
                altitude = String(layer.dropFirst(2))
            } else if layer.hasPrefix("BKN") || layer.hasPrefix("OVC") {
                altitude = String(layer.dropFirst(3))
            }

            if let alt = altitude, let altNum = Int(alt.prefix(while: { $0.isNumber })) {
                return altNum * 100  // Return first ceiling found (lowest)
            }
        }
        return nil
    }

    private func parseCeilingFromRaw(_ raw: String) -> Int? {
        let upper = raw.uppercased()
        let patterns = ["VV(\\d{3})", "BKN(\\d{3})", "OVC(\\d{3})"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: upper, options: [], range: NSRange(upper.startIndex..., in: upper)),
               let range = Range(match.range(at: 1), in: upper),
               let altNum = Int(upper[range]) {
                return altNum * 100
            }
        }
        return nil
    }

    // MARK: - Parsed Weather Table (ForeFlight Style)
    private func parsedWeatherTable(_ weather: RawMETAR) -> some View {
        VStack(spacing: 8) {
            // Time - show local time with timezone abbreviation
            if let obsTime = weather.observationTimeLocal {
                weatherTableRow(label: "Time", value: obsTime)
            }

            // Wind
            weatherTableRow(label: "Wind", value: windString(for: weather))

            // Visibility
            if let vis = weather.visibility {
                weatherTableRow(label: "Visibility", value: "\(visibilityString(for: vis)) sm")
            }

            // RVR (Runway Visual Range) - parse from raw METAR
            if let rvrString = parseRVR(from: weather.rawOb) {
                weatherTableRow(label: "RVR", value: rvrString)
            }

            // Clouds (AGL) - multiline display with flight category coloring
            cloudLayersRow(rawMetar: weather.rawOb, flightCategory: weather.flightCategory)

            // Weather Phenomena
            if let wxString = weather.wxString, !wxString.isEmpty {
                weatherTableRow(label: "Weather", value: formatWeatherPhenomena(wxString))
            }

            // Temperature with fog/icing caution indicator
            if let temp = weather.temp {
                let celsius = Int(temp)
                let fahrenheit = Int((temp * 9/5) + 32)
                let spread = weather.dewp.map { abs(temp - $0) } ?? 99
                temperatureRowWithCaution(
                    label: "Temperature",
                    value: "\(celsius)°C (\(fahrenheit)°F)",
                    showCaution: spread <= 3
                )
            }

            // Dewpoint
            if let dewp = weather.dewp {
                let celsius = Int(dewp)
                let fahrenheit = Int((dewp * 9/5) + 32)
                weatherTableRow(label: "Dewpoint", value: "\(celsius)°C (\(fahrenheit)°F)")
            }

            // Altimeter - use user's pressure preference
            if let pressureText = weather.formattedPressure(useInHg: settingsStore.usePressureInHg) {
                weatherTableRow(label: "Altimeter", value: pressureText)
            }

            // Humidity
            if let humidity = weather.relativeHumidity {
                weatherTableRow(label: "Humidity", value: "\(humidity)%")
            }

            // Density Altitude (calculated) - ensure altimeter is in inHg for calculation
            if let temp = weather.temp, let altim = weather.altim {
                // altim from API should be in inHg (typically 28-32 range)
                // If it's > 100, it's likely in millibars and needs conversion
                let altimInHg = altim > 100 ? altim / 33.8639 : altim
                // Use station elevation from API, default to 0 if not available
                let elevation = weather.elevationFeet ?? 0
                let densityAlt = calculateDensityAltitude(temp: temp, altimeter: altimInHg, elevation: elevation)
                weatherTableRow(label: "Density Altitude", value: "\(densityAlt)'")
            }
        }
    }

    // MARK: - Weather Table Row (ForeFlight Style)
    private func weatherTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Cloud Layers Row (multiline with flight category color)
    private func cloudLayersRow(rawMetar: String, flightCategory: String?) -> some View {
        let layers = parseCloudLayersArray(rawMetar)
        let lineCount = max(1, layers.count)
        let color = flightCategoryColor(flightCategory)

        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text("Clouds (AGL)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Cloud layers: Each on its own line, colored by flight category
                VStack(alignment: .leading, spacing: 2) {
                    if layers.isEmpty {
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(color)
                    } else {
                        ForEach(layers, id: \.self) { layer in
                            Text(layer)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(color)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: CGFloat(lineCount) * 20)
    }

    // MARK: - Parse Cloud Layers Array (sorted lowest first)
    private func parseCloudLayersArray(_ rawMetar: String) -> [String] {
        let components = rawMetar.uppercased().components(separatedBy: " ")
        var cloudLayers: [(altitude: Int, description: String)] = []

        for component in components {
            if component == "SKC" || component == "CLR" || component == "CAVOK" {
                return ["Clear"]
            }

            var cover = ""
            var altitude = ""

            if component.hasPrefix("VV") {
                altitude = String(component.dropFirst(2))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    let feet = altNum * 100
                    cloudLayers.append((feet, "Vertical Vis \(formatCloudAltitude(feet))"))
                }
                continue
            } else if component.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(component.dropFirst(3))
            }

            let altDigits = altitude.prefix(while: { $0.isNumber })
            if let altNum = Int(altDigits), !cover.isEmpty {
                let feet = altNum * 100
                cloudLayers.append((feet, "\(cover) \(formatCloudAltitude(feet))"))
            }
        }

        // Sort by altitude (lowest first)
        let sorted = cloudLayers.sorted { $0.altitude < $1.altitude }
        return sorted.map { $0.description }
    }

    // MARK: - Format Cloud Altitude (with comma for thousands)
    private func formatCloudAltitude(_ feet: Int) -> String {
        if feet >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: feet)) ?? "\(feet)")'"
        }
        return "\(feet)'"
    }

    // MARK: - Flight Category Color
    private func flightCategoryColor(_ category: String?) -> Color {
        guard let cat = category?.uppercased() else { return .cyan }
        switch cat {
        case "VFR":
            return .green
        case "MVFR":
            return .yellow
        case "IFR":
            return .red
        case "LIFR":
            return Color(red: 1.0, green: 0.0, blue: 1.0) // Magenta
        default:
            return .cyan
        }
    }

    // Temperature row with optional fog/icing caution indicator
    private func temperatureRowWithCaution(label: String, value: String, showCaution: Bool) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value with optional caution indicator
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)

                    if showCaution {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Runway Analysis Section
    private func runwayAnalysisSection(_ weather: RawMETAR) -> some View {
        Group {
            if let windDir = weather.windDirection,
               let windSpeed = weather.wspd,
               let runways = weatherService.cachedRunways[currentAirport],
               !runways.isEmpty {

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Runway Analysis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Wind: \(String(format: "%03d", windDir))° at \(windSpeed)kt")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    CompactRunwayWind(
                        windDirection: windDir,
                        windSpeed: windSpeed,
                        runways: runways.map { $0.ident }
                    )
                }
                .padding(.horizontal, 12)

            } else if isLoadingRunways {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading runway data...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }

    // MARK: - D-ATIS View
    private var datisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Information Letter badge
            HStack {
                Text("Digital ATIS - \(currentAirport)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if let datis = datisData[currentAirport], let letter = datis.informationLetter {
                    Text("INFO \(letter)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                }

                if isLoadingDATIS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let datis = datisData[currentAirport] {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Arrival ATIS
                        if let arrivalATIS = datis.arrivalATIS {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "airplane.arrival")
                                        .foregroundColor(.cyan)
                                    Text("ARRIVAL")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.cyan)
                                }

                                Text(arrivalATIS)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }

                        // Departure ATIS (if different from arrival)
                        if let departureATIS = datis.departureATIS,
                           departureATIS != datis.arrivalATIS {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "airplane.departure")
                                        .foregroundColor(.orange)
                                    Text("DEPARTURE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.orange)
                                }

                                Text(departureATIS)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }

                        // Combined ATIS (if neither arrival nor departure available)
                        if datis.arrivalATIS == nil && datis.departureATIS == nil,
                           let combinedATIS = datis.combinedATIS {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "airplane")
                                        .foregroundColor(.green)
                                    Text("ATIS")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                }

                                Text(combinedATIS)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingDATIS {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No D-ATIS available for \(currentAirport)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("D-ATIS is typically available at major airports")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            loadDATISData()
        }
    }

    // MARK: - Load D-ATIS Data
    private func loadDATISData() {
        guard !isLoadingDATIS else { return }
        guard datisData[currentAirport] == nil else { return }  // Already have data
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }

        isLoadingDATIS = true

        Task {
            do {
                let datis = try await weatherService.fetchDATIS(for: currentAirport)
                await MainActor.run {
                    datisData[currentAirport] = datis
                    isLoadingDATIS = false
                }
            } catch {
                print("❌ Failed to fetch D-ATIS for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingDATIS = false
                }
            }
        }
    }

    // MARK: - TAF View
    private var tafView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let taf = tafData[currentAirport] {
                // TAF Header
                HStack {
                    Text("Terminal Aerodrome Forecast")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if let issueTime = taf.issueTimeString {
                        Text(issueTime)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Toggle between raw and decoded
                HStack {
                    Button(action: { showDecodedTAF = false }) {
                        Text("Raw")
                            .font(.system(size: 12, weight: showDecodedTAF ? .regular : .bold))
                            .foregroundColor(showDecodedTAF ? .gray : .cyan)
                    }

                    Text("|")
                        .foregroundColor(.gray)

                    Button(action: { showDecodedTAF = true }) {
                        Text("Decoded")
                            .font(.system(size: 12, weight: showDecodedTAF ? .bold : .regular))
                            .foregroundColor(showDecodedTAF ? .cyan : .gray)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)

                if showDecodedTAF {
                    decodedTAFView(taf.rawTAF)
                } else {
                    // Raw TAF
                    Text(taf.rawTAF)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                }

            } else if isLoading {
                loadingView
            } else {
                noDataView("No TAF data available")
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            loadTAFData()
        }
    }

    // TAF Decoding Helpers for WeatherBannerView
    private func decodedTAFView(_ rawTAF: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Raw TAF at top (colored by estimated flight category)
                let groups = parseTAFGroups(rawTAF)
                let overallCategory = groups.first?.flightCategory

                Text(rawTAF)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor(overallCategory))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)

                // Decoded groups
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 4) {
                        // Group header with cloud icon and flight category
                        HStack(spacing: 8) {
                            Image(systemName: group.cloudIcon)
                                .font(.system(size: 16))
                                .foregroundColor(categoryColor(group.flightCategory))
                                .symbolRenderingMode(.multicolor)

                            Text(group.header)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(group.headerColor)

                            Spacer()

                            if let category = group.flightCategory {
                                Text(category)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor(category))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.bottom, 4)

                        // Table rows for this group (colored by flight category)
                        ForEach(group.rows, id: \.label) { row in
                            tafTableRow(label: row.label, value: row.value, category: group.flightCategory)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(minHeight: 150)
    }

    private func tafTableRow(label: String, value: String, category: String? = nil) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap (colored by category)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(categoryColor(category))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    private struct TAFGroup {
        let header: String
        let headerColor: Color
        let rows: [TAFRow]
        let flightCategory: String?  // Estimated category based on visibility/ceiling
        let cloudIcon: String        // SF Symbol for clouds

        init(header: String, headerColor: Color, rows: [TAFRow], flightCategory: String? = nil, cloudIcon: String = "cloud.fill") {
            self.header = header
            self.headerColor = headerColor
            self.rows = rows
            self.flightCategory = flightCategory
            self.cloudIcon = cloudIcon
        }
    }

    private struct TAFRow: Hashable {
        let label: String
        let value: String
    }

    /// Determine flight category and cloud icon from TAF segment content
    private func analyzeTAFSegment(_ segment: String) -> (category: String?, icon: String) {
        let upper = segment.uppercased()

        // Check for weather phenomena first
        if upper.contains("TS") {
            return ("IFR", "cloud.bolt.rain.fill")
        }
        if upper.contains("+RA") || upper.contains("TSRA") {
            return ("IFR", "cloud.heavyrain.fill")
        }
        if upper.contains("RA") || upper.contains("-RA") {
            return ("MVFR", "cloud.rain.fill")
        }
        if upper.contains("SN") || upper.contains("+SN") {
            return ("IFR", "cloud.snow.fill")
        }
        if upper.contains("FZRA") || upper.contains("FZDZ") {
            return ("LIFR", "cloud.sleet.fill")
        }
        if upper.contains("FG") {
            return ("LIFR", "cloud.fog.fill")
        }
        if upper.contains("BR") || upper.contains("HZ") {
            return ("MVFR", "cloud.fog.fill")
        }

        // Check visibility - FAA flight category thresholds:
        // LIFR: visibility < 1 SM
        // IFR: visibility 1 SM to < 3 SM
        // MVFR: visibility 3 SM to 5 SM
        // VFR: visibility > 5 SM
        if upper.contains("1/4SM") || upper.contains("1/2SM") || upper.contains("3/4SM") || upper.contains("0SM") {
            return ("LIFR", "cloud.fill")
        }
        // Use regex to match exactly 1SM or 2SM (IFR range: 1 to <3 SM)
        if let _ = upper.range(of: "\\b[12]SM\\b", options: .regularExpression) {
            return ("IFR", "cloud.fill")
        }
        // Also handle "1 1/2SM" type formats
        if upper.contains("1 1/2SM") || upper.contains("2 1/2SM") {
            return ("IFR", "cloud.fill")
        }
        // MVFR range: 3-5 SM
        if let _ = upper.range(of: "\\b[345]SM\\b", options: .regularExpression) {
            return ("MVFR", "cloud.fill")
        }

        // Check cloud cover - only BKN (broken) and OVC (overcast) count as ceilings
        // Flight category thresholds (in hundreds of feet, matching METAR format):
        // LIFR: ceiling < 500ft (height < 5)
        // IFR: ceiling 500-999ft (height 5-9)
        // MVFR: ceiling 1000-3000ft (height 10-30)
        // VFR: ceiling > 3000ft (height > 30)
        if upper.contains("OVC") {
            if let range = upper.range(of: "OVC\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                let heightStr = match.dropFirst(3)
                if let height = Int(heightStr) {
                    if height < 5 {
                        return ("LIFR", "cloud.fill")
                    } else if height < 10 {
                        return ("IFR", "cloud.fill")
                    } else if height <= 30 {
                        return ("MVFR", "cloud.fill")
                    }
                    // height > 30 means ceiling > 3000ft = VFR
                    return ("VFR", "cloud.fill")
                }
            }
            return ("MVFR", "cloud.fill")
        }
        if upper.contains("BKN") {
            if let range = upper.range(of: "BKN\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                let heightStr = match.dropFirst(3)
                if let height = Int(heightStr) {
                    if height < 5 {
                        return ("LIFR", "cloud.fill")
                    } else if height < 10 {
                        return ("IFR", "cloud.fill")
                    } else if height <= 30 {
                        return ("MVFR", "cloud.fill")
                    }
                    // height > 30 means ceiling > 3000ft = VFR
                    return ("VFR", "cloud.fill")
                }
            }
            return ("VFR", "cloud.fill")
        }
        if upper.contains("SCT") {
            return ("VFR", "cloud.sun.fill")
        }
        if upper.contains("FEW") {
            return ("VFR", "cloud.sun.fill")
        }
        if upper.contains("SKC") || upper.contains("CLR") || upper.contains("CAVOK") {
            return ("VFR", "sun.max.fill")
        }
        if upper.contains("P6SM") || upper.contains("9999") {
            return ("VFR", "cloud.sun.fill")
        }

        return (nil, "cloud.fill")
    }

    private func parseTAFGroups(_ rawTAF: String) -> [TAFGroup] {
        var groups: [TAFGroup] = []

        // Normalize TAF text
        let normalized = rawTAF
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        // Split by forecast groups
        let pattern = "(TAF\\s+\\w+|FM\\d+|TEMPO\\s+\\d+\\/\\d+|BECMG\\s+\\d+\\/\\d+|PROB\\d+\\s+\\d+\\/\\d+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        guard let matches = regex?.matches(in: normalized, options: [], range: NSRange(normalized.startIndex..., in: normalized)) else {
            let analysis = analyzeTAFSegment(normalized)
            return [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: analysis.category, cloudIcon: analysis.icon)]
        }

        var lastEnd = normalized.startIndex
        var segmentContents: [Int: String] = [:]  // Track segment content for analysis

        for match in matches {
            guard let range = Range(match.range, in: normalized) else { continue }

            if lastEnd < range.lowerBound {
                let segment = String(normalized[lastEnd..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !segment.isEmpty && !groups.isEmpty {
                    let existingContent = segmentContents[groups.count - 1] ?? ""
                    segmentContents[groups.count - 1] = existingContent + " " + segment
                    let analysis = analyzeTAFSegment(segmentContents[groups.count - 1] ?? segment)
                    groups[groups.count - 1] = TAFGroup(
                        header: groups[groups.count - 1].header,
                        headerColor: groups[groups.count - 1].headerColor,
                        rows: groups[groups.count - 1].rows + decodeTAFSegment(segment),
                        flightCategory: analysis.category,
                        cloudIcon: analysis.icon
                    )
                }
            }

            let matchText = String(normalized[range])
            let (header, color) = getTAFGroupHeader(matchText)
            groups.append(TAFGroup(header: header, headerColor: color, rows: []))
            segmentContents[groups.count - 1] = ""

            lastEnd = range.upperBound
        }

        if lastEnd < normalized.endIndex {
            let segment = String(normalized[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !segment.isEmpty && !groups.isEmpty {
                let analysis = analyzeTAFSegment(segment)
                groups[groups.count - 1] = TAFGroup(
                    header: groups[groups.count - 1].header,
                    headerColor: groups[groups.count - 1].headerColor,
                    rows: decodeTAFSegment(segment),
                    flightCategory: analysis.category,
                    cloudIcon: analysis.icon
                )
            }
        }

        let defaultAnalysis = analyzeTAFSegment(normalized)
        return groups.isEmpty ? [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: defaultAnalysis.category, cloudIcon: defaultAnalysis.icon)] : groups
    }

    private func getTAFGroupHeader(_ match: String) -> (String, Color) {
        if match.hasPrefix("TAF") {
            return ("Initial Forecast", .green)
        } else if match.hasPrefix("FM") {
            let digits = match.dropFirst(2)
            if digits.count >= 4 {
                let hour = String(digits.prefix(4).suffix(2))
                return ("From \(hour)00Z", .cyan)
            }
            return ("From", .cyan)
        } else if match.contains("TEMPO") {
            return ("Temporary", .orange)
        } else if match.contains("BECMG") {
            return ("Becoming", .yellow)
        } else if match.contains("PROB") {
            let prob = match.filter { $0.isNumber }
            return ("Probability \(prob)%", .purple)
        }
        return ("Forecast", .cyan)
    }

    private func decodeTAFSegment(_ segment: String) -> [TAFRow] {
        var decoded: [TAFRow] = []
        let parts = segment.components(separatedBy: " ").filter { !$0.isEmpty }

        for part in parts {
            if let row = decodeTAFElement(part) {
                decoded.append(row)
            }
        }

        return decoded
    }

    private func decodeTAFElement(_ element: String) -> TAFRow? {
        let upper = element.uppercased()

        // Skip airport identifiers and dates
        if upper.count == 4 && upper.first?.isLetter == true { return nil }
        if upper.contains("/") && upper.count == 9 { return nil }

        // Wind
        if upper.hasSuffix("KT") {
            let windPart = upper.dropLast(2)
            if windPart.count >= 5 {
                let dir = String(windPart.prefix(3))
                let remaining = windPart.dropFirst(3)

                if remaining.contains("G") {
                    let gustParts = remaining.components(separatedBy: "G")
                    if gustParts.count == 2 {
                        return TAFRow(label: "Wind", value: "\(dir)° at \(gustParts[0])kt gusting \(gustParts[1])kt")
                    }
                }
                return TAFRow(label: "Wind", value: "\(dir)° at \(remaining)kt")
            }
        }

        // Visibility
        if upper == "P6SM" || upper == "9999" {
            return TAFRow(label: "Visibility", value: "6+ SM")
        }
        if upper.hasSuffix("SM") {
            let vis = upper.dropLast(2)
            // Handle fractional visibility like "1/2SM" or "1 1/2SM"
            if vis.contains("/") {
                return TAFRow(label: "Visibility", value: "\(vis) SM")
            }
            return TAFRow(label: "Visibility", value: "\(vis) SM")
        }
        // Handle metric visibility (4-digit format like 0800, 1600, 9000)
        if upper.count == 4, let meters = Int(upper), meters > 0 && meters <= 9999 {
            // Convert meters to statute miles for US pilots
            let miles = Double(meters) / 1609.34
            if miles >= 6 {
                return TAFRow(label: "Visibility", value: "6+ SM")
            } else if miles >= 1 {
                return TAFRow(label: "Visibility", value: String(format: "%.0f SM", miles))
            } else {
                return TAFRow(label: "Visibility", value: String(format: "%.1f SM", miles))
            }
        }

        // Clouds
        if upper.hasPrefix("FEW") {
            let heightFt = (Int(upper.dropFirst(3)) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Few \(heightFt)'")
        }
        if upper.hasPrefix("SCT") {
            let heightFt = (Int(upper.dropFirst(3)) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Scattered \(heightFt)'")
        }
        if upper.hasPrefix("BKN") {
            let heightFt = (Int(upper.dropFirst(3)) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Broken \(heightFt)'")
        }
        if upper.hasPrefix("OVC") {
            let heightFt = (Int(upper.dropFirst(3)) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Overcast \(heightFt)'")
        }
        if upper == "SKC" || upper == "CLR" {
            return TAFRow(label: "Clouds", value: "Clear")
        }
        if upper.hasPrefix("VV") {
            let heightFt = (Int(upper.dropFirst(2)) ?? 0) * 100
            return TAFRow(label: "Visibility", value: "Vertical \(heightFt)'")
        }

        // Weather phenomena
        switch upper {
        case "RA": return TAFRow(label: "Weather", value: "Rain")
        case "-RA": return TAFRow(label: "Weather", value: "Light rain")
        case "+RA": return TAFRow(label: "Weather", value: "Heavy rain")
        case "SN": return TAFRow(label: "Weather", value: "Snow")
        case "-SN": return TAFRow(label: "Weather", value: "Light snow")
        case "+SN": return TAFRow(label: "Weather", value: "Heavy snow")
        case "TS": return TAFRow(label: "Weather", value: "Thunderstorm")
        case "TSRA": return TAFRow(label: "Weather", value: "Thunderstorm with rain")
        case "FG": return TAFRow(label: "Weather", value: "Fog")
        case "BR": return TAFRow(label: "Weather", value: "Mist")
        case "HZ": return TAFRow(label: "Weather", value: "Haze")
        case "FU": return TAFRow(label: "Weather", value: "Smoke")
        case "DZ": return TAFRow(label: "Weather", value: "Drizzle")
        case "FZRA": return TAFRow(label: "Weather", value: "Freezing rain")
        case "FZDZ": return TAFRow(label: "Weather", value: "Freezing drizzle")
        case "SH": return TAFRow(label: "Weather", value: "Showers")
        case "SHRA": return TAFRow(label: "Weather", value: "Rain showers")
        case "-SHRA": return TAFRow(label: "Weather", value: "Light rain showers")
        case "+SHRA": return TAFRow(label: "Weather", value: "Heavy rain showers")
        case "SHSN": return TAFRow(label: "Weather", value: "Snow showers")
        case "NSW": return TAFRow(label: "Weather", value: "No significant weather")
        case "CAVOK": return TAFRow(label: "Conditions", value: "Ceiling and visibility OK")
        default: return nil
        }
    }

    // MARK: - MOS View
    private var mosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Model Output Statistics (GFS)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingMOS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let forecasts = mosData[currentAirport], !forecasts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(forecasts.prefix(12))) { forecast in
                            mosRowCard(forecast)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(minHeight: 250)
            } else if isLoadingMOS {
                loadingView
            } else {
                noDataView("No MOS data available for \(currentAirport)")
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            loadMOSData()
        }
    }

    // MARK: - MOS Row Card (ForeFlight-style table layout)
    private func mosRowCard(_ forecast: MOSForecast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with time and cloud icon
            HStack(spacing: 8) {
                Image(systemName: mosCloudIcon(forecast))
                    .font(.system(size: 16))
                    .foregroundColor(mosIconColor(forecast))
                    .symbolRenderingMode(.multicolor)

                Text(mosTimeHeader(forecast))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)

                Spacer()

                // Precip probability badge if significant
                if let pop = forecast.p06 ?? forecast.p12, pop >= 30 {
                    Text("\(pop)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pop >= 70 ? Color.blue : Color.blue.opacity(0.6))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)

            // Table rows
            if let tmp = forecast.tmp, let dpt = forecast.dpt {
                mosTableRow(label: "Temperature", value: "\(tmp)°F / \(dpt)°F dew")
            } else if let tmp = forecast.tmp {
                mosTableRow(label: "Temperature", value: "\(tmp)°F")
            }

            if let wdr = forecast.windDirectionDegrees, let wsp = forecast.wsp {
                let windStr = wsp == 0 ? "Calm" : "\(String(format: "%03d", wdr))° at \(wsp)kt"
                mosTableRow(label: "Wind", value: windStr)
            }

            mosTableRow(label: "Sky", value: forecast.cloudCoverDescription)

            if let pop = forecast.p06 ?? forecast.p12, pop > 0 {
                mosTableRow(label: "Precip", value: "\(pop)% chance")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    /// Get cloud icon based on MOS cloud cover and precipitation
    private func mosCloudIcon(_ forecast: MOSForecast) -> String {
        // Check for precipitation first
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            if forecast.pos ?? 0 >= 30 {
                return "cloud.snow.fill"
            }
            return "cloud.rain.fill"
        }

        // Then check obstruction to vision
        if let obv = forecast.obv?.uppercased() {
            if obv.contains("FG") { return "cloud.fog.fill" }
            if obv.contains("HZ") || obv.contains("BR") { return "cloud.fog.fill" }
        }

        // Finally check cloud cover
        switch forecast.cld?.uppercased() {
        case "CL": return "sun.max.fill"
        case "FW": return "cloud.sun.fill"
        case "SC": return "cloud.sun.fill"
        case "BK": return "cloud.fill"
        case "OV": return "cloud.fill"
        default: return "cloud.fill"
        }
    }

    /// Get icon color based on MOS conditions
    private func mosIconColor(_ forecast: MOSForecast) -> Color {
        // Check for precipitation
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            return .blue
        }

        // Check obstruction to vision
        if let obv = forecast.obv?.uppercased(), obv.contains("FG") {
            return .gray
        }

        // Check cloud cover
        switch forecast.cld?.uppercased() {
        case "CL": return .yellow
        case "FW", "SC": return .cyan
        case "BK", "OV": return .gray
        default: return .gray
        }
    }

    private func mosTimeHeader(_ forecast: MOSForecast) -> String {
        guard let date = forecast.forecastTime else { return forecast.forecastHourString }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func mosTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    // MARK: - Load MOS Data
    private func loadMOSData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard mosData[currentAirport] == nil else { return }  // Already have data

        isLoadingMOS = true

        Task {
            do {
                let forecasts = try await weatherService.fetchMOS(for: currentAirport)
                await MainActor.run {
                    mosData[currentAirport] = forecasts
                    isLoadingMOS = false
                }
            } catch {
                print("❌ Failed to fetch MOS for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingMOS = false
                }
            }
        }
    }

    // MARK: - Daily Forecast View
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("7-Day Forecast")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingDaily {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if !dailyForecastData.isEmpty {
                // Forecast rows
                ForEach(dailyForecastData.prefix(10)) { forecast in
                    dailyForecastRow(forecast)
                }
            } else if isLoadingDaily {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No forecast data available")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Requires airport coordinates")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            loadDailyForecast()
        }
    }

    // MARK: - Daily Forecast Row
    private func dailyForecastRow(_ forecast: DailyForecastData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Day name
                Text(forecast.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)

                // Weather icon with appropriate coloring
                Image(systemName: forecast.icon)
                    .font(.system(size: 16))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(dailyForecastColor(for: forecast))
                    .frame(width: 24)

                // Short forecast
                Text(forecast.shortForecast)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Temperature - orange for highs (daytime), cyan for lows (nighttime)
                if let high = forecast.highTemp {
                    Text("\(high)°")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                } else if let low = forecast.lowTemp {
                    Text("\(low)°")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // Precip chance
                if let precip = forecast.precipChance, precip > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                        Text("\(precip)%")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(precip > 50 ? .blue : .gray)
                    .frame(width: 40, alignment: .trailing)
                } else {
                    Text("")
                        .frame(width: 40)
                }
            }

            // Wind info row (if available)
            if let windString = forecast.windString {
                HStack(spacing: 4) {
                    Spacer()
                        .frame(width: 80)  // Match day name width
                    Image(systemName: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(windString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func dailyForecastColor(for forecast: DailyForecastData) -> Color {
        let text = forecast.shortForecast.lowercased()
        let icon = forecast.icon.lowercased()

        // Thunderstorms - purple
        if text.contains("thunder") || icon.contains("bolt") {
            return .purple
        }

        // Rain - blue
        if text.contains("rain") || text.contains("shower") || icon.contains("rain") {
            return .blue
        }

        // Snow/Ice - cyan
        if text.contains("snow") || text.contains("ice") || text.contains("sleet") || icon.contains("snow") {
            return .cyan
        }

        // Fog/Haze - gray
        if text.contains("fog") || text.contains("haze") || text.contains("mist") || icon.contains("fog") {
            return .gray
        }

        // Cloudy - light gray
        if text.contains("cloudy") || text.contains("overcast") || icon.contains("cloud") {
            return Color.gray.opacity(0.8)
        }

        // Sunny/Clear - yellow/orange
        if text.contains("sunny") || text.contains("clear") || icon.contains("sun") {
            return .yellow
        }

        // Night/Moon - light blue
        if icon.contains("moon") {
            return Color.blue.opacity(0.7)
        }

        // Default
        return .cyan
    }

    // MARK: - Load Daily Forecast
    private func loadDailyForecast() {
        guard !isLoadingDaily else { return }
        guard dailyForecastData.isEmpty else { return }  // Already have data

        // Get airport coordinates from database
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }

        // Look up airport coordinates
        if let airport = AirportDatabaseManager.shared.getAirport(for: currentAirport) {
            isLoadingDaily = true

            Task {
                do {
                    let forecasts = try await weatherService.fetchDailyForecast(
                        latitude: airport.coordinate.latitude,
                        longitude: airport.coordinate.longitude
                    )
                    await MainActor.run {
                        dailyForecastData = forecasts
                        isLoadingDaily = false
                    }
                } catch {
                    print("❌ Failed to fetch daily forecast: \(error)")
                    await MainActor.run {
                        isLoadingDaily = false
                    }
                }
            }
        }
    }

    // MARK: - Winds Aloft View
    private var windsAloftView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - show source station if different from requested airport
            HStack {
                if let winds = windsAloftData[currentAirport],
                   let firstWind = winds.first,
                   let sourceStation = firstWind.sourceStation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Winds Aloft - \(currentAirport)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("(from \(sourceStation))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Winds Aloft - \(currentAirport)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                if isLoadingWinds {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let winds = windsAloftData[currentAirport], !winds.isEmpty {
                // Table header
                HStack(spacing: 0) {
                    Text("Altitude")
                        .frame(width: 70, alignment: .leading)
                    Text("Wind")
                        .frame(width: 80, alignment: .center)
                    Text("Temp")
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)

                // Wind rows
                ForEach(winds) { wind in
                    windsAloftRow(wind)
                }
            } else if isLoadingWinds {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No winds aloft data for \(currentAirport)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Winds aloft uses limited reporting stations")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
        .onAppear {
            loadWindsAloftData()
        }
    }

    // MARK: - Weather Images View
    private var weatherImagesView: some View {
        WeatherImagesTabView(routeAirports: routeAirports)
    }

    // MARK: - Winds Aloft Row
    private func windsAloftRow(_ wind: WindsAloftData) -> some View {
        HStack(spacing: 0) {
            // Altitude
            Text("\(wind.altitude)'")
                .frame(width: 70, alignment: .leading)
                .foregroundColor(.white)

            // Wind direction and speed
            Text(wind.windString)
                .frame(width: 80, alignment: .center)
                .foregroundColor(.cyan)

            // Temperature (if available)
            if let temp = wind.temperature {
                Text("\(temp)°C")
                    .frame(width: 50, alignment: .trailing)
                    .foregroundColor(temp < 0 ? .cyan : .orange)
            } else {
                Text("--")
                    .frame(width: 50, alignment: .trailing)
                    .foregroundColor(.gray)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Load Winds Aloft Data
    private func loadWindsAloftData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard windsAloftData[currentAirport] == nil else { return }  // Already have data

        isLoadingWinds = true

        Task {
            do {
                let winds = try await weatherService.fetchWindsAloft(for: currentAirport)
                await MainActor.run {
                    windsAloftData[currentAirport] = winds
                    isLoadingWinds = false
                }
            } catch {
                print("❌ Failed to fetch winds aloft for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingWinds = false
                }
            }
        }
    }

    // MARK: - Route Weather Summary
    private var routeWeatherSummary: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.2))

            Text("Route Weather Summary")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            ForEach(routeAirports, id: \.self) { airport in
                routeSummaryRow(for: airport)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button {
            loadAllWeather(forceRefresh: true)
        } label: {
            HStack {
                Image(systemName: isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                Text("Refresh All")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(LogbookTheme.accentBlue)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(LogbookTheme.accentBlue.opacity(0.15))
            .cornerRadius(8)
        }
        .disabled(isLoading)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No Active Trip")
                .font(.headline)
                .foregroundColor(.white)

            Text("Create a trip with flight legs to see route weather")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading weather data...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - No Data View
    private func noDataView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - Helper: Format Cloud Layers
    private func formatCloudLayers(_ clouds: String) -> String {
        // Parse cloud string like "SCT130 BKN160 BKN250" or "VV002" into readable format
        let layers = clouds.components(separatedBy: " ")
        var formatted: [String] = []

        for layer in layers {
            let upper = layer.uppercased()
            var cover = ""
            var altitude = ""

            if upper.hasPrefix("SKC") || upper.hasPrefix("CLR") || upper == "CAVOK" {
                return "Clear"
            } else if upper.hasPrefix("VV") {
                // Vertical Visibility (indefinite ceiling, typically fog)
                altitude = String(upper.dropFirst(2))
                if let altNum = Int(altitude) {
                    formatted.append("Vertical Vis \(altNum * 100)'")
                }
                continue
            } else if upper.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(upper.dropFirst(3))
            }

            // Handle altitude with possible CB/TCU suffix (e.g., "025CB")
            let altDigits = altitude.prefix(while: { $0.isNumber })
            if let altNum = Int(altDigits), !cover.isEmpty {
                formatted.append("\(cover) \(altNum * 100)'")
            }
        }

        return formatted.isEmpty ? clouds : formatted.joined(separator: "\n")
    }

    // MARK: - Helper: Parse Clouds from Raw METAR
    private func parseCloudsFromRawMetar(_ rawMetar: String) -> String? {
        // Parse cloud layers directly from raw METAR text
        // Format: "Scattered 900'" on line 1, "Broken 1,700'" on line 2, etc.
        let components = rawMetar.uppercased().components(separatedBy: " ")
        var cloudLayers: [(altitude: Int, description: String)] = []

        for component in components {
            if component == "SKC" || component == "CLR" || component == "CAVOK" {
                return "Clear"
            } else if component.hasPrefix("VV") {
                let altitude = String(component.dropFirst(2))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Vertical Vis \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("FEW") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Few \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("SCT") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Scattered \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("BKN") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Broken \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("OVC") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Overcast \(formatAltitude(altNum * 100))"))
                }
            }
        }

        // Sort by altitude (lowest first) and join with newlines
        let sorted = cloudLayers.sorted { $0.altitude < $1.altitude }
        return sorted.isEmpty ? nil : sorted.map { $0.description }.joined(separator: "\n")
    }

    // Format altitude with comma for thousands (e.g., 1,700')
    private func formatAltitude(_ feet: Int) -> String {
        if feet >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: feet)) ?? "\(feet)")'"
        }
        return "\(feet)'"
    }

    // MARK: - Helper: Parse RVR (Runway Visual Range) from raw METAR
    private func parseRVR(from rawMetar: String) -> String? {
        // RVR format: R09R/5500VP6000FT or R09L/2000V4000FT
        let pattern = "R(\\d{2}[LRC]?)/([\\dPM]+)(?:V([\\dPM]+))?FT"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let range = NSRange(rawMetar.startIndex..., in: rawMetar)
        let matches = regex.matches(in: rawMetar, options: [], range: range)

        guard !matches.isEmpty else { return nil }

        var rvrStrings: [String] = []
        for match in matches {
            guard let runwayRange = Range(match.range(at: 1), in: rawMetar),
                  let valueRange = Range(match.range(at: 2), in: rawMetar) else { continue }

            let runway = String(rawMetar[runwayRange])
            let value1 = String(rawMetar[valueRange])

            var rvrValue = ""
            if match.range(at: 3).location != NSNotFound,
               let value2Range = Range(match.range(at: 3), in: rawMetar) {
                let value2 = String(rawMetar[value2Range])
                rvrValue = "Rwy \(runway): \(formatRVRValue(value1))' to \(formatRVRValue(value2))'"
            } else {
                rvrValue = "Rwy \(runway): \(formatRVRValue(value1))'"
            }
            rvrStrings.append(rvrValue)
        }

        return rvrStrings.isEmpty ? nil : rvrStrings.joined(separator: "\n")
    }

    private func formatRVRValue(_ value: String) -> String {
        // Handle P (plus/greater than) and M (minus/less than) prefixes
        if value.hasPrefix("P") {
            return ">\(value.dropFirst())"
        } else if value.hasPrefix("M") {
            return "<\(value.dropFirst())"
        }
        return value
    }

    // MARK: - Helper: Format Weather Phenomena
    private func formatWeatherPhenomena(_ wxString: String) -> String {
        // Parse weather phenomena codes from wxString
        let codes = wxString.components(separatedBy: " ")
        var phenomena: [String] = []

        for code in codes {
            if let description = decodeWeatherPhenomenon(code) {
                phenomena.append(description)
            }
        }

        return phenomena.isEmpty ? wxString : phenomena.joined(separator: "\n")
    }

    private func decodeWeatherPhenomenon(_ code: String) -> String? {
        // Intensity prefixes
        var intensity = ""
        var workingCode = code

        if workingCode.hasPrefix("-") {
            intensity = "Light "
            workingCode = String(workingCode.dropFirst())
        } else if workingCode.hasPrefix("+") {
            intensity = "Heavy "
            workingCode = String(workingCode.dropFirst())
        } else if workingCode.hasPrefix("VC") {
            intensity = "Vicinity "
            workingCode = String(workingCode.dropFirst(2))
        }

        // Weather phenomena codes
        let phenomenaMap: [String: String] = [
            // Precipitation
            "RA": "Rain",
            "SN": "Snow",
            "DZ": "Drizzle",
            "PL": "Ice Pellets",
            "GR": "Hail",
            "GS": "Small Hail",
            "SG": "Snow Grains",
            "IC": "Ice Crystals",
            "UP": "Unknown Precip",
            // Obscurations
            "FG": "Fog",
            "BR": "Mist",
            "HZ": "Haze",
            "FU": "Smoke",
            "SA": "Sand",
            "DU": "Dust",
            "VA": "Volcanic Ash",
            "PY": "Spray",
            // Other
            "TS": "Thunderstorm",
            "SQ": "Squall",
            "FC": "Funnel Cloud",
            "SS": "Sandstorm",
            "DS": "Duststorm",
            "PO": "Dust Devils",
            "SH": "Showers",
            "BLSN": "Blowing Snow",
            "BLDU": "Blowing Dust",
            "BLSA": "Blowing Sand",
            "DRSN": "Drifting Snow",
            "DRDU": "Drifting Dust",
            "DRSA": "Drifting Sand",
            "FZRA": "Freezing Rain",
            "FZDZ": "Freezing Drizzle",
            "FZFG": "Freezing Fog",
            "TSRA": "Thunderstorm Rain",
            "TSSN": "Thunderstorm Snow",
            "SHRA": "Rain Showers",
            "SHSN": "Snow Showers",
            "SHGR": "Hail Showers",
            "PRFG": "Partial Fog",
            "BCFG": "Patches of Fog",
            "MIFG": "Shallow Fog",
        ]

        // Try compound codes first (like FZRA, TSRA)
        if let description = phenomenaMap[workingCode] {
            return intensity + description
        }

        // Try parsing as combination (e.g., "RABR" = Rain + Mist)
        var parts: [String] = []
        var remaining = workingCode
        while !remaining.isEmpty {
            var found = false
            // Try 4-char codes first, then 2-char
            for length in [4, 2] {
                if remaining.count >= length {
                    let prefix = String(remaining.prefix(length))
                    if let desc = phenomenaMap[prefix] {
                        parts.append(desc)
                        remaining = String(remaining.dropFirst(length))
                        found = true
                        break
                    }
                }
            }
            if !found { break }
        }

        if !parts.isEmpty {
            return intensity + parts.joined(separator: ", ")
        }

        return nil
    }

    // MARK: - Helper: Calculate Density Altitude
    private func calculateDensityAltitude(temp: Double, altimeter: Double, elevation: Int) -> Int {
        let pressureAlt = (29.92 - altimeter) * 1000 + Double(elevation)
        let isaTemp = 15 - (Double(elevation) / 1000 * 2)
        let tempDev = temp - isaTemp
        return Int(pressureAlt + (120 * tempDev))
    }

    // MARK: - Load TAF Data
    private func loadTAFData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard tafData[currentAirport] == nil else { return }  // Already have data

        Task {
            do {
                let taf = try await weatherService.fetchTAF(for: currentAirport)
                await MainActor.run {
                    tafData[currentAirport] = taf
                }
            } catch {
                print("❌ Failed to fetch TAF for \(currentAirport): \(error)")
            }
        }
    }
    
    // MARK: - Route Summary Row
    private func routeSummaryRow(for airport: String) -> some View {
        Button {
            if let index = routeAirports.firstIndex(of: airport) {
                withAnimation {
                    selectedAirportIndex = index
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Airport code
                Text(airport)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(airport == currentAirport ? LogbookTheme.accentBlue : .white)
                    .frame(width: 50, alignment: .leading)
                
                // Category badge
                if let weather = weatherData[airport], let category = weather.flightCategory {
                    categoryBadge(category)
                }
                
                Spacer()
                
                // Quick info
                if let weather = weatherData[airport] {
                    HStack(spacing: 8) {
                        if let tempStr = weather.temperature(useCelsius: settingsStore.useCelsius) {
                            Text(tempStr)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        
                        Text(windString(for: weather))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(airport == currentAirport ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Visibility String Helper
    private func visibilityString(for vis: Double) -> String {
        if vis >= 10 { return "10+" }
        if vis >= 6 { return "6+" }

        // Convert to fractions for common aviation visibility values
        let tolerance = 0.01
        if abs(vis - 0.25) < tolerance { return "¼" }
        if abs(vis - 0.5) < tolerance { return "½" }
        if abs(vis - 0.75) < tolerance { return "¾" }
        if abs(vis - 1.0) < tolerance { return "1" }
        if abs(vis - 1.25) < tolerance { return "1¼" }
        if abs(vis - 1.5) < tolerance { return "1½" }
        if abs(vis - 1.75) < tolerance { return "1¾" }
        if abs(vis - 2.0) < tolerance { return "2" }
        if abs(vis - 2.5) < tolerance { return "2½" }
        if abs(vis - 3.0) < tolerance { return "3" }
        if abs(vis - 4.0) < tolerance { return "4" }
        if abs(vis - 5.0) < tolerance { return "5" }

        // For other values, show decimal but prefer whole numbers
        if vis == floor(vis) {
            return String(format: "%.0f", vis)
        }
        return String(format: "%.1f", vis)
    }
    
    // MARK: - Weather Detail Row
    private func weatherDetailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    private func categoryColor(_ category: String?) -> Color {
        guard let category = category else { return .gray }
        switch category {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return Color(red: 1.0, green: 0.0, blue: 1.0)  // Magenta
        default: return .gray
        }
    }

    // MARK: - Load All Weather
    private func loadAllWeather(forceRefresh: Bool = false) {
        guard !routeAirports.isEmpty else {
            print("🌤️ No route airports to fetch weather for")
            return
        }
        
        guard !isLoading else { return }
        
        print("🌤️ Loading weather for route: \(routeAirports.joined(separator: ", "))")
        
        isLoading = true
        
        Task {
            // Fetch weather for all airports in parallel
            for airport in routeAirports {
                do {
                    let weather = try await weatherService.fetchMETAR(for: airport)
                    await MainActor.run {
                        weatherData[airport] = weather
                    }
                } catch {
                    print("❌ Failed to fetch weather for \(airport): \(error)")
                }
            }
            
            await MainActor.run {
                isLoading = false
                print("✅ Weather loaded for \(weatherData.count)/\(routeAirports.count) airports")
            }
        }
    }
    
    // MARK: - Load Runway Data
    private func loadRunwayDataIfNeeded() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        
        // Check if we already have runway data cached
        if weatherService.cachedRunways[currentAirport] != nil {
            print("✅ Runway data already cached for \(currentAirport)")
            return
        }
        
        // Check if we're already fetching
        if weatherService.runwaysFetchingStatus[currentAirport] == true {
            print("⏳ Already fetching runway data for \(currentAirport)")
            return
        }
        
        print("🛫 Loading runway data for \(currentAirport)")
        isLoadingRunways = true
        
        Task {
            await MainActor.run {
                weatherService.runwaysFetchingStatus[currentAirport] = true
            }
            
            do {
                let runways = try await weatherService.fetchRunways(for: currentAirport)
                await MainActor.run {
                    print("✅ Loaded \(runways.count) runways for \(currentAirport)")
                    weatherService.runwaysFetchingStatus[currentAirport] = false
                    isLoadingRunways = false
                }
            } catch {
                print("❌ Failed to load runway data for \(currentAirport): \(error)")
                await MainActor.run {
                    weatherService.runwaysFetchingStatus[currentAirport] = false
                    isLoadingRunways = false
                }
            }
        }
    }
}

// MARK: - Compact Runway Wind Widget (For METAR View)
struct CompactRunwayWind: View {
    let windDirection: Int
    let windSpeed: Int
    let runways: [String] // e.g., ["09", "27", "15", "33"]
    
    @State private var selectedRunwayIndex: Int = 0
    
    private var currentRunway: String {
        runways.isEmpty ? "09" : runways[selectedRunwayIndex]
    }
    
    private var runwayHeading: Double {
        // Handle runway identifiers with L/R/C suffixes
        let cleanRunway = currentRunway.filter { $0.isNumber }
        guard let num = Int(cleanRunway) else { return 90 }
        return Double(num * 10)
    }
    
    // Wind component calculations
    private var headwindComponent: Double {
        let angleDiff = Double(windDirection) - runwayHeading
        let angleRad = angleDiff * .pi / 180.0
        return Double(windSpeed) * cos(angleRad)
    }
    
    private var crosswindComponent: Double {
        let angleDiff = Double(windDirection) - runwayHeading
        let angleRad = angleDiff * .pi / 180.0
        return Double(windSpeed) * sin(angleRad)
    }
    
    private var favorabilityColor: Color {
        let xw = abs(crosswindComponent)
        if xw <= 5 { return .green }
        else if xw <= 10 { return .yellow }
        else if xw <= 15 { return .orange }
        else { return .red }
    }
    
    // Format runway number - drop leading zero (05 -> 5)
    private var formattedRunwayNumber: String {
        let cleanRunway = currentRunway.filter { $0.isNumber || $0 == "L" || $0 == "R" || $0 == "C" }
        // Remove leading zero from numbers
        if let firstChar = cleanRunway.first, firstChar == "0" {
            return String(cleanRunway.dropFirst())
        }
        return cleanRunway
    }

    var body: some View {
        VStack(spacing: 8) {
            // Wind components at top
            VStack(spacing: 6) {
                // Crosswind (primary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10))
                        .foregroundColor(favorabilityColor)

                    Text("\(Int(abs(crosswindComponent)))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(favorabilityColor)

                    Text("kt")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Text("X-WIND")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)

                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 8)

                // Headwind (secondary)
                HStack(spacing: 4) {
                    Image(systemName: headwindComponent >= 0 ? "arrow.down" : "arrow.up")
                        .font(.system(size: 8))
                        .foregroundColor(headwindComponent >= 0 ? .green : .red)

                    Text("\(Int(abs(headwindComponent)))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(headwindComponent >= 0 ? "HEAD" : "TAIL")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }

            // Runway number at bottom (approach end) with cycle buttons
            HStack(spacing: 4) {
                Button(action: previousRunway) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text("RWY \(formattedRunwayNumber)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Button(action: nextRunway) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(favorabilityColor, lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    private func nextRunway() {
        guard !runways.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedRunwayIndex = (selectedRunwayIndex + 1) % runways.count
        }
    }
    
    private func previousRunway() {
        guard !runways.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedRunwayIndex = (selectedRunwayIndex - 1 + runways.count) % runways.count
        }
    }
}

// MARK: - Weather Detail Sheet (Half-Sheet Presentation)
struct WeatherDetailSheet: View {
    @Binding var routeAirports: [String]
    @Binding var selectedAirportIndex: Int
    @Binding var weatherData: [String: RawMETAR]
    @Binding var tafData: [String: RawTAF]
    @Binding var mosData: [String: [MOSForecast]]
    @Binding var windsAloftData: [String: [WindsAloftData]]
    @Binding var dailyForecastData: [DailyForecastData]
    @Binding var datisData: [String: DATISData]

    @ObservedObject var weatherService: BannerWeatherService
    @ObservedObject var settingsStore: NOCSettingsStore

    var onRefresh: () -> Void

    @State private var selectedWeatherTab: WeatherDisplayTab = .metar
    @State private var isLoadingRunways = false
    @State private var isLoadingMOS = false
    @State private var isLoadingWinds = false
    @State private var isLoadingDaily = false
    @State private var isLoadingDATIS = false
    @State private var isLoadingTAF = false
    @State private var showAddAirportAlert = false
    @State private var newAirportCode = ""
    @State private var selectedRunwayIndex = 0
    @Environment(\.dismiss) private var dismiss

    private var currentAirport: String {
        guard !routeAirports.isEmpty, selectedAirportIndex < routeAirports.count else {
            return "----"
        }
        return routeAirports[selectedAirportIndex]
    }

    private var currentWeather: RawMETAR? {
        return weatherData[currentAirport]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Airport Selector (always show - allows adding airports)
                airportSelector

                // Weather Tab Selector
                weatherTabSelector

                Divider()
                    .background(Color.white.opacity(0.2))

                // Tab Content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedWeatherTab {
                        case .metar:
                            enhancedMETARView
                        case .datis:
                            datisView
                        case .taf:
                            tafView
                        case .mos:
                            mosView
                        case .daily:
                            dailyForecastView
                        case .winds:
                            windsAloftView
                        case .images:
                            weatherImagesView
                        }
                    }
                }
            }
            .background(LogbookTheme.navyLight)
            .navigationTitle(currentAirport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
        }
        .onAppear {
            loadDataForCurrentTab()
        }
        .onChange(of: selectedWeatherTab) { _, _ in
            loadDataForCurrentTab()
        }
        .onChange(of: selectedAirportIndex) { _, _ in
            // Clear daily forecast cache when airport changes (it's location-specific)
            dailyForecastData = []
            loadDataForCurrentTab()
        }
    }

    // MARK: - Airport Selector
    private var airportSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(routeAirports.enumerated()), id: \.offset) { index, airport in
                    Button {
                        withAnimation {
                            selectedAirportIndex = index
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(airport)
                                .font(.system(size: 14, weight: selectedAirportIndex == index ? .bold : .medium, design: .monospaced))
                                .foregroundColor(selectedAirportIndex == index ? .white : .gray)

                            if let weather = weatherData[airport], let category = weather.flightCategory {
                                Circle()
                                    .fill(categoryColor(category))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedAirportIndex == index ? Color.white.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                }

                // Add Airport Button
                Button {
                    newAirportCode = ""
                    showAddAirportAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LogbookTheme.accentGreen.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(LogbookTheme.navyDark)
        .alert("Add Airport", isPresented: $showAddAirportAlert) {
            TextField("ICAO Code (e.g. KJFK)", text: $newAirportCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                addAirport()
            }
        } message: {
            Text("Enter an ICAO airport code to check weather")
        }
    }

    // MARK: - Add Airport
    private func addAirport() {
        let code = newAirportCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 3, code.count <= 4 else { return }

        // Don't add duplicates
        if routeAirports.contains(code) {
            // Just select the existing one
            if let index = routeAirports.firstIndex(of: code) {
                withAnimation {
                    selectedAirportIndex = index
                }
            }
            return
        }

        // Add the new airport and select it
        routeAirports.append(code)
        withAnimation {
            selectedAirportIndex = routeAirports.count - 1
        }

        // Fetch METAR and Runway data for the new airport
        Task {
            // Fetch METAR
            do {
                let metar = try await weatherService.fetchMETAR(for: code)
                await MainActor.run {
                    weatherData[code] = metar
                }
            } catch {
                print("⚠️ Failed to fetch METAR for \(code): \(error)")
            }

            // Fetch Runways
            do {
                let runways = try await weatherService.fetchRunways(for: code)
                print("✅ Loaded \(runways.count) runways for added airport \(code)")
            } catch {
                print("⚠️ Failed to fetch runways for \(code): \(error)")
            }
        }
    }

    // MARK: - Weather Tab Selector
    private var weatherTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(WeatherDisplayTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeatherTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedWeatherTab == tab ? .bold : .medium))
                                .foregroundColor(selectedWeatherTab == tab ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                            Rectangle()
                                .fill(selectedWeatherTab == tab ? LogbookTheme.accentGreen : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(LogbookTheme.navyLight)
    }

    // MARK: - Enhanced METAR View
    private var enhancedMETARView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weather = currentWeather {
                // Flight Category Header
                HStack {
                    if let category = weather.flightCategory {
                        flightCategoryBadge(category)
                    }

                    Spacer()

                    Text(weather.timeAgo)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(timeAgeColor(weather))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timeAgeColor(weather).opacity(0.2))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Raw METAR
                Text(weather.rawOb)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor(weather.flightCategory))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)

                // Parsed Weather Data
                parsedWeatherTable(weather)
                    .padding(.horizontal, 12)

                // Runway Analysis
                runwayAnalysisSection(weather)

            } else {
                noDataView("No METAR data available")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - D-ATIS View
    private var datisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Digital ATIS - \(currentAirport)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if let datis = datisData[currentAirport], let letter = datis.informationLetter {
                    Text("INFO \(letter)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                }

                if isLoadingDATIS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let datis = datisData[currentAirport] {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let arrivalATIS = datis.arrivalATIS {
                            atisSection(type: "ARRIVAL", icon: "airplane.arrival", color: .cyan, text: arrivalATIS)
                        }

                        if let departureATIS = datis.departureATIS, departureATIS != datis.arrivalATIS {
                            atisSection(type: "DEPARTURE", icon: "airplane.departure", color: .orange, text: departureATIS)
                        }

                        if datis.arrivalATIS == nil && datis.departureATIS == nil,
                           let combinedATIS = datis.combinedATIS {
                            atisSection(type: "ATIS", icon: "airplane", color: .green, text: combinedATIS)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingDATIS {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No D-ATIS available for \(currentAirport)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("D-ATIS is typically available at major airports")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
    }

    private func atisSection(type: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(type)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }

    // MARK: - TAF View
    @State private var showDecodedTAF = false

    private var tafView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let taf = tafData[currentAirport] {
                HStack {
                    Text("Terminal Aerodrome Forecast")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if let issueTime = taf.issueTimeString {
                        Text(issueTime)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Toggle between raw and decoded
                HStack {
                    Button(action: { showDecodedTAF = false }) {
                        Text("Raw")
                            .font(.system(size: 12, weight: showDecodedTAF ? .regular : .bold))
                            .foregroundColor(showDecodedTAF ? .gray : .cyan)
                    }

                    Text("|")
                        .foregroundColor(.gray)

                    Button(action: { showDecodedTAF = true }) {
                        Text("Decoded")
                            .font(.system(size: 12, weight: showDecodedTAF ? .bold : .regular))
                            .foregroundColor(showDecodedTAF ? .cyan : .gray)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)

                if showDecodedTAF {
                    decodedTAFView(taf.rawTAF)
                } else {
                    Text(taf.rawTAF)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                }

            } else if isLoadingTAF {
                loadingView
            } else {
                noDataView("No TAF available for \(currentAirport)")
            }
        }
        .padding(.bottom, 12)
    }

    private func decodedTAFView(_ rawTAF: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Raw TAF at top (colored by estimated flight category)
                let groups = parseTAFGroups(rawTAF)
                let overallCategory = groups.first?.flightCategory

                Text(rawTAF)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor(overallCategory))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)

                // Decoded groups
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 4) {
                        // Group header with cloud icon and flight category
                        HStack(spacing: 8) {
                            Image(systemName: group.cloudIcon)
                                .font(.system(size: 16))
                                .foregroundColor(categoryColor(group.flightCategory))
                                .symbolRenderingMode(.multicolor)

                            Text(group.header)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(group.headerColor)

                            Spacer()

                            if let category = group.flightCategory {
                                Text(category)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor(category))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.bottom, 4)

                        // Table rows for this group (colored by flight category)
                        ForEach(group.rows, id: \.label) { row in
                            tafTableRow(label: row.label, value: row.value, category: group.flightCategory)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(minHeight: 150)
    }

    private func tafTableRow(label: String, value: String, category: String? = nil) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap (colored by category)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(categoryColor(category))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    private struct TAFGroup {
        let header: String
        let headerColor: Color
        let rows: [TAFRow]
        let flightCategory: String?
        let cloudIcon: String

        init(header: String, headerColor: Color, rows: [TAFRow], flightCategory: String? = nil, cloudIcon: String = "cloud.fill") {
            self.header = header
            self.headerColor = headerColor
            self.rows = rows
            self.flightCategory = flightCategory
            self.cloudIcon = cloudIcon
        }
    }

    private struct TAFRow: Hashable {
        let label: String
        let value: String
    }

    /// Determine flight category and cloud icon from TAF segment content
    private func analyzeTAFSegment(_ segment: String) -> (category: String?, icon: String) {
        let upper = segment.uppercased()

        if upper.contains("TS") { return ("IFR", "cloud.bolt.rain.fill") }
        if upper.contains("+RA") || upper.contains("TSRA") { return ("IFR", "cloud.heavyrain.fill") }
        if upper.contains("RA") || upper.contains("-RA") { return ("MVFR", "cloud.rain.fill") }
        if upper.contains("SN") || upper.contains("+SN") { return ("IFR", "cloud.snow.fill") }
        if upper.contains("FZRA") || upper.contains("FZDZ") { return ("LIFR", "cloud.sleet.fill") }
        if upper.contains("FG") { return ("LIFR", "cloud.fog.fill") }
        if upper.contains("BR") || upper.contains("HZ") { return ("MVFR", "cloud.fog.fill") }
        // Check visibility - FAA flight category thresholds:
        // LIFR: visibility < 1 SM
        // IFR: visibility 1 SM to < 3 SM
        // MVFR: visibility 3 SM to 5 SM
        // VFR: visibility > 5 SM
        if upper.contains("1/4SM") || upper.contains("1/2SM") || upper.contains("3/4SM") || upper.contains("0SM") { return ("LIFR", "cloud.fill") }
        // Use regex to match exactly 1SM or 2SM (IFR range: 1 to <3 SM)
        if let _ = upper.range(of: "\\b[12]SM\\b", options: .regularExpression) { return ("IFR", "cloud.fill") }
        // Also handle "1 1/2SM" type formats
        if upper.contains("1 1/2SM") || upper.contains("2 1/2SM") { return ("IFR", "cloud.fill") }
        // MVFR range: 3-5 SM
        if let _ = upper.range(of: "\\b[345]SM\\b", options: .regularExpression) { return ("MVFR", "cloud.fill") }

        // Check cloud cover - only BKN (broken) and OVC (overcast) count as ceilings
        // Flight category thresholds (in hundreds of feet, matching METAR format):
        // LIFR: ceiling < 500ft (height < 5)
        // IFR: ceiling 500-999ft (height 5-9)
        // MVFR: ceiling 1000-3000ft (height 10-30)
        // VFR: ceiling > 3000ft (height > 30)
        if upper.contains("OVC") {
            if let range = upper.range(of: "OVC\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)) {
                    if height < 5 { return ("LIFR", "cloud.fill") }
                    else if height < 10 { return ("IFR", "cloud.fill") }
                    else if height <= 30 { return ("MVFR", "cloud.fill") }
                    // height > 30 means ceiling > 3000ft = VFR
                    return ("VFR", "cloud.fill")
                }
            }
            return ("MVFR", "cloud.fill")
        }
        if upper.contains("BKN") {
            if let range = upper.range(of: "BKN\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)) {
                    if height < 5 { return ("LIFR", "cloud.fill") }
                    else if height < 10 { return ("IFR", "cloud.fill") }
                    else if height <= 30 { return ("MVFR", "cloud.fill") }
                    // height > 30 means ceiling > 3000ft = VFR
                    return ("VFR", "cloud.fill")
                }
            }
            return ("VFR", "cloud.fill")
        }
        if upper.contains("SCT") { return ("VFR", "cloud.sun.fill") }
        if upper.contains("FEW") { return ("VFR", "cloud.sun.fill") }
        if upper.contains("SKC") || upper.contains("CLR") || upper.contains("CAVOK") { return ("VFR", "sun.max.fill") }
        if upper.contains("P6SM") || upper.contains("9999") { return ("VFR", "cloud.sun.fill") }

        return (nil, "cloud.fill")
    }

    private func parseTAFGroups(_ rawTAF: String) -> [TAFGroup] {
        var groups: [TAFGroup] = []

        // Split TAF into lines and normalize
        let normalized = rawTAF
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        // Split by forecast groups (FM, TEMPO, BECMG, PROB)
        let pattern = "(TAF\\s+\\w+|FM\\d+|TEMPO\\s+\\d+\\/\\d+|BECMG\\s+\\d+\\/\\d+|PROB\\d+\\s+\\d+\\/\\d+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        guard let matches = regex?.matches(in: normalized, options: [], range: NSRange(normalized.startIndex..., in: normalized)) else {
            // If no matches, return single group with decoded content
            let analysis = analyzeTAFSegment(normalized)
            return [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: analysis.category, cloudIcon: analysis.icon)]
        }

        var lastEnd = normalized.startIndex

        for match in matches {
            guard let range = Range(match.range, in: normalized) else { continue }

            // Get text between last match and this one
            if lastEnd < range.lowerBound {
                let segment = String(normalized[lastEnd..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !segment.isEmpty && !groups.isEmpty {
                    let analysis = analyzeTAFSegment(segment)
                    groups[groups.count - 1] = TAFGroup(
                        header: groups[groups.count - 1].header,
                        headerColor: groups[groups.count - 1].headerColor,
                        rows: groups[groups.count - 1].rows + decodeTAFSegment(segment),
                        flightCategory: analysis.category,
                        cloudIcon: analysis.icon
                    )
                }
            }

            let matchText = String(normalized[range])
            let (header, color) = getTAFGroupHeader(matchText)
            groups.append(TAFGroup(header: header, headerColor: color, rows: []))

            lastEnd = range.upperBound
        }

        // Handle remaining text after last match
        if lastEnd < normalized.endIndex {
            let segment = String(normalized[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !segment.isEmpty && !groups.isEmpty {
                let analysis = analyzeTAFSegment(segment)
                groups[groups.count - 1] = TAFGroup(
                    header: groups[groups.count - 1].header,
                    headerColor: groups[groups.count - 1].headerColor,
                    rows: decodeTAFSegment(segment),
                    flightCategory: analysis.category,
                    cloudIcon: analysis.icon
                )
            }
        }

        let defaultAnalysis = analyzeTAFSegment(normalized)
        return groups.isEmpty ? [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: defaultAnalysis.category, cloudIcon: defaultAnalysis.icon)] : groups
    }

    private func getTAFGroupHeader(_ match: String) -> (String, Color) {
        if match.hasPrefix("TAF") {
            return ("Initial Forecast", .green)
        } else if match.hasPrefix("FM") {
            // FM followed by DDHHMM
            let digits = match.dropFirst(2)
            if digits.count >= 4 {
                let hour = String(digits.prefix(4).suffix(2))
                return ("From \(hour)00Z", .cyan)
            }
            return ("From", .cyan)
        } else if match.contains("TEMPO") {
            return ("Temporary", .orange)
        } else if match.contains("BECMG") {
            return ("Becoming", .yellow)
        } else if match.contains("PROB") {
            let probMatch = match.prefix(while: { $0.isNumber || $0 == "B" || $0 == "O" || $0 == "R" || $0 == "P" })
            let prob = probMatch.filter { $0.isNumber }
            return ("Probability \(prob)%", .purple)
        }
        return ("Forecast", .cyan)
    }

    private func decodeTAFSegment(_ segment: String) -> [TAFRow] {
        var decoded: [TAFRow] = []
        let parts = segment.components(separatedBy: " ").filter { !$0.isEmpty }

        for part in parts {
            if let row = decodeTAFElement(part) {
                decoded.append(row)
            }
        }

        return decoded
    }

    private func decodeTAFElement(_ element: String) -> TAFRow? {
        let upper = element.uppercased()

        // Skip airport identifiers and dates
        if upper.count == 4 && upper.first?.isLetter == true { return nil }
        if upper.contains("/") && upper.count == 9 { return nil } // Validity period like 2512/2612

        // Wind: DDDSSKT or DDDSSGSKT
        if upper.hasSuffix("KT") {
            let windPart = upper.dropLast(2)
            if windPart.count >= 5 {
                let dir = String(windPart.prefix(3))
                let remaining = windPart.dropFirst(3)

                if remaining.contains("G") {
                    let gustParts = remaining.components(separatedBy: "G")
                    if gustParts.count == 2 {
                        return TAFRow(label: "Wind", value: "\(dir)° at \(gustParts[0])kt gusting \(gustParts[1])kt")
                    }
                }
                return TAFRow(label: "Wind", value: "\(dir)° at \(remaining)kt")
            }
        }

        // Visibility
        if upper == "P6SM" || upper == "9999" {
            return TAFRow(label: "Visibility", value: "6+ SM")
        }
        if upper.hasSuffix("SM") {
            let vis = upper.dropLast(2)
            // Handle fractional visibility like "1/2SM" or "1 1/2SM"
            if vis.contains("/") {
                return TAFRow(label: "Visibility", value: "\(vis) SM")
            }
            return TAFRow(label: "Visibility", value: "\(vis) SM")
        }
        // Handle metric visibility (4-digit format like 0800, 1600, 9000)
        if upper.count == 4, let meters = Int(upper), meters > 0 && meters <= 9999 {
            // Convert meters to statute miles for US pilots
            let miles = Double(meters) / 1609.34
            if miles >= 6 {
                return TAFRow(label: "Visibility", value: "6+ SM")
            } else if miles >= 1 {
                return TAFRow(label: "Visibility", value: String(format: "%.0f SM", miles))
            } else {
                return TAFRow(label: "Visibility", value: String(format: "%.1f SM", miles))
            }
        }

        // Clouds - height is in hundreds of feet
        if upper.hasPrefix("FEW") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Few \(heightFt)'")
        }
        if upper.hasPrefix("SCT") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Scattered \(heightFt)'")
        }
        if upper.hasPrefix("BKN") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Broken \(heightFt)'")
        }
        if upper.hasPrefix("OVC") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Overcast \(heightFt)'")
        }
        if upper == "SKC" || upper == "CLR" {
            return TAFRow(label: "Clouds", value: "Clear")
        }
        if upper.hasPrefix("VV") {
            let height = upper.dropFirst(2)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Visibility", value: "Vertical \(heightFt)'")
        }

        // Weather phenomena
        switch upper {
        case "RA": return TAFRow(label: "Weather", value: "Rain")
        case "-RA": return TAFRow(label: "Weather", value: "Light rain")
        case "+RA": return TAFRow(label: "Weather", value: "Heavy rain")
        case "SN": return TAFRow(label: "Weather", value: "Snow")
        case "-SN": return TAFRow(label: "Weather", value: "Light snow")
        case "+SN": return TAFRow(label: "Weather", value: "Heavy snow")
        case "TS": return TAFRow(label: "Weather", value: "Thunderstorm")
        case "TSRA": return TAFRow(label: "Weather", value: "Thunderstorm with rain")
        case "FG": return TAFRow(label: "Weather", value: "Fog")
        case "BR": return TAFRow(label: "Weather", value: "Mist")
        case "HZ": return TAFRow(label: "Weather", value: "Haze")
        case "FU": return TAFRow(label: "Weather", value: "Smoke")
        case "DZ": return TAFRow(label: "Weather", value: "Drizzle")
        case "FZRA": return TAFRow(label: "Weather", value: "Freezing rain")
        case "FZDZ": return TAFRow(label: "Weather", value: "Freezing drizzle")
        case "SH": return TAFRow(label: "Weather", value: "Showers")
        case "SHRA": return TAFRow(label: "Weather", value: "Rain showers")
        case "-SHRA": return TAFRow(label: "Weather", value: "Light rain showers")
        case "+SHRA": return TAFRow(label: "Weather", value: "Heavy rain showers")
        case "SHSN": return TAFRow(label: "Weather", value: "Snow showers")
        case "NSW": return TAFRow(label: "Weather", value: "No significant weather")
        case "CAVOK": return TAFRow(label: "Conditions", value: "Ceiling and visibility OK")
        default: break
        }

        return nil
    }

    // MARK: - MOS View
    private var mosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Output Statistics (GFS)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingMOS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let forecasts = mosData[currentAirport], !forecasts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(forecasts.prefix(12))) { forecast in
                            mosRowCard(forecast)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(minHeight: 250)
            } else if isLoadingMOS {
                loadingView
            } else {
                noDataView("No MOS data available for \(currentAirport)")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - MOS Row Card (ForeFlight-style table layout)
    private func mosRowCard(_ forecast: MOSForecast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with time and cloud icon
            HStack(spacing: 8) {
                Image(systemName: mosCloudIcon(forecast))
                    .font(.system(size: 16))
                    .foregroundColor(mosIconColor(forecast))
                    .symbolRenderingMode(.multicolor)

                Text(mosTimeHeader(forecast))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)

                Spacer()

                // Precipitation probability badge for significant precip
                if let pop = forecast.p06 ?? forecast.p12, pop >= 30 {
                    Text("\(pop)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pop >= 70 ? Color.blue : Color.blue.opacity(0.6))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)

            // Table rows
            if let tmp = forecast.tmp, let dpt = forecast.dpt {
                mosTableRow(label: "Temperature", value: "\(tmp)°F / \(dpt)°F dew")
            } else if let tmp = forecast.tmp {
                mosTableRow(label: "Temperature", value: "\(tmp)°F")
            }

            if let wdr = forecast.windDirectionDegrees, let wsp = forecast.wsp {
                let windStr = wsp == 0 ? "Calm" : "\(String(format: "%03d", wdr))° at \(wsp)kt"
                mosTableRow(label: "Wind", value: windStr)
            }

            mosTableRow(label: "Sky", value: forecast.cloudCoverDescription)

            if let pop = forecast.p06 ?? forecast.p12, pop > 0 {
                mosTableRow(label: "Precip", value: "\(pop)% chance")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    private func mosCloudIcon(_ forecast: MOSForecast) -> String {
        // Check for precipitation first
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            if forecast.pos ?? 0 >= 30 {
                return "cloud.snow.fill"
            }
            return "cloud.rain.fill"
        }

        // Check for obstructions (fog, haze)
        if let obv = forecast.obv?.uppercased() {
            if obv.contains("FG") {
                return "cloud.fog.fill"
            }
            if obv.contains("HZ") || obv.contains("BR") {
                return "cloud.fog.fill"
            }
        }

        // Cloud cover icons
        switch forecast.cld?.uppercased() {
        case "CL": return "sun.max.fill"
        case "FW", "SC": return "cloud.sun.fill"
        case "BK", "OV": return "cloud.fill"
        default: return "cloud.fill"
        }
    }

    private func mosIconColor(_ forecast: MOSForecast) -> Color {
        // Precipitation - blue
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            return .blue
        }

        // Fog - gray
        if let obv = forecast.obv?.uppercased(), obv.contains("FG") {
            return .gray
        }

        // Cloud cover colors
        switch forecast.cld?.uppercased() {
        case "CL": return .yellow
        case "FW", "SC": return .cyan
        case "BK", "OV": return .gray
        default: return .gray
        }
    }

    private func mosTimeHeader(_ forecast: MOSForecast) -> String {
        guard let date = forecast.forecastTime else { return forecast.forecastHourString }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func mosTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    // MARK: - Daily Forecast View
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("7-Day Forecast")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingDaily {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if !dailyForecastData.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(dailyForecastData.prefix(14)) { forecast in
                            dailyForecastRow(forecast)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingDaily {
                loadingView
            } else {
                noDataView("No daily forecast available")
            }
        }
        .padding(.bottom, 12)
    }

    private func dailyForecastRow(_ forecast: DailyForecastData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: forecast.icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(dailyForecastColor(for: forecast))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(forecast.shortForecast)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Temperature - orange for highs (daytime), cyan for lows (nighttime)
                if let high = forecast.highTemp {
                    Text("\(high)°")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                } else if let low = forecast.lowTemp {
                    Text("\(low)°")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                if let precip = forecast.precipChance, precip > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("\(precip)%")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                }
            }

            // Wind info (if available)
            if let windString = forecast.windString {
                HStack(spacing: 4) {
                    Spacer()
                        .frame(width: 30)  // Match icon width
                    Image(systemName: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(windString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    private func dailyForecastColor(for forecast: DailyForecastData) -> Color {
        let text = forecast.shortForecast.lowercased()
        let icon = forecast.icon.lowercased()

        // Thunderstorms - purple
        if text.contains("thunder") || icon.contains("bolt") {
            return .purple
        }

        // Rain - blue
        if text.contains("rain") || text.contains("shower") || icon.contains("rain") {
            return .blue
        }

        // Snow/Ice - cyan
        if text.contains("snow") || text.contains("ice") || text.contains("sleet") || icon.contains("snow") {
            return .cyan
        }

        // Fog/Haze - gray
        if text.contains("fog") || text.contains("haze") || text.contains("mist") || icon.contains("fog") {
            return .gray
        }

        // Cloudy - light gray
        if text.contains("cloudy") || text.contains("overcast") || icon.contains("cloud") {
            return Color.gray.opacity(0.8)
        }

        // Sunny/Clear - yellow/orange
        if text.contains("sunny") || text.contains("clear") || icon.contains("sun") {
            return .yellow
        }

        // Night/Moon - light blue
        if icon.contains("moon") {
            return Color.blue.opacity(0.7)
        }

        // Default
        return .cyan
    }

    // MARK: - Winds Aloft View
    private var windsAloftView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - show source station if different from requested airport
            HStack {
                if let winds = windsAloftData[currentAirport],
                   let firstWind = winds.first,
                   let sourceStation = firstWind.sourceStation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Winds Aloft - \(currentAirport)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("(from \(sourceStation))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Winds Aloft")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                if isLoadingWinds {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let winds = windsAloftData[currentAirport], !winds.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(winds) { wind in
                            windsAloftRow(wind)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingWinds {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No winds aloft data for \(currentAirport)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Winds aloft uses limited reporting stations")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Weather Images View
    private var weatherImagesView: some View {
        WeatherImagesTabView(routeAirports: routeAirports)
    }

    private func windsAloftRow(_ wind: WindsAloftData) -> some View {
        HStack {
            Text("\(wind.altitude / 1000)K")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .leading)

            Text(wind.windString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            if let temp = wind.temperature {
                Text("\(temp)°C")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: - Parsed Weather Table
    private func parsedWeatherTable(_ weather: RawMETAR) -> some View {
        VStack(spacing: 8) {
            // Time - show local time with timezone abbreviation
            if let obsTime = weather.observationTimeLocal {
                weatherTableRow(label: "Time", value: obsTime)
            }

            weatherTableRow(label: "Wind", value: windString(for: weather))

            if let vis = weather.visibility {
                weatherTableRow(label: "Visibility", value: "\(visibilityString(for: vis)) sm")
            }

            // RVR (Runway Visual Range) - parse from raw METAR
            if let rvrString = parseRVR(from: weather.rawOb) {
                weatherTableRow(label: "RVR", value: rvrString)
            }

            // Clouds (AGL) - multiline display with flight category coloring
            cloudLayersRow(rawMetar: weather.rawOb, flightCategory: weather.flightCategory)

            // Weather Phenomena
            if let wxString = weather.wxString, !wxString.isEmpty {
                weatherTableRow(label: "Weather", value: formatWeatherPhenomena(wxString))
            }

            // Temperature with fog/icing caution indicator
            if let temp = weather.temp {
                let celsius = Int(temp)
                let fahrenheit = Int((temp * 9/5) + 32)
                let spread = weather.dewp.map { abs(temp - $0) } ?? 99
                temperatureRowWithCaution(
                    label: "Temperature",
                    value: "\(celsius)°C (\(fahrenheit)°F)",
                    showCaution: spread <= 3
                )
            }

            if let dewp = weather.dewp {
                let celsius = Int(dewp)
                let fahrenheit = Int((dewp * 9/5) + 32)
                weatherTableRow(label: "Dewpoint", value: "\(celsius)°C (\(fahrenheit)°F)")
            }

            if let pressureText = weather.formattedPressure(useInHg: settingsStore.usePressureInHg) {
                weatherTableRow(label: "Altimeter", value: pressureText)
            }

            if let humidity = weather.relativeHumidity {
                weatherTableRow(label: "Humidity", value: "\(humidity)%")
            }

            if let temp = weather.temp, let altim = weather.altim {
                let altimInHg = altim > 100 ? altim / 33.8639 : altim
                // Use station elevation from API, default to 0 if not available
                let elevation = Double(weather.elevationFeet ?? 0)
                let densityAlt = calculateDensityAltitude(temp: temp, altimeter: altimInHg, elevation: elevation)
                weatherTableRow(label: "Density Altitude", value: "\(densityAlt)'")
            }
        }
    }

    private func weatherTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value: LEFT-aligned after the gap
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Cloud Layers Row (multiline with flight category color)
    private func cloudLayersRow(rawMetar: String, flightCategory: String?) -> some View {
        let layers = parseCloudLayersArray(rawMetar)
        let lineCount = max(1, layers.count)
        let color = flightCategoryColor(flightCategory)

        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text("Clouds (AGL)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Cloud layers: Each on its own line, colored by flight category
                VStack(alignment: .leading, spacing: 2) {
                    if layers.isEmpty {
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(color)
                    } else {
                        ForEach(layers, id: \.self) { layer in
                            Text(layer)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(color)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: CGFloat(lineCount) * 20)
    }

    // MARK: - Parse Cloud Layers Array (sorted lowest first)
    private func parseCloudLayersArray(_ rawMetar: String) -> [String] {
        let components = rawMetar.uppercased().components(separatedBy: " ")
        var cloudLayers: [(altitude: Int, description: String)] = []

        for component in components {
            if component == "SKC" || component == "CLR" || component == "CAVOK" {
                return ["Clear"]
            }

            var cover = ""
            var altitude = ""

            if component.hasPrefix("VV") {
                altitude = String(component.dropFirst(2))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    let feet = altNum * 100
                    cloudLayers.append((feet, "Vertical Vis \(formatCloudAltitude(feet))"))
                }
                continue
            } else if component.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(component.dropFirst(3))
            }

            let altDigits = altitude.prefix(while: { $0.isNumber })
            if let altNum = Int(altDigits), !cover.isEmpty {
                let feet = altNum * 100
                cloudLayers.append((feet, "\(cover) \(formatCloudAltitude(feet))"))
            }
        }

        // Sort by altitude (lowest first)
        let sorted = cloudLayers.sorted { $0.altitude < $1.altitude }
        return sorted.map { $0.description }
    }

    // MARK: - Format Cloud Altitude (with comma for thousands)
    private func formatCloudAltitude(_ feet: Int) -> String {
        if feet >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: feet)) ?? "\(feet)")'"
        }
        return "\(feet)'"
    }

    // MARK: - Flight Category Color
    private func flightCategoryColor(_ category: String?) -> Color {
        guard let cat = category?.uppercased() else { return .cyan }
        switch cat {
        case "VFR":
            return .green
        case "MVFR":
            return .yellow
        case "IFR":
            return .red
        case "LIFR":
            return Color(red: 1.0, green: 0.0, blue: 1.0) // Magenta
        default:
            return .cyan
        }
    }

    // Temperature row with optional fog/icing caution indicator
    private func temperatureRowWithCaution(label: String, value: String, showCaution: Bool) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                // Label: RIGHT-aligned to 35% mark
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                // Value with optional caution indicator
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)

                    if showCaution {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Runway Analysis Section
    private func runwayAnalysisSection(_ weather: RawMETAR) -> some View {
        Group {
            if let runways = weatherService.cachedRunways[currentAirport],
               !runways.isEmpty {
                // Use wind data if available, default to calm (0) if not
                let windDir = weather.windDirection ?? 0
                let windSpeed = weather.wspd ?? 0

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                // Runway Wind Compass View
                runwayWindCompassView(
                    windDirection: windDir,
                    windSpeed: windSpeed,
                    runways: runways
                )

            } else if isLoadingRunways {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading runway data...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }

    // MARK: - Runway Wind Compass View (HSI Style - Runway Up)
    private func runwayWindCompassView(windDirection: Int, windSpeed: Int, runways: [RunwayInfo]) -> some View {
        let safeIndex = min(selectedRunwayIndex, runways.count - 1)
        let currentRunway = runways[max(0, safeIndex)]
        let runwayHeading = Double(currentRunway.heading)
        let windDir = Double(windDirection)
        let windSpd = Double(windSpeed)

        // Calculate wind components
        let angleDiff = (windDir - runwayHeading) * .pi / 180
        let headwind = Int(round(cos(angleDiff) * windSpd))
        let crosswind = Int(round(sin(angleDiff) * windSpd))

        // For HSI style: rotate compass so runway heading points UP
        // Wind arrow position relative to runway (not compass north)
        let compassRotation = -runwayHeading  // Rotate compass opposite to runway heading
        let windRelativeToRunway = windDir - runwayHeading  // Wind position relative to runway

        return VStack(spacing: 12) {
            // Section Header
            HStack {
                Text("Runway Analysis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Wind: \(String(format: "%03d", windDirection))° @ \(windSpeed)kt")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)

            // Runway selector with chevrons
            HStack {
                // Left chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if selectedRunwayIndex > 0 {
                            selectedRunwayIndex -= 1
                        } else {
                            selectedRunwayIndex = runways.count - 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Runway identifier
                VStack(spacing: 2) {
                    Text("RWY \(currentRunway.ident)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("\(currentRunway.length)ft × \(currentRunway.width)ft")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Right chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if selectedRunwayIndex < runways.count - 1 {
                            selectedRunwayIndex += 1
                        } else {
                            selectedRunwayIndex = 0
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)

            // HSI-Style Compass visualization (Runway always UP)
            ZStack {
                // Background Compass Rose - ROTATES so runway heading points UP
                HSICompassRoseView()
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(compassRotation))
                    .animation(.easeInOut(duration: 0.3), value: runwayHeading)

                // Wind Particles - rotate relative to runway
                WindParticlesView(speed: windSpd)
                    .id("wind-\(windDirection)-\(windSpeed)-\(Int(runwayHeading))")
                    .mask(Circle().padding(4))
                    .rotationEffect(.degrees(windRelativeToRunway))
                    .frame(width: 240, height: 240)
                    .opacity(windSpd > 0 ? 1.0 : 0)

                // Runway Graphic - FIXED pointing UP (no rotation)
                HSIRunwayGraphic(runwayIdent: currentRunway.ident)
                    .frame(width: 160, height: 160)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

                // Wind Arrow - positioned relative to runway
                HSIWindArrowGraphic(relativeDirection: windRelativeToRunway, speed: windSpd)
                    .frame(width: 200, height: 200)
            }
            .frame(height: 260)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < 0 {
                            // Swipe left - next runway
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if selectedRunwayIndex < runways.count - 1 {
                                    selectedRunwayIndex += 1
                                } else {
                                    selectedRunwayIndex = 0
                                }
                            }
                        } else if value.translation.width > 0 {
                            // Swipe right - previous runway
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if selectedRunwayIndex > 0 {
                                    selectedRunwayIndex -= 1
                                } else {
                                    selectedRunwayIndex = runways.count - 1
                                }
                            }
                        }
                    }
            )

            // Wind component cards
            HStack(spacing: 16) {
                // Headwind/Tailwind
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: headwind >= 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(headwind))")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                        Text("kt")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(headwind >= 0 ? LogbookTheme.accentGreen : .red)

                    Text(headwind >= 0 ? "HEADWIND" : "TAILWIND")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)

                // Crosswind
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: crosswind > 0 ? "arrow.right" : (crosswind < 0 ? "arrow.left" : "minus"))
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(crosswind))")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                        Text("kt")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(abs(crosswind) <= 10 ? LogbookTheme.accentGreen : (abs(crosswind) <= 20 ? .orange : .red))

                    Text("CROSSWIND")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            .padding(.horizontal, 12)

            // Page indicator dots
            if runways.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<runways.count, id: \.self) { index in
                        Circle()
                            .fill(index == safeIndex ? LogbookTheme.accentGreen : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .onChange(of: currentAirport) { _, _ in
            // Reset runway selection when airport changes
            selectedRunwayIndex = 0
        }
    }

    // MARK: - Flight Category Badge
    private func flightCategoryBadge(_ category: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(categoryColor(category))
                .frame(width: 12, height: 12)

            Text(category)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(categoryColor(category))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor(category).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Helper Views
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private func noDataView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - Helper Functions
    private func categoryColor(_ category: String?) -> Color {
        guard let category = category else { return .gray }
        switch category {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return Color(red: 1.0, green: 0.0, blue: 1.0)  // Magenta
        default: return .gray
        }
    }

    private func timeAgeColor(_ weather: RawMETAR) -> Color {
        guard let timestamp = weather.obsTime else { return .gray }

        let observationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let elapsed = Date().timeIntervalSince(observationDate)
        let minutes = Int(elapsed / 60)

        if minutes < 30 {
            return .green
        } else if minutes < 60 {
            return .yellow
        } else if minutes < 120 {
            return .orange
        } else {
            return .red
        }
    }

    private func windString(for weather: RawMETAR) -> String {
        if let dir = weather.windDirection, let speed = weather.wspd {
            // Calm winds (speed 0)
            if speed == 0 {
                return "Winds calm"
            }
            if let gust = weather.wgst {
                return "\(String(format: "%03d", dir))° at \(speed) kts gusting \(gust)"
            }
            return "\(String(format: "%03d", dir))° at \(speed) kts"
        } else if let speed = weather.wspd, speed > 0 {
            // Variable wind
            if let gust = weather.wgst {
                return "Variable at \(speed) kts gusting \(gust)"
            }
            return "Variable at \(speed) kts"
        }
        return "Winds calm"
    }

    private func visibilityString(for vis: Double) -> String {
        if vis >= 10 { return "10+" }
        if vis >= 6 { return "6+" }

        // Convert to fractions for common aviation visibility values
        let tolerance = 0.01
        if abs(vis - 0.25) < tolerance { return "¼" }
        if abs(vis - 0.5) < tolerance { return "½" }
        if abs(vis - 0.75) < tolerance { return "¾" }
        if abs(vis - 1.0) < tolerance { return "1" }
        if abs(vis - 1.25) < tolerance { return "1¼" }
        if abs(vis - 1.5) < tolerance { return "1½" }
        if abs(vis - 1.75) < tolerance { return "1¾" }
        if abs(vis - 2.0) < tolerance { return "2" }
        if abs(vis - 2.5) < tolerance { return "2½" }
        if abs(vis - 3.0) < tolerance { return "3" }
        if abs(vis - 4.0) < tolerance { return "4" }
        if abs(vis - 5.0) < tolerance { return "5" }

        // For other values, show decimal but prefer whole numbers
        if vis == floor(vis) {
            return String(format: "%.0f", vis)
        }
        return String(format: "%.1f", vis)
    }

    private func calculateDensityAltitude(temp: Double, altimeter: Double, elevation: Double) -> Int {
        // Standard day ISA temp at sea level is 15°C
        // Temp lapse rate is ~2°C per 1000ft
        let isaTemp = 15.0 - (elevation / 1000.0 * 2.0)
        let tempDeviation = temp - isaTemp

        // Pressure altitude from altimeter setting
        let pressureAlt = (29.92 - altimeter) * 1000 + elevation

        // Density altitude = pressure altitude + (120 * temp deviation)
        let densityAlt = pressureAlt + (120 * tempDeviation)

        return Int(densityAlt)
    }

    // MARK: - Helper: Format Cloud Layers
    private func formatCloudLayers(_ clouds: String) -> String {
        // Parse cloud string like "SCT130 BKN160 BKN250" or "VV002" into readable format
        let layers = clouds.components(separatedBy: " ")
        var formatted: [String] = []

        for layer in layers {
            let upper = layer.uppercased()
            var cover = ""
            var altitude = ""

            if upper.hasPrefix("SKC") || upper.hasPrefix("CLR") || upper == "CAVOK" {
                return "Clear"
            } else if upper.hasPrefix("VV") {
                // Vertical Visibility (indefinite ceiling, typically fog)
                altitude = String(upper.dropFirst(2))
                if let altNum = Int(altitude) {
                    formatted.append("Vertical Vis \(altNum * 100)'")
                }
                continue
            } else if upper.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(upper.dropFirst(3))
            } else if upper.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(upper.dropFirst(3))
            }

            // Handle altitude with possible CB/TCU suffix (e.g., "025CB")
            let altDigits = altitude.prefix(while: { $0.isNumber })
            if let altNum = Int(altDigits), !cover.isEmpty {
                formatted.append("\(cover) \(altNum * 100)'")
            }
        }

        return formatted.isEmpty ? clouds : formatted.joined(separator: "\n")
    }

    // MARK: - Helper: Parse Clouds from Raw METAR
    private func parseCloudsFromRawMetar(_ rawMetar: String) -> String? {
        // Parse cloud layers directly from raw METAR text
        // Format: "Scattered 900'" on line 1, "Broken 1,700'" on line 2, etc.
        let components = rawMetar.uppercased().components(separatedBy: " ")
        var cloudLayers: [(altitude: Int, description: String)] = []

        for component in components {
            if component == "SKC" || component == "CLR" || component == "CAVOK" {
                return "Clear"
            } else if component.hasPrefix("VV") {
                let altitude = String(component.dropFirst(2))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Vertical Vis \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("FEW") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Few \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("SCT") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Scattered \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("BKN") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Broken \(formatAltitude(altNum * 100))"))
                }
            } else if component.hasPrefix("OVC") {
                let altitude = String(component.dropFirst(3))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    cloudLayers.append((altNum * 100, "Overcast \(formatAltitude(altNum * 100))"))
                }
            }
        }

        // Sort by altitude (lowest first) and join with newlines
        let sorted = cloudLayers.sorted { $0.altitude < $1.altitude }
        return sorted.isEmpty ? nil : sorted.map { $0.description }.joined(separator: "\n")
    }

    // Format altitude with comma for thousands (e.g., 1,700')
    private func formatAltitude(_ feet: Int) -> String {
        if feet >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: feet)) ?? "\(feet)")'"
        }
        return "\(feet)'"
    }

    // MARK: - Helper: Parse RVR (Runway Visual Range) from raw METAR
    private func parseRVR(from rawMetar: String) -> String? {
        // RVR format: R09R/5500VP6000FT or R09L/2000V4000FT
        let pattern = "R(\\d{2}[LRC]?)/([\\dPM]+)(?:V([\\dPM]+))?FT"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let range = NSRange(rawMetar.startIndex..., in: rawMetar)
        let matches = regex.matches(in: rawMetar, options: [], range: range)

        guard !matches.isEmpty else { return nil }

        var rvrStrings: [String] = []
        for match in matches {
            guard let runwayRange = Range(match.range(at: 1), in: rawMetar),
                  let valueRange = Range(match.range(at: 2), in: rawMetar) else { continue }

            let runway = String(rawMetar[runwayRange])
            let value1 = String(rawMetar[valueRange])

            var rvrValue = ""
            if match.range(at: 3).location != NSNotFound,
               let value2Range = Range(match.range(at: 3), in: rawMetar) {
                let value2 = String(rawMetar[value2Range])
                rvrValue = "Rwy \(runway): \(formatRVRValue(value1))' to \(formatRVRValue(value2))'"
            } else {
                rvrValue = "Rwy \(runway): \(formatRVRValue(value1))'"
            }
            rvrStrings.append(rvrValue)
        }

        return rvrStrings.isEmpty ? nil : rvrStrings.joined(separator: "\n")
    }

    private func formatRVRValue(_ value: String) -> String {
        // Handle P (plus/greater than) and M (minus/less than) prefixes
        if value.hasPrefix("P") {
            return ">\(value.dropFirst())"
        } else if value.hasPrefix("M") {
            return "<\(value.dropFirst())"
        }
        return value
    }

    // MARK: - Helper: Format Weather Phenomena
    private func formatWeatherPhenomena(_ wxString: String) -> String {
        // Parse weather phenomena codes from wxString
        let codes = wxString.components(separatedBy: " ")
        var phenomena: [String] = []

        for code in codes {
            if let description = decodeWeatherPhenomenon(code) {
                phenomena.append(description)
            }
        }

        return phenomena.isEmpty ? wxString : phenomena.joined(separator: "\n")
    }

    private func decodeWeatherPhenomenon(_ code: String) -> String? {
        // Intensity prefixes
        var intensity = ""
        var workingCode = code

        if workingCode.hasPrefix("-") {
            intensity = "Light "
            workingCode = String(workingCode.dropFirst())
        } else if workingCode.hasPrefix("+") {
            intensity = "Heavy "
            workingCode = String(workingCode.dropFirst())
        } else if workingCode.hasPrefix("VC") {
            intensity = "Vicinity "
            workingCode = String(workingCode.dropFirst(2))
        }

        // Weather phenomena codes
        let phenomenaMap: [String: String] = [
            // Precipitation
            "RA": "Rain",
            "SN": "Snow",
            "DZ": "Drizzle",
            "PL": "Ice Pellets",
            "GR": "Hail",
            "GS": "Small Hail",
            "SG": "Snow Grains",
            "IC": "Ice Crystals",
            "UP": "Unknown Precip",
            // Obscurations
            "FG": "Fog",
            "BR": "Mist",
            "HZ": "Haze",
            "FU": "Smoke",
            "SA": "Sand",
            "DU": "Dust",
            "VA": "Volcanic Ash",
            "PY": "Spray",
            // Other
            "TS": "Thunderstorm",
            "SQ": "Squall",
            "FC": "Funnel Cloud",
            "SS": "Sandstorm",
            "DS": "Duststorm",
            "PO": "Dust Devils",
            "SH": "Showers",
            "BLSN": "Blowing Snow",
            "BLDU": "Blowing Dust",
            "BLSA": "Blowing Sand",
            "DRSN": "Drifting Snow",
            "DRDU": "Drifting Dust",
            "DRSA": "Drifting Sand",
            "FZRA": "Freezing Rain",
            "FZDZ": "Freezing Drizzle",
            "FZFG": "Freezing Fog",
            "TSRA": "Thunderstorm Rain",
            "TSSN": "Thunderstorm Snow",
            "SHRA": "Rain Showers",
            "SHSN": "Snow Showers",
            "SHGR": "Hail Showers",
            "PRFG": "Partial Fog",
            "BCFG": "Patches of Fog",
            "MIFG": "Shallow Fog",
        ]

        // Try compound codes first (like FZRA, TSRA)
        if let description = phenomenaMap[workingCode] {
            return intensity + description
        }

        // Try parsing as combination (e.g., "RABR" = Rain + Mist)
        var parts: [String] = []
        var remaining = workingCode
        while !remaining.isEmpty {
            var found = false
            // Try 4-char codes first, then 2-char
            for length in [4, 2] {
                if remaining.count >= length {
                    let prefix = String(remaining.prefix(length))
                    if let desc = phenomenaMap[prefix] {
                        parts.append(desc)
                        remaining = String(remaining.dropFirst(length))
                        found = true
                        break
                    }
                }
            }
            if !found { break }
        }

        if !parts.isEmpty {
            return intensity + parts.joined(separator: ", ")
        }

        return nil
    }

    // MARK: - Data Loading
    private func loadDataForCurrentTab() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }

        switch selectedWeatherTab {
        case .metar:
            loadRunwayData()
        case .datis:
            loadDATISData()
        case .taf:
            loadTAFData()
        case .mos:
            loadMOSData()
        case .daily:
            loadDailyForecast()
        case .winds:
            loadWindsAloft()
        case .images:
            // Images are loaded on-demand in the view
            break
        }
    }

    private func loadRunwayData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard weatherService.cachedRunways[currentAirport] == nil else {
            print("✅ Runways already cached for \(currentAirport)")
            return
        }
        guard !isLoadingRunways else { return }

        print("🛫 Loading Runways for \(currentAirport)...")
        isLoadingRunways = true

        Task {
            do {
                let runways = try await weatherService.fetchRunways(for: currentAirport)
                await MainActor.run {
                    isLoadingRunways = false
                    print("✅ Runways loaded for \(currentAirport): \(runways.count) runways")
                }
            } catch {
                print("❌ Failed to fetch Runways for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingRunways = false
                }
            }
        }
    }

    private func loadDATISData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard datisData[currentAirport] == nil else {
            print("✅ D-ATIS already cached for \(currentAirport)")
            return
        }
        guard !isLoadingDATIS else { return }

        print("🌐 Loading D-ATIS for \(currentAirport)...")
        isLoadingDATIS = true

        Task {
            do {
                let datis = try await weatherService.fetchDATIS(for: currentAirport)
                await MainActor.run {
                    datisData[currentAirport] = datis
                    isLoadingDATIS = false
                    print("✅ D-ATIS loaded for \(currentAirport)")
                }
            } catch {
                print("❌ Failed to fetch D-ATIS for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingDATIS = false
                }
            }
        }
    }

    private func loadTAFData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard tafData[currentAirport] == nil else {
            print("✅ TAF already cached for \(currentAirport)")
            return
        }
        guard !isLoadingTAF else { return }

        print("🌐 Loading TAF for \(currentAirport)...")
        isLoadingTAF = true

        Task {
            do {
                let taf = try await weatherService.fetchTAF(for: currentAirport)
                await MainActor.run {
                    tafData[currentAirport] = taf
                    isLoadingTAF = false
                    print("✅ TAF loaded for \(currentAirport)")
                }
            } catch {
                print("❌ Failed to fetch TAF for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingTAF = false
                }
            }
        }
    }

    private func loadMOSData() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard mosData[currentAirport] == nil else {
            print("✅ MOS already cached for \(currentAirport)")
            return
        }
        guard !isLoadingMOS else { return }

        print("🌐 Loading MOS for \(currentAirport)...")
        isLoadingMOS = true

        Task {
            do {
                let mos = try await weatherService.fetchMOS(for: currentAirport)
                await MainActor.run {
                    mosData[currentAirport] = mos
                    isLoadingMOS = false
                    print("✅ MOS loaded for \(currentAirport): \(mos.count) forecasts")
                }
            } catch {
                print("❌ Failed to fetch MOS for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingMOS = false
                }
            }
        }
    }

    private func loadDailyForecast() {
        guard dailyForecastData.isEmpty else {
            print("✅ Daily forecast already cached")
            return
        }
        guard !isLoadingDaily else { return }
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }

        // Get airport coordinates from database
        guard let airport = AirportDatabaseManager.shared.getAirport(for: currentAirport) else {
            print("❌ Could not find airport coordinates for \(currentAirport)")
            return
        }

        print("🌐 Loading Daily Forecast for \(currentAirport)...")
        isLoadingDaily = true

        Task {
            do {
                let forecast = try await weatherService.fetchDailyForecast(
                    latitude: airport.coordinate.latitude,
                    longitude: airport.coordinate.longitude
                )
                await MainActor.run {
                    dailyForecastData = forecast
                    isLoadingDaily = false
                    print("✅ Daily forecast loaded: \(forecast.count) periods")
                }
            } catch {
                print("❌ Failed to fetch Daily Forecast: \(error)")
                await MainActor.run {
                    isLoadingDaily = false
                }
            }
        }
    }

    private func loadWindsAloft() {
        guard !currentAirport.isEmpty, currentAirport != "----" else { return }
        guard windsAloftData[currentAirport] == nil else {
            print("✅ Winds already cached for \(currentAirport)")
            return
        }
        guard !isLoadingWinds else { return }

        print("🌐 Loading Winds Aloft for \(currentAirport)...")
        isLoadingWinds = true

        Task {
            do {
                let winds = try await weatherService.fetchWindsAloft(for: currentAirport)
                await MainActor.run {
                    windsAloftData[currentAirport] = winds
                    isLoadingWinds = false
                    print("✅ Winds Aloft loaded for \(currentAirport): \(winds.count) levels")
                }
            } catch {
                print("❌ Failed to fetch Winds Aloft for \(currentAirport): \(error)")
                await MainActor.run {
                    isLoadingWinds = false
                }
            }
        }
    }
}

// MARK: - HSI Style Compass Rose (with degree labels)
struct HSICompassRoseView: View {
    var body: some View {
        ZStack {
            // Dark Background
            Circle()
                .fill(LogbookTheme.navyLight)

            // Ticks - every 5 degrees (72 ticks)
            ForEach(0..<72) { tick in
                let degrees = tick * 5
                let isMajor = degrees % 30 == 0  // N, 3, 6, E, 12, 15, S, 21, 24, W, 30, 33
                let isCardinal = degrees % 90 == 0  // N, E, S, W

                Rectangle()
                    .fill(isCardinal ? Color.white : (isMajor ? Color.gray : Color.gray.opacity(0.3)))
                    .frame(width: isCardinal ? 3 : (isMajor ? 2 : 1),
                           height: isCardinal ? 15 : (isMajor ? 12 : 5))
                    .offset(y: -110)
                    .rotationEffect(.degrees(Double(degrees)))
            }

            // Degree Labels: N, 3, 6, E, 12, 15, S, 21, 24, W, 30, 33
            ForEach(0..<12) { i in
                let degrees = i * 30
                let label = hsiLabel(for: degrees)

                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(degrees == 0 ? LogbookTheme.accentOrange : .gray)
                    .offset(y: -92)
                    .rotationEffect(.degrees(Double(degrees)))
            }
        }
    }

    private func hsiLabel(for degrees: Int) -> String {
        switch degrees {
        case 0: return "N"
        case 30: return "3"
        case 60: return "6"
        case 90: return "E"
        case 120: return "12"
        case 150: return "15"
        case 180: return "S"
        case 210: return "21"
        case 240: return "24"
        case 270: return "W"
        case 300: return "30"
        case 330: return "33"
        default: return ""
        }
    }
}

// MARK: - HSI Runway Graphic (Fixed pointing UP)
struct HSIRunwayGraphic: View {
    let runwayIdent: String

    // Get reciprocal runway number
    private var reciprocalIdent: String {
        let cleanNum = runwayIdent.filter { $0.isNumber }
        guard let num = Int(cleanNum) else { return runwayIdent }
        var recip = num + 18
        if recip > 36 { recip -= 36 }

        // Handle L/R/C suffix
        let suffix = runwayIdent.filter { !$0.isNumber }
        let recipSuffix: String
        switch suffix {
        case "L": recipSuffix = "R"
        case "R": recipSuffix = "L"
        default: recipSuffix = suffix
        }
        return String(format: "%02d", recip) + recipSuffix
    }

    var body: some View {
        ZStack {
            // Runway asphalt
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 2)
                )
                .frame(width: 36, height: 180)

            // Centerline (Dashed)
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 16)
                }
            }

            // Threshold Markings & Numbers
            // Runway numbers are at the APPROACH end (threshold) where pilots see them
            VStack {
                // Top - reciprocal runway (approach end for opposite direction)
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle().fill(.white).frame(width: 2, height: 8)
                        }
                    }
                    Text(reciprocalIdent)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(180)) // Flipped so it reads correctly from its approach direction
                }
                .padding(.top, 8)

                Spacer()

                // Bottom - active runway (approach end / threshold we're landing on)
                VStack(spacing: 2) {
                    Text(runwayIdent)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle().fill(.white).frame(width: 2, height: 8)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(height: 180)
        }
    }
}

// MARK: - HSI Wind Arrow (relative to runway)
struct HSIWindArrowGraphic: View {
    let relativeDirection: Double  // Wind direction relative to runway heading
    let speed: Double

    var body: some View {
        ZStack {
            if speed > 0 {
                VStack(spacing: 0) {
                    // Arrow head
                    Image(systemName: "arrowtriangle.down.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.cyan)

                    // Arrow shaft
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 3, height: 50)

                    // Wind speed bubble
                    Text("\(Int(speed))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.cyan))
                }
                .offset(y: -65)
                .rotationEffect(.degrees(relativeDirection))
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct WeatherBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // With active trip
            WeatherBannerView(activeTrip: Trip(
                tripNumber: "1234",
                aircraft: "N12345",
                date: Date(),
                tatStart: "0800",
                crew: [],
                notes: "",
                legs: [
                    FlightLeg(departure: "KDAB", arrival: "KATL"),
                    FlightLeg(departure: "KATL", arrival: "KJFK"),
                    FlightLeg(departure: "KJFK", arrival: "KLAX")
                ],
                tripType: .operating,
                status: .active,
                pilotRole: .captain
            ))
            .padding()
            
            // Without active trip
            WeatherBannerView(activeTrip: nil)
                .padding()
        }
        .background(LogbookTheme.navy)
        .preferredColorScheme(.dark)
    }
}
#endif

// MARK: - Weather Images Tab View
struct WeatherImagesTabView: View {
    let routeAirports: [String]

    @State private var selectedImageType: Int = 0  // 0=Radar, 1=Satellite, 2=Infrared

    private struct WeatherRegion: Identifiable {
        let id = UUID()
        let name: String
        let radarURL: String
        let satelliteURL: String
        let infraredURL: String
    }

    private var allWeatherRegions: [WeatherRegion] {
        [
            WeatherRegion(
                name: "CONUS",
                radarURL: "https://radar.weather.gov/ridge/standard/CONUS-LARGE_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/CONUS/GEOCOLOR/1250x750.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/CONUS/13/1250x750.jpg"
            ),
            WeatherRegion(
                name: "Northeast",
                radarURL: "https://radar.weather.gov/ridge/standard/NORTHEAST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/ne/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/ne/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southeast",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHEAST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/se/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/se/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Great Lakes",
                radarURL: "https://radar.weather.gov/ridge/standard/CENTGRLAKES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/cgl/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/cgl/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Upper Mississippi",
                radarURL: "https://radar.weather.gov/ridge/standard/UPPERMISSVLY_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/umv/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/umv/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Mississippi",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHMISSVLY_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/smv/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/smv/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Plains",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHPLAINS_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sp/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sp/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Northern Rockies",
                radarURL: "https://radar.weather.gov/ridge/standard/NORTHROCKIES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/nr/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/nr/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Rockies",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHROCKIES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sr/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sr/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Pacific Northwest",
                radarURL: "https://radar.weather.gov/ridge/standard/PACNORTHWEST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/pnw/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/pnw/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Pacific Southwest",
                radarURL: "https://radar.weather.gov/ridge/standard/PACSOUTHWEST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/psw/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/psw/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Alaska",
                radarURL: "https://radar.weather.gov/ridge/standard/ALASKA_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/ak/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/ak/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Hawaii",
                radarURL: "https://radar.weather.gov/ridge/standard/HAWAII_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/hi/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/hi/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Caribbean",
                radarURL: "https://radar.weather.gov/ridge/standard/CARIB_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/car/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/car/13/1200x1200.jpg"
            )
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            // Image type selector
            Picker("Image Type", selection: $selectedImageType) {
                Text("Radar").tag(0)
                Text("Satellite").tag(1)
                Text("Infrared").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Swipeable regions
            TabView {
                ForEach(allWeatherRegions) { region in
                    VStack(spacing: 8) {
                        Text(region.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        let urlString: String = {
                            switch selectedImageType {
                            case 0: return region.radarURL
                            case 1: return region.satelliteURL
                            case 2: return region.infraredURL
                            default: return region.radarURL
                            }
                        }()

                        weatherImageContent(urlString: urlString)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(minHeight: 350)

            // Source attribution
            Text("Data: NOAA GOES / NWS Radar")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func weatherImageContent(urlString: String) -> some View {
        if let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 280)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                case .failure:
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .frame(height: 150)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

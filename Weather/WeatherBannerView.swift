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

        // Check cache first (safe - we're on MainActor)
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

        // Try OurAirports API as fallback
        do {
            let urlString = "https://ourairports.com/airports/\(icao)/runways.json"
            guard let url = URL(string: urlString) else {
                throw WeatherBannerError.invalidURL
            }

            let (data, _) = try await URLSession.shared.data(from: url)

            // Check for HTML response
            if let dataString = String(data: data, encoding: .utf8), dataString.starts(with: "<") {
                print("⚠️ OurAirports returned HTML for \(icao)")
                throw WeatherBannerError.noData
            }

            let runways = try JSONDecoder().decode([RunwayInfo].self, from: data)
            // Safe - we're on MainActor
            self.cachedRunways[icao] = runways
            self.lastRunwayFetchTime[icao] = Date()
            return runways
        } catch {
            print("⚠️ No runway data available for \(icao)")
            throw WeatherBannerError.noData
        }
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
    // These are the standard FAA winds aloft reporting stations (3-letter codes, coordinates)
    // Source: https://aviationweather.gov/data/windtemp/
    private static let windsAloftStations: [(code: String, lat: Double, lon: Double)] = [
        // Northeast
        ("ACK", 41.25, -70.07), ("ALB", 42.75, -73.80), ("BGR", 44.81, -68.82), ("BDL", 41.94, -72.68),
        ("BOS", 42.36, -71.01), ("BTV", 44.47, -73.15), ("CAR", 46.87, -68.02), ("CON", 43.20, -71.50),
        ("HTO", 40.96, -72.25), ("JFK", 40.64, -73.78), ("PVD", 41.72, -71.43), ("SYR", 43.11, -76.10),
        // Mid-Atlantic
        ("ABE", 40.65, -75.44), ("ACY", 39.45, -74.57), ("AOO", 40.30, -78.32), ("AVP", 41.34, -75.73),
        ("BWI", 39.18, -76.67), ("DCA", 38.85, -77.04), ("EWR", 40.69, -74.17), ("HAR", 40.29, -76.87),
        ("IAD", 38.95, -77.46), ("PHL", 39.87, -75.24), ("PIT", 40.50, -80.23), ("RIC", 37.50, -77.32),
        // Southeast
        ("ATL", 33.64, -84.43), ("AVL", 35.44, -82.54), ("BNA", 36.12, -86.68), ("CAE", 33.94, -81.12),
        ("CHS", 32.90, -80.04), ("CLT", 35.21, -80.94), ("CRW", 38.37, -81.59), ("DAB", 29.18, -81.06),
        ("EYW", 24.56, -81.76), ("GSO", 36.10, -79.94), ("HSV", 34.64, -86.77), ("JAX", 30.49, -81.69),
        ("LEX", 38.04, -84.60), ("MEM", 35.04, -90.00), ("MIA", 25.79, -80.29), ("MLB", 28.10, -80.65),
        ("MOB", 30.69, -88.24), ("ORF", 36.90, -76.21), ("PBI", 26.68, -80.10), ("PNS", 30.47, -87.19),
        ("ROA", 37.32, -79.97), ("SAV", 32.13, -81.20), ("TLH", 30.40, -84.35), ("TPA", 27.98, -82.53),
        ("TRI", 36.48, -82.40), ("TYS", 35.81, -84.00),
        // Great Lakes / Midwest
        ("APN", 45.07, -83.56), ("CMH", 39.98, -82.88), ("CLE", 41.41, -81.85), ("CVG", 39.05, -84.67),
        ("DAY", 39.90, -84.22), ("DET", 42.41, -83.01), ("DTW", 42.21, -83.35), ("ECK", 43.26, -82.72),
        ("FWA", 40.98, -85.19), ("GRB", 44.48, -88.13), ("GRR", 42.88, -85.52), ("IND", 39.72, -86.29),
        ("LAN", 42.78, -84.59), ("MBS", 43.53, -84.08), ("MKE", 42.95, -87.90), ("MKG", 43.17, -86.24),
        ("PLN", 45.57, -84.80), ("SBN", 41.71, -86.31), ("SSM", 46.48, -84.36), ("TOL", 41.59, -83.81),
        ("TVC", 44.74, -85.58), ("YNG", 41.26, -80.68),
        // Central / Plains
        ("ABR", 45.45, -98.42), ("AMA", 35.22, -101.70), ("BFF", 41.89, -103.60), ("BIS", 46.77, -100.74),
        ("DDC", 37.76, -99.97), ("DEN", 39.86, -104.67), ("DSM", 41.53, -93.66), ("FAR", 46.90, -96.80),
        ("FSD", 43.58, -96.74), ("GCK", 37.93, -100.72), ("GFK", 47.95, -97.18), ("GLD", 39.37, -101.70),
        ("GRI", 40.97, -98.31), ("ICT", 37.65, -97.43), ("INL", 48.57, -93.40), ("ISN", 48.18, -103.64),
        ("LBF", 41.13, -100.68), ("MCI", 39.30, -94.71), ("MKC", 39.12, -94.59), ("MLS", 46.43, -105.89),
        ("MOT", 48.26, -101.28), ("OFK", 41.99, -97.44), ("OMA", 41.30, -95.89), ("ONL", 42.47, -98.69),
        ("P60", 41.87, -102.28), ("PIR", 44.38, -100.29), ("RAP", 44.04, -103.05), ("SGF", 37.24, -93.39),
        ("SLC", 40.78, -111.97), ("STL", 38.75, -90.37), ("TOP", 39.07, -95.62),
        // Southwest
        ("ABQ", 35.04, -106.61), ("DFW", 32.90, -97.02), ("ELP", 31.81, -106.38), ("FTW", 32.82, -97.36),
        ("HOU", 29.65, -95.28), ("IAH", 29.98, -95.34), ("INK", 31.78, -103.20), ("LBB", 33.66, -101.82),
        ("MAF", 31.94, -102.20), ("MRF", 30.37, -104.02), ("OKC", 35.39, -97.60), ("PHX", 33.43, -112.01),
        ("PRC", 34.65, -112.42), ("ROW", 33.30, -104.53), ("SAT", 29.53, -98.47), ("TCS", 33.24, -107.27),
        ("TUS", 32.12, -110.94),
        // Northwest / Mountain
        ("BOI", 43.57, -116.22), ("BTM", 45.95, -112.50), ("BZN", 45.78, -111.15), ("DLN", 45.25, -112.55),
        ("DNJ", 45.18, -113.20), ("EKO", 40.83, -115.79), ("ELY", 39.30, -114.84), ("GEG", 47.62, -117.53),
        ("GTF", 47.48, -111.37), ("HLN", 46.61, -112.00), ("LKV", 42.16, -120.40), ("LVM", 45.68, -110.45),
        ("LWS", 46.37, -117.01), ("MLP", 44.13, -115.73), ("MUO", 43.04, -115.87), ("OTH", 43.42, -124.25),
        ("PDT", 45.69, -118.84), ("PDX", 45.59, -122.60), ("PIH", 42.91, -112.60), ("REO", 42.58, -117.87),
        ("RNO", 39.50, -119.77), ("SEA", 47.45, -122.31), ("SFF", 47.68, -117.32), ("WMC", 42.93, -117.81),
        ("YKM", 46.57, -120.54),
        // California
        ("BFL", 35.43, -119.06), ("BIH", 37.37, -118.36), ("DAG", 34.85, -116.79), ("EDW", 34.91, -117.88),
        ("FAT", 36.78, -119.72), ("FOT", 40.55, -124.13), ("LAX", 33.94, -118.41), ("MRY", 36.59, -121.85),
        ("OAK", 37.72, -122.22), ("ONT", 34.05, -117.60), ("RBL", 40.15, -122.25), ("SAC", 38.51, -121.49),
        ("SAN", 32.73, -117.19), ("SBA", 34.43, -119.84), ("SFO", 37.62, -122.38), ("SIY", 41.78, -122.47),
        ("TPH", 38.06, -117.09), ("WJF", 34.74, -118.22),
        // Alaska
        ("ADQ", 57.75, -152.50), ("ANC", 61.17, -150.02), ("ANI", 61.58, -159.55), ("BET", 60.78, -161.84),
        ("BRW", 71.29, -156.77), ("BTI", 70.13, -143.58), ("CDB", 55.21, -162.72), ("FAI", 64.81, -147.86),
        ("GAL", 64.74, -156.94), ("GKN", 62.16, -145.46), ("HOM", 59.65, -151.48), ("JNU", 58.36, -134.58),
        ("MCG", 62.95, -155.61), ("MDO", 59.45, -146.31), ("OME", 64.51, -165.44), ("OTZ", 66.89, -162.60),
        ("SIT", 57.05, -135.36), ("TKA", 62.32, -150.09), ("YAK", 59.51, -139.66),
        // Hawaii
        ("HNL", 21.32, -157.93), ("ITO", 19.72, -155.05), ("LIH", 21.98, -159.34), ("OGG", 20.90, -156.43)
    ]

    // MARK: - Winds Aloft Fetching (aviationweather.gov)
    func fetchWindsAloft(for airport: String) async throws -> [WindsAloftData] {
        let icao = airport.uppercased()

        // Use the winds aloft API - it provides forecast winds at various altitudes
        let urlString = "https://aviationweather.gov/api/data/windtemp?region=all&level=low,high&fcst=06,12,24"
        guard let url = URL(string: urlString) else {
            throw WeatherBannerError.invalidURL
        }

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
            if let airportInfo = AirportDatabaseManager.shared.getAirport(for: icao) {
                let airportLat = airportInfo.coordinate.latitude
                let airportLon = airportInfo.coordinate.longitude

                // Find the nearest winds aloft station
                if let nearestStation = findNearestWindsAloftStation(lat: airportLat, lon: airportLon) {
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
        // Winds aloft format: DDSS or DDSS+TT or DDSS-TT
        // DD = direction (tens of degrees, so 27 = 270°)
        // SS = speed in knots
        // TT = temperature (optional, with sign)

        var windPart = component
        var temp: Int? = nil

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
            return WindsAloftData(altitude: altitude, direction: 990, speed: 0, temperature: temp, sourceStation: sourceStation)
        }

        let direction = dirTens * 10

        return WindsAloftData(altitude: altitude, direction: direction, speed: speed, temperature: temp, sourceStation: sourceStation)
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
                icon: icon
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
                    // Large Flight Category Badge
                    if let category = weather.flightCategory {
                        flightCategoryBadge(category)
                    }

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

    // MARK: - Color-Coded Raw METAR
    private func colorCodedRawMETAR(_ weather: RawMETAR) -> some View {
        Text(weather.rawOb)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(categoryColor(weather.flightCategory))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .textSelection(.enabled)
    }

    // MARK: - Parsed Weather Table (ForeFlight Style)
    private func parsedWeatherTable(_ weather: RawMETAR) -> some View {
        VStack(spacing: 8) {
            // Time
            if let obsTime = weather.observationTime {
                weatherTableRow(label: "Time", value: obsTime)
            }

            // Wind
            weatherTableRow(label: "Wind", value: windString(for: weather))

            // Visibility
            if let vis = weather.visibility {
                weatherTableRow(label: "Visibility", value: "\(visibilityString(for: vis)) sm")
            }

            // Clouds (AGL)
            if let clouds = weather.cover, !clouds.isEmpty {
                weatherTableRow(label: "Clouds (AGL)", value: formatCloudLayers(clouds))
            }

            // Temperature
            if let temp = weather.temp {
                let celsius = Int(temp)
                let fahrenheit = Int((temp * 9/5) + 32)
                weatherTableRow(label: "Temperature", value: "\(celsius)°C (\(fahrenheit)°F)")
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
                let densityAlt = calculateDensityAltitude(temp: temp, altimeter: altimInHg, elevation: 0)
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

        // Check visibility
        if upper.contains("1/4SM") || upper.contains("1/2SM") || upper.contains("0SM") {
            return ("LIFR", "cloud.fill")
        }
        if upper.contains("1SM ") || upper.contains("2SM ") {
            return ("IFR", "cloud.fill")
        }
        if upper.contains("3SM") || upper.contains("4SM") || upper.contains("5SM") {
            return ("MVFR", "cloud.fill")
        }

        // Check cloud cover
        if upper.contains("OVC") {
            if let range = upper.range(of: "OVC\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                let heightStr = match.dropFirst(3)
                if let height = Int(heightStr), height < 5 {
                    return ("LIFR", "cloud.fill")
                } else if let height = Int(heightStr), height < 10 {
                    return ("IFR", "cloud.fill")
                } else if let height = Int(heightStr), height < 30 {
                    return ("MVFR", "cloud.fill")
                }
            }
            return ("MVFR", "cloud.fill")
        }
        if upper.contains("BKN") {
            if let range = upper.range(of: "BKN\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                let heightStr = match.dropFirst(3)
                if let height = Int(heightStr), height < 5 {
                    return ("LIFR", "cloud.fill")
                } else if let height = Int(heightStr), height < 10 {
                    return ("IFR", "cloud.fill")
                } else if let height = Int(heightStr), height < 30 {
                    return ("MVFR", "cloud.fill")
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

            // Temperature
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
        // Parse cloud string like "SCT130 BKN160 BKN250" into readable format
        let layers = clouds.components(separatedBy: " ")
        var formatted: [String] = []

        for layer in layers {
            var cover = ""
            var altitude = ""

            if layer.hasPrefix("SKC") || layer.hasPrefix("CLR") {
                return "Clear"
            } else if layer.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(layer.dropFirst(3))
            } else if layer.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(layer.dropFirst(3))
            } else if layer.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(layer.dropFirst(3))
            } else if layer.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(layer.dropFirst(3))
            }

            if let altNum = Int(altitude) {
                formatted.append("\(cover) \(altNum * 100)'")
            }
        }

        return formatted.isEmpty ? clouds : formatted.joined(separator: "\n")
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
        case "LIFR": return .pink
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
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with cycle buttons
            HStack(spacing: 4) {
                Button(action: previousRunway) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text("RWY \(currentRunway)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Button(action: nextRunway) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Wind components
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
                // Airport Selector (if multiple airports)
                if routeAirports.count > 1 {
                    airportSelector
                }

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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(LogbookTheme.navyDark)
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
        if upper.contains("1/4SM") || upper.contains("1/2SM") { return ("LIFR", "cloud.fill") }
        if upper.contains("1SM ") || upper.contains("2SM ") { return ("IFR", "cloud.fill") }
        if upper.contains("3SM") || upper.contains("4SM") || upper.contains("5SM") { return ("MVFR", "cloud.fill") }

        if upper.contains("OVC") {
            if let range = upper.range(of: "OVC\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)), height < 5 { return ("LIFR", "cloud.fill") }
                else if let height = Int(match.dropFirst(3)), height < 10 { return ("IFR", "cloud.fill") }
                else if let height = Int(match.dropFirst(3)), height < 30 { return ("MVFR", "cloud.fill") }
            }
            return ("MVFR", "cloud.fill")
        }
        if upper.contains("BKN") {
            if let range = upper.range(of: "BKN\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)), height < 5 { return ("LIFR", "cloud.fill") }
                else if let height = Int(match.dropFirst(3)), height < 10 { return ("IFR", "cloud.fill") }
                else if let height = Int(match.dropFirst(3)), height < 30 { return ("MVFR", "cloud.fill") }
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

            Text(forecast.temperatureString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.cyan)

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
            if let obsTime = weather.observationTime {
                weatherTableRow(label: "Time", value: obsTime)
            }

            weatherTableRow(label: "Wind", value: windString(for: weather))

            if let vis = weather.visibility {
                weatherTableRow(label: "Visibility", value: "\(visibilityString(for: vis)) sm")
            }

            if let clouds = weather.cover, !clouds.isEmpty {
                weatherTableRow(label: "Clouds (AGL)", value: clouds)
            }

            if let temp = weather.temp {
                let celsius = Int(temp)
                let fahrenheit = Int((temp * 9/5) + 32)
                weatherTableRow(label: "Temperature", value: "\(celsius)°C (\(fahrenheit)°F)")
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
                let densityAlt = calculateDensityAltitude(temp: temp, altimeter: altimInHg, elevation: 0)
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
        case "LIFR": return .pink
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
            if let gust = weather.wgst {
                return "\(String(format: "%03d", dir))@\(speed)G\(gust)kt"
            }
            return "\(String(format: "%03d", dir))@\(speed)kt"
        } else if let speed = weather.wspd, speed > 0 {
            if let gust = weather.wgst {
                return "VRB \(speed)G\(gust)kt"
            }
            return "VRB \(speed)kt"
        }
        return "Calm"
    }

    private func visibilityString(for vis: Double) -> String {
        if vis >= 10 { return "10+" }
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

        print("🌐 Loading Daily Forecast...")
        isLoadingDaily = true

        Task {
            do {
                // TODO: Get actual airport coordinates from database
                let forecast = try await weatherService.fetchDailyForecast(latitude: 29.18, longitude: -81.05)
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

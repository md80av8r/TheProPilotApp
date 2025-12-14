// AirportDatabaseManager.swift - Dynamic Airport Management
import Foundation
import CoreLocation
import SwiftUI

// Note: Notification names are defined in OPSCallingManager.swift

// MARK: - Night Hours Airport Info Structure (for NightHoursCalculator compatibility)
struct NightHoursAirportInfo {
    let coordinate: CLLocationCoordinate2D
    let timeZoneIdentifier: String
    let airportName: String
}

// MARK: - Enhanced Airport Database Manager
class AirportDatabaseManager: ObservableObject {
    @Published var userAddedAirports: [String: AirportInfo] = [:]
    @Published var isLookingUpAirport = false
    @Published var lookupStatus = ""
    
    private let userDefaults = UserDefaults.shared
    private let userAirportsKey = "UserAddedAirports"
    
    // Built-in airport coordinates
    private let builtInAirports: [String: CLLocationCoordinate2D] = [
        // UNITED STATES (K prefix)
        "TEST": CLLocationCoordinate2D(latitude: 42.58, longitude: -83.36),   // Test Airport - Orchard Lake area
        "KATL": CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277),   // Atlanta Hartsfield-Jackson
        "KLAX": CLLocationCoordinate2D(latitude: 33.9425, longitude: -118.4081),  // Los Angeles International
        "KORD": CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9073),   // Chicago O'Hare
        "KDFW": CLLocationCoordinate2D(latitude: 32.8998, longitude: -97.0403),   // Dallas/Fort Worth
        "KDEN": CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737),  // Denver International
        "KJFK": CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781),   // New York JFK
        "KLGA": CLLocationCoordinate2D(latitude: 40.7769, longitude: -73.8740),   // New York LaGuardia
        "KEWR": CLLocationCoordinate2D(latitude: 40.6925, longitude: -74.1687),   // Newark
        "KSFO": CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.3790),  // San Francisco
        "KLAS": CLLocationCoordinate2D(latitude: 36.0840, longitude: -115.1537),  // Las Vegas McCarran
        "KPHX": CLLocationCoordinate2D(latitude: 33.4352, longitude: -112.0101),  // Phoenix Sky Harbor
        "KMIA": CLLocationCoordinate2D(latitude: 25.7959, longitude: -80.2870),   // Miami International
        "KFLL": CLLocationCoordinate2D(latitude: 26.0742, longitude: -80.1506),   // Fort Lauderdale
        "KMCO": CLLocationCoordinate2D(latitude: 28.4312, longitude: -81.3081),   // Orlando International
        "KTPA": CLLocationCoordinate2D(latitude: 27.9755, longitude: -82.5332),   // Tampa International
        "KBOS": CLLocationCoordinate2D(latitude: 42.3656, longitude: -71.0096),   // Boston Logan
        "KDCA": CLLocationCoordinate2D(latitude: 38.8512, longitude: -77.0402),   // Washington National
        "KIAD": CLLocationCoordinate2D(latitude: 38.9531, longitude: -77.4565),   // Washington Dulles
        "KBWI": CLLocationCoordinate2D(latitude: 39.1774, longitude: -76.6684),   // Baltimore/Washington
        "KPHL": CLLocationCoordinate2D(latitude: 39.8744, longitude: -75.2424),   // Philadelphia
        "KCLT": CLLocationCoordinate2D(latitude: 35.2144, longitude: -80.9473),   // Charlotte Douglas
        "KSEA": CLLocationCoordinate2D(latitude: 47.4502, longitude: -122.3088),  // Seattle-Tacoma
        "KPDX": CLLocationCoordinate2D(latitude: 45.5898, longitude: -122.5951),  // Portland International
        "KMSP": CLLocationCoordinate2D(latitude: 44.8847, longitude: -93.2055),   // Minneapolis-St. Paul
        "KDTW": CLLocationCoordinate2D(latitude: 42.2162, longitude: -83.3554),   // Detroit Metropolitan
        "KYIP": CLLocationCoordinate2D(latitude: 42.2379, longitude: -83.5304),   // Willow Run (USA Jet base)
        "KIAH": CLLocationCoordinate2D(latitude: 29.9902, longitude: -95.3368),   // Houston Intercontinental
        "KHOU": CLLocationCoordinate2D(latitude: 29.6465, longitude: -95.2789),   // Houston Hobby
        "KAUS": CLLocationCoordinate2D(latitude: 30.1975, longitude: -97.6664),   // Austin-Bergstrom
        "KSAT": CLLocationCoordinate2D(latitude: 29.5337, longitude: -98.4698),   // San Antonio
        "KDAL": CLLocationCoordinate2D(latitude: 32.8439, longitude: -96.8517),   // Dallas Love Field
        "KMDW": CLLocationCoordinate2D(latitude: 41.7868, longitude: -87.7522),   // Chicago Midway
        "KELP": CLLocationCoordinate2D(latitude: 31.8072, longitude: -106.3781),  // El Paso
        "KLRD": CLLocationCoordinate2D(latitude: 27.5438, longitude: -99.4616),   // Laredo International
        "KCRP": CLLocationCoordinate2D(latitude: 27.7704, longitude: -97.5012),   // Corpus Christi
        "KMFE": CLLocationCoordinate2D(latitude: 26.1756, longitude: -98.2386),   // McAllen Miller
        "KBRO": CLLocationCoordinate2D(latitude: 25.9068, longitude: -97.4256),   // Brownsville/South Padre
        "KSDF": CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.7360),   // Louisville Muhammad Ali International
        
        // CANADA (C prefix)
        "CYYZ": CLLocationCoordinate2D(latitude: 43.6777, longitude: -79.6248),   // Toronto Pearson
        "CYVR": CLLocationCoordinate2D(latitude: 49.1939, longitude: -123.1844),  // Vancouver International
        "CYUL": CLLocationCoordinate2D(latitude: 45.4706, longitude: -73.7408),   // Montreal-Pierre Elliott Trudeau
        "CYYC": CLLocationCoordinate2D(latitude: 51.1315, longitude: -114.0106),  // Calgary International
        "CYEG": CLLocationCoordinate2D(latitude: 53.3097, longitude: -113.5801),  // Edmonton International
        "CYOW": CLLocationCoordinate2D(latitude: 45.3194, longitude: -75.6697),   // Ottawa Macdonald-Cartier
        "CYHZ": CLLocationCoordinate2D(latitude: 44.8808, longitude: -63.5086),   // Halifax Stanfield
        "CYWG": CLLocationCoordinate2D(latitude: 49.9069, longitude: -97.2314),   // Winnipeg Richardson
        
        // MEXICO (MM prefix)
        "MMMX": CLLocationCoordinate2D(latitude: 19.4363, longitude: -99.0721),   // Mexico City International
        "MMUN": CLLocationCoordinate2D(latitude: 21.0365, longitude: -86.8771),   // Cancún International
        "MMGL": CLLocationCoordinate2D(latitude: 20.5218, longitude: -103.3119),  // Guadalajara International
        "MMTJ": CLLocationCoordinate2D(latitude: 32.5411, longitude: -116.9700),  // Tijuana General Abelardo
        "MMMY": CLLocationCoordinate2D(latitude: 25.7785, longitude: -100.1077),  // Monterrey International
        "MMPR": CLLocationCoordinate2D(latitude: 20.6801, longitude: -105.2540),  // Puerto Vallarta
        "MMCZ": CLLocationCoordinate2D(latitude: 20.5226, longitude: -86.9256),   // Cozumel International
        "MMMZ": CLLocationCoordinate2D(latitude: 23.1614, longitude: -106.2658),  // Mazatlán General Rafael
        "MMSD": CLLocationCoordinate2D(latitude: 23.1518, longitude: -109.7209),  // Los Cabos International
        "MMQT": CLLocationCoordinate2D(latitude: 20.6173, longitude: -100.1857),  // Querétaro Intercontinental
        "MMLP": CLLocationCoordinate2D(latitude: 24.0727, longitude: -110.3624),  // La Paz International
        "MMHO": CLLocationCoordinate2D(latitude: 29.0959, longitude: -111.0481),  // Hermosillo General Ignacio
        "MMCU": CLLocationCoordinate2D(latitude: 28.7029, longitude: -105.9644),  // Chihuahua General Roberto Fierro
        
        // CARIBBEAN
        "MYNN": CLLocationCoordinate2D(latitude: 25.0394, longitude: -77.4663),   // Nassau Lynden Pindling (Bahamas)
        "TJSJ": CLLocationCoordinate2D(latitude: 18.4394, longitude: -66.0018),   // San Juan Luis Muñoz Marín (Puerto Rico)
        "TNCM": CLLocationCoordinate2D(latitude: 18.0410, longitude: -63.1086),   // St. Maarten Princess Juliana
        "TDPD": CLLocationCoordinate2D(latitude: 12.1315, longitude: -68.2681),   // Curaçao Hato International
        "TAPA": CLLocationCoordinate2D(latitude: 12.5014, longitude: -70.0152),   // Aruba Queen Beatrix
        "MKJP": CLLocationCoordinate2D(latitude: 17.9357, longitude: -76.7875),   // Kingston Norman Manley (Jamaica)
        "MUHA": CLLocationCoordinate2D(latitude: 23.1133, longitude: -82.4092),   // Havana José Martí (Cuba)
        
        // CENTRAL AMERICA
        "MGSJ": CLLocationCoordinate2D(latitude: 14.5833, longitude: -90.5275),   // Guatemala City La Aurora
        "MHTE": CLLocationCoordinate2D(latitude: 14.0608, longitude: -87.2172),   // Tegucigalpa Toncontín (Honduras)
        "MNMG": CLLocationCoordinate2D(latitude: 12.1415, longitude: -86.1681),   // Managua Augusto C. Sandino (Nicaragua)
        "MROC": CLLocationCoordinate2D(latitude: 9.9937, longitude: -84.2081),    // San José Juan Santamaría (Costa Rica)
        "MPTO": CLLocationCoordinate2D(latitude: 9.0714, longitude: -79.3835),    // Panama City Tocumen
        
        // EUROPE (Major hubs for reference)
        "EGLL": CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543),    // London Heathrow
        "EHAM": CLLocationCoordinate2D(latitude: 52.3086, longitude: 4.7639),     // Amsterdam Schiphol
        "EDDF": CLLocationCoordinate2D(latitude: 50.0333, longitude: 8.5706),     // Frankfurt am Main
        "LFPG": CLLocationCoordinate2D(latitude: 49.0097, longitude: 2.5479),     // Paris Charles de Gaulle
        "LEMD": CLLocationCoordinate2D(latitude: 40.4719, longitude: -3.5626),    // Madrid-Barajas
        "LIRF": CLLocationCoordinate2D(latitude: 41.8003, longitude: 12.2389),    // Rome Fiumicino
    ]
    
    init() {
        loadUserAirports()
    }
    
    // MARK: - Coordinate Lookup (Primary Interface)
    
    func coordinates(for icaoCode: String) -> CLLocationCoordinate2D? {
        // First check built-in database
        if let builtIn = builtInAirports[icaoCode.uppercased()] {
            return builtIn
        }
        
        // Then check user-added airports
        if let userAirport = userAddedAirports[icaoCode.uppercased()] {
            return userAirport.coordinate
        }
        
        return nil
    }
    
    // MARK: - Night Hours Calculator Support
    
    /// Get airport info with async lookup for night hours calculation
    func getAirportInfo(_ icao: String) async -> NightHoursAirportInfo? {
        let cleanICAO = icao.uppercased().trimmingCharacters(in: .whitespaces)
        
        print("🢢 Looking up airport info for \(cleanICAO)")
        
        // First check if we have this airport (built-in or user-added)
        if let coordinate = coordinates(for: cleanICAO) {
            let timeZone = timeZone(for: cleanICAO)
            let name = getAirportName(for: cleanICAO)
            
            print("🢢 Found \(cleanICAO) in database: \(name)")
            return NightHoursAirportInfo(
                coordinate: coordinate,
                timeZoneIdentifier: timeZone.identifier,
                airportName: name
            )
        }
        
        // Try dynamic lookup if not found
        print("🢢 Airport \(cleanICAO) not in database, attempting dynamic lookup...")
        if let airport = await lookupAirport(icaoCode: cleanICAO) {
            let timeZone = timeZone(for: cleanICAO)
            print("🢢 Successfully looked up and cached \(cleanICAO): \(airport.name)")
            
            return NightHoursAirportInfo(
                coordinate: airport.coordinate,
                timeZoneIdentifier: timeZone.identifier,
                airportName: airport.name
            )
        }
        
        print("🢢 ⚠️ Could not find airport info for \(cleanICAO)")
        return nil
    }
    
    // MARK: - Manual Airport Addition
    
    func addAirport(
        icaoCode: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: String? = nil
    ) {
        let airportInfo = AirportInfo(
            icaoCode: icaoCode.uppercased(),
            name: name,
            coordinate: coordinate,
            timeZone: timeZone,
            source: .userAdded,
            dateAdded: Date()
        )
        
        userAddedAirports[icaoCode.uppercased()] = airportInfo
        saveUserAirports()
        
        print("✅ Added airport: \(icaoCode) - \(name)")
    }
    
    // MARK: - Automatic Online Lookup
    
    func lookupAirport(icaoCode: String) async -> AirportInfo? {
        await MainActor.run {
            isLookingUpAirport = true
            lookupStatus = "Looking up \(icaoCode)..."
        }
        
        // Try multiple data sources
        if let airport = await lookupFromOpenFlights(icaoCode: icaoCode) {
            await MainActor.run {
                userAddedAirports[icaoCode.uppercased()] = airport
                saveUserAirports()
                isLookingUpAirport = false
                lookupStatus = "✅ Found \(airport.name)"
            }
            return airport
        }
        
        if let airport = await lookupFromAviationAPI(icaoCode: icaoCode) {
            await MainActor.run {
                userAddedAirports[icaoCode.uppercased()] = airport
                saveUserAirports()
                isLookingUpAirport = false
                lookupStatus = "✅ Found \(airport.name)"
            }
            return airport
        }
        
        await MainActor.run {
            isLookingUpAirport = false
            lookupStatus = "❌ Could not find \(icaoCode)"
        }
        
        return nil
    }
    
    // MARK: - Data Source APIs
    
    private func lookupFromOpenFlights(icaoCode: String) async -> AirportInfo? {
        // OpenFlights.org airport database (free)
        guard let url = URL(string: "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let csvData = String(data: data, encoding: .utf8) ?? ""
            
            // Parse CSV for matching ICAO code
            let lines = csvData.components(separatedBy: .newlines)
            for line in lines {
                let fields = parseCSVLine(line)
                
                // OpenFlights format: ID,Name,City,Country,IATA,ICAO,Latitude,Longitude,Altitude,Timezone,DST,Tz
                if fields.count >= 8,
                   fields[5].uppercased() == icaoCode.uppercased(),
                   let lat = Double(fields[6]),
                   let lon = Double(fields[7]) {
                    
                    return AirportInfo(
                        icaoCode: icaoCode.uppercased(),
                        name: "\(fields[1]) (\(fields[2]))",
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        timeZone: fields.count > 11 ? fields[11] : nil,
                        source: .openFlights,
                        dateAdded: Date()
                    )
                }
            }
        } catch {
            print("OpenFlights lookup error: \(error)")
        }
        
        return nil
    }
    
    private func lookupFromAviationAPI(icaoCode: String) async -> AirportInfo? {
        // Alternative: Aviation Edge API (requires API key)
        // For demonstration - you'd need to sign up for an API key
        guard let url = URL(string: "https://aviation-edge.com/v2/public/airports?key=YOUR_API_KEY&codeIcaoAirport=\(icaoCode)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let airport = json.first,
               let name = airport["nameAirport"] as? String,
               let latStr = airport["latitudeAirport"] as? String,
               let lonStr = airport["longitudeAirport"] as? String,
               let lat = Double(latStr),
               let lon = Double(lonStr) {
                
                return AirportInfo(
                    icaoCode: icaoCode.uppercased(),
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    timeZone: airport["timezone"] as? String,
                    source: .aviationAPI,
                    dateAdded: Date()
                )
            }
        } catch {
            print("Aviation API lookup error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Import from External Sources
    
    func importAirportsFromCSV(_ csvData: String) -> Int {
        let lines = csvData.components(separatedBy: .newlines)
        var importCount = 0
        
        for line in lines.dropFirst() { // Skip header
            let fields = parseCSVLine(line)
            
            // Expected format: ICAO,Name,Latitude,Longitude,Timezone
            if fields.count >= 4,
               let lat = Double(fields[2]),
               let lon = Double(fields[3]) {
                
                let icao = fields[0].uppercased()
                let name = fields[1]
                let timezone = fields.count > 4 ? fields[4] : nil
                
                let airport = AirportInfo(
                    icaoCode: icao,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    timeZone: timezone,
                    source: .csvImport,
                    dateAdded: Date()
                )
                
                userAddedAirports[icao] = airport
                importCount += 1
            }
        }
        
        saveUserAirports()
        return importCount
    }
    
    // MARK: - Persistence
    
    private func saveUserAirports() {
        do {
            let data = try JSONEncoder().encode(userAddedAirports)
            userDefaults.set(data, forKey: userAirportsKey)
        } catch {
            print("Failed to save user airports: \(error)")
        }
    }
    
    private func loadUserAirports() {
        guard let data = userDefaults.data(forKey: userAirportsKey) else { return }
        
        do {
            userAddedAirports = try JSONDecoder().decode([String: AirportInfo].self, from: data)
        } catch {
            print("Failed to load user airports: \(error)")
        }
    }
    
    // MARK: - Utility Functions
    
    func removeUserAirport(_ icaoCode: String) {
        userAddedAirports.removeValue(forKey: icaoCode.uppercased())
        saveUserAirports()
    }
    
    func getAllAirports() -> [AirportInfo] {
        return Array(userAddedAirports.values).sorted { $0.icaoCode < $1.icaoCode }
    }
    
    func searchAirports(_ query: String) -> [AirportInfo] {
        let lowercaseQuery = query.lowercased()
        return getAllAirports().filter {
            $0.icaoCode.lowercased().contains(lowercaseQuery) ||
            $0.name.lowercased().contains(lowercaseQuery)
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
    
    // MARK: - Additional Helper Methods
    
    // Helper function to find nearby airports if exact match not found
    func findNearbyAirport(to coordinate: CLLocationCoordinate2D, within radiusKm: Double = 100) -> String? {
        var closestAirport: String?
        var closestDistance: Double = Double.infinity
        
        // Check built-in airports
        for (icao, airportCoord) in builtInAirports {
            let distance = coordinate.distance(to: airportCoord)
            if distance < radiusKm * 1000 && distance < closestDistance {
                closestDistance = distance
                closestAirport = icao
            }
        }
        
        // Check user-added airports
        for (icao, airportInfo) in userAddedAirports {
            let distance = coordinate.distance(to: airportInfo.coordinate)
            if distance < radiusKm * 1000 && distance < closestDistance {
                closestDistance = distance
                closestAirport = icao
            }
        }
        
        return closestAirport
    }
    
    // Get time zone for airport (simplified lookup)
    func timeZone(for icaoCode: String) -> TimeZone {
        let timezones: [String: String] = [
            // US Eastern
            "KATL": "America/New_York", "KJFK": "America/New_York", "KLGA": "America/New_York",
            "KEWR": "America/New_York", "KBOS": "America/New_York", "KDCA": "America/New_York",
            "KIAD": "America/New_York", "KBWI": "America/New_York", "KPHL": "America/New_York",
            "KCLT": "America/New_York", "KMIA": "America/New_York", "KFLL": "America/New_York",
            "KMCO": "America/New_York", "KTPA": "America/New_York",
            
            // US Central
            "KORD": "America/Chicago", "KMDW": "America/Chicago", "KDFW": "America/Chicago",
            "KDAL": "America/Chicago", "KIAH": "America/Chicago", "KHOU": "America/Chicago",
            "KAUS": "America/Chicago", "KSAT": "America/Chicago", "KMSP": "America/Chicago",
            "KELP": "America/Denver", "KLRD": "America/Chicago", "KCRP": "America/Chicago",
            
            // US Mountain
            "KDEN": "America/Denver", "KPHX": "America/Phoenix",
            
            // US Pacific
            "KLAX": "America/Los_Angeles", "KSFO": "America/Los_Angeles", "KLAS": "America/Los_Angeles",
            "KSEA": "America/Los_Angeles", "KPDX": "America/Los_Angeles",
            
            // US Michigan
            "KDTW": "America/Detroit", "KYIP": "America/Detroit",
            
            // Canada
            "CYYZ": "America/Toronto", "CYUL": "America/Montreal", "CYVR": "America/Vancouver",
            "CYYC": "America/Edmonton", "CYEG": "America/Edmonton", "CYOW": "America/Toronto",
            
            // Mexico
            "MMMX": "America/Mexico_City", "MMUN": "America/Cancun", "MMGL": "America/Mexico_City",
            "MMTJ": "America/Tijuana", "MMMY": "America/Monterrey", "MMPR": "America/Mexico_City",
        ]
        
        let identifier = timezones[icaoCode.uppercased()] ?? "UTC"
        return TimeZone(identifier: identifier) ?? TimeZone(identifier: "UTC")!
    }
    
    // MARK: - Geofencing Support Methods
    
    /// Get all built-in airports for geofencing setup
    func getAllBuiltInAirports() -> [String: CLLocationCoordinate2D] {
        return self.builtInAirports
    }
    
    /// Get airport name for display purposes
    func getAirportName(for icaoCode: String) -> String {
        let icao = icaoCode.uppercased()
        
        // Check user-added airports first (they have full names)
        if let userAirport = self.userAddedAirports[icao] {
            return userAirport.name
        }
        
        // For built-in airports, provide common names
        let builtInNames: [String: String] = [
            // USA Jet Airports
            "KYIP": "Willow Run Airport",
            "KDTW": "Detroit Metropolitan Wayne County",
            "KDET": "Detroit City Airport",
            
            // Major US Hubs
            "KATL": "Atlanta Hartsfield-Jackson",
            "KLAX": "Los Angeles International",
            "KORD": "Chicago O'Hare",
            "KDFW": "Dallas/Fort Worth International",
            "KDEN": "Denver International",
            "KJFK": "JFK International",
            "KLGA": "LaGuardia Airport",
            "KEWR": "Newark Liberty International",
            "KSFO": "San Francisco International",
            "KLAS": "Harry Reid International",
            "KPHX": "Phoenix Sky Harbor",
            "KMIA": "Miami International",
            "KBOS": "Logan International",
            "KSEA": "Seattle-Tacoma International",
            "KMSP": "Minneapolis-St. Paul",
            "KIAH": "Houston Intercontinental",
            "KHOU": "Houston Hobby",
            "KAUS": "Austin-Bergstrom",
            "KSAT": "San Antonio International",
            "KLRD": "Laredo International",
            "KCRP": "Corpus Christi International",
            
            // Canada
            "CYYZ": "Toronto Pearson International",
            "CYVR": "Vancouver International",
            "CYUL": "Montreal-Pierre Elliott Trudeau",
            "CYYC": "Calgary International",
            "CYEG": "Edmonton International",
            "CYOW": "Ottawa Macdonald-Cartier",
            
            // Mexico
            "MMMX": "Mexico City International",
            "MMUN": "Cancún International",
            "MMGL": "Guadalajara International",
            "MMTJ": "Tijuana General Abelardo",
            "MMMY": "Monterrey International",
            
            // Caribbean
            "MYNN": "Nassau Lynden Pindling",
            "TJSJ": "San Juan Luis Muñoz Marín",
            "TNCM": "St. Maarten Princess Juliana",
            
            // Europe
            "EGLL": "London Heathrow",
            "EHAM": "Amsterdam Schiphol",
            "EDDF": "Frankfurt am Main",
            "LFPG": "Paris Charles de Gaulle",
            "LEMD": "Madrid-Barajas",
            "LIRF": "Rome Fiumicino",
        ]
        
        return builtInNames[icao] ?? "\(icao) Airport"
    }
    
    /// Get all airports (built-in + user-added) for comprehensive geofencing
    func getAllAirportsForGeofencing() -> [String: CLLocationCoordinate2D] {
        var allAirports = self.builtInAirports
        
        // Add user-added airports
        for (icao, airportInfo) in self.userAddedAirports {
            allAirports[icao] = airportInfo.coordinate
        }
        
        return allAirports
    }
    
    /// Check if an airport is a home base for automatic duty/OPS calling
    func isHomeBase(_ icaoCode: String, for airline: String = "USA Jet") -> Bool {
        let homeBases: [String: [String]] = [
            "USA Jet": ["KYIP", "KDET", "KLRD"],
            "American": ["KDFW", "KMIA", "KORD", "KPHX"],
            "Delta": ["KATL", "KORD", "KLAX", "KJFK"],
            "United": ["KORD", "KDEN", "KIAH", "KEWR"],
            "Southwest": ["KDFW", "KPHX", "KBWI", "KDEN"]
        ]
        
        return homeBases[airline]?.contains(icaoCode.uppercased()) ?? false
    }
    
    /// Enhanced distance calculation with better error handling
    func getDistanceToAirport(from location: CLLocation, to icaoCode: String) -> CLLocationDistance? {
        guard let coordinate = self.coordinates(for: icaoCode) else { return nil }
        
        let airportLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: airportLocation)
    }
    
    /// Get nearby airports sorted by distance (enhanced version)
    func getNearbyAirports(to location: CLLocation, within radiusKm: Double = 50, limit: Int = 10) -> [(icao: String, name: String, distance: CLLocationDistance)] {
        var nearbyAirports: [(icao: String, name: String, distance: CLLocationDistance)] = []
        
        // Check built-in airports
        for (icao, coordinate) in self.builtInAirports {
            let airportLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: airportLocation)
            
            if distance <= radiusKm * 1000 {
                nearbyAirports.append((
                    icao: icao,
                    name: getAirportName(for: icao),
                    distance: distance
                ))
            }
        }
        
        // Check user-added airports
        for (icao, airportInfo) in self.userAddedAirports {
            let airportLocation = CLLocation(latitude: airportInfo.coordinate.latitude, longitude: airportInfo.coordinate.longitude)
            let distance = location.distance(from: airportLocation)
            
            if distance <= radiusKm * 1000 {
                nearbyAirports.append((
                    icao: icao,
                    name: airportInfo.name,
                    distance: distance
                ))
            }
        }
        
        // Sort by distance and limit results
        return Array(nearbyAirports.sorted { $0.distance < $1.distance }.prefix(limit))
    }
    
    /// Get priority airports for geofencing (limited to 20 due to iOS restriction)
    func getPriorityAirportsForGeofencing() -> [String: CLLocationCoordinate2D] {
        // Priority order: USA Jet bases, user-added, major hubs
        // ⚠️ iOS HARD LIMIT: 20 geofenced regions per app
        var priorityAirports: [String: CLLocationCoordinate2D] = [:]
        let maxGeofences = 20
        
        // 1. USA Jet bases (highest priority)
        let usaJetBases = ["KYIP", "KDET", "KLRD"]
        for icao in usaJetBases {
            if priorityAirports.count >= maxGeofences { break }
            if let coordinate = self.coordinates(for: icao) {
                priorityAirports[icao] = coordinate
            }
        }
        
        // 2. User-added airports (high priority) - ENFORCE LIMIT
        for (icao, airportInfo) in self.userAddedAirports {
            if priorityAirports.count >= maxGeofences { break }
            priorityAirports[icao] = airportInfo.coordinate
        }
        
        // 3. Major hubs (fill remaining slots)
        let majorHubs = ["KATL", "KLAX", "KORD", "KDFW", "KDEN", "KJFK", "KSFO", "KLAS", "KPHX", "KMIA", "KBOS", "KSEA", "CYYZ"]
        for icao in majorHubs {
            if priorityAirports.count >= maxGeofences { break }
            if priorityAirports[icao] == nil, let coordinate = self.coordinates(for: icao) {
                priorityAirports[icao] = coordinate
            }
        }
        
        print("🛩️ Selected \(priorityAirports.count) priority airports for geofencing (iOS limit: \(maxGeofences))")
        return priorityAirports
    }
    
    /// Enhanced addAirport method that notifies geofencing system
    func addAirportWithGeofenceRefresh(
        icaoCode: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: String? = nil
    ) {
        // Add the airport using existing method
        self.addAirport(icaoCode: icaoCode, name: name, coordinate: coordinate, timeZone: timeZone)
        
        // Notify geofencing system to refresh
        NotificationCenter.default.post(name: .refreshGeofences, object: nil)
        
        print("✅ Added airport with geofence refresh: \(icaoCode) - \(name)")
    }
    
    /// Enhanced removeUserAirport method
    func removeUserAirportWithGeofenceRefresh(_ icaoCode: String) {
        self.removeUserAirport(icaoCode) // Call existing method
        
        // Notify geofencing system to refresh
        NotificationCenter.default.post(name: .refreshGeofences, object: nil)
        
        print("🗑️ Removed airport with geofence refresh: \(icaoCode)")
    }
    
    /// Get comprehensive airport info for debugging
    func getAirportDebugInfo() -> String {
        var info = "🛩️ AIRPORT DATABASE DEBUG:\n"
        info += "• Built-in airports: \(self.builtInAirports.count)\n"
        info += "• User-added airports: \(self.userAddedAirports.count)\n"
        info += "• Total airports: \(self.builtInAirports.count + self.userAddedAirports.count)\n"
        
        if !self.userAddedAirports.isEmpty {
            info += "• User airports:\n"
            for (icao, airport) in self.userAddedAirports.sorted(by: { $0.key < $1.key }) {
                info += "  - \(icao): \(airport.name)\n"
            }
        }
        
        return info
    }
}

// MARK: - Airport Info Model
struct AirportInfo: Codable, Identifiable {
    let id = UUID()
    let icaoCode: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let timeZone: String?
    let source: AirportSource
    let dateAdded: Date
    
    enum CodingKeys: String, CodingKey {
        case icaoCode, name, timeZone, source, dateAdded
        case latitude, longitude
    }
    
    init(icaoCode: String, name: String, coordinate: CLLocationCoordinate2D, timeZone: String?, source: AirportSource, dateAdded: Date) {
        self.icaoCode = icaoCode
        self.name = name
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.source = source
        self.dateAdded = dateAdded
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icaoCode = try container.decode(String.self, forKey: .icaoCode)
        name = try container.decode(String.self, forKey: .name)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
        source = try container.decode(AirportSource.self, forKey: .source)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(icaoCode, forKey: .icaoCode)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(timeZone, forKey: .timeZone)
        try container.encode(source, forKey: .source)
        try container.encode(dateAdded, forKey: .dateAdded)
    }
}

enum AirportSource: String, Codable {
    case builtIn = "Built-in"
    case userAdded = "User Added"
    case openFlights = "OpenFlights"
    case aviationAPI = "Aviation API"
    case csvImport = "CSV Import"
    
    var icon: String {
        switch self {
        case .builtIn: return "airplane"
        case .userAdded: return "person.crop.circle.badge.plus"
        case .openFlights: return "globe"
        case .aviationAPI: return "antenna.radiowaves.left.and.right"
        case .csvImport: return "doc.text"
        }
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}


// MARK: - Airport Management UI
struct AirportManagementView: View {
    @StateObject private var airportManager = AirportDatabaseManager()
    @State private var showingAddAirport = false
    @State private var showingImportCSV = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search airports...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Airport List
                List {
                    let airports = searchText.isEmpty ?
                        airportManager.getAllAirports() :
                        airportManager.searchAirports(searchText)
                    
                    ForEach(airports) { airport in
                        AirportRowView(airport: airport, manager: airportManager)
                    }
                }
                .listStyle(.insetGrouped)
                .background(LogbookTheme.navy)
                .scrollContentBackground(.hidden)
                
                // Status Message
                if !airportManager.lookupStatus.isEmpty {
                    HStack {
                        if airportManager.isLookingUpAirport {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(airportManager.lookupStatus)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Airport Database")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddAirport = true }) {
                            Label("Add Airport Manually", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingImportCSV = true }) {
                            Label("Import from CSV", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAirport) {
            AddAirportView(manager: airportManager)
        }
        .sheet(isPresented: $showingImportCSV) {
            ImportCSVView(manager: airportManager)
        }
    }
}

// MARK: - Airport Row View
struct AirportRowView: View {
    let airport: AirportInfo
    let manager: AirportDatabaseManager
    @State private var showingLookup = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(airport.icaoCode)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: airport.source.icon)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(airport.source.rawValue)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Text(airport.name)
                .font(.subheadline)
                .foregroundColor(LogbookTheme.accentBlue)
            
            HStack {
                Text("Lat: \(String(format: "%.4f", airport.coordinate.latitude))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Lon: \(String(format: "%.4f", airport.coordinate.longitude))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if airport.source == .userAdded {
                    Button("Remove") {
                        manager.removeUserAirport(airport.icaoCode)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(LogbookTheme.navyLight)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if airport.source == .userAdded {
                Button("Delete", role: .destructive) {
                    manager.removeUserAirport(airport.icaoCode)
                }
            }
            
            Button("Lookup") {
                Task {
                    await manager.lookupAirport(icaoCode: airport.icaoCode)
                }
            }
            .tint(.blue)
        }
    }
}

// MARK: - Add Airport View
struct AddAirportView: View {
    let manager: AirportDatabaseManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var icaoCode = ""
    @State private var airportName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var timeZone = ""
    @State private var autoLookup = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Airport Information") {
                    TextField("ICAO Code (e.g., KJFK)", text: $icaoCode)
                        .autocapitalization(.allCharacters)
                        .onChange(of: icaoCode) { oldValue, newValue in
                            if newValue.count == 4 && autoLookup {
                                Task {
                                    await performAutoLookup()
                                }
                            }
                        }
                    
                    TextField("Airport Name", text: $airportName)
                    
                    Toggle("Auto-lookup when ICAO entered", isOn: $autoLookup)
                }
                
                Section("Coordinates") {
                    TextField("Latitude (e.g., 40.6413)", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Longitude (e.g., -73.7781)", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                Section("Optional") {
                    TextField("Time Zone (e.g., America/New_York)", text: $timeZone)
                }
                
                Section {
                    Button("Add Airport") {
                        addAirport()
                    }
                    .disabled(!isValidInput)
                }
            }
            .navigationTitle("Add Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        !icaoCode.isEmpty &&
        !airportName.isEmpty &&
        Double(latitude) != nil &&
        Double(longitude) != nil
    }
    
    private func performAutoLookup() async {
        guard let airport = await manager.lookupAirport(icaoCode: icaoCode) else { return }
        
        await MainActor.run {
            airportName = airport.name
            latitude = String(format: "%.6f", airport.coordinate.latitude)
            longitude = String(format: "%.6f", airport.coordinate.longitude)
            timeZone = airport.timeZone ?? ""
        }
    }
    
    private func addAirport() {
        guard let lat = Double(latitude), let lon = Double(longitude) else { return }
        
        manager.addAirport(
            icaoCode: icaoCode,
            name: airportName,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timeZone: timeZone.isEmpty ? nil : timeZone
        )
        
        dismiss()
    }
}

// MARK: - Import CSV View
struct ImportCSVView: View {
    let manager: AirportDatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var importStatus = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Airport Database")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("CSV Format: ICAO,Name,Latitude,Longitude,Timezone")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Choose CSV File") {
                    showingFilePicker = true
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                if !importStatus.isEmpty {
                    Text(importStatus)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Import Airports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let csvData = try String(contentsOf: url, encoding: .utf8)
                let importCount = manager.importAirportsFromCSV(csvData)
                importStatus = "✅ Imported \(importCount) airports"
            } catch {
                importStatus = "❌ Error: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importStatus = "❌ Import failed: \(error.localizedDescription)"
        }
    }
}

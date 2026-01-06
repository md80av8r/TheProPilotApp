import Foundation
import CoreLocation
import SwiftUI
import CloudKit

// MARK: - Airport Source Enum
enum AirportSource: String, Codable {
    case builtIn = "Built-in"
    case userAdded = "User Added"
    case openFlights = "OpenFlights"
    case aviationAPI = "Aviation API"
    case csvImport = "CSV Import"
    case cloudKit = "CloudKit"
}

// MARK: - Preferred FBO Info (User-selected per airport)
struct PreferredFBO: Codable, Identifiable {
    var id: String { airportCode }
    let airportCode: String
    var fboName: String
    var unicomFrequency: String?
    var phoneNumber: String?
    var notes: String?
    var notifyAtDistance: Double  // nautical miles (default 120)
    var lastUpdated: Date

    init(airportCode: String, fboName: String, unicomFrequency: String? = nil, phoneNumber: String? = nil, notes: String? = nil, notifyAtDistance: Double = 120, lastUpdated: Date = Date()) {
        self.airportCode = airportCode
        self.fboName = fboName
        self.unicomFrequency = unicomFrequency
        self.phoneNumber = phoneNumber
        self.notes = notes
        self.notifyAtDistance = notifyAtDistance
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Crowdsourced FBO Data (CloudKit synced)
struct CrowdsourcedFBO: Codable, Identifiable {
    let id: UUID
    let airportCode: String
    var name: String
    var phoneNumber: String?
    var unicomFrequency: String?
    var website: String?

    // Fuel Prices
    var jetAPrice: Double?
    var avGasPrice: Double?
    var fuelPriceDate: Date?
    var fuelPriceReporter: String?

    // Amenities
    var hasCrewCars: Bool
    var hasCrewLounge: Bool
    var hasCatering: Bool
    var hasMaintenance: Bool
    var hasHangars: Bool
    var hasDeice: Bool
    var hasOxygen: Bool
    var hasGPU: Bool
    var hasLav: Bool

    // Fees
    var handlingFee: Double?
    var overnightFee: Double?
    var rampFee: Double?
    var rampFeeWaived: Bool  // waived with fuel purchase

    // Ratings
    var averageRating: Double?
    var ratingCount: Int?

    // Metadata
    var lastUpdated: Date
    var updatedBy: String?
    var cloudKitRecordID: String?
    var isVerified: Bool

    init(
        id: UUID = UUID(),
        airportCode: String,
        name: String,
        phoneNumber: String? = nil,
        unicomFrequency: String? = nil,
        website: String? = nil,
        jetAPrice: Double? = nil,
        avGasPrice: Double? = nil,
        fuelPriceDate: Date? = nil,
        fuelPriceReporter: String? = nil,
        hasCrewCars: Bool = false,
        hasCrewLounge: Bool = false,
        hasCatering: Bool = false,
        hasMaintenance: Bool = false,
        hasHangars: Bool = false,
        hasDeice: Bool = false,
        hasOxygen: Bool = false,
        hasGPU: Bool = false,
        hasLav: Bool = false,
        handlingFee: Double? = nil,
        overnightFee: Double? = nil,
        rampFee: Double? = nil,
        rampFeeWaived: Bool = false,
        averageRating: Double? = nil,
        ratingCount: Int? = nil,
        lastUpdated: Date = Date(),
        updatedBy: String? = nil,
        cloudKitRecordID: String? = nil,
        isVerified: Bool = false
    ) {
        self.id = id
        self.airportCode = airportCode
        self.name = name
        self.phoneNumber = phoneNumber
        self.unicomFrequency = unicomFrequency
        self.website = website
        self.jetAPrice = jetAPrice
        self.avGasPrice = avGasPrice
        self.fuelPriceDate = fuelPriceDate
        self.fuelPriceReporter = fuelPriceReporter
        self.hasCrewCars = hasCrewCars
        self.hasCrewLounge = hasCrewLounge
        self.hasCatering = hasCatering
        self.hasMaintenance = hasMaintenance
        self.hasHangars = hasHangars
        self.hasDeice = hasDeice
        self.hasOxygen = hasOxygen
        self.hasGPU = hasGPU
        self.hasLav = hasLav
        self.handlingFee = handlingFee
        self.overnightFee = overnightFee
        self.rampFee = rampFee
        self.rampFeeWaived = rampFeeWaived
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.lastUpdated = lastUpdated
        self.updatedBy = updatedBy
        self.cloudKitRecordID = cloudKitRecordID
        self.isVerified = isVerified
    }

    /// Format fuel price age for display
    var fuelPriceAge: String? {
        guard let date = fuelPriceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) weeks ago" }
        return "\(days / 30) months ago"
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
    var averageRating: Double?
    var reviewCount: Int?

    // Frequency Data (optional, from CloudKit or user-set)
    var towerFrequency: String?
    var groundFrequency: String?
    var atisFrequency: String?
    var unicomFrequency: String?
    var ctafFrequency: String?

    // Location Details (from CloudKit enrichment)
    var city: String?
    var state: String?              // State/province code (e.g., "MI", "ON")
    var stateName: String?          // Full state/province name (e.g., "Michigan", "Ontario")
    var countryCode: String?        // ISO country code (e.g., "US", "CA")
    var countryName: String?        // Full country name (e.g., "United States", "Canada")
    var regionName: String?         // Full region name (same as stateName for most cases)
    var elevation: String?          // Elevation string (e.g., "1234 ft")
    var elevationFeet: Int?         // Elevation in feet (numeric)

    // Runway Data (from CloudKit)
    var longestRunway: Int?         // Longest runway in feet
    var runwaySurface: String?      // Surface type (e.g., "ASP", "CON")
    var allRunways: String?         // Pipe-delimited runway info: "09/27:6000'ASP|18/36:4500'CON"
    var hasLightedRunway: Bool?

    // All Frequencies (from CloudKit - pipe-delimited)
    var allFrequencies: String?     // Pipe-delimited: "TWR:118.7|GND:121.9|ATIS:127.25"

    // Navaid Data (from CloudKit)
    var navaids: String?            // Pipe-delimited: "DTW:VOR:117.4|DXO:NDB:344"
    var navaidCount: Int?
    var vorIdent: String?           // Primary VOR identifier
    var vorFrequency: String?       // Primary VOR frequency
    var ndbIdent: String?           // Primary NDB identifier
    var ndbFrequency: String?       // Primary NDB frequency
    var dmeIdent: String?           // Primary DME identifier
    var dmeChannel: String?         // Primary DME channel

    // Local Comments/Tips (from CloudKit)
    var localComments: String?      // Pipe-delimited local pilot tips
    var commentCount: Int?

    // External Links (from CloudKit)
    var wikipediaLink: String?      // Wikipedia article URL
    var homeLink: String?           // Airport's official website

    enum CodingKeys: String, CodingKey {
        case icaoCode, name, timeZone, source, dateAdded, latitude, longitude, averageRating, reviewCount
        case towerFrequency, groundFrequency, atisFrequency, unicomFrequency, ctafFrequency
        case city, state, stateName, countryCode, countryName, regionName, elevation, elevationFeet
        case longestRunway, runwaySurface, allRunways, hasLightedRunway, allFrequencies
        case navaids, navaidCount, vorIdent, vorFrequency, ndbIdent, ndbFrequency, dmeIdent, dmeChannel
        case localComments, commentCount, wikipediaLink, homeLink
    }

    init(icaoCode: String, name: String, coordinate: CLLocationCoordinate2D, timeZone: String? = nil, source: AirportSource = .csvImport, dateAdded: Date = Date(), averageRating: Double? = nil, reviewCount: Int? = nil, towerFrequency: String? = nil, groundFrequency: String? = nil, atisFrequency: String? = nil, unicomFrequency: String? = nil, ctafFrequency: String? = nil, city: String? = nil, state: String? = nil, stateName: String? = nil, countryCode: String? = nil, countryName: String? = nil, regionName: String? = nil, elevation: String? = nil, elevationFeet: Int? = nil, longestRunway: Int? = nil, runwaySurface: String? = nil, allRunways: String? = nil, hasLightedRunway: Bool? = nil, allFrequencies: String? = nil, navaids: String? = nil, navaidCount: Int? = nil, vorIdent: String? = nil, vorFrequency: String? = nil, ndbIdent: String? = nil, ndbFrequency: String? = nil, dmeIdent: String? = nil, dmeChannel: String? = nil, localComments: String? = nil, commentCount: Int? = nil, wikipediaLink: String? = nil, homeLink: String? = nil) {
        self.icaoCode = icaoCode
        self.name = name
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.source = source
        self.dateAdded = dateAdded
        self.averageRating = averageRating
        self.reviewCount = reviewCount
        self.towerFrequency = towerFrequency
        self.groundFrequency = groundFrequency
        self.atisFrequency = atisFrequency
        self.unicomFrequency = unicomFrequency
        self.ctafFrequency = ctafFrequency
        self.city = city
        self.state = state
        self.stateName = stateName
        self.countryCode = countryCode
        self.countryName = countryName
        self.regionName = regionName
        self.elevation = elevation
        self.elevationFeet = elevationFeet
        self.longestRunway = longestRunway
        self.runwaySurface = runwaySurface
        self.allRunways = allRunways
        self.hasLightedRunway = hasLightedRunway
        self.allFrequencies = allFrequencies
        self.navaids = navaids
        self.navaidCount = navaidCount
        self.vorIdent = vorIdent
        self.vorFrequency = vorFrequency
        self.ndbIdent = ndbIdent
        self.ndbFrequency = ndbFrequency
        self.dmeIdent = dmeIdent
        self.dmeChannel = dmeChannel
        self.localComments = localComments
        self.commentCount = commentCount
        self.wikipediaLink = wikipediaLink
        self.homeLink = homeLink
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icaoCode = try c.decode(String.self, forKey: .icaoCode)
        name = try c.decode(String.self, forKey: .name)
        let lat = try c.decode(Double.self, forKey: .latitude)
        let lon = try c.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone)
        source = try c.decode(AirportSource.self, forKey: .source)
        dateAdded = try c.decode(Date.self, forKey: .dateAdded)
        averageRating = try c.decodeIfPresent(Double.self, forKey: .averageRating)
        reviewCount = try c.decodeIfPresent(Int.self, forKey: .reviewCount)
        towerFrequency = try c.decodeIfPresent(String.self, forKey: .towerFrequency)
        groundFrequency = try c.decodeIfPresent(String.self, forKey: .groundFrequency)
        atisFrequency = try c.decodeIfPresent(String.self, forKey: .atisFrequency)
        unicomFrequency = try c.decodeIfPresent(String.self, forKey: .unicomFrequency)
        ctafFrequency = try c.decodeIfPresent(String.self, forKey: .ctafFrequency)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        stateName = try c.decodeIfPresent(String.self, forKey: .stateName)
        countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode)
        countryName = try c.decodeIfPresent(String.self, forKey: .countryName)
        regionName = try c.decodeIfPresent(String.self, forKey: .regionName)
        elevation = try c.decodeIfPresent(String.self, forKey: .elevation)
        elevationFeet = try c.decodeIfPresent(Int.self, forKey: .elevationFeet)
        longestRunway = try c.decodeIfPresent(Int.self, forKey: .longestRunway)
        runwaySurface = try c.decodeIfPresent(String.self, forKey: .runwaySurface)
        allRunways = try c.decodeIfPresent(String.self, forKey: .allRunways)
        hasLightedRunway = try c.decodeIfPresent(Bool.self, forKey: .hasLightedRunway)
        allFrequencies = try c.decodeIfPresent(String.self, forKey: .allFrequencies)
        navaids = try c.decodeIfPresent(String.self, forKey: .navaids)
        navaidCount = try c.decodeIfPresent(Int.self, forKey: .navaidCount)
        vorIdent = try c.decodeIfPresent(String.self, forKey: .vorIdent)
        vorFrequency = try c.decodeIfPresent(String.self, forKey: .vorFrequency)
        ndbIdent = try c.decodeIfPresent(String.self, forKey: .ndbIdent)
        ndbFrequency = try c.decodeIfPresent(String.self, forKey: .ndbFrequency)
        dmeIdent = try c.decodeIfPresent(String.self, forKey: .dmeIdent)
        dmeChannel = try c.decodeIfPresent(String.self, forKey: .dmeChannel)
        localComments = try c.decodeIfPresent(String.self, forKey: .localComments)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        wikipediaLink = try c.decodeIfPresent(String.self, forKey: .wikipediaLink)
        homeLink = try c.decodeIfPresent(String.self, forKey: .homeLink)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(icaoCode, forKey: .icaoCode)
        try c.encode(name, forKey: .name)
        try c.encode(coordinate.latitude, forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
        try c.encodeIfPresent(timeZone, forKey: .timeZone)
        try c.encode(source, forKey: .source)
        try c.encode(dateAdded, forKey: .dateAdded)
        try c.encodeIfPresent(averageRating, forKey: .averageRating)
        try c.encodeIfPresent(reviewCount, forKey: .reviewCount)
        try c.encodeIfPresent(towerFrequency, forKey: .towerFrequency)
        try c.encodeIfPresent(groundFrequency, forKey: .groundFrequency)
        try c.encodeIfPresent(atisFrequency, forKey: .atisFrequency)
        try c.encodeIfPresent(unicomFrequency, forKey: .unicomFrequency)
        try c.encodeIfPresent(ctafFrequency, forKey: .ctafFrequency)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(stateName, forKey: .stateName)
        try c.encodeIfPresent(countryCode, forKey: .countryCode)
        try c.encodeIfPresent(countryName, forKey: .countryName)
        try c.encodeIfPresent(regionName, forKey: .regionName)
        try c.encodeIfPresent(elevation, forKey: .elevation)
        try c.encodeIfPresent(elevationFeet, forKey: .elevationFeet)
        try c.encodeIfPresent(longestRunway, forKey: .longestRunway)
        try c.encodeIfPresent(runwaySurface, forKey: .runwaySurface)
        try c.encodeIfPresent(allRunways, forKey: .allRunways)
        try c.encodeIfPresent(hasLightedRunway, forKey: .hasLightedRunway)
        try c.encodeIfPresent(allFrequencies, forKey: .allFrequencies)
        try c.encodeIfPresent(navaids, forKey: .navaids)
        try c.encodeIfPresent(navaidCount, forKey: .navaidCount)
        try c.encodeIfPresent(vorIdent, forKey: .vorIdent)
        try c.encodeIfPresent(vorFrequency, forKey: .vorFrequency)
        try c.encodeIfPresent(ndbIdent, forKey: .ndbIdent)
        try c.encodeIfPresent(ndbFrequency, forKey: .ndbFrequency)
        try c.encodeIfPresent(dmeIdent, forKey: .dmeIdent)
        try c.encodeIfPresent(dmeChannel, forKey: .dmeChannel)
        try c.encodeIfPresent(localComments, forKey: .localComments)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
        try c.encodeIfPresent(wikipediaLink, forKey: .wikipediaLink)
        try c.encodeIfPresent(homeLink, forKey: .homeLink)
    }

    /// Get the primary contact frequency (UNICOM or CTAF for non-towered, Tower for towered)
    var primaryContactFrequency: String? {
        unicomFrequency ?? ctafFrequency ?? towerFrequency
    }

    /// Get display-friendly location string (e.g., "Detroit, Michigan, United States")
    var locationString: String {
        var parts: [String] = []
        if let city = city, !city.isEmpty { parts.append(city) }
        if let stateName = stateName, !stateName.isEmpty { parts.append(stateName) }
        else if let state = state, !state.isEmpty { parts.append(state) }
        if let countryName = countryName, !countryName.isEmpty { parts.append(countryName) }
        else if let countryCode = countryCode, !countryCode.isEmpty { parts.append(countryCode) }
        return parts.joined(separator: ", ")
    }

    /// Get parsed runway list from allRunways string
    var parsedRunways: [(name: String, length: String, surface: String)] {
        guard let runways = allRunways, !runways.isEmpty else { return [] }
        return runways.components(separatedBy: "|").compactMap { runway in
            // Format: "09/27:6000'ASP"
            let parts = runway.components(separatedBy: ":")
            guard parts.count >= 2 else { return nil }
            let name = parts[0]
            let details = parts[1]
            // Parse length and surface from "6000'ASP"
            if let apostropheIndex = details.firstIndex(of: "'") {
                let length = String(details[..<apostropheIndex])
                let surface = String(details[details.index(after: apostropheIndex)...])
                return (name: name, length: length + " ft", surface: surface)
            }
            return (name: name, length: details, surface: "")
        }
    }

    /// Get parsed frequency list from allFrequencies string
    var parsedFrequencies: [(type: String, frequency: String)] {
        guard let freqs = allFrequencies, !freqs.isEmpty else { return [] }
        return freqs.components(separatedBy: "|").compactMap { freq in
            // Format: "TWR:118.7"
            let parts = freq.components(separatedBy: ":")
            guard parts.count >= 2 else { return nil }
            return (type: parts[0], frequency: parts[1])
        }
    }

    /// Get parsed navaid list from navaids string
    var parsedNavaids: [(ident: String, type: String, frequency: String)] {
        guard let navs = navaids, !navs.isEmpty else { return [] }
        return navs.components(separatedBy: "|").compactMap { nav in
            // Format: "DTW:VOR:117.4"
            let parts = nav.components(separatedBy: ":")
            guard parts.count >= 3 else { return nil }
            return (ident: parts[0], type: parts[1], frequency: parts[2])
        }
    }

    /// Get parsed local comments
    var parsedComments: [String] {
        guard let comments = localComments, !comments.isEmpty else { return [] }
        return comments.components(separatedBy: " | ").filter { !$0.isEmpty }
    }
}

extension AirportInfo: Equatable {
    static func == (lhs: AirportInfo, rhs: AirportInfo) -> Bool {
        lhs.icaoCode == rhs.icaoCode
    }
}

extension AirportInfo: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(icaoCode)
    }
}

// MARK: - Pilot Review Model (maps to CloudKit PilotReview schema)
struct PilotReview: Codable, Identifiable {
    let id: UUID
    let airportCode: String
    let pilotName: String
    let rating: Int // 1-5 stars
    let content: String // Review text
    let title: String?
    let date: Date
    
    // FBO Details
    var fboName: String?
    var fuelPrice: Double?
    var crewCarAvailable: Bool?
    var crewCarNotes: String?
    var serviceQuality: Int? // 1-5
    
    // Amenities
    var fboHasCrewCars: Bool?
    var fboHasCrewLounge: Bool?
    var fboHasCatering: Bool?
    var fboHasMaintenance: Bool?
    var fboHasHangars: Bool?
    var fboHasDeice: Bool?
    
    // Costs
    var handlingFee: Double?
    var fboHangarCost: Double?
    
    // Flight Details
    var aircraftType: String?
    var operatorName: String?
    var runwayUsed: String?
    var approachUsed: String?
    var winds: String?
    var visibility: String?
    var waitTimeMinutes: Int?
    
    // Metadata
    var remarks: String?
    var tags: [String]?
    var helpfulCount: Int?
    var isFlagged: Bool?
    var cloudKitRecordID: String?
    
    init(id: UUID = UUID(), airportCode: String, pilotName: String, rating: Int, content: String, title: String? = nil, date: Date = Date(), fboName: String? = nil, fuelPrice: Double? = nil, crewCarAvailable: Bool? = nil, cloudKitRecordID: String? = nil) {
        self.id = id
        self.airportCode = airportCode
        self.pilotName = pilotName
        self.rating = rating
        self.content = content
        self.title = title
        self.date = date
        self.fboName = fboName
        self.fuelPrice = fuelPrice
        self.crewCarAvailable = crewCarAvailable
        self.cloudKitRecordID = cloudKitRecordID
    }
}

// MARK: - Airport Database Manager
class AirportDatabaseManager: ObservableObject {
    static let shared = AirportDatabaseManager()
    
    @Published var airports: [String: AirportInfo] = [:]  // ICAO code -> AirportInfo
    @Published var pilotReviews: [String: [PilotReview]] = [:]  // ICAO code -> Reviews
    @Published var preferredFBOs: [String: PreferredFBO] = [:]  // ICAO code -> Preferred FBO
    @Published var crowdsourcedFBOs: [String: [CrowdsourcedFBO]] = [:]  // ICAO code -> FBOs at airport
    @Published var isLoading = false
    @Published var loadingMessage: String = ""
    @Published var lastDatabaseUpdate: Date?

    private let container = CKContainer(identifier: "iCloud.com.jkadans.TheProPilotApp")
    private let cacheKey = "CachedAirportDatabase"
    private let reviewsCacheKey = "CachedPilotReviews"
    private let preferredFBOsCacheKey = "CachedPreferredFBOs"
    private let crowdsourcedFBOsCacheKey = "CachedCrowdsourcedFBOs"
    private let lastUpdateKey = "AirportDatabaseLastUpdate"
    private let userDefaults = UserDefaults.shared
    private let csvLoadedKey = "CSVAirportsLoaded"
    private let fboCSVLoadedKey = "CSVFBOsLoaded"
    private let fboCSVVersionKey = "CSVFBOsVersion"
    private let currentFBOCSVVersion = 4  // Increment this when CSV data changes (v4: fixed duplicate FBO loading)

    private init() {
        loadLocalData()
        loadFBOsFromCSV()  // Load bundled FBOs before cached ones
        loadCachedPreferredFBOs()
        loadCachedCrowdsourcedFBOs()
    }
    
    // MARK: - Initialization & Loading
    
    /// Load airports from local CSV and cached CloudKit data
    private func loadLocalData() {
        // 1. Load CSV if not already loaded
        if !userDefaults.bool(forKey: csvLoadedKey) {
            // Clear any bad cache data from previous versions
            userDefaults.removeObject(forKey: cacheKey)
            userDefaults.removeObject(forKey: lastUpdateKey)
            
            loadAirportsFromCSV()
            userDefaults.set(true, forKey: csvLoadedKey)
        } else {
            // Load from cache
            loadCachedAirports()
        }
        
        // 2. Load cached reviews
        loadCachedReviews()
        
        // 3. Check for CloudKit updates if it's been a while
        checkForCloudKitUpdates()
    }
    
    /// Load airports from local CSV file (propilot_airports.csv)
    private func loadAirportsFromCSV() {
        print("📦 Loading airports from CSV...")
        
        guard let url = Bundle.main.url(forResource: "propilot_airports", withExtension: "csv") else {
            print("❌ propilot_airports.csv not found in bundle")
            print("   Please add propilot_airports.csv to your Xcode target")
            print("   Check Build Phases → Copy Bundle Resources")
            return
        }
        
        print("✅ Found CSV file at: \(url.path)")
        
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines)
            
            var loadedAirports: [AirportInfo] = []
            var icaoCodeCounts: [String: Int] = [:]  // Track duplicates
            
            // Skip header (line 0)
            for line in lines.dropFirst() {
                guard !line.isEmpty else { continue }
                
                let columns = line.components(separatedBy: ",")
                guard columns.count >= 13 else { continue }
                
                // CSV columns: id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,continent,iso_country,iso_region,municipality,scheduled_service,icao_code,iata_code
                let name = columns[3].trimmingCharacters(in: .whitespaces)
                let latStr = columns[4]
                let lonStr = columns[5]
                let icaoCode = columns[12].trimmingCharacters(in: .whitespaces).uppercased()
                
                // Skip if missing ICAO code or coordinates
                guard !icaoCode.isEmpty,
                      icaoCode.count >= 3,  // Valid ICAO codes are 3-4 characters
                      icaoCode.count <= 4,
                      let lat = Double(latStr),
                      let lon = Double(lonStr) else {
                    continue
                }
                
                // Track duplicate count
                icaoCodeCounts[icaoCode, default: 0] += 1
                
                let airport = AirportInfo(
                    icaoCode: icaoCode,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    timeZone: nil,
                    source: .csvImport,
                    dateAdded: Date()
                )
                
                loadedAirports.append(airport)
            }
            
            // Log duplicates
            let duplicates = icaoCodeCounts.filter { $0.value > 1 }
            if !duplicates.isEmpty {
                print("⚠️ Found \(duplicates.count) duplicate ICAO codes in CSV:")
                for (code, count) in duplicates.prefix(10) {
                    print("   - \(code): \(count) occurrences")
                }
            }
            
            DispatchQueue.main.async {
                // Handle duplicates by keeping the first occurrence
                var uniqueAirports: [String: AirportInfo] = [:]
                for airport in loadedAirports {
                    // Only add if key doesn't exist yet
                    if uniqueAirports[airport.icaoCode] == nil {
                        uniqueAirports[airport.icaoCode] = airport
                    }
                }
                
                self.airports = uniqueAirports
                self.cacheAirports()
                print("✅ Loaded \(uniqueAirports.count) unique airports from CSV (filtered from \(loadedAirports.count) total)")
            }
            
        } catch {
            print("❌ Failed to load CSV: \(error)")
        }
    }

    /// Load FBOs from local CSV file (propilot_fbos.csv)
    private func loadFBOsFromCSV() {
        // Check if we need to reload (new version or never loaded)
        let loadedVersion = userDefaults.integer(forKey: fboCSVVersionKey)
        guard loadedVersion < currentFBOCSVVersion else {
            print("📦 FBO CSV v\(loadedVersion) already loaded, skipping")
            return
        }

        if loadedVersion > 0 {
            print("📦 FBO CSV updated: v\(loadedVersion) -> v\(currentFBOCSVVersion), reloading...")
            // Clear potentially corrupted FBO cache when upgrading versions
            // This ensures we start fresh with deduplicated data
            crowdsourcedFBOs.removeAll()
            userDefaults.removeObject(forKey: crowdsourcedFBOsCacheKey)
            print("🧹 Cleared old FBO cache to fix duplicates")
        }

        print("📦 Loading FBOs from CSV...")

        guard let url = Bundle.main.url(forResource: "propilot_fbos", withExtension: "csv") else {
            print("⚠️ propilot_fbos.csv not found in bundle (optional)")
            return
        }

        print("✅ Found FBO CSV file at: \(url.path)")

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines)

            var loadedFBOs: [String: [CrowdsourcedFBO]] = [:]
            var fboCount = 0

            // Skip header (line 0)
            // Header: airport_code,name,phone,unicom,website,jet_a_price,avgas_price,crew_cars,crew_lounge,catering,maintenance,hangars,deice,oxygen,gpu,lav,handling_fee,overnight_fee,ramp_fee,ramp_fee_waived
            for line in lines.dropFirst() {
                guard !line.isEmpty else { continue }

                let columns = parseCSVLine(line)
                guard columns.count >= 20 else { continue }

                let airportCode = columns[0].trimmingCharacters(in: .whitespaces).uppercased()
                let name = columns[1].trimmingCharacters(in: .whitespaces)

                guard !airportCode.isEmpty, !name.isEmpty else { continue }

                // Helper to parse boolean values from CSV (handles "1", "Yes", "true", etc.)
                func parseBool(_ value: String) -> Bool {
                    let v = value.lowercased().trimmingCharacters(in: .whitespaces)
                    return v == "1" || v == "yes" || v == "true"
                }

                let phone = columns[2].isEmpty ? nil : columns[2]
                let unicom = columns[3].isEmpty ? nil : columns[3]

                // Debug: log FBOs with unicom frequencies
                if unicom != nil {
                    print("📻 CSV FBO: \(airportCode) - \(name) - UNICOM: \(unicom!)")
                }

                let fbo = CrowdsourcedFBO(
                    id: UUID(),
                    airportCode: airportCode,
                    name: name,
                    phoneNumber: phone,
                    unicomFrequency: unicom,
                    website: columns[4].isEmpty ? nil : columns[4],
                    jetAPrice: Double(columns[5]),
                    avGasPrice: Double(columns[6]),
                    fuelPriceDate: nil,
                    fuelPriceReporter: nil,
                    hasCrewCars: parseBool(columns[7]),
                    hasCrewLounge: parseBool(columns[8]),
                    hasCatering: parseBool(columns[9]),
                    hasMaintenance: parseBool(columns[10]),
                    hasHangars: parseBool(columns[11]),
                    hasDeice: parseBool(columns[12]),
                    hasOxygen: parseBool(columns[13]),
                    hasGPU: parseBool(columns[14]),
                    hasLav: parseBool(columns[15]),
                    handlingFee: Double(columns[16]),
                    overnightFee: Double(columns[17]),
                    rampFee: Double(columns[18]),
                    rampFeeWaived: parseBool(columns[19]),
                    averageRating: nil,
                    ratingCount: nil,
                    lastUpdated: Date(),
                    updatedBy: "CSV Import",
                    cloudKitRecordID: nil,
                    isVerified: true  // CSV entries are verified
                )

                if loadedFBOs[airportCode] == nil {
                    loadedFBOs[airportCode] = []
                }
                loadedFBOs[airportCode]?.append(fbo)
                fboCount += 1
            }

            DispatchQueue.main.async {
                // Helper to normalize FBO names for matching (same logic as mergeFBOData)
                func normalizeName(_ name: String) -> String {
                    return name.lowercased()
                        .replacingOccurrences(of: "aviation", with: "")
                        .replacingOccurrences(of: "fbo", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "  ", with: " ")
                }

                // Merge with existing FBOs (don't overwrite user entries)
                for (airport, fbos) in loadedFBOs {
                    if self.crowdsourcedFBOs[airport] == nil {
                        self.crowdsourcedFBOs[airport] = fbos
                    } else {
                        // Add CSV FBOs that aren't already present (by normalized name)
                        let existingNormalizedNames = Set(self.crowdsourcedFBOs[airport]?.map { normalizeName($0.name) } ?? [])
                        for fbo in fbos where !existingNormalizedNames.contains(normalizeName(fbo.name)) {
                            self.crowdsourcedFBOs[airport]?.append(fbo)
                        }
                    }
                }
                self.cacheCrowdsourcedFBOs()
                self.userDefaults.set(self.currentFBOCSVVersion, forKey: self.fboCSVVersionKey)
                print("✅ Loaded \(fboCount) FBOs from CSV v\(self.currentFBOCSVVersion) for \(loadedFBOs.count) airports")
            }

        } catch {
            print("❌ Failed to load FBO CSV: \(error)")
        }
    }

    /// Parse a CSV line handling quoted fields with commas
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    /// Load cached airports from UserDefaults
    private func loadCachedAirports() {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("📦 No cached airports found")
            return
        }
        
        do {
            let airportList = try JSONDecoder().decode([AirportInfo].self, from: data)
            DispatchQueue.main.async {
                // Handle duplicates by keeping the first occurrence
                var uniqueAirports: [String: AirportInfo] = [:]
                for airport in airportList {
                    if uniqueAirports[airport.icaoCode] == nil {
                        uniqueAirports[airport.icaoCode] = airport
                    }
                }
                
                self.airports = uniqueAirports
                self.lastDatabaseUpdate = self.userDefaults.object(forKey: self.lastUpdateKey) as? Date
                print("📦 Loaded \(uniqueAirports.count) airports from cache")
            }
        } catch {
            print("❌ Failed to load cached airports: \(error)")
        }
    }
    
    /// Cache airports to UserDefaults
    private func cacheAirports() {
        do {
            let airportList = Array(airports.values)
            let data = try JSONEncoder().encode(airportList)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: lastUpdateKey)
            print("💾 Cached \(airportList.count) airports")
        } catch {
            print("❌ Failed to cache airports: \(error)")
        }
    }
    
    // MARK: - CloudKit Updates
    
    /// Check if CloudKit has updates (call this periodically)
    private func checkForCloudKitUpdates() {
        // Only update once per day
        if let lastUpdate = lastDatabaseUpdate,
           Date().timeIntervalSince(lastUpdate) < 86400 {  // 24 hours
            print("📡 CloudKit check skipped - updated recently")
            return
        }
        
        Task {
            await fetchCloudKitUpdates()
        }
    }
    
    /// Fetch airport updates from CloudKit
    func fetchCloudKitUpdates() async {
        print("📡 Checking CloudKit for airport updates...")
        
        await MainActor.run {
            isLoading = true
            loadingMessage = "Checking for airport updates..."
        }
        
        do {
            let publicDB = container.publicCloudDatabase
            
            // ✅ FIX: Use NSPredicate(value: true) to fetch ALL airports
            // modificationDate is not marked queryable in CloudKit schema
            // For airport database, we want all airports anyway (not just updates)
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Airport", predicate: predicate)

            // ✅ REMOVED: sortDescriptors (system fields can't be sorted in CloudKit)
            // We'll sort in memory after fetching if needed

            print("   Fetching airports from CloudKit Public Database...")
            let results = try await publicDB.records(matching: query)
            var updatedAirports: [AirportInfo] = []

            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let airport = parseCloudKitAirport(record) {
                    updatedAirports.append(airport)
                }
            }

            // ✅ Optional: Sort in memory after fetching (fast for <10K records)
            updatedAirports.sort { $0.icaoCode < $1.icaoCode }

            // Capture the final value for MainActor (Swift 6 concurrency fix)
            let finalAirports = updatedAirports

            await MainActor.run {
                // Merge updates into existing airports
                for airport in finalAirports {
                    self.airports[airport.icaoCode] = airport
                }

                self.cacheAirports()
                self.lastDatabaseUpdate = Date()
                self.isLoading = false
                self.loadingMessage = ""

                print("✅ Updated \(finalAirports.count) airports from CloudKit")
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.loadingMessage = ""
            }
            print("❌ CloudKit update failed: \(error)")
        }
    }
    
    /// Parse CloudKit airport record
    private func parseCloudKitAirport(_ record: CKRecord) -> AirportInfo? {
        guard let icao = record["icaoCode"] as? String ?? record["code"] as? String,
              let name = record["name"] as? String,
              let lat = record["latitude"] as? Double ?? record["lat"] as? Double,
              let lon = record["longitude"] as? Double ?? record["lon"] as? Double else {
            return nil
        }

        let timezone = record["timezoneId"] as? String ?? record["timezone"] as? String
        let avgRating = record["averageRating"] as? Double
        let reviewCount = record["reviewCount"] as? Int

        // Location fields
        let city = record["city"] as? String ?? record["municipality"] as? String
        let state = record["state"] as? String
        let stateName = record["stateName"] as? String ?? record["regionName"] as? String
        let countryCode = record["countryCode"] as? String ?? record["country"] as? String
        let countryName = record["countryName"] as? String
        let regionName = record["regionName"] as? String

        // Elevation
        let elevation = record["elevation"] as? String
        let elevationFeet = record["elevationInteger"] as? Int

        // Runway data
        let longestRunway = record["longestRunway"] as? Int
        let runwaySurface = record["runwaySurface"] as? String
        let allRunways = record["allRunways"] as? String
        let hasLightedRunwayStr = record["hasLightedRunway"] as? String
        let hasLightedRunway = hasLightedRunwayStr == "yes"

        // Frequency data
        let towerFrequency = record["towerFrequency"] as? String
        let groundFrequency = record["groundFrequency"] as? String
        let atisFrequency = record["atisFrequency"] as? String
        let allFrequencies = record["frequencies"] as? String

        // Navaid data
        let navaids = record["navaids"] as? String
        let navaidCount = record["navaidCount"] as? Int
        let vorIdent = record["vorIdent"] as? String
        let vorFrequency = record["vorFrequency"] as? String
        let ndbIdent = record["ndbIdent"] as? String
        let ndbFrequency = record["ndbFrequency"] as? String
        let dmeIdent = record["dmeIdent"] as? String
        let dmeChannel = record["dmeChannel"] as? String

        // Comments
        let localComments = record["localComments"] as? String
        let commentCount = record["commentCount"] as? Int

        // External links
        let wikipediaLink = record["wikipediaLink"] as? String ?? record["wikipedia_link"] as? String
        let homeLink = record["homeLink"] as? String ?? record["home_link"] as? String

        return AirportInfo(
            icaoCode: icao.uppercased(),
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timeZone: timezone,
            source: .cloudKit,
            dateAdded: Date(),
            averageRating: avgRating,
            reviewCount: reviewCount,
            towerFrequency: towerFrequency,
            groundFrequency: groundFrequency,
            atisFrequency: atisFrequency,
            city: city,
            state: state,
            stateName: stateName,
            countryCode: countryCode,
            countryName: countryName,
            regionName: regionName,
            elevation: elevation,
            elevationFeet: elevationFeet,
            longestRunway: longestRunway,
            runwaySurface: runwaySurface,
            allRunways: allRunways,
            hasLightedRunway: hasLightedRunway,
            allFrequencies: allFrequencies,
            navaids: navaids,
            navaidCount: navaidCount,
            vorIdent: vorIdent,
            vorFrequency: vorFrequency,
            ndbIdent: ndbIdent,
            ndbFrequency: ndbFrequency,
            dmeIdent: dmeIdent,
            dmeChannel: dmeChannel,
            localComments: localComments,
            commentCount: commentCount,
            wikipediaLink: wikipediaLink,
            homeLink: homeLink
        )
    }
    
    
    // MARK: - Pilot Reviews
    
    /// Submit a review for an airport
    func submitReview(_ review: PilotReview) async throws {
        print("📝 Submitting review for \(review.airportCode)...")
        
        let publicDB = container.publicCloudDatabase
        let record = CKRecord(recordType: "PilotReview")
        
        // Required fields
        record["airportCode"] = review.airportCode
        record["pilotName"] = review.pilotName
        record["rating"] = review.rating as CKRecordValue
        record["content"] = review.content
        record["date"] = review.date
        
        // Optional fields
        if let title = review.title {
            record["title"] = title
        }
        if let fboName = review.fboName {
            record["fboName"] = fboName
        }
        if let fuelPrice = review.fuelPrice {
            record["fuelPrice"] = fuelPrice as CKRecordValue
        }
        if let crewCarAvailable = review.crewCarAvailable {
            record["crewCarAvailable"] = (crewCarAvailable ? 1 : 0) as CKRecordValue
        }
        if let crewCarNotes = review.crewCarNotes {
            record["crewCarNotes"] = crewCarNotes
        }
        if let serviceQuality = review.serviceQuality {
            record["serviceQuality"] = serviceQuality as CKRecordValue
        }
        
        // Amenities
        if let fboHasCrewCars = review.fboHasCrewCars {
            record["fboHasCrewCars"] = (fboHasCrewCars ? 1 : 0) as CKRecordValue
        }
        if let fboHasCrewLounge = review.fboHasCrewLounge {
            record["fboHasCrewLounge"] = (fboHasCrewLounge ? 1 : 0) as CKRecordValue
        }
        if let fboHasCatering = review.fboHasCatering {
            record["fboHasCatering"] = (fboHasCatering ? 1 : 0) as CKRecordValue
        }
        if let fboHasMaintenance = review.fboHasMaintenance {
            record["fboHasMaintenance"] = (fboHasMaintenance ? 1 : 0) as CKRecordValue
        }
        if let fboHasHangars = review.fboHasHangars {
            record["fboHasHangars"] = (fboHasHangars ? 1 : 0) as CKRecordValue
        }
        if let fboHasDeice = review.fboHasDeice {
            record["fboHasDeice"] = (fboHasDeice ? 1 : 0) as CKRecordValue
        }
        
        // Costs
        if let handlingFee = review.handlingFee {
            record["handlingFee"] = handlingFee as CKRecordValue
        }
        if let fboHangarCost = review.fboHangarCost {
            record["fboHangarCost"] = fboHangarCost as CKRecordValue
        }
        
        // Flight details
        if let aircraftType = review.aircraftType {
            record["aircraftType"] = aircraftType
        }
        if let operatorName = review.operatorName {
            record["operatorName"] = operatorName
        }
        if let runwayUsed = review.runwayUsed {
            record["runwayUsed"] = runwayUsed
        }
        if let approachUsed = review.approachUsed {
            record["approachUsed"] = approachUsed
        }
        if let winds = review.winds {
            record["winds"] = winds
        }
        if let visibility = review.visibility {
            record["visibility"] = visibility
        }
        if let waitTimeMinutes = review.waitTimeMinutes {
            record["waitTimeMinutes"] = waitTimeMinutes as CKRecordValue
        }
        
        // Metadata
        if let remarks = review.remarks {
            record["remarks"] = remarks
        }
        if let tags = review.tags {
            record["tags"] = tags as CKRecordValue
        }
        record["helpfulCount"] = 0 as CKRecordValue
        record["isFlagged"] = 0 as CKRecordValue
        
        do {
            let savedRecord = try await publicDB.save(record)
            
            await MainActor.run {
                // Add to local cache
                var reviews = self.pilotReviews[review.airportCode] ?? []
                var updatedReview = review
                updatedReview.cloudKitRecordID = savedRecord.recordID.recordName
                reviews.append(updatedReview)
                self.pilotReviews[review.airportCode] = reviews
                
                self.cacheReviews()
                
                // Update airport rating
                self.updateAirportRating(for: review.airportCode)
                
                print("✅ Review submitted successfully")
            }
            
        } catch {
            print("❌ Failed to submit review: \(error)")
            throw error
        }
    }
    
    /// Fetch reviews for an airport
    func fetchReviews(for icaoCode: String) async throws -> [PilotReview] {
        print("📖 Fetching reviews for \(icaoCode)...")
        
        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "airportCode == %@", icaoCode.uppercased())
        let query = CKQuery(recordType: "PilotReview", predicate: predicate)
        // Sort disabled until CloudKit schema marks 'date' field as sortable
        // query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let results = try await publicDB.records(matching: query)
            var reviews: [PilotReview] = []
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let review = parseCloudKitReview(record) {
                    reviews.append(review)
                }
            }
            
            // Sort reviews in-memory by date (newest first)
            reviews.sort { $0.date > $1.date }

            // Capture the final value for MainActor (Swift 6 concurrency fix)
            let finalReviews = reviews

            await MainActor.run {
                self.pilotReviews[icaoCode] = finalReviews
                self.cacheReviews()
                print("✅ Fetched \(finalReviews.count) reviews for \(icaoCode)")
            }

            return finalReviews
            
        } catch {
            print("❌ Failed to fetch reviews: \(error)")
            throw error
        }
    }
    
    /// Parse CloudKit review record
    private func parseCloudKitReview(_ record: CKRecord) -> PilotReview? {
        guard let airportCode = record["airportCode"] as? String,
              let pilotName = record["pilotName"] as? String,
              let rating = record["rating"] as? Int,
              let content = record["content"] as? String,
              let date = record["date"] as? Date else {
            return nil
        }
        
        // Extract all optional fields
        let title = record["title"] as? String
        let fboName = record["fboName"] as? String
        let fuelPrice = record["fuelPrice"] as? Double
        let crewCarNotes = record["crewCarNotes"] as? String
        let serviceQuality = record["serviceQuality"] as? Int
        
        // Create review with required fields
        var review = PilotReview(
            airportCode: airportCode,
            pilotName: pilotName,
            rating: rating,
            content: content,
            title: title,
            date: date,
            fboName: fboName,
            fuelPrice: fuelPrice,
            cloudKitRecordID: record.recordID.recordName
        )
        
        // Set additional optional fields
        review.crewCarNotes = crewCarNotes
        review.serviceQuality = serviceQuality
        
        // Amenities (stored as Int64, convert to Bool)
        if let val = record["crewCarAvailable"] as? Int {
            review.crewCarAvailable = val != 0
        }
        if let val = record["fboHasCrewCars"] as? Int {
            review.fboHasCrewCars = val != 0
        }
        if let val = record["fboHasCrewLounge"] as? Int {
            review.fboHasCrewLounge = val != 0
        }
        if let val = record["fboHasCatering"] as? Int {
            review.fboHasCatering = val != 0
        }
        if let val = record["fboHasMaintenance"] as? Int {
            review.fboHasMaintenance = val != 0
        }
        if let val = record["fboHasHangars"] as? Int {
            review.fboHasHangars = val != 0
        }
        if let val = record["fboHasDeice"] as? Int {
            review.fboHasDeice = val != 0
        }
        if let val = record["isFlagged"] as? Int {
            review.isFlagged = val != 0
        }
        
        // Costs
        review.handlingFee = record["handlingFee"] as? Double
        review.fboHangarCost = record["fboHangarCost"] as? Double
        
        // Flight details
        review.aircraftType = record["aircraftType"] as? String
        review.operatorName = record["operatorName"] as? String
        review.runwayUsed = record["runwayUsed"] as? String
        review.approachUsed = record["approachUsed"] as? String
        review.winds = record["winds"] as? String
        review.visibility = record["visibility"] as? String
        review.waitTimeMinutes = record["waitTimeMinutes"] as? Int
        
        // Metadata
        review.remarks = record["remarks"] as? String
        review.tags = record["tags"] as? [String]
        review.helpfulCount = record["helpfulCount"] as? Int
        
        return review
    }
    
    /// Update airport's average rating based on reviews
    private func updateAirportRating(for icaoCode: String) {
        guard var airport = airports[icaoCode],
              let reviews = pilotReviews[icaoCode],
              !reviews.isEmpty else {
            return
        }
        
        let totalRating = reviews.reduce(0) { $0 + $1.rating }
        let average = Double(totalRating) / Double(reviews.count)
        
        airport.averageRating = average
        airport.reviewCount = reviews.count
        airports[icaoCode] = airport
        
        cacheAirports()
    }
    
    /// Load cached reviews
    private func loadCachedReviews() {
        guard let data = userDefaults.data(forKey: reviewsCacheKey) else {
            print("📦 No cached reviews found")
            return
        }
        
        do {
            let reviewsDict = try JSONDecoder().decode([String: [PilotReview]].self, from: data)
            DispatchQueue.main.async {
                self.pilotReviews = reviewsDict
                print("📦 Loaded \(reviewsDict.values.flatMap { $0 }.count) cached reviews")
            }
        } catch {
            print("❌ Failed to load cached reviews: \(error)")
        }
    }
    
    /// Cache reviews to UserDefaults
    private func cacheReviews() {
        do {
            let data = try JSONEncoder().encode(pilotReviews)
            userDefaults.set(data, forKey: reviewsCacheKey)
            print("💾 Cached \(pilotReviews.values.flatMap { $0 }.count) reviews")
        } catch {
            print("❌ Failed to cache reviews: \(error)")
        }
    }
    
    // MARK: - Public Helper Methods
    
    /// Get airport by ICAO code
    func getAirport(for icaoCode: String) -> AirportInfo? {
        return airports[icaoCode.uppercased()]
    }
    
    /// Get airport name
    func getAirportName(for icaoCode: String) -> String {
        let icao = icaoCode.uppercased()
        if let airport = airports[icao] {
            return airport.name
        }
        return "\(icao) Airport"
    }
    
    /// Get reviews for airport
    func getReviews(for icaoCode: String) -> [PilotReview] {
        return pilotReviews[icaoCode.uppercased()] ?? []
    }
    
    /// Search airports by code or name
    func searchAirports(query: String) -> [AirportInfo] {
        let searchQuery = query.uppercased()
        return airports.values.filter { airport in
            airport.icaoCode.contains(searchQuery) ||
            airport.name.uppercased().contains(searchQuery)
        }.sorted { $0.icaoCode < $1.icaoCode }
    }
    
    /// Get all airports
    func getAllAirports() -> [AirportInfo] {
        return Array(airports.values).sorted { $0.icaoCode < $1.icaoCode }
    }
    
    /// Check if airport exists
    func hasAirport(for icaoCode: String) -> Bool {
        return airports[icaoCode.uppercased()] != nil
    }
    
    // MARK: - Geofencing Support
    
    /// Get priority airports for geofencing (returns up to 20 for iOS limit)
    func getPriorityAirportsForGeofencing() -> [(icao: String, coordinate: CLLocationCoordinate2D)] {
        // Get the most reviewed/rated airports (top priority)
        let sortedAirports = airports.values
            .sorted { airport1, airport2 in
                // Prioritize by review count, then by rating
                let count1 = airport1.reviewCount ?? 0
                let count2 = airport2.reviewCount ?? 0
                
                if count1 != count2 {
                    return count1 > count2
                }
                
                let rating1 = airport1.averageRating ?? 0
                let rating2 = airport2.averageRating ?? 0
                return rating1 > rating2
            }
            .prefix(20) // iOS geofencing limit
        
        return sortedAirports.map { (icao: $0.icaoCode, coordinate: $0.coordinate) }
    }
    
    /// Get nearby airports
    func getNearbyAirports(to location: CLLocation, within radiusKm: Double, limit: Int) -> [(icao: String, name: String, distance: Double)] {
        let radiusMeters = radiusKm * 1000
        var nearbyAirports: [(icao: String, name: String, distance: Double)] = []
        
        for airport in airports.values {
            let airportLocation = CLLocation(
                latitude: airport.coordinate.latitude,
                longitude: airport.coordinate.longitude
            )
            let distance = location.distance(from: airportLocation)
            
            if distance <= radiusMeters {
                nearbyAirports.append((
                    icao: airport.icaoCode,
                    name: airport.name,
                    distance: distance
                ))
            }
        }
        
        return nearbyAirports
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get airport info for Live Activity
    func getAirportInfo(_ icao: String) async -> (airportName: String, city: String)? {
        if let airport = airports[icao.uppercased()] {
            return (airport.name, "") // City not in CSV, could add later
        }
        return nil
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ ADD THIS METHOD HERE - for GPS Spoofing route checking
    // ═══════════════════════════════════════════════════════════════════════════
    /// Get airport coordinates for route spoofing zone checks
    func getCoordinates(for icaoCode: String) -> CLLocationCoordinate2D? {
        guard let airport = airports[icaoCode.uppercased()] else {
            return nil
        }
        return airport.coordinate
    }
    // ═══════════════════════════════════════════════════════════════════════════

    
    // MARK: - Database Management
    
    /// Check if CSV file exists in bundle
    func csvFileExists() -> Bool {
        return Bundle.main.url(forResource: "propilot_airports", withExtension: "csv") != nil
    }
    
    /// Get database status for diagnostics
    func getDatabaseStatus() -> (csvExists: Bool, airportCount: Int, cacheStatus: String) {
        let csvExists = csvFileExists()
        let airportCount = airports.count
        
        let cacheStatus: String
        if userDefaults.bool(forKey: csvLoadedKey) {
            cacheStatus = "CSV marked as loaded"
        } else {
            cacheStatus = "CSV not yet loaded"
        }
        
        return (csvExists, airportCount, cacheStatus)
    }
    
    /// Force reload from CSV even if already loaded
    func forceReloadFromCSV() {
        print("🔄 Force reloading airports from CSV...")
        
        // Clear the loaded flag
        userDefaults.set(false, forKey: csvLoadedKey)
        
        // Clear airports
        airports.removeAll()
        
        // Reload
        loadAirportsFromCSV()
        userDefaults.set(true, forKey: csvLoadedKey)
        
        print("✅ Force reload complete: \(airports.count) airports")
    }
    
    /// Reset and reload the airport database (use if corrupted)
    func resetDatabase() {
        print("🔄 Resetting airport database...")

        // Clear all caches
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: reviewsCacheKey)
        userDefaults.removeObject(forKey: lastUpdateKey)
        userDefaults.removeObject(forKey: csvLoadedKey)

        // Clear in-memory data
        airports.removeAll()
        pilotReviews.removeAll()
        lastDatabaseUpdate = nil

        // Reload from CSV
        loadLocalData()

        print("✅ Database reset complete")
    }

    // MARK: - Preferred FBO Management

    /// Load cached preferred FBOs
    private func loadCachedPreferredFBOs() {
        guard let data = userDefaults.data(forKey: preferredFBOsCacheKey) else {
            print("📦 No cached preferred FBOs found")
            return
        }

        do {
            let fbos = try JSONDecoder().decode([String: PreferredFBO].self, from: data)
            DispatchQueue.main.async {
                self.preferredFBOs = fbos
                print("📦 Loaded \(fbos.count) preferred FBOs from cache")
            }
        } catch {
            print("❌ Failed to load cached preferred FBOs: \(error)")
        }
    }

    /// Cache preferred FBOs to UserDefaults
    private func cachePreferredFBOs() {
        do {
            let data = try JSONEncoder().encode(preferredFBOs)
            userDefaults.set(data, forKey: preferredFBOsCacheKey)
            print("💾 Cached \(preferredFBOs.count) preferred FBOs")
        } catch {
            print("❌ Failed to cache preferred FBOs: \(error)")
        }
    }

    /// Set preferred FBO for an airport
    func setPreferredFBO(_ fbo: PreferredFBO) {
        DispatchQueue.main.async {
            self.preferredFBOs[fbo.airportCode.uppercased()] = fbo
            self.cachePreferredFBOs()
            print("✅ Set preferred FBO '\(fbo.fboName)' for \(fbo.airportCode)")
        }
    }

    /// Get preferred FBO for an airport
    func getPreferredFBO(for icaoCode: String) -> PreferredFBO? {
        return preferredFBOs[icaoCode.uppercased()]
    }

    /// Remove preferred FBO for an airport
    func removePreferredFBO(for icaoCode: String) {
        DispatchQueue.main.async {
            self.preferredFBOs.removeValue(forKey: icaoCode.uppercased())
            self.cachePreferredFBOs()
            print("🗑️ Removed preferred FBO for \(icaoCode)")
        }
    }

    /// Get all airports with preferred FBOs that need contact notifications
    /// Returns airports within the specified distance (in nautical miles)
    func getAirportsNeedingFBOContact(from currentLocation: CLLocation, withinNM: Double = 150) -> [(airport: AirportInfo, fbo: PreferredFBO, distanceNM: Double)] {
        var results: [(airport: AirportInfo, fbo: PreferredFBO, distanceNM: Double)] = []

        for (icao, fbo) in preferredFBOs {
            guard let airport = airports[icao] else { continue }

            let airportLocation = CLLocation(
                latitude: airport.coordinate.latitude,
                longitude: airport.coordinate.longitude
            )

            // Convert meters to nautical miles (1 NM = 1852 meters)
            let distanceMeters = currentLocation.distance(from: airportLocation)
            let distanceNM = distanceMeters / 1852.0

            // Check if within the specified range and notification distance
            if distanceNM <= withinNM && distanceNM <= fbo.notifyAtDistance {
                results.append((airport: airport, fbo: fbo, distanceNM: distanceNM))
            }
        }

        return results.sorted { $0.distanceNM < $1.distanceNM }
    }

    /// Get the contact frequency for an airport (UNICOM from preferred FBO, or airport's primary frequency)
    func getContactFrequency(for icaoCode: String) -> String? {
        let icao = icaoCode.uppercased()

        // First, check if there's a preferred FBO with a UNICOM frequency
        if let fbo = preferredFBOs[icao], let unicom = fbo.unicomFrequency {
            return unicom
        }

        // Fall back to airport's primary contact frequency
        if let airport = airports[icao] {
            return airport.primaryContactFrequency
        }

        return nil
    }

    // MARK: - Crowdsourced FBO CloudKit Methods

    /// Fetch crowdsourced FBOs for an airport from CloudKit and merge with local data
    func fetchCrowdsourcedFBOs(for icaoCode: String) async throws -> [CrowdsourcedFBO] {
        let icao = icaoCode.uppercased()
        let database = container.publicCloudDatabase

        let predicate = NSPredicate(format: "airportCode == %@", icao)
        let query = CKQuery(recordType: "CrowdsourcedFBO", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await database.records(matching: query)

        var cloudFBOs: [CrowdsourcedFBO] = []
        for (_, result) in results {
            if let record = try? result.get() {
                if let fbo = crowdsourcedFBO(from: record) {
                    cloudFBOs.append(fbo)
                }
            }
        }

        // Smart merge: Combine CloudKit data with local CSV/cached data
        // Capture data before MainActor to avoid Swift 6 concurrency issues
        let cloudFBOsToMerge = cloudFBOs
        let cloudFBOCount = cloudFBOs.count
        
        await MainActor.run {
            let localFBOs = self.crowdsourcedFBOs[icao] ?? []
            let mergedFBOs = self.mergeFBOData(local: localFBOs, cloud: cloudFBOsToMerge)
            self.crowdsourcedFBOs[icao] = mergedFBOs
            self.cacheCrowdsourcedFBOs()
            
            print("🔄 FBO merge for \(icao): \(localFBOs.count) local + \(cloudFBOCount) cloud = \(mergedFBOs.count) merged")
        }

        return crowdsourcedFBOs[icao] ?? []
    }
    
    /// Smart merge strategy for FBO data
    /// Priorities:
    /// 1. CloudKit FBOs with newer data (from other users)
    /// 2. CSV baseline FBOs (verified)
    /// 3. Newer fuel prices always win (even if from different source)
    private func mergeFBOData(local: [CrowdsourcedFBO], cloud: [CrowdsourcedFBO]) -> [CrowdsourcedFBO] {
        var merged: [String: CrowdsourcedFBO] = [:]  // key = normalized FBO name
        
        // Helper to normalize FBO names for matching
        func normalize(_ name: String) -> String {
            return name.lowercased()
                .replacingOccurrences(of: "aviation", with: "")
                .replacingOccurrences(of: "fbo", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "  ", with: " ")
        }
        
        // Step 1: Add all local FBOs (CSV baseline + cached)
        for fbo in local {
            merged[normalize(fbo.name)] = fbo
        }
        
        // Step 2: Merge CloudKit FBOs
        for cloudFBO in cloud {
            let key = normalize(cloudFBO.name)
            
            if let existingFBO = merged[key] {
                // Duplicate detected - merge intelligently
                var mergedFBO = existingFBO
                
                // CloudKit record ID always wins (for syncing)
                if cloudFBO.cloudKitRecordID != nil {
                    mergedFBO.cloudKitRecordID = cloudFBO.cloudKitRecordID
                }
                
                // Use CloudKit data if it's from a real user (not CSV import)
                if cloudFBO.updatedBy != "CSV Import" && cloudFBO.updatedBy != nil {
                    // User-contributed data - prefer contact info from CloudKit
                    mergedFBO.phoneNumber = cloudFBO.phoneNumber ?? existingFBO.phoneNumber
                    mergedFBO.unicomFrequency = cloudFBO.unicomFrequency ?? existingFBO.unicomFrequency
                    mergedFBO.website = cloudFBO.website ?? existingFBO.website
                    
                    // Merge amenities (use CloudKit if explicitly set)
                    mergedFBO.hasCrewCars = cloudFBO.hasCrewCars || existingFBO.hasCrewCars
                    mergedFBO.hasCrewLounge = cloudFBO.hasCrewLounge || existingFBO.hasCrewLounge
                    mergedFBO.hasCatering = cloudFBO.hasCatering || existingFBO.hasCatering
                    mergedFBO.hasMaintenance = cloudFBO.hasMaintenance || existingFBO.hasMaintenance
                    mergedFBO.hasHangars = cloudFBO.hasHangars || existingFBO.hasHangars
                    mergedFBO.hasDeice = cloudFBO.hasDeice || existingFBO.hasDeice
                    mergedFBO.hasOxygen = cloudFBO.hasOxygen || existingFBO.hasOxygen
                    mergedFBO.hasGPU = cloudFBO.hasGPU || existingFBO.hasGPU
                    mergedFBO.hasLav = cloudFBO.hasLav || existingFBO.hasLav
                    
                    // Prefer CloudKit fees if available
                    mergedFBO.handlingFee = cloudFBO.handlingFee ?? existingFBO.handlingFee
                    mergedFBO.overnightFee = cloudFBO.overnightFee ?? existingFBO.overnightFee
                    mergedFBO.rampFee = cloudFBO.rampFee ?? existingFBO.rampFee
                    if cloudFBO.rampFee != nil {
                        mergedFBO.rampFeeWaived = cloudFBO.rampFeeWaived
                    }
                    
                    // Use CloudKit ratings
                    mergedFBO.averageRating = cloudFBO.averageRating ?? existingFBO.averageRating
                    mergedFBO.ratingCount = cloudFBO.ratingCount ?? existingFBO.ratingCount
                }
                
                // FUEL PRICES: Always use the newest, regardless of source
                let cloudPriceDate = cloudFBO.fuelPriceDate ?? Date.distantPast
                let localPriceDate = existingFBO.fuelPriceDate ?? Date.distantPast
                
                if cloudPriceDate > localPriceDate {
                    mergedFBO.jetAPrice = cloudFBO.jetAPrice ?? existingFBO.jetAPrice
                    mergedFBO.avGasPrice = cloudFBO.avGasPrice ?? existingFBO.avGasPrice
                    mergedFBO.fuelPriceDate = cloudFBO.fuelPriceDate
                    mergedFBO.fuelPriceReporter = cloudFBO.fuelPriceReporter
                } else if existingFBO.jetAPrice != nil || existingFBO.avGasPrice != nil {
                    // Keep existing fuel prices if they're newer
                    mergedFBO.jetAPrice = existingFBO.jetAPrice ?? cloudFBO.jetAPrice
                    mergedFBO.avGasPrice = existingFBO.avGasPrice ?? cloudFBO.avGasPrice
                }
                
                // Update timestamp
                mergedFBO.lastUpdated = max(cloudFBO.lastUpdated, existingFBO.lastUpdated)
                
                // Keep verified status if either source is verified
                mergedFBO.isVerified = cloudFBO.isVerified || existingFBO.isVerified
                
                merged[key] = mergedFBO
                
            } else {
                // New FBO from CloudKit - add it
                merged[key] = cloudFBO
            }
        }
        
        // Return sorted by name
        return merged.values.sorted { $0.name < $1.name }
    }

    /// Check if an FBO with the same name already exists at this airport
    /// Returns the existing FBO if found (for duplicate detection)
    func findDuplicateFBO(name: String, airportCode: String, excludingId: UUID? = nil) -> CrowdsourcedFBO? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let fbos = crowdsourcedFBOs[airportCode] ?? []

        return fbos.first { fbo in
            let existingName = fbo.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isSameName = existingName == normalizedName ||
                             existingName.contains(normalizedName) ||
                             normalizedName.contains(existingName)
            let isDifferentRecord = excludingId == nil || fbo.id != excludingId
            return isSameName && isDifferentRecord
        }
    }

    /// Check if this FBO is a duplicate of a verified FBO
    func isDuplicateOfVerified(_ fbo: CrowdsourcedFBO) -> Bool {
        if let duplicate = findDuplicateFBO(name: fbo.name, airportCode: fbo.airportCode, excludingId: fbo.id) {
            return duplicate.isVerified
        }
        return false
    }

    /// Save or update a crowdsourced FBO to CloudKit
    func saveCrowdsourcedFBO(_ fbo: CrowdsourcedFBO) async throws {
        let airportCode = fbo.airportCode
        let fboId = fbo.id

        // Check for duplicates when creating NEW FBOs (not when editing existing)
        if fbo.cloudKitRecordID == nil {
            if let existingFBO = findDuplicateFBO(name: fbo.name, airportCode: airportCode, excludingId: fboId) {
                // If duplicate of verified FBO, merge the new data into the verified one instead
                if existingFBO.isVerified {
                    print("🔄 Merging new data into verified FBO '\(existingFBO.name)'")
                    var mergedFBO = existingFBO
                    // Merge in any new data the user provided
                    if fbo.unicomFrequency != nil && existingFBO.unicomFrequency == nil {
                        mergedFBO.unicomFrequency = fbo.unicomFrequency
                    }
                    if fbo.phoneNumber != nil && existingFBO.phoneNumber == nil {
                        mergedFBO.phoneNumber = fbo.phoneNumber
                    }
                    if fbo.website != nil && existingFBO.website == nil {
                        mergedFBO.website = fbo.website
                    }
                    if fbo.jetAPrice != nil { mergedFBO.jetAPrice = fbo.jetAPrice }
                    if fbo.avGasPrice != nil { mergedFBO.avGasPrice = fbo.avGasPrice }
                    // Merge amenities (true wins)
                    if fbo.hasCrewCars { mergedFBO.hasCrewCars = true }
                    if fbo.hasCrewLounge { mergedFBO.hasCrewLounge = true }
                    if fbo.hasCatering { mergedFBO.hasCatering = true }
                    if fbo.hasMaintenance { mergedFBO.hasMaintenance = true }
                    if fbo.hasHangars { mergedFBO.hasHangars = true }
                    if fbo.hasDeice { mergedFBO.hasDeice = true }
                    if fbo.hasOxygen { mergedFBO.hasOxygen = true }
                    if fbo.hasGPU { mergedFBO.hasGPU = true }
                    if fbo.hasLav { mergedFBO.hasLav = true }
                    mergedFBO.lastUpdated = Date()

                    // Save the merged verified FBO instead
                    try await saveCrowdsourcedFBO(mergedFBO)
                    return
                } else {
                    // Duplicate of non-verified FBO - block creation
                    throw NSError(domain: "FBODuplicate", code: 2,
                                 userInfo: [NSLocalizedDescriptionKey: "An FBO named '\(existingFBO.name)' already exists at this airport. Please edit the existing entry instead."])
                }
            }
        }

        // ALWAYS save locally first (so user edits are never lost)
        var updatedFBO = fbo
        updatedFBO.lastUpdated = Date()
        
        // Capture values before MainActor to avoid Swift 6 concurrency issues
        let fboToSave = updatedFBO

        await MainActor.run {
            var fbos = self.crowdsourcedFBOs[airportCode] ?? []
            if let index = fbos.firstIndex(where: { $0.id == fboId }) {
                fbos[index] = fboToSave
            } else {
                fbos.append(fboToSave)
            }
            self.crowdsourcedFBOs[airportCode] = fbos
            self.cacheCrowdsourcedFBOs()
            print("💾 FBO '\(fbo.name)' saved locally for \(airportCode)")
        }

        // Then try to sync to CloudKit (non-blocking for user experience)
        let database = container.publicCloudDatabase

        do {
            let record: CKRecord
            if let recordID = fbo.cloudKitRecordID {
                // Update existing record
                record = try await database.record(for: CKRecord.ID(recordName: recordID))
            } else {
                // Create new record
                record = CKRecord(recordType: "CrowdsourcedFBO")
            }

            // Set all fields
            record["airportCode"] = fbo.airportCode
            record["name"] = fbo.name
            record["phoneNumber"] = fbo.phoneNumber
            record["unicomFrequency"] = fbo.unicomFrequency
            record["website"] = fbo.website
            record["jetAPrice"] = fbo.jetAPrice
            record["avGasPrice"] = fbo.avGasPrice
            record["fuelPriceDate"] = fbo.fuelPriceDate
            record["fuelPriceReporter"] = fbo.fuelPriceReporter
            record["hasCrewCars"] = fbo.hasCrewCars ? 1 : 0
            record["hasCrewLounge"] = fbo.hasCrewLounge ? 1 : 0
            record["hasCatering"] = fbo.hasCatering ? 1 : 0
            record["hasMaintenance"] = fbo.hasMaintenance ? 1 : 0
            record["hasHangars"] = fbo.hasHangars ? 1 : 0
            record["hasDeice"] = fbo.hasDeice ? 1 : 0
            record["hasOxygen"] = fbo.hasOxygen ? 1 : 0
            record["hasGPU"] = fbo.hasGPU ? 1 : 0
            record["hasLav"] = fbo.hasLav ? 1 : 0
            record["handlingFee"] = fbo.handlingFee
            record["overnightFee"] = fbo.overnightFee
            record["rampFee"] = fbo.rampFee
            record["rampFeeWaived"] = fbo.rampFeeWaived ? 1 : 0
            record["averageRating"] = fbo.averageRating
            record["ratingCount"] = fbo.ratingCount
            record["lastUpdated"] = Date()
            record["isVerified"] = fbo.isVerified ? 1 : 0

            let savedRecord = try await database.save(record)

            // Update local cache with the CloudKit record ID
            var cloudSyncedFBO = updatedFBO
            cloudSyncedFBO.cloudKitRecordID = savedRecord.recordID.recordName
            
            // Capture for MainActor to avoid Swift 6 concurrency issues
            let finalFBO = cloudSyncedFBO

            await MainActor.run {
                var fbos = self.crowdsourcedFBOs[airportCode] ?? []
                if let index = fbos.firstIndex(where: { $0.id == fboId }) {
                    fbos[index] = finalFBO
                }
                self.crowdsourcedFBOs[airportCode] = fbos
                self.cacheCrowdsourcedFBOs()
                print("☁️ FBO '\(fbo.name)' synced to CloudKit")
            }
        } catch {
            // CloudKit sync failed, but local save succeeded - that's OK
            print("⚠️ CloudKit sync failed for FBO '\(fbo.name)': \(error.localizedDescription)")
            print("   (Local changes are saved and will sync when possible)")
        }
    }

    /// Quick update fuel price for an FBO
    func updateFuelPrice(for fboId: UUID, airportCode: String, jetAPrice: Double?, avGasPrice: Double?) async throws {
        guard let fbos = crowdsourcedFBOs[airportCode],
              let index = fbos.firstIndex(where: { $0.id == fboId }) else {
            throw NSError(domain: "FBO", code: 404, userInfo: [NSLocalizedDescriptionKey: "FBO not found"])
        }

        var fbo = fbos[index]
        fbo.jetAPrice = jetAPrice
        fbo.avGasPrice = avGasPrice
        fbo.fuelPriceDate = Date()
        // Could add user ID here for fuelPriceReporter

        try await saveCrowdsourcedFBO(fbo)
    }

    /// Delete a crowdsourced FBO from CloudKit
    /// NOTE: Verified FBOs (from CSV) cannot be deleted by users - they are protected
    /// EXCEPTION: Non-verified duplicates of verified FBOs CAN be deleted
    func deleteCrowdsourcedFBO(_ fbo: CrowdsourcedFBO) async throws {
        // PROTECT verified FBOs - these come from the CSV and cannot be deleted
        if fbo.isVerified {
            print("🛡️ Cannot delete verified FBO '\(fbo.name)' - protected data")
            throw NSError(domain: "FBOProtection", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "This FBO is from the verified database and cannot be deleted."])
        }

        // Allow deletion - this is either a user-created FBO or a duplicate
        if isDuplicateOfVerified(fbo) {
            print("🗑️ Deleting duplicate FBO '\(fbo.name)' (verified version exists)")
        }

        guard let recordIDName = fbo.cloudKitRecordID else {
            // Just remove from local cache if not synced to CloudKit
            await MainActor.run {
                var fbos = self.crowdsourcedFBOs[fbo.airportCode] ?? []
                fbos.removeAll { $0.id == fbo.id }
                self.crowdsourcedFBOs[fbo.airportCode] = fbos
                self.cacheCrowdsourcedFBOs()
            }
            return
        }

        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: recordIDName)
        try await database.deleteRecord(withID: recordID)

        await MainActor.run {
            var fbos = self.crowdsourcedFBOs[fbo.airportCode] ?? []
            fbos.removeAll { $0.id == fbo.id }
            self.crowdsourcedFBOs[fbo.airportCode] = fbos
            self.cacheCrowdsourcedFBOs()
        }
    }

    /// Check if an FBO can be deleted
    /// - Verified FBOs cannot be deleted
    /// - Non-verified FBOs can be deleted
    /// - Duplicates of verified FBOs can be deleted (cleanup)
    func canDeleteFBO(_ fbo: CrowdsourcedFBO) -> Bool {
        return !fbo.isVerified
    }

    /// Check if this FBO is a duplicate that should be offered for deletion
    func shouldOfferDuplicateDeletion(_ fbo: CrowdsourcedFBO) -> Bool {
        // Only offer deletion for non-verified FBOs that duplicate a verified one
        return !fbo.isVerified && isDuplicateOfVerified(fbo)
    }

    /// Convert CloudKit record to CrowdsourcedFBO
    private func crowdsourcedFBO(from record: CKRecord) -> CrowdsourcedFBO? {
        guard let airportCode = record["airportCode"] as? String,
              let name = record["name"] as? String else {
            return nil
        }

        return CrowdsourcedFBO(
            id: UUID(),
            airportCode: airportCode,
            name: name,
            phoneNumber: record["phoneNumber"] as? String,
            unicomFrequency: record["unicomFrequency"] as? String,
            website: record["website"] as? String,
            jetAPrice: record["jetAPrice"] as? Double,
            avGasPrice: record["avGasPrice"] as? Double,
            fuelPriceDate: record["fuelPriceDate"] as? Date,
            fuelPriceReporter: record["fuelPriceReporter"] as? String,
            hasCrewCars: (record["hasCrewCars"] as? Int ?? 0) == 1,
            hasCrewLounge: (record["hasCrewLounge"] as? Int ?? 0) == 1,
            hasCatering: (record["hasCatering"] as? Int ?? 0) == 1,
            hasMaintenance: (record["hasMaintenance"] as? Int ?? 0) == 1,
            hasHangars: (record["hasHangars"] as? Int ?? 0) == 1,
            hasDeice: (record["hasDeice"] as? Int ?? 0) == 1,
            hasOxygen: (record["hasOxygen"] as? Int ?? 0) == 1,
            hasGPU: (record["hasGPU"] as? Int ?? 0) == 1,
            hasLav: (record["hasLav"] as? Int ?? 0) == 1,
            handlingFee: record["handlingFee"] as? Double,
            overnightFee: record["overnightFee"] as? Double,
            rampFee: record["rampFee"] as? Double,
            rampFeeWaived: (record["rampFeeWaived"] as? Int ?? 0) == 1,
            averageRating: record["averageRating"] as? Double,
            ratingCount: record["ratingCount"] as? Int,
            lastUpdated: record["lastUpdated"] as? Date ?? Date(),
            updatedBy: record["updatedBy"] as? String,
            cloudKitRecordID: record.recordID.recordName,
            isVerified: (record["isVerified"] as? Int ?? 0) == 1
        )
    }

    /// Cache crowdsourced FBOs locally
    private func cacheCrowdsourcedFBOs() {
        if let data = try? JSONEncoder().encode(crowdsourcedFBOs) {
            userDefaults.set(data, forKey: crowdsourcedFBOsCacheKey)
        }
    }

    /// Load cached crowdsourced FBOs and merge with existing (CSV) data
    private func loadCachedCrowdsourcedFBOs() {
        guard let data = userDefaults.data(forKey: crowdsourcedFBOsCacheKey),
              let cached = try? JSONDecoder().decode([String: [CrowdsourcedFBO]].self, from: data) else {
            return
        }

        // Merge cached FBOs with existing CSV FBOs (deduplicate by normalized name)
        for (airportCode, cachedFBOs) in cached {
            if crowdsourcedFBOs[airportCode] == nil {
                // No existing data, use cached (but deduplicate within the cache)
                crowdsourcedFBOs[airportCode] = deduplicateFBOs(cachedFBOs)
            } else {
                // Merge cached with existing CSV data
                let merged = mergeFBOData(local: crowdsourcedFBOs[airportCode] ?? [], cloud: cachedFBOs)
                crowdsourcedFBOs[airportCode] = merged
            }
        }
    }

    /// Deduplicate FBOs by normalized name, preferring verified entries
    private func deduplicateFBOs(_ fbos: [CrowdsourcedFBO]) -> [CrowdsourcedFBO] {
        var seen: [String: CrowdsourcedFBO] = [:]

        func normalizeName(_ name: String) -> String {
            return name.lowercased()
                .replacingOccurrences(of: "aviation", with: "")
                .replacingOccurrences(of: "fbo", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "  ", with: " ")
        }

        for fbo in fbos {
            let key = normalizeName(fbo.name)
            if let existing = seen[key] {
                // Keep verified over non-verified, otherwise keep newer
                if fbo.isVerified && !existing.isVerified {
                    seen[key] = fbo
                } else if !existing.isVerified && fbo.lastUpdated > existing.lastUpdated {
                    seen[key] = fbo
                }
            } else {
                seen[key] = fbo
            }
        }

        return seen.values.sorted { $0.name < $1.name }
    }

    /// Get all FBOs for an airport (crowdsourced) - always deduplicated
    func getFBOs(for icaoCode: String) -> [CrowdsourcedFBO] {
        let fbos = crowdsourcedFBOs[icaoCode.uppercased()] ?? []
        // Apply deduplication as a safety net before returning
        return deduplicateFBOs(fbos)
    }
}

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
    
    enum CodingKeys: String, CodingKey {
        case icaoCode, name, timeZone, source, dateAdded, latitude, longitude, averageRating, reviewCount
    }
    
    init(icaoCode: String, name: String, coordinate: CLLocationCoordinate2D, timeZone: String? = nil, source: AirportSource = .csvImport, dateAdded: Date = Date(), averageRating: Double? = nil, reviewCount: Int? = nil) {
        self.icaoCode = icaoCode
        self.name = name
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.source = source
        self.dateAdded = dateAdded
        self.averageRating = averageRating
        self.reviewCount = reviewCount
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
    @Published var isLoading = false
    @Published var loadingMessage: String = ""
    @Published var lastDatabaseUpdate: Date?

    private let container = CKContainer(identifier: "iCloud.com.jkadans.ProPilotApp")
    private let cacheKey = "CachedAirportDatabase"
    private let reviewsCacheKey = "CachedPilotReviews"
    private let lastUpdateKey = "AirportDatabaseLastUpdate"
    private let userDefaults = UserDefaults.shared
    private let csvLoadedKey = "CSVAirportsLoaded"

    private init() {
        loadLocalData()
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
        
        return AirportInfo(
            icaoCode: icao.uppercased(),
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timeZone: timezone,
            source: .cloudKit,
            dateAdded: Date(),
            averageRating: avgRating,
            reviewCount: reviewCount
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
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let results = try await publicDB.records(matching: query)
            var reviews: [PilotReview] = []
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let review = parseCloudKitReview(record) {
                    reviews.append(review)
                }
            }

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
}

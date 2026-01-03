//
//  CloudAirport.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//

import Foundation
import CloudKit
import CoreLocation

// MARK: - CloudAirport Model
public struct CloudAirport {
    public let code: String
    public let name: String
    public let city: String
    public let state: String
    public let elevation: String
    public let coordinate: CLLocationCoordinate2D
    public let unicom: String?
    public let phone: String?
    public let address: String?
    public let fboName: String?
    
    public init(code: String, name: String, city: String, state: String, elevation: String, coordinate: CLLocationCoordinate2D, unicom: String? = nil, phone: String? = nil, address: String? = nil, fboName: String? = nil) {
        self.code = code
        self.name = name
        self.city = city
        self.state = state
        self.elevation = elevation
        self.coordinate = coordinate
        self.unicom = unicom
        self.phone = phone
        self.address = address
        self.fboName = fboName
    }
}

// MARK: - CloudReview Model
public struct CloudReview: Identifiable {
    public let id: UUID
    public let pilotName: String
    public let rating: Int
    public let date: Date
    public let title: String
    public let content: String
    public let tags: [String]

    public init(id: UUID = UUID(), pilotName: String, rating: Int, date: Date, title: String, content: String, tags: [String]) {
        self.id = id
        self.pilotName = pilotName
        self.rating = rating
        self.date = date
        self.title = title
        self.content = content
        self.tags = tags
    }
}

// MARK: - AreaGuideCloudKit Service
final class AreaGuideCloudKit {
    static let shared = AreaGuideCloudKit()
    private let container: CKContainer
    
    // MARK: - Record Types
    private enum RecordType {
        static let airport = "Airport"
        static let review = "PilotReview"
    }
    
    // MARK: - Airport Keys
    private enum AirportKeys {
        static let code = "code"
        static let name = "name"
        static let city = "city"
        static let state = "state"
        static let elevation = "elevation"
        static let location = "location"
        static let unicom = "unicom"
        static let phone = "phone"
        static let address = "address"
        static let fboName = "fboName"
    }
    
    // MARK: - Review Keys
    private enum ReviewKeys {
        static let airportCode = "airportCode"
        static let pilotName = "pilotName"
        static let rating = "rating"
        static let date = "date"
        static let title = "title"
        static let content = "content"
        static let tags = "tags"
    }
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.jkadans.TheProPilotApp")
        print("🔵 CloudKit initialized with container: iCloud.com.jkadans.TheProPilotApp")
        
        // Log which environment we're using
        #if DEBUG
        print("🔵 Running in DEBUG mode - should use Development environment")
        #else
        print("🔵 Running in RELEASE mode - will use Production environment")
        #endif
        
        // Check account status
        Task {
            do {
                let status = try await checkAccountStatus()
                print("🔵 iCloud account status: \(status.rawValue)")
                // 0 = No Account, 1 = Available, 2 = Restricted, 3 = CouldNotDetermine
            } catch {
                print("❌ Could not check iCloud status: \(error)")
            }
        }
    }
    
    // MARK: - Account Status Check
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    // MARK: - Fetch All Airports
    func fetchAllAirports() async throws -> [CloudAirport] {
        print("🔍 Fetching all airports from CloudKit...")
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.airport, predicate: predicate)
        
        do {
            let records = try await performQuery(query)
            print("✅ Fetched \(records.count) airport records from CloudKit")
            
            let airports = records.compactMap { record -> CloudAirport? in
                guard
                    let code = record[AirportKeys.code] as? String,
                    let name = record[AirportKeys.name] as? String,
                    let city = record[AirportKeys.city] as? String,
                    let state = record[AirportKeys.state] as? String,
                    let elevation = record[AirportKeys.elevation] as? String,
                    let location = record[AirportKeys.location] as? CLLocation
                else {
                    print("⚠️ Skipping malformed record")
                    return nil
                }
                
                return CloudAirport(
                    code: code,
                    name: name,
                    city: city,
                    state: state,
                    elevation: elevation,
                    coordinate: location.coordinate,
                    unicom: record[AirportKeys.unicom] as? String,
                    phone: record[AirportKeys.phone] as? String,
                    address: record[AirportKeys.address] as? String,
                    fboName: record[AirportKeys.fboName] as? String
                )
            }
            print("✅ Parsed \(airports.count) valid airports")
            // Sort client-side by airport code
            return airports.sorted { $0.code < $1.code }
        } catch {
            print("❌ CloudKit fetch error: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("❌ CKError code: \(ckError.code.rawValue)")
                print("❌ CKError: \(ckError)")
            }
            throw error
        }
    }
    
    // MARK: - Fetch Airports (by code prefix)
    func fetchAirports(matching text: String?) async throws -> [CloudAirport] {
        let predicate: NSPredicate
        if let text, !text.isEmpty {
            let uppercaseText = text.uppercased()
            predicate = NSPredicate(format: "%K BEGINSWITH %@", AirportKeys.code, uppercaseText)
        } else {
            predicate = NSPredicate(value: true)
        }
        
        let query = CKQuery(recordType: RecordType.airport, predicate: predicate)
        // NOTE: Can't sort on 'code' as it's not marked SORTABLE in CloudKit schema
        // Will sort results client-side instead
        
        let records = try await performQuery(query)
        
        let airports = records.compactMap { record -> CloudAirport? in
            guard
                let code = record[AirportKeys.code] as? String,
                let name = record[AirportKeys.name] as? String,
                let city = record[AirportKeys.city] as? String,
                let state = record[AirportKeys.state] as? String,
                let elevation = record[AirportKeys.elevation] as? String,
                let loc = record[AirportKeys.location] as? CLLocation
            else {
                print("⚠️ Skipping airport record with missing required fields")
                return nil
            }
            
            return CloudAirport(
                code: code,
                name: name,
                city: city,
                state: state,
                elevation: elevation,
                coordinate: loc.coordinate,
                unicom: record[AirportKeys.unicom] as? String,
                phone: record[AirportKeys.phone] as? String,
                address: record[AirportKeys.address] as? String,
                fboName: record[AirportKeys.fboName] as? String
            )
        }
        
        // Sort client-side by airport code
        return airports.sorted { $0.code < $1.code }
    }
    
    // MARK: - Fetch Reviews
    func fetchReviews(for airportCode: String) async throws -> [CloudReview] {
        let predicate = NSPredicate(format: "%K == %@", ReviewKeys.airportCode, airportCode)
        let query = CKQuery(recordType: RecordType.review, predicate: predicate)
        // ✅ No sortDescriptors - we'll sort client-side
        
        let records = try await performQuery(query)
        
        // ✅ Explicitly type the reviews array
        let reviews: [CloudReview] = records.compactMap { record -> CloudReview? in
            guard
                let pilotName = record[ReviewKeys.pilotName] as? String,
                let rating = record[ReviewKeys.rating] as? Int,
                let date = record[ReviewKeys.date] as? Date,
                let title = record[ReviewKeys.title] as? String,
                let content = record[ReviewKeys.content] as? String,
                let tags = record[ReviewKeys.tags] as? [String]
            else { return nil }
            
            return CloudReview(
                pilotName: pilotName,
                rating: rating,
                date: date,
                title: title,
                content: content,
                tags: tags
            )
        }
        
        // ✅ Sort REVIEWS by date (newest first)
        return reviews.sorted { $0.date > $1.date }
    }
    
    // MARK: - Save Review
    func saveReview(_ review: CloudReview, for airportCode: String) async throws {
        let record = CKRecord(recordType: RecordType.review)
        
        record[ReviewKeys.airportCode] = airportCode as CKRecordValue
        record[ReviewKeys.pilotName] = review.pilotName as CKRecordValue
        record[ReviewKeys.rating] = review.rating as CKRecordValue
        record[ReviewKeys.date] = review.date as CKRecordValue
        record[ReviewKeys.title] = review.title as CKRecordValue
        record[ReviewKeys.content] = review.content as CKRecordValue
        record[ReviewKeys.tags] = review.tags as CKRecordValue
        
        let database = container.publicCloudDatabase
        let _ = try await database.save(record)
        
        print("✅ Review saved successfully for \(airportCode)")
    }
    
    // MARK: - Airport Validation & Creation
    
    func validateAirportCode(_ code: String) async throws -> CloudAirport {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        
        guard cleanCode.count >= 3 && cleanCode.count <= 4,
              cleanCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw AirportValidationError.invalidFormat
        }
        
        let urlString = "https://airport-data.com/api/ap_info.json?icao=\(code)"
        
        guard let url = URL(string: urlString) else {
            throw AirportValidationError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AirportValidationError.apiError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let airportName = json?["name"] as? String,
              let cityName = json?["location"] as? String,
              let latString = json?["latitude"] as? String,
              let lonString = json?["longitude"] as? String,
              let lat = Double(latString),
              let lon = Double(lonString) else {
            throw AirportValidationError.airportNotFound
        }
        
        let elevationString: String
        if let elevFeet = json?["elevation_ft"] as? Int {
            elevationString = "\(elevFeet) ft"
        } else if let elevMeters = json?["elevation"] as? Int {
            let feet = Int(Double(elevMeters) * 3.28084)
            elevationString = "\(feet) ft"
        } else {
            elevationString = "N/A"
        }
        
        let locationComponents = cityName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let city = locationComponents.first ?? cityName
        let state = locationComponents.count > 1 ? locationComponents[1] : "N/A"
        
        return CloudAirport(
            code: cleanCode,
            name: airportName,
            city: city,
            state: state,
            elevation: elevationString,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
    }
    
    func createAirport(_ airport: CloudAirport) async throws {
        let record = CKRecord(recordType: RecordType.airport)
        
        record[AirportKeys.code] = airport.code as CKRecordValue
        record[AirportKeys.name] = airport.name as CKRecordValue
        record[AirportKeys.city] = airport.city as CKRecordValue
        record[AirportKeys.state] = airport.state as CKRecordValue
        record[AirportKeys.elevation] = airport.elevation as CKRecordValue
        
        let location = CLLocation(latitude: airport.coordinate.latitude, longitude: airport.coordinate.longitude)
        record[AirportKeys.location] = location as CKRecordValue
        
        if let unicom = airport.unicom {
            record[AirportKeys.unicom] = unicom as CKRecordValue
        }
        if let phone = airport.phone {
            record[AirportKeys.phone] = phone as CKRecordValue
        }
        if let address = airport.address {
            record[AirportKeys.address] = address as CKRecordValue
        }
        if let fboName = airport.fboName {
            record[AirportKeys.fboName] = fboName as CKRecordValue
        }
        
        let database = container.publicCloudDatabase
        let _ = try await database.save(record)
        
        print("✅ Airport created: \(airport.code) - \(airport.name)")
    }
    
    func fetchOrCreateAirport(code: String) async throws -> CloudAirport {
        let results = try await fetchAirports(matching: code)
        if let existing = results.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            print("✅ Airport found in CloudKit: \(code)")
            return existing
        }
        
        print("🔍 Airport not in CloudKit, validating with API...")
        let validatedAirport = try await validateAirportCode(code)
        
        print("💾 Creating airport in CloudKit...")
        try await createAirport(validatedAirport)
        
        return validatedAirport
    }
    
    // MARK: - Helper Methods
    private func performQuery(_ query: CKQuery) async throws -> [CKRecord] {
        let database = container.publicCloudDatabase
        
        // Use modern CloudKit API (iOS 15+) to avoid CKQueryOperation sorting issues
        let (matchResults, _) = try await database.records(matching: query)
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        print("🔍 Query returned \(records.count) records")
        return records
    }
}

// MARK: - Validation Errors
enum AirportValidationError: LocalizedError {
    case invalidFormat
    case invalidURL
    case apiError
    case airportNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Airport code must be 3-4 characters (e.g., KLRD, LRD)"
        case .invalidURL:
            return "Invalid API URL"
        case .apiError:
            return "Unable to connect to airport database"
        case .airportNotFound:
            return "Airport code not found in database. Please verify the code."
        case .invalidData:
            return "Invalid airport data received"
        }
    }
}

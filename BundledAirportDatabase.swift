//
//  BundledAirportDatabase.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/15/25.
//


//
//  BundledAirportDatabase.swift
//  TheProPilotApp
//
//  Loads airports from bundled CSV file
//

import Foundation
import CoreLocation

class BundledAirportDatabase {
    static let shared = BundledAirportDatabase()
    
    private var airports: [AirportExperience] = []
    private var isLoaded = false
    
    private init() {}
    
    func loadAirports() {
        guard !isLoaded else { return }
        
        guard let csvPath = Bundle.main.path(forResource: "propilot_airports", ofType: "csv") else {
            print("❌ Could not find propilot_airports.csv in bundle")
            return
        }
        
        do {
            let csvString = try String(contentsOfFile: csvPath, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines)
            
            print("📦 Loading \(lines.count) airports from bundled CSV...")
            
            // Skip header row
            for line in lines.dropFirst() {
                guard !line.isEmpty else { continue }
                
                if let airport = parseCSVLine(line) {
                    airports.append(airport)
                }
            }
            
            isLoaded = true
            print("✅ Loaded \(airports.count) airports from bundle")
            
        } catch {
            print("❌ Error loading CSV: \(error)")
        }
    }
    
    private func parseCSVLine(_ line: String) -> AirportExperience? {
        let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        
        guard columns.count >= 19 else { return nil }
        
        // CSV format: id, ident, type, name, latitude_deg, longitude_deg, elevation_ft, 
        //             continent, iso_country, iso_region, municipality, scheduled_service, 
        //             icao_code, iata_code, gps_code, local_code, home_link, wikipedia_link, keywords
        
        let code = columns[1].trimmingCharacters(in: .whitespaces)
        let name = columns[3].trimmingCharacters(in: .whitespaces)
        let latString = columns[4].trimmingCharacters(in: .whitespaces)
        let lonString = columns[5].trimmingCharacters(in: .whitespaces)
        let elevationString = columns[6].trimmingCharacters(in: .whitespaces)
        let municipality = columns[10].trimmingCharacters(in: .whitespaces)
        let isoRegion = columns[9].trimmingCharacters(in: .whitespaces)
        
        guard let lat = Double(latString),
              let lon = Double(lonString) else {
            return nil
        }
        
        let elevation = Int(elevationString) ?? 0
        let elevationText = elevation > 0 ? "\(elevation) ft" : "N/A"
        
        // Extract state from iso_region (e.g., "US-TX" -> "TX")
        let state = isoRegion.components(separatedBy: "-").last ?? ""
        
        return AirportExperience(
            code: code,
            name: name,
            city: municipality,
            state: state,
            elevation: elevationText,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            reviews: []
        )
    }
    
    func searchAirports(query: String) -> [AirportExperience] {
        if !isLoaded {
            loadAirports()
        }
        
        guard !query.isEmpty else {
            return Array(airports.prefix(100)) // Return first 100 if no search
        }
        
        let lowercaseQuery = query.lowercased()
        
        return airports.filter { airport in
            airport.code.lowercased().contains(lowercaseQuery) ||
            airport.city.lowercased().contains(lowercaseQuery) ||
            airport.name.lowercased().contains(lowercaseQuery)
        }
    }
    
    func getAllAirports() -> [AirportExperience] {
        if !isLoaded {
            loadAirports()
        }
        return airports
    }
}
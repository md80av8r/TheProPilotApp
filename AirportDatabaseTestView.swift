//
//  AirportDatabaseTestView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/17/25.
//

import SwiftUI
import CloudKit

/// Simple test view to verify your CloudKit airport import worked
/// Add this to your app temporarily to test the imported data
struct AirportDatabaseTestView: View {
    @State private var searchText = "KYIP"
    @State private var searchResults: [ImportedAirport] = []  // ✅ RENAMED
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search bar
                HStack {
                    TextField("Enter ICAO code (e.g., KYIP)", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                    
                    Button("Search") {
                        Task {
                            await searchAirport()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty)
                }
                .padding()
                
                if isLoading {
                    ProgressView("Searching CloudKit...")
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(searchResults, id: \.icaoCode) { airport in
                            AirportDetailCard(airport: airport)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Airport Database Test")
        }
    }
    
    // MARK: - CloudKit Query
    
    func searchAirport() async {
        isLoading = true
        errorMessage = ""
        searchResults = []
        
        let container = CKContainer(identifier: "iCloud.com.jkadans.TheProPilotApp")
        let database = container.publicCloudDatabase
        
        // Query by ICAO code
        let predicate = NSPredicate(format: "icaoCode == %@", searchText.uppercased())
        let query = CKQuery(recordType: "Airport", predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            
            var airports: [ImportedAirport] = []  // ✅ RENAMED
            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    if let airport = parseAirport(from: record) {
                        airports.append(airport)
                    }
                case .failure(let error):
                    print("Error fetching record: \(error)")
                }
            }
            
            await MainActor.run {
                if airports.isEmpty {
                    errorMessage = "No airport found for '\(searchText)'"
                } else {
                    searchResults = airports
                }
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "CloudKit error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Parse CloudKit Record
    
    func parseAirport(from record: CKRecord) -> ImportedAirport? {  // ✅ RENAMED
        guard let icaoCode = record["icaoCode"] as? String,
              let name = record["name"] as? String else {
            return nil
        }
        
        return ImportedAirport(  // ✅ RENAMED
            icaoCode: icaoCode,
            iataCode: record["iataCode"] as? String,
            name: name,
            latitude: record["latitude"] as? Double ?? 0,
            longitude: record["longitude"] as? Double ?? 0,
            elevation: record["elevation"] as? String,
            city: record["city"] as? String,
            state: record["state"] as? String,
            country: record["country"] as? String,
            longestRunway: record["longestRunway"] as? String,
            runwaySurface: record["runwaySurface"] as? String,
            qualityTier: record["qualityTier"] as? String,
            allRunways: record["allRunways"] as? String,
            hasLightedRunway: record["hasLightedRunway"] as? String,
            frequencies: record["frequencies"] as? String,
            towerFrequency: record["towerFrequency"] as? String,
            atisFrequency: record["atisFrequency"] as? String,
            groundFrequency: record["groundFrequency"] as? String,
            homeLink: record["homeLink"] as? String,
            wikipediaLink: record["wikipediaLink"] as? String,
            localComments: record["localComments"] as? String,
            commentCount: record["commentCount"] as? Int64 ?? 0
        )
    }
}

// MARK: - Imported Airport Model (for testing comprehensive CloudKit import)
// ✅ RENAMED to avoid conflict with existing CloudAirport

struct ImportedAirport {  // ✅ RENAMED
    let icaoCode: String
    let iataCode: String?
    let name: String
    let latitude: Double
    let longitude: Double
    let elevation: String?
    let city: String?
    let state: String?
    let country: String?
    
    // Runway data
    let longestRunway: String?
    let runwaySurface: String?
    let qualityTier: String?
    let allRunways: String?
    let hasLightedRunway: String?
    
    // Frequencies
    let frequencies: String?
    let towerFrequency: String?
    let atisFrequency: String?
    let groundFrequency: String?
    
    // Links
    let homeLink: String?
    let wikipediaLink: String?
    
    // Comments
    let localComments: String?
    let commentCount: Int64
    
    var runwaysList: [String] {
        guard let runways = allRunways else { return [] }
        return runways.components(separatedBy: "|")
    }
    
    var frequenciesList: [String] {
        guard let freqs = frequencies else { return [] }
        return freqs.components(separatedBy: "|")
    }
    
    var commentsList: [String] {
        guard let comments = localComments else { return [] }
        return comments.components(separatedBy: " | ")
    }
}

// MARK: - Airport Detail Card

struct AirportDetailCard: View {
    let airport: ImportedAirport  // ✅ RENAMED
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(airport.icaoCode)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let iata = airport.iataCode {
                    Text("(\(iata))")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let quality = airport.qualityTier {
                    Text(quality.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(qualityColor(quality))
                        .cornerRadius(8)
                }
            }
            
            Text(airport.name)
                .font(.headline)
            
            if let city = airport.city, let state = airport.state {
                Text("\(city), \(state)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Runways
            if !airport.runwaysList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Runways", systemImage: "airplane.departure")
                        .font(.headline)
                    
                    ForEach(airport.runwaysList, id: \.self) { runway in
                        Text(runway)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Frequencies
            if !airport.frequenciesList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Frequencies", systemImage: "radio")
                        .font(.headline)
                    
                    ForEach(airport.frequenciesList, id: \.self) { freq in
                        Text(freq)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Comments
            if !airport.commentsList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Local Tips (\(airport.commentCount))", systemImage: "text.bubble")
                        .font(.headline)
                    
                    ForEach(airport.commentsList.prefix(3), id: \.self) { comment in
                        Text(comment)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Links
            if let wiki = airport.wikipediaLink, !wiki.isEmpty {
                Link(destination: URL(string: wiki)!) {
                    Label("Wikipedia", systemImage: "link")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    func qualityColor(_ quality: String) -> Color {
        switch quality.lowercased() {
        case "commercial": return .blue
        case "regional": return .green
        case "general": return .orange
        case "basic": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    AirportDatabaseTestView()
}

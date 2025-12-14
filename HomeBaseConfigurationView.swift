import SwiftUI

struct HomeBaseConfigurationView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current home base display
                VStack(spacing: 12) {
                    Text("Current Home Base")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(airlineSettings.settings.homeBaseAirport.isEmpty ? "Not Set" : airlineSettings.settings.homeBaseAirport)
                        .font(.title2)
                        .foregroundColor(LogbookTheme.accentGreen)
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(8)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search airports...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(8)
                
                // Airport list
                List {
                    ForEach(filteredAirports, id: \.self) { airportCode in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(airportDisplayName(for: airportCode))
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Text("ICAO: \(airportCode)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            if airlineSettings.settings.homeBaseAirport == airportCode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            airlineSettings.settings.homeBaseAirport = airportCode
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Home Base Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        airlineSettings.saveSettings()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
    }
    
    private var filteredAirports: [String] {
        let commonAirports = [
            "KATL", "KBOS", "KCLT", "KORD", "KMDW", "KDFW", "KDAL", "KDEN",
            "KDET", "KFLL", "KIAH", "KHOU", "KLAS", "KLAX", "KMEM", "KMIA",
            "KMSP", "KJFK", "KLGA", "KEWR", "KPHL", "KPHX", "KSAN", "KSFO",
            "KSEA", "KSLC", "KDCA", "KIAD", "KYIP", "KBWI", "KOAK", "KPDX",
            "KBNA", "KAUS", "KSTL", "KSDF", "KCVG", "KMCO", "KTPA", "KRDU",
            "KANC", "KULS"
        ]
        
        if searchText.isEmpty {
            return commonAirports.sorted()
        } else {
            return commonAirports.filter { airport in
                airport.localizedCaseInsensitiveContains(searchText) ||
                airportDisplayName(for: airport).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func airportDisplayName(for icaoCode: String) -> String {
        let airportNames: [String: String] = [
            "KATL": "Atlanta (ATL)",
            "KBOS": "Boston (BOS)",
            "KCLT": "Charlotte (CLT)",
            "KORD": "Chicago O'Hare (ORD)",
            "KMDW": "Chicago Midway (MDW)",
            "KDFW": "Dallas/Fort Worth (DFW)",
            "KDAL": "Dallas Love Field (DAL)",
            "KDEN": "Denver (DEN)",
            "KDET": "Detroit (DTW)",
            "KFLL": "Fort Lauderdale (FLL)",
            "KIAH": "Houston (IAH)",
            "KHOU": "Houston Hobby (HOU)",
            "KLAS": "Las Vegas (LAS)",
            "KLAX": "Los Angeles (LAX)",
            "KMEM": "Memphis (MEM)",
            "KMIA": "Miami (MIA)",
            "KMSP": "Minneapolis (MSP)",
            "KJFK": "New York JFK (JFK)",
            "KLGA": "New York LaGuardia (LGA)",
            "KEWR": "Newark (EWR)",
            "KPHL": "Philadelphia (PHL)",
            "KPHX": "Phoenix (PHX)",
            "KSAN": "San Diego (SAN)",
            "KSFO": "San Francisco (SFO)",
            "KSEA": "Seattle (SEA)",
            "KSLC": "Salt Lake City (SLC)",
            "KDCA": "Washington National (DCA)",
            "KIAD": "Washington Dulles (IAD)",
            "KYIP": "Willow Run (YIP)",
            "KBWI": "Baltimore (BWI)",
            "KOAK": "Oakland (OAK)",
            "KPDX": "Portland (PDX)",
            "KBNA": "Nashville (BNA)",
            "KAUS": "Austin (AUS)",
            "KSTL": "St. Louis (STL)",
            "KSDF": "Louisville (SDF)",
            "KCVG": "Cincinnati (CVG)",
            "KMCO": "Orlando (MCO)",
            "KTPA": "Tampa (TPA)",
            "KRDU": "Raleigh-Durham (RDU)",
            "KANC": "Anchorage (ANC)",
            "KULS": "Louisville UPS (SDF)",
        ]
        
        return airportNames[icaoCode] ?? icaoCode
    }
}

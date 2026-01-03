//
//  AirportDatabaseView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//

//
//  AirportDatabaseView.swift
//  TheProPilotApp
//
//  Comprehensive airport database with search, weather, frequencies, and reviews
//

import SwiftUI
import CoreLocation

struct AirportDatabaseView: View {
    @StateObject private var viewModel = AirportDatabaseViewModel()
    @State private var searchText = ""
    @State private var selectedAirport: AirportInfo?
    @State private var showSettings = false
    @State private var selectedTab: DatabaseTab = .nearby  // Start with Nearby tab showing closest airports
    
    enum DatabaseTab: String, CaseIterable {
        case search = "Search"
        case nearby = "Nearby"
        case favorites = "Favorites"
        
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .nearby: return "location.circle"
            case .favorites: return "star.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with settings
                headerSection
                
                // Tab Selector
                tabSelector
                
                // Content based on selected tab
                switch selectedTab {
                case .search:
                    searchView
                case .nearby:
                    nearbyView
                case .favorites:
                    favoritesView
                }
            }
        }
        .sheet(item: $selectedAirport, onDismiss: {
            // Refresh favorites when sheet is dismissed (in case user toggled favorite)
            viewModel.loadFavorites()
        }) { airport in
            AirportDetailViewEnhanced(airport: airport)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                AirportDatabaseSettingsView()
            }
        }
        .onAppear {
            viewModel.loadAirports()
            viewModel.requestLocation()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Airport Database")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Show context-specific subtitle
                switch selectedTab {
                case .nearby:
                    Text("\(viewModel.nearbyAirports.count) nearest airports")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .search:
                    if searchText.isEmpty {
                        Text("Search \(viewModel.airports.count) airports")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(viewModel.searchResults.count) results")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                case .favorites:
                    Text("\(viewModel.favoriteAirports.count) favorites")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Settings button (access to diagnostics)
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DatabaseTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? LogbookTheme.accentGreen : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        Color.white.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Search View
    
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search by ICAO, name, or city...", text: $searchText)
                    .foregroundColor(.white)
                    .autocapitalization(.allCharacters)
                    .onChange(of: searchText) { oldValue, newValue in
                        viewModel.searchAirports(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding()
            
            // Results
            if searchText.isEmpty {
                emptySearchState
            } else if viewModel.searchResults.isEmpty {
                noResultsState
            } else {
                searchResultsList
            }
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Search Airports")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Enter ICAO code, airport name, or city")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Airports Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Try searching by ICAO code (KDTW)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.searchResults) { airport in
                    AirportRowView(airport: airport) {
                        print("🔵 Tapped airport: \(airport.icaoCode) - \(airport.name)")
                        selectedAirport = airport
                        print("🔵 selectedAirport set to: \(String(describing: selectedAirport))")
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Nearby View
    
    private var nearbyView: some View {
        VStack(spacing: 0) {
            // Info bar
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("Showing 5 nearest airports")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navyLight)
            
            // Results
            if viewModel.isLoadingLocation {
                loadingLocationView
            } else if viewModel.nearbyAirports.isEmpty {
                noNearbyAirportsView
            } else {
                nearbyAirportsList
            }
        }
    }
    
    private var loadingLocationView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Getting your location...")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private var noNearbyAirportsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Nearby Airports")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Enable location services or increase search radius")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var nearbyAirportsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.nearbyAirports) { airport in
                    AirportRowView(
                        airport: airport,
                        distance: viewModel.distanceToAirport(airport)
                    ) {
                        selectedAirport = airport
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Favorites View
    
    private var favoritesView: some View {
        VStack {
            if viewModel.favoriteAirports.isEmpty {
                emptyFavoritesState
            } else {
                favoritesList
            }
        }
    }
    
    private var emptyFavoritesState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Tap the star icon on any airport to add it to your favorites")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.favoriteAirports) { airport in
                    AirportRowView(airport: airport, isFavorite: true) {
                        selectedAirport = airport
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Airport Row View

struct AirportRowView: View {
    let airport: AirportInfo
    var distance: Double?
    var isFavorite: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // ICAO code badge
                Text(airport.icaoCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(LogbookTheme.accentGreen)
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                // Airport info
                VStack(alignment: .leading, spacing: 4) {
                    Text(airport.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // ✅ FIXED: Removed city check since AirportInfo doesn't have city property
                        Label(airport.icaoCode, systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let dist = distance {
                            Label("\(Int(dist)) nm", systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
}

// MARK: - View Model

@MainActor
class AirportDatabaseViewModel: ObservableObject {
    @Published var airports: [AirportInfo] = []
    @Published var searchResults: [AirportInfo] = []
    @Published var nearbyAirports: [AirportInfo] = []
    @Published var favoriteAirports: [AirportInfo] = []
    @Published var isLoadingLocation = false
    @Published var searchRadius: Double = 50.0 // nautical miles
    @Published var userLocation: CLLocation?
    
    private let locationManager = CLLocationManager()
    private let dbManager = AirportDatabaseManager.shared
    
    func loadAirports() {
        airports = dbManager.getAllAirports()
        loadFavorites()
    }
    
    func searchAirports(query: String) {
        print("🔍 searchAirports called with query: '\(query)'")
        
        guard !query.isEmpty else {
            searchResults = []
            print("🔍 Query empty, clearing results")
            return
        }
        
        // ✅ FIXED: Removed 'limit' parameter
        searchResults = dbManager.searchAirports(query: query)
        print("🔍 Search returned \(searchResults.count) results")
        
        if !searchResults.isEmpty {
            print("🔍 First result: \(searchResults[0].icaoCode) - \(searchResults[0].name)")
        }
    }
    
    func requestLocation() {
        isLoadingLocation = true
        locationManager.requestWhenInUseAuthorization()
        
        if let location = locationManager.location {
            userLocation = location
            updateNearbyAirports()
            isLoadingLocation = false
        } else {
            // Wait a bit for location
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.userLocation = self.locationManager.location
                self.updateNearbyAirports()
                self.isLoadingLocation = false
            }
        }
    }
    
    func updateNearbyAirports() {
        guard let location = userLocation else {
            nearbyAirports = []
            return
        }
        
        // Get all airports and calculate distances
        let allAirports = dbManager.getAllAirports()
        
        // Sort by distance and take only the closest 5
        nearbyAirports = allAirports
            .map { airport -> (airport: AirportInfo, distance: Double) in
                let airportLocation = CLLocation(
                    latitude: airport.coordinate.latitude,
                    longitude: airport.coordinate.longitude
                )
                let distanceMeters = location.distance(from: airportLocation)
                let distanceNM = distanceMeters * 0.000539957 // Convert to nautical miles
                return (airport, distanceNM)
            }
            .sorted { $0.distance < $1.distance }  // Sort by closest first
            .prefix(5)  // Take only 5 nearest
            .map { $0.airport }  // Extract just the airport objects
    }
    
    func distanceToAirport(_ airport: AirportInfo) -> Double? {
        guard let userLoc = userLocation else { return nil }
        
        // ✅ FIXED: Use coordinate.latitude and coordinate.longitude
        let airportLoc = CLLocation(
            latitude: airport.coordinate.latitude,
            longitude: airport.coordinate.longitude
        )
        
        let distanceMeters = userLoc.distance(from: airportLoc)
        return distanceMeters * 0.000539957 // Convert to nautical miles
    }
    
    func loadFavorites() {
        let favoriteICAOs = UserDefaults.standard.stringArray(forKey: "FavoriteAirports") ?? []
        favoriteAirports = favoriteICAOs.compactMap { dbManager.getAirport(for: $0) }
    }
    
    func toggleFavorite(_ airport: AirportInfo) {
        var favorites = UserDefaults.standard.stringArray(forKey: "FavoriteAirports") ?? []
        
        if favorites.contains(airport.icaoCode) {
            favorites.removeAll { $0 == airport.icaoCode }
        } else {
            favorites.append(airport.icaoCode)
        }
        
        UserDefaults.standard.set(favorites, forKey: "FavoriteAirports")
        loadFavorites()
    }
}

// MARK: - Airport Database Settings View

struct AirportDatabaseSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDiagnostics = false

    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: CloudKitDiagnosticView()) {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("System Diagnostics")
                                    .foregroundColor(.white)

                                Text("CloudKit & Database Tests")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } header: {
                    Text("Developer Tools")
                }

                Section {
                    HStack {
                        Text("Total Airports")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(AirportDatabaseManager.shared.getAllAirports().count)")
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("Favorites")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(UserDefaults.standard.stringArray(forKey: "FavoriteAirports")?.count ?? 0)")
                            .foregroundColor(.white)
                    }
                } header: {
                    Text("Database Info")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Airport Database Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(LogbookTheme.accentGreen)
            }
        }
    }
}

// MARK: - Preview

struct AirportDatabaseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AirportDatabaseView()
        }
    }
}

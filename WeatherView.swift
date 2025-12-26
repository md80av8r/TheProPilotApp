// WeatherView.swift - ENHANCED with Nearest tab, TAF, and D-ATIS
// WeatherView.swift - ENHANCED with Nearest tab, TAF, and D-ATIS
import SwiftUI
import CoreLocation

// Weather models are in WeatherModels.swift

// MARK: - Weather Sort Option
enum WeatherSortOption: String, CaseIterable {
    case manual = "Manual Order"
    case alphabetical = "Alphabetical"
    case temperature = "Temperature"
    case flightCategory = "Flight Category"
    case windSpeed = "Wind Speed"
    
    var icon: String {
        switch self {
        case .manual: return "hand.draw"
        case .alphabetical: return "textformat.abc"
        case .temperature: return "thermometer"
        case .flightCategory: return "airplane.circle"
        case .windSpeed: return "wind"
        }
    }
}

// MARK: - Weather Service
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var favoriteAirports: [AirportWeather] = []
    @Published var nearestAirports: [AirportWeather] = []
    @Published var isLoading = false
    @Published var isLoadingNearest = false
    @Published var errorMessage: String?
    @Published var sortOption: WeatherSortOption = .manual
    @Published var userLocation: CLLocation?
    
    private let locationManager = CLLocationManager()
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "FavoriteAirports"
    private let sortOptionKey = "WeatherSortOption"
    private let airportDB = AirportDatabaseManager.shared
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadSortOption()
        loadFavorites()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        locationManager.stopUpdatingLocation()
        updateNearestAirports()
    }
    
    func updateNearestAirports() {
        guard let location = userLocation else { return }
        
        isLoadingNearest = true
        
        Task {
            let allAirports = airportDB.getAllAirports()
            
            let nearby = allAirports
                .compactMap { airport -> (AirportInfo, Double)? in
                    let airportLoc = CLLocation(
                        latitude: airport.coordinate.latitude,
                        longitude: airport.coordinate.longitude
                    )
                    let distanceMeters = location.distance(from: airportLoc)
                    let distanceNM = distanceMeters * 0.000539957
                    
                    if distanceNM <= 100 {
                        return (airport, distanceNM)
                    }
                    return nil
                }
                .sorted { $0.1 < $1.1 }
                .prefix(15)
            
            let icaos = nearby.map { $0.0.icaoCode }
            
            await fetchWeatherForAirports(icaos, isNearest: true, distances: Dictionary(uniqueKeysWithValues: nearby.map { ($0.0.icaoCode, $0.1) }))
            
            await MainActor.run {
                self.isLoadingNearest = false
            }
        }
    }
    
    private func loadSortOption() {
        if let saved = userDefaults.string(forKey: sortOptionKey),
           let option = WeatherSortOption(rawValue: saved) {
            sortOption = option
        }
    }
    
    private func saveSortOption() {
        userDefaults.set(sortOption.rawValue, forKey: sortOptionKey)
    }
    
    func setSortOption(_ option: WeatherSortOption) {
        sortOption = option
        saveSortOption()
        sortAirports()
    }
    
    private func sortAirports() {
        switch sortOption {
        case .manual:
            break
        case .alphabetical:
            favoriteAirports.sort { $0.icao < $1.icao }
        case .temperature:
            favoriteAirports.sort { (a, b) in
                let tempA = a.metar?.temp ?? -999
                let tempB = b.metar?.temp ?? -999
                return tempA > tempB
            }
        case .flightCategory:
            let categoryOrder: [String: Int] = ["VFR": 0, "MVFR": 1, "IFR": 2, "LIFR": 3]
            favoriteAirports.sort { (a, b) in
                let catA = categoryOrder[a.metar?.flightCategory ?? ""] ?? 999
                let catB = categoryOrder[b.metar?.flightCategory ?? ""] ?? 999
                return catA < catB
            }
        case .windSpeed:
            favoriteAirports.sort { (a, b) in
                let windA = a.metar?.windSpeed ?? 0
                let windB = b.metar?.windSpeed ?? 0
                return windA > windB
            }
        }
    }
    
    func moveAirport(from source: IndexSet, to destination: Int) {
        favoriteAirports.move(fromOffsets: source, toOffset: destination)
        saveFavorites(favoriteAirports.map { $0.icao })
    }
    
    func loadFavorites() {
        let favorites: [String]
        
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            favorites = decoded
        } else {
            favorites = ["KDTW", "KCLE", "KPTK", "KYIP", "KLRD"]
            saveFavorites(favorites)
        }
        
        print("🛫 Loading weather for: \(favorites.joined(separator: ", "))")
        
        Task {
            await fetchWeatherForAirports(favorites, isNearest: false)
        }
    }
    
    func fetchWeatherForAirports(_ icaos: [String], isNearest: Bool, distances: [String: Double] = [:]) async {
        let validIcaos = icaos.filter { !$0.isEmpty }
        
        guard !validIcaos.isEmpty else {
            print("⚠️ No valid ICAO codes to fetch")
            return
        }
        
        await MainActor.run {
            if isNearest {
                isLoadingNearest = true
            } else {
                isLoading = true
            }
            errorMessage = nil
        }
        
        let icaoString = validIcaos.joined(separator: ",")
        
        guard let metarURL = URL(string: "https://aviationweather.gov/api/data/metar?ids=\(icaoString)&format=json") else {
            await MainActor.run {
                if isNearest {
                    self.isLoadingNearest = false
                } else {
                    self.isLoading = false
                }
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        guard let tafURL = URL(string: "https://aviationweather.gov/api/data/taf?ids=\(icaoString)&format=json") else {
            return
        }
        
        print("🌐 Fetching METAR from: \(metarURL.absoluteString)")
        print("🌐 Fetching TAF from: \(tafURL.absoluteString)")
        
        do {
            async let metarData = URLSession.shared.data(from: metarURL)
            async let tafData = URLSession.shared.data(from: tafURL)
            
            let (metarResult, _) = try await metarData
            let metars = try JSONDecoder().decode([RawMETAR].self, from: metarResult)
            print("✅ Decoded \(metars.count) METARs")
            
            var tafs: [RawTAF] = []
            do {
                let (tafResult, _) = try await tafData
                tafs = try JSONDecoder().decode([RawTAF].self, from: tafResult)
                print("✅ Decoded \(tafs.count) TAFs")
            } catch {
                print("⚠️ TAF fetch failed: \(error)")
            }
            
            var newAirports: [AirportWeather] = []
            for icao in validIcaos {
                let metar = metars.first(where: { $0.icaoId == icao })
                let taf = tafs.first(where: { $0.icaoId == icao })
                
                // Debug logging for TAF
                if let taf = taf {
                    print("✅ TAF found for \(icao): \(taf.rawTAF.prefix(50))...")
                } else {
                    print("⚠️ No TAF for \(icao)")
                }
                
                if let metar = metar {
                    // Debug altimeter value
                    print("Altimeter value for \(icao): \(metar.altim ?? 0)")
                    
                    let airportWeather = AirportWeather(
                        icao: icao,
                        name: airportDB.getAirportName(for: icao),
                        metar: METARData(
                            rawOb: metar.rawOb,
                            flightCategory: metar.flightCategory,
                            temp: metar.temp,
                            dewpoint: metar.dewp,
                            windDir: metar.windDirection,
                            windSpeed: metar.wspd,
                            windGust: metar.wgst,
                            visibility: metar.visibility,
                            altimeter: metar.altim,
                            clouds: metar.cover,
                            wxString: metar.wxString,
                            obsTime: metar.reportTime
                        ),
                        taf: taf != nil ? TAFData(
                            rawTAF: taf!.rawTAF,
                            issueTime: taf!.issueTimeString,
                            validFrom: nil,
                            validTo: nil
                        ) : nil,
                        hasTAF: taf != nil,
                        isFavorite: !isNearest,
                        distance: distances[icao]
                    )
                    newAirports.append(airportWeather)
                    print("✅ Added weather for \(icao): \(metar.temp ?? 0)°C, TAF: \(taf != nil)")
                }
            }
            
            await MainActor.run { [newAirports] in
                if isNearest {
                    self.nearestAirports = newAirports
                    self.isLoadingNearest = false
                } else {
                    self.favoriteAirports = newAirports
                    self.sortAirports()
                    self.isLoading = false
                }
                
                if newAirports.isEmpty {
                    self.errorMessage = "No weather data available"
                }
            }
        } catch {
            print("❌ Error fetching weather: \(error)")
            await MainActor.run {
                if isNearest {
                    self.isLoadingNearest = false
                } else {
                    self.isLoading = false
                }
                self.errorMessage = "Failed to load weather data"
            }
        }
    }
    
    func addAirport(_ icao: String) {
        var favorites = favoriteAirports.map { $0.icao }
        if !favorites.contains(icao.uppercased()) {
            favorites.append(icao.uppercased())
            saveFavorites(favorites)
            Task {
                await fetchWeatherForAirports(favorites, isNearest: false)
            }
        }
    }
    
    func removeAirport(_ icao: String) {
        favoriteAirports.removeAll { $0.icao == icao }
        saveFavorites(favoriteAirports.map { $0.icao })
        sortAirports()
    }
    
    private func saveFavorites(_ icaos: [String]) {
        if let encoded = try? JSONEncoder().encode(icaos) {
            userDefaults.set(encoded, forKey: favoritesKey)
        }
    }
    
    func refresh() {
        let favorites = favoriteAirports.map { $0.icao }
        Task {
            await fetchWeatherForAirports(favorites, isNearest: false)
        }
        if userLocation != nil {
            updateNearestAirports()
        }
    }
}

// MARK: - Main Weather View
struct WeatherView: View {
    @StateObject private var weatherService = WeatherService()
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    @State private var newAirportCode = ""
    @State private var selectedTab: WeatherTab = .favorites
    @FocusState private var isSearchFocused: Bool
    
    enum WeatherTab: String, CaseIterable {
        case nearest = "Nearest"
        case favorites = "Favorites"
        
        var icon: String {
            switch self {
            case .nearest: return "location.circle.fill"
            case .favorites: return "star.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if selectedTab == .favorites {
                        HStack(spacing: 12) {
                            EnhancedICAOTextField(
                                text: $newAirportCode,
                                placeholder: "Add Airport (ICAO)"
                            )
                            .focused($isSearchFocused)
                            .onSubmit {
                                if newAirportCode.count == 4 {
                                    weatherService.addAirport(newAirportCode)
                                    newAirportCode = ""
                                    isSearchFocused = false
                                }
                            }
                            
                            Menu {
                                ForEach(WeatherSortOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        weatherService.setSortOption(option)
                                    }) {
                                        HStack {
                                            Image(systemName: option.icon)
                                            Text(option.rawValue)
                                            if weatherService.sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.orange.opacity(0.3))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: { weatherService.refresh() }) {
                                Image(systemName: weatherService.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(10)
                                    .rotationEffect(.degrees(weatherService.isLoading ? 360 : 0))
                                    .animation(weatherService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: weatherService.isLoading)
                            }
                        }
                        .padding()
                    }
                    
                    HStack(spacing: 0) {
                        ForEach(WeatherTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                    if tab == .nearest && weatherService.userLocation == nil {
                                        weatherService.requestLocationPermission()
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                    Text(tab.rawValue)
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedTab == tab ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedTab == tab ?
                                    LogbookTheme.accentGreen : Color.clear
                                )
                            }
                        }
                    }
                    .background(LogbookTheme.navyLight)
                    
                    if let error = weatherService.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    switch selectedTab {
                    case .nearest:
                        nearestAirportsView
                    case .favorites:
                        favoritesView
                    }
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { weatherService.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
        }
    }
    
    private var nearestAirportsView: some View {
        Group {
            if weatherService.isLoadingNearest {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Finding nearest airports...")
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else if weatherService.nearestAirports.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("No Nearby Airports")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Enable location services to see nearby weather")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { weatherService.requestLocationPermission() }) {
                        Text("Enable Location")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .background(LogbookTheme.accentBlue)
                            .cornerRadius(12)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(weatherService.nearestAirports) { airport in
                            DenseAirportWeatherRow(airport: airport, showDistance: true)
                        }
                    }
                }
            }
        }
    }
    
    private var favoritesView: some View {
        Group {
            if weatherService.isLoading && weatherService.favoriteAirports.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading weather data...")
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else if weatherService.favoriteAirports.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No airports added")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Enter an ICAO code above to add an airport")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(weatherService.favoriteAirports) { airport in
                            DenseAirportWeatherRow(
                                airport: airport,
                                showDistance: false,
                                onDelete: {
                                    weatherService.removeAirport(airport.icao)
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .deleteDisabled(true)  // Disable system delete button
                        }
                        .onMove { source, destination in
                            if weatherService.sortOption == .manual {
                                weatherService.moveAirport(from: source, to: destination)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(LogbookTheme.navy)
                    .environment(\.editMode, weatherService.sortOption == .manual ? .constant(.active) : .constant(.inactive))
                    
                    if weatherService.sortOption != .manual {
                        HStack {
                            Image(systemName: weatherService.sortOption.icon)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Sorted by \(weatherService.sortOption.rawValue)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        .background(LogbookTheme.navy)
                    } else {
                        Text("Drag ☰ to reorder")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.navy)
                    }
                }
            }
        }
    }
}

// MARK: - Dense Airport Weather Row
struct DenseAirportWeatherRow: View {
    let airport: AirportWeather
    var showDistance: Bool = false
    var onDelete: (() -> Void)? = nil
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    @State private var showDetail = false
    
    var body: some View {
        HStack(spacing: 0) {
            if let delete = onDelete {
                Button(action: delete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 40)
                }
            }
            
            Button(action: { showDetail = true }) {
                VStack(spacing: 2) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(airport.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(airport.icao)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    if let metar = airport.metar {
                        HStack(alignment: .center, spacing: 8) {
                            if let dir = metar.windDir, let spd = metar.windSpeed {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.north.fill")
                                        .rotationEffect(.degrees(Double(dir)))
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                    
                                    Text("\(String(format: "%03d", dir))° \(spd)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    if let gust = metar.windGust {
                                        Text("kt")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 8))
                                            .foregroundColor(.white)
                                        
                                        Text("\(gust)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("kt")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("kt")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else if let spd = metar.windSpeed, spd > 0 {
                                HStack(spacing: 3) {
                                    Text("var \(spd) kt")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Text("calm")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                if let temp = metar.temp {
                                    let tempStr = settingsStore.useCelsius 
                                        ? String(format: "%.1f°C", temp)
                                        : String(format: "%.1f°F", (temp * 9/5) + 32)
                                    Text(tempStr)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 2) {
                                    if let category = metar.flightCategory {
                                        Text(category)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(metar.categoryColor)
                                            .cornerRadius(3)
                                    }
                                    
                                    if metar.rawOb.contains("AMD") || metar.rawOb.contains("COR") {
                                        Text(metar.rawOb.contains("AMD") ? "AMD" : "COR")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.gray)
                                            .cornerRadius(3)
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                        
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                if let vis = metar.visibility {
                                    if vis >= 10.0 {
                                        Text("10+ miles")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(String(format: "%.1f", vis)) miles")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text(parseSkyConditions(metar.rawOb))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                if let dew = metar.dewpoint, let hum = metar.humidity {
                                    let dewStr = settingsStore.useCelsius
                                        ? String(format: "%.1f°C", dew)
                                        : String(format: "%.1f°F", (dew * 9/5) + 32)
                                    Text("\(dewStr) \(hum)%")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                }
                                
                                HStack(spacing: 0) {
                                    if let alt = metar.altimeter {
                                        let pressureText = settingsStore.usePressureInHg
                                            ? String(format: "%.2f inHg", alt)
                                            : String(format: "%.0f mb", alt * 33.8639)
                                        let unitText = settingsStore.usePressureInHg ? "inHg" : "mb"
                                        
                                        HStack(spacing: 2) {
                                            Text(pressureText.replacingOccurrences(of: " \(unitText)", with: ""))
                                                .font(.system(size: 11))
                                                .foregroundColor(.white)
                                            Text(unitText)
                                                .font(.system(size: 8))
                                                .foregroundColor(.gray)
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 7))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                        
                        HStack {
                            Spacer()
                            
                            if showDistance, let distance = airport.distance {
                                Text("\(Int(distance)) nm")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            } else {
                                Text(parseTimeAgo(metar.rawOb))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.top, 1)
                        
                    } else {
                        Text("No weather data available")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
        }
        .background(LogbookTheme.navyLight)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
        .sheet(isPresented: $showDetail) {
            AirportWeatherDetailView(airport: airport)
        }
    }
    
    private func parseSkyConditions(_ rawMETAR: String) -> String {
        let components = rawMETAR.components(separatedBy: " ")
        var skyConditions: [String] = []
        
        for component in components {
            if component.hasPrefix("FEW") {
                let height = component.dropFirst(3)
                skyConditions.append("few clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("SCT") {
                let height = component.dropFirst(3)
                skyConditions.append("scattered clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("BKN") {
                let height = component.dropFirst(3)
                skyConditions.append("broken clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("OVC") {
                let height = component.dropFirst(3)
                skyConditions.append("overcast clouds at \(formatCeiling(String(height))) ft")
            } else if component == "CLR" || component == "SKC" {
                return "clear"
            }
        }
        
        return skyConditions.first ?? "clear"
    }
    
    private func formatCeiling(_ ceiling: String) -> String {
        guard let value = Int(ceiling) else { return ceiling }
        return "\(value * 100)"
    }
    
    private func parseTimeAgo(_ rawMETAR: String) -> String {
        let components = rawMETAR.components(separatedBy: " ")
        
        for component in components {
            if component.hasSuffix("Z") && component.count == 7 {
                let day = Int(component.prefix(2)) ?? 0
                let hour = Int(component.dropFirst(2).prefix(2)) ?? 0
                let minute = Int(component.dropFirst(4).prefix(2)) ?? 0
                
                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.year, .month], from: Date())
                dateComponents.day = day
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.timeZone = TimeZone(identifier: "UTC")
                
                if let metarDate = calendar.date(from: dateComponents) {
                    let elapsed = Date().timeIntervalSince(metarDate)
                    let minutes = Int(elapsed / 60)
                    
                    if minutes < 60 {
                        return "\(minutes) min"
                    } else {
                        let hours = Int(elapsed / 3600)
                        return "\(hours) hr"
                    }
                }
            }
        }
        
        return "Unknown"
    }
}

// MARK: - Airport Weather Detail View
struct AirportWeatherDetailView: View {
    let airport: AirportWeather
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: DetailTab = .decoded
    @State private var datisText: String?
    @State private var isLoadingDATIS = false
    @State private var arrivalATIS: String?
    @State private var departureATIS: String?
    @State private var selectedATISType: ATISType = .arrival
    
    enum DetailTab: String, CaseIterable {
        case decoded = "Decoded"
        case raw = "Raw"
        
        var icon: String {
            switch self {
            case .decoded: return "text.alignleft"
            case .raw: return "doc.text"
            }
        }
    }
    
    enum ATISType: String, CaseIterable {
        case arrival = "Arrival"
        case departure = "Departure"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text(airport.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(airport.icao)
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        
                        if let metar = airport.metar {
                            HStack(spacing: 0) {
                                ForEach(DetailTab.allCases, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation {
                                            selectedTab = tab
                                        }
                                    }) {
                                        Text(tab.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(selectedTab == tab ? .white : .gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selectedTab == tab ? LogbookTheme.accentGreen : Color.clear)
                                    }
                                }
                            }
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("METAR")
                                        .font(.headline)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    
                                    Spacer()
                                    
                                    if let category = metar.flightCategory {
                                        Text(category)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(metar.categoryColor)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(parseTimeAgo(metar.rawOb))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                
                                if selectedTab == .raw {
                                    Text(metar.rawOb)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                } else {
                                    VStack(spacing: 12) {
                                        DetailRowWx(
                                            label: "Wind",
                                            value: formatWind(metar)
                                        )
                                        
                                        if let vis = metar.visibility {
                                            DetailRowWx(
                                                label: "Visibility",
                                                value: vis >= 10.0 ? "10+ miles" : "\(String(format: "%.1f", vis)) miles"
                                            )
                                        }
                                        
                                        DetailRowWx(
                                            label: "Sky",
                                            value: parseSkyConditions(metar.rawOb)
                                        )
                                        
                                        if let temp = metar.temp {
                                            let tempStr = settingsStore.useCelsius
                                                ? String(format: "%.1f°C", temp)
                                                : String(format: "%.1f°F", (temp * 9/5) + 32)
                                            DetailRowWx(
                                                label: "Temperature",
                                                value: tempStr
                                            )
                                        }
                                        
                                        if let dew = metar.dewpoint, let hum = metar.humidity {
                                            let dewStr = settingsStore.useCelsius
                                                ? String(format: "%.1f°C", dew)
                                                : String(format: "%.1f°F", (dew * 9/5) + 32)
                                            DetailRowWx(
                                                label: "Dew point",
                                                value: "\(dewStr), Relative humidity: \(hum)%"
                                            )
                                        }
                                        
                                        if let alt = metar.altimeter {
                                            let pressureText = settingsStore.usePressureInHg
                                                ? String(format: "%.2f inHg", alt)
                                                : String(format: "%.0f mb", alt * 33.8639)
                                            DetailRowWx(
                                                label: "Pressure",
                                                value: pressureText
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            if let taf = airport.taf {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("TAF")
                                            .font(.headline)
                                            .foregroundColor(LogbookTheme.accentGreen)
                                        
                                        Spacer()
                                        
                                        if let issueTime = taf.issueTime {
                                            Text(issueTime)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    if selectedTab == .raw {
                                        Text(taf.rawTAF)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(8)
                                    } else {
                                        Text(formatTAF(taf.rawTAF))
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(LogbookTheme.navyLight)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("D-ATIS")
                                        .font(.headline)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        fetchDATIS()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Refresh")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(LogbookTheme.accentGreen.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                if isLoadingDATIS {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading D-ATIS...")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else if arrivalATIS != nil || departureATIS != nil {
                                    // Segmented control for Arrival/Departure
                                    Picker("ATIS Type", selection: $selectedATISType) {
                                        ForEach(ATISType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.bottom, 8)
                                    
                                    // Display selected ATIS
                                    if let atis = selectedATISType == .arrival ? arrivalATIS : departureATIS {
                                        ScrollView {
                                            Text(atis)
                                                .font(.system(.subheadline, design: .monospaced))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxHeight: 300)
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "info.circle")
                                                .font(.title2)
                                                .foregroundColor(.gray)
                                            Text("\(selectedATISType.rawValue) ATIS not available")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .italic()
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                        
                                        Text("D-ATIS not loaded")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        Text("Tap Refresh to load D-ATIS information")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                            }
                            .padding()
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            Text("No weather data available")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
    }
    
    private func fetchDATIS() {
        isLoadingDATIS = true
        
        Task {
            // Try multiple D-ATIS sources
            let sources = [
                "https://datis.clowd.io/api/\(airport.icao)",
                "https://api.aviationapi.com/v1/weather/station/\(airport.icao)/atis"
            ]
            
            for sourceURL in sources {
                guard let url = URL(string: sourceURL) else { continue }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    // Log the raw response
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📡 D-ATIS Response from \(sourceURL):")
                        print(jsonString)
                    }
                    
                    // Try parsing as array (clowd.io returns array)
                    if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        // Structure: [{"datis": "...", "type": "arr"}, {"datis": "...", "type": "dep"}]
                        var arrATIS: String?
                        var depATIS: String?
                        
                        for item in jsonArray {
                            if let datis = item["datis"] as? String,
                               let type = item["type"] as? String {
                                if type.uppercased() == "ARR" {
                                    arrATIS = datis
                                } else if type.uppercased() == "DEP" {
                                    depATIS = datis
                                }
                            }
                        }
                        
                        // If we found at least one ATIS
                        if arrATIS != nil || depATIS != nil {
                            await MainActor.run {
                                arrivalATIS = arrATIS
                                departureATIS = depATIS
                                // Auto-select the available one
                                if arrATIS != nil {
                                    selectedATISType = .arrival
                                } else if depATIS != nil {
                                    selectedATISType = .departure
                                }
                                isLoadingDATIS = false
                            }
                            print("✅ D-ATIS parsed successfully from \(sourceURL) - Arrival: \(arrATIS != nil), Departure: \(depATIS != nil)")
                            return
                        }
                    }
                    
                    // Try parsing as single object
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Structure 1: { "datis": "..." }
                        if let datis = json["datis"] as? String {
                            await MainActor.run {
                                // If it's a single ATIS, put it in both
                                arrivalATIS = datis
                                departureATIS = datis
                                isLoadingDATIS = false
                            }
                            print("✅ D-ATIS parsed successfully from \(sourceURL)")
                            return
                        }
                        
                        // Structure 2: { "atis": "..." }
                        if let atis = json["atis"] as? String {
                            await MainActor.run {
                                arrivalATIS = atis
                                departureATIS = atis
                                isLoadingDATIS = false
                            }
                            print("✅ D-ATIS parsed successfully from \(sourceURL)")
                            return
                        }
                        
                        // Structure 3: { "data": { "atis": "..." } }
                        if let dataObj = json["data"] as? [String: Any],
                           let atis = dataObj["atis"] as? String {
                            await MainActor.run {
                                arrivalATIS = atis
                                departureATIS = atis
                                isLoadingDATIS = false
                            }
                            print("✅ D-ATIS parsed successfully from \(sourceURL)")
                            return
                        }
                    }
                } catch {
                    print("❌ D-ATIS fetch failed from \(sourceURL): \(error)")
                    continue
                }
            }
            
            // If all sources fail
            await MainActor.run {
                arrivalATIS = nil
                departureATIS = nil
                isLoadingDATIS = false
                print("⚠️ D-ATIS not available from any source for \(airport.icao)")
            }
        }
    }
    
    private func formatTAF(_ rawTAF: String) -> String {
        let lines = rawTAF.components(separatedBy: " FM")
        return lines.joined(separator: "\nFM")
    }
    
    private func formatWind(_ metar: METARData) -> String {
        if let dir = metar.windDir, let spd = metar.windSpeed {
            if let gust = metar.windGust {
                return "\(String(format: "%03d", dir))° at \(spd) knots, gusts \(gust) knots"
            } else {
                return "\(String(format: "%03d", dir))° at \(spd) knots"
            }
        } else if let spd = metar.windSpeed {
            return "Variable at \(spd) knots"
        }
        return "Calm"
    }
    
    private func parseSkyConditions(_ rawMETAR: String) -> String {
        let components = rawMETAR.components(separatedBy: " ")
        var skyConditions: [String] = []
        
        for component in components {
            if component.hasPrefix("FEW") {
                let height = component.dropFirst(3)
                skyConditions.append("few clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("SCT") {
                let height = component.dropFirst(3)
                skyConditions.append("scattered clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("BKN") {
                let height = component.dropFirst(3)
                skyConditions.append("broken clouds at \(formatCeiling(String(height))) ft")
            } else if component.hasPrefix("OVC") {
                let height = component.dropFirst(3)
                skyConditions.append("overcast clouds at \(formatCeiling(String(height))) ft")
            } else if component == "CLR" || component == "SKC" {
                return "clear"
            }
        }
        
        return skyConditions.isEmpty ? "clear" : skyConditions.joined(separator: ", ")
    }
    
    private func formatCeiling(_ ceiling: String) -> String {
        guard let value = Int(ceiling) else { return ceiling }
        return "\(value * 100)"
    }
    
    private func parseTimeAgo(_ rawMETAR: String) -> String {
        let components = rawMETAR.components(separatedBy: " ")
        
        for component in components {
            if component.hasSuffix("Z") && component.count == 7 {
                let day = Int(component.prefix(2)) ?? 0
                let hour = Int(component.dropFirst(2).prefix(2)) ?? 0
                let minute = Int(component.dropFirst(4).prefix(2)) ?? 0
                
                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.year, .month], from: Date())
                dateComponents.day = day
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.timeZone = TimeZone(identifier: "UTC")
                
                if let metarDate = calendar.date(from: dateComponents) {
                    let elapsed = Date().timeIntervalSince(metarDate)
                    let minutes = Int(elapsed / 60)
                    
                    if minutes < 60 {
                        return "\(minutes) min"
                    } else {
                        let hours = Int(elapsed / 3600)
                        return "\(hours) hr"
                    }
                }
            }
        }
        
        return "Unknown"
    }
}

// MARK: - Detail Row Component
struct DetailRowWx: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview
struct WeatherView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherView()
            .preferredColorScheme(.dark)
    }
}

// WeatherView.swift - FIXED with proper API parsing and enhanced ICAO picker
import SwiftUI
import CoreLocation

// MARK: - Weather Models (Matching actual API response)
struct AirportWeather: Identifiable, Codable {
    let id = UUID()
    let icao: String
    let name: String
    let metar: METARData?
    let hasTAF: Bool
    var isFavorite: Bool
    var distance: Double? // In nautical miles
    
    enum CodingKeys: String, CodingKey {
        case icao, name, metar, hasTAF, isFavorite, distance
    }
}

struct METARData: Codable {
    let rawOb: String
    let flightCategory: String?
    let temp: Double?
    let dewpoint: Double?
    let windDir: Int?
    let windSpeed: Int?
    let windGust: Int?
    let visibility: Double?
    let altimeter: Double?
    let clouds: String?
    let wxString: String?
    let obsTime: String?
    
    var categoryColor: Color {
        switch flightCategory {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return .purple
        default: return .gray
        }
    }
    
    var humidity: Int? {
        guard let t = temp, let d = dewpoint else { return nil }
        let humidity = 100 * (exp((17.625 * d) / (243.04 + d)) / exp((17.625 * t) / (243.04 + t)))
        return Int(humidity)
    }
}

// Raw METAR from API (actual aviationweather.gov format)
struct RawMETAR: Codable {
    let icaoId: String
    let rawOb: String
    let flightCategory: String?
    let temp: Double?
    let dewp: Double?
    let wdirRaw: WindDirection?  // Can be Int or String ("VRB", "CALM")
    let wspd: Int?
    let wgst: Int?
    let visib: String?  // Can be "10+" or a number
    let altim: Double?
    let cover: String?
    let wxString: String?
    let obsTime: Int?  // Unix timestamp
    let reportTime: String?
    
    enum CodingKeys: String, CodingKey {
        case icaoId, rawOb, flightCategory, temp, dewp, wspd, wgst, visib, altim, cover, wxString, obsTime, reportTime
        case wdirRaw = "wdir"
    }
    
    var windDirection: Int? {
        if case .degrees(let value) = wdirRaw {
            return value
        }
        return nil
    }
    
    var windText: String? {
        if case .text(let value) = wdirRaw {
            return value
        }
        return nil
    }
    
    var visibility: Double? {
        guard let vis = visib else { return nil }
        // Handle "10+" format
        if vis.contains("+") {
            return 10.0
        }
        return Double(vis)
    }
    
    var observationTime: String? {
        // Use reportTime if available, otherwise format obsTime
        if let reportTime = reportTime {
            return reportTime
        }
        if let timestamp = obsTime {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date)
        }
        return nil
    }
}

// Handle wind direction that can be Int or String
enum WindDirection: Codable {
    case degrees(Int)
    case text(String)  // "VRB", "CALM"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .degrees(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                WindDirection.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or String for wind direction"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .degrees(let value):
            try container.encode(value)
        case .text(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Sort Options
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
class WeatherService: ObservableObject {
    @Published var airports: [AirportWeather] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sortOption: WeatherSortOption = .manual
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "FavoriteAirports"
    private let sortOptionKey = "WeatherSortOption"
    private let airportDB = AirportDatabaseManager()
    
    init() {
        loadSortOption()
        loadFavorites()
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
            // Keep current order (order added)
            break
            
        case .alphabetical:
            airports.sort { $0.icao < $1.icao }
            
        case .temperature:
            airports.sort { (a, b) in
                let tempA = a.metar?.temp ?? -999
                let tempB = b.metar?.temp ?? -999
                return tempA > tempB // Hottest first
            }
            
        case .flightCategory:
            let categoryOrder: [String: Int] = ["VFR": 0, "MVFR": 1, "IFR": 2, "LIFR": 3]
            airports.sort { (a, b) in
                let catA = categoryOrder[a.metar?.flightCategory ?? ""] ?? 999
                let catB = categoryOrder[b.metar?.flightCategory ?? ""] ?? 999
                return catA < catB
            }
            
        case .windSpeed:
            airports.sort { (a, b) in
                let windA = a.metar?.windSpeed ?? 0
                let windB = b.metar?.windSpeed ?? 0
                return windA > windB // Windiest first
            }
        }
    }
    
    func moveAirport(from source: IndexSet, to destination: Int) {
        airports.move(fromOffsets: source, toOffset: destination)
        // Save new order
        saveFavorites(airports.map { $0.icao })
    }
    
    func loadFavorites() {
        // Load saved favorites
        let favorites: [String]
        
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            favorites = decoded
        } else {
            // Default airports
            favorites = ["KDAB", "KATL", "KJFK", "KLAX", "KORD"]
            // Save defaults for next time
            saveFavorites(favorites)
        }
        
        print("🛫 Loading weather for: \(favorites.joined(separator: ", "))")
        
        Task {
            await fetchWeatherForAirports(favorites)
        }
    }
    
    func fetchWeatherForAirports(_ icaos: [String]) async {
        // Filter out empty strings and ensure we have airports to fetch
        let validIcaos = icaos.filter { !$0.isEmpty }
        
        guard !validIcaos.isEmpty else {
            print("⚠️ No valid ICAO codes to fetch")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let icaoString = validIcaos.joined(separator: ",")
        guard let url = URL(string: "https://aviationweather.gov/api/data/metar?ids=\(icaoString)&format=json") else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Invalid URL"
            }
            return
        }
        
        print("🌐 Fetching weather from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Debug: Print response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                // Handle error responses
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ API Error: \(errorString)")
                    }
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Server returned error (HTTP \(httpResponse.statusCode))"
                    }
                    return
                }
            }
            
            // Debug: Print raw JSON
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Raw JSON response: \(jsonString.prefix(500))...")
                    }
                    
                    let metars = try JSONDecoder().decode([RawMETAR].self, from: data)
                    print("✅ Decoded \(metars.count) METARs")
                    
                    var newAirports: [AirportWeather] = []
                    for icao in validIcaos {
                        if let metar = metars.first(where: { $0.icaoId == icao }) {
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
                                    obsTime: metar.observationTime
                                ),
                                hasTAF: false,
                                isFavorite: true,
                                distance: nil
                            )
                            newAirports.append(airportWeather)
                            print("✅ Added weather for \(icao): \(metar.temp ?? 0)°C, \(metar.flightCategory ?? "N/A")")
                        } else {
                            print("⚠️ No METAR found for \(icao)")
                        }
                    }
                    
                    await MainActor.run { [newAirports] in
                        self.airports = newAirports
                        self.sortAirports()
                        self.isLoading = false
                        if newAirports.isEmpty {
                            self.errorMessage = "No weather data available for selected airports"
                        }
                    }
                } catch {
                    print("❌ Error fetching weather: \(error)")
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Failed to load weather data"
                    }
                }
            }
    
    func addAirport(_ icao: String) {
        var favorites = airports.map { $0.icao }
        if !favorites.contains(icao.uppercased()) {
            favorites.append(icao.uppercased())
            saveFavorites(favorites)
            Task {
                await fetchWeatherForAirports(favorites)
            }
        }
    }
    
    func removeAirport(_ icao: String) {
        airports.removeAll { $0.icao == icao }
        saveFavorites(airports.map { $0.icao })
        sortAirports()
    }
    
    private func saveFavorites(_ icaos: [String]) {
        if let encoded = try? JSONEncoder().encode(icaos) {
            userDefaults.set(encoded, forKey: favoritesKey)
        }
    }
    
    func refresh() {
        let favorites = airports.map { $0.icao }
        Task {
            await fetchWeatherForAirports(favorites)
        }
    }
}

// MARK: - Main Weather View
struct WeatherView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var newAirportCode = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search/Add Bar with Enhanced ICAO TextField
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
                        
                        // Sort Menu
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
                    
                    // Error Message
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
                    
                    // Airport List
                    if weatherService.isLoading && weatherService.airports.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Loading weather data...")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else if weatherService.airports.isEmpty {
                        Spacer()
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
                        Spacer()
                    } else {
                        VStack(spacing: 0) {
                            List {
                                ForEach(weatherService.airports) { airport in
                                    AirportWeatherRow(airport: airport, onDelete: {
                                        weatherService.removeAirport(airport.icao)
                                    })
                                    .listRowBackground(LogbookTheme.navyLight)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                                .onMove { source, destination in
                                    if weatherService.sortOption == .manual {
                                        weatherService.moveAirport(from: source, to: destination)
                                    }
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { index in
                                        weatherService.removeAirport(weatherService.airports[index].icao)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(LogbookTheme.navy)
                            .environment(\.editMode, weatherService.sortOption == .manual ? .constant(.active) : .constant(.inactive))
                            
                            // Sort indicator
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
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Airport Weather Row
struct AirportWeatherRow: View {
    let airport: AirportWeather
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(alignment: .leading, spacing: 8) {
                // Airport Name & Code
                HStack {
                    Text(airport.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(airport.icao)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // Weather Data Row
                if let metar = airport.metar {
                    HStack(alignment: .top, spacing: 16) {
                        // Left: Wind & Conditions
                        VStack(alignment: .leading, spacing: 4) {
                            // Wind
                            if let dir = metar.windDir, let spd = metar.windSpeed {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.north.fill")
                                        .rotationEffect(.degrees(Double(dir)))
                                        .foregroundColor(.red)
                                        .font(.system(size: 12))
                                    
                                    if let gust = metar.windGust {
                                        Text("\(String(format: "%03d", dir))° \(spd) G\(gust) kt")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(String(format: "%03d", dir))° \(spd) kt")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else if let spd = metar.windSpeed, spd > 0 {
                                // Variable wind (has speed but no direction)
                                HStack(spacing: 4) {
                                    Image(systemName: "wind")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 12))
                                    
                                    if let gust = metar.windGust {
                                        Text("VRB \(spd) G\(gust) kt")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("VRB \(spd) kt")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else {
                                // Calm
                                Text("calm")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Visibility & Conditions
                            HStack(spacing: 8) {
                                if let vis = metar.visibility {
                                    if vis >= 10.0 {
                                        Text("10+ miles")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("\(String(format: "%.1f", vis)) miles")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                if let wx = metar.wxString {
                                    Text(wx)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            // Sky Condition
                            if let clouds = metar.clouds {
                                Text(clouds)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("clear")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Temp, Pressure, Category
                        VStack(alignment: .trailing, spacing: 4) {
                            // Temperature
                            if let temp = metar.temp {
                                HStack(spacing: 4) {
                                    Text("\(Int(temp))°C")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    if let category = metar.flightCategory {
                                        Text(category)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(metar.categoryColor)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            
                            // Dewpoint & Humidity
                            if let dew = metar.dewpoint, let hum = metar.humidity {
                                Text("\(Int(dew))°C \(hum)%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Altimeter
                            if let alt = metar.altimeter {
                                HStack(spacing: 2) {
                                    Text(String(format: "%.2f", alt))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("inHg")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 8))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // TAF indicator
                            if airport.hasTAF {
                                Text("TAF")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.4))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    // Distance (if available)
                    if let distance = airport.distance {
                        Text("\(Int(distance)) min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Text("No weather data available")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove from Favorites", systemImage: "trash")
                }
            }
        }
        .background(LogbookTheme.navyLight)
    }
}

// MARK: - Preview
struct WeatherView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherView()
            .preferredColorScheme(.dark)
    }
}

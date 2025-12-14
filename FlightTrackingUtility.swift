// FlightTrackingUtility.swift - USA Jet Fleet Tracker (Fixed)
import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Flight Data Models
struct TrackedFlight: Identifiable, Codable {
    var id = UUID()
    let icao24: String
    let callsign: String
    let originCountry: String
    let timePosition: TimeInterval?
    let lastContact: TimeInterval
    let longitude: Double?
    let latitude: Double?
    let baroAltitude: Double?
    let onGround: Bool
    let velocity: Double?
    let trueTrack: Double?
    let verticalRate: Double?
    let sensors: [Int]?
    let geoAltitude: Double?
    let squawk: String?
    let spi: Bool
    let positionSource: Int
    
    // Flight track history - using FlightTrackPoint to avoid naming conflict
    var trackHistory: [FlightTrackPoint] = []
    
    var isUSAJet: Bool {
        return callsign.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("JUS")
    }
    
    var displayCallsign: String {
        return callsign.trimmingCharacters(in: .whitespaces)
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var altitudeString: String {
        if let altitude = baroAltitude {
            return "\(Int(altitude * 3.28084))ft" // Convert meters to feet
        }
        return "N/A"
    }
    
    var speedString: String {
        if let velocity = velocity {
            let knots = velocity * 1.94384 // Convert m/s to knots
            return "\(Int(knots)) kts"
        }
        return "N/A"
    }
    
    var headingString: String {
        if let track = trueTrack {
            return "\(Int(track))°"
        }
        return "N/A"
    }
    
    var statusString: String {
        if onGround {
            return "On Ground"
        } else if let altitude = baroAltitude, altitude > 100 {
            return "In Flight"
        } else {
            return "Unknown"
        }
    }
    
    var statusColor: Color {
        if onGround {
            return .orange
        } else if let _ = baroAltitude {
            return .green
        } else {
            return .gray
        }
    }
    
    var lastSeenString: String {
        let timeSince = Date().timeIntervalSince1970 - lastContact
        let minutes = Int(timeSince / 60)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
    
    // Custom Codable implementation to handle trackHistory
    enum CodingKeys: String, CodingKey {
        case id, icao24, callsign, originCountry, timePosition, lastContact
        case longitude, latitude, baroAltitude, onGround, velocity, trueTrack
        case verticalRate, sensors, geoAltitude, squawk, spi, positionSource
        case trackHistory
    }
}

// MARK: - Flight Track Point (renamed to avoid conflict with GPS TrackPoint)
struct FlightTrackPoint: Identifiable, Codable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let altitude: Double?
    let timestamp: Date
    let heading: Double?
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, altitude, timestamp, heading
    }
    
    init(coordinate: CLLocationCoordinate2D, altitude: Double?, timestamp: Date, heading: Double?) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.timestamp = timestamp
        self.heading = heading
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.heading = try container.decodeIfPresent(Double.self, forKey: .heading)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(heading, forKey: .heading)
    }
}

// MARK: - OpenSky API Response Structure
struct OpenSkyResponse: Codable {
    let time: TimeInterval
    let states: [[OpenSkyValue]]?
}

enum OpenSkyValue: Codable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
            return
        }
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        
        throw DecodingError.typeMismatch(OpenSkyValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode OpenSkyValue"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        if case .int(let value) = self { return Double(value) }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

// MARK: - Flight Tracking Manager
class FlightTrackingManager: ObservableObject {
    static let shared = FlightTrackingManager()
    
    @Published var usaJetFlights: [TrackedFlight] = []
    @Published var isLoading = false
    @Published var lastUpdate: Date?
    @Published var errorMessage: String?
    @Published var showFlightTracks = true
    
    private let openSkyBaseURL = "https://opensky-network.org/api/states/all"
    private var updateTimer: Timer?
    private var flightHistory: [String: [FlightTrackPoint]] = [:] // ICAO24 -> track points
    
    init() {
        startPeriodicUpdates()
    }
    
    func startPeriodicUpdates() {
        // Update every 30 seconds (OpenSky rate limit is quite generous)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.fetchUSAJetFlights()
            }
        }
        
        // Initial fetch
        Task {
            await fetchUSAJetFlights()
        }
    }
    
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @MainActor
    func fetchUSAJetFlights() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let flights = try await fetchFlightsFromOpenSky()
            var updatedFlights: [TrackedFlight] = []
            
            for var flight in flights.filter({ $0.isUSAJet }) {
                // Add current position to track history
                if let coord = flight.coordinate {
                    let trackPoint = FlightTrackPoint(
                        coordinate: coord,
                        altitude: flight.baroAltitude,
                        timestamp: Date(),
                        heading: flight.trueTrack
                    )
                    
                    // Get existing history or create new
                    var history = flightHistory[flight.icao24] ?? []
                    history.append(trackPoint)
                    
                    // Keep only last 50 points (last ~25 minutes of track)
                    if history.count > 50 {
                        history.removeFirst(history.count - 50)
                    }
                    
                    flightHistory[flight.icao24] = history
                    flight.trackHistory = history
                }
                
                updatedFlights.append(flight)
            }
            
            usaJetFlights = updatedFlights
            lastUpdate = Date()
            
            if usaJetFlights.isEmpty {
                errorMessage = "No USA Jet flights currently visible on ADS-B network"
            }
        } catch {
            errorMessage = "Failed to fetch flight data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func clearFlightTracks() {
        flightHistory.removeAll()
        for i in usaJetFlights.indices {
            usaJetFlights[i].trackHistory.removeAll()
        }
    }
    
    private func fetchFlightsFromOpenSky() async throws -> [TrackedFlight] {
        guard let url = URL(string: openSkyBaseURL) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let openSkyResponse = try JSONDecoder().decode(OpenSkyResponse.self, from: data)
        
        guard let states = openSkyResponse.states else {
            return []
        }
        
        var flights: [TrackedFlight] = []
        
        for state in states {
            if state.count >= 17 {
                let flight = TrackedFlight(
                    icao24: state[0].stringValue ?? "",
                    callsign: state[1].stringValue ?? "",
                    originCountry: state[2].stringValue ?? "",
                    timePosition: state[3].doubleValue,
                    lastContact: state[4].doubleValue ?? 0,
                    longitude: state[5].doubleValue,
                    latitude: state[6].doubleValue,
                    baroAltitude: state[7].doubleValue,
                    onGround: state[8].boolValue ?? false,
                    velocity: state[9].doubleValue,
                    trueTrack: state[10].doubleValue,
                    verticalRate: state[11].doubleValue,
                    sensors: nil, // Complex array, skip for now
                    geoAltitude: state[13].doubleValue,
                    squawk: state[14].stringValue,
                    spi: state[15].boolValue ?? false,
                    positionSource: Int(state[16].doubleValue ?? 0)
                )
                flights.append(flight)
            }
        }
        
        return flights
    }
    
    deinit {
        stopPeriodicUpdates()
    }
}

// MARK: - Flight Tracking View
struct FlightTrackingView: View {
    @StateObject private var flightManager = FlightTrackingManager.shared
    @State private var selectedFlight: TrackedFlight?
    @State private var showingFlightDetail = false
    @State private var showingMap = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.2, blue: 0.3).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with update info
                    headerSection
                    
                    // Flight track toggle
                    if !flightManager.usaJetFlights.isEmpty {
                        trackControlSection
                    }
                    
                    if flightManager.isLoading && flightManager.usaJetFlights.isEmpty {
                        loadingView
                    } else if flightManager.usaJetFlights.isEmpty {
                        emptyStateView
                    } else {
                        flightListView
                    }
                }
            }
            .navigationTitle("USA Jet Fleet")
            .navigationBarItems(
                trailing: HStack(spacing: 16) {
                    Button(action: {
                        showingMap = true
                    }) {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                    }
                    .disabled(flightManager.usaJetFlights.isEmpty)
                    
                    Button(action: {
                        Task {
                            await flightManager.fetchUSAJetFlights()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            )
        }
        .sheet(isPresented: $showingFlightDetail) {
            if let flight = selectedFlight {
                FlightDetailView(flight: flight)
            }
        }
        .sheet(isPresented: $showingMap) {
            FlightMapView(flights: flightManager.usaJetFlights, showTracks: flightManager.showFlightTracks)
        }
        .refreshable {
            await flightManager.fetchUSAJetFlights()
        }
    }
    
    private var trackControlSection: some View {
        HStack {
            Toggle("Show Flight Tracks", isOn: $flightManager.showFlightTracks)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Clear Tracks") {
                flightManager.clearFlightTracks()
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
        .background(Color(red: 0.2, green: 0.3, blue: 0.4))
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "airplane.departure")
                    .foregroundColor(.blue)
                
                Text("Live Fleet Tracking")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if flightManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                }
            }
            
            HStack {
                Text("Active Aircraft: \(flightManager.usaJetFlights.count)")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                if let lastUpdate = flightManager.lastUpdate {
                    Text("Updated: \(lastUpdate, formatter: timeFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if let error = flightManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(red: 0.15, green: 0.25, blue: 0.35))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Searching for USA Jet flights...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Scanning global ADS-B network for JUS callsigns")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No USA Jet Flights Detected")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Aircraft may be on ground, outside ADS-B coverage, or transponders off")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                Task {
                    await flightManager.fetchUSAJetFlights()
                }
            }
            .font(.headline)
            .padding()
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var flightListView: some View {
        List(flightManager.usaJetFlights) { flight in
            FlightRowView(flight: flight)
                .listRowBackground(Color(red: 0.1, green: 0.2, blue: 0.3))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    selectedFlight = flight
                    showingFlightDetail = true
                }
        }
        .listStyle(.plain)
        .background(Color(red: 0.1, green: 0.2, blue: 0.3))
    }
}

// MARK: - Flight Row View
struct FlightRowView: View {
    let flight: TrackedFlight
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.displayCallsign)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Text("ICAO: \(flight.icao24.uppercased())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(flight.statusString)
                        .font(.caption.bold())
                        .foregroundColor(flight.statusColor)
                    
                    Text(flight.lastSeenString)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 20) {
                FlightDataItem(title: "Altitude", value: flight.altitudeString, icon: "arrow.up")
                FlightDataItem(title: "Speed", value: flight.speedString, icon: "speedometer")
                FlightDataItem(title: "Heading", value: flight.headingString, icon: "safari")
            }
        }
        .padding()
        .background(Color(red: 0.15, green: 0.25, blue: 0.35))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct FlightDataItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flight Detail View
struct FlightDetailView: View {
    let flight: TrackedFlight
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Aircraft header
                    VStack(spacing: 12) {
                        Image(systemName: "airplane")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(flight.displayCallsign)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text(flight.statusString)
                            .font(.headline)
                            .foregroundColor(flight.statusColor)
                    }
                    .padding()
                    .background(Color(red: 0.15, green: 0.25, blue: 0.35))
                    .cornerRadius(16)
                    
                    // Flight details
                    VStack(spacing: 16) {
                        FlightDetailRow(title: "ICAO 24-bit", value: flight.icao24.uppercased())
                        FlightDetailRow(title: "Country", value: flight.originCountry)
                        FlightDetailRow(title: "Altitude", value: flight.altitudeString)
                        FlightDetailRow(title: "Ground Speed", value: flight.speedString)
                        FlightDetailRow(title: "True Track", value: flight.headingString)
                        
                        if let lat = flight.latitude, let lon = flight.longitude {
                            FlightDetailRow(title: "Position", value: "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                        }
                        
                        FlightDetailRow(title: "Last Contact", value: flight.lastSeenString)
                        
                        if let squawk = flight.squawk {
                            FlightDetailRow(title: "Squawk", value: squawk)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.15, green: 0.25, blue: 0.35))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color(red: 0.1, green: 0.2, blue: 0.3).ignoresSafeArea())
            .navigationTitle("Flight Details")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct FlightDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Flight Map View (Fixed for newer MapKit)
struct FlightMapView: View {
    let flights: [TrackedFlight]
    let showTracks: Bool
    @Environment(\.dismiss) private var dismiss
    
    // Break down complex expressions for compiler
    private var validFlights: [TrackedFlight] {
        flights.filter { $0.coordinate != nil }
    }
    
    private var flightAnnotations: [FlightAnnotation] {
        validFlights.map { flight in
            FlightAnnotation(flight: flight, coordinate: flight.coordinate!)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Map {
                    // Flight tracks (if enabled)
                    if showTracks {
                        ForEach(flights.indices, id: \.self) { index in
                            let flight = flights[index]
                            if flight.trackHistory.count > 1 {
                                MapPolyline(coordinates: flight.trackHistory.map { $0.coordinate })
                                    .stroke(.blue.opacity(0.6), lineWidth: 3)
                            }
                        }
                    }
                    
                    // Aircraft current positions
                    ForEach(flightAnnotations) { annotation in
                        Annotation(
                            annotation.flight.displayCallsign,
                            coordinate: annotation.coordinate
                        ) {
                            FlightAnnotationView(flight: annotation.flight)
                        }
                    }
                }
            }
            .navigationTitle("Fleet Map")
            .navigationBarItems(
                leading: Button("Done") { dismiss() },
                trailing: Text(showTracks ? "Tracks: ON" : "Tracks: OFF")
                    .font(.caption)
                    .foregroundColor(showTracks ? .green : .gray)
            )
        }
    }
}

// MARK: - Flight Annotation View (Separated for clarity)
struct FlightAnnotationView: View {
    let flight: TrackedFlight
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .rotationEffect(.degrees(flight.trueTrack ?? 0))
            }
            
            Text(flight.displayCallsign)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.black.opacity(0.7)))
        }
    }
}

struct FlightAnnotation: Identifiable {
    let id = UUID()
    let flight: TrackedFlight
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Helper
private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

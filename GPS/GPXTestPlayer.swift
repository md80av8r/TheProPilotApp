// GPXTestPlayer.swift - GPX File Playback for Testing Flight Times
// Simulates location updates from a GPX file to test auto-time capture

import Foundation
import CoreLocation
import SwiftUI

// MARK: - GPX Track Point Model
struct GPXTrackPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: CLLocationDistance
    let timestamp: Date
    let speed: CLLocationSpeed // in m/s
    
    var speedKnots: Double {
        speed * 1.94384
    }
}

// MARK: - GPX Test Player
class GPXTestPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentSpeed: Double = 0
    @Published var currentAltitude: Double = 0
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var currentTrackPoint: Int = 0
    @Published var totalTrackPoints: Int = 0
    @Published var playbackSpeed: Double = 1.0 // 1.0 = real-time, 2.0 = 2x speed
    @Published var statusMessage = "Ready"
    
    private var trackPoints: [GPXTrackPoint] = []
    private var playbackTimer: Timer?
    private var currentIndex = 0
    
    // For triggering location updates
    weak var locationManager: PilotLocationManager?
    weak var speedMonitor: GPSSpeedMonitor?
    
    // MARK: - Load GPX File
    func loadGPX(from filename: String) -> Bool {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "gpx") else {
            print("❌ GPX file not found: \(filename).gpx")
            statusMessage = "File not found: \(filename).gpx"
            return false
        }
        
        return loadGPX(from: url)
    }
    
    func loadGPX(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let parser = GPXParser()
            
            guard let points = parser.parse(data: data) else {
                print("❌ Failed to parse GPX file")
                statusMessage = "Failed to parse GPX"
                return false
            }
            
            trackPoints = points
            totalTrackPoints = points.count
            currentIndex = 0
            currentTrackPoint = 0
            
            print("✅ Loaded \(points.count) track points from GPX")
            statusMessage = "Loaded \(points.count) points"
            
            // Log key points
            if let first = points.first, let last = points.last {
                print("📍 Start: \(first.coordinate.latitude), \(first.coordinate.longitude)")
                print("📍 End: \(last.coordinate.latitude), \(last.coordinate.longitude)")
                print("⏱️ Duration: \(last.timestamp.timeIntervalSince(first.timestamp) / 60) minutes")
            }
            
            return true
        } catch {
            print("❌ Error loading GPX: \(error)")
            statusMessage = "Error: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Playback Controls
    func play() {
        guard !trackPoints.isEmpty else {
            print("⚠️ No track points loaded")
            statusMessage = "No track points loaded"
            return
        }
        
        guard !isPlaying else { return }
        
        isPlaying = true
        statusMessage = "Playing..."
        
        print("▶️ Starting GPX playback at \(playbackSpeed)x speed")
        
        // Start from beginning if we've reached the end
        if currentIndex >= trackPoints.count {
            currentIndex = 0
        }
        
        scheduleNextPoint()
    }
    
    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        statusMessage = "Paused"
        print("⏸️ GPX playback paused")
    }
    
    func stop() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentIndex = 0
        currentTrackPoint = 0
        currentSpeed = 0
        currentAltitude = 0
        currentCoordinate = nil
        statusMessage = "Stopped"
        print("⏹️ GPX playback stopped")
    }
    
    func restart() {
        stop()
        play()
    }
    
    func skipToPoint(_ index: Int) {
        guard index >= 0 && index < trackPoints.count else { return }
        currentIndex = index
        currentTrackPoint = index
        processCurrentPoint()
    }
    
    // MARK: - Playback Engine
    private func scheduleNextPoint() {
        guard isPlaying, currentIndex < trackPoints.count else {
            print("✅ GPX playback completed")
            isPlaying = false
            statusMessage = "Completed"
            return
        }
        
        let currentPoint = trackPoints[currentIndex]
        
        // Calculate delay to next point
        var delay: TimeInterval = 0
        if currentIndex + 1 < trackPoints.count {
            let nextPoint = trackPoints[currentIndex + 1]
            let realTimeInterval = nextPoint.timestamp.timeIntervalSince(currentPoint.timestamp)
            delay = realTimeInterval / playbackSpeed
        }
        
        // Process current point
        processCurrentPoint()
        
        // Move to next point
        currentIndex += 1
        
        // Schedule next update
        if currentIndex < trackPoints.count {
            playbackTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, delay), repeats: false) { [weak self] _ in
                self?.scheduleNextPoint()
            }
        } else {
            isPlaying = false
            statusMessage = "Completed"
        }
    }
    
    private func processCurrentPoint() {
        guard currentIndex < trackPoints.count else { return }
        
        let point = trackPoints[currentIndex]
        
        // Update published properties
        DispatchQueue.main.async {
            self.currentCoordinate = point.coordinate
            self.currentSpeed = point.speedKnots
            self.currentAltitude = point.elevation
            self.currentTrackPoint = self.currentIndex
        }
        
        // Create CLLocation
        let location = CLLocation(
            coordinate: point.coordinate,
            altitude: point.elevation,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: point.speed,
            timestamp: Date() // Use current time, not GPX timestamp
        )
        
        // Simulate location update to PilotLocationManager
        simulateLocationUpdate(location)
        
        // Log significant events
        if point.speedKnots >= 80 && (currentIndex == 0 || trackPoints[currentIndex - 1].speedKnots < 80) {
            print("🛫 TAKEOFF: Speed crossed 80 kts (\(Int(point.speedKnots)) kts)")
        }
        
        if point.speedKnots < 60 && currentIndex > 0 && trackPoints[currentIndex - 1].speedKnots >= 60 {
            // Check if we were recently fast
            if trackPoints[max(0, currentIndex - 10)...currentIndex].contains(where: { $0.speedKnots > 80 }) {
                print("🛬 LANDING: Speed dropped below 60 kts (\(Int(point.speedKnots)) kts)")
            }
        }
    }
    
    private func simulateLocationUpdate(_ location: CLLocation) {
        // Post notification that other systems can listen to
        NotificationCenter.default.post(
            name: Notification.Name("GPXTestLocationUpdate"),
            object: nil,
            userInfo: ["location": location]
        )
        
        // Directly trigger location manager if available
        // Note: You may need to add a method to PilotLocationManager to accept simulated locations
        
        print("📍 [\(currentIndex + 1)/\(trackPoints.count)] Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lon: \(String(format: "%.4f", location.coordinate.longitude)), Speed: \(Int(currentSpeed)) kts, Alt: \(Int(currentAltitude)) ft")
    }
    
    // MARK: - Helper Methods
    func getProgress() -> Double {
        guard totalTrackPoints > 0 else { return 0 }
        return Double(currentTrackPoint) / Double(totalTrackPoints)
    }
    
    func getTimeRemaining() -> String {
        guard currentIndex < trackPoints.count, let last = trackPoints.last else {
            return "0:00"
        }
        
        let current = trackPoints[currentIndex]
        let remaining = last.timestamp.timeIntervalSince(current.timestamp) / playbackSpeed
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - GPX Parser
class GPXParser: NSObject, XMLParserDelegate {
    private var trackPoints: [GPXTrackPoint] = []
    private var currentElement = ""
    
    // Temporary storage for current track point
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentSpeed: Double?
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    func parse(data: Data) -> [GPXTrackPoint]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            print("❌ XML parsing failed")
            return nil
        }
        
        return trackPoints
    }
    
    // MARK: - XML Parser Delegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "trkpt" {
            // New track point
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "ele":
            currentEle = Double(trimmed)
            
        case "time":
            currentTime = dateFormatter.date(from: trimmed)
            
        case "speed":
            currentSpeed = Double(trimmed)
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trkpt" {
            // Save track point
            if let lat = currentLat,
               let lon = currentLon,
               let ele = currentEle,
               let time = currentTime {
                
                let trackPoint = GPXTrackPoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    elevation: ele,
                    timestamp: time,
                    speed: currentSpeed ?? 0 // Speed in m/s
                )
                
                trackPoints.append(trackPoint)
            }
            
            // Reset temporary storage
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentTime = nil
            currentSpeed = nil
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        print("✅ GPX parsing complete: \(trackPoints.count) points")
    }
}

// MARK: - SwiftUI Test View
struct GPXTestPlayerView: View {
    @StateObject private var player = GPXTestPlayer()
    @State private var selectedFile = "YIP_DTW"
    
    var body: some View {
        NavigationView {
            Form {
                Section("GPX File") {
                    TextField("Filename (without .gpx)", text: $selectedFile)
                    
                    Button("Load GPX File") {
                        _ = player.loadGPX(from: selectedFile)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if player.totalTrackPoints > 0 {
                        Label("\(player.totalTrackPoints) track points loaded", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Playback") {
                    HStack {
                        Button(action: player.play) {
                            Label("Play", systemImage: "play.fill")
                        }
                        .disabled(player.isPlaying || player.totalTrackPoints == 0)
                        
                        Button(action: player.pause) {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .disabled(!player.isPlaying)
                        
                        Button(action: player.stop) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .disabled(!player.isPlaying && player.currentTrackPoint == 0)
                        
                        Button(action: player.restart) {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        .disabled(player.totalTrackPoints == 0)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Playback Speed", selection: $player.playbackSpeed) {
                                Text("0.5x").tag(0.5)
                                Text("1x").tag(1.0)
                                Text("2x").tag(2.0)
                                Text("5x").tag(5.0)
                                Text("10x").tag(10.0)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        ProgressView(value: player.getProgress()) {
                            HStack {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(player.currentTrackPoint) / \(player.totalTrackPoints)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if player.isPlaying {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                Text("Time Remaining: \(player.getTimeRemaining())")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Current State") {
                    LabeledContent("Status", value: player.statusMessage)
                    
                    if let coord = player.currentCoordinate {
                        LabeledContent("Latitude", value: String(format: "%.6f", coord.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", coord.longitude))
                    }
                    
                    LabeledContent("Speed", value: "\(Int(player.currentSpeed)) kts")
                        .foregroundColor(speedColor(player.currentSpeed))
                    
                    LabeledContent("Altitude", value: "\(Int(player.currentAltitude)) ft")
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Test:")
                            .font(.headline)
                        
                        Text("1. Make sure you have a flight created in the app")
                        Text("2. Load the GPX file above")
                        Text("3. Adjust playback speed (10x recommended for testing)")
                        Text("4. Press Play")
                        Text("5. Watch for auto-triggered OUT/OFF/ON/IN times")
                        Text("6. Check the console logs for speed triggers")
                        
                        Divider()
                        
                        Text("Key Speed Thresholds:")
                            .font(.headline)
                        
                        Label("OFF (Takeoff): ≥ 80 knots", systemImage: "airplane.departure")
                            .foregroundColor(.orange)
                        
                        Label("ON (Landing): < 60 knots after being fast", systemImage: "airplane.arrival")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("GPX Test Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func speedColor(_ speed: Double) -> Color {
        if speed >= 80 {
            return .orange // Takeoff speed
        } else if speed > 60 {
            return .blue // Cruise/approach
        } else if speed > 20 {
            return .yellow // Taxi/slow
        } else {
            return .green // Stopped/parked
        }
    }
}

// MARK: - Preview
struct GPXTestPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        GPXTestPlayerView()
    }
}

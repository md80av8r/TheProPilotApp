// FlightTrackRecorder.swift - GPS Track Recording Service
// Records GPS track points during flight for post-flight review and storage

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Track Point Model
struct RecordedTrackPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double // meters
    let speed: Double // m/s
    let course: Double // degrees
    let horizontalAccuracy: Double
    let verticalAccuracy: Double

    init(from location: CLLocation) {
        self.id = UUID()
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.speed = max(0, location.speed)
        self.course = location.course >= 0 ? location.course : 0
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var speedKnots: Double {
        speed * 1.94384
    }

    var altitudeFeet: Double {
        altitude * 3.28084
    }

    func toCLLocation() -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}

// MARK: - Flight Track Model
struct RecordedFlightTrack: Codable, Identifiable {
    let id: UUID
    let legId: UUID
    var departure: String
    var arrival: String
    let flightNumber: String
    let startTime: Date
    var endTime: Date?
    var trackPoints: [RecordedTrackPoint]
    var isComplete: Bool

    init(legId: UUID, departure: String, arrival: String, flightNumber: String) {
        self.id = UUID()
        self.legId = legId
        self.departure = departure
        self.arrival = arrival
        self.flightNumber = flightNumber
        self.startTime = Date()
        self.endTime = nil
        self.trackPoints = []
        self.isComplete = false
    }

    // Full initializer for copying with modifications
    init(id: UUID, legId: UUID, departure: String, arrival: String, flightNumber: String,
         startTime: Date, endTime: Date?, trackPoints: [RecordedTrackPoint], isComplete: Bool) {
        self.id = id
        self.legId = legId
        self.departure = departure
        self.arrival = arrival
        self.flightNumber = flightNumber
        self.startTime = startTime
        self.endTime = endTime
        self.trackPoints = trackPoints
        self.isComplete = isComplete
    }

    // MARK: - Computed Properties
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    var totalDistance: Double {
        guard trackPoints.count > 1 else { return 0 }

        var distance: Double = 0
        for i in 1..<trackPoints.count {
            let prev = trackPoints[i-1].toCLLocation()
            let curr = trackPoints[i].toCLLocation()
            distance += curr.distance(from: prev)
        }
        return distance // meters
    }

    var totalDistanceNM: Double {
        totalDistance / 1852.0
    }

    // MARK: - Detected Takeoff/Landing Times
    /// Detects takeoff time as the first point where speed exceeds 80 knots
    var detectedTakeoffTime: Date? {
        let takeoffThresholdKnots = 80.0
        return trackPoints.first { $0.speedKnots >= takeoffThresholdKnots }?.timestamp
    }

    /// Detects landing time as the last point where speed drops below 60 knots after being above 80
    var detectedLandingTime: Date? {
        let airborneThresholdKnots = 80.0
        let landingThresholdKnots = 60.0

        // Find when we were last airborne (above 80 kts)
        guard let lastAirborneIndex = trackPoints.lastIndex(where: { $0.speedKnots >= airborneThresholdKnots }) else {
            return nil
        }

        // Find the first point after that where we dropped below 60 kts
        for i in lastAirborneIndex..<trackPoints.count {
            if trackPoints[i].speedKnots < landingThresholdKnots {
                return trackPoints[i].timestamp
            }
        }

        return nil
    }

    /// Formatted takeoff time string (HHmm)
    var detectedTakeoffTimeString: String? {
        guard let time = detectedTakeoffTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        return formatter.string(from: time)
    }

    /// Formatted landing time string (HHmm)
    var detectedLandingTimeString: String? {
        guard let time = detectedLandingTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        return formatter.string(from: time)
    }

    var maxAltitude: Double {
        trackPoints.map { $0.altitudeFeet }.max() ?? 0
    }

    var maxSpeed: Double {
        trackPoints.map { $0.speedKnots }.max() ?? 0
    }

    var averageSpeed: Double {
        guard !trackPoints.isEmpty else { return 0 }
        let totalSpeed = trackPoints.map { $0.speedKnots }.reduce(0, +)
        return totalSpeed / Double(trackPoints.count)
    }

    // MARK: - GPX Export
    func toGPX() -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="ProPilot App" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(departure) to \(arrival)</name>
            <desc>Flight \(flightNumber) recorded by ProPilot</desc>
            <time>\(ISO8601DateFormatter().string(from: startTime))</time>
          </metadata>
          <trk>
            <name>\(flightNumber): \(departure)-\(arrival)</name>
            <trkseg>

        """

        let dateFormatter = ISO8601DateFormatter()

        for point in trackPoints {
            gpx += """
                  <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                    <ele>\(point.altitude)</ele>
                    <time>\(dateFormatter.string(from: point.timestamp))</time>
                    <extensions><speed>\(point.speed)</speed></extensions>
                  </trkpt>

            """
        }

        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    // MARK: - KML Export
    func toKML() -> String {
        var kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
          <Document>
            <name>\(flightNumber): \(departure) to \(arrival)</name>
            <description>Flight recorded by ProPilot App</description>

            <!-- Flight Path Style -->
            <Style id="flightPath">
              <LineStyle>
                <color>ff0066ff</color>
                <width>3</width>
              </LineStyle>
              <PolyStyle>
                <color>330066ff</color>
              </PolyStyle>
            </Style>

            <!-- Departure Marker Style -->
            <Style id="departure">
              <IconStyle>
                <color>ff00ff00</color>
                <scale>1.2</scale>
                <Icon><href>http://maps.google.com/mapfiles/kml/shapes/airports.png</href></Icon>
              </IconStyle>
            </Style>

            <!-- Arrival Marker Style -->
            <Style id="arrival">
              <IconStyle>
                <color>ff0000ff</color>
                <scale>1.2</scale>
                <Icon><href>http://maps.google.com/mapfiles/kml/shapes/airports.png</href></Icon>
              </IconStyle>
            </Style>

            <!-- Departure Point -->
        """

        if let firstPoint = trackPoints.first {
            kml += """

                <Placemark>
                  <name>\(departure)</name>
                  <description>Departure Airport</description>
                  <styleUrl>#departure</styleUrl>
                  <Point>
                    <coordinates>\(firstPoint.longitude),\(firstPoint.latitude),\(firstPoint.altitude)</coordinates>
                  </Point>
                </Placemark>

            """
        }

        // Arrival Point
        if let lastPoint = trackPoints.last {
            kml += """

                <Placemark>
                  <name>\(arrival)</name>
                  <description>Arrival Airport</description>
                  <styleUrl>#arrival</styleUrl>
                  <Point>
                    <coordinates>\(lastPoint.longitude),\(lastPoint.latitude),\(lastPoint.altitude)</coordinates>
                  </Point>
                </Placemark>

            """
        }

        // Flight Path with altitude
        kml += """

            <Placemark>
              <name>Flight Path</name>
              <description>
                Flight: \(flightNumber)
                Distance: \(String(format: "%.1f", totalDistanceNM)) NM
                Duration: \(durationFormatted)
                Max Altitude: \(Int(maxAltitude)) ft
                Max Speed: \(Int(maxSpeed)) kts
              </description>
              <styleUrl>#flightPath</styleUrl>
              <LineString>
                <extrude>1</extrude>
                <tessellate>1</tessellate>
                <altitudeMode>absolute</altitudeMode>
                <coordinates>
        """

        for point in trackPoints {
            kml += "\(point.longitude),\(point.latitude),\(point.altitude)\n"
        }

        kml += """
                </coordinates>
              </LineString>
            </Placemark>

            <!-- Animated Tour (for Google Earth) -->
            <gx:Tour>
              <name>Fly Along Flight Path</name>
              <gx:Playlist>
        """

        // Add animated flyalong points (sample every 10th point)
        let step = max(1, trackPoints.count / 20)
        for i in stride(from: 0, to: trackPoints.count, by: step) {
            let point = trackPoints[i]
            let heading = i + step < trackPoints.count ? calculateHeading(from: point, to: trackPoints[min(i + step, trackPoints.count - 1)]) : 0

            kml += """
                    <gx:FlyTo>
                      <gx:duration>2.0</gx:duration>
                      <gx:flyToMode>smooth</gx:flyToMode>
                      <LookAt>
                        <longitude>\(point.longitude)</longitude>
                        <latitude>\(point.latitude)</latitude>
                        <altitude>\(point.altitude + 500)</altitude>
                        <heading>\(heading)</heading>
                        <tilt>70</tilt>
                        <range>2000</range>
                        <altitudeMode>absolute</altitudeMode>
                      </LookAt>
                    </gx:FlyTo>

            """
        }

        kml += """
              </gx:Playlist>
            </gx:Tour>

          </Document>
        </kml>
        """

        return kml
    }

    private func calculateHeading(from point1: RecordedTrackPoint, to point2: RecordedTrackPoint) -> Double {
        let lat1 = point1.latitude * .pi / 180
        let lat2 = point2.latitude * .pi / 180
        let dLon = (point2.longitude - point1.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var heading = atan2(y, x) * 180 / .pi
        if heading < 0 { heading += 360 }
        return heading
    }
}

// MARK: - Flight Track Recorder Service
class FlightTrackRecorder: NSObject, ObservableObject {
    static let shared = FlightTrackRecorder()

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var currentTrack: RecordedFlightTrack?
    @Published var recordedPointsCount = 0
    @Published var statusMessage = "Ready"
    @Published var lastError: String?

    // MARK: - Configuration
    var minimumDistanceFilter: Double = 50 // meters between points
    var minimumTimeInterval: TimeInterval = 5 // seconds between points
    var recordOnlyWhenMoving = true
    var minimumSpeedForRecording: Double = 5.1 // m/s (~10 knots)

    // MARK: - Auto Recording Integration
    private var autoTimeSettings = AutoTimeSettings.shared
    private var takeoffObserver: NSObjectProtocol?
    private var landingObserver: NSObjectProtocol?
    private var pendingDeparture: String?
    private var pendingArrival: String?
    private var pendingFlightNumber: String?

    // MARK: - Airport Detection
    private let airportDB = AirportDatabaseManager.shared

    // MARK: - Private Properties
    private var lastRecordedLocation: CLLocation?
    private var lastRecordedTime: Date?
    private var locationObserver: NSObjectProtocol?

    // MARK: - Storage
    private let tracksDirectoryName = "FlightTracks"

    private var tracksDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tracksPath = documentsPath.appendingPathComponent(tracksDirectoryName)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: tracksPath.path) {
            try? FileManager.default.createDirectory(at: tracksPath, withIntermediateDirectories: true)
        }

        return tracksPath
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        setupLocationObserver()
        setupAutoRecordingObservers()
    }

    private func setupLocationObserver() {
        // Listen for GPX test location updates
        locationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("GPXTestLocationUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let location = notification.userInfo?["location"] as? CLLocation {
                self?.processLocationUpdate(location)
            }
        }
    }

    private func setupAutoRecordingObservers() {
        // Listen for takeoff to auto-start recording
        takeoffObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("takeoffRollStarted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTakeoffDetected(notification)
        }

        // Listen for landing to auto-stop recording
        landingObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("landingRollDecel"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLandingDetected(notification)
        }

        print("📍 FlightTrackRecorder: Auto-recording observers configured")
    }

    // MARK: - Auto Recording Handlers
    private func handleTakeoffDetected(_ notification: Notification) {
        guard autoTimeSettings.trackRecordingEnabled else {
            print("📍 Track recording disabled - skipping auto-start")
            return
        }

        guard !isRecording else {
            print("📍 Already recording - ignoring takeoff trigger")
            return
        }

        // Get departure airport from notification
        let departure = notification.userInfo?["airport"] as? String ?? "UNKN"

        // Start recording with available info
        startRecording(
            for: UUID(),
            departure: departure,
            arrival: pendingArrival ?? "UNKN",
            flightNumber: pendingFlightNumber ?? ""
        )

        print("📍 Auto-started track recording on takeoff from \(departure)")
    }

    private func handleLandingDetected(_ notification: Notification) {
        guard isRecording else {
            print("📍 Not recording - ignoring landing trigger")
            return
        }

        // Get arrival airport from notification
        let arrival = notification.userInfo?["airport"] as? String ?? "UNKN"

        // Update the arrival in current track before stopping
        if let track = currentTrack {
            // Create a new track with updated arrival if it was unknown
            if track.arrival == "UNKN" {
                // We can't mutate the struct directly in currentTrack, so just log it
                print("📍 Landing at \(arrival) - track will show arrival")
            }
        }

        // Stop recording
        if let completedTrack = stopRecording() {
            print("📍 Auto-stopped track recording on landing at \(arrival): \(completedTrack.trackPoints.count) points")
        }

        // Clear pending info
        pendingDeparture = nil
        pendingArrival = nil
        pendingFlightNumber = nil
    }

    /// Set pending flight info for auto-recording (call when active leg is known)
    func setPendingFlightInfo(departure: String, arrival: String, flightNumber: String) {
        pendingDeparture = departure
        pendingArrival = arrival
        pendingFlightNumber = flightNumber
        print("📍 Set pending flight info: \(flightNumber) \(departure)-\(arrival)")
    }

    deinit {
        if let observer = locationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = takeoffObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = landingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Recording Controls
    func startRecording(for legId: UUID, departure: String, arrival: String, flightNumber: String) {
        guard !isRecording else {
            print("Track recording already in progress")
            return
        }

        let track = RecordedFlightTrack(
            legId: legId,
            departure: departure,
            arrival: arrival,
            flightNumber: flightNumber
        )

        currentTrack = track
        isRecording = true
        recordedPointsCount = 0
        lastRecordedLocation = nil
        lastRecordedTime = nil
        statusMessage = "Recording..."

        print("Started track recording for \(flightNumber): \(departure)-\(arrival)")

        // Post notification
        NotificationCenter.default.post(
            name: .flightTrackRecordingStarted,
            object: nil,
            userInfo: ["legId": legId]
        )
    }

    func stopRecording() -> RecordedFlightTrack? {
        guard isRecording, var track = currentTrack else {
            return nil
        }

        track.endTime = Date()
        track.isComplete = true

        // Detect airports from track points if they're unknown
        track = detectAirportsFromTrackPoints(track)

        isRecording = false
        statusMessage = "Recording stopped"

        // Save track locally
        saveTrack(track)
        
        // 📤 Sync to iCloud (if enabled)
        Task {
            await syncTrackToiCloud(track)
        }

        let completedTrack = track
        currentTrack = nil

        print("✅ Stopped track recording: \(track.trackPoints.count) points, \(String(format: "%.1f", track.totalDistanceNM)) NM")
        print("📍 Departure: \(track.departure), Arrival: \(track.arrival)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .flightTrackRecordingStopped,
            object: nil,
            userInfo: [
                "legId": track.legId,
                "trackId": track.id,
                "pointCount": track.trackPoints.count
            ]
        )

        return completedTrack
    }

    // MARK: - Airport Detection from Track Points
    private func detectAirportsFromTrackPoints(_ track: RecordedFlightTrack) -> RecordedFlightTrack {
        var updatedTrack = track

        // Detect departure airport from first track point
        if track.departure == "UNKN" || track.departure.isEmpty {
            if let firstPoint = track.trackPoints.first {
                let location = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
                let nearby = airportDB.getNearbyAirports(to: location, within: 10, limit: 1)
                if let closest = nearby.first {
                    updatedTrack.departure = closest.icao
                    print("📍 Detected departure airport: \(closest.icao) (\(closest.name))")
                }
            }
        }

        // Detect arrival airport from last track point
        if updatedTrack.arrival == "UNKN" || updatedTrack.arrival.isEmpty {
            if let lastPoint = track.trackPoints.last {
                let location = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
                let nearby = airportDB.getNearbyAirports(to: location, within: 10, limit: 1)
                if let closest = nearby.first {
                    updatedTrack.arrival = closest.icao
                    print("📍 Detected arrival airport: \(closest.icao) (\(closest.name))")
                }
            }
        }

        return updatedTrack
    }

    func cancelRecording() {
        isRecording = false
        currentTrack = nil
        recordedPointsCount = 0
        lastRecordedLocation = nil
        lastRecordedTime = nil
        statusMessage = "Recording cancelled"

        print("Track recording cancelled")
    }

    // MARK: - Location Processing
    func processLocationUpdate(_ location: CLLocation) {
        guard isRecording else { return }

        // Check if we should record this point
        guard shouldRecordPoint(location) else { return }

        // Create track point
        let trackPoint = RecordedTrackPoint(from: location)

        // Add to current track
        currentTrack?.trackPoints.append(trackPoint)
        recordedPointsCount = currentTrack?.trackPoints.count ?? 0

        // Update last recorded
        lastRecordedLocation = location
        lastRecordedTime = Date()

        // Update status
        let speedKt = location.speed * 1.94384
        statusMessage = "Recording: \(recordedPointsCount) pts, \(Int(speedKt)) kts"
    }

    private func shouldRecordPoint(_ location: CLLocation) -> Bool {
        let now = Date()

        // Always record first point
        guard let lastLocation = lastRecordedLocation,
              let lastTime = lastRecordedTime else {
            return true
        }

        // Check time interval
        if now.timeIntervalSince(lastTime) < minimumTimeInterval {
            return false
        }

        // Check distance
        let distance = location.distance(from: lastLocation)
        if distance < minimumDistanceFilter {
            return false
        }

        // Check speed if required
        if recordOnlyWhenMoving && location.speed < minimumSpeedForRecording {
            return false
        }

        // Check accuracy (skip bad readings)
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 {
            return false
        }

        return true
    }

    // MARK: - Storage Operations
    private func saveTrack(_ track: RecordedFlightTrack) {
        let filename = "\(track.legId.uuidString).json"
        let fileURL = tracksDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(track)
            try data.write(to: fileURL)

            print("Saved track to: \(fileURL.lastPathComponent)")
        } catch {
            print("Failed to save track: \(error)")
            lastError = error.localizedDescription
        }
    }

    func loadTrack(for legId: UUID) -> RecordedFlightTrack? {
        let filename = "\(legId.uuidString).json"
        let fileURL = tracksDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let track = try decoder.decode(RecordedFlightTrack.self, from: data)
            return track
        } catch {
            print("Failed to load track: \(error)")
            lastError = error.localizedDescription
            return nil
        }
    }

    func getAllTracks() -> [RecordedFlightTrack] {
        var tracks: [RecordedFlightTrack] = []

        guard let files = try? FileManager.default.contentsOfDirectory(at: tracksDirectory, includingPropertiesForKeys: nil) else {
            return tracks
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let track = try? decoder.decode(RecordedFlightTrack.self, from: data) {
                tracks.append(track)
            }
        }

        // Sort by start time, newest first
        return tracks.sorted { $0.startTime > $1.startTime }
    }

    func deleteTrack(for legId: UUID) {
        let filename = "\(legId.uuidString).json"
        let fileURL = tracksDirectory.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: fileURL)
        print("Deleted track for leg: \(legId)")
    }

    func exportTrackToGPX(_ track: RecordedFlightTrack) -> URL? {
        let gpxContent = track.toGPX()
        let flightName = track.flightNumber.isEmpty ? "Flight" : track.flightNumber
        let filename = "\(flightName)_\(track.departure)-\(track.arrival).gpx"
        let fileURL = tracksDirectory.appendingPathComponent(filename)

        do {
            try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Exported GPX to: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            print("Failed to export GPX: \(error)")
            lastError = error.localizedDescription
            return nil
        }
    }

    func exportTrackToKML(_ track: RecordedFlightTrack) -> URL? {
        let kmlContent = track.toKML()
        let flightName = track.flightNumber.isEmpty ? "Flight" : track.flightNumber
        let filename = "\(flightName)_\(track.departure)-\(track.arrival).kml"
        let fileURL = tracksDirectory.appendingPathComponent(filename)

        do {
            try kmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Exported KML to: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            print("Failed to export KML: \(error)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Track Data for CloudKit
    func getTrackData(for legId: UUID) -> Data? {
        guard let track = loadTrack(for: legId) else { return nil }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(track)
    }

    func saveTrackData(_ data: Data, for legId: UUID) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let track = try? decoder.decode(RecordedFlightTrack.self, from: data) else {
            return false
        }

        saveTrack(track)
        return true
    }
    
    // MARK: - ═══════════════════════════════════════════════════════════════
    // MARK: iCloud Sync Integration
    // MARK: ═══════════════════════════════════════════════════════════════
    
    /// Upload track to iCloud after recording completes
    private func syncTrackToiCloud(_ track: RecordedFlightTrack) async {
        // Check if user has track recording enabled
        guard UserDefaults.standard.bool(forKey: "trackRecordingEnabled") else {
            print("ℹ️ Track recording disabled by user, skipping iCloud sync")
            return
        }
        
        // Check if iCloud sync is enabled
        guard UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") else {
            print("ℹ️ iCloud sync disabled, skipping track upload")
            return
        }
        
        guard let trackData = getTrackData(for: track.legId) else {
            print("❌ Failed to encode track data for sync")
            return
        }
        
        do {
            try await CloudKitManager.shared.saveFlightTrack(legId: track.legId, trackData: trackData)
            print("✅ Flight track synced to iCloud: \(track.legId.uuidString)")
        } catch {
            print("❌ Failed to sync track to iCloud: \(error)")
        }
    }
    
    /// Download track from iCloud (for device restore or sync)
    func syncTrackFromiCloud(legId: UUID) async -> Bool {
        do {
            guard let trackData = try await CloudKitManager.shared.fetchFlightTrack(legId: legId) else {
                print("ℹ️ No track found in iCloud for leg: \(legId.uuidString)")
                return false
            }
            
            let success = saveTrackData(trackData, for: legId)
            if success {
                print("✅ Flight track synced from iCloud: \(legId.uuidString)")
            } else {
                print("❌ Failed to decode track from iCloud")
            }
            return success
            
        } catch {
            print("❌ Failed to sync track from iCloud: \(error)")
            return false
        }
    }
    
    /// Delete track from iCloud when user deletes it locally
    func deleteTrackFromiCloud(legId: UUID) async {
        do {
            try await CloudKitManager.shared.deleteFlightTrack(legId: legId)
            print("✅ Flight track deleted from iCloud: \(legId.uuidString)")
        } catch {
            print("❌ Failed to delete track from iCloud: \(error)")
        }
    }
    
    /// Sync all tracks for a trip (used when restoring data)
    func syncAllTracksForTrip(legIds: [UUID]) async {
        print("📥 Syncing \(legIds.count) tracks from iCloud...")
        
        do {
            let tracks = try await CloudKitManager.shared.fetchFlightTracksForTrip(legIds: legIds)
            
            var successCount = 0
            for (legId, trackData) in tracks {
                if saveTrackData(trackData, for: legId) {
                    successCount += 1
                }
            }
            
            // Capture count before MainActor to avoid Swift 6 concurrency issues
            let finalSuccessCount = successCount
            let totalCount = legIds.count
            
            await MainActor.run {
                statusMessage = "Synced \(finalSuccessCount)/\(totalCount) tracks"
            }
            
            print("✅ Synced \(finalSuccessCount)/\(totalCount) tracks from iCloud")
            
        } catch {
            print("❌ Failed to sync tracks: \(error)")
        }
    }
    
    /// Check if a track is synced to iCloud
    func isTrackSynced(legId: UUID) async -> Bool {
        return await CloudKitManager.shared.flightTrackExists(legId: legId)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let flightTrackRecordingStarted = Notification.Name("flightTrackRecordingStarted")
    static let flightTrackRecordingStopped = Notification.Name("flightTrackRecordingStopped")
}

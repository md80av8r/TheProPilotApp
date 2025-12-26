//
//  GPSSpoofingAlertLevel.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/24/25.
//


//
//  GPSSpoofingMonitor.swift
//  ProPilot
//
//  Created for USA Jet cargo operations
//  Monitors for GPS spoofing/jamming with focus on US-Mexico border region
//

import Foundation
import CoreLocation
import Combine

// MARK: - Spoofing Alert Types

enum GPSSpoofingAlertLevel: String, Codable {
    case normal = "Normal"
    case caution = "Caution"      // Entering known risk area
    case warning = "Warning"      // Anomaly detected
    case alert = "Alert"          // Active spoofing suspected
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .caution: return "yellow"
        case .warning: return "orange"
        case .alert: return "red"
        }
    }
    
    var systemImage: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alert: return "xmark.octagon.fill"
        }
    }
}

enum GPSAnomalyType: String, Codable {
    case suddenPositionJump = "Sudden Position Jump"
    case unrealisticSpeed = "Unrealistic Speed"
    case poorAccuracy = "Poor GPS Accuracy"
    case timeDiscrepancy = "Time Discrepancy"
    case altitudeAnomaly = "Altitude Anomaly"
    case signalLoss = "GPS Signal Loss"
    case knownSpoofingZone = "Known Spoofing Zone"
    case softwareSimulation = "Software Simulation Detected"
}

// MARK: - Spoofing Event Model

struct GPSSpoofingEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let location: CodableLocation
    let anomalyType: GPSAnomalyType
    let alertLevel: GPSSpoofingAlertLevel
    let details: String
    let flightNumber: String?
    let reportedToFAA: Bool
    
    init(timestamp: Date = Date(),
         location: CLLocation,
         anomalyType: GPSAnomalyType,
         alertLevel: GPSSpoofingAlertLevel,
         details: String,
         flightNumber: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.location = CodableLocation(from: location)
        self.anomalyType = anomalyType
        self.alertLevel = alertLevel
        self.details = details
        self.flightNumber = flightNumber
        self.reportedToFAA = false
    }
}

struct CodableLocation: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let speed: Double
    let course: Double
    
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = location.speed
        self.course = location.course
    }
    
    var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: course,
            speed: speed,
            timestamp: Date()
        )
    }
}

// MARK: - Known Spoofing Zones

struct GPSSpoofingZone: Identifiable {
    let id = UUID()
    let name: String
    let region: String
    let centerLat: Double
    let centerLon: Double
    let radiusNM: Double
    let riskLevel: GPSSpoofingAlertLevel
    let notes: String
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
}

// MARK: - GPS Spoofing Monitor

class GPSSpoofingMonitor: NSObject, ObservableObject {
    
    static let shared = GPSSpoofingMonitor()
    
    // MARK: - Published Properties
    
    @Published var currentAlertLevel: GPSSpoofingAlertLevel = .normal
    @Published var currentZone: GPSSpoofingZone? = nil
    @Published var recentEvents: [GPSSpoofingEvent] = []
    @Published var isMonitoring: Bool = false
    @Published var lastValidPosition: CLLocation? = nil
    @Published var statusMessage: String = "GPS: Normal"
    
    // MARK: - Detection Settings
    
    /// Maximum realistic groundspeed in knots (MD-88 cruise ~500kts, allow some margin)
    var maxRealisticSpeedKts: Double = 600
    
    /// Position jump threshold in nautical miles that would indicate spoofing
    var positionJumpThresholdNM: Double = 5.0
    
    /// Minimum horizontal accuracy in meters before flagging
    var minAccuracyThreshold: Double = 100.0
    
    /// Time discrepancy threshold in seconds
    var timeDiscrepancyThreshold: Double = 5.0
    
    /// Enable alerts for known spoofing zones
    var alertOnKnownZones: Bool = true
    
    // MARK: - Private Properties
    
    private var positionHistory: [CLLocation] = []
    private let maxHistoryCount = 20
    private var lastAlertTime: Date? = nil
    private let minimumAlertInterval: TimeInterval = 30 // Don't spam alerts
    
    // MARK: - Known Spoofing Zones Database
    
    /// Known GPS spoofing/jamming hotspots
    /// Updated based on FAA reports, OPSGROUP data, and pilot reports
    let knownSpoofingZones: [GPSSpoofingZone] = [
        // US-Mexico Border Region (HIGH PRIORITY for USA Jet)
        GPSSpoofingZone(
            name: "Laredo Border Region",
            region: "US-Mexico Border",
            centerLat: 27.5436,
            centerLon: -99.4803,
            radiusNM: 50,
            riskLevel: .caution,
            notes: "Known GPS interference zone. Cartel jamming activity reported. KLRD operations affected."
        ),
        GPSSpoofingZone(
            name: "Nuevo Laredo",
            region: "Mexico",
            centerLat: 27.4763,
            centerLon: -99.5075,
            radiusNM: 30,
            riskLevel: .warning,
            notes: "Frequent GPS anomalies reported by cross-border flights."
        ),
        GPSSpoofingZone(
            name: "El Paso/Juarez Border",
            region: "US-Mexico Border",
            centerLat: 31.7619,
            centerLon: -106.4850,
            radiusNM: 40,
            riskLevel: .caution,
            notes: "GPS interference reported in border region."
        ),
        GPSSpoofingZone(
            name: "McAllen/Reynosa",
            region: "US-Mexico Border",
            centerLat: 26.2034,
            centerLon: -98.2300,
            radiusNM: 35,
            riskLevel: .caution,
            notes: "Rio Grande Valley - intermittent GPS issues."
        ),
        GPSSpoofingZone(
            name: "Brownsville/Matamoros",
            region: "US-Mexico Border",
            centerLat: 25.9067,
            centerLon: -97.4975,
            radiusNM: 30,
            riskLevel: .caution,
            notes: "Southern Texas border - GPS anomalies reported."
        ),
        
        // Mexico Interior (for flights south of the border)
        GPSSpoofingZone(
            name: "Monterrey Region",
            region: "Mexico",
            centerLat: 25.6866,
            centerLon: -100.3161,
            radiusNM: 40,
            riskLevel: .caution,
            notes: "Northern Mexico - occasional GPS interference."
        ),
        GPSSpoofingZone(
            name: "Mexico City TMA",
            region: "Mexico",
            centerLat: 19.4326,
            centerLon: -99.1332,
            radiusNM: 50,
            riskLevel: .caution,
            notes: "MMMX area - some GPS anomaly reports."
        ),
        
        // US Military Testing Areas
        GPSSpoofingZone(
            name: "White Sands",
            region: "New Mexico",
            centerLat: 32.9500,
            centerLon: -106.4200,
            radiusNM: 60,
            riskLevel: .caution,
            notes: "Military GPS testing area. Check NOTAMs."
        ),
        GPSSpoofingZone(
            name: "China Lake",
            region: "California",
            centerLat: 35.6855,
            centerLon: -117.6920,
            radiusNM: 50,
            riskLevel: .caution,
            notes: "Naval weapons testing. GPS denial possible."
        ),
        GPSSpoofingZone(
            name: "Nellis Range",
            region: "Nevada",
            centerLat: 37.2350,
            centerLon: -115.8111,
            radiusNM: 80,
            riskLevel: .caution,
            notes: "Military training area. GPS interference during exercises."
        ),
        
        // International Hotspots (if ever needed)
        GPSSpoofingZone(
            name: "Eastern Mediterranean",
            region: "Middle East",
            centerLat: 33.8,
            centerLon: 35.5,
            radiusNM: 200,
            riskLevel: .alert,
            notes: "MAJOR spoofing zone - Beirut/Cyprus/Israel area."
        ),
        GPSSpoofingZone(
            name: "Black Sea/Crimea",
            region: "Eastern Europe",
            centerLat: 44.6,
            centerLon: 33.5,
            radiusNM: 150,
            riskLevel: .alert,
            notes: "Active conflict zone. Heavy GPS spoofing."
        ),
        GPSSpoofingZone(
            name: "Baltic Region",
            region: "Europe",
            centerLat: 54.9,
            centerLon: 20.5,
            radiusNM: 100,
            riskLevel: .warning,
            notes: "Kaliningrad jamming affects Poland, Lithuania."
        )
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadSavedEvents()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring GPS for spoofing indicators
    func startMonitoring() {
        isMonitoring = true
        print("🛡️ GPS Spoofing Monitor: Started")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        print("🛡️ GPS Spoofing Monitor: Stopped")
    }
    
    /// Process a new location update - call this from your existing location manager
    func processLocationUpdate(_ location: CLLocation, flightNumber: String? = nil) {
        guard isMonitoring else { return }
        
        var detectedAnomalies: [GPSSpoofingEvent] = []
        
        // 1. Check for software simulation (iOS 15+)
        if #available(iOS 15.0, *) {
            if let sourceInfo = location.sourceInformation {
                if sourceInfo.isSimulatedBySoftware {
                    let event = GPSSpoofingEvent(
                        location: location,
                        anomalyType: .softwareSimulation,
                        alertLevel: .alert,
                        details: "Location is being simulated by software",
                        flightNumber: flightNumber
                    )
                    detectedAnomalies.append(event)
                }
            }
        }
        
        // 2. Check if in known spoofing zone
        if alertOnKnownZones, let zone = checkKnownSpoofingZones(location: location) {
            if currentZone?.name != zone.name {
                // Just entered a new zone
                let event = GPSSpoofingEvent(
                    location: location,
                    anomalyType: .knownSpoofingZone,
                    alertLevel: zone.riskLevel,
                    details: "Entered \(zone.name): \(zone.notes)",
                    flightNumber: flightNumber
                )
                detectedAnomalies.append(event)
                currentZone = zone
            }
        } else {
            currentZone = nil
        }
        
        // 3. Check for position jumps
        if let lastPos = positionHistory.last {
            let anomaly = checkForPositionJump(from: lastPos, to: location, flightNumber: flightNumber)
            if let anomaly = anomaly {
                detectedAnomalies.append(anomaly)
            }
        }
        
        // 4. Check for poor accuracy
        if location.horizontalAccuracy > minAccuracyThreshold {
            let event = GPSSpoofingEvent(
                location: location,
                anomalyType: .poorAccuracy,
                alertLevel: .warning,
                details: "GPS accuracy degraded: \(Int(location.horizontalAccuracy))m (threshold: \(Int(minAccuracyThreshold))m)",
                flightNumber: flightNumber
            )
            detectedAnomalies.append(event)
        }
        
        // 5. Check for time discrepancy
        let systemTime = Date()
        let gpsTime = location.timestamp
        let timeDiff = abs(systemTime.timeIntervalSince(gpsTime))
        if timeDiff > timeDiscrepancyThreshold {
            let event = GPSSpoofingEvent(
                location: location,
                anomalyType: .timeDiscrepancy,
                alertLevel: .warning,
                details: "GPS time differs from system time by \(String(format: "%.1f", timeDiff)) seconds",
                flightNumber: flightNumber
            )
            detectedAnomalies.append(event)
        }
        
        // 6. Check for unrealistic speed
        let speedKts = location.speed * 1.94384 // m/s to knots
        if speedKts > maxRealisticSpeedKts && location.speed >= 0 {
            let event = GPSSpoofingEvent(
                location: location,
                anomalyType: .unrealisticSpeed,
                alertLevel: .alert,
                details: "GPS reports unrealistic speed: \(Int(speedKts)) kts",
                flightNumber: flightNumber
            )
            detectedAnomalies.append(event)
        }
        
        // Update position history
        positionHistory.append(location)
        if positionHistory.count > maxHistoryCount {
            positionHistory.removeFirst()
        }
        
        // If position seems valid, update last valid position
        if detectedAnomalies.isEmpty || detectedAnomalies.allSatisfy({ $0.alertLevel == .caution }) {
            lastValidPosition = location
        }
        
        // Process detected anomalies
        if !detectedAnomalies.isEmpty {
            processAnomalies(detectedAnomalies)
        } else {
            // All clear
            if currentZone == nil {
                updateStatus(.normal, message: "GPS: Normal")
            }
        }
    }
    
    /// Check if a route passes through any known spoofing zones
    func checkRouteForSpoofingZones(departure: CLLocationCoordinate2D, arrival: CLLocationCoordinate2D) -> [GPSSpoofingZone] {
        var affectedZones: [GPSSpoofingZone] = []
        
        for zone in knownSpoofingZones {
            // Simple check: see if either endpoint is in the zone, or if zone is between them
            let depDistance = distanceNM(from: departure, to: zone.centerCoordinate)
            let arrDistance = distanceNM(from: arrival, to: zone.centerCoordinate)
            
            if depDistance <= zone.radiusNM || arrDistance <= zone.radiusNM {
                affectedZones.append(zone)
                continue
            }
            
            // Check if route crosses through zone (simplified great circle check)
            if routeCrossesZone(from: departure, to: arrival, zone: zone) {
                affectedZones.append(zone)
            }
        }
        
        return affectedZones.sorted { $0.riskLevel.rawValue > $1.riskLevel.rawValue }
    }
    
    /// Get pre-flight briefing for spoofing risk on a route
    func getRouteSpoofingBriefing(departure: String, arrival: String, depCoord: CLLocationCoordinate2D, arrCoord: CLLocationCoordinate2D) -> String {
        let zones = checkRouteForSpoofingZones(departure: depCoord, arrival: arrCoord)
        
        if zones.isEmpty {
            return "✅ GPS SPOOFING BRIEFING: No known spoofing zones along \(departure)-\(arrival) route."
        }
        
        var briefing = "⚠️ GPS SPOOFING BRIEFING for \(departure)-\(arrival):\n\n"
        
        for zone in zones {
            let icon: String
            switch zone.riskLevel {
            case .alert: icon = "🔴"
            case .warning: icon = "🟠"
            case .caution: icon = "🟡"
            case .normal: icon = "🟢"
            }
            
            briefing += "\(icon) \(zone.name) (\(zone.region))\n"
            briefing += "   Risk: \(zone.riskLevel.rawValue)\n"
            briefing += "   \(zone.notes)\n\n"
        }
        
        briefing += "RECOMMENDATIONS:\n"
        briefing += "• Monitor GPS accuracy and position carefully\n"
        briefing += "• Cross-check position with VOR/DME if available\n"
        briefing += "• Be prepared to navigate using conventional methods\n"
        briefing += "• Report anomalies to ATC and dispatch"
        
        return briefing
    }
    
    /// Clear event history
    func clearEvents() {
        recentEvents.removeAll()
        saveEvents()
    }
    
    /// Export events for FAA reporting
    func exportEventsForReporting() -> String {
        var report = "GPS SPOOFING/INTERFERENCE EVENT REPORT\n"
        report += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .long))\n"
        report += "Aircraft Operator: USA Jet Airlines\n"
        report += "="*50 + "\n\n"
        
        for event in recentEvents {
            report += "Event ID: \(event.id.uuidString.prefix(8))\n"
            report += "Time: \(DateFormatter.localizedString(from: event.timestamp, dateStyle: .short, timeStyle: .long))\n"
            report += "Type: \(event.anomalyType.rawValue)\n"
            report += "Alert Level: \(event.alertLevel.rawValue)\n"
            report += "Position: \(String(format: "%.4f", event.location.latitude)), \(String(format: "%.4f", event.location.longitude))\n"
            report += "Altitude: \(Int(event.location.altitude)) ft\n"
            report += "Flight: \(event.flightNumber ?? "N/A")\n"
            report += "Details: \(event.details)\n"
            report += "-"*40 + "\n\n"
        }
        
        return report
    }
    
    // MARK: - Private Methods
    
    private func checkKnownSpoofingZones(location: CLLocation) -> GPSSpoofingZone? {
        for zone in knownSpoofingZones {
            let distance = distanceNM(from: location.coordinate, to: zone.centerCoordinate)
            if distance <= zone.radiusNM {
                return zone
            }
        }
        return nil
    }
    
    private func checkForPositionJump(from lastPos: CLLocation, to newPos: CLLocation, flightNumber: String?) -> GPSSpoofingEvent? {
        let distanceMeters = newPos.distance(from: lastPos)
        let distanceNM = distanceMeters / 1852.0
        let timeDelta = newPos.timestamp.timeIntervalSince(lastPos.timestamp)
        
        guard timeDelta > 0 else { return nil }
        
        let impliedSpeedMPS = distanceMeters / timeDelta
        let impliedSpeedKts = impliedSpeedMPS * 1.94384
        
        // Check for sudden position jump that's unrealistic
        if distanceNM > positionJumpThresholdNM && timeDelta < 60 {
            // Position jumped more than threshold in less than a minute
            if impliedSpeedKts > maxRealisticSpeedKts {
                return GPSSpoofingEvent(
                    location: newPos,
                    anomalyType: .suddenPositionJump,
                    alertLevel: .alert,
                    details: "Position jumped \(String(format: "%.1f", distanceNM)) NM in \(Int(timeDelta))s (implied \(Int(impliedSpeedKts)) kts)",
                    flightNumber: flightNumber
                )
            }
        }
        
        return nil
    }
    
    private func distanceNM(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1852.0
    }
    
    private func routeCrossesZone(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, zone: GPSSpoofingZone) -> Bool {
        // Simplified: check midpoint and quarter points
        let checkPoints = [
            CLLocationCoordinate2D(
                latitude: (from.latitude + to.latitude) / 2,
                longitude: (from.longitude + to.longitude) / 2
            ),
            CLLocationCoordinate2D(
                latitude: (from.latitude * 3 + to.latitude) / 4,
                longitude: (from.longitude * 3 + to.longitude) / 4
            ),
            CLLocationCoordinate2D(
                latitude: (from.latitude + to.latitude * 3) / 4,
                longitude: (from.longitude + to.longitude * 3) / 4
            )
        ]
        
        for point in checkPoints {
            let distance = distanceNM(from: point, to: zone.centerCoordinate)
            if distance <= zone.radiusNM {
                return true
            }
        }
        
        return false
    }
    
    private func processAnomalies(_ anomalies: [GPSSpoofingEvent]) {
        // Find highest alert level
        let highestLevel = anomalies.map { $0.alertLevel }.max { a, b in
            let order: [GPSSpoofingAlertLevel] = [.normal, .caution, .warning, .alert]
            return (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        } ?? .normal
        
        // Add events to history
        for event in anomalies {
            if !recentEvents.contains(where: { $0.id == event.id }) {
                recentEvents.insert(event, at: 0)
            }
        }
        
        // Trim history
        if recentEvents.count > 100 {
            recentEvents = Array(recentEvents.prefix(100))
        }
        
        // Update status
        let messages = anomalies.map { $0.anomalyType.rawValue }
        updateStatus(highestLevel, message: messages.joined(separator: ", "))
        
        // Post notification for alerts
        if highestLevel == .alert || highestLevel == .warning {
            if shouldPostAlert() {
                postSpoofingNotification(anomalies: anomalies)
            }
        }
        
        // Save events
        saveEvents()
    }
    
    private func updateStatus(_ level: GPSSpoofingAlertLevel, message: String) {
        DispatchQueue.main.async {
            self.currentAlertLevel = level
            self.statusMessage = message
        }
    }
    
    private func shouldPostAlert() -> Bool {
        guard let lastAlert = lastAlertTime else {
            lastAlertTime = Date()
            return true
        }
        
        if Date().timeIntervalSince(lastAlert) > minimumAlertInterval {
            lastAlertTime = Date()
            return true
        }
        
        return false
    }
    
    private func postSpoofingNotification(anomalies: [GPSSpoofingEvent]) {
        let userInfo: [String: Any] = [
            "alertLevel": currentAlertLevel.rawValue,
            "anomalyCount": anomalies.count,
            "primaryAnomaly": anomalies.first?.anomalyType.rawValue ?? "Unknown",
            "details": anomalies.first?.details ?? ""
        ]
        
        NotificationCenter.default.post(
            name: .gpsSpoofingDetected,
            object: nil,
            userInfo: userInfo
        )
        
        print("🛡️⚠️ GPS SPOOFING ALERT: \(anomalies.first?.details ?? "Unknown anomaly")")
    }
    
    // MARK: - Persistence
    
    private func loadSavedEvents() {
        guard let data = UserDefaults.standard.data(forKey: "gpsSpoofingEvents"),
              let events = try? JSONDecoder().decode([GPSSpoofingEvent].self, from: data) else {
            return
        }
        recentEvents = events
    }
    
    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(recentEvents) else { return }
        UserDefaults.standard.set(data, forKey: "gpsSpoofingEvents")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let gpsSpoofingDetected = Notification.Name("gpsSpoofingDetected")
    static let gpsSpoofingZoneEntered = Notification.Name("gpsSpoofingZoneEntered")
    static let gpsSpoofingZoneExited = Notification.Name("gpsSpoofingZoneExited")
}

// MARK: - String Extension for Report Formatting

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
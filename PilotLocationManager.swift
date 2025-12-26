import Foundation
import CoreLocation
import SwiftUI

// MARK: - Enhanced Pilot Location Manager with Speed Triggers & Always Auth
class PilotLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentAirport: String?
    @Published var isLocationAuthorized = false
    @Published var locationStatus = "Initializing..."
    
    private let locationManager = CLLocationManager()
    private let airportDB = AirportDatabaseManager.shared
    private var monitoredGeofences: Set<String> = []
    
    // 🔥 Speed trigger state machine
    private var lastFastRollTimestamp: Date? = nil
    private var hasPostedTakeoffThisSession = false
    private var hasPostedLandingThisSession = false
    
    // 🛡️ Prevent duplicate geofence setup
    private var hasSetupGeofences = false
    private var isSettingUpGeofences = false
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ NEW: GPS Spoofing Monitor Integration
    // ═══════════════════════════════════════════════════════════════════════════
    private let spoofingMonitor = GPSSpoofingMonitor.shared
    @Published var gpsIntegrityStatus: GPSSpoofingAlertLevel = .normal
    @Published var inKnownSpoofingZone: Bool = false
    @Published var currentSpoofingZoneName: String? = nil
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Debug tracking
    @Published var debugInfo = ""
    @Published var nearbyAirports: [(icao: String, name: String, distance: Double)] = []
    
    override init() {
        super.init()
        setupLocationManager()
        requestLocationPermission()
        
        // ═══════════════════════════════════════════════════════════════════════
        // 🛡️ NEW: Setup spoofing monitor listeners
        // ═══════════════════════════════════════════════════════════════════════
        setupSpoofingMonitorListeners()
        // ═══════════════════════════════════════════════════════════════════════
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        
        // Background location updates + don't pause
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        print("🛩️ PilotLocationManager: Setting up location services")
        updateDebugInfo("Location manager configured")
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ NEW: Spoofing Monitor Listeners
    // ═══════════════════════════════════════════════════════════════════════════
    private func setupSpoofingMonitorListeners() {
        // Listen for spoofing alerts
        NotificationCenter.default.addObserver(
            forName: .gpsSpoofingDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSpoofingNotification(notification)
        }
        
        // Listen for zone entry
        NotificationCenter.default.addObserver(
            forName: .gpsSpoofingZoneEntered,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let zoneName = notification.userInfo?["zoneName"] as? String {
                self?.inKnownSpoofingZone = true
                self?.currentSpoofingZoneName = zoneName
                print("🛡️ Entered GPS spoofing zone: \(zoneName)")
            }
        }
        
        // Listen for zone exit
        NotificationCenter.default.addObserver(
            forName: .gpsSpoofingZoneExited,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.inKnownSpoofingZone = false
            self?.currentSpoofingZoneName = nil
            print("🛡️ Exited GPS spoofing zone")
        }
        
        print("🛡️ PilotLocationManager: Spoofing monitor listeners configured")
    }
    
    private func handleSpoofingNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let alertLevelString = userInfo["alertLevel"] as? String else { return }
        
        if let alertLevel = GPSSpoofingAlertLevel(rawValue: alertLevelString) {
            gpsIntegrityStatus = alertLevel
        }
        
        // Update zone status from monitor
        inKnownSpoofingZone = spoofingMonitor.currentZone != nil
        currentSpoofingZoneName = spoofingMonitor.currentZone?.name
    }
    // ═══════════════════════════════════════════════════════════════════════════
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("🛩️ Location access not determined, requesting ALWAYS")
            locationManager.requestAlwaysAuthorization()
            updateLocationStatus("Requesting 'Always' permission...")
            
        case .denied, .restricted:
            print("🛩️ Location access denied/restricted")
            updateLocationStatus("Location access denied")
            isLocationAuthorized = false
            
        case .authorizedWhenInUse:
            print("🛩️ WhenInUse → requesting ALWAYS for geofencing")
            locationManager.requestAlwaysAuthorization()
            updateLocationStatus("Need 'Always' permission for geofencing")
            isLocationAuthorized = true
            startLocationServices()
            
        case .authorizedAlways:
            print("🛩️ Location access granted (Always) - starting services")
            isLocationAuthorized = true
            startLocationServices()
            updateLocationStatus("Location authorized")
            
        @unknown default:
            print("🛩️ Unknown location authorization status")
            updateLocationStatus("Unknown authorization status")
        }
    }
    
    func startLocationServices() {
        guard isLocationAuthorized else {
            print("🛩️ Cannot start location services - not authorized")
            return
        }
        
        print("🛩️ Starting location services...")
        locationManager.startUpdatingLocation()
        
        // ═══════════════════════════════════════════════════════════════════════
        // 🛡️ NEW: Start spoofing monitor when location services start
        // ═══════════════════════════════════════════════════════════════════════
        spoofingMonitor.startMonitoring()
        print("🛡️ GPS Spoofing Monitor started")
        // ═══════════════════════════════════════════════════════════════════════
        
        // Setup geofencing only once with delay
        if !hasSetupGeofences && !isSettingUpGeofences {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.setupGeofencing()
            }
        } else {
            print("🛩️ Geofencing already set up or in progress, skipping")
        }
        
        updateLocationStatus("Location services active")
        updateDebugInfo("Location services started")
    }
    
    // MARK: - Geofencing Setup (FIXED)
    private func setupGeofencing() {
        // Prevent duplicate calls
        guard !hasSetupGeofences else {
            // Silent - already set up
            return
        }
        
        guard !isSettingUpGeofences else {
            // Silent - already in progress
            return
        }
        
        isSettingUpGeofences = true
        print("🛩️ Setting up geofencing...")
        
        // Clear existing geofences
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredGeofences.removeAll()
        
        // Get priority airports (limited to 20 due to iOS restriction)
        let priorityAirports = airportDB.getPriorityAirportsForGeofencing()
        
        var setupCount = 0
        for (icao, coordinate) in priorityAirports {
            let region = CLCircularRegion(
                center: coordinate,
                radius: 1000, // 1km radius
                identifier: icao
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            locationManager.startMonitoring(for: region)
            monitoredGeofences.insert(icao)
            setupCount += 1
        }
        
        print("🛩️ ✅ Geofence setup complete: \(setupCount) airports monitored")
        updateDebugInfo("Geofencing setup complete: \(setupCount) airports")
        
        hasSetupGeofences = true
        isSettingUpGeofences = false
        
        // Request current location state for all regions
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }
    }
    
    // MARK: - Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.updateDebugInfo("Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Find nearby airports
            self.updateNearbyAirports(location)
            
            // Check for current airport
            self.checkCurrentAirport(location)
            
            // ═══════════════════════════════════════════════════════════════════
            // 🛡️ NEW: Send location to GPS Spoofing Monitor
            // ═══════════════════════════════════════════════════════════════════
            self.spoofingMonitor.processLocationUpdate(
                location,
                flightNumber: self.getCurrentFlightNumber()
            )
            
            // Update published spoofing status
            self.gpsIntegrityStatus = self.spoofingMonitor.currentAlertLevel
            self.inKnownSpoofingZone = self.spoofingMonitor.currentZone != nil
            self.currentSpoofingZoneName = self.spoofingMonitor.currentZone?.name
            // ═══════════════════════════════════════════════════════════════════
            
            // 🔥 Speed-trigger logic (knots)
            let speedMS = max(0, location.speed)
            let speedKt = speedMS * 1.94384

            let now = Date()
            let atAirport = (self.currentAirport != nil)

            // Takeoff trigger: speed >= 80kts at airport
            if speedKt >= 80 {
                self.lastFastRollTimestamp = now
                self.hasPostedLandingThisSession = false
                if atAirport && !self.hasPostedTakeoffThisSession {
                    NotificationCenter.default.post(name: Notification.Name("takeoffRollStarted"), object: nil, userInfo: [
                        "airport": self.currentAirport ?? "",
                        "speedKt": speedKt
                    ])
                    self.hasPostedTakeoffThisSession = true
                    self.updateDebugInfo("Trigger: TAKEOFF ≥80 kt")
                    print("🛩️ Triggered takeoffRollStarted at \(Int(speedKt)) kt")
                }
            }

            // Landing trigger: recently fast, now below 60kts at airport
            if atAirport, speedKt > 0, speedKt < 60,
               let lastFast = self.lastFastRollTimestamp,
               now.timeIntervalSince(lastFast) < 10 * 60,
               !self.hasPostedLandingThisSession {

                NotificationCenter.default.post(name: Notification.Name("landingRollDecel"), object: nil, userInfo: [
                    "airport": self.currentAirport ?? "",
                    "speedKt": speedKt
                ])
                self.hasPostedLandingThisSession = true
                self.hasPostedTakeoffThisSession = false
                self.updateDebugInfo("Trigger: LANDING decel <60 kt")
                print("🛩️ Triggered landingRollDecel at \(Int(speedKt)) kt")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ NEW: Helper to get current flight number for spoofing logs
    // ═══════════════════════════════════════════════════════════════════════════
    private func getCurrentFlightNumber() -> String? {
        // TODO: Connect to LogBookStore to get active trip's current leg flight number
        // For now, return nil - the spoofing monitor will still work without it
        return nil
    }
    // ═══════════════════════════════════════════════════════════════════════════
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🛩️ Location authorization changed to: \(status)")
        
        DispatchQueue.main.async {
            switch status {
            case .notDetermined:
                self.updateLocationStatus("Permission not determined")
                self.isLocationAuthorized = false
                
            case .denied, .restricted:
                self.updateLocationStatus("Location access denied")
                self.isLocationAuthorized = false
                
            case .authorizedWhenInUse:
                self.updateLocationStatus("When in use - limited geofencing")
                self.isLocationAuthorized = true
                self.startLocationServices()
                
            case .authorizedAlways:
                self.updateLocationStatus("Always authorized - full geofencing")
                self.isLocationAuthorized = true
                self.startLocationServices()
                
            @unknown default:
                self.updateLocationStatus("Unknown status")
                self.isLocationAuthorized = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let icaoCode = circularRegion.identifier
        
        print("🛩️ ✅ ENTERED GEOFENCE: \(icaoCode)")
        
        DispatchQueue.main.async {
            // Check speed/altitude before declaring arrival
            if let location = self.currentLocation {
                let speedMS = max(0, location.speed)
                let speedKt = speedMS * 1.94384
                let altitudeMeters = location.altitude
                let altitudeFeet = altitudeMeters * 3.28084
                
                // Suppress if clearly airborne
                if speedKt > 100 {
                    print("🛩️ Ignoring geofence entry for \(icaoCode) - speed \(Int(speedKt)) kt (airborne)")
                    return
                }
                
                if altitudeFeet > 5000 {
                    print("🛩️ Ignoring geofence entry for \(icaoCode) - altitude \(Int(altitudeFeet)) ft (airborne)")
                    return
                }
            }
            
            self.currentAirport = icaoCode
            let airportName = self.airportDB.getAirportName(for: icaoCode)
            
            self.updateDebugInfo("ENTERED: \(icaoCode) - \(airportName)")
            
            NotificationCenter.default.post(
                name: .arrivedAtAirport,
                object: nil,
                userInfo: [
                    "airport": icaoCode,
                    "name": airportName
                ]
            )
            
            print("🛩️ Posted arrivedAtAirport notification for \(icaoCode)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let icaoCode = circularRegion.identifier
        
        print("🛩️ ✅ EXITED GEOFENCE: \(icaoCode)")
        
        DispatchQueue.main.async {
            if self.currentAirport == icaoCode {
                self.currentAirport = nil
            }
            
            let airportName = self.airportDB.getAirportName(for: icaoCode)
            self.updateDebugInfo("EXITED: \(icaoCode) - \(airportName)")
            
            NotificationCenter.default.post(
                name: Notification.Name("departedAirport"),
                object: nil,
                userInfo: [
                    "airport": icaoCode,
                    "name": airportName
                ]
            )
            
            print("🛩️ Posted departedAirport notification for \(icaoCode)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let icaoCode = region.identifier
        let airportName = airportDB.getAirportName(for: icaoCode)
        
        DispatchQueue.main.async {
            switch state {
            case .inside:
                // Check speed before declaring arrival
                if let location = self.currentLocation {
                    let speedMS = max(0, location.speed)
                    let speedKt = speedMS * 1.94384
                    let altitudeMeters = location.altitude
                    let altitudeFeet = altitudeMeters * 3.28084
                    
                    if speedKt > 100 {
                        print("🛩️ Ignoring region entry for \(icaoCode) - speed \(Int(speedKt)) kt (airborne)")
                        return
                    }
                    
                    if altitudeFeet > 5000 {
                        print("🛩️ Ignoring region entry for \(icaoCode) - altitude \(Int(altitudeFeet)) ft (airborne)")
                        return
                    }
                }
                
                print("🛩️ Currently INSIDE \(icaoCode)")
                self.currentAirport = icaoCode
                self.updateDebugInfo("INSIDE: \(icaoCode) - \(airportName)")
                
                NotificationCenter.default.post(
                    name: .arrivedAtAirport,
                    object: nil,
                    userInfo: [
                        "airport": icaoCode,
                        "name": airportName
                    ]
                )
                
            case .outside:
                break
                
            case .unknown:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🛩️ Location manager error: \(error.localizedDescription)")
        updateDebugInfo("Error: \(error.localizedDescription)")
        updateLocationStatus("Location error")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Silently handle geofence monitoring failures (iOS limit = 20)
    }
    
    // MARK: - Helper Functions
    private func checkCurrentAirport(_ location: CLLocation) {
        let nearbyAirports = airportDB.getNearbyAirports(to: location, within: 2, limit: 1)
        
        if let closest = nearbyAirports.first, closest.distance < 1000 {
            if currentAirport != closest.icao {
                currentAirport = closest.icao
                print("🛩️ Current airport updated to: \(closest.icao)")
                updateDebugInfo("Current airport: \(closest.icao)")
            }
        }
    }
    
    private func updateNearbyAirports(_ location: CLLocation) {
        let nearby = airportDB.getNearbyAirports(to: location, within: 10, limit: 5)
        nearbyAirports = nearby.map { (icao: $0.icao, name: $0.name, distance: $0.distance) }
    }
    
    private func updateLocationStatus(_ status: String) {
        DispatchQueue.main.async {
            self.locationStatus = status
        }
    }
    
    private func updateDebugInfo(_ info: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.debugInfo = "[\(timestamp)] \(info)"
        }
    }
    
    private func stateDescription(_ state: CLRegionState) -> String {
        switch state {
        case .inside: return "INSIDE"
        case .outside: return "OUTSIDE"
        case .unknown: return "UNKNOWN"
        }
    }
    
    // MARK: - Public Interface
    func refreshGeofences() {
        print("🛩️ Manual geofence refresh requested")
        hasSetupGeofences = false
        isSettingUpGeofences = false
        setupGeofencing()
    }
    
    func getLocationDebugInfo() -> String {
        var info = "🛩️ LOCATION DEBUG INFO:\n"
        info += "• Authorization: \(locationManager.authorizationStatus.description)\n"
        info += "• Is Authorized: \(isLocationAuthorized)\n"
        info += "• Current Location: \(currentLocation?.description ?? "None")\n"
        info += "• Current Airport: \(currentAirport ?? "None")\n"
        info += "• Monitored Regions: \(locationManager.monitoredRegions.count)\n"
        info += "• Geofences Set Up: \(hasSetupGeofences)\n"
        info += "• Status: \(locationStatus)\n"
        info += "• Debug: \(debugInfo)\n"
        
        // ═══════════════════════════════════════════════════════════════════════
        // 🛡️ NEW: Include GPS integrity info in debug output
        // ═══════════════════════════════════════════════════════════════════════
        info += "• GPS Integrity: \(gpsIntegrityStatus.rawValue)\n"
        if let zoneName = currentSpoofingZoneName {
            info += "• ⚠️ In Spoofing Zone: \(zoneName)\n"
        }
        info += "• Spoofing Events: \(spoofingMonitor.recentEvents.count)\n"
        // ═══════════════════════════════════════════════════════════════════════
        
        if !nearbyAirports.isEmpty {
            info += "• Nearby Airports:\n"
            for airport in nearbyAirports.prefix(3) {
                let distanceKm = airport.distance / 1000
                info += "  - \(airport.icao): \(String(format: "%.1f", distanceKm))km\n"
            }
        }
        
        if let lastFast = lastFastRollTimestamp {
            let secondsAgo = Int(Date().timeIntervalSince(lastFast))
            info += "• Last Fast Roll: \(secondsAgo)s ago\n"
            info += "• Takeoff Posted: \(hasPostedTakeoffThisSession)\n"
            info += "• Landing Posted: \(hasPostedLandingThisSession)\n"
        }
        
        return info
    }
    
    func forceLocationUpdate() {
        print("🛩️ Forcing location update...")
        locationManager.requestLocation()
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ NEW: Pre-flight route spoofing check
    // ═══════════════════════════════════════════════════════════════════════════
    func checkRouteForSpoofingZones(from departure: String, to arrival: String) -> [GPSSpoofingZone] {
        // Get coordinates for airports
        guard let depCoord = airportDB.getCoordinates(for: departure),
              let arrCoord = airportDB.getCoordinates(for: arrival) else {
            print("🛡️ Could not get coordinates for route \(departure)-\(arrival)")
            return []
        }
        
        return spoofingMonitor.checkRouteForSpoofingZones(
            departure: depCoord,
            arrival: arrCoord
        )
    }
    
    func getSpoofingBriefing(from departure: String, to arrival: String) -> String {
        guard let depCoord = airportDB.getCoordinates(for: departure),
              let arrCoord = airportDB.getCoordinates(for: arrival) else {
            return "⚠️ Could not generate spoofing briefing - airport coordinates not found"
        }
        
        return spoofingMonitor.getRouteSpoofingBriefing(
            departure: departure,
            arrival: arrival,
            depCoord: depCoord,
            arrCoord: arrCoord
        )
    }
    // ═══════════════════════════════════════════════════════════════════════════
    
    // MARK: - Test Functions
    func simulateAirportArrival(_ icaoCode: String = "KYIP") {
        print("🛩️ SIMULATING airport arrival: \(icaoCode)")
        let airportName = airportDB.getAirportName(for: icaoCode)
        
        DispatchQueue.main.async {
            self.currentAirport = icaoCode
            self.updateDebugInfo("SIMULATED ARRIVAL: \(icaoCode)")
            
            NotificationCenter.default.post(
                name: .arrivedAtAirport,
                object: nil,
                userInfo: [
                    "airport": icaoCode,
                    "name": airportName
                ]
            )
            
            print("🛩️ Posted simulated arrivedAtAirport notification")
        }
    }
    
    func simulateTakeoff(_ icaoCode: String = "TEST") {
        print("🛩️ SIMULATING takeoff: \(icaoCode)")
        
        DispatchQueue.main.async {
            self.currentAirport = icaoCode
            
            NotificationCenter.default.post(
                name: Notification.Name("takeoffRollStarted"),
                object: nil,
                userInfo: [
                    "airport": icaoCode,
                    "speedKt": 85.0
                ]
            )
            
            self.updateDebugInfo("SIMULATED TAKEOFF: \(icaoCode)")
            print("🛩️ Posted simulated takeoffRollStarted notification")
        }
    }
    
    func simulateLanding(_ icaoCode: String = "TEST") {
        print("🛩️ SIMULATING landing: \(icaoCode)")
        
        DispatchQueue.main.async {
            self.currentAirport = icaoCode
            
            NotificationCenter.default.post(
                name: Notification.Name("landingRollDecel"),
                object: nil,
                userInfo: [
                    "airport": icaoCode,
                    "speedKt": 55.0
                ]
            )
            
            self.updateDebugInfo("SIMULATED LANDING: \(icaoCode)")
            print("🛩️ Posted simulated landingRollDecel notification")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 🛡️ NEW: Simulate entering a spoofing zone (for testing)
    // ═══════════════════════════════════════════════════════════════════════════
    func simulateSpoofingZoneEntry(_ zoneName: String = "Laredo Border Region") {
        print("🛡️ SIMULATING spoofing zone entry: \(zoneName)")
        
        // Create a fake location near Laredo
        let laredoLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 27.5436, longitude: -99.4803),
            altitude: 3000,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 180,
            speed: 100, // ~194 kts
            timestamp: Date()
        )
        
        spoofingMonitor.processLocationUpdate(laredoLocation, flightNumber: "TEST123")
    }
    // ═══════════════════════════════════════════════════════════════════════════
}

// MARK: - CLAuthorizationStatus Extension
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always Authorized"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown (\(self.rawValue))"
        }
    }
}


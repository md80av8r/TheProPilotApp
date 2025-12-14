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
    private let airportDB = AirportDatabaseManager()
    private var monitoredGeofences: Set<String> = []
    
    // 🔥 NEW: Speed trigger state machine
    private var lastFastRollTimestamp: Date? = nil
    private var hasPostedTakeoffThisSession = false
    private var hasPostedLandingThisSession = false
    
    // 🛡️ FIXED: Prevent duplicate geofence setup
    private var hasSetupGeofences = false
    private var isSettingUpGeofences = false
    
    // Debug tracking
    @Published var debugInfo = ""
    @Published var nearbyAirports: [(icao: String, name: String, distance: Double)] = []
    
    override init() {
        super.init()
        setupLocationManager()
        requestLocationPermission()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        
        // 🔥 NEW: Background location updates + don't pause
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        print("🛩️ PilotLocationManager: Setting up location services")
        updateDebugInfo("Location manager configured")
    }
    
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
        // DEBUG: Commented out excessive print statement
        // print("🛩️ Will monitor \(priorityAirports.count) priority airports (iOS limit: 20)")
        
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
            // ✅ FIXED: Check speed/altitude before declaring arrival
            // Prevents false "arrived" notifications while flying over airports at FL360
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
        
        // DEBUG: Commented out excessive print statement (fires for all 20+ geofences)
        // print("🛩️ Region state for \(icaoCode): \(stateDescription(state))")
        
        DispatchQueue.main.async {
            switch state {
            case .inside:
                // ✅ FIXED: Check speed before declaring arrival
                // At FL360 you're going 400+ knots - not "at" an airport!
                if let location = self.currentLocation {
                    let speedMS = max(0, location.speed)
                    let speedKt = speedMS * 1.94384
                    let altitudeMeters = location.altitude
                    let altitudeFeet = altitudeMeters * 3.28084
                    
                    // Suppress if:
                    // - Speed > 100 knots (clearly flying, not on ground)
                    // - Altitude > 5000 feet AGL (clearly airborne)
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
                // DEBUG: Commented out excessive print statement
                // print("🛩️ Currently OUTSIDE \(icaoCode)")
                break
                
            case .unknown:
                // DEBUG: Commented out excessive print statement
                // print("🛩️ Unknown state for \(icaoCode)")
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
        let regionName = region?.identifier ?? "unknown"
        // DEBUG: Commented out excessive print statement (iOS limit = 20 geofences)
        // print("🛩️ ⚠️ Geofence monitoring failed for \(regionName): \(error.localizedDescription)")
        // Don't update debug info for every failed geofence to avoid spam
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

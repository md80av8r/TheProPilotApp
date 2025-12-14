import Foundation
import SwiftUI
import CoreLocation


// MARK: - GPS Speed Monitor with Auto-Time Logic
class GPSSpeedMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentSpeed: Double = 0
    @Published var isTracking = false
    @Published var flightState: FlightState = .onGround
    
    private var speedHistory: [Double] = []
    private let speedHistoryLimit = 5
    private var autoTimeSettings = AutoTimeSettings.shared
    
    // State tracking for auto-time triggers
    private var hasTriggeredTakeoff = false
    private var hasTriggeredLanding = false
    private var lastTriggerTime: [String: Date] = [:]
    private let minimumTimeBetweenTriggers: TimeInterval = 10 // seconds
    
    enum FlightState {
        case onGround
        case taxiing
        case takeoffRoll
        case airborne
        case landingRoll
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startTracking() {
        // Don't restart if already tracking (prevents state reset during GPX tests)
        guard !isTracking else {
            print("🛰️ Speed monitor already tracking - skipping restart")
            return
        }
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
                locationManager.authorizationStatus == .authorizedAlways else {
            locationManager.requestAlwaysAuthorization() // Request "Always" for background tracking
            return
        }
        
        locationManager.startUpdatingLocation()
        isTracking = true
        resetState()
        print("🛰️ GPS Speed monitoring started for auto-time")
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
        speedHistory.removeAll()
        currentSpeed = 0
        resetState()
        print("🛑 GPS Speed monitoring stopped")
    }
    
    // MARK: - Test Mode Support
    func injectTestLocation(_ location: CLLocation) {
        // Allow simulated GPX locations to be processed
        guard location.speed >= 0 else { return }
        
        let speedKnots = location.speed * 1.94384 // Convert m/s to knots
        updateSpeed(speedKnots)
        
        print("🧪 TEST: Injected speed \(Int(speedKnots)) kts into speed monitor (State: \(flightState))")
    }
    
    func resetForTesting() {
        // Reset for a new test run
        speedHistory.removeAll()
        currentSpeed = 0
        hasTriggeredTakeoff = false
        hasTriggeredLanding = false
        flightState = .onGround
        lastTriggerTime.removeAll()
        print("🔄 Speed monitor reset for testing - State: \(flightState)")
    }
    
    private func resetState() {
        hasTriggeredTakeoff = false
        hasTriggeredLanding = false
        flightState = .onGround
        lastTriggerTime.removeAll()
    }
    
    // MARK: - Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.speed >= 0 else { return }
        
        let speedKnots = location.speed * 1.94384 // Convert m/s to knots
        updateSpeed(speedKnots)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            stopTracking()
            print("⚠️ Location access denied - auto-time will not work")
        default:
            break
        }
    }
    
    // MARK: - Speed Processing with Auto-Time Logic
    private func updateSpeed(_ newSpeed: Double) {
        DispatchQueue.main.async {
            self.speedHistory.append(newSpeed)
            
            if self.speedHistory.count > self.speedHistoryLimit {
                self.speedHistory.removeFirst()
            }
            
            // Smoothed speed to reduce false triggers
            let smoothedSpeed = self.speedHistory.reduce(0, +) / Double(self.speedHistory.count)
            self.currentSpeed = max(0, smoothedSpeed)
            
            // Check for auto-time events
            self.checkForAutoTimeEvents(smoothedSpeed)
        }
    }
    
    // MARK: - Auto-Time Event Detection
    private func checkForAutoTimeEvents(_ speed: Double) {
        guard autoTimeSettings.isEnabled else { return }
        
        let takeoffThreshold = autoTimeSettings.takeoffSpeedThreshold
        let landingThreshold = autoTimeSettings.landingSpeedThreshold
        
        // STATE MACHINE for flight phases
        switch flightState {
        case .onGround:
            if speed > 10 && speed < takeoffThreshold {
                flightState = .taxiing
                print("🚕 Detected taxi - speed: \(Int(speed)) kts")
            }
            
        case .taxiing:
            if speed >= takeoffThreshold && !hasTriggeredTakeoff {
                flightState = .takeoffRoll
                triggerOFFTime(speed: speed)
                hasTriggeredTakeoff = true
                print("🛫 TAKEOFF DETECTED - Triggered OFF time at \(Int(speed)) kts")
            } else if speed < 5 {
                flightState = .onGround
            }
            
        case .takeoffRoll:
            if speed >= takeoffThreshold + 20 {
                flightState = .airborne
                print("✈️ Airborne - speed: \(Int(speed)) kts")
            }
            
        case .airborne:
            if speed <= landingThreshold {
                flightState = .landingRoll
                triggerONTime(speed: speed)
                print("🛬 LANDING DETECTED - Triggered ON time at \(Int(speed)) kts")
            }
            
        case .landingRoll:
            if speed < 10 {
                flightState = .onGround
                hasTriggeredTakeoff = false
                hasTriggeredLanding = false
                print("🏁 Aircraft stopped - ready for next leg")
            }
        }
    }
    
    // MARK: - Notification Triggers
    private func triggerOFFTime(speed: Double) {
        guard canTrigger("OFF") else { return }
        
        let currentTime = getCurrentTimeString()
        
        NotificationCenter.default.post(
            name: .autoTimeTriggered,
            object: nil,
            userInfo: [
                "timeType": "OFF",
                "timeValue": currentTime,
                "speedKts": speed,
                "timestamp": Date()
            ]
        )
        
        // Also post takeoff roll notification for Live Activity
        NotificationCenter.default.post(
            name: .takeoffRollStarted,
            object: nil,
            userInfo: ["speedKt": speed]
        )
        
        lastTriggerTime["OFF"] = Date()
        print("📤 Posted OFF time notification: \(currentTime)")
    }
    
    private func triggerONTime(speed: Double) {
        guard canTrigger("ON") else { return }
        
        let currentTime = getCurrentTimeString()
        
        NotificationCenter.default.post(
            name: .autoTimeTriggered,
            object: nil,
            userInfo: [
                "timeType": "ON",
                "timeValue": currentTime,
                "speedKts": speed,
                "timestamp": Date()
            ]
        )
        
        // Also post landing roll notification for Live Activity
        NotificationCenter.default.post(
            name: .landingRollDecel,
            object: nil,
            userInfo: ["speedKt": speed]
        )
        
        lastTriggerTime["ON"] = Date()
        print("📤 Posted ON time notification: \(currentTime)")
    }
    
    private func canTrigger(_ timeType: String) -> Bool {
        guard let lastTime = lastTriggerTime[timeType] else { return true }
        return Date().timeIntervalSince(lastTime) > minimumTimeBetweenTriggers
    }
    
    private func getCurrentTimeString() -> String {
        // ✅ STEP 1: Get current time (potentially rounded)
        let now = Date()
        let shouldRound = autoTimeSettings.roundTimesToFiveMinutes
        let finalTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)
        
        // ✅ STEP 2: Format the (potentially rounded) time
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        
        if autoTimeSettings.useZuluTime {
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            print("⏰ Using Zulu time for auto-log")
        } else {
            formatter.timeZone = TimeZone.current
            print("⏰ Using local time for auto-log")
        }
        
        let timeString = formatter.string(from: finalTime)
        
        // ✅ STEP 3: Log if rounding occurred
        if shouldRound {
            let originalString = formatter.string(from: now)
            if originalString != timeString {
                print("⏱️ Time rounded: \(originalString) → \(timeString)")
            }
        }
        
        return timeString
    }
}

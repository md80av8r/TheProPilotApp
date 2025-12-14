// GPXTestIntegration.swift - Connect GPX Player to PilotLocationManager
// Allows GPX playback to trigger real location updates for testing

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Test Mode Manager
class GPXTestModeManager: ObservableObject {
    static let shared = GPXTestModeManager()
    
    @Published var isTestMode = false
    @Published var testMessage = ""
    
    private var locationManager: PilotLocationManager?
    private var speedMonitor: GPSSpeedMonitor?
    
    private init() {}
    
    func configure(with locationManager: PilotLocationManager, speedMonitor: GPSSpeedMonitor? = nil) {
        self.locationManager = locationManager
        self.speedMonitor = speedMonitor
        
        // Listen for GPX test location updates
        NotificationCenter.default.addObserver(
            forName: Notification.Name("GPXTestLocationUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let location = notification.userInfo?["location"] as? CLLocation else { return }
            self?.processTestLocation(location)
        }
    }
    
    func enableTestMode() {
        isTestMode = true
        testMessage = "Test Mode Active - GPX playback enabled"
        print("🧪 GPX Test Mode ENABLED")
    }
    
    func disableTestMode() {
        isTestMode = false
        testMessage = ""
        print("🧪 GPX Test Mode DISABLED")
    }
    
    private func processTestLocation(_ location: CLLocation) {
        guard isTestMode else { return }
        
        // Manually trigger the location manager's delegate method
        // This simulates a real GPS location update
        locationManager?.currentLocation = location
        
        // **CRITICAL**: Inject location into speed monitor for auto-time detection
        speedMonitor?.injectTestLocation(location)
        
        // Calculate speed in knots
        let speedMS = max(0, location.speed)
        let speedKt = speedMS * 1.94384
        
        // Check if we're at an airport (for testing, we'll use the GPX file's airports)
        checkAirportProximity(location)
        
        // Trigger speed-based events (backup, but speed monitor should handle this)
        checkSpeedTriggers(location: location, speedKt: speedKt)
        
        testMessage = "Speed: \(Int(speedKt)) kts | Alt: \(Int(location.altitude)) ft"
    }
    
    private func checkAirportProximity(_ location: CLLocation) {
        // KYIP coordinates
        let kyip = CLLocation(latitude: 42.2379, longitude: -83.5304)
        // KDTW coordinates
        let kdtw = CLLocation(latitude: 42.2124, longitude: -83.3534)
        
        let distanceToKYIP = location.distance(from: kyip)
        let distanceToKDTW = location.distance(from: kdtw)
        
        if distanceToKYIP < 1000 {
            if locationManager?.currentAirport != "KYIP" {
                print("🏢 Entered KYIP geofence (simulated)")
                locationManager?.currentAirport = "KYIP"
                NotificationCenter.default.post(
                    name: .arrivedAtAirport,
                    object: nil,
                    userInfo: ["airport": "KYIP", "name": "Willow Run Airport"]
                )
            }
        } else if distanceToKDTW < 1000 {
            if locationManager?.currentAirport != "KDTW" {
                print("🏢 Entered KDTW geofence (simulated)")
                locationManager?.currentAirport = "KDTW"
                NotificationCenter.default.post(
                    name: .arrivedAtAirport,
                    object: nil,
                    userInfo: ["airport": "KDTW", "name": "Detroit Metropolitan Wayne County"]
                )
            }
        }
    }
    
    private var lastFastRollTimestamp: Date?
    private var hasPostedTakeoffThisSession = false
    private var hasPostedLandingThisSession = false
    
    private func checkSpeedTriggers(location: CLLocation, speedKt: Double) {
        let now = Date()
        let atAirport = (locationManager?.currentAirport != nil)
        
        // Takeoff trigger: speed >= 80kts at airport
        if speedKt >= 80 {
            lastFastRollTimestamp = now
            hasPostedLandingThisSession = false
            
            if atAirport && !hasPostedTakeoffThisSession {
                print("🛫 TEST MODE: Triggering takeoffRollStarted at \(Int(speedKt)) kts")
                NotificationCenter.default.post(
                    name: Notification.Name("takeoffRollStarted"),
                    object: nil,
                    userInfo: [
                        "airport": locationManager?.currentAirport ?? "TEST",
                        "speedKt": speedKt
                    ]
                )
                hasPostedTakeoffThisSession = true
            }
        }
        
        // Landing trigger: recently fast, now below 60kts at airport
        if atAirport, speedKt > 0, speedKt < 60,
           let lastFast = lastFastRollTimestamp,
           now.timeIntervalSince(lastFast) < 10 * 60,
           !hasPostedLandingThisSession {
            
            print("🛬 TEST MODE: Triggering landingRollDecel at \(Int(speedKt)) kts")
            NotificationCenter.default.post(
                name: Notification.Name("landingRollDecel"),
                object: nil,
                userInfo: [
                    "airport": locationManager?.currentAirport ?? "TEST",
                    "speedKt": speedKt
                ]
            )
            hasPostedLandingThisSession = true
            hasPostedTakeoffThisSession = false
        }
    }
    
    // Reset test session
    func resetTestSession() {
        lastFastRollTimestamp = nil
        hasPostedTakeoffThisSession = false
        hasPostedLandingThisSession = false
        
        // Also reset speed monitor for clean test
        speedMonitor?.resetForTesting()
        
        print("🔄 Test session reset (including speed monitor)")
    }
}

// MARK: - Enhanced GPX Test View with Integration
struct GPXTestingView: View {
    @StateObject private var player = GPXTestPlayer()
    @StateObject private var testMode = GPXTestModeManager.shared
    @EnvironmentObject var locationManager: PilotLocationManager
    
    // Add speed monitor to receive it from parent
    var speedMonitor: GPSSpeedMonitor?
    
    @State private var showingInstructions = false
    @State private var takeoffDetected = false
    @State private var landingDetected = false
    @State private var lastEventMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Test Mode Toggle
                Section("Test Mode") {
                    Toggle(isOn: Binding(
                        get: { testMode.isTestMode },
                        set: { enabled in
                            if enabled {
                                testMode.enableTestMode()
                            } else {
                                testMode.disableTestMode()
                            }
                        }
                    )) {
                        Label("Enable GPX Testing", systemImage: "play.circle.fill")
                    }
                    .tint(.orange)
                    
                    if testMode.isTestMode {
                        Label("Test Mode Active", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.orange)
                        
                        Text(testMode.testMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Reset Test Session") {
                            testMode.resetTestSession()
                            takeoffDetected = false
                            landingDetected = false
                            lastEventMessage = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Speed Detection Status
                if testMode.isTestMode && player.totalTrackPoints > 0 {
                    Section("Speed Event Detection") {
                        HStack {
                            Label("Takeoff (≥80 kts)", systemImage: "airplane.departure")
                            Spacer()
                            if takeoffDetected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Detected!")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                Text("Waiting...")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Label("Landing (<60 kts)", systemImage: "airplane.arrival")
                            Spacer()
                            if landingDetected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Detected!")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                Text("Waiting...")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !lastEventMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Event:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(lastEventMessage)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Clear times button for testing
                        Button(role: .destructive) {
                            clearFlightTimes()
                        } label: {
                            Label("Clear All Flight Times", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                
                // GPX File Loading
                Section("GPX File") {
                    Button {
                        // Load the test file
                        if player.loadGPX(from: "YIP_DTW") {
                            testMode.enableTestMode()
                            testMode.resetTestSession() // Reset state for new test
                        } else {
                            // Show error feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    } label: {
                        HStack {
                            Label("Load YIP_DTW", systemImage: "doc.fill")
                            if player.isPlaying {
                                Spacer()
                                Text("Playing...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(player.isPlaying) // Can't load while playing
                    
                    Button {
                        // Load the test file
                        if player.loadGPX(from: "KDTW_KCLE") {
                            testMode.enableTestMode()
                            testMode.resetTestSession() // Reset state for new test
                        } else {
                            // Show error feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    } label: {
                        HStack {
                            Label("Load KDTW_KCLE", systemImage: "doc.fill")
                            if player.isPlaying {
                                Spacer()
                                Text("Playing...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(player.isPlaying) // Can't load while playing
                    
                    if player.totalTrackPoints > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(player.totalTrackPoints) track points loaded")
                                Spacer()
                            }
                            
                            HStack {
                                Label("Duration", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(player.getTimeRemaining())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if !player.statusMessage.isEmpty && player.statusMessage != "Ready" {
                        // Show error message
                        Label(player.statusMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Playback Controls
                if player.totalTrackPoints > 0 {
                    Section("Playback") {
                        // Main controls
                        HStack(spacing: 12) {
                            Button(action: player.play) {
                                Image(systemName: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(player.isPlaying)
                            
                            Button(action: player.pause) {
                                Image(systemName: "pause.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!player.isPlaying)
                            
                            Button(action: player.stop) {
                                Image(systemName: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            
                            Button(action: player.restart) {
                                Image(systemName: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // Speed control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Playback Speed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(String(format: "%.1f", player.playbackSpeed))x")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Picker("Speed", selection: $player.playbackSpeed) {
                                Text("0.5x").tag(0.5)
                                Text("1x").tag(1.0)
                                Text("2x").tag(2.0)
                                Text("5x").tag(5.0)
                                Text("10x").tag(10.0)
                                Text("20x").tag(20.0)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Progress bar
                        VStack(spacing: 4) {
                            ProgressView(value: player.getProgress())
                            
                            HStack {
                                Text("Point \(player.currentTrackPoint)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(player.totalTrackPoints) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Current state
                    Section("Current Flight State") {
                        // Speed with visual indicator
                        VStack(spacing: 8) {
                            HStack {
                                Label("Speed", systemImage: "speedometer")
                                Spacer()
                                Text("\(Int(player.currentSpeed)) kts")
                                    .fontWeight(.semibold)
                                    .foregroundColor(speedColor(player.currentSpeed))
                            }
                            
                            // Speed gauge
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    // Takeoff threshold line
                                    Rectangle()
                                        .fill(Color.orange.opacity(0.3))
                                        .frame(width: 2, height: 12)
                                        .offset(x: geometry.size.width * 0.53) // 80kts out of ~150kts
                                    
                                    // Landing threshold line
                                    Rectangle()
                                        .fill(Color.green.opacity(0.3))
                                        .frame(width: 2, height: 12)
                                        .offset(x: geometry.size.width * 0.4) // 60kts
                                    
                                    // Current speed indicator
                                    Rectangle()
                                        .fill(speedColor(player.currentSpeed))
                                        .frame(width: geometry.size.width * min(player.currentSpeed / 150, 1.0), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 12)
                            
                            HStack {
                                Text("0")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("60")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("80")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("150 kts")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Label("Altitude", systemImage: "arrow.up.right")
                            Spacer()
                            Text("\(Int(player.currentAltitude)) ft")
                                .fontWeight(.semibold)
                        }
                        
                        if let coord = player.currentCoordinate {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Position")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Lat: \(String(format: "%.6f", coord.latitude))")
                                    .font(.caption)
                                    .monospaced()
                                Text("Lon: \(String(format: "%.6f", coord.longitude))")
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                        
                        HStack {
                            Label("Current Airport", systemImage: "building.2.fill")
                            Spacer()
                            Text(locationManager.currentAirport ?? "None")
                                .fontWeight(.semibold)
                                .foregroundColor(locationManager.currentAirport != nil ? .blue : .secondary)
                        }
                    }
                }
                
                // Instructions
                Section {
                    Button {
                        showingInstructions.toggle()
                    } label: {
                        Label("Testing Instructions", systemImage: "questionmark.circle")
                    }
                } footer: {
                    if showingInstructions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Test Flight Times:")
                                .font(.headline)
                            
                            Group {
                                Text("1. Create a Flight")
                                    .fontWeight(.semibold)
                                Text("   • Go to the main flight tracking view")
                                Text("   • Create a new flight (KYIP → KDTW works best)")
                                
                                Text("2. Enable Test Mode")
                                    .fontWeight(.semibold)
                                Text("   • Toggle 'Enable GPX Testing' above")
                                
                                Text("3. Load Test Flight")
                                    .fontWeight(.semibold)
                                Text("   • Tap 'Load YIP_DTW'")
                                Text("   • Should see track points loaded")
                                
                                Text("4. Adjust Speed")
                                    .fontWeight(.semibold)
                                Text("   • Set to 10x or 20x for quick testing")
                                Text("   • Real-time (1x) takes ~20 minutes")
                                
                                Text("5. Start Playback")
                                    .fontWeight(.semibold)
                                Text("   • Press the Play button")
                                Text("   • Watch speed and altitude change")
                                
                                Text("6. Observe Auto-Times")
                                    .fontWeight(.semibold)
                                Text("   • OFF time when speed ≥ 80 kts")
                                Text("   • ON time when speed < 60 kts after fast roll")
                            }
                            .font(.caption)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Expected Behavior:")
                                    .font(.headline)
                                
                                Label("At ~80 kts: OFF time auto-captured", systemImage: "airplane.departure")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Label("At ~55 kts: ON time auto-captured", systemImage: "airplane.arrival")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Label("Check Console: Look for trigger logs", systemImage: "terminal")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("GPX Testing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInstructions.toggle()
                    } label: {
                        Image(systemName: showingInstructions ? "info.circle.fill" : "info.circle")
                    }
                }
            }
        }
        .onAppear {
            testMode.configure(with: locationManager, speedMonitor: speedMonitor)
            
            // Listen for leg completion check requests
            NotificationCenter.default.addObserver(
                forName: Notification.Name("checkLegCompletion"),
                object: nil,
                queue: .main
            ) { _ in
                print("📢 Received checkLegCompletion notification")
                // The LogBookStore should handle this automatically
                // But we can log it for debugging
            }
            
            // Listen for takeoff events
            NotificationCenter.default.addObserver(
                forName: Notification.Name("takeoffRollStarted"),
                object: nil,
                queue: .main
            ) { notification in
                takeoffDetected = true
                if let speedKt = notification.userInfo?["speedKt"] as? Double {
                    lastEventMessage = "🛫 Takeoff at \(Int(speedKt)) kts"
                }
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            // Listen for landing events
            NotificationCenter.default.addObserver(
                forName: Notification.Name("landingRollDecel"),
                object: nil,
                queue: .main
            ) { notification in
                landingDetected = true
                if let speedKt = notification.userInfo?["speedKt"] as? Double {
                    lastEventMessage = "🛬 Landing at \(Int(speedKt)) kts"
                }
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            // Listen for auto-time triggers (from GPSSpeedMonitor)
            NotificationCenter.default.addObserver(
                forName: .autoTimeTriggered,
                object: nil,
                queue: .main
            ) { notification in
                guard let timeType = notification.userInfo?["timeType"] as? String,
                      let speedKts = notification.userInfo?["speedKts"] as? Double else { return }
                
                if timeType == "OFF" {
                    takeoffDetected = true
                    lastEventMessage = "🛫 OFF Time at \(Int(speedKts)) kts"
                } else if timeType == "ON" {
                    landingDetected = true
                    lastEventMessage = "🛬 ON Time at \(Int(speedKts)) kts"
                    
                    // AUTO-ADVANCE TO NEXT LEG after ON time is captured
                    // This fixes the "standby" issue after landing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        print("🔄 Auto-checking leg completion after ON time")
                        self.checkAndAdvanceToNextLeg()
                    }
                }
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
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
    
    // Helper to clear flight times for testing
    private func clearFlightTimes() {
        // Need access to store - we'll post a notification
        NotificationCenter.default.post(
            name: Notification.Name("clearActiveFlightTimes"),
            object: nil
        )
        
        // Reset detection states
        takeoffDetected = false
        landingDetected = false
        lastEventMessage = "Times cleared - ready for test"
        
        print("🗑️ Cleared all flight times for active trip")
    }
    
    // Helper to auto-advance to next leg when current leg is complete
    private func checkAndAdvanceToNextLeg() {
        // Post notification to check if current leg is complete and advance
        NotificationCenter.default.post(
            name: Notification.Name("checkLegCompletion"),
            object: nil
        )
        print("🔄 Checking leg completion and advancing if needed")
    }
}

// MARK: - Preview
struct GPXTestingView_Previews: PreviewProvider {
    static var previews: some View {
        GPXTestingView()
            .environmentObject(PilotLocationManager())
    }
}

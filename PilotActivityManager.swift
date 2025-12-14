//
//  PilotActivityManager.swift
//  ProPilot
//
//  Updated version with real-time duty timer updates for Dynamic Island + Watch/Widget sync
//

import Foundation
import SwiftUI
import ActivityKit
import UserNotifications
import OSLog
#if os(iOS)
import WidgetKit
#endif

@MainActor
class PilotActivityManager: ObservableObject {
    static let shared = PilotActivityManager()
    
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.propilot.app", category: "LiveActivity")
    
    // MARK: - Published Properties
    @Published var isActivityActive: Bool = false
    @Published var currentPhase: String = "Off Duty"
    @Published var dutyStartTime: Date? = nil
    @Published var activityStartTime: Date? = nil
    @Published var lastUpdateTime: Date? = nil
    
    // MARK: - Private Properties
    private var currentActivity: Activity<PilotDutyAttributes>? = nil
    private var updateTimer: Timer? = nil // KEY: This timer keeps the Dynamic Island updating
    
    init() {
        setupNotificationObservers()
        restoreExistingActivity()
    }
    
    // MARK: - Permission Management
    
    func requestActivityPermission() async -> Bool {
        let authInfo = ActivityAuthorizationInfo()
        let isEnabled = authInfo.areActivitiesEnabled
        
        print("🏝️ Live Activities Authorization Status: \(isEnabled)")
        print("🏝️ Frequent Push Enabled: \(authInfo.areActivitiesEnabled)")
        
        if !isEnabled {
            print("❌ Live Activities are disabled in Settings")
            print("📱 User needs to enable: Settings > [Your App] > Live Activities")
            
            // Show user alert about enabling Live Activities
            showLiveActivityAlert()  // Removed 'await'
            return false
        }
        
        return true
    }
    
    @MainActor
    private func showLiveActivityAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Enable Live Activities",
            message: "To see flight info in Dynamic Island, enable Live Activities in Settings > ProPilot > Live Activities",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Activity Lifecycle
        
        func startActivity(tripNumber: String, aircraft: String, departure: String, arrival: String,
                          currentAirport: String, currentAirportName: String, dutyStartTime: Date) {
            
            Task {
                // Check permission first
                let hasPermission = await requestActivityPermission()
                guard hasPermission else {
                    print("❌ Cannot start Live Activity - permission denied")
                    return
                }
                
                // END any existing Live Activity first
                if let existingActivity = currentActivity {
                    await existingActivity.end(nil, dismissalPolicy: .immediate)
                    print("🧹 Ended existing Live Activity before starting new one")
                    self.currentActivity = nil
                    self.isActivityActive = false
                }
                
                // Calculate initial elapsed time if duty started before activity
                let initialElapsed = Int(Date().timeIntervalSince(dutyStartTime) / 60)
                
                let attributes = PilotDutyAttributes(
                    tripNumber: tripNumber,
                    aircraftType: aircraft,
                    departure: departure,
                    arrival: arrival,
                    dutyStartTime: dutyStartTime
                )
                
                let contentState = PilotDutyAttributes.ContentState(
                    flightPhase: .preTrip,
                    currentAirport: currentAirport,
                    currentAirportName: currentAirportName,
                    dutyElapsedMinutes: initialElapsed, // KEY: Start with correct elapsed time
                    blockOutTime: nil,
                    blockOffTime: nil,
                    blockOnTime: nil,
                    blockInTime: nil,
                    nextLegDeparture: nil,
                    nextLegArrival: nil
                )
                
                let content = ActivityContent(state: contentState, staleDate: nil)
                
                do {
                    let activity = try Activity.request(attributes: attributes, content: content)
                    self.currentActivity = activity
                    self.isActivityActive = true
                    self.currentPhase = "Pre-Trip"
                    self.dutyStartTime = dutyStartTime
                    self.activityStartTime = Date()
                    self.lastUpdateTime = Date() // Track when activity started
                    
                    // KEY: Start the timer to update duty elapsed time every minute
                    self.startUpdateTimer()
                    
                    // NEW: Update shared data for complications and widgets
                    self.updateSharedDataForComplications()
                    
                    print("✅ Started Live Activity: \(activity.id)")
                    print("🗓️ Trip: \(tripNumber), Aircraft: \(aircraft)")
                    print("🗓️ Route: \(departure) → \(arrival)")
                    print("⏰ Started update timer for real-time duty updates")
                    print("🏝️ ⚠️  TO SEE DYNAMIC ISLAND:")
                    print("🏝️    1. Press Home button (go to home screen)")
                    print("🏝️    2. Look at the notch/pill area at the top")
                    print("🏝️    3. Long press to expand")
                    print("🏝️ 📱 Device must be iPhone 14 Pro or newer Pro model")
                    
                } catch {
                    print("❌ Failed to start Live Activity: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    
                    // More detailed error info
                    if let activityError = error as? ActivityAuthorizationError {
                        print("❌ Authorization Error: \(activityError)")
                    }
                }
            }
        }
    
    // MARK: - Debug Methods

    func logActiveActivities() {
        print("🏝️ ========== ACTIVE ACTIVITIES ==========")
        print("🏝️ isActivityActive: \(isActivityActive)")
        print("🏝️ currentPhase: \(currentPhase)")
        print("🏝️ dutyStartTime: \(dutyStartTime?.description ?? "nil")")
        
        #if targetEnvironment(simulator)
        print("🏝️ ⚠️  Running on SIMULATOR")
        print("🏝️    Current Device: \(UIDevice.current.name)")
        print("🏝️    ⚠️  Dynamic Island ONLY works on iPhone 14 Pro or newer Pro models")
        #else
        print("🏝️ ✅ Running on PHYSICAL DEVICE")
        print("🏝️    Device: \(UIDevice.current.name)")
        #endif
        
        if let activity = currentActivity {
            print("🏝️ Activity ID: \(activity.id)")
            print("🏝️ Activity State: \(activity.activityState)")
            print("🏝️ Trip: \(activity.attributes.tripNumber)")
            print("🏝️ Aircraft: \(activity.attributes.aircraftType)")
            print("🏝️ Route: \(activity.attributes.departure) → \(activity.attributes.arrival)")
            print("🏝️ Content State Phase: \(activity.content.state.flightPhase.rawValue)")
            print("🏝️ Content State Duty: \(activity.content.state.dutyTimeFormatted)")
            print("🏝️")
            print("🏝️ 👀 TO VIEW:")
            print("🏝️    1. Press Home button (exit app)")
            print("🏝️    2. Look at notch/pill at top of screen")
            print("🏝️    3. Long press to expand Dynamic Island")
        } else {
            print("🏝️ No current activity")
        }
        
        // List all activities from ActivityKit
        print("🏝️")
        print("🏝️ All ActivityKit instances:")
        for activity in Activity<PilotDutyAttributes>.activities {
            print("🏝️ Found activity: \(activity.id) - State: \(activity.activityState)")
        }
        
        print("🏝️ ==========================================")
    }
    func updateActivity(phase: String? = nil, nextEvent: String? = nil, estimatedTime: String? = nil) {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }
        
        Task {
            var contentState = activity.content.state
            
            // Update flight phase if provided
            if let phaseString = phase {
                if let flightPhase = FlightPhase.allCases.first(where: { $0.rawValue == phaseString }) {
                    contentState = contentState.withUpdatedFlightPhase(flightPhase)
                    self.currentPhase = phaseString
                    print("🗓️ Updated phase to: \(phaseString)")
                }
            }
            
            // Update duty elapsed time (this is crucial for real-time updates)
            if let startTime = dutyStartTime ?? activityStartTime {
                contentState = contentState.withUpdatedDutyTime(from: startTime)
            }
            
            let staleDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())
            
            await activity.update(
                ActivityContent(state: contentState, staleDate: staleDate)
            )
            
            // NEW: Update shared data whenever activity updates
            self.updateSharedDataForComplications()
            
            print("🗓️ Updated Live Activity - Phase: \(contentState.flightPhase.rawValue), Duty: \(contentState.dutyTimeFormatted)")
        }
    }
    
    // NEW: Sync Live Activity with current trip state
    func syncWithTrip(_ trip: Trip) {
        guard let activity = currentActivity,
              let currentLeg = trip.legs.last else {
            print("⚠️ Cannot sync - no active activity or current leg")
            return
        }
        
        Task {
            // Get current times from the trip leg
            let outTime = currentLeg.outTime.isEmpty ? nil : currentLeg.outTime
            let offTime = currentLeg.offTime.isEmpty ? nil : currentLeg.offTime
            let onTime = currentLeg.onTime.isEmpty ? nil : currentLeg.onTime
            let inTime = currentLeg.inTime.isEmpty ? nil : currentLeg.inTime
            
            // Update with flight times - this will auto-calculate the correct phase
            var contentState = activity.content.state.withUpdatedFlightTimes(
                out: outTime,
                off: offTime,
                on: onTime,
                inTime: inTime
            )
            
            // Update duty elapsed time
            if let startTime = dutyStartTime ?? activityStartTime {
                contentState = contentState.withUpdatedDutyTime(from: startTime)
            }
            
            // Update next leg info if available
            if trip.legs.count > 1 {
                let currentLegIndex = trip.legs.firstIndex { leg in
                    leg.inTime.isEmpty // Find the incomplete leg
                } ?? trip.legs.count - 1
                
                if currentLegIndex < trip.legs.count - 1 {
                    let nextLeg = trip.legs[currentLegIndex + 1]
                    contentState.nextLegDeparture = nextLeg.departure
                    contentState.nextLegArrival = nextLeg.arrival
                }
            }
            
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
            
            self.currentPhase = contentState.flightPhase.rawValue
            
            // NEW: Update shared data with flight times
            self.updateSharedDataForComplications(
                outTime: outTime,
                offTime: offTime,
                onTime: onTime,
                inTime: inTime
            )
            
            print("🔄 Synced Live Activity with trip: \(trip.tripNumber)")
            print("🔄 Current phase: \(contentState.flightPhase.rawValue)")
            print("🔄 Flight times - OUT: \(outTime ?? "nil"), OFF: \(offTime ?? "nil"), ON: \(onTime ?? "nil"), IN: \(inTime ?? "nil")")
        }
    }
    
    func updateActivityWithFlightTimes(out: String? = nil, off: String? = nil,
                                     on: String? = nil, inTime: String? = nil) {
        guard let activity = currentActivity else { return }
        
        Task {
            let contentState = activity.content.state.withUpdatedFlightTimes(
                out: out, off: off, on: on, inTime: inTime
            )
            
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
            
            // NEW: Update shared data with flight times
            self.updateSharedDataForComplications(
                outTime: out,
                offTime: off,
                onTime: on,
                inTime: inTime
            )
            
            print("🗓️ Updated flight times - OUT: \(out ?? "nil"), OFF: \(off ?? "nil"), ON: \(on ?? "nil"), IN: \(inTime ?? "nil")")
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            let finalState = activity.content.state.withUpdatedFlightPhase(.complete)
            
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .default
            )
            
            self.currentActivity = nil
            self.isActivityActive = false
            self.currentPhase = "Off Duty"
            self.dutyStartTime = nil
            self.activityStartTime = nil
            self.lastUpdateTime = nil
            
            // KEY: Stop the update timer when activity ends
            self.stopUpdateTimer()
            
            // NEW: Clear shared data when ending
            self.updateSharedDataForComplications()
            
            print("✅ Ended Live Activity")
        }
    }
    
    // MARK: - NEW: Shared Data Management for Complications & Widgets
    
    private func updateSharedDataForComplications(
        outTime: String? = nil,
        offTime: String? = nil,
        onTime: String? = nil,
        inTime: String? = nil
    ) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("⚠️ Failed to access shared UserDefaults")
            return
        }
        
        let isOnDuty = isActivityActive
        let dutyTime = getDutyElapsedTime()
        
        // Basic duty status
        sharedDefaults.set(isOnDuty, forKey: "isOnDuty")
        sharedDefaults.set(dutyTime, forKey: "dutyTimeRemaining")
        
        // Trip and aircraft data
        if let activity = currentActivity {
            sharedDefaults.set(activity.attributes.tripNumber, forKey: "currentTripNumber")
            sharedDefaults.set(activity.attributes.aircraftType, forKey: "currentAircraft")
            sharedDefaults.set(currentPhase, forKey: "flightStatus")
            
            // Determine next action based on current phase
            let nextAction = getNextActionFromPhase(currentPhase)
            sharedDefaults.set(nextAction, forKey: "nextFlightAction")
            
            print("📊 Updating complications data:")
            print("📊 Trip: \(activity.attributes.tripNumber), Aircraft: \(activity.attributes.aircraftType)")
            print("📊 Phase: \(currentPhase), Next: \(nextAction)")
        } else {
            // Clear data when no activity
            sharedDefaults.set("------", forKey: "currentTripNumber")
            sharedDefaults.set("----", forKey: "currentAircraft")
            sharedDefaults.set("OFF DUTY", forKey: "flightStatus")
            sharedDefaults.set("OUT", forKey: "nextFlightAction")
        }
        
        // Flight times with proper formatting
        if let outTime = outTime {
            let formattedOut = formatTimeForComplications(outTime)
            sharedDefaults.set(formattedOut, forKey: "currentOutTime")
            print("📊 OUT: \(formattedOut)")
        }
        if let offTime = offTime {
            let formattedOff = formatTimeForComplications(offTime)
            sharedDefaults.set(formattedOff, forKey: "currentOffTime")
            print("📊 OFF: \(formattedOff)")
        }
        if let onTime = onTime {
            let formattedOn = formatTimeForComplications(onTime)
            sharedDefaults.set(formattedOn, forKey: "currentOnTime")
            print("📊 ON: \(formattedOn)")
        }
        if let inTime = inTime {
            let formattedIn = formatTimeForComplications(inTime)
            sharedDefaults.set(formattedIn, forKey: "currentInTime")
            print("📊 IN: \(formattedIn)")
        }
        
        sharedDefaults.synchronize()
        
        #if os(iOS)
        // Update home screen widget
        WidgetCenter.shared.reloadTimelines(ofKind: "ProPilotHomeWidget")
        #endif
        
        print("📊 Updated shared data for complications - OnDuty: \(isOnDuty), Duty: \(dutyTime)")
    }
    
    private func formatTimeForComplications(_ timeString: String) -> String {
        // Convert "0830" to "08:30Z" format for complications
        guard timeString.count == 4 else { return timeString }
        
        let hour = String(timeString.prefix(2))
        let minute = String(timeString.suffix(2))
        return "\(hour):\(minute)Z"
    }
    
    private func getNextActionFromPhase(_ phase: String) -> String {
        switch phase.lowercased() {
        case "pre-trip", "pre-flight", "boarding":
            return "OUT"
        case "taxi", "taxi out":
            return "OFF"
        case "takeoff", "enroute", "en route":
            return "ON"
        case "approach", "landing", "taxi in":
            return "IN"
        case "complete", "off duty":
            return "Complete"
        default:
            return "OUT"
        }
    }
    
    // MARK: - KEY: Timer Management for Real-Time Updates
    
    private func startUpdateTimer() {
        stopUpdateTimer() // Ensure any existing timer is stopped
        
        // Update every 60 seconds to keep duty time current
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDutyTime()
            }
        }
        
        print("⏰ Started duty timer update (every 60 seconds)")
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏰ Stopped duty timer updates")
    }
    
    private func updateDutyTime() {
        guard let activity = currentActivity,
              let startTime = dutyStartTime ?? activityStartTime else {
            print("⚠️ Cannot update duty time - missing activity or start time")
            return
        }
        
        Task {
            let contentState = activity.content.state.withUpdatedDutyTime(from: startTime)
            
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
            
            // NEW: Update shared data every minute
            self.updateSharedDataForComplications()
            
            print("⏰ Updated duty time: \(contentState.dutyTimeFormatted)")
        }
    }
    
    // MARK: - Activity Restoration
    
    private func restoreExistingActivity() {
        Task {
            for activity in Activity<PilotDutyAttributes>.activities {
                if activity.activityState == .active {
                    self.currentActivity = activity
                    self.isActivityActive = true
                    self.dutyStartTime = activity.attributes.dutyStartTime
                    self.activityStartTime = activity.attributes.dutyStartTime
                    self.currentPhase = activity.content.state.flightPhase.rawValue
                    
                    // KEY: Restart the timer for existing activities
                    self.startUpdateTimer()
                    
                    // NEW: Restore shared data
                    self.updateSharedDataForComplications()
                    
                    print("🔄 Restored existing Live Activity: \(activity.id)")
                    break
                }
            }
        }
    }
    
    // MARK: - UPDATED: Notification Observers with Speed Triggers
    
    private func setupNotificationObservers() {
        // Airport arrival (existing)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAirportArrival),
            name: .arrivedAtAirport,
            object: nil
        )
        
        // NEW: Airport departure
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAirportDeparture),
            name: Notification.Name("departedAirport"),
            object: nil
        )

        // NEW: Takeoff roll detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTakeoffRoll),
            name: Notification.Name("takeoffRollStarted"),
            object: nil
        )

        // NEW: Landing roll detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLandingRoll),
            name: Notification.Name("landingRollDecel"),
            object: nil
        )
        
        print("🛩️ PilotActivityManager: Set up all notification observers")
    }
    
    @objc private func handleAirportArrival(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let airport = userInfo["airport"] as? String,
              let _ = userInfo["name"] as? String else { return }
        
        // Auto-update activity if already running
        if isActivityActive {
            updateActivity(phase: "Pre-Flight")
            print("🗓️ Updated activity for airport arrival: \(airport)")
            
            // ✅ SUPPRESS notification when there's an active trip/duty
            // User is already flying - don't spam them with "start duty" notifications
            print("🗓️ Suppressing arrival notification - active duty in progress")
            return
        }
        
        // Only show "start duty" notification if NOT already on duty
        let content = UNMutableNotificationContent()
        content.title = "Arrived at \(airport)"
        content.body = "Start duty timer?"
        content.sound = .default
        content.categoryIdentifier = "AIRPORT_ARRIVAL"

        let req = UNNotificationRequest(identifier: "callOps.\(airport).\(UUID().uuidString)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
        
        print("🗓️ Sent arrival notification for \(airport) - no active duty")
    }
    
    @objc private func handleAirportDeparture(_ notification: Notification) {
        guard let airport = notification.userInfo?["airport"] as? String else { return }
        print("🗓️ Departed airport: \(airport)")
        updateActivity(phase: "Taxi") // or "Out / Taxi"
    }

    @objc private func handleTakeoffRoll(_ notification: Notification) {
        let speed = (notification.userInfo?["speedKt"] as? Double) ?? 0
        print("🗓️ Takeoff roll detected (~\(Int(speed)) kt) – updating phase")
        updateActivity(phase: "Takeoff")
    }

    @objc private func handleLandingRoll(_ notification: Notification) {
        let speed = (notification.userInfo?["speedKt"] as? Double) ?? 0
        print("🗓️ Landing roll decel (<60 kt, \(Int(speed)) kt) – updating phase")
        updateActivity(phase: "Landing")
    }
    
    // MARK: - Utility Methods
    
    func getDutyElapsedTime() -> String {
        guard let startTime = dutyStartTime ?? activityStartTime else {
            return "0:00"
        }
        
        let elapsed = Int(Date().timeIntervalSince(startTime) / 60)
        let hours = elapsed / 60
        let minutes = elapsed % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    func isDutyActive() -> Bool {
        return dutyStartTime != nil && isActivityActive
    }
    
    // MARK: - Debug Methods
    
    func testActivityWithAlert() {
        startActivity(
            tripNumber: "TEST123",
            aircraft: "B737",
            departure: "KORD",
            arrival: "KLAX",
            currentAirport: "KORD",
            currentAirportName: "Chicago O'Hare",
            dutyStartTime: Date()
        )
        
        // Log status immediately
        logActiveActivities()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                
                let deviceModel = UIDevice.current.name
                let hasDynamicIsland = deviceModel.contains("iPhone 14 Pro") ||
                                      deviceModel.contains("iPhone 15 Pro") ||
                                      deviceModel.contains("iPhone 16 Pro")
                
                var message = "✅ Live Activity Started!\n\n"
                
                #if targetEnvironment(simulator)
                message += "📱 SIMULATOR: \(deviceModel)\n\n"
                if hasDynamicIsland {
                    message += "✅ This simulator supports Dynamic Island!\n\n"
                } else {
                    message += "⚠️ This simulator does NOT have Dynamic Island.\n\nSelect iPhone 14 Pro or newer Pro model.\n\n"
                }
                #else
                message += "📱 DEVICE: \(deviceModel)\n\n"
                #endif
                
                message += "TO SEE IT:\n"
                message += "1. Tap OK below\n"
                message += "2. Swipe up to go home\n"
                if hasDynamicIsland {
                    message += "3. Look at the pill/notch area\n"
                    message += "4. Long press to expand\n\n"
                    message += "You should see your flight info!"
                } else {
                    message += "3. Look for banner at top of screen\n"
                    message += "4. Check Lock Screen for widget"
                }
                
                let alert = UIAlertController(
                    title: "🛩️ Live Activity Test",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK - Take Me Home!", style: .default) { _ in
                    // Automatically minimize the app after dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                    }
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                viewController.present(alert, animated: true)
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

//
//  DutyTimerManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/31/25.
//
//  ENHANCED: Integrates with PhoneWatchConnectivity for Watch sync

import SwiftUI
import UserNotifications
import Combine

/// Manages duty timer state, alarms, FAR 117 compliance warnings, and Watch synchronization
class DutyTimerManager: ObservableObject {
    static let shared = DutyTimerManager()
    
    // MARK: - Published State
    @Published var dutyStartTime: Date?
    @Published var isOnDuty: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var showingWarning: Bool = false
    @Published var warningMessage: String = ""
    
    // 🔥 NEW: Rest period tracking
    @Published var isInRest: Bool = false
    @Published var restStartTime: Date?
    
    // MARK: - Convenience computed property for compatibility
    var isDutyActive: Bool { isOnDuty }
    
    // MARK: - Alarm Thresholds (in seconds)
    // FAR Part 121 Cargo: 16 hour duty limit
    private let fourteenHourWarning: TimeInterval = 14 * 3600 // 14 hours (2 hours remaining)
    private let fifteenHourWarning: TimeInterval = 15 * 3600 // 15 hours (1 hour remaining)
    private let fifteenHalfHourWarning: TimeInterval = 15.5 * 3600 // 15.5 hours (30 min remaining)
    private let sixteenHourLimit: TimeInterval = 16 * 3600 // 16 hours - FAR 121 cargo limit
    
    // MARK: - State Tracking
    private var hasShownFourteenHourWarning = false
    private var hasShownFifteenHourWarning = false
    private var hasShownFifteenHalfHourWarning = false
    private var hasShownSixteenHourWarning = false
    
    // MARK: - Timer
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    private let dutyStartKey = "dutyTimerStartTime"
    private let isOnDutyKey = "isOnDuty"
    
    // MARK: - App Group UserDefaults
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.propilot.app")
    }
    
    private init() {
        loadState()
        setupNotifications()
        
        if isOnDuty {
            startTimer()
        }
    }
    
    // MARK: - Public Methods
    
    func startDuty() {
        let now = Date()
        dutyStartTime = now
        isOnDuty = true
        elapsedTime = 0
        resetWarningFlags()
        
        // 🔥 NEW: End rest period when duty starts
        isInRest = false
        restStartTime = nil
        
        saveState()
        startTimer()
        
        // Sync to Watch via PhoneWatchConnectivity
        syncToWatch()
        
        // Post notification for backward compatibility with other parts of app
        NotificationCenter.default.post(
            name: NSNotification.Name("DutyTimerStarted"),
            object: nil,
            userInfo: ["startTime": now]
        )
        
        // Update widget data
        updateWidgetData()
        
        print("✈️ DUTY TIMER: Started at \(now.formatted(date: .omitted, time: .shortened))")
        print("🔚 REST PERIOD: Ended")
    }
    
    func endDuty() {
        let endTime = Date()
        let duration = dutyStartTime != nil ? endTime.timeIntervalSince(dutyStartTime!) : 0
        
        dutyStartTime = nil
        isOnDuty = false
        elapsedTime = 0
        resetWarningFlags()
        
        // 🔥 NEW: Start rest period when duty ends
        isInRest = true
        restStartTime = endTime
        
        saveState()
        stopTimer()
        cancelAllNotifications()
        
        // 🔥 NEW: Post notification that rest period started
        NotificationCenter.default.post(
            name: NSNotification.Name("RestPeriodStarted"),
            object: nil,
            userInfo: ["restStartTime": endTime]
        )
        
        // Sync to Watch
        syncToWatch()
        
        // Post notification for backward compatibility
        NotificationCenter.default.post(
            name: NSNotification.Name("DutyTimerEnded"),
            object: nil,
            userInfo: [
                "endTime": endTime,
                "duration": duration
            ]
        )
        
        // Update widget data
        updateWidgetData()
        
        print("✈️ DUTY TIMER: Ended (Duration: \(formatDuration(duration)))")
        print("🛏️ REST PERIOD: Started at \(endTime.formatted(date: .omitted, time: .shortened))")
    }
    
    func toggleDuty() {
        if isOnDuty {
            endDuty()
        } else {
            startDuty()
        }
    }
    
    func formattedElapsedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var formattedDutyTime: String {
        return formattedElapsedTime()
    }
    
    func timeRemaining() -> TimeInterval {
        return max(0, sixteenHourLimit - elapsedTime)
    }
    
    func formattedTimeRemaining() -> String {
        let remaining = timeRemaining()
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    func dutyStatus() -> DutyStatus {
        if !isOnDuty {
            return .notOnDuty
        }
        
        if elapsedTime >= sixteenHourLimit {
            return .limitReached
        } else if elapsedTime >= fifteenHalfHourWarning {
            return .criticalWarning
        } else if elapsedTime >= fourteenHourWarning {
            return .warning
        } else {
            return .normal
        }
    }
    
    // MARK: - Trip Integration Methods
    
    /// Capture current duty time data for saving to a trip
    /// Returns tuple of (startTime, endTime, totalMinutes) or nil if no duty active
    func captureDutyTimeForTrip() -> (startTime: Date, endTime: Date, totalMinutes: Int)? {
        guard let start = dutyStartTime else {
            print("⚠️ DutyTimerManager: Cannot capture - no duty start time")
            return nil
        }
        
        let end = Date()
        let totalMinutes = Int(end.timeIntervalSince(start) / 60)
        
        print("📋 DutyTimerManager: Captured duty time")
        print("   Start: \(start.formatted(date: .abbreviated, time: .shortened))")
        print("   End: \(end.formatted(date: .abbreviated, time: .shortened))")
        print("   Duration: \(totalMinutes) minutes (\(String(format: "%.1f", Double(totalMinutes) / 60.0)) hours)")
        
        return (startTime: start, endTime: end, totalMinutes: totalMinutes)
    }
    
    /// Apply duty time data to a trip (should be called before saving the trip)
    /// Returns the updated trip with duty time data populated
    func applyDutyTimeToTrip(_ trip: Trip) -> Trip {
        guard let dutyData = captureDutyTimeForTrip() else {
            print("⚠️ DutyTimerManager: No active duty time to apply to trip")
            return trip
        }
        
        var updatedTrip = trip
        updatedTrip.dutyStartTime = dutyData.startTime
        updatedTrip.dutyEndTime = dutyData.endTime
        updatedTrip.dutyMinutes = dutyData.totalMinutes
        
        print("✅ DutyTimerManager: Applied duty time to Trip #\(trip.tripNumber)")
        
        return updatedTrip
    }
    
    /// Check if trip should automatically trigger duty timer start
    /// (e.g., when first leg becomes active or first OUT time is recorded)
    func shouldAutoStartDutyForTrip(_ trip: Trip) -> Bool {
        // Don't auto-start if already on duty
        guard !isOnDuty else { return false }
        
        // Check if trip is active and has any times recorded
        if trip.status == .active {
            // Check if any leg has started (has OUT or OFF time)
            let hasStartedLeg = trip.legs.contains { leg in
                !leg.outTime.isEmpty || !leg.offTime.isEmpty
            }
            
            if hasStartedLeg {
                print("🎯 DutyTimerManager: Trip #\(trip.tripNumber) should auto-start duty timer")
                return true
            }
        }
        
        return false
    }
    
    /// Auto-start duty timer for a trip if conditions are met
    func autoStartDutyIfNeeded(for trip: Trip) {
        if shouldAutoStartDutyForTrip(trip) {
            print("🚀 DutyTimerManager: Auto-starting duty for Trip #\(trip.tripNumber)")
            startDuty()
        }
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        // Update every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard let startTime = dutyStartTime else { return }
        
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Update widget data every minute
        if Int(elapsedTime) % 60 == 0 {
            updateWidgetData()
        }
        
        // Check for warnings
        checkWarnings()
    }
    
    private func checkWarnings() {
        // 14 hour warning (2 hours remaining)
        if elapsedTime >= fourteenHourWarning && !hasShownFourteenHourWarning {
            hasShownFourteenHourWarning = true
            showWarning(message: "⚠️ 14 Hours on Duty\n2 hours remaining until FAR 121 limit")
            scheduleLocalNotification(
                title: "Duty Time Warning",
                body: "You've been on duty for 14 hours. 2 hours remaining.",
                timeInterval: 0
            )
        }
        
        // 15 hour warning (1 hour remaining)
        if elapsedTime >= fifteenHourWarning && !hasShownFifteenHourWarning {
            hasShownFifteenHourWarning = true
            showWarning(message: "🚨 15 Hours on Duty\n1 hour remaining until FAR 121 limit")
            scheduleLocalNotification(
                title: "CRITICAL: Duty Time Warning",
                body: "Only 1 hour remaining before 16-hour limit!",
                timeInterval: 0
            )
        }
        
        // 15.5 hour warning (30 minutes remaining)
        if elapsedTime >= fifteenHalfHourWarning && !hasShownFifteenHalfHourWarning {
            hasShownFifteenHalfHourWarning = true
            showWarning(message: "🚨 15.5 Hours on Duty\n30 minutes remaining until FAR 121 limit")
            scheduleLocalNotification(
                title: "URGENT: Duty Time Warning",
                body: "Only 30 minutes remaining before 16-hour limit!",
                timeInterval: 0
            )
        }
        
        // 16 hour limit reached
        if elapsedTime >= sixteenHourLimit && !hasShownSixteenHourWarning {
            hasShownSixteenHourWarning = true
            showWarning(message: "🛑 16 Hour Limit Reached\nFAR 121 duty limit exceeded")
            scheduleLocalNotification(
                title: "🛑 DUTY LIMIT EXCEEDED",
                body: "You have exceeded the 16-hour FAR 121 duty limit!",
                timeInterval: 0
            )
        }
    }
    
    private func showWarning(message: String) {
        warningMessage = message
        showingWarning = true
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showingWarning = false
        }
    }
    
    private func resetWarningFlags() {
        hasShownFourteenHourWarning = false
        hasShownFifteenHourWarning = false
        hasShownFifteenHalfHourWarning = false
        hasShownSixteenHourWarning = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Watch Sync via PhoneWatchConnectivity
    
    private func syncToWatch() {
        // Use PhoneWatchConnectivity to send duty timer update
        PhoneWatchConnectivity.shared.sendDutyTimerUpdate(
            isRunning: isOnDuty,
            startTime: dutyStartTime
        )
        print("⌚️ DutyTimerManager: Synced to Watch via PhoneWatchConnectivity")
    }
    
    // MARK: - Widget Data Update
    
    private func updateWidgetData() {
        guard let sharedDefaults = sharedDefaults else {
            print("❌ DutyTimerManager: Failed to access App Group UserDefaults for widget update")
            return
        }
        
        sharedDefaults.set(isOnDuty, forKey: "isOnDuty")
        
        if isOnDuty {
            let elapsedMinutes = Int(elapsedTime / 60)
            let hours = elapsedMinutes / 60
            let minutes = elapsedMinutes % 60
            let formatted = String(format: "%d:%02d", hours, minutes)
            sharedDefaults.set(formatted, forKey: "dutyTimeRemaining")
        } else {
            sharedDefaults.removeObject(forKey: "dutyTimeRemaining")
        }
        
        sharedDefaults.synchronize()
        print("📱 DutyTimerManager: Updated widget data (isOnDuty: \(isOnDuty))")
    }
    
    // MARK: - Persistence (FIXED: Using App Group UserDefaults)
    
    private func saveState() {
        guard let sharedDefaults = sharedDefaults else {
            print("❌ DutyTimerManager: Failed to access App Group UserDefaults for save")
            return
        }
        
        if let startTime = dutyStartTime {
            sharedDefaults.set(startTime, forKey: dutyStartKey)
        } else {
            sharedDefaults.removeObject(forKey: dutyStartKey)
        }
        
        sharedDefaults.set(isOnDuty, forKey: isOnDutyKey)
        sharedDefaults.synchronize()
        
        print("💾 DutyTimerManager: State saved to App Group (isOnDuty: \(isOnDuty))")
    }
    
    private func loadState() {
        guard let sharedDefaults = sharedDefaults else {
            print("❌ DutyTimerManager: Failed to access App Group UserDefaults for load")
            return
        }
        
        if let savedStart = sharedDefaults.object(forKey: dutyStartKey) as? Date {
            dutyStartTime = savedStart
            isOnDuty = sharedDefaults.bool(forKey: isOnDutyKey)
            
            if isOnDuty {
                elapsedTime = Date().timeIntervalSince(savedStart)
                
                // Restore warning flags based on elapsed time
                if elapsedTime >= fourteenHourWarning {
                    hasShownFourteenHourWarning = true
                }
                if elapsedTime >= fifteenHourWarning {
                    hasShownFifteenHourWarning = true
                }
                if elapsedTime >= fifteenHalfHourWarning {
                    hasShownFifteenHalfHourWarning = true
                }
                if elapsedTime >= sixteenHourLimit {
                    hasShownSixteenHourWarning = true
                }
                
                print("📱 DutyTimerManager: Loaded saved duty state (elapsed: \(formattedElapsedTime()))")
                
                // Sync state to Watch on app launch
                syncToWatch()
            }
        } else {
            print("📱 DutyTimerManager: No saved duty state found")
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Duty Timer: Notification permission granted")
            } else if let error = error {
                print("❌ Duty Timer: Notification permission denied: \(error)")
            }
        }
    }
    
    private func scheduleLocalNotification(title: String, body: String, timeInterval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timeInterval), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Duty Status Enum
enum DutyStatus {
    case notOnDuty
    case normal
    case warning
    case criticalWarning
    case limitReached
    
    var color: Color {
        switch self {
        case .notOnDuty: return .gray
        case .normal: return .green
        case .warning: return .orange
        case .criticalWarning: return .red
        case .limitReached: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .notOnDuty: return "timer"
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .criticalWarning: return "exclamationmark.triangle.fill"
        case .limitReached: return "xmark.octagon.fill"
        }
    }
}

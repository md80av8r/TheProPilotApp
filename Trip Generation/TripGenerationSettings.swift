// TripGenerationSettings.swift - Smart Trip Generation from NOC Roster
import Foundation
import SwiftUI
import Combine

// MARK: - Trip Alarm Settings
struct TripAlarmSettings: Codable, Equatable {
    var enabled: Bool = true
    var reminderMinutesBefore: Int = 60       // Default: 1 hour before show time
    var alarmSound: AlarmSound = .chime
    var showCountdownOnWatch: Bool = true
    var repeatAlarm: Bool = false
    var snoozeMinutes: Int = 10
    
    // Preset options for reminder time
    static let reminderOptions: [Int] = [15, 30, 45, 60, 90, 120, 180, 240]
    
    var reminderDisplayText: String {
        if reminderMinutesBefore < 60 {
            return "\(reminderMinutesBefore) min before"
        } else {
            let hours = reminderMinutesBefore / 60
            let mins = reminderMinutesBefore % 60
            if mins == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "") before"
            } else {
                return "\(hours)h \(mins)m before"
            }
        }
    }
}

// MARK: - Trip Grouping Mode
enum TripGroupingMode: String, Codable, CaseIterable {
    case automatic = "Automatic"           // Auto-group legs using duty time logic
    case manual = "Manual"                 // User manually selects which legs to include
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .automatic:
            return "Automatically group legs into trips based on duty time rules (<12h gap)"
        case .manual:
            return "Let user review and select which legs to include in each trip"
        }
    }
    
    var icon: String {
        switch self {
        case .automatic:
            return "bolt.automatic"
        case .manual:
            return "hand.tap"
        }
    }
}

// MARK: - Leg Advancement Settings
enum LegAdvancementMode: String, Codable, CaseIterable {
    case autoPrompt = "Auto Prompt"        // Alert appears asking about next leg
    case manual = "Manual"                  // User taps "Next Leg" when ready
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .autoPrompt:
            return "Automatically prompt when a leg is completed"
        case .manual:
            return "Manually advance to next leg when ready"
        }
    }
}

// MARK: - Trip Detection Time Filter
enum TripDetectionTimeFilter: String, Codable, CaseIterable {
    case futureOnly = "Future Only"
    case todayAndFuture = "Today + Future"
    case allDetected = "All Detected"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .futureOnly:
            return "Only detect trips that start in the future"
        case .todayAndFuture:
            return "Detect trips from today onwards (includes trips ending today)"
        case .allDetected:
            return "Detect all trips from your roster, including past trips"
        }
    }
    
    /// Returns the cutoff date - trips ending before this date are filtered out
    var cutoffDate: Date {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .futureOnly:
            // Start of tomorrow
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        case .todayAndFuture:
            // 2 hours ago (tight grace period - if show time passed 2+ hours ago, it's stale)
            return calendar.date(byAdding: .hour, value: -2, to: now) ?? now
        case .allDetected:
            // Very old date - include everything
            return Date.distantPast
        }
    }
    
    /// Grace period in hours - trips with showTime older than this are considered stale
    var staleShowTimeHours: Int {
        switch self {
        case .futureOnly:
            return 0  // Must be in future
        case .todayAndFuture:
            return 2  // 2 hour grace period
        case .allDetected:
            return Int.max  // No limit
        }
    }
}

// MARK: - Trip Generation Settings Store
class TripGenerationSettings: ObservableObject {
    static let shared = TripGenerationSettings()
    
    // MARK: - Published Properties
    
    // Master toggle for roster-to-trip feature
    @Published var enableRosterTripGeneration: Bool = false {
        didSet { save() }
    }
    
    // 🆕 Trip grouping mode: automatic vs manual leg selection
    @Published var tripGroupingMode: TripGroupingMode = .automatic {
        didSet { save() }
    }
    
    // Trip creation behavior
    @Published var autoCreateTrips: Bool = false {
        didSet { save() }
    }
    
    @Published var requireConfirmation: Bool = true {
        didSet { save() }
    }
    
    @Published var includeDeadheads: Bool = true {
        didSet { save() }
    }
    
    // Time filter for trip detection
    @Published var tripDetectionTimeFilter: TripDetectionTimeFilter = .todayAndFuture {
        didSet { save() }
    }
    
    // Leg advancement
    @Published var legAdvancementMode: LegAdvancementMode = .autoPrompt {
        didSet { save() }
    }
    
    // Default alarm settings for new trips
    @Published var defaultAlarmSettings: TripAlarmSettings = TripAlarmSettings() {
        didSet { save() }
    }
    
    // Pre-populate options
    @Published var prePopulateFlightNumbers: Bool = true {
        didSet { save() }
    }
    
    @Published var prePopulateScheduledTimes: Bool = true {
        didSet { save() }
    }
    
    @Published var defaultAircraft: String = "" {
        didSet { save() }
    }
    
    // Notification settings
    @Published var notifyOnNewTripsDetected: Bool = true {
        didSet { save() }
    }
    
    @Published var notifyOnScheduleChanges: Bool = true {
        didSet { save() }
    }
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let settingsKey = "TripGenerationSettings"
    
    // MARK: - Initialization
    private init() {
        if let groupDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
            self.userDefaults = groupDefaults
        } else {
            self.userDefaults = .standard
        }
        load()
    }
    
    // MARK: - Persistence
    
    /// Flag to prevent logging during initial load
    private var isLoading = false
    
    private func save() {
        // Don't log during initial load
        guard !isLoading else { return }
        
        let settings = TripGenerationSettingsData(
            enableRosterTripGeneration: enableRosterTripGeneration,
            tripGroupingMode: tripGroupingMode,
            autoCreateTrips: autoCreateTrips,
            requireConfirmation: requireConfirmation,
            includeDeadheads: includeDeadheads,
            tripDetectionTimeFilter: tripDetectionTimeFilter,
            legAdvancementMode: legAdvancementMode,
            defaultAlarmSettings: defaultAlarmSettings,
            prePopulateFlightNumbers: prePopulateFlightNumbers,
            prePopulateScheduledTimes: prePopulateScheduledTimes,
            defaultAircraft: defaultAircraft,
            notifyOnNewTripsDetected: notifyOnNewTripsDetected,
            notifyOnScheduleChanges: notifyOnScheduleChanges
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            userDefaults.synchronize()
            // Only log on actual user changes, not initial load
        }
    }
    
    private func load() {
        isLoading = true  // Prevent save() from logging during load
        defer { isLoading = false }  // Re-enable logging after load
        
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(TripGenerationSettingsData.self, from: data) else {
            return
        }
        
        enableRosterTripGeneration = settings.enableRosterTripGeneration
        tripGroupingMode = settings.tripGroupingMode ?? .automatic
        autoCreateTrips = settings.autoCreateTrips
        requireConfirmation = settings.requireConfirmation
        includeDeadheads = settings.includeDeadheads
        tripDetectionTimeFilter = settings.tripDetectionTimeFilter ?? .todayAndFuture
        legAdvancementMode = settings.legAdvancementMode
        defaultAlarmSettings = settings.defaultAlarmSettings
        prePopulateFlightNumbers = settings.prePopulateFlightNumbers
        prePopulateScheduledTimes = settings.prePopulateScheduledTimes
        defaultAircraft = settings.defaultAircraft
        notifyOnNewTripsDetected = settings.notifyOnNewTripsDetected
        notifyOnScheduleChanges = settings.notifyOnScheduleChanges
    }
    
    // MARK: - Helper Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        enableRosterTripGeneration = false
        tripGroupingMode = .automatic
        autoCreateTrips = false
        requireConfirmation = true
        includeDeadheads = true
        tripDetectionTimeFilter = .todayAndFuture
        legAdvancementMode = .autoPrompt
        defaultAlarmSettings = TripAlarmSettings()
        prePopulateFlightNumbers = true
        prePopulateScheduledTimes = true
        defaultAircraft = ""
        notifyOnNewTripsDetected = true
        notifyOnScheduleChanges = true
        
        print("🔄 Trip generation settings reset to defaults")
    }
}

// MARK: - Settings Data Model (for Codable)
private struct TripGenerationSettingsData: Codable {
    let enableRosterTripGeneration: Bool
    let tripGroupingMode: TripGroupingMode?  // Optional for backwards compatibility
    let autoCreateTrips: Bool
    let requireConfirmation: Bool
    let includeDeadheads: Bool
    let tripDetectionTimeFilter: TripDetectionTimeFilter?  // Optional for backwards compatibility
    let legAdvancementMode: LegAdvancementMode
    let defaultAlarmSettings: TripAlarmSettings
    let prePopulateFlightNumbers: Bool
    let prePopulateScheduledTimes: Bool
    let defaultAircraft: String
    let notifyOnNewTripsDetected: Bool
    let notifyOnScheduleChanges: Bool
}

// MARK: - Pending Roster Trip (Detected but not yet created)
struct PendingRosterTrip: Identifiable, Codable {
    let id: UUID
    let detectedDate: Date
    let tripDate: Date
    let tripNumber: String
    var legs: [PendingLeg]  // Made mutable for manual leg addition
    var totalBlockMinutes: Int  // Made mutable
    let showTime: Date?           // First leg scheduled OUT time
    var rosterSourceIds: [String] // Made mutable - Links to original roster items
    
    var alarmSettings: TripAlarmSettings?
    var userAction: PendingTripAction = .pending
    
    var legCount: Int { legs.count }
    
    var routeSummary: String {
        guard !legs.isEmpty else { return "No Route" }
        let airports = legs.map { $0.departure } + [legs.last?.arrival ?? ""]
        return airports.filter { !$0.isEmpty }.joined(separator: " → ")
    }
    
    var formattedBlockTime: String {
        let hours = totalBlockMinutes / 60
        let mins = totalBlockMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    var formattedShowTime: String? {
        guard let showTime = showTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: showTime)
    }
    
    var timeUntilShowTime: TimeInterval? {
        guard let showTime = showTime else { return nil }
        return showTime.timeIntervalSince(Date())
    }
    
    var formattedTimeUntilShow: String? {
        guard let interval = timeUntilShowTime, interval > 0 else { return nil }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Pending Leg (Pre-trip leg data)
struct PendingLeg: Identifiable, Codable {
    let id: UUID
    let flightNumber: String
    let departure: String
    let arrival: String
    let scheduledOut: Date
    let scheduledIn: Date
    let isDeadhead: Bool
    let rosterSourceId: String
    
    var scheduledBlockMinutes: Int {
        Int(scheduledIn.timeIntervalSince(scheduledOut) / 60)
    }
    
    var formattedScheduledOut: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: scheduledOut)
    }
    
    var formattedScheduledIn: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: scheduledIn)
    }
}

// MARK: - Pending Trip Action
enum PendingTripAction: String, Codable {
    case pending = "Pending"
    case approved = "Approved"
    case dismissed = "Dismissed"
    case remindLater = "Remind Later"
}

// MARK: - Notification Names for Trip Generation
extension Notification.Name {
    static let newRosterTripsDetected = Notification.Name("newRosterTripsDetected")
    static let rosterTripCreated = Notification.Name("rosterTripCreated")
    static let legCompletedPromptNext = Notification.Name("legCompletedPromptNext")
    static let scheduleVarianceAlert = Notification.Name("scheduleVarianceAlert")
}

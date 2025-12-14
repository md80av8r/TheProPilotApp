
// TripGenerationSettings.swift - Smart Trip Generation from NOC Roster
import Foundation
import SwiftUI
import Combine

// MARK: - Alarm Sound Options
enum AlarmSound: String, Codable, CaseIterable {
    case chime = "Chime"
    case bell = "Bell"
    case radar = "Radar"
    case alert = "Alert"
    case horn = "Horn"
    case classic = "Classic"
    case digital = "Digital"
    case gentle = "Gentle"
    case urgent = "Urgent"
    case silent = "Silent"
    
    var displayName: String { rawValue }
    
    var systemSoundName: String {
        switch self {
        case .chime: return "chime"
        case .bell: return "bell"
        case .radar: return "radar"
        case .alert: return "alert"
        case .horn: return "horn"
        case .classic: return "classic"
        case .digital: return "digital"
        case .gentle: return "gentle"
        case .urgent: return "urgent"
        case .silent: return ""
        }
    }
    
    var symbolName: String {
        switch self {
        case .chime: return "bell"
        case .bell: return "bell.fill"
        case .radar: return "dot.radiowaves.left.and.right"
        case .alert: return "exclamationmark.triangle"
        case .horn: return "speaker.wave.3"
        case .classic: return "alarm"
        case .digital: return "clock.badge.checkmark"
        case .gentle: return "leaf"
        case .urgent: return "exclamationmark.2"
        case .silent: return "speaker.slash"
        }
    }
}

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

// MARK: - Trip Generation Settings Store
class TripGenerationSettings: ObservableObject {
    static let shared = TripGenerationSettings()
    
    // MARK: - Published Properties
    
    // Master toggle for roster-to-trip feature
    @Published var enableRosterTripGeneration: Bool = false {
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
    private func save() {
        let settings = TripGenerationSettingsData(
            enableRosterTripGeneration: enableRosterTripGeneration,
            autoCreateTrips: autoCreateTrips,
            requireConfirmation: requireConfirmation,
            includeDeadheads: includeDeadheads,
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
            print("✅ Trip generation settings saved")
        }
    }
    
    private func load() {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(TripGenerationSettingsData.self, from: data) else {
            print("📋 Using default trip generation settings")
            return
        }
        
        enableRosterTripGeneration = settings.enableRosterTripGeneration
        autoCreateTrips = settings.autoCreateTrips
        requireConfirmation = settings.requireConfirmation
        includeDeadheads = settings.includeDeadheads
        legAdvancementMode = settings.legAdvancementMode
        defaultAlarmSettings = settings.defaultAlarmSettings
        prePopulateFlightNumbers = settings.prePopulateFlightNumbers
        prePopulateScheduledTimes = settings.prePopulateScheduledTimes
        defaultAircraft = settings.defaultAircraft
        notifyOnNewTripsDetected = settings.notifyOnNewTripsDetected
        notifyOnScheduleChanges = settings.notifyOnScheduleChanges
        
        print("✅ Trip generation settings loaded")
    }
    
    // MARK: - Helper Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        enableRosterTripGeneration = false
        autoCreateTrips = false
        requireConfirmation = true
        includeDeadheads = true
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
    let autoCreateTrips: Bool
    let requireConfirmation: Bool
    let includeDeadheads: Bool
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
    let legs: [PendingLeg]
    let totalBlockMinutes: Int
    let showTime: Date?           // First leg scheduled OUT time
    let rosterSourceIds: [String] // Links to original roster items
    
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

// MARK: - Trip Extensions for Roster Integration
extension Trip {
    /// The currently active leg (first leg with .active status)
    var activeLeg: FlightLeg? {
        legs.first { $0.status == .active }
    }
    
    /// Index of the active leg
    var activeLegIndex: Int? {
        legs.firstIndex { $0.status == .active }
    }
    
    /// The next standby leg waiting to be activated
    var nextStandbyLeg: FlightLeg? {
        legs.first { $0.status == .standby }
    }
    
    /// Index of the next standby leg
    var nextStandbyLegIndex: Int? {
        legs.firstIndex { $0.status == .standby }
    }
    
    /// Whether there are more legs queued up
    var hasUpcomingLegs: Bool {
        legs.contains { $0.status == .standby }
    }
    
    /// Count of completed legs
    var completedLegCount: Int {
        legs.filter { $0.status == .completed }.count
    }
    
    /// Count of remaining legs (active + standby)
    var remainingLegCount: Int {
        legs.filter { $0.status == .active || $0.status == .standby }.count
    }
    
    /// Progress through the trip (0.0 to 1.0)
    var legProgress: Double {
        guard !legs.isEmpty else { return 0 }
        return Double(completedLegCount) / Double(legs.count)
    }
    
    /// Overall schedule variance for the trip
    var overallScheduleVariance: Int? {
        // Sum up all completed leg variances
        let completedLegs = legs.filter { $0.status == .completed }
        guard !completedLegs.isEmpty else { return nil }
        
        let totalVariance = completedLegs.compactMap { $0.inTimeVarianceMinutes }.reduce(0, +)
        return totalVariance
    }
    
    /// Human-readable overall schedule status
    var overallScheduleStatus: String {
        guard let variance = overallScheduleVariance else { return "No Data" }
        
        if abs(variance) <= 5 {
            return "On Schedule"
        } else if variance < 0 {
            return "\(abs(variance))m ahead"
        } else {
            return "\(variance)m behind"
        }
    }
    
    /// Check if trip was created from roster
    var isFromRoster: Bool {
        legs.contains { $0.rosterSourceId != nil }
    }
}

// MARK: - Notification Names for Trip Generation
extension Notification.Name {
    static let newRosterTripsDetected = Notification.Name("newRosterTripsDetected")
    static let rosterTripCreated = Notification.Name("rosterTripCreated")
    static let legCompletedPromptNext = Notification.Name("legCompletedPromptNext")
    static let scheduleVarianceAlert = Notification.Name("scheduleVarianceAlert")
}

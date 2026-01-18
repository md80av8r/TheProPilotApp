// DutyLimitSettings.swift
// Configurable flight time and duty limits for Part 91, 135, and 121 operations
// Created for TheProPilotApp

import SwiftUI
import Combine

// MARK: - Operation Type Enum
enum OperationType: String, CaseIterable, Codable {
    case part91 = "Part 91"
    case part135 = "Part 135"
    case part121 = "Part 121"
    case custom = "Custom"
    
    var description: String {
        switch self {
        case .part91:
            return "General Aviation - No regulatory duty limits"
        case .part135:
            return "Charter/On-Demand - FAR Part 135 limits"
        case .part121:
            return "Scheduled Airline - FAR Part 117/121 limits"
        case .custom:
            return "Custom limits based on your company ops specs"
        }
    }
    
    var icon: String {
        switch self {
        case .part91: return "airplane"
        case .part135: return "airplane.circle"
        case .part121: return "airplane.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Rolling Period Option
enum RollingPeriodOption: Int, CaseIterable, Codable {
    case days28 = 28
    case days30 = 30
    case days31 = 31
    
    var displayName: String {
        return "\(rawValue) Days"
    }
    
    var hours: Int {
        return rawValue * 24
    }
}

// MARK: - Flight Time Limit Model
struct FlightTimeLimit: Codable, Equatable {
    var enabled: Bool
    var hours: Double
    var periodDays: Int
    var periodHours: Int { periodDays * 24 }
    
    static let disabled = FlightTimeLimit(enabled: false, hours: 0, periodDays: 0)
}

// MARK: - FDP Limit Model
struct FDPLimit: Codable, Equatable {
    var enabled: Bool
    var hours: Double
    var periodDays: Int
    var periodHours: Int { periodDays * 24 }
    
    static let disabled = FDPLimit(enabled: false, hours: 0, periodDays: 0)
}

// MARK: - Rest Requirement Model
struct RestRequirement: Codable, Equatable {
    var enabled: Bool
    var minimumRestHours: Double
    var sleepOpportunityHours: Double
    var requiredInPeriodHours: Int  // e.g., 30 hours rest in 168 hours
    var periodHours: Int
    
    static let disabled = RestRequirement(enabled: false, minimumRestHours: 0, sleepOpportunityHours: 0, requiredInPeriodHours: 0, periodHours: 0)
}

// MARK: - Per-FDP Flight Time Limit
struct PerFDPFlightLimit: Codable, Equatable {
    var enabled: Bool
    var dayHours: Double      // Report time 0500-1959
    var nightHours: Double    // Report time 2000-0459
    var resetsAfterRest: Bool // Does the limit reset after legal rest?
    
    static let disabled = PerFDPFlightLimit(enabled: false, dayHours: 0, nightHours: 0, resetsAfterRest: false)
}

// MARK: - Complete Duty Limit Configuration
struct DutyLimitConfiguration: Codable, Equatable {
    // Operation Type
    var operationType: OperationType
    
    // Per-FDP Flight Time (resets after rest)
    var perFDPFlightLimit: PerFDPFlightLimit
    
    // Cumulative Flight Time Limits
    var flightTime7Day: FlightTimeLimit
    var flightTimeRolling: FlightTimeLimit  // 28 or 30 day based on rollingPeriod
    var flightTime365Day: FlightTimeLimit
    
    // Cumulative FDP Limits
    var fdp7Day: FDPLimit
    var fdpRolling: FDPLimit  // 28 or 30 day based on rollingPeriod
    
    // Rest Requirements
    var restRequirement: RestRequirement
    
    // Rolling Period Selection (28 or 30 days)
    var rollingPeriodDays: Int
    
    // Warning Thresholds
    var warningThresholdPercent: Double  // Default 90%
    var criticalThresholdPercent: Double // Default 95%
    
    // MARK: - Preset Configurations
    
    /// Part 91 - No limits tracked
    static let part91Default = DutyLimitConfiguration(
        operationType: .part91,
        perFDPFlightLimit: .disabled,
        flightTime7Day: .disabled,
        flightTimeRolling: .disabled,
        flightTime365Day: .disabled,
        fdp7Day: .disabled,
        fdpRolling: .disabled,
        restRequirement: .disabled,
        rollingPeriodDays: 30,
        warningThresholdPercent: 0.90,
        criticalThresholdPercent: 0.95
    )
    
    /// Part 135 Default Configuration
    static let part135Default = DutyLimitConfiguration(
        operationType: .part135,
        perFDPFlightLimit: PerFDPFlightLimit(
            enabled: true,
            dayHours: 8.0,
            nightHours: 8.0,
            resetsAfterRest: true
        ),
        flightTime7Day: FlightTimeLimit(enabled: true, hours: 34.0, periodDays: 7),
        flightTimeRolling: FlightTimeLimit(enabled: true, hours: 120.0, periodDays: 30),
        flightTime365Day: FlightTimeLimit(enabled: true, hours: 1200.0, periodDays: 365),
        fdp7Day: .disabled,  // Part 135 doesn't track FDP the same way
        fdpRolling: .disabled,
        restRequirement: RestRequirement(
            enabled: true,
            minimumRestHours: 10.0,
            sleepOpportunityHours: 8.0,
            requiredInPeriodHours: 24,
            periodHours: 168
        ),
        rollingPeriodDays: 30,
        warningThresholdPercent: 0.90,
        criticalThresholdPercent: 0.95
    )
    
    /// Part 121 / FAR 117 Default Configuration (28-day)
    static let part121Default28Day = DutyLimitConfiguration(
        operationType: .part121,
        perFDPFlightLimit: PerFDPFlightLimit(
            enabled: false,     // DISABLED: Dispatch pre-screens for 8h, actual block often exceeds
            dayHours: 9.0,      // 0500-1959 report time
            nightHours: 8.0,    // 2000-0459 report time
            resetsAfterRest: true
        ),
        flightTime7Day: .disabled,  // Part 117 doesn't use 7-day flight time
        flightTimeRolling: FlightTimeLimit(enabled: true, hours: 100.0, periodDays: 28),  // PRIMARY CONCERN
        flightTime365Day: FlightTimeLimit(enabled: true, hours: 1000.0, periodDays: 365),
        fdp7Day: FDPLimit(enabled: true, hours: 60.0, periodDays: 7),
        fdpRolling: FDPLimit(enabled: true, hours: 190.0, periodDays: 28),
        restRequirement: RestRequirement(
            enabled: true,
            minimumRestHours: 10.0,
            sleepOpportunityHours: 8.0,
            requiredInPeriodHours: 30,
            periodHours: 168
        ),
        rollingPeriodDays: 28,
        warningThresholdPercent: 0.90,
        criticalThresholdPercent: 0.95
    )
    
    /// Part 121 / FAR 117 Configuration with 30-day rolling period (more restrictive ops spec)
    static let part121Default30Day = DutyLimitConfiguration(
        operationType: .part121,
        perFDPFlightLimit: PerFDPFlightLimit(
            enabled: false,     // DISABLED: Dispatch pre-screens for 8h, actual block often exceeds
            dayHours: 9.0,
            nightHours: 8.0,
            resetsAfterRest: true
        ),
        flightTime7Day: .disabled,
        flightTimeRolling: FlightTimeLimit(enabled: true, hours: 100.0, periodDays: 30),  // PRIMARY CONCERN
        flightTime365Day: FlightTimeLimit(enabled: true, hours: 1000.0, periodDays: 365),
        fdp7Day: FDPLimit(enabled: true, hours: 60.0, periodDays: 7),
        fdpRolling: FDPLimit(enabled: true, hours: 190.0, periodDays: 30),
        restRequirement: RestRequirement(
            enabled: true,
            minimumRestHours: 10.0,
            sleepOpportunityHours: 8.0,
            requiredInPeriodHours: 30,
            periodHours: 168
        ),
        rollingPeriodDays: 30,
        warningThresholdPercent: 0.90,
        criticalThresholdPercent: 0.95
    )
    
    // MARK: - Helper Methods
    
    /// Get preset for operation type
    static func preset(for type: OperationType, rollingDays: Int = 30) -> DutyLimitConfiguration {
        switch type {
        case .part91:
            return part91Default
        case .part135:
            return part135Default
        case .part121:
            return rollingDays == 28 ? part121Default28Day : part121Default30Day
        case .custom:
            // Start with Part 121 30-day as base for custom
            var config = part121Default30Day
            config.operationType = .custom
            return config
        }
    }
    
    /// Update rolling period and adjust limits accordingly
    mutating func updateRollingPeriod(to days: Int) {
        rollingPeriodDays = days
        flightTimeRolling.periodDays = days
        fdpRolling.periodDays = days
    }
}

// MARK: - Settings Store (Observable)
class DutyLimitSettingsStore: ObservableObject {
    static let shared = DutyLimitSettingsStore()
    
    @Published var configuration: DutyLimitConfiguration {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var trackingEnabled: Bool {
        didSet {
            print("🔧 DutyLimitSettingsStore.trackingEnabled changed to: \(trackingEnabled)")
            UserDefaults.appGroup?.set(trackingEnabled, forKey: "dutyLimitTrackingEnabled")
            objectWillChange.send()
        }
    }
    
    @Published var showWarningsOnTripRows: Bool {
        didSet {
            UserDefaults.appGroup?.set(showWarningsOnTripRows, forKey: "dutyLimitShowWarningsOnRows")
        }
    }
    
    @Published var notifyApproachingLimits: Bool {
        didSet {
            UserDefaults.appGroup?.set(notifyApproachingLimits, forKey: "dutyLimitNotifyApproaching")
        }
    }
    
    private let configKey = "dutyLimitConfiguration"
    
    private init() {
        // Load tracking enabled state
        self.trackingEnabled = UserDefaults.appGroup?.bool(forKey: "dutyLimitTrackingEnabled") ?? true
        self.showWarningsOnTripRows = UserDefaults.appGroup?.bool(forKey: "dutyLimitShowWarningsOnRows") ?? true
        self.notifyApproachingLimits = UserDefaults.appGroup?.bool(forKey: "dutyLimitNotifyApproaching") ?? true
        
        // Load configuration
        if let data = UserDefaults.appGroup?.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(DutyLimitConfiguration.self, from: data) {
            self.configuration = decoded
        } else {
            // Default to Part 121 with 30-day rolling period
            self.configuration = .part121Default30Day
        }
    }
    
    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.appGroup?.set(encoded, forKey: configKey)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Apply a preset configuration
    func applyPreset(_ type: OperationType, rollingDays: Int? = nil) {
        let days = rollingDays ?? configuration.rollingPeriodDays
        configuration = .preset(for: type, rollingDays: days)
    }
    
    /// Update just the rolling period
    func setRollingPeriod(_ days: Int) {
        configuration.updateRollingPeriod(to: days)
    }
    
    /// Check if any limits are being tracked
    var hasActiveLimits: Bool {
        guard trackingEnabled else { return false }
        
        return configuration.perFDPFlightLimit.enabled ||
               configuration.flightTime7Day.enabled ||
               configuration.flightTimeRolling.enabled ||
               configuration.flightTime365Day.enabled ||
               configuration.fdp7Day.enabled ||
               configuration.fdpRolling.enabled ||
               configuration.restRequirement.enabled
    }
}

// MARK: - Computed Limit Status
struct LimitStatus {
    let name: String
    let current: Double
    let limit: Double
    let periodDescription: String
    let regulation: String
    
    // Safe helpers
    var safeLimit: Double { max(0, limit) }
    var safeCurrent: Double { max(0, current) }
    
    // Clamped percentage [0, 100]
    var percentage: Double {
        guard safeLimit > 0 else { return 0 }
        return min(max((safeCurrent / safeLimit) * 100, 0), 100)
    }
    
    // Remaining never negative
    var remaining: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeLimit - safeCurrent)
    }
    
    // Over-by (for UI that wants to show exceeded amount)
    var overBy: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeCurrent - safeLimit)
    }
    
    var isWarning: Bool {
        percentage >= 90
    }
    
    var isCritical: Bool {
        percentage >= 95
    }
    
    var statusColor: Color {
        if isCritical { return .red }
        if isWarning { return .orange }
        return .green
    }
}
//Keep this one
// MARK: - Updated FAR117Status using DutyLimitSettings
struct ConfigurableLimitStatus {
    let settings: DutyLimitConfiguration
    
    // Current values (populated by calculation)
    var currentFDPFlightTime: Double = 0
    var flightTime7Day: Double = 0
    var flightTimeRolling: Double = 0
    var flightTime365Day: Double = 0
    var fdpTime7Day: Double = 0
    var fdpTimeRolling: Double = 0
    var lastRestPeriodHours: Double = 0
    var restInLast168Hours: Double = 0
    
    // Report time for per-FDP limit (true if day, false if night)
    var isDayReportTime: Bool = true
    
    // MARK: - REST STATUS (NEW)
    var isInRest: Bool = false
    var restEndTime: Date? = nil
    
    // Formatted rest end for display
    var formattedRestEnd: String? {
        guard let endTime = restEndTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endTime)
    }
    
    var formattedRestEndZulu: String? {
        guard let endTime = restEndTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: endTime)
    }
    
    // MARK: - Status Checks
    
    var perFDPLimit: Double {
        guard settings.perFDPFlightLimit.enabled else { return 0 }
        return isDayReportTime ? settings.perFDPFlightLimit.dayHours : settings.perFDPFlightLimit.nightHours
    }
    
    var showWarning: Bool {
        guard settings.operationType != .part91 else { return false }
        
        let threshold = settings.warningThresholdPercent
        
        if settings.perFDPFlightLimit.enabled && perFDPLimit > 0 {
            if currentFDPFlightTime / perFDPLimit >= threshold { return true }
        }
        if settings.flightTimeRolling.enabled && settings.flightTimeRolling.hours > 0 {
            if flightTimeRolling / settings.flightTimeRolling.hours >= threshold { return true }
        }
        if settings.fdp7Day.enabled && settings.fdp7Day.hours > 0 {
            if fdpTime7Day / settings.fdp7Day.hours >= threshold { return true }
        }
        if settings.fdpRolling.enabled && settings.fdpRolling.hours > 0 {
            if fdpTimeRolling / settings.fdpRolling.hours >= threshold { return true }
        }
        
        return false
    }
    
    var criticalWarning: Bool {
        guard settings.operationType != .part91 else { return false }
        
        let threshold = settings.criticalThresholdPercent
        
        if settings.perFDPFlightLimit.enabled && perFDPLimit > 0 {
            if currentFDPFlightTime / perFDPLimit >= threshold { return true }
        }
        if settings.flightTimeRolling.enabled && settings.flightTimeRolling.hours > 0 {
            if flightTimeRolling / settings.flightTimeRolling.hours >= threshold { return true }
        }
        
        return false
    }
    
    // MARK: - Get All Active Limit Statuses
    
    func getAllLimitStatuses() -> [LimitStatus] {
        var statuses: [LimitStatus] = []
        
        // Check if currently in rest from multiple sources:
        // 1. DutyTimerManager (manual duty timer ended = rest started)
        // 2. ConfigurableLimitStatus.isInRest (calculated from trip data)
        let inRest = DutyTimerManager.shared.isInRest || self.isInRest
        
        // Only show Per-FDP if enabled AND NOT in rest (per-FDP resets after rest)
        if settings.perFDPFlightLimit.enabled && !inRest {
            // Additional check: if Per-FDP is 0 or very small, hide it
            if currentFDPFlightTime > 0.1 {
                statuses.append(LimitStatus(
                    name: "Block Time (This FDP)",
                    current: max(0, currentFDPFlightTime), // defensive clamp
                    limit: perFDPLimit,
                    periodDescription: "Current Duty Period",
                    regulation: isDayReportTime ? "§117.11 (Day)" : "§117.11 (Night)"
                ))
            }
        }

        if settings.flightTime7Day.enabled {
            statuses.append(LimitStatus(
                name: "7-Day Block Time",
                current: max(0, flightTime7Day), // defensive clamp
                limit: settings.flightTime7Day.hours,
                periodDescription: "Rolling 7 Days",
                regulation: "§135.267"
            ))
        }

        if settings.flightTimeRolling.enabled {
            statuses.append(LimitStatus(
                name: "\(settings.rollingPeriodDays)-Day Block Time",
                current: max(0, flightTimeRolling), // defensive clamp
                limit: settings.flightTimeRolling.hours,
                periodDescription: "Rolling \(settings.rollingPeriodDays) Days",
                regulation: settings.operationType == .part121 ? "§117.23(b)" : "§135.267"
            ))
        }

        if settings.flightTime365Day.enabled {
            statuses.append(LimitStatus(
                name: "Annual Block Time",
                current: max(0, flightTime365Day), // defensive clamp
                limit: settings.flightTime365Day.hours,
                periodDescription: "Rolling 365 Days",
                regulation: settings.operationType == .part121 ? "§117.23(b)" : "§135.267"
            ))
        }

        if settings.fdp7Day.enabled {
            statuses.append(LimitStatus(
                name: "7-Day Duty Time",
                current: max(0, fdpTime7Day), // defensive clamp
                limit: settings.fdp7Day.hours,
                periodDescription: "Rolling 168 Hours",
                regulation: "§117.23(c)"
            ))
        }

        if settings.fdpRolling.enabled {
            statuses.append(LimitStatus(
                name: "\(settings.rollingPeriodDays)-Day Duty Time",
                current: max(0, fdpTimeRolling), // defensive clamp
                limit: settings.fdpRolling.hours,
                periodDescription: "Rolling \(settings.rollingPeriodDays * 24) Hours",
                regulation: "§117.23(c)"
            ))
        }
        
        return statuses
    }
}


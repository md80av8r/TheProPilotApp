// FlightLeg.swift - Enhanced with Status Tracking & Schedule Variance
import Foundation

// MARK: - Leg Status for Staged Progression
enum LegStatus: String, Codable, CaseIterable {
    case standby = "Standby"       // Pre-populated from roster, waiting
    case active = "Active"         // Currently being flown/timed
    case completed = "Completed"   // Times locked in
    case skipped = "Skipped"       // User chose to skip (schedule change)
    
    var displayName: String { rawValue }
    
    var symbolName: String {
        switch self {
        case .standby: return "clock.badge"
        case .active: return "airplane"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }
}

// MARK: - Leg Pilot Role for PF/PM Tracking (per-leg, not trip role)
enum LegPilotRole: String, Codable, CaseIterable {
    case notSet = "Not Set"
    case pilotFlying = "PF"           // Pilot Flying this leg
    case pilotMonitoring = "PM"       // Pilot Monitoring this leg
    
    var displayName: String {
        switch self {
        case .notSet: return "Not Set"
        case .pilotFlying: return "Pilot Flying"
        case .pilotMonitoring: return "Pilot Monitoring"
        }
    }
    
    var shortName: String { rawValue }
}

struct FlightLeg: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var departure: String = ""
    var arrival: String = ""
    var outTime: String = ""
    var offTime: String = ""
    var onTime: String = ""
    var inTime: String = ""
    var flightNumber: String = ""
    var isDeadhead: Bool = false
    
    // MARK: - Flight Date
    /// The actual calendar date this leg occurred on (for red-eyes, timezone crossings, etc.)
    /// Falls back to trip.date if not explicitly set
    var flightDate: Date?
    
    // MARK: - Leg Status
    var status: LegStatus = .active  // Default for backward compatibility
    
    // MARK: - Scheduled Times from Roster
    var scheduledOut: Date?          // Original roster OUT time
    var scheduledIn: Date?           // Original roster IN time
    var scheduledFlightNumber: String? // Original roster flight number
    var rosterSourceId: String?      // Link back to roster item for reference
    
    // MARK: - Deadhead Time Tracking
    var deadheadOutTime: String = ""
    var deadheadInTime: String = ""
    var deadheadFlightHours: Double = 0.0
    
    // MARK: - Pilot Role Tracking (PF/PM)
    var legPilotRole: LegPilotRole = .notSet  // PF or PM for this leg
    
    // MARK: - Night Operations Tracking
    var nightTakeoff: Bool = false      // Was takeoff at night? (for currency)
    var nightLanding: Bool = false      // Was landing at night? (for currency)

    var isValid: Bool {
        return !departure.isEmpty && !arrival.isEmpty &&
               (!outTime.isEmpty || !inTime.isEmpty ||
                !deadheadOutTime.isEmpty || !deadheadInTime.isEmpty ||
                deadheadFlightHours > 0)
    }
    
    // MARK: - Schedule Variance Calculations
    
    /// Returns the variance in minutes between scheduled and actual OUT time
    /// Negative = early (ahead of schedule), Positive = late (behind schedule)
    var outTimeVarianceMinutes: Int? {
        guard let scheduled = scheduledOut,
              let actual = parseTimeToDate(outTime) else { return nil }
        return Int(actual.timeIntervalSince(scheduled) / 60)
    }
    
    /// Returns the variance in minutes between scheduled and actual IN time
    /// Negative = early, Positive = late
    var inTimeVarianceMinutes: Int? {
        guard let scheduled = scheduledIn,
              let actual = parseTimeToDate(inTime) else { return nil }
        return Int(actual.timeIntervalSince(scheduled) / 60)
    }
    
    /// Human-readable schedule status
    var scheduleStatus: ScheduleVariance {
        // If leg not completed, check OUT time variance
        if status == .active {
            if let outVariance = outTimeVarianceMinutes {
                return ScheduleVariance(minutes: outVariance, phase: .departure)
            }
        }
        
        // If leg completed, check IN time variance
        if status == .completed {
            if let inVariance = inTimeVarianceMinutes {
                return ScheduleVariance(minutes: inVariance, phase: .arrival)
            }
        }
        
        return ScheduleVariance(minutes: 0, phase: .unknown)
    }
    
    /// Check if this leg has scheduled times (was created from roster)
    var hasScheduledTimes: Bool {
        return scheduledOut != nil || scheduledIn != nil
    }
    
    /// Formatted scheduled OUT time for display
    var formattedScheduledOut: String? {
        guard let scheduled = scheduledOut else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: scheduled)
    }
    
    /// Formatted scheduled IN time for display
    var formattedScheduledIn: String? {
        guard let scheduled = scheduledIn else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: scheduled)
    }

    // MARK: - Block Time Calculations
    
    func blockMinutes() -> Int {
        if isDeadhead {
            if !deadheadOutTime.isEmpty && !deadheadInTime.isEmpty,
               let outDate = parseTime(deadheadOutTime),
               let inDate = parseTime(deadheadInTime) {
                let interval = inDate.timeIntervalSince(outDate)
                let minutes = interval < 0 ? interval + 24*3600 : interval
                return Int(minutes / 60)
            }
            
            if deadheadFlightHours > 0 {
                return Int(deadheadFlightHours * 60)
            }
            
            return 0
        }
        
        guard let outDate = parseTime(outTime),
              let inDate = parseTime(inTime) else { return 0 }
        
        let interval = inDate.timeIntervalSince(outDate)
        let minutes = interval < 0 ? interval + 24*3600 : interval
        return Int(minutes / 60)
    }
    
    /// Scheduled block minutes from roster
    var scheduledBlockMinutes: Int? {
        guard let out = scheduledOut, let inTime = scheduledIn else { return nil }
        return Int(inTime.timeIntervalSince(out) / 60)
    }
    
    /// Block time variance (actual - scheduled)
    /// Negative = shorter than planned, Positive = longer than planned
    var blockTimeVarianceMinutes: Int? {
        guard let scheduled = scheduledBlockMinutes else { return nil }
        let actual = blockMinutes()
        guard actual > 0 else { return nil }
        return actual - scheduled
    }

    func calculateFlightMinutes() -> Int {
        guard let offDate = parseTime(offTime),
              let onDate = parseTime(onTime) else { return 0 }
        
        let interval = onDate.timeIntervalSince(offDate)
        let minutes = interval < 0 ? interval + 24*3600 : interval
        return Int(minutes / 60)
    }

    var formattedBlockTime: String {
        let minutes = blockMinutes()
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    var formattedFlightTime: String {
        let minutes = calculateFlightMinutes()
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private func parseTime(_ timeString: String) -> Date? {
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        let hours = Int(padded.prefix(2)) ?? 0
        let minutes = Int(padded.suffix(2)) ?? 0
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hours
        components.minute = minutes
        
        return Calendar.current.date(from: components)
    }
    
    /// Parse time string to Date using today's date (for variance calculation)
    private func parseTimeToDate(_ timeString: String) -> Date? {
        return parseTime(timeString)
    }

    // MARK: - Automatic Flight Date Detection
    
    /// Automatically calculates the flight date based on OUT time and trip date
    /// Detects if the flight crosses midnight and adjusts accordingly
    mutating func autoCalculateFlightDate(tripDate: Date) {
        // If already manually set, don't override
        if flightDate != nil { return }
        
        guard !outTime.isEmpty, !inTime.isEmpty else {
            // No times set yet, use trip date
            flightDate = tripDate
            return
        }
        
        // Parse OUT and IN times
        guard let outDate = parseTimeToDate(outTime),
              let inDate = parseTimeToDate(inTime) else {
            flightDate = tripDate
            return
        }
        
        // Check if flight crosses midnight (IN time < OUT time)
        if inDate < outDate {
            // Flight crossed midnight - leg occurred on next day
            let calendar = Calendar.current
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: tripDate) {
                flightDate = nextDay
                print("🌙 Red-eye detected: \(departure) → \(arrival) crosses midnight, dated: \(nextDay.formatted(date: .abbreviated, time: .omitted))")
            } else {
                flightDate = tripDate
            }
        } else {
            // Normal flight, same day as trip
            flightDate = tripDate
        }
    }
    
    /// Returns the effective flight date (flightDate if set, otherwise tripDate)
    func effectiveFlightDate(tripDate: Date) -> Date {
        return flightDate ?? tripDate
    }
    
    // MARK: - Night Hours Calculation (Platform-specific)
    
    func nightMinutes(flightDate: Date) async -> Int {
        #if !os(watchOS)
        guard let outDate = parseGMTTimeToDate(outTime, flightDate: flightDate),
              let inDate = parseGMTTimeToDate(inTime, flightDate: flightDate) else {
            return estimateNightMinutesFromTimeStrings()
        }
        
        let nightCalculator = NightHoursCalculator()
        let nightSeconds = await nightCalculator.calculateNightHours(
            departure: departure,
            arrival: arrival,
            outTime: outDate,
            inTime: inDate,
            flightDate: flightDate
        )
        
        return Int(nightSeconds / 60)
        #else
        return estimateNightMinutesFromTimeStrings()
        #endif
    }
    
    func calculateNightHours(flightDate: Date) async -> TimeInterval {
        #if !os(watchOS)
        let minutes = await nightMinutes(flightDate: flightDate)
        return TimeInterval(minutes * 60)
        #else
        return 0
        #endif
    }
    
    private func parseGMTTimeToDate(_ timeString: String, flightDate: Date) -> Date? {
        let calendar = Calendar.current
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        
        let paddedTime = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        let hours = Int(String(paddedTime.prefix(2))) ?? 0
        let minutes = Int(String(paddedTime.suffix(2))) ?? 0
        
        guard hours < 24 && minutes < 60 else { return nil }
        
        var components = calendar.dateComponents([.year, .month, .day], from: flightDate)
        components.hour = hours
        components.minute = minutes
        components.second = 0
        components.timeZone = TimeZone(identifier: "GMT")
        
        return calendar.date(from: components)
    }
    
    private func estimateNightMinutesFromTimeStrings() -> Int {
        let outInt = Int(outTime.filter(\.isWholeNumber)) ?? 0
        let inInt = Int(inTime.filter(\.isWholeNumber)) ?? 0
        
        let isNightDeparture = (outInt >= 1900) || (outInt <= 600)
        let isNightArrival = (inInt >= 1900) || (inInt <= 600)
        
        let blockMins = blockMinutes()
        
        if isNightDeparture && isNightArrival {
            return Int(Double(blockMins) * 0.8)
        } else if isNightDeparture || isNightArrival {
            return Int(Double(blockMins) * 0.4)
        } else {
            // Check if flight crosses into night (e.g., depart 1700, arrive 2100)
            let departHour = outInt / 100
            let arriveHour = inInt / 100
            
            // If departure is afternoon and arrival is evening, estimate some night time
            if departHour >= 15 && departHour < 19 && arriveHour >= 19 {
                // Flight crossed sunset - estimate portion after 1900
                let totalMinutes = blockMins
                let estimatedDaylightPortion = max(0, (19 - departHour) * 60)
                let nightPortion = max(0, totalMinutes - estimatedDaylightPortion)
                return Int(Double(nightPortion) * 0.8)  // 80% of post-sunset time
            }
            
            return 0
        }
    }
    
    func formattedNightTime(flightDate: Date) async -> String {
        let minutes = await nightMinutes(flightDate: flightDate)
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    func formattedNightTimeDecimal(flightDate: Date) async -> String {
        let hours = Double(await nightMinutes(flightDate: flightDate)) / 60.0
        return String(format: "%.1f", hours)
    }
}

// MARK: - Schedule Variance Model
struct ScheduleVariance: Equatable {
    let minutes: Int
    let phase: Phase
    
    enum Phase {
        case departure
        case arrival
        case unknown
    }
    
    var isOnTime: Bool {
        abs(minutes) <= 5  // Within 5 minutes = on time
    }
    
    var isEarly: Bool {
        minutes < -5
    }
    
    var isLate: Bool {
        minutes > 5
    }
    
    var displayText: String {
        if isOnTime {
            return "On Time"
        } else if isEarly {
            return "\(abs(minutes))m early"
        } else {
            return "\(minutes)m late"
        }
    }
    
    var shortDisplayText: String {
        if isOnTime {
            return "OT"
        } else if isEarly {
            return "-\(abs(minutes))m"
        } else {
            return "+\(minutes)m"
        }
    }
    
    #if !os(watchOS)
    var color: Color {
        if isOnTime {
            return .green
        } else if isEarly {
            return .blue
        } else {
            return .orange
        }
    }
    #endif
}

// MARK: - Improved Time Formatting Extensions
extension FlightLeg {
    var formattedBlockTimeWithPlus: String {
        let minutes = blockMinutes()
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            
            let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
            return String(format: "%@+%02d", hoursFormatted, mins)
        } else {
            return String(format: "%d+%02d", hours, mins)
        }
    }
    
    var formattedFlightTimeWithPlus: String {
        let minutes = calculateFlightMinutes()
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            
            let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
            return String(format: "%@+%02d", hoursFormatted, mins)
        } else {
            return String(format: "%d+%02d", hours, mins)
        }
    }
    
    /// Formatted scheduled block time
    var formattedScheduledBlockTime: String? {
        guard let minutes = scheduledBlockMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - SwiftUI Import for Color (non-watchOS only)
#if !os(watchOS)
import SwiftUI
#endif

// Trip.swift - Enhanced with Logpage Break Support & Roster Integration
// FIXED: Leg modification now correctly updates through logpages structure
import Foundation
import SwiftUI

// MARK: - Logpage Support
struct Logpage: Identifiable, Codable, Equatable {
    var id = UUID()
    var pageNumber: Int
    var tatStart: String // Starting TAT for this logpage
    var legs: [FlightLeg]
    var mechanicalIssueNote: String? // Optional note about why logpage was broken
    var dateCreated: Date = Date()
    
    var totalFlightMinutes: Int {
        legs.reduce(0) { $0 + $1.calculateFlightMinutes() }
    }
    
    var totalBlockMinutes: Int {
        legs.reduce(0) { $0 + $1.blockMinutes() }
    }

    // MARK: - Block Time Mismatch Detection (NOC vs Logged)

    /// Returns true if any leg in this trip has a block time mismatch with roster
    var hasBlockTimeMismatch: Bool {
        legs.contains { $0.hasBlockTimeMismatch }
    }

    /// Returns legs that have block time mismatches
    var legsWithMismatch: [FlightLeg] {
        legs.filter { $0.hasBlockTimeMismatch }
    }

    /// Returns the worst mismatch severity across all legs
    var worstMismatchSeverity: MismatchSeverity {
        let severities = legs.map { $0.blockTimeMismatchSeverity }
        if severities.contains(.significant) { return .significant }
        if severities.contains(.moderate) { return .moderate }
        if severities.contains(.minor) { return .minor }
        return .none
    }

    /// Total scheduled block minutes from roster (if available)
    var totalScheduledBlockMinutes: Int? {
        let scheduledLegs = legs.compactMap { $0.scheduledBlockMinutes }
        guard !scheduledLegs.isEmpty else { return nil }
        return scheduledLegs.reduce(0, +)
    }

    /// Total block time variance (actual - scheduled) in minutes
    var totalBlockTimeVarianceMinutes: Int? {
        guard let scheduled = totalScheduledBlockMinutes else { return nil }
        return totalBlockMinutes - scheduled
    }

    var tatFinal: String {
        guard let startMinutes = parseTATMinutes(tatStart) else { return "" }
        let finalMinutes = startMinutes + totalFlightMinutes
        let hours = finalMinutes / 60
        let minutes = finalMinutes % 60
        return "\(hours)+\(String(format: "%02d", minutes))"
    }
    
    private func parseTATMinutes(_ tat: String) -> Int? {
        let digits = tat.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        let mins = Int(digits.suffix(2)) ?? 0
        let hrs = Int(digits.dropLast(2)) ?? 0
        return hrs * 60 + mins
    }
}

enum PilotRole: String, CaseIterable, Codable, Equatable {
    case captain = "Captain"
    case firstOfficer = "First Officer"
    case solo = "Solo"
    case jumpseater = "Jumpseater"

    var shouldHandleReceipts: Bool {
        return self == .captain || self == .solo
    }
}

enum TripStatus: String, Codable, Equatable {
    case planning = "Planning"
    case active = "Active"
    case completed = "Completed"
}


// MARK: - Enhanced Trip with Logpage Support & Roster Integration
struct Trip: Identifiable, Codable, Equatable {
    var id = UUID()
    var tripNumber: String
    var aircraft: String
    var date: Date
    var crew: [CrewMember]
    var notes: String
    var tripType: TripType = .operating
    var deadheadAirline: String?
    var deadheadFlightNumber: String?
    
    // MARK: - Logpage Support
    var logpages: [Logpage] = []
    
    // Legacy support - computed property for backwards compatibility
    // NOTE: Use updateLeg(at:with:) for modifying individual legs!
    var legs: [FlightLeg] {
        get { logpages.flatMap { $0.legs } }
        set {
            if logpages.isEmpty {
                logpages = [Logpage(pageNumber: 1, tatStart: tatStart, legs: newValue)]
            } else {
                // FIXED: Distribute legs across logpages properly
                // For simple cases (single logpage), just replace
                if logpages.count == 1 {
                    logpages[0].legs = newValue
                } else {
                    // For multiple logpages, replace all with single logpage
                    // This maintains backwards compatibility
                    let tat = logpages.first?.tatStart ?? ""
                    logpages = [Logpage(pageNumber: 1, tatStart: tat, legs: newValue)]
                }
            }
        }
    }
    
    // Legacy TAT support - uses first logpage TAT
    var tatStart: String {
        get { logpages.first?.tatStart ?? "" }
        set {
            if logpages.isEmpty {
                logpages = [Logpage(pageNumber: 1, tatStart: newValue, legs: [])]
            } else {
                logpages[0].tatStart = newValue
            }
        }
    }
    
    // Aviation Workflow Properties
    var status: TripStatus = .planning
    var pilotRole: PilotRole = .captain
    var receiptCount: Int = 0
    var logbookPageSent: Bool = false
    
    // Per Diem Properties
    var perDiemStarted: Date?
    var perDiemEnded: Date?
    
    // Simulator Properties
    var simulatorMinutes: Int?
    
    // MARK: - Roster Integration Properties (NEW)
    var rosterSourceIds: [String]?        // Links to original roster items
    var showTimeAlarmId: String?          // Notification ID for show time alarm
    var scheduledShowTime: Date?          // Original scheduled show time from roster
    
    // MARK: - Duty Time Tracking
    var dutyStartTime: Date?          // When duty period started (editable)
    var dutyEndTime: Date?            // When duty period ended
    var dutyMinutes: Int?             // Total duty time in minutes (calculated)
    
    // MARK: - Migration Tracking (FIX: Prevents re-migration on every load)
    private var hasBeenMigrated: Bool = false
    
    // MARK: - Computed Properties
    var perDiemIsOngoing: Bool {
        perDiemStarted != nil && perDiemEnded == nil
    }
    
    var perDiemMinutes: Int? {
        guard let started = perDiemStarted else { return nil }
        let ended = perDiemEnded ?? Date()
        return Int(ended.timeIntervalSince(started) / 60)
    }
    
    var totalBlockMinutes: Int {
        logpages.reduce(0) { $0 + $1.totalBlockMinutes }
    }
    
    var totalFlightMinutes: Int {
        logpages.reduce(0) { $0 + $1.totalFlightMinutes }
    }

    // MARK: - Block Time Mismatch Detection (NOC vs Logged)

    /// Returns true if any leg in this trip has a block time mismatch with roster
    var hasBlockTimeMismatch: Bool {
        legs.contains { $0.hasBlockTimeMismatch }
    }

    /// Returns legs that have block time mismatches
    var legsWithMismatch: [FlightLeg] {
        legs.filter { $0.hasBlockTimeMismatch }
    }

    /// Returns the worst mismatch severity across all legs
    var worstMismatchSeverity: MismatchSeverity {
        let severities = legs.map { $0.blockTimeMismatchSeverity }
        if severities.contains(.significant) { return .significant }
        if severities.contains(.moderate) { return .moderate }
        if severities.contains(.minor) { return .minor }
        return .none
    }

    var routeString: String {
        let allLegs = legs
        guard !allLegs.isEmpty else { return "No Route" }
        if allLegs.count == 1 {
            return "\(allLegs[0].departure) → \(allLegs[0].arrival)"
        }
        return "\(allLegs.first?.departure ?? "") → \(allLegs.last?.arrival ?? "")"
    }
    
    /// Full route with all stops
    var fullRouteString: String {
        let allLegs = legs
        guard !allLegs.isEmpty else { return "No Route" }
        var airports = allLegs.map { $0.departure }
        if let lastArrival = allLegs.last?.arrival {
            airports.append(lastArrival)
        }
        return airports.joined(separator: " → ")
    }
    
    var displayTitle: String {
        switch tripType {
        case .operating:
            return "Trip #\(tripNumber)"
        case .deadhead:
            if let airline = deadheadAirline, let flightNum = deadheadFlightNumber {
                return "DH: \(airline) \(flightNum)"
            }
            return "Deadhead"
        case .simulator:
            return "Sim: \(aircraft)"
        }
    }
    
    var isDeadhead: Bool {
        return tripType == .deadhead
    }
    
    var canScanReceipts: Bool {
        return pilotRole.shouldHandleReceipts && (status == .planning || status == .active)
    }
    
    var formattedTotalTime: String {
        if tripType == .simulator, let simMinutes = simulatorMinutes {
            let hours = simMinutes / 60
            let mins = simMinutes % 60
            return "\(hours)+\(String(format: "%02d", mins))"
        }
        
        let minutes = totalBlockMinutes
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)+\(String(format: "%02d", mins))"
    }
    
    var nextReceiptNumber: Int {
        return receiptCount + 1
    }
    
    // MARK: - Leg Status & Progression (NEW)
    
    /// The currently active leg (first leg with .active status)
    var activeLeg: FlightLeg? {
        legs.first { $0.status == .active }
    }
    
    /// Index of the active leg in the flat legs array
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
    
    /// Count of skipped legs
    var skippedLegCount: Int {
        legs.filter { $0.status == .skipped }.count
    }
    
    /// Progress through the trip (0.0 to 1.0)
    var legProgress: Double {
        guard !legs.isEmpty else { return 0 }
        return Double(completedLegCount) / Double(legs.count)
    }
    
    /// Formatted progress string (e.g., "2 of 4 legs")
    var legProgressString: String {
        "\(completedLegCount) of \(legs.count) leg\(legs.count == 1 ? "" : "s")"
    }
    
    // MARK: - Schedule Variance (NEW)
    
    /// Check if trip was created from roster
    var isFromRoster: Bool {
        rosterSourceIds != nil || legs.contains { $0.rosterSourceId != nil }
    }
    
    /// Check if trip has any scheduled times
    var hasScheduledTimes: Bool {
        legs.contains { $0.hasScheduledTimes }
    }
    
    /// Overall schedule variance for the trip (sum of completed leg variances)
    var overallScheduleVariance: Int? {
        let completedLegs = legs.filter { $0.status == .completed }
        guard !completedLegs.isEmpty else { return nil }
        
        let variances = completedLegs.compactMap { $0.inTimeVarianceMinutes }
        guard !variances.isEmpty else { return nil }
        
        return variances.reduce(0, +)
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
    
    /// Schedule status for display with color hint
    var scheduleStatusInfo: (text: String, isAhead: Bool, isOnTime: Bool, isBehind: Bool) {
        guard let variance = overallScheduleVariance else {
            return ("No Data", false, false, false)
        }
        
        if abs(variance) <= 5 {
            return ("On Schedule", false, true, false)
        } else if variance < 0 {
            return ("\(abs(variance))m ahead", true, false, false)
        } else {
            return ("\(variance)m behind", false, false, true)
        }
    }
    
    /// Total scheduled block time (from roster)
    var totalScheduledBlockMinutes: Int? {
        let scheduledMinutes = legs.compactMap { $0.scheduledBlockMinutes }
        guard !scheduledMinutes.isEmpty else { return nil }
        return scheduledMinutes.reduce(0, +)
    }
    
    /// Block time variance (actual - scheduled)
    var blockTimeVariance: Int? {
        guard let scheduled = totalScheduledBlockMinutes else { return nil }
        let actual = totalBlockMinutes
        guard actual > 0 else { return nil }
        return actual - scheduled
    }
    
    /// Time until show time (if scheduled)
    var timeUntilShowTime: TimeInterval? {
        guard let showTime = scheduledShowTime ?? legs.first?.scheduledOut else { return nil }
        return showTime.timeIntervalSince(Date())
    }
    
    /// Formatted countdown to show time
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
    
    // MARK: - Duty Time Calculations
    
    /// Pre-duty buffer in minutes (default 60 = 1 hour before first OUT)
    static let defaultPreDutyBuffer: Int = 60
    
    /// Calculated or stored duty start time
    /// Returns stored dutyStartTime, or calculates from first OUT - 1 hour
    var effectiveDutyStartTime: Date? {
        // If explicitly set, use that
        if let stored = dutyStartTime {
            return stored
        }
        
        // Otherwise calculate from first OUT time - 1 hour
        guard let firstLeg = legs.first,
              !firstLeg.outTime.isEmpty,
              let outDateTime = parseTimeForDuty(timeString: firstLeg.outTime, date: date) else {
            return nil
        }
        
        // Subtract 1 hour (default pre-duty buffer)
        return Calendar.current.date(byAdding: .minute, value: -Trip.defaultPreDutyBuffer, to: outDateTime)
    }
    
    /// Calculated or stored duty end time
    /// Returns stored dutyEndTime, or calculates from last IN + 15 minutes
    var effectiveDutyEndTime: Date? {
        // If explicitly set, use that
        if let stored = dutyEndTime {
            return stored
        }

        // Otherwise calculate from last IN time + 15 minutes post-duty
        guard let lastLeg = legs.last,
              let firstLeg = legs.first,
              !lastLeg.inTime.isEmpty else {
            return nil
        }

        // CRITICAL FIX: Use leg.flightDate for overnight flights!
        var legDate = lastLeg.flightDate ?? date

        // Detect overnight if flightDate is nil
        if lastLeg.flightDate == nil && !firstLeg.outTime.isEmpty {
            if let inHour = parseHourFromTime(lastLeg.inTime),
               let outHour = parseHourFromTime(firstLeg.outTime) {
                if inHour < 12 && outHour > 12 {
                    let calendar = Calendar.current
                    if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                        legDate = nextDay
                    }
                }
            }
        }

        guard let inDateTime = parseTimeForDuty(timeString: lastLeg.inTime, date: legDate) else {
            return nil
        }

        // Add 15 minutes post-duty buffer
        return Calendar.current.date(byAdding: .minute, value: 15, to: inDateTime)
    }
    
    /// Total duty period in hours for this trip
    var totalDutyHours: Double {
        // For overnight trips, always recalculate to ensure correct date handling
        // (stored values may have been calculated with old buggy logic)
        let shouldRecalculate = isOvernightTrip && dutyEndTime != nil

        let start: Date?
        let end: Date?

        if shouldRecalculate {
            start = dutyStartTime ?? calculateAutoDutyStart()
            end = calculateAutoDutyEnd()  // Force recalculate for overnight
        } else {
            start = dutyStartTime ?? calculateAutoDutyStart()
            end = dutyEndTime ?? calculateAutoDutyEnd()
        }

        guard let startTime = start, let endTime = end else {
            return 0
        }

        let interval = endTime.timeIntervalSince(startTime)
        let hours = interval / 3600.0
        return max(0, hours)
    }

    /// Check if this trip spans overnight (first OUT in PM, last IN in AM)
    private var isOvernightTrip: Bool {
        guard let firstLeg = legs.first, let lastLeg = legs.last else {
            return false
        }

        guard let outHour = parseHourFromTime(firstLeg.outTime),
              let inHour = parseHourFromTime(lastLeg.inTime) else {
            return false
        }

        // OUT in afternoon/evening (12+), IN in early morning (0-11) = overnight
        return outHour >= 12 && inHour < 12
    }
    
    private func calculateAutoDutyStart() -> Date? {
        guard let firstLeg = legs.first,
              let outTime = parseTimeWithDate(timeString: firstLeg.outTime, date: date) else {
            return nil
        }
        return outTime.addingTimeInterval(-60 * 60) // 60 min before
    }
    
    private func calculateAutoDutyEnd() -> Date? {
        guard let lastLeg = legs.last,
              let firstLeg = legs.first else {
            return nil
        }

        // Determine the base date - use leg.flightDate if available
        var legDate = lastLeg.flightDate ?? date

        // Detect overnight if flightDate is nil by comparing times
        if lastLeg.flightDate == nil && !lastLeg.inTime.isEmpty && !firstLeg.outTime.isEmpty {
            if let inHour = parseHourFromTime(lastLeg.inTime),
               let outHour = parseHourFromTime(firstLeg.outTime) {
                // IN in early morning (0-11), OUT in afternoon/evening (12+) = overnight
                if inHour < 12 && outHour > 12 {
                    let calendar = Calendar.current
                    if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                        legDate = nextDay
                    }
                }
            }
        }

        guard let inTime = parseTimeWithDate(timeString: lastLeg.inTime, date: legDate) else {
            return nil
        }
        return inTime.addingTimeInterval(15 * 60) // 15 min after
    }

    /// Helper to extract hour from time string
    private func parseHourFromTime(_ timeString: String) -> Int? {
        let cleanedTime = timeString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleanedTime.count == 4 {
            return Int(cleanedTime.prefix(2))
        } else if cleanedTime.count == 3 {
            return Int(cleanedTime.prefix(1))
        } else if cleanedTime.count <= 2 {
            return Int(cleanedTime)
        }
        return nil
    }
    
    /// Parse time string to Date for duty calculations
    private func parseTimeForDuty(timeString: String, date: Date) -> Date? {
        let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTime.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let cleanedTime = trimmedTime
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        var hours: Int?
        var minutes: Int?
        
        if cleanedTime.count == 4 {
            hours = Int(cleanedTime.prefix(2))
            minutes = Int(cleanedTime.suffix(2))
        } else if cleanedTime.count == 3 {
            hours = Int(cleanedTime.prefix(1))
            minutes = Int(cleanedTime.suffix(2))
        } else if cleanedTime.count <= 2 {
            hours = Int(cleanedTime)
            minutes = 0
        }
        
        guard let h = hours, let m = minutes,
              h >= 0 && h <= 23, m >= 0 && m <= 59 else {
            return nil
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = h
        components.minute = m
        return calendar.date(from: components)
    }
    
    /// Parse time string to Date with date (used for auto duty calculations)
    private func parseTimeWithDate(timeString: String, date: Date) -> Date? {
        let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTime.isEmpty else { return nil }

        let calendar = Calendar.current
        let cleanedTime = trimmedTime
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")

        var hours: Int?
        var minutes: Int?

        if cleanedTime.count == 4 {
            hours = Int(cleanedTime.prefix(2))
            minutes = Int(cleanedTime.suffix(2))
        } else if cleanedTime.count == 3 {
            hours = Int(cleanedTime.prefix(1))
            minutes = Int(cleanedTime.suffix(2))
        } else if cleanedTime.count <= 2 {
            hours = Int(cleanedTime)
            minutes = 0
        }

        guard let h = hours, let m = minutes,
              h >= 0 && h <= 23, m >= 0 && m <= 59 else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = h
        components.minute = m
        return calendar.date(from: components)
    }
    
    // MARK: - Logpage Management Functions
    
    var hasMultipleLogpages: Bool {
        return logpages.count > 1
    }
    
    var currentLogpage: Logpage? {
        return logpages.last
    }
    
    mutating func breakLogpage(newTAT: String, mechanicalNote: String? = nil) {
        if !logpages.isEmpty {
            logpages[logpages.count - 1].mechanicalIssueNote = mechanicalNote
        }
        
        let newPageNumber = (logpages.last?.pageNumber ?? 0) + 1
        let newLogpage = Logpage(
            pageNumber: newPageNumber,
            tatStart: newTAT,
            legs: [],
            mechanicalIssueNote: nil,
            dateCreated: Date()
        )
        
        logpages.append(newLogpage)
        print("🔧 Broke logpage for trip \(tripNumber). Now has \(logpages.count) logpages")
    }
    
    mutating func addLegToCurrentLogpage(_ leg: FlightLeg) {
        if logpages.isEmpty {
            logpages = [Logpage(pageNumber: 1, tatStart: "", legs: [leg])]
        } else {
            logpages[logpages.count - 1].legs.append(leg)
        }
    }
    
    // MARK: - FIXED: Individual Leg Modification
    
    /// Convert flat index to (logpageIndex, legIndex) tuple
    private func logpageIndices(forFlatIndex flatIndex: Int) -> (pageIndex: Int, legIndex: Int)? {
        var counter = 0
        for pageIndex in logpages.indices {
            for legIndex in logpages[pageIndex].legs.indices {
                if counter == flatIndex {
                    return (pageIndex, legIndex)
                }
                counter += 1
            }
        }
        return nil
    }
    
    /// FIXED: Update a specific leg at flat index
    /// Use this instead of legs[index] = newLeg
    mutating func updateLeg(at flatIndex: Int, with updatedLeg: FlightLeg) {
        guard let indices = logpageIndices(forFlatIndex: flatIndex) else {
            print("⚠️ updateLeg: Invalid index \(flatIndex)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex] = updatedLeg
        print("✏️ Updated leg at index \(flatIndex) (page \(indices.pageIndex), leg \(indices.legIndex))")
    }
    
    /// FIXED: Update OUT time for leg at flat index
    mutating func setOutTime(_ time: String, forLegAt flatIndex: Int) {
        guard let indices = logpageIndices(forFlatIndex: flatIndex) else {
            print("⚠️ setOutTime: Invalid index \(flatIndex)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].outTime = time
        print("✏️ Set OUT time '\(time)' for leg \(flatIndex + 1)")
    }
    
    /// FIXED: Update OFF time for leg at flat index
    mutating func setOffTime(_ time: String, forLegAt flatIndex: Int) {
        guard let indices = logpageIndices(forFlatIndex: flatIndex) else {
            print("⚠️ setOffTime: Invalid index \(flatIndex)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].offTime = time
        print("✏️ Set OFF time '\(time)' for leg \(flatIndex + 1)")
    }
    
    /// FIXED: Update ON time for leg at flat index
    mutating func setOnTime(_ time: String, forLegAt flatIndex: Int) {
        guard let indices = logpageIndices(forFlatIndex: flatIndex) else {
            print("⚠️ setOnTime: Invalid index \(flatIndex)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].onTime = time
        print("✏️ Set ON time '\(time)' for leg \(flatIndex + 1)")
    }
    
    /// FIXED: Update IN time for leg at flat index
    mutating func setInTime(_ time: String, forLegAt flatIndex: Int) {
        guard let indices = logpageIndices(forFlatIndex: flatIndex) else {
            print("⚠️ setInTime: Invalid index \(flatIndex)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].inTime = time
        print("✏️ Set IN time '\(time)' for leg \(flatIndex + 1)")
    }
    
    // MARK: - Leg Status Management (NEW)
    
    /// Complete the active leg and optionally activate the next standby leg
    mutating func completeActiveLeg(activateNext: Bool = true) {
        guard let activeIndex = activeLegIndex else {
            print("⚠️ completeActiveLeg: No active leg found")
            return
        }
        
        // Find which logpage contains this leg using the helper
        guard let indices = logpageIndices(forFlatIndex: activeIndex) else {
            print("⚠️ completeActiveLeg: Could not find leg at index \(activeIndex)")
            return
        }
        
        logpages[indices.pageIndex].legs[indices.legIndex].status = .completed
        print("✅ Completed leg \(activeIndex + 1) (page \(indices.pageIndex), leg \(indices.legIndex))")
        
        if activateNext {
            activateNextStandbyLeg()
        }
    }
    
    /// Initialize all legs with proper status (first = active, rest = standby)
    mutating func initializeLegStatuses() {
        guard !legs.isEmpty else { return }
        
        // Set first leg to active, rest to standby
        var legCounter = 0
        for pageIndex in logpages.indices {
            for legIndex in logpages[pageIndex].legs.indices {
                if legCounter == 0 {
                    logpages[pageIndex].legs[legIndex].status = .active
                } else {
                    logpages[pageIndex].legs[legIndex].status = .standby
                }
                legCounter += 1
            }
        }
        print("🎬 Initialized leg statuses: Leg 1 = Active, Legs 2-\(legs.count) = Standby")
    }
    
    /// Check if all times are filled and auto-complete/advance
    mutating func checkAndAdvanceLeg(at index: Int) {
        guard index >= 0 && index < legs.count else {
            print("⚠️ checkAndAdvanceLeg: Invalid index \(index)")
            return
        }
        
        let leg = legs[index]

        // Check if this leg should be marked complete
        let isComplete: Bool
        if leg.isGroundOperationsOnly {
            // Ground ops: Complete if has OUT and IN times only
            isComplete = !leg.outTime.isEmpty && !leg.inTime.isEmpty
        } else if leg.isDeadhead {
            // Deadhead: Complete if has OUT and IN times OR has hours
            isComplete = (!leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty) || leg.deadheadFlightHours > 0
        } else {
            // Regular flight: Complete ONLY if ALL FOUR times are filled
            isComplete = !leg.outTime.isEmpty &&
                        !leg.offTime.isEmpty &&
                        !leg.onTime.isEmpty &&
                        !leg.inTime.isEmpty
        }

        print("🔍 checkAndAdvanceLeg(\(index)): status=\(leg.status), isGroundOps=\(leg.isGroundOperationsOnly), OUT='\(leg.outTime)', OFF='\(leg.offTime)', ON='\(leg.onTime)', IN='\(leg.inTime)', isComplete=\(isComplete)")
        
        // If complete and currently active, advance
        if isComplete && leg.status == .active {
            completeActiveLeg(activateNext: true)
            print("✅ Leg \(index + 1) complete - all times filled, advancing to next leg")
        } else if !isComplete {
            print("⏳ Leg \(index + 1) not yet complete - waiting for all times")
        } else if leg.status != .active {
            print("ℹ️ Leg \(index + 1) is \(leg.status.rawValue), not active - skipping advancement")
        }
    }
    
    /// Activate the next standby leg (MANUAL ONLY - no auto-create)
    mutating func activateNextStandbyLeg() {
        // Check if there's an existing standby leg
        guard let standbyIndex = nextStandbyLegIndex else {
            print("📋 No more standby legs to activate - trip may be complete")
            return
        }
        
        // Found existing standby leg - activate it
        guard let indices = logpageIndices(forFlatIndex: standbyIndex) else {
            print("⚠️ activateNextStandbyLeg: Could not find standby leg at index \(standbyIndex)")
            return
        }
        
        logpages[indices.pageIndex].legs[indices.legIndex].status = .active
        print("▶️ Activated existing leg \(standbyIndex + 1) (page \(indices.pageIndex), leg \(indices.legIndex))")
    }
    
    /// Skip a leg (schedule change, cancellation, etc.)
    mutating func skipLeg(at index: Int) {
        guard let indices = logpageIndices(forFlatIndex: index) else {
            print("⚠️ skipLeg: Invalid index \(index)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].status = .skipped
        print("⏭️ Skipped leg \(index + 1)")
    }
    
    /// Update leg status at specific index
    mutating func updateLegStatus(at index: Int, to newStatus: LegStatus) {
        guard let indices = logpageIndices(forFlatIndex: index) else {
            print("⚠️ updateLegStatus: Invalid index \(index)")
            return
        }
        logpages[indices.pageIndex].legs[indices.legIndex].status = newStatus
        print("📝 Updated leg \(index + 1) status to \(newStatus.rawValue)")
    }
    
    /// Get leg at specific index
    func leg(at index: Int) -> FlightLeg? {
        guard index >= 0 && index < legs.count else { return nil }
        return legs[index]
    }
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), tripNumber: String, aircraft: String, date: Date,
         tatStart: String, crew: [CrewMember], notes: String, legs: [FlightLeg],
         tripType: TripType = .operating, deadheadAirline: String? = nil,
         deadheadFlightNumber: String? = nil, status: TripStatus = .planning,
         pilotRole: PilotRole = .captain, receiptCount: Int = 0,
         logbookPageSent: Bool = false, perDiemStarted: Date? = nil,
         perDiemEnded: Date? = nil, simulatorMinutes: Int? = nil,
         rosterSourceIds: [String]? = nil, scheduledShowTime: Date? = nil) {
        
        self.id = id
        self.tripNumber = tripNumber
        self.aircraft = aircraft
        self.date = date
        self.crew = crew
        self.notes = notes
        self.tripType = tripType
        self.deadheadAirline = deadheadAirline
        self.deadheadFlightNumber = deadheadFlightNumber
        self.status = status
        self.pilotRole = pilotRole
        self.receiptCount = receiptCount
        self.logbookPageSent = logbookPageSent
        self.perDiemStarted = perDiemStarted
        self.perDiemEnded = perDiemEnded
        self.simulatorMinutes = simulatorMinutes
        self.rosterSourceIds = rosterSourceIds
        self.scheduledShowTime = scheduledShowTime
        
        self.logpages = [Logpage(pageNumber: 1, tatStart: tatStart, legs: legs)]
    }
    
    // MARK: - Codable Support for Migration
    
    enum CodingKeys: String, CodingKey {
        case id, tripNumber, aircraft, date, crew, notes, tripType
        case deadheadAirline, deadheadFlightNumber, status, pilotRole
        case receiptCount, logbookPageSent, perDiemStarted, perDiemEnded
        case logpages, simulatorMinutes
        case rosterSourceIds, showTimeAlarmId, scheduledShowTime  // NEW
        case dutyStartTime, dutyEndTime, dutyMinutes  // Duty time tracking
        case hasBeenMigrated  // 🔥 FIX: Migration tracking
        // Legacy keys for backwards compatibility
        case legs, tatStart
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        tripNumber = try container.decode(String.self, forKey: .tripNumber)
        aircraft = try container.decode(String.self, forKey: .aircraft)
        date = try container.decode(Date.self, forKey: .date)
        crew = try container.decode([CrewMember].self, forKey: .crew)
        notes = try container.decode(String.self, forKey: .notes)
        tripType = try container.decode(TripType.self, forKey: .tripType)
        deadheadAirline = try container.decodeIfPresent(String.self, forKey: .deadheadAirline)
        deadheadFlightNumber = try container.decodeIfPresent(String.self, forKey: .deadheadFlightNumber)
        status = try container.decode(TripStatus.self, forKey: .status)
        pilotRole = try container.decode(PilotRole.self, forKey: .pilotRole)
        receiptCount = try container.decode(Int.self, forKey: .receiptCount)
        logbookPageSent = try container.decode(Bool.self, forKey: .logbookPageSent)
        perDiemStarted = try container.decodeIfPresent(Date.self, forKey: .perDiemStarted)
        perDiemEnded = try container.decodeIfPresent(Date.self, forKey: .perDiemEnded)
        simulatorMinutes = try container.decodeIfPresent(Int.self, forKey: .simulatorMinutes)
        
        // NEW: Roster integration fields
        rosterSourceIds = try container.decodeIfPresent([String].self, forKey: .rosterSourceIds)
        showTimeAlarmId = try container.decodeIfPresent(String.self, forKey: .showTimeAlarmId)
        scheduledShowTime = try container.decodeIfPresent(Date.self, forKey: .scheduledShowTime)
        
        // Duty time tracking
        dutyStartTime = try container.decodeIfPresent(Date.self, forKey: .dutyStartTime)
        dutyEndTime = try container.decodeIfPresent(Date.self, forKey: .dutyEndTime)
        dutyMinutes = try container.decodeIfPresent(Int.self, forKey: .dutyMinutes)
        
        // 🔥 FIX: Check if already migrated to prevent re-migration on every load
        hasBeenMigrated = try container.decodeIfPresent(Bool.self, forKey: .hasBeenMigrated) ?? false
        
        // 🔥 DECODER LOGIC:
        // - CloudKit: FlightLegs stored as SEPARATE records (loaded via fetchFlightLegs)
        // - Local JSON: legs embedded in Trip JSON (need to decode here)
        
        // Try method 1: Decode logpages structure (new format)
        if let decodedLogpages = try? container.decode([Logpage].self, forKey: .logpages), 
           !decodedLogpages.isEmpty,
           !decodedLogpages.allSatisfy({ $0.legs.isEmpty }) {
            // Successfully loaded logpages from local storage
            logpages = decodedLogpages
            hasBeenMigrated = true
            print("✅ Loaded \(decodedLogpages.count) logpage(s) with \(decodedLogpages.flatMap { $0.legs }.count) legs for trip \(tripNumber)")
        }
        // Try method 2: Decode legacy legs array (old format)
        else if let legacyLegs = try? container.decode([FlightLeg].self, forKey: .legs), !legacyLegs.isEmpty {
            // Migrate from legacy format
            let legacyTATStart = (try? container.decode(String.self, forKey: .tatStart)) ?? ""
            logpages = [Logpage(pageNumber: 1, tatStart: legacyTATStart, legs: legacyLegs)]
            hasBeenMigrated = true
            print("✅ Migrated \(legacyLegs.count) legs from legacy format for trip \(tripNumber)")
        }
        // Method 3: No legs found - CloudKit or empty trip
        else {
            // Initialize with empty logpage - legs will be loaded separately from CloudKit
            let legacyTATStart = (try? container.decode(String.self, forKey: .tatStart)) ?? ""
            logpages = [Logpage(pageNumber: 1, tatStart: legacyTATStart, legs: [])]
            print("📦 Initialized empty logpage for trip \(tripNumber) (CloudKit or new trip)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(tripNumber, forKey: .tripNumber)
        try container.encode(aircraft, forKey: .aircraft)
        try container.encode(date, forKey: .date)
        try container.encode(crew, forKey: .crew)
        try container.encode(notes, forKey: .notes)
        try container.encode(tripType, forKey: .tripType)
        try container.encodeIfPresent(deadheadAirline, forKey: .deadheadAirline)
        try container.encodeIfPresent(deadheadFlightNumber, forKey: .deadheadFlightNumber)
        try container.encode(status, forKey: .status)
        try container.encode(pilotRole, forKey: .pilotRole)
        try container.encode(receiptCount, forKey: .receiptCount)
        try container.encode(logbookPageSent, forKey: .logbookPageSent)
        try container.encodeIfPresent(perDiemStarted, forKey: .perDiemStarted)
        try container.encodeIfPresent(perDiemEnded, forKey: .perDiemEnded)
        try container.encodeIfPresent(simulatorMinutes, forKey: .simulatorMinutes)
        
        // NEW: Roster integration fields
        try container.encodeIfPresent(rosterSourceIds, forKey: .rosterSourceIds)
        try container.encodeIfPresent(showTimeAlarmId, forKey: .showTimeAlarmId)
        try container.encodeIfPresent(scheduledShowTime, forKey: .scheduledShowTime)
        
        // Duty time tracking
        try container.encodeIfPresent(dutyStartTime, forKey: .dutyStartTime)
        try container.encodeIfPresent(dutyEndTime, forKey: .dutyEndTime)
        try container.encodeIfPresent(dutyMinutes, forKey: .dutyMinutes)
        
        // 🔥 FIX: Save migration status to prevent re-migration
        try container.encode(hasBeenMigrated, forKey: .hasBeenMigrated)
        
        // Always encode logpages (new format)
        try container.encode(logpages, forKey: .logpages)
        
        // Also encode legacy format for backwards compatibility
        try container.encode(legs, forKey: .legs)
        try container.encode(tatStart, forKey: .tatStart)
    }
}

// MARK: - TripStatus Extensions
extension TripStatus {
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
    
    #if !os(watchOS)
    var color: Color {
        switch self {
        case .planning: return LogbookTheme.accentOrange
        case .active: return LogbookTheme.accentGreen
        case .completed: return LogbookTheme.accentBlue
        }
    }
    #endif
}

// MARK: - Improved Time Formatting Extensions
extension Trip {
    /// Formats total block time as "H,HHH+MM" (e.g., "1,234+56" for 1234 hours 56 minutes)
    var formattedTotalTimeWithCommaPlus: String {
        let hours = totalBlockMinutes / 60
        let minutes = totalBlockMinutes % 60
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
        return String(format: "%@+%02d", hoursFormatted, minutes)
    }
    
    /// Formats total flight time as "H,HHH+MM"
    var formattedFlightTimeWithCommaPlus: String {
        let hours = totalFlightMinutes / 60
        let minutes = totalFlightMinutes % 60
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
        return String(format: "%@+%02d", hoursFormatted, minutes)
    }
    
    /// Formats TAT start time as "H,HHH+MM"
    var formattedTATStart: String {
        guard !tatStart.isEmpty else { return "" }
        
        let digits = tatStart.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return tatStart }
        
        let mins = Int(digits.suffix(2)) ?? 0
        let hrs = Int(digits.dropLast(2)) ?? 0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        let hoursFormatted = formatter.string(from: NSNumber(value: hrs)) ?? "\(hrs)"
        return String(format: "%@+%02d", hoursFormatted, mins)
    }
    
    /// Formats final TAT as "H,HHH+MM"
    var formattedFinalTAT: String {
        guard let firstLogpage = logpages.first,
              let startMinutes = parseTATMinutes(firstLogpage.tatStart) else { return "" }
        
        let finalMinutes = startMinutes + totalFlightMinutes
        let hours = finalMinutes / 60
        let minutes = finalMinutes % 60
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        let hoursFormatted = formatter.string(from: NSNumber(value: hours)) ?? "\(hours)"
        return String(format: "%@+%02d", hoursFormatted, minutes)
    }
    
    /// Formatted scheduled block time
    var formattedScheduledBlockTime: String? {
        guard let minutes = totalScheduledBlockMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    private func parseTATMinutes(_ tat: String) -> Int? {
        let digits = tat.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        let mins = Int(digits.suffix(2)) ?? 0
        let hrs = Int(digits.dropLast(2)) ?? 0
        return hrs * 60 + mins
    }
}

// MARK: - Trip Schedule Status View Helper
#if !os(watchOS)
extension Trip {
    /// Color for schedule status display
    var scheduleStatusColor: Color {
        let info = scheduleStatusInfo
        if info.isOnTime { return .green }
        if info.isAhead { return .blue }
        if info.isBehind { return .orange }
        return .gray
    }
}
#endif


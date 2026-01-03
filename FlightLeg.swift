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

// MARK: - Block Time Mismatch Severity
/// Indicates how far off actual block time is from scheduled (NOC roster)
enum MismatchSeverity: String, Codable {
    case none = "None"              // Within threshold (≤5 min)
    case minor = "Minor"            // 6-15 minutes off
    case moderate = "Moderate"      // 16-30 minutes off
    case significant = "Significant" // >30 minutes off

    var symbolName: String {
        switch self {
        case .none: return "checkmark.circle"
        case .minor: return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .significant: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .none: return "green"
        case .minor: return "yellow"
        case .moderate: return "orange"
        case .significant: return "red"
        }
    }
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
    var scheduledOut: Date?          // Original roster OUT time (STD)
    var scheduledIn: Date?           // Original roster IN time (STA)
    var scheduledFlightNumber: String? // Original roster flight number
    var scheduledBlockMinutesFromRoster: Int? // BLH from roster (more accurate than STD-STA)
    var rosterSourceId: String?      // Link back to roster item for reference

    // MARK: - NOC Roster Fields (CloudKit sync)
    var nocUID: String?                    // Server's unique ID (e.g., "117760") for sync
    var nocTimestamp: Date?                // DTSTAMP - when roster was last modified on server
    var isLastLegOfTrip: Bool = false      // RD: X marker - indicates end of trip
    var tripGroupId: String?               // Groups legs into same trip (e.g., "UJ325")
    var checkInTime: Date?                 // CI - Show time
    var checkOutTime: Date?                // CO - Release time
    var scheduledDeparture: Date?          // STD - Wheels off time
    var scheduledArrival: Date?            // STA - Wheels on time
    var scheduledFlightMinutes: Int?       // Duration (flight time, not block)
    var aircraftType: String?              // e.g., "M88", "M83"
    var tailNumber: String?                // e.g., "N832US"
    
    // MARK: - Deadhead Time Tracking
    var deadheadOutTime: String = ""
    var deadheadInTime: String = ""
    var deadheadFlightHours: Double = 0.0
    
    // MARK: - Pilot Role Tracking (PF/PM)
    var legPilotRole: LegPilotRole = .notSet  // PF or PM for this leg
    
    // MARK: - Night Operations Tracking
    var nightTakeoff: Bool = false      // Was takeoff at night? (for currency)
    var nightLanding: Bool = false      // Was landing at night? (for currency)

    // MARK: - GPS Track Data
    var trackData: Data?                // Encoded FlightTrack JSON for CloudKit sync
    var hasRecordedTrack: Bool = false  // Quick flag to check if track exists

    // MARK: - Initializers
    
    /// Default memberwise initializer (must be explicit when custom init(from:) exists)
    init(id: UUID = UUID(),
         departure: String = "",
         arrival: String = "",
         outTime: String = "",
         offTime: String = "",
         onTime: String = "",
         inTime: String = "",
         flightNumber: String = "",
         isDeadhead: Bool = false,
         flightDate: Date? = nil,
         status: LegStatus = .active,
         scheduledOut: Date? = nil,
         scheduledIn: Date? = nil,
         scheduledFlightNumber: String? = nil,
         scheduledBlockMinutesFromRoster: Int? = nil,
         rosterSourceId: String? = nil,
         nocUID: String? = nil,
         nocTimestamp: Date? = nil,
         isLastLegOfTrip: Bool = false,
         tripGroupId: String? = nil,
         checkInTime: Date? = nil,
         checkOutTime: Date? = nil,
         scheduledDeparture: Date? = nil,
         scheduledArrival: Date? = nil,
         scheduledFlightMinutes: Int? = nil,
         aircraftType: String? = nil,
         tailNumber: String? = nil,
         deadheadOutTime: String = "",
         deadheadInTime: String = "",
         deadheadFlightHours: Double = 0.0,
         legPilotRole: LegPilotRole = .notSet,
         nightTakeoff: Bool = false,
         nightLanding: Bool = false,
         trackData: Data? = nil,
         hasRecordedTrack: Bool = false) {

        self.id = id
        self.departure = departure
        self.arrival = arrival
        self.outTime = outTime
        self.offTime = offTime
        self.onTime = onTime
        self.inTime = inTime
        self.flightNumber = flightNumber
        self.isDeadhead = isDeadhead
        self.flightDate = flightDate
        self.status = status
        self.scheduledOut = scheduledOut
        self.scheduledIn = scheduledIn
        self.scheduledFlightNumber = scheduledFlightNumber
        self.scheduledBlockMinutesFromRoster = scheduledBlockMinutesFromRoster
        self.rosterSourceId = rosterSourceId
        self.nocUID = nocUID
        self.nocTimestamp = nocTimestamp
        self.isLastLegOfTrip = isLastLegOfTrip
        self.tripGroupId = tripGroupId
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.scheduledFlightMinutes = scheduledFlightMinutes
        self.aircraftType = aircraftType
        self.tailNumber = tailNumber
        self.deadheadOutTime = deadheadOutTime
        self.deadheadInTime = deadheadInTime
        self.deadheadFlightHours = deadheadFlightHours
        self.legPilotRole = legPilotRole
        self.nightTakeoff = nightTakeoff
        self.nightLanding = nightLanding
        self.trackData = trackData
        self.hasRecordedTrack = hasRecordedTrack
    }

    // MARK: - Custom Decoder for Legacy Data Compatibility
    enum CodingKeys: String, CodingKey {
        case id, departure, arrival, outTime, offTime, onTime, inTime
        case flightNumber, isDeadhead, flightDate, status
        case scheduledOut, scheduledIn, scheduledFlightNumber
        case scheduledBlockMinutesFromRoster, rosterSourceId
        case nocUID, nocTimestamp, isLastLegOfTrip, tripGroupId
        case checkInTime, checkOutTime, scheduledDeparture, scheduledArrival
        case scheduledFlightMinutes, aircraftType, tailNumber
        case deadheadOutTime, deadheadInTime, deadheadFlightHours
        case legPilotRole, nightTakeoff, nightLanding
        case trackData, hasRecordedTrack
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use decodeIfPresent for everything to handle missing fields gracefully
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        departure = (try? container.decode(String.self, forKey: .departure)) ?? ""
        arrival = (try? container.decode(String.self, forKey: .arrival)) ?? ""
        outTime = (try? container.decode(String.self, forKey: .outTime)) ?? ""
        offTime = (try? container.decode(String.self, forKey: .offTime)) ?? ""
        onTime = (try? container.decode(String.self, forKey: .onTime)) ?? ""
        inTime = (try? container.decode(String.self, forKey: .inTime)) ?? ""
        flightNumber = (try? container.decode(String.self, forKey: .flightNumber)) ?? ""
        isDeadhead = (try? container.decode(Bool.self, forKey: .isDeadhead)) ?? false
        flightDate = try? container.decode(Date.self, forKey: .flightDate)
        
        // Handle status with fallback for old data
        if let statusString = try? container.decode(String.self, forKey: .status),
           let parsedStatus = LegStatus(rawValue: statusString) {
            status = parsedStatus
        } else {
            status = .active  // Default for legacy data
        }
        
        // Scheduled times (optional)
        scheduledOut = try? container.decode(Date.self, forKey: .scheduledOut)
        scheduledIn = try? container.decode(Date.self, forKey: .scheduledIn)
        scheduledFlightNumber = try? container.decode(String.self, forKey: .scheduledFlightNumber)
        scheduledBlockMinutesFromRoster = try? container.decode(Int.self, forKey: .scheduledBlockMinutesFromRoster)
        rosterSourceId = try? container.decode(String.self, forKey: .rosterSourceId)
        
        // NOC roster fields (optional)
        nocUID = try? container.decode(String.self, forKey: .nocUID)
        nocTimestamp = try? container.decode(Date.self, forKey: .nocTimestamp)
        isLastLegOfTrip = (try? container.decode(Bool.self, forKey: .isLastLegOfTrip)) ?? false
        tripGroupId = try? container.decode(String.self, forKey: .tripGroupId)
        checkInTime = try? container.decode(Date.self, forKey: .checkInTime)
        checkOutTime = try? container.decode(Date.self, forKey: .checkOutTime)
        scheduledDeparture = try? container.decode(Date.self, forKey: .scheduledDeparture)
        scheduledArrival = try? container.decode(Date.self, forKey: .scheduledArrival)
        scheduledFlightMinutes = try? container.decode(Int.self, forKey: .scheduledFlightMinutes)
        aircraftType = try? container.decode(String.self, forKey: .aircraftType)
        tailNumber = try? container.decode(String.self, forKey: .tailNumber)
        
        // Deadhead fields
        deadheadOutTime = (try? container.decode(String.self, forKey: .deadheadOutTime)) ?? ""
        deadheadInTime = (try? container.decode(String.self, forKey: .deadheadInTime)) ?? ""
        deadheadFlightHours = (try? container.decode(Double.self, forKey: .deadheadFlightHours)) ?? 0.0
        
        // Pilot role with fallback
        if let roleString = try? container.decode(String.self, forKey: .legPilotRole),
           let parsedRole = LegPilotRole(rawValue: roleString) {
            legPilotRole = parsedRole
        } else {
            legPilotRole = .notSet
        }
        
        // Night operations
        nightTakeoff = (try? container.decode(Bool.self, forKey: .nightTakeoff)) ?? false
        nightLanding = (try? container.decode(Bool.self, forKey: .nightLanding)) ?? false

        // GPS Track data
        trackData = try? container.decode(Data.self, forKey: .trackData)
        hasRecordedTrack = (try? container.decode(Bool.self, forKey: .hasRecordedTrack)) ?? false
    }

    var isValid: Bool {
        return !departure.isEmpty && !arrival.isEmpty &&
               (!outTime.isEmpty || !inTime.isEmpty ||
                !deadheadOutTime.isEmpty || !deadheadInTime.isEmpty ||
                deadheadFlightHours > 0)
    }

    // MARK: - Fingerprint for Duplicate Detection

    /// Creates a unique fingerprint based on flight characteristics for duplicate detection.
    /// This allows matching flights from different sources (RAIDO, NOC, backup) even if they have different UUIDs.
    /// Format: "DATE|DEP-ARR|FLIGHTNUM|OUT|IN" e.g., "2024-01-03|KYIP-KLRD|UJ1302|1535|1910"
    var fingerprint: String {
        let dateStr: String
        if let date = flightDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            dateStr = formatter.string(from: date)
        } else {
            dateStr = "nodate"
        }

        // Normalize times - strip whitespace and newlines
        let normalizedOut = outTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIn = inTime.trimmingCharacters(in: .whitespacesAndNewlines)

        // For deadheads, use deadhead times
        let effectiveOut = isDeadhead ? deadheadOutTime.trimmingCharacters(in: .whitespacesAndNewlines) : normalizedOut
        let effectiveIn = isDeadhead ? deadheadInTime.trimmingCharacters(in: .whitespacesAndNewlines) : normalizedIn

        return "\(dateStr)|\(departure)-\(arrival)|\(flightNumber)|\(effectiveOut)|\(effectiveIn)"
    }

    /// Creates a relaxed fingerprint that ignores exact times - useful for matching scheduled vs actual flights.
    /// Format: "DATE|DEP-ARR|FLIGHTNUM" e.g., "2024-01-03|KYIP-KLRD|UJ1302"
    var relaxedFingerprint: String {
        let dateStr: String
        if let date = flightDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            dateStr = formatter.string(from: date)
        } else {
            dateStr = "nodate"
        }
        return "\(dateStr)|\(departure)-\(arrival)|\(flightNumber)"
    }

    /// Checks if this leg matches another leg by flight characteristics (not UUID).
    /// Uses relaxed matching: same date, city pair, and flight number.
    func matchesFlight(_ other: FlightLeg) -> Bool {
        // Must have same city pair
        guard departure == other.departure && arrival == other.arrival else { return false }

        // Must have same or similar flight number (handle empty flight numbers)
        let flightNumMatch = flightNumber == other.flightNumber ||
                            flightNumber.isEmpty || other.flightNumber.isEmpty

        guard flightNumMatch else { return false }

        // Must be on same date (within same calendar day)
        if let date1 = flightDate, let date2 = other.flightDate {
            let calendar = Calendar(identifier: .gregorian)
            return calendar.isDate(date1, inSameDayAs: date2)
        }

        // If no dates, can't match
        return false
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
    /// Prefers BLH (scheduledBlockMinutesFromRoster) if available, otherwise calculates from STD/STA
    var scheduledBlockMinutes: Int? {
        // Prefer the explicit BLH from roster if available (more accurate)
        if let blh = scheduledBlockMinutesFromRoster {
            return blh
        }
        // Fallback to calculating from scheduled times (less accurate - uses flight time not block)
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

    /// Threshold in minutes for flagging block time mismatch (default 5 minutes)
    static let blockTimeMismatchThreshold: Int = 5

    /// Returns true if actual block time differs from scheduled by more than threshold
    /// Used to flag legs that need review
    var hasBlockTimeMismatch: Bool {
        guard let variance = blockTimeVarianceMinutes else { return false }
        return abs(variance) > FlightLeg.blockTimeMismatchThreshold
    }

    /// Severity of block time mismatch for UI display
    var blockTimeMismatchSeverity: MismatchSeverity {
        guard let variance = blockTimeVarianceMinutes else { return .none }
        let absVariance = abs(variance)
        if absVariance <= FlightLeg.blockTimeMismatchThreshold {
            return .none
        } else if absVariance <= 15 {
            return .minor  // 6-15 minutes off
        } else if absVariance <= 30 {
            return .moderate  // 16-30 minutes off
        } else {
            return .significant  // >30 minutes off
        }
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

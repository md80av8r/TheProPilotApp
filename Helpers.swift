import SwiftUI
import Foundation

struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    func displayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - CONSOLIDATED: FlightLeg Validation Functions
extension FlightLeg {
    /// Validate a \
    ///  string in HHMM or HMM format.
    public static func isValidTime(_ timeString: String) -> Bool {
        let digits = timeString.filter { $0.isWholeNumber }
        guard digits.count >= 3 else { return false }
        
        // Pad to 4 digits if needed (e.g. "800" -> "0800")
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        guard let hh = Int(padded.prefix(2)),
              let mm = Int(padded.suffix(2)) else { return false }
        
        return (0..<24).contains(hh) && (0..<60).contains(mm)
    }

    /// Convert an HHMM/HMM GMT time string to a Date on the given flight date.
    public static func parseGMTTimeToDate(_ timeString: String, on flightDate: Date) -> Date? {
        let digits = timeString.filter { $0.isWholeNumber }
        guard digits.count >= 3 else { return nil }
        
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        guard let hh = Int(padded.prefix(2)),
              let mm = Int(padded.suffix(2)),
              (0..<24).contains(hh), (0..<60).contains(mm) else { return nil }
        
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: flightDate)
        comps.hour = hh
        comps.minute = mm
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "GMT")
        
        return Calendar.current.date(from: comps)
    }
}

extension Array where Element == Trip {
    func groupedByMonth() -> [(String, [Trip])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { (trip) -> YearMonth in
            let comps = calendar.dateComponents([.year, .month], from: trip.date)
            return YearMonth(year: comps.year ?? 0, month: comps.month ?? 0)
        }
        let sortedKeys = grouped.keys.sorted()
        return sortedKeys.map { key in
            let trips = grouped[key]?.sorted { $0.date < $1.date } ?? []
            return (key.displayString(), trips)
        }
    }

    func totalBlockMinutes() -> Int {
        self.flatMap { $0.legs }.reduce(0) { $0 + $1.blockMinutes() }
    }

    func totalBlockMinutes(forYear year: Int) -> Int {
        self.filter { Calendar.current.component(.year, from: $0.date) == year }
            .totalBlockMinutes()
    }
    
    var allLegs: [FlightLeg] {
        self.flatMap { $0.legs }
    }
}

func formatPerDiemDuration(_ minutes: Int) -> String {
    let days = minutes / 1440
    let hours = (minutes % 1440) / 60
    let mins = minutes % 60
    if days > 0 {
        return String(format: "%dd %dh %02dm", days, hours, mins)
    } else if hours > 0 {
        return String(format: "%dh %02dm", hours, mins)
    } else {
        return String(format: "%dm", mins)
    }
}

func perDiemTotal(for trips: [Trip], rate: Double) -> (minutes: Int, dollars: Double) {
    let minutes = trips.reduce(0, { $0 + ($1.perDiemMinutes ?? 0) })
    let dollars = Double(minutes) / 60.0 * rate
    return (minutes, dollars)
}

func formatDuration(_ totalMin: Int) -> String {
    let hours = totalMin / 60
    let minutes = totalMin % 60
    return "\(hours)+\(String(format: "%02d", minutes))"
}

func formatLogbookTotal(minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return String(format: "%d:%02d", h, m)
}

func formatTimeInput(_ raw: String) -> String {
    let digits = raw.filter(\.isWholeNumber)
    let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
    let h = padded.prefix(2)
    let m = padded.suffix(2)
    return "\(h):\(m)"
}

func tatStartMinutes(_ s: String) -> Int {
    let digits = s.filter(\.isWholeNumber)
    if digits.count < 3 { return 0 }
    let mins = Int(digits.suffix(2)) ?? 0
    let hrs = Int(digits.dropLast(2)) ?? 0
    return hrs * 60 + mins
}

extension Int {
    var asLogbookTotal: String {
        let h = self / 60
        let m = self % 60
        return String(format: "%d+%02d", h, m)
    }
}

// MARK: - Time Utilities
struct TimeUtils {
    static func parseTAT(_ tat: String) -> Int? {
        let components = tat.split(separator: "+")
        guard let base = Int(components.first ?? "") else { return nil }
        let extra = components.count > 1 ? Int(components[1]) ?? 0 : 0
        return base * 60 + extra
    }

    static func formatTAT(_ value: Int) -> String {
        let hours = value / 60
        let minutes = value % 60
        return "\(hours)+\(String(format: "%02d", minutes))"
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02dh %02dm", h, m)
    }
}

// MARK: - Display Settings
class DisplaySettingsStore: ObservableObject {
    @Published var settings = DisplaySettings()
    
    private let userDefaults = UserDefaults.shared
    private let settingsKey = "DisplaySettings"
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(DisplaySettings.self, from: data) {
            settings = decoded
        }
    }
}

struct DisplaySettings: Codable {
    var timeDisplayFormat: TimeDisplayFormat = .hoursMinutes
}

enum TimeDisplayFormat: String, CaseIterable, Codable {
    case hoursMinutes = "hoursMinutes"
    case decimalHours = "decimalHours"
    
    var displayName: String {
        switch self {
        case .hoursMinutes: return "Hours+Minutes"
        case .decimalHours: return "Decimal Hours"
        }
    }
}

// MARK: - Time Display Formatting
func formatTimeDisplay(_ totalMinutes: Int, format: TimeDisplayFormat) -> String {
    switch format {
    case .hoursMinutes:
        return formatDuration(totalMinutes)
    case .decimalHours:
        let hours = Double(totalMinutes) / 60.0
        return String(format: "%.1f", hours)
    }
}

// ==========================================================
// MARK: - CONSOLIDATED: Time Validation (replaces private isValidZuluTime)
// ==========================================================
@inline(__always)
private func isValidZuluTime(_ timeString: String) -> Bool {
    // UPDATED: Use the public FlightLeg.isValidTime function
    return FlightLeg.isValidTime(timeString)
}

// ==========================================================
// MARK: - ENHANCED Per Diem Logic with Start/End Times for Company Portal Entry
// ==========================================================

/// Represents a continuous per diem period (away from home base) with detailed timing info
struct PerDiemPeriod {
    let startTrip: Trip
    let endTrip: Trip?  // nil if still ongoing
    let trips: [Trip]   // all trips in this period
    let startTime: Date // When period started (actual block out time)
    let endTime: Date?  // When period ended, nil if still ongoing
    
    var minutes: Int {
        let end = endTime ?? Date() // Current time if still ongoing
        return Int(end.timeIntervalSince(startTime) / 60)
    }
    
    var isOngoing: Bool {
        return endTime == nil
    }
    
    // ADDED: Company portal entry helpers
    var startDateForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: startTime)
    }
    
    var startTimeForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: startTime) + "Z"
    }
    
    var endDateForPortal: String? {
        guard let endTime = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: endTime)
    }
    
    var endTimeForPortal: String? {
        guard let endTime = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: endTime) + "Z"
    }
    
    var portalEntryString: String {
        if let endDate = endDateForPortal, let endTime = endTimeForPortal {
            return "Start: \(startDateForPortal) \(startTimeForPortal) | End: \(endDate) \(endTime)"
        } else {
            return "Start: \(startDateForPortal) \(startTimeForPortal) | Ongoing"
        }
    }
}

/// Represents a portion of a per diem period within a specific month
struct MonthlyPerDiemPortion {
    let originalPeriod: PerDiemPeriod
    let monthStartDate: Date
    let monthEndDate: Date
    let portionStartDate: Date
    let portionEndDate: Date
    let trips: [Trip]
    
    var minutes: Int {
        return Int(portionEndDate.timeIntervalSince(portionStartDate) / 60)
    }
    
    var formattedDuration: String {
        return formatPerDiemDuration(minutes)
    }
    
    func perDiemAmount(rate: Double) -> Double {
        let hours = Double(minutes) / 60.0
        return hours * rate
    }
    
    // ADDED: Company portal entry helpers for month portions
    var portionStartDateForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: portionStartDate)
    }
    
    var portionStartTimeForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: portionStartDate) + "Z"
    }
    
    var portionEndDateForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: portionEndDate)
    }
    
    var portionEndTimeForPortal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: portionEndDate) + "Z"
    }
    
    var portionPortalEntryString: String {
        let isOngoing = originalPeriod.isOngoing && portionEndDate >= (originalPeriod.endTime ?? Date())
        if isOngoing {
            return "Start: \(portionStartDateForPortal) \(portionStartTimeForPortal) | Ongoing"
        } else {
            return "Start: \(portionStartDateForPortal) \(portionStartTimeForPortal) | End: \(portionEndDateForPortal) \(portionEndTimeForPortal)"
        }
    }
}

/// CORRECTED: Calculates continuous per diem periods using actual block out/in times
func calculatePerDiemPeriods(trips: [Trip], homeBase: String) -> [PerDiemPeriod] {
    let sortedTrips = trips.sorted { $0.date < $1.date }
    var periods: [PerDiemPeriod] = []
    var currentPeriodTrips: [Trip] = []
    var currentPeriodStartTime: Date?
    var isAwayFromBase = false
    
    for trip in sortedTrips {
        // Check each leg in the trip
        for leg in trip.legs {
            let departure = leg.departure.uppercased()
            let arrival = leg.arrival.uppercased()
            
            // Starting a new period - departing from home base
            if departure.matchesHomeBase(homeBase) && !isAwayFromBase {
                // End any previous period first
                if !currentPeriodTrips.isEmpty, let startTime = currentPeriodStartTime {
                    let period = PerDiemPeriod(
                        startTrip: currentPeriodTrips.first!,
                        endTrip: currentPeriodTrips.last!,
                        trips: currentPeriodTrips,
                        startTime: startTime,
                        endTime: getPreviousArrivalTime(currentPeriodTrips.last!, homeBase: homeBase)
                    )
                    periods.append(period)
                }
                
                // Start new period - CORRECTED: Use actual block out time
                currentPeriodTrips = [trip]
                currentPeriodStartTime = getDepartureTime(trip, leg: leg)
                isAwayFromBase = true
                // DEBUG: Commented out excessive print statement
                // print("Per diem started at block out: \(departure) on \(trip.date)")
                
            // Ending current period - arriving at home base
            } else if arrival.matchesHomeBase(homeBase) && isAwayFromBase {
                // Add this trip to current period
                if !currentPeriodTrips.contains(where: { $0.id == trip.id }) {
                    currentPeriodTrips.append(trip)
                }
                
                // Check if this is truly the end (no subsequent departures from home in same trip)
                let hasSubsequentDeparture = trip.legs.contains { laterLeg in
                    laterLeg.departure.matchesHomeBase(homeBase) && laterLeg != leg
                }
                
                if !hasSubsequentDeparture {
                    // End the period
                    if let startTime = currentPeriodStartTime {
                        let endTime = getArrivalTime(trip, leg: leg) ?? trip.date
                        let period = PerDiemPeriod(
                            startTrip: currentPeriodTrips.first!,
                            endTrip: trip,
                            trips: currentPeriodTrips,
                            startTime: startTime,
                            endTime: endTime
                        )
                        periods.append(period)
                        // DEBUG: Commented out excessive print statement
                        // print("Per diem ended at block in: \(arrival) on \(trip.date)")
                    }
                    
                    // Reset
                    currentPeriodTrips = []
                    currentPeriodStartTime = nil
                    isAwayFromBase = false
                }
                
            // Continue existing period
            } else if isAwayFromBase {
                if !currentPeriodTrips.contains(where: { $0.id == trip.id }) {
                    currentPeriodTrips.append(trip)
                }
            }
        }
    }
    
    // Handle ongoing period (still away from base)
    if !currentPeriodTrips.isEmpty, let startTime = currentPeriodStartTime, isAwayFromBase {
        let period = PerDiemPeriod(
            startTrip: currentPeriodTrips.first!,
            endTrip: nil,
            trips: currentPeriodTrips,
            startTime: startTime,
            endTime: nil
        )
        periods.append(period)
        // DEBUG: Commented out excessive print statement
        // print("Ongoing per diem period detected (started at actual block out time)")
    }
    
    return periods
}

/// Helper: Get departure time from a trip/leg, with fallbacks - CORRECTED to use actual times
private func getDepartureTime(_ trip: Trip, leg: FlightLeg) -> Date? {
    // Try to parse OUT time first (actual block out time)
    if !leg.outTime.isEmpty && leg.outTime != "N/A" {
        return parseTimeFromTrip(leg.outTime, trip: trip)
    }
    
    // Fallback to trip's TAT start time
    if !trip.tatStart.isEmpty && trip.tatStart != "N/A" {
        return parseTimeFromTrip(trip.tatStart, trip: trip)
    }
    
    // Final fallback to trip date
    return trip.date
}

/// Helper: Get arrival time from a trip/leg, with fallbacks - uses actual block in time
private func getArrivalTime(_ trip: Trip, leg: FlightLeg) -> Date? {
    // Try to parse IN time first (actual block in time)
    if !leg.inTime.isEmpty && leg.inTime != "N/A" {
        return parseTimeFromTrip(leg.inTime, trip: trip)
    }
    
    // Fallback to trip date (assume end of day)
    var components = Calendar.current.dateComponents([.year, .month, .day], from: trip.date)
    components.hour = 23
    components.minute = 59
    return Calendar.current.date(from: components)
}

/// Helper: Get the arrival time of the last trip at home base
private func getPreviousArrivalTime(_ trip: Trip, homeBase: String) -> Date? {
    // Find the last leg that arrives at home base
    for leg in trip.legs.reversed() {
        if leg.arrival.matchesHomeBase(homeBase) {
            return getArrivalTime(trip, leg: leg)
        }
    }
    return trip.date
}

/// Helper: Parse time string and combine with trip date
private func parseTimeFromTrip(_ timeString: String, trip: Trip) -> Date? {
    guard timeString.count >= 3 && timeString != "N/A" else { return nil }
    
    let digits = timeString.filter { $0.isWholeNumber }
    guard digits.count >= 3 else { return nil }
    
    let padded = digits.count < 4
        ? String(repeating: "0", count: 4 - digits.count) + digits
        : String(digits.prefix(4))
    
    guard let hour = Int(padded.prefix(2)),
          let minute = Int(padded.suffix(2)),
          hour < 24, minute < 60 else { return nil }
    
    var components = Calendar.current.dateComponents([.year, .month, .day], from: trip.date)
    components.hour = hour
    components.minute = minute
    components.timeZone = TimeZone(identifier: "UTC")
    
    return Calendar.current.date(from: components)
}

/// Calculate per diem start time in UTC - CORRECTED: Uses actual block out time
func tripCalculatePerDiemStartUTC(trip: Trip) -> Date? {
    guard let firstLeg = trip.legs.first,
          FlightLeg.isValidTime(firstLeg.outTime) else { return nil }
    
    return FlightLeg.parseGMTTimeToDate(firstLeg.outTime, on: trip.date)
}

/// Calculate per diem end time in UTC - uses actual block in time
func tripCalculatePerDiemEndUTC(trip: Trip, homeBase: String) -> Date? {
    guard !trip.legs.isEmpty else { return nil }
    
    // Find the last leg that arrives at home base with no subsequent departure
    for (index, leg) in trip.legs.enumerated().reversed() {
        if leg.arrival.matchesHomeBase(homeBase) {
            // Check if this is truly the end (no subsequent leg departing from home base)
            let hasSubsequentDeparture = trip.legs.indices.contains(index + 1) &&
                trip.legs[index + 1].departure.matchesHomeBase(homeBase)
            
            if !hasSubsequentDeparture && FlightLeg.isValidTime(leg.inTime) {
                return FlightLeg.parseGMTTimeToDate(leg.inTime, on: trip.date)
            }
        }
    }
    
    return nil // Trip doesn't end at home base
}

/// ENHANCED: Group per diem periods by month, splitting cross-month periods
func groupPeriodsByMonthEnhanced(periods: [PerDiemPeriod]) -> [(String, [MonthlyPerDiemPortion])] {
    var monthlyPortions: [YearMonth: [MonthlyPerDiemPortion]] = [:]
    
    for period in periods {
        let portions = splitPeriodAcrossMonths(period: period)
        
        for portion in portions {
            let yearMonth = YearMonth(
                year: Calendar.current.component(.year, from: portion.monthStartDate),
                month: Calendar.current.component(.month, from: portion.monthStartDate)
            )
            
            if monthlyPortions[yearMonth] == nil {
                monthlyPortions[yearMonth] = []
            }
            monthlyPortions[yearMonth]?.append(portion)
        }
    }
    
    let sortedKeys = monthlyPortions.keys.sorted()
    return sortedKeys.map { key in
        let portions = monthlyPortions[key]?.sorted { $0.portionStartDate < $1.portionStartDate } ?? []
        return (key.displayString(), portions)
    }
}

/// Split a per diem period across multiple months - 00Z ONLY used for month boundary splitting
private func splitPeriodAcrossMonths(period: PerDiemPeriod) -> [MonthlyPerDiemPortion] {
    var portions: [MonthlyPerDiemPortion] = []
    let calendar = Calendar.current
    
    let startDate = period.startTime
    let endDate = period.endTime ?? Date()
    
    // Get start of first month and iterate through months
    var currentMonthStart = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate
    
    while currentMonthStart < endDate {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonthStart) else { break }
        
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        
        // Calculate the portion of the period that falls within this month
        // IMPORTANT: For cross-month periods, the portion in a new month starts at 00:00Z of that month
        // but ONLY for the portion calculation, not the original period
        let portionStart: Date
        if startDate >= monthStart {
            // Period started this month - use actual start time
            portionStart = startDate
        } else {
            // Period started in previous month - portion starts at 00:00Z of this month
            var components = calendar.dateComponents([.year, .month, .day], from: monthStart)
            components.hour = 0
            components.minute = 0
            components.second = 0
            components.timeZone = TimeZone(identifier: "UTC")
            portionStart = calendar.date(from: components) ?? monthStart
        }
        
        let portionEnd = min(endDate, monthEnd)
        
        // Only create a portion if there's actual time in this month
        if portionStart < portionEnd {
            let portion = MonthlyPerDiemPortion(
                originalPeriod: period,
                monthStartDate: monthStart,
                monthEndDate: monthEnd,
                portionStartDate: portionStart,
                portionEndDate: portionEnd,
                trips: period.trips
            )
            portions.append(portion)
        }
        
        // Move to next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else { break }
        currentMonthStart = nextMonth
    }
    
    return portions
}

/// ENHANCED: Format date range that might be within the same month
func formatCrossMonthDateRange(start: Date, end: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current
    
    let startMonth = calendar.component(.month, from: start)
    let endMonth = calendar.component(.month, from: end)
    let startYear = calendar.component(.year, from: start)
    let endYear = calendar.component(.year, from: end)
    
    if startMonth == endMonth && startYear == endYear {
        // Same month - show day range
        formatter.dateFormat = "MMM d"
        let startString = formatter.string(from: start)
        formatter.dateFormat = "d"
        let endString = formatter.string(from: end)
        return "\(startString) → \(endString)"
    } else {
        // Different months - show full dates
        formatter.dateFormat = "MMM d"
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        return "\(startString) → \(endString)"
    }
}

/// FIXED: Gets the current ongoing per diem period (if any)
func getCurrentPerDiemPeriod(trips: [Trip], homeBase: String) -> PerDiemPeriod? {
    let periods = calculatePerDiemPeriods(trips: trips, homeBase: homeBase)
    return periods.first { $0.isOngoing }
}

/// FIXED: Calculates total per diem minutes for a specific month
func calculateMonthlyPerDiem(trips: [Trip], homeBase: String, rate: Double) -> (minutes: Int, dollars: Double) {
    let periods = calculatePerDiemPeriods(trips: trips, homeBase: homeBase)
    
    let totalMinutes = periods.reduce(0) { total, period in
        return total + period.minutes
    }
    
    let totalDollars = Double(totalMinutes) / 60.0 * rate
    return (totalMinutes, totalDollars)
}

/// Gets per diem info for a specific trip (part of which period?)
func getPerDiemInfoForTrip(trip: Trip, allTrips: [Trip], homeBase: String) -> (minutes: Int, isOngoing: Bool)? {
    let periods = calculatePerDiemPeriods(trips: allTrips, homeBase: homeBase)
    
    // Find which period this trip belongs to
    for period in periods {
        if period.trips.contains(where: { $0.id == trip.id }) {
            return (period.minutes, period.isOngoing)
        }
    }
    
    return nil // Trip not part of any per diem period
}

/// FIXED: Gets per diem display text for a trip
func getPerDiemDisplayText(trip: Trip, allTriips: [Trip], homeBase: String, rate: Double) -> String? {
    let periods = calculatePerDiemPeriods(trips: allTriips, homeBase: homeBase)
    
    // Find which period this trip belongs to
    guard let period = periods.first(where: { $0.trips.contains { $0.id == trip.id } }),
          period.minutes > 0 else { return nil }
    
    let hours = Double(period.minutes) / 60.0
    let dollars = hours * rate
    let timeText = formatPerDiemDuration(period.minutes)
    
    if period.isOngoing {
        return "🔴 Away: \(timeText) • $\(String(format: "%.2f", dollars))"
    } else {
        return "Away: \(timeText) • $\(String(format: "%.2f", dollars))"
    }
}

// MARK: - Helper Functions for Period Grouping

private func groupPeriodsByMonth(periods: [PerDiemPeriod]) -> [(String, [PerDiemPeriod])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: periods) { period -> YearMonth in
        let comps = calendar.dateComponents([.year, .month], from: period.startTime)
        return YearMonth(year: comps.year ?? 0, month: comps.month ?? 0)
    }
    let sortedKeys = grouped.keys.sorted()
    return sortedKeys.map { key in
        let periods = grouped[key]?.sorted { $0.startTime < $1.startTime } ?? []
        return (key.displayString(), periods)
    }
}

// MARK: - Enhanced Home Base Matching Extension
extension String {
    func matchesHomeBase(_ homeBase: String) -> Bool {
        let selfUpper = self.uppercased()
        let homeUpper = homeBase.uppercased()
        
        // Direct match
        if selfUpper == homeUpper { return true }
        
        // Handle K prefix variations (KYIP vs YIP)
        let cleanSelf = selfUpper.replacingOccurrences(of: "K", with: "")
        let cleanHome = homeUpper.replacingOccurrences(of: "K", with: "")
        
        return cleanSelf == cleanHome ||
               selfUpper.contains(cleanHome) ||
               cleanSelf.contains(homeUpper.replacingOccurrences(of: "K", with: ""))
    }
}

// MARK: - CSV Import Helpers
/// Extract airline code from flight number (e.g., "UJ627" -> "UJ")
func extractAirlineFromTripNumber(_ tripNumber: String) -> String {
    let letters = tripNumber.filter { $0.isLetter }
    return letters.isEmpty ? "Unknown" : String(letters)
}

// MARK: - FileManager helpers (used by DocumentStore, Scanner, etc.)
extension FileManager {
    /// App's Documents directory URL.
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Create the directory if it doesn't exist.
    static func createDirectoryIfNeeded(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("FileManager.createDirectoryIfNeeded:", error)
            }
        }
    }

    /// Ensure a nested subdirectory under Documents and return it.
    /// Example: let pdfs = FileManager.appSubdirectory(["Scanner", "PDFs"])
    static func appSubdirectory(_ components: [String]) -> URL {
        let base = getDocumentsDirectory()
        let dir = components.reduce(base) { $0.appendingPathComponent($1) }
        createDirectoryIfNeeded(at: dir)
        return dir
    }
}

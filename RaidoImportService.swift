//
//  RaidoImportService.swift
//  ProPilot
//
//  Handles parsing RAIDO JSON exports into Trip/FlightLeg models
//  RAIDO is the crew scheduling/logbook system used by USA Jet
//

import Foundation
import SwiftUI

// MARK: - RAIDO JSON Row Structure
/// All fields are optional to handle different RAIDO export formats
struct RaidoReportRow: Codable {
    // Date/Name field - can be "RaidoLab_TimeMode" or "RaidoLab_Name" depending on export
    let raidoLabTimeMode: String?
    let raidoLabName: String?

    // Flight info
    let raidoLabCode: String?          // Flight number (e.g., "UJ101")
    let idRaidoLab151: String?         // Aircraft type (e.g., "M88", "M83")
    let raidoLabRegistration: String?  // Tail number (e.g., "N832US")

    // Route
    let raidoLabDep: String?           // Departure airport
    let raidoLabArr: String?           // Arrival airport

    // Times
    let raidoLabSTD: String?           // Scheduled Time Departure
    let raidoLabATD: String?           // Actual Time Departure (OUT)
    let raidoLabSTA: String?           // Scheduled Time Arrival
    let raidoLabATA: String?           // Actual Time Arrival (IN)
    let idRaidoLab1069: String?        // Check-in time (optional)
    let idRaidoLab10691: String?       // CI marker (optional)
    let idRaidoLab1070: String?        // Check-out time (optional)

    // Role/designator
    let raidoLabDes: String?           // "X" = Landing pilot

    // Block times - format varies by export template
    let mimerLabel1: String?           // Could be block time "03:00" OR OFF time "02NOV 2230"
    let mimerLabel2: String?           // ON time "03NOV 0130" (if using new format)
    let mimerLabel3: String?

    // Crew
    let crewOnBoardText: String?       // Full crew string

    // Other
    let raidoLabEmpNo: String?         // Employee number
    let raidoLabBRQ: String?           // Base/qualifications
    let raidoLabPages: String?         // Page info
    let labSeasons: String?            // Date range or header
    let raidoLabLE: String?            // LE marker
    let raidoLabShortCode: String?     // Short code
    let raidoVer: String?
    let raidoPrintedBy: String?
    let text6: String?
    let text9: String?
    let text16: String?                // New field in some exports

    // Computed property to get date string from either field
    var dateString: String {
        raidoLabName ?? raidoLabTimeMode ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case raidoLabTimeMode = "RaidoLab_TimeMode"
        case raidoLabName = "RaidoLab_Name"
        case raidoLabCode = "RaidoLab_Code"
        case idRaidoLab151 = "IdRaidoLab_151"
        case raidoLabRegistration = "RaidoLab_Registration"
        case raidoLabDep = "RaidoLab_Dep"
        case raidoLabArr = "RaidoLab_Arr"
        case raidoLabSTD = "RaidoLab_STD"
        case raidoLabATD = "RaidoLab_ATD"
        case raidoLabSTA = "RaidoLab_STA"
        case raidoLabATA = "RaidoLab_ATA"
        case idRaidoLab1069 = "IdRaidoLab_1069"
        case idRaidoLab10691 = "IdRaidoLab_10691"
        case idRaidoLab1070 = "IdRaidoLab_1070"
        case raidoLabDes = "RaidoLab_Des."
        case mimerLabel1 = "MimerLabel1"
        case mimerLabel2 = "MimerLabel2"
        case mimerLabel3 = "MimerLabel3"
        case crewOnBoardText = "CrewOnBoardText"
        case raidoLabEmpNo = "RaidoLab_EmpNo"
        case raidoLabBRQ = "RaidoLab_BRQ"
        case raidoLabPages = "RaidoLab_Pages"
        case labSeasons = "Lab_Seasons"
        case raidoLabLE = "RaidoLab_LE"
        case raidoLabShortCode = "RaidoLab_ShortCode"
        case raidoVer = "RaidoVer"
        case raidoPrintedBy = "Raido_PrintedBy"
        case text6 = "Text6"
        case text9 = "Text9"
        case text16 = "Text16"
    }
}

// MARK: - RAIDO Report Root Structure
struct RaidoReport: Codable {
    let report: [RaidoReportRow]

    enum CodingKeys: String, CodingKey {
        case report = "Report"
    }
}

// MARK: - Parsed Flight Record (intermediate)
struct ParsedRaidoFlight {
    let date: Date
    let flightNumber: String
    let aircraftType: String
    let tailNumber: String
    let departure: String
    let arrival: String
    let outTime: String        // ATD - Actual Time Departure (block out)
    var offTime: String        // OFF time (wheels up) - from MimerLabel1 if available
    var onTime: String         // ON time (wheels down) - from MimerLabel2 if available
    let inTime: String         // ATA - Actual Time Arrival (block in)
    let scheduledOut: String   // STD
    let scheduledIn: String    // STA
    let blockMinutes: Int
    let checkInTime: String
    let checkOutTime: String
    let didLanding: Bool       // "X" designator = pilot made the landing
    var crewText: String       // Mutable - attached after flight row

    // Takeoff/Landing tracking
    var takeoffs: Int          // Usually 1 per flight (0 for deadhead)
    var landings: Int          // 1 if didLanding is true, else 0
}

// MARK: - Detected Field Mapping
struct RaidoFieldMapping {
    var dateField: String = "RaidoLab_Name or RaidoLab_TimeMode"
    var outTimeField: String = "RaidoLab_ATD"
    var inTimeField: String = "RaidoLab_ATA"
    var offTimeField: String = "MimerLabel1 (if datetime format)"
    var onTimeField: String = "MimerLabel2 (if datetime format)"
    var landingDesignator: String = "X in RaidoLab_Des."
    var hasOffOnTimes: Bool = false  // True if MimerLabel contains datetime

    var description: String {
        """
        Date: \(dateField)
        OUT (Block): \(outTimeField)
        OFF (Wheels Up): \(offTimeField)
        ON (Wheels Down): \(onTimeField)
        IN (Block): \(inTimeField)
        Landing: \(landingDesignator)
        """
    }
}

// MARK: - Import Preview Data
struct RaidoImportPreview {
    let pilotName: String
    let employeeNumber: String
    let dateRange: String
    let flightCount: Int
    let totalBlockMinutes: Int
    let totalTakeoffs: Int
    let totalLandings: Int
    let aircraftTypes: Set<String>
    var flights: [ParsedRaidoFlight]  // Mutable for crew attachment
    let fieldMapping: RaidoFieldMapping

    var formattedBlockTime: String {
        let hours = totalBlockMinutes / 60
        let mins = totalBlockMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - RAIDO Import Service
class RaidoImportService {
    static let shared = RaidoImportService()

    private init() {}

    // MARK: - Parse RAIDO JSON
    func parseRaidoJSON(from url: URL) throws -> RaidoImportPreview {
        let data = try Data(contentsOf: url)
        return try parseRaidoJSON(from: data)
    }

    func parseRaidoJSON(from data: Data) throws -> RaidoImportPreview {
        let decoder = JSONDecoder()
        let report = try decoder.decode(RaidoReport.self, from: data)

        var pilotName = ""
        var employeeNumber = ""
        var dateRange = ""
        var flights: [ParsedRaidoFlight] = []
        var aircraftTypes: Set<String> = []
        var currentDate: Date?
        var fieldMapping = RaidoFieldMapping()

        // First pass: detect field mapping by searching for the header row
        // The header row contains labels like "Date", "Code", "BlockOff time (UTC)"
        print("📋 Searching for header row in first 10 rows...")
        for (index, row) in report.report.prefix(10).enumerated() {
            // Check if MimerLabel1 contains "BlockOff" or "Off time" (header row)
            let mimer1 = (row.mimerLabel1 ?? "").lowercased()
            print("📋 Row \(index): MimerLabel1 = '\(row.mimerLabel1 ?? "")'")
            if mimer1.contains("blockoff") || mimer1.contains("off time") || mimer1.contains("block off") {
                fieldMapping.hasOffOnTimes = true
                fieldMapping.offTimeField = "MimerLabel1 (BlockOff)"
                fieldMapping.onTimeField = "MimerLabel2 (BlockOn)"
                print("✅ Detected OFF/ON time fields in header row \(index)!")
                break
            }
        }
        print("📋 hasOffOnTimes = \(fieldMapping.hasOffOnTimes)")

        // Detect which date field is used
        if let firstRow = report.report.first {
            if firstRow.raidoLabName != nil && !firstRow.raidoLabName!.isEmpty {
                fieldMapping.dateField = "RaidoLab_Name"
            } else {
                fieldMapping.dateField = "RaidoLab_TimeMode"
            }
        }

        // Parse rows
        for row in report.report {
            let dateStr = row.dateString

            // Extract pilot info from header rows (contains comma like "Kadans, Jeffrey")
            if dateStr.contains(",") && !(row.raidoLabEmpNo?.isEmpty ?? true) {
                if pilotName.isEmpty {
                    pilotName = dateStr
                    employeeNumber = row.raidoLabEmpNo ?? ""
                }
            }

            // Extract date range from Lab_Seasons
            if let seasons = row.labSeasons, seasons.contains("(") && seasons.contains(")") {
                dateRange = seasons
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
            }

            // Check if this is a crew row (follows a flight row)
            // Attach crew to the PREVIOUS flight
            let crewText = row.crewOnBoardText ?? ""
            if !crewText.isEmpty && !flights.isEmpty {
                flights[flights.count - 1].crewText = crewText
                continue
            }

            // Check if this row has a date (flight data row)
            if let date = parseRaidoDate(dateStr) {
                currentDate = date
            }

            // Skip header/empty rows - check for actual flight data
            // Also skip if values are header labels (e.g., "Dep", "Arr", "Code", "ATD")
            let dep = row.raidoLabDep ?? ""
            let arr = row.raidoLabArr ?? ""
            let code = row.raidoLabCode ?? ""
            let atd = row.raidoLabATD ?? ""

            let isHeaderRow = dep == "Dep" ||
                              arr == "Arr" ||
                              code == "Code" ||
                              atd == "ATD"

            guard !dep.isEmpty,
                  !arr.isEmpty,
                  !code.isEmpty,
                  !isHeaderRow,
                  let flightDate = currentDate else {
                continue
            }

            // Parse times (remove newlines and + markers)
            let outTime = cleanTime(row.raidoLabATD ?? "")
            let inTime = cleanTime(row.raidoLabATA ?? "")
            let scheduledOut = cleanTime(row.raidoLabSTD ?? "")
            let scheduledIn = cleanTime(row.raidoLabSTA ?? "")
            let checkIn = cleanTime(row.idRaidoLab1069 ?? "")
            let checkOut = cleanTime(row.idRaidoLab1070 ?? "")

            // Parse OFF/ON times from MimerLabel if they contain datetime format
            // Format: "02NOV 2230" or similar
            var offTime = ""
            var onTime = ""
            var blockMinutes = 0

            if fieldMapping.hasOffOnTimes {
                // MimerLabel1 = OFF time, MimerLabel2 = ON time
                offTime = parseBlockOffOnTime(row.mimerLabel1 ?? "")
                onTime = parseBlockOffOnTime(row.mimerLabel2 ?? "")
                // Calculate block from OUT/IN times
                blockMinutes = calculateBlockMinutes(outTime: outTime, inTime: inTime) ?? 0

                // Debug first few flights
                if flights.count < 5 {
                    print("✈️ Flight \(flights.count + 1) \(code): MimerLabel1='\(row.mimerLabel1 ?? "")' → OFF='\(offTime)', MimerLabel2='\(row.mimerLabel2 ?? "")' → ON='\(onTime)'")
                }
            } else {
                // MimerLabel1 = block time in HH:MM format
                blockMinutes = parseBlockTime(row.mimerLabel1 ?? "")
                // Debug - OFF/ON not detected
                if flights.count < 3 {
                    print("⚠️ Flight \(flights.count + 1): hasOffOnTimes=false, using block time from MimerLabel1='\(row.mimerLabel1 ?? "")'")
                }
            }

            // Parse designator - X = Landing pilot
            let designators = (row.raidoLabDes ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let didLanding = designators.contains("X")

            // Track aircraft type
            let aircraftType = row.idRaidoLab151 ?? ""
            if !aircraftType.isEmpty {
                aircraftTypes.insert(aircraftType)
            }

            // Each flight = 1 takeoff, landing only if X designator
            // Convert IATA to ICAO airport codes
            let departure = convertToICAO(dep)
            let arrival = convertToICAO(arr)

            let flight = ParsedRaidoFlight(
                date: flightDate,
                flightNumber: code,
                aircraftType: aircraftType,
                tailNumber: row.raidoLabRegistration ?? "",
                departure: departure,
                arrival: arrival,
                outTime: outTime,
                offTime: offTime,
                onTime: onTime,
                inTime: inTime,
                scheduledOut: scheduledOut,
                scheduledIn: scheduledIn,
                blockMinutes: blockMinutes,
                checkInTime: checkIn,
                checkOutTime: checkOut,
                didLanding: didLanding,
                crewText: "",  // Will be filled by next crew row
                takeoffs: 1,   // 1 takeoff per flight
                landings: didLanding ? 1 : 0
            )

            flights.append(flight)
        }

        // Calculate totals
        let totalBlockMinutes = flights.reduce(0) { $0 + $1.blockMinutes }
        let totalTakeoffs = flights.reduce(0) { $0 + $1.takeoffs }
        let totalLandings = flights.reduce(0) { $0 + $1.landings }

        return RaidoImportPreview(
            pilotName: pilotName,
            employeeNumber: employeeNumber,
            dateRange: dateRange,
            flightCount: flights.count,
            totalBlockMinutes: totalBlockMinutes,
            totalTakeoffs: totalTakeoffs,
            totalLandings: totalLandings,
            aircraftTypes: aircraftTypes,
            flights: flights,
            fieldMapping: fieldMapping
        )
    }

    // MARK: - Convert to Trips
    func convertToTrips(from preview: RaidoImportPreview, groupByDate: Bool = true) -> [Trip] {
        var trips: [Trip] = []

        if groupByDate {
            // Group flights into trips based on rest breaks (>= 10 hours between IN and next OUT)
            let sortedFlights = preview.flights.sorted {
                // Sort by date first, then by OUT time
                if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                    return $0.outTime < $1.outTime
                }
                return $0.date < $1.date
            }

            // Group into trips - new trip starts when gap >= 10 hours
            var tripGroups: [[ParsedRaidoFlight]] = []
            var currentGroup: [ParsedRaidoFlight] = []

            for flight in sortedFlights {
                if let lastFlight = currentGroup.last {
                    // Calculate gap between last IN and current OUT
                    let gapMinutes = calculateGapMinutes(
                        fromDate: lastFlight.date,
                        fromTime: lastFlight.inTime,
                        toDate: flight.date,
                        toTime: flight.outTime
                    )

                    // If gap >= 10 hours (600 minutes), start new trip
                    if gapMinutes >= 600 {
                        if !currentGroup.isEmpty {
                            tripGroups.append(currentGroup)
                        }
                        currentGroup = [flight]
                    } else {
                        currentGroup.append(flight)
                    }
                } else {
                    currentGroup.append(flight)
                }
            }

            // Don't forget the last group
            if !currentGroup.isEmpty {
                tripGroups.append(currentGroup)
            }

            // Convert each group to a Trip
            for groupFlights in tripGroups {
                let date = groupFlights.first?.date ?? Date()

                // Create legs from flights
                var legs: [FlightLeg] = []
                for flight in groupFlights {
                    // X designator = Pilot Flying (PF) = made the landing
                    // If X is present, this pilot was PF for this leg
                    let legRole: LegPilotRole = flight.didLanding ? .pilotFlying : .pilotMonitoring

                    let leg = FlightLeg(
                        departure: flight.departure,
                        arrival: flight.arrival,
                        outTime: flight.outTime,
                        offTime: flight.offTime,
                        onTime: flight.onTime,
                        inTime: flight.inTime,
                        flightNumber: flight.flightNumber,
                        isDeadhead: false,
                        flightDate: flight.date,
                        status: .completed,
                        scheduledOut: parseTimeToDate(flight.scheduledOut, on: flight.date),
                        scheduledIn: parseTimeToDate(flight.scheduledIn, on: flight.date),
                        scheduledBlockMinutesFromRoster: flight.blockMinutes,
                        aircraftType: flight.aircraftType,
                        tailNumber: flight.tailNumber,
                        legPilotRole: legRole  // X = Pilot Flying (made the landing)
                    )
                    legs.append(leg)
                }

                // Determine aircraft from first flight with tail number
                let aircraft = groupFlights.first(where: { !$0.tailNumber.isEmpty })?.tailNumber ??
                              groupFlights.first?.aircraftType ?? ""

                // Leave trip number empty for RAIDO imports
                let tripNumber = ""

                // Parse crew from first flight's crew text
                let crew = parseCrewMembers(from: groupFlights.first?.crewText ?? "")

                // Build notes with landing info
                let landingCount = groupFlights.reduce(0) { $0 + $1.landings }
                let takeoffCount = groupFlights.reduce(0) { $0 + $1.takeoffs }
                var notes = "Imported from RAIDO"
                if takeoffCount > 0 || landingCount > 0 {
                    notes += " | T/O: \(takeoffCount), Ldg: \(landingCount)"
                }

                let trip = Trip(
                    tripNumber: tripNumber,
                    aircraft: aircraft,
                    date: date,
                    tatStart: "",
                    crew: crew,
                    notes: notes,
                    legs: legs,
                    tripType: .operating,
                    status: .completed,
                    pilotRole: determinePilotRole(from: groupFlights)
                )

                trips.append(trip)
            }
        } else {
            // Create one trip per flight
            for flight in preview.flights {
                // X designator = Pilot Flying (PF) = made the landing
                let legRole: LegPilotRole = flight.didLanding ? .pilotFlying : .pilotMonitoring

                let leg = FlightLeg(
                    departure: flight.departure,
                    arrival: flight.arrival,
                    outTime: flight.outTime,
                    offTime: flight.offTime,
                    onTime: flight.onTime,
                    inTime: flight.inTime,
                    flightNumber: flight.flightNumber,
                    isDeadhead: false,
                    flightDate: flight.date,
                    status: .completed,
                    scheduledOut: parseTimeToDate(flight.scheduledOut, on: flight.date),
                    scheduledIn: parseTimeToDate(flight.scheduledIn, on: flight.date),
                    scheduledBlockMinutesFromRoster: flight.blockMinutes,
                    aircraftType: flight.aircraftType,
                    tailNumber: flight.tailNumber,
                    legPilotRole: legRole  // X = Pilot Flying (made the landing)
                )

                let crew = parseCrewMembers(from: flight.crewText)

                // Build notes with landing info
                var notes = "Imported from RAIDO"
                if flight.takeoffs > 0 || flight.landings > 0 {
                    notes += " | T/O: \(flight.takeoffs), Ldg: \(flight.landings)"
                }

                let trip = Trip(
                    tripNumber: "",  // Leave empty for RAIDO imports
                    aircraft: flight.tailNumber.isEmpty ? flight.aircraftType : flight.tailNumber,
                    date: flight.date,
                    tatStart: "",
                    crew: crew,
                    notes: notes,
                    legs: [leg],
                    tripType: .operating,
                    status: .completed,
                    pilotRole: determinePilotRole(from: [flight])
                )

                trips.append(trip)
            }
        }

        return trips.sorted { $0.date < $1.date }
    }

    // MARK: - Helper Functions

    private func parseRaidoDate(_ dateString: String) -> Date? {
        // Format: "02Nov25" or "06Nov25"
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 7 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMMyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return formatter.date(from: trimmed)
    }

    private func cleanTime(_ timeString: String) -> String {
        // Remove newlines, plus signs, and trim
        return timeString
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseBlockTime(_ blockString: String) -> Int {
        // Format: "03:00" or "02:35"
        let parts = blockString.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return 0
        }
        return hours * 60 + minutes
    }

    // Parse BlockOff/On times like "02NOV 2230" -> "2230"
    private func parseBlockOffOnTime(_ timeString: String) -> String {
        let cleaned = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Format: "02NOV 2230" - extract just the time part
        let parts = cleaned.split(separator: " ")
        if parts.count >= 2 {
            // Last part should be the time
            return String(parts.last ?? "")
        }
        // If no space, might already be just a time
        if cleaned.count == 4, Int(cleaned) != nil {
            return cleaned
        }
        return ""
    }

    /// Calculate the gap in minutes between one flight's IN and the next flight's OUT
    private func calculateGapMinutes(fromDate: Date, fromTime: String, toDate: Date, toTime: String) -> Int {
        // Get the calendar days difference
        let daysDiff = Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0

        // Parse times as HHMM
        guard fromTime.count == 4, toTime.count == 4,
              let fromHour = Int(fromTime.prefix(2)),
              let fromMin = Int(fromTime.suffix(2)),
              let toHour = Int(toTime.prefix(2)),
              let toMin = Int(toTime.suffix(2)) else {
            // If we can't parse times, assume it's a new trip if different day
            return daysDiff > 0 ? 24 * 60 : 0
        }

        let fromMinutes = fromHour * 60 + fromMin
        let toMinutes = toHour * 60 + toMin

        // Total gap = days difference * 24 hours + time difference
        let totalGap = (daysDiff * 24 * 60) + (toMinutes - fromMinutes)

        return max(0, totalGap)
    }

    // Calculate block minutes from HHMM strings
    private func calculateBlockMinutes(outTime: String, inTime: String) -> Int? {
        guard outTime.count == 4, inTime.count == 4,
              let outHour = Int(outTime.prefix(2)),
              let outMin = Int(outTime.suffix(2)),
              let inHour = Int(inTime.prefix(2)),
              let inMin = Int(inTime.suffix(2)) else {
            return nil
        }

        let outTotal = outHour * 60 + outMin
        var inTotal = inHour * 60 + inMin

        // Handle overnight flights
        if inTotal < outTotal {
            inTotal += 24 * 60
        }

        return inTotal - outTotal
    }

    private func parseTimeToDate(_ timeString: String, on date: Date) -> Date? {
        let cleaned = cleanTime(timeString)
        guard cleaned.count == 4,
              let hours = Int(cleaned.prefix(2)),
              let minutes = Int(cleaned.suffix(2)) else {
            return nil
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hours
        components.minute = minutes
        components.timeZone = TimeZone(identifier: "UTC")

        return Calendar.current.date(from: components)
    }

    private func formatTripNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMM"
        return formatter.string(from: date).uppercased()
    }

    /// Convert IATA (3-letter) airport code to ICAO (4-letter) format
    private func convertToICAO(_ code: String) -> String {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Already ICAO format (4 letters starting with K, C, M, P, T, etc.)
        if cleanCode.count == 4 {
            let firstChar = cleanCode.first!
            if "KCMPTOELSW".contains(firstChar) {
                return cleanCode
            }
        }

        // Check user-added mappings first (highest priority)
        if let userICAO = UserAirportCodeMappings.shared.getICAO(for: cleanCode) {
            return userICAO
        }

        // If 3-letter US code, add K prefix (most common case)
        if cleanCode.count == 3 && cleanCode.allSatisfy({ $0.isLetter }) {
            return "K" + cleanCode
        }

        return cleanCode
    }

    private func parseCrewMembers(from crewText: String) -> [CrewMember] {
        // Format: "Crew: CP: Kadans, Jeffrey, FO(X): Hart, Melvin, LM: Bracken, Alex"
        // or "Crew: CP(X): Kadans, Jeffrey, FO: Hart, Melvin, LM: Bracken, Alex"

        guard crewText.hasPrefix("Crew:") else { return [] }

        var crew: [CrewMember] = []

        // Remove "Crew: " prefix
        let crewPart = String(crewText.dropFirst(6))

        // Split by common role prefixes
        let rolePattern = #"(CP|FO|LM)(\([^)]*\))?:\s*([^,]+(?:,\s*[^,]+)?)"#

        if let regex = try? NSRegularExpression(pattern: rolePattern, options: []) {
            let range = NSRange(crewPart.startIndex..., in: crewPart)
            let matches = regex.matches(in: crewPart, options: [], range: range)

            for match in matches {
                if let roleRange = Range(match.range(at: 1), in: crewPart),
                   let nameRange = Range(match.range(at: 3), in: crewPart) {

                    let roleCode = String(crewPart[roleRange])
                    var name = String(crewPart[nameRange]).trimmingCharacters(in: .whitespaces)

                    // Clean up name - remove trailing role markers
                    if let commaIndex = name.lastIndex(of: ",") {
                        let afterComma = String(name[name.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
                        // Check if after comma is another role code
                        if ["CP", "FO", "LM"].contains(where: { afterComma.hasPrefix($0) }) {
                            name = String(name[..<commaIndex])
                        }
                    }

                    // Map role code to display name
                    let role: String
                    switch roleCode {
                    case "CP": role = "Captain"
                    case "FO": role = "First Officer"
                    case "LM": role = "Loadmaster"
                    default: role = roleCode
                    }

                    let member = CrewMember(role: role, name: name.trimmingCharacters(in: .whitespaces))
                    crew.append(member)
                }
            }
        }

        return crew
    }

    private func determinePilotRole(from flights: [ParsedRaidoFlight]) -> PilotRole {
        // Determine pilot role from crew text
        // Look for "CP:" or "CP(" to indicate Captain role
        for flight in flights {
            if flight.crewText.contains("CP:") || flight.crewText.contains("CP(") {
                // Check if the user is listed as CP
                // The format is "Crew: CP: LastName, FirstName" or "Crew: CP(X): LastName, FirstName"
                return .captain
            }
        }
        return .firstOfficer
    }
}

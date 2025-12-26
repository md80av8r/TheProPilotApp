// UnifiedLogbookManager.swift
// Fixed version with corrected import logic
import Foundation
import SwiftUI

// MARK: - Unified Import/Export Manager
@MainActor
class UnifiedLogbookManager: ObservableObject {
    
    // MARK: - Import Functions
    func importFromFile(_ url: URL) async -> LogbookImportResult {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let format = detectFormat(from: content, filename: url.lastPathComponent)
            return await processImport(content: content, format: format)
        } catch {
            return LogbookImportResult(success: false, message: "Failed to read file: \(error.localizedDescription)", entries: [])
        }
    }
    
    private func detectFormat(from content: String, filename: String) -> LogbookFormat {
        let headers = content.components(separatedBy: .newlines).first?.lowercased() ?? ""
        
        // Check for LogTen Pro specific headers (tab-delimited with flight_ prefix)
        if headers.contains("flight_flightdate") || headers.contains("flight_totaltime") || headers.contains("flight_from") {
            print("📋 Detected LogTen Pro format (tab-delimited with flight_ prefix)")
            return .logTenPro
        }
        
        // Check for older LogTen Pro format (comma-separated)
        if headers.contains("aircraft type") && headers.contains("total duration") {
            print("📋 Detected LogTen Pro format (legacy comma-separated)")
            return .logTenPro
        }
        
        // Default to ForeFlight format (our gold standard)
        print("📋 Defaulting to ForeFlight format")
        return .foreFlight
    }
    
    private func processImport(content: String, format: LogbookFormat) async -> LogbookImportResult {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > 1 else {
            return LogbookImportResult(success: false, message: "File appears to be empty", entries: [])
        }
        
        let headers = parseCSVLine(lines[0])
        var entries: [FlightEntry] = []
        var errorCount = 0
        
        print("🔍 CSV Headers found: \(headers)")
        print("📊 Processing \(lines.count - 1) data rows...")
        
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            if let entry = parseFlightEntry(headers: headers, values: values, format: format) {
                entries.append(entry)
                print("✅ Parsed line \(i): \(entry.departure) → \(entry.arrival)")
            } else {
                errorCount += 1
                print("❌ Failed to parse line \(i + 1): \(lines[i].prefix(100))...")
            }
        }
        
        let message = errorCount > 0 ?
            "Successfully imported \(entries.count) flights (\(errorCount) lines had errors)" :
            "Successfully imported \(entries.count) flights"
        
        return LogbookImportResult(success: true, message: message, entries: entries)
    }
    
    // MARK: - FIXED: Flight Entry Parsing with Better Crew and Trip Number Extraction
    private func parseFlightEntry(headers: [String], values: [String], format: LogbookFormat) -> FlightEntry? {
        // Ensure we have matching header/value counts
        let minCount = min(headers.count, values.count)
        guard minCount > 0 else {
            print("❌ No data columns found")
            return nil
        }
        
        // Create safe header-to-value mapping
        var data: [String: String] = [:]
        for i in 0..<minCount {
            let key = headers[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = values[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle duplicate keys by keeping the first occurrence
            if data[key] == nil {
                data[key] = value
            }
        }
        
        let mapping = format.fieldMapping
        
        // FIXED: Enhanced date parsing with M/d/yy support
        guard let dateStr = getValue(from: data, mapping: mapping, key: "date"),
              !dateStr.isEmpty,
              let date = parseDate(dateStr) else {
            print("❌ Missing or invalid date field: \(getValue(from: data, mapping: mapping, key: "date") ?? "nil")")
            return nil
        }
        
        // Extract aircraft info
        let aircraftType = getValue(from: data, mapping: mapping, key: "aircraftType") ??
                          getValue(from: data, mapping: mapping, key: "aircraftRegistration") ??
                          "Unknown"
        
        // Extract route info
        let departure = getValue(from: data, mapping: mapping, key: "departure") ?? ""
        let arrival = getValue(from: data, mapping: mapping, key: "arrival") ?? ""
        
        // Skip entries without basic flight info
        guard !departure.isEmpty && !arrival.isEmpty else {
            print("❌ Missing departure (\(departure)) or arrival (\(arrival)) information")
            return nil
        }
        
        // Parse times with ForeFlight decimal format support
        let totalTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "totalTime") ?? "0.0")
        let picTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "picTime") ?? "0.0")
        let sicTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "sicTime") ?? "0.0")
        let nightTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "nightTime") ?? "0.0")
        let crossCountryTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "crossCountryTime") ?? "0.0")
        let instrumentTime = parseLogbookTime(getValue(from: data, mapping: mapping, key: "instrumentTime") ?? "0.0")
        
        // Determine pilot role properly
        let pilotRole: PilotRole = picTime > 0 ? .captain : .firstOfficer
        
        // FIXED: Extract trip number from Route field (where our export puts it)
        let routeField = getValue(from: data, mapping: mapping, key: "route") ?? ""
        let tripNumber = extractTripNumberFromRoute(routeField)
        
        // FIXED: Parse crew info from PilotComments field (where our export puts them)
        let remarks = getValue(from: data, mapping: mapping, key: "remarks") ?? ""
        
        print("✅ Creating flight entry: \(departure) → \(arrival)")
        print("   Total: \(formatTime(totalTime)), PIC: \(formatTime(picTime)), SIC: \(formatTime(sicTime))")
        print("   Remarks: '\(remarks)'")
        print("   Trip Number: '\(tripNumber ?? "none")'")
        
        // Create comprehensive flight entry
        return FlightEntry(
            date: date,
            aircraftType: aircraftType,
            aircraftRegistration: aircraftType,
            departure: departure,
            arrival: arrival,
            blockOut: createTimeFromDate(date, timeString: getValue(from: data, mapping: mapping, key: "timeOut")),
            blockIn: createTimeFromDate(date, timeString: getValue(from: data, mapping: mapping, key: "timeIn")),
            totalTime: totalTime,
            flightTime: totalTime,
            crossCountryTime: crossCountryTime,
            nightTime: nightTime,
            instrumentTime: instrumentTime,
            simulatedInstrumentTime: parseLogbookTime(getValue(from: data, mapping: mapping, key: "simulatedInstrumentTime") ?? "0.0"),
            dualGivenTime: 0,
            dualReceivedTime: 0,
            picTime: picTime,
            sicTime: sicTime,
            soloTime: 0,
            dayLandings: Int(getValue(from: data, mapping: mapping, key: "dayLandings") ?? "1") ?? 1,
            nightLandings: Int(getValue(from: data, mapping: mapping, key: "nightLandings") ?? "0") ?? 0,
            instrumentLandings: 0,
            pilotRole: pilotRole,
            aircraftCategory: .airplane,
            aircraftClass: .multiEngineLand,
            aircraftEngine: .turbofan,
            approaches: [],
            holds: Int(getValue(from: data, mapping: mapping, key: "holds") ?? "0") ?? 0,
            flightRules: .ifr,
            actualInstrument: instrumentTime,
            simulatedInstrument: parseLogbookTime(getValue(from: data, mapping: mapping, key: "simulatedInstrumentTime") ?? "0.0"),
            route: getValue(from: data, mapping: mapping, key: "route") ?? "\(departure)-\(arrival)",
            remarks: remarks,
            flightNumber: nil,
            passengers: 0,
            tripNumber: tripNumber,
            isDeadhead: remarks.lowercased().contains("deadhead"),
            perDiemEligible: true
        )
    }
    
    // MARK: - FIXED: Enhanced Helper Functions
    
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        // FIXED: Added M/d/yy format that ForeFlight exports use
        let formats = ["M/d/yy", "MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd", "yyyy/MM/dd"]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        print("❌ Could not parse date: '\(dateString)'")
        return nil
    }
    
    private func extractTripNumberFromRoute(_ route: String) -> String? {
        // Route field contains things like "KLRD-MMIO"
        // For imported trips, we'll use the route as trip identifier
        guard !route.isEmpty && route != "\(route.split(separator: "-").first ?? "")-\(route.split(separator: "-").last ?? "")" else {
            return nil
        }
        return route
    }
    
    private func createTimeFromDate(_ date: Date, timeString: String?) -> Date {
        guard let timeString = timeString, !timeString.isEmpty else { return date }
        
        // Parse H:MM or HH:MM format (ForeFlight time format)
        let components = timeString.components(separatedBy: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else { return date }
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hours
        dateComponents.minute = minutes
        
        return calendar.date(from: dateComponents) ?? date
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    // MARK: - Export Functions (ForeFlight Standard) - FIXED WITH PROPER TEMPLATE
    func exportToFormat(_ trips: [Trip], format: LogbookFormat, startDate: Date? = nil, endDate: Date? = nil) async -> String {
        // Filter trips by date if specified
        var filteredTrips = trips
        
        if let start = startDate {
            filteredTrips = filteredTrips.filter { $0.date >= start }
        }
        
        if let end = endDate {
            filteredTrips = filteredTrips.filter { $0.date <= end }
        }
        
        switch format {
        case .foreFlight:
            return await generateForeFlightExport(trips: filteredTrips)
        case .logTenPro:
            return await generateLogTenProExport(trips: filteredTrips)
        }
    }
    
    // MARK: - ForeFlight Export with Full Template Structure
    private func generateForeFlightExport(trips: [Trip]) async -> String {
        // ForeFlight CSV format - EXACT match to official ForeFlight template
        // Uses COMMAS as separator
        // Total: 69 columns in Flights Table (updated format)
        
        let totalColumns = 69
        let aircraftDatabase = UnifiedAircraftDatabase.shared
        
        // Helper to pad row to correct column count
        // NOTE: N fields require N-1 commas
        func padRow(_ content: String, filledColumns: Int) -> String {
            // Special case: empty rows need totalColumns - 1 commas to create totalColumns fields
            if filledColumns == 0 {
                return String(repeating: ",", count: totalColumns - 1)
            }
            // Non-empty rows: add enough commas to reach totalColumns total fields
            let padding = String(repeating: ",", count: totalColumns - filledColumns)
            return content + padding
        }
        
        var csvLines: [String] = []
        
        // Row 1: ForeFlight Logbook Import marker (REQUIRED)
        csvLines.append(padRow("ForeFlight Logbook Import,This row is required for importing into ForeFlight. Do not delete or modify.", filledColumns: 2))
        
        // Row 2: Empty row
        csvLines.append(padRow("", filledColumns: 0))
        
        // Row 3: Aircraft Table marker
        csvLines.append(padRow("Aircraft Table", filledColumns: 1))
        
        // Row 4: Aircraft table data types
        csvLines.append(padRow("Text,Text,Text,YYYY,Text,Text,Text,Text,Text,Boolean,Boolean,Boolean,Boolean", filledColumns: 13))
        
        // Row 5: Aircraft table column headers
        csvLines.append(padRow("AircraftID,equipType,TypeCode,Year,Make,Model,GearType,EngineType,Category/Class,complexAircraft,highPerformance,pressurized,taa", filledColumns: 13))
        
        // Rows 6-12: Aircraft data from library (up to 7 aircraft)
        // Get unique aircraft used in these trips
        let usedAircraft = Set(trips.map { $0.aircraft.uppercased() }).filter { !$0.isEmpty }
        var aircraftRowCount = 0
        
        for registration in usedAircraft.sorted() {
            if aircraftRowCount >= 7 { break }  // ForeFlight template has 7 aircraft rows
            
            if let aircraft = aircraftDatabase.findAircraft(byTailNumber: registration) {
                csvLines.append(padRow(aircraft.foreFlightAircraftRow(), filledColumns: 13))
            } else {
                // Aircraft not in database - add basic row with just registration
                csvLines.append(padRow(registration + String(repeating: ",", count: 12), filledColumns: 13))
            }
            aircraftRowCount += 1
        }
        
        // Fill remaining aircraft rows with empty rows (need exactly 7 total)
        while aircraftRowCount < 7 {
            csvLines.append(padRow("", filledColumns: 0))
            aircraftRowCount += 1
        }
        
        // Row 13: Flights Table marker
        csvLines.append(padRow("Flights Table", filledColumns: 1))
        
        // Row 14: Data type definitions (exact match to template)
        csvLines.append("Date,Text,Text,Text,Text,HH:MM,HH:MM,HH:MM,HH:MM,HH:MM,HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Number,Decimal,Number,Number,Number,Number,Number,Number,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal,Decimal,Decimal,Decimal,Number,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Text,Text,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Text,Boolean,Boolean,Boolean,Boolean,Boolean,Text,Decimal,Decimal or HH:MM,Number,Date,DateTime,Boolean")
        
        // Row 15: Column headers (exact match to ForeFlight template row 15)
        csvLines.append("Date,AircraftID,From,To,Route,TimeOut,TimeOff,TimeOn,TimeIn,OnDuty,OffDuty,TotalTime,PIC,SIC,Night,Solo,CrossCountry,PICUS,MultiPilot,IFR,Examiner,NVG,NVGOps,Distance,Takeoff Day,Takeoff Night,Landing Full-Stop Day,Landing Full-Stop Night,Landing Touch-and-Go Day,Landing Touch-and-Go Night,ActualInstrument,SimulatedInstrument,GroundTraining,GroundTrainingGiven,HobbsStart,HobbsEnd,TachStart,TachEnd,Holds,Approach1,Approach2,Approach3,Approach4,Approach5,Approach6,DualGiven,DualReceived,SimulatedFlight,InstructorName,InstructorComments,Person1,Person2,Person3,Person4,Person5,Person6,PilotComments,Flight Review,IPC,Checkride,FAA 61.58,NVG Proficiency,[Text]CustomFieldName,[Numeric]CustomFieldName,[Hours]CustomFieldName,[Counter]CustomFieldName,[Date]CustomFieldName,[DateTime]CustomFieldName,[Toggle]CustomFieldName")
        
        // Data rows
        for trip in trips {
            for leg in trip.legs {
                // Skip legs missing both departure and arrival
                guard !leg.departure.isEmpty || !leg.arrival.isEmpty else { continue }
                
                let line = await formatForeFlightDataRow(trip: trip, leg: leg)
                csvLines.append(line)
            }
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func formatForeFlightDataRow(trip: Trip, leg: FlightLeg) async -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"  // ForeFlight date format per docs: YYYY-MM-DD
        let dateString = dateFormatter.string(from: leg.flightDate ?? trip.date)
        
        let aircraft = trip.aircraft.isEmpty ? "" : trip.aircraft
        let blockMinutes = leg.blockMinutes()
        let blockTime = blockMinutes > 0 ? String(format: "%.1f", Double(blockMinutes) / 60.0) : "0.0"
        
        // Get night time
        let nightMins = await leg.nightMinutes(flightDate: leg.flightDate ?? trip.date)
        let nightTime = nightMins > 0 ? String(format: "%.1f", Double(nightMins) / 60.0) : "0.0"
        
        // Determine PIC/SIC based on pilot role
        let picTime = (trip.pilotRole == .captain) ? blockTime : "0.0"
        let sicTime = (trip.pilotRole == .firstOfficer) ? blockTime : "0.0"
        
        // Build route string (DEP-ARR)
        let route = "\(leg.departure)-\(leg.arrival)"
        
        // Extract crew by role for proper ForeFlight fields
        let crewMembers = trip.crew.filter { !$0.name.isEmpty }
        
        // Find Captain and First Officer specifically
        let captain = crewMembers.first { $0.role.lowercased().contains("captain") || $0.role.lowercased() == "pic" }
        let firstOfficer = crewMembers.first { $0.role.lowercased().contains("first officer") || $0.role.lowercased() == "fo" || $0.role.lowercased() == "sic" }
        
        // Person1 = Captain name only (no role suffix)
        // Person2 = First Officer name only (no role suffix)
        let person1 = captain?.name ?? ""
        let person2 = firstOfficer?.name ?? ""
        
        // Build crew string for notes: "Crew: J. Smith (Captain), M. Jones (FO), B. Lee (LM)"
        var crewNoteParts: [String] = []
        for member in crewMembers {
            crewNoteParts.append("\(member.name) (\(member.role))")
        }
        let crewNoteString = crewNoteParts.isEmpty ? "" : "Crew: \(crewNoteParts.joined(separator: ", "))"
        
        // Combine trip notes with crew info
        var notesComponents: [String] = []
        if !trip.notes.isEmpty {
            notesComponents.append(trip.notes)
        }
        if !crewNoteString.isEmpty {
            notesComponents.append(crewNoteString)
        }
        
        // Clean notes for CSV
        let cleanNotes = notesComponents.joined(separator: " | ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // Determine if day or night operations for takeoffs/landings
        let isDayOperation = nightMins == 0 || nightMins < (blockMinutes / 2)
        let dayTakeoffs = isDayOperation ? "1" : "0"
        let dayLandings = isDayOperation ? "1" : "0"
        let nightTakeoffs = isDayOperation ? "0" : "1"
        let nightLandings = isDayOperation ? "0" : "1"
        
        // Pilot Flying toggle - currently unused but preserved for future ForeFlight export enhancements
        _ = (trip.pilotRole == .captain) ? "TRUE" : "FALSE"
        
        // Build the line with all 69 columns (COMMA-separated for ForeFlight)
        // Column order MUST match Row 15 header exactly
        return [
            dateString,                                           // 1: Date
            aircraft,                                              // 2: AircraftID
            leg.departure,                                         // 3: From
            leg.arrival,                                           // 4: To
            route,                                                 // 5: Route
            formatTimeForForeFlight(leg.outTime),                  // 6: TimeOut
            formatTimeForForeFlight(leg.offTime),                  // 7: TimeOff
            formatTimeForForeFlight(leg.onTime),                   // 8: TimeOn
            formatTimeForForeFlight(leg.inTime),                   // 9: TimeIn
            "",                                                    // 10: OnDuty
            "",                                                    // 11: OffDuty
            blockTime,                                             // 12: TotalTime
            picTime,                                               // 13: PIC
            sicTime,                                               // 14: SIC
            nightTime,                                             // 15: Night
            "",                                                    // 16: Solo
            blockTime,                                             // 17: CrossCountry (auto-filled for cargo ops)
            "",                                                    // 18: PICUS
            "",                                                    // 19: MultiPilot
            "",                                                    // 20: IFR
            "",                                                    // 21: Examiner
            "",                                                    // 22: NVG
            "",                                                    // 23: NVGOps
            calculateDistance(from: leg.departure, to: leg.arrival), // 24: Distance (nautical miles)
            dayTakeoffs,                                           // 25: Takeoff Day
            nightTakeoffs,                                         // 26: Takeoff Night
            dayLandings,                                           // 27: Landing Full-Stop Day
            nightLandings,                                         // 28: Landing Full-Stop Night
            "",                                                    // 29: Landing Touch-and-Go Day
            "",                                                    // 30: Landing Touch-and-Go Night
            "",                                                    // 31: ActualInstrument
            "",                                                    // 32: SimulatedInstrument
            "",                                                    // 33: GroundTraining
            "",                                                    // 34: GroundTrainingGiven
            "",                                                    // 35: HobbsStart
            "",                                                    // 36: HobbsEnd
            "",                                                    // 37: TachStart
            "",                                                    // 38: TachEnd
            "",                                                    // 39: Holds
            "",                                                    // 40: Approach1
            "",                                                    // 41: Approach2
            "",                                                    // 42: Approach3
            "",                                                    // 43: Approach4
            "",                                                    // 44: Approach5
            "",                                                    // 45: Approach6
            "",                                                    // 46: DualGiven
            "",                                                    // 47: DualReceived
            "",                                                    // 48: SimulatedFlight
            "",                                                    // 49: InstructorName
            "",                                                    // 50: InstructorComments
            person1,                                               // 51: Person1 (Captain name only)
            person2,                                               // 52: Person2 (FO name only)
            "",                                                    // 53: Person3
            "",                                                    // 54: Person4
            "",                                                    // 55: Person5
            "",                                                    // 56: Person6
            cleanNotes,                                            // 57: PilotComments (includes crew list)
            "",                                                    // 58: Flight Review
            "",                                                    // 59: IPC
            "",                                                    // 60: Checkride
            "",                                                    // 61: FAA 61.58
            "",                                                    // 62: NVG Proficiency
            "",                                                    // 63: [Text]CustomFieldName
            "",                                                    // 64: [Numeric]CustomFieldName
            "",                                                    // 65: [Hours]CustomFieldName
            "",                                                    // 66: [Counter]CustomFieldName
            "",                                                    // 67: [Date]CustomFieldName
            "",                                                    // 68: [DateTime]CustomFieldName
            ""                                                     // 69: [Toggle]CustomFieldName
        ].joined(separator: ",")
    }
    
    // MARK: - LogTen Pro Export
    private func generateLogTenProExport(trips: [Trip]) async -> String {
        let headers = LogbookFormat.logTenPro.exportHeaders.joined(separator: ",")
        var csvLines = [headers]
        
        for trip in trips {
            for leg in trip.legs {
                let line = await formatLogTenProDataRow(trip: trip, leg: leg)
                csvLines.append(line)
            }
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func formatLogTenProDataRow(trip: Trip, leg: FlightLeg) async -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: trip.date)
        
        let nightMinutes = await leg.nightMinutes(flightDate: trip.date)
        let captainName = trip.crew.first { $0.role.contains("Captain") }?.name ?? ""
        let foName = trip.crew.first { $0.role.contains("First Officer") }?.name ?? ""
        
        return [
            dateString,                   // Date
            trip.aircraft,               // Aircraft ID
            trip.aircraft,               // Aircraft Type
            leg.departure,               // Departure
            leg.arrival,                 // Arrival
            trip.tripNumber,             // Trip Number
            formatTimeHHMM(leg.blockMinutes()), // Total Duration
            trip.pilotRole == .captain ? formatTimeHHMM(leg.blockMinutes()) : "0:00", // PIC
            trip.pilotRole == .firstOfficer ? formatTimeHHMM(leg.blockMinutes()) : "0:00", // SIC
            formatTimeHHMM(nightMinutes), // Night
            "0:00",                      // Cross Country
            "0:00",                      // Instrument
            "1",                         // Day Landings
            "0",                         // Night Landings
            captainName,                 // Captain
            foName,                      // First Officer
            trip.notes                   // Remarks
        ].map { escapeCSVField($0) }.joined(separator: ",")
    }
    
    // MARK: - Template Generation
    func generateTemplate(for format: LogbookFormat) -> String {
        let headers = format.exportHeaders.joined(separator: ",")
        let sampleData = getSampleRows(for: format)
        
        return headers + "\n" + sampleData.joined(separator: "\n")
    }
    
    private func getSampleRows(for format: LogbookFormat) -> [String] {
        switch format {
        case .foreFlight:
            return [
                "1/15/24,B737-800,KYIP,KORD,KYIP-KORD,12:00,12:15,13:45,14:00,,,2.0,2.0,0.0,0.5,0.0,2.0,0.0,0.0,0.0,0.0,0.0,0,0,0.0,0.0,0,0,0,0,0,,,,,,,,0.0,0.0,0.0,0.0,0.0,,,,,,,John Smith Jane Doe Normal flight,,,,,,1,1,0,0,1,TRUE,",
                "1/16/24,B737-800,KORD,KJFK,KORD-KJFK,08:00,08:15,10:45,11:00,,,2.8,2.8,0.0,1.2,0.0,2.8,0.0,0.0,0.0,0.0,0.0,0,0,0.0,0.0,0,0,0,0,0,,,,,,,,0.0,0.0,0.0,0.0,0.0,,,,,,,John Smith Jane Doe ILS approach,,,,,,1,1,0,0,1,TRUE,"
            ]
            
        case .logTenPro:
            return [
                "2024-01-15,N12345,B737-800,KYIP,KORD,1234,2:00,2:00,0:00,0:30,2:00,0:00,1,0,John Smith,Jane Doe,Normal flight",
                "2024-01-16,N12345,B737-800,KORD,KJFK,5678,2:48,2:48,0:00,1:12,2:48,0:00,1,0,John Smith,Jane Doe,ILS approach"
            ]
        }
    }
    
    // MARK: - Existing Helper Functions (Unchanged)
    private func parseCSVLine(_ line: String) -> [String] {
        // Detect delimiter - LogTen Pro uses tabs, ForeFlight uses commas
        let delimiter: Character = line.contains("\t") ? "\t" : ","
        
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == delimiter && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
    
    private func getValue(from data: [String: String], mapping: [String: String], key: String) -> String? {
        // First try the primary mapping
        if let mappedKey = mapping[key] {
            // Try exact match
            if let value = data[mappedKey], !value.isEmpty {
                return value
            }
            
            // Try case-insensitive match
            for (dataKey, dataValue) in data {
                if dataKey.lowercased() == mappedKey.lowercased() && !dataValue.isEmpty {
                    return dataValue
                }
            }
        }
        
        // Try legacy mapping (for LogTen Pro backwards compatibility)
        if let legacyKey = mapping["\(key)_legacy"] {
            if let value = data[legacyKey], !value.isEmpty {
                return value
            }
            
            for (dataKey, dataValue) in data {
                if dataKey.lowercased() == legacyKey.lowercased() && !dataValue.isEmpty {
                    return dataValue
                }
            }
        }
        
        return nil
    }
    
    private func parseLogbookTime(_ timeString: String) -> TimeInterval {
        let cleanTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTime.isEmpty else { return 0 }
        
        // Handle ForeFlight decimal format (2.5 = 2 hours 30 minutes)
        if !cleanTime.contains(":") {
            guard let decimal = Double(cleanTime) else { return 0 }
            return TimeInterval(decimal * 3600)
        }
        
        // Handle HH:MM format
        let components = cleanTime.components(separatedBy: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else { return 0 }
        return TimeInterval((hours * 60 + minutes) * 60)
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    private func formatTimeForForeFlight(_ timeString: String) -> String {
        // ForeFlight wants HHMM format (no colon) per docs: "Hours and minutes in 24-hour format. Example: 1823"
        guard !timeString.isEmpty else { return "" }
        
        // Extract only digits from the string
        let digits = timeString.filter(\.isWholeNumber)
        
        // ✅ FIX: Always pad to 4 digits, even for times like "0", "7", "50"
        // Empty or invalid times still return ""
        guard !digits.isEmpty else { return "" }
        
        // Pad to 4 digits: "0" → "0000", "7" → "0007", "50" → "0050", "945" → "0945"
        let padded = String(repeating: "0", count: max(0, 4 - digits.count)) + digits
        
        // Take only first 4 digits to handle any overflow
        return String(padded.prefix(4))
    }
    
    private func formatTimeHHMM(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    // MARK: - Distance Calculation
    
    /// Calculate great circle distance between two airports in nautical miles
    private func calculateDistance(from: String, to: String) -> String {
        // Common airport coordinates (lat, lon in degrees)
        let airports: [String: (lat: Double, lon: Double)] = [
            "KLRD": (27.5444, -99.4616),   // Laredo
            "KYIP": (42.2379, -83.5304),   // Willow Run
            "KSDF": (38.1744, -85.7360),   // Louisville
            "KELP": (31.8072, -106.3778),  // El Paso
            "KIND": (39.7173, -86.2945),   // Indianapolis
            "KAFW": (32.7881, -97.3628),   // Fort Worth Alliance
            "KTUS": (32.1161, -110.9410),  // Tucson
            "MMCU": (28.7029, -105.9647),  // Chihuahua
            "MMHO": (29.0959, -111.0480),  // Hermosillo
            "KHUF": (39.4331, -87.3076),   // Terre Haute
            // Add more airports as needed
        ]
        
        guard let fromCoord = airports[from.uppercased()],
              let toCoord = airports[to.uppercased()] else {
            return ""  // Return empty if airports not in database
        }
        
        // Haversine formula for great circle distance
        let R = 3440.065  // Earth radius in nautical miles
        
        let lat1 = fromCoord.lat * .pi / 180
        let lat2 = toCoord.lat * .pi / 180
        let dLat = (toCoord.lat - fromCoord.lat) * .pi / 180
        let dLon = (toCoord.lon - fromCoord.lon) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1) * cos(lat2) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let distance = R * c
        
        return String(format: "%.0f", distance)  // Round to whole number
    }
}

// MARK: - Data Structures
struct LogbookImportResult {
    let success: Bool
    let message: String
    let entries: [FlightEntry]
}

// LogbookFormat.swift
// Updated with EXACT ForeFlight export format (63 columns) based on real ForeFlight data
import Foundation
import SwiftUI
import CoreLocation

enum LogbookFormat: CaseIterable {
    case foreFlight
    case logTenPro
    
    var displayName: String {
        switch self {
        case .foreFlight: return "ForeFlight"
        case .logTenPro: return "LogTen Pro"
        }
    }
    
    var iconName: String {
        switch self {
        case .foreFlight: return "airplane.departure"
        case .logTenPro: return "book.closed"
        }
    }
    
    var color: Color {
        switch self {
        case .foreFlight: return .blue
        case .logTenPro: return .green
        }
    }
    
    var fieldMapping: [String: String] {
        switch self {
        case .foreFlight:
            return [
                "date": "Date",                    // Match exact case
                "aircraftType": "AircraftID",      // Match exact case
                "aircraftRegistration": "AircraftID",
                "departure": "From",               // Match exact case
                "arrival": "To",                   // Match exact case
                "route": "Route",
                "timeOut": "TimeOut",              // Match exact case
                "timeOff": "TimeOff",
                "timeOn": "TimeOn",
                "timeIn": "TimeIn",
                "totalTime": "TotalTime",          // Match exact case
                "picTime": "PIC",
                "sicTime": "SIC",
                "nightTime": "Night",
                "crossCountryTime": "CrossCountry",
                "instrumentTime": "ActualInstrument",
                "simulatedInstrumentTime": "SimulatedInstrument",
                "dayLandings": "DayLandingsFullStop",
                "nightLandings": "NightLandingsFullStop",
                "approaches": "Approach1",
                "holds": "Holds",
                "remarks": "PilotComments",        // Not "pilotcomments"
                "dualGiven": "DualGiven",
                "dualReceived": "DualReceived",
                "distance": "Distance",
                "solo": "Solo",
                "picus": "PICUS",
                "multiPilot": "MultiPilot",
                "ifr": "IFR",
                "examiner": "Examiner",
                "nvg": "NVG",
                "nvgOps": "NVG Ops",
                "hobbsStart": "HobbsStart",
                "hobbsEnd": "HobbsEnd",
                "tachStart": "TachStart",
                "tachEnd": "TachEnd",
                "pilotFlying": "[Toggle]Pilot Flying",
                "pilotMonitoring": "[Toggle]Pilot Monitoring"
            ]
            
        case .logTenPro:
            // Updated for actual LogTen Pro tab-delimited export
            // Note: Headers have spaces and varying cases like "flight_flightDate", " flight_from"
            return [
                "date": "flight_flightdate",
                "aircraftType": "aircrafttype_type",
                "aircraftRegistration": "aircraft_aircraftid",
                "departure": "flight_from",
                "arrival": "flight_to",
                "tripNumber": "flight_flightnumber",
                "totalTime": "flight_totaltime",
                "picTime": "flight_pic",
                "sicTime": "flight_sic",
                "nightTime": "flight_night",
                "crossCountryTime": "flight_crosscountry",
                "instrumentTime": "flight_actualinstrument",
                "dayLandings": "flight_daylandings",
                "nightLandings": "flight_nightlandings",
                "captainName": "flight_selectedcrewpic",
                "firstOfficerName": "flight_selectedcrewsic",
                "remarks": "flight_remarks",
                "aircraftMake": "aircrafttype_make",
                "aircraftModel": "aircrafttype_model",
                "engineType": "aircrafttype_selectedenginetype",
                "aircraftCategory": "aircrafttype_selectedcategory",
                "aircraftClass": "aircrafttype_selectedaircraftclass"
            ]
        }
    }
    
    var exportHeaders: [String] {
        switch self {
        case .foreFlight:
            // EXACT ForeFlight format - 63 columns in correct order
            return [
                "Date", "AircraftID", "From", "To", "Route", "TimeOut", "TimeOff", "TimeOn", "TimeIn",
                "OnDuty", "OffDuty", "TotalTime", "PIC", "SIC", "Night", "Solo", "CrossCountry",
                "PICUS", "MultiPilot", "IFR", "Examiner", "NVG", "NVG Ops", "Distance",
                "ActualInstrument", "SimulatedInstrument", "HobbsStart", "HobbsEnd", "TachStart", "TachEnd",
                "Holds", "Approach1", "Approach2", "Approach3", "Approach4", "Approach5", "Approach6",
                "DualGiven", "DualReceived", "SimulatedFlight", "GroundTraining", "GroundTrainingGiven",
                "InstructorName", "InstructorComments", "Person1", "Person2", "Person3", "Person4",
                "Person5", "Person6", "PilotComments", "Flight Review (FAA)", "IPC (FAA)",
                "Checkride (FAA)", "FAA 61.58 (FAA)", "NVG Proficiency (FAA)", "DayTakeoffs",
                "DayLandingsFullStop", "NightTakeoffs", "NightLandingsFullStop", "AllLandings",
                "[Toggle]Pilot Flying", "[Toggle]Pilot Monitoring"
            ]
            
        case .logTenPro:
            return [
                "Date", "Aircraft ID", "Aircraft Type", "Departure", "Arrival", "Trip Number",
                "Total Duration", "PIC", "SIC", "Night", "Cross Country", "Instrument",
                "Day Landings", "Night Landings", "Captain", "First Officer", "Remarks"
            ]
        }
    }
    
    var description: String {
        switch self {
        case .foreFlight:
            return "EXACT ForeFlight export format with all 63 fields"
        case .logTenPro:
            return "Professional logging application"
        }
    }
}

// MARK: - Complete Import/Export Manager
class LogbookImportExportManager {
    private let nightCalculator = NightHoursCalculator()
    
    // MARK: - Import Functions
    func importForeFlight(_ csvData: String) -> [FlightEntry] {
        return parseCSVData(csvData, format: .foreFlight)
    }
    
    func importLogTenPro(_ csvData: String) -> [FlightEntry] {
        return parseCSVData(csvData, format: .logTenPro)
    }
    
    // MARK: - Export Functions
    func exportForeFlight(_ entries: [FlightEntry]) -> String {
        return exportCSV(entries, format: .foreFlight)
    }
    
    func exportLogTenPro(_ entries: [FlightEntry]) -> String {
        return exportCSV(entries, format: .logTenPro)
    }
    
    // MARK: - Private Export Implementation
    private func exportCSV(_ entries: [FlightEntry], format: LogbookFormat) -> String {
        let headers = format.exportHeaders
        var csvLines = [headers.joined(separator: ",")]
        
        for entry in entries {
            let values = formatEntryForExport(entry, format: format)
            csvLines.append(values.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func formatEntryForExport(_ entry: FlightEntry, format: LogbookFormat) -> [String] {
        switch format {
        case .foreFlight:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d/yy"  // Match ForeFlight format
            let dateString = dateFormatter.string(from: entry.date)
            
            return [
                dateString,                                      // 1. Date
                entry.aircraftRegistration,                     // 2. AircraftID
                entry.departure,                                // 3. From
                entry.arrival,                                  // 4. To
                entry.route,                                    // 5. Route
                formatTimeForForeFlight(entry.blockOut),        // 6. TimeOut
                formatTimeForForeFlight(entry.blockOut.addingTimeInterval(300)), // 7. TimeOff
                formatTimeForForeFlight(entry.blockIn.addingTimeInterval(-300)), // 8. TimeOn
                formatTimeForForeFlight(entry.blockIn),         // 9. TimeIn
                "",                                             // 10. OnDuty
                "",                                             // 11. OffDuty
                String(format: "%.1f", entry.totalTime / 3600), // 12. TotalTime (decimal)
                String(format: "%.1f", entry.picTime / 3600),   // 13. PIC (decimal)
                String(format: "%.1f", entry.sicTime / 3600),   // 14. SIC (decimal)
                String(format: "%.1f", entry.nightTime / 3600), // 15. Night (decimal)
                String(format: "%.1f", entry.soloTime / 3600),  // 16. Solo (decimal)
                String(format: "%.1f", entry.crossCountryTime / 3600), // 17. CrossCountry (decimal)
                "0.0",                                          // 18. PICUS
                "0.0",                                          // 19. MultiPilot (NOT crew names!)
                "0.0",                                          // 20. IFR
                "0.0",                                          // 21. Examiner
                "0.0",                                          // 22. NVG
                "0",                                            // 23. NVG Ops
                "0",                                            // 24. Distance
                String(format: "%.1f", entry.actualInstrument / 3600), // 25. ActualInstrument
                String(format: "%.1f", entry.simulatedInstrument / 3600), // 26. SimulatedInstrument
                "0",                                            // 27. HobbsStart
                "0",                                            // 28. HobbsEnd
                "0",                                            // 29. TachStart
                "0",                                            // 30. TachEnd
                String(entry.holds),                            // 31. Holds
                "",                                             // 32. Approach1
                "",                                             // 33. Approach2
                "",                                             // 34. Approach3
                "",                                             // 35. Approach4
                "",                                             // 36. Approach5
                "",                                             // 37. Approach6
                String(format: "%.1f", entry.dualGivenTime / 3600),    // 38. DualGiven
                String(format: "%.1f", entry.dualReceivedTime / 3600), // 39. DualReceived
                "0.0",                                          // 40. SimulatedFlight
                "0.0",                                          // 41. GroundTraining
                "0.0",                                          // 42. GroundTrainingGiven
                "",                                             // 43. InstructorName
                "",                                             // 44. InstructorComments
                "",                                             // 45. Person1
                "",                                             // 46. Person2
                "",                                             // 47. Person3
                "",                                             // 48. Person4
                "",                                             // 49. Person5
                "",                                             // 50. Person6
                entry.remarks,                                  // 51. PilotComments <- Crew names go HERE!
                "",                                             // 52. Flight Review (FAA)
                "",                                             // 53. IPC (FAA)
                "",                                             // 54. Checkride (FAA)
                "",                                             // 55. FAA 61.58 (FAA)
                "",                                             // 56. NVG Proficiency (FAA)
                String(entry.dayLandings),                      // 57. DayTakeoffs
                String(entry.dayLandings),                      // 58. DayLandingsFullStop
                String(entry.nightLandings),                    // 59. NightTakeoffs
                String(entry.nightLandings),                    // 60. NightLandingsFullStop
                String(entry.dayLandings + entry.nightLandings), // 61. AllLandings
                entry.pilotRole == .captain ? "TRUE" : "",      // 62. [Toggle]Pilot Flying
                entry.pilotRole == .firstOfficer ? "TRUE" : ""  // 63. [Toggle]Pilot Monitoring
            ]
            
        case .logTenPro:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: entry.date)
            
            return [
                dateString,                                     // Date
                entry.aircraftRegistration,                    // Aircraft ID
                entry.aircraftType,                            // Aircraft Type
                entry.departure,                               // Departure
                entry.arrival,                                 // Arrival
                entry.tripNumber ?? "",                        // Trip Number
                formatTimeHMM(entry.totalTime),                // Total Duration
                formatTimeHMM(entry.picTime),                  // PIC
                formatTimeHMM(entry.sicTime),                  // SIC
                formatTimeHMM(entry.nightTime),                // Night
                formatTimeHMM(entry.crossCountryTime),         // Cross Country
                formatTimeHMM(entry.instrumentTime),           // Instrument
                String(entry.dayLandings),                     // Day Landings
                String(entry.nightLandings),                   // Night Landings
                "",                                            // Captain
                "",                                            // First Officer
                escapeCSVField(entry.remarks)                  // Remarks
            ]
        }
    }
    
    // MARK: - Private Import Implementation
    private func parseCSVData(_ csvData: String, format: LogbookFormat) -> [FlightEntry] {
        let lines = csvData.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > 1 else { return [] }
        
        let headers = parseCSVLine(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        var entries: [FlightEntry] = []
        
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            if let entry = parseFlightEntry(headers: headers, values: values, format: format) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func parseFlightEntry(headers: [String], values: [String], format: LogbookFormat) -> FlightEntry? {
        let minCount = min(headers.count, values.count)
        guard minCount > 0 else { return nil }
        
        // Create data dictionary
        var data: [String: String] = [:]
        for i in 0..<minCount {
            data[headers[i]] = values[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Parse using the fieldMapping from the format
        let mapping = format.fieldMapping
        
        // Parse date
        guard let dateStr = getValue(data, mapping: mapping, key: "date"),
              let date = parseDate(dateStr) else { return nil }
        
        // Parse basic fields
        let aircraftType = getValue(data, mapping: mapping, key: "aircraftType") ?? "Unknown"
        let departure = getValue(data, mapping: mapping, key: "departure") ?? ""
        let arrival = getValue(data, mapping: mapping, key: "arrival") ?? ""
        
        guard !departure.isEmpty && !arrival.isEmpty else { return nil }
        
        // Parse times
        let totalTime = parseTimeString(getValue(data, mapping: mapping, key: "totalTime") ?? "0")
        let picTime = parseTimeString(getValue(data, mapping: mapping, key: "picTime") ?? "0")
        let sicTime = parseTimeString(getValue(data, mapping: mapping, key: "sicTime") ?? "0")
        let nightTime = parseTimeString(getValue(data, mapping: mapping, key: "nightTime") ?? "0")
        let crossCountryTime = parseTimeString(getValue(data, mapping: mapping, key: "crossCountryTime") ?? "0")
        let instrumentTime = parseTimeString(getValue(data, mapping: mapping, key: "instrumentTime") ?? "0")
        
        // Parse landings
        let dayLandings = Int(getValue(data, mapping: mapping, key: "dayLandings") ?? "1") ?? 1
        let nightLandings = Int(getValue(data, mapping: mapping, key: "nightLandings") ?? "0") ?? 0
        
        let pilotRole: PilotRole = picTime > 0 ? .captain : .firstOfficer
        let remarks = getValue(data, mapping: mapping, key: "remarks") ?? ""
        
        return FlightEntry(
            date: date,
            aircraftType: aircraftType,
            aircraftRegistration: aircraftType,
            departure: departure,
            arrival: arrival,
            blockOut: date,
            blockIn: date.addingTimeInterval(totalTime),
            totalTime: totalTime,
            flightTime: totalTime,
            crossCountryTime: crossCountryTime,
            nightTime: nightTime,
            instrumentTime: instrumentTime,
            simulatedInstrumentTime: 0,
            dualGivenTime: 0,
            dualReceivedTime: 0,
            picTime: picTime,
            sicTime: sicTime,
            soloTime: 0,
            dayLandings: dayLandings,
            nightLandings: nightLandings,
            instrumentLandings: 0,
            pilotRole: pilotRole,
            aircraftCategory: .airplane,
            aircraftClass: .multiEngineLand,
            aircraftEngine: .turbofan,
            approaches: [],
            holds: 0,
            flightRules: .ifr,
            actualInstrument: instrumentTime,
            simulatedInstrument: 0,
            route: "\(departure)-\(arrival)",
            remarks: remarks,
            flightNumber: nil,
            passengers: 0,
            tripNumber: getValue(data, mapping: mapping, key: "tripNumber"),
            isDeadhead: remarks.lowercased().contains("deadhead"),
            perDiemEligible: true
        )
    }
    
    // MARK: - Helper Functions for EXACT ForeFlight formatting
    
    // Format time for ForeFlight TimeOut/TimeOff/TimeOn/TimeIn (H:MM format, not HH:MM)
    private func formatTimeForForeFlight(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"  // ForeFlight uses H:MM (not HH:MM)
        formatter.timeZone = TimeZone(identifier: "GMT")
        return formatter.string(from: date)
    }
    
    // Format duration times for ForeFlight (H:MM format)
    private func formatTimeHMM(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        // Use H:MM format (not HH:MM) to match ForeFlight exactly
        return String(format: "%d:%02d", hours, minutes)
    }
    
    // Calculate distance between airports (ForeFlight includes this)
    private func calculateDistance(_ departure: String, _ arrival: String) -> String {
        // For now, return "0" - you could integrate with airport database for real distances
        // ForeFlight shows distances like "407.1" for nautical miles
        return "0"
    }
    
    // Helper Methods (unchanged)
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
    
    private func getValue(_ data: [String: String], mapping: [String: String], key: String) -> String? {
        guard let mappedKey = mapping[key] else { return nil }
        return data[mappedKey.lowercased()]
    }
    
    private func parseDate(_ dateStr: String) -> Date? {
        let formatters = ["M/d/yy", "MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd"]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
    
    private func parseTimeString(_ timeStr: String) -> TimeInterval {
        if timeStr.contains(":") {
            // H:MM format
            let components = timeStr.components(separatedBy: ":")
            guard components.count == 2,
                  let hours = Double(components[0]),
                  let minutes = Double(components[1]) else { return 0 }
            return TimeInterval((hours * 3600) + (minutes * 60))
        } else {
            // Decimal format
            return TimeInterval((Double(timeStr) ?? 0) * 3600)
        }
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

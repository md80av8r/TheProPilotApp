//
//  ExcelExportService.swift
//  TheProPilotApp
//
//  Generates Excel files for logbook export
//

import Foundation

// MARK: - Excel Export Service
class ExcelExportService {
    static let shared = ExcelExportService()

    private init() {}

    // MARK: - Generate Logbook Excel
    func generateLogbookExcel(trips: [Trip], monthName: String? = nil) -> URL? {
        // Create CSV data (Excel-compatible)
        var csvContent = generateCSVHeader()

        // Sort trips by date
        let sortedTrips = trips.sorted { $0.date < $1.date }

        for trip in sortedTrips {
            for leg in trip.legs {
                let row = generateCSVRow(trip: trip, leg: leg)
                csvContent += row
            }
        }

        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let filename: String
        if let month = monthName {
            let sanitizedMonth = month.replacingOccurrences(of: " ", with: "_")
            filename = "ProPilot_Logbook_\(sanitizedMonth).csv"
        } else {
            filename = "ProPilot_Logbook_\(dateString).csv"
        }

        // Write to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write Excel file: \(error)")
            return nil
        }
    }

    // MARK: - CSV Header
    private func generateCSVHeader() -> String {
        let columns = [
            "Date",
            "Flight Number",
            "Departure",
            "Arrival",
            "OUT",
            "OFF",
            "ON",
            "IN",
            "Block Time",
            "Flight Time",
            "Aircraft",
            "Trip Number",
            "Pilot Role",
            "PF/PM",
            "Night Takeoff",
            "Night Landing",
            "Deadhead",
            "Notes"
        ]

        return columns.joined(separator: ",") + "\n"
    }

    // MARK: - Generate CSV Row
    private func generateCSVRow(trip: Trip, leg: FlightLeg) -> String {
        // Date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let flightDate = leg.flightDate ?? trip.date

        let values: [String] = [
            dateFormatter.string(from: flightDate),
            escapeCSV(leg.flightNumber),
            escapeCSV(leg.departure),
            escapeCSV(leg.arrival),
            escapeCSV(leg.isDeadhead ? leg.deadheadOutTime : leg.outTime),
            escapeCSV(leg.offTime),
            escapeCSV(leg.onTime),
            escapeCSV(leg.isDeadhead ? leg.deadheadInTime : leg.inTime),
            formatMinutes(leg.blockMinutes()),
            formatMinutes(leg.calculateFlightMinutes()),
            escapeCSV(trip.aircraft),
            escapeCSV(trip.tripNumber),
            escapeCSV(trip.pilotRole.rawValue),
            escapeCSV(leg.legPilotRole.shortName),
            leg.nightTakeoff ? "Yes" : "No",
            leg.nightLanding ? "Yes" : "No",
            leg.isDeadhead ? "Yes" : "No",
            escapeCSV(trip.notes)
        ]

        return values.joined(separator: ",") + "\n"
    }

    // MARK: - Helpers
    private func escapeCSV(_ value: String) -> String {
        // If value contains comma, quote, or newline, wrap in quotes
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    // MARK: - Generate Summary Excel
    func generateSummaryExcel(
        totalBlockMinutes: Int,
        totalPICMinutes: Int,
        totalFlights: Int,
        nightTakeoffs: Int,
        nightLandings: Int,
        monthName: String
    ) -> URL? {
        var csvContent = "ProPilot Flight Summary - \(monthName)\n\n"
        csvContent += "Category,Value\n"
        csvContent += "Total Block Time,\(formatMinutes(totalBlockMinutes))\n"
        csvContent += "Total Block Hours,\(String(format: "%.1f", Double(totalBlockMinutes) / 60.0))\n"
        csvContent += "Total PIC Time,\(formatMinutes(totalPICMinutes))\n"
        csvContent += "Total PIC Hours,\(String(format: "%.1f", Double(totalPICMinutes) / 60.0))\n"
        csvContent += "Total Flights,\(totalFlights)\n"
        csvContent += "Night Takeoffs,\(nightTakeoffs)\n"
        csvContent += "Night Landings,\(nightLandings)\n"

        let sanitizedMonth = monthName.replacingOccurrences(of: " ", with: "_")
        let filename = "ProPilot_Summary_\(sanitizedMonth).csv"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write summary file: \(error)")
            return nil
        }
    }

    // MARK: - Generate Full Export with Multiple Sheets (ZIP)
    func generateFullExportZip(trips: [Trip], monthName: String) -> URL? {
        // Generate logbook CSV
        guard let logbookURL = generateLogbookExcel(trips: trips, monthName: monthName) else {
            return nil
        }

        // Calculate summary stats
        var totalBlock = 0
        var totalPIC = 0
        var flights = 0
        var nightTO = 0
        var nightLDG = 0

        for trip in trips {
            totalBlock += trip.totalBlockMinutes
            if trip.pilotRole == .captain || trip.pilotRole == .solo {
                totalPIC += trip.totalBlockMinutes
            }
            flights += trip.legs.count
            for leg in trip.legs {
                if leg.nightTakeoff { nightTO += 1 }
                if leg.nightLanding { nightLDG += 1 }
            }
        }

        // Generate summary CSV (created but not yet returned - ZIP implementation needed)
        guard let _ = generateSummaryExcel(
            totalBlockMinutes: totalBlock,
            totalPICMinutes: totalPIC,
            totalFlights: flights,
            nightTakeoffs: nightTO,
            nightLandings: nightLDG,
            monthName: monthName
        ) else {
            return logbookURL // Return just logbook if summary fails
        }

        // For now, just return the logbook URL
        // A full ZIP implementation would require additional libraries
        return logbookURL
    }
}

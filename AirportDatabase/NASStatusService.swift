//
//  NASStatusService.swift
//  TheProPilotApp
//
//  FAA National Airspace System (NAS) Status Service
//  Fetches real-time flow control data: Ground Delay Programs, Airspace Flow Programs,
//  Ground Stops, and Airport Closures from the FAA NAS Status API.
//
//  API: https://nasstatus.faa.gov/api/airport-status-information
//  NOTE: API returns XML, not JSON
//

import Foundation
import SwiftUI

// MARK: - NAS Status Models

/// Ground Delay Program - delays assigned before departure
struct GroundDelayProgram: Identifiable, Codable {
    let id = UUID()
    let airportCode: String
    let reason: String
    let averageDelay: String
    let maxDelay: String

    var averageMinutes: Int? {
        parseDelayMinutes(averageDelay)
    }

    var maxMinutes: Int? {
        parseDelayMinutes(maxDelay)
    }

    private func parseDelayMinutes(_ delay: String) -> Int? {
        var totalMinutes = 0
        let lowercased = delay.lowercased()

        // Parse hours
        if let hourRange = lowercased.range(of: #"(\d+)\s*hour"#, options: .regularExpression) {
            let hourStr = lowercased[hourRange].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(hourStr) {
                totalMinutes += hours * 60
            }
        }

        // Parse minutes
        if let minRange = lowercased.range(of: #"(\d+)\s*minute"#, options: .regularExpression) {
            let minStr = lowercased[minRange].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let mins = Int(minStr) {
                totalMinutes += mins
            }
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }

    enum CodingKeys: String, CodingKey {
        case airportCode, reason, averageDelay, maxDelay
    }
}

/// Airspace Flow Program - delays for specific routes/airspace
struct AirspaceFlowProgram: Identifiable, Codable {
    let id = UUID()
    let controlElement: String
    let reason: String
    let startTime: String
    let endTime: String
    let averageDelay: String
    let floor: String?
    let ceiling: String?

    var averageMinutes: Int? {
        parseDelayMinutes(averageDelay)
    }

    var activeTimeRange: String {
        "\(startTime)Z - \(endTime)Z"
    }

    var altitudeRange: String? {
        guard let floor = floor, let ceiling = ceiling else { return nil }
        let floorFL = floor == "000" ? "SFC" : "FL\(floor)"
        let ceilingFL = "FL\(ceiling)"
        return "\(floorFL) - \(ceilingFL)"
    }

    private func parseDelayMinutes(_ delay: String) -> Int? {
        var totalMinutes = 0
        let lowercased = delay.lowercased()

        if let hourRange = lowercased.range(of: #"(\d+)\s*hour"#, options: .regularExpression) {
            let hourStr = lowercased[hourRange].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(hourStr) {
                totalMinutes += hours * 60
            }
        }

        if let minRange = lowercased.range(of: #"(\d+)\s*minute"#, options: .regularExpression) {
            let minStr = lowercased[minRange].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let mins = Int(minStr) {
                totalMinutes += mins
            }
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }

    enum CodingKeys: String, CodingKey {
        case controlElement, reason, startTime, endTime, averageDelay, floor, ceiling
    }
}

/// Ground Stop - complete halt of departures to an airport
struct GroundStop: Identifiable, Codable {
    let id = UUID()
    let airportCode: String
    let reason: String
    let endTime: String?

    enum CodingKeys: String, CodingKey {
        case airportCode, reason, endTime
    }
}

/// Airport Closure
struct AirportClosure: Identifiable, Codable {
    let id = UUID()
    let airportCode: String
    let reason: String
    let startTime: String
    let reopenTime: String

    enum CodingKeys: String, CodingKey {
        case airportCode, reason, startTime, reopenTime
    }
}

/// Complete NAS Status Response
struct NASStatus: Codable {
    let updateTime: Date
    let groundDelayPrograms: [GroundDelayProgram]
    let airspaceFlowPrograms: [AirspaceFlowProgram]
    let groundStops: [GroundStop]
    let airportClosures: [AirportClosure]

    /// Check if an airport has any active delays/restrictions
    func hasDelays(for airportCode: String) -> Bool {
        let code = normalizeAirportCode(airportCode)
        return groundDelayPrograms.contains { normalizeAirportCode($0.airportCode) == code } ||
               groundStops.contains { normalizeAirportCode($0.airportCode) == code } ||
               airportClosures.contains { normalizeAirportCode($0.airportCode) == code }
    }

    /// Get all delays for a specific airport
    func delays(for airportCode: String) -> AirportFlowStatus {
        let code = normalizeAirportCode(airportCode)
        return AirportFlowStatus(
            airportCode: airportCode.uppercased(),
            groundDelayProgram: groundDelayPrograms.first { normalizeAirportCode($0.airportCode) == code },
            groundStop: groundStops.first { normalizeAirportCode($0.airportCode) == code },
            closure: airportClosures.first { normalizeAirportCode($0.airportCode) == code }
        )
    }

    /// Get severity level for an airport (for sorting/display)
    func severityLevel(for airportCode: String) -> Int {
        let code = normalizeAirportCode(airportCode)
        if airportClosures.contains(where: { normalizeAirportCode($0.airportCode) == code }) { return 3 }
        if groundStops.contains(where: { normalizeAirportCode($0.airportCode) == code }) { return 2 }
        if groundDelayPrograms.contains(where: { normalizeAirportCode($0.airportCode) == code }) { return 1 }
        return 0
    }

    /// Normalize airport code (FAA uses 3-letter, we use ICAO 4-letter for US)
    private func normalizeAirportCode(_ code: String) -> String {
        let upper = code.uppercased()
        // If it's a 3-letter FAA code, we need to match against both
        // If it's a 4-letter ICAO starting with K, strip the K for comparison
        if upper.count == 4 && upper.hasPrefix("K") {
            return String(upper.dropFirst())
        }
        return upper
    }
}

/// Flow status for a single airport
struct AirportFlowStatus {
    let airportCode: String
    let groundDelayProgram: GroundDelayProgram?
    let groundStop: GroundStop?
    let closure: AirportClosure?

    var hasAnyDelay: Bool {
        groundDelayProgram != nil || groundStop != nil || closure != nil
    }

    var statusColor: Color {
        if closure != nil { return .purple }
        if groundStop != nil { return .red }
        if groundDelayProgram != nil { return .orange }
        return .green
    }

    var statusIcon: String {
        if closure != nil { return "xmark.circle.fill" }
        if groundStop != nil { return "stop.circle.fill" }
        if groundDelayProgram != nil { return "clock.badge.exclamationmark.fill" }
        return "checkmark.circle.fill"
    }

    var statusText: String {
        if closure != nil { return "CLOSED" }
        if groundStop != nil { return "GROUND STOP" }
        if let gdp = groundDelayProgram { return "GDP: \(gdp.averageDelay)" }
        return "No Delays"
    }
}

// MARK: - NAS Status Service

class NASStatusService: ObservableObject {
    static let shared = NASStatusService()

    private let apiURL = "https://nasstatus.faa.gov/api/airport-status-information"
    private var cachedStatus: NASStatus?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 120 // 2 minutes

    @Published var currentStatus: NASStatus?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var lastUpdated: Date?

    private init() {}

    /// Fetch current NAS status (uses cache if recent)
    func fetchStatus(forceRefresh: Bool = false) async throws -> NASStatus {
        // Return cached if still valid
        if !forceRefresh,
           let cached = cachedStatus,
           let fetchTime = lastFetchTime,
           Date().timeIntervalSince(fetchTime) < cacheValiditySeconds {
            return cached
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        guard let url = URL(string: apiURL) else {
            throw NASStatusError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NASStatusError.networkError
        }

        let status = try parseNASStatusXML(from: data)

        // Update cache
        cachedStatus = status
        lastFetchTime = Date()

        // Debug logging
        print("📡 NAS Status fetched: \(status.groundDelayPrograms.count) GDPs, \(status.groundStops.count) Ground Stops, \(status.airportClosures.count) Closures")
        for gdp in status.groundDelayPrograms {
            print("   GDP: \(gdp.airportCode) - \(gdp.averageDelay)")
        }

        await MainActor.run {
            currentStatus = status
            lastUpdated = Date()
            lastError = nil
        }

        return status
    }

    /// Get flow status for a specific airport
    func getAirportStatus(for airportCode: String) async throws -> AirportFlowStatus {
        let status = try await fetchStatus()
        let flowStatus = status.delays(for: airportCode)
        print("🔍 Looking up \(airportCode): found GDP=\(flowStatus.groundDelayProgram != nil)")
        return flowStatus
    }

    /// Check if airport has any delays (quick check)
    func hasDelays(for airportCode: String) async -> Bool {
        do {
            let status = try await fetchStatus()
            return status.hasDelays(for: airportCode)
        } catch {
            print("NAS Status error: \(error)")
            return false
        }
    }

    // MARK: - XML Parsing

    private func parseNASStatusXML(from data: Data) throws -> NASStatus {
        let parser = NASXMLParser(data: data)
        guard parser.parse() else {
            throw NASStatusError.parsingError
        }
        return parser.nasStatus
    }
}

// MARK: - XML Parser

private class NASXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var currentElement = ""
    private var currentDelayType = ""
    private var elementStack: [String] = []

    // Current parsing state
    private var currentGDP: [String: String] = [:]
    private var currentAFP: [String: String] = [:]
    private var currentGroundStop: [String: String] = [:]
    private var currentClosure: [String: String] = [:]
    private var currentText = ""

    // Results
    private var updateTimeStr = ""
    private var groundDelayPrograms: [GroundDelayProgram] = []
    private var airspaceFlowPrograms: [AirspaceFlowProgram] = []
    private var groundStops: [GroundStop] = []
    private var airportClosures: [AirportClosure] = []

    var nasStatus: NASStatus {
        let updateTime = parseUpdateTime(updateTimeStr) ?? Date()
        return NASStatus(
            updateTime: updateTime,
            groundDelayPrograms: groundDelayPrograms,
            airspaceFlowPrograms: airspaceFlowPrograms,
            groundStops: groundStops,
            airportClosures: airportClosures
        )
    }

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() -> Bool {
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        elementStack.append(elementName)
        currentText = ""

        switch elementName {
        case "Ground_Delay":
            currentGDP = [:]
        case "Airspace_Flow":
            currentAFP = [:]
        case "Program": // Ground Stop
            currentGroundStop = [:]
        case "Airport": // Closure
            currentClosure = [:]
        case "Name":
            // Will capture delay type name
            break
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Determine context
        let parentElement = elementStack.count > 1 ? elementStack[elementStack.count - 2] : ""

        switch elementName {
        case "Update_Time":
            updateTimeStr = trimmedText

        case "Name":
            if parentElement == "Delay_type" {
                currentDelayType = trimmedText
            }

        // Ground Delay Program fields
        case "ARPT":
            if currentDelayType == "Ground Delay Programs" {
                currentGDP["ARPT"] = trimmedText
            } else if currentDelayType == "Ground Stops" {
                currentGroundStop["ARPT"] = trimmedText
            } else if currentDelayType == "Airport Closures" {
                currentClosure["ARPT"] = trimmedText
            }

        case "Reason":
            if currentDelayType == "Ground Delay Programs" {
                currentGDP["Reason"] = trimmedText
            } else if currentDelayType == "Airspace Flow Programs" {
                currentAFP["Reason"] = trimmedText
            } else if currentDelayType == "Ground Stops" {
                currentGroundStop["Reason"] = trimmedText
            } else if currentDelayType == "Airport Closures" {
                currentClosure["Reason"] = trimmedText
            }

        case "Avg":
            if currentDelayType == "Ground Delay Programs" {
                currentGDP["Avg"] = trimmedText
            } else if currentDelayType == "Airspace Flow Programs" {
                currentAFP["Avg"] = trimmedText
            }

        case "Max":
            currentGDP["Max"] = trimmedText

        // AFP fields
        case "CTL_Element":
            currentAFP["CTL_Element"] = trimmedText

        case "AFP_StartTime":
            currentAFP["AFP_StartTime"] = trimmedText

        case "AFP_EndTime":
            currentAFP["AFP_EndTime"] = trimmedText

        case "Floor":
            currentAFP["Floor"] = trimmedText

        case "Ceiling":
            currentAFP["Ceiling"] = trimmedText

        // Ground Stop fields
        case "End_Time":
            currentGroundStop["End_Time"] = trimmedText

        // Closure fields
        case "Start":
            currentClosure["Start"] = trimmedText

        case "Reopen":
            currentClosure["Reopen"] = trimmedText

        // End of records
        case "Ground_Delay":
            if let arpt = currentGDP["ARPT"] {
                let gdp = GroundDelayProgram(
                    airportCode: arpt,
                    reason: currentGDP["Reason"] ?? "Unknown",
                    averageDelay: currentGDP["Avg"] ?? "Unknown",
                    maxDelay: currentGDP["Max"] ?? "Unknown"
                )
                groundDelayPrograms.append(gdp)
                print("📊 Parsed GDP: \(arpt) - \(gdp.averageDelay)")
            }
            currentGDP = [:]

        case "Airspace_Flow":
            if let ctl = currentAFP["CTL_Element"] {
                let afp = AirspaceFlowProgram(
                    controlElement: ctl,
                    reason: currentAFP["Reason"] ?? "Unknown",
                    startTime: currentAFP["AFP_StartTime"] ?? "",
                    endTime: currentAFP["AFP_EndTime"] ?? "",
                    averageDelay: currentAFP["Avg"] ?? "Unknown",
                    floor: currentAFP["Floor"],
                    ceiling: currentAFP["Ceiling"]
                )
                airspaceFlowPrograms.append(afp)
            }
            currentAFP = [:]

        case "Program":
            if currentDelayType == "Ground Stops", let arpt = currentGroundStop["ARPT"] {
                let gs = GroundStop(
                    airportCode: arpt,
                    reason: currentGroundStop["Reason"] ?? "Unknown",
                    endTime: currentGroundStop["End_Time"]
                )
                groundStops.append(gs)
                print("🛑 Parsed Ground Stop: \(arpt)")
            }
            currentGroundStop = [:]

        case "Airport":
            if currentDelayType == "Airport Closures", let arpt = currentClosure["ARPT"] {
                let closure = AirportClosure(
                    airportCode: arpt,
                    reason: currentClosure["Reason"] ?? "Unknown",
                    startTime: currentClosure["Start"] ?? "",
                    reopenTime: currentClosure["Reopen"] ?? ""
                )
                airportClosures.append(closure)
                print("🚫 Parsed Closure: \(arpt)")
            }
            currentClosure = [:]

        default:
            break
        }

        elementStack.removeLast()
        currentText = ""
    }

    private func parseUpdateTime(_ timeStr: String) -> Date? {
        // Format: "Sun Jan 4 13:10:55 2026 GMT"
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: timeStr)
    }
}

// MARK: - Errors

enum NASStatusError: Error, LocalizedError {
    case invalidURL
    case networkError
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid FAA NAS Status URL"
        case .networkError:
            return "Failed to connect to FAA NAS Status"
        case .parsingError:
            return "Failed to parse FAA NAS Status data"
        }
    }
}

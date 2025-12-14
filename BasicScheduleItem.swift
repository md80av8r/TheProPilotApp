//
//  BasicScheduleItem.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 7/12/25.
//


// MARK: - Final Compilation Fixes

// Fix for ScheduleStore extension
extension ScheduleStore {
    var lastUpdateTime: Date? {
        return UserDefaults.standard.object(forKey: "scheduleLastUpdate") as? Date
    }
}

// Fix for NOCSettingsStore extensions
extension NOCSettingsStore {
    var lastSuccessfulSync: Date? {
        return UserDefaults.standard.object(forKey: "lastNOCSync") as? Date
    }
    
    var isValidURL: Bool {
        return rosterURL.absoluteString.contains("webcal://") || rosterURL.absoluteString.contains("https://")
    }
    
    var scheduleItems: [BasicScheduleItem] {
        // Parse the calendar data if it exists
        if let data = calendarData {
            return parseICSData(data)
        }
        return []
    }
    
    func testRosterConnection() {
        fetchRosterCalendar()
    }
    
    private func parseICSData(_ data: Data) -> [BasicScheduleItem] {
        // Basic ICS parsing - in a real implementation this would be more robust
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        
        // For now, return empty array - full ICS parsing would go here
        return []
    }
}

// MARK: - Missing Basic Schedule Item
struct BasicScheduleItem: Identifiable {
    let id = UUID()
    let date: Date
    let tripNumber: String
    let departure: String
    let arrival: String
    let blockOut: Date
    let blockOff: Date
    let blockOn: Date
    let blockIn: Date
    let summary: String
    let status: ScheduleStatus
    
    var totalBlockTime: TimeInterval {
        blockIn.timeIntervalSince(blockOut)
    }
    
    // Display title that cleans up "KOFF" -> "Off Duty"
    var displayTitle: String {
        let upper = tripNumber.uppercased()
        if upper.contains("OFF") && !upper.contains("WOFF") {
            return "Off Duty"
        }
        return tripNumber
    }
}

enum ScheduleStatus {
    case activeTrip
    case onDuty
    case offDuty
    case deadhead
}

// MARK: - Fix for Array Extensions
extension Array where Element == Trip {
    var allLegs: [FlightLeg] {
        return self.flatMap { $0.legs }
    }
    
    func totalBlockMinutes() -> Int {
        return self.allLegs.reduce(0) { total, leg in
            return total + leg.blockMinutes()
        }
    }
}

// MARK: - Helper Functions
func getCurrentPerDiemPeriod(trips: [Trip], homeBase: String) -> PerDiemPeriod? {
    let periods = calculatePerDiemPeriods(trips: trips, homeBase: homeBase)
    return periods.first { $0.isOngoing }
}

func formatLogbookDuration(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    return String(format: "%d:%02d", hours, mins)
}
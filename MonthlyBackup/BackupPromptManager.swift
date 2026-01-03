//
//  BackupPromptManager.swift
//  TheProPilotApp
//
//  Manages backup prompts and monthly summary email functionality
//

import SwiftUI
import MessageUI

// MARK: - Backup Prompt Manager
class BackupPromptManager: ObservableObject {
    static let shared = BackupPromptManager()

    // MARK: - Published Properties
    @Published var shouldShowBackupPrompt = false
    @Published var shouldShowMonthlySummary = false
    @Published var monthlySummaryData: MonthlySummaryData?

    // MARK: - UserDefaults Keys
    private let lastBackupPromptKey = "lastBackupPromptDate"
    private let lastBackupDateKey = "lastBackupDate"
    private let lastMonthlySummaryKey = "lastMonthlySummaryDate"
    private let monthlyEmailEnabledKey = "monthlyEmailEnabled"
    private let userEmailKey = "userEmailAddress"
    private let backupPromptIntervalDaysKey = "backupPromptIntervalDays"

    // MARK: - Settings
    var monthlyEmailEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: monthlyEmailEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: monthlyEmailEnabledKey) }
    }

    var userEmail: String {
        get { UserDefaults.standard.string(forKey: userEmailKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userEmailKey) }
    }

    var backupPromptIntervalDays: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: backupPromptIntervalDaysKey)
            return value > 0 ? value : 7 // Default 7 days
        }
        set { UserDefaults.standard.set(newValue, forKey: backupPromptIntervalDaysKey) }
    }

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupDateKey) }
    }

    private var lastBackupPromptDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupPromptKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupPromptKey) }
    }

    private var lastMonthlySummaryDate: Date? {
        get { UserDefaults.standard.object(forKey: lastMonthlySummaryKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastMonthlySummaryKey) }
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Check on App Launch
    func checkOnAppLaunch(tripCount: Int, hasSignificantData: Bool) {
        // Only prompt if user has meaningful data
        guard tripCount > 0 || hasSignificantData else { return }

        checkBackupPrompt()
        checkMonthlySummary()
    }

    // MARK: - Backup Prompt Logic
    private func checkBackupPrompt() {
        let now = Date()
        let calendar = Calendar.current

        // Check if we should show backup prompt
        if let lastPrompt = lastBackupPromptDate {
            // Check if enough days have passed since last prompt
            let daysSincePrompt = calendar.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            if daysSincePrompt < backupPromptIntervalDays {
                return
            }
        }

        // Check if recent backup exists
        if let lastBackup = lastBackupDate {
            let daysSinceBackup = calendar.dateComponents([.day], from: lastBackup, to: now).day ?? 0
            // Don't prompt if backed up within the interval
            if daysSinceBackup < backupPromptIntervalDays {
                return
            }
        }

        // Show prompt
        DispatchQueue.main.async {
            self.shouldShowBackupPrompt = true
        }
    }

    // MARK: - Monthly Summary Logic
    private func checkMonthlySummary() {
        guard monthlyEmailEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        // Check if it's a new month
        if let lastSummary = lastMonthlySummaryDate {
            let lastMonth = calendar.component(.month, from: lastSummary)
            let lastYear = calendar.component(.year, from: lastSummary)
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)

            // Only trigger if we're in a new month
            if lastMonth == currentMonth && lastYear == currentYear {
                return
            }
        }

        // Check if we're in the first 3 days of the month (grace period for summary)
        let dayOfMonth = calendar.component(.day, from: now)
        if dayOfMonth <= 3 {
            DispatchQueue.main.async {
                self.shouldShowMonthlySummary = true
            }
        }
    }

    // MARK: - Actions
    func dismissBackupPrompt() {
        lastBackupPromptDate = Date()
        shouldShowBackupPrompt = false
    }

    func recordBackupCompleted() {
        lastBackupDate = Date()
        lastBackupPromptDate = Date()
        shouldShowBackupPrompt = false
    }

    func dismissMonthlySummary() {
        lastMonthlySummaryDate = Date()
        shouldShowMonthlySummary = false
    }

    func recordMonthlySummarySent() {
        lastMonthlySummaryDate = Date()
        shouldShowMonthlySummary = false
    }

    // MARK: - Generate Monthly Summary
    func generateMonthlySummary(from trips: [Trip]) -> MonthlySummaryData {
        let calendar = Calendar.current
        let now = Date()

        // Get previous month's date range
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) else {
            return MonthlySummaryData.empty
        }

        let components = calendar.dateComponents([.year, .month], from: previousMonth)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return MonthlySummaryData.empty
        }

        // Filter trips for the previous month
        let monthlyTrips = trips.filter { trip in
            trip.date >= monthStart && trip.date <= monthEnd
        }

        // Calculate statistics
        var totalBlockMinutes = 0
        var totalPICMinutes = 0
        var totalFlights = 0
        var lastFlightDate: Date?
        var nightTakeoffs = 0
        var nightLandings = 0

        for trip in monthlyTrips {
            totalBlockMinutes += trip.totalBlockMinutes

            // PIC time - if captain or solo
            if trip.pilotRole == .captain || trip.pilotRole == .solo {
                totalPICMinutes += trip.totalBlockMinutes
            }

            // Count legs
            totalFlights += trip.legs.count

            // Track last flight date
            if let tripLast = trip.legs.last?.flightDate ?? trip.legs.last.map({ _ in trip.date }) {
                if lastFlightDate == nil || tripLast > lastFlightDate! {
                    lastFlightDate = tripLast
                }
            }

            // Night ops
            for leg in trip.legs {
                if leg.nightTakeoff { nightTakeoffs += 1 }
                if leg.nightLanding { nightLandings += 1 }
            }
        }

        // Format month name
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthName = monthFormatter.string(from: previousMonth)

        return MonthlySummaryData(
            monthName: monthName,
            totalBlockMinutes: totalBlockMinutes,
            totalPICMinutes: totalPICMinutes,
            totalFlights: totalFlights,
            lastFlightDate: lastFlightDate,
            nightTakeoffs: nightTakeoffs,
            nightLandings: nightLandings,
            tripCount: monthlyTrips.count,
            monthStart: monthStart,
            monthEnd: monthEnd
        )
    }

    // MARK: - Days Since Backup
    var daysSinceBackup: Int? {
        guard let lastBackup = lastBackupDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastBackup, to: Date()).day
    }

    var backupStatusText: String {
        if let days = daysSinceBackup {
            if days == 0 {
                return "Backed up today"
            } else if days == 1 {
                return "Backed up yesterday"
            } else {
                return "Last backup: \(days) days ago"
            }
        } else {
            return "No recent backup"
        }
    }
}

// MARK: - Monthly Summary Data
struct MonthlySummaryData {
    let monthName: String
    let totalBlockMinutes: Int
    let totalPICMinutes: Int
    let totalFlights: Int
    let lastFlightDate: Date?
    let nightTakeoffs: Int
    let nightLandings: Int
    let tripCount: Int
    let monthStart: Date
    let monthEnd: Date

    static let empty = MonthlySummaryData(
        monthName: "",
        totalBlockMinutes: 0,
        totalPICMinutes: 0,
        totalFlights: 0,
        lastFlightDate: nil,
        nightTakeoffs: 0,
        nightLandings: 0,
        tripCount: 0,
        monthStart: Date(),
        monthEnd: Date()
    )

    // MARK: - Formatted Values
    var formattedTotalTime: String {
        let hours = totalBlockMinutes / 60
        let mins = totalBlockMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    var formattedTotalTimeDecimal: String {
        let hours = Double(totalBlockMinutes) / 60.0
        return String(format: "%.1f", hours)
    }

    var formattedPICTime: String {
        let hours = totalPICMinutes / 60
        let mins = totalPICMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    var formattedPICTimeDecimal: String {
        let hours = Double(totalPICMinutes) / 60.0
        return String(format: "%.1f", hours)
    }

    var formattedLastFlightDate: String {
        guard let date = lastFlightDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Email Body
    func generateEmailBody() -> String {
        """
        ProPilot Monthly Flight Summary
        \(monthName)

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        FLIGHT STATISTICS

        Total Time:          \(formattedTotalTime) (\(formattedTotalTimeDecimal) hours)
        Total PIC Time:      \(formattedPICTime) (\(formattedPICTimeDecimal) hours)
        Total Flights:       \(totalFlights)
        Trips Completed:     \(tripCount)
        Date of Last Flight: \(formattedLastFlightDate)

        NIGHT OPERATIONS

        Night Takeoffs:      \(nightTakeoffs)
        Night Landings:      \(nightLandings)

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        This summary was automatically generated by ProPilot.

        View your complete logbook in the app or download
        the attached Excel file for detailed records.

        Fly safe!

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Generated by ProPilot - The Professional Pilot App
        """
    }

    func generateEmailSubject() -> String {
        "ProPilot Monthly Summary - \(monthName)"
    }
}

//
//  BackupPromptView.swift
//  TheProPilotApp
//
//  Backup prompt modal shown on app launch
//

import SwiftUI
import MessageUI

struct BackupPromptView: View {
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @ObservedObject var backupManager = BackupPromptManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingBackup = false
    @State private var backupComplete = false
    @State private var backupError: String?
    @State private var showingShareSheet = false
    @State private var backupURL: URL?

    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentBlue)
                        .padding(.top, 20)

                    // Title
                    Text("Backup Your Data")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    // Status
                    VStack(spacing: 8) {
                        Text(backupManager.backupStatusText)
                            .font(.subheadline)
                            .foregroundColor(statusColor)

                        if let days = backupManager.daysSinceBackup, days > 7 {
                            Text("We recommend backing up at least weekly")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)

                    // Data Summary
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "airplane")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Trips")
                            Spacer()
                            Text("\(logbookStore.trips.count)")
                                .foregroundColor(LogbookTheme.textSecondary)
                        }

                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Flight Legs")
                            Spacer()
                            Text("\(totalLegs)")
                                .foregroundColor(LogbookTheme.textSecondary)
                        }

                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Total Time")
                            Spacer()
                            Text(formattedTotalTime)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)

                    Spacer()

                    // Success Message
                    if backupComplete {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Backup created successfully!")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                    }

                    // Error Message
                    if let error = backupError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: createBackup) {
                            HStack {
                                if isCreatingBackup {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text(backupComplete ? "Backup Complete" : "Backup Now")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(backupComplete ? Color.green : LogbookTheme.accentBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isCreatingBackup || backupComplete)

                        Button(action: remindLater) {
                            Text("Remind Me Later")
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        backupManager.dismissBackupPrompt()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = backupURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Computed Properties

    private var totalLegs: Int {
        logbookStore.trips.reduce(0) { $0 + $1.legs.count }
    }

    private var totalBlockMinutes: Int {
        logbookStore.trips.reduce(0) { $0 + $1.totalBlockMinutes }
    }

    private var formattedTotalTime: String {
        let hours = totalBlockMinutes / 60
        let mins = totalBlockMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    private var statusColor: Color {
        guard let days = backupManager.daysSinceBackup else {
            return .orange
        }
        if days <= 3 {
            return .green
        } else if days <= 7 {
            return LogbookTheme.accentBlue
        } else {
            return .orange
        }
    }

    // MARK: - Actions

    private func createBackup() {
        isCreatingBackup = true
        backupError = nil

        Task {
            do {
                // Create JSON backup
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted

                let jsonData = try encoder.encode(logbookStore.trips)

                // Generate filename with date
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm"
                let dateString = formatter.string(from: Date())
                let filename = "ProPilot_Backup_\(dateString).json"

                // Save to temp directory
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(filename)
                try jsonData.write(to: fileURL)

                await MainActor.run {
                    backupURL = fileURL
                    isCreatingBackup = false
                    backupComplete = true
                    backupManager.recordBackupCompleted()

                    // Show share sheet after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingShareSheet = true
                    }

                    // Auto-dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingBackup = false
                    backupError = "Backup failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func remindLater() {
        backupManager.dismissBackupPrompt()
        dismiss()
    }
}

// MARK: - Monthly Summary Email View

struct MonthlySummaryEmailView: View {
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @ObservedObject var backupManager = BackupPromptManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var summaryData: MonthlySummaryData?
    @State private var showingEmailComposer = false
    @State private var excelURL: URL?
    @State private var isGeneratingExcel = false

    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentBlue)
                        .padding(.top, 20)

                    // Title
                    if let data = summaryData {
                        Text("Monthly Summary")
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text(data.monthName)
                            .font(.title2)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }

                    // Stats Grid
                    if let data = summaryData {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MonthlySummaryStatCard(label: "Total Time", value: data.formattedTotalTime, icon: "clock.fill", color: LogbookTheme.accentBlue)
                            MonthlySummaryStatCard(label: "PIC Time", value: data.formattedPICTime, icon: "person.fill", color: LogbookTheme.accentGreen)
                            MonthlySummaryStatCard(label: "Flights", value: "\(data.totalFlights)", icon: "airplane", color: LogbookTheme.accentOrange)
                            MonthlySummaryStatCard(label: "Last Flight", value: data.formattedLastFlightDate, icon: "calendar", color: .purple)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Email Settings Reminder
                    if backupManager.userEmail.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Set your email in settings to receive monthly summaries")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: sendEmail) {
                            HStack {
                                if isGeneratingExcel {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "envelope")
                                }
                                Text("Email Summary")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LogbookTheme.accentBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isGeneratingExcel)

                        Button(action: {
                            backupManager.dismissMonthlySummary()
                            dismiss()
                        }) {
                            Text("Skip This Month")
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        backupManager.dismissMonthlySummary()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            summaryData = backupManager.generateMonthlySummary(from: logbookStore.trips)
        }
        .sheet(isPresented: $showingEmailComposer) {
            if let data = summaryData {
                MonthlySummaryMailView(
                    summaryData: data,
                    excelURL: excelURL,
                    onComplete: {
                        backupManager.recordMonthlySummarySent()
                        dismiss()
                    }
                )
            }
        }
    }

    private func sendEmail() {
        guard let data = summaryData else { return }

        isGeneratingExcel = true

        Task {
            // Generate Excel file
            let url = await generateExcelFile(for: data)

            await MainActor.run {
                excelURL = url
                isGeneratingExcel = false
                showingEmailComposer = true
            }
        }
    }

    private func generateExcelFile(for data: MonthlySummaryData) async -> URL? {
        // Filter trips for the month
        let monthlyTrips = logbookStore.trips.filter { trip in
            trip.date >= data.monthStart && trip.date <= data.monthEnd
        }

        return ExcelExportService.shared.generateLogbookExcel(
            trips: monthlyTrips,
            monthName: data.monthName
        )
    }
}

// MARK: - Monthly Summary Stat Card (unique name to avoid conflict)

struct MonthlySummaryStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Monthly Summary Mail View

struct MonthlySummaryMailView: UIViewControllerRepresentable {
    let summaryData: MonthlySummaryData
    let excelURL: URL?
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator

        // Set recipient from settings
        let userEmail = BackupPromptManager.shared.userEmail
        if !userEmail.isEmpty {
            composer.setToRecipients([userEmail])
        }

        composer.setSubject(summaryData.generateEmailSubject())
        composer.setMessageBody(summaryData.generateEmailBody(), isHTML: false)

        // Attach Excel file if available
        if let url = excelURL {
            do {
                let data = try Data(contentsOf: url)
                composer.addAttachmentData(
                    data,
                    mimeType: "text/csv",
                    fileName: url.lastPathComponent
                )
            } catch {
                print("Failed to attach Excel file: \(error)")
            }
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MonthlySummaryMailView

        init(_ parent: MonthlySummaryMailView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if result == .sent {
                parent.onComplete()
            }
            controller.dismiss(animated: true)
        }
    }
}

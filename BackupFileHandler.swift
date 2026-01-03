//
//  BackupFileHandler.swift
//  ProPilot
//
//  Handles incoming backup JSON files with user confirmation
//

import SwiftUI
import Foundation

// MARK: - Simple Backup Format (for Electronic Logbook exports)
struct SimpleBackupFormat: Codable {
    let exportDate: Date
    let appVersion: String
    let perDiemRate: Double
    let trips: [Trip]
}

// MARK: - Backup File Handler
class BackupFileHandler: ObservableObject {
    static let shared = BackupFileHandler()
    
    @Published var pendingBackupURL: URL?
    @Published var showingConfirmation = false
    @Published var backupPreview: BackupPreviewData?
    @Published var importError: String?
    @Published var showingError = false
    @Published var isProcessing = false
    @Published var importSuccess = false
    @Published var importedTripCount = 0
    
    // Store reference passed from app
    var logbookStore: SwiftDataLogBookStore?
    
    private init() {}
    
    // MARK: - Handle Incoming File
    func handleIncomingFile(_ url: URL) {
        print("📦 Received backup file: \(url.lastPathComponent)")
        
        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Copy to temp location for processing
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
            
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            // Try to parse and validate the backup
            if let preview = parseBackupPreview(from: tempURL) {
                DispatchQueue.main.async {
                    self.pendingBackupURL = tempURL
                    self.backupPreview = preview
                    self.showingConfirmation = true
                }
            } else {
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                showError("This doesn't appear to be a valid ProPilot backup file.")
            }
        } catch {
            print("❌ Error handling backup file: \(error)")
            showError("Failed to read backup file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Parse Backup Preview
    private func parseBackupPreview(from url: URL) -> BackupPreviewData? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // First, try to decode as the FULL AppBackupData format
            if let backup = try? decoder.decode(AppBackupData.self, from: data) {
                print("✅ Detected FULL backup format")
                return parseFullBackupPreview(backup)
            }
            
            // Fall back to SIMPLE format (exportDate, appVersion, perDiemRate, trips)
            print("⚠️ Trying SIMPLE backup format")
            let simpleBackup = try decoder.decode(SimpleBackupFormat.self, from: data)
            print("✅ Detected SIMPLE backup format")
            return parseSimpleBackupPreview(simpleBackup)
            
        } catch {
            print("❌ Failed to parse backup: \(error)")
            return nil
        }
    }
    
    private func parseFullBackupPreview(_ backup: AppBackupData) -> BackupPreviewData {
        // Calculate total flight time from legs
        var totalMinutes = 0
        for trip in backup.trips {
            for logpage in trip.logpages {
                for leg in logpage.legs {
                    if let blockMins = calculateBlockMinutes(outTime: leg.outTime, inTime: leg.inTime) {
                        totalMinutes += blockMins
                    }
                }
            }
        }
        
        // Get date range
        let sortedTrips = backup.trips.sorted { $0.date < $1.date }
        let firstDate = sortedTrips.first?.date
        let lastDate = sortedTrips.last?.date
        
        return BackupPreviewData(
            tripCount: backup.trips.count,
            totalFlightMinutes: totalMinutes,
            backupDate: backup.backupDate,
            backupVersion: backup.backupVersion,
            firstFlightDate: firstDate,
            lastFlightDate: lastDate
        )
    }
    
    private func parseSimpleBackupPreview(_ backup: SimpleBackupFormat) -> BackupPreviewData {
        // Calculate total flight time from legs
        var totalMinutes = 0
        for trip in backup.trips {
            for logpage in trip.logpages {
                for leg in logpage.legs {
                    if let blockMins = calculateBlockMinutes(outTime: leg.outTime, inTime: leg.inTime) {
                        totalMinutes += blockMins
                    }
                }
            }
        }
        
        // Get date range
        let sortedTrips = backup.trips.sorted { $0.date < $1.date }
        let firstDate = sortedTrips.first?.date
        let lastDate = sortedTrips.last?.date
        
        return BackupPreviewData(
            tripCount: backup.trips.count,
            totalFlightMinutes: totalMinutes,
            backupDate: backup.exportDate,
            backupVersion: backup.appVersion,
            firstFlightDate: firstDate,
            lastFlightDate: lastDate
        )
    }
    
    // MARK: - Calculate Block Minutes from HHMM strings
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
    
    // MARK: - Confirm Import
    func confirmImport(store: SwiftDataLogBookStore) {
        guard let url = pendingBackupURL else {
            showError("No backup file to import.")
            return
        }

        isProcessing = true

        Task {
            do {
                let data = try Data(contentsOf: url)

                // Use the new nuclear reset function which properly handles relationships
                print("🔥 Using Nuclear Reset for clean import...")
                let success = await store.nuclearResetAndImport(data)

                await MainActor.run {
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: url)

                    if success {
                        self.importedTripCount = store.trips.count
                        self.isProcessing = false
                        self.showingConfirmation = false
                        self.pendingBackupURL = nil
                        self.backupPreview = nil
                        self.importSuccess = true

                        // Post notification for UI update
                        NotificationCenter.default.post(
                            name: .backupRestored,
                            object: nil,
                            userInfo: ["tripCount": store.trips.count]
                        )

                        print("✅ Backup restored successfully: \(store.trips.count) trips with legs in SwiftData")
                    } else {
                        self.isProcessing = false
                        self.showError("Failed to import backup. Check console for details.")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.showError("Failed to restore backup: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cancel Import
    func cancelImport() {
        if let url = pendingBackupURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingBackupURL = nil
        backupPreview = nil
        showingConfirmation = false
    }
    
    // MARK: - Show Error
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            self.importError = message
            self.showingError = true
        }
    }
}

// MARK: - Backup Preview Data
struct BackupPreviewData {
    let tripCount: Int
    let totalFlightMinutes: Int
    let backupDate: Date
    let backupVersion: String
    let firstFlightDate: Date?
    let lastFlightDate: Date?
    
    var formattedFlightTime: String {
        let hours = totalFlightMinutes / 60
        let minutes = totalFlightMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let first = firstFlightDate, let last = lastFlightDate {
            return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
        }
        return "Unknown"
    }
}

// MARK: - Backup Import Confirmation View
struct BackupImportConfirmationView: View {
    @ObservedObject var handler = BackupFileHandler.shared
    @ObservedObject var store: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Warning Banner
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Will Be Replaced")
                            .font(.headline)
                            .foregroundColor(.black)
                        Text("This action cannot be undone")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.orange)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Data Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Current Data (Will Be Deleted)", systemImage: "trash")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            HStack {
                                Text("Trips:")
                                Spacer()
                                Text("\(store.trips.count)")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(LogbookTheme.cardBackground)
                        .cornerRadius(12)
                        
                        // Arrow
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title)
                            .foregroundColor(LogbookTheme.accentOrange)
                        
                        // New Data Section
                        if let preview = handler.backupPreview {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Backup Data (Will Be Imported)", systemImage: "square.and.arrow.down")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                                
                                VStack(spacing: 8) {
                                    BackupInfoRow(label: "Trips", value: "\(preview.tripCount)", color: LogbookTheme.accentGreen)
                                    BackupInfoRow(label: "Total Flight Time", value: preview.formattedFlightTime, color: LogbookTheme.accentBlue)
                                    BackupInfoRow(label: "Date Range", value: preview.dateRange, color: .white)
                                    BackupInfoRow(label: "Backup Created", value: preview.backupDate.formatted(date: .abbreviated, time: .shortened), color: .gray)
                                    BackupInfoRow(label: "Version", value: preview.backupVersion, color: .gray)
                                }
                            }
                            .padding()
                            .background(LogbookTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        
                        // Confirmation Text
                        Text("Are you sure you want to replace your current \(store.trips.count) trips with this backup containing \(handler.backupPreview?.tripCount ?? 0) trips?")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                handler.confirmImport(store: store)
                            }) {
                                HStack {
                                    if handler.isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.down.doc.fill")
                                    }
                                    Text(handler.isProcessing ? "Importing..." : "Yes, Replace My Data")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(handler.isProcessing ? Color.gray : Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(handler.isProcessing)
                            
                            Button(action: {
                                handler.cancelImport()
                            }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(LogbookTheme.navyLight)
                                    .cornerRadius(12)
                            }
                            .disabled(handler.isProcessing)
                        }
                    }
                    .padding()
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handler.cancelImport()
                    }
                    .disabled(handler.isProcessing)
                }
            }
        }
    }
}

// MARK: - Backup Info Row Helper
private struct BackupInfoRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(LogbookTheme.navyLight)
        .cornerRadius(6)
    }
}

// MARK: - View Modifier for Backup Import Handling
struct BackupImportHandlerModifier: ViewModifier {
    @StateObject private var handler = BackupFileHandler.shared
    let store: SwiftDataLogBookStore  // Direct parameter, no @EnvironmentObject

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Store reference for file imports
                handler.logbookStore = store
            }
            .sheet(isPresented: $handler.showingConfirmation) {
                BackupImportConfirmationView(store: store)
            }
            .alert("Import Error", isPresented: $handler.showingError) {
                Button("OK") { }
            } message: {
                Text(handler.importError ?? "Unknown error")
            }
            .alert("Import Successful", isPresented: $handler.importSuccess) {
                Button("OK") { }
            } message: {
                Text("Successfully imported \(handler.importedTripCount) trips!")
            }
    }
}

// MARK: - View Extension
extension View {
    func backupImportHandler(store: SwiftDataLogBookStore) -> some View {
        modifier(BackupImportHandlerModifier(store: store))
    }
}

// MARK: - Notification Names Extension
extension Notification.Name {
    static let backupRestored = Notification.Name("backupRestored")
}

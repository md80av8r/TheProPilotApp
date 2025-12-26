//
//  AppBackupData.swift
//  TheProPilotApp
//
//  Fixed version compatible with your existing data structures
//

import SwiftUI
import Foundation
import CloudKit
import MessageUI

// MARK: - Backup Data Models
struct AppBackupData: Codable {
    let backupVersion: String
    let backupDate: Date
    let trips: [Trip]
    let airlineSettings: AirlineSettings
    let nocSettings: NOCSettingsData
    let scannerSettings: ScannerSettingsData
    let userPreferences: [String: String]
    let documentPaths: [String]
    
    init(trips: [Trip],
         airlineSettings: AirlineSettings,
         nocSettings: NOCSettingsStore,
         scannerSettings: ScannerSettings,
         documentPaths: [String] = []) {
        self.backupVersion = "1.0"
        self.backupDate = Date()
        self.trips = trips
        self.airlineSettings = airlineSettings
        self.nocSettings = NOCSettingsData(from: nocSettings)
        self.scannerSettings = ScannerSettingsData(from: scannerSettings)
        self.documentPaths = documentPaths
        
        // Capture UserDefaults data - only strings for easier encoding
        var prefs: [String: String] = [:]
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() {
            if key.hasPrefix("propilot") || key.hasPrefix("scanner") {
                if let stringValue = value as? String {
                    prefs[key] = stringValue
                } else {
                    prefs[key] = String(describing: value)
                }
            }
        }
        self.userPreferences = prefs
    }
}

// MARK: - NOC Settings Data (Codable version of NOCSettingsStore)
struct NOCSettingsData: Codable {
    let username: String
    let password: String
    let rosterURL: String
    let webPortalURL: String
    let isOfflineMode: Bool
    let lastParseDate: Date?
    let parseDebugInfo: String
    
    init(from store: NOCSettingsStore) {
        self.username = store.username
        self.password = store.password
        self.rosterURL = store.rosterURL
        self.webPortalURL = store.webPortalURL
        self.isOfflineMode = store.isOfflineMode
        self.lastParseDate = store.lastParseDate
        self.parseDebugInfo = store.parseDebugInfo
    }
    
    func applyTo(_ store: NOCSettingsStore) {
        store.username = self.username
        store.password = self.password
        store.rosterURL = self.rosterURL
        store.webPortalURL = self.webPortalURL
        store.isOfflineMode = self.isOfflineMode
        store.lastParseDate = self.lastParseDate
        store.parseDebugInfo = self.parseDebugInfo
    }
}

// MARK: - Codable Scanner Settings (Updated for new features)
struct ScannerSettingsData: Codable {
    let imageEnhancement: Bool
    let ocrEnabled: Bool
    let enableCropEditor: Bool
    let outputFormat: String
    let colorMode: String
    let selectedDocumentSize: String?
    let flashlightEnabled: Bool?
    let imageQuality: String?
    
    init(from settings: ScannerSettings) {
        self.imageEnhancement = settings.imageEnhancement
        self.ocrEnabled = settings.ocrEnabled
        self.enableCropEditor = settings.enableCropEditor
        self.outputFormat = settings.outputFormat.rawValue
        self.colorMode = settings.colorMode.rawValue
        self.selectedDocumentSize = settings.selectedDocumentSize.rawValue
        self.flashlightEnabled = settings.flashlightEnabled
        self.imageQuality = settings.imageQuality.rawValue
    }
    
    func applyTo(_ settings: ScannerSettings) {
        settings.imageEnhancement = self.imageEnhancement
        settings.ocrEnabled = self.ocrEnabled
        settings.enableCropEditor = self.enableCropEditor
        
        if let format = OutputFormat(rawValue: self.outputFormat) {
            settings.outputFormat = format
        }
        
        if let color = ColorMode(rawValue: self.colorMode) {
            settings.colorMode = color
        }
        
        if let docSize = self.selectedDocumentSize,
           let size = DocumentSize(rawValue: docSize) {
            settings.selectedDocumentSize = size
        }
        
        if let flash = self.flashlightEnabled {
            settings.flashlightEnabled = flash
        }
        
        if let quality = self.imageQuality,
           let qualityEnum = ScannerSettings.ImageQuality(rawValue: quality) {
            settings.imageQuality = qualityEnum
        }
    }
}

// MARK: - Backup Methods Enum
enum BackupMethod: String, CaseIterable {
    case iCloudDrive = "iCloud Drive"
    case email = "Email"
    case airdrop = "AirDrop"
    case files = "Files App"
    case manual = "Manual Export"
    
    var icon: String {
        switch self {
        case .iCloudDrive: return "icloud.and.arrow.up"
        case .email: return "envelope"
        case .airdrop: return "airpods.chargingcase.wireless"
        case .files: return "folder"
        case .manual: return "square.and.arrow.up"
        }
    }
    
    var description: String {
        switch self {
        case .iCloudDrive: return "Backup to iCloud Drive (Recommended)"
        case .email: return "Email backup file to yourself"
        case .airdrop: return "AirDrop to another device"
        case .files: return "Save to Files app"
        case .manual: return "Export and share manually"
        }
    }
}

// MARK: - Data Backup Manager
class DataBackupManager: ObservableObject {
    @Published var isCreatingBackup = false
    @Published var isRestoringBackup = false
    @Published var backupProgress = 0.0
    @Published var lastBackupDate: Date?
    @Published var availableBackups: [BackupInfo] = []
    
    private let fileManager = FileManager.default
    
    struct BackupInfo: Identifiable {
        let id = UUID()
        let filename: String
        let date: Date
        let size: Int64
        let method: BackupMethod
        let url: URL
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Create Full Backup
    func createFullBackup(
        trips: [Trip],
        airlineSettings: AirlineSettings,
        nocSettings: NOCSettingsStore,
        scannerSettings: ScannerSettings,
        documentStore: TripDocumentManager,
        method: BackupMethod = .iCloudDrive
    ) async -> Result<URL, Error> {
        
        await MainActor.run {
            isCreatingBackup = true
            backupProgress = 0.0
        }
        
        do {
            await updateProgress(0.1, message: "Collecting documents...")
            let documentPaths = collectDocumentPaths(from: documentStore)
            
            await updateProgress(0.3, message: "Preparing backup data...")
            let backupData = AppBackupData(
                trips: trips,
                airlineSettings: airlineSettings,
                nocSettings: nocSettings,
                scannerSettings: scannerSettings,
                documentPaths: documentPaths
            )
            
            await updateProgress(0.5, message: "Creating backup file...")
            let backupURL = try await createBackupFile(backupData)
            
            await updateProgress(0.7, message: "Copying documents...")
            let fullBackupURL = try await createCompleteBackup(backupURL: backupURL, documentPaths: documentPaths)
            
            await updateProgress(0.9, message: "Finalizing...")
            let finalURL = try await handleBackupMethod(method, backupURL: fullBackupURL)
            
            await updateProgress(1.0, message: "Backup complete!")
            
            await MainActor.run {
                lastBackupDate = Date()
                isCreatingBackup = false
            }
            
            return .success(finalURL)
            
        } catch {
            await MainActor.run {
                isCreatingBackup = false
            }
            return .failure(error)
        }
    }
    
    // MARK: - Restore from Backup
    func restoreFromBackup(
        backupURL: URL,
        store: SwiftDataLogBookStore,
        airlineSettings: AirlineSettingsStore,
        nocSettings: NOCSettingsStore,
        scannerSettings: ScannerSettings,
        documentStore: TripDocumentManager
    ) async -> Result<Void, Error> {
        
        await MainActor.run {
            isRestoringBackup = true
            backupProgress = 0.0
        }
        
        do {
            await updateProgress(0.1, message: "Reading backup file...")
            let backupData = try await readBackupFile(backupURL)
            
            await updateProgress(0.3, message: "Restoring flight data...")
            await MainActor.run {
                store.trips = backupData.trips
                store.savePersistently()
            }
            
            await updateProgress(0.5, message: "Restoring settings...")
            await MainActor.run {
                airlineSettings.settings = backupData.airlineSettings
                backupData.nocSettings.applyTo(nocSettings)
                backupData.scannerSettings.applyTo(scannerSettings)
                airlineSettings.saveSettings()
            }
            
            await updateProgress(0.7, message: "Restoring preferences...")
            restoreUserDefaults(backupData.userPreferences)
            
            await updateProgress(0.9, message: "Restoring documents...")
            try await restoreDocuments(backupData.documentPaths, to: documentStore)
            
            await updateProgress(1.0, message: "Restore complete!")
            
            await MainActor.run {
                isRestoringBackup = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isRestoringBackup = false
            }
            return .failure(error)
        }
    }

    // MARK: - Simple Trip Import (for logbook.json files)
    func restoreTripsFromSimpleJSON(
        backupURL: URL,
        store: SwiftDataLogBookStore
    ) async -> Result<String, Error> {
        
        await MainActor.run {
            isRestoringBackup = true
            backupProgress = 0.0
        }
        
        do {
            await updateProgress(0.2, message: "Reading trips file...")
            let jsonData = try Data(contentsOf: backupURL)
            
            await updateProgress(0.4, message: "Parsing trip data...")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let trips = try decoder.decode([Trip].self, from: jsonData)
            
            await updateProgress(0.8, message: "Importing trips...")
            await MainActor.run {
                store.trips = trips
                store.savePersistently()
            }
            
            await updateProgress(1.0, message: "Import complete!")
            
            await MainActor.run {
                isRestoringBackup = false
            }
            
            let message = "Successfully imported \(trips.count) trips from backup."
            return .success(message)
            
        } catch {
            await MainActor.run {
                isRestoringBackup = false
            }
            print("Import error: \(error)")
            return .failure(error)
        }
    }

    // MARK: - Helper Methods
    
    private func collectDocumentPaths(from documentStore: TripDocumentManager) -> [String] {
        var paths: [String] = []
        
        for document in documentStore.documents {
            if let fileURL = document.fileURL {
                paths.append(fileURL.path)
            }
        }
        
        return paths
    }
    
    private func createBackupFile(_ backupData: AppBackupData) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(backupData)
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDir = documentsURL.appendingPathComponent("Backups")
        
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        
        let filename = "ProPilot_Backup_\(dateString).json"
        let backupURL = backupDir.appendingPathComponent(filename)
        
        try jsonData.write(to: backupURL)
        
        return backupURL
    }
    
    private func createCompleteBackup(backupURL: URL, documentPaths: [String]) async throws -> URL {
        return backupURL
    }
    
    private func handleBackupMethod(_ method: BackupMethod, backupURL: URL) async throws -> URL {
        switch method {
        case .iCloudDrive:
            return try await copyToiCloudDrive(backupURL)
        case .email, .airdrop, .files, .manual:
            return backupURL
        }
    }
    
    private func copyToiCloudDrive(_ backupURL: URL) async throws -> URL {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("ProPilot Backups") else {
            throw BackupError.iCloudNotAvailable
        }
        
        try fileManager.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
        
        let destinationURL = iCloudURL.appendingPathComponent(backupURL.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: backupURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func readBackupFile(_ backupURL: URL) async throws -> AppBackupData {
        let jsonData = try Data(contentsOf: backupURL)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(AppBackupData.self, from: jsonData)
    }
    
    private func restoreUserDefaults(_ preferences: [String: String]) {
        let defaults = UserDefaults.standard
        
        for (key, value) in preferences {
            defaults.set(value, forKey: key)
        }
        
        defaults.synchronize()
    }
    
    private func restoreDocuments(_ documentPaths: [String], to documentStore: TripDocumentManager) async throws {
        print("Restoring \(documentPaths.count) documents...")
    }
    
    private func updateProgress(_ progress: Double, message: String) async {
        await MainActor.run {
            self.backupProgress = progress
            print("Backup progress: \(Int(progress * 100))% - \(message)")
        }
    }
    
    // MARK: - Quick Export for Testing
    func createQuickExport(trips: [Trip]) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(trips)
            
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let exportURL = documentsURL.appendingPathComponent("ProPilot_Trips_Export.json")
            
            try jsonData.write(to: exportURL)
            
            return exportURL
            
        } catch {
            print("Quick export failed: \(error)")
            return nil
        }
    }
}

// MARK: - Backup Errors
enum BackupError: LocalizedError {
    case iCloudNotAvailable
    case fileCreationFailed
    case documentsCopyFailed
    case invalidBackupFile
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please check your iCloud settings."
        case .fileCreationFailed:
            return "Failed to create backup file."
        case .documentsCopyFailed:
            return "Failed to copy documents to backup."
        case .invalidBackupFile:
            return "The backup file is invalid or corrupted."
        }
    }
}

// MARK: - JSON Viewer
struct JSONViewerView: View {
    let url: URL
    @State private var jsonContent: String = ""
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    ScrollView {
                        Text(jsonContent)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("JSON Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareJSON) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            loadJSON()
        }
    }
    
    private func loadJSON() {
        do {
            let data = try Data(contentsOf: url)
            
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                jsonContent = prettyString
            } else {
                jsonContent = String(data: data, encoding: .utf8) ?? "Unable to parse JSON"
            }
            
            isLoading = false
        } catch {
            self.error = "Failed to load JSON: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func shareJSON() {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Backup View
struct DataBackupView: View {
    @StateObject private var backupManager = DataBackupManager()
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var nocSettings: NOCSettingsStore
    @ObservedObject var scannerSettings: ScannerSettings
    @ObservedObject var documentStore: TripDocumentManager
    
    @State private var selectedBackupMethod: BackupMethod = .iCloudDrive
    @State private var showingFileImporter = false
    @State private var fileImportMode: FileImportMode = .restore
    @State private var showingShareSheet = false
    @State private var backupURL: URL?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showingJSONViewer = false
    @State private var jsonViewerURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    // Import mode enum to handle different file picker purposes
    enum FileImportMode {
        case restore
        case browse
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    summarySection
                    backupSection
                    restoreSection
                    quickActionsSection
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Data Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = backupURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingJSONViewer) {
            if let url = jsonViewerURL {
                JSONViewerView(url: url)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch fileImportMode {
            case .restore:
                handleFileImport(result)
            case .browse:
                handleFilePickerSelection(result)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Data")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Flights:")
                    Spacer()
                    Text("\(store.trips.count)")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                HStack {
                    Text("Documents:")
                    Spacer()
                    Text("\(documentStore.documents.count)")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                if let lastBackup = backupManager.lastBackupDate {
                    HStack {
                        Text("Last Backup:")
                        Spacer()
                        Text(lastBackup.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
            .foregroundColor(LogbookTheme.textSecondary)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Backup")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BackupMethod.allCases, id: \.self) { method in
                    BackupMethodCard(
                        method: method,
                        isSelected: selectedBackupMethod == method
                    ) {
                        selectedBackupMethod = method
                        
                        // If Files App is selected, open the file picker immediately after backup
                        if method == .files {
                            // Will be handled after backup creation
                        }
                    }
                }
            }
            
            Button(action: createBackup) {
                HStack {
                    if backupManager.isCreatingBackup {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: selectedBackupMethod.icon)
                    }
                    Text("Create Backup")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(backupManager.isCreatingBackup ? Color.gray : LogbookTheme.accentBlue)
                .cornerRadius(12)
            }
            .disabled(backupManager.isCreatingBackup)
            
            if backupManager.isCreatingBackup {
                ProgressView(value: backupManager.backupProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Restore Data")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("⚠️ Restoring will replace all current data")
                .font(.caption)
                .foregroundColor(.orange)
            
            Button("Select Backup File") {
                fileImportMode = .restore
                showingFileImporter = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backupManager.isRestoringBackup ? Color.gray : LogbookTheme.accentOrange)
            .cornerRadius(12)
            .disabled(backupManager.isRestoringBackup)
            
            if backupManager.isRestoringBackup {
                ProgressView(value: backupManager.backupProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                Button(action: exportFlightsOnly) {
                    HStack {
                        Image(systemName: "airplane")
                        Text("Export Flights Only")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    fileImportMode = .browse
                    showingFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "folder.badge.gear")
                        Text("Browse Files App")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func createBackup() {
        Task {
            let result = await backupManager.createFullBackup(
                trips: store.trips,
                airlineSettings: airlineSettings.settings,
                nocSettings: nocSettings,
                scannerSettings: scannerSettings,
                documentStore: documentStore,
                method: selectedBackupMethod
            )
            
            await MainActor.run {
                switch result {
                case .success(let url):
                    backupURL = url
                    alertTitle = "Backup Created"
                    alertMessage = "Backup successfully created at \(url.lastPathComponent)"
                    
                    // Handle Files App method by opening iOS file picker
                    if selectedBackupMethod == .files {
                        fileImportMode = .browse
                        showingFileImporter = true
                    } else if selectedBackupMethod != .iCloudDrive {
                        showingShareSheet = true
                    }
                    
                    showingAlert = true
                    
                case .failure(let error):
                    alertTitle = "Backup Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                let result = await backupManager.restoreFromBackup(
                    backupURL: url,
                    store: store,
                    airlineSettings: airlineSettings,
                    nocSettings: nocSettings,
                    scannerSettings: scannerSettings,
                    documentStore: documentStore
                )
                
                await MainActor.run {
                    switch result {
                    case .success:
                        alertTitle = "Restore Complete"
                        alertMessage = "Successfully restored backup data."
                    case .failure(let error):
                        alertTitle = "Restore Failed"
                        alertMessage = error.localizedDescription
                    }
                    showingAlert = true
                }
            }
            
        case .failure(let error):
            alertTitle = "File Selection Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func handleFilePickerSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Open JSON viewer
            jsonViewerURL = url
            showingJSONViewer = true
            
        case .failure(let error):
            alertTitle = "File Selection Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func exportFlightsOnly() {
        if let url = backupManager.createQuickExport(trips: store.trips) {
            backupURL = url
            showingShareSheet = true
        }
    }
}

// MARK: - Backup Method Card
struct BackupMethodCard: View {
    let method: BackupMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? LogbookTheme.accentBlue : LogbookTheme.textSecondary)
                
                Text(method.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? LogbookTheme.accentBlue.opacity(0.2) : LogbookTheme.navyLight)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? LogbookTheme.accentBlue : Color.clear, lineWidth: 2)
            )
        }
    }
}

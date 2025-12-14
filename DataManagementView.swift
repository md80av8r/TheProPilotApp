//
//  DataManagementView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 8/25/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @ObservedObject var store: LogBookStore
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var exportData: Data?
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var mergeOnImport = true
    @State private var showingImportOptions = false
    @State private var showingExportOptions = false
    @State private var selectedExportRange: ExportDateRange = .lastMonth
    @State private var exportFormat: ExportFormat = .summary
    
    enum ExportDateRange: String, CaseIterable {
        case lastMonth = "Last Month"
        case last3Months = "Last 3 Months"
        case last6Months = "Last 6 Months"
        case yearToDate = "Year to Date"
        case last12Months = "Last 12 Months"
        case all = "All Flights"
        
        var dateRange: (start: Date?, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .lastMonth:
                let start = calendar.date(byAdding: .month, value: -1, to: now)
                return (start, now)
            case .last3Months:
                let start = calendar.date(byAdding: .month, value: -3, to: now)
                return (start, now)
            case .last6Months:
                let start = calendar.date(byAdding: .month, value: -6, to: now)
                return (start, now)
            case .yearToDate:
                let year = calendar.component(.year, from: now)
                let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
                return (start, now)
            case .last12Months:
                let start = calendar.date(byAdding: .year, value: -1, to: now)
                return (start, now)
            case .all:
                return (nil, now)
            }
        }
    }
    
    enum ExportFormat: String, CaseIterable {
        case summary = "Flight Summary"
        case detailed = "Detailed with Times"
        case csv = "CSV Spreadsheet"
        case json = "JSON Format"
    }
    
    var body: some View {
        List {
            // Current Status
            Section("Current Logbook") {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Total Flights")
                            .font(.headline)
                        Text("\(store.trips.count) trips")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(totalFlightHours, specifier: "%.1f") hrs")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
            
            // Export by Date Range
            Section("Export by Date Range") {
                Button(action: { showingExportOptions = true }) {
                    Label("Export Flights by Period", systemImage: "calendar.badge.clock")
                        .foregroundColor(.blue)
                }
                
                Text("Export specific time periods for applications or records")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Export Options
            Section("Backup & Export") {
                Button(action: exportAllFlights) {
                    Label("Export All Flights", systemImage: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                
                Button(action: createBackup) {
                    Label("Create Backup File", systemImage: "doc.badge.plus")
                        .foregroundColor(.green)
                }
                
                Text("Save your flight data to share or backup")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Import Options
            Section("Import & Recovery") {
                Button(action: { showingImportOptions = true }) {
                    Label("Import Flights", systemImage: "square.and.arrow.down")
                        .foregroundColor(.orange)
                }
                
                Button(action: attemptRecovery) {
                    Label("Attempt Data Recovery", systemImage: "arrow.clockwise")
                        .foregroundColor(.purple)
                }
                
                Text("Import from backup or recover lost data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Emergency Recovery
            Section("Manual Recovery Help") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lost your flight data when switching apps?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("1. Check if you have the old ProPilotApp still installed")
                    Text("2. Export flights from the old app")
                    Text("3. Import them here using the button above")
                    Text("4. Or create a manual JSON file with your flights")
                    
                    Button("Show Manual Recovery Guide") {
                        showManualRecoveryGuide()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Import Options", isPresented: $showingImportOptions) {
            Button("Merge with existing flights") {
                mergeOnImport = true
                showingFilePicker = true
            }
            Button("Replace all flights") {
                mergeOnImport = false
                showingFilePicker = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to handle the imported flights?")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exportFileURL {
                ShareSheet(items: [fileURL])
            } else if let data = exportData {
                ShareSheet(items: [data])
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                selectedRange: $selectedExportRange,
                selectedFormat: $exportFormat,
                onExport: performDateRangeExport,
                onCancel: { showingExportOptions = false }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalFlightHours: Double {
        Double(store.trips.reduce(0) { $0 + $1.totalBlockMinutes }) / 60.0
    }
    
    // MARK: - Actions
    
    private func exportAllFlights() {
        guard let data = store.exportToJSON() else {
            showAlert(title: "Export Failed", message: "Unable to export flight data")
            return
        }
        
        exportData = data
        exportFileURL = createExportFile(data: data, extension: "json")
        showingShareSheet = true
    }
    
    private func createBackup() {
        guard let backupURL = store.createBackupFile() else {
            showAlert(title: "Backup Failed", message: "Unable to create backup file")
            return
        }
        
        exportData = try? Data(contentsOf: backupURL)
        exportFileURL = backupURL
        showingShareSheet = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let importResult = store.importFromJSON(data, mergeWithExisting: mergeOnImport)
                
                showAlert(
                    title: importResult.success ? "Import Successful" : "Import Failed",
                    message: importResult.message
                )
            } catch {
                showAlert(title: "Import Error", message: "Could not read file: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            showAlert(title: "File Selection Failed", message: error.localizedDescription)
        }
    }
    
    private func attemptRecovery() {
        let success = store.attemptDataRecovery()
        showAlert(
            title: success ? "Recovery Successful" : "Recovery Failed",
            message: success ? "Found and recovered flight data!" : "No recoverable data found. Try manual import instead."
        )
    }
    
    private func showManualRecoveryGuide() {
        let guide = """
        Manual Recovery Steps:
        
        1. Create a file named "flights.json"
        2. Format your flights like this:
        
        [
          {
            "id": "123",
            "tripNumber": "1234",
            "aircraft": "B737",
            "date": "2025-08-25T12:00:00Z",
            "tatStart": "0800",
            "crew": [],
            "notes": "Your notes",
            "legs": [
              {
                "id": "456",
                "departure": "DFW",
                "arrival": "LAX",
                "outTime": "0800",
                "offTime": "0805",
                "onTime": "1155",
                "inTime": "1200"
              }
            ]
          }
        ]
        
        3. Import using the Import button above
        """
        
        showAlert(title: "Manual Recovery Guide", message: guide)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    // MARK: - Date Range Export Functions
    
    private func formatTime(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    private func createExportFile(data: Data, extension fileExtension: String) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let rangeName = selectedExportRange.rawValue.replacingOccurrences(of: " ", with: "_")
        let filename = "flight_export_\(rangeName)_\(timestamp).\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func performDateRangeExport() {
        showingExportOptions = false
        
        let range = selectedExportRange.dateRange
        let filteredTrips = store.trips.filter { trip in
            if let startDate = range.start {
                return trip.date >= startDate && trip.date <= range.end
            } else {
                return trip.date <= range.end
            }
        }.sorted(by: { $0.date > $1.date })
        
        switch exportFormat {
        case .summary:
            exportSummaryFormat(trips: filteredTrips)
        case .detailed:
            exportDetailedFormat(trips: filteredTrips)
        case .csv:
            exportCSVFormat(trips: filteredTrips)
        case .json:
            exportJSONFormat(trips: filteredTrips)
        }
    }
    
    private func exportSummaryFormat(trips: [Trip]) {
        var output = "Flight Summary - \(selectedExportRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        let totalHours = Double(trips.reduce(0) { $0 + $1.totalBlockMinutes }) / 60.0
        let operatingTrips = trips.filter { $0.tripType == .operating }
        let deadheadTrips = trips.filter { $0.tripType == .deadhead }
        let simulatorTrips = trips.filter { $0.tripType == .simulator }
        
        output += "Total Flights: \(trips.count)\n"
        output += "Total Hours: \(String(format: "%.1f", totalHours))\n"
        output += "Operating: \(operatingTrips.count) flights\n"
        output += "Deadhead: \(deadheadTrips.count) flights\n"
        output += "Simulator: \(simulatorTrips.count) sessions\n\n"
        
        output += "Date\t\tTrip#\t\tRoute\t\t\tBlock\n"
        output += "----------------------------------------------------\n"
        
        for trip in trips {
            let dateStr = trip.date.formatted(date: .abbreviated, time: .omitted)
            let tripNum = trip.tripType == .simulator ? "SIM" : (trip.tripNumber.isEmpty ? "N/A" : trip.tripNumber)
            let route = trip.displayTitle
            let blockTime = formatTime(minutes: trip.totalBlockMinutes)
            
            output += "\(dateStr)\t\(tripNum)\t\t\(route)\t\t\(blockTime)\n"
        }
        
        exportData = output.data(using: .utf8)
        if let data = exportData {
            exportFileURL = createExportFile(data: data, extension: "txt")
        }
        showingShareSheet = true
    }
    
    private func exportDetailedFormat(trips: [Trip]) {
        var output = "Detailed Flight Log - \(selectedExportRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        for trip in trips {
            output += "Date: \(trip.date.formatted())\n"
            output += "Trip #: \(trip.tripNumber)\n"
            output += "Aircraft: \(trip.aircraft)\n"
            output += "Type: \(trip.tripType.rawValue)\n"
            
            if trip.tripType == .simulator {
                output += "Simulator Time: \(formatTime(minutes: trip.totalBlockMinutes))\n"
            } else {
                output += "\nLegs:\n"
                for (index, leg) in trip.legs.enumerated() {
                    output += "  Leg \(index + 1): \(leg.departure) → \(leg.arrival)\n"
                    if !leg.outTime.isEmpty {
                        output += "    Out: \(leg.outTime)\n"
                    }
                    if !leg.offTime.isEmpty {
                        output += "    Off: \(leg.offTime)\n"
                    }
                    if !leg.onTime.isEmpty {
                        output += "    On: \(leg.onTime)\n"
                    }
                    if !leg.inTime.isEmpty {
                        output += "    In: \(leg.inTime)\n"
                    }
                }
            }
            
            output += "Block Time: \(formatTime(minutes: trip.totalBlockMinutes))\n"
            output += "Flight Time: \(formatTime(minutes: trip.totalFlightMinutes))\n"
            
            if !trip.notes.isEmpty {
                output += "Notes: \(trip.notes)\n"
            }
            
            output += "\n-------------------------------------\n\n"
        }
        
        exportData = output.data(using: .utf8)
        if let data = exportData {
            exportFileURL = createExportFile(data: data, extension: "txt")
        }
        showingShareSheet = true
    }
    
    private func exportCSVFormat(trips: [Trip]) {
        var csv = "Date,Trip Number,Type,Aircraft,Route,Block Time,Flight Time,Notes\n"
        
        for trip in trips {
            let date = trip.date.formatted(date: .abbreviated, time: .omitted)
            let tripNum = trip.tripNumber.isEmpty ? "" : trip.tripNumber
            let route = trip.displayTitle.replacingOccurrences(of: ",", with: ";")
            let notes = trip.notes.replacingOccurrences(of: ",", with: ";")
            
            csv += "\"\(date)\",\"\(tripNum)\",\"\(trip.tripType.rawValue)\",\"\(trip.aircraft)\",\"\(route)\",\"\(formatTime(minutes: trip.totalBlockMinutes))\",\"\(formatTime(minutes: trip.totalFlightMinutes))\",\"\(notes)\"\n"
        }
        
        exportData = csv.data(using: .utf8)
        if let data = exportData {
            exportFileURL = createExportFile(data: data, extension: "csv")
        }
        showingShareSheet = true
    }
    
    private func exportJSONFormat(trips: [Trip]) {
        do {
            let data = try JSONEncoder().encode(trips)
            exportData = data
            exportFileURL = createExportFile(data: data, extension: "json")
            showingShareSheet = true
        } catch {
            showAlert(title: "Export Failed", message: "Unable to encode trips to JSON: \(error.localizedDescription)")
        }
    }
}


// MARK: - Export Options View

struct ExportOptionsView: View {
    @Binding var selectedRange: DataManagementView.ExportDateRange
    @Binding var selectedFormat: DataManagementView.ExportFormat
    let onExport: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select Date Range") {
                    Picker("Date Range", selection: $selectedRange) {
                        ForEach(DataManagementView.ExportDateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                }
                
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(DataManagementView.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                }
                
                Section {
                    Button("Export") {
                        onExport()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    NavigationView {
        DataManagementView(store: LogBookStore())
    }
}

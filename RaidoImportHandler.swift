//
//  RaidoImportHandler.swift
//  ProPilot
//
//  Handles RAIDO JSON file imports with preview and confirmation
//

import SwiftUI
import Foundation

// MARK: - RAIDO Import Handler
class RaidoImportHandler: ObservableObject {
    static let shared = RaidoImportHandler()

    @Published var pendingFileURL: URL?
    @Published var showingConfirmation = false
    @Published var importPreview: RaidoImportPreview?
    @Published var importError: String?
    @Published var showingError = false
    @Published var isProcessing = false
    @Published var importSuccess = false
    @Published var importedTripCount = 0

    // Import options
    @Published var groupByDate = true
    @Published var importMode: ImportMode = .addNew

    enum ImportMode: String, CaseIterable {
        case addNew = "Add to Existing"
        case replace = "Replace All"

        var description: String {
            switch self {
            case .addNew: return "Add imported trips to your existing logbook"
            case .replace: return "Replace all trips with imported data"
            }
        }
    }

    // Store reference
    var logbookStore: SwiftDataLogBookStore?

    private init() {}

    // MARK: - Check if File is RAIDO JSON
    static func isRaidoFile(_ url: URL) -> Bool {
        print("🔍 isRaidoFile checking: \(url.lastPathComponent)")
        print("🔍 Full URL: \(url.absoluteString)")

        guard url.pathExtension.lowercased() == "json" else {
            print("🔍 Not a JSON file extension")
            return false
        }

        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        print("🔍 Security-scoped access granted: \(accessing)")

        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy file to temp location first to avoid file coordination issues
        let tempURL: URL
        do {
            let tempDir = FileManager.default.temporaryDirectory
            tempURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("🔍 Copied file to temp: \(tempURL.lastPathComponent)")
        } catch {
            print("❌ Failed to copy file to temp: \(error)")
            // Try reading directly as fallback
            return checkRaidoContent(from: url)
        }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        return checkRaidoContent(from: tempURL)
    }

    /// Helper to check if JSON data is RAIDO format
    private static func checkRaidoContent(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            print("🔍 Read \(data.count) bytes from file")

            // Check if JSON contains "Report" array with RAIDO-specific fields
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 Parsed JSON, top-level keys: \(json.keys.sorted())")

                if let report = json["Report"] as? [[String: Any]], !report.isEmpty {
                    print("🔍 Found Report array with \(report.count) rows")

                    // Check FIRST row for RAIDO key structure
                    // RAIDO exports always have ALL keys in every row (values may be empty)
                    let firstRow = report[0]
                    let keys = Set(firstRow.keys)

                    print("🔍 First row has \(keys.count) keys")
                    print("🔍 Keys: \(keys.sorted())")

                    // Check for RAIDO-specific key names
                    let hasDateField = keys.contains("RaidoLab_TimeMode") || keys.contains("RaidoLab_Name")
                    let hasFlightFields = keys.contains("RaidoLab_Code") &&
                                          keys.contains("RaidoLab_Dep") &&
                                          keys.contains("RaidoLab_Arr")
                    let hasCrewField = keys.contains("CrewOnBoardText")
                    let hasTimeFields = keys.contains("RaidoLab_STD") && keys.contains("RaidoLab_ATD")

                    print("🔍 hasDateField=\(hasDateField), hasFlightFields=\(hasFlightFields)")
                    print("🔍 hasCrewField=\(hasCrewField), hasTimeFields=\(hasTimeFields)")

                    // RAIDO files have these characteristic keys
                    if hasDateField && hasFlightFields {
                        print("✅ RAIDO file detected by key structure")
                        return true
                    }

                    print("❌ Missing required RAIDO keys")
                } else {
                    print("🔍 No 'Report' array found in JSON")
                }
            } else {
                print("🔍 Failed to parse JSON as dictionary")
            }
        } catch {
            print("❌ Error checking RAIDO file: \(error)")
        }

        print("❌ Not a RAIDO file")
        return false
    }

    // MARK: - Handle Incoming File
    func handleIncomingFile(_ url: URL) {
        print("📁 RaidoImportHandler received: \(url.lastPathComponent)")

        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()

        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy to temp location
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")

            try FileManager.default.copyItem(at: url, to: tempURL)

            // Parse and preview
            isProcessing = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let preview = try RaidoImportService.shared.parseRaidoJSON(from: tempURL)

                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.pendingFileURL = tempURL
                        self.importPreview = preview
                        self.showingConfirmation = true
                        print("✅ RAIDO preview ready: \(preview.flightCount) flights")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        try? FileManager.default.removeItem(at: tempURL)
                        self.showError("Failed to parse RAIDO file: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("❌ Error handling RAIDO file: \(error)")
            showError("Failed to read file: \(error.localizedDescription)")
        }
    }

    // MARK: - Confirm Import
    func confirmImport(store: SwiftDataLogBookStore) {
        guard let preview = importPreview else {
            showError("No import data available.")
            return
        }

        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Convert to trips
            let trips = RaidoImportService.shared.convertToTrips(
                from: preview,
                groupByDate: self.groupByDate
            )

            DispatchQueue.main.async {
                switch self.importMode {
                case .replace:
                    store.trips = trips

                case .addNew:
                    // Add new trips, avoiding duplicates by date+flight number
                    var newTrips = store.trips
                    for trip in trips {
                        let isDuplicate = newTrips.contains { existing in
                            Calendar.current.isDate(existing.date, inSameDayAs: trip.date) &&
                            existing.tripNumber == trip.tripNumber
                        }
                        if !isDuplicate {
                            newTrips.append(trip)
                        }
                    }
                    store.trips = newTrips.sorted { $0.date < $1.date }
                }

                store.save()

                // Cleanup
                if let url = self.pendingFileURL {
                    try? FileManager.default.removeItem(at: url)
                }

                self.importedTripCount = trips.count
                self.isProcessing = false
                self.showingConfirmation = false
                self.pendingFileURL = nil
                self.importPreview = nil
                self.importSuccess = true

                print("✅ RAIDO import complete: \(trips.count) trips")
            }
        }
    }

    // MARK: - Cancel Import
    func cancelImport() {
        if let url = pendingFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingFileURL = nil
        importPreview = nil
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

// MARK: - RAIDO Import Confirmation View
struct RaidoImportConfirmationView: View {
    @ObservedObject var handler = RaidoImportHandler.shared
    @ObservedObject var store: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFieldMapping = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "airplane.arrival")
                        .font(.title2)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("RAIDO Import")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Review and import your flight data")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()
                }
                .padding()
                .background(LogbookTheme.accentBlue)

                ScrollView {
                    VStack(spacing: 20) {
                        // Preview Data
                        if let preview = handler.importPreview {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Import Preview", systemImage: "doc.text.magnifyingglass")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentBlue)

                                VStack(spacing: 8) {
                                    RaidoInfoRow(label: "Pilot", value: preview.pilotName, color: .white)
                                    RaidoInfoRow(label: "Employee #", value: preview.employeeNumber, color: .gray)
                                    RaidoInfoRow(label: "Date Range", value: preview.dateRange, color: .white)
                                    RaidoInfoRow(label: "Flights", value: "\(preview.flightCount)", color: LogbookTheme.accentGreen)
                                    RaidoInfoRow(label: "Total Block", value: preview.formattedBlockTime, color: LogbookTheme.accentBlue)
                                    RaidoInfoRow(label: "Takeoffs", value: "\(preview.totalTakeoffs)", color: LogbookTheme.accentOrange)
                                    RaidoInfoRow(label: "Landings", value: "\(preview.totalLandings)", color: LogbookTheme.accentOrange)
                                    RaidoInfoRow(label: "Aircraft Types", value: preview.aircraftTypes.joined(separator: ", "), color: .gray)
                                }
                            }
                            .padding()
                            .background(LogbookTheme.cardBackground)
                            .cornerRadius(12)

                            // Field Mapping Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Detected Field Mapping", systemImage: "arrow.left.arrow.right")
                                        .font(.headline)
                                        .foregroundColor(LogbookTheme.accentGreen)

                                    Spacer()

                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showFieldMapping.toggle()
                                        }
                                    }) {
                                        Image(systemName: showFieldMapping ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    if showFieldMapping {
                                        Group {
                                            RaidoFieldMappingRow(label: "Date", value: preview.fieldMapping.dateField)
                                            RaidoFieldMappingRow(label: "OUT (Block)", value: preview.fieldMapping.outTimeField)
                                            RaidoFieldMappingRow(label: "OFF (Wheels Up)", value: preview.fieldMapping.offTimeField)
                                            RaidoFieldMappingRow(label: "ON (Wheels Down)", value: preview.fieldMapping.onTimeField)
                                            RaidoFieldMappingRow(label: "IN (Block)", value: preview.fieldMapping.inTimeField)
                                            RaidoFieldMappingRow(label: "Landing (X)", value: preview.fieldMapping.landingDesignator)
                                        }

                                        Text("If these don't match your export format, the import may have incorrect data.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(LogbookTheme.cardBackground)
                            .cornerRadius(12)

                            // Flight Records Preview
                            FlightRecordsPreviewSection(flights: preview.flights)

                            // Current Data Warning (if replacing)
                            if handler.importMode == .replace && store.trips.count > 0 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Warning: Data Will Be Replaced", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundColor(.orange)

                                    Text("You currently have \(store.trips.count) trips that will be replaced.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }

                        // Import Options
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Import Options", systemImage: "gearshape")
                                .font(.headline)
                                .foregroundColor(.white)

                            // Group by date toggle
                            Toggle(isOn: $handler.groupByDate) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Group Flights by Date")
                                        .foregroundColor(.white)
                                    Text("Create one trip per day with multiple legs")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .tint(LogbookTheme.accentBlue)

                            Divider().background(Color.gray.opacity(0.3))

                            // Import mode picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Import Mode")
                                    .foregroundColor(.white)

                                Picker("Import Mode", selection: $handler.importMode) {
                                    ForEach(RaidoImportHandler.ImportMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(handler.importMode.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.cardBackground)
                        .cornerRadius(12)

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
                                    Text(handler.isProcessing ? "Importing..." : "Import Flights")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(handler.isProcessing ? Color.gray : LogbookTheme.accentBlue)
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
            .navigationTitle("Import RAIDO Data")
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

// MARK: - RAIDO Field Mapping Row Helper
struct RaidoFieldMappingRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - RAIDO Info Row Helper
struct RaidoInfoRow: View {
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

// MARK: - Flight Records Preview Section
struct FlightRecordsPreviewSection: View {
    let flights: [ParsedRaidoFlight]
    @State private var isExpanded = false
    @State private var selectedFlightIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse
            HStack {
                Label("Preview Flight Records (\(flights.count))", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundColor(LogbookTheme.accentBlue)

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if isExpanded {
                // Flight navigator
                HStack {
                    Button(action: { if selectedFlightIndex > 0 { selectedFlightIndex -= 1 } }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(selectedFlightIndex > 0 ? LogbookTheme.accentBlue : .gray)
                    }
                    .disabled(selectedFlightIndex == 0)

                    Spacer()

                    Text("Flight \(selectedFlightIndex + 1) of \(flights.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { if selectedFlightIndex < flights.count - 1 { selectedFlightIndex += 1 } }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(selectedFlightIndex < flights.count - 1 ? LogbookTheme.accentBlue : .gray)
                    }
                    .disabled(selectedFlightIndex >= flights.count - 1)
                }
                .padding(.vertical, 8)

                // Current flight details
                if selectedFlightIndex < flights.count {
                    let flight = flights[selectedFlightIndex]
                    FlightRecordCard(flight: flight)
                }

                // Quick jump slider
                if flights.count > 10 {
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { Double(selectedFlightIndex) },
                                set: { selectedFlightIndex = Int($0) }
                            ),
                            in: 0...Double(flights.count - 1),
                            step: 1
                        )
                        .tint(LogbookTheme.accentBlue)

                        Text("Drag to jump to any flight")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Flight Record Card
struct FlightRecordCard: View {
    let flight: ParsedRaidoFlight

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }

    var body: some View {
        VStack(spacing: 12) {
            // Date and Flight Number Header
            HStack {
                Text(dateFormatter.string(from: flight.date))
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text(flight.flightNumber)
                    .font(.headline)
                    .foregroundColor(LogbookTheme.accentGreen)

                if flight.didLanding {
                    Image(systemName: "airplane.arrival")
                        .foregroundColor(LogbookTheme.accentOrange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LogbookTheme.navyLight)
            .cornerRadius(8)

            // Route
            HStack(spacing: 16) {
                VStack {
                    Text("FROM")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(flight.departure)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(LogbookTheme.accentBlue)

                VStack {
                    Text("TO")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(flight.arrival)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("AIRCRAFT")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(flight.tailNumber.isEmpty ? flight.aircraftType : flight.tailNumber)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if !flight.tailNumber.isEmpty {
                        Text(flight.aircraftType)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            // Times Grid
            HStack(spacing: 0) {
                TimeColumn(label: "OUT", value: flight.outTime, color: .white)
                TimeColumn(label: "OFF", value: flight.offTime.isEmpty ? "-" : flight.offTime, color: LogbookTheme.accentBlue)
                TimeColumn(label: "ON", value: flight.onTime.isEmpty ? "-" : flight.onTime, color: LogbookTheme.accentBlue)
                TimeColumn(label: "IN", value: flight.inTime, color: .white)
            }

            Divider().background(Color.gray.opacity(0.3))

            // Block Time and Takeoffs/Landings
            HStack {
                VStack(alignment: .leading) {
                    Text("BLOCK TIME")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatBlockTime(flight.blockMinutes))
                        .font(.headline)
                        .foregroundColor(LogbookTheme.accentGreen)
                }

                Spacer()

                HStack(spacing: 16) {
                    VStack {
                        Text("T/O")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(flight.takeoffs)")
                            .font(.headline)
                            .foregroundColor(LogbookTheme.accentOrange)
                    }

                    VStack {
                        Text("LDG")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(flight.landings)")
                            .font(.headline)
                            .foregroundColor(flight.didLanding ? LogbookTheme.accentOrange : .gray)
                    }
                }
            }

            // Crew (if available)
            if !flight.crewText.isEmpty {
                Divider().background(Color.gray.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    Text("CREW")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(flight.crewText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navy)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatBlockTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - Time Column Helper
struct TimeColumn: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - View Modifier for RAIDO Import Handling
struct RaidoImportHandlerModifier: ViewModifier {
    @StateObject private var handler = RaidoImportHandler.shared
    let store: SwiftDataLogBookStore

    func body(content: Content) -> some View {
        content
            .onAppear {
                handler.logbookStore = store
            }
            .sheet(isPresented: $handler.showingConfirmation) {
                RaidoImportConfirmationView(store: store)
            }
            .alert("Import Error", isPresented: $handler.showingError) {
                Button("OK") { }
            } message: {
                Text(handler.importError ?? "Unknown error")
            }
            .alert("Import Successful", isPresented: $handler.importSuccess) {
                Button("OK") { }
            } message: {
                Text("Successfully imported \(handler.importedTripCount) trips from RAIDO!")
            }
    }
}

// MARK: - View Extension
extension View {
    func raidoImportHandler(store: SwiftDataLogBookStore) -> some View {
        modifier(RaidoImportHandlerModifier(store: store))
    }
}

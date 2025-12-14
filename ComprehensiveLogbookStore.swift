// ComprehensiveLogbookStore.swift
// Updated for ForeFlight/LogTen Pro only support
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Comprehensive Logbook Store
class ComprehensiveLogbookStore: ObservableObject {
    @Published var flightEntries: [FlightEntry] = []
    @Published var importStatus: String = ""
    @Published var isProcessing: Bool = false
    
    private lazy var importExportManager = LogbookImportExportManager()
    private let userDefaults = UserDefaults.shared
    private let entriesKey = "ComprehensiveFlightEntries"
    
    init() {
        loadEntries()
    }
    
    // MARK: - Import Functions
    
    func importFromCSV(_ csvData: String, format: LogbookFormat) {
        isProcessing = true
        importStatus = "Processing \(format.displayName) import..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newEntries: [FlightEntry]
            
            switch format {
            case .foreFlight:
                newEntries = self?.importExportManager.importForeFlight(csvData) ?? []
            case .logTenPro:
                newEntries = self?.importExportManager.importLogTenPro(csvData) ?? []
            }
            
            DispatchQueue.main.async {
                self?.flightEntries.append(contentsOf: newEntries)
                self?.saveEntries()
                self?.importStatus = "Imported \(newEntries.count) flight entries from \(format.displayName)"
                self?.isProcessing = false
            }
        }
    }
    
    // MARK: - Export Functions
    
    func exportToCSV(format: LogbookFormat) -> String {
        switch format {
        case .foreFlight:
            return importExportManager.exportForeFlight(flightEntries)
        case .logTenPro:
            return importExportManager.exportLogTenPro(flightEntries)
        }
    }
    
    // MARK: - Persistence
    
    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(flightEntries)
            userDefaults.set(data, forKey: entriesKey)
        } catch {
            print("Failed to save flight entries: \(error)")
        }
    }
    
    private func loadEntries() {
        guard let data = userDefaults.data(forKey: entriesKey) else { return }
        
        do {
            flightEntries = try JSONDecoder().decode([FlightEntry].self, from: data)
        } catch {
            print("Failed to load flight entries: \(error)")
        }
    }
    
    // MARK: - Statistics
    
    var totalFlightTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.flightTime }
    }
    
    var totalPICTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.picTime }
    }
    
    var totalSICTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.sicTime }
    }
    
    var totalNightTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.nightTime }
    }
    
    var totalCrossCountryTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.crossCountryTime }
    }
    
    var totalInstrumentTime: TimeInterval {
        flightEntries.reduce(0) { $0 + $1.instrumentTime }
    }
    
    var totalLandings: Int {
        flightEntries.reduce(0) { $0 + $1.dayLandings + $1.nightLandings }
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - Statistics Header
struct LogbookStatsHeaderView: View {
    @ObservedObject var store: ComprehensiveLogbookStore
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Flight Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(store.formatTime(store.totalFlightTime))
                        .font(.title2.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Entries")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(store.flightEntries.count)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
            
            // Enhanced stats row with ForeFlight focus
            HStack(spacing: 16) {
                StatItemView(title: "PIC", value: store.formatTime(store.totalPICTime), color: LogbookTheme.accentBlue)
                StatItemView(title: "SIC", value: store.formatTime(store.totalSICTime), color: LogbookTheme.accentOrange)
                StatItemView(title: "Night", value: store.formatTime(store.totalNightTime), color: .purple)
                StatItemView(title: "XC", value: store.formatTime(store.totalCrossCountryTime), color: LogbookTheme.accentGreen)
                StatItemView(title: "Inst", value: store.formatTime(store.totalInstrumentTime), color: .yellow)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

// MARK: - Format Buttons (Updated for ForeFlight/LogTen Pro only)
struct ImportFormatButton: View {
    let format: LogbookFormat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: format.iconName)
                    .font(.title2)
                    .foregroundColor(format.color)
                
                HStack(spacing: 4) {
                    Text(format.displayName)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    if format == .foreFlight {
                        Text("★")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("Import")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(format == .foreFlight ? LogbookTheme.accentBlue.opacity(0.1) : LogbookTheme.fieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(format == .foreFlight ? LogbookTheme.accentBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportFormatButton: View {
    let format: LogbookFormat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: format.iconName)
                    .font(.title2)
                    .foregroundColor(format.color)
                
                HStack(spacing: 4) {
                    Text(format.displayName)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    if format == .foreFlight {
                        Text("★")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("Export")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(format == .foreFlight ? LogbookTheme.accentBlue.opacity(0.1) : LogbookTheme.fieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(format == .foreFlight ? LogbookTheme.accentBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Comprehensive Logbook View
struct ComprehensiveLogbookView: View {
    @ObservedObject var store: ComprehensiveLogbookStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats header
                if !store.flightEntries.isEmpty {
                    LogbookStatsHeaderView(store: store)
                        .padding()
                }
                
                // Flight entries list
                if store.flightEntries.isEmpty {
                    emptyStateView
                } else {
                    flightEntriesList
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Electronic Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Flight Entries")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Import flights from ForeFlight or LogTen Pro to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var flightEntriesList: some View {
        List {
            ForEach(store.flightEntries.sorted { $0.date > $1.date }) { entry in
                FlightEntryRowView(entry: entry)
            }
            .onDelete { indexSet in
                let sortedEntries = store.flightEntries.sorted { $0.date > $1.date }
                let entriesToDelete = indexSet.map { sortedEntries[$0] }
                
                for entry in entriesToDelete {
                    if let index = store.flightEntries.firstIndex(where: { $0.id == entry.id }) {
                        store.flightEntries.remove(at: index)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Flight Entry Row (Enhanced)
struct FlightEntryRowView: View {
    let entry: FlightEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text("\(entry.departure) → \(entry.arrival)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let flightNumber = entry.flightNumber {
                        Text(flightNumber)
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            
            // Aircraft and total time row
            HStack {
                Text("\(entry.aircraftType)")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                if !entry.aircraftRegistration.isEmpty && entry.aircraftRegistration != entry.aircraftType {
                    Text("• \(entry.aircraftRegistration)")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                Spacer()
                
                Text("Total: \(entry.formattedTotalTime)")
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentGreen)
            }
            
            // Time details row
            HStack {
                if entry.picTime > 0 {
                    TimeLabel(title: "PIC", time: entry.formattedPICTime, color: LogbookTheme.accentBlue)
                }
                if entry.sicTime > 0 {
                    TimeLabel(title: "SIC", time: entry.formattedSICTime, color: LogbookTheme.accentOrange)
                }
                if entry.nightTime > 0 {
                    TimeLabel(title: "Night", time: entry.formattedNightTime, color: .purple)
                }
                if entry.crossCountryTime > 0 {
                    TimeLabel(title: "XC", time: entry.formattedCrossCountryTime, color: LogbookTheme.accentGreen)
                }
                if entry.instrumentTime > 0 {
                    TimeLabel(title: "Inst", time: entry.formattedInstrumentTime, color: .yellow)
                }
                
                Spacer()
                
                // Pilot role badge
                Text(entry.pilotRole.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.pilotRole == .captain ? LogbookTheme.accentGreen : LogbookTheme.accentOrange)
                    .foregroundColor(.black)
                    .cornerRadius(4)
            }
            
            // Remarks (if any)
            if !entry.remarks.isEmpty {
                Text(entry.remarks)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(LogbookTheme.navyLight)
    }
}

private struct TimeLabel: View {
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(time)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

//
//  LegsExportView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//


import SwiftUI

struct LegsExportView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @State private var showingExportOptions = false
    @State private var selectedDateRange: DateRange = .lastMonth
    @State private var selectedExportFormat: ExportFormat = .summary
    @State private var exportData: Data?
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var sortOption: SortOption = .dateDescending
    
    enum DateRange: String, CaseIterable {
        case lastMonth = "Last Month"
        case last3Months = "Last 3 Months"
        case last6Months = "Last 6 Months"
        case yearToDate = "Year to Date"
        case last12Months = "Last 12 Months"
        case all = "All Time"
        
        var dateRange: (start: Date?, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .lastMonth:
                return (calendar.date(byAdding: .month, value: -1, to: now), now)
            case .last3Months:
                return (calendar.date(byAdding: .month, value: -3, to: now), now)
            case .last6Months:
                return (calendar.date(byAdding: .month, value: -6, to: now), now)
            case .yearToDate:
                let year = calendar.component(.year, from: now)
                return (calendar.date(from: DateComponents(year: year, month: 1, day: 1)), now)
            case .last12Months:
                return (calendar.date(byAdding: .year, value: -1, to: now), now)
            case .all:
                return (nil, now)
            }
        }
    }
    
    enum ExportFormat: String, CaseIterable {
        case summary = "Summary Report"
        case detailed = "Detailed Report"
        case csv = "CSV Export"
        case json = "JSON Export"
    }
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Date (Newest First)"
        case dateAscending = "Date (Oldest First)"
        case tripNumber = "Trip Number"
        case aircraft = "Aircraft"
    }
    
    var filteredAndSortedTrips: [Trip] {
        let range = selectedDateRange.dateRange
        var trips = store.trips.filter { trip in
            if let startDate = range.start {
                return trip.date >= startDate && trip.date <= range.end
            }
            return trip.date <= range.end
        }
        
        switch sortOption {
        case .dateDescending:
            trips.sort { $0.date > $1.date }
        case .dateAscending:
            trips.sort { $0.date < $1.date }
        case .tripNumber:
            trips.sort { $0.tripNumber.localizedStandardCompare($1.tripNumber) == .orderedAscending }
        case .aircraft:
            trips.sort { $0.aircraft.localizedStandardCompare($1.aircraft) == .orderedAscending }
        }
        
        return trips
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Export Controls Bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Date Range Picker
                        Menu {
                            ForEach(DateRange.allCases, id: \.self) { range in
                                Button(action: { selectedDateRange = range }) {
                                    HStack {
                                        Text(range.rawValue)
                                        if selectedDateRange == range {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                Text(selectedDateRange.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.navyLight)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // Sort Options
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortOption = option }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                Image(systemName: "chevron.down")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.navyLight)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Export Button
                        Button(action: { showingExportOptions = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Summary Stats
                    HStack(spacing: 20) {
                        StatLabel(title: "Flights", value: "\(filteredAndSortedTrips.count)")
                        StatLabel(title: "Hours", value: formatHours(totalMinutes: filteredAndSortedTrips.reduce(0) { $0 + $1.totalBlockMinutes }))
                        StatLabel(title: "Legs", value: "\(filteredAndSortedTrips.reduce(0) { $0 + $1.legs.count })")
                    }
                }
                .padding()
                .background(LogbookTheme.navy)
                
                // Legs List
                if filteredAndSortedTrips.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No flights found")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text("Try adjusting your date range")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LogbookTheme.navy)
                } else {
                    List {
                        ForEach(filteredAndSortedTrips) { trip in
                            TripLegsRow(trip: trip)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(LogbookTheme.navy)
                }
            }
            .navigationTitle("Flight Legs")
            .navigationBarTitleDisplayMode(.inline)
            .background(LogbookTheme.navy.ignoresSafeArea())
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsSheet(
                selectedFormat: $selectedExportFormat,
                onExport: performExport,
                onCancel: { showingExportOptions = false }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = exportFileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatHours(totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    private func performExport() {
        showingExportOptions = false
        
        let trips = filteredAndSortedTrips
        
        switch selectedExportFormat {
        case .summary:
            exportSummary(trips: trips)
        case .detailed:
            exportDetailed(trips: trips)
        case .csv:
            exportCSV(trips: trips)
        case .json:
            exportJSON(trips: trips)
        }
    }
    
    private func createExportFile(data: Data, extension fileExtension: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let rangeName = selectedDateRange.rawValue.replacingOccurrences(of: " ", with: "_")
        let filename = "legs_export_\(rangeName)_\(timestamp).\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func exportSummary(trips: [Trip]) {
        var output = "Flight Legs Summary - \(selectedDateRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        let totalLegs = trips.reduce(0) { $0 + $1.legs.count }
        let totalHours = trips.reduce(0) { $0 + $1.totalBlockMinutes }
        
        output += "Total Trips: \(trips.count)\n"
        output += "Total Legs: \(totalLegs)\n"
        output += "Total Block Time: \(formatHours(totalMinutes: totalHours))\n\n"
        
        output += "Date\t\tTrip#\t\tLegs\t\tRoute\t\t\tBlock\n"
        output += "----------------------------------------------------\n"
        
        for trip in trips {
            let dateStr = trip.date.formatted(date: .abbreviated, time: .omitted)
            let route = trip.displayTitle
            output += "\(dateStr)\t\(trip.tripNumber)\t\t\(trip.legs.count)\t\t\(route)\t\t\(formatHours(totalMinutes: trip.totalBlockMinutes))\n"
            
            for (index, leg) in trip.legs.enumerated() {
                output += "  Leg \(index + 1): \(leg.departure) → \(leg.arrival)\n"
            }
            output += "\n"
        }
        
        if let data = output.data(using: .utf8) {
            exportFileURL = createExportFile(data: data, extension: "txt")
            showingShareSheet = true
        }
    }
    
    private func exportDetailed(trips: [Trip]) {
        var output = "Detailed Flight Legs - \(selectedDateRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        for trip in trips {
            output += "Trip #: \(trip.tripNumber)\n"
            output += "Date: \(trip.date.formatted())\n"
            output += "Aircraft: \(trip.aircraft)\n"
            output += "Type: \(trip.tripType.rawValue)\n\n"
            
            for (index, leg) in trip.legs.enumerated() {
                output += "Leg \(index + 1): \(leg.departure) → \(leg.arrival)\n"
                output += "  Out: \(leg.outTime)\n"
                output += "  Off: \(leg.offTime)\n"
                output += "  On: \(leg.onTime)\n"
                output += "  In: \(leg.inTime)\n"
                if leg.isDeadhead {
                    output += "  Type: DEADHEAD\n"
                }
                output += "\n"
            }
            
            output += "Total Block: \(formatHours(totalMinutes: trip.totalBlockMinutes))\n"
            output += "Total Flight: \(formatHours(totalMinutes: trip.totalFlightMinutes))\n"
            output += "-------------------------------------\n\n"
        }
        
        if let data = output.data(using: .utf8) {
            exportFileURL = createExportFile(data: data, extension: "txt")
            showingShareSheet = true
        }
    }
    
    private func exportCSV(trips: [Trip]) {
        var csv = "Date,Trip Number,Aircraft,Leg,Departure,Arrival,Out Time,Off Time,On Time,In Time,Type\n"
        
        for trip in trips {
            for (index, leg) in trip.legs.enumerated() {
                let date = trip.date.formatted(date: .abbreviated, time: .omitted)
                let legType = leg.isDeadhead ? "Deadhead" : "Operating"
                csv += "\"\(date)\",\"\(trip.tripNumber)\",\"\(trip.aircraft)\",\(index + 1),\"\(leg.departure)\",\"\(leg.arrival)\",\"\(leg.outTime)\",\"\(leg.offTime)\",\"\(leg.onTime)\",\"\(leg.inTime)\",\"\(legType)\"\n"
            }
        }
        
        if let data = csv.data(using: .utf8) {
            exportFileURL = createExportFile(data: data, extension: "csv")
            showingShareSheet = true
        }
    }
    
    private func exportJSON(trips: [Trip]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(trips)
            exportFileURL = createExportFile(data: data, extension: "json")
            showingShareSheet = true
        } catch {
            print("Failed to encode trips: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StatLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct TripLegsRow: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip #\(trip.tripNumber)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trip.aircraft)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text("\(trip.legs.count) \(trip.legs.count == 1 ? "leg" : "legs")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            ForEach(trip.legs.indices, id: \.self) { index in
                HStack {
                    Text("Leg \(index + 1):")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(trip.legs[index].departure) → \(trip.legs[index].arrival)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(trip.legs[index].isDeadhead ? LogbookTheme.accentOrange : .white)
                    if trip.legs[index].isDeadhead {
                        Text("DH")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LogbookTheme.accentOrange)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(LogbookTheme.navyLight)
    }
}

struct ExportOptionsSheet: View {
    @Binding var selectedFormat: LegsExportView.ExportFormat
    let onExport: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    ForEach(LegsExportView.ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(format.rawValue)
                                    .foregroundColor(.primary)
                                Text(formatDescription(format))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedFormat == format {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFormat = format
                        }
                    }
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
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
    
    private func formatDescription(_ format: LegsExportView.ExportFormat) -> String {
        switch format {
        case .summary:
            return "Overview with leg counts and routes"
        case .detailed:
            return "Full details including all times"
        case .csv:
            return "Spreadsheet format for analysis"
        case .json:
            return "Machine-readable data format"
        }
    }
}
import SwiftUI

struct FlightLegsView: View {
    @ObservedObject var store: LogBookStore
    @AppStorage("selectedLegsStats") private var selectedStatsData: Data = Data()
    @State private var currentSelectedStats: [StatType] = []
    @State private var showingStatsPicker = false
    @State private var showingExportSheet = false
    @State private var selectedExportRange: ExportDateRange = .lastMonth
    @State private var exportFormat: ExportFormat = .summary
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    
    // Available statistics
    enum StatType: String, CaseIterable, Codable {
        case totalLegs = "Total Legs"
        case blockTime = "Block Time"
        case flightTime = "Flight Time"
        case aircraft = "Aircraft"
        case airports = "Airports"
        case routes = "Routes"
        
        var icon: String {
            switch self {
            case .totalLegs: return "list.number"
            case .blockTime: return "clock"
            case .flightTime: return "airplane"
            case .aircraft: return "airplane.circle"
            case .airports: return "mappin.circle"
            case .routes: return "point.topleft.down.curvedto.point.bottomright.up"
            }
        }
    }
    
    // User's selected stats (default to first 3)
    var selectedStats: [StatType] {
        get {
            if let data = try? JSONDecoder().decode([StatType].self, from: selectedStatsData) {
                return data
            }
            return Array(StatType.allCases.prefix(3))
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                selectedStatsData = data
            }
        }
    }
    
    enum ExportDateRange: String, CaseIterable {
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
        case summary = "Summary"
        case detailed = "Detailed"
        case csv = "CSV"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Customizable Stats Grid
            HStack(spacing: 16) {
                ForEach(currentSelectedStats.isEmpty ? selectedStats : currentSelectedStats, id: \.self) { stat in
                    StatCardView(
                        type: stat,
                        value: getStatValue(for: stat),
                        icon: stat.icon
                    )
                }
                
                // Edit button
                Button(action: { showingStatsPicker = true }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .frame(width: 40)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            
            // Date Row (existing)
            DateFilterRow()
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Export Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ExportDateRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedExportRange = range
                            showingExportSheet = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16))
                                Text(range.rawValue)
                                    .font(.caption)
                            }
                            .frame(minWidth: 80)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(LogbookTheme.navyLight)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Flight Legs List (existing content)
            List {
                ForEach(store.trips.sorted(by: { $0.date > $1.date })) { trip in
                    FlightLegsRow(trip: trip)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Flight Legs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize currentSelectedStats from saved data or defaults
            if currentSelectedStats.isEmpty {
                currentSelectedStats = selectedStats
            }
        }
        .sheet(isPresented: $showingStatsPicker) {
            StatsPickerView(selectedStats: $currentSelectedStats)
                .onDisappear {
                    // Save the selection when the sheet dismisses
                    if let data = try? JSONEncoder().encode(currentSelectedStats) {
                        selectedStatsData = data
                    }
                }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportConfirmationSheet(
                range: selectedExportRange,
                format: $exportFormat,
                onExport: performExport,
                onCancel: { showingExportSheet = false }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Statistics Calculations
    
    private func getStatValue(for type: StatType) -> String {
        switch type {
        case .totalLegs:
            let total = store.trips.reduce(0) { $0 + $1.legs.count }
            return "\(total)"
            
        case .blockTime:
            let minutes = store.trips.reduce(0) { $0 + $1.totalBlockMinutes }
            return formatTime(minutes: minutes)
            
        case .flightTime:
            let minutes = store.trips.reduce(0) { $0 + $1.totalFlightMinutes }
            return formatTime(minutes: minutes)
            
        case .aircraft:
            let unique = Set(store.trips.map { $0.aircraft }).count
            return "\(unique)"
            
        case .airports:
            var airports = Set<String>()
            for trip in store.trips {
                for leg in trip.legs {
                    airports.insert(leg.departure)
                    airports.insert(leg.arrival)
                }
            }
            return "\(airports.count)"
            
        case .routes:
            var routes = Set<String>()
            for trip in store.trips {
                for leg in trip.legs {
                    routes.insert("\(leg.departure)-\(leg.arrival)")
                }
            }
            return "\(routes.count)"
        }
    }
    
    private func formatTime(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
    
    // MARK: - Export Functions
    
    private func performExport() {
        showingExportSheet = false
        
        let range = selectedExportRange.dateRange
        let filteredTrips = store.trips.filter { trip in
            if let startDate = range.start {
                return trip.date >= startDate && trip.date <= range.end
            }
            return trip.date <= range.end
        }.sorted(by: { $0.date > $1.date })
        
        let data: Data?
        let fileExtension: String
        
        switch exportFormat {
        case .summary:
            data = createSummaryExport(trips: filteredTrips)
            fileExtension = "txt"
        case .detailed:
            data = createDetailedExport(trips: filteredTrips)
            fileExtension = "txt"
        case .csv:
            data = createCSVExport(trips: filteredTrips)
            fileExtension = "csv"
        }
        
        if let data = data {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            
            let filename = "legs_\(selectedExportRange.rawValue.replacingOccurrences(of: " ", with: "_"))_\(timestamp).\(fileExtension)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            try? data.write(to: tempURL)
            exportFileURL = tempURL
            showingShareSheet = true
        }
    }
    
    private func createSummaryExport(trips: [Trip]) -> Data? {
        var output = "Flight Legs Summary - \(selectedExportRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        let totalLegs = trips.reduce(0) { $0 + $1.legs.count }
        let totalMinutes = trips.reduce(0) { $0 + $1.totalBlockMinutes }
        
        output += "Total Trips: \(trips.count)\n"
        output += "Total Legs: \(totalLegs)\n"
        output += "Total Time: \(formatTime(minutes: totalMinutes))\n\n"
        
        for trip in trips {
            output += "\(trip.date.formatted(date: .abbreviated, time: .omitted)) - Trip #\(trip.tripNumber)\n"
            for (index, leg) in trip.legs.enumerated() {
                output += "  Leg \(index + 1): \(leg.departure) → \(leg.arrival)\n"
            }
            output += "\n"
        }
        
        return output.data(using: .utf8)
    }
    
    private func createDetailedExport(trips: [Trip]) -> Data? {
        var output = "Detailed Flight Legs - \(selectedExportRange.rawValue)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        for trip in trips {
            output += "Trip #\(trip.tripNumber) - \(trip.date.formatted())\n"
            output += "Aircraft: \(trip.aircraft)\n\n"
            
            for (index, leg) in trip.legs.enumerated() {
                output += "Leg \(index + 1): \(leg.departure) → \(leg.arrival)\n"
                output += "  Out: \(leg.outTime)  Off: \(leg.offTime)\n"
                output += "  On: \(leg.onTime)   In: \(leg.inTime)\n\n"
            }
            output += "-------------------------------------\n\n"
        }
        
        return output.data(using: .utf8)
    }
    
    private func createCSVExport(trips: [Trip]) -> Data? {
        var csv = "Date,Trip,Leg,Departure,Arrival,Out,Off,On,In\n"
        
        for trip in trips {
            let date = trip.date.formatted(date: .abbreviated, time: .omitted)
            for (index, leg) in trip.legs.enumerated() {
                csv += "\"\(date)\",\"\(trip.tripNumber)\",\(index + 1),\"\(leg.departure)\",\"\(leg.arrival)\",\"\(leg.outTime)\",\"\(leg.offTime)\",\"\(leg.onTime)\",\"\(leg.inTime)\"\n"
            }
        }
        
        return csv.data(using: .utf8)
    }
}

// MARK: - Supporting Views

struct StatCardView: View {
    let type: FlightLegsView.StatType
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(type.rawValue)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LogbookTheme.navy)
        .cornerRadius(12)
    }
}

struct DateFilterRow: View {
    var body: some View {
        // Existing date filter implementation
        HStack {
            Text("Date Filter")
                .foregroundColor(.gray)
            Spacer()
            Text("All Time")
                .foregroundColor(.white)
            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(8)
    }
}

struct FlightLegsRow: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trip #\(trip.tripNumber)")
                    .font(.headline)
                Spacer()
                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ForEach(trip.legs.indices, id: \.self) { index in
                HStack {
                    Text("Leg \(index + 1):")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(trip.legs[index].departure) → \(trip.legs[index].arrival)")
                        .font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatsPickerView: View {
    @Binding var selectedStats: [FlightLegsView.StatType]
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelection: [FlightLegsView.StatType] = []
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select 3 statistics to display")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                ForEach(FlightLegsView.StatType.allCases, id: \.self) { stat in
                    HStack {
                        Image(systemName: stat.icon)
                            .foregroundColor(LogbookTheme.accentBlue)
                            .frame(width: 30)
                        
                        Text(stat.rawValue)
                        
                        Spacer()
                        
                        if tempSelection.contains(stat) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(stat)
                    }
                }
            }
            .navigationTitle("Customize Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedStats = tempSelection
                        dismiss()
                    }
                    .disabled(tempSelection.count != 3)
                }
            }
            .onAppear {
                tempSelection = selectedStats
            }
        }
    }
    
    private func toggleSelection(_ stat: FlightLegsView.StatType) {
        if let index = tempSelection.firstIndex(of: stat) {
            tempSelection.remove(at: index)
        } else if tempSelection.count < 3 {
            tempSelection.append(stat)
        }
    }
}

struct ExportConfirmationSheet: View {
    let range: FlightLegsView.ExportDateRange
    @Binding var format: FlightLegsView.ExportFormat
    let onExport: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Range") {
                    Label(range.rawValue, systemImage: "calendar")
                }
                
                Section("Format") {
                    ForEach(FlightLegsView.ExportFormat.allCases, id: \.self) { exportFormat in
                        HStack {
                            Text(exportFormat.rawValue)
                            Spacer()
                            if format == exportFormat {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            format = exportFormat
                        }
                    }
                }
                
                Section {
                    Button("Export") {
                        onExport()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Export Flight Legs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

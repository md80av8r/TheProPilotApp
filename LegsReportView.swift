// LegsReportView.swift - Complete with all supporting views
import SwiftUI

// MARK: - Statistics Model
struct LegStatistics {
    let totalLegs: Int
    let totalBlockMinutes: Int
    let totalFlightMinutes: Int
    let uniqueAirports: Int
    let uniqueAircraft: Int
    let uniqueRoutes: Int
    
    var blockHours: String {
        let hours = totalBlockMinutes / 60
        let mins = totalBlockMinutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
    
    var flightHours: String {
        let hours = totalFlightMinutes / 60
        let mins = totalFlightMinutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}

// MARK: - Main View
struct LegsReportView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .dateNewest
    @State private var showingLegDetail: FlightLeg?
    @State private var selectedTrip: Trip?
    @State private var showingSearch = false
    @State private var showingStatsPicker = false
    @State private var showingExportOptions = false
    @State private var selectedExportRange = "All Time"
    @State private var selectedExportFormat = "Summary"
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var exportData: Data?
    @State private var exportFilename: String = ""

    @AppStorage("selectedLegsReportStats") private var selectedStatsData: Data = Data()
    @State private var currentSelectedStats: [String] = ["Total Legs", "Block Time", "Flight Time"]
    
    // Available stats
    let availableStats = [
        "Total Legs",
        "Block Time",
        "Flight Time",
        "Aircraft",
        "Airports",
        "Routes"
    ]
    
    // Export date ranges
    let exportDateRanges = [
        "All Time",
        "This Month",
        "Last Month",
        "Last 3 Months",
        "Last 6 Months",
        "Year to Date",
        "Last 12 Months"
    ]
    
    // Export formats
    let exportFormats = ["Summary", "Detailed", "Trip", "CSV"]
    
    enum FilterOption: String, CaseIterable {
        case all = "All Legs"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .thisWeek: return "calendar.badge.clock"
            case .thisMonth: return "calendar"
            case .lastMonth: return "calendar.badge.minus"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case departureAZ = "Departure (A-Z)"
        case arrivalAZ = "Arrival (A-Z)"
        case flightNumber = "Flight Number"
        case aircraft = "Aircraft"
        case blockTime = "Block Time"
        
        var icon: String {
            switch self {
            case .dateNewest, .dateOldest: return "calendar"
            case .departureAZ, .arrivalAZ: return "airplane.departure"
            case .flightNumber: return "number"
            case .aircraft: return "airplane"
            case .blockTime: return "clock"
            }
        }
    }
    
    // User's selected stats
    var selectedStats: [String] {
        get {
            if !currentSelectedStats.isEmpty {
                return currentSelectedStats
            }
            if let data = try? JSONDecoder().decode([String].self, from: selectedStatsData) {
                return data
            }
            return ["Total Legs", "Block Time", "Flight Time"]
        }
    }
    
    // Flatten all legs from all trips with trip context
    var allLegs: [(leg: FlightLeg, trip: Trip)] {
        store.trips.flatMap { trip in
            trip.legs.map { leg in (leg: leg, trip: trip) }
        }
    }
    
    var filteredAndSortedLegs: [(leg: FlightLeg, trip: Trip)] {
        var result = allLegs
        
        // Apply filter
        let now = Date()
        let calendar = Calendar.current
        
        switch filterOption {
        case .all:
            break
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            result = result.filter { $0.trip.date >= startOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            result = result.filter { $0.trip.date >= startOfMonth }
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfLastMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 0, to: now)!)!
            result = result.filter { $0.trip.date >= startOfLastMonth && $0.trip.date <= endOfLastMonth }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.leg.departure.localizedCaseInsensitiveContains(searchText) ||
                $0.leg.arrival.localizedCaseInsensitiveContains(searchText) ||
                $0.leg.flightNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.trip.tripNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.trip.aircraft.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateNewest:
            result.sort { $0.trip.date > $1.trip.date }
        case .dateOldest:
            result.sort { $0.trip.date < $1.trip.date }
        case .departureAZ:
            result.sort { $0.leg.departure < $1.leg.departure }
        case .arrivalAZ:
            result.sort { $0.leg.arrival < $1.leg.arrival }
        case .flightNumber:
            result.sort { $0.leg.flightNumber < $1.leg.flightNumber }
        case .aircraft:
            result.sort { $0.trip.aircraft < $1.trip.aircraft }
        case .blockTime:
            result.sort { $0.leg.blockMinutes() > $1.leg.blockMinutes() }
        }
        
        return result
    }
    
    // Group legs by trip for better visualization (only when sorted by date)
    var groupedByTrip: [(trip: Trip, legs: [(leg: FlightLeg, index: Int)])]? {
        // Only group when sorted by date (newest or oldest)
        guard sortOption == .dateNewest || sortOption == .dateOldest else {
            return nil
        }
        
        let grouped = Dictionary(grouping: Array(filteredAndSortedLegs.enumerated())) {
            $0.element.trip.id
        }
        
        return grouped.compactMap { (tripId, indexedItems) in
            guard let trip = indexedItems.first?.element.trip else { return nil }
            let legs = indexedItems.map { (leg: $0.element.leg, index: $0.offset + 1) }
            return (trip: trip, legs: legs)
        }.sorted {
            // Sort by trip date based on current sort option
            sortOption == .dateNewest ? $0.trip.date > $1.trip.date : $0.trip.date < $1.trip.date
        }
    }
    
    private var statistics: LegStatistics {
        calculateStatistics(from: filteredAndSortedLegs)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Statistics Dashboard
                    enhancedStatisticsSection
                    
                    // Filter and Sort Controls
                    controlsSection
                    
                    if filteredAndSortedLegs.isEmpty {
                        emptyStateView
                    } else {
                        legsList
                    }
                }
            }
            .navigationTitle("Flight Legs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSearch.toggle() }) {
                        Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .sheet(item: $showingLegDetail) { leg in
                if let trip = selectedTrip {
                    LegDetailView(trip: trip, leg: leg)
                }
            }
            .sheet(isPresented: $showingStatsPicker) {
                LegsStatsPickerView(
                    availableStats: availableStats,
                    selectedStats: $currentSelectedStats,
                    onDismiss: {
                        if let data = try? JSONEncoder().encode(currentSelectedStats) {
                            selectedStatsData = data
                        }
                    }
                )
            }
            .sheet(isPresented: $showingExportOptions) {
                LegsExportOptionsView(
                    selectedRange: $selectedExportRange,
                    selectedFormat: $selectedExportFormat,
                    dateRanges: exportDateRanges,
                    formats: exportFormats,
                    onExport: performExport,
                    onCancel: { showingExportOptions = false }
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportData, !exportFilename.isEmpty {
                    ShareSheet.forFileExport(
                        data: data,
                        filename: exportFilename,
                        completion: {
                            exportData = nil
                            exportFilename = ""
                        }
                    )
                }
            }
            .onAppear {
                // Load saved stats
                if let data = try? JSONDecoder().decode([String].self, from: selectedStatsData) {
                    currentSelectedStats = data
                }
            }
        }
    }
    
    // MARK: - Enhanced Statistics Section
    private var enhancedStatisticsSection: some View {
        VStack(spacing: 12) {
            // Header with controls
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Show grouping indicator
                if sortOption == .dateNewest || sortOption == .dateOldest {
                    Text("(Grouped by Trip)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Export button
                Button(action: { showingExportOptions = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // Edit stats button
                Button(action: { showingStatsPicker = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // Display selected stats (3 cards)
            HStack(spacing: 12) {
                ForEach(selectedStats, id: \.self) { stat in
                    LegsStatCard(
                        title: stat,
                        value: getStatValue(for: stat),
                        icon: getStatIcon(for: stat),
                        color: getStatColor(for: stat)
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(LogbookTheme.navyLight)
    }
    
    private func getStatValue(for stat: String) -> String {
        switch stat {
        case "Total Legs":
            return "\(statistics.totalLegs)"
        case "Block Time":
            return statistics.blockHours
        case "Flight Time":
            return statistics.flightHours
        case "Aircraft":
            return "\(statistics.uniqueAircraft)"
        case "Airports":
            return "\(statistics.uniqueAirports)"
        case "Routes":
            return "\(statistics.uniqueRoutes)"
        default:
            return "0"
        }
    }
    
    private func getStatIcon(for stat: String) -> String {
        switch stat {
        case "Total Legs": return "airplane.departure"
        case "Block Time": return "clock.fill"
        case "Flight Time": return "timer"
        case "Aircraft": return "airplane"
        case "Airports": return "location.fill"
        case "Routes": return "map"
        default: return "questionmark"
        }
    }
    
    private func getStatColor(for stat: String) -> Color {
        switch stat {
        case "Total Legs": return LogbookTheme.accentBlue
        case "Block Time": return LogbookTheme.accentGreen
        case "Flight Time": return LogbookTheme.accentOrange
        case "Aircraft": return .cyan
        case "Airports": return .purple
        case "Routes": return LogbookTheme.warningYellow
        default: return .gray
        }
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            if showingSearch {
                LegsSearchBar(searchText: $searchText)
                    .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
            }
            
            // Filter Options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        LegsFilterButton(
                            option: option,
                            isSelected: filterOption == option
                        ) {
                            withAnimation {
                                filterOption = option
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Sort Options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        LegsSortButton(
                            option: option,
                            isSelected: sortOption == option
                        ) {
                            withAnimation {
                                sortOption = option
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(LogbookTheme.navyLight.opacity(0.5))
    }
    
    // MARK: - Legs List
    private var legsList: some View {
        Group {
            if let grouped = groupedByTrip {
                // Grouped view for date sorting
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(grouped, id: \.trip.id) { group in
                            VStack(spacing: 0) {
                                // Trip Header
                                TripHeaderView(trip: group.trip, legCount: group.legs.count)
                                
                                // Legs for this trip
                                VStack(spacing: 1) {
                                    ForEach(Array(group.legs.enumerated()), id: \.element.leg.id) { index, legInfo in
                                        GroupedLegRow(
                                            leg: legInfo.leg,
                                            trip: group.trip,
                                            globalIndex: legInfo.index,
                                            tripLegIndex: index + 1,
                                            totalLegsInTrip: group.legs.count
                                        )
                                        .background(LogbookTheme.navyLight)
                                        .onTapGesture {
                                            showingLegDetail = legInfo.leg
                                            selectedTrip = group.trip
                                        }
                                    }
                                }
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding()
                }
                .background(LogbookTheme.navy)
            } else {
                // Flat list view for non-date sorting
                List {
                    ForEach(Array(filteredAndSortedLegs.enumerated()), id: \.1.leg.id) { index, item in
                        EnhancedLegRow(
                            leg: item.leg,
                            trip: item.trip,
                            index: index + 1,
                            sortOption: sortOption
                        )
                        .listRowBackground(LogbookTheme.navyLight)
                        .listRowSeparator(.visible, edges: .bottom)
                        .onTapGesture {
                            showingLegDetail = item.leg
                            selectedTrip = item.trip
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(LogbookTheme.navy)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "airplane.departure" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No flight legs found" : "No results for '\(searchText)'")
                .font(.title3)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
                .foregroundColor(LogbookTheme.accentBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LogbookTheme.navy)
    }
    
    private func calculateStatistics(from legs: [(leg: FlightLeg, trip: Trip)]) -> LegStatistics {
        let totalLegs = legs.count
        let totalBlockMinutes = legs.reduce(0) { $0 + $1.leg.blockMinutes() }
        let totalFlightMinutes = legs.reduce(0) { $0 + $1.leg.calculateFlightMinutes() }
        
        let uniqueAirports = Set(legs.flatMap { [$0.leg.departure, $0.leg.arrival] }.filter { !$0.isEmpty })
        let uniqueAircraft = Set(legs.map { $0.trip.aircraft }.filter { !$0.isEmpty })
        let uniqueRoutes = Set(legs.map { "\($0.leg.departure)-\($0.leg.arrival)" }.filter { !$0.contains("") })
        
        return LegStatistics(
            totalLegs: totalLegs,
            totalBlockMinutes: totalBlockMinutes,
            totalFlightMinutes: totalFlightMinutes,
            uniqueAirports: uniqueAirports.count,
            uniqueAircraft: uniqueAircraft.count,
            uniqueRoutes: uniqueRoutes.count
        )
    }
    
    // MARK: - Export Functions
    
    private func performExport() {
        showingExportOptions = false
        
        let legs = getLegsForExport()
        let data: Data?
        let fileExtension: String
        
        switch selectedExportFormat {
        case "Summary":
            data = createSummaryExport(legs: legs)
            fileExtension = "txt"
        case "Detailed":
            data = createDetailedExport(legs: legs)
            fileExtension = "txt"
        case "Trip":
            data = createTripExport()
            fileExtension = "txt"
        case "CSV":
            data = createCSVExport(legs: legs)
            fileExtension = "csv"
        default:
            data = nil
            fileExtension = "txt"
        }
        
        if let data = data {
            // Store data and filename for sharing
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let rangeName = selectedExportRange.replacingOccurrences(of: " ", with: "_")
            
            exportData = data
            exportFilename = "ProPilot_Legs_\(rangeName)_\(timestamp).\(fileExtension)"
            showingShareSheet = true
        }
    }
    
    private func getLegsForExport() -> [(leg: FlightLeg, trip: Trip)] {
        var legs = allLegs
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedExportRange {
        case "All Time":
            break
        case "This Month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            legs = legs.filter { $0.trip.date >= startOfMonth }
        case "Last Month":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfLastMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfLastMonth)!
            legs = legs.filter { $0.trip.date >= startOfLastMonth && $0.trip.date <= endOfLastMonth }
        case "Last 3 Months":
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            legs = legs.filter { $0.trip.date >= threeMonthsAgo }
        case "Last 6 Months":
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            legs = legs.filter { $0.trip.date >= sixMonthsAgo }
        case "Year to Date":
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            legs = legs.filter { $0.trip.date >= startOfYear }
        case "Last 12 Months":
            let twelveMonthsAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            legs = legs.filter { $0.trip.date >= twelveMonthsAgo }
        default:
            break
        }
        
        return legs.sorted { $0.trip.date > $1.trip.date }
    }
    
    private func createSummaryExport(legs: [(leg: FlightLeg, trip: Trip)]) -> Data? {
        var output = "Flight Legs Summary - \(selectedExportRange)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        let stats = calculateStatistics(from: legs)
        output += "Total Legs: \(stats.totalLegs)\n"
        output += "Block Time: \(stats.blockHours)\n"
        output += "Flight Time: \(stats.flightHours)\n"
        output += "Unique Aircraft: \(stats.uniqueAircraft)\n"
        output += "Unique Airports: \(stats.uniqueAirports)\n\n"
        
        for (leg, trip) in legs {
            output += "\(trip.date.formatted(date: .abbreviated, time: .omitted)) - Trip #\(trip.tripNumber)\n"
            output += "  \(leg.departure) → \(leg.arrival)"
            if !leg.flightNumber.isEmpty {
                output += " (\(leg.flightNumber))"
            }
            output += "\n"
        }
        
        return output.data(using: .utf8)
    }
    
    private func createDetailedExport(legs: [(leg: FlightLeg, trip: Trip)]) -> Data? {
        var output = "Detailed Flight Legs - \(selectedExportRange)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        for (leg, trip) in legs {
            output += "Trip #\(trip.tripNumber) - \(trip.date.formatted())\n"
            output += "Aircraft: \(trip.aircraft)\n"
            output += "Route: \(leg.departure) → \(leg.arrival)\n"
            if !leg.flightNumber.isEmpty {
                output += "Flight: \(leg.flightNumber)\n"
            }
            output += "Times: Out \(leg.outTime) Off \(leg.offTime) On \(leg.onTime) In \(leg.inTime)\n"
            output += "Block: \(formatTime(leg.blockMinutes()))\n"
            output += "-------------------------------------\n\n"
        }
        
        return output.data(using: .utf8)
    }
    
    private func createCSVExport(legs: [(leg: FlightLeg, trip: Trip)]) -> Data? {
        var csv = "Date,Trip,Flight,Departure,Arrival,Out,Off,On,In,Block\n"
        
        for (leg, trip) in legs {
            let date = trip.date.formatted(date: .abbreviated, time: .omitted)
            let block = formatTime(leg.blockMinutes())
            csv += "\"\(date)\",\"\(trip.tripNumber)\",\"\(leg.flightNumber)\",\"\(leg.departure)\",\"\(leg.arrival)\",\"\(leg.outTime)\",\"\(leg.offTime)\",\"\(leg.onTime)\",\"\(leg.inTime)\",\"\(block)\"\n"
        }
        
        return csv.data(using: .utf8)
    }
    
    private func createTripExport() -> Data? {
        var output = "Flight Trip Report - \(selectedExportRange)\n"
        output += "Generated: \(Date().formatted())\n"
        output += "=====================================\n\n"
        
        // Get trips for export based on date range
        let trips = getTripsForExport()
        
        if trips.isEmpty {
            output += "No trips found for the selected period.\n"
            return output.data(using: .utf8)
        }
        
        // Group by month for monthly totals
        let calendar = Calendar.current
        let groupedByMonth = Dictionary(grouping: trips) { trip in
            calendar.dateInterval(of: .month, for: trip.date)?.start ?? trip.date
        }
        
        var grandTotalBlock = 0
        var grandTotalFlight = 0
        var grandTotalOperating = 0
        var grandTotalDeadhead = 0
        var grandTotalSimulator = 0
        
        // Process each month
        for (monthStart, monthTrips) in groupedByMonth.sorted(by: { $0.key > $1.key }) {
            output += "\n" + String(repeating: "=", count: 50) + "\n"
            output += "MONTH: \(monthStart.formatted(.dateTime.month(.wide).year()))\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            
            var monthlyTotalBlock = 0
            var monthlyTotalFlight = 0
            var monthlyOperating = 0
            var monthlyDeadhead = 0
            var monthlySimulator = 0
            
            // Process each trip in the month
            for trip in monthTrips.sorted(by: { $0.date > $1.date }) {
                output += "Trip #\(trip.tripNumber) - \(trip.date.formatted(date: .abbreviated, time: .omitted))\n"
                output += "Aircraft: \(trip.aircraft)\n"
                output += "Type: \(trip.tripType.rawValue)\n"
                
                if trip.tripType == .simulator {
                    let simMinutes = trip.simulatorMinutes ?? 0
                    output += "Simulator Time: \(formatTime(simMinutes))\n"
                    monthlySimulator += simMinutes
                    monthlyTotalBlock += simMinutes
                } else {
                    output += "\nLegs:\n"
                    
                    var tripBlockTotal = 0
                    var tripFlightTotal = 0
                    
                    for (index, leg) in trip.legs.enumerated() {
                        output += "  \(index + 1). \(leg.departure) → \(leg.arrival)"
                        if !leg.flightNumber.isEmpty {
                            output += " (\(leg.flightNumber))"
                        }
                        if leg.isDeadhead {
                            output += " [DEADHEAD]"
                        }
                        output += "\n"
                        output += "     Out: \(leg.outTime)  Off: \(leg.offTime)  On: \(leg.onTime)  In: \(leg.inTime)\n"
                        let blockMinutes = leg.blockMinutes()
                        let flightMinutes = leg.calculateFlightMinutes()
                        output += "     Block: \(formatTime(blockMinutes))  Flight: \(formatTime(flightMinutes))\n"
                        
                        tripBlockTotal += blockMinutes
                        tripFlightTotal += flightMinutes
                        
                        if leg.isDeadhead {
                            monthlyDeadhead += blockMinutes
                        } else if trip.tripType == .operating {
                            monthlyOperating += blockMinutes
                        }
                    }
                    
                    output += "\nTrip Totals:\n"
                    output += "  Block Time: \(formatTime(tripBlockTotal))\n"
                    output += "  Flight Time: \(formatTime(tripFlightTotal))\n"
                    
                    monthlyTotalBlock += tripBlockTotal
                    monthlyTotalFlight += tripFlightTotal
                }
                
                output += "\n" + String(repeating: "-", count: 40) + "\n"
            }
            
            // Monthly summary
            output += "\nMONTHLY TOTALS:\n"
            output += "Operating: \(formatTime(monthlyOperating))\n"
            output += "Deadhead: \(formatTime(monthlyDeadhead))\n"
            output += "Simulator: \(formatTime(monthlySimulator))\n"
            output += "Total Block: \(formatTime(monthlyTotalBlock))\n"
            output += "Total Flight: \(formatTime(monthlyTotalFlight))\n"
            
            grandTotalBlock += monthlyTotalBlock
            grandTotalFlight += monthlyTotalFlight
            grandTotalOperating += monthlyOperating
            grandTotalDeadhead += monthlyDeadhead
            grandTotalSimulator += monthlySimulator
        }
        
        // Only show grand totals if there's more than one month
        if groupedByMonth.count > 1 {
            output += "\n" + String(repeating: "=", count: 50) + "\n"
            output += "GRAND TOTALS FOR PERIOD\n"
            output += String(repeating: "=", count: 50) + "\n"
            output += "Operating: \(formatTime(grandTotalOperating))\n"
            output += "Deadhead: \(formatTime(grandTotalDeadhead))\n"
            output += "Simulator: \(formatTime(grandTotalSimulator))\n"
            output += "Total Block: \(formatTime(grandTotalBlock))\n"
            output += "Total Flight: \(formatTime(grandTotalFlight))\n"
        }
        
        return output.data(using: .utf8)
    }
    
    private func getTripsForExport() -> [Trip] {
        var trips = store.trips
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedExportRange {
        case "All Time":
            break
        case "This Month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            trips = trips.filter { $0.date >= startOfMonth }
        case "Last Month":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            let endOfLastMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfLastMonth)!
            trips = trips.filter { $0.date >= startOfLastMonth && $0.date <= endOfLastMonth }
        case "Last 3 Months":
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            trips = trips.filter { $0.date >= threeMonthsAgo }
        case "Last 6 Months":
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            trips = trips.filter { $0.date >= sixMonthsAgo }
        case "Year to Date":
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            trips = trips.filter { $0.date >= startOfYear }
        case "Last 12 Months":
            let twelveMonthsAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            trips = trips.filter { $0.date >= twelveMonthsAgo }
        default:
            break
        }
        
        return trips.sorted { $0.date > $1.date }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}

// MARK: - Supporting Views

// Enhanced Leg Row
struct EnhancedLegRow: View {
    let leg: FlightLeg
    let trip: Trip
    let index: Int
    let sortOption: LegsReportView.SortOption
    
    private var hasFlightNumber: Bool {
        !leg.flightNumber.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row: Route and flight number
            HStack {
                // Leg number badge
                Text("#\(index)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(6)
                
                HStack(spacing: 4) {
                    Text(leg.departure)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text(leg.arrival)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Flight number badge
                if hasFlightNumber {
                    Text(leg.flightNumber)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(LogbookTheme.accentGreen)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // Second row: Trip info and date
            HStack {
                // Trip number (truncated if too long)
                Text(trip.tripNumber)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 120, alignment: .leading)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Date
                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Aircraft
                Label(trip.aircraft, systemImage: "airplane")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Third row: Times
            HStack(spacing: 12) {
                LegTimeLabel(label: "OUT", time: leg.outTime)
                LegTimeLabel(label: "OFF", time: leg.offTime)
                LegTimeLabel(label: "ON", time: leg.onTime)
                LegTimeLabel(label: "IN", time: leg.inTime)
                
                Spacer()
                
                // Block time
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Block")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatTime(leg.blockMinutes()))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}
                // MARK: - Supporting Views

                // Time Label Component
struct LegTimeLabel: View {
    let label: String
    let time: String
    
    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Text(time.isEmpty ? "--:--" : formatDisplayTime(time))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(time.isEmpty ? .gray : .white)
        }
    }
    
    private func formatDisplayTime(_ time: String) -> String {
        guard time.count == 4 else { return time }
        let hours = String(time.prefix(2))
        let mins = String(time.suffix(2))
        return "\(hours):\(mins)"
    }
}



// Stat Card
struct LegsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

// Filter Button
struct LegsFilterButton: View {
    let option: LegsReportView.FilterOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(option.rawValue, systemImage: option.icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? LogbookTheme.accentBlue : LogbookTheme.navyLight)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

// Sort Button
struct LegsSortButton: View {
    let option: LegsReportView.SortOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(option.rawValue, systemImage: option.icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? LogbookTheme.accentGreen : LogbookTheme.navyLight)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

// Search Bar
struct LegsSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search legs, airports, aircraft...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Leg Detail View (Placeholder)
struct ReportLegDetailView: View {
    let leg: FlightLeg
    let trip: Trip
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Route Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Route")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(leg.departure)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Image(systemName: "arrow.right")
                                .font(.title)
                                .foregroundColor(.gray)
                            
                            Text(leg.arrival)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Add more detail sections here
                }
                .padding()
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Leg Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Stats Picker View
struct LegsStatsPickerView: View {
    let availableStats: [String]
    @Binding var selectedStats: [String]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelection: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select 3 statistics to display")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                ForEach(availableStats, id: \.self) { stat in
                    HStack {
                        Image(systemName: getIcon(for: stat))
                            .foregroundColor(getColor(for: stat))
                            .frame(width: 30)
                        
                        Text(stat)
                        
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
                        onDismiss()
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
    
    private func toggleSelection(_ stat: String) {
        if let index = tempSelection.firstIndex(of: stat) {
            tempSelection.remove(at: index)
        } else if tempSelection.count < 3 {
            tempSelection.append(stat)
        }
    }
    
    private func getIcon(for stat: String) -> String {
        switch stat {
        case "Total Legs": return "airplane.departure"
        case "Block Time": return "clock.fill"
        case "Flight Time": return "timer"
        case "Aircraft": return "airplane"
        case "Airports": return "location.fill"
        case "Routes": return "map"
        default: return "questionmark"
        }
    }
    
    private func getColor(for stat: String) -> Color {
        switch stat {
        case "Total Legs": return LogbookTheme.accentBlue
        case "Block Time": return LogbookTheme.accentGreen
        case "Flight Time": return LogbookTheme.accentOrange
        case "Aircraft": return .cyan
        case "Airports": return .purple
        case "Routes": return LogbookTheme.warningYellow
        default: return .gray
        }
    }
}

// Export Options View
struct LegsExportOptionsView: View {
    @Binding var selectedRange: String
    @Binding var selectedFormat: String
    let dateRanges: [String]
    let formats: [String]
    let onExport: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Range") {
                    ForEach(dateRanges, id: \.self) { range in
                        HStack {
                            Text(range)
                            Spacer()
                            if selectedRange == range {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRange = range
                        }
                    }
                }
                
                Section("Format") {
                    ForEach(formats, id: \.self) { format in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(format)
                                    .foregroundColor(.primary)
                                Text(getFormatDescription(format))
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
    
    private func getFormatDescription(_ format: String) -> String {
        switch format {
        case "Summary":
            return "Simple list of legs with basic info"
        case "Detailed":
            return "Full leg details with all times"
        case "Trip":
            return "By trip with subtotals and monthly totals"
        case "CSV":
            return "Spreadsheet format for analysis"
        default:
            return ""
        }
    }
}

// MARK: - Trip Header View
struct TripHeaderView: View {
    let trip: Trip
    let legCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Trip number and date
                HStack {
                    Text("Trip #\(trip.tripNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Aircraft and leg count
                HStack(spacing: 12) {
                    Label(trip.aircraft, systemImage: "airplane")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Label("\(legCount) leg\(legCount == 1 ? "" : "s")", systemImage: "arrow.triangle.turn.up.right.circle")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                    
                    if trip.tripType != .operating {
                        Text(trip.tripType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(trip.tripType == .deadhead ? Color.orange : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Total time for trip
            VStack(alignment: .trailing, spacing: 2) {
                Text("Total")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(trip.formattedTotalTime)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(LogbookTheme.accentOrange)
            }
        }
        .padding()
        .background(LogbookTheme.navy.opacity(0.8))
        .cornerRadius(12, corners: [.topLeft, .topRight])
    }
}

// MARK: - Grouped Leg Row
struct GroupedLegRow: View {
    let leg: FlightLeg
    let trip: Trip
    let globalIndex: Int
    let tripLegIndex: Int
    let totalLegsInTrip: Int
    
    private var hasFlightNumber: Bool {
        !leg.flightNumber.isEmpty
    }
    
    var body: some View {
        HStack {
            // Connection indicator for multi-leg trips
            if totalLegsInTrip > 1 {
                VStack(spacing: 0) {
                    if tripLegIndex > 1 {
                        Rectangle()
                            .fill(LogbookTheme.accentBlue)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    } else {
                        Color.clear
                            .frame(maxHeight: .infinity)
                    }
                    
                    Circle()
                        .fill(LogbookTheme.accentBlue)
                        .frame(width: 8, height: 8)
                    
                    if tripLegIndex < totalLegsInTrip {
                        Rectangle()
                            .fill(LogbookTheme.accentBlue)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    } else {
                        Color.clear
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 20)
                .padding(.vertical, 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Route with flight number
                HStack(spacing: 8) {
                    // Leg number in trip
                    Text("\(tripLegIndex)/\(totalLegsInTrip)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(4)
                    
                    HStack(spacing: 4) {
                        Text(leg.departure)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Text(leg.arrival)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Flight number badge
                    if hasFlightNumber {
                        Text(leg.flightNumber)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LogbookTheme.accentGreen)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    // Deadhead indicator
                    if leg.isDeadhead {
                        Text("DH")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                // Times
                HStack(spacing: 16) {
                    LegTimeLabel(label: "OUT", time: leg.outTime)
                    LegTimeLabel(label: "OFF", time: leg.offTime)
                    LegTimeLabel(label: "ON", time: leg.onTime)
                    LegTimeLabel(label: "IN", time: leg.inTime)
                    
                    Spacer()
                    
                    // Block time
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Block")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatTime(leg.blockMinutes()))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(LogbookTheme.accentOrange)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, totalLegsInTrip > 1 ? 8 : 16)
        }
        .background(
            tripLegIndex == totalLegsInTrip ?
            LogbookTheme.navyLight.opacity(0.8) :
            LogbookTheme.navyLight
        )
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

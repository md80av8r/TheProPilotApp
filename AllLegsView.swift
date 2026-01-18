// AllLegsView.swift
// View all logged flight legs across all trips
import SwiftUI

struct AllLegsView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var searchText = ""
    @State private var selectedFilter: LegFilter = .all
    @State private var selectedSort: LegSort = .dateDescending
    @State private var selectedLeg: FlightLeg?
    @State private var selectedTrip: Trip?
    
    enum LegFilter: String, CaseIterable {
        case all = "All Legs"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        
        func applies(to leg: FlightLeg, flightDate: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all:
                return true
            case .thisWeek:
                return calendar.isDate(flightDate, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(flightDate, equalTo: now, toGranularity: .month)
            case .last30Days:
                if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) {
                    return flightDate >= thirtyDaysAgo
                }
                return false
            case .last90Days:
                if let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) {
                    return flightDate >= ninetyDaysAgo
                }
                return false
            }
        }
    }
    
    enum LegSort: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case durationDescending = "Longest First"
        case durationAscending = "Shortest First"
        
        var icon: String {
            switch self {
            case .dateDescending: return "arrow.down"
            case .dateAscending: return "arrow.up"
            case .durationDescending: return "clock.arrow.circlepath"
            case .durationAscending: return "clock"
            }
        }
    }
    
    var allLegs: [(trip: Trip, leg: FlightLeg)] {
        var legs: [(trip: Trip, leg: FlightLeg)] = []
        for trip in store.trips {
            for leg in trip.legs {
                legs.append((trip, leg))
            }
        }
        return legs
    }
    
    var filteredAndSortedLegs: [(trip: Trip, leg: FlightLeg)] {
        var legs = allLegs
        
        // Apply filter
        legs = legs.filter { selectedFilter.applies(to: $0.leg, flightDate: $0.trip.date) }
        
        // Apply search
        if !searchText.isEmpty {
            legs = legs.filter { (trip, leg) in
                leg.departure.localizedCaseInsensitiveContains(searchText) ||
                leg.arrival.localizedCaseInsensitiveContains(searchText) ||
                trip.tripNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sort
        switch selectedSort {
        case .dateDescending:
            legs.sort { $0.trip.date > $1.trip.date }
        case .dateAscending:
            legs.sort { $0.trip.date < $1.trip.date }
        case .durationDescending:
            legs.sort { $0.leg.blockMinutes() > $1.leg.blockMinutes() }
        case .durationAscending:
            legs.sort { $0.leg.blockMinutes() < $1.leg.blockMinutes() }
        }
        
        return legs
    }
    
    var totalStats: (legs: Int, blockTime: Int, flightTime: Int) {
        let legs = filteredAndSortedLegs
        return (
            legs: legs.count,
            blockTime: legs.reduce(0) { $0 + $1.leg.blockMinutes() },
            flightTime: legs.reduce(0) { $0 + $1.leg.calculateFlightMinutes() }
        )
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Master-Detail layout
                iPadLayout
            } else {
                // iPhone: List layout
                iPhoneLayout
            }
        }
        .background(LogbookTheme.navy)
        .navigationTitle("Detailed Legs View")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(LegFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    
                    Divider()
                    
                    Picker("Sort", selection: $selectedSort) {
                        ForEach(LegSort.allCases, id: \.self) { sort in
                            Label(sort.rawValue, systemImage: sort.icon).tag(sort)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            // Statistics Header
            StatisticsHeaderView(stats: totalStats, filter: selectedFilter)
                .padding(.horizontal, 4)   // Reduced from 6 to 4
                .padding(.vertical, 2)     // Reduced from 4 to 2
                .background(LogbookTheme.navyLight)
            
            // Legs List
            List {
                if filteredAndSortedLegs.isEmpty {
                    EmptyLegsView(hasSearch: !searchText.isEmpty)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredAndSortedLegs, id: \.leg.id) { item in
                        LegRowView(trip: item.trip, leg: item.leg)
                            .listRowBackground(LogbookTheme.navyLight)
                            .onTapGesture {
                                selectedTrip = item.trip  // ✅ Capture trip HERE
                                selectedLeg = item.leg
                            }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $searchText, prompt: "Search airports or trip numbers")
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $selectedLeg) { leg in
            // ✅ Use the captured trip instead of looking it up
            if let trip = selectedTrip {
                LegDetailView(trip: trip, leg: leg)
            }
        }
    }
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Statistics Header
                StatisticsHeaderView(stats: totalStats, filter: selectedFilter)
                    .padding(.horizontal, 4)   // Reduced from 6 to 4
                    .padding(.vertical, 2)     // Reduced from 4 to 2
                    .background(LogbookTheme.navyLight)
                
                // Legs List
                List(filteredAndSortedLegs, id: \.leg.id, selection: $selectedLeg) { item in
                    LegRowView(trip: item.trip, leg: item.leg)
                        .listRowBackground(LogbookTheme.navyLight)
                        .tag(item.leg)
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "Search airports or trip numbers")
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Flight Legs")
        } detail: {
            if let leg = selectedLeg,
               let item = filteredAndSortedLegs.first(where: { $0.leg.id == leg.id }) {
                LegDetailView(trip: item.trip, leg: item.leg)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "airplane")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Select a flight leg")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LogbookTheme.navy)
            }
        }
    }
}

// MARK: - Statistics Header View
struct StatisticsHeaderView: View {
    let stats: (legs: Int, blockTime: Int, flightTime: Int)
    let filter: AllLegsView.LegFilter
    
    var body: some View {
        VStack(spacing: 2) {  // Reduced from 4 to 2
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(LogbookTheme.accentBlue)
                    .font(.subheadline)  // Made smaller
                Text(filter.rawValue)
                    .font(.subheadline)  // Made smaller
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 4) {  // Reduced from 6 to 4
                StatBox(
                    icon: "airplane.departure",
                    label: "Legs",
                    value: "\(stats.legs)",
                    color: LogbookTheme.accentGreen
                )
                
                StatBox(
                    icon: "clock.fill",
                    label: "Block",
                    value: formatTime(stats.blockTime),
                    color: LogbookTheme.accentBlue
                )
                
                StatBox(
                    icon: "timer",
                    label: "Flight",
                    value: formatTime(stats.flightTime),
                    color: LogbookTheme.accentOrange
                )
            }
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}

struct StatBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {  // Reduced from 3 to 2
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)  // Made smaller from title3
            
            Text(value)
                .font(.body)  // Made smaller from title3
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)  // Made smaller from caption
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)   // Reduced from 4 to 3
        .padding(.vertical, 4)     // Reduced from 5 to 4
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(8)  // Reduced from 12
    }
}

// MARK: - Leg Row View
struct LegRowView: View {
    let trip: Trip
    let leg: FlightLeg
    
    private var hasCustomDate: Bool {
        guard let legDate = leg.flightDate else { return false }
        return !Calendar.current.isDate(legDate, inSameDayAs: trip.date)
    }
    
    private var displayDate: Date {
        leg.flightDate ?? trip.date
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Route Display
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(leg.departure)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text(leg.arrival)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                
                }
                
                HStack(spacing: 4) {
                    Text("Trip: \(trip.tripNumber)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Show indicator if leg date differs from trip date
                    if hasCustomDate {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentOrange)
                    }
                }
            }
            
            // Times
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text(formatBlockTime(leg.blockMinutes()))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(displayDate))
                        .font(.caption)
                        .foregroundColor(hasCustomDate ? LogbookTheme.accentOrange : .gray)
                    
                    if hasCustomDate {
                        Text("(Trip: \(formatShortDate(trip.date)))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatBlockTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Leg Detail View
struct LegDetailView: View {
    let trip: Trip
    let leg: FlightLeg
    @Environment(\.dismiss) private var dismiss
    @State private var showingDatePicker = false
    @State private var customDate: Date
    @State private var hasCustomDate: Bool
    
    init(trip: Trip, leg: FlightLeg) {
        self.trip = trip
        self.leg = leg
        _customDate = State(initialValue: leg.flightDate ?? trip.date)
        _hasCustomDate = State(initialValue: leg.flightDate != nil)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Route Header
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            VStack {
                                Text(leg.departure)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Departure")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Image(systemName: "airplane")
                                .font(.title)
                                .foregroundColor(LogbookTheme.accentBlue)
                            
                            VStack {
                                Text(leg.arrival)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Arrival")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text("Trip: \(trip.tripNumber)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Flight Date Card (NEW)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(hasCustomDate ? LogbookTheme.accentOrange : LogbookTheme.accentBlue)
                            Text("Flight Date")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if hasCustomDate {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LogbookTheme.accentOrange.opacity(0.3))
                                    .foregroundColor(LogbookTheme.accentOrange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Button(action: { showingDatePicker = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatDate(customDate))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    if hasCustomDate {
                                        Text("Different from trip date (\(formatDate(trip.date)))")
                                            .font(.caption)
                                            .foregroundColor(LogbookTheme.accentOrange)
                                    } else {
                                        Text("Same as trip date")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.title3)
                            }
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if hasCustomDate {
                            Button(action: resetToTripDate) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset to Trip Date")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Times Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Flight Times")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            TimeDetailRow(label: "OUT", time: leg.outTime)
                            TimeDetailRow(label: "OFF", time: leg.offTime)
                            TimeDetailRow(label: "ON", time: leg.onTime)
                            TimeDetailRow(label: "IN", time: leg.inTime)
                        }
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Block Time")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(formatTime(leg.blockMinutes()))
                                    .fontWeight(.semibold)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                            
                            HStack {
                                Text("Flight Time")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(formatTime(leg.calculateFlightMinutes()))
                                    .fontWeight(.semibold)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Aircraft Info
                    if !trip.aircraft.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "airplane.circle.fill")
                                    .foregroundColor(LogbookTheme.accentOrange)
                                Text("Aircraft")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text(trip.aircraft)
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Leg Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                FlightDatePickerSheet(
                    date: $customDate,
                    tripDate: trip.date,
                    onSave: saveCustomDate,
                    onReset: resetToTripDate
                )
            }
        }
    }
    
    private func saveCustomDate() {
        // Note: This is read-only view, actual implementation would need store update
        hasCustomDate = !Calendar.current.isDate(customDate, inSameDayAs: trip.date)
        print("📅 Leg date updated: \(leg.departure)-\(leg.arrival) → \(formatDate(customDate))")
    }
    
    private func resetToTripDate() {
        customDate = trip.date
        hasCustomDate = false
        showingDatePicker = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Flight Date Picker Sheet
struct FlightDatePickerSheet: View {
    @Binding var date: Date
    let tripDate: Date
    let onSave: () -> Void
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var isDifferentFromTripDate: Bool {
        !Calendar.current.isDate(date, inSameDayAs: tripDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 50))
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text("Set Flight Date")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("For red-eyes or timezone crossings")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top)
                
                // Date Picker
                DatePicker(
                    "Flight Date",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(16)
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(isDifferentFromTripDate ? LogbookTheme.accentOrange : LogbookTheme.accentBlue)
                        Text("Trip Date")
                            .font(.headline)
                    }
                    
                    Text(formatDate(tripDate))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if isDifferentFromTripDate {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("This leg will be counted on \(formatDate(date))")
                                .font(.caption)
                        }
                        .foregroundColor(LogbookTheme.accentOrange)
                    } else {
                        Text("Flight date matches trip date")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(16)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if isDifferentFromTripDate {
                        Button(action: {
                            onReset()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Trip Date")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        onSave()
                        dismiss()
                    }) {
                        Text("Save Date")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LogbookTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(LogbookTheme.navy)
            .navigationTitle("Edit Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct TimeDetailRow: View {
    let label: String
    let time: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .leading)
            
            if !time.isEmpty {
                Text(time)
                    .foregroundColor(.white)
            } else {
                Text("--:--")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Empty Legs View
struct EmptyLegsView: View {
    let hasSearch: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasSearch ? "magnifyingglass" : "airplane")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(hasSearch ? "No Matching Legs" : "No Flight Legs")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text(hasSearch ? "Try a different search term or filter" : "Flight legs will appear here after you complete trips")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

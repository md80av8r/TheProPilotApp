// ElectronicLogbookViewer.swift
// View for browsing imported electronic logbook entries
import SwiftUI

struct ElectronicLogbookViewer: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var filterAircraft = "All"
    @State private var showingStats = true
    
    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case aircraft = "By Aircraft"
        case route = "By Route"
    }
    
    // Get unique aircraft for filter
    private var uniqueAircraft: [String] {
        let aircraft = Set(store.trips.map { $0.aircraft })
        return ["All"] + aircraft.sorted()
    }
    
    // Filtered and sorted trips
    private var filteredTrips: [Trip] {
        var trips = store.trips
        
        // Apply search filter
        if !searchText.isEmpty {
            trips = trips.filter { trip in
                trip.tripNumber.localizedCaseInsensitiveContains(searchText) ||
                trip.aircraft.localizedCaseInsensitiveContains(searchText) ||
                trip.legs.contains { leg in
                    leg.departure.localizedCaseInsensitiveContains(searchText) ||
                    leg.arrival.localizedCaseInsensitiveContains(searchText)
                } ||
                trip.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply aircraft filter
        if filterAircraft != "All" {
            trips = trips.filter { $0.aircraft == filterAircraft }
        }
        
        // Apply sort
        switch sortOrder {
        case .dateDescending:
            trips.sort { $0.date > $1.date }
        case .dateAscending:
            trips.sort { $0.date < $1.date }
        case .aircraft:
            trips.sort { $0.aircraft < $1.aircraft }
        case .route:
            trips.sort { ($0.legs.first?.departure ?? "") < ($1.legs.first?.departure ?? "") }
        }
        
        return trips
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header (collapsible)
                if showingStats {
                    LogbookStatsView(trips: filteredTrips)
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Search and Filter Bar
                VStack(spacing: 8) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search flights...", text: $searchText)
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(10)
                    
                    // Filters
                    HStack(spacing: 12) {
                        // Sort Order
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button(action: { sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortOrder.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LogbookTheme.accentBlue.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Aircraft Filter
                        if uniqueAircraft.count > 2 {
                            Menu {
                                ForEach(uniqueAircraft, id: \.self) { aircraft in
                                    Button(action: { filterAircraft = aircraft }) {
                                        HStack {
                                            Text(aircraft)
                                            if filterAircraft == aircraft {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "airplane")
                                    Text(filterAircraft == "All" ? "All Aircraft" : filterAircraft)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .foregroundColor(filterAircraft == "All" ? .gray : LogbookTheme.accentGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(filterAircraft == "All" ? LogbookTheme.fieldBackground : LogbookTheme.accentGreen.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        // Toggle Stats
                        Button(action: {
                            withAnimation { showingStats.toggle() }
                        }) {
                            Image(systemName: showingStats ? "chart.bar.fill" : "chart.bar")
                                .foregroundColor(showingStats ? LogbookTheme.accentBlue : .gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(LogbookTheme.navyLight)
                
                // Flight List
                if filteredTrips.isEmpty {
                    emptyStateView
                } else {
                    flightList
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Electronic Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(filteredTrips.count) flights")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Flights" : "No Matching Flights")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ?
                 "Import flights from ForeFlight or LogTen Pro" :
                 "Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Flight List
    private var flightList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredTrips) { trip in
                    ELogFlightRowView(trip: trip)
                }
            }
        }
    }
}

// MARK: - Stats View
struct LogbookStatsView: View {
    let trips: [Trip]
    
    private var totalBlockMinutes: Int {
        trips.reduce(0) { $0 + $1.totalBlockMinutes }
    }
    
    private var totalLegs: Int {
        trips.reduce(0) { $0 + $1.legs.count }
    }
    
    private var uniqueAirports: Int {
        var airports = Set<String>()
        for trip in trips {
            for leg in trip.legs {
                airports.insert(leg.departure)
                airports.insert(leg.arrival)
            }
        }
        return airports.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Stats Row
            HStack(spacing: 20) {
                ELogStatBox(title: "Total Time", value: formatTime(totalBlockMinutes), icon: "clock.fill", color: LogbookTheme.accentGreen)
                ELogStatBox(title: "Flights", value: "\(trips.count)", icon: "airplane", color: LogbookTheme.accentBlue)
                ELogStatBox(title: "Legs", value: "\(totalLegs)", icon: "arrow.triangle.swap", color: LogbookTheme.accentOrange)
                ELogStatBox(title: "Airports", value: "\(uniqueAirports)", icon: "mappin.circle.fill", color: .purple)
            }
            
            // Time Breakdown
            if !trips.isEmpty {
                HStack(spacing: 16) {
                    let picMinutes = trips.filter { $0.pilotRole == .captain }.reduce(0) { $0 + $1.totalBlockMinutes }
                    let sicMinutes = trips.filter { $0.pilotRole == .firstOfficer }.reduce(0) { $0 + $1.totalBlockMinutes }
                    
                    ELogMiniStatView(title: "PIC", value: formatTime(picMinutes), color: LogbookTheme.accentGreen)
                    ELogMiniStatView(title: "SIC", value: formatTime(sicMinutes), color: LogbookTheme.accentOrange)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

struct ELogStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ELogMiniStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(8)
    }
}

// MARK: - Flight Row View
struct ELogFlightRowView: View {
    let trip: Trip
    
    private var routeString: String {
        let airports = trip.legs.map { $0.departure } + [trip.legs.last?.arrival ?? ""]
        return airports.filter { !$0.isEmpty }.joined(separator: " → ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Date and Aircraft
            HStack {
                Text(trip.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(trip.aircraft)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
                
                // Pilot Role Badge
                Text(trip.pilotRole == .captain ? "PIC" : "SIC")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(trip.pilotRole == .captain ? LogbookTheme.accentGreen : LogbookTheme.accentOrange)
                    .foregroundColor(.black)
                    .cornerRadius(4)
            }
            
            // Route
            HStack {
                Text(routeString)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Total Time
                Text(formatBlockTime(trip.totalBlockMinutes))
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.accentGreen)
            }
            
            // Bottom Row: Legs count and notes
            HStack {
                if trip.legs.count > 1 {
                    Text("\(trip.legs.count) legs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if !trip.notes.isEmpty {
                    Text("•")
                        .foregroundColor(.gray)
                    Text(trip.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Trip Number if available
                if !trip.tripNumber.isEmpty && !trip.tripNumber.starts(with: "IMPORTED") {
                    Text("#\(trip.tripNumber)")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue.opacity(0.7))
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
    }
    
    private func formatBlockTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - Preview
#if DEBUG
struct ElectronicLogbookViewer_Previews: PreviewProvider {
    static var previews: some View {
        ElectronicLogbookViewer(store: SwiftDataLogBookStore.preview)
    }
}
#endif

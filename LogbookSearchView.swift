//
//  LogbookSearchView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/22/25.
//

import SwiftUI

struct LogbookSearchView: View {
    @EnvironmentObject private var store: SwiftDataLogBookStore
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @State private var showFilters = false
    @Environment(\.dismiss) var dismiss
    
    // Filter options
    @State private var selectedAircraft: String?
    @State private var dateRange: DateRange = .allTime
    @State private var minFlightTime: Double = 0
    @State private var showOnlyNightFlights = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar with scope
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search flights...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding()
                    
                    // Search scope picker
                    Picker("Search In", selection: $searchScope) {
                        ForEach(SearchScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Filter button
                    HStack {
                        Button(action: { showFilters.toggle() }) {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                        }
                        
                        if hasActiveFilters {
                            Button("Clear Filters") {
                                clearFilters()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Text("\(filteredTrips.count) results")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Divider()
                
                // Results list
                if searchText.isEmpty && !hasActiveFilters {
                    SearchEmptyState()
                } else if filteredTrips.isEmpty {
                    SearchNoResults(searchText: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTrips) { trip in
                                SearchResultRow(trip: trip, searchText: searchText)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Search Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersSheet(
                    selectedAircraft: $selectedAircraft,
                    dateRange: $dateRange,
                    minFlightTime: $minFlightTime,
                    showOnlyNightFlights: $showOnlyNightFlights
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTrips: [Trip] {
        var trips = store.trips
        
        // Apply search text
        if !searchText.isEmpty {
            trips = trips.filter { trip in
                searchMatches(trip: trip, query: searchText, scope: searchScope)
            }
        }
        
        // Apply filters
        if let aircraft = selectedAircraft {
            trips = trips.filter { $0.aircraft == aircraft }
        }
        
        switch dateRange {
        case .last30Days:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            trips = trips.filter { $0.date >= thirtyDaysAgo }
        case .last90Days:
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            trips = trips.filter { $0.date >= ninetyDaysAgo }
        case .thisYear:
            let startOfYear = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
            trips = trips.filter { $0.date >= startOfYear }
        case .allTime:
            break
        }
        
        if minFlightTime > 0 {
            let minMinutes = Int(minFlightTime * 60)
            trips = trips.filter { $0.totalFlightMinutes >= minMinutes }
        }
        
        if showOnlyNightFlights {
            trips = trips.filter { trip in
                trip.legs.contains { $0.nightLanding || $0.nightTakeoff }
            }
        }
        
        return trips.sorted { $0.date > $1.date }
    }
    
    private var hasActiveFilters: Bool {
        selectedAircraft != nil ||
        dateRange != .allTime ||
        minFlightTime > 0 ||
        showOnlyNightFlights
    }
    
    // MARK: - Helper Functions
    
    private func searchMatches(trip: Trip, query: String, scope: SearchScope) -> Bool {
        let query = query.lowercased()
        
        switch scope {
        case .all:
            return matchesAnyField(trip: trip, query: query)
        case .airports:
            return matchesAirports(trip: trip, query: query)
        case .tripNumber:
            return trip.tripNumber.lowercased().contains(query)
        case .aircraft:
            return trip.aircraft.lowercased().contains(query)
        case .notes:
            return trip.notes.lowercased().contains(query)
        }
    }
    
    private func matchesAnyField(trip: Trip, query: String) -> Bool {
        // Trip number
        if trip.tripNumber.lowercased().contains(query) {
            return true
        }
        
        // Airports
        if matchesAirports(trip: trip, query: query) {
            return true
        }
        
        // Aircraft
        if trip.aircraft.lowercased().contains(query) {
            return true
        }
        
        // Notes
        if trip.notes.lowercased().contains(query) {
            return true
        }
        
        // Crew
        for crew in trip.crew {
            if crew.name.lowercased().contains(query) {
                return true
            }
        }
        
        return false
    }
    
    private func matchesAirports(trip: Trip, query: String) -> Bool {
        for leg in trip.legs {
            if leg.departure.lowercased().contains(query) ||
               leg.arrival.lowercased().contains(query) {
                return true
            }
        }
        return false
    }
    
    private func clearFilters() {
        selectedAircraft = nil
        dateRange = .allTime
        minFlightTime = 0
        showOnlyNightFlights = false
    }
}

// MARK: - Search Scope

enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case airports = "Airports"
    case tripNumber = "Trip #"
    case aircraft = "Aircraft"
    case notes = "Notes"
    
    var id: String { rawValue }
}

// MARK: - Date Range

enum DateRange: String, CaseIterable, Identifiable {
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"
    case thisYear = "This Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let trip: Trip
    let searchText: String
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(trip.tripNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .highlightedText(searchText: searchText)
                    
                    Spacer()
                    
                    Text(trip.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Route
                HStack(spacing: 4) {
                    ForEach(Array(trip.legs.enumerated()), id: \.offset) { index, leg in
                        Text(leg.departure)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .highlightedText(searchText: searchText)
                        
                        if index < trip.legs.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(leg.arrival)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .highlightedText(searchText: searchText)
                        }
                    }
                }
                
                // Stats
                HStack(spacing: 16) {
                    let flightHours = Double(trip.totalFlightMinutes) / 60.0
                    Label("\(flightHours.formatted(.number.precision(.fractionLength(1)))) hrs",
                          systemImage: "airplane")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if trip.legs.contains(where: { $0.nightLanding || $0.nightTakeoff }) {
                        Label("Night",
                              systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    
                    Text(trip.aircraft)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .highlightedText(searchText: searchText)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            TripDetailSheetView(trip: trip)
        }
    }
}

// MARK: - Empty States

struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Search Your Logbook")
                .font(.title2.bold())
            
            Text("Search by trip number, airports, aircraft, or notes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchNoResults: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.title2.bold())
            
            Text("No flights match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try different search terms or filters")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filters Sheet

struct SearchFiltersSheet: View {
    @Binding var selectedAircraft: String?
    @Binding var dateRange: DateRange
    @Binding var minFlightTime: Double
    @Binding var showOnlyNightFlights: Bool
    
    @EnvironmentObject private var store: SwiftDataLogBookStore
    @Environment(\.dismiss) var dismiss
    
    var availableAircraft: [String] {
        Array(Set(store.trips.map { $0.aircraft })).sorted()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date Range") {
                    Picker("Period", selection: $dateRange) {
                        ForEach(DateRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                
                Section("Aircraft") {
                    Picker("Aircraft Type", selection: $selectedAircraft) {
                        Text("All Aircraft").tag(nil as String?)
                        ForEach(availableAircraft, id: \.self) { aircraft in
                            Text(aircraft).tag(aircraft as String?)
                        }
                    }
                }
                
                Section("Flight Time") {
                    HStack {
                        Text("Minimum:")
                        Spacer()
                        Text("\(minFlightTime.formatted(.number.precision(.fractionLength(1)))) hrs")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $minFlightTime, in: 0...10, step: 0.5)
                }
                
                Section("Flight Type") {
                    Toggle("Night Flights Only", isOn: $showOnlyNightFlights)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Text Highlighting Extension

extension Text {
    func highlightedText(searchText: String) -> Text {
        // Basic highlighting - you can enhance this with AttributedString
        return self
    }
}

// MARK: - Trip Detail Sheet (Simple View)

struct TripDetailSheetView: View {
    let trip: Trip
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(trip.tripNumber)
                            .font(.title.bold())
                        
                        Text(trip.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(trip.aircraft)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Route Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Route")
                            .font(.headline)
                        
                        ForEach(trip.legs) { leg in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(leg.departure)
                                            .font(.title3.bold())
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.secondary)
                                        Text(leg.arrival)
                                            .font(.title3.bold())
                                    }
                                    
                                    if !leg.flightNumber.isEmpty {
                                        Text("Flight \(leg.flightNumber)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if !leg.outTime.isEmpty {
                                        Text("OUT: \(leg.outTime)")
                                            .font(.caption.monospacedDigit())
                                    }
                                    if !leg.inTime.isEmpty {
                                        Text("IN: \(leg.inTime)")
                                            .font(.caption.monospacedDigit())
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Stats Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Flight Time")
                            .font(.headline)
                        
                        HStack {
                            SearchStatBox(
                                title: "Block Time",
                                value: formatMinutes(trip.totalBlockMinutes),
                                icon: "clock.fill"
                            )
                            
                            SearchStatBox(
                                title: "Flight Time",
                                value: formatMinutes(trip.totalFlightMinutes),
                                icon: "airplane"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Crew Section
                    if !trip.crew.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Crew")
                                .font(.headline)
                            
                            ForEach(trip.crew) { member in
                                HStack {
                                    Text(member.role)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(member.name)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Notes Section
                    if !trip.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            
                            Text(trip.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours):\(String(format: "%02d", mins))"
    }
}

struct SearchStatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct LogbookSearchView_Previews: PreviewProvider {
    static var previews: some View {
        LogbookSearchView()
    }
}

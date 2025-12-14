// JumpseatSearchView.swift - Proximity Search for Available Jumpseats
// ProPilot App

import SwiftUI
import CoreLocation

struct JumpseatSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = JumpseatService.shared
    @StateObject private var settings = JumpseatSettings.shared
    
    @State private var searchAirport = ""
    @State private var searchRadius: Double = 50
    @State private var dateRange: DateRangeOption = .week
    @State private var cassOnly = false
    @State private var isSearching = false
    @State private var searchResults: [JumpseatFlight] = []
    @State private var hasSearched = false
    @State private var errorMessage: String?
    
    enum DateRangeOption: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case week = "Next 7 Days"
        case twoWeeks = "Next 14 Days"
        case month = "Next 30 Days"
        
        var toDate: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            case .week:
                return calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            case .twoWeeks:
                return calendar.date(byAdding: .day, value: 14, to: Date()) ?? Date()
            case .month:
                return calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchForm
                    resultsSection
                }
            }
            .navigationTitle("Find a Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            searchRadius = settings.defaultSearchRadius
        }
    }
    
    private var searchForm: some View {
        VStack(spacing: 16) {
            // Airport Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination Airport")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "airplane.arrival")
                        .foregroundColor(.gray)
                    
                    TextField("ICAO Code (e.g., KDTW)", text: $searchAirport)
                        .textInputAutocapitalization(.characters)
                        .foregroundColor(.white)
                        .onChange(of: searchAirport) { _, newValue in
                            searchAirport = newValue.uppercased()
                        }
                    
                    if !searchAirport.isEmpty {
                        Button { searchAirport = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(LogbookTheme.cardBackground)
                .cornerRadius(10)
            }
            
            // Radius Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Search Radius")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(searchRadius)) NM")
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                Slider(value: $searchRadius, in: 10...200, step: 10)
                    .tint(LogbookTheme.accentBlue)
            }
            
            // Date Range & CASS Filter
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date Range").font(.caption).foregroundColor(.gray)
                    Menu {
                        ForEach(DateRangeOption.allCases, id: \.self) { option in
                            Button(option.rawValue) { dateRange = option }
                        }
                    } label: {
                        HStack {
                            Text(dateRange.rawValue).foregroundColor(.white)
                            Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LogbookTheme.cardBackground)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Toggle(isOn: $cassOnly) {
                    Text("CASS Only").font(.caption).foregroundColor(.gray)
                }
                .toggleStyle(SwitchToggleStyle(tint: LogbookTheme.accentBlue))
            }
            
            // Search Button
            Button { performSearch() } label: {
                HStack {
                    if isSearching {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isSearching ? "Searching..." : "Search Flights").font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(searchAirport.count >= 3 ? LogbookTheme.accentBlue : Color.gray.opacity(0.5))
                .cornerRadius(12)
            }
            .disabled(searchAirport.count < 3 || isSearching)
        }
        .padding()
        .background(LogbookTheme.cardBackground.opacity(0.5))
    }
    
    private var resultsSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = errorMessage {
                    errorView(error)
                } else if !hasSearched {
                    initialStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsListView
                }
            }
            .padding()
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundColor(.orange)
            Text(error).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle").font(.system(size: 50)).foregroundColor(.gray)
            Text("Search for Available Jumpseats").font(.headline).foregroundColor(.white)
            Text("Enter an airport code to find flights arriving nearby, including cargo and charter flights.")
                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle.fill").font(.system(size: 50)).foregroundColor(.gray)
            Text("No Flights Found").font(.headline).foregroundColor(.white)
            Text("Try expanding your search radius or date range.")
                .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
            
            Button {
                searchRadius = min(searchRadius + 50, 200)
            } label: {
                Text("Expand Radius to \(Int(min(searchRadius + 50, 200))) NM")
                    .font(.subheadline).foregroundColor(LogbookTheme.accentBlue)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
    
    private var resultsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(searchResults.count) Flight\(searchResults.count == 1 ? "" : "s") Found")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Text("Near \(searchAirport)").font(.caption).foregroundColor(.gray)
            }
            
            ForEach(searchResults) { flight in
                SearchResultCard(flight: flight, targetAirport: searchAirport)
            }
        }
    }
    
    private func performSearch() {
        guard searchAirport.count >= 3 else { return }
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let criteria = JumpseatSearchCriteria(
                    nearAirport: searchAirport,
                    radiusNM: searchRadius,
                    toDate: dateRange.toDate,
                    cassOnly: cassOnly
                )
                let results = try await service.searchFlights(criteria: criteria)
                
                await MainActor.run {
                    searchResults = results
                    hasSearched = true
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    hasSearched = true
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let flight: JumpseatFlight
    let targetAirport: String
    @State private var showingDetail = false
    
    var body: some View {
        Button { showingDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.routeString).font(.headline).foregroundColor(.white)
                        if let distance = calculateDistance() {
                            Text("\(Int(distance)) NM from \(targetAirport)")
                                .font(.caption).foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.aircraft).font(.subheadline.bold()).foregroundColor(.white)
                        Text(flight.operatorName).font(.caption).foregroundColor(.gray)
                    }
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Details
                HStack {
                    Label("\(flight.relativeDateString) \(flight.displayTime)", systemImage: "calendar")
                        .font(.caption).foregroundColor(.gray)
                    
                    Spacer()
                    
                    Label("\(flight.seatsAvailable) seat\(flight.seatsAvailable == 1 ? "" : "s")", systemImage: "person")
                        .font(.caption).foregroundColor(.gray)
                    
                    if flight.cassRequired {
                        Text("CASS").font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue).cornerRadius(4)
                    }
                }
                
                // Pilot
                HStack {
                    Image(systemName: "person.circle").foregroundColor(.gray)
                    Text(flight.pilotDisplayName).font(.caption).foregroundColor(.gray)
                    
                    if let rating = flight.pilotRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating)).font(.caption2).foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                }
            }
            .padding()
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingDetail) {
            JumpseatFlightDetailView(flight: flight)
        }
    }
    
    private func calculateDistance() -> Double? {
        // TODO: Calculate actual distance using airport coordinates
        // For now, return a placeholder
        return Double.random(in: 10...50)
    }
}

// MARK: - Preview

#if DEBUG
struct JumpseatSearchView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatSearchView()
    }
}
#endif

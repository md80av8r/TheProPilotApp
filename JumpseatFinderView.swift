//
//  JumpseatFinderView.swift
//  TheProPilotApp
//
//  Jumpseat flight finder - helps pilots find flights for commuting
//

import SwiftUI

struct JumpseatFinderView: View {
    @StateObject private var viewModel = JumpseatViewModel()
    @State private var fromAirport = ""
    @State private var toAirport = ""
    @State private var selectedDate = Date()
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        headerCard
                        
                        // Free Tier Info Card
                        freeTierInfoCard
                        
                        // Search Form
                        searchFormCard
                        
                        // Search Button
                        searchButton
                        
                        // Error Message
                        if let error = errorMessage {
                            errorCard(error)
                        }
                        
                        // Results
                        if isSearching {
                            loadingView
                        } else if !viewModel.flights.isEmpty {
                            resultsSection
                        } else if viewModel.hasSearched {
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Jumpseat Finder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                JumpseatSettingsView()
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 24))
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text("Find Your Commute")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Search for available flights between airports. Perfect for planning jumpseats and commutes.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Free Tier Info Card
    
    private var freeTierInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Beta: Try These Routes")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Free API tier works best with major airports:")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Airport chips
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(["JFK", "LAX", "ORD", "ATL"], id: \.self) { code in
                        airportChip(code)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(["DFW", "DEN", "SFO", "MIA"], id: \.self) { code in
                        airportChip(code)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(["LHR", "CDG", "FRA"], id: \.self) { code in
                        airportChip(code)
                    }
                    Spacer()
                }
            }
            
            Text("Tap any code to auto-fill. Or leave API key blank to use demo data.")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
                .italic()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func airportChip(_ code: String) -> some View {
        Button(action: {
            if fromAirport.isEmpty {
                fromAirport = code
            } else if toAirport.isEmpty {
                toAirport = code
            } else {
                // Swap if both are filled
                fromAirport = toAirport
                toAirport = code
            }
        }) {
            Text(code)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(LogbookTheme.accentBlue.opacity(0.8))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Search Form
    
    private var searchFormCard: some View {
        VStack(spacing: 16) {
            // From Airport
            VStack(alignment: .leading, spacing: 8) {
                Label("From", systemImage: "airplane.departure")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                TextField("e.g., KMEM or MEM", text: $fromAirport)
                    .textFieldStyle(JumpseatTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            
            // Swap Button
            Button(action: swapAirports) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            // To Airport
            VStack(alignment: .leading, spacing: 8) {
                Label("To", systemImage: "airplane.arrival")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                TextField("e.g., KATL or ATL", text: $toAirport)
                    .textFieldStyle(JumpseatTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            
            // Date Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Date", systemImage: "calendar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(LogbookTheme.accentBlue)
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Search Button
    
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                
                Text(isSearching ? "Searching..." : "Search Flights")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSearch ? LogbookTheme.accentBlue : Color.gray)
            .cornerRadius(16)
        }
        .disabled(!canSearch || isSearching)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(viewModel.flights.count) Flights Found")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Tap to view details")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.flights) { flight in
                NavigationLink(destination: JumpseatFlightDetailView(flight: flight)) {
                    JumpseatFlightResultCard(flight: flight)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Searching for flights...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("This may take a moment")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Flights Found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try adjusting your search dates or airport codes")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Error Card
    
    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private var canSearch: Bool {
        !fromAirport.trimmingCharacters(in: .whitespaces).isEmpty &&
        !toAirport.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func swapAirports() {
        let temp = fromAirport
        fromAirport = toAirport
        toAirport = temp
    }
    
    private func performSearch() {
        errorMessage = nil
        isSearching = true
        
        Task {
            // No try/catch needed - ViewModel handles all errors internally
            await viewModel.searchFlights(
                from: fromAirport,
                to: toAirport,
                date: selectedDate
            )
            
            await MainActor.run {
                isSearching = false
            }
        }
    }
}

// MARK: - Flight Result Card

struct JumpseatFlightResultCard: View {
    let flight: FlightSchedule
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Airline + Flight Number
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.airline)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(flight.flightNumber)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status Badge
                Text(flight.status.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(flight.status))
                    .cornerRadius(8)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Route: DEP -> ARR
            HStack(alignment: .center, spacing: 16) {
                // Departure
                VStack(spacing: 8) {
                    Text(flight.departure)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(flight.formattedDepartureTime)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                .frame(maxWidth: .infinity)
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                // Arrival
                VStack(spacing: 8) {
                    Text(flight.arrival)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(flight.formattedArrivalTime)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Additional Info
            HStack(spacing: 20) {
                if let aircraft = flight.aircraft {
                    Label(aircraft, systemImage: "airplane")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let gate = flight.gate {
                    Label("Gate \(gate)", systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let terminal = flight.terminal {
                    Label("Terminal \(terminal)", systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Load Indicator (Phase 2 feature)
            loadIndicatorBadge
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func statusColor(_ status: FlightStatus) -> Color {
        switch status {
        case .scheduled: return .blue
        case .active: return .green
        case .landed: return .gray
        case .cancelled, .incident, .diverted: return .red
        }
    }
    
    private var loadIndicatorBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: flight.loadIndicator.icon)
                .foregroundColor(loadIndicatorColor)
            
            Text(loadIndicatorText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(loadIndicatorColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(loadIndicatorColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var loadIndicatorColor: Color {
        switch flight.loadIndicator {
        case .available: return .green
        case .tight: return .yellow
        case .full: return .red
        case .unknown: return .gray
        }
    }
    
    private var loadIndicatorText: String {
        switch flight.loadIndicator {
        case .available: return "Likely Available"
        case .tight: return "May Be Tight"
        case .full: return "Likely Full"
        case .unknown: return "Load Unknown"
        }
    }
}

// MARK: - Flight Detail View

struct JumpseatFlightDetailView: View {
    let flight: FlightSchedule
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Flight Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(flight.airline)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Flight \(flight.flightNumber)")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(flight.status.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor(flight.status))
                                .cornerRadius(8)
                            
                            if let aircraft = flight.aircraft {
                                Text(aircraft)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(LogbookTheme.fieldBackground)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    
                    // Route Info
                    VStack(spacing: 20) {
                        routeInfoRow(
                            title: "Departure",
                            code: flight.departure,
                            time: flight.formattedDepartureTime,
                            gate: flight.gate,
                            terminal: flight.terminal
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        routeInfoRow(
                            title: "Arrival",
                            code: flight.arrival,
                            time: flight.formattedArrivalTime,
                            gate: nil,
                            terminal: nil
                        )
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    
                    // Pro Tip
                    proTipCard
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Flight Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func routeInfoRow(title: String, code: String, time: String, gate: String?, terminal: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            HStack(alignment: .center) {
                Text(code)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(time)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            if let terminal = terminal, let gate = gate {
                HStack(spacing: 16) {
                    Label("Terminal \(terminal)", systemImage: "building.2")
                    Label("Gate \(gate)", systemImage: "mappin.circle")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
    }
    
    private var proTipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Pro Tip")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Arrive at the gate early and speak with the gate agent. Have your ID and jumpseat authorization ready. Be professional and courteous.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func statusColor(_ status: FlightStatus) -> Color {
        switch status {
        case .scheduled: return .blue
        case .active: return .green
        case .landed: return .gray
        case .cancelled, .incident, .diverted: return .red
        }
    }
}

// MARK: - View Model

@MainActor
class JumpseatViewModel: ObservableObject {
    @Published var flights: [FlightSchedule] = []
    @Published var hasSearched = false
    
    func searchFlights(from: String, to: String, date: Date) async {
        hasSearched = false
        flights = []
        
        do {
            let results = try await FlightScheduleService.shared.searchFlights(
                from: from,
                to: to,
                date: date
            )
            
            flights = results
            hasSearched = true
            
        } catch let error as FlightScheduleError {
            // Always use mock data on any API error during testing
            print("⚠️ API error (\(error)), falling back to mock data")
            flights = FlightScheduleService.shared.getMockFlights(from: from, to: to)
            hasSearched = true
        } catch {
            // Catch any other errors too
            print("⚠️ Unknown error (\(error)), falling back to mock data")
            flights = FlightScheduleService.shared.getMockFlights(from: from, to: to)
            hasSearched = true
        }
    }
}

// MARK: - Settings View

struct JumpseatSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("aviationStackAPIKey") private var apiKey = ""
    @State private var showingAPIInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Configure your flight schedule API to enable real-time flight searches.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("API Configuration")) {
                    SecureField("AviationStack API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    Button(action: { showingAPIInfo = true }) {
                        Label("How to Get API Key", systemImage: "info.circle")
                    }
                }
                
                Section {
                    Text("Free tier: 100 requests/month\n~$50/month: 10,000 requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Jumpseat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Get API Key", isPresented: $showingAPIInfo) {
                Button("Open Website") {
                    if let url = URL(string: "https://aviationstack.com/signup/free") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Visit aviationstack.com to sign up for a free API key. Copy your access key and paste it here.")
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct JumpseatTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding()
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(12)
    }
}

// MARK: - Preview

struct JumpseatFinderView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatFinderView()
    }
}

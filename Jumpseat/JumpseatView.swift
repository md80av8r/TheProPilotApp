// JumpseatView.swift - Main Jumpseat Network Tab View
// ProPilot App

import SwiftUI

struct JumpseatView: View {
    @StateObject private var service = JumpseatService.shared
    @StateObject private var settings = JumpseatSettings.shared
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingSearch = false
    @State private var searchAirport = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Segmented Control
                    segmentedControl
                    
                    // Content based on selected tab
                    TabView(selection: $selectedTab) {
                        // Tab 0: Discover Flights
                        discoverView
                            .tag(0)
                        
                        // Tab 1: My Flights (Posted)
                        myFlightsView
                            .tag(1)
                        
                        // Tab 2: My Requests
                        myRequestsView
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Jumpseat Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                JumpseatSettingsView()
            }
            .sheet(isPresented: $showingProfile) {
                JumpseatProfileSetupView()
            }
            .sheet(isPresented: $showingSearch) {
                JumpseatSearchView()
            }
        }
        .onAppear {
            // Check if profile needs setup
            if !settings.isProfileComplete && !settings.hasCompletedOnboarding {
                showingProfile = true
            }
        }
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tabTitle(for: index))
                            .font(.subheadline.weight(selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? .white : .gray)
                        
                        // Badge for pending requests
                        if index == 2 && service.incomingRequests.count > 0 {
                            Text("\(service.incomingRequests.count)")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LogbookTheme.accentOrange)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == index ?
                        LogbookTheme.accentBlue.opacity(0.2) :
                        Color.clear
                    )
                }
            }
        }
        .background(LogbookTheme.cardBackground)
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Discover"
        case 1: return "My Flights"
        case 2: return "Requests"
        default: return ""
        }
    }
    
    // MARK: - Discover View
    
    private var discoverView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search Card
                searchCard
                
                // Quick Stats
                quickStatsCard
                
                // Recent/Nearby Flights
                recentFlightsSection
            }
            .padding()
        }
    }
    
    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a Ride")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Airport (e.g., KDTW)", text: $searchAirport)
                    .textInputAutocapitalization(.characters)
                    .foregroundColor(.white)
                
                Button {
                    showingSearch = true
                } label: {
                    Text("Search")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(LogbookTheme.navy)
            .cornerRadius(10)
            
            Text("Search for flights arriving near your destination")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var quickStatsCard: some View {
        HStack(spacing: 20) {
            JumpseatStatBox(title: "Available", value: "\(service.nearbyFlights.count)", icon: "airplane", color: .green)
            JumpseatStatBox(title: "My Posts", value: "\(service.myPostedFlights.count)", icon: "paperplane", color: .blue)
            JumpseatStatBox(title: "Requests", value: "\(service.incomingRequests.count)", icon: "bell", color: .orange)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var recentFlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Jumpseats")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    showingSearch = true
                }
                .font(.subheadline)
                .foregroundColor(LogbookTheme.accentBlue)
            }
            
            if service.nearbyFlights.isEmpty {
                emptyStateCard
            } else {
                ForEach(service.nearbyFlights.prefix(5)) { flight in
                    JumpseatFlightCard(flight: flight)
                }
            }
        }
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Flights Found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try searching for flights near a specific airport, or check back later.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - My Flights View
    
    private var myFlightsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if service.myPostedFlights.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "paperplane.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Flights Posted")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("When you create trips in ProPilot, they can automatically be posted here for other pilots to find.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        if !settings.autoPostFlights {
                            Button {
                                showingSettings = true
                            } label: {
                                Text("Enable Auto-Post")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(LogbookTheme.accentBlue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(service.myPostedFlights) { flight in
                        MyFlightCard(flight: flight)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - My Requests View
    
    private var myRequestsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Incoming requests (on my flights)
                if !service.incomingRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pending Requests")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(service.incomingRequests) { request in
                            IncomingRequestCard(request: request)
                        }
                    }
                }
                
                // My outgoing requests
                VStack(alignment: .leading, spacing: 12) {
                    Text("My Requests")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if service.myRequests.isEmpty {
                        Text("You haven't requested any jumpseats yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(service.myRequests) { request in
                            MyRequestCard(request: request)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct JumpseatStatBox: View {
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
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct JumpseatFlightCard: View {
    let flight: JumpseatFlight
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Route
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.routeString)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(flight.relativeDateString) • \(flight.displayTime)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Aircraft & Operator
                VStack(alignment: .trailing, spacing: 4) {
                    Text(flight.aircraft)
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text(flight.operatorName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(LogbookTheme.cardBackground)
            .cornerRadius(10)
        }
        .sheet(isPresented: $showingDetail) {
            JumpseatFlightDetailView(flight: flight)
        }
    }
}

struct MyFlightCard: View {
    let flight: JumpseatFlight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(flight.routeString)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                JumpseatStatusBadge(status: flight.status)
            }
            
            HStack {
                Label("\(flight.displayDate) \(flight.displayTime)", systemImage: "calendar")
                Spacer()
                Label(flight.aircraft, systemImage: "airplane")
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            if flight.hasInterestedPilots {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(LogbookTheme.accentOrange)
                    
                    Text("\(flight.interestedCount) pilot\(flight.interestedCount == 1 ? "" : "s") interested")
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                .font(.subheadline.bold())
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(10)
    }
}

struct JumpseatStatusBadge: View {
    let status: JumpseatFlightStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
        case .available: return .green
        case .claimed: return .orange
        case .departed: return .blue
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

struct IncomingRequestCard: View {
    let request: JumpseatRequest
    @StateObject private var service = JumpseatService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(request.requesterName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(request.requesterAirline)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(request.status.displayName)
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
            
            if !request.message.isEmpty {
                Text("\"\(request.message)\"")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .italic()
            }
            
            if request.isPending {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            try? await service.respondToRequest(request, approved: true)
                        }
                    } label: {
                        Text("Approve")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    Button {
                        Task {
                            try? await service.respondToRequest(request, approved: false)
                        }
                    } label: {
                        Text("Deny")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LogbookTheme.accentOrange.opacity(0.5), lineWidth: 1)
        )
    }
}

struct MyRequestCard: View {
    let request: JumpseatRequest
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Flight: \(request.flightId.prefix(8))...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(request.status.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(10)
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .approved: return .green
        case .denied: return .red
        case .withdrawn: return .gray
        }
    }
    
    private var statusIcon: String {
        switch request.status {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward.circle"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct JumpseatView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatView()
    }
}
#endif

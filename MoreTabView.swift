// MoreTabView.swift - UPDATED WITH CONSOLIDATED SETTINGS
import SwiftUI
import Foundation

struct MoreTabView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @EnvironmentObject var nocSettings: NOCSettingsStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    @ObservedObject var activityManager: PilotActivityManager
    @ObservedObject var scannerSettings: ScannerSettings
    @ObservedObject var documentStore: TripDocumentManager
    @ObservedObject var crewContactManager: CrewContactManager
    @Binding var sharedDutyStartTime: Date?
    @Binding var showingElectronicLogbook: Bool
    @ObservedObject var phoneWatchConnectivity: PhoneWatchConnectivity
    @ObservedObject var locationManager: PilotLocationManager
    @ObservedObject var opsManager: OPSCallingManager
    var speedMonitor: GPSSpeedMonitor? // Add speedMonitor parameter
    
    @State private var showingClocksView = false
    @State private var showingNOCSettings = false
    @State private var showingGPSRAIM = false
    @State private var showingWatchSettings = false
    @State private var showingDataBackup = false
    @State private var showingCrewContacts = false
    @State private var showingWeather = false
    @State private var showingCalculator = false
    @State private var showingFlightOps = false
    @State private var showingLegs = false
    @State private var showingDocuments = false
    @State private var showingNotes = false
    // GPX Testing
    @State private var showingGPXTesting = false
    
    // NEW: Consolidated settings views
    @State private var showingAirlineConfig = false
    @State private var showingAircraftManagement = false
    @State private var showingAutoTimeLogging = false
    @State private var showingScannerEmailConfig = false
    @State private var showingProximitySettings = false
    
    // NEW: Additional settings
    @State private var showingPerDiemSettings = false
    @State private var showingFAR117Settings = false
    @State private var showingNotificationSettings = false
    @State private var showingElectronicLogbookView = false
    @State private var showingRolling30Day = false
    @State private var showingAreaGuide = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Grid layout
                iPadGridLayout
            } else {
                // iPhone: List layout
                iPhoneListLayout
            }
        }
        .background(LogbookTheme.navy)
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.large)
        
        // MARK: - Sheets
        .sheet(isPresented: $showingClocksView) {
            ClocksTabView(sharedDutyStartTime: $sharedDutyStartTime)
                .environmentObject(airlineSettings)
                .environmentObject(activityManager)
        }
        .sheet(isPresented: $showingNOCSettings) {
            NOCSettingsView(nocSettings: nocSettings)
        }
        .sheet(isPresented: $showingGPSRAIM) {
            GPSRAIMView()
        }
        .sheet(isPresented: $showingWatchSettings) {
            NavigationView {
                WatchConnectivityStatusView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingWatchSettings = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        
        .sheet(isPresented: $showingCrewContacts) {
            NavigationView {
                CrewContactsView(contactManager: crewContactManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingCrewContacts = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingWeather) {
            NavigationView {
                WeatherView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingWeather = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingCalculator) {
            FlightCalculatorView()
        }
        .sheet(isPresented: $showingFlightOps) {
            NavigationView {
                FlightOpsView(airlineSettings: airlineSettings)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingFlightOps = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingLegs) {
            NavigationView {
                AllLegsView(store: store)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingLegs = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        
        // NEW: Consolidated Settings Sheets
        .sheet(isPresented: $showingAirlineConfig) {
            AirlineConfigurationView(airlineSettings: airlineSettings)
        }
        .sheet(isPresented: $showingAircraftManagement) {
            AircraftManagementView()
        }
        .sheet(isPresented: $showingAutoTimeLogging) {
            AutoTimeSettingsView(
                autoTimeSettings: AutoTimeSettings.shared,
                speedMonitor: GPSSpeedMonitor()
            )
        }
        .sheet(isPresented: $showingScannerEmailConfig) {
            ScannerEmailConfigView(airlineSettings: airlineSettings)  // ✅ Correct!
        }
        .sheet(isPresented: $showingProximitySettings) {
            ProximitySettingsView()
        }
        .sheet(isPresented: $showingDataBackup) {
            DataBackupView(
                store: store,
                airlineSettings: airlineSettings,
                nocSettings: nocSettings,
                scannerSettings: scannerSettings,
                documentStore: documentStore
            )
        }
        
        // NEW: Additional settings sheets
        .sheet(isPresented: $showingPerDiemSettings) {
            PerDiemView(store: store)
        }
        .sheet(isPresented: $showingFAR117Settings) {
            FAR117SettingsView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingElectronicLogbookView) {
            SimpleElectronicLogbookView(mainStore: store)
        }
        .sheet(isPresented: $showingRolling30Day) {
            NavigationView {
                Rolling30DayComplianceView(store: store)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingRolling30Day = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        
        .sheet(isPresented: $showingGPXTesting) {
            NavigationView {
                GPXTestingView(speedMonitor: speedMonitor)
                    .environmentObject(locationManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingGPXTesting = false }
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAreaGuide) {
            AreaGuideView()
        }
    }
    
    // MARK: - iPhone List Layout
    private var iPhoneListLayout: some View {
        List {
            // APPLE WATCH SECTION
            Section("Apple Watch") {
                // Tappable status row that opens Watch Settings
                Button {
                    showingWatchSettings = true
                } label: {
                    HStack {
                        Image(systemName: phoneWatchConnectivity.isWatchConnected ? "applewatch" : "applewatch.slash")
                            .foregroundColor(phoneWatchConnectivity.isWatchConnected ? .green : .red)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Apple Watch")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(phoneWatchConnectivity.isWatchConnected ? "Connected & Ready" : "Not Connected")
                                .font(.caption)
                                .foregroundColor(phoneWatchConnectivity.isWatchConnected ? .green : .red)
                        }
                        
                        Spacer()
                        
                        if phoneWatchConnectivity.isWatchConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // AIRLINE & AIRCRAFT SECTION
            Section("Airline & Aircraft") {
                MoreRowItem(
                    title: "Airline Configuration",
                    subtitle: "Airline name, callsign, home base, and timers",
                    icon: "building.2.fill",
                    color: LogbookTheme.accentGreen
                ) {
                    showingAirlineConfig = true
                }
                
                MoreRowItem(
                    title: "Aircraft Management",
                    subtitle: "Manage your fleet aircraft",
                    icon: "airplane",
                    color: LogbookTheme.accentGreen
                ) {
                    showingAircraftManagement = true
                }
            }
            
            // FLIGHT LOGGING SECTION
            Section("Flight Logging") {
                MoreRowItem(
                    title: "Auto Time Logging",
                    subtitle: "GPS speed tracking and time rounding",
                    icon: "clock.arrow.2.circlepath",
                    color: LogbookTheme.accentOrange
                ) {
                    showingAutoTimeLogging = true
                }
                
                MoreRowItem(
                    title: "Airport Detection",
                    subtitle: "Proximity alerts and auto-fill airports",
                    icon: "location.circle.fill",
                    color: .blue
                ) {
                    showingProximitySettings = true
                }
                
                MoreRowItem(
                    title: "Scanner Email Settings",
                    subtitle: "Configure email destinations for documents",
                    icon: "envelope.fill",
                    color: LogbookTheme.accentOrange
                ) {
                    showingScannerEmailConfig = true
                }
                
                MoreRowItem(
                    title: "Time Away / Per Diem",
                    subtitle: "Track time away from base and per diem earned",
                    icon: "dollarsign.circle.fill",
                    color: LogbookTheme.accentGreen
                ) {
                    showingPerDiemSettings = true
                }
                
                MoreRowItem(
                    title: "FAR 117 Settings",
                    subtitle: "Flight time limits and rest requirements",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .red
                ) {
                    showingFAR117Settings = true
                }
                
                MoreRowItem(
                    title: "Notification Settings",
                    subtitle: "Alerts, reminders, and sounds",
                    icon: "bell.badge.fill",
                    color: .purple
                ) {
                    showingNotificationSettings = true
                }
            }
            
            // CLOCKS & TIMERS SECTION
            Section("Clocks & Timers") {
                MoreRowItem(
                    title: "World Clock",
                    subtitle: "Zulu time, local time, and duty timer",
                    icon: "clock.fill",
                    color: LogbookTheme.accentBlue
                ) {
                    showingClocksView = true
                }
                
                HStack(spacing: 16) {
                    Image(systemName: "stopwatch.fill")
                        .font(.title2)
                        .foregroundColor(LogbookTheme.accentOrange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duty Timer")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let dutyStart = sharedDutyStartTime {
                            Text("On duty: \(formatDutyDuration(from: dutyStart, to: Date()))")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentOrange)
                        } else {
                            Text("Not on duty")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if sharedDutyStartTime != nil {
                        Button("End") {
                            sharedDutyStartTime = nil
                        }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    } else {
                        Button("Start") {
                            sharedDutyStartTime = Date()
                        }
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // SCHEDULE & OPERATIONS SECTION
            Section("Schedule & Operations") {
                MoreRowItem(
                    title: "NOC Schedule Import",
                    subtitle: "Import your personal roster from NOC system",
                    icon: "calendar.badge.clock",
                    color: LogbookTheme.accentGreen
                ) {
                    showingNOCSettings = true
                }
                
                MoreRowItem(
                    title: "Crew Contacts",
                    subtitle: "Manage crew member information",
                    icon: "person.3.fill",
                    color: LogbookTheme.accentBlue
                ) {
                    showingCrewContacts = true
                }
            }

            // SMART TRIP GENERATION SECTION - Move it here, outside the other section
            TripGenerationSettingsRow()
            
            // FLIGHT TOOLS SECTION
            Section("Flight Tools") {
                MoreRowItem(
                    title: "Area Guide",
                    subtitle: "Airport info, restaurants, hotels, and transportation",
                    icon: "map.fill",
                    color: .green
                ) {
                    showingAreaGuide = true
                }
                
                MoreRowItem(
                    title: "GPS RAIM Check",
                    subtitle: "Monitor GPS accuracy and integrity",
                    icon: "location.fill",
                    color: .purple
                ) {
                    showingGPSRAIM = true
                }
                
                MoreRowItem(
                    title: "Weather",
                    subtitle: "Check aviation weather",
                    icon: "cloud.sun.fill",
                    color: .cyan
                ) {
                    showingWeather = true
                }
                
                // ADD THIS NEW ROW
                MoreRowItem(
                    title: "GPX Flight Testing",
                    subtitle: "Test flight detection",
                    icon: "airplane.circle.fill", color: .orange
                ) {
                    showingGPXTesting = true
                }
                
                MoreRowItem(
                    title: "Flight Calculator",
                    subtitle: "Fuel, temperature, uplift check, crosswind",
                    icon: "function",
                    color: LogbookTheme.accentOrange
                ) {
                    showingCalculator = true
                }
                
                MoreRowItem(
                    title: "Flight Ops",
                    subtitle: "Operational information and procedures",
                    icon: "airplane.circle.fill",
                    color: .purple
                ) {
                    showingFlightOps = true
                }
            }
            
            // TRACKING & REPORTS SECTION
            Section("Tracking & Reports") {
                // Rolling 30-Day Compliance - TOP PRIORITY
                Button {
                    showingRolling30Day = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(rolling30StatusColor.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.title3)
                                .foregroundColor(rolling30StatusColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("30-Day Rolling Hours")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("FAR 121 flight time limit tracking")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Current hours badge
                        Text(rolling30StatusText)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rolling30StatusColor.opacity(0.2))
                            .foregroundColor(rolling30StatusColor)
                            .cornerRadius(6)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                MoreRowItem(
                    title: "Flight Legs",
                    subtitle: "View all logged flight legs",
                    icon: "list.bullet.rectangle",
                    color: LogbookTheme.accentGreen
                ) {
                    showingLegs = true
                }
            }
            
            // FLIGHT DATA SECTION
            Section("Flight Data") {
                MoreRowItem(
                    title: "Electronic Logbook",
                    subtitle: "Import/Export ForeFlight & LogTen Pro",
                    icon: "book.closed.fill",
                    color: LogbookTheme.accentBlue
                ) {
                    showingElectronicLogbookView = true
                }
                
                MoreRowItem(
                    title: "Backup & Restore",
                    subtitle: "Manage automatic and manual backups",
                    icon: "externaldrive.fill.badge.timemachine",
                    color: LogbookTheme.accentOrange
                ) {
                    showingDataBackup = true
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - iPad Grid Layout
    private var iPadGridLayout: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 20) {
                // Watch (single entry - combines status and settings)
                MoreGridCard(title: "Apple Watch", icon: "applewatch", color: LogbookTheme.accentBlue) {
                    showingWatchSettings = true
                }
                
                // Airline & Aircraft
                MoreGridCard(title: "Airline Configuration", icon: "building.2.fill", color: LogbookTheme.accentGreen) {
                    showingAirlineConfig = true
                }
                
                MoreGridCard(title: "Aircraft Management", icon: "airplane", color: LogbookTheme.accentGreen) {
                    showingAircraftManagement = true
                }
                
                // Flight Logging
                MoreGridCard(title: "Auto Time Logging", icon: "clock.arrow.2.circlepath", color: LogbookTheme.accentOrange) {
                    showingAutoTimeLogging = true
                }
                
                MoreGridCard(title: "Airport Detection", icon: "location.circle.fill", color: .blue) {
                    showingProximitySettings = true
                }
                
                MoreGridCard(title: "Scanner Email", icon: "envelope.fill", color: LogbookTheme.accentOrange) {
                    showingScannerEmailConfig = true
                }
                
                MoreGridCard(title: "Time Away / Per Diem", icon: "dollarsign.circle.fill", color: LogbookTheme.accentGreen) {
                    showingPerDiemSettings = true
                }
                
                MoreGridCard(title: "FAR 117 Settings", icon: "clock.badge.exclamationmark.fill", color: .red) {
                    showingFAR117Settings = true
                }
                
                MoreGridCard(title: "30-Day Rolling", icon: "gauge.with.needle.fill", color: rolling30StatusColor) {
                    showingRolling30Day = true
                }
                
                MoreGridCard(title: "Notifications", icon: "bell.badge.fill", color: .purple) {
                    showingNotificationSettings = true
                }
                
                // Schedule & Ops
                MoreGridCard(title: "NOC Schedule", icon: "calendar.badge.clock", color: LogbookTheme.accentGreen) {
                    showingNOCSettings = true
                }
                
                MoreGridCard(title: "Crew Contacts", icon: "person.3.fill", color: LogbookTheme.accentBlue) {
                    showingCrewContacts = true
                }
                
                // Clocks
                MoreGridCard(title: "World Clock", icon: "clock.fill", color: LogbookTheme.accentBlue) {
                    showingClocksView = true
                }
                
                // Flight Tools
                MoreGridCard(title: "Area Guide", icon: "map.fill", color: .green) {
                    showingAreaGuide = true
                }
                
                MoreGridCard(title: "GPS/RAIM", icon: "location.fill", color: .purple) {
                    showingGPSRAIM = true
                }
                
                MoreGridCard(title: "GPX Testing", icon: "airplane.circle.fill", color: .orange) {
                    showingGPXTesting = true
                }
                
                MoreGridCard(title: "Weather", icon: "cloud.sun.fill", color: .cyan) {
                    showingWeather = true
                }
                
                MoreGridCard(title: "Flight Calculator", icon: "function", color: LogbookTheme.accentOrange) {
                    showingCalculator = true
                }
                
                MoreGridCard(title: "Flight Ops", icon: "airplane.circle.fill", color: .purple) {
                    showingFlightOps = true
                }
                
                // Reports
                MoreGridCard(title: "Flight Legs", icon: "list.bullet.rectangle", color: LogbookTheme.accentGreen) {
                    showingLegs = true
                }
                
                // Data - Consolidated
                MoreGridCard(title: "Electronic Logbook", icon: "book.closed.fill", color: LogbookTheme.accentBlue) {
                    showingElectronicLogbookView = true
                }
                
                MoreGridCard(title: "Backup & Restore", icon: "externaldrive.fill.badge.timemachine", color: LogbookTheme.accentOrange) {
                    showingDataBackup = true
                }
            }
            .padding(24)
        }
    }
    
    private func formatDutyDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    // MARK: - Rolling 30-Day Compliance Helpers
    
    private var currentRolling30Hours: Double {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        var totalMinutes: Int = 0
        
        for trip in store.trips {
            // Use the trip date for all legs in that trip
            let tripDate = calendar.startOfDay(for: trip.date)
            
            if tripDate >= calendar.startOfDay(for: thirtyDaysAgo) &&
               tripDate <= calendar.startOfDay(for: Date()) {
                for leg in trip.legs {
                    totalMinutes += leg.blockMinutes()  // Call as function
                }
            }
        }
        
        return Double(totalMinutes) / 60.0
    }
    
    private var rolling30StatusText: String {
        String(format: "%.0f/100", currentRolling30Hours)
    }
    
    private var rolling30StatusColor: Color {
        if currentRolling30Hours >= 100 { return .red }
        if currentRolling30Hours >= 90 { return .orange }
        if currentRolling30Hours >= 80 { return .yellow }
        return .green
    }
}


// MARK: - More Grid Card Component (iPad)
struct MoreGridCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(LogbookTheme.navyLight)
            .cornerRadius(16)
        }
    }
}

// MARK: - Watch Settings View
struct WatchSettingsView: View {
    @ObservedObject var phoneWatchConnectivity: PhoneWatchConnectivity
    @ObservedObject var locationManager: PilotLocationManager
    
    @Environment(\.dismiss) var dismiss
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedback = true
    @AppStorage("airportDetectionRadius") private var airportRadius: Double = 2.0
    @State private var showingResetAlert = false
    @ObservedObject private var autoTimeSettings = AutoTimeSettings.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection Status").foregroundColor(.white)) {
                    HStack {
                        Image(systemName: phoneWatchConnectivity.isWatchConnected ? "applewatch" : "applewatch.slash")
                            .foregroundColor(phoneWatchConnectivity.isWatchConnected ? .green : .red)
                            .font(.title2)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Watch")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(phoneWatchConnectivity.isWatchConnected ? "Connected & Syncing" : "Not Connected")
                                .font(.caption)
                                .foregroundColor(phoneWatchConnectivity.isWatchConnected ? .green : .gray)
                        }
                        
                        Spacer()
                        
                        if phoneWatchConnectivity.isWatchConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                Section(header: Text("Actions").foregroundColor(.white)) {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.orange)
                            Text("Reset Connection State")
                                .foregroundColor(.orange)
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Watch Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .alert("Reset Connection State", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    PhoneWatchConnectivity.shared.resetConnectionState()
                }
            } message: {
                Text("This will clear stuck message processing flags and refresh the connection status.")
            }
        }
    }
}

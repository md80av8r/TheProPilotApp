// FlightOperationsView.swift - Flight Operations Display for ProPilot
import SwiftUI

// MARK: - Flight Operations View
struct FlightOperationsView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @StateObject private var autoTimeSettings = AutoTimeSettings.shared
    @StateObject private var opsManager = OPSCallingManager()
    @State private var showingAirlineSetup = false
    @State private var showingAutoTimeSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Airline Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Airline Configuration", icon: "building.2.fill")
                        
                        if !airlineSettings.settings.airlineName.isEmpty {
                            OperationalCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    FlightOpsInfoRow(
                                        icon: "building.2",
                                        label: "Airline",
                                        value: airlineSettings.settings.airlineName,
                                        color: LogbookTheme.accentBlue
                                    )
                                    
                                    if !airlineSettings.settings.homeBaseAirport.isEmpty {
                                        FlightOpsInfoRow(
                                            icon: "location.fill",
                                            label: "Home Base",
                                            value: airlineSettings.settings.homeBaseAirport,
                                            color: LogbookTheme.accentGreen
                                        )
                                    }
                                    
                                    if !opsManager.opsPhoneNumber.isEmpty {
                                        FlightOpsInfoRow(
                                            icon: "phone.fill",
                                            label: "OPS Phone",
                                            value: opsManager.getFormattedOPSNumber(),
                                            color: LogbookTheme.accentOrange
                                        )
                                    }
                                }
                            }
                        } else {
                            EmptyConfigCard(
                                icon: "building.2.fill",
                                title: "No Airline Configured",
                                description: "Set up your airline information",
                                action: { showingAirlineSetup = true }
                            )
                        }
                        
                        Button(action: { showingAirlineSetup = true }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Configure Airline Settings")
                            }
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.accentBlue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Auto Time Logging Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Auto Time Logging", icon: "clock.arrow.circlepath")
                        
                        OperationalCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("GPS Auto-Detection")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Automatically log takeoff and landing times")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { autoTimeSettings.isEnabled },
                                        set: { autoTimeSettings.isEnabled = $0 }
                                    ))
                                    .labelsHidden()
                                }
                                
                                if autoTimeSettings.isEnabled {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        FlightOpsInfoRow(
                                            icon: "location.fill",
                                            label: "Takeoff Detection",
                                            value: "80+ knots",
                                            color: .green
                                        )
                                        
                                        FlightOpsInfoRow(
                                            icon: "location.fill",
                                            label: "Landing Detection",
                                            value: "<60 knots",
                                            color: .orange
                                        )
                                        
                                        FlightOpsInfoRow(
                                            icon: "clock.fill",
                                            label: "Time Rounding",
                                            value: autoTimeSettings.roundTimesToFiveMinutes ? "Enabled (5 min)" : "Disabled",
                                            color: LogbookTheme.accentBlue
                                        )
                                    }
                                    
                                    Button(action: { showingAutoTimeSettings = true }) {
                                        HStack {
                                            Image(systemName: "gear")
                                            Text("Advanced Settings")
                                        }
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(LogbookTheme.fieldBackground)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Flight Time Limits Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "FAR 117 Flight Time Limits", icon: "clock.badge.exclamationmark")
                        
                        OperationalCard {
                            VStack(spacing: 12) {
                                FlightOpsLimitRow(
                                    period: "24 Hours (Rolling)",
                                    limit: "8 hours",
                                    icon: "clock.fill",
                                    color: .red
                                )
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                FlightOpsLimitRow(
                                    period: "7 Consecutive Days",
                                    limit: "60 hours",
                                    icon: "calendar.badge.clock",
                                    color: .orange
                                )
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                FlightOpsLimitRow(
                                    period: "28 Consecutive Days",
                                    limit: "190 hours",
                                    icon: "calendar",
                                    color: .blue
                                )
                            }
                        }
                        
                        Text("The app monitors these limits in real-time and displays warnings in the Logbook tab when approaching limits.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal)
                    
                    // Operations Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Operational Features", icon: "list.bullet.clipboard")
                        
                        OperationalCard {
                            VStack(alignment: .leading, spacing: 16) {
                                FeatureRow(
                                    icon: "fuelpump.fill",
                                    title: "Fuel Receipt Scanning",
                                    description: "Scan and email fuel receipts automatically",
                                    color: LogbookTheme.accentGreen
                                )
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                FeatureRow(
                                    icon: "doc.text.fill",
                                    title: "Document Management",
                                    description: "Organize trip documents and logbook pages",
                                    color: LogbookTheme.accentBlue
                                )
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                FeatureRow(
                                    icon: "applewatch",
                                    title: "Apple Watch Integration",
                                    description: "Log times directly from your wrist",
                                    color: .pink
                                )
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                FeatureRow(
                                    icon: "calendar.badge.clock",
                                    title: "Schedule Integration",
                                    description: "Import trips from NOC roster",
                                    color: LogbookTheme.accentOrange
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Time Zone Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Time Settings", icon: "clock.fill")
                        
                        OperationalCard {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Time Zone")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(autoTimeSettings.useZuluTime ? "Zulu (UTC)" : "Local Time")
                                            .font(.subheadline)
                                            .foregroundColor(autoTimeSettings.useZuluTime ? .cyan : .gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "globe")
                                        .font(.title2)
                                        .foregroundColor(autoTimeSettings.useZuluTime ? .cyan : .gray)
                                }
                                
                                Text("All flight times are recorded in \(autoTimeSettings.useZuluTime ? "Zulu (UTC)" : "local") time for consistency")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Flight Operations")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAirlineSetup) {
                AirlineSetupSheet(settings: airlineSettings, opsManager: opsManager)
            }
            .sheet(isPresented: $showingAutoTimeSettings) {
                AutoTimeSettingsSheet()
            }
        }
    }
}

// MARK: - Helper Views
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(LogbookTheme.accentBlue)
                .font(.headline)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct OperationalCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
    }
}

struct FlightOpsInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
}

struct EmptyConfigCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Tap to Configure")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LogbookTheme.accentBlue.opacity(0.2))
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
}

struct FlightOpsLimitRow: View {
    let period: String
    let limit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(period)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Maximum flight time limit")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(limit)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Airline Setup Sheet
struct AirlineSetupSheet: View {
    @ObservedObject var settings: AirlineSettingsStore
    @ObservedObject var opsManager: OPSCallingManager
    @Environment(\.dismiss) private var dismiss
    @State private var airlineName: String = ""
    @State private var homeBaseAirport: String = ""
    @State private var opsPhoneNumber: String = ""
    @State private var showingAirlinePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Airline Information") {
                    HStack {
                        TextField("Airline Name", text: $airlineName)
                        Button(action: { showingAirlinePicker = true }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                    TextField("Home Base (ICAO)", text: $homeBaseAirport)
                        .textInputAutocapitalization(.characters)
                }
                
                Section {
                    TextField("OPS Phone Number", text: $opsPhoneNumber)
                        .keyboardType(.phonePad)
                    
                    if let defaultNumber = opsManager.getDefaultPhoneNumber(for: airlineName),
                       opsPhoneNumber != defaultNumber {
                        Button("Use Default: \(formatPhoneNumber(defaultNumber))") {
                            opsPhoneNumber = defaultNumber
                        }
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                } header: {
                    Text("Operations Contact")
                } footer: {
                    Text("Enter the phone number for your airline's operations center")
                        .font(.caption)
                }
                
                Section {
                    Toggle("Auto-Call OPS", isOn: $opsManager.autoCallEnabled)
                } header: {
                    Text("Automatic Calling")
                } footer: {
                    Text("Automatically call OPS when arriving at home base")
                        .font(.caption)
                }
            }
            .navigationTitle("Airline Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settings.settings.airlineName = airlineName
                        settings.settings.homeBaseAirport = homeBaseAirport
                        settings.saveSettings()
                        
                        opsManager.setupOPSNumber(for: airlineName, customNumber: opsPhoneNumber)
                        
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                airlineName = settings.settings.airlineName
                homeBaseAirport = settings.settings.homeBaseAirport
                opsPhoneNumber = opsManager.opsPhoneNumber
            }
            .sheet(isPresented: $showingAirlinePicker) {
                AirlinePickerSheet(selectedAirline: $airlineName, opsManager: opsManager, opsPhoneNumber: $opsPhoneNumber)
            }
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleaned.count == 10 {
            let area = String(cleaned.prefix(3))
            let middle = String(cleaned.dropFirst(3).prefix(3))
            let last = String(cleaned.suffix(4))
            return "(\(area)) \(middle)-\(last)"
        }
        
        return number
    }
}

// MARK: - Airline Picker Sheet
struct AirlinePickerSheet: View {
    @Binding var selectedAirline: String
    @ObservedObject var opsManager: OPSCallingManager
    @Binding var opsPhoneNumber: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(opsManager.getAvailableAirlines(), id: \.self) { airline in
                    Button(action: {
                        selectedAirline = airline
                        if let defaultNumber = opsManager.getDefaultPhoneNumber(for: airline) {
                            opsPhoneNumber = defaultNumber
                        }
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(airline)
                                    .foregroundColor(.white)
                                if let phone = opsManager.getDefaultPhoneNumber(for: airline) {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            if selectedAirline == airline {
                                Image(systemName: "checkmark")
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                    }
                }
                
                Section {
                    Text("Select an airline to use its default OPS number, or enter a custom number")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Select Airline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Auto Time Settings Sheet
struct AutoTimeSettingsSheet: View {
    @StateObject private var settings = AutoTimeSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("GPS Detection") {
                    Toggle("Enable Auto Time Logging", isOn: $settings.isEnabled)
                    
                    if settings.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Takeoff Speed: 80+ knots")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Landing Speed: <60 knots")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section("Time Zone") {
                    Toggle("Use Zulu (UTC) Time", isOn: $settings.useZuluTime)
                    
                    Text(settings.useZuluTime ? "All times recorded in UTC" : "Times recorded in local time")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Auto Time Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Typealias for backwards compatibility
typealias FlightOpsView = FlightOperationsView

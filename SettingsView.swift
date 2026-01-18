import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var nocSettings: NOCSettingsStore
    @Binding var sheetToOpen: String?  // NEW: External control for which sheet to open
    @State private var showingHomeBaseConfig = false
    @State private var showingAirlineSetup = false
    @State private var showingScannerEmailSettings = false
    @State private var showingAutoTimeSettings = false
    @State private var showingProximitySettings = false
    @State private var showingTripCountingSettings = false
    @State private var showingMileageSettings = false
    @State private var roundTimesToFiveMinutes = UserDefaults.appGroup?.roundTimesToFiveMinutes ?? false
    @ObservedObject private var autoTimeSettings = AutoTimeSettings.shared
    @StateObject private var speedMonitor = GPSSpeedMonitor()


    var body: some View {
        NavigationView {
            List {
                // MARK: - NOC SECTION REMOVED
                // All NOC settings now accessed via More tab → NOC Schedule Import
                
                // MARK: - Watch Connectivity Section
                #if os(iOS)
                Section(header: Text("Apple Watch").foregroundColor(.white)) {
                    NavigationLink(destination: WatchConnectivityStatusView()) {
                        HStack {
                            Image(systemName: "applewatch.watchface")
                                .foregroundColor(LogbookTheme.accentBlue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch Connection")
                                    .font(.headline)
                                Text("Manage Watch sync and features")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)
                #endif
                
                // MARK: - Scanner Email Settings Section
                Section(header: Text("Scanner Email Settings").foregroundColor(.white)) {
                    // Scanner Email Configuration Row
                    HStack {
                        Image(systemName: "doc.viewfinder")
                            .foregroundColor(LogbookTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Destinations")
                                .font(.headline)
                            if airlineSettings.settings.hasValidScannerEmails {
                                Text("\(airlineSettings.settings.configuredEmailCount) destination\(airlineSettings.settings.configuredEmailCount == 1 ? "" : "s") configured")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            } else {
                                Text("Configure email destinations")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingScannerEmailSettings = true
                    }

                    // Quick Email Preview (show first configured email)
                    if !airlineSettings.settings.logbookEmail.isEmpty || !airlineSettings.settings.receiptsEmail.isEmpty {
                        VStack(spacing: 8) {
                            if !airlineSettings.settings.logbookEmail.isEmpty {
                                HStack {
                                    Image(systemName: "book.pages")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .frame(width: 20)
                                    Text("Logbook Pages:")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Spacer()
                                    Text(airlineSettings.settings.logbookEmail)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            
                            if !airlineSettings.settings.receiptsEmail.isEmpty {
                                HStack {
                                    Image(systemName: "fuelpump")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .frame(width: 20)
                                    Text("Fuel Receipts:")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Spacer()
                                    Text(airlineSettings.settings.receiptsEmail)
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            
                            if !airlineSettings.settings.generalEmail.isEmpty {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(LogbookTheme.accentOrange)
                                        .frame(width: 20)
                                    Text("General Docs:")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Spacer()
                                    Text(airlineSettings.settings.generalEmail)
                                        .foregroundColor(LogbookTheme.accentOrange)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Auto-send Settings Toggle
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("Auto-send Receipts")
                        Spacer()
                        Toggle("", isOn: $airlineSettings.settings.autoSendReceipts)
                            .labelsHidden()
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Auto Time Logging Section
                Section(header: Text("Auto Time Logging").foregroundColor(.white)) {
                    // Time Rounding Toggle - MOVED HERE AS FIRST ITEM
                    Toggle("Round Times to 5 Minutes", isOn: $roundTimesToFiveMinutes)
                        .onChange(of: roundTimesToFiveMinutes) { _, newValue in
                            // Update UserDefaults on background thread - NO synchronize()
                            DispatchQueue.global(qos: .userInitiated).async {
                                UserDefaults.appGroup?.set(newValue, forKey: "roundTimesToFiveMinutes")
                            }
                        }
                    
                    if roundTimesToFiveMinutes {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("All flight times rounded to nearest 5-minute interval")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "book.closed")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Useful for aircraft logbooks and company reporting")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Example display
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Examples:")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("08:23 →")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("08:25")
                                        .font(.caption2.bold())
                                        .foregroundColor(.blue)
                                }
                                
                                HStack {
                                    Text("14:57 →")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("15:00")
                                        .font(.caption2.bold())
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Rest of the section...
                                    
                                    // GPS Auto Time Configuration Row
                                    HStack {
                                        Image(systemName: "timer.circle")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("GPS Auto Time")
                                                .font(.headline)
                                            Text("Automatically log OFF/ON times based on aircraft speed")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showingAutoTimeSettings = true
                                    }
                                    
                                    // Timezone Toggle Row
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(LogbookTheme.accentBlue)
                                        Text("Use Zulu Time for Auto-Log")
                                            .font(.subheadline)
                                        Spacer()
                                        Toggle("", isOn: $autoTimeSettings.useZuluTime)
                                            .labelsHidden()
                                    }
                                    
                                    // Adjustable Speed Thresholds Info
                                    VStack(spacing: 8) {
                                        HStack {
                                            Image(systemName: "speedometer")
                                                .foregroundColor(LogbookTheme.accentGreen)
                                                .frame(width: 20)
                                            Text("Takeoff Trigger:")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Spacer()
                                            Text("> \(Int(autoTimeSettings.takeoffSpeedThreshold)) kts")
                                                .foregroundColor(LogbookTheme.accentGreen)
                                                .font(.caption)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "speedometer")
                                                .foregroundColor(LogbookTheme.accentOrange)
                                                .frame(width: 20)
                                            Text("Landing Trigger:")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Spacer()
                                            Text("< \(Int(autoTimeSettings.landingSpeedThreshold)) kts")
                                                .foregroundColor(LogbookTheme.accentOrange)
                                                .font(.caption)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "slider.horizontal.3")
                                                .foregroundColor(LogbookTheme.accentBlue)
                                                .frame(width: 20)
                                            Text("Tap above to adjust speed thresholds")
                                                .foregroundColor(LogbookTheme.accentBlue)
                                                .font(.caption2)
                                            Spacer()
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(LogbookTheme.navyLight)
                                .textCase(nil)

                // MARK: - Airport Proximity Section
                Section(header: Text("Airport Proximity").foregroundColor(.white)) {
                    // Proximity Settings Row
                    HStack {
                        Image(systemName: "location.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Proximity Alerts")
                                .font(.headline)
                            Text("Auto-detect airport arrival, duty prompts, OPS calling")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingProximitySettings = true
                    }

                    // Quick status preview
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .frame(width: 20)
                            Text("Geofencing:")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Spacer()
                            Text("Active")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .font(.caption)
                        }

                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 20)
                            Text("Monitored Airports:")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Spacer()
                            Text("20 priority")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Trip Counting Settings Section
                Section(header: Text("Trip Counting").foregroundColor(.white)) {
                    // Trip Counting Settings Row
                    HStack {
                        Image(systemName: "number.circle")
                            .foregroundColor(LogbookTheme.accentOrange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip Counting Method")
                                .font(.headline)
                            Text("Configure how trips are counted for statistics")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingTripCountingSettings = true
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Mileage Settings Section
                Section(header: Text("Mileage Tracking").foregroundColor(.white)) {
                    // Mileage Settings Row
                    HStack {
                        Image(systemName: "road.lanes")
                            .foregroundColor(LogbookTheme.accentOrange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mileage & Pay")
                                .font(.headline)
                            Text("Track distance and calculate mileage pay")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingMileageSettings = true
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Trip Creation Settings Section
                Section(header: Text("Trip Creation").foregroundColor(.white)) {
                    @ObservedObject var tripSettings = TripCreationSettings.shared
                    
                    // Device Selection Picker
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Create Trips From")
                                .font(.headline)
                        }
                        
                        Picker("Trip Creation Device", selection: $tripSettings.preferredTripCreationDevice) {
                            ForEach(TripCreationSettings.TripCreationDevice.allCases, id: \.self) { device in
                                HStack {
                                    Image(systemName: device.icon)
                                    Text(device.displayName)
                                }
                                .tag(device)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: tripSettings.preferredTripCreationDevice) { _, _ in
                            tripSettings.syncToAppGroup()
                        }
                        
                        // Description of selected option
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .font(.caption)
                            Text(tripSettings.preferredTripCreationDevice.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                    
                    // Watch-specific settings (only show if watch creation is enabled)
                    if tripSettings.preferredTripCreationDevice == .watch {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "applewatch.watchface")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                Text("Watch Trip Creation")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("When starting duty from your Apple Watch, trips will be automatically created with basic information. You can add full details later on iPhone.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Requires Apple Watch with ProPilot app installed")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(LogbookTheme.accentGreen.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Home Base & Per Diem Section
                Section(header: Text("Home Base & Per Diem").foregroundColor(.white)) {
                    // Home Base Configuration Row
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home Base Airport")
                                .font(.headline)
                            Text(airlineSettings.settings.homeBaseAirport.isEmpty ? "Not set" : airlineSettings.settings.homeBaseAirport)
                                .font(.caption)
                                .foregroundColor(airlineSettings.settings.homeBaseAirport.isEmpty ? .orange : LogbookTheme.accentBlue)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingHomeBaseConfig = true
                    }

                    // Per Diem Rate
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Per Diem Rate")
                        Spacer()
                        Text("$")
                            .foregroundColor(LogbookTheme.accentBlue)
                        TextField(
                            "2.50",
                            value: $store.perDiemRate,
                            format: .number.precision(.fractionLength(2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("/ hour")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Per Diem Status Preview
                    if let currentPeriod = getCurrentPerDiemPeriod(
                        trips: store.trips,
                        homeBase: airlineSettings.settings.homeBaseAirport
                    ) {
                        HStack {
                            Image(systemName: "airplane.departure")
                                .foregroundColor(LogbookTheme.accentGreen)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currently Away")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                                Text(
                                    "\(formatPerDiemDuration(currentPeriod.minutes)) • $\(String(format: "%.2f", Double(currentPeriod.minutes) / 60.0 * store.perDiemRate))"
                                )
                                .font(.caption)
                                .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    } else {
                        HStack {
                            Image(systemName: "house")
                                .foregroundColor(.gray)
                            Text("At Home Base")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - About Section
                Section(header: Text("About").foregroundColor(.white)) {
                    HStack {
                        Image(systemName: "airplane")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Pilot Logbook")
                        Spacer()
                        Text("v1.0")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .listRowBackground(LogbookTheme.navyLight)

                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("GPS Tracking")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(LogbookTheme.accentGreen)
                            .font(.caption)
                    }
                    .listRowBackground(LogbookTheme.navyLight)

                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Device")
                        Spacer()
                        Text(UIDevice.current.model)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .listRowBackground(LogbookTheme.navyLight)

                    if !airlineSettings.settings.airlineName.isEmpty {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Configured For")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(airlineSettings.settings.airlineName)
                                    .foregroundColor(.white)
                                    .font(.caption.bold())
                                Text(airlineSettings.settings.fleetCallsign)
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                    
                    // ✅ NEW: Subscription Debug (only in DEBUG builds)
                    #if DEBUG
                    NavigationLink(destination: SubscriptionDebugView()) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.orange)
                            Text("Subscription Debug")
                            Spacer()
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    #endif
                }
                .textCase(nil)

                // MARK: - Data Summary Section
                Section(header: Text("Data Summary").foregroundColor(.white)) {
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Total Trips")
                        Spacer()
                        Text("\(store.trips.count)")
                            .foregroundColor(LogbookTheme.accentBlue)
                            .font(.caption.bold())
                    }
                    .listRowBackground(LogbookTheme.navyLight)

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("Total Flight Time")
                        Spacer()
                        Text(formatDuration(store.trips.totalBlockMinutes()))
                            .foregroundColor(LogbookTheme.accentGreen)
                            .font(.caption.bold())
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                .textCase(nil)

                // Show warning if configuration incomplete
                if !airlineSettings.settings.isValidConfiguration || !airlineSettings.settings.hasValidScannerEmails {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Setup Required")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                if !airlineSettings.settings.isValidConfiguration {
                                    Text("Complete your airline configuration for full functionality")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                if !airlineSettings.settings.hasValidScannerEmails {
                                    Text("Configure scanner email destinations for document sending")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.orange.opacity(0.1))
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("More")
            .toolbarRole(.editor)
                        .onAppear {
                            // Load the current value from UserDefaults when view appears
                            roundTimesToFiveMinutes = UserDefaults.appGroup?.roundTimesToFiveMinutes ?? false
                        }
                        .sheet(isPresented: $showingHomeBaseConfig) {
                            HomeBaseConfigurationView(airlineSettings: airlineSettings)
                        }
                        .sheet(isPresented: $showingAirlineSetup) {
                            AirlineQuickSetupView(airlineSettings: airlineSettings)
                        }
                        .sheet(isPresented: $showingScannerEmailSettings) {
                            ScannerEmailSettingsView(airlineSettings: airlineSettings)
                        }
                        .sheet(isPresented: $showingAutoTimeSettings) {
                            AutoTimeSettingsView(autoTimeSettings: autoTimeSettings, speedMonitor: speedMonitor)
                        }
                        .sheet(isPresented: $showingProximitySettings) {
                            ProximitySettingsView()
                        }
                        .sheet(isPresented: $showingTripCountingSettings) {
                            TripCountingSettingsView()
                        }
                        .sheet(isPresented: $showingMileageSettings) {
                            MileageSettingsView()
                        }
                        .onChange(of: sheetToOpen) { newValue in
                            // Handle external sheet opening requests from Smart Search
                            guard let sheetId = newValue else { return }

                            switch sheetId {
                            case "proximity":
                                showingProximitySettings = true
                            case "airlineSetup":
                                showingAirlineSetup = true
                            case "tripCounting":
                                showingTripCountingSettings = true
                            case "mileage":
                                showingMileageSettings = true
                            case "homeBase":
                                showingHomeBaseConfig = true
                            case "scannerEmail":
                                showingScannerEmailSettings = true
                            case "autoTime":
                                showingAutoTimeSettings = true
                            default:
                                print("⚠️ Unknown settings sheet: \(sheetId)")
                            }

                            // Clear the trigger
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                sheetToOpen = nil
                            }
                        }
        }
    }
}

// MARK: - Scanner Email Settings View (Keep existing)
struct ScannerEmailSettingsView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore  // ✅ Correct!
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempLogbookEmail: String = ""
    @State private var tempReceiptsEmail: String = ""
    @State private var tempMaintenanceEmail: String = ""
    @State private var tempGeneralEmail: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Document Email Destinations").foregroundColor(.white)) {
                    Text("Configure where scanned documents are automatically sent. The first email entered will auto-populate other fields.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .listRowBackground(LogbookTheme.navyLight)
                }
                .textCase(nil)
                
                Section(header: Text("Email Addresses").foregroundColor(.white)) {
                    // Logbook Pages Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.pages")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 24)
                            Text("Logbook Pages")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("pilot@airline.com", text: $tempLogbookEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: tempLogbookEmail) { _, newValue in
                                if isValidEmail(newValue) && isFirstEmailEntered {
                                    autoPopulateEmptyFields(with: newValue)
                                }
                            }
                        
                        Text("Scanned logbook pages will be sent here")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Fuel Receipts Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "fuelpump")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .frame(width: 24)
                            Text("Fuel Receipts")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("receipts@airline.com", text: $tempReceiptsEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: tempReceiptsEmail) { _, newValue in
                                if isValidEmail(newValue) && isFirstEmailEntered {
                                    autoPopulateEmptyFields(with: newValue)
                                }
                            }
                        
                        Text("Fuel receipt photos will be sent here")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Maintenance Logs Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(LogbookTheme.accentOrange)
                                .frame(width: 24)
                            Text("Maintenance Logs")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("maintenance@airline.com", text: $tempMaintenanceEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: tempMaintenanceEmail) { _, newValue in
                                if isValidEmail(newValue) && isFirstEmailEntered {
                                    autoPopulateEmptyFields(with: newValue)
                                }
                            }
                        
                        Text("Maintenance documentation will be sent here")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // General Documents Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(LogbookTheme.textSecondary)
                                .frame(width: 24)
                            Text("General Documents")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("general@airline.com", text: $tempGeneralEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: tempGeneralEmail) { _, newValue in
                                if isValidEmail(newValue) && isFirstEmailEntered {
                                    autoPopulateEmptyFields(with: newValue)
                                }
                            }
                        
                        Text("Other scanned documents will be sent here")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                .textCase(nil)
                
                Section(header: Text("Auto-Population").foregroundColor(.white)) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(LogbookTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Auto-Fill")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("The first valid email you enter will auto-populate empty fields. You can customize each field afterward.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                .textCase(nil)
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Scanner Emails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEmailSettings()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Helper Methods
    private var isFirstEmailEntered: Bool {
        [tempLogbookEmail, tempReceiptsEmail, tempMaintenanceEmail, tempGeneralEmail]
            .filter { isValidEmail($0) }.count <= 1
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil && !email.isEmpty
    }
    
    private func autoPopulateEmptyFields(with email: String) {
        if tempLogbookEmail.isEmpty {
            tempLogbookEmail = email
        }
        if tempReceiptsEmail.isEmpty {
            tempReceiptsEmail = email
        }
        if tempMaintenanceEmail.isEmpty {
            tempMaintenanceEmail = email
        }
        if tempGeneralEmail.isEmpty {
            tempGeneralEmail = email
        }
    }
    
    private func loadCurrentSettings() {
        tempLogbookEmail = airlineSettings.settings.logbookEmail
        tempReceiptsEmail = airlineSettings.settings.receiptsEmail
        tempMaintenanceEmail = airlineSettings.settings.maintenanceEmail  // ✅ Correct!
        tempGeneralEmail = airlineSettings.settings.generalEmail
    }
    
    private func saveEmailSettings() {
        airlineSettings.settings.logbookEmail = tempLogbookEmail
        airlineSettings.settings.receiptsEmail = tempReceiptsEmail
        airlineSettings.settings.maintenanceEmail = tempMaintenanceEmail  // ✅ ADD THIS!
        airlineSettings.settings.generalEmail = tempGeneralEmail
        airlineSettings.saveSettings()
    }
}



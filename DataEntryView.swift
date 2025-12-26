// Updated DataEntryView.swift - Complete with Flight Number Support
import SwiftUI

// Time picker configuration for overlay presentation
struct TimeEntryPickerConfig {
    let label: String
    let initialTime: Date
    let onSet: (String) -> Void
    let onClear: (() -> Void)?
    
    init(label: String, initialTime: Date, onSet: @escaping (String) -> Void, onClear: (() -> Void)? = nil) {
        self.label = label
        self.initialTime = initialTime
        self.onSet = onSet
        self.onClear = onClear
    }
}

struct DataEntryView: View {
    @Binding var tripNumber: String
    @Binding var aircraft: String
    @Binding var date: Date
    @Binding var tatStart: String
    @Binding var crew: [CrewMember]
    @Binding var notes: String
    @Binding var legs: [FlightLeg]
    @Binding var tripType: TripType
    @Binding var deadheadAirline: String
    @Binding var deadheadFlightNumber: String
    @Binding var pilotRole: PilotRole
    @Binding var shouldAutoStartDuty: Bool
    @Binding var simTotalMinutes: Int  // For simulator trips
    var isEditing: Bool = false
    var onSave: (() -> Void)?
    var onEdit: (() -> Void)?
    var onScanLogPage: (() -> Void)?
    var onAddLeg: (() -> Void)?

    @FocusState private var focusedField: Field?
    @AppStorage("savedAircraft") private var savedAircraftData: Data = Data()
    @State private var isLandscape = false
    // Added for Contact Import
    @StateObject private var crewContactManager = CrewContactManager()
    
    // State for overlay-based time picker
    @State private var activeTimePickerConfig: TimeEntryPickerConfig? = nil
    
    // Track Last synced values to avoid loops
    @State private var lastArrivalSync: [Int: String] = [:]
    
    // Smart toggle state management
    @EnvironmentObject var activityManager: PilotActivityManager
    @State private var sharedDutyStartTime: Date? = nil
    
    // Delete confirmation state
    @State private var showingDeleteConfirmation = false
    @State private var legToDelete: Int?
    
    // Night minutes cache for async calculations
    @State private var nightMinutesCache: [UUID: Int] = [:]
    
    // Simulator time state
    @State private var simHours: Int = 2  // Default 2 hours
    @State private var simMinutes: Int = 0
    
    // Top 6 airlines for deadhead selection
    private let topAirlines = [
        "American", "Delta", "United", "Southwest", "JetBlue", "Alaska", "Other"
    ]
    
    private var savedAircraft: [String] {
        (try? JSONDecoder().decode([String].self, from: savedAircraftData)) ?? []
    }
    
    // Date formatter for parsing departure strings
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    // Smart logic for auto-start toggle state
    private var isDutyAlreadyActive: Bool {
        return sharedDutyStartTime != nil || activityManager.isActivityActive
    }
    
    private var autoStartToggleTitle: String {
        if isDutyAlreadyActive {
            return "Link this trip to active duty timer"
        } else {
            return "Start duty timer with this trip"
        }
    }
    
    private var autoStartToggleSubtitle: String? {
        if isDutyAlreadyActive {
            return "Duty timer is already running"
        } else if isEditing {
            return "Won't affect existing duty status"
        } else {
            return nil
        }
    }
    
    enum Field: Hashable {
        case tripNumber, aircraft, tatStart, notes
        case deadheadAirline, deadheadFlightNumber
        case crewName(Int)
        case legField(Int, LegField)
    }
    
    enum LegField: Hashable {
        case departure, arrival, outTime, offTime, onTime, inTime, deadheadHours, flightNumber
    }

    var totalFlightMinutes: Int {
        legs.map { $0.calculateFlightMinutes() }.reduce(0, +)
    }

    var totalBlockMinutes: Int {
        legs.map { $0.blockMinutes() }.reduce(0, +)
    }
    
    var totalNightMinutes: Int {
        nightMinutesCache.values.reduce(0, +)
    }
        
    var tatFinal: String {
        guard tatStart.filter(\.isWholeNumber).count >= 3 else { return "" }
        let startMinutes = tatStartMinutes(tatStart)
        let finalMinutes = startMinutes + totalFlightMinutes
        let hours = finalMinutes / 60
        let minutes = finalMinutes % 60
        return "\(hours)+\(String(format: "%02d", minutes))"
    }

    var body: some View {
        ZStack {
            // Main content
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                if isLandscape && !legs.isEmpty {
                    landscapeView
                } else {
                    portraitView
                }
            }
            
            // Time picker overlay
            if let config = activeTimePickerConfig {
                timePickerOverlay(config: config)
            }
        }
        .task {
            await loadNightMinutes()
        }
        .onAppear {
            updateOrientation()
            loadDutyStatus()
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateOrientation()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
        .alert("Delete Leg", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let index = legToDelete {
                    legs.remove(at: index)
                    legToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                legToDelete = nil
            }
        } message: {
            if let index = legToDelete {
                Text("Are you sure you want to delete \(tripType == .deadhead ? "Segment" : "Leg") \(index + 1)? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Watch Sync Helper
    private func syncLegToWatch(legIndex: Int) {
        guard legIndex < legs.count else { return }
        
        // Debounce sync calls to avoid spamming watch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
            print("📱 Synced leg \(legIndex + 1) changes to watch")
        }
    }
    // MARK: - Async Loading
    private func loadNightMinutes() async {
        var cache: [UUID: Int] = [:]
        
        for leg in legs {
            if let departureDate = dateFormatter.date(from: leg.departure) {
                let nightMins = await leg.nightMinutes(flightDate: departureDate)
                cache[leg.id] = nightMins
            }
        }
        
        await MainActor.run {
            nightMinutesCache = cache
        }
    }
    
    // Load current duty status
    private func loadDutyStatus() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app"),
           let _ = sharedDefaults.string(forKey: "dutyTimeRemaining") {
            sharedDutyStartTime = Date()
        }
    }
    
    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        withAnimation(.easeInOut(duration: 0.3)) {
            isLandscape = orientation.isLandscape
        }
    }
    
    private func showDeleteConfirmation(for legIndex: Int) {
        legToDelete = legIndex
        showingDeleteConfirmation = true
    }
    
    // MARK: - Landscape View
    private var landscapeView: some View {
        VStack {
            HorizontalLogView(
                date: date,
                tripNumber: tripNumber,
                legs: legs,
                totalFlight: totalFlightMinutes,
                totalBlock: totalBlockMinutes,
                tatFinal: tatFinal,
                tatStart: tatStart
            )
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
            .padding()
            
            // Action buttons in landscape
            HStack(spacing: 16) {
                if let onScanLogPage = onScanLogPage {
                    Button(action: onScanLogPage) {
                        Label("Scan LogPage", systemImage: "doc.viewfinder")
                            .font(.title3)
                            .padding()
                            .background(LogbookTheme.accentOrange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    saveTrip()
                }) {
                    Label(isEditing ? "Save Changes" : "Save Trip", systemImage: "checkmark.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(LogbookTheme.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding()
        }
    }
    
    // Enhanced portrait view content
    private var portraitView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                tripTypeSection
                if tripType != .simulator {
                    autoStartDutySection
                }
                pilotRoleSection
                tripInformationSection
                if tripType != .simulator {
                    crewSection
                }
                if tripType == .simulator {
                    simulatorTimeSection
                } else {
                    flightLegsSection
                }
                notesSection
                totalsSection
                actionButtonsSection
            }
            .padding([.horizontal, .top], 16)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - View Components
    private var tripTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trip Type")
                .font(.headline)
                .foregroundColor(.white)
            
            Picker("Trip Type", selection: $tripType) {
                ForEach(TripType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(LogbookTheme.accentBlue)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var autoStartDutySection: some View {
        if !isEditing {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: isDutyAlreadyActive ? "link.circle.fill" : "play.circle.fill")
                        .foregroundColor(isDutyAlreadyActive ? .orange : LogbookTheme.accentGreen)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duty Timer")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let subtitle = autoStartToggleSubtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $shouldAutoStartDuty)
                        .scaleEffect(1.1)
                        .disabled(isDutyAlreadyActive && isEditing)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: shouldAutoStartDuty ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(shouldAutoStartDuty ? LogbookTheme.accentGreen : .gray)
                            .font(.system(size: 16))
                        
                        Text(autoStartToggleTitle)
                            .font(.subheadline)
                            .foregroundColor(shouldAutoStartDuty ? .white : .gray)
                    }
                    
                    if shouldAutoStartDuty && !isDutyAlreadyActive {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.caption)
                                Text("Duty timer will start automatically")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.caption)
                                Text("Dynamic Island will show live flight status")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                        .padding(.leading, 24)
                    } else if shouldAutoStartDuty && isDutyAlreadyActive {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Trip will be linked to active duty timer")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(shouldAutoStartDuty ? LogbookTheme.accentGreen.opacity(0.1) : LogbookTheme.navyLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(shouldAutoStartDuty ? LogbookTheme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private var pilotRoleSection: some View {
        if tripType != .deadhead {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Role")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Picker("Pilot Role", selection: $pilotRole) {
                    ForEach(PilotRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accentColor(pilotRole == .captain ? LogbookTheme.accentGreen : LogbookTheme.accentBlue)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
    
    private var tripInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tripType == .deadhead ? "Deadhead Information" : "Trip Information")
                .font(.headline)
                .foregroundColor(.white)
            
            if tripType == .deadhead {
                deadheadFields
            } else {
                regularTripFields
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var deadheadFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Airline")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Airline", selection: $deadheadAirline) {
                        ForEach(topAirlines, id: \.self) { airline in
                            Text(airline).tag(airline)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(height: 40)
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flight Number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("UA1234", text: $deadheadFlightNumber)
                        .textFieldStyle(LogbookTextFieldStyle())
                        .focused($focusedField, equals: .deadheadFlightNumber)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.gray)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .accentColor(LogbookTheme.accentBlue)
                        .environment(\.timeZone, TimeDisplayUtility.getPickerTimeZone())
                }
                Spacer()
            }
        }
    }
    
    private var regularTripFields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip Number")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Trip #", text: $tripNumber)
                        .textFieldStyle(LogbookTextFieldStyle())
                        .focused($focusedField, equals: .tripNumber)
                        .keyboardType(.numberPad)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aircraft")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    EnhancedAircraftTextField(text: $aircraft, savedAircraft: savedAircraft)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if AutoTimeSettings.shared.useZuluTime {
                            Text("(UTC)")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .accentColor(LogbookTheme.accentBlue)
                        .environment(\.timeZone, TimeDisplayUtility.getPickerTimeZone())
                }
                .frame(maxWidth: .infinity, alignment: .leading)  // Left-align date
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TAT Start")
                        .font(.caption)
                        .foregroundColor(.gray)
                    EnhancedTATTextField(text: $tatStart)
                        .focused($focusedField, equals: .tatStart)
                        .frame(width: 120)  // Increased width for better visibility
                }
            }
        }
    }
    
    private var crewSection: some View {
        EnhancedCrewManagementView(crew: $crew)
            .environmentObject(crewContactManager)
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
    }
    
    private var flightLegsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tripType == .deadhead ? "Deadhead Segments" : "Flight Legs")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Time format indicator
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(TimeDisplayUtility.getTimeFormatLabel())
                        .font(.caption)
                    Text(TimeDisplayUtility.getTimeZoneLabel())
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            ForEach(legs.indices, id: \.self) { legIndex in
                legView(for: legIndex)
            }

            // Add Leg Button with auto-populate
            Button(action: { onAddLeg?() ?? addNewLeg() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Add \(tripType == .deadhead ? "Segment" : "Leg")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LogbookTheme.accentGreen)
                .cornerRadius(15)
                .shadow(color: LogbookTheme.accentGreen.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    // MARK: - NEW: Add Leg with Smart Auto-Population
    private func addNewLeg() {
        var newLeg = FlightLeg()
        newLeg.isDeadhead = (tripType == .deadhead)
        
        // Auto-populate flight number from previous leg if it exists
        if let lastLeg = legs.last, !lastLeg.flightNumber.isEmpty {
            newLeg.flightNumber = lastLeg.flightNumber
        }
        
        legs.append(newLeg)
        
        // Smart auto-fill departure airport for new leg
        autoFillDepartureAirport(for: legs.count - 1)
    }

    private func autoFillDepartureAirport(for legIndex: Int) {
        guard legIndex < legs.count else { return }
        
        if legIndex == 0 {
            // First leg: Use current location to find nearest airport (if available)
            findNearestAirportAndFill(for: legIndex)
        } else {
            // Subsequent legs: Use arrival airport from previous leg
            let previousLeg = legs[legIndex - 1]
            if !previousLeg.arrival.isEmpty {
                // Set departure to previous leg's arrival
                legs[legIndex].departure = previousLeg.arrival
                print("Auto-filled departure from previous arrival: \(previousLeg.arrival)")
            } else {
                // Fallback to location-based if previous leg has no arrival
                findNearestAirportAndFill(for: legIndex)
            }
        }
    }

    private func findNearestAirportAndFill(for legIndex: Int) {
        guard legIndex < legs.count else { return }
        
        // For now, just leave empty - you can enhance this later when location services are available
        // TODO: Implement location-based airport detection when locationManager is available
        print("Location-based airport detection not yet implemented")
    }

    private func validateAirportCode(_ code: String, for legIndex: Int) {
        // For now, just log - you can enhance this later when airport database is available
        // TODO: Implement airport validation when airportDatabase is available
        print("Airport code validation: \(code)")
    }

    private func legView(for legIndex: Int) -> some View {
        // Add bounds checking to prevent crashes
        guard legIndex < legs.count else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 8) {
                HStack {
                    Text("\(tripType == .deadhead ? "Segment" : "Leg") \(legIndex + 1)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    // Show continuation indicator for subsequent legs
                    if legIndex > 0 && !legs[legIndex].departure.isEmpty {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    if legs.count > 1 {
                        Button("Delete") {
                            showDeleteConfirmation(for: legIndex)
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
                
                // Flight Number Field
                if tripType != .deadhead {
                    flightNumberField(for: legIndex)
                }
                
                // Route with ICAO auto-complete and smart auto-fill
                routeFields(for: legIndex)
                
                if tripType == .deadhead {
                    deadheadTimeEntry(for: legIndex)
                } else {
                    regularTimeEntry(for: legIndex)
                }
                
                // Enhanced Calculated Times Display
                if legs[legIndex].isValid {
                    calculatedTimesDisplay(for: legIndex)
                }
            }
            .padding()
            .background(tripType == .deadhead ? LogbookTheme.accentOrange.opacity(0.15) : LogbookTheme.fieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tripType == .deadhead ? LogbookTheme.accentOrange.opacity(0.4) : LogbookTheme.fieldBackground, lineWidth: 1)
            )
            .onChange(of: legs[safe: legIndex]?.arrival ?? "") { _, newArrival in
                // When arrival changes, update next leg's departure if it exists
                guard legIndex < legs.count else { return }
                let nextLegIndex = legIndex + 1
                if nextLegIndex < legs.count && !newArrival.isEmpty {
                    legs[nextLegIndex].departure = newArrival
                }
                
                // ✅ Sync to watch when arrival changes
                if lastArrivalSync[legIndex] != newArrival {
                    lastArrivalSync[legIndex] = newArrival
                    syncLegToWatch(legIndex: legIndex)
                }
            }
        )
    }
    
    // MARK: - NEW: Flight Number Field Component
    @ViewBuilder
    private func flightNumberField(for legIndex: Int) -> some View {
        // Add bounds checking to prevent crashes
        if legIndex < legs.count {
            VStack(alignment: .leading, spacing: 4) {
                Text("Flight Number")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                TextField("1234 or UAL1234", text: Binding(
                    get: { 
                        guard legIndex < legs.count else { return "" }
                        return legs[legIndex].flightNumber
                    },
                    set: { newValue in
                        guard legIndex < legs.count else { return }
                        legs[legIndex].flightNumber = newValue.uppercased()
                        
                        // Auto-populate next leg's flight number if it's empty and this field is being committed
                        if legIndex + 1 < legs.count && legs[legIndex + 1].flightNumber.isEmpty && !newValue.isEmpty {
                            legs[legIndex + 1].flightNumber = newValue.uppercased()
                        }
                    }
                ))
                .textFieldStyle(LogbookTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .focused($focusedField, equals: .legField(legIndex, .flightNumber))
                .onSubmit {
                    // Auto-populate next leg's flight number when user hits return
                    guard legIndex < legs.count else { return }
                    if legIndex + 1 < legs.count && legs[legIndex + 1].flightNumber.isEmpty {
                        legs[legIndex + 1].flightNumber = legs[legIndex].flightNumber
                    }
                }
            }
        }
    }
    
    private func routeFields(for legIndex: Int) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FROM")
                    .font(.caption2)
                    .foregroundColor(.gray)
                EnhancedICAOTextField(
                    text: Binding(
                        get: { 
                            guard legIndex < legs.count else { return "" }
                            return legs[legIndex].departure
                        },
                        set: { 
                            guard legIndex < legs.count else { return }
                            legs[legIndex].departure = $0
                        }
                    ),
                    placeholder: "ICAO"
                )
                .onChange(of: legs[safe: legIndex]?.departure ?? "") { _, _ in
                    syncLegToWatch(legIndex: legIndex)
                }
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(LogbookTheme.accentBlue)
                .font(.title2)
                .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TO")
                    .font(.caption2)
                    .foregroundColor(.gray)
                EnhancedICAOTextField(
                    text: Binding(
                        get: { 
                            guard legIndex < legs.count else { return "" }
                            return legs[legIndex].arrival
                        },
                        set: { 
                            guard legIndex < legs.count else { return }
                            legs[legIndex].arrival = $0
                        }
                    ),
                    placeholder: "ICAO"
                )
                // Note: arrival already has onChange handler elsewhere (lines ~695-701)
                // that needs to be updated per Step 2 in the instructions
            }
        }
    }
    
    private func deadheadTimeEntry(for legIndex: Int) -> some View {
        guard legIndex < legs.count else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 12) {
                // OUT/IN Times Row (Preferred method)
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUT/IN Times (Preferred)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        TimeEntryField(
                            label: "OUT",
                            icon: "arrow.up.circle.fill",
                            color: .blue,
                            timeString: Binding(
                                get: { legs[safe: legIndex]?.deadheadOutTime ?? "" },
                                set: { 
                                    guard legIndex < legs.count else { return }
                                    legs[legIndex].deadheadOutTime = $0
                                }
                            ),
                            activePickerConfig: $activeTimePickerConfig
                        )
                        .onChange(of: legs[safe: legIndex]?.deadheadOutTime ?? "") { oldValue, newValue in
                            print("🔵 DataEntry: Deadhead OUT changed from '\(oldValue)' to '\(newValue)'")
                            // Clear manual hours if using OUT/IN times
                            guard legIndex < legs.count else { return }
                            if !legs[legIndex].deadheadOutTime.isEmpty && !legs[legIndex].deadheadInTime.isEmpty {
                                legs[legIndex].deadheadFlightHours = 0.0
                            }
                        }
                        
                        TimeEntryField(
                            label: "IN",
                            icon: "arrow.down.circle.fill",
                            color: .blue,
                            timeString: Binding(
                                get: { legs[safe: legIndex]?.deadheadInTime ?? "" },
                                set: { 
                                    guard legIndex < legs.count else { return }
                                    legs[legIndex].deadheadInTime = $0
                                }
                            ),
                            activePickerConfig: $activeTimePickerConfig
                        )
                        .onChange(of: legs[safe: legIndex]?.deadheadInTime ?? "") { oldValue, newValue in
                            print("🔵 DataEntry: Deadhead IN changed from '\(oldValue)' to '\(newValue)'")
                            // Clear manual hours if using OUT/IN times
                            guard legIndex < legs.count else { return }
                            if !legs[legIndex].deadheadOutTime.isEmpty && !legs[legIndex].deadheadInTime.isEmpty {
                                legs[legIndex].deadheadFlightHours = 0.0
                            }
                        }
                    }
                }
                
                // Divider with OR
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    
                    Text("OR")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                
                // Total Hours Row (Backup method)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Hours")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    TextField("2.5", value: Binding(
                        get: { legs[safe: legIndex]?.deadheadFlightHours ?? 0.0 },
                        set: { 
                            guard legIndex < legs.count else { return }
                            legs[legIndex].deadheadFlightHours = $0
                        }
                    ), format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(LogbookTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                        .onChange(of: legs[safe: legIndex]?.deadheadFlightHours ?? 0.0) { oldValue, newValue in
                            // Clear OUT/IN times if using manual hours
                            guard legIndex < legs.count, newValue > 0 else { return }
                            legs[legIndex].deadheadOutTime = ""
                            legs[legIndex].deadheadInTime = ""
                        }
                }
                
                // Show calculated block time if OUT/IN times are entered
                if let leg = legs[safe: legIndex], !leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty {
                    let blockMins = leg.blockMinutes()
                    if blockMins > 0 {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("Block Time: \(blockMins.asLogbookTotal)")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentGreen)
                            Spacer()
                        }
                    }
                }
            }
        )
    }
    
    private func regularTimeEntry(for legIndex: Int) -> some View {
        guard legIndex < legs.count else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TimeEntryField(
                        label: "OUT",
                        icon: "arrow.up.circle.fill",
                        color: .blue,
                        timeString: Binding(
                            get: { legs[safe: legIndex]?.outTime ?? "" },
                            set: { 
                                guard legIndex < legs.count else { return }
                                legs[legIndex].outTime = $0
                            }
                        ),
                        activePickerConfig: $activeTimePickerConfig
                    )
                    
                    TimeEntryField(
                        label: "OFF",
                        icon: "airplane.departure",
                        color: .green,
                        timeString: Binding(
                            get: { legs[safe: legIndex]?.offTime ?? "" },
                            set: { 
                                guard legIndex < legs.count else { return }
                                legs[legIndex].offTime = $0
                            }
                        ),
                        activePickerConfig: $activeTimePickerConfig
                    )
                }

                HStack(spacing: 12) {
                    TimeEntryField(
                        label: "ON",
                        icon: "airplane.arrival",
                        color: .orange,
                        timeString: Binding(
                            get: { legs[safe: legIndex]?.onTime ?? "" },
                            set: { 
                                guard legIndex < legs.count else { return }
                                legs[legIndex].onTime = $0
                            }
                        ),
                        activePickerConfig: $activeTimePickerConfig
                    )
                    
                    TimeEntryField(
                        label: "IN",
                        icon: "arrow.down.circle.fill",
                        color: .blue,
                        timeString: Binding(
                            get: { legs[safe: legIndex]?.inTime ?? "" },
                            set: { 
                                guard legIndex < legs.count else { return }
                                legs[legIndex].inTime = $0
                            }
                        ),
                        activePickerConfig: $activeTimePickerConfig
                    )
                }
            }
        )
    }
    
    private func calculatedTimesDisplay(for legIndex: Int) -> some View {
        guard legIndex < legs.count else {
            return AnyView(EmptyView())
        }
        
        let leg = legs[legIndex]
        
        return AnyView(
            VStack(spacing: 6) {
                // Primary times (Flight and Block)
                HStack {
                    if tripType != .deadhead {
                        Text("Flight: \(leg.formattedFlightTime)")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    Spacer()
                    Text("Block: \(leg.formattedBlockTime)")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                
                // Night hours display (if any)
                if let nightMins = nightMinutesCache[leg.id], nightMins > 0 {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.stars.fill")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Night: \(String(format: "%.1f", Double(nightMins) / 60.0))")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                        Spacer()
                        Text("(\(formatLogbookTotal(minutes: nightMins)))")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentOrange.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LogbookTheme.accentOrange.opacity(0.1))
                    )
                }
            }
        )
    }
    
    // MARK: - Simulator Time Section
    private var simulatorTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulator Time")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Hours", selection: $simHours) {
                        ForEach(0..<24) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80, height: 120)
                    .clipped()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .onChange(of: simHours) { _, _ in
                        updateSimTotalMinutes()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Minutes", selection: $simMinutes) {
                        ForEach(0..<60) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80, height: 120)
                    .clipped()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .onChange(of: simMinutes) { _, _ in
                        updateSimTotalMinutes()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(simHours):\(String(format: "%02d", simMinutes))")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
            .padding(.vertical, 8)
            
            Text("Standard sim session is 2 hours")
                .font(.caption)
                .foregroundColor(.gray)
                .italic()
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .onAppear {
            // Initialize from binding
            simHours = simTotalMinutes / 60
            simMinutes = simTotalMinutes % 60
        }
    }
    
    private func updateSimTotalMinutes() {
        simTotalMinutes = (simHours * 60) + simMinutes
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Additional notes...", text: $notes, axis: .vertical)
                .textFieldStyle(LogbookTextFieldStyle())
                .focused($focusedField, equals: .notes)
                .lineLimit(3...6)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var totalsSection: some View {
        if tripType == .simulator {
            // Simulator totals
            VStack(alignment: .leading, spacing: 12) {
                Text("Simulator Session")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Sim Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(simHours):\(String(format: "%02d", simMinutes))")
                            .font(.title2.bold())
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Type")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Training")
                            .font(.title3.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        } else if !legs.isEmpty && legs.contains(where: { $0.isValid }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Totals")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    // Row 1: TAT Start (Far Right)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("TAT Start")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(tatStartMinutes(tatStart).asLogbookTotal)
                                .font(.title3.bold())
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    
                    // Row 2: Total Flight (Far Right) - Only for non-deadhead
                    if tripType != .deadhead {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total Flight")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(totalFlightMinutes.asLogbookTotal)
                                    .font(.title3.bold())
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                    }
                    
                    // Row 3: Total Block (Left) and Ending TAT (Right)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Block")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(totalBlockMinutes.asLogbookTotal)
                                .font(.title3.bold())
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Ending TAT")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(tatFinal)
                                .font(.title3.bold())
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Row 4: Night Hours (if any)
                    if totalNightMinutes > 0 {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.title3)
                                    .foregroundColor(LogbookTheme.accentOrange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Night")
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentOrange)
                                    Text(totalNightMinutes.asLogbookTotal)
                                        .font(.title3.bold())
                                        .foregroundColor(LogbookTheme.accentOrange)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Decimal")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentOrange.opacity(0.8))
                                Text(String(format: "%.1f", Double(totalNightMinutes) / 60.0))
                                    .font(.title3.bold())
                                    .foregroundColor(LogbookTheme.accentOrange)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LogbookTheme.accentOrange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LogbookTheme.accentOrange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Scan LogPage button (full width, shorter height)
            if let onScanLogPage = onScanLogPage {
                Button(action: onScanLogPage) {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                        Text("Scan LogPage")
                    }
                    .font(.subheadline.bold())
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.accentOrange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Save Button (full width)
            Button(action: saveTrip) {
                Label(isEditing ? "Save Changes" : "Save \(tripType.rawValue)",
                      systemImage: isEditing ? "square.and.arrow.down" : "tray.and.arrow.down.fill")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(tripType == .deadhead ? LogbookTheme.accentOrange : LogbookTheme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Save Trip Function
    private func saveTrip() {
        // Set deadhead flag on legs
        for index in legs.indices {
            legs[index].isDeadhead = (tripType == .deadhead)
        }
        
        if isEditing {
            onEdit?()
        } else {
            onSave?()
        }
    }
    
    // MARK: - Helper Functions
    private func formatLogbookTotal(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    // MARK: - Time Picker Overlay
    private func timePickerOverlay(config: TimeEntryPickerConfig) -> some View {
        ZStack {
            // More transparent background (reduced from 0.4 to 0.2)
            Color.black.opacity(0.05)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        activeTimePickerConfig = nil
                    }
                }
                .transition(.opacity)
            
            // Time picker at the bottom
            VStack(spacing: 0) {
                Spacer()
                
                TranslucentTimePicker(
                    timeType: config.label,
                    initialTime: config.initialTime,
                    useZuluTime: AutoTimeSettings.shared.useZuluTime,
                    onTimeSet: { time in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HHmm"
                        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
                        let timeString = formatter.string(from: time)
                        config.onSet(timeString)
                        
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    },
                    onClear: {
                        // Clear the time field by setting empty string
                        config.onSet("")
                        
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)  // Reduced padding to move closer to bottom
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Enhanced Aircraft Text Field
struct EnhancedAircraftTextField: View {
    @Binding var text: String
    let savedAircraft: [String]
    @FocusState private var isFocused: Bool
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var matchedAircraft: Aircraft? = nil
    @AppStorage("frequent_aircraft_registrations") private var frequentAircraftData: Data = Data()
    
    // Access the shared Aircraft Database
    private var aircraftDatabase: UnifiedAircraftDatabase {
        UnifiedAircraftDatabase.shared
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("N12345", text: $text)
                .textFieldStyle(LogbookTextFieldStyle())
                .focused($isFocused)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .onChange(of: text) { oldValue, newValue in
                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                    updateSuggestions()
                    checkAircraftLibrary(filtered)
                }
                .onChange(of: isFocused) { _, focused in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if focused {
                            updateSuggestions()
                        } else {
                            showingSuggestions = false
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                saveFrequentAircraft(text)
                            }
                        }
                    }
                }
            
            // Show matched aircraft info from library
            if let aircraft = matchedAircraft {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                        .font(.caption)
                    Text("\(aircraft.manufacturer) \(aircraft.model)")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(aircraft.typeCode)
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                    if aircraft.isComplex || aircraft.isHighPerformance {
                        Text("•")
                            .foregroundColor(.gray)
                        if aircraft.isHighPerformance {
                            Text("HP")
                                .font(.caption2.bold())
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Suggestions dropdown
            if showingSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            text = suggestion
                            showingSuggestions = false
                            isFocused = false
                            saveFrequentAircraft(suggestion)
                            checkAircraftLibrary(suggestion)
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                // Show type from database if available
                                if let dbAircraft = aircraftDatabase.findAircraft(byTailNumber: suggestion) {
                                    Text(dbAircraft.typeCode)
                                        .font(.caption2.bold())
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(LogbookTheme.accentGreen.opacity(0.2)))
                                } else {
                                    Text(aircraftType(for: suggestion))
                                        .font(.caption2)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(LogbookTheme.accentBlue.opacity(0.2)))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.fieldBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if suggestion != suggestions.prefix(5).last {
                            Divider().background(Color.gray.opacity(0.3))
                        }
                    }
                }
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1))
            }
        }
        .onAppear {
            loadFrequentAircraft()
            checkAircraftLibrary(text)
        }
        .animation(.easeInOut(duration: 0.2), value: matchedAircraft?.id)
    }
    
    private func checkAircraftLibrary(_ registration: String) {
        let trimmed = registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.count >= 3 {
            matchedAircraft = aircraftDatabase.findAircraft(byTailNumber: trimmed)
        } else {
            matchedAircraft = nil
        }
    }
    
    private func updateSuggestions() {
        let frequentAircraft = getFrequentAircraft()
        
        if text.isEmpty {
            suggestions = Array(frequentAircraft.prefix(5))
            showingSuggestions = !suggestions.isEmpty
        } else {
            suggestions = frequentAircraft.filter { aircraft in
                aircraft.hasPrefix(text.uppercased()) && aircraft != text.uppercased()
            }
            showingSuggestions = !suggestions.isEmpty
        }
    }
    
    private func saveFrequentAircraft(_ registration: String) {
        guard !registration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let formattedRegistration = registration.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var aircraft = getFrequentAircraft()
        
        // Remove if already exists (to move to front)
        aircraft.removeAll { $0.uppercased() == formattedRegistration }
        
        // Add to front
        aircraft.insert(formattedRegistration, at: 0)
        
        // Keep only last 25 aircraft
        if aircraft.count > 25 {
            aircraft = Array(aircraft.prefix(25))
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(aircraft) {
            frequentAircraftData = encoded
        }
    }
    
    private func getFrequentAircraft() -> [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: frequentAircraftData) {
            return decoded
        }
        return []
    }
    
    private func loadFrequentAircraft() {
        // Initialize with empty array if no saved aircraft exist
        if frequentAircraftData.isEmpty {
            frequentAircraftData = Data()
        }
    }
    
    private func aircraftType(for registration: String) -> String {
        // Default aircraft type indicator
        if registration.hasPrefix("N") {
            return "US"
        } else if registration.hasPrefix("C") {
            return "CA"
        } else {
            return "INT"
        }
    }
}

// MARK: - Enhanced TAT Text Field
struct EnhancedTATTextField: View {
    @Binding var text: String
    @State private var displayText: String = ""
    
    var body: some View {
        TextField("0800", text: $displayText)
            .textFieldStyle(LogbookTextFieldStyle())
            .keyboardType(.numberPad)
            .onAppear {
                displayText = formatTATDisplay(text)
            }
            .onChange(of: displayText) { oldValue, newValue in
                let digitsOnly = newValue.filter(\.isWholeNumber)
                text = digitsOnly
                displayText = formatTATDisplay(digitsOnly)
            }
            .onChange(of: text) { oldValue, newValue in
                if displayText != formatTATDisplay(newValue) {
                    displayText = formatTATDisplay(newValue)
                }
            }
    }
    
    private func formatTATDisplay(_ input: String) -> String {
        let digits = input.filter(\.isWholeNumber)
        
        guard digits.count >= 3 else {
            return digits  // Show "0", "79" as-is
        }
        
        // Last 2 digits are ALWAYS minutes, everything before is hours
        let hours = String(digits.dropLast(2))
        let minutes = String(digits.suffix(2))
        
        return "\(hours)+\(minutes)"
    }
}

// TimeEntryField_Fixed.swift - Extract of the fixed TimeEntryField from DataEntryView
// This replaces lines 1323-1448 in DataEntryView.swift

// MARK: - Time Entry Field Component - TAP TO FILL, LONG PRESS TO PICK
struct TimeEntryField: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var timeString: String
    @Binding var activePickerConfig: TimeEntryPickerConfig?
    
    @State private var displayText: String = ""
    @State private var justTapped = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Time display with tap and long press gestures
            HStack {
                Text(displayText.isEmpty ? "----" : displayText)
                    .foregroundColor(displayText.isEmpty ? .gray : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if justTapped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(LogbookTheme.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                justTapped ? LogbookTheme.accentGreen : Color.clear,
                                lineWidth: justTapped ? 2 : 0
                            )
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                handleLongPress()
            }
        }
        .onAppear {
            displayText = formatTimeDisplay(timeString)
        }
        .onChange(of: timeString) { _, newValue in
            let formatted = formatTimeDisplay(newValue)
            if displayText != formatted {
                displayText = formatted
            }
        }
    }
    
    // MARK: - Tap Handler (Fill Current Time)
    private func handleTap() {
        let currentTime = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        
        timeString = formatter.string(from: currentTime)
        displayText = formatTimeDisplay(timeString)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            justTapped = true
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                justTapped = false
            }
        }
    }
    
    // MARK: - Long Press Handler (Show Picker)
    private func handleLongPress() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        let initialTime: Date
        if let existingTime = parseTimeStringToDate(timeString) {
            initialTime = existingTime
        } else {
            initialTime = Date()
        }
        
        withAnimation(.spring()) {
            activePickerConfig = TimeEntryPickerConfig(
                label: label,
                initialTime: initialTime,
                onSet: { newTimeString in
                    timeString = newTimeString
                    displayText = formatTimeDisplay(newTimeString)
                },
                onClear: {
                    timeString = ""
                    displayText = ""
                }
            )
        }
    }
    
    private func parseTimeStringToDate(_ input: String) -> Date? {
        let digits = input.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        guard let hour = Int(padded.prefix(2)),
              let minute = Int(padded.suffix(2)),
              hour < 24, minute < 60 else { return nil }
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        return Calendar.current.date(from: components)
    }
    
    private func formatTimeDisplay(_ input: String) -> String {
        let digits = input.filter(\.isWholeNumber)
        
        guard digits.count >= 3 else {
            return digits
        }
        
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        let hours = padded.prefix(2)
        let minutes = padded.suffix(2)
        
        return "\(hours):\(minutes)"
    }
}
// MARK: - Instructions for Integration
/*
 To fix the modal presentation in DataEntryView:
 
 1. Replace the TimeEntryField struct (lines 1323-1448) with the TimeEntryField above
 2. Add the TimeEntryPickerModal struct after TimeEntryField
 3. Remove any NavigationView wrapper from the sheet presentation
 
 The key changes:
 - Removed NavigationView wrapper in the sheet
 - Created a proper modal with translucent background using ZStack
 - Added .presentationBackground(.clear) for transparency
 - Added .presentationBackgroundInteraction for dismissal on background tap
 - Properly centered the TranslucentTimePicker
 */

// MARK: - LogbookTextFieldStyle
struct LogbookTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(8)
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(6)
            .foregroundColor(.white)
    }
}

// MARK: - Array Safe Subscript Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

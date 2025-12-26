//
//  NOCTestView.swift
//  TheProPilotApp
//
//  NOC Trip Tester - Generates fake roster data for testing
//

import SwiftUI

struct NOCTestView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var testResult: String = "Ready to generate test trip"
    @State private var isGenerating = false
    @State private var generatedTrip: Trip?
    @State private var testMode: TestMode = .directTrip

    // Date/Time Configuration
    @State private var selectedDate = Date()
    @State private var hoursFromNow: Int = 2
    @State private var showDatePicker = false

    // MARK: - Route Configuration
    @State private var showRouteConfig = false
    @State private var legCount: Int = 3
    @State private var selectedRoute: TestRoute = .yipRoundtrip

    // City pairs for each leg (up to 4 legs)
    @State private var leg1Origin = "YIP"
    @State private var leg1Dest = "DTW"
    @State private var leg2Origin = "DTW"
    @State private var leg2Dest = "CLE"
    @State private var leg3Origin = "CLE"
    @State private var leg3Dest = "YIP"
    @State private var leg4Origin = "YIP"
    @State private var leg4Dest = "LRD"

    // MARK: - Aircraft Configuration
    @State private var showAircraftConfig = false
    @State private var tailNumber = "N833US"
    @State private var aircraftType = "M88"
    @State private var flightNumberPrefix = "UJ"
    @State private var baseFlightNumber = 8790

    // Preset routes
    enum TestRoute: String, CaseIterable {
        case yipRoundtrip = "YIP Roundtrip (3 legs)"
        case lrdTurn = "LRD Turn (2 legs)"
        case mexTrip = "Mexico Trip (4 legs)"
        case custom = "Custom Route"

        var description: String {
            switch self {
            case .yipRoundtrip: return "YIP → DTW → CLE → YIP"
            case .lrdTurn: return "YIP → LRD → YIP"
            case .mexTrip: return "YIP → LRD → MEX → LRD → YIP"
            case .custom: return "Configure your own"
            }
        }
    }

    enum TestMode: String, CaseIterable {
        case directTrip = "Direct Trip (Current)"
        case rosterItems = "Roster Items (Real Flow)"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 50))
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Text("NOC Trip Tester")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Generate test roster data")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                    
                    // Test Mode Picker
                    Picker("Test Mode", selection: $testMode) {
                        ForEach(TestMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Mode Description
                    Text(testMode == .directTrip
                         ? "Creates trip directly in LogBook"
                         : "Creates roster items → tests trip generation flow")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Date/Time Configuration Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Schedule Time")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        // Quick time presets
                        VStack(spacing: 12) {
                            Text("Start trip in:")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                ForEach([1, 2, 4, 8, 24], id: \.self) { hours in
                                    Button {
                                        hoursFromNow = hours
                                        selectedDate = Calendar.current.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("\(hours)h")
                                                .font(.caption.bold())
                                            if hours >= 24 {
                                                Text("tomorrow")
                                                    .font(.caption2)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(hoursFromNow == hours ? LogbookTheme.accentBlue : Color.gray.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // Custom date picker toggle
                            Button {
                                showDatePicker.toggle()
                            } label: {
                                HStack {
                                    Image(systemName: showDatePicker ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                    Text("Custom Date/Time")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(formatScheduledTime())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .foregroundColor(.white)
                            }
                            
                            if showDatePicker {
                                DatePicker("Trip Start", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .onChange(of: selectedDate) { _, newDate in
                                        // Calculate hours from now
                                        let hours = Int(newDate.timeIntervalSince(Date()) / 3600)
                                        hoursFromNow = max(1, hours)
                                    }
                            }
                            
                            // Show calculated times
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("First departure:")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(formatTime(selectedDate))
                                        .font(.caption2.monospaced())
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                                HStack {
                                    Text("Last arrival:")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(formatTime(estimatedEndTime()))
                                        .font(.caption2.monospaced())
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: - Route Configuration Card
                    VStack(alignment: .leading, spacing: 16) {
                        Button {
                            withAnimation { showRouteConfig.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                Text("Route Configuration")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showRouteConfig ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                            }
                        }

                        if showRouteConfig {
                            // Preset route picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preset Routes")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Picker("Route", selection: $selectedRoute) {
                                    ForEach(TestRoute.allCases, id: \.self) { route in
                                        Text(route.rawValue).tag(route)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedRoute) { _, newRoute in
                                    applyPresetRoute(newRoute)
                                }

                                Text(selectedRoute.description)
                                    .font(.caption2)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }

                            Divider().background(Color.gray.opacity(0.3))

                            // Leg count stepper
                            HStack {
                                Text("Number of Legs:")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Spacer()
                                Stepper("\(legCount)", value: $legCount, in: 1...4)
                                    .labelsHidden()
                                Text("\(legCount)")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .frame(width: 30)
                            }

                            // City pair inputs
                            VStack(spacing: 12) {
                                cityPairRow(legNumber: 1, origin: $leg1Origin, dest: $leg1Dest)
                                if legCount >= 2 {
                                    cityPairRow(legNumber: 2, origin: $leg2Origin, dest: $leg2Dest)
                                }
                                if legCount >= 3 {
                                    cityPairRow(legNumber: 3, origin: $leg3Origin, dest: $leg3Dest)
                                }
                                if legCount >= 4 {
                                    cityPairRow(legNumber: 4, origin: $leg4Origin, dest: $leg4Dest)
                                }
                            }
                        } else {
                            // Collapsed summary
                            Text(getRouteSummary())
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // MARK: - Aircraft Configuration Card
                    VStack(alignment: .leading, spacing: 16) {
                        Button {
                            withAnimation { showAircraftConfig.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "airplane")
                                    .foregroundColor(LogbookTheme.accentOrange)
                                Text("Aircraft Configuration")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showAircraftConfig ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                            }
                        }

                        if showAircraftConfig {
                            VStack(spacing: 12) {
                                // Tail number
                                HStack {
                                    Text("Tail Number:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    TextField("N-number", text: $tailNumber)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                        .autocapitalization(.allCharacters)
                                }

                                // Aircraft type
                                HStack {
                                    Text("Aircraft Type:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Picker("Type", selection: $aircraftType) {
                                        Text("M88 (MD-88)").tag("M88")
                                        Text("M83 (MD-83)").tag("M83")
                                        Text("M87 (MD-87)").tag("M87")
                                        Text("CRJ (CRJ-200)").tag("CRJ")
                                    }
                                    .pickerStyle(.menu)
                                }

                                Divider().background(Color.gray.opacity(0.3))

                                // Flight number config
                                HStack {
                                    Text("Flight Prefix:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    TextField("UJ", text: $flightNumberPrefix)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .autocapitalization(.allCharacters)
                                }

                                HStack {
                                    Text("Base Flight #:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    TextField("8790", value: $baseFlightNumber, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .keyboardType(.numberPad)
                                }

                                Text("Flight numbers: \(getFlightNumbersPreview())")
                                    .font(.caption2)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        } else {
                            // Collapsed summary
                            Text("\(tailNumber) (\(aircraftType)) • \(flightNumberPrefix)\(baseFlightNumber)")
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Test Trip Info Card (Summary)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Test Trip Summary")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            testDetailRow(label: "Route", value: getRouteSummary())
                            testDetailRow(label: "Legs", value: "\(legCount)")
                            testDetailRow(label: "Aircraft", value: "\(tailNumber) (\(getAircraftFullName()))")
                            testDetailRow(label: "Date", value: formatDate(selectedDate))
                            testDetailRow(label: "Flight Numbers", value: getFlightNumbersPreview())
                            testDetailRow(label: "NOC UID", value: "TEST-\(UUID().uuidString.prefix(8))")
                            testDetailRow(label: "Trip End Marker", value: "RD: X on last leg")
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Generate Button
                    Button(action: generateTestTrip) {
                        HStack(spacing: 12) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: testMode == .directTrip ? "wand.and.stars" : "calendar.badge.plus")
                            }
                            Text(isGenerating ? "Generating..." :
                                 testMode == .directTrip ? "Generate Test Trip" : "Add to Roster")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isGenerating ? Color.gray : LogbookTheme.accentGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isGenerating)
                    .padding(.horizontal)
                    
                    // Result Display
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Generation Log")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        ScrollView {
                            Text(testResult)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // If trip was generated, show quick view
                    if let trip = generatedTrip {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Generated Trip #\(trip.tripNumber)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            ForEach(trip.legs.indices, id: \.self) { index in
                                legPreviewRow(leg: trip.legs[index], number: index + 1)
                            }
                            
                            Button(action: {
                                // Clear test trip
                                if let tripIndex = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                    store.trips.remove(at: tripIndex)
                                    generatedTrip = nil
                                    
                                    // 🔧 FIX: Restore duty status after removing test trip
                                    restoreDutyStatusFromNOC()
                                    
                                    testResult = "✅ Test trip removed\n✅ Duty status restored from NOC\n\nReady to generate new test trip"
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove Test Trip")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // 🔍 Data Integrity Diagnostic Section
                    if !store.trips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.cyan)
                                Text("Data Integrity Check")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                runDataIntegrityCheck()
                            } label: {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Check All Trips for Missing Data")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            // 🚑 Data Recovery Tool
                            Button {
                                attemptDataRecovery()
                            } label: {
                                HStack {
                                    Image(systemName: "waveform.path.ecg")
                                    Text("Attempt Data Recovery (Fix Zero-Leg Trips)")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Text("Scans all trips for missing scheduled times, roster IDs, and other critical data. Recovery tool can fix trips with zero legs by reloading from disk.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("NOC Testing")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize to 2 hours from now
                if selectedDate < Date() {
                    selectedDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
                }
            }
        }
    }
    
    // MARK: - Data Integrity Diagnostics
    
    private func runDataIntegrityCheck() {
        testResult = "🔍 Running Data Integrity Check...\n\n"
        
        var totalTrips = 0
        var totalLegs = 0
        var tripsWithZeroLegs = 0
        var legsWithScheduledData = 0
        var legsWithRosterId = 0
        var legsMissingScheduledOut = 0
        var legsMissingScheduledIn = 0
        var legsMissingRosterId = 0
        
        for trip in store.trips {
            totalTrips += 1
            testResult += "📋 Trip #\(trip.tripNumber) (\(trip.date.formatted(date: .abbreviated, time: .omitted)))\n"
            testResult += "  Status: \(trip.status.rawValue), Legs: \(trip.legs.count), Logpages: \(trip.logpages.count)\n"
            
            // 🚨 CRITICAL: Check for zero legs
            if trip.legs.isEmpty {
                tripsWithZeroLegs += 1
                testResult += "  🚨 CRITICAL: ZERO LEGS!\n"
                
                // Check if logpages have legs
                for (pageIdx, page) in trip.logpages.enumerated() {
                    testResult += "    Logpage \(pageIdx + 1): \(page.legs.count) legs\n"
                    if !page.legs.isEmpty {
                        testResult += "      ⚠️ Logpage HAS legs but trip.legs is empty!\n"
                        for (legIdx, leg) in page.legs.enumerated() {
                            testResult += "      Leg \(legIdx + 1): \(leg.departure)→\(leg.arrival)\n"
                        }
                    }
                }
                testResult += "\n"
                continue
            }
            
            for (index, leg) in trip.legs.enumerated() {
                totalLegs += 1
                let hasOut = leg.scheduledOut != nil
                let hasIn = leg.scheduledIn != nil
                let hasRoster = leg.rosterSourceId != nil
                
                if hasOut { legsWithScheduledData += 1 } else { legsMissingScheduledOut += 1 }
                if hasIn { legsWithScheduledData += 1 } else { legsMissingScheduledIn += 1 }
                if hasRoster { legsWithRosterId += 1 } else { legsMissingRosterId += 1 }
                
                let outIcon = hasOut ? "✅" : "❌"
                let inIcon = hasIn ? "✅" : "❌"
                let rosterIcon = hasRoster ? "✅" : "❌"
                
                testResult += "    Leg \(index + 1): \(leg.departure)→\(leg.arrival) "
                testResult += "\(outIcon)OUT \(inIcon)IN \(rosterIcon)ID"
                
                if !hasOut || !hasIn || !hasRoster {
                    testResult += " ⚠️ MISSING DATA"
                }
                testResult += "\n"
                
                // Show what's actually stored
                if hasOut, let out = leg.scheduledOut {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm"
                    testResult += "      scheduledOut: \(f.string(from: out))\n"
                }
                if hasIn, let inTime = leg.scheduledIn {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm"
                    testResult += "      scheduledIn: \(f.string(from: inTime))\n"
                }
                if hasRoster {
                    testResult += "      rosterSourceId: \(leg.rosterSourceId ?? "nil")\n"
                }
            }
            testResult += "\n"
        }
        
        testResult += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        testResult += "📊 SUMMARY\n"
        testResult += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        testResult += "Total Trips: \(totalTrips)\n"
        testResult += "🚨 Trips with ZERO legs: \(tripsWithZeroLegs)\n"
        testResult += "Total Legs: \(totalLegs)\n"
        testResult += "Legs with Scheduled OUT: \(totalLegs - legsMissingScheduledOut)/\(totalLegs)\n"
        testResult += "Legs with Scheduled IN: \(totalLegs - legsMissingScheduledIn)/\(totalLegs)\n"
        testResult += "Legs with Roster ID: \(legsWithRosterId)/\(totalLegs)\n"
        
        if tripsWithZeroLegs > 0 {
            testResult += "\n🚨 CRITICAL ISSUE FOUND!\n"
            testResult += "  • \(tripsWithZeroLegs) trips have ZERO legs!\n"
            testResult += "\n💡 POSSIBLE CAUSES:\n"
            testResult += "  1. Trip.legs computed property broken\n"
            testResult += "  2. Logpages array is empty\n"
            testResult += "  3. Data corruption during save/load\n"
            testResult += "  4. Migration issue from old format\n"
            testResult += "\n🔧 CHECK:\n"
            testResult += "  • Look for 'Logpage X: N legs' above\n"
            testResult += "  • If logpages HAVE legs but trip.legs empty,\n"
            testResult += "    the computed property is broken!\n"
        } else if legsMissingScheduledOut > 0 || legsMissingScheduledIn > 0 || legsMissingRosterId > 0 {
            testResult += "\n⚠️ ISSUES FOUND\n"
            if legsMissingScheduledOut > 0 {
                testResult += "  • \(legsMissingScheduledOut) legs missing scheduledOut\n"
            }
            if legsMissingScheduledIn > 0 {
                testResult += "  • \(legsMissingScheduledIn) legs missing scheduledIn\n"
            }
            if legsMissingRosterId > 0 {
                testResult += "  • \(legsMissingRosterId) legs missing rosterSourceId\n"
            }
            testResult += "\n💡 This suggests the legs were created without\n"
            testResult += "   scheduled data, not lost during save/load.\n"
            testResult += "\n🔧 Check RosterToTripHelper.createLeg() to ensure\n"
            testResult += "   it properly transfers scheduled times.\n"
        } else {
            testResult += "\n✅ All legs have complete scheduled data!\n"
        }
    }
    
    // MARK: - Data Recovery Function
    
    private func attemptDataRecovery() {
        testResult = "🚑 Starting Data Recovery...\n\n"
        
        testResult += "Step 1: Identifying trips with zero legs...\n"
        let zeroLegTrips = store.trips.filter { $0.legs.isEmpty }
        testResult += "Found \(zeroLegTrips.count) trips with zero legs\n\n"
        
        if zeroLegTrips.isEmpty {
            testResult += "✅ No trips need recovery!\n"
            return
        }
        
        testResult += "Step 2: Forcing reload from disk...\n"
        testResult += "(This will re-decode from JSON with improved recovery logic)\n\n"
        
        // Force a reload which will trigger the improved decode logic
        store.loadWithRecovery()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            testResult += "Step 3: Re-checking after reload...\n"
            let stillZeroLegs = store.trips.filter { $0.legs.isEmpty }
            
            if stillZeroLegs.count == 0 {
                testResult += "🎉 SUCCESS! All trips recovered.\n"
                testResult += "  Before: \(zeroLegTrips.count) trips with zero legs\n"
                testResult += "  After: 0 trips with zero legs\n"
            } else if stillZeroLegs.count < zeroLegTrips.count {
                testResult += "✅ PARTIAL SUCCESS\n"
                testResult += "  Before: \(zeroLegTrips.count) trips with zero legs\n"
                testResult += "  After: \(stillZeroLegs.count) trips with zero legs\n"
                testResult += "  Recovered: \(zeroLegTrips.count - stillZeroLegs.count) trips\n"
                testResult += "\n⚠️ Some trips could not be recovered.\n"
                testResult += "   They may have truly corrupted data.\n"
            } else {
                testResult += "❌ RECOVERY FAILED\n"
                testResult += "  Trips with zero legs: \(stillZeroLegs.count)\n"
                testResult += "\n💡 NEXT STEPS:\n"
                testResult += "1. Check console for decode errors\n"
                testResult += "2. Try restoring from a backup file\n"
                testResult += "3. The backup may have the complete leg data\n"
            }
            
            testResult += "\n📋 Detailed Analysis:\n"
            for trip in stillZeroLegs.prefix(5) {
                testResult += "\nTrip #\(trip.tripNumber):\n"
                testResult += "  Logpages: \(trip.logpages.count)\n"
                for (idx, page) in trip.logpages.enumerated() {
                    testResult += "  Logpage \(idx + 1): \(page.legs.count) legs\n"
                }
            }
        }
    }
    
    // MARK: - Critical Notes About Data Persistence
    /*
     🔥 DATA LOSS ROOT CAUSE ANALYSIS:
     
     The issue is NOT with Trip.encode/decode - that works correctly.
     
     The problem is likely in RosterToTripHelper.createLeg(from:BasicScheduleItem)
     which may not be transferring these critical fields:
     
     1. scheduledOut (from item.blockOut)
     2. scheduledIn (from item.blockIn)
     3. scheduledFlightNumber (from item.tripNumber or summary)
     4. rosterSourceId (from item.id.uuidString)
     
     These fields MUST be set when creating legs from roster data,
     otherwise they will be nil from the start (not lost during save).
     
     The fix in createTestTrip() below shows how to explicitly set these.
     Apply the same pattern to your production roster-to-trip code.
     */
    
    // MARK: - Helper Views
    
    private func testDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Route Configuration Helpers

    private func cityPairRow(legNumber: Int, origin: Binding<String>, dest: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text("Leg \(legNumber):")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)

            TextField("DEP", text: origin)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .autocapitalization(.allCharacters)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("ARR", text: dest)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .autocapitalization(.allCharacters)

            Spacer()

            // Show if this is the last leg (RD:X marker)
            if legNumber == legCount {
                Text("RD:X")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LogbookTheme.accentGreen.opacity(0.3))
                    .foregroundColor(LogbookTheme.accentGreen)
                    .cornerRadius(4)
            }
        }
    }

    private func applyPresetRoute(_ route: TestRoute) {
        switch route {
        case .yipRoundtrip:
            legCount = 3
            leg1Origin = "YIP"; leg1Dest = "DTW"
            leg2Origin = "DTW"; leg2Dest = "CLE"
            leg3Origin = "CLE"; leg3Dest = "YIP"
        case .lrdTurn:
            legCount = 2
            leg1Origin = "YIP"; leg1Dest = "LRD"
            leg2Origin = "LRD"; leg2Dest = "YIP"
        case .mexTrip:
            legCount = 4
            leg1Origin = "YIP"; leg1Dest = "LRD"
            leg2Origin = "LRD"; leg2Dest = "MEX"
            leg3Origin = "MEX"; leg3Dest = "LRD"
            leg4Origin = "LRD"; leg4Dest = "YIP"
        case .custom:
            break // Keep current values
        }
    }

    private func getRouteSummary() -> String {
        var cities: [String] = [leg1Origin]
        cities.append(leg1Dest)
        if legCount >= 2 { cities.append(leg2Dest) }
        if legCount >= 3 { cities.append(leg3Dest) }
        if legCount >= 4 { cities.append(leg4Dest) }
        return cities.joined(separator: " → ")
    }

    private func getFlightNumbersPreview() -> String {
        (0..<legCount).map { "\(flightNumberPrefix)\(baseFlightNumber + $0)" }.joined(separator: ", ")
    }

    private func getAircraftFullName() -> String {
        switch aircraftType {
        case "M88": return "MD-88"
        case "M83": return "MD-83"
        case "M87": return "MD-87"
        case "CRJ": return "CRJ-200"
        default: return aircraftType
        }
    }

    /// Get city pairs as array of tuples for iCal generation
    private func getCityPairs() -> [(origin: String, dest: String)] {
        var pairs: [(String, String)] = []
        pairs.append((leg1Origin, leg1Dest))
        if legCount >= 2 { pairs.append((leg2Origin, leg2Dest)) }
        if legCount >= 3 { pairs.append((leg3Origin, leg3Dest)) }
        if legCount >= 4 { pairs.append((leg4Origin, leg4Dest)) }
        return pairs
    }
    
    private func legPreviewRow(leg: FlightLeg, number: Int) -> some View {
        HStack {
            Text("Leg \(number)")
                .font(.caption)
                .foregroundColor(.gray)
            Text("\(leg.departure) → \(leg.arrival)")
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Text("\(leg.flightNumber)")
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Date/Time Helpers
    
    private func formatScheduledTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: selectedDate)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    private func estimatedEndTime() -> Date {
        // Total trip duration: ~3h 50m (includes ground time between legs)
        let totalMinutes = 230 // 3h 50m
        return Calendar.current.date(byAdding: .minute, value: totalMinutes, to: selectedDate) ?? selectedDate
    }
    
    // MARK: - Test Trip Generation
    
    private func generateTestTrip() {
        isGenerating = true
        
        if testMode == .directTrip {
            generateDirectTrip()
        } else {
            generateRosterItems()
        }
    }
    
    // Original flow - creates trip directly
    private func generateDirectTrip() {
        testResult = "🚀 Starting test trip generation...\n"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Generate fake iCal data
            let icalData = createTestICalData()
            testResult += "✅ Generated test iCal data\n"
            
            // Parse it
            let (flights, _) = ICalFlightParser.parseCalendarString(icalData)
            testResult += "✅ Parsed \(flights.count) flights\n"
            
            // Create BasicScheduleItems from flights
            var scheduleItems: [BasicScheduleItem] = []
            for flight in flights {
                if let item = convertToScheduleItem(flight) {
                    scheduleItems.append(item)
                    testResult += "  • \(flight.flightNumber): \(flight.origin) → \(flight.destination)\n"
                }
            }
            
            if scheduleItems.isEmpty {
                testResult += "❌ No valid schedule items created\n"
                isGenerating = false
                return
            }
            
            // Create a new trip
            let newTrip = createTestTrip(from: scheduleItems)
            
            // 🔥 VALIDATE: Check that scheduled times were preserved
            testResult += "\n🔍 Validating leg data...\n"
            for (index, leg) in newTrip.legs.enumerated() {
                let hasScheduledOut = leg.scheduledOut != nil
                let hasScheduledIn = leg.scheduledIn != nil
                let hasRosterId = leg.rosterSourceId != nil
                
                testResult += "  Leg \(index + 1): "
                testResult += hasScheduledOut ? "✅OUT " : "❌OUT "
                testResult += hasScheduledIn ? "✅IN " : "❌IN "
                testResult += hasRosterId ? "✅ID\n" : "❌ID\n"
                
                if let out = leg.scheduledOut, let inTime = leg.scheduledIn {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    testResult += "    Scheduled: \(formatter.string(from: out)) → \(formatter.string(from: inTime))\n"
                }
            }
            
            store.trips.append(newTrip)
            store.save()  // Save to persistence
            
            // 🔥 VERIFY: Reload and check persistence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let savedTrip = store.trips.first(where: { $0.id == newTrip.id }) {
                    testResult += "\n🔍 Verifying saved trip...\n"
                    testResult += "  Legs in trip: \(savedTrip.legs.count)\n"
                    testResult += "  Logpages: \(savedTrip.logpages.count)\n"
                    for (index, leg) in savedTrip.legs.enumerated() {
                        let hasData = leg.scheduledOut != nil && leg.scheduledIn != nil
                        testResult += "  Leg \(index + 1): \(hasData ? "✅" : "❌") scheduled data preserved\n"
                    }
                } else {
                    testResult += "\n⚠️ Could not find saved trip in store\n"
                }
            }
            
            generatedTrip = newTrip
            
            testResult += "✅ Created Trip #\(newTrip.tripNumber)\n"
            testResult += "✅ Added \(newTrip.legs.count) legs\n"
            
            // 🔍 CRITICAL: Calculate and display duty hours
            let dutyHours = newTrip.totalDutyHours
            testResult += "\n📊 DUTY TIME CALCULATION:\n"
            testResult += "   Total Duty Hours: \(dutyHours)\n"
            testResult += "   Formatted: \(Int(dutyHours))h \(Int((dutyHours - Double(Int(dutyHours))) * 60))m\n"
            
            if dutyHours > 16 {
                testResult += "\n🚨 ERROR: Duty hours exceed 16! This is a bug.\n"
                testResult += "   Check console logs for detailed debug info.\n"
            } else if dutyHours < 0.5 {
                testResult += "\n⚠️ WARNING: Duty hours suspiciously low\n"
            } else {
                testResult += "   ✅ Duty calculation looks reasonable\n"
            }
            
            // 🔧 FIX: Restore duty status after test trip generation
            restoreDutyStatusFromNOC()
            testResult += "\n✅ Restored duty status from NOC\n"
            
            testResult += "\n🎉 Test trip ready!\n"
            testResult += "Use GPX Testing to simulate flying it.\n"
            testResult += "\n💡 Check Xcode console for detailed duty calculation logs."
            
            isGenerating = false
        }
    }
    
    // New flow - adds to roster, tests trip generation
    private func generateRosterItems() {
        testResult = "🚀 Starting roster item generation...\n"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Generate fake iCal data
            let icalData = createTestICalData()
            testResult += "✅ Generated test iCal data\n"
            
            // Parse it
            let (flights, _) = ICalFlightParser.parseCalendarString(icalData)
            testResult += "✅ Parsed \(flights.count) flights\n"
            
            // Create BasicScheduleItems from flights
            var scheduleItems: [BasicScheduleItem] = []
            for flight in flights {
                if let item = convertToScheduleItem(flight) {
                    scheduleItems.append(item)
                    testResult += "  • \(flight.flightNumber): \(flight.origin) → \(flight.destination)\n"
                }
            }
            
            if scheduleItems.isEmpty {
                testResult += "❌ No valid schedule items created\n"
                isGenerating = false
                return
            }
            
            // Inject into ScheduleStore
            testResult += "✅ Adding \(scheduleItems.count) items to ScheduleStore\n"
            // Add items to ScheduleStore's items array
            for item in scheduleItems {
                scheduleStore.items.append(item)
            }
            
            // Trigger trip generation by posting notification
            testResult += "✅ Notifying TripGenerationService...\n"
            NotificationCenter.default.post(
                name: .rosterDataReadyForTripGeneration,
                object: nil,
                userInfo: ["items": scheduleItems]
            )
            
            // 🔧 FIX: Restore duty status after roster generation
            restoreDutyStatusFromNOC()
            testResult += "✅ Restored duty status from NOC\n\n"
            
            testResult += "\n🎉 Roster items added!\n"
            testResult += "\n📋 NEXT STEPS:\n"
            testResult += "1️⃣ Go to RosterView (Schedule tab)\n"
            testResult += "2️⃣ Find your test flights in the calendar\n"
            testResult += "3️⃣ Long-press a flight → 'Add to Trip'\n"
            testResult += "4️⃣ Choose 'Create New Trip'\n"
            testResult += "5️⃣ Trip will be in Planning status\n"
            testResult += "6️⃣ Activate it when ready to fly\n"
            testResult += "\n🤖 OR wait for auto-detection:\n"
            
            // Check if TripGenerationService picked them up
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let pendingCount = TripGenerationService.shared.pendingTrips.count
                if pendingCount > 0 {
                    testResult += "✅ Auto-detected \(pendingCount) pending trip(s)!\n"
                    testResult += "Check the Pending Trips notification\n"
                } else {
                    testResult += "⏳ No auto-detection yet (check TripGenerationSettings)\n"
                }
            }
            
            isGenerating = false
        }
    }
    
    // MARK: - iCal Data Generation

    private func createTestICalData() -> String {
        let now = Date()
        let calendar = Calendar.current

        // Use the selected date/time instead of hardcoded "today at 10am"
        let baseTime = selectedDate

        // Get configured city pairs
        let cityPairs = getCityPairs()

        // Generate unique test UID base
        let testUIDBase = Int.random(in: 100000...999999)

        // Build VEVENT entries dynamically based on leg count
        var events: [String] = []
        var currentTime = baseTime
        let checkInTime = calendar.date(byAdding: .minute, value: -30, to: baseTime)!

        for (index, pair) in cityPairs.enumerated() {
            let legNumber = index + 1
            let flightNumber = "\(flightNumberPrefix)\(baseFlightNumber + index)"
            let uid = "\(testUIDBase + index)"
            let isLastLeg = (legNumber == legCount)

            // Calculate leg times
            let legStart = currentTime
            let blockMinutes = 30 + (index * 5) // Vary block times: 30, 35, 40, 45 min
            let legEnd = calendar.date(byAdding: .minute, value: blockMinutes, to: legStart)!

            // Ground time between legs (45 min)
            let nextLegStart = calendar.date(byAdding: .minute, value: 45, to: legEnd)!

            // Build description with all NOC fields
            var descParts: [String] = []
            descParts.append("\(flightNumber) \(pair.origin) - \(pair.dest)")

            // CI only on first leg
            if legNumber == 1 {
                descParts.append("CI \(formatZuluTime(checkInTime))Z")
            }

            descParts.append("STD \(formatZuluTime(legStart))Z")
            descParts.append("STA \(formatZuluTime(legEnd))Z")

            // CO and RD:X only on last leg
            if isLastLeg {
                let checkOutTime = calendar.date(byAdding: .minute, value: 30, to: legEnd)!
                descParts.append("CO \(formatZuluTime(checkOutTime))Z")
                descParts.append("RD: X")  // Trip end marker!
            } else {
                descParts.append("RD: L")  // Regular leg
            }

            let durationHours = blockMinutes / 60
            let durationMins = blockMinutes % 60
            let blhMinutes = blockMinutes - 5 // BLH slightly less than duration
            let blhHours = blhMinutes / 60
            let blhMins = blhMinutes % 60

            descParts.append(String(format: "Duration: %02d:%02d, BLH: %02d:%02d", durationHours, durationMins, blhHours, blhMins))
            descParts.append("Aircraft: \(aircraftType) - \(getAircraftFullName()) - \(tailNumber)")

            let description = descParts.joined(separator: "\\n")

            let event = """
            BEGIN:VEVENT
            UID:\(uid)
            DTSTAMP:\(formatICalDate(now))
            DTSTART:\(formatICalDate(legStart))
            DTEND:\(formatICalDate(legEnd))
            SUMMARY:\(flightNumber) \(pair.origin)-\(pair.dest)
            DESCRIPTION:\(description)
            END:VEVENT
            """

            events.append(event)
            currentTime = nextLegStart
        }

        let icalData = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//TheProPilotApp//Testing//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        \(events.joined(separator: "\n"))
        END:VCALENDAR
        """

        return icalData
    }
    
    private func formatICalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    private func formatZuluTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    private func formatLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // MARK: - Convert Parsed Flight to Schedule Item

    private func convertToScheduleItem(_ flight: ParsedFlightData) -> BasicScheduleItem? {
        guard let blockOut = flight.scheduledDeparture,
              let blockIn = flight.scheduledArrival else {
            return nil
        }

        // Calculate OFF/ON times (taxi times)
        let taxiOut: TimeInterval = 5 * 60  // 5 min taxi out
        let taxiIn: TimeInterval = 3 * 60   // 3 min taxi in
        let blockOff = blockOut.addingTimeInterval(taxiOut)
        let blockOn = blockIn.addingTimeInterval(-taxiIn)

        let date = Calendar.current.startOfDay(for: blockOut)
        let summary = "\(flight.flightNumber) \(flight.origin)-\(flight.destination)"

        // Extract BLH in minutes
        let blhMinutes: Int? = flight.blockHours.map { Int($0 / 60) }

        // Detect if this is the last leg of trip from role field
        let isLastLeg = flight.role?.contains("X") ?? false

        return BasicScheduleItem(
            date: date,
            tripNumber: flight.flightNumber,
            departure: flight.origin,
            arrival: flight.destination,
            blockOut: blockOut,
            blockOff: blockOff,
            blockOn: blockOn,
            blockIn: blockIn,
            summary: summary,
            status: flight.isDeadhead ? .deadhead : .activeTrip,
            scheduledBlockMinutes: blhMinutes,
            nocUID: flight.uid,
            nocTimestamp: flight.dtStart, // Using dtStart as timestamp
            isLastLegOfTrip: isLastLeg,
            tripGroupId: flight.flightNumber,
            checkInTime: flight.checkIn,
            checkOutTime: flight.checkOut,
            scheduledDeparture: flight.scheduledDeparture,
            scheduledArrival: flight.scheduledArrival,
            scheduledFlightMinutes: flight.dutyDuration.map { Int($0 / 60) },
            aircraftType: flight.aircraftType,
            tailNumber: flight.tailNumber
        )
    }
    
    // MARK: - Create Trip from Schedule Items
    
    private func createTestTrip(from scheduleItems: [BasicScheduleItem]) -> Trip {
        testResult += "\n🔨 Creating trip from \(scheduleItems.count) schedule items...\n"
        
        // Convert schedule items to legs with EXPLICIT scheduled time mapping
        var legs: [FlightLeg] = []
        for (index, item) in scheduleItems.enumerated() {
            testResult += "  Processing item \(index + 1): \(item.departure)→\(item.arrival)\n"
            
            var leg = RosterToTripHelper.shared.createLeg(from: item)
            testResult += "    After createLeg(): \(leg.departure)→\(leg.arrival)\n"
            
            // 🔥 EXPLICIT FIX: Ensure all scheduled fields are set
            leg.scheduledOut = item.blockOut
            leg.scheduledIn = item.blockIn
            leg.scheduledFlightNumber = item.tripNumber  // Or extract from summary if different
            leg.rosterSourceId = item.id.uuidString
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            formatter.timeZone = .current
            
            testResult += "    Set scheduledOut: \(formatter.string(from: item.blockOut))\n"
            testResult += "    Set scheduledIn: \(formatter.string(from: item.blockIn))\n"
            testResult += "    Set rosterSourceId: \(item.id.uuidString)\n"
            
            // 🔍 DEBUG: Log the actual leg times that will be used for duty calc
            testResult += "    Leg OUT time: '\(leg.outTime)'\n"
            testResult += "    Leg IN time: '\(leg.inTime)'\n"
            
            legs.append(leg)
            testResult += "    ✅ Leg \(index + 1) added to array (total: \(legs.count))\n"
        }
        
        testResult += "\n✅ Created \(legs.count) legs array\n"
        
        // Generate test trip number using the first flight number
        let tripNumber = scheduleItems.first?.tripGroupId ?? "\(flightNumberPrefix)\(baseFlightNumber)"

        // Use the selected date for the trip
        let tripDate = Calendar.current.startOfDay(for: selectedDate)

        // Get aircraft from first schedule item (or use configured tail number)
        let aircraft = scheduleItems.first?.tailNumber ?? tailNumber

        testResult += "🏗️ Calling Trip initializer with \(legs.count) legs...\n"
        testResult += "   Aircraft: \(aircraft)\n"

        // Create trip using the proper initializer
        let trip = Trip(
            tripNumber: tripNumber,
            aircraft: aircraft,  // Uses NOC tail number!
            date: tripDate,
            tatStart: "",
            crew: [],
            notes: "Generated test trip from NOC Tester",
            legs: legs,
            status: .planning,
            rosterSourceIds: scheduleItems.map { $0.id.uuidString },
            scheduledShowTime: scheduleItems.first?.blockOut
        )
        
        testResult += "✅ Trip created with ID: \(trip.id)\n"
        testResult += "✅ Trip.legs.count = \(trip.legs.count)\n"
        testResult += "✅ Trip.logpages.count = \(trip.logpages.count)\n"
        
        if !trip.logpages.isEmpty {
            for (idx, page) in trip.logpages.enumerated() {
                testResult += "  Logpage \(idx + 1): \(page.legs.count) legs\n"
            }
        }
        
        if trip.legs.count == 0 {
            testResult += "🚨 CRITICAL: Trip has ZERO legs after creation!\n"
            testResult += "   This means the Trip initializer failed to create logpages.\n"
        }
        
        return trip
    }
    
    // MARK: - Duty Status Restoration
    
    /// Restores duty status from NOC calendar after test trip generation
    /// This prevents phantom duty hours from corrupting the FDP calculation
    private func restoreDutyStatusFromNOC() {
        // Delegate to ScheduleStore which has access to NOC settings
        scheduleStore.restoreDutyStatusFromNOC()
    }
}

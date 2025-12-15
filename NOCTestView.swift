//
//  NOCTestView.swift
//  TheProPilotApp
//
//  NOC Trip Tester - Generates fake roster data for testing
//

import SwiftUI

struct NOCTestView: View {
    @ObservedObject var store: LogBookStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var testResult: String = "Ready to generate test trip"
    @State private var isGenerating = false
    @State private var generatedTrip: Trip?
    @State private var testMode: TestMode = .directTrip
    
    // Date/Time Configuration
    @State private var selectedDate = Date()
    @State private var hoursFromNow: Int = 2
    @State private var showDatePicker = false
    
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
                    
                    // Test Trip Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Test Trip Details")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            testDetailRow(label: "Route", value: "YIP → DTW → CLE → YIP")
                            testDetailRow(label: "Legs", value: "3")
                            testDetailRow(label: "Aircraft", value: "N833US (MD-88)")
                            testDetailRow(label: "Date", value: formatDate(selectedDate))
                            testDetailRow(label: "Flight Numbers", value: "UJ8790, UJ8791, UJ8792")
                            testDetailRow(label: "Total Duration", value: "~3h 50m")
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
                                    testResult = "Test trip removed\nReady to generate new test"
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
            store.trips.append(newTrip)
            store.save()  // Save to persistence
            generatedTrip = newTrip
            
            testResult += "✅ Created Trip #\(newTrip.tripNumber)\n"
            testResult += "✅ Added \(newTrip.legs.count) legs\n"
            testResult += "\n🎉 Test trip ready!\n"
            testResult += "Use GPX Testing to simulate flying it."
            
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
        
        // Create 3 flight legs
        let leg1Start = baseTime
        let leg1End = calendar.date(byAdding: .minute, value: 30, to: leg1Start)!
        
        let leg2Start = calendar.date(byAdding: .minute, value: 45, to: leg1End)!
        let leg2End = calendar.date(byAdding: .minute, value: 35, to: leg2Start)!
        
        let leg3Start = calendar.date(byAdding: .minute, value: 45, to: leg2End)!
        let leg3End = calendar.date(byAdding: .minute, value: 40, to: leg3Start)!
        
        let icalData = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//TheProPilotApp//Testing//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        UID:TEST001
        DTSTAMP:\(formatICalDate(now))
        DTSTART:\(formatICalDate(leg1Start))
        DTEND:\(formatICalDate(leg1End))
        SUMMARY:UJ8790 YIP-DTW
        DESCRIPTION:UJ8790 YIP - DTW\\nCI \(formatZuluTime(calendar.date(byAdding: .minute, value: -30, to: leg1Start)!))Z / \(formatLocalTime(calendar.date(byAdding: .minute, value: -30, to: leg1Start)!))L\\nSTD \(formatZuluTime(leg1Start))Z / \(formatLocalTime(leg1Start))L\\nSTA \(formatZuluTime(leg1End))Z / \(formatLocalTime(leg1End))L\\nDuration: 01:00, BLH: 00:30\\nAircraft: M88 - M88 - M88 - N833US\\n
        END:VEVENT
        BEGIN:VEVENT
        UID:TEST002
        DTSTAMP:\(formatICalDate(now))
        DTSTART:\(formatICalDate(leg2Start))
        DTEND:\(formatICalDate(leg2End))
        SUMMARY:UJ8791 DTW-CLE
        DESCRIPTION:UJ8791 DTW - CLE\\nSTD \(formatZuluTime(leg2Start))Z / \(formatLocalTime(leg2Start))L\\nSTA \(formatZuluTime(leg2End))Z / \(formatLocalTime(leg2End))L\\nDuration: 01:20, BLH: 00:35\\nAircraft: M88 - M88 - M88 - N833US\\n
        END:VEVENT
        BEGIN:VEVENT
        UID:TEST003
        DTSTAMP:\(formatICalDate(now))
        DTSTART:\(formatICalDate(leg3Start))
        DTEND:\(formatICalDate(leg3End))
        SUMMARY:UJ8792 CLE-YIP
        DESCRIPTION:UJ8792 CLE - YIP\\nSTD \(formatZuluTime(leg3Start))Z / \(formatLocalTime(leg3Start))L\\nSTA \(formatZuluTime(leg3End))Z / \(formatLocalTime(leg3End))L\\nCO \(formatZuluTime(calendar.date(byAdding: .minute, value: 30, to: leg3End)!))Z / \(formatLocalTime(calendar.date(byAdding: .minute, value: 30, to: leg3End)!))L\\nDuration: 01:55, BLH: 00:40\\nAircraft: M88 - M88 - M88 - N833US\\n
        END:VEVENT
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
            status: flight.isDeadhead ? .deadhead : .activeTrip
        )
    }
    
    // MARK: - Create Trip from Schedule Items
    
    private func createTestTrip(from scheduleItems: [BasicScheduleItem]) -> Trip {
        // Convert schedule items to legs
        var legs: [FlightLeg] = []
        for item in scheduleItems {
            let leg = RosterToTripHelper.shared.createLeg(from: item)
            legs.append(leg)
        }
        
        // Generate test trip number
        let tripNumber = "TEST-\(Int.random(in: 1000...9999))"
        
        // Use the selected date for the trip
        let tripDate = Calendar.current.startOfDay(for: selectedDate)
        
        // Create trip using the proper initializer
        let trip = Trip(
            tripNumber: tripNumber,
            aircraft: "N833US",
            date: tripDate,
            tatStart: "",
            crew: [],
            notes: "Generated test trip from NOC Tester",
            legs: legs,
            status: .planning,
            rosterSourceIds: scheduleItems.map { $0.id.uuidString },
            scheduledShowTime: scheduleItems.first?.blockOut
        )
        
        return trip
    }
}

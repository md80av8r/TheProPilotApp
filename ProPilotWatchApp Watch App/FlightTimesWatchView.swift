// FlightTimesWatchView.swift - ENHANCED with Trip Summary
// Features: 2x2 grid, Manual Advance, Haptic 24h Picker, History View, Trip Summary, Clear Button
import SwiftUI
import WatchKit

struct FlightTimesWatchView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var showEndTripConfirmation = false
    @State private var showTripSummary = false
    @State private var isAddingLeg = false
    @State private var isAdvancingLeg = false
    
    // Syncs Zulu/Local preference with iPhone
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    // Page Selection: 0 is always Current Leg. 1+ are History pages.
    @State private var currentPage: Int = 0
    
    // Safe UTC timezone
    private var utcTimeZone: TimeZone {
        TimeZone(identifier: "UTC") ?? TimeZone.current
    }
    
    // MARK: - Computed Properties
    private var outTime: Date? { connectivityManager.currentFlight?.outTime }
    private var offTime: Date? { connectivityManager.currentFlight?.offTime }
    private var onTime: Date? { connectivityManager.currentFlight?.onTime }
    private var inTime: Date? { connectivityManager.currentFlight?.inTime }
    
    private var flightNumber: String { connectivityManager.currentFlight?.flightNumber ?? "---" }
    
    private var route: String {
        let departure = connectivityManager.currentFlight?.departureAirport ?? "---"
        let arrival = connectivityManager.currentFlight?.arrivalAirport ?? "---"
        return "\(departure) → \(arrival)"
    }
    
    private var isLegComplete: Bool {
        outTime != nil && offTime != nil && onTime != nil && inTime != nil
    }
    
    private var legDisplay: String {
        let current = connectivityManager.currentLegIndex + 1
        let total = connectivityManager.totalLegs
        return "Leg \(current) of \(total)"
    }
    
    var body: some View {
        mainTabView
            .confirmationDialog("End Trip?", isPresented: $showEndTripConfirmation) {
                Button("End Trip", role: .destructive) {
                    endTrip()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Complete this trip and view summary?")
            }
            .sheet(isPresented: $showTripSummary) {
                TripSummaryView(useZuluTime: useZuluTime)
                    .environmentObject(connectivityManager)
            }
            .onChange(of: isLegComplete) { _, newValue in
                // ✅ Auto-save now handled in WatchConnectivityManager when leg data is received
                // No action needed here - completed legs are saved automatically
                if newValue {
                    print("⌚ Leg complete - will be auto-saved when synced from phone")
                }
            }
            .onChange(of: connectivityManager.currentFlight) { _, newValue in
                // ✅ FIX: Reset to page 0 when trip is cleared (prevents crash)
                if newValue == nil {
                    currentPage = 0
                    print("⌚ Trip cleared - reset to page 0")
                }
            }
    }
    
    // MARK: - Main Tab View
    private var mainTabView: some View {
        TabView(selection: $currentPage) {
            currentLegView
                .tag(0)
            
            historyPages
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .id(connectivityManager.completedLegs.count)
    }
    
    // MARK: - History Pages
    private var historyPages: some View {
        Group {
            if !connectivityManager.completedLegs.isEmpty {
                ForEach(connectivityManager.completedLegs.indices, id: \.self) { index in
                    CompletedLegPageView(
                        leg: connectivityManager.completedLegs[index],
                        legNumber: index + 1,
                        useZuluTime: useZuluTime
                    )
                    .tag(index + 1)
                }
            }
        }
    }
    
    // MARK: - Current Leg View
    private var currentLegView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Connection status
                SyncStatusView()
                
                // Header Info
                VStack(spacing: 4) {
                    Text(flightNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(route)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Timezone Badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(useZuluTime ? "ZULU TIME" : "LOCAL TIME")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(useZuluTime ? .blue : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((useZuluTime ? Color.blue : Color.orange).opacity(0.2))
                    .cornerRadius(4)
                    
                    // Leg & Summary Button
                    HStack(spacing: 8) {
                        Text(legDisplay)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        if !connectivityManager.completedLegs.isEmpty {
                            Button {
                                showTripSummary = true
                            } label: {
                                HStack(spacing: 2) {
                                    Text("Summary")
                                    Image(systemName: "list.bullet")
                                }
                                .font(.caption2)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // 2x2 Time Picker Grid
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        CompactSmartTimeButton(
                            label: "OUT", time: outTime, color: .blue,
                            onTimeSet: { time in connectivityManager.sendTimeEntry(timeType: "OUT", time: time) }
                        )
                        CompactSmartTimeButton(
                            label: "OFF", time: offTime, color: .orange,
                            onTimeSet: { time in connectivityManager.sendTimeEntry(timeType: "OFF", time: time) }
                        )
                    }
                    
                    HStack(spacing: 8) {
                        CompactSmartTimeButton(
                            label: "ON", time: onTime, color: .purple,
                            onTimeSet: { time in connectivityManager.sendTimeEntry(timeType: "ON", time: time) }
                        )
                        CompactSmartTimeButton(
                            label: "IN", time: inTime, color: .green,
                            onTimeSet: { time in connectivityManager.sendTimeEntry(timeType: "IN", time: time) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                
                Text("Tap = Now • Hold = Edit")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                
                // Controls (Only visible when leg is complete)
                if isLegComplete {
                    legTotalsView
                    
                    Divider().padding(.vertical, 4)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Leg Complete")
                        }
                        .foregroundColor(.green)
                        .font(.caption)
                        .fontWeight(.semibold)
                        
                        if !connectivityManager.completedLegs.isEmpty {
                            Text("⬅️ Swipe to view completed legs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            addNewLeg()
                        } label: {
                            Label(isAddingLeg ? "Adding..." : "Add Another Leg", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(isAddingLeg)
                        
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            showEndTripConfirmation = true
                        } label: {
                            Label("End Trip", systemImage: "flag.checkered")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - Current Leg Totals
    private var legTotalsView: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 4)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    timeCell(label: "OUT", time: outTime, color: .blue)
                    timeCell(label: "OFF", time: offTime, color: .orange)
                }
                HStack(spacing: 8) {
                    timeCell(label: "ON", time: onTime, color: .purple)
                    timeCell(label: "IN", time: inTime, color: .green)
                }
            }
            
            Text("LEG TOTALS").font(.caption2).foregroundColor(.secondary).padding(.top, 4)
            HStack(spacing: 12) {
                if let off = offTime, let on = onTime {
                    totalBox(label: "✈️ Flight", value: formatDuration(from: off, to: on), color: .green)
                }
                if let out = outTime, let in_ = inTime {
                    totalBox(label: "🕐 Block", value: formatDuration(from: out, to: in_), color: .blue)
                }
            }
        }
    }
    
    private func timeCell(label: String, time: Date?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(formatTime(time)).font(.system(.caption, design: .monospaced)).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(color.opacity(time != nil ? 0.2 : 0.05))
        .cornerRadius(6)
    }
    
    private func formatTime(_ time: Date?) -> String {
        guard let time = time else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = useZuluTime ? utcTimeZone : TimeZone.current
        return formatter.string(from: time)
    }
    
    private func totalBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Logic Helpers
    private func advanceToNextLeg() {
        isAdvancingLeg = true
        
        // ✅ Auto-save now handled in WatchConnectivityManager
        // No manual save needed here
        
        let message: [String: Any] = [
            "type": "requestNextLeg",
            "currentLegIndex": connectivityManager.currentLegIndex,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessageToPhoneWithReply(
            message,
            description: "request next leg",
            replyHandler: { reply in
                DispatchQueue.main.async {
                    self.isAdvancingLeg = false
                    WKInterfaceDevice.current().play(.success)
                }
            },
            errorHandler: { error in
                print("❌ Failed to advance leg: \(error.localizedDescription)")
                self.connectivityManager.sendMessageToPhone(message, description: "request next leg (fallback)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isAdvancingLeg = false
                }
            }
        )
    }
    
    private func addNewLeg() {
        isAddingLeg = true
        
        let message: [String: Any] = [
            "type": "addNewLeg",
            "departure": connectivityManager.currentFlight?.arrivalAirport ?? "",
            "flightNumber": connectivityManager.currentFlight?.flightNumber ?? ""
        ]
        
        connectivityManager.sendMessageToPhoneWithReply(
            message,
            description: "add new leg",
            replyHandler: { _ in
                isAddingLeg = false
                WKInterfaceDevice.current().play(.success)
            },
            errorHandler: { _ in
                self.connectivityManager.sendMessageToPhone(message, description: "add new leg")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isAddingLeg = false }
            }
        )
    }
    
    private func endTrip() {
        // ✅ FIX: Reset page to 0 BEFORE clearing data (prevents crash)
        currentPage = 0
        
        let message: [String: Any] = ["type": "endTrip", "timestamp": Date().timeIntervalSince1970]
        connectivityManager.sendMessageToPhone(message, description: "end trip")
        WKInterfaceDevice.current().play(.success)
        
        // Clear after a short delay to let the page reset take effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.connectivityManager.clearCompletedLegs()
        }
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        var interval = end.timeIntervalSince(start)
        if interval < 0 { interval += 24 * 3600 }
        let minutes = Int(interval / 60)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

// MARK: - Trip Summary View
struct TripSummaryView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @Environment(\.dismiss) var dismiss
    let useZuluTime: Bool
    
    // Safe UTC timezone
    private var utcTimeZone: TimeZone {
        TimeZone(identifier: "UTC") ?? TimeZone.current
    }
    
    var allLegs: [(leg: CompletedLegData, number: Int)] {
        var legs: [(CompletedLegData, Int)] = []
        
        // Add completed legs from history
        for (index, leg) in connectivityManager.completedLegs.enumerated() {
            legs.append((leg, index + 1))
        }
        
        // Add current leg if complete
        if let current = connectivityManager.currentFlight,
           let out = current.outTime, let off = current.offTime,
           let on = current.onTime, let in_ = current.inTime {
            // ✅ Generate a temporary UUID for the current leg in summary
            // (The real UUID will come from the phone when this leg is saved)
            let completedCurrent = CompletedLegData(
                id: UUID(),  // Temporary UUID for display only
                flightNumber: current.flightNumber,
                departure: current.departureAirport,
                arrival: current.arrivalAirport,
                outTime: out,
                offTime: off,
                onTime: on,
                inTime: in_
            )
            legs.append((completedCurrent, connectivityManager.currentLegIndex + 1))
        }
        
        return legs
    }
    
    var totalBlockTime: String {
        var totalMinutes = 0
        for (leg, _) in allLegs {
            guard let out = leg.outTime, let in_ = leg.inTime else { continue }
            let interval = in_.timeIntervalSince(out)
            totalMinutes += Int(interval / 60)
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var totalFlightTime: String {
        var totalMinutes = 0
        for (leg, _) in allLegs {
            guard let off = leg.offTime, let on = leg.onTime else { continue }
            let interval = on.timeIntervalSince(off)
            totalMinutes += Int(interval / 60)
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Trip Totals Card
                    VStack(spacing: 8) {
                        Text("Trip Totals")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Text("Total Block")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(totalBlockTime)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(8)
                            
                            VStack(spacing: 4) {
                                Text("Total Flight")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(totalFlightTime)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(8)
                        }
                        
                        Text("\(allLegs.count) Leg\(allLegs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Individual Legs
                    ForEach(allLegs, id: \.number) { leg, number in
                        TripSummaryLegCard(
                            leg: leg,
                            legNumber: number,
                            useZuluTime: useZuluTime
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Trip Summary Leg Card
struct TripSummaryLegCard: View {
    let leg: CompletedLegData
    let legNumber: Int
    let useZuluTime: Bool
    
    // Safe UTC timezone
    private var utcTimeZone: TimeZone {
        TimeZone(identifier: "UTC") ?? TimeZone.current
    }
    
    var blockTime: String {
        guard let out = leg.outTime, let in_ = leg.inTime else { return "--:--" }
        let interval = in_.timeIntervalSince(out)
        let minutes = Int(interval / 60)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
    
    var flightTime: String {
        guard let off = leg.offTime, let on = leg.onTime else { return "--:--" }
        let interval = on.timeIntervalSince(off)
        let minutes = Int(interval / 60)
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Leg \(legNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Spacer()
                if !leg.flightNumber.isEmpty {
                    Text(leg.flightNumber)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Route
            Text("\(leg.departure) → \(leg.arrival)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Times
            HStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text("OUT").font(.caption2).foregroundColor(.secondary)
                    Text(formatTime(leg.outTime))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 2) {
                    Text("OFF").font(.caption2).foregroundColor(.secondary)
                    Text(formatTime(leg.offTime))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 2) {
                    Text("ON").font(.caption2).foregroundColor(.secondary)
                    Text(formatTime(leg.onTime))
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 2) {
                    Text("IN").font(.caption2).foregroundColor(.secondary)
                    Text(formatTime(leg.inTime))
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Totals
            HStack(spacing: 8) {
                HStack {
                    Text("Block:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(blockTime)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text("Flight:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(flightTime)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = useZuluTime ? utcTimeZone : TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Completed Leg Page View
struct CompletedLegPageView: View {
    let leg: CompletedLegData
    let legNumber: Int
    let useZuluTime: Bool
    
    // Safe UTC timezone
    private var utcTimeZone: TimeZone {
        TimeZone(identifier: "UTC") ?? TimeZone.current
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Leg \(legNumber) Complete").font(.headline).foregroundColor(.green)
                }
                .padding(.top, 8)
                
                Text("\(leg.departure) → \(leg.arrival)")
                    .font(.title3).fontWeight(.semibold)
                
                if !leg.flightNumber.isEmpty {
                    Text(leg.flightNumber).font(.caption).foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        timeDisplay(label: "OUT", time: leg.outTime, color: .blue)
                        timeDisplay(label: "OFF", time: leg.offTime, color: .orange)
                    }
                    HStack(spacing: 16) {
                        timeDisplay(label: "ON", time: leg.onTime, color: .purple)
                        timeDisplay(label: "IN", time: leg.inTime, color: .green)
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    summaryBox(label: "Flight", value: formatDuration(start: leg.offTime, end: leg.onTime), color: .green)
                    summaryBox(label: "Block", value: formatDuration(start: leg.outTime, end: leg.inTime), color: .blue)
                }
                
                Text("⬅️ Current Leg")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .padding(8)
        }
    }
    
    private func timeDisplay(label: String, time: Date?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(formatTime(time)).font(.system(.body, design: .monospaced)).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(time != nil ? 0.2 : 0.05))
        .cornerRadius(8)
    }
    
    private func summaryBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = useZuluTime ? utcTimeZone : TimeZone.current
        return formatter.string(from: date)
    }
    
    private func formatDuration(start: Date?, end: Date?) -> String {
        guard let s = start, let e = end else { return "--:--" }
        var interval = e.timeIntervalSince(s)
        if interval < 0 { interval += 24 * 3600 }
        let m = Int(interval / 60)
        return String(format: "%d:%02d", m / 60, m % 60)
    }
}

// MARK: - Compact Smart Time Button with Clear
struct CompactSmartTimeButton: View {
    let label: String
    let time: Date?
    let color: Color
    let onTimeSet: (Date) -> Void
    
    @State private var showingPicker = false
    @State private var tempTime = Date()
    @State private var justTapped = false
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    // Safe UTC timezone
    private var utcTimeZone: TimeZone {
        TimeZone(identifier: "UTC") ?? TimeZone.current
    }
    
    var timeString: String {
        guard let time = time else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = useZuluTime ? utcTimeZone : TimeZone.current
        return formatter.string(from: time)
    }
    
    var body: some View {
        Button {
            let now = Date()
            onTimeSet(now)
            WKInterfaceDevice.current().play(.click)
            withAnimation { justTapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { justTapped = false } }
        } label: {
            VStack(spacing: 4) {
                Text(label).font(.caption2).foregroundColor(justTapped ? .white : .secondary)
                Text(timeString)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(time != nil ? .semibold : .regular)
                    .foregroundColor(justTapped ? .white : (time != nil ? .primary : .secondary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(justTapped ? color : (time != nil ? color.opacity(0.25) : Color.gray.opacity(0.1))))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(justTapped ? color.opacity(0) : (time != nil ? color : Color.gray.opacity(0.3)), lineWidth: 1.5))
            .scaleEffect(justTapped ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            tempTime = time ?? Date()
            showingPicker = true
            WKInterfaceDevice.current().play(.click)
        })
        .sheet(isPresented: $showingPicker) {
            manualPickerSheet
        }
    }
    
    private var manualPickerSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Set \(label)")
                    .font(.headline)
                    .padding(.top, 8)
                
                // Timezone Toggle
                HStack(spacing: 8) {
                    Button {
                        useZuluTime = false
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("LOCAL")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(!useZuluTime ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(!useZuluTime ? Color.orange : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        useZuluTime = true
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("ZULU")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(useZuluTime ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(useZuluTime ? Color.blue : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Time Picker
                AviationWatchTimePicker(
                    date: $tempTime,
                    timeZone: useZuluTime ? utcTimeZone : TimeZone.current
                )
                .frame(height: 120)
                
                // Action Buttons - BIGGER AND MORE VISIBLE
                HStack(spacing: 12) {
                    // Clear Button - Large and Red
                    Button {
                        onTimeSet(Date(timeIntervalSince1970: 0))
                        showingPicker = false
                        WKInterfaceDevice.current().play(.success)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.title3)
                            Text("Clear")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    // Set Button - Large and Green
                    Button {
                        onTimeSet(tempTime)
                        showingPicker = false
                        WKInterfaceDevice.current().play(.success)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Set")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .toolbar {
                // X button (top-left cancel)
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingPicker = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
// MARK: - Sync Status View
struct SyncStatusView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch connectivityManager.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
    
    private var statusText: String {
        switch connectivityManager.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "No Connection"
        }
    }
}

// MARK: - Preview
struct FlightTimesWatchView_Previews: PreviewProvider {
    static var previews: some View {
        FlightTimesWatchView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}

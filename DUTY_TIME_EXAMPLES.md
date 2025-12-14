# Duty Time Integration - Example Implementations

This file shows complete working examples of how to integrate the duty time tracking system into your views.

## Example 1: Full Trip Detail View with Duty Time

```swift
import SwiftUI

struct EnhancedTripDetailView: View {
    @Binding var trip: Trip
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dutyManager = DutyTimerManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    tripHeaderSection
                    
                    // Duty Time Section
                    if trip.status == .active {
                        // Show LIVE duty timer for active trips
                        LiveDutyTimerDisplay(trip: trip)
                    } else if trip.status == .completed {
                        // Show duty summary for completed trips
                        CompletedDutyTimeSummary(trip: trip)
                        
                        // Allow editing duty start time
                        DutyStartTimeEditor(trip: $trip)
                    }
                    
                    // Flight Legs
                    flightLegsSection
                    
                    // Crew
                    crewSection
                    
                    // Notes
                    notesSection
                }
                .padding()
            }
            .navigationTitle("Trip #\(trip.tripNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var tripHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trip #\(trip.tripNumber)")
                    .font(.title.bold())
                
                Spacer()
                
                // Status badge
                statusBadge
            }
            
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text(trip.aircraft)
                    .font(.headline)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        Text(trip.status.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .active: return .green
        case .planning: return .orange
        case .completed: return .blue
        case .cancelled: return .red
        }
    }
    
    private var flightLegsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Legs")
                .font(.headline)
            
            ForEach(trip.legs.indices, id: \.self) { index in
                LegRowView(leg: trip.legs[index], number: index + 1)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crew")
                .font(.headline)
            
            ForEach(trip.crew) { member in
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text(member.role)
                        .font(.subheadline.bold())
                    Text(member.name)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            
            Text(trip.notes.isEmpty ? "No notes" : trip.notes)
                .font(.subheadline)
                .foregroundColor(trip.notes.isEmpty ? .gray : .primary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LegRowView: View {
    let leg: FlightLeg
    let number: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Leg \(number)")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                
                Spacer()
                
                legStatusBadge
            }
            
            HStack(spacing: 4) {
                Text(leg.departure)
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(leg.arrival)
                    .font(.headline)
            }
            
            // Times
            HStack(spacing: 16) {
                TimeDisplayView(label: "OUT", time: leg.outTime)
                TimeDisplayView(label: "OFF", time: leg.offTime)
                TimeDisplayView(label: "ON", time: leg.onTime)
                TimeDisplayView(label: "IN", time: leg.inTime)
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var legStatusBadge: some View {
        Text(leg.status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(legStatusColor.opacity(0.2))
            .foregroundColor(legStatusColor)
            .cornerRadius(4)
    }
    
    private var legStatusColor: Color {
        switch leg.status {
        case .standby: return .gray
        case .active: return .green
        case .completed: return .blue
        case .skipped: return .red
        }
    }
}

struct TimeDisplayView: View {
    let label: String
    let time: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(time.isEmpty ? "----" : time)
                .foregroundColor(time.isEmpty ? .gray : .white)
        }
    }
}
```

## Example 2: Logbook Row with Duty Time Indicator

```swift
import SwiftUI

struct LogbookRowWithDutyIndicator: View {
    let trip: Trip
    
    var body: some View {
        HStack(spacing: 12) {
            // Trip number and date
            VStack(alignment: .leading, spacing: 4) {
                Text("Trip #\(trip.tripNumber)")
                    .font(.headline)
                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Duty time indicator
            dutyTimeIndicator
            
            // Total block time
            VStack(alignment: .trailing, spacing: 4) {
                Text("Block")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(trip.formattedTotalTime)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var dutyTimeIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: dutyIconName)
                .foregroundColor(dutyColor)
                .font(.title3)
            
            Text(String(format: "%.1fh", trip.totalDutyHours))
                .font(.caption.bold())
                .foregroundColor(dutyColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(dutyColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var dutyIconName: String {
        if trip.dutyStartTime != nil {
            return "clock.badge.checkmark.fill"  // Recorded
        } else {
            return "clock.arrow.circlepath"  // Auto-calculated
        }
    }
    
    private var dutyColor: Color {
        let hours = trip.totalDutyHours
        if hours >= 15 {
            return .red
        } else if hours >= 14 {
            return .orange
        } else {
            return .green
        }
    }
}
```

## Example 3: Quick Duty Timer Widget

```swift
import SwiftUI

struct DutyTimerQuickWidget: View {
    @ObservedObject var dutyManager = DutyTimerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: dutyManager.isOnDuty ? "timer.circle.fill" : "timer.circle")
                .font(.title)
                .foregroundColor(dutyManager.isOnDuty ? statusColor : .gray)
            
            if dutyManager.isOnDuty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ON DUTY")
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                    
                    Text(dutyManager.formattedElapsedTime())
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(.white)
                    
                    Text("\(dutyManager.formattedTimeRemaining()) remaining")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status indicator
                statusIndicator
            } else {
                Text("Not on duty")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 6)
            )
    }
    
    private var statusColor: Color {
        switch dutyManager.dutyStatus() {
        case .notOnDuty: return .gray
        case .normal: return .green
        case .warning: return .orange
        case .criticalWarning, .limitReached: return .red
        }
    }
}
```

## Example 4: Duty Time Analytics View

```swift
import SwiftUI

struct DutyTimeAnalyticsView: View {
    @ObservedObject var store: LogBookStore
    let dateRange: ClosedRange<Date>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Duty Time Analytics")
                    .font(.title.bold())
                
                Text(dateRangeText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Summary cards
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Total Duty Days",
                        value: "\(totalDutyDays)",
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                    
                    SummaryCard(
                        title: "Total Hours",
                        value: String(format: "%.1f", totalDutyHours),
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Avg per Day",
                        value: String(format: "%.1f", averageDutyHours),
                        icon: "chart.bar.fill",
                        color: .green
                    )
                    
                    SummaryCard(
                        title: "Longest Day",
                        value: String(format: "%.1f", longestDutyDay),
                        icon: "arrow.up.circle.fill",
                        color: .red
                    )
                }
                
                // Trip breakdown
                tripBreakdownSection
            }
            .padding()
        }
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: dateRange.lowerBound)) - \(formatter.string(from: dateRange.upperBound))"
    }
    
    private var tripsInRange: [Trip] {
        store.trips.filter { trip in
            dateRange.contains(trip.date) && trip.tripType == .operating
        }
    }
    
    private var totalDutyDays: Int {
        tripsInRange.count
    }
    
    private var totalDutyHours: Double {
        tripsInRange.reduce(0) { $0 + $1.totalDutyHours }
    }
    
    private var averageDutyHours: Double {
        guard totalDutyDays > 0 else { return 0 }
        return totalDutyHours / Double(totalDutyDays)
    }
    
    private var longestDutyDay: Double {
        tripsInRange.map { $0.totalDutyHours }.max() ?? 0
    }
    
    private var tripBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Breakdown")
                .font(.headline)
            
            ForEach(tripsInRange.sorted(by: { $0.date > $1.date })) { trip in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip #\(trip.tripNumber)")
                            .font(.subheadline.bold())
                        Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.2f hrs", trip.totalDutyHours))
                            .font(.subheadline.bold())
                        
                        if trip.dutyStartTime != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
```

## Example 5: Settings View for Duty Timer

```swift
import SwiftUI

struct DutyTimerSettingsView: View {
    @AppStorage("dutyTimerAutoStart") private var autoStart = true
    @AppStorage("dutyTimerNotifications") private var notifications = true
    @AppStorage("dutyTimerSyncWatch") private var syncWatch = true
    
    var body: some View {
        Form {
            Section(header: Text("Automation")) {
                Toggle("Auto-start with trip", isOn: $autoStart)
                    .tint(.green)
                
                if autoStart {
                    Text("Duty timer will start automatically when a trip becomes active")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Notifications")) {
                Toggle("Duty limit warnings", isOn: $notifications)
                    .tint(.orange)
                
                if notifications {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("14 hours - 2h remaining", systemImage: "bell.fill")
                        Label("15 hours - 1h remaining", systemImage: "bell.badge.fill")
                        Label("15.5 hours - 30m remaining", systemImage: "bell.badge.fill")
                        Label("16 hours - LIMIT REACHED", systemImage: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Apple Watch")) {
                Toggle("Sync to Watch", isOn: $syncWatch)
                    .tint(.blue)
                
                if syncWatch {
                    Text("Duty timer state will sync to Apple Watch via PhoneWatchConnectivity")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Current Status")) {
                DutyTimerQuickWidget()
            }
        }
        .navigationTitle("Duty Timer Settings")
    }
}
```

## Usage in Main App

Add to your main content view or tab view:

```swift
struct MainAppView: View {
    @StateObject private var store = LogBookStore()
    @StateObject private var dutyManager = DutyTimerManager.shared
    
    var body: some View {
        TabView {
            // Logbook tab
            LogbookView(store: store)
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
            
            // Active trip (if any)
            if let activeTrip = store.trips.first(where: { $0.status == .active }) {
                EnhancedTripDetailView(trip: binding(for: activeTrip))
                    .tabItem {
                        Label("Active Trip", systemImage: "airplane.circle.fill")
                    }
            }
            
            // Duty Timer tab
            DutyTimerView()
                .tabItem {
                    Label("Duty Timer", systemImage: "timer")
                }
                .badge(dutyManager.isOnDuty ? "!" : nil)
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
    
    private func binding(for trip: Trip) -> Binding<Trip> {
        guard let index = store.trips.firstIndex(where: { $0.id == trip.id }) else {
            return .constant(trip)
        }
        return Binding(
            get: { store.trips[index] },
            set: { store.updateTrip($0, at: index) }
        )
    }
}
```

---

These examples show real-world implementations you can copy and adapt for your app. All components are designed to work together seamlessly with the integrated duty time tracking system.

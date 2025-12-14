// TripGenerationSettingsView.swift - Settings UI for Smart Trip Generation
import SwiftUI

struct TripGenerationSettingsView: View {
    @ObservedObject var settings = TripGenerationSettings.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Master Toggle Section
                Section {
                    Toggle(isOn: $settings.enableRosterTripGeneration) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Smart Trip Generation")
                                .font(.headline)
                            Text("Automatically detect trips from your NOC roster")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(LogbookTheme.accentGreen)
                } header: {
                    Text("Roster Integration")
                } footer: {
                    Text("When enabled, ProPilot will analyze your NOC roster after each sync and offer to create trips from detected flights.")
                }
                
                if settings.enableRosterTripGeneration {
                    // MARK: - Trip Detection Section
                    Section {
                        Toggle("Include Deadhead Flights", isOn: $settings.includeDeadheads)
                        
                        Toggle("Require Confirmation", isOn: $settings.requireConfirmation)
                        
                        if !settings.requireConfirmation {
                            Toggle("Auto-Create Trips", isOn: $settings.autoCreateTrips)
                        }
                    } header: {
                        Text("Trip Detection")
                    } footer: {
                        Text(settings.requireConfirmation ?
                             "You'll be prompted to review and approve each detected trip before it's created." :
                             "Trips will be created automatically when detected. Use with caution.")
                    }
                    
                    // MARK: - Pre-Population Section
                    Section {
                        Toggle("Pre-fill Flight Numbers", isOn: $settings.prePopulateFlightNumbers)
                        
                        Toggle("Pre-fill Scheduled Times", isOn: $settings.prePopulateScheduledTimes)
                        
                        HStack {
                            Text("Default Aircraft")
                            Spacer()
                            TextField("N-Number", text: $settings.defaultAircraft)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.characters)
                                .frame(width: 120)
                        }
                    } header: {
                        Text("Trip Defaults")
                    } footer: {
                        Text("These settings control what information is automatically filled in when creating trips from your roster.")
                    }
                    
                    // MARK: - Leg Advancement Section
                    Section {
                        Picker("When Leg Completes", selection: $settings.legAdvancementMode) {
                            ForEach(LegAdvancementMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                    } header: {
                        Text("Leg Progression")
                    } footer: {
                        Text(settings.legAdvancementMode.description)
                    }
                    
                    // MARK: - Alarm Settings Section
                    Section {
                        Toggle("Enable Show Time Alarms", isOn: Binding(
                            get: { settings.defaultAlarmSettings.enabled },
                            set: { settings.defaultAlarmSettings.enabled = $0 }
                        ))
                        
                        if settings.defaultAlarmSettings.enabled {
                            Picker("Reminder Time", selection: Binding(
                                get: { settings.defaultAlarmSettings.reminderMinutesBefore },
                                set: { settings.defaultAlarmSettings.reminderMinutesBefore = $0 }
                            )) {
                                ForEach(TripAlarmSettings.reminderOptions, id: \.self) { minutes in
                                    Text(formatReminderTime(minutes)).tag(minutes)
                                }
                            }
                            
                            Picker("Alarm Sound", selection: Binding(
                                get: { settings.defaultAlarmSettings.alarmSound },
                                set: { settings.defaultAlarmSettings.alarmSound = $0 }
                            )) {
                                ForEach(AlarmSound.allCases, id: \.self) { sound in
                                    Text(sound.displayName).tag(sound)
                                }
                            }
                            
                            Toggle("Show Countdown on Watch", isOn: Binding(
                                get: { settings.defaultAlarmSettings.showCountdownOnWatch },
                                set: { settings.defaultAlarmSettings.showCountdownOnWatch = $0 }
                            ))
                        }
                    } header: {
                        Text("Show Time Alarms")
                    } footer: {
                        Text("Get reminded before your show time with a customizable alarm and countdown timer on your Apple Watch.")
                    }
                    
                    // MARK: - Notifications Section
                    Section {
                        Toggle("New Trips Detected", isOn: $settings.notifyOnNewTripsDetected)
                        
                        Toggle("Schedule Changes", isOn: $settings.notifyOnScheduleChanges)
                    } header: {
                        Text("Notifications")
                    }
                    
                    // MARK: - Reset Section
                    Section {
                        Button(role: .destructive) {
                            settings.resetToDefaults()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Reset to Defaults")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Trip Generation")
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
    
    private func formatReminderTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }
}

// MARK: - Pending Trips View
struct PendingTripsView: View {
    @ObservedObject var tripService = TripGenerationService.shared
    @EnvironmentObject var logbookStore: LogBookStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if tripService.pendingTrips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Pending Trips")
                            .font(.headline)
                        
                        Text("New trips will appear here when detected from your NOC roster.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(tripService.pendingTrips) { pending in
                            PendingTripRow(pending: pending)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        tripService.dismissPendingTrip(pending)
                                    } label: {
                                        Label("Dismiss", systemImage: "xmark")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        tripService.approvePendingTrip(pending, logbookStore: logbookStore)
                                    } label: {
                                        Label("Create", systemImage: "plus.circle")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Pending Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !tripService.pendingTrips.isEmpty {
                        Button("Clear All") {
                            tripService.clearAllPendingTrips()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .environmentObject(logbookStore)
    }
}

// MARK: - Pending Trip Row
struct PendingTripRow: View {
    let pending: PendingRosterTrip
    @ObservedObject var tripService = TripGenerationService.shared
    @EnvironmentObject var logbookStore: LogBookStore
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(pending.tripNumber)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(pending.tripDate))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Route
                Text(pending.routeSummary)
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                // Details
                HStack {
                    Label("\(pending.legCount) leg\(pending.legCount > 1 ? "s" : "")", systemImage: "airplane")
                    
                    Spacer()
                    
                    Label(pending.formattedBlockTime, systemImage: "clock")
                    
                    if let showTime = pending.formattedShowTime {
                        Spacer()
                        Label(showTime, systemImage: "bell")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                // Countdown if show time is upcoming
                if let countdown = pending.formattedTimeUntilShow {
                    HStack {
                        Image(systemName: "timer")
                        Text("Show time in \(countdown)")
                    }
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentOrange)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingDetail) {
            PendingTripDetailView(pending: pending)
                .environmentObject(logbookStore)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Pending Trip Detail View
struct PendingTripDetailView: View {
    let pending: PendingRosterTrip
    @ObservedObject var tripService = TripGenerationService.shared
    @ObservedObject var settings = TripGenerationSettings.shared
    @EnvironmentObject var logbookStore: LogBookStore
    @Environment(\.dismiss) var dismiss
    
    @State private var alarmEnabled: Bool
    @State private var reminderMinutes: Int
    @State private var alarmSound: AlarmSound
    @State private var showCountdown: Bool
    
    init(pending: PendingRosterTrip) {
        self.pending = pending
        let alarm = pending.alarmSettings ?? TripAlarmSettings()
        _alarmEnabled = State(initialValue: alarm.enabled)
        _reminderMinutes = State(initialValue: alarm.reminderMinutesBefore)
        _alarmSound = State(initialValue: alarm.alarmSound)
        _showCountdown = State(initialValue: alarm.showCountdownOnWatch)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Trip Info Section
                Section {
                    HStack {
                        Text("Trip")
                        Spacer()
                        Text(pending.tripNumber)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formatFullDate(pending.tripDate))
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Total Block")
                        Spacer()
                        Text(pending.formattedBlockTime)
                            .foregroundColor(.gray)
                    }
                    
                    if let showTime = pending.formattedShowTime {
                        HStack {
                            Text("Show Time")
                            Spacer()
                            Text(showTime)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                    }
                } header: {
                    Text("Trip Details")
                }
                
                // Legs Section
                Section {
                    ForEach(Array(pending.legs.enumerated()), id: \.element.id) { index, leg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Leg \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                if leg.isDeadhead {
                                    Text("DH")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Text("\(leg.formattedScheduledOut) - \(leg.formattedScheduledIn)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text(leg.flightNumber)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(leg.departure) → \(leg.arrival)")
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Legs (\(pending.legCount))")
                }
                
                // Alarm Settings Section
                Section {
                    Toggle("Set Show Time Alarm", isOn: $alarmEnabled)
                    
                    if alarmEnabled {
                        Picker("Remind Me", selection: $reminderMinutes) {
                            ForEach(TripAlarmSettings.reminderOptions, id: \.self) { minutes in
                                Text(formatReminderTime(minutes)).tag(minutes)
                            }
                        }
                        
                        Picker("Sound", selection: $alarmSound) {
                            ForEach(AlarmSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        
                        Toggle("Countdown on Watch", isOn: $showCountdown)
                    }
                } header: {
                    Text("Alarm")
                } footer: {
                    if alarmEnabled, let showTime = pending.showTime {
                        let alarmTime = showTime.addingTimeInterval(-Double(reminderMinutes * 60))
                        Text("Alarm will fire at \(formatTime(alarmTime))")
                    }
                }
                
                // Actions Section
                Section {
                    Button {
                        createTrip()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Trip", systemImage: "plus.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(LogbookTheme.accentGreen)
                    
                    Button {
                        tripService.remindLater(pending)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Remind Me Later", systemImage: "clock")
                            Spacer()
                        }
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                    
                    Button(role: .destructive) {
                        tripService.dismissPendingTrip(pending)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Dismiss", systemImage: "xmark")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .environmentObject(logbookStore)
    }
    
    private func createTrip() {
        // Update pending with current alarm settings
        var updatedPending = pending
        updatedPending.alarmSettings = TripAlarmSettings(
            enabled: alarmEnabled,
            reminderMinutesBefore: reminderMinutes,
            alarmSound: alarmSound,
            showCountdownOnWatch: showCountdown
        )
        
        tripService.approvePendingTrip(updatedPending, logbookStore: logbookStore)
        dismiss()
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatReminderTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes before"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "") before"
            } else {
                return "\(hours)h \(mins)m before"
            }
        }
    }
}

// MARK: - Schedule Variance Badge
struct ScheduleVarianceBadge: View {
    let variance: ScheduleVariance
    
    var body: some View {
        Text(variance.shortDisplayText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(variance.color.opacity(0.2))
            .foregroundColor(variance.color)
            .cornerRadius(4)
    }
}

// MARK: - Leg Status Badge
struct LegStatusBadge: View {
    let status: LegStatus
    
    var body: some View {
        Label(status.displayName, systemImage: status.symbolName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .standby: return .gray
        case .active: return LogbookTheme.accentGreen
        case .completed: return LogbookTheme.accentBlue
        case .skipped: return .orange
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TripGenerationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TripGenerationSettingsView()
            .preferredColorScheme(.dark)
    }
}
#endif

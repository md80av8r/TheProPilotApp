import SwiftUI

struct NOCSettingsView: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    @ObservedObject var scheduleStore: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearScheduleConfirmation = false
    @State private var showingAirportMappings = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Connection Status Section
                Section("Connection Status") {
                    HStack {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connectionStatus)
                                .font(.headline)
                                .foregroundColor(connectionStatusColor)
                            
                            if let lastSync = nocSettings.lastSyncTime {
                                Text("Last sync: \(lastSync, formatter: syncTimeFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if !nocSettings.username.isEmpty {
                                Text("Ready to sync")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Enter credentials to connect")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        // Sync status indicator
                        if nocSettings.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if nocSettings.syncSuccess && nocSettings.lastSyncTime != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Credentials Section
                Section(header: Text("Credentials")) {
                    TextField("Username", text: $nocSettings.username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $nocSettings.password)
                }

                // MARK: - Roster URL Section
                Section(header: Text("Roster URL")) {
                    TextField("Webcal URL", text: $nocSettings.rosterURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                // MARK: - Auto-Sync Settings with Interval Slider
                Section(header: Text("Automatic Sync")) {
                    Toggle("Auto Sync Enabled", isOn: $nocSettings.autoSyncEnabled)
                    
                    // 🔥 Background Processing Indicator - Makes it clear to Apple reviewers
                    if nocSettings.autoSyncEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.green)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Background sync active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                                Text("Updates schedule even when app is closed")
                                    .font(.caption2)
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.vertical, 4)
                    }
                    
                    if nocSettings.autoSyncEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            // Sync Interval Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Sync Interval")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(syncIntervalText)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(
                                    value: $nocSettings.syncIntervalMinutes,
                                    in: 15...240,
                                    step: 15
                                ) {
                                    Text("Sync Interval")
                                } minimumValueLabel: {
                                    Text("15m")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } maximumValueLabel: {
                                    Text("4h")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .tint(.blue)
                                
                                // Quick preset buttons
                                HStack(spacing: 8) {
                                    ForEach([15, 30, 60, 120], id: \.self) { minutes in
                                        Button(action: {
                                            nocSettings.syncIntervalMinutes = Double(minutes)
                                        }) {
                                            Text(formatInterval(minutes))
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(nocSettings.syncIntervalMinutes == Double(minutes) ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(nocSettings.syncIntervalMinutes == Double(minutes) ? .white : .primary)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            
                            Divider()
                            
                            // Info section
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.blue)
                                    Text("Syncs every \(syncIntervalText)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                if let lastSync = nocSettings.lastSyncTime {
                                    let nextSync = Calendar.current.date(byAdding: .minute, value: Int(nocSettings.syncIntervalMinutes), to: lastSync) ?? Date()
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.blue)
                                        Text("Next sync: \(nextSync, formatter: timeFormatter)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Schedule Data Management
                Section {
                    // Clear Offline Schedule
                    Button(action: {
                        showingClearScheduleConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Offline Schedule")
                                    .foregroundColor(.red)
                                Text("\(scheduleStore.items.count) items stored")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } header: {
                    Text("Schedule Data")
                } footer: {
                    Text("Clears cached schedule data. Re-sync to reload from NOC.")
                }

                // MARK: - Sync Action (SINGLE BUTTON)
                Section("Sync") {
                    Button(action: {
                        nocSettings.fetchRosterCalendar()
                    }) {
                        HStack {
                            if nocSettings.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                            }
                            Text(nocSettings.isSyncing ? "Syncing..." : "Sync Schedule Now")
                                .foregroundColor(.blue)
                            Spacer()
                            if nocSettings.syncSuccess && !nocSettings.isSyncing {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .disabled(nocSettings.username.isEmpty || nocSettings.password.isEmpty || nocSettings.isSyncing)
                    
                    Button(action: { nocSettings.clearCachedData() }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cached Data")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // MARK: - Time Offset Settings
                Section {
                    Toggle("Apply Time Offset", isOn: $nocSettings.applyTimeOffset)
                    
                    if nocSettings.applyTimeOffset {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Show Time to Block Out")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(nocSettings.showTimeToBlockOutOffset) min")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.blue)
                            }
                            
                            Stepper("", value: $nocSettings.showTimeToBlockOutOffset, in: 0...120, step: 15)
                                .labelsHidden()
                            
                            // Quick preset buttons
                            HStack(spacing: 8) {
                                ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                                    Button(action: {
                                        nocSettings.showTimeToBlockOutOffset = minutes
                                    }) {
                                        Text("\(minutes)m")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(nocSettings.showTimeToBlockOutOffset == minutes ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(nocSettings.showTimeToBlockOutOffset == minutes ? .white : .primary)
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            
                            Text("iCal shows Show Time, not Block Out. This offset adjusts times when importing trips.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Time Offset")
                } footer: {
                    Text("USA Jet typically uses 60 min from show to block out. Adjust based on your airline's callout time.")
                }

                // MARK: - Error Display
                if let error = nocSettings.fetchError {
                    Section(header: Text("Error")) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Button("Retry") {
                            nocSettings.fetchRosterCalendar()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // MARK: - Offline Data Info
                if nocSettings.hasOfflineData {
                    Section("Offline Data") {
                        if let age = nocSettings.offlineDataAge {
                            let days = Int(age / (24 * 60 * 60))
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cached Schedule Available")
                                        .font(.headline)
                                    Text("\(days) day\(days == 1 ? "" : "s") old")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                // MARK: - Diagnostics Section
                Section("Diagnostics") {
                    NavigationLink {
                        ICalDiagnosticView(nocSettings: nocSettings)
                    } label: {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCal Data Inspector")
                                    .foregroundColor(.primary)
                                Text("View raw iCal fields to find block times")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Airport Code Mappings
                    Button(action: {
                        showingAirportMappings = true
                    }) {
                        HStack {
                            Image(systemName: "airplane.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Airport Code Mappings")
                                    .foregroundColor(.primary)
                                let userCount = UserAirportCodeMappings.shared.userMappings.count
                                if userCount > 0 {
                                    Text("\(userCount) custom mapping\(userCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("Add custom IATA to ICAO conversions")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // MARK: - Help Section
                Section("Help") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Enter your NOC system username and password")
                        Text("• Paste the webcal URL from your roster system")
                        Text("• Tap 'Sync Schedule Now' to fetch your schedule")
                        if nocSettings.autoSyncEnabled {
                            Text("• Schedule syncs automatically every \(syncIntervalText)")
                                .foregroundColor(.blue)
                        }
                        Text("• Use iCal Data Inspector to view all available fields")
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
            .navigationTitle("NOC Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .confirmationDialog(
                "Clear Offline Schedule?",
                isPresented: $showingClearScheduleConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Schedule", role: .destructive) {
                    scheduleStore.clearOfflineSchedule()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all cached schedule data (\(scheduleStore.items.count) items). You'll need to re-sync to reload your schedule from NOC.")
            }
            .sheet(isPresented: $showingAirportMappings) {
                UserAirportMappingsView()
            }
        }
    }
    
    // MARK: - Helper Properties
    private var connectionStatus: String {
        if nocSettings.isSyncing {
            return "Syncing..."
        } else if nocSettings.syncSuccess && nocSettings.lastSyncTime != nil {
            return "Connected"
        } else if !nocSettings.username.isEmpty && !nocSettings.password.isEmpty {
            return "Ready to Connect"
        } else {
            return "Not Configured"
        }
    }
    
    private var connectionStatusColor: Color {
        if nocSettings.isSyncing {
            return .orange
        } else if nocSettings.syncSuccess && nocSettings.lastSyncTime != nil {
            return .green
        } else if !nocSettings.username.isEmpty && !nocSettings.password.isEmpty {
            return .blue
        } else {
            return .red
        }
    }
    
    private var syncIntervalText: String {
        let minutes = Int(nocSettings.syncIntervalMinutes)
        
        if minutes < 60 {
            return "\(minutes) minutes"
        } else if minutes == 60 {
            return "1 hour"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return "\(hours) hours"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes == 60 {
            return "1h"
        } else {
            return "\(minutes / 60)h"
        }
    }
}
 
// MARK: - Time Formatters
private let syncTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .short
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
}()

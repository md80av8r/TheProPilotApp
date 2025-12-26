//
//  AppleWatchStatusView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/27/25.
//


// AppleWatchStatusView.swift - Combined Watch Status, Diagnostics & Settings
import SwiftUI
import WatchConnectivity

struct AppleWatchStatusView: View {
    @ObservedObject var phoneWatchConnectivity: PhoneWatchConnectivity
    @ObservedObject var locationManager: PilotLocationManager
    @ObservedObject var opsManager: OPSCallingManager
    @ObservedObject var autoTimeSettings: AutoTimeSettings
    @EnvironmentObject var store: SwiftDataLogBookStore
    
    @State private var lastSyncTime = Date()
    @State private var showingResetConfirmation = false
    @State private var showingDisableAutoTimeConfirmation = false
    @State private var showingSyncSuccess = false
    @State private var showingDebugLog = false
    @State private var isDebugExpanded = false
    @State private var watchCurrentLeg: Int?
    @State private var phoneCurrentLeg: Int?
    
    // Auto-refresh timer
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Status Card
                connectionStatusCard
                
                // Airplane Mode & GPS Status
                airplaneModeCard
                
                // Current Trip Sync Status
                if let activeTrip = store.trips.first(where: { $0.status == .active }) {
                    currentTripSyncCard(trip: activeTrip)
                }
                
                // Quick Actions
                quickActionsCard
                
                // Watch Settings
                watchSettingsCard
                
                // Auto-Time Settings
                autoTimeSettingsCard
                
                // Debug Section (Collapsible)
                debugSectionCard
            }
            .padding()
        }
        .navigationTitle("⌚ Apple Watch")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .alert("Reset Watch Connection?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetWatchConnection()
            }
        } message: {
            Text("This will restart the connection between your iPhone and Apple Watch. Current trip data will be resynced.")
        }
        .alert("Disable Auto-Time Logging?", isPresented: $showingDisableAutoTimeConfirmation) {
            Button("Keep Enabled", role: .cancel) { }
            Button("Disable Anyway", role: .destructive) {
                autoTimeSettings.isEnabled = false
            }
        } message: {
            Text("Auto-time capture helps ensure accurate flight time logging. You'll need to manually enter all OUT/OFF/ON/IN times.")
        }
        .alert("Sync Successful!", isPresented: $showingSyncSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Current trip has been synced to Apple Watch")
        }
        .onReceive(timer) { _ in
            updateSyncStatus()
        }
        .onAppear {
            updateSyncStatus()
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connection Status")
                    .font(.headline)
                Spacer()
                connectionStatusBadge
            }
            
            // Visual Connection Indicator
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                Image(systemName: connectionArrowIcon)
                    .font(.system(size: 24))
                    .foregroundColor(connectionStatusColor)
                
                Image(systemName: "applewatch")
                    .font(.system(size: 32))
                    .foregroundColor(watchStatusColor)
            }
            .padding(.vertical, 8)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Session:")
                    Spacer()
                    Text(sessionStateText)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Watch App:")
                    Spacer()
                    Text(phoneWatchConnectivity.isWatchPaired ? "Installed ✅" : "Not Installed ❌")
                        .foregroundColor(phoneWatchConnectivity.isWatchPaired ? .green : .red)
                }
                
                HStack {
                    Text("Reachable:")
                    Spacer()
                    if phoneWatchConnectivity.isWatchConnected {
                        Text("Active ✅")
                            .foregroundColor(.green)
                    } else {
                        Text("Background 💤")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("Last Sync:")
                    Spacer()
                    Text(timeAgoString(from: lastSyncTime))
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Flight Mode Card
    
    private var airplaneModeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Location Services")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // GPS Status
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(locationManager.isLocationAuthorized ? .green : .red)
                        .font(.system(size: 18))
                    Text("GPS:")
                    Spacer()
                    Text(gpsStatusText)
                        .foregroundColor(locationManager.isLocationAuthorized ? .green : .red)
                        .font(.system(size: 15, weight: .semibold))
                }
                
                // Auto-Time Status
                HStack {
                    Image(systemName: autoTimeSettings.isEnabled ? "clock.badge.checkmark.fill" : "clock.badge.xmark.fill")
                        .foregroundColor(autoTimeSettings.isEnabled ? .green : .orange)
                        .font(.system(size: 18))
                    Text("Auto-Time Logging:")
                    Spacer()
                    Text(autoTimeSettings.isEnabled ? "Active ✅" : "Disabled")
                        .foregroundColor(autoTimeSettings.isEnabled ? .green : .orange)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .font(.subheadline)
            
            if locationManager.isLocationAuthorized && autoTimeSettings.isEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("GPS works in airplane mode - auto-time logging will continue normally")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Current Trip Sync Card
    
    private func currentTripSyncCard(trip: Trip) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Trip Sync")
                    .font(.headline)
                Spacer()
                if hasLegMismatch {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Trip Number:")
                    Spacer()
                    Text(trip.tripNumber.isEmpty ? "No Number" : trip.tripNumber)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Aircraft:")
                    Spacer()
                    Text(trip.aircraft)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Phone leg status
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    Text("Phone: Leg \(phoneCurrentLeg ?? 0) of \(trip.legs.count)")
                    Spacer()
                    if !hasLegMismatch {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                // Watch leg status
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundColor(watchStatusColor)
                    Text("Watch: Leg \(watchCurrentLeg ?? 0) of \(trip.legs.count)")
                    Spacer()
                    if hasLegMismatch {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if hasLegMismatch {
                    Text("⚠️ SYNC ISSUE DETECTED")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.vertical, 4)
                    
                    Button {
                        fixLegMismatch()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Fix Sync Issue")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                }
                
                // Current leg times
                if let currentLeg = getCurrentLeg(from: trip) {
                    Divider()
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("OUT: \(currentLeg.outTime)")
                            Spacer()
                            Text("OFF: \(currentLeg.offTime)")
                        }
                        HStack {
                            Text("ON: \(currentLeg.onTime)")
                            Spacer()
                            Text("IN: \(currentLeg.inTime)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(hasLegMismatch ? Color.orange.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasLegMismatch ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - Quick Actions Card
    
    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Sync Now
                Button {
                    syncNow()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sync Now")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                
                // Force Sync Current Trip
                Button {
                    forceSyncCurrentTrip()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Force Sync Trip to Watch")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                
                // Reset Connection
                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Reset Watch Connection")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Watch Settings Card
    
    private var watchSettingsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Watch Settings")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .foregroundColor(.pink)
                        Text("Enable Watch Sync")
                    }
                }
                .disabled(true) // Always on
                
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Auto-Sync on Changes")
                    }
                }
                .disabled(true) // Always on
                
                Text("Watch sync is always enabled to keep your devices in sync")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Auto-Time Settings Card
    
    private var autoTimeSettingsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Auto-Time Logging")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { autoTimeSettings.isEnabled },
                    set: { newValue in
                        if newValue {
                            // Turning ON - just enable
                            autoTimeSettings.isEnabled = true
                        } else {
                            // Turning OFF - show confirmation
                            showingDisableAutoTimeConfirmation = true
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(.green)
                        Text("Enable GPS Auto-Time")
                    }
                }
                
                if autoTimeSettings.isEnabled {
                                    VStack(spacing: 8) {
                                        // ✅ MODIFIED: Custom binding to force sync immediately on toggle
                                        Toggle("Use Zulu Time", isOn: Binding(
                                            get: { autoTimeSettings.useZuluTime },
                                            set: { newValue in
                                                // 1. Update the setting locally
                                                autoTimeSettings.useZuluTime = newValue
                                                
                                                // 2. ⚡️ FORCE SYNC IMMEDIATELY
                                                print("⚡️ Zulu toggle changed, forcing watch sync...")
                                                phoneWatchConnectivity.syncCurrentLegToWatch()
                                            }
                                        ))
                                    }
                                    
                                    Text("GPS will automatically detect takeoff/landing and log OUT/OFF/ON/IN times")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("⚠️ Auto-time logging is disabled. You must manually enter all times.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
    
    // MARK: - Debug Section Card
    
    private var debugSectionCard: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation {
                    isDebugExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Connection Details")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isDebugExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isDebugExpanded {
                VStack(spacing: 8) {
                    debugRow("Session State", value: sessionStateText)
                    debugRow("Paired", value: phoneWatchConnectivity.isWatchPaired ? "Yes" : "No")
                    debugRow("Watch App", value: phoneWatchConnectivity.isWatchPaired ? "Installed" : "Not Installed")
                    debugRow("Reachable", value: phoneWatchConnectivity.isWatchConnected ? "Yes" : "No")
                    debugRow("Activation State", value: String(describing: WCSession.default.activationState.rawValue))
                    
                    Button {
                        showingDebugLog = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Full Debug Log")
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func debugRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatus: WatchConnectionStatus {
        guard phoneWatchConnectivity.isWatchPaired else {
            return .notInstalled
        }
        
        if hasLegMismatch {
            return .outOfSync
        }
        
        // Connected if paired (reachable just means app is in foreground)
        return .connected
    }
    
    private var connectionStatusColor: Color {
        switch connectionStatus {
        case .connected: return phoneWatchConnectivity.isWatchConnected ? .green : .blue
        case .outOfSync: return .yellow
        case .disconnected: return .red
        case .notInstalled: return .gray
        }
    }
    
    private var watchStatusColor: Color {
        phoneWatchConnectivity.isWatchPaired ? .pink : .gray
    }
    
    private var connectionArrowIcon: String {
        if phoneWatchConnectivity.isWatchConnected {
            // Active - bidirectional arrows
            return "arrow.left.arrow.right"
        } else if phoneWatchConnectivity.isWatchPaired {
            // Connected but backgrounded - single direction (can still receive)
            return "arrow.right"
        } else {
            return "xmark"
        }
    }
    
    private var connectionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(connectionStatus.displayText)
                .font(.caption)
                .foregroundColor(connectionStatusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(connectionStatusColor.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var sessionStateText: String {
        let state = WCSession.default.activationState
        
        switch state {
        case .activated: return "Activated"
        case .inactive: return "Inactive"
        case .notActivated: return "Not Activated"
        @unknown default: return "Unknown"
        }
    }
    
    private var isAirplaneModeEnabled: Bool {
        // iOS doesn't provide a reliable way to detect airplane mode
        // We can't distinguish between airplane mode and just having cellular off
        // So we'll remove this detection and focus on what we CAN detect: GPS status
        return false
    }
    
    private var gpsStatusText: String {
        if locationManager.isLocationAuthorized {
            return "Active ✅"
        } else {
            return "Disabled ❌"
        }
    }
    
    private var hasLegMismatch: Bool {
        guard let phone = phoneCurrentLeg, let watch = watchCurrentLeg else {
            return false
        }
        return phone != watch
    }
    
    // MARK: - Helper Functions
    
    private func updateSyncStatus() {
        lastSyncTime = Date()
        
        // Get current leg numbers
        if let activeTrip = store.trips.first(where: { $0.status == .active }) {
            phoneCurrentLeg = getCurrentLegIndex(from: activeTrip)
            
            // TODO: Get watch current leg from WatchConnectivity
            // For now, simulate or retrieve from actual watch data
            watchCurrentLeg = phoneCurrentLeg // Placeholder
        }
    }
    
    private func getCurrentLegIndex(from trip: Trip) -> Int? {
        // Find the current active leg (first leg with incomplete times)
        for (index, leg) in trip.legs.enumerated() {
            if leg.inTime.isEmpty || leg.inTime == "0000" {
                return index + 1 // 1-indexed
            }
        }
        return trip.legs.count // All legs complete
    }
    
    private func getCurrentLeg(from trip: Trip) -> FlightLeg? {
        guard let index = getCurrentLegIndex(from: trip), index > 0 else {
            return nil
        }
        return trip.legs[index - 1]
    }
    
    private func syncNow() {
        phoneWatchConnectivity.syncCurrentLegToWatch()
        lastSyncTime = Date()
        showingSyncSuccess = true
    }
    
    private func forceSyncCurrentTrip() {
        phoneWatchConnectivity.syncCurrentLegToWatch()
        lastSyncTime = Date()
        showingSyncSuccess = true
    }
    
    private func fixLegMismatch() {
        forceSyncCurrentTrip()
    }
    
    private func resetWatchConnection() {
        WCSession.default.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            forceSyncCurrentTrip()
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 10 {
            return "Just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Connection Status Enum

enum WatchConnectionStatus {
    case connected       // Green/Blue - paired and working
    case outOfSync      // Yellow - connected but leg mismatch
    case disconnected   // Red - not reachable
    case notInstalled   // Gray - app not on watch
    
    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .outOfSync: return "Out of Sync"
        case .disconnected: return "Disconnected"
        case .notInstalled: return "Not Installed"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AppleWatchStatusView(
            phoneWatchConnectivity: PhoneWatchConnectivity.shared,
            locationManager: PilotLocationManager(),
            opsManager: OPSCallingManager(),
            autoTimeSettings: AutoTimeSettings.shared
        )
        .environmentObject(LogBookStore())
    }
}

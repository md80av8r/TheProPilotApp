//
//  WatchConnectivityStatusView.swift
//  TheProPilotApp - iPhone Watch Connectivity Status with Improved Sync Display
//

import SwiftUI
import WatchConnectivity

struct WatchConnectivityStatusView: View {
    @ObservedObject private var watchManager = PhoneWatchConnectivity.shared
    @State private var lastSyncTime: Date?
    @State private var showingDiagnostics = false
    @State private var connectionHistory: [PhoneConnectionEvent] = []
    @State private var animationScale: CGFloat = 1.0
    @State private var isExpanded = false
    
    private var isWatchReachable: Bool {
        WCSession.default.isReachable
    }
    
    private var isWatchPaired: Bool {
        WCSession.default.isPaired
    }
    
    private var isWatchAppInstalled: Bool {
        WCSession.default.isWatchAppInstalled
    }
    
    var body: some View {
        List {
            // MARK: - Enhanced Connection Status Section
            Section {
                enhancedConnectionStatusRow
                
                // Sync Metrics Display
                if watchManager.syncState != .notPaired {
                    syncMetricsDisplay
                }
                
                if isWatchReachable {
                    activeSyncStatusRows
                } else {
                    notConnectedStatus
                }
            } header: {
                Text("Apple Watch Connection")
                    .foregroundColor(.white)
            }
            .listRowBackground(LogbookTheme.navyLight)
            
            // MARK: - Current Duty Status
            if watchManager.isDutyTimerRunning {
                Section {
                    currentDutyStatusRows
                } header: {
                    Text("Active Duty")
                        .foregroundColor(.white)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // MARK: - Flight Data Status
            if let flight = watchManager.currentFlight {
                Section {
                    flightDataRows(flight)
                } header: {
                    Text("Current Flight")
                        .foregroundColor(.white)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // MARK: - Connection Actions
            Section {
                connectionActionButtons
            } header: {
                Text("Actions")
                    .foregroundColor(.white)
            }
            .listRowBackground(LogbookTheme.navyLight)
            
            // MARK: - Diagnostics
            Section {
                diagnosticsButton
            } header: {
                Text("Diagnostics")
                    .foregroundColor(.white)
            }
            .listRowBackground(LogbookTheme.navyLight)
        }
        .background(LogbookTheme.navy)
        .scrollContentBackground(.hidden)
        .navigationTitle("Watch Status")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDiagnostics) {
            PhoneWatchDiagnosticsView(connectionHistory: $connectionHistory)
        }
        .onAppear {
            checkConnectionStatus()
            watchManager.evaluateSyncHealth()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            watchManager.evaluateSyncHealth()
        }
    }
    
    // MARK: - Enhanced Connection Status Row
    private var enhancedConnectionStatusRow: some View {
        VStack(spacing: 12) {
            // Main connection status
            HStack {
                // Animated Status Icon
                ZStack {
                    Circle()
                        .fill(syncStateColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: syncStateIcon)
                        .font(.title2)
                        .foregroundColor(syncStateColor)
                        .rotationEffect(.degrees(watchManager.syncState == .syncInProgress ? 360 : 0))
                        .animation(
                            watchManager.syncState == .syncInProgress ?
                                .linear(duration: 2).repeatForever(autoreverses: false) :
                                .default,
                            value: watchManager.syncState
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(watchManager.syncState.rawValue)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        syncHealthBadge
                    }
                    
                    Text(syncDetailText)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Live indicator
                if watchManager.syncState == .synced {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.3), lineWidth: 4)
                                .scaleEffect(animationScale)
                        )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Sync Metrics Display
    private var syncMetricsDisplay: some View {
        VStack(spacing: 12) {
            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(
                    icon: "clock",
                    title: "Last Sync",
                    value: lastSyncText,
                    color: syncTimeColor
                )
                
                metricCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Pending",
                    value: "\(watchManager.syncMetrics.pendingChanges)",
                    color: watchManager.syncMetrics.pendingChanges > 0 ? .orange : .green
                )
                
                metricCard(
                    icon: "exclamationmark.triangle",
                    title: "Failed",
                    value: "\(watchManager.syncMetrics.failedAttempts)",
                    color: watchManager.syncMetrics.failedAttempts > 0 ? .red : .green
                )
                
                metricCard(
                    icon: "number",
                    title: "Version",
                    value: "v\(watchManager.syncMetrics.dataVersion)",
                    color: .blue
                )
            }
            
            // Error display if present
            if let error = watchManager.lastSyncError {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func metricCard(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Sync State Helpers
    private var syncStateColor: Color {
        switch watchManager.syncState {
        case .synced: return .green
        case .syncInProgress: return .blue
        case .bluetoothOnly: return .yellow
        case .dataStale: return .orange
        case .notPaired, .syncError: return .red
        }
    }
    
    private var syncStateIcon: String {
        switch watchManager.syncState {
        case .synced: return "checkmark.circle.fill"
        case .syncInProgress: return "arrow.triangle.2.circlepath"
        case .bluetoothOnly: return "dot.radiowaves.left.and.right"
        case .dataStale: return "exclamationmark.triangle"
        case .notPaired: return "applewatch.slash"
        case .syncError: return "xmark.circle"
        }
    }
    
    private var syncDetailText: String {
        if !isWatchPaired {
            return "Pair your Apple Watch to enable sync"
        } else if !isWatchAppInstalled {
            return "Install ProPilot on your Apple Watch"
        } else if !isWatchReachable {
            return "Watch paired but not reachable - open app on watch"
        } else if let lastSync = watchManager.syncMetrics.lastSyncTime {
            let timeSince = Date().timeIntervalSince(lastSync)
            return "Last synced \(formatTimeAgo(timeSince))"
        } else {
            return "Never synced - tap to sync now"
        }
    }
    
    private var syncHealthBadge: some View {
        Text("\(Int(watchManager.syncMetrics.syncHealthScore))%")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(healthScoreColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var healthScoreColor: Color {
        let score = watchManager.syncMetrics.syncHealthScore
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }
    
    private var lastSyncText: String {
        guard let lastSync = watchManager.syncMetrics.lastSyncTime else {
            return "Never"
        }
        return formatTimeAgo(Date().timeIntervalSince(lastSync))
    }
    
    private var syncTimeColor: Color {
        guard let timeSince = watchManager.syncMetrics.timeSinceSync else {
            return .red
        }
        
        if timeSince < 300 { return .green }
        if timeSince < 900 { return .yellow }
        if timeSince < 3600 { return .orange }
        return .red
    }
    
    private func formatTimeAgo(_ interval: TimeInterval) -> String {
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
    
    // MARK: - Active Sync Status (Existing)
    private var activeSyncStatusRows: some View {
        Group {
            HStack {
                Label("Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.gray)
                Spacer()
                Text(isWatchReachable ? "Connected" : "Disconnected")
                    .foregroundColor(isWatchReachable ? .green : .red)
            }
            
            HStack {
                Label("Data Sync", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.gray)
                Spacer()
                Text(watchManager.syncMetrics.isDataCurrent ? "Current" : "Out of Date")
                    .foregroundColor(watchManager.syncMetrics.isDataCurrent ? .green : .orange)
            }
            
            HStack {
                Label("App Installed", systemImage: "app.badge.checkmark")
                    .foregroundColor(.gray)
                Spacer()
                Text(isWatchAppInstalled ? "Yes" : "No")
                    .foregroundColor(isWatchAppInstalled ? .green : .orange)
            }
        }
    }
    
    private var notConnectedStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Watch Not Reachable", systemImage: "exclamationmark.triangle")
                .foregroundColor(.orange)
            
            Text("Make sure your Watch is unlocked and nearby. Open the ProPilot Watch app to enable real-time sync.")
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
    
    private var lastSyncTimeText: String {
        guard let lastSync = watchManager.syncMetrics.lastSyncTime else {
            return "Never"
        }
        
        let interval = Date().timeIntervalSince(lastSync)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: lastSync)
        }
    }
    
    // MARK: - Current Duty Status
    private var currentDutyStatusRows: some View {
        Group {
            HStack {
                Label("Status", systemImage: "clock.fill")
                    .foregroundColor(.green)
                Spacer()
                Text("On Duty")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
            
            if let startTime = watchManager.dutyStartTime {
                HStack {
                    Label("Started", systemImage: "play.circle")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(startTime))
                        .foregroundColor(.white)
                }
                
                HStack {
                    Label("Duration", systemImage: "timer")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatDuration(from: startTime))
                        .foregroundColor(.white)
                        .fontDesign(.monospaced)
                }
            }
        }
    }
    
    // MARK: - Flight Data Rows
    private func flightDataRows(_ flight: WatchFlightData) -> some View {
        Group {
            if let departure = flight.departure, let arrival = flight.arrival {
                HStack {
                    Label("Route", systemImage: "airplane")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(departure) → \(arrival)")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            
            HStack {
                Label("Current Leg", systemImage: "list.number")
                    .foregroundColor(.gray)
                Spacer()
                Text("Leg \(watchManager.currentLegIndex + 1)")
                    .foregroundColor(.white)
            }
            
            // Flight times if available
            if let outTime = flight.outTime {
                timeRow(label: "OUT", time: outTime, color: .blue)
            }
            if let offTime = flight.offTime {
                timeRow(label: "OFF", time: offTime, color: .green)
            }
            if let onTime = flight.onTime {
                timeRow(label: "ON", time: onTime, color: .orange)
            }
            if let inTime = flight.inTime {
                timeRow(label: "IN", time: inTime, color: .purple)
            }
        }
    }
    
    private func timeRow(label: String, time: Date, color: Color) -> some View {
        HStack {
            Label(label, systemImage: "clock")
                .foregroundColor(color)
            Spacer()
            Text(formatTime(time))
                .foregroundColor(.white)
                .fontDesign(.monospaced)
        }
    }
    
    // MARK: - Connection Actions
    private var connectionActionButtons: some View {
        Group {
            Button(action: {
                watchManager.syncCurrentLegToWatch()
            }) {
                Label("Force Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            }
            .disabled(watchManager.syncState == .syncInProgress)
            
            Button(action: {
                sendTestPing()
            }) {
                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.purple)
            }
            
            Button(action: {
                refreshConnectionStatus()
            }) {
                Label("Refresh Status", systemImage: "arrow.clockwise")
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Diagnostics
    private var diagnosticsButton: some View {
        Button(action: {
            showingDiagnostics = true
        }) {
            Label("View Detailed Diagnostics", systemImage: "stethoscope")
                .foregroundColor(.purple)
        }
    }
    
    // MARK: - Actions
    private func checkConnectionStatus() {
        lastSyncTime = Date()
        
        // Start pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
            animationScale = 1.3
        }
        
        logConnectionEvent(action: "Status Check")
    }
    
    private func sendTestPing() {
        watchManager.sendPingToWatch()
        logConnectionEvent(action: "Manual Ping")
    }
    
    private func refreshConnectionStatus() {
        watchManager.evaluateSyncHealth()
        lastSyncTime = Date()
        logConnectionEvent(action: "Manual Refresh")
    }
    
    private func logConnectionEvent(action: String) {
        let event = PhoneConnectionEvent(
            timestamp: Date(),
            isReachable: isWatchReachable,
            isPaired: isWatchPaired,
            isAppInstalled: isWatchAppInstalled,
            activationState: WCSession.default.activationState,
            action: action,
            syncState: watchManager.syncState.rawValue
        )
        connectionHistory.insert(event, at: 0)
        if connectionHistory.count > 100 {
            connectionHistory.removeLast()
        }
    }
    
    // MARK: - Formatters
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(from start: Date) -> String {
        let duration = Int(Date().timeIntervalSince(start))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - Connection Event Model (Updated)
struct PhoneConnectionEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let isReachable: Bool
    let isPaired: Bool
    let isAppInstalled: Bool
    let activationState: WCSessionActivationState
    var action: String
    var syncState: String = ""
}

// MARK: - Diagnostics View (Enhanced)
struct PhoneWatchDiagnosticsView: View {
    @Binding var connectionHistory: [PhoneConnectionEvent]
    @ObservedObject private var watchManager = PhoneWatchConnectivity.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Sync Health Section
                Section {
                    syncHealthRows
                } header: {
                    Text("Sync Health")
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                Section {
                    systemInfoRows
                } header: {
                    Text("System Information")
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                Section {
                    ForEach(connectionHistory) { event in
                        connectionEventRow(event)
                    }
                } header: {
                    HStack {
                        Text("Connection History")
                        Spacer()
                        Button("Clear") {
                            connectionHistory.removeAll()
                        }
                        .font(.caption)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Diagnostics")
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
    
    private var syncHealthRows: some View {
        Group {
            diagnosticRow(
                label: "Sync Health Score",
                value: "\(Int(watchManager.syncMetrics.syncHealthScore))%",
                status: watchManager.syncMetrics.syncHealthScore >= 80
            )
            diagnosticRow(
                label: "Data Version",
                value: "v\(watchManager.syncMetrics.dataVersion)"
            )
            diagnosticRow(
                label: "Pending Changes",
                value: "\(watchManager.syncMetrics.pendingChanges)",
                status: watchManager.syncMetrics.pendingChanges == 0
            )
            diagnosticRow(
                label: "Failed Attempts",
                value: "\(watchManager.syncMetrics.failedAttempts)",
                status: watchManager.syncMetrics.failedAttempts == 0
            )
            if let lastSync = watchManager.syncMetrics.lastSyncTime {
                diagnosticRow(
                    label: "Last Sync",
                    value: DateFormatter.localizedString(from: lastSync, dateStyle: .none, timeStyle: .medium)
                )
            } else {
                diagnosticRow(label: "Last Sync", value: "Never", status: false)
            }
        }
    }
    
    private var systemInfoRows: some View {
        Group {
            diagnosticRow(label: "WatchConnectivity Supported", value: "\(WCSession.isSupported())")
            diagnosticRow(label: "Watch App Installed", value: "\(WCSession.default.isWatchAppInstalled)")
            diagnosticRow(label: "Complication Enabled", value: "\(WCSession.default.isComplicationEnabled)")
            diagnosticRow(label: "Is Paired", value: "\(WCSession.default.isPaired)")
            diagnosticRow(label: "Is Reachable", value: "\(WCSession.default.isReachable)")
            diagnosticRow(label: "Activation State", value: activationStateDescription())
        }
    }
    
    private func diagnosticRow(label: String, value: String, status: Bool? = nil) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
                .font(.subheadline)
            Spacer()
            
            if let status = status {
                Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.caption)
                    .foregroundColor(status ? .green : .red)
            }
            
            Text(value)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    private func connectionEventRow(_ event: PhoneConnectionEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: event.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(event.isReachable ? .green : .orange)
                
                Text(formatTimestamp(event.timestamp))
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(event.action)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                statusPill(
                    icon: event.isReachable ? "applewatch" : "applewatch.slash",
                    text: event.isReachable ? "Reachable" : "Not Reachable",
                    color: event.isReachable ? .green : .orange
                )
                
                if !event.syncState.isEmpty {
                    statusPill(
                        icon: "arrow.triangle.2.circlepath",
                        text: event.syncState,
                        color: .blue
                    )
                }
                
                if event.isAppInstalled {
                    statusPill(
                        icon: "checkmark.circle",
                        text: "App",
                        color: .green
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.2))
        .cornerRadius(4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func activationStateDescription() -> String {
        switch WCSession.default.activationState {
        case .activated: return "Activated ✅"
        case .inactive: return "Inactive ⚠️"
        case .notActivated: return "Not Activated ❌"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Preview
struct WatchConnectivityStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchConnectivityStatusView()
        }
    }
}

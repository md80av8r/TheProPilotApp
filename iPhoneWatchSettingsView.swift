// iPhoneWatchSettingsView.swift - iPhone-side Watch Sync Controls
import SwiftUI
import WatchConnectivity

struct iPhoneWatchSettingsView: View {
    @ObservedObject var phoneWatchConnectivity: PhoneWatchConnectivity
    @ObservedObject var locationManager: PilotLocationManager
    
    @Environment(\.dismiss) var dismiss
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedback = true
    @State private var showingResetAlert = false
    @State private var isSyncing = false
    @State private var lastSyncResult: String?
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Connection Status Section
                Section {
                    // Main connection status
                    HStack {
                        Image(systemName: connectionIcon)
                            .foregroundColor(connectionColor)
                            .font(.title)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Watch")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(connectionStatusText)
                                .font(.caption)
                                .foregroundColor(connectionColor)
                        }
                        
                        Spacer()
                        
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentBlue))
                        } else if phoneWatchConnectivity.isWatchConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Detailed status using WCSession directly
                    if WCSession.isSupported() {
                        VStack(alignment: .leading, spacing: 8) {
                            WatchStatusRow(label: "Watch Paired", value: WCSession.default.isPaired ? "Yes" : "No", color: WCSession.default.isPaired ? .green : .red)
                            WatchStatusRow(label: "Watch Reachable", value: WCSession.default.isReachable ? "Yes" : "No", color: WCSession.default.isReachable ? .green : .orange)
                            WatchStatusRow(label: "App Installed", value: WCSession.default.isWatchAppInstalled ? "Yes" : "No", color: WCSession.default.isWatchAppInstalled ? .green : .red)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                } header: {
                    Text("Connection Status")
                        .foregroundColor(.white)
                }
                
                // MARK: - Sync Actions Section
                Section {
                    // Manual Sync Button
                    Button(action: performManualSync) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Send current trip data to watch")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentBlue))
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .disabled(isSyncing || !WCSession.default.isReachable)
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Test Connection
                    Button(action: testConnection) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Test Connection")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Send ping to verify watch communication")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(!WCSession.default.isPaired)
                    .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Sync Actions")
                        .foregroundColor(.white)
                }
                
                // MARK: - Last Sync Result
                if let result = lastSyncResult {
                    Section {
                        HStack {
                            Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(result.contains("✅") ? .green : .orange)
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    } header: {
                        Text("Last Action")
                            .foregroundColor(.white)
                    }
                }
                
                // MARK: - Watch Preferences Section
                Section {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentGreen)
                        .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Watch Preferences")
                        .foregroundColor(.white)
                }
                
                // MARK: - Troubleshooting Section
                Section {
                    Button(action: { showingResetAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("Reset Connection State")
                                .foregroundColor(.orange)
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Help text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Troubleshooting Tips:")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        Text("• Make sure Watch app is installed")
                        Text("• Keep iPhone and Watch close together")
                        Text("• Check that Bluetooth is enabled")
                        Text("• Try opening the Watch app manually")
                        Text("• Restart both devices if issues persist")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
                    .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Troubleshooting")
                        .foregroundColor(.white)
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Apple Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .alert("Reset Connection State", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    PhoneWatchConnectivity.shared.resetConnectionState()
                    lastSyncResult = "✅ Connection state reset"
                }
            } message: {
                Text("This will clear stuck message processing flags and refresh the connection status.")
            }
        }
    }
    
    // MARK: - Connection Status Helpers
    
    private var connectionIcon: String {
        guard WCSession.isSupported() else { return "applewatch.slash" }
        
        if !WCSession.default.isPaired {
            return "applewatch.slash"
        } else if WCSession.default.isReachable {
            return "applewatch.radiowaves.left.and.right"
        } else if phoneWatchConnectivity.isWatchConnected {
            return "applewatch"
        } else {
            return "applewatch.slash"
        }
    }
    
    private var connectionColor: Color {
        guard WCSession.isSupported() else { return .red }
        
        if WCSession.default.isReachable {
            return .green
        } else if phoneWatchConnectivity.isWatchConnected || WCSession.default.isPaired {
            return .orange
        } else {
            return .red
        }
    }
    
    private var connectionStatusText: String {
        guard WCSession.isSupported() else { return "Not Supported" }
        
        if !WCSession.default.isPaired {
            return "Not Paired"
        } else if !WCSession.default.isWatchAppInstalled {
            return "ProPilot App Not Installed on Watch"
        } else if WCSession.default.isReachable {
            return "Connected & Reachable"
        } else if phoneWatchConnectivity.isWatchConnected {
            return "Connected (Background)"
        } else {
            return "Paired but Not Reachable - Open Watch App"
        }
    }
    
    // MARK: - Actions
    
    private func performManualSync() {
        isSyncing = true
        lastSyncResult = nil
        
        phoneWatchConnectivity.syncCurrentLegToWatch()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSyncing = false
            lastSyncResult = "✅ Trip data sent to watch"
        }
    }
    
    private func testConnection() {
        lastSyncResult = nil
        phoneWatchConnectivity.testWatchConnection()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if WCSession.default.isReachable {
                lastSyncResult = "✅ Watch responded successfully"
            } else {
                lastSyncResult = "⚠️ Watch not responding - try opening watch app"
            }
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Watch Status Row Component
struct WatchStatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

#if DEBUG
struct iPhoneWatchSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        iPhoneWatchSettingsView(
            phoneWatchConnectivity: PhoneWatchConnectivity.shared,
            locationManager: PilotLocationManager()
        )
    }
}
#endif

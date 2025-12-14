// WatchSettingsView.swift - Enhanced Settings View for Apple Watch with Time Zone Support
import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var showingResetConfirmation = false
    
    // ✅ Add time zone preference toggle
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    var body: some View {
        List {
            // MARK: - Connection Status
            Section {
                connectionStatusView
            }
            
            // MARK: - ✅ NEW: Time Zone Preference
            Section {
                Toggle(isOn: $useZuluTime) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: useZuluTime ? "globe" : "location.fill")
                                .foregroundColor(useZuluTime ? .blue : .orange)
                            Text(useZuluTime ? "Zulu Time (UTC)" : "Local Time")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text(useZuluTime ? "All times shown in UTC" : "Times shown in local timezone")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: useZuluTime) { oldValue, newValue in
                    print("⌚ Time zone preference changed to: \(newValue ? "Zulu" : "Local")")
                    // Force UI refresh
                    connectivityManager.objectWillChange.send()
                }
            } header: {
                Text("Time Display")
            } footer: {
                Text("Choose how flight times are displayed on your watch. Times are always stored as UTC regardless of this setting.")
                    .font(.caption2)
            }
            
            // MARK: - Current Trip Info
            if connectivityManager.currentTripId != nil {
                Section("Active Trip") {
                    HStack {
                        Image(systemName: "airplane")
                            .foregroundColor(.blue)
                        Text("Leg \(connectivityManager.currentLegIndex + 1)")
                            .font(.caption)
                    }
                    
                    if let flight = connectivityManager.currentFlight {
                        HStack {
                            Text("\(flight.departureAirport) → \(flight.arrivalAirport)")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            
            // MARK: - Duty Timer
            if connectivityManager.isDutyTimerRunning {
                Section("Duty Time") {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text(connectivityManager.elapsedDutyTime)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // MARK: - Quick Actions
            Section("Actions") {
                Button {
                    connectivityManager.sendPingToPhone()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Test Connection")
                            .font(.caption)
                    }
                }
                
                Button {
                    connectivityManager.ensureConnectivity()
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        Text("Reconnect")
                            .font(.caption)
                    }
                }
            }
            
            // MARK: - Debug Info
            Section("Debug") {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text(String(format: "%.0f kts", connectivityManager.currentSpeed))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("Airport")
                    Spacer()
                    Text(connectivityManager.currentAirport.isEmpty ? "---" : connectivityManager.currentAirport)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Reset Watch Data")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // MARK: - App Info
            Section {
                HStack {
                    Text("ProPilot Watch")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("v1.0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset Watch Data", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetWatchData()
            }
        } message: {
            Text("This will clear all flight data from your watch. Data on your iPhone will not be affected.")
        }
    }
    
    // MARK: - Connection Status View
    private var connectionStatusView: some View {
        VStack(spacing: 8) {
            // Status indicator
            HStack {
                Circle()
                    .fill(connectivityManager.isPhoneReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(connectivityManager.isPhoneReachable ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(connectivityManager.isPhoneReachable ? .green : .red)
            }
            
            // Status message
            Text(connectionStatusMessage)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
    
    private var connectionStatusMessage: String {
        if connectivityManager.isPhoneReachable {
            return "iPhone is nearby and reachable"
        } else {
            return "Make sure iPhone is unlocked and nearby"
        }
    }
    
    // MARK: - Actions
    private func resetWatchData() {
        // Clear all current flight data
        connectivityManager.currentFlight = nil
        connectivityManager.currentTripId = nil
        connectivityManager.currentLegIndex = 0
        connectivityManager.hasMoreLegs = false
        connectivityManager.dutyStartTime = nil
        connectivityManager.isDutyTimerRunning = false
        connectivityManager.currentAirport = ""
        connectivityManager.currentSpeed = 0.0
        
        print("⌚ Watch data reset")
    }
}

// MARK: - Preview
struct WatchSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchSettingsView()
                .environmentObject(WatchConnectivityManager.shared)
        }
    }
}

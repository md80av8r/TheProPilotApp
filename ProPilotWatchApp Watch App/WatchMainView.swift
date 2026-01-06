// WatchMainView.swift - Main watch navigation
import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var selectedTab = 0
    @State private var showingFBOAlert = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Tab 1: Duty Timer
                ModernDutyTimerView()
                    .environmentObject(connectivityManager)
                    .tag(0)

                // Tab 2: Flight Times - ✅ FIXED: Using FlightTimesWatchView with 2x2 grid
                FlightTimesWatchView()
                    .environmentObject(connectivityManager)
                    .tag(1)

                // Tab 3: OPS
                ModernOPSView()
                    .environmentObject(connectivityManager)
                    .tag(2)

                // Tab 4: Settings
                ModernWatchSettingsView()
                    .environmentObject(connectivityManager)
                    .tag(3)
            }
            .tabViewStyle(.page)

            // FBO Alert Overlay
            if showingFBOAlert, let alert = connectivityManager.pendingFBOAlert {
                FBOAlertWatchView(alert: alert) {
                    withAnimation {
                        showingFBOAlert = false
                        connectivityManager.dismissFBOAlert()
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onChange(of: connectivityManager.pendingFBOAlert?.id) { _, newValue in
            if newValue != nil {
                withAnimation {
                    showingFBOAlert = true
                }
            }
        }
    }
}

// MARK: - FBO Alert Watch View
struct FBOAlertWatchView: View {
    let alert: FBOAlertData
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Radio icon
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)

                // FBO Name
                Text("Contact \(alert.fboName)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Airport and distance
                HStack(spacing: 8) {
                    Text(alert.airportCode)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text("•")
                        .foregroundColor(.gray)

                    Text("\(String(format: "%.0f", alert.distanceNM)) nm")
                        .font(.callout)
                        .foregroundColor(.gray)
                }

                // UNICOM Frequency
                if let unicom = alert.unicomFrequency {
                    HStack {
                        Text("UNICOM:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(unicom)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(8)
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding()
        }
    }
}

// MARK: - Modern Duty Timer View
struct ModernDutyTimerView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection Status Indicator
                connectionStatusBadge
                
                // Duty Timer Display
                if connectivityManager.isDutyTimerRunning {
                    VStack(spacing: 12) {
                        Text("ON DUTY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text(connectivityManager.elapsedDutyTime)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if let startTime = connectivityManager.dutyStartTime {
                            Text("Started \(formatTime(startTime))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("Off Duty")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
                
                // Quick Actions
                if !connectivityManager.isDutyTimerRunning {
                    Button(action: {
                        connectivityManager.sendStartDuty()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Duty")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        connectivityManager.sendEndDuty()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("End Duty")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Duty")
    }
    
    private var connectionStatusBadge: some View {
        HStack {
            Circle()
                .fill(connectivityManager.isPhoneReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(connectivityManager.isPhoneReachable ? "Connected" : "Disconnected")
                .font(.caption2)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Modern OPS View
struct ModernOPSView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var showingCallConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection Status
                connectionStatusBadge
                
                // Emergency Call
                Button(action: {
                    showingCallConfirmation = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("Call OPS")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Emergency Contact")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // Current Airport
                VStack(spacing: 4) {
                    Text("Quick Access")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("Emergency OPS Contact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("OPS")
        .alert("Call Operations?", isPresented: $showingCallConfirmation) {
            Button("Call", role: .destructive) {
                connectivityManager.sendCallOPS()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will initiate a call to operations on your iPhone")
        }
    }
    
    private var connectionStatusBadge: some View {
        HStack {
            Circle()
                .fill(connectivityManager.isPhoneReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(connectivityManager.isPhoneReachable ? "Connected" : "Disconnected")
                .font(.caption2)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Modern Watch Settings View
struct ModernWatchSettingsView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    Circle()
                        .fill(connectivityManager.isPhoneReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectivityManager.isPhoneReachable ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    connectivityManager.sendPingToPhone()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Test Connection")
                    }
                }
                
                Button(action: {
                    connectivityManager.ensureConnectivity()
                }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        Text("Reconnect")
                    }
                }
            }
            
            Section("Info") {
                if let tripId = connectivityManager.currentTripId {
                    Text("Trip ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tripId.uuidString.prefix(8))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .monospaced()
                }
                
                HStack {
                    Text("Duty Status")
                    Spacer()
                    Text(connectivityManager.isDutyTimerRunning ? "On Duty" : "Off Duty")
                        .font(.caption)
                        .foregroundColor(connectivityManager.isDutyTimerRunning ? .green : .gray)
                }
                
                HStack {
                    Text("Phone Link")
                    Spacer()
                    Text(connectivityManager.isPhoneReachable ? "Active" : "Background")
                        .font(.caption)
                        .foregroundColor(connectivityManager.isPhoneReachable ? .green : .orange)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Preview
struct WatchMainView_Previews: PreviewProvider {
    static var previews: some View {
        WatchMainView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}

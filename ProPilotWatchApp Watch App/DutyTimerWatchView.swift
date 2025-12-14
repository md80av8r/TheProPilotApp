// DutyTimerWatchView.swift - Duty Timer Watch Interface
import SwiftUI

struct DutyTimerWatchView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(spacing: 8) {
            // Connection Status - Use the new SyncStatusView
            SyncStatusView()
                .environmentObject(connectivityManager)
            
            // Current Airport
            if !connectivityManager.currentAirport.isEmpty {
                Text(connectivityManager.currentAirport)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Duty Timer
            if connectivityManager.dutyIsRunning {
                VStack(spacing: 4) {
                    Text("ON DUTY")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text(dutyTimeString)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                    
                    Button("End Duty") {
                        sendEndDuty()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .font(.caption)
                }
            } else {
                VStack(spacing: 8) {
                    Text("OFF DUTY")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button("Start Duty") {
                        sendStartDuty()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .font(.caption)
                }
            }
            
            // Quick OUT/OFF/ON/IN buttons
            HStack(spacing: 6) {
                Button("OUT") { connectivityManager.sendTimeEntry(timeType: "OUT", time: Date()) }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .font(.caption2)
                Button("OFF") { connectivityManager.sendTimeEntry(timeType: "OFF", time: Date()) }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .font(.caption2)
                Button("ON") { connectivityManager.sendTimeEntry(timeType: "ON", time: Date()) }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .font(.caption2)
                Button("IN") { connectivityManager.sendTimeEntry(timeType: "IN", time: Date()) }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .font(.caption2)
            }
            
            // Telemetry badges
            HStack(spacing: 8) {
                if connectivityManager.currentSpeed > 0 {
                    VStack(spacing: 2) {
                        Text("Speed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(connectivityManager.currentSpeed)) kts")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                if connectivityManager.currentAltitude > 0 {
                    VStack(spacing: 2) {
                        Text("Altitude")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(connectivityManager.currentAltitude)) ft")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
        .onAppear {
            requestDutyStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    private var dutyTimeString: String {
        guard let startTime = connectivityManager.dutyStartTime else { return "00:00:00" }
        let duration = currentTime.timeIntervalSince(startTime)
        return formatDuration(duration)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Messaging Methods
    
    private func sendStartDuty() {
        let message: [String: Any] = [
            "type": "startDuty",
            "timestamp": Date().timeIntervalSince1970
        ]
        connectivityManager.sendMessageToPhone(message, description: "start duty timer")
    }
    
    private func sendEndDuty() {
        let message: [String: Any] = [
            "type": "endDuty",
            "timestamp": Date().timeIntervalSince1970
        ]
        connectivityManager.sendMessageToPhone(message, description: "end duty timer")
    }
    
    private func requestDutyStatus() {
        let message: [String: Any] = [
            "type": "requestDutyStatus",
            "timestamp": Date().timeIntervalSince1970
        ]
        if let isReachable = connectivityManager.isReachable, isReachable {
            connectivityManager.sendMessageToPhoneWithReply(
                message,
                description: "request duty status",
                replyHandler: { reply in
                    // Expect keys: isRunning (Bool), startTimestamp (Double), airport (String), speed (Double), altitude (Double)
                    DispatchQueue.main.async {
                        if let running = reply["isRunning"] as? Bool {
                            connectivityManager.dutyIsRunning = running
                        }
                        if let ts = reply["startTimestamp"] as? Double {
                            connectivityManager.dutyStartTime = Date(timeIntervalSince1970: ts)
                        }
                        if let airport = reply["airport"] as? String {
                            connectivityManager.currentAirport = airport
                        }
                        if let speed = reply["speed"] as? Double {
                            connectivityManager.currentSpeed = speed
                        }
                        if let altitude = reply["altitude"] as? Double {
                            connectivityManager.currentAltitude = altitude
                        }
                    }
                },
                errorHandler: { error in
                    print("⌚ Duty status request failed: \(error.localizedDescription)")
                }
            )
        } else {
            connectivityManager.sendMessageToPhone(message, description: "request duty status")
        }
    }
}

// MARK: - Preview
struct DutyTimerWatchView_Previews: PreviewProvider {
    static var previews: some View {
        DutyTimerWatchView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}

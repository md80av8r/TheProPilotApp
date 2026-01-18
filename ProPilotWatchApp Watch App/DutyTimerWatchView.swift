// DutyTimerWatchView.swift - Duty Timer Watch Interface
import SwiftUI

struct DutyTimerWatchView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var currentTime = Date()
    @State private var showPlanningTripAlert = false
    @State private var planningTripInfo: (tripNumber: String, tripId: String, departure: String, arrival: String, legCount: Int)?
    @State private var showEndDutyConfirmation = false
    
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
                        showEndDutyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .font(.caption)
                    .confirmationDialog("End Duty", isPresented: $showEndDutyConfirmation) {
                        Button("End & Complete Trip", role: .destructive) {
                            sendEndDuty()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will end your duty timer and complete your trip.")
                    }
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
        .alert("Trip Found", isPresented: $showPlanningTripAlert) {
            Button("Use Trip", role: .none) {
                confirmPlanningTrip()
            }
            Button("Create New", role: .cancel) {
                declinePlanningTrip()
            }
        } message: {
            if let tripInfo = planningTripInfo {
                Text("Trip \(tripInfo.tripNumber)\n\(tripInfo.departure) → \(tripInfo.arrival)\n\(tripInfo.legCount) leg(s)")
            }
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

        connectivityManager.sendMessageToPhoneWithReply(message, description: "start duty timer") { reply in
            // Check if phone is asking for confirmation of a planning trip
            if let status = reply["status"] as? String, status == "confirmTrip" {
                // Extract trip details
                let tripNumber = reply["tripNumber"] as? String ?? ""
                let tripId = reply["tripId"] as? String ?? ""
                let departure = reply["departure"] as? String ?? ""
                let arrival = reply["arrival"] as? String ?? ""
                let legCount = reply["legCount"] as? Int ?? 0

                // Store trip info and show alert
                self.planningTripInfo = (tripNumber, tripId, departure, arrival, legCount)
                self.showPlanningTripAlert = true

                print("📱 Planning trip found: \(tripNumber) (\(departure) → \(arrival))")
            } else {
                print("✅ Duty started directly (no planning trip found)")
            }
        } errorHandler: { error in
            print("❌ Failed to start duty: \(error.localizedDescription)")
        }
    }

    private func confirmPlanningTrip() {
        guard let tripInfo = planningTripInfo else { return }

        let message: [String: Any] = [
            "type": "confirmPlanningTrip",
            "tripId": tripInfo.tripId,
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager.sendMessageToPhone(message, description: "confirm planning trip")
        print("✅ Confirmed planning trip: \(tripInfo.tripNumber)")
    }

    private func declinePlanningTrip() {
        guard let tripInfo = planningTripInfo else { return }

        let message: [String: Any] = [
            "type": "declinePlanningTrip",
            "tripId": tripInfo.tripId,
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager.sendMessageToPhone(message, description: "decline planning trip")
        print("✅ Declined planning trip - creating new trip")
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

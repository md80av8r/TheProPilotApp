//
//  LiveActivityDebugView.swift
//  ProPilot
//
//  Debug view to monitor Live Activity status in real-time
//

import SwiftUI
import ActivityKit

struct LiveActivityDebugView: View {
    @ObservedObject var activityManager = PilotActivityManager.shared
    @State private var updateCount = 0
    @State private var currentTime = Date()
    @State private var shouldPulse = false
    
    // Timer to refresh the view every second for live updates
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.orange)
                    Text("Live Activity Debug")
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    // Live indicator
                    if activityManager.isActivityActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .opacity(shouldPulse ? 1.0 : 0.3)
                                .animation(.easeInOut(duration: 1).repeatForever(), value: shouldPulse)
                            
                            Text("LIVE")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }
                        .onAppear { shouldPulse = true }
                    }
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Status Section
                GroupBox(label: Label("Status", systemImage: "info.circle.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        StatusRow(label: "Activity Active", 
                                value: activityManager.isActivityActive ? "✅ YES" : "❌ NO",
                                color: activityManager.isActivityActive ? .green : .gray)
                        
                        StatusRow(label: "Current Phase", 
                                value: activityManager.currentPhase,
                                color: .blue)
                        
                        if let dutyStart = activityManager.dutyStartTime {
                            StatusRow(label: "Duty Started", 
                                    value: dutyStart.formatted(date: .omitted, time: .shortened),
                                    color: .orange)
                        }
                        
                        StatusRow(label: "Elapsed Time", 
                                value: activityManager.getDutyElapsedTime(),
                                color: .purple)
                        
                        if let lastUpdate = activityManager.lastUpdateTime {
                            StatusRow(label: "Last Update", 
                                    value: lastUpdate.formatted(date: .omitted, time: .complete),
                                    color: .mint)
                            
                            // Show time since last update
                            let timeSince = currentTime.timeIntervalSince(lastUpdate)
                            StatusRow(label: "Seconds Ago", 
                                    value: String(format: "%.0f sec", timeSince),
                                    color: timeSince < 70 ? .green : .orange)
                        } else {
                            StatusRow(label: "Last Update", 
                                    value: "Never",
                                    color: .gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Activity Details
                if activityManager.isActivityActive {
                    GroupBox(label: Label("Activity Details", systemImage: "airplane.circle.fill")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let activity = getCurrentActivity() {
                                StatusRow(label: "Trip", 
                                        value: activity.attributes.tripNumber,
                                        color: .blue)
                                
                                StatusRow(label: "Aircraft", 
                                        value: activity.attributes.aircraftType,
                                        color: .blue)
                                
                                StatusRow(label: "Route", 
                                        value: "\(activity.attributes.departure) → \(activity.attributes.arrival)",
                                        color: .blue)
                                
                                StatusRow(label: "Activity State", 
                                        value: "\(activity.activityState)",
                                        color: activity.activityState == .active ? .green : .red)
                                
                                StatusRow(label: "Activity ID", 
                                        value: activity.id,
                                        color: .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Controls
                GroupBox(label: Label("Test Controls", systemImage: "gamecontroller.fill")) {
                    VStack(spacing: 12) {
                        Button {
                            activityManager.testActivityWithAlert()
                        } label: {
                            Label("Start Test Activity", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(activityManager.isActivityActive)
                        
                        if activityManager.isActivityActive {
                            Button {
                                activityManager.endActivity()
                            } label: {
                                Label("End Activity", systemImage: "stop.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            
                            Button {
                                testPhaseUpdate()
                            } label: {
                                Label("Test Phase Update", systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button {
                            activityManager.logActiveActivities()
                        } label: {
                            Label("Print Debug Info to Console", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding(.vertical, 4)
                }
                
                // Instructions
                GroupBox(label: Label("How to View", systemImage: "questionmark.circle.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(number: "1", text: "Start a test activity above")
                        InstructionRow(number: "2", text: "Press Home button (swipe up)")
                        InstructionRow(number: "3", text: "Look at Dynamic Island (pill shape)")
                        InstructionRow(number: "4", text: "Long press to expand")
                        
                        Divider()
                        
                        Text("📱 Requires iPhone 14 Pro or newer Pro model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                // Device Info
                GroupBox(label: Label("Device Info", systemImage: "iphone")) {
                    VStack(alignment: .leading, spacing: 8) {
                        StatusRow(label: "Device", 
                                value: UIDevice.current.name,
                                color: .secondary)
                        
                        StatusRow(label: "System", 
                                value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                                color: .secondary)
                        
                        #if targetEnvironment(simulator)
                        StatusRow(label: "Environment", 
                                value: "Simulator",
                                color: .orange)
                        #else
                        StatusRow(label: "Environment", 
                                value: "Physical Device",
                                color: .green)
                        #endif
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Live Activity Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // Helper to get current activity (for display only)
    private func getCurrentActivity() -> Activity<PilotDutyAttributes>? {
        return Activity<PilotDutyAttributes>.activities.first { $0.activityState == .active }
    }
    
    private func testPhaseUpdate() {
        let phases = ["Pre-Flight", "Taxi Out", "Enroute", "Approach", "Taxi In"]
        let randomPhase = phases.randomElement() ?? "Enroute"
        activityManager.updateActivity(phase: randomPhase)
        updateCount += 1
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
                .textSelection(.enabled)
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveActivityDebugView()
    }
}

//
//  AutoTimeLoggingSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/27/25.
//


// AutoTimeLoggingSettingsView.swift - Enhanced Settings View
import SwiftUI

struct AutoTimeLoggingSettingsView: View {
    @ObservedObject private var autoTimeSettings = AutoTimeSettings.shared
    @StateObject private var speedMonitor = GPSSpeedMonitor()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Time Rounding Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Round Times to 5 Minutes", isOn: $autoTimeSettings.roundTimesToFiveMinutes)
                        
                        if autoTimeSettings.roundTimesToFiveMinutes {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("All flight times rounded to nearest 5-minute interval")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Examples
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Examples:")
                                        .font(.caption2.bold())
                                        .foregroundColor(.gray)
                                    
                                    HStack {
                                        Text("12:32 →")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("12:30")
                                            .font(.caption2.bold())
                                            .foregroundColor(.blue)
                                    }
                                    
                                    HStack {
                                        Text("15:47 →")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("15:45")
                                            .font(.caption2.bold())
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                } header: {
                    Text("Time Rounding")
                }
                
                // MARK: - GPS Auto Time Section
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("GPS Speed Tracking")
                                .font(.headline)
                            Text("Automatically log OFF/ON times based on aircraft speed")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoTimeSettings.isEnabled)
                            .onChange(of: autoTimeSettings.isEnabled) { _, enabled in
                                if enabled {
                                    speedMonitor.startTracking()
                                } else {
                                    speedMonitor.stopTracking()
                                }
                            }
                    }
                    
                    if speedMonitor.isTracking {
                        HStack {
                            Text("Current Speed")
                            Spacer()
                            Text("\(Int(speedMonitor.currentSpeed)) kts")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Auto Time Logging")
                }
                
                // MARK: - Timezone Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Time Format for Auto-Logging")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $autoTimeSettings.useZuluTime)
                        }
                        
                        Text(autoTimeSettings.useZuluTime ?
                             "Times will be logged in Zulu Time (UTC)" :
                             "Times will be logged in Local Time")
                            .font(.caption)
                            .foregroundColor(autoTimeSettings.useZuluTime ? .green : .orange)
                        
                        // Current time preview
                        HStack {
                            Text("Current Time Preview:")
                            Spacer()
                            if autoTimeSettings.useZuluTime {
                                Text("\(formatCurrentTimeAsZulu()) Z")
                                    .foregroundColor(.green)
                            } else {
                                Text("\(formatCurrentTimeAsLocal()) Local")
                                    .foregroundColor(.orange)
                            }
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Timezone Settings")
                }
                
                // MARK: - Speed Thresholds Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Takeoff Speed Threshold
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Takeoff Trigger Speed")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(autoTimeSettings.takeoffSpeedThreshold)) kts")
                                    .foregroundColor(.green)
                                    .font(.title3.bold())
                            }
                            
                            Slider(
                                value: $autoTimeSettings.takeoffSpeedThreshold,
                                in: 60...120,
                                step: 5
                            ) {
                                Text("Takeoff Speed")
                            } minimumValueLabel: {
                                Text("60")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } maximumValueLabel: {
                                Text("120")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .tint(.green)
                            
                            Text("Speed above which OFF time is automatically logged")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Divider()
                        
                        // Landing Speed Threshold
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Landing Trigger Speed")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(autoTimeSettings.landingSpeedThreshold)) kts")
                                    .foregroundColor(.red)
                                    .font(.title3.bold())
                            }
                            
                            Slider(
                                value: $autoTimeSettings.landingSpeedThreshold,
                                in: 10...60,
                                step: 5
                            ) {
                                Text("Landing Speed")
                            } minimumValueLabel: {
                                Text("10")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } maximumValueLabel: {
                                Text("60")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .tint(.red)
                            
                            Text("Speed below which ON time is automatically logged (after being fast)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Speed Thresholds")
                }
                
                // MARK: - Aircraft Type Presets Section
                Section {
                    Button("Light Aircraft (V-speeds ~60/30 kts)") {
                        autoTimeSettings.takeoffSpeedThreshold = 60.0
                        autoTimeSettings.landingSpeedThreshold = 30.0
                    }
                    .foregroundColor(.blue)
                    
                    Button("Regional Jet (V-speeds ~80/40 kts)") {
                        autoTimeSettings.takeoffSpeedThreshold = 80.0
                        autoTimeSettings.landingSpeedThreshold = 40.0
                    }
                    .foregroundColor(.blue)
                    
                    Button("Heavy Jet (V-speeds ~100/50 kts)") {
                        autoTimeSettings.takeoffSpeedThreshold = 100.0
                        autoTimeSettings.landingSpeedThreshold = 50.0
                    }
                    .foregroundColor(.blue)
                    
                    Button("Turboprop (V-speeds ~70/35 kts)") {
                        autoTimeSettings.takeoffSpeedThreshold = 70.0
                        autoTimeSettings.landingSpeedThreshold = 35.0
                    }
                    .foregroundColor(.blue)
                } header: {
                    Text("Aircraft Type Presets")
                }
                
                // MARK: - How It Works Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "airplane.departure")
                                .foregroundColor(.green)
                            Text("Takeoff Detection")
                                .font(.headline)
                        }
                        Text("When ground speed exceeds the takeoff threshold, OFF time is automatically logged")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Divider()
                        
                        HStack {
                            Image(systemName: "airplane.arrival")
                                .foregroundColor(.red)
                            Text("Landing Detection")
                                .font(.headline)
                        }
                        Text("When ground speed drops below the landing threshold (after being fast), ON time is automatically logged")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Auto Time Logging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if autoTimeSettings.isEnabled {
                speedMonitor.startTracking()
            }
        }
        .onDisappear {
            speedMonitor.stopTracking()
        }
    }
    
    private func formatCurrentTimeAsZulu() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")!
        formatter.dateFormat = "HHmm"
        return formatter.string(from: Date())
    }
    
    private func formatCurrentTimeAsLocal() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HHmm"
        return formatter.string(from: Date())
    }
}

#Preview {
    AutoTimeLoggingSettingsView()
}
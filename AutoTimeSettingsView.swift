import SwiftUI

struct AutoTimeSettingsView: View {
    @ObservedObject var autoTimeSettings: AutoTimeSettings
    @ObservedObject var speedMonitor: GPSSpeedMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Auto Time Logging") {
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
                        }
                    }
                }
                
                // ⭐ NEW: TIME ROUNDING SECTION - PROMINENT!
                Section("Time Rounding") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Round Times to 5 Minutes")
                                    .font(.headline)
                                Text("Round flight times for company logbook reporting")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $autoTimeSettings.roundTimesToFiveMinutes)
                        }
                        
                        if autoTimeSettings.roundTimesToFiveMinutes {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.2.circlepath")
                                        .foregroundColor(.blue)
                                    Text("Flight times will be rounded to nearest 5 minutes")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Examples:")
                                        .font(.caption.bold())
                                    Text("14:32 → 14:30  |  14:33 → 14:35  |  14:37 → 14:35")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                Text("Exact times will be logged")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section("Timezone Settings") {
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
                }
                
                Section("Speed Thresholds") {
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
                }
                
                Section("Aircraft Type Presets") {
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
                }
                
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "airplane.departure")
                                .foregroundColor(.green)
                            Text("Takeoff Detection")
                                .font(.headline)
                        }
                        Text("When ground speed exceeds the takeoff threshold, OFF time is automatically logged")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
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
                }
            }
            .navigationTitle("Auto Time Settings")
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

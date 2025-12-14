//
//  TimerSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/14/25.
//


// TimerSettingsView.swift
import SwiftUI

struct TimerSettingsView: View {
    @ObservedObject var timer: FlexibleTimerManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0
    @State private var customSeconds: Int = 0
    @State private var showingCustomInput = false
    
    var body: some View {
        NavigationStack {
            List {
                // Mode Selection
                Section {
                    Picker("Timer Mode", selection: $timer.mode) {
                        Text("Stopwatch").tag(FlexibleTimerManager.TimerMode.stopwatch)
                        Text("Countdown").tag(FlexibleTimerManager.TimerMode.countdown)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: timer.mode) { _, newMode in
                        timer.switchMode(to: newMode)
                    }
                } header: {
                    Text("Mode")
                        .foregroundColor(.white)
                } footer: {
                    Text(timer.mode == .stopwatch ?
                         "Count up from zero with optional alarm" :
                         "Count down from set duration")
                        .foregroundColor(.gray)
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                // Countdown Settings
                if timer.mode == .countdown {
                    Section {
                        // Current duration display
                        HStack {
                            Text("Duration")
                                .foregroundColor(.white)
                            Spacer()
                            Text(timer.formattedCountdownDuration())
                                .font(.title3.monospacedDigit())
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                        
                        // Quick presets
                        ForEach(FlexibleTimerManager.durationPresets, id: \.0) { preset in
                            Button(action: {
                                timer.countdownDuration = preset.1
                                timer.resetTimer()
                            }) {
                                HStack {
                                    Text(preset.0)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if timer.countdownDuration == preset.1 {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                }
                            }
                        }
                        
                        // Custom duration
                        Button(action: {
                            showingCustomInput = true
                        }) {
                            HStack {
                                Text("Custom Duration...")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                Spacer()
                                Image(systemName: "keyboard")
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                    } header: {
                        Text("Countdown Duration")
                            .foregroundColor(.white)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // Stopwatch Settings
                if timer.mode == .stopwatch {
                    Section {
                        Toggle("Enable Alarm", isOn: $timer.stopwatchAlarmEnabled)
                            .foregroundColor(.white)
                        
                        if timer.stopwatchAlarmEnabled {
                            // Current alarm time display
                            HStack {
                                Text("Alarm At")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(timer.formattedStopwatchAlarm())
                                    .font(.title3.monospacedDigit())
                                    .foregroundColor(LogbookTheme.accentOrange)
                            }
                            
                            // Quick presets
                            ForEach(FlexibleTimerManager.durationPresets, id: \.0) { preset in
                                Button(action: {
                                    timer.stopwatchAlarmTime = preset.1
                                }) {
                                    HStack {
                                        Text(preset.0)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if timer.stopwatchAlarmTime == preset.1 {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(LogbookTheme.accentGreen)
                                        }
                                    }
                                }
                            }
                            
                            // Custom alarm time
                            Button(action: {
                                showingCustomInput = true
                            }) {
                                HStack {
                                    Text("Custom Alarm Time...")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    Spacer()
                                    Image(systemName: "keyboard")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                            }
                        }
                    } header: {
                        Text("Stopwatch Alarm")
                            .foregroundColor(.white)
                    } footer: {
                        Text("Alarm will trigger when stopwatch reaches the set time")
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // Reset button
                Section {
                    Button(role: .destructive, action: {
                        timer.resetTimer()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset Timer")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .sheet(isPresented: $showingCustomInput) {
                CustomTimeInputView(
                    hours: $customHours,
                    minutes: $customMinutes,
                    seconds: $customSeconds,
                    onSave: {
                        let totalSeconds = TimeInterval(customHours * 3600 + customMinutes * 60 + customSeconds)
                        if timer.mode == .countdown {
                            timer.countdownDuration = totalSeconds
                            timer.resetTimer()
                        } else {
                            timer.stopwatchAlarmTime = totalSeconds
                        }
                        showingCustomInput = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Custom Time Input View
struct CustomTimeInputView: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set Custom Time")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Time pickers
                HStack(spacing: 20) {
                    // Hours
                    VStack {
                        Text("Hours")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                    
                    Text(":")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    // Minutes
                    VStack {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                    
                    Text(":")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    // Seconds
                    VStack {
                        Text("Seconds")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                }
                
                // Preview
                Text("\(String(format: "%02d:%02d:%02d", hours, minutes, seconds))")
                    .font(.system(size: 48, design: .monospaced))
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LogbookTheme.navy)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
struct TimerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TimerSettingsView(timer: FlexibleTimerManager.shared)
    }
}
#endif

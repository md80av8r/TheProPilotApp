//
//  FlexibleTimerView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/31/25.
//


//
//  FlexibleTimerView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/31/25.
//

import SwiftUI

struct FlexibleTimerView: View {
    @StateObject private var timer = FlexibleTimerManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Background
            LogbookTheme.navy
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section - timer display
                VStack(spacing: 20) {
                    // Mode indicator (Stopwatch/Countdown)
                    Text(timer.mode == .stopwatch ? "Stopwatch" : "Countdown")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                    
                    // Main timer display
                    Text(timer.formattedDisplayTime())
                        .font(.system(size: 72, weight: .light, design: .monospaced))
                        .foregroundColor(displayColor())
                        .padding(.horizontal)
                    
                    // Repeat indicator
                    if timer.repeatEnabled {
                        if timer.repeatCount == 0 {
                            Text("Repeat Forever")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("Repeat \(timer.currentRepeat)/\(timer.repeatCount)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Alarm indicator for stopwatch
                    if timer.mode == .stopwatch && timer.stopwatchAlarmEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                            Text("Alarm at \(timer.formattedStopwatchAlarm())")
                                .font(.caption)
                        }
                        .foregroundColor(LogbookTheme.accentOrange)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
                
                // Bottom section - controls
                VStack(spacing: 30) {
                    // Mode switch arrows and control buttons
                    HStack(spacing: 40) {
                        // Up arrow - Stopwatch
                        Button(action: {
                            if timer.mode != .stopwatch {
                                timer.switchMode(to: .stopwatch)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(timer.mode == .stopwatch ? LogbookTheme.accentBlue : .gray)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(LogbookTheme.navyLight)
                                )
                        }
                        
                        // Reset button (center)
                        Button(action: {
                            timer.stopTimer()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                )
                        }
                        .disabled(timer.state == .idle)
                        .opacity(timer.state == .idle ? 0.3 : 1.0)
                        
                        // Down arrow - Countdown
                        Button(action: {
                            if timer.mode != .countdown {
                                timer.switchMode(to: .countdown)
                            }
                        }) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(timer.mode == .countdown ? LogbookTheme.accentBlue : .gray)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(LogbookTheme.navyLight)
                                )
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Main control button (Start/Pause)
                    mainControlButton()
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .overlay(
            // Settings overlay
            Group {
                if showingSettings {
                    ForeFlightTimerSettingsOverlay(
                        timer: timer,
                        isShowing: $showingSettings
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: showingSettings)
    }
    
    // MARK: - Main Control Button
    @ViewBuilder
    private func mainControlButton() -> some View {
        Button(action: {
            handleMainButtonTap()
        }) {
            VStack(spacing: 8) {
                Text(mainButtonTitle())
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                if timer.state == .idle {
                    Text("Tap to Start")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(buttonBackgroundColor())
            )
        }
    }
    
    private func mainButtonTitle() -> String {
        switch timer.state {
        case .idle:
            return timer.formattedDisplayTime()
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .completed:
            return "Done"
        case .alarming:
            return "Stop Alarm"
        }
    }
    
    private func handleMainButtonTap() {
        switch timer.state {
        case .idle:
            timer.startTimer()
        case .running:
            timer.pauseTimer()
        case .paused:
            timer.startTimer()
        case .completed, .alarming:
            timer.acknowledgeAlarm()
        }
    }
    
    private func buttonBackgroundColor() -> Color {
        switch timer.state {
        case .idle:
            return LogbookTheme.navyLight
        case .running:
            return LogbookTheme.accentOrange
        case .paused:
            return LogbookTheme.accentGreen
        case .completed, .alarming:
            return Color.red
        }
    }
    
    private func displayColor() -> Color {
        switch timer.state {
        case .idle:
            return .white
        case .running:
            return LogbookTheme.accentBlue
        case .paused:
            return LogbookTheme.accentOrange
        case .completed:
            return LogbookTheme.accentGreen
        case .alarming:
            return .red
        }
    }
}

// MARK: - ForeFlight-Style Settings Overlay
struct ForeFlightTimerSettingsOverlay: View {
    @ObservedObject var timer: FlexibleTimerManager
    @Binding var isShowing: Bool
    
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 2
    @State private var selectedSeconds: Int = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }
            
            // Settings panel
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Text(timer.mode == .countdown ? "Countdown Timer" : "Stopwatch Alarm")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            isShowing = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navy)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Time picker
                    HStack(spacing: 0) {
                        // Hours
                        Picker("", selection: $selectedHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)")
                                    .foregroundColor(.white)
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        
                        Text("hours")
                            .foregroundColor(.white)
                            .frame(width: 60)
                        
                        // Minutes
                        Picker("", selection: $selectedMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)")
                                    .foregroundColor(.white)
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        
                        Text("mins")
                            .foregroundColor(.white)
                            .frame(width: 60)
                        
                        // Seconds
                        Picker("", selection: $selectedSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)")
                                    .foregroundColor(.white)
                                    .tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        
                        Text("secs")
                            .foregroundColor(.white)
                            .frame(width: 60)
                    }
                    .frame(height: 180)
                    .background(LogbookTheme.navyLight)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Repeat toggle
                    Toggle(isOn: $timer.repeatEnabled) {
                        Text("Repeat")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(LogbookTheme.navy)
                    
                    // Repeat count (when enabled)
                    if timer.repeatEnabled {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        HStack {
                            Text("Repeat Count")
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if timer.repeatCount == 0 {
                                Text("Will Not Repeat")
                                    .foregroundColor(.gray)
                            } else {
                                Text("\(timer.repeatCount) times")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.navy)
                        .onTapGesture {
                            // Toggle between 0 (infinite) and specific counts
                            if timer.repeatCount == 0 {
                                timer.repeatCount = 1
                            } else if timer.repeatCount < 10 {
                                timer.repeatCount += 1
                            } else {
                                timer.repeatCount = 0
                            }
                        }
                    }
                    
                    // Apply button
                    Button(action: {
                        applySettings()
                        isShowing = false
                    }) {
                        Text("Apply")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LogbookTheme.accentBlue)
                    }
                }
                .background(LogbookTheme.navy)
                .cornerRadius(16, corners: [.topLeft, .topRight])
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        let currentDuration = timer.mode == .countdown ? timer.countdownDuration : timer.stopwatchAlarmTime
        let components = timer.formatTimeComponents(currentDuration)
        selectedHours = components.hours
        selectedMinutes = components.minutes
        selectedSeconds = components.seconds
    }
    
    private func applySettings() {
        let newDuration = timer.timeIntervalFromComponents(
            hours: selectedHours,
            minutes: selectedMinutes,
            seconds: selectedSeconds
        )
        
        if timer.mode == .countdown {
            timer.countdownDuration = newDuration
            if timer.state == .idle {
                timer.displayTime = newDuration
            }
        } else {
            timer.stopwatchAlarmTime = newDuration
            timer.stopwatchAlarmEnabled = true
        }
    }
}

// MARK: - Corner Radius Extension
#if DEBUG
struct FlexibleTimerView_Previews: PreviewProvider {
    static var previews: some View {
        FlexibleTimerView()
    }
}
#endif

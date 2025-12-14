//
//  ForeFlightStyleTimerView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/1/25.
//

import SwiftUI

struct ForeFlightStyleTimerView: View {
    @ObservedObject var timer: FlexibleTimerManager
    @State private var hours: Int = 0
    @State private var minutes: Int = 10  // Default 10 minutes
    @State private var seconds: Int = 0
    @State private var showingPicker = false
    @State private var repeatEnabled = false
    @State private var repeatCount = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main timer display with arrow
                HStack(spacing: 20) {
                    // Time display
                    Text(formatDisplayTime())
                        .font(.system(size: 56, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    
                    // Tappable arrow
                    Button(action: {
                        withAnimation {
                            if timer.mode == .stopwatch {
                                // Switch to countdown
                                timer.switchMode(to: .countdown)
                                showingPicker = true
                            } else {
                                // Switch to stopwatch
                                timer.switchMode(to: .stopwatch)
                                showingPicker = false
                            }
                            loadCurrentSettings()
                        }
                    }) {
                        Image(systemName: timer.mode == .countdown ? "arrow.down" : "arrow.up")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .padding(.bottom, 12)
                
                // Tap to Start / Tap to Set
                if timer.state == .idle {
                    Text(timer.mode == .countdown ? "Tap to Set" : "Tap to Start")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .onTapGesture {
                            if timer.mode == .countdown {
                                showingPicker = true
                            } else {
                                startTimer()
                            }
                        }
                } else if timer.state == .running {
                    Text(timer.mode == .countdown ? "Countdown" : "Stopwatch")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                } else if timer.state == .paused {
                    Text("Paused")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // Control buttons when running
                if timer.state == .running || timer.state == .paused {
                    HStack(spacing: 20) {
                        // Pause/Resume
                        Button(action: {
                            if timer.state == .paused {
                                timer.startTimer()
                            } else {
                                timer.pauseTimer()
                            }
                        }) {
                            HStack {
                                Image(systemName: timer.state == .paused ? "play.fill" : "pause.fill")
                                Text(timer.state == .paused ? "Resume" : "Pause")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LogbookTheme.accentBlue)
                            .cornerRadius(12)
                        }
                        
                        // Reset
                        Button(action: {
                            timer.stopTimer()
                            loadCurrentSettings()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                
                // Tap to Start button (stopwatch only, when idle)
                if timer.state == .idle && timer.mode == .stopwatch {
                    Button(action: {
                        startTimer()
                    }) {
                        Text("Tap to Start")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(LogbookTheme.accentBlue)
                    }
                }
            }
            .padding(.vertical, 40)
            
            // Picker overlay
            if showingPicker {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showingPicker = false
                        }
                    }
                
                VStack(spacing: 0) {
                    // Picker card
                    VStack(spacing: 20) {
                        // Wheel pickers
                        HStack(spacing: 0) {
                            // Hours
                            VStack(spacing: 4) {
                                Picker("Hours", selection: $hours) {
                                    ForEach(0..<24) { hour in
                                        Text("\(hour)")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                .onChange(of: hours) { _, _ in updateTimerDuration() }
                                
                                Text("hours")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            
                            // Minutes
                            VStack(spacing: 4) {
                                Picker("Minutes", selection: $minutes) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                .onChange(of: minutes) { _, _ in updateTimerDuration() }
                                
                                Text("mins")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            
                            // Seconds
                            VStack(spacing: 4) {
                                Picker("Seconds", selection: $seconds) {
                                    ForEach(0..<60) { second in
                                        Text("\(second)")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                            .tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                .onChange(of: seconds) { _, _ in updateTimerDuration() }
                                
                                Text("secs")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        // Repeat section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Repeat")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $repeatEnabled)
                                    .labelsHidden()
                                    .onChange(of: repeatEnabled) { _, enabled in
                                        timer.repeatEnabled = enabled
                                        if !enabled {
                                            repeatCount = 0
                                            timer.repeatCount = 0
                                        }
                                    }
                            }
                            .padding(.horizontal, 20)
                            
                            if repeatEnabled {
                                HStack {
                                    Text("Repeat Count")
                                        .font(.system(size: 17))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(repeatCount == 0 ? "Will Not Repeat" : "\(repeatCount)")
                                        .font(.system(size: 17))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                
                                Picker("Repeat Count", selection: $repeatCount) {
                                    Text("Will Not Repeat").tag(0)
                                    ForEach(1...20, id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                                .onChange(of: repeatCount) { _, count in
                                    timer.repeatCount = count
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Bottom time display with Tap to Start
                    VStack(spacing: 0) {
                        HStack(spacing: 20) {
                            Text(formatDisplayTime())
                                .font(.system(size: 56, weight: .medium))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.down")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 20)
                        
                        Button(action: {
                            withAnimation {
                                showingPicker = false
                            }
                            startTimer()
                        }) {
                            Text("Tap to Start")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(LogbookTheme.accentBlue)
                        }
                    }
                    .background(LogbookTheme.navyLight)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func formatDisplayTime() -> String {
        if timer.state == .running || timer.state == .paused || timer.state == .alarming {
            // Show running time
            let totalSeconds = Int(timer.displayTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        } else {
            // Show setup time
            let totalMinutes = hours * 60 + minutes
            return String(format: "%02d:%02d", totalMinutes, seconds)
        }
    }
    
    private func startTimer() {
        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        
        guard totalSeconds > 0 else { return }
        
        if timer.mode == .countdown {
            timer.countdownDuration = totalSeconds
            timer.resetTimer()
        } else {
            timer.stopwatchAlarmTime = totalSeconds
            timer.stopwatchAlarmEnabled = totalSeconds > 0
        }
        
        timer.startTimer()
    }
    
    private func updateTimerDuration() {
        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        
        if timer.mode == .countdown {
            timer.countdownDuration = totalSeconds
            if timer.state == .idle {
                timer.displayTime = totalSeconds
            }
        } else {
            timer.stopwatchAlarmTime = totalSeconds
        }
    }
    
    private func loadCurrentSettings() {
        if timer.mode == .countdown {
            let total = Int(timer.countdownDuration)
            hours = total / 3600
            minutes = (total % 3600) / 60
            seconds = total % 60
            repeatEnabled = timer.repeatEnabled
            repeatCount = timer.repeatCount
        } else {
            // Stopwatch - reset to default
            hours = 0
            minutes = 10
            seconds = 0
        }
    }
}

#if DEBUG
struct ForeFlightStyleTimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForeFlightStyleTimerView(timer: FlexibleTimerManager.shared)
    }
}
#endif

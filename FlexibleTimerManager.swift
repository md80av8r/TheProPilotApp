//
//  FlexibleTimerManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/31/25.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Flexible Timer Manager
class FlexibleTimerManager: ObservableObject {
    static let shared = FlexibleTimerManager()
    
    // MARK: - Timer Mode
    enum TimerMode: String, Codable {
        case stopwatch  // Count up
        case countdown  // Count down
    }
    
    // MARK: - Timer State
    enum TimerState {
        case idle
        case running
        case paused
        case completed  // Only for countdown
        case alarming   // When stopwatch alarm triggers
    }
    
    // MARK: - Published Properties
    @Published var mode: TimerMode {
        didSet {
            saveSettings()
        }
    }
    
    @Published var state: TimerState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var displayTime: TimeInterval = 0  // What to show to user
    
    // Countdown settings
    @Published var countdownDuration: TimeInterval {
        didSet {
            saveSettings()
            if state == .idle {
                displayTime = countdownDuration
            }
        }
    }
    
    // Stopwatch alarm settings
    @Published var stopwatchAlarmEnabled: Bool {
        didSet {
            saveSettings()
        }
    }
    
    @Published var stopwatchAlarmTime: TimeInterval {
        didSet {
            saveSettings()
        }
    }
    
    // Repeat settings
    @Published var repeatEnabled: Bool {
        didSet {
            saveSettings()
        }
    }
    
    @Published var repeatCount: Int {
        didSet {
            saveSettings()
        }
    }
    
    @Published var currentRepeat: Int = 0
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var startTime: Date?
    private var pausedElapsed: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var hasPlayedAlarm = false
    
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    
    // MARK: - Settings Keys
    private enum SettingsKey {
        static let mode = "FlexibleTimer_Mode"
        static let countdownDuration = "FlexibleTimer_CountdownDuration"
        static let stopwatchAlarmEnabled = "FlexibleTimer_StopwatchAlarmEnabled"
        static let stopwatchAlarmTime = "FlexibleTimer_StopwatchAlarmTime"
        static let repeatEnabled = "FlexibleTimer_RepeatEnabled"
        static let repeatCount = "FlexibleTimer_RepeatCount"
    }
    
    // MARK: - Initialization
    init() {
        self.mode = .stopwatch
        self.countdownDuration = 120  // 2 minutes default
        self.stopwatchAlarmEnabled = false
        self.stopwatchAlarmTime = 120  // 2 minutes default
        self.repeatEnabled = false
        self.repeatCount = 0  // 0 means infinite
        
        loadSettings()
        
        // Initialize display time based on mode
        if mode == .countdown {
            displayTime = countdownDuration
        }
    }
    
    // MARK: - Settings Persistence
    private func saveSettings() {
        userDefaults?.set(mode.rawValue, forKey: SettingsKey.mode)
        userDefaults?.set(countdownDuration, forKey: SettingsKey.countdownDuration)
        userDefaults?.set(stopwatchAlarmEnabled, forKey: SettingsKey.stopwatchAlarmEnabled)
        userDefaults?.set(stopwatchAlarmTime, forKey: SettingsKey.stopwatchAlarmTime)
        userDefaults?.set(repeatEnabled, forKey: SettingsKey.repeatEnabled)
        userDefaults?.set(repeatCount, forKey: SettingsKey.repeatCount)
    }
    
    private func loadSettings() {
        if let modeString = userDefaults?.string(forKey: SettingsKey.mode),
           let loadedMode = TimerMode(rawValue: modeString) {
            mode = loadedMode
        }
        
        if let duration = userDefaults?.double(forKey: SettingsKey.countdownDuration), duration > 0 {
            countdownDuration = duration
        }
        
        stopwatchAlarmEnabled = userDefaults?.bool(forKey: SettingsKey.stopwatchAlarmEnabled) ?? false
        
        if let alarmTime = userDefaults?.double(forKey: SettingsKey.stopwatchAlarmTime), alarmTime > 0 {
            stopwatchAlarmTime = alarmTime
        }
        
        repeatEnabled = userDefaults?.bool(forKey: SettingsKey.repeatEnabled) ?? false
        repeatCount = userDefaults?.integer(forKey: SettingsKey.repeatCount) ?? 0
    }
    
    // MARK: - Timer Controls
    func startTimer() {
        guard state == .idle || state == .paused else { return }
        
        state = .running
        hasPlayedAlarm = false
        startTime = Date()
        
        if state != .paused {
            currentRepeat += 1
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func pauseTimer() {
        guard state == .running else { return }
        
        state = .paused
        pausedElapsed = elapsedTime
        timer?.invalidate()
        timer = nil
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        state = .idle
        elapsedTime = 0
        pausedElapsed = 0
        displayTime = mode == .countdown ? countdownDuration : 0
        currentRepeat = 0
        hasPlayedAlarm = false
        stopAlarmSound()
    }
    
    func resetTimer() {
        let wasRunning = state == .running
        
        timer?.invalidate()
        timer = nil
        state = .idle
        elapsedTime = 0
        pausedElapsed = 0
        displayTime = mode == .countdown ? countdownDuration : 0
        hasPlayedAlarm = false
        stopAlarmSound()
        
        // If we're repeating and timer was running, restart
        if wasRunning && repeatEnabled {
            if repeatCount == 0 {  // Infinite repeat
                startTimer()
            } else if currentRepeat < repeatCount {
                startTimer()
            } else {
                currentRepeat = 0  // Reset repeat counter
            }
        } else {
            currentRepeat = 0
        }
    }
    
    func switchMode(to newMode: TimerMode) {
        stopTimer()
        mode = newMode
        displayTime = mode == .countdown ? countdownDuration : 0
    }
    
    // MARK: - Timer Update
    private func updateTimer() {
        guard let startTime = startTime else { return }
        
        elapsedTime = pausedElapsed + Date().timeIntervalSince(startTime)
        
        switch mode {
        case .stopwatch:
            displayTime = elapsedTime
            
            // Check stopwatch alarm
            if stopwatchAlarmEnabled && !hasPlayedAlarm && elapsedTime >= stopwatchAlarmTime {
                triggerAlarm()
            }
            
        case .countdown:
            let remaining = countdownDuration - elapsedTime
            
            if remaining <= 0 {
                displayTime = 0
                state = .completed
                timer?.invalidate()
                timer = nil
                triggerAlarm()
                
                // Handle repeat
                if repeatEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.resetTimer()
                    }
                }
            } else {
                displayTime = remaining
            }
        }
    }
    
    // MARK: - Alarm
    private func triggerAlarm() {
        guard !hasPlayedAlarm else { return }
        hasPlayedAlarm = true
        state = .alarming
        playAlarmSound()
        
        // Vibrate
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        // Auto-reset after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.acknowledgeAlarm()
        }
    }
    
    func acknowledgeAlarm() {
        stopAlarmSound()
        
        if mode == .stopwatch {
            // Stopwatch alarm - keep running
            state = .running
            hasPlayedAlarm = true  // Don't alarm again
        } else {
            // Countdown completed
            if repeatEnabled {
                resetTimer()
            } else {
                state = .idle
            }
        }
    }
    
    private func playAlarmSound() {
        // Play system sound for now - can be customized
        AudioServicesPlaySystemSound(1005)  // Low power alert sound
    }
    
    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: - Formatting
    func formattedDisplayTime() -> String {
        return formatTimeInterval(displayTime)
    }
    
    func formattedCountdownDuration() -> String {
        return formatTimeInterval(countdownDuration)
    }
    
    func formattedStopwatchAlarm() -> String {
        return formatTimeInterval(stopwatchAlarmTime)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        let centiseconds = Int((interval - floor(interval)) * 100)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
        }
    }
    
    func formatTimeComponents(_ interval: TimeInterval) -> (hours: Int, minutes: Int, seconds: Int) {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return (hours, minutes, seconds)
    }
    
    func timeIntervalFromComponents(hours: Int, minutes: Int, seconds: Int) -> TimeInterval {
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }
    
    // MARK: - Preset Durations
    static let durationPresets: [(String, TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
}

// Complete ClocksTabView.swift with World Clocks, Timers, and Duty Timer
import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit
import Foundation

struct ClocksTabView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var airlineSettings: AirlineSettingsStore
    @EnvironmentObject var activityManager: PilotActivityManager
    
    // MARK: - Bindings
    @Binding var sharedDutyStartTime: Date?
    
    // MARK: - State Variables
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    
    // Timer states
    @State private var timerMinutes = 2
    @State private var timerSeconds = 0
    @State private var countdownTimer: Timer?
    @State private var isTimerRunning = false
    @State private var showTimerSettings = false
    @State private var countdownEndTime: Date?
    @State private var remainingTime: TimeInterval = 0
    
    // Preset timer options
    private let timerPresets = [2, 5, 10, 15, 30]
    
    // MARK: - Initializer
    init(sharedDutyStartTime: Binding<Date?>) {
        self._sharedDutyStartTime = sharedDutyStartTime
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // MARK: - World Clocks Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("World Time")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        // GMT/UTC Clock (Always correct)
                        ClockDisplayView(
                            title: "GMT (UTC)",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "UTC")!),
                            subtitle: "Greenwich Mean Time",
                            color: LogbookTheme.accentBlue
                        )
                        
                        // Local Time Clock (Fixed to use device timezone properly)
                        ClockDisplayView(
                            title: "Local Time",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone.current),
                            subtitle: getLocalTimezoneDescription(),
                            color: LogbookTheme.accentGreen
                        )
                        
                        // Eastern Time (Common aviation reference)
                        ClockDisplayView(
                            title: "Eastern Time",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/New_York")!),
                            subtitle: "New York, Atlanta, Miami",
                            color: LogbookTheme.accentOrange
                        )
                        
                        // Central Time (Common aviation reference)
                        ClockDisplayView(
                            title: "Central Time",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/Chicago")!),
                            subtitle: "Chicago, Dallas, Houston",
                            color: Color.purple
                        )
                        
                        // Mountain Time (Common aviation reference)
                        ClockDisplayView(
                            title: "Mountain Time",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/Denver")!),
                            subtitle: "Denver, Phoenix",
                            color: Color.brown
                        )
                        
                        // Pacific Time (Common aviation reference)
                        ClockDisplayView(
                            title: "Pacific Time",
                            time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/Los_Angeles")!),
                            subtitle: "Los Angeles, San Francisco, Seattle",
                            color: Color.pink
                        )
                        
                        // Home Base Time (if different from local)
                        if !airlineSettings.settings.homeBaseAirport.isEmpty {
                            let homeBaseTimezone = getTimezoneForAirport(airlineSettings.settings.homeBaseAirport)
                            if homeBaseTimezone.identifier != TimeZone.current.identifier {
                                ClockDisplayView(
                                    title: "Home Base",
                                    time: formatTimeForTimezone(currentTime, timeZone: homeBaseTimezone),
                                    subtitle: airlineSettings.settings.homeBaseAirport,
                                    color: LogbookTheme.accentBlue.opacity(0.8)
                                )
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // MARK: - Countdown Timer Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Countdown Timer")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 20) {
                            // Timer Display
                            VStack(spacing: 8) {
                                if isTimerRunning {
                                    Text(formatCountdownTime(remainingTime))
                                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                                        .foregroundColor(remainingTime > 60 ? LogbookTheme.accentBlue : .red)
                                } else {
                                    Text("\(timerMinutes):\(String(format: "%02d", timerSeconds))")
                                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                                
                                Text(isTimerRunning ? "Time Remaining" : "Timer Set")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Timer Progress Ring (if running)
                            if isTimerRunning, let endTime = countdownEndTime {
                                let totalDuration = endTime.timeIntervalSince(endTime.addingTimeInterval(-Double(timerMinutes * 60 + timerSeconds)))
                                let progress = totalDuration > 0 ? (totalDuration - remainingTime) / totalDuration : 0
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                        .frame(width: 120, height: 120)
                                    
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            remainingTime > 60 ? LogbookTheme.accentBlue : .red,
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 1), value: progress)
                                }
                            }
                            
                            // Timer Controls
                            if !isTimerRunning {
                                // Timer Setting Controls
                                VStack(spacing: 12) {
                                    HStack(spacing: 20) {
                                        VStack {
                                            Text("Minutes")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Picker("Minutes", selection: $timerMinutes) {
                                                ForEach(0...59, id: \.self) { minute in
                                                    Text("\(minute)").tag(minute)
                                                }
                                            }
                                            .pickerStyle(WheelPickerStyle())
                                            .frame(width: 80, height: 100)
                                        }
                                        
                                        VStack {
                                            Text("Seconds")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Picker("Seconds", selection: $timerSeconds) {
                                                ForEach([0, 15, 30, 45], id: \.self) { second in
                                                    Text("\(second)").tag(second)
                                                }
                                            }
                                            .pickerStyle(WheelPickerStyle())
                                            .frame(width: 80, height: 100)
                                        }
                                    }
                                    
                                    // Preset Buttons
                                    HStack(spacing: 12) {
                                        ForEach(timerPresets, id: \.self) { preset in
                                            Button("\(preset)m") {
                                                timerMinutes = preset
                                                timerSeconds = 0
                                            }
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(LogbookTheme.accentBlue.opacity(0.3))
                                            .cornerRadius(15)
                                        }
                                    }
                                }
                            }
                            
                            // Start/Stop Button
                            Button(action: {
                                if isTimerRunning {
                                    stopCountdownTimer()
                                } else {
                                    startCountdownTimer()
                                }
                            }) {
                                HStack {
                                    Image(systemName: isTimerRunning ? "stop.fill" : "play.fill")
                                    Text(isTimerRunning ? "Stop Timer" : "Start Timer")
                                }
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isTimerRunning ? .red : LogbookTheme.accentGreen)
                                .cornerRadius(12)
                            }
                            .disabled(timerMinutes == 0 && timerSeconds == 0 && !isTimerRunning)
                        }
                        .padding()
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // MARK: - Duty Timer Section (Connected to Unified System)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Duty Timer")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            if let dutyStart = sharedDutyStartTime {
                                // On Duty Display
                                VStack(spacing: 8) {
                                    Text("ON DUTY")
                                        .font(.caption.bold())
                                        .foregroundColor(LogbookTheme.accentOrange)
                                    
                                    Text(formatDutyDuration(from: dutyStart, to: currentTime))
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentOrange)
                                    
                                    Text("Started: \(formatDutyStartTime(dutyStart))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(spacing: 12) {
                                    Button("End Duty") {
                                        endDutyTimer()
                                    }
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.red)
                                    .cornerRadius(12)
                                    
                                    if !activityManager.isActivityActive {
                                        Button("Start Live Activity") {
                                            startLiveActivityFromDuty()
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(LogbookTheme.accentBlue)
                                        .cornerRadius(12)
                                    }
                                }
                            } else {
                                // Off Duty Display
                                VStack(spacing: 16) {
                                    Text("OFF DUTY")
                                        .font(.caption.bold())
                                        .foregroundColor(.gray)
                                    
                                    Text("00:00:00")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(.gray)
                                    
                                    VStack(spacing: 12) {
                                        Button("Start Duty") {
                                            startDutyTimer()
                                        }
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(LogbookTheme.accentGreen)
                                        .cornerRadius(12)
                                        
                                        Button("Start with Live Activity") {
                                            startDutyWithLiveActivity()
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(LogbookTheme.accentBlue)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Clocks & Timers")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            startClockTimer()
        }
        .onDisappear {
            stopClockTimer()
        }
    }
    
    // MARK: - Clock Display Component
    struct ClockDisplayView: View {
        let title: String
        let time: String
        let subtitle: String
        let color: Color
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(time)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            .padding()
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Timer Functions
    private func startClockTimer() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    private func startCountdownTimer() {
        let totalSeconds = timerMinutes * 60 + timerSeconds
        guard totalSeconds > 0 else { return }
        
        countdownEndTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
        remainingTime = TimeInterval(totalSeconds)
        isTimerRunning = true
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let endTime = countdownEndTime {
                remainingTime = endTime.timeIntervalSinceNow
                
                if remainingTime <= 0 {
                    stopCountdownTimer()
                    timerFinished()
                }
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isTimerRunning = false
        countdownEndTime = nil
        remainingTime = 0
    }
    
    private func timerFinished() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Audio alert
        AudioServicesPlaySystemSound(SystemSoundID(1005)) // System alert sound
        
        print("⏰ Timer finished!")
    }
    
    // MARK: - 🆕 FIXED Duty Timer Functions (Connected to Unified System)
    private func startDutyTimer() {
        print("🔴 ClocksTabView: Starting duty timer via notification")
        // Trigger the unified duty timer function in ContentView
        NotificationCenter.default.post(name: .startDutyFromWatch, object: nil)
    }
    
    private func endDutyTimer() {
        print("🔴 ClocksTabView: Ending duty timer via notification")
        // Trigger the unified duty timer end function in ContentView
        NotificationCenter.default.post(name: .endDutyFromWatch, object: nil)
    }
    
    private func startDutyWithLiveActivity() {
        print("🔴 ClocksTabView: Starting duty with Live Activity via notification")
        // This should trigger the unified system which includes Live Activity
        NotificationCenter.default.post(name: .startDutyFromWatch, object: nil)
    }
    
    private func startLiveActivityFromDuty() {
        print("🔴 ClocksTabView: Starting Live Activity from existing duty")
        // Only start Live Activity if duty is already running
        guard sharedDutyStartTime != nil else {
            print("🔴 ClocksTabView: No duty timer running, starting duty first")
            startDutyTimer()
            return
        }
        
        // Manually start Live Activity for existing duty
        activityManager.startActivity(
            tripNumber: "MANUAL",
            aircraft: "TBD",
            departure: "TBD",
            arrival: "TBD",
            currentAirport: "TBD",
            currentAirportName: "Duty Active",
            dutyStartTime: sharedDutyStartTime ?? Date()
        )
    }
    
    // MARK: - 🆕 FIXED Timezone Formatting Functions
    private func formatTimeForTimezone(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func getLocalTimezoneDescription() -> String {
        let timezone = TimeZone.current
        let abbreviation = timezone.localizedName(for: .shortStandard, locale: .current) ?? timezone.abbreviation() ?? "Local"
        let identifier = timezone.identifier
        
        // Common timezone mappings for better readability
        let friendlyNames: [String: String] = [
            "America/New_York": "Eastern Time",
            "America/Chicago": "Central Time",
            "America/Denver": "Mountain Time",
            "America/Los_Angeles": "Pacific Time",
            "America/Anchorage": "Alaska Time",
            "Pacific/Honolulu": "Hawaii Time",
            "America/Phoenix": "Arizona Time",
            "America/Detroit": "Eastern Time",
            "UTC": "UTC"
        ]
        
        return friendlyNames[identifier] ?? abbreviation
    }
    
    private func getTimezoneForAirport(_ icaoCode: String) -> TimeZone {
        // Enhanced airport timezone mapping
        let airportTimezones: [String: String] = [
            // US Eastern
            "KATL": "America/New_York", "KJFK": "America/New_York", "KLGA": "America/New_York",
            "KEWR": "America/New_York", "KBOS": "America/New_York", "KDCA": "America/New_York",
            "KIAD": "America/New_York", "KBWI": "America/New_York", "KPHL": "America/New_York",
            "KCLT": "America/New_York", "KMIA": "America/New_York", "KFLL": "America/New_York",
            "KMCO": "America/New_York", "KTPA": "America/New_York", "KDTW": "America/Detroit",
            
            // US Central
            "KORD": "America/Chicago", "KMDW": "America/Chicago", "KDFW": "America/Chicago",
            "KDAL": "America/Chicago", "KIAH": "America/Chicago", "KHOU": "America/Chicago",
            "KAUS": "America/Chicago", "KSAT": "America/Chicago", "KMSP": "America/Chicago",
            "KELP": "America/Denver", "KLRD": "America/Chicago", "KCRP": "America/Chicago",
            "KMFE": "America/Chicago", "KBRO": "America/Chicago",
            
            // US Mountain
            "KDEN": "America/Denver", "KSLC": "America/Denver",
            
            // US Arizona (no DST)
            "KPHX": "America/Phoenix",
            
            // US Pacific
            "KLAX": "America/Los_Angeles", "KSFO": "America/Los_Angeles", "KLAS": "America/Los_Angeles",
            "KSEA": "America/Los_Angeles", "KPDX": "America/Los_Angeles", "KSAN": "America/Los_Angeles",
            "KOAK": "America/Los_Angeles",
            
            // Michigan specific
            "KYIP": "America/Detroit", "KDET": "America/Detroit",
            
            // Canada
            "CYYZ": "America/Toronto", "CYUL": "America/Montreal", "CYVR": "America/Vancouver",
            "CYYC": "America/Edmonton", "CYEG": "America/Edmonton", "CYOW": "America/Toronto",
            "CYHZ": "America/Halifax", "CYWG": "America/Winnipeg",
            
            // Mexico
            "MMMX": "America/Mexico_City", "MMUN": "America/Cancun", "MMGL": "America/Mexico_City",
            "MMTJ": "America/Tijuana", "MMMY": "America/Monterrey", "MMPR": "America/Mexico_City",
            
            // Caribbean
            "MYNN": "America/Nassau", "TJSJ": "America/Puerto_Rico", "TNCM": "America/Lower_Princes",
            
            // Europe
            "EGLL": "Europe/London", "EHAM": "Europe/Amsterdam", "EDDF": "Europe/Berlin",
            "LFPG": "Europe/Paris", "LEMD": "Europe/Madrid", "LIRF": "Europe/Rome"
        ]
        
        let identifier = airportTimezones[icaoCode.uppercased()] ?? "UTC"
        return TimeZone(identifier: identifier) ?? TimeZone(identifier: "UTC")!
    }
    
    private func formatDutyStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDutyDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatCountdownTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct ClocksTabView_Previews: PreviewProvider {
    static var previews: some View {
        ClocksTabView(sharedDutyStartTime: .constant(nil))
            .environmentObject(AirlineSettingsStore())
            .environmentObject(PilotActivityManager.shared)
            .preferredColorScheme(.dark)
    }
}


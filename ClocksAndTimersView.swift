//
//  ClocksAndTimersView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/31/25.
//
//  FINAL: Integrates Duty Timer + FlexibleTimer + World Clocks

import SwiftUI

struct ClocksAndTimersView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var airlineSettings: AirlineSettingsStore
    @EnvironmentObject var activityManager: PilotActivityManager
    @EnvironmentObject var dutyTimerManager: DutyTimerManager
    @EnvironmentObject var watchConnectivity: PhoneWatchConnectivity
    
    // MARK: - State
    @StateObject private var flexibleTimer = FlexibleTimerManager.shared
    @State private var selectedTab = 0
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector with icons
                Picker("", selection: $selectedTab) {
                    Label("Duty", systemImage: "clock.badge.airplane").tag(0)
                    Label("Timer", systemImage: "timer").tag(1)
                    Label("World", systemImage: "globe").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(LogbookTheme.navy)
                
                // Content
                TabView(selection: $selectedTab) {
                    // Tab 0: Duty Timer (PRIORITY)
                    DutyTimerTabContent(currentTime: $currentTime)
                        .tag(0)
                    
                    // Tab 1: Flexible Timer (your existing timer)
                    FlexibleTimerView()
                        .tag(1)
                    
                    // Tab 2: World Clocks
                    WorldClocksTabContent(currentTime: $currentTime)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Clocks & Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LogbookTheme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startClock()
        }
        .onDisappear {
            stopClock()
        }
    }
    
    // MARK: - Clock Management
    private func startClock() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
}

// MARK: - Duty Timer Tab Content
struct DutyTimerTabContent: View {
    @EnvironmentObject var dutyTimerManager: DutyTimerManager
    @EnvironmentObject var activityManager: PilotActivityManager
    @EnvironmentObject var watchConnectivity: PhoneWatchConnectivity
    @Binding var currentTime: Date
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large Duty Timer Display
                VStack(spacing: 16) {
                    // Status Badge
                    HStack {
                        Circle()
                            .fill(dutyTimerManager.isOnDuty ? LogbookTheme.accentGreen : Color.gray)
                            .frame(width: 12, height: 12)
                        
                        Text(dutyTimerManager.isOnDuty ? "ON DUTY" : "OFF DUTY")
                            .font(.headline.bold())
                            .foregroundColor(dutyTimerManager.isOnDuty ? LogbookTheme.accentGreen : .gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(dutyTimerManager.isOnDuty ? LogbookTheme.accentGreen.opacity(0.2) : Color.gray.opacity(0.2))
                    )
                    
                    // Main Timer Display with airplane icon
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.airplane")
                            .font(.system(size: 36))
                            .foregroundColor(dutyTimerManager.isOnDuty ? LogbookTheme.accentOrange : .gray)
                        
                        Text(dutyTimerManager.formattedElapsedTime())
                            .font(.system(size: 72, weight: .bold, design: .monospaced))
                            .foregroundColor(dutyTimerManager.dutyStatus().color)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    
                    // Start Time
                    if let startTime = dutyTimerManager.dutyStartTime {
                        VStack(spacing: 4) {
                            Text("Started at")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(startTime))
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                    }
                    
                    // FAR 117 Duty Limits
                    if dutyTimerManager.isOnDuty {
                        DutyLimitsView(
                            startTime: dutyTimerManager.dutyStartTime ?? Date(),
                            status: dutyTimerManager.dutyStatus()
                        )
                    }
                }
                .padding(32)
                .background(LogbookTheme.navyLight)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 24)
                
                // FAR 117 Warning Display
                if dutyTimerManager.showingWarning {
                    Text(dutyTimerManager.warningMessage)
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(dutyTimerManager.dutyStatus().color.opacity(0.9))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Control Buttons
                VStack(spacing: 12) {
                    if dutyTimerManager.isOnDuty {
                        // End Duty Button
                        Button(action: {
                            dutyTimerManager.endDuty()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("End Duty")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.red)
                            .cornerRadius(12)
                        }
                        
                        // Live Activity Toggle
                        if activityManager.isActivityActive {
                            Button(action: {
                                activityManager.endActivity()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Stop Live Activity")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                startLiveActivityFromDuty()
                            }) {
                                HStack {
                                    Image(systemName: "macwindow.on.rectangle")
                                    Text("Start Live Activity")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(LogbookTheme.accentBlue)
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        // Start Duty Button
                        Button(action: {
                            dutyTimerManager.startDuty()
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Start Duty")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LogbookTheme.accentGreen)
                            .cornerRadius(12)
                        }
                        
                        // Start with Live Activity
                        Button(action: {
                            dutyTimerManager.startDuty()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                startLiveActivityFromDuty()
                            }
                        }) {
                            HStack {
                                Image(systemName: "macwindow.on.rectangle")
                                Text("Start with Live Activity")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LogbookTheme.accentBlue.opacity(0.8))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Watch Connection Status
                WatchConnectionStatusView()
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func startLiveActivityFromDuty() {
        guard let startTime = dutyTimerManager.dutyStartTime else { return }
        
        activityManager.startActivity(
            tripNumber: "MANUAL",
            aircraft: "TBD",
            departure: "TBD",
            arrival: "TBD",
            currentAirport: "TBD",
            currentAirportName: "Duty Active",
            dutyStartTime: startTime
        )
    }
}

// MARK: - FAR 117 Duty Limits Info View
struct DutyLimitsView: View {
    let startTime: Date
    let status: DutyStatus
    @EnvironmentObject var airlineSettings: AirlineSettingsStore
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 8)
            
            Text("FAR 117 Duty Limits")
                .font(.caption2.bold())
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                DutyLimitCard(
                    title: "7 Hour Warning",
                    endTime: startTime.addingTimeInterval(7 * 3600),
                    color: .orange,
                    isPassed: status == .warning || status == .criticalWarning || status == .limitReached
                )
                
                DutyLimitCard(
                    title: "8 Hour Limit",
                    endTime: startTime.addingTimeInterval(8 * 3600),
                    color: .red,
                    isPassed: status == .limitReached
                )
            }
        }
    }
}

struct DutyLimitCard: View {
    let title: String
    let endTime: Date
    let color: Color
    let isPassed: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(isPassed ? color : .gray)
            
            Text(formatTime(endTime))
                .font(.caption.bold())
                .foregroundColor(isPassed ? color : .gray)
            
            if isPassed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isPassed ? color.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPassed ? color : Color.clear, lineWidth: 2)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Watch Connection Status View
struct WatchConnectionStatusView: View {
    @EnvironmentObject var watchConnectivity: PhoneWatchConnectivity
    
    var body: some View {
        HStack {
            Circle()
                .fill(watchConnectivity.isWatchConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Image(systemName: "applewatch")
                .foregroundColor(watchConnectivity.isWatchConnected ? LogbookTheme.accentBlue : .gray)
            
            Text(watchConnectivity.isWatchConnected ? "Synced with Apple Watch" : "Watch Not Connected")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.navyLight)
        .cornerRadius(8)
    }
}

// MARK: - World Clocks Tab Content
struct WorldClocksTabContent: View {
    @EnvironmentObject var airlineSettings: AirlineSettingsStore
    @Binding var currentTime: Date
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // GMT/UTC Clock
                ClockDisplayView(
                    title: "GMT (UTC)",
                    time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "UTC")!),
                    subtitle: "Greenwich Mean Time",
                    color: LogbookTheme.accentBlue
                )
                
                // Local Time Clock
                ClockDisplayView(
                    title: "Local Time",
                    time: formatTimeForTimezone(currentTime, timeZone: TimeZone.current),
                    subtitle: getLocalTimezoneDescription(),
                    color: LogbookTheme.accentGreen
                )
                
                // Eastern Time
                ClockDisplayView(
                    title: "Eastern Time",
                    time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/New_York")!),
                    subtitle: "New York, Atlanta, Miami",
                    color: LogbookTheme.accentOrange
                )
                
                // Central Time
                ClockDisplayView(
                    title: "Central Time",
                    time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/Chicago")!),
                    subtitle: "Chicago, Dallas, Houston",
                    color: Color.purple
                )
                
                // Mountain Time
                ClockDisplayView(
                    title: "Mountain Time",
                    time: formatTimeForTimezone(currentTime, timeZone: TimeZone(identifier: "America/Denver")!),
                    subtitle: "Denver, Phoenix",
                    color: Color.brown
                )
                
                // Pacific Time
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
        }
        .background(LogbookTheme.navy)
    }
    
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
        let airportTimezones: [String: String] = [
            // US Eastern
            "KATL": "America/New_York", "KJFK": "America/New_York", "KLGA": "America/New_York",
            "KEWR": "America/New_York", "KBOS": "America/New_York", "KDCA": "America/New_York",
            "KDTW": "America/Detroit",
            
            // US Central
            "KORD": "America/Chicago", "KMDW": "America/Chicago", "KDFW": "America/Chicago",
            
            // US Mountain
            "KDEN": "America/Denver", "KSLC": "America/Denver",
            
            // US Arizona
            "KPHX": "America/Phoenix",
            
            // US Pacific
            "KLAX": "America/Los_Angeles", "KSFO": "America/Los_Angeles", "KSEA": "America/Los_Angeles",
            
            // Michigan
            "KYIP": "America/Detroit", "KDET": "America/Detroit"
        ]
        
        let identifier = airportTimezones[icaoCode.uppercased()] ?? "UTC"
        return TimeZone(identifier: identifier) ?? TimeZone(identifier: "UTC")!
    }
}

// MARK: - Clock Display View
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
                .font(.title.bold().monospacedDigit())
                .foregroundColor(color)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#if DEBUG
struct ClocksAndTimersView_Previews: PreviewProvider {
    static var previews: some View {
        ClocksAndTimersView()
            .environmentObject(AirlineSettingsStore())
            .environmentObject(PilotActivityManager.shared)
            .environmentObject(DutyTimerManager.shared)
            .environmentObject(PhoneWatchConnectivity.shared)
    }
}
#endif

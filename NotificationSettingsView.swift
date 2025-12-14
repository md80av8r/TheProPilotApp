//
//  NotificationSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/28/25.
//


// NotificationSettingsView.swift
// Configure app notifications, alerts, and reminders
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Notification Settings
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("notifySoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("notifyBadgeEnabled") private var badgeEnabled: Bool = true
    
    // Flight Notifications
    @AppStorage("notifyFlightReminder") private var flightReminder: Bool = true
    @AppStorage("notifyFlightReminderMinutes") private var reminderMinutes: Int = 60
    @AppStorage("notifyDutyStart") private var dutyStartNotify: Bool = true
    @AppStorage("notifyDutyEnd") private var dutyEndNotify: Bool = false
    
    // Timer Notifications
    @AppStorage("notifyTimerAlarm") private var timerAlarm: Bool = true
    @AppStorage("notifyTimerVibrate") private var timerVibrate: Bool = true
    
    // Sync Notifications
    @AppStorage("notifySyncComplete") private var syncComplete: Bool = false
    @AppStorage("notifyBackupReminder") private var backupReminder: Bool = true
    @AppStorage("notifyBackupReminderDays") private var backupReminderDays: Int = 7
    
    // Schedule Notifications
    @AppStorage("notifyScheduleChanges") private var scheduleChanges: Bool = true
    @AppStorage("notifyUpcomingTrips") private var upcomingTrips: Bool = true
    @AppStorage("notifyUpcomingTripsDays") private var upcomingTripsDays: Int = 1
    
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationView {
            List {
                // System Permission Status
                Section {
                    HStack {
                        Image(systemName: notificationStatusIcon)
                            .foregroundColor(notificationStatusColor)
                            .font(.title2)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(notificationStatusText)
                                .font(.caption)
                                .foregroundColor(notificationStatusColor)
                        }
                        
                        Spacer()
                        
                        if notificationStatus == .denied {
                            Button("Settings") {
                                openAppSettings()
                            }
                            .font(.caption.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(LogbookTheme.navyLight)
                } footer: {
                    if notificationStatus == .denied {
                        Text("Notifications are disabled in system settings. Tap Settings to enable.")
                            .foregroundColor(.orange)
                    }
                }
                
                if notificationStatus == .authorized {
                    // Master Toggle
                    Section {
                        Toggle("Enable All Notifications", isOn: $notificationsEnabled)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentGreen)
                            .listRowBackground(LogbookTheme.navyLight)
                        
                        if notificationsEnabled {
                            Toggle("Sound", isOn: $soundEnabled)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            Toggle("Badge Count", isOn: $badgeEnabled)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                        }
                    } header: {
                        Text("General")
                            .foregroundColor(.white)
                    }
                    
                    if notificationsEnabled {
                        // Flight Notifications
                        Section {
                            Toggle("Flight Reminders", isOn: $flightReminder)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentOrange)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            if flightReminder {
                                Picker("Remind Before", selection: $reminderMinutes) {
                                    Text("30 minutes").tag(30)
                                    Text("1 hour").tag(60)
                                    Text("2 hours").tag(120)
                                    Text("4 hours").tag(240)
                                }
                                .foregroundColor(.white)
                                .listRowBackground(LogbookTheme.navyLight)
                            }
                            
                            Toggle("Duty Start Alert", isOn: $dutyStartNotify)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentGreen)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            Toggle("Duty End Alert", isOn: $dutyEndNotify)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentGreen)
                                .listRowBackground(LogbookTheme.navyLight)
                        } header: {
                            Text("Flight Alerts")
                                .foregroundColor(.white)
                        }
                        
                        // Timer Notifications
                        Section {
                            Toggle("Timer Alarm Sound", isOn: $timerAlarm)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentOrange)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            Toggle("Timer Vibration", isOn: $timerVibrate)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentOrange)
                                .listRowBackground(LogbookTheme.navyLight)
                        } header: {
                            Text("Timers")
                                .foregroundColor(.white)
                        }
                        
                        // Schedule Notifications
                        Section {
                            Toggle("Schedule Changes", isOn: $scheduleChanges)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            Toggle("Upcoming Trips", isOn: $upcomingTrips)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            if upcomingTrips {
                                Picker("Notify Before", selection: $upcomingTripsDays) {
                                    Text("1 day").tag(1)
                                    Text("2 days").tag(2)
                                    Text("3 days").tag(3)
                                }
                                .foregroundColor(.white)
                                .listRowBackground(LogbookTheme.navyLight)
                            }
                        } header: {
                            Text("Schedule")
                                .foregroundColor(.white)
                        }
                        
                        // Data Notifications
                        Section {
                            Toggle("Sync Complete", isOn: $syncComplete)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentGreen)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            Toggle("Backup Reminder", isOn: $backupReminder)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentOrange)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            if backupReminder {
                                Picker("Remind Every", selection: $backupReminderDays) {
                                    Text("7 days").tag(7)
                                    Text("14 days").tag(14)
                                    Text("30 days").tag(30)
                                }
                                .foregroundColor(.white)
                                .listRowBackground(LogbookTheme.navyLight)
                            }
                        } header: {
                            Text("Data & Sync")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var notificationStatusIcon: String {
        switch notificationStatus {
        case .authorized: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .provisional: return "bell.fill"
        case .notDetermined: return "bell"
        case .ephemeral: return "bell.fill"
        @unknown default: return "bell"
        }
    }
    
    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized: return .green
        case .denied: return .red
        case .provisional: return .orange
        default: return .gray
        }
    }
    
    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Enabled"
        case .denied: return "Disabled in Settings"
        case .provisional: return "Provisional"
        case .notDetermined: return "Not Configured"
        case .ephemeral: return "Temporary"
        @unknown default: return "Unknown"
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#if DEBUG
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}
#endif
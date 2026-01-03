//
//  NOCAlertSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/31/25.
//

import SwiftUI

struct NOCAlertSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nocSettings: NOCSettingsStore
    @ObservedObject var tripSettings = TripGenerationSettings.shared
    
    @State private var showingNotificationInfo = false

    // NOC Alert Settings
    @AppStorage("nocAlertsEnabled") private var nocAlertsEnabled: Bool = true
    @AppStorage("nocRevisionBannerEnabled") private var revisionBannerEnabled: Bool = true
    @AppStorage("nocNewTripAlerts") private var newTripAlerts: Bool = true
    @AppStorage("nocSyncNotifications") private var syncNotifications: Bool = false
    @AppStorage("nocAlertSound") private var alertSound: Bool = true

    // Quiet Hours
    @AppStorage("nocQuietHoursEnabled") private var quietHoursEnabled: Bool = false
    @AppStorage("nocQuietHoursStart") private var quietHoursStart: Int = 22 // 10 PM
    @AppStorage("nocQuietHoursEnd") private var quietHoursEnd: Int = 6 // 6 AM

    // Near-term filtering
    @AppStorage("nocOnlyNearTermAlerts") private var onlyNearTermAlerts: Bool = false
    @AppStorage("nocNearTermDays") private var nearTermDays: Int = 7

    var body: some View {
        NavigationView {
            List {
                // Master Toggle
                Section {
                    Toggle("NOC Alerts", isOn: $nocAlertsEnabled)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentGreen)
                        .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Master Control")
                        .foregroundColor(.white)
                } footer: {
                    Text("Disable to silence all NOC-related notifications")
                        .foregroundColor(.gray)
                }

                if nocAlertsEnabled {
                    // Schedule Revision Alerts
                    Section {
                        Toggle("Schedule Revision Alerts", isOn: $nocSettings.revisionNotificationsEnabled)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentOrange)
                            .listRowBackground(LogbookTheme.navyLight)

                        if nocSettings.revisionNotificationsEnabled {
                            Toggle("Show Revision Banner", isOn: $revisionBannerEnabled)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)

                            Toggle("Alert Sound", isOn: $alertSound)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            // NEW: Alert Window Control
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alert Window")
                                    .foregroundColor(.white)
                                Text("Only alert for changes within the next \(nocSettings.revisionAlertWindowDays) days")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Picker("Alert Window", selection: $nocSettings.revisionAlertWindowDays) {
                                    Text("3 days").tag(3)
                                    Text("5 days").tag(5)
                                    Text("7 days").tag(7)
                                    Text("14 days").tag(14)
                                    Text("30 days").tag(30)
                                }
                                .pickerStyle(.segmented)
                                .padding(.top, 4)
                            }
                            .listRowBackground(LogbookTheme.navyLight)
                            
                            // NEW: Throttle Control
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Throttle")
                                    .foregroundColor(.white)
                                Text("Minimum time between duplicate alerts: \(Int(nocSettings.minNotificationIntervalHours))h")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Picker("Throttle", selection: $nocSettings.minNotificationIntervalHours) {
                                    Text("6 hours").tag(6.0)
                                    Text("12 hours").tag(12.0)
                                    Text("24 hours").tag(24.0)
                                    Text("48 hours").tag(48.0)
                                }
                                .pickerStyle(.segmented)
                                .padding(.top, 4)
                            }
                            .listRowBackground(LogbookTheme.navyLight)
                        }
                    } header: {
                        Label("Schedule Changes", systemImage: "calendar.badge.exclamationmark")
                            .foregroundColor(.white)
                    } footer: {
                        Text("Get notified when your NOC schedule has pending revisions that need confirmation")
                            .foregroundColor(.gray)
                    }

                    // Trip Detection Alerts
                    Section {
                        Toggle("New Trip Detection", isOn: $newTripAlerts)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentGreen)
                            .listRowBackground(LogbookTheme.navyLight)

                        if newTripAlerts {
                            Toggle("Only Near-Term Trips", isOn: $onlyNearTermAlerts)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)

                            if onlyNearTermAlerts {
                                Picker("Alert Window", selection: $nearTermDays) {
                                    Text("3 days").tag(3)
                                    Text("5 days").tag(5)
                                    Text("7 days").tag(7)
                                    Text("14 days").tag(14)
                                }
                                .foregroundColor(.white)
                                .listRowBackground(LogbookTheme.navyLight)
                            }
                        }
                    } header: {
                        Label("Trip Detection", systemImage: "airplane.departure")
                            .foregroundColor(.white)
                    } footer: {
                        Text(onlyNearTermAlerts ? "Only alert for trips within the next \(nearTermDays) days" : "Alert for all new trips detected from your roster")
                            .foregroundColor(.gray)
                    }

                    // Sync Settings
                    Section {
                        Toggle("Sync Notifications", isOn: $syncNotifications)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentBlue)
                            .listRowBackground(LogbookTheme.navyLight)

                        Toggle("Auto-Sync", isOn: $nocSettings.autoSyncEnabled)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentGreen)
                            .listRowBackground(LogbookTheme.navyLight)

                        if nocSettings.autoSyncEnabled {
                            Picker("Sync Frequency", selection: $nocSettings.syncIntervalMinutes) {
                                Text("15 minutes").tag(15.0)
                                Text("30 minutes").tag(30.0)
                                Text("1 hour").tag(60.0)
                                Text("2 hours").tag(120.0)
                                Text("4 hours").tag(240.0)
                            }
                            .foregroundColor(.white)
                            .listRowBackground(LogbookTheme.navyLight)
                        }
                    } header: {
                        Label("Background Sync", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white)
                    } footer: {
                        if nocSettings.autoSyncEnabled {
                            if let lastSync = nocSettings.lastSyncTime {
                                Text("Last sync: \(lastSync, style: .relative) ago")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Automatically checks for schedule changes")
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text("Manual sync only - open NOC Settings to sync")
                                .foregroundColor(.gray)
                        }
                    }

                    // Quiet Hours
                    Section {
                        Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentOrange)
                            .listRowBackground(LogbookTheme.navyLight)

                        if quietHoursEnabled {
                            Toggle("Apply to Revisions", isOn: $nocSettings.respectQuietHours)
                                .foregroundColor(.white)
                                .tint(LogbookTheme.accentBlue)
                                .listRowBackground(LogbookTheme.navyLight)
                            
                            HStack {
                                Text("Start")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $quietHoursStart) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(LogbookTheme.accentBlue)
                            }
                            .listRowBackground(LogbookTheme.navyLight)

                            HStack {
                                Text("End")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $quietHoursEnd) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(LogbookTheme.accentBlue)
                            }
                            .listRowBackground(LogbookTheme.navyLight)
                        }
                    } header: {
                        Label("Quiet Hours", systemImage: "moon.fill")
                            .foregroundColor(.white)
                    } footer: {
                        if quietHoursEnabled {
                            Text("NOC alerts will be silenced from \(formatHour(quietHoursStart)) to \(formatHour(quietHoursEnd))")
                                .foregroundColor(.gray)
                        } else {
                            Text("Suppress alerts during sleep or rest periods")
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Current Status
                Section {
                    if nocSettings.hasPendingRevision {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Pending Revision")
                                    .foregroundColor(.white)
                                if let detectedAt = nocSettings.pendingRevisionDetectedAt {
                                    Text("Detected \(detectedAt, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Button("Confirm") {
                                nocSettings.openNOCForConfirmation()
                            }
                            .font(.caption.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No pending revisions")
                                .foregroundColor(.white)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                } header: {
                    Label("Status", systemImage: "info.circle")
                        .foregroundColor(.white)
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("NOC Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingNotificationInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .sheet(isPresented: $showingNotificationInfo) {
                NOCNotificationInfoView()
                    .environmentObject(nocSettings)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

#if DEBUG
struct NOCAlertSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NOCAlertSettingsView()
            .environmentObject(NOCSettingsStore.shared)
    }
}
#endif

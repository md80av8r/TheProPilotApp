//
//  NOCNotificationInfoView.swift
//  TheProPilotApp
//
//  A helpful guide explaining how NOC revision notifications work
//

import SwiftUI

struct NOCNotificationInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nocSettings: NOCSettingsStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 60))
                            .foregroundColor(LogbookTheme.accentOrange)
                        
                        Text("How Revision Alerts Work")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Smart notifications that prevent spam while keeping you informed")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // Current Configuration
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                Text("Your Current Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            SettingRow(
                                icon: "bell.fill",
                                label: "Revision Alerts",
                                value: nocSettings.revisionNotificationsEnabled ? "Enabled" : "Disabled",
                                color: nocSettings.revisionNotificationsEnabled ? .green : .gray
                            )
                            
                            SettingRow(
                                icon: "calendar",
                                label: "Alert Window",
                                value: "\(nocSettings.revisionAlertWindowDays) days",
                                color: LogbookTheme.accentBlue
                            )
                            
                            SettingRow(
                                icon: "timer",
                                label: "Throttle",
                                value: "\(Int(nocSettings.minNotificationIntervalHours))h minimum",
                                color: LogbookTheme.accentOrange
                            )
                            
                            SettingRow(
                                icon: "moon.fill",
                                label: "Quiet Hours",
                                value: nocSettings.respectQuietHours ? "Respected" : "Ignored",
                                color: nocSettings.respectQuietHours ? .purple : .gray
                            )
                        }
                        .padding(8)
                    }
                    .backgroundStyle(LogbookTheme.navyLight)
                    
                    // How It Works
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("How It Works")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            FeatureCard(
                                emoji: "🔍",
                                title: "Smart Detection",
                                description: "Only actual schedule changes trigger alerts. Metadata updates are ignored."
                            )
                            
                            FeatureCard(
                                emoji: "📅",
                                title: "Relevance Filter",
                                description: "Only changes within your \(nocSettings.revisionAlertWindowDays)-day window trigger notifications. Far-future changes are tracked but silent."
                            )
                            
                            FeatureCard(
                                emoji: "🔇",
                                title: "Deduplication",
                                description: "Auto-sync won't spam you. Each unique revision only notifies once, no matter how many times it syncs."
                            )
                            
                            FeatureCard(
                                emoji: "⏱️",
                                title: "Throttling",
                                description: "Maximum one notification per \(Int(nocSettings.minNotificationIntervalHours)) hours prevents alert fatigue."
                            )
                            
                            if nocSettings.respectQuietHours {
                                FeatureCard(
                                    emoji: "🌙",
                                    title: "Quiet Hours",
                                    description: "Revision alerts respect your rest periods. Revisions still flag in-app."
                                )
                            }
                        }
                        .padding(8)
                    }
                    .backgroundStyle(LogbookTheme.navyLight)
                    
                    // When You'll Get Notified
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("You'll Get Notified When")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            NotificationCondition(included: true, text: "Schedule changes within \(nocSettings.revisionAlertWindowDays) days")
                            NotificationCondition(included: true, text: "It's a new/different revision")
                            NotificationCondition(included: true, text: "Not during quiet hours")
                            NotificationCondition(included: true, text: "Throttle period has passed")
                        }
                        .padding(8)
                    }
                    .backgroundStyle(LogbookTheme.navyLight)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("You Won't Get Notified When")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            NotificationCondition(included: false, text: "Auto-sync runs but schedule unchanged")
                            NotificationCondition(included: false, text: "Already notified about this revision")
                            NotificationCondition(included: false, text: "Changes are beyond \(nocSettings.revisionAlertWindowDays)-day window")
                            NotificationCondition(included: false, text: "During quiet hours (if enabled)")
                            NotificationCondition(included: false, text: "Within \(Int(nocSettings.minNotificationIntervalHours))h throttle window")
                        }
                        .padding(8)
                    }
                    .backgroundStyle(LogbookTheme.navyLight)
                    
                    // Quick Tips
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Pro Tips")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            TipRow(tip: "Schedule changes frequently? Increase throttle to 24h")
                            TipRow(tip: "Need immediate updates? Reduce auto-sync to 15 min")
                            TipRow(tip: "Commuter? Use quiet hours during rest periods")
                            TipRow(tip: "On reserve? Use 3-day alert window for urgency")
                        }
                        .padding(8)
                    }
                    .backgroundStyle(LogbookTheme.navyLight)
                    
                    // Status
                    if nocSettings.hasPendingRevision {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Pending Revision")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                if let detectedAt = nocSettings.pendingRevisionDetectedAt {
                                    Text("Detected \(detectedAt, style: .relative) ago")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Button {
                                    nocSettings.openNOCForConfirmation()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.right.circle.fill")
                                        Text("Open NOC to Confirm")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(LogbookTheme.accentOrange)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 8)
                            }
                            .padding(8)
                        }
                        .backgroundStyle(Color.orange.opacity(0.1))
                    }
                    
                }
                .padding()
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Notification Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SettingRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
    }
}

struct FeatureCard: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct NotificationCondition: View {
    let included: Bool
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(included ? .green : .red)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TipRow: View {
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            
            Text(tip)
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NOCNotificationInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NOCNotificationInfoView()
            .environmentObject(NOCSettingsStore.shared)
    }
}
#endif

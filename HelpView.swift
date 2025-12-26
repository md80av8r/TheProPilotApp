//
//  HelpView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/22/25.
//


//
//  HelpView.swift
//  TheProPilotApp
//
//  Comprehensive help and support section
//

import SwiftUI

struct HelpView: View {
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        NavigationView {
            List {
                // Search within help
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search help articles", text: $searchText)
                    }
                }
                
                // Quick Actions
                Section("Quick Actions") {
                    HelpQuickActionRow(
                        icon: "message.fill",
                        iconColor: .blue,
                        title: "Contact Support",
                        subtitle: "Get help from our team"
                    ) {
                        // Open email or support form
                        openSupport()
                    }
                    
                    HelpQuickActionRow(
                        icon: "video.fill",
                        iconColor: .red,
                        title: "Video Tutorials",
                        subtitle: "Watch how-to videos"
                    ) {
                        // Open video tutorials
                        openVideoTutorials()
                    }
                    
                    HelpQuickActionRow(
                        icon: "star.fill",
                        iconColor: .orange,
                        title: "What's New",
                        subtitle: "Latest features and updates"
                    ) {
                        // Show changelog
                    }
                }
                
                // Getting Started
                HelpSection(
                    title: "Getting Started",
                    icon: "airplane.departure",
                    items: [
                        HelpArticle(
                            title: "Logging Your First Flight",
                            content: """
                            To log a flight manually:
                            
                            1. Tap the green "New Trip" button
                            2. Enter trip number and date
                            3. Add flight legs with OUT, OFF, ON, IN times
                            4. Times are automatically calculated
                            5. Save your trip
                            
                            Tip: Block time = OUT to IN
                            Flight time = OFF to ON
                            """
                        ),
                        HelpArticle(
                            title: "Importing NOC Schedule",
                            content: """
                            Import your roster automatically:
                            
                            1. Go to "NOC Schedule Import"
                            2. Tap "Import from Email"
                            3. Forward your NOC schedule email
                            4. Or paste NOC HTML directly
                            5. Review and confirm trips
                            
                            Supported airlines: Major US carriers
                            Updates: Monthly roster imports
                            """
                        ),
                        HelpArticle(
                            title: "Understanding Duty Time",
                            content: """
                            Duty time is automatically calculated:
                            
                            • Starts: 60 minutes before first OUT
                            • Ends: 15 minutes after last IN
                            • Customizable in Settings
                            
                            Manual override available per trip.
                            """
                        )
                    ],
                    expandedSections: $expandedSections
                )
                
                // Features
                HelpSection(
                    title: "Features & Tools",
                    icon: "wrench.and.screwdriver.fill",
                    items: [
                        HelpArticle(
                            title: "CloudKit Sync",
                            content: """
                            Your data syncs across all devices:
                            
                            • iPhone, iPad, Apple Watch
                            • Automatic background sync
                            • Works offline, syncs when online
                            • End-to-end encrypted
                            
                            Make sure you're signed into iCloud.
                            """
                        ),
                        HelpArticle(
                            title: "Flight Time Limits",
                            content: """
                            Track compliance automatically:
                            
                            • 30-Day Flight Time (100 hrs)
                            • Annual Flight Time (1,000 hrs)
                            • 30-Day FDP (100 hrs duty)
                            • Configurable for Part 121/135
                            
                            View in Flight Time Limits card.
                            """
                        ),
                        HelpArticle(
                            title: "CSV Import/Export",
                            content: """
                            Compatible with ForeFlight:
                            
                            Import:
                            1. Export CSV from ForeFlight
                            2. Tap "Import Flight Data"
                            3. Select your CSV file
                            4. Review and import
                            
                            Export:
                            1. Tap export in Logbook
                            2. Choose date range
                            3. Share CSV file
                            """
                        ),
                        HelpArticle(
                            title: "Apple Watch App",
                            content: """
                            Track flights from your wrist:
                            
                            • View recent trips
                            • See flight time totals
                            • Quick duty status
                            • Sync with iPhone
                            
                            Requires Apple Watch Series 4+
                            """
                        )
                    ],
                    expandedSections: $expandedSections
                )
                
                // FAQ
                HelpSection(
                    title: "Frequently Asked Questions",
                    icon: "questionmark.circle.fill",
                    items: [
                        HelpArticle(
                            title: "How do I backup my logbook?",
                            content: """
                            Your logbook is backed up automatically:
                            
                            • CloudKit backup (iCloud)
                            • Export CSV for local backup
                            • Restore from iCloud anytime
                            
                            We recommend exporting CSV monthly
                            for an additional local backup.
                            """
                        ),
                        HelpArticle(
                            title: "Can I use this offline?",
                            content: """
                            Yes! The app works fully offline:
                            
                            • Log flights without internet
                            • View all data locally
                            • Syncs when connection returns
                            
                            NOC import requires internet.
                            """
                        ),
                        HelpArticle(
                            title: "How accurate are the calculations?",
                            content: """
                            All calculations follow FAA standards:
                            
                            • Block time: OUT to IN
                            • Flight time: OFF to ON
                            • Night time: Civil twilight
                            • Duty time: Pre/post flight buffer
                            
                            Calculations verified against FAR 121/135.
                            """
                        ),
                        HelpArticle(
                            title: "What's included in Pro subscription?",
                            content: """
                            Pro unlocks everything:
                            
                            ✓ Unlimited trips (free = 10 max)
                            ✓ NOC schedule integration
                            ✓ Automatic duty time tracking
                            ✓ CloudKit sync across devices
                            ✓ Apple Watch app
                            ✓ Compliance tracking
                            ✓ Priority support
                            
                            Try free for 7 days!
                            """
                        )
                    ],
                    expandedSections: $expandedSections
                )
                
                // Troubleshooting
                HelpSection(
                    title: "Troubleshooting",
                    icon: "exclamationmark.triangle.fill",
                    items: [
                        HelpArticle(
                            title: "Sync not working",
                            content: """
                            If CloudKit sync fails:
                            
                            1. Check iCloud settings
                            2. Verify internet connection
                            3. Sign out/in of iCloud
                            4. Force quit and reopen app
                            5. Check iCloud storage space
                            
                            Still issues? Contact support.
                            """
                        ),
                        HelpArticle(
                            title: "Missing trips after update",
                            content: """
                            Data recovery options:
                            
                            1. Check "All Trips" filter
                            2. Wait for iCloud sync (5-10 min)
                            3. Use "Attempt Recovery" button
                            4. Restore from CSV backup
                            
                            Contact support with details.
                            """
                        ),
                        HelpArticle(
                            title: "NOC import not working",
                            content: """
                            NOC import troubleshooting:
                            
                            1. Verify email format
                            2. Check airline is supported
                            3. Ensure schedule is current
                            4. Try pasting HTML directly
                            5. Update app to latest version
                            
                            Send sample to support@propilotapp.com
                            """
                        )
                    ],
                    expandedSections: $expandedSections
                )
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion())
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://propilotapp.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://propilotapp.com/terms")!)
                    
                    Button("Rate App on App Store") {
                        rateApp()
                    }
                }
            }
            .navigationTitle("Help & Support")
            .searchable(text: $searchText, prompt: "Search help")
        }
    }
    
    // MARK: - Helper Functions
    
    private func openSupport() {
        let email = "support@propilotapp.com"
        let subject = "Support Request"
        let body = """
        
        
        ---
        App Version: \(appVersion())
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
        
        let encoded = "mailto:\(email)?subject=\(subject)&body=\(body)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        if let url = URL(string: encoded ?? "") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openVideoTutorials() {
        if let url = URL(string: "https://propilotapp.com/tutorials") {
            UIApplication.shared.open(url)
        }
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id6748836146?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Help Article Model

struct HelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

// MARK: - Help Section

struct HelpSection: View {
    let title: String
    let icon: String
    let items: [HelpArticle]
    @Binding var expandedSections: Set<String>
    
    var body: some View {
        Section(header: Label(title, systemImage: icon)) {
            ForEach(items) { article in
                HelpArticleRow(
                    article: article,
                    isExpanded: expandedSections.contains(article.id.uuidString)
                ) {
                    if expandedSections.contains(article.id.uuidString) {
                        expandedSections.remove(article.id.uuidString)
                    } else {
                        expandedSections.insert(article.id.uuidString)
                    }
                }
            }
        }
    }
}

// MARK: - Help Article Row

struct HelpArticleRow: View {
    let article: HelpArticle
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isExpanded {
                    Text(article.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Action Row

struct HelpQuickActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(iconColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
    }
}

// MARK: - Preview

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}

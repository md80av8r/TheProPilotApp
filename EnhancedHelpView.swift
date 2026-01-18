//
//  EnhancedHelpView.swift
//  TheProPilotApp
//
//  Created by Claude on 1/17/26.
//  Enhanced help system with interactive features, onboarding checklist, and feature discovery
//

import SwiftUI

// MARK: - Enhanced Help View
struct EnhancedHelpView: View {
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []
    @State private var showingFeatureTour = false
    @State private var showingWhatsNew = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingChecklistState") private var checklistStateData = Data()
    @StateObject private var checklistState = OnboardingChecklistState()

    var body: some View {
        NavigationView {
            List {
                // NEW: Getting Started Checklist (if not complete)
                if !hasCompletedOnboarding {
                    gettingStartedChecklist
                }

                // NEW: Feature Discovery
                featureDiscoverySection

                // Search within help
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search help articles", text: $searchText)
                    }
                }

                // Quick Actions (Enhanced)
                Section("Quick Actions") {
                    HelpQuickActionRow(
                        icon: "play.circle.fill",
                        iconColor: .green,
                        title: "Start Feature Tour",
                        subtitle: "Interactive walkthrough of key features"
                    ) {
                        showingFeatureTour = true
                    }

                    HelpQuickActionRow(
                        icon: "message.fill",
                        iconColor: .blue,
                        title: "Contact Support",
                        subtitle: "Get help from our team"
                    ) {
                        openSupport()
                    }

                    HelpQuickActionRow(
                        icon: "video.fill",
                        iconColor: .red,
                        title: "Video Tutorials",
                        subtitle: "Watch how-to videos"
                    ) {
                        openVideoTutorials()
                    }

                    HelpQuickActionRow(
                        icon: "star.fill",
                        iconColor: .orange,
                        title: "What's New",
                        subtitle: "Latest features and updates"
                    ) {
                        showingWhatsNew = true
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
                            title: "GPS Track Recording",
                            content: """
                            Record your flight paths automatically:

                            • Auto-starts on takeoff (>80 kts)
                            • Auto-stops on landing (<60 kts)
                            • Detects departure/arrival airports
                            • Shows OFF/ON times from GPS data

                            View tracks in Trip Details or export:
                            • GPX format (standard GPS)
                            • KML format (Google Earth 3D)

                            Open directly in Apple Maps or Google Earth!
                            """
                        ),
                        HelpArticle(
                            title: "Airport Proximity Alerts",
                            content: """
                            Automatic detection when you arrive:

                            • Geofencing for 20 priority airports
                            • Auto-prompt to start duty timer
                            • OPS calling reminders
                            • Configurable in Settings

                            Enable Location "Always" for best results.
                            Access via Settings > Airport Proximity.
                            """
                        ),
                        HelpArticle(
                            title: "Auto Time Logging",
                            content: """
                            GPS-based automatic time capture:

                            • Takeoff detected at 80+ knots
                            • Landing detected at 60 knots
                            • Optional 5-minute rounding
                            • Zulu or Local time option
                            • GPS spoofing detection included

                            Configure in Settings > Auto Time Logging.
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
                            title: "Smart Search",
                            content: """
                            Find anything instantly:

                            • Search app features and settings
                            • Search help articles
                            • Search your flight logs

                            All in one unified search experience!
                            Access from More > Smart Search.
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
                        ),
                        HelpArticle(
                            title: "Where can I find specific features?",
                            content: """
                            Use Smart Search to find anything:

                            1. Tap More > Smart Search
                            2. Type what you're looking for
                            3. Get instant results for features, help, and flights

                            Or explore organized sections in the More menu!
                            """
                        ),
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
        }
        .sheet(isPresented: $showingFeatureTour) {
            FeatureTourView()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView()
        }
        .onAppear {
            loadChecklistState()
        }
    }

    // MARK: - Getting Started Checklist
    private var gettingStartedChecklist: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Getting Started")
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("\(checklistState.completedCount)/\(checklistState.totalCount) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 3)

                        Circle()
                            .trim(from: 0, to: checklistState.progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(checklistState.progress * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .frame(width: 50, height: 50)
                }

                // Checklist items
                ForEach(checklistState.items) { item in
                    ChecklistItemRow(item: item) {
                        checklistState.toggle(item.id)
                        saveChecklistState()
                    }
                }

                // Dismiss button (if all complete)
                if checklistState.isComplete {
                    Button(action: {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }) {
                        HStack {
                            Spacer()
                            Label("All Done! Hide Checklist", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Label("Start Here", systemImage: "sparkles")
        }
    }

    // MARK: - Feature Discovery
    private var featureDiscoverySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Did You Know?", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.orange)

                FeatureDiscoveryCard(
                    icon: "magnifyingglass.circle.fill",
                    iconColor: .blue,
                    title: "Smart Search is Here!",
                    description: "Search app features, help articles, and your flight logs all in one place."
                )

                FeatureDiscoveryCard(
                    icon: "location.fill",
                    iconColor: .purple,
                    title: "GPS Track Recording",
                    description: "Your flights are automatically recorded and can be exported to Google Earth!"
                )
            }
            .padding(.vertical, 8)
        } header: {
            Text("Discover Features")
        }
    }

    // MARK: - Helper Functions
    private func loadChecklistState() {
        if let decoded = try? JSONDecoder().decode(OnboardingChecklistState.self, from: checklistStateData) {
            checklistState.items = decoded.items
        }
    }

    private func saveChecklistState() {
        if let encoded = try? JSONEncoder().encode(checklistState) {
            checklistStateData = encoded
        }
    }

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

// MARK: - Onboarding Checklist State
class OnboardingChecklistState: ObservableObject, Codable {
    @Published var items: [ChecklistItem]

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    var isComplete: Bool {
        completedCount == totalCount
    }

    init() {
        self.items = [
            ChecklistItem(
                id: "airline_setup",
                title: "Set up your airline",
                description: "Configure airline-specific settings",
                icon: "building.2.fill",
                destination: "airlineConfig"
            ),
            ChecklistItem(
                id: "first_flight",
                title: "Log your first flight",
                description: "Manually create a trip and add legs",
                icon: "airplane.departure",
                destination: "logbook"
            ),
            ChecklistItem(
                id: "noc_import",
                title: "Import NOC schedule",
                description: "Automatically sync your roster",
                icon: "calendar.badge.clock",
                destination: "nocSchedule"
            ),
            ChecklistItem(
                id: "auto_time",
                title: "Enable Auto Time Logging",
                description: "Let GPS automatically capture takeoff/landing times",
                icon: "clock.arrow.2.circlepath",
                destination: "autoTimeLogging"
            ),
            ChecklistItem(
                id: "smart_search",
                title: "Try Smart Search",
                description: "Find features, help, and flights instantly",
                icon: "magnifyingglass.circle.fill",
                destination: "smartSearch"
            ),
        ]
    }

    func toggle(_ id: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            objectWillChange.send()
        }
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case items
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([ChecklistItem].self, forKey: .items)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }
}

// MARK: - Checklist Item
struct ChecklistItem: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let destination: String
    var isCompleted: Bool = false
}

// MARK: - Checklist Item Row
struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isCompleted ? .green : .secondary)

                // Icon
                Image(systemName: item.icon)
                    .foregroundColor(.blue)
                    .frame(width: 28)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .strikethrough(item.isCompleted)

                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Discovery Card
struct FeatureDiscoveryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Feature Tour View
struct FeatureTourView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0

    let tourPages = [
        TourPage(
            icon: "book.closed.fill",
            iconColor: .blue,
            title: "Welcome to ProPilot",
            description: "Your comprehensive flight logbook and pilot tools, designed by pilots for pilots."
        ),
        TourPage(
            icon: "location.fill",
            iconColor: .purple,
            title: "GPS Track Recording",
            description: "Automatically record every flight. Tracks start on takeoff and stop on landing. Export to Google Earth!"
        ),
        TourPage(
            icon: "clock.arrow.2.circlepath",
            iconColor: .orange,
            title: "Auto Time Logging",
            description: "GPS detects takeoff and landing, automatically capturing your OFF and ON times."
        ),
        TourPage(
            icon: "calendar.badge.clock",
            iconColor: .green,
            title: "NOC Schedule Import",
            description: "Import your airline roster automatically. Just forward your NOC email and review."
        ),
        TourPage(
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            title: "Smart Search",
            description: "Find anything instantly - app features, help articles, or specific flights."
        ),
        TourPage(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "Ready to Fly!",
            description: "You're all set! Explore the app and check out the Getting Started checklist in Help."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<tourPages.count, id: \.self) { index in
                    TourPageView(page: tourPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                if currentPage < tourPages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Get Started") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Tour Page Model
struct TourPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

// MARK: - Tour Page View
struct TourPageView: View {
    let page: TourPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.iconColor)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - What's New View
struct WhatsNewView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("January 2026")
                            .font(.title2)
                            .fontWeight(.bold)

                        WhatsNewItem(
                            icon: "magnifyingglass.circle.fill",
                            iconColor: .blue,
                            title: "Smart Search",
                            description: "New unified search that finds app features, help articles, and your flights all in one place!"
                        )

                        WhatsNewItem(
                            icon: "questionmark.circle.fill",
                            iconColor: .cyan,
                            title: "Enhanced Help System",
                            description: "Interactive feature tour, getting started checklist, and improved help articles."
                        )

                        WhatsNewItem(
                            icon: "slider.horizontal.3",
                            iconColor: .purple,
                            title: "Reorganized More Menu",
                            description: "Features are now better organized with Help & Support at the top for easy access."
                        )
                    }
                    .padding(.vertical)
                }

                Section("December 2025") {
                    WhatsNewItem(
                        icon: "location.fill",
                        iconColor: .purple,
                        title: "GPS Track Recording",
                        description: "Automatically record flight paths with export to Google Earth."
                    )

                    WhatsNewItem(
                        icon: "clock.arrow.2.circlepath",
                        iconColor: .orange,
                        title: "Auto Time Logging",
                        description: "GPS-based automatic takeoff/landing detection."
                    )
                }
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - What's New Item
struct WhatsNewItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct EnhancedHelpView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedHelpView()
    }
}

//
//  UniversalSearchView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/31/25.
//

import SwiftUI

// MARK: - Searchable Item Model
struct SearchableItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let keywords: [String]
    let icon: String
    let iconColor: Color
    let category: SearchCategory
    let destination: SearchDestination

    func matches(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()

        // Check title
        if title.lowercased().contains(lowercasedQuery) { return true }

        // Check subtitle
        if subtitle.lowercased().contains(lowercasedQuery) { return true }

        // Check keywords
        for keyword in keywords {
            if keyword.lowercased().contains(lowercasedQuery) { return true }
        }

        return false
    }

    // Relevance score for sorting results
    func relevanceScore(for query: String) -> Int {
        let lowercasedQuery = query.lowercased()
        var score = 0

        // Exact title match = highest priority
        if title.lowercased() == lowercasedQuery { score += 100 }
        // Title starts with query
        else if title.lowercased().hasPrefix(lowercasedQuery) { score += 50 }
        // Title contains query
        else if title.lowercased().contains(lowercasedQuery) { score += 25 }

        // Keyword exact match
        if keywords.contains(where: { $0.lowercased() == lowercasedQuery }) { score += 40 }
        // Keyword contains
        else if keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) { score += 15 }

        // Subtitle contains
        if subtitle.lowercased().contains(lowercasedQuery) { score += 10 }

        return score
    }
}

// MARK: - Search Categories
enum SearchCategory: String, CaseIterable {
    case feature = "Features"
    case setting = "Settings"
    case tool = "Tools"
    case help = "Help"

    var icon: String {
        switch self {
        case .feature: return "square.grid.2x2"
        case .setting: return "gear"
        case .tool: return "wrench.and.screwdriver"
        case .help: return "questionmark.circle"
        }
    }
}

// MARK: - Search Destination
enum SearchDestination: Hashable {
    case tab(String)           // Navigate to a tab by ID
    case settingsSection(String, String) // Tab ID + section identifier
    case url(String)           // Open external URL
    case action(String)        // Perform an action
}

// MARK: - App Search Index
class AppSearchIndex: ObservableObject {
    static let shared = AppSearchIndex()

    @Published var allItems: [SearchableItem] = []

    init() {
        buildIndex()
    }

    private func buildIndex() {
        allItems = [
            // ═══════════════════════════════════════════════════════════════
            // FEATURES - Main app screens/tabs
            // ═══════════════════════════════════════════════════════════════

            // Logbook
            SearchableItem(
                title: "Logbook",
                subtitle: "View and manage your flight records",
                keywords: ["flights", "trips", "records", "log", "history"],
                icon: "book.closed",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("logbook")
            ),

            // Schedule
            SearchableItem(
                title: "Schedule",
                subtitle: "View your upcoming flights and roster",
                keywords: ["calendar", "roster", "upcoming", "trips", "pairing"],
                icon: "calendar",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("schedule")
            ),

            // Time Away / Per Diem
            SearchableItem(
                title: "Time Away / Per Diem",
                subtitle: "Track time away from base and earnings",
                keywords: ["per diem", "money", "pay", "overnight", "tafb", "earnings"],
                icon: "clock.arrow.circlepath",
                iconColor: LogbookTheme.accentGreen,
                category: .feature,
                destination: .tab("perDiem")
            ),

            // Weather
            SearchableItem(
                title: "Weather",
                subtitle: "Check aviation weather and METARs",
                keywords: ["metar", "taf", "wx", "forecast", "winds", "ceiling", "visibility"],
                icon: "cloud.sun.fill",
                iconColor: .cyan,
                category: .feature,
                destination: .tab("weather")
            ),

            // Flight Calculator
            SearchableItem(
                title: "Flight Calculator",
                subtitle: "Fuel, crosswind, density altitude calculations",
                keywords: ["fuel", "crosswind", "density altitude", "calculator", "math", "compute"],
                icon: "function",
                iconColor: LogbookTheme.accentOrange,
                category: .feature,
                destination: .tab("calculator")
            ),

            // World Clock
            SearchableItem(
                title: "World Clock",
                subtitle: "Zulu time, local time, and timers",
                keywords: ["zulu", "utc", "gmt", "time", "clock", "timer", "stopwatch"],
                icon: "clock.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("clocks")
            ),

            // Document Scanner
            SearchableItem(
                title: "Document Scanner",
                subtitle: "Scan fuel receipts and trip documents",
                keywords: ["scan", "camera", "receipt", "fuel", "document", "photo"],
                icon: "doc.viewfinder",
                iconColor: LogbookTheme.accentOrange,
                category: .feature,
                destination: .tab("scanner")
            ),

            // Crew Contacts
            SearchableItem(
                title: "Crew Contacts",
                subtitle: "Manage crew member information",
                keywords: ["crew", "pilot", "captain", "first officer", "contacts", "phone"],
                icon: "person.3.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("crewContacts")
            ),

            // GPS RAIM
            SearchableItem(
                title: "GPS RAIM",
                subtitle: "Check GPS accuracy and integrity",
                keywords: ["gps", "raim", "satellite", "navigation", "rnav", "accuracy"],
                icon: "location.fill",
                iconColor: .purple,
                category: .feature,
                destination: .tab("gpsRaim")
            ),

            // Area Guide
            SearchableItem(
                title: "Area Guide",
                subtitle: "Airport info, hotels, restaurants, transportation",
                keywords: ["hotel", "restaurant", "food", "uber", "lyft", "transportation", "layover"],
                icon: "map.fill",
                iconColor: LogbookTheme.accentGreen,
                category: .feature,
                destination: .tab("areaGuide")
            ),

            // Electronic Logbook
            SearchableItem(
                title: "Electronic Logbook",
                subtitle: "Import/Export ForeFlight & LogTen Pro",
                keywords: ["foreflight", "logten", "export", "import", "csv", "backup"],
                icon: "book.closed.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("electronicLogbook")
            ),

            // 30-Day Rolling
            SearchableItem(
                title: "30-Day Rolling Hours",
                subtitle: "FAR 121 flight time limit tracking",
                keywords: ["30 day", "rolling", "hours", "limit", "far 121", "100 hours"],
                icon: "gauge.with.needle.fill",
                iconColor: LogbookTheme.accentGreen,
                category: .feature,
                destination: .tab("rolling30Day")
            ),

            // FAR 117 Compliance
            SearchableItem(
                title: "FAR 117 Compliance",
                subtitle: "Duty time and rest requirements",
                keywords: ["far 117", "duty", "rest", "fdp", "flight duty period", "compliance"],
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .red,
                category: .feature,
                destination: .tab("far117Compliance")
            ),

            // Apple Watch
            SearchableItem(
                title: "Apple Watch",
                subtitle: "Watch connection and sync status",
                keywords: ["watch", "apple watch", "sync", "wearable"],
                icon: "applewatch",
                iconColor: .pink,
                category: .feature,
                destination: .tab("appleWatch")
            ),

            // ═══════════════════════════════════════════════════════════════
            // SETTINGS - Configuration options
            // ═══════════════════════════════════════════════════════════════

            // NOC Schedule Import
            SearchableItem(
                title: "NOC Schedule Import",
                subtitle: "Import roster from NOC/Navblue system",
                keywords: ["noc", "navblue", "roster", "import", "schedule", "raido", "ical"],
                icon: "calendar.badge.clock",
                iconColor: LogbookTheme.accentGreen,
                category: .setting,
                destination: .tab("nocSchedule")
            ),

            // NOC Alert Settings
            SearchableItem(
                title: "NOC Alert Settings",
                subtitle: "Manage schedule change notifications",
                keywords: ["noc", "alerts", "notifications", "revision", "schedule change", "quiet hours"],
                icon: "bell.badge.fill",
                iconColor: .orange,
                category: .setting,
                destination: .tab("nocAlertSettings")
            ),

            // Trip Generation
            SearchableItem(
                title: "Trip Generation",
                subtitle: "Auto-detect trips from NOC roster",
                keywords: ["trip", "generate", "auto", "detect", "create", "roster"],
                icon: "wand.and.stars",
                iconColor: .purple,
                category: .setting,
                destination: .tab("tripGeneration")
            ),

            // Airline Configuration
            SearchableItem(
                title: "Airline Configuration",
                subtitle: "Airline name, callsign, home base",
                keywords: ["airline", "callsign", "base", "hub", "company", "carrier"],
                icon: "building.2.fill",
                iconColor: LogbookTheme.accentGreen,
                category: .setting,
                destination: .settingsSection("settings", "airlineSetup")
            ),

            // Home Base Configuration
            SearchableItem(
                title: "Home Base Configuration",
                subtitle: "Set your primary airport hub",
                keywords: ["home", "base", "hub", "primary", "airport", "domicile"],
                icon: "house.circle.fill",
                iconColor: LogbookTheme.accentGreen,
                category: .setting,
                destination: .settingsSection("settings", "homeBase")
            ),

            // Aircraft Database
            SearchableItem(
                title: "Aircraft Database",
                subtitle: "Manage fleet aircraft and tail numbers",
                keywords: ["aircraft", "tail", "fleet", "airplane", "type", "registration"],
                icon: "airplane.circle.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .setting,
                destination: .tab("aircraftDatabase")
            ),

            // Auto Time Logging
            SearchableItem(
                title: "Auto Time Logging",
                subtitle: "GPS speed tracking and time rounding",
                keywords: ["auto", "gps", "speed", "rounding", "block time", "automatic"],
                icon: "clock.arrow.2.circlepath",
                iconColor: LogbookTheme.accentOrange,
                category: .setting,
                destination: .settingsSection("settings", "autoTime")
            ),

            // GPS Track Recording
            SearchableItem(
                title: "GPS Track Recording",
                subtitle: "Record flight paths and export GPX/KML",
                keywords: ["gps", "track", "recording", "gpx", "kml", "google earth", "flight path", "route"],
                icon: "location.north.line.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .feature,
                destination: .tab("flightTracks")
            ),

            // Airport Proximity
            SearchableItem(
                title: "Airport Proximity Alerts",
                subtitle: "Geofencing and arrival detection",
                keywords: ["proximity", "geofence", "airport", "arrival", "detection", "duty", "ops calling"],
                icon: "location.circle",
                iconColor: LogbookTheme.accentGreen,
                category: .setting,
                destination: .settingsSection("settings", "proximity")
            ),

            // Trip Counting
            SearchableItem(
                title: "Trip Counting Settings",
                subtitle: "Configure how trips are counted",
                keywords: ["trip", "count", "counting", "method", "statistics", "deadhead", "trip pay", "usa jet"],
                icon: "number.circle",
                iconColor: LogbookTheme.accentOrange,
                category: .setting,
                destination: .settingsSection("settings", "tripCounting")
            ),

            // Mileage Tracking
            SearchableItem(
                title: "Mileage Tracking",
                subtitle: "Track distance and mileage pay",
                keywords: ["mileage", "distance", "pay", "nautical miles", "road", "miles", "nm", "dollar per mile"],
                icon: "road.lanes",
                iconColor: LogbookTheme.accentOrange,
                category: .setting,
                destination: .settingsSection("settings", "mileage")
            ),

            // Scanner & Email
            SearchableItem(
                title: "Scanner & Email Settings",
                subtitle: "Configure email destinations for documents",
                keywords: ["scanner", "email", "send", "recipient", "document"],
                icon: "envelope.fill",
                iconColor: LogbookTheme.accentOrange,
                category: .setting,
                destination: .settingsSection("settings", "scannerEmail")
            ),

            // Backup & Restore
            SearchableItem(
                title: "Backup & Restore",
                subtitle: "Manage automatic and manual backups",
                keywords: ["backup", "restore", "data", "save", "export", "icloud"],
                icon: "externaldrive.fill.badge.timemachine",
                iconColor: LogbookTheme.accentOrange,
                category: .setting,
                destination: .tab("dataBackup")
            ),

            // FAR 117 Settings
            SearchableItem(
                title: "FAR 117 Settings",
                subtitle: "Flight time limits and rest requirements",
                keywords: ["far 117", "limits", "rest", "duty", "settings", "configuration"],
                icon: "clock.badge.exclamationmark",
                iconColor: .red,
                category: .setting,
                destination: .tab("flightTimeLimits")
            ),

            // Airport Database
            SearchableItem(
                title: "Airport Database",
                subtitle: "Manage airport information and runways",
                keywords: ["airport", "icao", "iata", "runway", "database"],
                icon: "building.2.crop.circle",
                iconColor: .cyan,
                category: .setting,
                destination: .tab("airportDatabase")
            ),

            // Monthly Summary
            SearchableItem(
                title: "Monthly Summary Email",
                subtitle: "Configure monthly backup emails",
                keywords: ["monthly", "summary", "email", "report", "export"],
                icon: "envelope.badge.fill",
                iconColor: LogbookTheme.accentBlue,
                category: .setting,
                destination: .tab("monthlySummary")
            ),

            // ═══════════════════════════════════════════════════════════════
            // SPECIFIC SETTINGS - Individual toggles and options
            // ═══════════════════════════════════════════════════════════════

            // Quiet Hours
            SearchableItem(
                title: "Quiet Hours",
                subtitle: "Suppress NOC alerts during rest periods",
                keywords: ["quiet", "silent", "sleep", "rest", "do not disturb", "dnd"],
                icon: "moon.fill",
                iconColor: .indigo,
                category: .setting,
                destination: .tab("nocAlertSettings")
            ),

            // Sync Frequency
            SearchableItem(
                title: "Sync Frequency",
                subtitle: "How often to check for schedule changes",
                keywords: ["sync", "frequency", "interval", "refresh", "auto sync"],
                icon: "arrow.triangle.2.circlepath",
                iconColor: LogbookTheme.accentBlue,
                category: .setting,
                destination: .tab("nocAlertSettings")
            ),

            // Schedule Revision Alerts
            SearchableItem(
                title: "Schedule Revision Alerts",
                subtitle: "Notifications for pending schedule changes",
                keywords: ["revision", "alert", "notification", "schedule change", "pending"],
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                category: .setting,
                destination: .tab("nocAlertSettings")
            ),

            // ═══════════════════════════════════════════════════════════════
            // TOOLS - Utilities and calculators
            // ═══════════════════════════════════════════════════════════════

            // Crosswind Calculator
            SearchableItem(
                title: "Crosswind Calculator",
                subtitle: "Calculate crosswind and headwind components",
                keywords: ["crosswind", "headwind", "tailwind", "wind", "runway", "component"],
                icon: "wind",
                iconColor: .cyan,
                category: .tool,
                destination: .tab("calculator")
            ),

            // Density Altitude
            SearchableItem(
                title: "Density Altitude Calculator",
                subtitle: "Calculate density altitude for performance",
                keywords: ["density", "altitude", "performance", "temperature", "pressure"],
                icon: "thermometer.sun.fill",
                iconColor: .orange,
                category: .tool,
                destination: .tab("calculator")
            ),

            // Fuel Calculator
            SearchableItem(
                title: "Fuel Calculator",
                subtitle: "Calculate fuel requirements and burn",
                keywords: ["fuel", "burn", "gallons", "pounds", "uplift"],
                icon: "fuelpump.fill",
                iconColor: LogbookTheme.accentGreen,
                category: .tool,
                destination: .tab("calculator")
            ),

            // Duty Timer
            SearchableItem(
                title: "Duty Timer",
                subtitle: "Track duty time with stopwatch",
                keywords: ["duty", "timer", "stopwatch", "track", "time"],
                icon: "stopwatch.fill",
                iconColor: LogbookTheme.accentOrange,
                category: .tool,
                destination: .tab("clocks")
            ),

            // GPX Export
            SearchableItem(
                title: "Export GPX Track",
                subtitle: "Export flight path as GPX file",
                keywords: ["gpx", "export", "track", "flight path", "gps"],
                icon: "square.and.arrow.up",
                iconColor: LogbookTheme.accentBlue,
                category: .tool,
                destination: .tab("flightTracks")
            ),

            // KML Export / Google Earth
            SearchableItem(
                title: "Google Earth Export",
                subtitle: "Export flight path as KML for Google Earth",
                keywords: ["kml", "google earth", "export", "3d", "flight path", "map"],
                icon: "globe.americas.fill",
                iconColor: .green,
                category: .tool,
                destination: .tab("flightTracks")
            ),

            // ═══════════════════════════════════════════════════════════════
            // HELP - Documentation and support
            // ═══════════════════════════════════════════════════════════════

            SearchableItem(
                title: "Help & Support",
                subtitle: "Get help with app features",
                keywords: ["help", "support", "faq", "how to", "guide", "tutorial"],
                icon: "questionmark.circle.fill",
                iconColor: .cyan,
                category: .help,
                destination: .tab("help")
            ),

            SearchableItem(
                title: "GPS Track Recording Help",
                subtitle: "Learn about flight path recording",
                keywords: ["gps", "track", "recording", "help", "how to", "gpx", "kml"],
                icon: "doc.text.magnifyingglass",
                iconColor: .cyan,
                category: .help,
                destination: .tab("help")
            ),

            SearchableItem(
                title: "How to Import from NOC",
                subtitle: "Set up NOC roster import",
                keywords: ["noc", "import", "setup", "how to", "roster", "calendar"],
                icon: "doc.text.magnifyingglass",
                iconColor: .cyan,
                category: .help,
                destination: .tab("nocSchedule")
            ),

            SearchableItem(
                title: "How to Export Logbook",
                subtitle: "Export to ForeFlight or LogTen Pro",
                keywords: ["export", "foreflight", "logten", "how to", "backup", "csv"],
                icon: "doc.text.magnifyingglass",
                iconColor: .cyan,
                category: .help,
                destination: .tab("electronicLogbook")
            ),
        ]
    }

    func search(_ query: String) -> [SearchableItem] {
        guard !query.isEmpty else { return [] }

        return allItems
            .filter { $0.matches(query) }
            .sorted { $0.relevanceScore(for: query) > $1.relevanceScore(for: query) }
    }

    func itemsByCategory(_ category: SearchCategory) -> [SearchableItem] {
        allItems.filter { $0.category == category }
    }
}

// MARK: - Universal Search View
struct UniversalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchIndex = AppSearchIndex.shared
    @State private var searchText = ""
    @State private var selectedItem: SearchableItem?
    @FocusState private var isSearchFocused: Bool

    let onNavigate: (String) -> Void
    let onOpenSettingsSheet: ((String) -> Void)?  // Optional callback for opening settings sheets

    init(onNavigate: @escaping (String) -> Void, onOpenSettingsSheet: ((String) -> Void)? = nil) {
        self.onNavigate = onNavigate
        self.onOpenSettingsSheet = onOpenSettingsSheet
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Results
                if searchText.isEmpty {
                    // Show categories when not searching
                    browseCategories
                } else {
                    // Show search results
                    searchResults
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search features, settings, tools...", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(LogbookTheme.navyLight)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Browse Categories
    private var browseCategories: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(SearchCategory.allCases, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func categorySection(_ category: SearchCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.gray)
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Items in category
            let items = searchIndex.itemsByCategory(category)
            ForEach(items.prefix(5)) { item in
                searchResultRow(item)
            }

            if items.count > 5 {
                Text("+ \(items.count - 5) more")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 44)
            }
        }
    }

    // MARK: - Search Results
    private var searchResults: some View {
        let results = searchIndex.search(searchText)

        return Group {
            if results.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Try different keywords")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.7))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        ForEach(results) { item in
                            searchResultRow(item)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Result Row
    private func searchResultRow(_ item: SearchableItem) -> some View {
        Button {
            handleSelection(item)
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.icon)
                        .foregroundColor(item.iconColor)
                        .font(.system(size: 16))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Category badge
                Text(item.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(LogbookTheme.navyLight)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Handle Selection
    private func handleSelection(_ item: SearchableItem) {
        switch item.destination {
        case .tab(let tabId):
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onNavigate(tabId)
            }
        case .settingsSection(let tabId, let sheetId):
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // First navigate to the tab
                onNavigate(tabId)
                // Then trigger the sheet to open
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onOpenSettingsSheet?(sheetId)
                }
            }
        case .url(let urlString):
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case .action(let actionId):
            print("Action: \(actionId)")
            // Handle custom actions here
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UniversalSearchView_Previews: PreviewProvider {
    static var previews: some View {
        UniversalSearchView { _ in }
            .preferredColorScheme(.dark)
    }
}
#endif

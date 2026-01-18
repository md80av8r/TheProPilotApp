//
//  SmartSearchView.swift
//  TheProPilotApp
//
//  Created by Claude on 1/17/26.
//  Unified search combining app features, help articles, and logbook entries
//

import SwiftUI

// MARK: - Smart Search View
struct SmartSearchView: View {
    @EnvironmentObject private var store: SwiftDataLogBookStore
    @State private var searchText = ""
    @State private var searchTab: SmartSearchTab = .all
    @StateObject private var appSearchIndex = AppSearchIndex.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                searchHeader

                // Tab picker
                Picker("Search In", selection: $searchTab) {
                    ForEach(SmartSearchTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // Results
                if searchText.isEmpty {
                    emptyStateView
                } else {
                    searchResults
                }
            }
            .navigationTitle("Smart Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search app, help, or flights...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Search Everything")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Find app features, help articles, or flights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Quick suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Try searching for:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                QuickSearchButton(title: "GPS tracking", icon: "location.fill") {
                    searchText = "GPS tracking"
                }

                QuickSearchButton(title: "Auto time logging", icon: "clock.arrow.2.circlepath") {
                    searchText = "Auto time"
                }

                QuickSearchButton(title: "Airport database", icon: "building.2.crop.circle") {
                    searchText = "Airport"
                }

                QuickSearchButton(title: "NOC import", icon: "calendar.badge.clock") {
                    searchText = "NOC"
                }
            }
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Search Results
    private var searchResults: some View {
        ScrollView {
            VStack(spacing: 0) {
                // App Features & Settings
                if searchTab == .all || searchTab == .appFeatures {
                    appFeaturesSection
                }

                // Help Articles
                if searchTab == .all || searchTab == .help {
                    helpArticlesSection
                }

                // Logbook Entries
                if searchTab == .all || searchTab == .logbook {
                    logbookSection
                }

                // No results message
                if noResultsFound {
                    noResultsView
                }
            }
        }
    }

    // MARK: - App Features Section
    private var appFeaturesSection: some View {
        Group {
            if !filteredAppItems.isEmpty {
                Section {
                    VStack(spacing: 0) {
                        ForEach(filteredAppItems.prefix(10)) { item in
                            AppFeatureRow(item: item)
                            if item.id != filteredAppItems.prefix(10).last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }

                        if filteredAppItems.count > 10 {
                            Button(action: {
                                searchTab = .appFeatures
                            }) {
                                HStack {
                                    Text("See all \(filteredAppItems.count) features")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding()
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "App Features & Settings", icon: "square.grid.2x2", count: filteredAppItems.count)
                }
            }
        }
    }

    // MARK: - Help Articles Section
    private var helpArticlesSection: some View {
        Group {
            if !filteredHelpArticles.isEmpty {
                Section {
                    VStack(spacing: 0) {
                        ForEach(filteredHelpArticles.prefix(10)) { article in
                            HelpArticleRow(article: article)
                            if article.id != filteredHelpArticles.prefix(10).last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }

                        if filteredHelpArticles.count > 10 {
                            Button(action: {
                                searchTab = .help
                            }) {
                                HStack {
                                    Text("See all \(filteredHelpArticles.count) articles")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding()
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Help & Support", icon: "questionmark.circle", count: filteredHelpArticles.count)
                }
            }
        }
    }

    // MARK: - Logbook Section
    private var logbookSection: some View {
        Group {
            if !filteredFlights.isEmpty {
                Section {
                    VStack(spacing: 0) {
                        ForEach(filteredFlights.prefix(10)) { trip in
                            LogbookSearchRow(trip: trip)
                            if trip.id != filteredFlights.prefix(10).last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }

                        if filteredFlights.count > 10 {
                            Button(action: {
                                searchTab = .logbook
                            }) {
                                HStack {
                                    Text("See all \(filteredFlights.count) flights")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding()
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Flight Logs", icon: "airplane", count: filteredFlights.count)
                }
            }
        }
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No results found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Try different keywords or check your search tab")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Computed Properties
    private var filteredAppItems: [SearchableItem] {
        guard !searchText.isEmpty else { return [] }
        return appSearchIndex.allItems
            .filter { $0.matches(searchText) }
            .sorted { $0.relevanceScore(for: searchText) > $1.relevanceScore(for: searchText) }
    }

    private var filteredHelpArticles: [SearchableHelpArticle] {
        guard !searchText.isEmpty else { return [] }
        return SearchableHelpArticle.allArticles
            .filter { $0.matches(searchText) }
            .sorted { $0.relevanceScore(for: searchText) > $1.relevanceScore(for: searchText) }
    }

    private var filteredFlights: [SDTrip] {
        guard !searchText.isEmpty else { return [] }
        return store.trips.filter { trip in
            // Search trip number
            if let tripNumber = trip.tripNumber,
               tripNumber.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            // Search legs
            for leg in trip.legs {
                if leg.departureAirport?.localizedCaseInsensitiveContains(searchText) == true ||
                   leg.arrivalAirport?.localizedCaseInsensitiveContains(searchText) == true ||
                   leg.aircraft?.localizedCaseInsensitiveContains(searchText) == true {
                    return true
                }
            }

            return false
        }
    }

    private var noResultsFound: Bool {
        searchText.isEmpty == false &&
        filteredAppItems.isEmpty &&
        filteredHelpArticles.isEmpty &&
        filteredFlights.isEmpty
    }
}

// MARK: - Search Tabs
enum SmartSearchTab: String, CaseIterable, Identifiable {
    case all = "All"
    case appFeatures = "Features"
    case help = "Help"
    case logbook = "Flights"

    var id: String { rawValue }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    let count: Int

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
}

// MARK: - App Feature Row
struct AppFeatureRow: View {
    let item: SearchableItem

    var body: some View {
        Button(action: {
            // Handle navigation
            navigateToItem(item)
        }) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundColor(item.iconColor)
                    .frame(width: 36, height: 36)
                    .background(item.iconColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func navigateToItem(_ item: SearchableItem) {
        // TODO: Implement navigation based on item.destination
        print("Navigate to: \(item.title)")
    }
}

// MARK: - Help Article Row
struct HelpArticleRow: View {
    let article: SearchableHelpArticle
    @State private var isExpanded = false

    var body: some View {
        Button(action: {
            withAnimation {
                isExpanded.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.cyan)
                        .frame(width: 36, height: 36)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(article.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    Text(article.preview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 48)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Logbook Search Row
struct LogbookSearchRow: View {
    let trip: SDTrip

    var body: some View {
        NavigationLink(destination: Text("Trip Detail")) {
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let tripNumber = trip.tripNumber {
                            Text(tripNumber)
                                .font(.body)
                                .fontWeight(.semibold)
                        }

                        Text(trip.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let firstLeg = trip.legs.first, let lastLeg = trip.legs.last {
                        Text("\(firstLeg.departureAirport ?? "???") → \(lastLeg.arrivalAirport ?? "???")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", trip.totalBlockTime))
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("block")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Quick Search Button
struct QuickSearchButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - Searchable Help Article Model
struct SearchableHelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let preview: String
    let keywords: [String]
    let content: String

    func matches(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return title.lowercased().contains(lowercasedQuery) ||
               category.lowercased().contains(lowercasedQuery) ||
               preview.lowercased().contains(lowercasedQuery) ||
               content.lowercased().contains(lowercasedQuery) ||
               keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) })
    }

    func relevanceScore(for query: String) -> Int {
        let lowercasedQuery = query.lowercased()
        var score = 0

        if title.lowercased() == lowercasedQuery { score += 100 }
        else if title.lowercased().hasPrefix(lowercasedQuery) { score += 50 }
        else if title.lowercased().contains(lowercasedQuery) { score += 25 }

        if keywords.contains(where: { $0.lowercased() == lowercasedQuery }) { score += 40 }
        else if keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) { score += 15 }

        if preview.lowercased().contains(lowercasedQuery) { score += 10 }

        return score
    }

    // Static help articles database
    static let allArticles: [SearchableHelpArticle] = [
        SearchableHelpArticle(
            title: "GPS Track Recording",
            category: "Features",
            preview: "Automatically record flight paths with auto-start/stop on takeoff and landing",
            keywords: ["gps", "tracking", "flight path", "recording", "location"],
            content: """
            Record your flight paths automatically with GPS Track Recording.

            • Auto-starts on takeoff (>80 knots)
            • Auto-stops on landing (<60 knots)
            • Detects departure/arrival airports
            • Shows OFF/ON times from GPS data

            Export tracks in GPX or KML format for Google Earth.
            """
        ),
        SearchableHelpArticle(
            title: "Auto Time Logging",
            category: "Features",
            preview: "GPS-based automatic time capture with takeoff/landing detection",
            keywords: ["auto", "time", "logging", "automatic", "gps", "speed"],
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
        SearchableHelpArticle(
            title: "NOC Schedule Import",
            category: "Getting Started",
            preview: "Import your airline roster automatically from NOC emails",
            keywords: ["noc", "schedule", "import", "roster", "email", "trips"],
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
        // Add more help articles here...
    ]
}

// MARK: - Preview
struct SmartSearchView_Previews: PreviewProvider {
    static var previews: some View {
        SmartSearchView()
            .environmentObject(SwiftDataLogBookStore.preview)
    }
}

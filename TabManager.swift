// TabManager.swift - CLEANED UP WITH TRIP GENERATION
// Slide-out More panel with proper tab-to-view mappings
import SwiftUI
import Foundation

// MARK: - Tab Item Definition
struct TabItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let badge: String?
    var isVisible: Bool
    var order: Int
    
    init(id: String, title: String, systemImage: String, badge: String? = nil, isVisible: Bool = true, order: Int = 0) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.badge = badge
        self.isVisible = isVisible
        self.order = order
    }
}

// MARK: - Tab Configuration Manager
class CustomizableTabManager: ObservableObject {
    static let shared = CustomizableTabManager()

    @Published var availableTabs: [TabItem] = []
    @Published var visibleTabs: [TabItem] = []      // iPhone visible tabs (max 4 + More)
    @Published var iPadVisibleTabs: [TabItem] = []  // iPad visible tabs (max 7 + More)
    @Published var moreTabs: [TabItem] = []         // iPhone "more" tabs
    @Published var iPadMoreTabs: [TabItem] = []     // iPad "more" tabs
    @Published var recentTab: TabItem?

    // iPhone: 4 main tabs + Recent + More = 6 items in bar
    private let maxVisibleTabs = 5
    // iPad: 7 main tabs + More = 8 items in bar (no Recent needed with more space)
    private let maxVisibleTabsiPad = 8
    private let userDefaults = UserDefaults.standard
    private let tabConfigKey = "TabConfiguration"
    private let iPadTabConfigKey = "iPadTabConfiguration"
    private let recentTabKey = "RecentTabID"
    
    init() {
        // TEMPORARY - forces reload of tabs
        UserDefaults.standard.removeObject(forKey: "TabConfiguration")

        setupDefaultTabs()
        loadConfiguration()
        loadRecentTab()
        updateTabArrays()
    }
    
    // MARK: - Tab Definitions
    // Each tab ID must match a case in ContentView.contentForTab()
    private func setupDefaultTabs() {
        availableTabs = [
            // ═══════════════════════════════════════════════════════════════
            // MAIN VISIBLE TABS (shown in bottom tab bar)
            // ═══════════════════════════════════════════════════════════════
            TabItem(id: "logbook", title: "Logbook", systemImage: "book.closed", order: 0),
            TabItem(id: "schedule", title: "Schedule", systemImage: "calendar", order: 1),
            TabItem(id: "perDiem", title: "Time Away", systemImage: "clock.arrow.circlepath", order: 2),
            
            // ═══════════════════════════════════════════════════════════════
            // MORE PANEL TABS - Organized by Section
            // ═══════════════════════════════════════════════════════════════
            
            // ─────────────────────────────────────────────────────────────────
            // APPLE WATCH SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "appleWatch" → Opens: AppleWatchStatusView
            TabItem(id: "appleWatch", title: "Apple Watch", systemImage: "applewatch", isVisible: false, order: 4),
            
            // ─────────────────────────────────────────────────────────────────
            // AIRLINE & AIRCRAFT SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "airlineConfig" → Opens: AirlineConfigurationView
            TabItem(id: "airlineConfig", title: "Airline Configuration", systemImage: "building.2.fill", isVisible: false, order: 5),
            // ID: "aircraftDatabase" → Opens: UnifiedAircraftView (merged Aircraft Management + Library with CloudKit)
            TabItem(id: "aircraftDatabase", title: "Aircraft Database", systemImage: "airplane.circle.fill", isVisible: false, order: 6),
            
            // ─────────────────────────────────────────────────────────────────
            // FLIGHT LOGGING SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "autoTimeLogging" → Opens: AutoTimeLoggingSettingsView
            TabItem(id: "autoTimeLogging", title: "Auto Time Logging", systemImage: "clock.arrow.2.circlepath", isVisible: false, order: 7),
            // ID: "scannerEmailSettings" → Opens: ScannerEmailConfigView
            TabItem(id: "scannerEmailSettings", title: "Scanner & Email", systemImage: "envelope.fill", isVisible: false, order: 8),
            // ID: "scanner" → Opens: TripScannerView (standalone scanner)
            TabItem(id: "scanner", title: "Document Scanner", systemImage: "doc.viewfinder", isVisible: false, order: 9),
            // ID: "flightTracks" → Opens: FlightTrackListView (GPS track recording & viewer)
            TabItem(id: "flightTracks", title: "Flight Tracks", systemImage: "recordingtape", isVisible: false, order: 10),
            
            // ─────────────────────────────────────────────────────────────────
            // SCHEDULE & OPERATIONS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "nocSchedule" → Opens: NOCSettingsView
            TabItem(id: "nocSchedule", title: "NOC Schedule Import", systemImage: "calendar.badge.clock", isVisible: false, order: 10),
            // ID: "nocAlertSettings" → Opens: NOCAlertSettingsView
            TabItem(id: "nocAlertSettings", title: "NOC Alert Settings", systemImage: "bell.badge.fill", isVisible: false, order: 11),
            // ID: "tripGeneration" → Opens: TripGenerationSettingsView
            TabItem(id: "tripGeneration", title: "Trip Generation", systemImage: "wand.and.stars", isVisible: false, order: 12),
            // ID: "crewContacts" → Opens: CrewImportHelperView
            TabItem(id: "crewContacts", title: "Crew Contacts", systemImage: "person.3.fill", isVisible: false, order: 13),
            
            // ─────────────────────────────────────────────────────────────────
            // CLOCKS & TIMERS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "clocks" → Opens: ClocksTabView
            TabItem(id: "clocks", title: "World Clock", systemImage: "clock.fill", isVisible: false, order: 13),
            
            // ─────────────────────────────────────────────────────────────────
            // FLIGHT TOOLS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "airportDatabase" → Opens: AirportManagementView ⭐ NEW
            TabItem(id: "airportDatabase", title: "Airport Database", systemImage: "building.2.crop.circle", isVisible: false, order: 14),
            // ID: "gpsRaim" → Opens: GPSRAIMView
            TabItem(id: "gpsRaim", title: "GPS/RAIM", systemImage: "location.fill", isVisible: false, order: 15),
            // ID: "weather" → Opens: WeatherView
            TabItem(id: "weather", title: "Weather", systemImage: "cloud.sun.fill", isVisible: false, order: 16),
            // ID: "areaGuide" → Opens: AreaGuideViewComplete <--- ADDED HERE
            TabItem(id: "areaGuide", title: "Area Guide", systemImage: "map.fill", isVisible: false, order: 17),
            // ID: "calculator" → Opens: FlightCalculatorView
            TabItem(id: "calculator", title: "Flight Calculator", systemImage: "function", isVisible: false, order: 18),
            // ID: "flightOps" → Opens: FlightOpsView
            TabItem(id: "flightOps", title: "Flight Ops", systemImage: "airplane.circle.fill", isVisible: false, order: 19),
            
            // ─────────────────────────────────────────────────────────────────
            // TRACKING & REPORTS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "flightTimeLimits" → Opens: DutyLimitSettingsView ⭐ NEW
            TabItem(id: "flightTimeLimits", title: "Flight Time Limits", systemImage: "clock.badge.exclamationmark", isVisible: false, order: 19),
            // ID: "rolling30Day" → Opens: Rolling30DayComplianceView
            TabItem(id: "rolling30Day", title: "30-Day Rolling", systemImage: "gauge.with.needle.fill", isVisible: false, order: 20),
            // ID: "far117Compliance" → Opens: FAR121ComplianceView
            TabItem(id: "far117Compliance", title: "FAR 121 Compliance", systemImage: "chart.line.uptrend.xyaxis", isVisible: false, order: 20),
            // ID: "fleetTracker" → Opens: FleetTrackerView
            TabItem(id: "fleetTracker", title: "Fleet Tracker", systemImage: "chart.bar.fill", isVisible: false, order: 21),
            // ID: "reports" → Opens: AllLegsView
            TabItem(id: "reports", title: "Flight Legs", systemImage: "list.bullet.rectangle", isVisible: false, order: 22),
            // ID: "electronicLogbook" → Opens: SimpleElectronicLogbookView
            TabItem(id: "electronicLogbook", title: "Electronic Logbook", systemImage: "book.closed.fill", isVisible: false, order: 23),
            
            // ─────────────────────────────────────────────────────────────────
            // DOCUMENTS & DATA SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "documents" → Opens: DocumentsView (if exists)
            TabItem(id: "documents", title: "Documents", systemImage: "folder.fill", isVisible: false, order: 23),
            // ID: "notes" → Opens: NotesView (if exists)
            TabItem(id: "notes", title: "Notes", systemImage: "note.text", isVisible: false, order: 24),
            // ID: "dataBackup" → Opens: DataBackupSettingsView
            TabItem(id: "dataBackup", title: "Backup & Restore", systemImage: "externaldrive.fill.badge.timemachine", isVisible: false, order: 25),
            // ID: "monthlySummary" → Opens: MonthlyEmailSettingsView
            TabItem(id: "monthlySummary", title: "Monthly Summary", systemImage: "envelope.badge.fill", isVisible: false, order: 26),
            
            // ─────────────────────────────────────────────────────────────────
            // HELP & SUPPORT SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "universalSearch" → Opens: UniversalSearchView (App-wide search)
            TabItem(id: "universalSearch", title: "Search App", systemImage: "magnifyingglass", isVisible: false, order: 26),
            // ID: "help" → Opens: HelpView
            TabItem(id: "help", title: "Help & Support", systemImage: "questionmark.circle.fill", isVisible: false, order: 27),
            // ID: "search" → Opens: LogbookSearchView
            TabItem(id: "search", title: "Search Logbook", systemImage: "magnifyingglass.circle.fill", isVisible: false, order: 28),

            // ─────────────────────────────────────────────────────────────────
            // JUMPSEAT NETWORK SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "jumpseat" → Opens: JumpseatFinderView ⭐ NEW
            TabItem(id: "jumpseat", title: "Jumpseat Finder", systemImage: "person.2.fill", isVisible: false, order: 28),
            
            // ─────────────────────────────────────────────────────────────────
            // BETA TESTING SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "nocTest" → Opens: NOCTestView ⭐ NEW
            TabItem(id: "nocTest", title: "NOC Trip Tester", systemImage: "calendar.badge.plus", isVisible: false, order: 29),
            // ID: "gpxTesting" → Opens: GPXTestingView
            TabItem(id: "gpxTesting", title: "GPX Testing", systemImage: "location.circle", isVisible: false, order: 30),
            // ID: "airportTest" → Opens: AirportDatabaseTestView
            TabItem(id: "airportTest", title: "Airport Database Test", systemImage: "building.2.crop.circle.fill", isVisible: false, order: 31),
        ]

        // ✅ Subscription Debug (only in DEBUG builds) - added after array initialization
        #if DEBUG
        availableTabs.append(TabItem(id: "subscriptionDebug", title: "Subscription Debug", systemImage: "dollarsign.circle.fill", isVisible: false, order: 32))
        #endif
    }
    
    // MARK: - Recent Tab Management
    private func loadRecentTab() {
        if let recentID = userDefaults.string(forKey: recentTabKey),
           let tab = availableTabs.first(where: { $0.id == recentID && !$0.isVisible }) {
            recentTab = tab
        } else {
            recentTab = availableTabs.first(where: { $0.id == "scanner" })
        }
    }
    
    func setRecentTab(_ tabID: String) {
        if let tab = availableTabs.first(where: { $0.id == tabID && !$0.isVisible }) {
            recentTab = tab
            userDefaults.set(tabID, forKey: recentTabKey)
            objectWillChange.send()
            print("📌 Set recent tab to: \(tab.title)")
        }
    }
    
    // MARK: - Tab Array Updates
    func updateTabArrays() {
        let sorted = availableTabs.sorted { $0.order < $1.order }

        // iPhone: Up to 4 visible tabs (5 - 1 for More button)
        visibleTabs = Array(sorted.filter { $0.isVisible }.prefix(maxVisibleTabs - 1))
        moreTabs = sorted.filter { !$0.isVisible }

        // iPad: Up to 7 visible tabs (8 - 1 for More button)
        // iPad shows all visible tabs plus some from "more" to fill the space
        let allVisible = sorted.filter { $0.isVisible }
        let remaining = sorted.filter { !$0.isVisible }

        if allVisible.count >= maxVisibleTabsiPad - 1 {
            // User has configured enough visible tabs
            iPadVisibleTabs = Array(allVisible.prefix(maxVisibleTabsiPad - 1))
            iPadMoreTabs = Array(allVisible.dropFirst(maxVisibleTabsiPad - 1)) + remaining
        } else {
            // Fill iPad bar with some "more" tabs
            let neededFromMore = (maxVisibleTabsiPad - 1) - allVisible.count
            iPadVisibleTabs = allVisible + Array(remaining.prefix(neededFromMore))
            iPadMoreTabs = Array(remaining.dropFirst(neededFromMore))
        }
    }
    
    func moveTab(_ tab: TabItem, toVisible: Bool) {
        if let index = availableTabs.firstIndex(where: { $0.id == tab.id }) {
            availableTabs[index].isVisible = toVisible
            
            if toVisible && visibleTabs.count >= maxVisibleTabs - 1 {
                if let lastVisible = visibleTabs.last,
                   lastVisible.id != "logbook",
                   lastVisible.id != "more" {
                    moveTab(lastVisible, toVisible: false)
                }
            }
            
            saveConfiguration()
            updateTabArrays()
        }
    }
    
    func reorderTabs(_ tabs: [TabItem]) {
        for (index, tab) in tabs.enumerated() {
            if let originalIndex = availableTabs.firstIndex(where: { $0.id == tab.id }) {
                availableTabs[originalIndex].order = index
            }
        }
        updateTabArrays()
        saveConfiguration()
    }
    
    func resetToDefaults() {
        setupDefaultTabs()
        updateTabArrays()
        saveConfiguration()
    }
    
    // MARK: - Persistence
    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(availableTabs) {
            userDefaults.set(encoded, forKey: tabConfigKey)
        }
    }
    
    private func loadConfiguration() {
        guard let data = userDefaults.data(forKey: tabConfigKey),
              let decoded = try? JSONDecoder().decode([TabItem].self, from: data) else {
            return
        }
        
        for savedTab in decoded {
            if let index = availableTabs.firstIndex(where: { $0.id == savedTab.id }) {
                availableTabs[index] = savedTab
            }
        }
    }
}

// MARK: - Customizable Tab View (iPhone)
struct CustomizableTabView<Content: View>: View {
    @StateObject private var tabManager = CustomizableTabManager.shared
    @State private var selectedTab = "logbook"
    @State private var showingTabEditor = false
    @State private var showingMorePanel = false
    @State private var selectedMoreTabForSheet: MoreTabSelection? = nil

    let content: (String) -> Content

    init(@ViewBuilder content: @escaping (String) -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            // Main content with NavigationView for each tab
            TabView(selection: $selectedTab) {
                ForEach(tabManager.visibleTabs) { tab in
                    NavigationView {
                        content(tab.id)
                    }
                    .navigationViewStyle(.stack)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab.id)
                }

                // Dynamic Recent Tab
                if let recentTab = tabManager.recentTab {
                    NavigationView {
                        content(recentTab.id)
                    }
                    .navigationViewStyle(.stack)
                    .tabItem {
                        Label(recentTab.title, systemImage: recentTab.systemImage)
                    }
                    .tag(recentTab.id)
                }

                // More tab - triggers overlay
                Color.clear
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag("more")
            }
            .accentColor(LogbookTheme.accentBlue)
            .onChange(of: selectedTab) { _, newTab in
                if newTab == "more" {
                    showingMorePanel = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedTab = tabManager.visibleTabs.first?.id ?? "logbook"
                    }
                }
            }

            // More panel overlay (slides from right)
            if showingMorePanel {
                MorePanelOverlay(
                    moreTabs: tabManager.moreTabs,
                    isShowing: $showingMorePanel,
                    onTabSelected: { tabId in
                        selectedTab = tabId
                        showingMorePanel = false
                    },
                    onEditTabs: {
                        showingTabEditor = true
                    },
                    onSelectMoreTab: { tabId in
                        tabManager.setRecentTab(tabId)
                        selectedMoreTabForSheet = MoreTabSelection(id: tabId)
                        showingMorePanel = false
                    },
                    content: content
                )
                .animation(.easeInOut(duration: 0.3), value: showingMorePanel)
            }
        }
        .sheet(isPresented: $showingTabEditor) {
            TabEditorView(tabManager: tabManager)
        }
        .sheet(item: $selectedMoreTabForSheet) { selection in
            NavigationView {
                content(selection.id)
            }
            .navigationViewStyle(.stack)
        }
    }
}

// MARK: - More Tab Selection
struct MoreTabSelection: Identifiable {
    let id: String
}

// MARK: - More Panel Overlay (Slide-Out with Timer)
struct MorePanelOverlay<Content: View>: View {
    let moreTabs: [TabItem]
    @Binding var isShowing: Bool
    let onTabSelected: (String) -> Void
    let onEditTabs: () -> Void
    let onSelectMoreTab: (String) -> Void
    let content: (String) -> Content
    
    @StateObject private var timer = FlexibleTimerManager.shared
    @State private var showingTimerSettings = false
    
    // Section definitions for cleaner code
    private let appleWatchTabs = ["appleWatch"]
    private let airlineAircraftTabs = ["airlineConfig", "aircraftDatabase"]
    private let flightLoggingTabs = ["autoTimeLogging", "scannerEmailSettings", "scanner", "flightTracks"]
    private let scheduleOpsTabs = ["nocSchedule", "nocAlertSettings", "tripGeneration", "crewContacts"]
    private let clocksTabs = ["clocks"]
    private let flightToolsTabs = ["airportDatabase", "gpsRaim", "weather", "areaGuide", "calculator", "flightOps"]
    private let trackingReportsTabs = ["flightTimeLimits", "rolling30Day", "far117Compliance", "fleetTracker", "reports", "electronicLogbook"]
    private let documentsDataTabs = ["documents", "notes", "dataBackup", "monthlySummary"]
    #if DEBUG
    private let helpSupportTabs = ["universalSearch", "help", "search", "subscriptionDebug"]
    #else
    private let helpSupportTabs = ["universalSearch", "help", "search"]
    #endif
    private let jumpseatTabs = ["jumpseat"]
    private let betaTestingTabs = ["nocTest", "gpxTesting"]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - transparent tap area to dismiss
                Color.clear
                    .frame(width: geometry.size.width * 0.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isShowing = false
                    }
                
                // Right side - More panel
                VStack(spacing: 0) {
                    // Header
                    panelHeader
                    
                    // Scrollable content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Edit Tab Order button
                            MorePanelButton(
                                icon: "slider.horizontal.3",
                                iconColor: .blue,
                                title: "Edit Tab Order",
                                action: {
                                    onEditTabs()
                                    isShowing = false
                                }
                            )
                            
                            Divider()
                                .background(LogbookTheme.divider)
                                .padding(.leading, 52)
                            
                            // All sections
                            VStack(spacing: 0) {
                                appleWatchSection
                                airlineAircraftSection
                                flightLoggingSection
                                scheduleOpsSection
                                clocksSection
                                flightToolsSection
                                trackingReportsSection
                                documentsDataSection
                                helpSupportSection  // ⭐ NEW
                                jumpseatSection
                                betaTestingSection
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    Spacer()
                    
                    // Timer at bottom
                    timerSection
                }
                .frame(width: geometry.size.width * 0.5)
                .background(LogbookTheme.navyDark)
            }
        }
        .edgesIgnoringSafeArea(.vertical)
    }
    
    // MARK: - Panel Header
    private var panelHeader: some View {
        HStack {
            Text("More")
                .font(.title3)
                .fontWeight(.regular)
                .foregroundColor(.white)
            Spacer()
            
            Button(action: {
                isShowing = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Sections
    @ViewBuilder
    private var appleWatchSection: some View {
        if moreTabs.contains(where: { appleWatchTabs.contains($0.id) }) {
            sectionHeader(title: "APPLE WATCH")
            ForEach(moreTabs.filter { appleWatchTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var airlineAircraftSection: some View {
        if moreTabs.contains(where: { airlineAircraftTabs.contains($0.id) }) {
            sectionHeader(title: "AIRLINE & AIRCRAFT")
            ForEach(moreTabs.filter { airlineAircraftTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var flightLoggingSection: some View {
        if moreTabs.contains(where: { flightLoggingTabs.contains($0.id) }) {
            sectionHeader(title: "FLIGHT LOGGING")
            ForEach(moreTabs.filter { flightLoggingTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var scheduleOpsSection: some View {
        if moreTabs.contains(where: { scheduleOpsTabs.contains($0.id) }) {
            sectionHeader(title: "SCHEDULE & OPERATIONS")
            
            // Pending Trips Quick View (embedded widget)
            PendingTripsCompactWidget(onSelectTab: { tabID in
                onSelectMoreTab(tabID)
                isShowing = false
            })
            
            ForEach(moreTabs.filter { scheduleOpsTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var clocksSection: some View {
        if moreTabs.contains(where: { clocksTabs.contains($0.id) }) {
            sectionHeader(title: "CLOCKS & TIMERS")
            ForEach(moreTabs.filter { clocksTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var flightToolsSection: some View {
        if moreTabs.contains(where: { flightToolsTabs.contains($0.id) }) {
            sectionHeader(title: "FLIGHT TOOLS")
            ForEach(moreTabs.filter { flightToolsTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var trackingReportsSection: some View {
        if moreTabs.contains(where: { trackingReportsTabs.contains($0.id) }) {
            sectionHeader(title: "TRACKING & REPORTS")
            ForEach(moreTabs.filter { trackingReportsTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var documentsDataSection: some View {
        if moreTabs.contains(where: { documentsDataTabs.contains($0.id) }) {
            sectionHeader(title: "DOCUMENTS & DATA")
            ForEach(moreTabs.filter { documentsDataTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var helpSupportSection: some View {
        if moreTabs.contains(where: { helpSupportTabs.contains($0.id) }) {
            sectionHeader(title: "HELP & SUPPORT")
            ForEach(moreTabs.filter { helpSupportTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var jumpseatSection: some View {
        if moreTabs.contains(where: { jumpseatTabs.contains($0.id) }) {
            sectionHeader(title: "JUMPSEAT NETWORK")
            ForEach(moreTabs.filter { jumpseatTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
            sectionDivider()
        }
    }
    
    @ViewBuilder
    private var betaTestingSection: some View {
        if moreTabs.contains(where: { betaTestingTabs.contains($0.id) }) {
            sectionHeader(title: "BETA TESTING")
            ForEach(moreTabs.filter { betaTestingTabs.contains($0.id) }) { tab in
                tabButton(for: tab)
            }
        }
    }
    
    // MARK: - Helper Views
    private func tabButton(for tab: TabItem) -> some View {
        MorePanelButton(
            icon: tab.systemImage,
            iconColor: getIconColor(for: tab.id),
            title: tab.title,
            badge: tab.badge,
            action: { onSelectMoreTab(tab.id) }
        )
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            Spacer()
        }
    }
    
    private func sectionDivider() -> some View {
        Divider()
            .background(Color.white.opacity(0.05))
            .padding(.vertical, 8)
    }
    
    // MARK: - Icon Colors (matched to each tab)
    private func getIconColor(for tabId: String) -> Color {
        switch tabId {
        // Apple Watch
        case "appleWatch": return .pink
        
        // Airline & Aircraft
        case "airlineConfig": return LogbookTheme.accentGreen
        case "aircraftDatabase": return LogbookTheme.accentBlue
        
        // Flight Logging
        case "autoTimeLogging": return LogbookTheme.accentOrange
        case "scannerEmailSettings": return LogbookTheme.accentOrange
        case "scanner": return LogbookTheme.accentOrange
        
        // Schedule & Operations
        case "nocSchedule": return LogbookTheme.accentGreen
        case "nocAlertSettings": return .orange
        case "tripGeneration": return .purple
        case "crewContacts": return LogbookTheme.accentBlue
        
        // Clocks & Timers
        case "clocks": return LogbookTheme.accentBlue
        
        // Flight Tools
        case "airportDatabase": return .cyan
        case "gpsRaim": return .purple
        case "weather": return .cyan
        case "areaGuide": return LogbookTheme.accentGreen // <--- ADDED HERE
        case "calculator": return LogbookTheme.accentOrange
        case "flightOps": return .purple
        
        // Tracking & Reports
        case "fleetTracker": return .indigo
        case "reports": return LogbookTheme.accentGreen
        case "electronicLogbook": return LogbookTheme.accentBlue
        
        // Documents & Data
        case "documents": return LogbookTheme.accentBlue
        case "notes": return .yellow
        case "dataBackup": return LogbookTheme.accentOrange
        case "monthlySummary": return LogbookTheme.accentBlue
        
        // Help & Support
        case "universalSearch": return .blue
        case "help": return .cyan
        case "search": return .purple
        #if DEBUG
        case "subscriptionDebug": return .orange
        #endif
        
        // Jumpseat Network
        case "jumpseat": return .cyan
        
        // Beta Testing
        case "nocTest": return .purple
        case "gpxTesting": return .orange
        case "flightTracks": return .cyan

        default: return .blue
        }
    }

    // MARK: - Timer Section
    private var timerSection: some View {
        VStack(spacing: 8) {
            // Time display with mode arrow
            HStack(spacing: 12) {
                Text(formatCompactTime())
                    .font(.system(size: 40, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(timerDisplayColor())
                
                // Tappable arrow to toggle mode
                Button(action: {
                    withAnimation {
                        if timer.mode == .stopwatch {
                            timer.switchMode(to: .countdown)
                        } else {
                            timer.switchMode(to: .stopwatch)
                        }
                    }
                }) {
                    Image(systemName: timer.mode == .stopwatch ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(timer.mode == .stopwatch ? .green : .orange)
                }
            }
            .padding(.top, 8)
            
            // Mode label
            Text(timer.mode == .stopwatch ? "Stopwatch" : "Countdown")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Control buttons
            HStack(spacing: 20) {
                // Start/Pause button
                Button(action: {
                    if timer.state == .running {
                        timer.pauseTimer()
                    } else {
                        timer.startTimer()
                    }
                }) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(timer.state == .running ? Color.orange : Color.green)
                        .clipShape(Circle())
                }
                
                // Reset button
                Button(action: {
                    timer.stopTimer()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.5))
                        .clipShape(Circle())
                }
                
                // Settings button
                Button(action: {
                    showingTimerSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .background(LogbookTheme.navyLight)
        .sheet(isPresented: $showingTimerSettings) {
            TimerSettingsView(timer: timer)
        }
    }
    
    // Timer helper functions
    private func formatCompactTime() -> String {
        let totalSeconds = Int(timer.displayTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func timerDisplayColor() -> Color {
        if timer.mode == .countdown && timer.displayTime <= 60 {
            return .red
        } else if timer.state == .running {
            return timer.mode == .stopwatch ? .green : .orange
        } else {
            return .white
        }
    }
}

// MARK: - More Panel Button
struct MorePanelButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let badge: String?
    let action: () -> Void
    
    init(icon: String, iconColor: Color, title: String, badge: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tab Editor View
struct TabEditorView: View {
    @ObservedObject var tabManager: CustomizableTabManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customize your tab bar by selecting which features appear as main tabs. You can have up to 4 main tabs plus the More tab.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    Text("Tap + to add to main tabs, - to remove. Drag to reorder main tabs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                List {
                    Section("Main Tabs (\(tabManager.visibleTabs.count)/4)") {
                        ForEach(tabManager.visibleTabs) { tab in
                            TabEditorRow(
                                tab: tab,
                                isVisible: true,
                                onToggle: {
                                    tabManager.moveTab(tab, toVisible: false)
                                }
                            )
                        }
                        .onMove { source, destination in
                            var visibleTabs = tabManager.visibleTabs
                            visibleTabs.move(fromOffsets: source, toOffset: destination)
                            tabManager.reorderTabs(visibleTabs + tabManager.moreTabs)
                        }
                    }
                    
                    Section("Available for More Tab") {
                        ForEach(tabManager.moreTabs) { tab in
                            TabEditorRow(
                                tab: tab,
                                isVisible: false,
                                onToggle: {
                                    if tabManager.visibleTabs.count < 4 {
                                        tabManager.moveTab(tab, toVisible: true)
                                    }
                                }
                            )
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Edit Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        tabManager.resetToDefaults()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tab Editor Row
struct TabEditorRow: View {
    let tab: TabItem
    let isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: tab.systemImage)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(tab.title)

            Spacer()

            if isVisible {
                Button(action: onToggle) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: onToggle) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════
// MARK: iPad Tab View System (Bottom tabs + Slide-out More Panel)
// MARK: ═══════════════════════════════════════════════════════════════════════════

/// iPad Tab View Wrapper - Custom bottom tab bar implementation for iPad
/// SwiftUI's TabView doesn't reliably show bottom tabs on iPad, so we build our own
struct iPadTabViewWrapper<Content: View>: View {
    @StateObject private var tabManager = CustomizableTabManager.shared
    @State private var selectedTab = "logbook"
    @State private var showingTabEditor = false
    @State private var showingMorePanel = false

    let content: (String) -> Content

    init(@ViewBuilder content: @escaping (String) -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            // Main content area with custom bottom tab bar
            VStack(spacing: 0) {
                // Content area
                NavigationStack {
                    content(selectedTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom bottom tab bar for iPad
                iPadBottomTabBar
            }

            // iPad More panel overlay (slides from right - optimized for iPad)
            if showingMorePanel {
                iPadMorePanelOverlay(
                    moreTabs: tabManager.iPadMoreTabs,
                    isShowing: $showingMorePanel,
                    onTabSelected: { tabId in
                        selectedTab = tabId
                        showingMorePanel = false
                    },
                    onEditTabs: {
                        showingTabEditor = true
                    },
                    onSelectMoreTab: { tabId in
                        // On iPad, directly switch to the tab (no recent tab needed)
                        selectedTab = tabId
                        showingMorePanel = false
                    },
                    content: content
                )
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.3), value: showingMorePanel)
            }
        }
        .sheet(isPresented: $showingTabEditor) {
            iPadTabEditorView(tabManager: tabManager)
        }
    }

    // MARK: - Custom iPad Bottom Tab Bar (supports up to 7 tabs + More)
    private var iPadBottomTabBar: some View {
        HStack(spacing: 0) {
            // iPad visible tabs (up to 7)
            ForEach(tabManager.iPadVisibleTabs) { tab in
                iPadTabButton(
                    title: tab.title,
                    systemImage: tab.systemImage,
                    isSelected: selectedTab == tab.id
                ) {
                    selectedTab = tab.id
                }
            }

            // More button (only show if there are more tabs)
            if !tabManager.iPadMoreTabs.isEmpty {
                iPadTabButton(
                    title: "More",
                    systemImage: "ellipsis.circle.fill",
                    isSelected: false
                ) {
                    showingMorePanel = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(LogbookTheme.navyDark)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: -4)
        )
    }

    // MARK: - iPad Tab Button
    private func iPadTabButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? LogbookTheme.accentBlue : .gray)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? LogbookTheme.accentBlue : .gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - iPad More Panel Overlay (Optimized for larger screens)
struct iPadMorePanelOverlay<Content: View>: View {
    let moreTabs: [TabItem]
    @Binding var isShowing: Bool
    let onTabSelected: (String) -> Void
    let onEditTabs: () -> Void
    let onSelectMoreTab: (String) -> Void
    let content: (String) -> Content

    @StateObject private var timer = FlexibleTimerManager.shared
    @State private var showingTimerSettings = false

    // Section definitions
    private let appleWatchTabs = ["appleWatch"]
    private let airlineAircraftTabs = ["airlineConfig", "aircraftDatabase"]
    private let flightLoggingTabs = ["autoTimeLogging", "scannerEmailSettings", "scanner", "flightTracks"]
    private let scheduleOpsTabs = ["nocSchedule", "nocAlertSettings", "tripGeneration", "crewContacts"]
    private let clocksTabs = ["clocks"]
    private let flightToolsTabs = ["airportDatabase", "gpsRaim", "weather", "areaGuide", "calculator", "flightOps"]
    private let trackingReportsTabs = ["flightTimeLimits", "rolling30Day", "far117Compliance", "fleetTracker", "reports", "electronicLogbook"]
    private let documentsDataTabs = ["documents", "notes", "dataBackup", "monthlySummary"]
    #if DEBUG
    private let helpSupportTabs = ["universalSearch", "help", "search", "subscriptionDebug"]
    #else
    private let helpSupportTabs = ["universalSearch", "help", "search"]
    #endif
    private let jumpseatTabs = ["jumpseat"]
    private let betaTestingTabs = ["nocTest", "gpxTesting"]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - transparent tap area to dismiss (larger on iPad)
                Color.black.opacity(0.4)
                    .frame(width: geometry.size.width * 0.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isShowing = false
                        }
                    }

                // Right side - iPad-optimized More panel (single column, wider cards)
                VStack(spacing: 0) {
                    // Header
                    iPadPanelHeader

                    // Single-column scrolling list (better for text readability)
                    ScrollView {
                        VStack(spacing: 0) {
                            // Edit Tab Order button
                            iPadMorePanelCard(
                                icon: "slider.horizontal.3",
                                iconColor: .blue,
                                title: "Edit Tab Order",
                                action: {
                                    onEditTabs()
                                    isShowing = false
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)

                            // All sections
                            ForEach(allSections, id: \.title) { section in
                                if !section.tabs.isEmpty {
                                    iPadSectionView(section: section)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    Spacer()

                    // Timer at bottom
                    iPadTimerSection
                }
                .frame(width: geometry.size.width * 0.5)
                .background(LogbookTheme.navyDark)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - All Sections Helper
    private var allSections: [(title: String, tabs: [TabItem])] {
        [
            ("Apple Watch", moreTabs.filter { appleWatchTabs.contains($0.id) }),
            ("Airline & Aircraft", moreTabs.filter { airlineAircraftTabs.contains($0.id) }),
            ("Flight Logging", moreTabs.filter { flightLoggingTabs.contains($0.id) }),
            ("Schedule & Operations", moreTabs.filter { scheduleOpsTabs.contains($0.id) }),
            ("Clocks & Timers", moreTabs.filter { clocksTabs.contains($0.id) }),
            ("Flight Tools", moreTabs.filter { flightToolsTabs.contains($0.id) }),
            ("Tracking & Reports", moreTabs.filter { trackingReportsTabs.contains($0.id) }),
            ("Documents & Data", moreTabs.filter { documentsDataTabs.contains($0.id) }),
            ("Help & Support", moreTabs.filter { helpSupportTabs.contains($0.id) }),
            ("Jumpseat Network", moreTabs.filter { jumpseatTabs.contains($0.id) }),
            ("Beta Testing", moreTabs.filter { betaTestingTabs.contains($0.id) })
        ]
    }

    // MARK: - Section View
    @ViewBuilder
    private func iPadSectionView(section: (title: String, tabs: [TabItem])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.leading, 20)
                .padding(.top, 16)

            ForEach(section.tabs) { tab in
                iPadMorePanelCard(
                    icon: tab.systemImage,
                    iconColor: getIconColor(for: tab.id),
                    title: tab.title,
                    badge: tab.badge,
                    action: { onSelectMoreTab(tab.id) }
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Panel Header
    private var iPadPanelHeader: some View {
        HStack {
            Text("More")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isShowing = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Icon Colors
    private func getIconColor(for tabId: String) -> Color {
        switch tabId {
        case "appleWatch": return .pink
        case "airlineConfig": return LogbookTheme.accentGreen
        case "aircraftDatabase": return LogbookTheme.accentBlue
        case "autoTimeLogging", "scannerEmailSettings", "scanner": return LogbookTheme.accentOrange
        case "nocSchedule": return LogbookTheme.accentGreen
        case "nocAlertSettings": return .orange
        case "tripGeneration": return .purple
        case "crewContacts": return LogbookTheme.accentBlue
        case "clocks": return LogbookTheme.accentBlue
        case "airportDatabase": return .cyan
        case "gpsRaim": return .purple
        case "weather": return .cyan
        case "areaGuide": return LogbookTheme.accentGreen
        case "calculator": return LogbookTheme.accentOrange
        case "flightOps": return .purple
        case "fleetTracker": return .indigo
        case "reports": return LogbookTheme.accentGreen
        case "electronicLogbook": return LogbookTheme.accentBlue
        case "documents": return LogbookTheme.accentBlue
        case "notes": return .yellow
        case "dataBackup": return LogbookTheme.accentOrange
        case "monthlySummary": return LogbookTheme.accentBlue
        case "universalSearch": return .blue
        case "help": return .cyan
        case "search": return .purple
        case "jumpseat": return .cyan
        case "nocTest": return .purple
        case "gpxTesting": return .orange
        case "flightTracks": return .cyan
        #if DEBUG
        case "subscriptionDebug": return .orange
        #endif
        default: return .blue
        }
    }

    // MARK: - iPad Timer Section
    private var iPadTimerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Time display with mode toggle
                VStack(spacing: 4) {
                    Text(formatCompactTime())
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(timerDisplayColor())

                    Text(timer.mode == .stopwatch ? "Stopwatch" : "Countdown")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Mode toggle arrow
                Button(action: {
                    withAnimation {
                        if timer.mode == .stopwatch {
                            timer.switchMode(to: .countdown)
                        } else {
                            timer.switchMode(to: .stopwatch)
                        }
                    }
                }) {
                    Image(systemName: timer.mode == .stopwatch ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(timer.mode == .stopwatch ? .green : .orange)
                }
            }

            // Control buttons (larger for iPad)
            HStack(spacing: 24) {
                Button(action: {
                    if timer.state == .running {
                        timer.pauseTimer()
                    } else {
                        timer.startTimer()
                    }
                }) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(timer.state == .running ? Color.orange : Color.green)
                        .clipShape(Circle())
                }

                Button(action: {
                    timer.stopTimer()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.gray.opacity(0.5))
                        .clipShape(Circle())
                }

                Button(action: {
                    showingTimerSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(LogbookTheme.navyLight)
        .sheet(isPresented: $showingTimerSettings) {
            TimerSettingsView(timer: timer)
        }
    }

    private func formatCompactTime() -> String {
        let totalSeconds = Int(timer.displayTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func timerDisplayColor() -> Color {
        if timer.mode == .countdown && timer.displayTime <= 60 {
            return .red
        } else if timer.state == .running {
            return timer.mode == .stopwatch ? .green : .orange
        } else {
            return .white
        }
    }
}

// MARK: - iPad More Panel Card
struct iPadMorePanelCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 22))
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════════════
// MARK: iPad Tab Editor View (Supports 7 main tabs)
// MARK: ═══════════════════════════════════════════════════════════════════════════

struct iPadTabEditorView: View {
    @ObservedObject var tabManager: CustomizableTabManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customize your iPad tab bar. You can have up to 7 main tabs plus the More button.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)

                    Text("Tap + to add to main tabs, - to remove. Drag to reorder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                List {
                    Section("Main Tabs (\(tabManager.iPadVisibleTabs.count)/7)") {
                        ForEach(tabManager.iPadVisibleTabs) { tab in
                            iPadTabEditorRow(
                                tab: tab,
                                isVisible: true,
                                onToggle: {
                                    removeFromiPadVisible(tab)
                                }
                            )
                        }
                        .onMove { source, destination in
                            var tabs = tabManager.iPadVisibleTabs
                            tabs.move(fromOffsets: source, toOffset: destination)
                            reorderTabs(tabs)
                        }
                    }

                    Section("Available Tabs") {
                        ForEach(tabManager.iPadMoreTabs) { tab in
                            iPadTabEditorRow(
                                tab: tab,
                                isVisible: false,
                                onToggle: {
                                    if tabManager.iPadVisibleTabs.count < 7 {
                                        addToiPadVisible(tab)
                                    }
                                }
                            )
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Edit iPad Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        tabManager.resetToDefaults()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addToiPadVisible(_ tab: TabItem) {
        // Mark the tab as visible
        if let index = tabManager.availableTabs.firstIndex(where: { $0.id == tab.id }) {
            tabManager.availableTabs[index].isVisible = true
            tabManager.updateTabArrays()
        }
    }

    private func removeFromiPadVisible(_ tab: TabItem) {
        // Don't allow removing logbook
        guard tab.id != "logbook" else { return }

        if let index = tabManager.availableTabs.firstIndex(where: { $0.id == tab.id }) {
            tabManager.availableTabs[index].isVisible = false
            tabManager.updateTabArrays()
        }
    }

    private func reorderTabs(_ tabs: [TabItem]) {
        for (index, tab) in tabs.enumerated() {
            if let originalIndex = tabManager.availableTabs.firstIndex(where: { $0.id == tab.id }) {
                tabManager.availableTabs[originalIndex].order = index
            }
        }
        tabManager.updateTabArrays()
    }
}

// MARK: - iPad Tab Editor Row
struct iPadTabEditorRow: View {
    let tab: TabItem
    let isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: tab.systemImage)
                .foregroundColor(.blue)
                .frame(width: 28)

            Text(tab.title)
                .font(.body)

            Spacer()

            if isVisible {
                if tab.id != "logbook" {
                    Button(action: onToggle) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Logbook can't be removed
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            } else {
                Button(action: onToggle) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

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
    @Published var visibleTabs: [TabItem] = []
    @Published var moreTabs: [TabItem] = []
    @Published var recentTab: TabItem?
    
    private let maxVisibleTabs = 5
    private let userDefaults = UserDefaults.standard
    private let tabConfigKey = "TabConfiguration"
    private let recentTabKey = "RecentTabID"
    
    init() {
        // 🔥 CRASH FIX: Wrap in error handling
        do {
            // TEMPORARY - forces reload of tabs
            UserDefaults.standard.removeObject(forKey: "TabConfiguration")
            
            setupDefaultTabs()
            loadConfiguration()
            loadRecentTab()
            updateTabArrays()
        } catch {
            print("⚠️ TabManager init error: \(error)")
            // Fallback to minimal tabs
            availableTabs = [
                TabItem(id: "logbook", title: "Logbook", systemImage: "book.closed", order: 0)
            ]
            updateTabArrays()
        }
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
            
            // ─────────────────────────────────────────────────────────────────
            // SCHEDULE & OPERATIONS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "nocSchedule" → Opens: NOCSettingsView
            TabItem(id: "nocSchedule", title: "NOC Schedule Import", systemImage: "calendar.badge.clock", isVisible: false, order: 10),
            // ID: "tripGeneration" → Opens: TripGenerationSettingsView ⭐ NEW
            TabItem(id: "tripGeneration", title: "Trip Generation", systemImage: "wand.and.stars", isVisible: false, order: 11),
            // ID: "crewContacts" → Opens: CrewImportHelperView
            TabItem(id: "crewContacts", title: "Crew Contacts", systemImage: "person.3.fill", isVisible: false, order: 12),
            
            // ─────────────────────────────────────────────────────────────────
            // CLOCKS & TIMERS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "clocks" → Opens: ClocksTabView
            TabItem(id: "clocks", title: "World Clock", systemImage: "clock.fill", isVisible: false, order: 13),
            
            // ─────────────────────────────────────────────────────────────────
            // FLIGHT TOOLS SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "gpsRaim" → Opens: GPSRAIMView
            TabItem(id: "gpsRaim", title: "GPS/RAIM", systemImage: "location.fill", isVisible: false, order: 14),
            // ID: "weather" → Opens: WeatherView
            TabItem(id: "weather", title: "Weather", systemImage: "cloud.sun.fill", isVisible: false, order: 15),
            // ID: "areaGuide" → Opens: AreaGuideViewComplete <--- ADDED HERE
            TabItem(id: "areaGuide", title: "Area Guide", systemImage: "map.fill", isVisible: false, order: 16),
            // ID: "calculator" → Opens: FlightCalculatorView
            TabItem(id: "calculator", title: "Flight Calculator", systemImage: "function", isVisible: false, order: 17),
            // ID: "flightOps" → Opens: FlightOpsView
            TabItem(id: "flightOps", title: "Flight Ops", systemImage: "airplane.circle.fill", isVisible: false, order: 18),
            
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
            
            // ─────────────────────────────────────────────────────────────────
            // JUMPSEAT NETWORK SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "jumpseat" → Opens: JumpseatView
            // TabItem(id: "jumpseat", title: "Jumpseat Network", systemImage: "person.2.fill", isVisible: false, order: 26),
            
            // ─────────────────────────────────────────────────────────────────
            // BETA TESTING SECTION
            // ─────────────────────────────────────────────────────────────────
            // ID: "gpxTesting" → Opens: GPXTestingView
            TabItem(id: "gpxTesting", title: "GPX Testing", systemImage: "location.viewfinder", isVisible: false, order: 27)
        ] // ; print("📋 Available tabs: \(availableTabs.map { $0.id })")
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
        visibleTabs = Array(sorted.filter { $0.isVisible }.prefix(maxVisibleTabs - 1))
        moreTabs = sorted.filter { !$0.isVisible }
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

// MARK: - Customizable Tab View
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
            // Main content
            TabView(selection: $selectedTab) {
                ForEach(tabManager.visibleTabs) { tab in
                    content(tab.id)
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .tag(tab.id)
                }
                
                // Dynamic Recent Tab
                if let recentTab = tabManager.recentTab {
                    content(recentTab.id)
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
            content(selection.id)
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
    private let flightLoggingTabs = ["autoTimeLogging", "scannerEmailSettings", "scanner"]
    private let scheduleOpsTabs = ["nocSchedule", "tripGeneration", "crewContacts"]
    private let clocksTabs = ["clocks"]
    private let flightToolsTabs = ["gpsRaim", "weather", "areaGuide", "calculator", "flightOps"] // <--- ADDED HERE
    private let trackingReportsTabs = ["flightTimeLimits", "rolling30Day", "far117Compliance", "fleetTracker", "reports", "electronicLogbook"]
    private let documentsDataTabs = ["documents", "notes", "dataBackup"]
    private let jumpseatTabs = ["jumpseat"]
    private let betaTestingTabs = ["gpxTesting"]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - transparent tap area to dismiss
                Color.clear
                    .frame(width: geometry.size.width * 0.35)
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
                .frame(width: geometry.size.width * 0.65)
                .background(LogbookTheme.navyDark)
            }
        }
        .edgesIgnoringSafeArea(.vertical)
    }
    
    // MARK: - Panel Header
    private var panelHeader: some View {
        HStack {
            Text("More")
                .font(.title2)
                .fontWeight(.semibold)
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
        case "tripGeneration": return .purple
        case "crewContacts": return LogbookTheme.accentBlue
        
        // Clocks & Timers
        case "clocks": return LogbookTheme.accentBlue
        
        // Flight Tools
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
        
        // Jumpseat Network
        case "jumpseat": return .cyan
        
        // Beta Testing
        case "gpxTesting": return .orange
        
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
                    .font(.system(size: 16, weight: .medium))
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

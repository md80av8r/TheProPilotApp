// ScheduleCalendarView.swift - Complete Merged Version with All Features
import SwiftUI
import UserNotifications

// MARK: - Schedule View Types
enum ScheduleViewType: String, CaseIterable, Codable, Identifiable {
    case list = "List"
    case agenda = "Agenda"
    case week = "Week"
    case month = "Month"
    case threeDay = "3-Day"
    case workWeek = "Work Week"
    case timeline = "Timeline"
    case year = "Year"
    case gantt = "Gantt"
    case dataAnalyzer = "Data Analyzer"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .agenda: return "list.bullet.indent"
        case .week: return "calendar.day.timeline.leading"
        case .month: return "calendar"
        case .threeDay: return "rectangle.split.3x1"
        case .workWeek: return "calendar.badge.clock"
        case .timeline: return "timeline.selection"
        case .year: return "calendar.circle"
        case .gantt: return "chart.bar.xaxis"
        case .dataAnalyzer: return "magnifyingglass"
        }
    }
    
    var description: String {
        switch self {
        case .list: return "Original list view"
        case .agenda: return "Compact agenda style"
        case .week: return "7-day week grid"
        case .month: return "Traditional month calendar"
        case .threeDay: return "3-day detailed view"
        case .workWeek: return "Monday-Friday only"
        case .timeline: return "Horizontal timeline"
        case .year: return "Full year overview"
        case .gantt: return "Project-style view"
        case .dataAnalyzer: return "Analyze schedule data"
        }
    }
}

// MARK: - Schedule View Preference Manager
class ScheduleViewPreferenceManager: ObservableObject {
    static let shared = ScheduleViewPreferenceManager()
    
    private let userDefaultsKey = "scheduleViewOrder"
    
    @Published var orderedViews: [ScheduleViewType] {
        didSet {
            saveOrder()
        }
    }
    
    private init() {
        // Load saved order or use default
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ScheduleViewType].self, from: savedData) {
            // Ensure all view types are present (in case new ones were added)
            var merged = decoded
            for viewType in ScheduleViewType.allCases {
                if !merged.contains(viewType) {
                    merged.append(viewType)
                }
            }
            self.orderedViews = merged
        } else {
            // Default order
            self.orderedViews = Array(ScheduleViewType.allCases)
        }
    }
    
    private func saveOrder() {
        if let encoded = try? JSONEncoder().encode(orderedViews) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        orderedViews.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Alarm Manager
class ScheduleAlarmManager: ObservableObject {
    @Published var alarmSettings: [String: AlarmSetting] = [:]
    @Published var syncAlerts = true
    @Published var lastSyncTime: Date?
    @Published var autoAlarmEnabled = true
    
    struct AlarmSetting {
        let eventID: String
        let alarmTime: Date
        let isEnabled: Bool
        let reminderMinutes: Int
    }
    
    func setAlarm(for item: BasicScheduleItem, minutesBefore: Int = 60) {
        let alarmTime = item.blockOut.addingTimeInterval(-TimeInterval(minutesBefore * 60))
        
        let content = UNMutableNotificationContent()
        content.title = "Flight Reminder"
        content.body = "Flight \(item.tripNumber) from \(item.departure) to \(item.arrival) departing soon"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error setting alarm: \(error)")
            }
        }
        
        alarmSettings[item.id.uuidString] = AlarmSetting(
            eventID: item.id.uuidString,
            alarmTime: alarmTime,
            isEnabled: true,
            reminderMinutes: minutesBefore
        )
    }
    
    func removeAlarm(for item: BasicScheduleItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
        alarmSettings.removeValue(forKey: item.id.uuidString)
    }
    
    func updateSyncTime() {
        lastSyncTime = Date()
    }
}

// MARK: - Main Schedule Calendar View
struct ScheduleCalendarView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @EnvironmentObject var nocSettings: NOCSettingsStore
    @EnvironmentObject var logbookStore: SwiftDataLogBookStore
    @EnvironmentObject var importMappingStore: ImportMappingStore  // NEW: iCal import mappings
    @StateObject private var alarmManager = ScheduleAlarmManager()
    @StateObject private var viewPreferences = ScheduleViewPreferenceManager.shared
    @State private var selectedViewType: ScheduleViewType?  // nil = use first in ordered list
    @State private var currentDate = Date()
    @State private var showingViewPicker = false
    @State private var showingSyncStatus = false
    @State private var showingAlarmSettings = false
    @State private var showingNOCSettings = false
    @State private var showingUserInfoPrompt = false
    @State private var showingViewOrderEditor = false  // NEW: View order editor
    @State private var selectedItem: BasicScheduleItem?
    @State private var showingDismissedTrips = false
    @State private var showImportWizard = false  // NEW: Import wizard sheet
    @StateObject private var dismissedManager = DismissedRosterItemsManager.shared
    
    // Computed property for the active view type
    private var activeViewType: ScheduleViewType {
        selectedViewType ?? viewPreferences.orderedViews.first ?? .list
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Group {
            if isIPad {
                // iPad: No NavigationView wrapper (already inside NavigationSplitView)
                scheduleContentWrapper
            } else {
                // iPhone: Keep NavigationView
                NavigationView {
                    scheduleContentWrapper
                }
            }
        }
        .onAppear {
            requestNotificationPermission()
            checkUserInfoSetup()
        }
        .sheet(isPresented: $showingAlarmSettings) {
            AlarmSettingsView(alarmManager: alarmManager)
        }
        .sheet(isPresented: $showingNOCSettings) {
            NOCSettingsView(nocSettings: nocSettings, scheduleStore: scheduleStore)
        }
        .sheet(isPresented: $showingDismissedTrips) {
            DismissedRosterItemsView()
        }
        .sheet(item: $selectedItem) { item in
            FlightDetailModal(item: item, alarmManager: alarmManager)
        }
        .sheet(isPresented: $showingSyncStatus) {
            syncStatusDetailView
        }
        .sheet(isPresented: $showImportWizard) {
            ICalendarImportWizardView()
        }
        .sheet(isPresented: $showingViewOrderEditor) {
            ScheduleViewOrderEditor(viewPreferences: viewPreferences)
        }
        .alert("Setup User Information", isPresented: $showingUserInfoPrompt) {
            Button("Setup Now") {
                showingNOCSettings = true
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Would you like to set up your NOC credentials and roster URL? This will allow you to sync your schedule automatically.")
        }
    }
    
    private var scheduleContentWrapper: some View {
        VStack(spacing: 0) {
            headerView
            
            if needsDateNavigation {
                dateNavigationBar
            }
            
            scheduleContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Roster Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .background(LogbookTheme.navy)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImportWizard = true
                } label: {
                    Label("Import Schedule", systemImage: "calendar.badge.plus")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    syncMenuSection
                    Divider()
                    
                    Button {
                        showingDismissedTrips = true
                    } label: {
                        Label("Dismissed Trips", systemImage: "eye.slash")
                    }
                    
                    Divider()
                    
                    alarmsMenuSection
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    // MARK: - Menu Sections
    private var syncMenuSection: some View {
        Section {
            Button {
                showingNOCSettings = true
            } label: {
                Label("NOC Settings", systemImage: "gear")
            }
            
            Divider()
            
            Button {
                nocSettings.fetchRosterCalendar()
            } label: {
                Label {
                    if nocSettings.isSyncing {
                        Text("Syncing...")
                    } else {
                        Text("Sync Now")
                    }
                } icon: {
                    if nocSettings.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .disabled(nocSettings.isSyncing || nocSettings.username.isEmpty || nocSettings.password.isEmpty)
            
            Button {
                showingSyncStatus = true
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Status")
                        if let lastSync = nocSettings.lastSyncTime {
                            Text("Last: \(lastSync, formatter: relativeDateFormatter)")
                                .font(.caption)
                                .foregroundColor(nocSettings.syncSuccess ? .green : .orange)
                        } else {
                            Text("Never synced")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Toggle("Auto Sync", isOn: $nocSettings.autoSyncEnabled)
        }
    }

    private var alarmsMenuSection: some View {
        Section {
            Toggle("Auto Alarms", isOn: $alarmManager.autoAlarmEnabled)
            
            Button {
                showingAlarmSettings = true
            } label: {
                Label("Alarm Settings", systemImage: "alarm")
            }
        }
    }

    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: - Sync Status Detail View
    private var syncStatusDetailView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: nocSettings.syncSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(nocSettings.syncSuccess ? .green : .orange)
                
                Text(nocSettings.syncSuccess ? "Sync Successful" : "Sync Status")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    if let lastSync = nocSettings.lastSyncTime {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("Last sync:")
                            Spacer()
                            Text(lastSync, formatter: DateFormatter.shortDateTime)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: nocSettings.autoSyncEnabled ? "checkmark.circle" : "xmark.circle")
                            .foregroundColor(nocSettings.autoSyncEnabled ? .green : .gray)
                        Text("Auto Sync:")
                        Spacer()
                        Text(nocSettings.autoSyncEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(.gray)
                    }
                    
                    if nocSettings.hasOfflineData, let age = nocSettings.offlineDataAge {
                        let hours = Int(age / 3600)
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.blue)
                            Text("Cached data:")
                            Spacer()
                            Text("\(hours)h old")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let error = nocSettings.fetchError {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Last Error:")
                                    .foregroundColor(.orange)
                            }
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                Button("Close") {
                    showingSyncStatus = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(LogbookTheme.navy)
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Menu {
                    ForEach(viewPreferences.orderedViews) { viewType in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedViewType = viewType
                            }
                        }) {
                            Label(viewType.rawValue, systemImage: viewType.icon)
                            if viewType == activeViewType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        showingViewOrderEditor = true
                    } label: {
                        Label("Customize Order...", systemImage: "line.3.horizontal.decrease")
                    }
                } label: {
                    HStack {
                        Image(systemName: activeViewType.icon)
                        Text(activeViewType.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentBlue)
                    .foregroundColor(LogbookTheme.textPrimary)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                syncStatusIndicator
            }
            .padding(.horizontal)
            
            Text(activeViewType.description)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
        }
        .padding(.vertical, 12)
        .background(LogbookTheme.navyDark)
    }
    
    private var syncStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(syncStatusColor)
                .frame(width: 8, height: 8)
            
            if let lastSync = nocSettings.lastSyncTime {
                Text("Synced \(timeAgoString(from: lastSync))")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.textTertiary)
            } else {
                Text("Not synced")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.errorRed)
            }
        }
        .onTapGesture {
            showingSyncStatus.toggle()
        }
    }

    private var syncStatusColor: Color {
        guard let lastSync = nocSettings.lastSyncTime else { return LogbookTheme.errorRed }
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        
        if hoursSinceSync < 1 { return LogbookTheme.successGreen }
        else if hoursSinceSync < 24 { return LogbookTheme.warningYellow }
        else { return LogbookTheme.errorRed }
    }
    
    private var needsDateNavigation: Bool {
        ![.list, .agenda, .year, .dataAnalyzer].contains(selectedViewType)
    }
    
    private var dateNavigationBar: some View {
        HStack {
            Button(action: { navigateDate(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Spacer()
            
            Text(dateRangeText)
                .font(.headline)
                .foregroundColor(LogbookTheme.textPrimary)
            
            Spacer()
            
            Button(action: { navigateDate(1) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Button("Today") {
                withAnimation {
                    currentDate = Date()
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(LogbookTheme.accentBlue)
            .foregroundColor(LogbookTheme.textPrimary)
            .cornerRadius(8)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
    }
    
    private var scheduleContent: some View {
        Group {
            switch activeViewType {
            case .list:
                OriginalScheduleListView(scheduleStore: scheduleStore, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .agenda:
                AgendaView(scheduleStore: scheduleStore, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .week:
                WeekView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .month:
                MonthView(scheduleStore: scheduleStore, logbookStore: logbookStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 }, selectedViewType: $selectedViewType)
            case .threeDay:
                ThreeDayView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .workWeek:
                WorkWeekView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .timeline:
                TimelineView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .year:
                YearView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .gantt:
                GanttView(scheduleStore: scheduleStore, currentDate: $currentDate, alarmManager: alarmManager, onItemTap: { selectedItem = $0 })
            case .dataAnalyzer:
                ScheduleDataAnalyzer(scheduleStore: scheduleStore)
            }
        }
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        
        switch activeViewType {
        case .list, .agenda:
            return ""
        case .week:
            let startOfWeek = currentDate.startOfWeek
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDate)
        case .threeDay:
            let endDate = Calendar.current.date(byAdding: .day, value: 2, to: currentDate) ?? currentDate
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: currentDate)) - \(formatter.string(from: endDate))"
        case .workWeek:
            let startOfWeek = currentDate.startOfWorkWeek
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 4, to: startOfWeek) ?? startOfWeek
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .timeline:
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: currentDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentDate)
        case .gantt:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: currentDate)
        case .dataAnalyzer:
            return "Data Analysis"
        }
    }
    
    private func navigateDate(_ direction: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component
        let value: Int
        
        switch activeViewType {
        case .list, .agenda, .dataAnalyzer:
            return
        case .week, .workWeek:
            component = .weekOfYear
            value = direction
        case .month, .gantt:
            component = .month
            value = direction
        case .threeDay, .timeline:
            component = .day
            value = direction * (activeViewType == .threeDay ? 3 : 1)
        case .year:
            component = .year
            value = direction
        }
        
        if let newDate = calendar.date(byAdding: component, value: value, to: currentDate) {
            withAnimation {
                currentDate = newDate
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    print("Notification permission denied")
                }
            }
        }
    }
    
    private func checkUserInfoSetup() {
        if nocSettings.username.isEmpty || nocSettings.password.isEmpty || nocSettings.rosterURL.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingUserInfoPrompt = true
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 { return "\(days)d ago" }
        else if hours > 0 { return "\(hours)h ago" }
        else if minutes > 0 { return "\(minutes)m ago" }
        else { return "just now" }
    }
}

// MARK: - Original Schedule List View with Add to Trip
struct OriginalScheduleListView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var alarmManager: ScheduleAlarmManager
    @EnvironmentObject var logbookStore: SwiftDataLogBookStore
    let onItemTap: (BasicScheduleItem) -> Void
    
    @State private var selectedFilter: FilterOption = .currentMonth
    @State private var showingFilterMenu = false
    @State private var showingAllTime = false
    @State private var filteredItems: [BasicScheduleItem] = []
    @State private var groupedItems: [String: [BasicScheduleItem]] = [:]
    @State private var sortedDateKeys: [String] = []
    
    // Add to Trip state
    @State private var selectedRosterItem: BasicScheduleItem?
    @State private var showingAddToTripSheet = false
    
    enum FilterOption: String, CaseIterable {
        case all = "All Events"
        case currentMonth = "This Month"
        case nextMonth = "Next Month"
        case previousMonth = "Last Month"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .currentMonth: return "calendar"
            case .nextMonth: return "calendar.badge.plus"
            case .previousMonth: return "calendar.badge.minus"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerControls
            scrollableContent
        }
        .background(LogbookTheme.navy)
        .sheet(isPresented: $showingAddToTripSheet) {
            if let item = selectedRosterItem {
                RosterItemActionSheet(
                    rosterItem: item,
                    store: logbookStore,
                    isPresented: $showingAddToTripSheet
                )
            }
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    dateSections
                    
                    if filteredItems.isEmpty {
                        emptyStateView
                    }
                }
                .padding(.vertical)
            }
            .background(LogbookTheme.navy)
            .onAppear {
                scrollToToday(proxy: proxy)
                updateFilteredData()
            }
            .onChange(of: showingAllTime) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToToday(proxy: proxy)
                }
                updateFilteredData()
            }
            .onChange(of: scheduleStore.items) {
                updateFilteredData()
            }
            .onChange(of: selectedFilter) {
                updateFilteredData()
            }
        }
    }

    @ViewBuilder
    private var dateSections: some View {
        ForEach(sortedDateKeys, id: \.self) { dateKey in
            dateSectionView(for: dateKey)
        }
    }

    @ViewBuilder
    private func dateSectionView(for dateKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(for: dateKey)
                .id(dateKey)
            
            if let items = groupedItems[dateKey] {
                ForEach(items) { item in
                    ScheduleRowView(
                        item: item,
                        alarmManager: alarmManager,
                        onTap: { onItemTap(item) },
                        onAddToTrip: { selectedItem in
                            selectedRosterItem = selectedItem
                            showingAddToTripSheet = true
                        }
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(for dateKey: String) -> some View {
        HStack {
            Text(sectionTitle(for: dateKey))
                .font(.headline)
                .foregroundColor(isToday(dateKey) ? LogbookTheme.accentBlue : LogbookTheme.textPrimary)
                .padding(.horizontal)
            
            Spacer()
            
            if let count = groupedItems[dateKey]?.count {
                Text("\(count) flights")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .padding(.horizontal)
            }
        }
        .background(isToday(dateKey) ? LogbookTheme.accentBlue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Events")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("No flights found for \(selectedFilter.rawValue.lowercased())")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    private var headerControls: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.circle.fill")
                        Text("Today")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LogbookTheme.accentBlue)
                    .foregroundColor(LogbookTheme.textPrimary)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingAllTime.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showingAllTime ? "calendar" : "calendar.badge.clock")
                        Text(showingAllTime ? "All Time" : "Upcoming")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showingAllTime ? LogbookTheme.successGreen : LogbookTheme.warningYellow)
                    .foregroundColor(LogbookTheme.textPrimary)
                    .cornerRadius(12)
                }
                
                Menu {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedFilter = option
                            }
                        }) {
                            Label(option.rawValue, systemImage: option.icon)
                            if option == selectedFilter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedFilter.icon)
                        Text(selectedFilter.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LogbookTheme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            if !scheduleStore.visibleItems.isEmpty {
                Text(dateRangeSummary)
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(LogbookTheme.fieldBackground)
    }
    
    // MARK: - Data Processing
    private func updateFilteredData() {
        let calendar = Calendar.current
        let now = Date()
        
        let baseItems: [BasicScheduleItem]
        
        if showingAllTime {
            baseItems = scheduleStore.visibleItems
        } else {
            let startOfToday = calendar.startOfDay(for: now)
            baseItems = scheduleStore.visibleItems.filter { item in
                item.date >= startOfToday
            }
        }
        
        let filtered: [BasicScheduleItem]
        
        switch selectedFilter {
        case .all:
            filtered = baseItems
        case .currentMonth:
            filtered = baseItems.filter { item in
                calendar.isDate(item.date, equalTo: now, toGranularity: .month)
            }
        case .nextMonth:
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            filtered = baseItems.filter { item in
                calendar.isDate(item.date, equalTo: nextMonth, toGranularity: .month)
            }
        case .previousMonth:
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filtered = baseItems.filter { item in
                calendar.isDate(item.date, equalTo: previousMonth, toGranularity: .month)
            }
        }
        
        self.filteredItems = filtered
        
        let grouped = Dictionary(grouping: filtered) { item in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: item.date)
        }
        
        var sortedGrouped: [String: [BasicScheduleItem]] = [:]
        for (key, items) in grouped {
            sortedGrouped[key] = items.sorted { $0.blockOut < $1.blockOut }
        }
        
        self.groupedItems = sortedGrouped
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let dateMapping: [(Date, String)] = filtered.compactMap { item in
            let dateString = formatter.string(from: item.date)
            return (item.date, dateString)
        }
        
        let uniqueDates = Array(Set(dateMapping.map { $0.1 }))
        let sortedDates = uniqueDates.sorted { dateString1, dateString2 in
            guard let date1 = dateMapping.first(where: { $0.1 == dateString1 })?.0,
                  let date2 = dateMapping.first(where: { $0.1 == dateString2 })?.0 else {
                return dateString1 < dateString2
            }
            return date1 < date2
        }
        
        self.sortedDateKeys = sortedDates
    }
    
    private var dateRangeSummary: String {
        guard !scheduleStore.visibleItems.isEmpty else { return "No flights scheduled" }
        
        let sortedItems = scheduleStore.visibleItems.sorted { $0.date < $1.date }
        let firstDate = sortedItems.first!.date
        let lastDate = sortedItems.last!.date
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let totalFlights = scheduleStore.visibleItems.count
        let visibleFlights = groupedItems.values.flatMap { $0 }.count
        
        if showingAllTime {
            return "Showing all \(totalFlights) flights from \(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate))"
        } else {
            return "Showing \(visibleFlights) upcoming flights (of \(totalFlights) total)"
        }
    }

    private func sectionTitle(for key: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        guard let date = formatter.date(from: key) else { return key }
        
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today - \(key)"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today) ?? today) {
            return "Tomorrow - \(key)"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today) ?? today) {
            return "Yesterday - \(key)"
        }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: date)
        
        return "\(dayOfWeek), \(key)"
    }
    
    private func isToday(_ dateKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let todayString = formatter.string(from: Date())
        return dateKey == todayString
    }
    
    private func scrollToToday(proxy: ScrollViewProxy) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let todayString = formatter.string(from: Date())
        
        if groupedItems.keys.contains(todayString) {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo(todayString, anchor: .top)
            }
        } else {
            let today = Date()
            let futureItems = scheduleStore.visibleItems.filter { $0.date >= today }
            
            if let nearestFuture = futureItems.min(by: { $0.date < $1.date }) {
                let nearestDateString = formatter.string(from: nearestFuture.date)
                withAnimation(.easeInOut(duration: 0.8)) {
                    proxy.scrollTo(nearestDateString, anchor: .top)
                }
            } else if showingAllTime {
                let pastItems = scheduleStore.visibleItems.filter { $0.date < today }
                if let mostRecent = pastItems.max(by: { $0.date < $1.date }) {
                    let recentDateString = formatter.string(from: mostRecent.date)
                    withAnimation(.easeInOut(duration: 0.8)) {
                        proxy.scrollTo(recentDateString, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Schedule Row View with Context Menu
struct ScheduleRowView: View {
    let item: BasicScheduleItem
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onTap: () -> Void
    var onAddToTrip: ((BasicScheduleItem) -> Void)? = nil
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var isPastFlight: Bool {
        item.blockIn < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(item.status.color)
                .frame(width: 6)
                .opacity(isPastFlight ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.displayTitle)
                        .font(.subheadline.bold())
                        .foregroundColor(isPastFlight ? LogbookTheme.textSecondary : LogbookTheme.textPrimary)
                    
                    Spacer()
                    
                    if alarmManager.alarmSettings[item.id.uuidString]?.isEnabled == true {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                            .font(.caption)
                    }
                    
                    // Time display - varies by item type
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.startTimeLabel): \(timeFormatter.string(from: item.blockOut))")
                            .font(.caption2)
                            .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.textSecondary)
                        
                        if item.shouldShowDuration {
                            Text("\(item.endTimeLabel): \(timeFormatter.string(from: item.blockIn))")
                                .font(.caption2)
                                .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.textSecondary)
                        }
                    }
                }
                
                // Route - only show for flights/deadheads with valid airports
                if item.status == .activeTrip || item.status == .deadhead {
                    if !item.departure.isEmpty && !item.arrival.isEmpty {
                        Text("\(item.departure) → \(item.arrival)")
                            .font(.subheadline)
                            .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.accentBlue)
                    }
                } else if item.status == .other {
                    // For rest - show location, but hide for off-duty
                    let upper = item.tripNumber.uppercased()
                    if !item.departure.isEmpty && !upper.contains("OFF") {
                        Text(item.departure)
                            .font(.subheadline)
                            .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.textSecondary)
                    }
                }
                
                HStack {
                    // Duration with correct label
                    if item.shouldShowDuration {
                        Text("\(item.durationLabel): \(item.formattedDuration)")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    if isPastFlight {
                        Text("Completed")
                            .font(.caption2.bold())
                            .foregroundColor(LogbookTheme.successGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LogbookTheme.successGreen.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("Scheduled")
                            .font(.caption2.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LogbookTheme.accentBlue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(
            isPastFlight ? LogbookTheme.cardBackground.opacity(0.5) : LogbookTheme.cardBackground
        ))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.status.color.opacity(isPastFlight ? 0.3 : 0.8), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            if item.status == .activeTrip || item.status == .deadhead {
                Button {
                    onAddToTrip?(item)
                } label: {
                    Label("Add to Trip", systemImage: "plus.circle")
                }
                
                Divider()
            }
            
            Button {
                onTap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
            
            Button(role: .destructive) {
                DismissedRosterItemsManager.shared.dismiss(item, reason: .notFlying)
            } label: {
                Label("Dismiss", systemImage: "eye.slash")
            }
        }
    }
}

// MARK: - Agenda View
struct AgendaView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(upcomingItems, id: \.id) { item in
                    AgendaRowView(item: item, alarmManager: alarmManager, onTap: { onItemTap(item) })
                }
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private var upcomingItems: [BasicScheduleItem] {
        scheduleStore.visibleItems
            .filter { $0.date >= Date().addingTimeInterval(-24*60*60) }
            .sorted { $0.blockOut < $1.blockOut }
    }
}

struct AgendaRowView: View {
    let item: BasicScheduleItem
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text("On Call")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.textTertiary)
                Text(timeFormatter.string(from: item.blockOut))
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                Text("Block In")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.textTertiary)
                Text(timeFormatter.string(from: item.blockIn))
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
            .frame(width: 60)
            
            Rectangle()
                .fill(item.status.color)
                .frame(width: 4)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.displayTitle)
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.textPrimary)
                    
                    Spacer()
                    
                    if alarmManager.alarmSettings[item.id.uuidString]?.isEnabled == true {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                            .font(.caption)
                    }
                }
                
                Text("\(item.departure) → \(item.arrival)")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(LogbookTheme.cardBackground.opacity(0.5))
        .onTapGesture {
            onTap()
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Week View
struct WeekView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    private var weekDays: [Date] {
        let startOfWeek = currentDate.startOfWeek
        return (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                weekDayHeaders
                weekGrid
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private var weekDayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                VStack(spacing: 4) {
                    Text(DateFormatters.dayFormatter.string(from: day))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text(DateFormatters.dateFormatter.string(from: day))
                        .font(.headline)
                        .foregroundColor(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                                       LogbookTheme.accentBlue : LogbookTheme.textPrimary)
                    
                    let dayFlights = flightsForDay(day)
                    if !dayFlights.isEmpty {
                        Text("\(dayFlights.count) flights")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                           LogbookTheme.accentBlue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
    }
    
    private var weekGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                VStack(spacing: 2) {
                    ForEach(flightsForDay(day), id: \.id) { flight in
                        WeekFlightCard(item: flight, alarmManager: alarmManager, onTap: { onItemTap(flight) })
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200, alignment: .top)
                .background(LogbookTheme.cardBackground.opacity(0.3))
                .border(LogbookTheme.divider, width: 0.5)
            }
        }
    }
    
    private func flightsForDay(_ day: Date) -> [BasicScheduleItem] {
        scheduleStore.visibleItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: day)
        }
    }
}

// MARK: - Month View
struct MonthView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    @Binding var selectedViewType: ScheduleViewType?  // NEW: For switching views
    
    private var monthDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
        
        // Get the weekday of the 1st (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Calculate how many empty cells we need before the 1st
        let leadingEmptyDays = firstWeekday - 1
        
        // Get all the days in this month
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let monthDates = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
        
        // Add empty cells before the first day
        var result: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        result.append(contentsOf: monthDates.map { Optional($0) })
        
        return result
    }
    
    /// All items for the current month
    private var monthItems: [BasicScheduleItem] {
        let calendar = Calendar.current
        return scheduleStore.visibleItems.filter { item in
            calendar.isDate(item.date, equalTo: currentDate, toGranularity: .month)
        }
    }
    
    /// Monthly statistics
    private var monthStats: MonthlyStats {
        var stats = MonthlyStats()
        
        let calendar = Calendar.current
        var uniqueTripNumbers = Set<String>()
        var totalBlockMinutes = 0
        
        for item in monthItems {
            let upper = item.tripNumber.uppercased()
            
            if item.status == .activeTrip {
                stats.flightDays += 1
                stats.flightLegs += 1
                
                // Track unique trip numbers
                if !upper.isEmpty && !upper.contains("OFF") && !upper.contains("REST") {
                    uniqueTripNumbers.insert(item.tripNumber)
                }
                
                // Get actual block hours from logbook for this day
                let dayTrips = logbookStore.trips.filter { trip in
                    calendar.isDate(trip.date, inSameDayAs: item.date)
                }
                
                for trip in dayTrips {
                    for logpage in trip.logpages {
                        for leg in logpage.legs {
                            if let blockMins = calculateBlockMinutes(outTime: leg.outTime, inTime: leg.inTime) {
                                totalBlockMinutes += blockMins
                            }
                        }
                    }
                }
            } else if item.status == .deadhead {
                stats.deadheadDays += 1
            } else if item.status == .onDuty {
                stats.onDutyDays += 1
            } else if upper.contains("WOFF") || upper.contains("WORKING DAY OFF") {
                stats.woffDays += 1
            } else if upper.contains("OFF") && !upper.contains("WOFF") {
                stats.offDays += 1
            } else if upper.contains("VAC") {
                stats.vacationDays += 1
            } else if upper.contains("HOL") {
                stats.holidayDays += 1
            } else if upper.contains("REST") {
                stats.restDays += 1
            }
        }
        
        stats.tripCount = uniqueTripNumbers.count
        stats.totalBlockMinutes = totalBlockMinutes
        
        return stats
    }
    
    /// Calculate block minutes from HHMM format strings
    private func calculateBlockMinutes(outTime: String, inTime: String) -> Int? {
        guard outTime.count == 4, inTime.count == 4,
              let outHour = Int(outTime.prefix(2)),
              let outMin = Int(outTime.suffix(2)),
              let inHour = Int(inTime.prefix(2)),
              let inMin = Int(inTime.suffix(2)) else {
            return nil
        }
        
        let outTotal = outHour * 60 + outMin
        var inTotal = inHour * 60 + inMin
        
        // Handle overnight flights
        if inTotal < outTotal {
            inTotal += 24 * 60
        }
        
        return inTotal - outTotal
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                    ForEach(Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()), id: \.element) { index, day in
                        Button {
                            // Find first occurrence of this weekday in the month
                            let calendar = Calendar.current
                            if let firstDay = monthDays.compactMap({ $0 }).first(where: { calendar.component(.weekday, from: $0) == index + 1 }) {
                                currentDate = firstDay
                                withAnimation {
                                    selectedViewType = .week
                                }
                            }
                        } label: {
                            Text(day)
                                .font(.caption.bold())
                                .foregroundColor(LogbookTheme.textSecondary)
                                .frame(height: 30)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ForEach(Array(monthDays.enumerated()), id: \.offset) { index, optionalDay in
                        if let day = optionalDay {
                            MonthDayCell(
                                day: day,
                                flights: flightsForDay(day),
                                logbookStore: logbookStore,
                                alarmManager: alarmManager,
                                onItemTap: onItemTap,
                                onDayTap: { tappedDay in
                                    // Switch to list view and set the date
                                    currentDate = tappedDay
                                    withAnimation {
                                        selectedViewType = .list
                                    }
                                }
                            )
                        } else {
                            // Empty cell for days before the month starts
                            Color.clear
                                .frame(height: 80)
                        }
                    }
                }
                .padding()
            }
            
            // Monthly Summary Footer
            MonthSummaryFooter(stats: monthStats)
        }
        .background(LogbookTheme.navy)
    }
    
    private func flightsForDay(_ day: Date) -> [BasicScheduleItem] {
        scheduleStore.visibleItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: day)
        }
    }
}

// MARK: - Monthly Statistics
struct MonthlyStats {
    var flightDays: Int = 0
    var flightLegs: Int = 0
    var deadheadDays: Int = 0
    var onDutyDays: Int = 0
    var woffDays: Int = 0
    var offDays: Int = 0
    var vacationDays: Int = 0
    var holidayDays: Int = 0
    var restDays: Int = 0
    var tripCount: Int = 0
    var totalBlockMinutes: Int = 0
    
    var totalDaysOff: Int {
        offDays + vacationDays + holidayDays
    }
    
    var totalWorkDays: Int {
        flightDays + deadheadDays + onDutyDays + woffDays
    }
    
    var formattedBlockTime: String {
        let hours = totalBlockMinutes / 60
        let minutes = totalBlockMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

// MARK: - Month Summary Footer
struct MonthSummaryFooter: View {
    let stats: MonthlyStats
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .background(LogbookTheme.divider)
            
            // Main stats row
            HStack(spacing: 16) {
                ScheduleStatBadge(
                    icon: "airplane",
                    value: "\(stats.flightDays)",
                    label: "Flight Days",
                    color: LogbookTheme.accentGreen
                )
                
                if stats.deadheadDays > 0 {
                    ScheduleStatBadge(
                        icon: "airplane.circle",
                        value: "\(stats.deadheadDays)",
                        label: "Deadhead",
                        color: .orange
                    )
                }
                
                if stats.onDutyDays > 0 {
                    ScheduleStatBadge(
                        icon: "clock.badge.checkmark",
                        value: "\(stats.onDutyDays)",
                        label: "On Duty",
                        color: LogbookTheme.accentBlue
                    )
                }
                
                if stats.woffDays > 0 {
                    ScheduleStatBadge(
                        icon: "dollarsign.circle.fill",
                        value: "\(stats.woffDays)",
                        label: "WOFF",
                        color: .yellow
                    )
                }
                
                ScheduleStatBadge(
                    icon: "house.fill",
                    value: "\(stats.totalDaysOff)",
                    label: "Days Off",
                    color: .red.opacity(0.7)
                )
            }
            .padding(.horizontal)
            
            // Flight stats row - Trips Flown and Hours Flown
            if stats.tripCount > 0 || stats.totalBlockMinutes > 0 {
                HStack(spacing: 16) {
                    if stats.tripCount > 0 {
                        ScheduleStatBadge(
                            icon: "number.circle.fill",
                            value: "\(stats.tripCount)",
                            label: "Trips Flown",
                            color: LogbookTheme.accentBlue
                        )
                    }
                    
                    if stats.totalBlockMinutes > 0 {
                        ScheduleStatBadge(
                            icon: "clock.fill",
                            value: stats.formattedBlockTime,
                            label: "Hours Flown",
                            color: LogbookTheme.accentGreen
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Secondary stats row (if applicable)
            if stats.vacationDays > 0 || stats.holidayDays > 0 || stats.restDays > 0 {
                HStack(spacing: 16) {
                    if stats.vacationDays > 0 {
                        MiniStatBadge(label: "VAC", value: stats.vacationDays, color: .red.opacity(0.7))
                    }
                    if stats.holidayDays > 0 {
                        MiniStatBadge(label: "HOL", value: stats.holidayDays, color: .red.opacity(0.7))
                    }
                    if stats.restDays > 0 {
                        MiniStatBadge(label: "REST", value: stats.restDays, color: .purple.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Work Days: \(stats.totalWorkDays)")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(LogbookTheme.cardBackground)
    }
}

// MARK: - Stat Badge Components
struct ScheduleStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(value)
                    .font(.headline.bold())
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(LogbookTheme.textSecondary)
        }
    }
}

struct MiniStatBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(LogbookTheme.textSecondary)
            Text("\(value)")
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Three Day View
struct ThreeDayView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    private var threeDays: [Date] {
        (0..<3).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: currentDate)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                threeDayHeaders
                threeDayContent
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private var threeDayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(threeDays, id: \.self) { day in
                VStack(spacing: 4) {
                    Text(DateFormatters.dayFormatter.string(from: day))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text(DateFormatters.dateFormatter.string(from: day))
                        .font(.title2.bold())
                        .foregroundColor(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                                       LogbookTheme.accentBlue : LogbookTheme.textPrimary)
                    
                    let dayFlights = flightsForDay(day)
                    Text("\(dayFlights.count) flights")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                           LogbookTheme.accentBlue.opacity(0.2) : LogbookTheme.fieldBackground)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var threeDayContent: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(threeDays, id: \.self) { day in
                VStack(spacing: 4) {
                    ForEach(flightsForDay(day), id: \.id) { flight in
                        ThreeDayFlightCard(item: flight, alarmManager: alarmManager, onTap: { onItemTap(flight) })
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
                .padding(4)
                .background(LogbookTheme.cardBackground.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func flightsForDay(_ day: Date) -> [BasicScheduleItem] {
        scheduleStore.visibleItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: day)
        }.sorted { $0.blockOut < $1.blockOut }
    }
}

// MARK: - Work Week View
struct WorkWeekView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    private var workWeekDays: [Date] {
        let startOfWorkWeek = currentDate.startOfWorkWeek
        return (0..<5).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWorkWeek)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                workWeekHeaders
                workWeekGrid
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private var workWeekHeaders: some View {
        HStack(spacing: 0) {
            ForEach(workWeekDays, id: \.self) { day in
                VStack(spacing: 4) {
                    Text(DateFormatters.dayFormatter.string(from: day))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text(DateFormatters.dateFormatter.string(from: day))
                        .font(.headline)
                        .foregroundColor(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                                       LogbookTheme.accentBlue : LogbookTheme.textPrimary)
                    
                    let dayFlights = flightsForDay(day)
                    if !dayFlights.isEmpty {
                        Text("\(dayFlights.count) flights")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentGreen)
                    } else {
                        Text("Off")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                           LogbookTheme.accentBlue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
    }
    
    private var workWeekGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(workWeekDays, id: \.self) { day in
                VStack(spacing: 2) {
                    ForEach(flightsForDay(day), id: \.id) { flight in
                        WeekFlightCard(item: flight, alarmManager: alarmManager, onTap: { onItemTap(flight) })
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200, alignment: .top)
                .background(LogbookTheme.cardBackground.opacity(0.3))
                .border(LogbookTheme.divider, width: 0.5)
            }
        }
    }
    
    private func flightsForDay(_ day: Date) -> [BasicScheduleItem] {
        scheduleStore.visibleItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: day)
        }
    }
}

// MARK: - Timeline View
struct TimelineView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    private var dayFlights: [BasicScheduleItem] {
        scheduleStore.visibleItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: currentDate)
        }.sorted { $0.blockOut < $1.blockOut }
    }
    
    private let timeSlots = Array(0...23)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                timelineHeader
                timelineContent
            }
        }
        .background(LogbookTheme.navy)
    }
    
    private var timelineHeader: some View {
        HStack(spacing: 0) {
            ForEach(timeSlots, id: \.self) { hour in
                VStack {
                    Text("\(hour):00")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Rectangle()
                        .fill(LogbookTheme.divider)
                        .frame(width: 1, height: 20)
                }
                .frame(width: 60)
            }
        }
        .padding(.horizontal)
        .background(LogbookTheme.fieldBackground)
    }
    
    private var timelineContent: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(timeSlots, id: \.self) { hour in
                    Rectangle()
                        .fill(hour % 4 == 0 ? LogbookTheme.divider : LogbookTheme.divider.opacity(0.3))
                        .frame(width: 1)
                }
            }
            
            if Calendar.current.isDate(currentDate, inSameDayAs: Date()) {
                currentTimeIndicator
            }
            
            ForEach(Array(dayFlights.enumerated()), id: \.element.id) { index, flight in
                TimelineFlightBar(
                    item: flight,
                    index: index,
                    alarmManager: alarmManager,
                    onTap: { onItemTap(flight) }
                )
            }
        }
        .frame(height: max(200, CGFloat(dayFlights.count * 40 + 60)))
        .padding(.horizontal)
    }
    
    private var currentTimeIndicator: some View {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())
        let xPosition = CGFloat(currentHour * 60 + currentMinute) / 60.0 * 60.0
        
        return Rectangle()
            .fill(LogbookTheme.errorRed)
            .frame(width: 2)
            .offset(x: xPosition)
    }
}

// MARK: - Year View
struct YearView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    private var yearMonths: [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(yearMonths, id: \.self) { month in
                    YearMonthView(
                        month: month,
                        scheduleStore: scheduleStore,
                        alarmManager: alarmManager,
                        onItemTap: onItemTap
                    )
                }
            }
            .padding()
        }
        .background(LogbookTheme.navy)
    }
}

// MARK: - Gantt View
struct GanttView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Binding var currentDate: Date
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    var body: some View {
        ScrollView {
            Text("Gantt Chart View")
                .foregroundColor(.white)
                .padding()
        }
        .background(LogbookTheme.navy)
    }
}

// MARK: - Supporting Views

struct WeekFlightCard: View {
    let item: BasicScheduleItem
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(item.status.color)
                    .frame(width: 6, height: 6)
                
                Text(item.displayTitle)
                    .font(.caption2.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                if alarmManager.alarmSettings[item.id.uuidString]?.isEnabled == true {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                        .font(.system(size: 8))
                }
            }
            
            Text("\(item.departure) → \(item.arrival)")
                .font(.caption2)
                .foregroundColor(LogbookTheme.accentBlue)
                .lineLimit(1)
        }
        .padding(4)
        .background(item.status.color.opacity(0.1))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(item.status.color, lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct ThreeDayFlightCard: View {
    let item: BasicScheduleItem
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onTap: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(item.status.color)
                    .frame(width: 8, height: 8)
                
                Text(item.displayTitle)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                
                Spacer()
                
                if alarmManager.alarmSettings[item.id.uuidString]?.isEnabled == true {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                        .font(.caption2)
                }
            }
            
            Text("\(item.departure) → \(item.arrival)")
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("\(timeFormatter.string(from: item.blockOut)) - \(timeFormatter.string(from: item.blockIn))")
                .font(.caption2)
                .foregroundColor(LogbookTheme.textSecondary)
        }
        .padding(8)
        .background(item.status.color.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.status.color, lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct MonthDayCell: View {
    let day: Date
    let flights: [BasicScheduleItem]
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    let onDayTap: (Date) -> Void  // NEW: Callback for tapping the day itself
    
    // MARK: - Day Type Detection
    
    /// Check if day has WOFF (Working Day Off) - premium pay!
    private var hasWOFF: Bool {
        flights.contains { item in
            let upper = item.tripNumber.uppercased()
            return upper.contains("WOFF") || upper.contains("WORKING DAY OFF")
        }
    }
    
    /// Check if day has actual flight legs (UJ### pattern, not duty codes)
    private var hasActualFlights: Bool {
        flights.contains { item in
            let upper = item.tripNumber.uppercased()
            // Check for flight number pattern (UJ followed by digits)
            let hasFlightNumber = upper.range(of: #"UJ\d+"#, options: .regularExpression) != nil ||
                                  upper.range(of: #"^[A-Z]{2}\d{3,4}"#, options: .regularExpression) != nil
            
            return item.status == .activeTrip && hasFlightNumber
        }
    }
    
    /// Count of unique trip numbers for this day from logbook
    private var tripNumberCount: Int {
        let calendar = Calendar.current
        let dayTrips = logbookStore.trips.filter { trip in
            calendar.isDate(trip.date, inSameDayAs: day)
        }
        
        // Get unique trip numbers
        let uniqueTripNumbers = Set(dayTrips.map { $0.tripNumber }).filter { !$0.isEmpty }
        return uniqueTripNumbers.count
    }
    
    /// Total block hours for this day from logbook
    private var dayBlockHours: String {
        let calendar = Calendar.current
        let dayTrips = logbookStore.trips.filter { trip in
            calendar.isDate(trip.date, inSameDayAs: day)
        }
        
        var totalMinutes = 0
        for trip in dayTrips {
            for logpage in trip.logpages {
                for leg in logpage.legs {
                    if let blockMins = calculateBlockMinutes(outTime: leg.outTime, inTime: leg.inTime) {
                        totalMinutes += blockMins
                    }
                }
            }
        }
        
        if totalMinutes == 0 {
            return ""
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    /// Calculate block minutes from HHMM format strings
    private func calculateBlockMinutes(outTime: String, inTime: String) -> Int? {
        guard outTime.count == 4, inTime.count == 4,
              let outHour = Int(outTime.prefix(2)),
              let outMin = Int(outTime.suffix(2)),
              let inHour = Int(inTime.prefix(2)),
              let inMin = Int(inTime.suffix(2)) else {
            return nil
        }
        
        let outTotal = outHour * 60 + outMin
        var inTotal = inHour * 60 + inMin
        
        // Handle overnight flights
        if inTotal < outTotal {
            inTotal += 24 * 60
        }
        
        return inTotal - outTotal
    }
    
    /// Count of actual flight legs
    private var flightCount: Int {
        flights.filter { item in
            let upper = item.tripNumber.uppercased()
            let hasFlightNumber = upper.range(of: #"UJ\d+"#, options: .regularExpression) != nil ||
                                  upper.range(of: #"^[A-Z]{2}\d{3,4}"#, options: .regularExpression) != nil
            return item.status == .activeTrip && hasFlightNumber
        }.count
    }
    
    /// Determine the primary color for this day
    private var dayColor: Color {
        guard !flights.isEmpty else { return .clear }
        
        // If flying on WOFF = green (flight takes priority for color)
        if hasWOFF && hasActualFlights {
            return LogbookTheme.accentGreen
        }
        
        // WOFF only (no flight) = gold
        if hasWOFF {
            return .yellow
        }
        
        // Regular flights
        if hasActualFlights {
            return LogbookTheme.accentGreen
        }
        
        // Deadhead
        if flights.contains(where: { $0.status == .deadhead }) {
            return .orange
        }
        
        // On Duty
        if flights.contains(where: { $0.status == .onDuty }) {
            return LogbookTheme.accentBlue
        }
        
        // Regular day off
        let hasOff = flights.contains { item in
            let upper = item.tripNumber.uppercased()
            return (upper.contains("OFF") && !upper.contains("WOFF")) ||
                   upper.contains("VAC") || upper.contains("HOL")
        }
        if hasOff {
            return .red.opacity(0.7)
        }
        
        // Rest
        if flights.contains(where: { $0.tripNumber.uppercased().contains("REST") }) {
            return .purple.opacity(0.7)
        }
        
        return .gray
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 2) {
            // Day number
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption)
                .foregroundColor(Calendar.current.isDate(day, inSameDayAs: Date()) ?
                               LogbookTheme.accentBlue : LogbookTheme.textPrimary)
            
            if !flights.isEmpty {
                // Icons row - can show multiple icons!
                HStack(spacing: 2) {
                    // Flight icon (if flying)
                    if hasActualFlights {
                        Image(systemName: "airplane")
                            .font(.system(size: 10))
                            .foregroundColor(LogbookTheme.accentGreen)
                    } else if flights.contains(where: { $0.status == .deadhead }) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    } else if flights.contains(where: { $0.status == .onDuty }) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(LogbookTheme.accentBlue)
                    } else if !hasWOFF {
                        // Show appropriate icon for non-WOFF, non-flight days
                        let hasOff = flights.contains { item in
                            let upper = item.tripNumber.uppercased()
                            return (upper.contains("OFF") && !upper.contains("WOFF")) ||
                                   upper.contains("VAC") || upper.contains("HOL")
                        }
                        if hasOff {
                            Image(systemName: "house.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.7))
                        } else {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }
                    
                    // WOFF dollar sign (always show if WOFF, regardless of flight)
                    if hasWOFF {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
                
                Spacer()
                
                // Bottom row: Trip count (left) and Block hours (right)
                if hasActualFlights && (tripNumberCount > 0 || !dayBlockHours.isEmpty) {
                    HStack(alignment: .bottom) {
                        // Trip count - bottom left
                        if tripNumberCount > 0 {
                            Text("\(tripNumberCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                        
                        Spacer()
                        
                        // Block hours - bottom right
                        if !dayBlockHours.isEmpty {
                            Text(dayBlockHours)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    .padding(.horizontal, 2)
                } else if !hasActualFlights {
                    // For non-flight days, show status abbreviation centered
                    if let label = statusLabel {
                        Text(label)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(dayColor)
                    }
                }
                
                // Alarm indicator (if needed, show at very bottom)
                if flights.contains(where: { alarmManager.alarmSettings[$0.id.uuidString]?.isEnabled == true }) {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(LogbookTheme.warningYellow)
                        .font(.system(size: 7))
                }
            }
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .background(
            Calendar.current.isDate(day, inSameDayAs: Date()) ?
                LogbookTheme.accentBlue.opacity(0.2) :
                (flights.isEmpty ? LogbookTheme.cardBackground.opacity(0.3) : dayColor.opacity(0.1))
        )
        .border(LogbookTheme.divider, width: 0.5)
        .onTapGesture {
            // When user taps a day, switch to list view for that day
            onDayTap(day)
        }
    }
    
    /// Status label for non-flight days
    private var statusLabel: String? {
        guard let firstItem = flights.first else { return nil }
        
        // Don't show label if we have flights
        if flightCount > 0 { return nil }
        
        let upper = firstItem.tripNumber.uppercased()
        
        // WOFF only (no flight)
        if hasWOFF { return "W$" }
        
        if upper.contains("OFF") { return "OFF" }
        if upper.contains("OND") { return "OND" }
        if upper.contains("REST") { return "RST" }
        if upper.contains("VAC") { return "VAC" }
        if upper.contains("HOL") { return "HOL" }
        
        return nil
    }
}

struct TimelineFlightBar: View {
    let item: BasicScheduleItem
    let index: Int
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            if alarmManager.alarmSettings[item.id.uuidString]?.isEnabled == true {
                Image(systemName: "alarm.fill")
                    .foregroundColor(LogbookTheme.accentGreen)
                    .font(.caption2)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                
                Text("\(item.departure) → \(item.arrival)")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(item.status.color.opacity(0.2))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(item.status.color, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct YearMonthView: View {
    let month: Date
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var alarmManager: ScheduleAlarmManager
    let onItemTap: (BasicScheduleItem) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text(month.monthName)
                .font(.caption.bold())
                .foregroundColor(LogbookTheme.textPrimary)
            
            let monthFlights = flightsForMonth(month)
            Text("\(monthFlights.count) flights")
                .font(.caption2)
                .foregroundColor(LogbookTheme.accentBlue)
        }
        .padding(8)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(8)
        .onTapGesture {
            if let firstFlight = flightsForMonth(month).first {
                onItemTap(firstFlight)
            }
        }
    }
    
    private func flightsForMonth(_ month: Date) -> [BasicScheduleItem] {
        let calendar = Calendar.current
        return scheduleStore.visibleItems.filter { item in
            calendar.isDate(item.date, equalTo: month, toGranularity: .month)
        }
    }
}

// MARK: - Alarm Settings View
struct AlarmSettingsView: View {
    @ObservedObject var alarmManager: ScheduleAlarmManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Default Settings") {
                    Toggle("Auto Alarms for New Flights", isOn: $alarmManager.autoAlarmEnabled)
                    Toggle("Sync Change Alerts", isOn: $alarmManager.syncAlerts)
                }
                
                Section("Active Alarms") {
                    if alarmManager.alarmSettings.isEmpty {
                        Text("No active alarms")
                            .foregroundColor(LogbookTheme.textSecondary)
                    } else {
                        ForEach(Array(alarmManager.alarmSettings.values), id: \.eventID) { alarm in
                            HStack {
                                Text("Flight Reminder")
                                Spacer()
                                Text("\(alarm.reminderMinutes) min before")
                                    .foregroundColor(LogbookTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alarm Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Flight Detail Modal
struct FlightDetailModal: View {
    let item: BasicScheduleItem
    @ObservedObject var alarmManager: ScheduleAlarmManager
    @Environment(\.dismiss) private var dismiss
    @State private var reminderMinutes = 60
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    /// Dynamic title based on item type
    private var modalTitle: String {
        switch item.status {
        case .activeTrip: return "Flight Details"
        case .deadhead: return "Deadhead Details"
        case .onDuty: return "Duty Details"
        case .other:
            let upper = item.tripNumber.uppercased()
            if upper.contains("REST") { return "Rest Period" }
            if upper.contains("OFF") { return "Day Off" }
            return "Schedule Details"
        }
    }
    
    /// Section header based on item type
    private var sectionHeader: String {
        switch item.status {
        case .activeTrip: return "Flight Details"
        case .deadhead: return "Deadhead Details"
        case .onDuty: return "Duty Details"
        case .other: return "Details"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(sectionHeader) {
                    // Row 1: Flight/Activity identifier
                    HStack {
                        Text(item.status == .activeTrip ? "Flight" : "Activity")
                        Spacer()
                        Text(item.displayTitle)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    // Row 2: Route (only for flights/deadheads with valid airports)
                    if (item.status == .activeTrip || item.status == .deadhead) &&
                        !item.departure.isEmpty && !item.arrival.isEmpty {
                        HStack {
                            Text("Route")
                            Spacer()
                            Text("\(item.departure) → \(item.arrival)")
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    } else if !item.departure.isEmpty {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(item.departure)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                    
                    // Row 3: Start time with correct label
                    HStack {
                        Text(item.startTimeLabel)
                        Spacer()
                        Text(timeFormatter.string(from: item.blockOut))
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                    
                    // Row 4: End time with correct label (if applicable)
                    if item.shouldShowDuration {
                        HStack {
                            Text(item.endTimeLabel)
                            Spacer()
                            Text(timeFormatter.string(from: item.blockIn))
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        
                        // Row 5: Duration with correct label
                        HStack {
                            Text(item.durationLabel)
                            Spacer()
                            Text(item.formattedDuration)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
                
                // Only show reminder section for flights and deadheads
                if item.status == .activeTrip || item.status == .deadhead {
                    Section("Reminder") {
                        Picker("Remind me", selection: $reminderMinutes) {
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                            Text("2 hours before").tag(120)
                            Text("1 day before").tag(1440)
                        }
                        
                        if alarmManager.alarmSettings[item.id.uuidString] != nil {
                            Button("Remove Alarm", role: .destructive) {
                                alarmManager.removeAlarm(for: item)
                                dismiss()
                            }
                        } else {
                            Button("Set Alarm") {
                                alarmManager.setAlarm(for: item, minutesBefore: reminderMinutes)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(modalTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Extensions
extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var startOfWorkWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        let startOfWeek = calendar.date(from: components) ?? self
        let weekday = calendar.component(.weekday, from: startOfWeek)
        let daysFromMonday = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfWeek) ?? startOfWeek
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
}

struct DateFormatters {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Quick Import Extension
extension ScheduleCalendarView {
    func quickImport(fileURL: URL) {
        guard let defaultMapping = importMappingStore.savedMappings.first(where: { $0.isDefault }) else {
            // No default - show wizard
            showImportWizard = true
            return
        }
        
        // Use default mapping
        Task {
            do {
                let content = try String(contentsOf: fileURL)
                let result = ICalendarImportEngine.importCalendar(
                    icsContent: content,
                    using: defaultMapping
                )
                
                // Save trips
                for trip in result.createdTrips {
                    logbookStore.saveTrip(trip)
                }
                
                // Show success message
                await MainActor.run {
                    showSuccessAlert(result)
                }
            } catch {
                // Show error message
                await MainActor.run {
                    showErrorAlert(error)
                }
            }
        }
    }
    
    private func showSuccessAlert(_ result: ImportResult) {
        // You can implement a custom alert or banner here
        print("✅ Import successful: \(result.createdTrips.count) trips created")
    }
    
    private func showErrorAlert(_ error: Error) {
        // You can implement a custom alert or banner here
        print("❌ Import failed: \(error.localizedDescription)")
    }
}

// MARK: - Schedule View Order Editor
struct ScheduleViewOrderEditor: View {
    @ObservedObject var viewPreferences: ScheduleViewPreferenceManager
    @Environment(\.dismiss) private var dismiss
    @State private var editableViews: [ScheduleViewType]
    
    init(viewPreferences: ScheduleViewPreferenceManager) {
        self.viewPreferences = viewPreferences
        _editableViews = State(initialValue: viewPreferences.orderedViews)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with instructions
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Drag to Reorder Views")
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.textPrimary)
                    }
                    .padding(.top, 12)
                    
                    Text("Your favorite view will appear first when you open the Schedule tab")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                .background(LogbookTheme.fieldBackground)
                
                // Reorderable list
                List {
                    ForEach(editableViews) { viewType in
                        HStack(spacing: 12) {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                                .font(.title3)
                            
                            // View icon
                            Image(systemName: viewType.icon)
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 24)
                            
                            // View name and description
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewType.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(LogbookTheme.textPrimary)
                                
                                Text(viewType.description)
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Position indicator
                            if let index = editableViews.firstIndex(of: viewType) {
                                Text("#\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(index == 0 ? LogbookTheme.accentGreen : LogbookTheme.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(index == 0 ? LogbookTheme.accentGreen.opacity(0.2) : LogbookTheme.fieldBackground)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(LogbookTheme.cardBackground)
                    }
                    .onMove { source, destination in
                        editableViews.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
                .background(LogbookTheme.navy)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Customize View Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewPreferences.orderedViews = editableViews
                        dismiss()
                    }
                    .bold()
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        withAnimation {
                            editableViews = Array(ScheduleViewType.allCases)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview
struct ScheduleCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let nocSettings = NOCSettingsStore()
        let scheduleStore = ScheduleStore(settings: nocSettings)
        
        ScheduleCalendarView()
            .environmentObject(nocSettings)
            .environmentObject(scheduleStore)
    }
}

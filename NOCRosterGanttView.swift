//
//  NOCRosterGanttView.swift
//  TheProPilotApp
//
//  A clean, organized view of the NOC roster data
//

import SwiftUI

// MARK: - NOC Roster Gantt View
struct NOCRosterGanttView: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var selectedView: RosterViewType = .yourSchedule
    @State private var showingWebPortal = false
    @State private var currentWeekStart = Date().startOfWeek
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    enum RosterViewType: String, CaseIterable {
        case yourSchedule = "Your Schedule"
        case webPortal = "Full Roster"
        case calendar = "Calendar"
        case list = "List"
        
        var icon: String {
            switch self {
            case .yourSchedule: return "person.crop.square"
            case .webPortal: return "globe"
            case .calendar: return "calendar"
            case .list: return "list.bullet"
            }
        }
    }
    
    // Is iPad or landscape iPhone?
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular || 
        (horizontalSizeClass == .compact && verticalSizeClass == .compact)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // View Type Picker
            viewTypePicker
            
            // Main Content with adaptive layout
            if isWideLayout {
                wideLayoutContent
            } else {
                compactLayoutContent
            }
        }
        .background(LogbookTheme.navy)
        .navigationTitle("NOC Roster")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                syncStatusButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingWebPortal) {
            NOCWebPortalView(settings: nocSettings)
        }
    }
    
    // MARK: - Wide Layout (iPad / Landscape)
    private var wideLayoutContent: some View {
        HStack(spacing: 0) {
            // Left Side: Your Schedule
            VStack(spacing: 0) {
                Text("Your Schedule")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.navyDark)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Week Navigation
                        weekNavigationBar
                        
                        // Your Flights
                        if !upcomingFlights.isEmpty {
                            ForEach(upcomingFlights.prefix(10)) { flight in
                                PersonalFlightCard(flight: flight, isCompact: false)
                                    .padding(.horizontal)
                            }
                        } else {
                            emptyStateView
                        }
                    }
                    .padding(.vertical)
                }
            }
            .frame(maxWidth: .infinity)
            .background(LogbookTheme.navy)
            
            Divider()
                .background(LogbookTheme.accentBlue)
            
            // Right Side: Stats & Quick Actions
            VStack(spacing: 0) {
                Text("Overview")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.navyDark)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Stats
                        statsSection
                        
                        // Quick Actions
                        VStack(spacing: 12) {
                            quickActionButton(
                                title: "View Full Roster",
                                icon: "globe",
                                color: LogbookTheme.accentBlue
                            ) {
                                showingWebPortal = true
                            }
                            
                            quickActionButton(
                                title: "Sync Now",
                                icon: nocSettings.isSyncing ? "arrow.clockwise" : "arrow.triangle.2.circlepath",
                                color: LogbookTheme.accentGreen
                            ) {
                                nocSettings.fetchRosterCalendar()
                            }
                            .disabled(nocSettings.isSyncing)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .frame(maxWidth: .infinity)
            .background(LogbookTheme.navyLight)
        }
    }
    
    // MARK: - Compact Layout (iPhone Portrait)
    private var compactLayoutContent: some View {
        Group {
            switch selectedView {
            case .yourSchedule:
                yourScheduleView
            case .webPortal:
                webPortalButton
            case .calendar:
                calendarView
            case .list:
                listView
            }
        }
    }
    
    // MARK: - Quick Action Button
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(color.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 1)
            )
        }
    }
    
    // MARK: - View Type Picker
    private var viewTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RosterViewType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation {
                            selectedView = type
                            if type == .webPortal {
                                showingWebPortal = true
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedView == type ? LogbookTheme.accentBlue : LogbookTheme.navyLight)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
            .padding()
        }
        .background(LogbookTheme.navyDark)
    }
    
    // MARK: - Your Schedule View (Clean, Personal)
    private var yourScheduleView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Week Navigation
                weekNavigationBar
                
                // Your Flights This Week
                if !upcomingFlights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Flights This Week")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(upcomingFlights.prefix(7)) { flight in
                            PersonalFlightCard(flight: flight)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    emptyStateView
                }
                
                // Quick Stats
                statsSection
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Week Navigation
    private var weekNavigationBar: some View {
        HStack {
            Button(action: { previousWeek() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(weekRangeText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(upcomingFlights.count) flights")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
            
            Spacer()
            
            Button(action: { nextWeek() }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Button("Today") {
                withAnimation {
                    currentWeekStart = Date().startOfWeek
                }
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(LogbookTheme.accentBlue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
    }
    
    // MARK: - Personal Flight Card
    struct PersonalFlightCard: View {
        let flight: BasicScheduleItem
        var isCompact: Bool = true
        
        var body: some View {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                // Date Header
                HStack {
                    Text(flight.date, style: .date)
                        .font(isCompact ? .subheadline.bold() : .headline)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Spacer()
                    
                    Text(flight.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(flight.status.color.opacity(0.2))
                        .foregroundColor(flight.status.color)
                        .cornerRadius(6)
                }
                
                // Flight Info
                if isCompact {
                    compactFlightInfo
                } else {
                    expandedFlightInfo
                }
                
                // Duration
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    Text(durationText(flight))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Spacer()
                    
                    if isToday(flight.date) {
                        Text("TODAY")
                            .font(.caption.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LogbookTheme.accentBlue.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(isCompact ? 12 : 16)
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(flight.status.color.opacity(0.3), lineWidth: 1)
            )
        }
        
        private var compactFlightInfo: some View {
            HStack(spacing: 12) {
                // Flight Number
                VStack(alignment: .leading, spacing: 2) {
                    Text("FLIGHT")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textTertiary)
                    Text(flight.tripNumber)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Route
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.departure)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text(timeFormatter.string(from: flight.blockOut))
                            .font(.caption)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                    
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.arrival)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text(timeFormatter.string(from: flight.blockIn))
                            .font(.caption)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
            }
        }
        
        private var expandedFlightInfo: some View {
            VStack(spacing: 12) {
                // Flight Number
                HStack {
                    Text("FLIGHT")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textTertiary)
                    Text(flight.tripNumber)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Route - Larger for iPad
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(flight.departure)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("DEPART")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textTertiary)
                        Text(timeFormatter.string(from: flight.blockOut))
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Image(systemName: "airplane")
                        .font(.title)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    VStack(spacing: 4) {
                        Text(flight.arrival)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("ARRIVE")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textTertiary)
                        Text(timeFormatter.string(from: flight.blockIn))
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            }
        }
        
        private var timeFormatter: DateFormatter {
            let f = DateFormatter()
            f.timeStyle = .short
            return f
        }
        
        private func durationText(_ flight: BasicScheduleItem) -> String {
            let total = Int(flight.totalBlockTime)
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
        
        private func isToday(_ date: Date) -> Bool {
            Calendar.current.isDateInToday(date)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Flights This Week")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("You have no scheduled flights for this week")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("View Full Roster") {
                showingWebPortal = true
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Total Flights",
                    value: "\(scheduleStore.items.count)",
                    icon: "airplane",
                    color: LogbookTheme.accentBlue
                )
                
                StatCard(
                    title: "Block Hours",
                    value: totalBlockHours,
                    icon: "clock",
                    color: LogbookTheme.accentGreen
                )
                
                StatCard(
                    title: "Days On",
                    value: "\(daysWithFlights)",
                    icon: "calendar",
                    color: LogbookTheme.accentOrange
                )
                
                StatCard(
                    title: "Days Off",
                    value: "\(daysOff)",
                    icon: "moon.zzz",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    struct StatCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Spacer()
                }
                
                Text(value)
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
            .padding()
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Web Portal Button
    private var webPortalButton: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 80))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("Full Crew Roster")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("View the complete crew scheduling roster with all crew members and flights")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingWebPortal = true }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open NOC Web Portal")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.accentBlue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            // Quick Info
            VStack(spacing: 12) {
                InfoRow(icon: "person.3", text: "View all crew schedules")
                InfoRow(icon: "calendar.badge.clock", text: "See scheduling conflicts")
                InfoRow(icon: "chart.bar", text: "Analyze crew utilization")
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    struct InfoRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .frame(width: 30)
                Text(text)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Calendar View
    private var calendarView: some View {
        VStack {
            Text("Calendar View")
                .font(.headline)
                .foregroundColor(.white)
            Text("Coming Soon")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List View
    private var listView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(upcomingFlights) { flight in
                    PersonalFlightCard(flight: flight)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Sync Status Button
    private var syncStatusButton: some View {
        Button(action: {
            if !nocSettings.isSyncing {
                nocSettings.fetchRosterCalendar()
            }
        }) {
            HStack(spacing: 4) {
                if nocSettings.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: syncStatusIcon)
                        .foregroundColor(syncStatusColor)
                }
            }
        }
    }
    
    private var syncStatusIcon: String {
        if nocSettings.syncSuccess {
            return "checkmark.circle.fill"
        } else if nocSettings.fetchError != nil {
            return "exclamationmark.triangle.fill"
        } else {
            return "arrow.clockwise.circle"
        }
    }
    
    private var syncStatusColor: Color {
        if nocSettings.syncSuccess {
            return .green
        } else if nocSettings.fetchError != nil {
            return .red
        } else {
            return .gray
        }
    }
    
    // MARK: - Computed Properties
    private var upcomingFlights: [BasicScheduleItem] {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        
        return scheduleStore.visibleItems.filter { item in
            item.date >= currentWeekStart && item.date < weekEnd
        }.sorted { $0.date < $1.date }
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
        
        return "\(formatter.string(from: currentWeekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    private var totalBlockHours: String {
        let total = scheduleStore.items.reduce(0.0) { $0 + $1.totalBlockTime }
        let hours = Int(total) / 3600
        return "\(hours)"
    }
    
    private var daysWithFlights: Int {
        let uniqueDates = Set(scheduleStore.items.map {
            Calendar.current.startOfDay(for: $0.date)
        })
        return uniqueDates.count
    }
    
    private var daysOff: Int {
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return daysInMonth - daysWithFlights
    }
    
    // MARK: - Helper Methods
    private func previousWeek() {
        withAnimation {
            currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
        }
    }
    
    private func nextWeek() {
        withAnimation {
            currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
        }
    }
}

// MARK: - Preview
struct NOCRosterGanttView_Previews: PreviewProvider {
    static var previews: some View {
        let nocSettings = NOCSettingsStore()
        let scheduleStore = ScheduleStore(settings: nocSettings)
        NOCRosterGanttView(nocSettings: nocSettings, scheduleStore: scheduleStore)
    }
}

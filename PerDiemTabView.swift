// ===== PerDiemSummaryView.swift - Enhanced with Collapsible Sections + Period Details View =====
import SwiftUI

struct PerDiemTabView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @StateObject private var airlineSettings = AirlineSettingsStore()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var rateFieldFocused: Bool
    @State private var showingPortalInfo = false
    @State private var selectedPeriodForPortal: MonthlyPerDiemPortion?
    @State private var showingRateSettings = false
    
    // Collapsible section state
    @State private var expandedMonths: Set<String> = []
    
    // View mode toggle
    @State private var viewMode: PerDiemViewMode = .summary
    
    // Sort order for Period Details view
    @State private var sortNewestFirst: Bool = true
    
    enum PerDiemViewMode: String, CaseIterable {
        case summary = "Summary"
        case periodDetails = "Period Details"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Airline Configuration Header
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(airlineSettings.settings.airlineName)")
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Text("Home Base: \(airlineSettings.settings.homeBaseAirport)")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }

                            Spacer()
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)

                    // Current Per Diem Status (if away from home)
                    if let currentPeriod = getCurrentPerDiemPeriod(trips: store.trips, homeBase: airlineSettings.settings.homeBaseAirport) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "airplane.departure")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .font(.title)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CURRENTLY AWAY FROM \(airlineSettings.settings.homeBaseAirport)")
                                        .font(.headline.bold())
                                        .foregroundColor(LogbookTheme.accentGreen)
                                    Text("Ongoing per diem period")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Text("\(currentPeriod.trips.count) trips in period")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }

                            // Current totals
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text(formatPerDiemDuration(currentPeriod.minutes))
                                        .font(.title.bold())
                                        .foregroundColor(.white)
                                    Text("Time Away")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                VStack {
                                    Text("•")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                }

                                VStack(spacing: 4) {
                                    Text("$\(String(format: "%.2f", Double(currentPeriod.minutes) / 60.0 * store.perDiemRate))")
                                        .font(.title.bold())
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    Text("Per Diem Earned")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }

                            // Portal entry info for current period
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Company Portal Entry:")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                Text(currentPeriod.portalEntryString)
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .textSelection(.enabled)
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [LogbookTheme.accentGreen.opacity(0.2), LogbookTheme.accentBlue.opacity(0.1)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(LogbookTheme.accentGreen, lineWidth: 2)
                        )
                        .cornerRadius(16)
                    }

                    // View Mode Picker
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(PerDiemViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Display either Summary or Period Details view
                    if viewMode == .summary {
                        monthlySummaryView
                    } else {
                        periodDetailsView
                    }

                    // How Per Diem Works Explanation
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("How Per Diem Works")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Per diem starts at block out when departing from \(airlineSettings.settings.homeBaseAirport)")
                            Text("• Continues through ALL trips until you return to \(airlineSettings.settings.homeBaseAirport)")
                            Text("• Multiple trips away from home = one continuous per diem period")
                            Text("• Cross-month periods are split for accurate monthly totals")
                            Text("• Tap any period for company portal entry information")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight.opacity(0.5))
                    .cornerRadius(12)

                    // Empty state
                    let monthlyData = calculateMonthlyPerDiem()
                    if monthlyData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No Per Diem Data")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("Per diem will appear here when you add trips with time away from \(airlineSettings.settings.homeBaseAirport)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Time Away")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRateSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { rateFieldFocused = false }
                }
            }
        }
        .onAppear {
            if store.perDiemRate == 0 { store.perDiemRate = 2.50 }
            // Auto-expand current month on first load
            let monthlyData = calculateMonthlyPerDiem()
            if let currentMonth = monthlyData.first?.0 {
                expandedMonths.insert(currentMonth)
            }
        }
        .sheet(isPresented: $showingRateSettings) {
            PerDiemRateSettingsSheet(store: store, airlineSettings: airlineSettings)
        }
        .sheet(isPresented: $showingPortalInfo) {
            if let period = selectedPeriodForPortal {
                PortalEntryInfoSheet(portion: period, rate: store.perDiemRate)
            }
        }
    }
    
    // MARK: - Monthly Summary View (Collapsible)
    private var monthlySummaryView: some View {
        Group {
            let monthlyData = calculateMonthlyPerDiem()
            let sortedMonthlyData = sortNewestFirst ? monthlyData : monthlyData.reversed()
            
            // BY MONTH Header with sort toggle
            if !monthlyData.isEmpty {
                VStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            if expandedMonths.isEmpty {
                                // Expand all
                                expandedMonths = Set(monthlyData.map { $0.0 })
                            } else {
                                // Collapse all
                                expandedMonths.removeAll()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: expandedMonths.isEmpty ? "chevron.right" : "chevron.down")
                                .foregroundColor(LogbookTheme.textSecondary)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 20)
                            
                            Text("BY MONTH")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(LogbookTheme.textSecondary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(LogbookTheme.cardBackground)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Sort toggle
                    HStack {
                        Text("Sort Order:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                sortNewestFirst.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: sortNewestFirst ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                Text(sortNewestFirst ? "Newest First" : "Oldest First")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LogbookTheme.accentBlue.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LogbookTheme.cardBackground.opacity(0.5))
                    .cornerRadius(8)
                }
            }
            
            ForEach(sortedMonthlyData, id: \.0) { monthData in
                let month = monthData.0
                let portions = monthData.1
                let totalMinutes = portions.reduce(0) { $0 + $1.minutes }
                let totalDollars = portions.reduce(0) { $0 + $1.perDiemAmount(rate: store.perDiemRate) }

                if totalMinutes > 0 {
                    VStack(alignment: .leading, spacing: 0) {
                        // Collapsible Month Header
                        Button(action: {
                            withAnimation {
                                if expandedMonths.contains(month) {
                                    expandedMonths.remove(month)
                                } else {
                                    expandedMonths.insert(month)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: expandedMonths.contains(month) ? "chevron.down" : "chevron.right")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 20)
                                
                                Text(month)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Text(formatPerDiemDuration(totalMinutes))
                                        .font(.system(size: 12))
                                        .foregroundColor(LogbookTheme.textSecondary)
                                    
                                    Text("$\(String(format: "%.2f", totalDollars))")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(LogbookTheme.cardBackground)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Collapsible Content
                        if expandedMonths.contains(month) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Month Total Detail
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Time Away from \(airlineSettings.settings.homeBaseAirport)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(formatPerDiemDuration(totalMinutes))
                                            .font(.title3.bold())
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Total Earned")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("$\(String(format: "%.2f", totalDollars))")
                                            .font(.title3.bold())
                                            .foregroundColor(LogbookTheme.accentBlue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                                // Individual Per Diem Periods/Portions
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Per Diem Periods:")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                    
                                    ForEach(portions.indices, id: \.self) { index in
                                        let portion = portions[index]

                                        Button(action: {
                                            selectedPeriodForPortal = portion
                                            showingPortalInfo = true
                                        }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(formatFullDateTimeRange(start: portion.portionStartDate, end: portion.portionEndDate))
                                                    .font(.caption.bold())
                                                    .foregroundColor(LogbookTheme.accentGreen)
                                                
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("\(portion.trips.count) trip\(portion.trips.count == 1 ? "" : "s")")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray)
                                                        
                                                        // Status indicators
                                                        HStack(spacing: 8) {
                                                            if portion.originalPeriod.isOngoing {
                                                                Text("• ONGOING")
                                                                    .font(.caption2.bold())
                                                                    .foregroundColor(LogbookTheme.accentGreen)
                                                            }
                                                            
                                                            if portion.portionStartDate != portion.originalPeriod.startTime ||
                                                               portion.portionEndDate != (portion.originalPeriod.endTime ?? Date()) {
                                                                Text("• Part of longer period")
                                                                    .font(.caption2)
                                                                    .foregroundColor(LogbookTheme.accentBlue.opacity(0.8))
                                                            }
                                                        }
                                                        
                                                        Text("Tap for portal entry info")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray.opacity(0.8))
                                                            .italic()
                                                    }
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        Text(portion.formattedDuration)
                                                            .font(.caption.bold())
                                                            .foregroundColor(LogbookTheme.accentGreen)
                                                        Text("$\(String(format: "%.2f", portion.perDiemAmount(rate: store.perDiemRate)))")
                                                            .font(.caption)
                                                            .foregroundColor(LogbookTheme.accentBlue)
                                                        
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(LogbookTheme.navy.opacity(0.3))
                                        .cornerRadius(8)
                                    }
                                    .padding(.horizontal, 12)
                                }
                                .padding(.bottom, 12)
                            }
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(12)
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Period Details View (Shows Block Out/In Times)
    private var periodDetailsView: some View {
        Group {
            let allPeriods = calculatePerDiemPeriods(trips: store.trips, homeBase: airlineSettings.settings.homeBaseAirport)
            let sortedPeriods = sortNewestFirst ? allPeriods.sorted { $0.startTime > $1.startTime } : allPeriods.sorted { $0.startTime < $1.startTime }
            
            // Sort toggle button
            HStack {
                Text("Sort Order:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        sortNewestFirst.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: sortNewestFirst ? "arrow.down" : "arrow.up")
                            .font(.caption)
                        Text(sortNewestFirst ? "Newest First" : "Oldest First")
                            .font(.caption.bold())
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LogbookTheme.accentBlue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(LogbookTheme.navyLight)
            .cornerRadius(8)
            
            ForEach(sortedPeriods, id: \.startTime) { period in
                Button(action: {
                    // Find the monthly portion for this period to show portal info
                    let monthlyData = calculateMonthlyPerDiem()
                    for (_, portions) in monthlyData {
                        if let portion = portions.first(where: { $0.originalPeriod.startTime == period.startTime }) {
                            selectedPeriodForPortal = portion
                            showingPortalInfo = true
                            break
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Period Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(period.trips.count) Trip\(period.trips.count == 1 ? "" : "s")")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if period.isOngoing {
                                    HStack(spacing: 4) {
                                        Image(systemName: "record.circle")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                        Text("ONGOING")
                                            .font(.caption.bold())
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatPerDiemDuration(period.minutes))
                                    .font(.title3.bold())
                                    .foregroundColor(LogbookTheme.accentGreen)
                                Text("$\(String(format: "%.2f", Double(period.minutes) / 60.0 * store.perDiemRate))")
                                    .font(.title3.bold())
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                        
                        Divider()
                            .background(.gray)
                        
                        // Block Out (Start)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BLOCK OUT (Per Diem Start)")
                                .font(.caption.bold())
                                .foregroundColor(LogbookTheme.accentGreen)
                            
                            HStack {
                                Image(systemName: "airplane.departure")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(period.startTime))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(formatTime(period.startTime))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text(period.trips.first?.legs.first?.departure ?? "")
                                    .font(.caption.bold())
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.accentGreen.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Block In (End)
                        if let endTime = period.endTime {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BLOCK IN (Per Diem End)")
                                    .font(.caption.bold())
                                    .foregroundColor(LogbookTheme.accentBlue)
                                
                                HStack {
                                    Image(systemName: "airplane.arrival")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(endTime))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Text(formatTime(endTime))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(period.trips.last?.legs.last?.arrival ?? "")
                                        .font(.caption.bold())
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                            }
                            .padding()
                            .background(LogbookTheme.accentBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Trip List
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trips in Period:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            
                            ForEach(period.trips) { trip in
                                HStack {
                                    Text("Trip #\(trip.tripNumber)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    // Clean route display
                                    if let firstLeg = trip.legs.first, let lastLeg = trip.legs.last {
                                        if trip.legs.count == 1 {
                                            Text("\(firstLeg.departure) → \(firstLeg.arrival)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(firstLeg.departure) → \(lastLeg.arrival)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                        
                        // Tap hint
                        HStack {
                            Spacer()
                            Text("Tap for portal entry info")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.8))
                                .italic()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Functions
    private func calculateMonthlyPerDiem() -> [(String, [MonthlyPerDiemPortion])] {
        let periods = calculatePerDiemPeriods(trips: store.trips, homeBase: airlineSettings.settings.homeBaseAirport)
        return groupPeriodsByMonthEnhanced(periods: periods)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date) + "Z"
    }
    
    private func formatFullDateTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        formatter.dateFormat = "MMM d HH:mm"
        let startString = formatter.string(from: start) + "Z"
        
        let endString: String
        let calendar = Calendar.current
        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        
        if startMonth == endMonth && startDay == endDay {
            formatter.dateFormat = "HH:mm"
            endString = formatter.string(from: end) + "Z"
        } else {
            formatter.dateFormat = "MMM d HH:mm"
            endString = formatter.string(from: end) + "Z"
        }
        
        return "\(startString) → \(endString)"
    }
}

// MARK: - Per Diem Rate Settings View
struct PerDiemRateSettingsSheet: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var rateFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header Info
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text("Per Diem Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Set your hourly per diem rate")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top)
                
                // Rate Editor
                VStack(alignment: .leading, spacing: 12) {
                    Text("Per Diem Rate")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        TextField(
                            "2.50",
                            value: $store.perDiemRate,
                            format: .number.precision(.fractionLength(2))
                        )
                        .font(.title2)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .focused($rateFieldFocused)
                    }
                    
                    Text("per hour away from \(airlineSettings.settings.homeBaseAirport)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                
                // Quick presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Presets")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        ForEach([2.00, 2.50, 3.00, 3.50], id: \.self) { rate in
                            Button(action: {
                                store.perDiemRate = rate
                            }) {
                                Text("$\(String(format: "%.2f", rate))")
                                    .font(.subheadline)
                                    .foregroundColor(store.perDiemRate == rate ? .white : LogbookTheme.accentBlue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(store.perDiemRate == rate ? LogbookTheme.accentBlue : LogbookTheme.navyLight)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight.opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { rateFieldFocused = false }
                }
            }
        }
    }
}

// MARK: - Portal Entry Info View
struct PortalEntryInfoSheet: View {
    let portion: MonthlyPerDiemPortion
    let rate: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Computed property to detect landscape
    private var isLandscape: Bool {
        verticalSizeClass == .compact || horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLandscape {
                    landscapeView
                } else {
                    portraitView
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Portal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    // MARK: - Portrait View (Original)
    private var portraitView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Company Portal Entry")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Copy the information below to enter into your company's per diem system")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    // Period Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Period Summary")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Duration:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(portion.formattedDuration)
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                Text("Amount:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("$\(String(format: "%.2f", portion.perDiemAmount(rate: rate)))")
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                            
                            HStack {
                                Text("Trips:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(portion.trips.count)")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Portal Entry String
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portal Entry String")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start Date:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(portion.portionStartDateForPortal)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(LogbookTheme.accentGreen)
                                .textSelection(.enabled)
                            
                            Text("Start Time:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(portion.portionStartTimeForPortal)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(LogbookTheme.accentGreen)
                                .textSelection(.enabled)
                            
                            if !portion.originalPeriod.isOngoing || portion.portionEndDate < Date() {
                                Text("End Date:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(portion.portionEndDateForPortal)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .textSelection(.enabled)
                                
                                Text("End Time:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(portion.portionEndTimeForPortal)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .textSelection(.enabled)
                            } else {
                                Text("Status:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("ONGOING")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                        
                        Divider()
                            .background(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Complete Entry String:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            
                            Text(portion.portionPortalEntryString)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(LogbookTheme.accentBlue)
                                .padding()
                                .background(LogbookTheme.navy)
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Trip Details (NEW)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trips in Period")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(portion.trips.sorted(by: { $0.date < $1.date })) { trip in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        Text(formatTripDetailLine(trip))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(LogbookTheme.accentBlue)
                                            .padding(.vertical, 4)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .padding()
                            .background(LogbookTheme.navy)
                            .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    if portion.portionStartDate != portion.originalPeriod.startTime ||
                       portion.portionEndDate != (portion.originalPeriod.endTime ?? Date()) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                Text("Cross-Month Period")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("This is part of a longer per diem period that spans multiple months. The dates and times shown above represent only the portion that falls within this month.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight.opacity(0.5))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Landscape View (Optimized for copying text)
    private var landscapeView: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                // Left column - Summary
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Period Summary")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 6) {
                            HStack {
                                Text("Duration:")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Spacer()
                                Text(portion.formattedDuration)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Amount:")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Spacer()
                                Text("$\(String(format: "%.2f", portion.perDiemAmount(rate: rate)))")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Trips:")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Spacer()
                                Text("\(portion.trips.count)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .frame(maxWidth: 250)
                    
                    if portion.portionStartDate != portion.originalPeriod.startTime ||
                       portion.portionEndDate != (portion.originalPeriod.endTime ?? Date()) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.caption)
                                Text("Cross-Month Period")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            
                            Text("This is part of a longer period spanning multiple months.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight.opacity(0.5))
                        .cornerRadius(12)
                        .frame(maxWidth: 250)
                    }
                }
                
                // Right column - Portal Entry Data (wider for copying)
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portal Entry String")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Start Date:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 80, alignment: .leading)
                                Text(portion.portionStartDateForPortal)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .textSelection(.enabled)
                            }
                            
                            HStack {
                                Text("Start Time:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 80, alignment: .leading)
                                Text(portion.portionStartTimeForPortal)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .textSelection(.enabled)
                            }
                            
                            if !portion.originalPeriod.isOngoing || portion.portionEndDate < Date() {
                                HStack {
                                    Text("End Date:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(width: 80, alignment: .leading)
                                    Text(portion.portionEndDateForPortal)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .textSelection(.enabled)
                                }
                                
                                HStack {
                                    Text("End Time:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(width: 80, alignment: .leading)
                                    Text(portion.portionEndTimeForPortal)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .textSelection(.enabled)
                                }
                            } else {
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(width: 80, alignment: .leading)
                                    Text("ONGOING")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Trip Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trips in Period")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(portion.trips.sorted(by: { $0.date < $1.date })) { trip in
                                    Text(formatTripDetailLine(trip))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .textSelection(.enabled)
                                        .lineLimit(1)
                                }
                            }
                            .padding()
                        }
                        .background(LogbookTheme.navy)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper to format trip detail line
    private func formatTripDetailLine(_ trip: Trip) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateStr = dateFormatter.string(from: trip.date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        timeFormatter.timeZone = TimeZone(identifier: "UTC")
        
        // Build airport string with all legs
        var airports: [String] = []
        if let firstLeg = trip.legs.first {
            airports.append(firstLeg.departure)
        }
        for leg in trip.legs {
            airports.append(leg.arrival)
        }
        let airportStr = airports.joined(separator: "-")
        
        // Get first out time and last in time from the legs
        var timeStr = ""
        if let firstLeg = trip.legs.first,
           !firstLeg.outTime.isEmpty {
            // outTime is likely a string in HHMM format
            let outTime = firstLeg.outTime
            timeStr = "\(outTime)Z"
            
            if let lastLeg = trip.legs.last,
               !lastLeg.inTime.isEmpty {
                let inTime = lastLeg.inTime
                timeStr += "-\(inTime)Z"
            }
        }
        
        return "\(dateStr) | Trip #\(trip.tripNumber) | \(airportStr) | \(timeStr)"
    }
}


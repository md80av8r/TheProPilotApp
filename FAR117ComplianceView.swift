import SwiftUI
import Charts

enum ChartMode: String, CaseIterable {
    case timeline = "Total & Trend"
    case netActivity = "Daily Credit/Debit"
    case gantt = "Trip Timeline"
}

struct FAR121ComplianceView: View {
    @EnvironmentObject var logbookStore: LogBookStore
    
    @State private var chartData: [DayFlightData] = []
    @State private var selectedTimeframe: TimeframeOption = .standard
    @State private var forecastDays: Int = 7  // User can choose 7 or 14 days
    @State private var chartMode: ChartMode = .timeline
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Status Cards
                statusCardsSection
                
                // MARK: - NEW: Flight Capacity Forecast
                capacityForecastSection
                
                // MARK: - Chart Section
                chartSection
                
                // MARK: - Key Dates
                keyDatesSection
                
                // MARK: - All Limits Reference
                allLimitsSection
            }
            .padding()
        }
        .navigationTitle("FAR Part 121 Compliance")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            calculateChartData()
        }
    }
    
    // MARK: - NEW: Capacity Forecast Section
    private var capacityForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Flight Capacity Forecast")
                    .font(.headline)
                
                Spacer()
                
                Picker("Days", selection: $forecastDays) {
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            Text("How many hours you can fly on each upcoming day")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(getForecastData(), id: \.date) { forecast in
                    ForecastDayRow(forecast: forecast)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Status Cards Section
    private var statusCardsSection: some View {
        VStack(spacing: 12) {
            // Primary: 28-Day Limit
            StatusCard(
                title: "Rolling 30-Day Block Time",
                current: currentRolling30DayTotal,
                limit: 100,
                unit: "hrs",
                status: rolling30Status,
                icon: "airplane.circle.fill"
            )
            
            // Secondary Cards in a row
            HStack(spacing: 12) {
                CompactStatusCard(
                    title: "7-Day",
                    current: rolling7DayTotal,
                    limit: 60,
                    status: rolling7Status
                )
                
                CompactStatusCard(
                    title: "365-Day",
                    current: rolling365DayTotal,
                    limit: 1000,
                    status: rolling365Status
                )
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Flight Analysis")
                    .font(.headline)
                Spacer()
            }
            
            // Timeframe Picker
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeframeOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeframe) { oldValue, newValue in
                calculateChartData()
            }
            
            // NEW: Chart Mode Picker
            Picker("Chart Mode", selection: $chartMode) {
                ForEach(ChartMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Chart Switcher with Dynamic Height
            Group {
                switch chartMode {
                case .timeline:
                    StandardTimelineChart(chartData: chartData, timeframe: selectedTimeframe)
                case .netActivity:
                    NetActivityChart(chartData: chartData, timeframe: selectedTimeframe)
                case .gantt:
                    TripTimelineGanttChart(logbookStore: logbookStore)
                }
            }
            .frame(height: chartMode == .gantt ? 500 : 350)  // Taller for Gantt
            
            // Dynamic Legend based on Chart Mode
            if chartMode == .timeline {
                // Timeline Legend
                HStack(spacing: 20) {
                    LegendItem(color: .blue, label: "Daily Hours")
                    LegendItem(color: .blue.opacity(0.3), label: "Projected")
                    LegendItem(color: .orange, label: "30-Day Rolling Total")
                }
                .font(.caption)
                .padding(.top, 8)
                
            } else if chartMode == .netActivity {
                // Net Activity Legend
                HStack(spacing: 12) {
                    LegendItem(color: .blue, label: "Flown (Debit)")
                    LegendItem(color: .red.opacity(0.5), label: "Restored (Credit)")
                    LegendItem(color: .green, label: "Capacity Left")
                }
                .font(.caption)
                .padding(.top, 8)
                
            } else if chartMode == .gantt {
                // Gantt Chart Legend
                HStack(spacing: 12) {
                    LegendItem(color: .green, label: "Fresh (>20d)")
                    LegendItem(color: .yellow, label: "Mid (10-20d)")
                    LegendItem(color: .orange, label: "Soon (<10d)")
                    LegendItem(color: .red, label: "Critical (<3d)")
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Key Dates Section
    private var keyDatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Dates")
                .font(.headline)
            
            if upcomingMilestones.isEmpty {
                Text("You're in good standing! No critical dates approaching.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                    )
            } else {
                ForEach(upcomingMilestones, id: \.date) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }
        }
    }
    
    // MARK: - All Limits Reference
    private var allLimitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All FAR 121 Flight Time Limits")
                .font(.headline)
            
            VStack(spacing: 8) {
                LimitReferenceRow(period: "30 consecutive days", limit: "100 hours")
                LimitReferenceRow(period: "7 consecutive days", limit: "60 hours")
                LimitReferenceRow(period: "365 consecutive days", limit: "1,000 hours")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - NEW: Forecast Data Calculation
    private func getForecastData() -> [DayForecast] {
        let calendar = Calendar.current
        let today = Date()
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        
        var forecasts: [DayForecast] = []
        
        for dayOffset in 0..<forecastDays {
            guard let forecastDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            // Calculate rolling 30-day total as of that future date
            let rolling30Total = calculate30DayTotal(upToDate: forecastDate, trips: operatingTrips)
            
            // Calculate available capacity
            let availableHours = max(0, 100 - rolling30Total)
            
            // Check if there are any scheduled trips on this day
            let scheduledHours = blockHoursForDate(forecastDate, trips: operatingTrips.filter { $0.status == .planning || $0.status == .active })
            
            // Determine capacity status
            let capacityStatus: CapacityStatus
            if availableHours >= 15 {
                capacityStatus = .excellent
            } else if availableHours >= 10 {
                capacityStatus = .good
            } else if availableHours >= 5 {
                capacityStatus = .limited
            } else {
                capacityStatus = .minimal
            }
            
            // Determine day label
            let dayLabel: String
            if dayOffset == 0 {
                dayLabel = "Today"
            } else if dayOffset == 1 {
                dayLabel = "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                dayLabel = formatter.string(from: forecastDate)
            }
            
            forecasts.append(DayForecast(
                date: forecastDate,
                dayLabel: dayLabel,
                rolling30Total: rolling30Total,
                availableHours: availableHours,
                scheduledHours: scheduledHours,
                capacityStatus: capacityStatus
            ))
        }
        
        return forecasts
    }
    
    // MARK: - Calculations
    private func calculateChartData() {
        let calendar = Calendar.current
        let today = Date()
        
        let startDate = calendar.date(byAdding: .day, value: selectedTimeframe.lookbackDays, to: today)!
        let endDate = calendar.date(byAdding: .day, value: selectedTimeframe.lookforwardDays, to: today)!
        
        var data: [DayFlightData] = []
        var currentDate = startDate
        
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        
        while currentDate <= endDate {
            let isFuture = currentDate > today
            
            // 1. Hours flown ON this date
            let dailyHours = blockHoursForDate(currentDate, trips: operatingTrips)
            
            // 2. Rolling 30-day total as of this date
            let rolling30DayTotal = calculate30DayTotal(upToDate: currentDate, trips: operatingTrips)
            
            // 3. Hours Dropping Off (what was flown exactly 30 days ago)
            let dropOffDate = calendar.date(byAdding: .day, value: -30, to: currentDate)!
            let hoursDroppingOff = blockHoursForDate(dropOffDate, trips: operatingTrips)
            
            // 4. Available Capacity
            let available = max(0, 100.0 - rolling30DayTotal)
            
            data.append(DayFlightData(
                date: currentDate,
                dailyHours: dailyHours,
                rolling30DayTotal: rolling30DayTotal,
                hoursDroppingOff: hoursDroppingOff,
                availableHours: available,
                isFuture: isFuture
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        self.chartData = data
    }
    
    private func blockHoursForDate(_ date: Date, trips: [Trip]) -> Double {
        let calendar = Calendar.current
        return trips
            .filter { trip in
                // Check if the trip date matches the target date
                calendar.isDate(trip.date, inSameDayAs: date)
            }
            .reduce(into: 0.0) { sum, trip in
                sum += Double(trip.totalBlockMinutes) / 60.0
            }
    }
    
    private func calculate30DayTotal(upToDate targetDate: Date, trips: [Trip]) -> Double {
        let calendar = Calendar.current
        
        // Calculate the start of the 30-day window (30 days before targetDate)
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: targetDate) else {
            return 0.0
        }
        
        // Sum block time for trips within this 30-day window
        return trips
            .filter { trip in
                trip.date >= startDate && trip.date <= targetDate
            }
            .reduce(into: 0.0) { sum, trip in
                sum += Double(trip.totalBlockMinutes) / 60.0
            }
    }
    
    private func calculate7DayTotal(upToDate targetDate: Date, trips: [Trip]) -> Double {
        let calendar = Calendar.current
        
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: targetDate) else {
            return 0.0
        }
        
        return trips
            .filter { trip in
                trip.date >= startDate && trip.date <= targetDate
            }
            .reduce(into: 0.0) { sum, trip in
                sum += Double(trip.totalBlockMinutes) / 60.0
            }
    }
    
    private func calculate365DayTotal(upToDate targetDate: Date, trips: [Trip]) -> Double {
        let calendar = Calendar.current
        
        guard let startDate = calendar.date(byAdding: .day, value: -364, to: targetDate) else {
            return 0.0
        }
        
        return trips
            .filter { trip in
                trip.date >= startDate && trip.date <= targetDate
            }
            .reduce(into: 0.0) { sum, trip in
                sum += Double(trip.totalBlockMinutes) / 60.0
            }
    }
    
    // MARK: - Computed Properties
    
    private var currentRolling30DayTotal: Double {
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        return calculate30DayTotal(upToDate: Date(), trips: operatingTrips)
    }
    
    private var rolling7DayTotal: Double {
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        return calculate7DayTotal(upToDate: Date(), trips: operatingTrips)
    }
    
    private var rolling365DayTotal: Double {
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        return calculate365DayTotal(upToDate: Date(), trips: operatingTrips)
    }
    
    private var rolling30Status: ComplianceStatus {
        let percentage = (currentRolling30DayTotal / 100.0)
        if percentage >= 0.95 { return .critical }
        if percentage >= 0.85 { return .warning }
        if percentage >= 0.70 { return .caution }
        return .safe
    }
    
    private var rolling7Status: ComplianceStatus {
        let percentage = (rolling7DayTotal / 60.0)
        if percentage >= 0.95 { return .critical }
        if percentage >= 0.85 { return .warning }
        if percentage >= 0.70 { return .caution }
        return .safe
    }
    
    private var rolling365Status: ComplianceStatus {
        let percentage = (rolling365DayTotal / 1000.0)
        if percentage >= 0.95 { return .critical }
        if percentage >= 0.85 { return .warning }
        if percentage >= 0.70 { return .caution }
        return .safe
    }
    
    private var upcomingMilestones: [Milestone] {
        var milestones: [Milestone] = []
        let calendar = Calendar.current
        let today = Date()
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        
        // Check next 14 days for potential limit breaches
        for dayOffset in 1...14 {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let rolling30 = calculate30DayTotal(upToDate: checkDate, trips: operatingTrips)
            
            // If approaching 30-day limit
            if rolling30 >= 90 && rolling30 < 100 {
                milestones.append(Milestone(
                    date: checkDate,
                    title: "Approaching 30-day limit",
                    hoursText: String(format: "%.1f hrs", rolling30),
                    color: .orange,
                    icon: "exclamationmark.triangle.fill"
                ))
            }
        }
        
        return milestones
    }
}

// MARK: - Forecast Day Row Component
struct ForecastDayRow: View {
    let forecast: DayForecast
    
    var body: some View {
        HStack(spacing: 12) {
            // Date label
            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.dayLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if forecast.scheduledHours > 0 {
                    Text("Scheduled: \(String(format: "%.1f", forecast.scheduledHours)) hrs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Visual capacity bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background (total capacity)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 24)
                    
                    // Used capacity (from rolling total)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(forecast.rolling30Total / 100.0), height: 24)
                    
                    // Available capacity overlay
                    RoundedRectangle(cornerRadius: 4)
                        .fill(forecast.capacityStatus.color)
                        .frame(width: geometry.size.width * CGFloat(forecast.availableHours / 100.0), height: 24)
                        .offset(x: geometry.size.width * CGFloat(forecast.rolling30Total / 100.0))
                    
                    // Hours text centered
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f hrs available", forecast.availableHours))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            .frame(height: 24)
            
            // Status icon
            Image(systemName: forecast.capacityStatus.icon)
                .foregroundColor(forecast.capacityStatus.color)
                .frame(width: 20)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Supporting View Components

struct StatusCard: View {
    let title: String
    let current: Double
    let limit: Double
    let unit: String
    let status: ComplianceStatus
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text(status.text)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(status.color)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", current))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(status.color)
                
                Text("/ \(Int(limit)) \(unit)")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(status.color)
                        .frame(width: geometry.size.width * CGFloat(min(current / limit, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(String(format: "%.1f", limit - current)) \(unit) available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct CompactStatusCard: View {
    let title: String
    let current: Double
    let limit: Double
    let status: ComplianceStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", current))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(status.color)
                
                Text("/\(Int(limit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(status.color)
                        .frame(width: geometry.size.width * CGFloat(min(current / limit, 1.0)))
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1)
        )
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    
    var body: some View {
        HStack {
            Image(systemName: milestone.icon)
                .foregroundColor(milestone.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(milestone.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(milestone.hoursText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(milestone.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(milestone.color.opacity(0.1))
                .cornerRadius(6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct LimitReferenceRow: View {
    let period: String
    let limit: String
    
    var body: some View {
        HStack {
            Text(period)
                .font(.subheadline)
            Spacer()
            Text(limit)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
        }
    }
}

// MARK: - Supporting Types

struct DayFlightData: Identifiable {
    let id = UUID()
    let date: Date
    let dailyHours: Double
    let rolling30DayTotal: Double
    let hoursDroppingOff: Double      // NEW
    let availableHours: Double        // NEW
    let isFuture: Bool
}

// NEW: Forecast data structure
struct DayForecast {
    let date: Date
    let dayLabel: String
    let rolling30Total: Double
    let availableHours: Double
    let scheduledHours: Double
    let capacityStatus: CapacityStatus
}

// NEW: Capacity status enum
enum CapacityStatus {
    case excellent, good, limited, minimal
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .minimal: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .limited: return "exclamationmark.triangle"
        case .minimal: return "xmark.circle"
        }
    }
}

struct Milestone {
    let date: Date
    let title: String
    let hoursText: String
    let color: Color
    let icon: String
}

enum ComplianceStatus {
    case safe, caution, warning, critical
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var text: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

enum TimeframeOption: String, CaseIterable {
    case compact = "14 Days"
    case standard = "30 Days"
    case extended = "45 Days"
    
    var lookbackDays: Int {
        switch self {
        case .compact: return -14
        case .standard: return -30
        case .extended: return -38
        }
    }
    
    var lookforwardDays: Int {
        switch self {
        case .compact: return 7
        case .standard: return 14
        case .extended: return 21
        }
    }
    
    var xAxisStride: Int {
        switch self {
        case .compact: return 3
        case .standard: return 7
        case .extended: return 7
        }
    }
}

// MARK: - Preview
struct FAR121ComplianceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FAR121ComplianceView()
                .environmentObject(LogBookStore())
        }
    }
}

// ADD THESE TWO NEW STRUCTS after your main FAR121ComplianceView struct (before the other supporting views)

// MARK: - Standard Timeline Chart (Original)
struct StandardTimelineChart: View {
    let chartData: [DayFlightData]
    let timeframe: TimeframeOption
    
    var body: some View {
        Chart {
            ForEach(chartData) { dayData in
                BarMark(
                    x: .value("Date", dayData.date),
                    y: .value("Hours", dayData.dailyHours)
                )
                .foregroundStyle(dayData.isFuture ? Color.blue.opacity(0.3) : Color.blue)
            }
            
            ForEach(chartData) { dayData in
                LineMark(
                    x: .value("Date", dayData.date),
                    y: .value("Rolling Total", dayData.rolling30DayTotal)
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", dayData.date),
                    y: .value("Rolling Total", dayData.rolling30DayTotal)
                )
                .foregroundStyle(Color.orange)
                .symbolSize(40)
            }
            
            RuleMark(y: .value("Limit", 100))
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("100 hr limit")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(4)
                        .background(Color(.systemBackground))
                }
            
            RuleMark(y: .value("Warning", 90))
                .foregroundStyle(Color.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: timeframe.xAxisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(domain: 0...110)
    }
}

// MARK: - NEW: Net Activity Chart (Shows Credits/Debits)
struct NetActivityChart: View {
    let chartData: [DayFlightData]
    let timeframe: TimeframeOption
    
    var body: some View {
        Chart {
            ForEach(chartData) { day in
                // 1. Positive Bar (Debit): Flown
                if day.dailyHours > 0 {
                    BarMark(
                        x: .value("Date", day.date),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Flown", day.dailyHours)
                    )
                    .foregroundStyle(day.isFuture ? Color.blue.opacity(0.3) : Color.blue)
                }
                
                // 2. Negative Bar (Credit): Dropping Off
                if day.hoursDroppingOff > 0 {
                    BarMark(
                        x: .value("Date", day.date),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Restored", -day.hoursDroppingOff)
                    )
                    .foregroundStyle(Color.red.opacity(0.4))
                }
                
                // 3. Line: Available Capacity (scaled down by 10 to fit)
                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Capacity", day.availableHours / 10.0)
                )
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)
                
                // Highlight current day
                if Calendar.current.isDateInToday(day.date) {
                    PointMark(
                        x: .value("Date", day.date),
                        y: .value("Capacity", day.availableHours / 10.0)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(60)
                }
            }
            
            // Zero line
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.primary.opacity(0.2))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: timeframe.xAxisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            // Left Axis (Daily Hours)
            AxisMarks(position: .leading) { value in
                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(String(format: "%.0f", abs(doubleValue)))h")
                    }
                    AxisGridLine()
                }
            }
            
            // Right Axis (Capacity 0-100)
            AxisMarks(position: .trailing, values: .automatic) { value in
                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(doubleValue * 10))")
                            .foregroundColor(.green)
                            .bold()
                    }
                }
            }
        }
    }
}

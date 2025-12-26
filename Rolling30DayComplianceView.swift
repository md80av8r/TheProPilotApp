// Rolling30DayComplianceView.swift
// Rolling 30-day flight time tracking for FAR Part 121 compliance
// 100 hours in 30 consecutive days limit

import SwiftUI
import Charts

struct Rolling30DayComplianceView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedDate: Date = Date()
    @State private var showingExport = false
    @State private var showingDayDetail: R30DayData?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    // The FAR 121 limit
    private let limitHours: Double = 100.0
    private let warningThreshold: Double = 90.0
    private let cautionThreshold: Double = 80.0
    
    var body: some View {
        GeometryReader { geometry in
            let isIPad = horizontalSizeClass == .regular
            
            ScrollView {
                VStack(spacing: isIPad ? 24 : 16) {
                    // Current Status Card
                    currentStatusCard(isIPad: isIPad)
                    
                    // Chart Section
                    chartSection(isIPad: isIPad, width: geometry.size.width)
                    
                    // Upcoming Drop-offs
                    dropOffSection(isIPad: isIPad)
                    
                    // Daily Breakdown
                    dailyBreakdownSection(isIPad: isIPad)
                }
                .padding(isIPad ? 24 : 16)
            }
        }
        .navigationTitle("30-Day Rolling")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            R30ExportSheet(
                data: rolling30DayData,
                currentHours: currentRolling30Hours,
                onExport: exportComplianceReport
            )
        }
        .sheet(item: $showingDayDetail) { dayData in
            R30DayDetailSheet(dayData: dayData, store: store)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Current Status Card
    
    private func currentStatusCard(isIPad: Bool) -> some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Big number display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", currentRolling30Hours))
                    .font(.system(size: isIPad ? 72 : 56, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
                Text("/ 100")
                    .font(.system(size: isIPad ? 32 : 24, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text("Hours in Rolling 30 Days")
                .font(isIPad ? .title3 : .subheadline)
                .foregroundColor(.gray)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    // Warning zone (80-90)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: geo.size.width * 0.9)
                    
                    // Danger zone (90-100)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.3))
                        .frame(width: geo.size.width)
                    
                    // Safe zone (0-80)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: geo.size.width * 0.8)
                    
                    // Current progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusColor)
                        .frame(width: geo.size.width * min(currentRolling30Hours / limitHours, 1.0))
                }
            }
            .frame(height: isIPad ? 24 : 16)
            
            // Status indicators
            HStack(spacing: isIPad ? 32 : 16) {
                R30StatusIndicator(label: "Available", value: String(format: "%.1f hrs", remainingHours), color: .green, isIPad: isIPad)
                R30StatusIndicator(label: "Next Drop", value: nextDropOffText, color: .blue, isIPad: isIPad)
                R30StatusIndicator(label: "Status", value: statusText, color: statusColor, isIPad: isIPad)
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Chart Section
    
    private func chartSection(isIPad: Bool, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rolling 30-Day Trend")
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    // Limit line
                    RuleMark(y: .value("Limit", 100))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("100 hr limit")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    
                    // Warning line
                    RuleMark(y: .value("Warning", 90))
                        .foregroundStyle(.orange.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    
                    // Data points
                    ForEach(chartData, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Hours", point.rollingTotal)
                        )
                        .foregroundStyle(
                            point.rollingTotal >= 100 ? .red :
                            point.rollingTotal >= 90 ? .orange :
                            point.rollingTotal >= 80 ? .yellow : .green
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Hours", point.rollingTotal)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [statusColorFor(point.rollingTotal).opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Hours", point.rollingTotal)
                        )
                        .foregroundStyle(statusColorFor(point.rollingTotal))
                        .symbolSize(Calendar.current.isDateInToday(point.date) ? 100 : 30)
                    }
                }
                .chartYScale(domain: 0...110)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: isIPad ? 3 : 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: isIPad ? 300 : 200)
            } else {
                // Fallback for iOS 15
                R30LegacyChartView(data: chartData, isIPad: isIPad)
                    .frame(height: isIPad ? 300 : 200)
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Drop-off Section
    
    private func dropOffSection(isIPad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Hour Drop-offs")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Hours returning to your budget")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if upcomingDropOffs.isEmpty {
                Text("No hours dropping off in the next 7 days")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                LazyVGrid(columns: isIPad ?
                    [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] :
                    [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(upcomingDropOffs.prefix(8), id: \.date) { dropOff in
                        R30DropOffCard(dropOff: dropOff, isIPad: isIPad)
                    }
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Daily Breakdown Section
    
    private func dailyBreakdownSection(isIPad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 30 Days Detail")
                    .font(isIPad ? .title2 : .headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Tap for details")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Grid for iPad, List for iPhone
            if isIPad {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(rolling30DayData, id: \.date) { dayData in
                        R30DayCell(dayData: dayData)
                            .onTapGesture {
                                if dayData.flightHours > 0 {
                                    showingDayDetail = dayData
                                }
                            }
                    }
                }
            } else {
                ForEach(rolling30DayData.filter { $0.flightHours > 0 }, id: \.date) { dayData in
                    R30DayRowView(dayData: dayData)
                        .onTapGesture {
                            showingDayDetail = dayData
                        }
                }
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    
    private var currentRolling30Hours: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return calculateHoursInRange(from: thirtyDaysAgo, to: Date())
    }
    
    private var remainingHours: Double {
        max(0, limitHours - currentRolling30Hours)
    }
    
    private var statusColor: Color {
        if currentRolling30Hours >= limitHours { return .red }
        if currentRolling30Hours >= warningThreshold { return .orange }
        if currentRolling30Hours >= cautionThreshold { return .yellow }
        return .green
    }
    
    private func statusColorFor(_ hours: Double) -> Color {
        if hours >= limitHours { return .red }
        if hours >= warningThreshold { return .orange }
        if hours >= cautionThreshold { return .yellow }
        return .green
    }
    
    private var statusText: String {
        if currentRolling30Hours >= limitHours { return "AT LIMIT" }
        if currentRolling30Hours >= warningThreshold { return "WARNING" }
        if currentRolling30Hours >= cautionThreshold { return "CAUTION" }
        return "LEGAL"
    }
    
    private var nextDropOffText: String {
        guard let nextDrop = upcomingDropOffs.first else { return "None" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: nextDrop.date)) (-\(String(format: "%.1f", nextDrop.hours)))"
    }
    
    private var rolling30DayData: [R30DayData] {
        var data: [R30DayData] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dateStart = calendar.startOfDay(for: date)
            let hours = calculateHoursOnDate(dateStart)
            let legs = getLegsOnDate(dateStart)
            
            data.append(R30DayData(
                date: dateStart,
                flightHours: hours,
                legCount: legs.count,
                legs: legs
            ))
        }
        
        return data.reversed() // Chronological order
    }
    
    private var chartData: [R30ChartPoint] {
        var data: [R30ChartPoint] = []
        let calendar = Calendar.current
        
        // Show trend for last 30 days + 7 days future projection
        for dayOffset in (-30...7) {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let dateStart = calendar.startOfDay(for: date)
            let rollingTotal = calculateRolling30At(date: dateStart)
            
            data.append(R30ChartPoint(
                date: dateStart,
                rollingTotal: rollingTotal,
                dailyHours: calculateHoursOnDate(dateStart)
            ))
        }
        
        return data
    }
    
    private var upcomingDropOffs: [R30DropOff] {
        var dropOffs: [R30DropOff] = []
        let calendar = Calendar.current
        
        // Look at flights from 30 days ago that will drop off
        for dayOffset in 1...7 {
            let dropDate = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let dropDateStart = calendar.startOfDay(for: dropDate)
            let flightDate = calendar.date(byAdding: .day, value: -30, to: dropDateStart)!
            let hours = calculateHoursOnDate(flightDate)
            
            if hours > 0 {
                dropOffs.append(R30DropOff(
                    date: dropDateStart,
                    hours: hours,
                    originalFlightDate: flightDate
                ))
            }
        }
        
        return dropOffs.sorted { $0.date < $1.date }
    }
    
    // MARK: - Helper Methods

    /// Get effective flight date for a leg, detecting overnight flights when flightDate is nil
    private func effectiveLegDate(for leg: FlightLeg, tripDate: Date) -> Date {
        // If flightDate is already set, use it
        if let flightDate = leg.flightDate {
            return flightDate
        }

        // Otherwise, detect overnight flights by comparing OUT vs IN times
        let calendar = Calendar.current
        guard !leg.outTime.isEmpty, !leg.inTime.isEmpty else {
            return tripDate
        }

        // Parse hours from time strings
        let outHour = parseHourFromTimeString(leg.outTime)
        let inHour = parseHourFromTimeString(leg.inTime)

        // Overnight detection: OUT in afternoon/evening (12+), IN in early morning (0-11)
        if let out = outHour, let inn = inHour, out >= 12 && inn < 12 {
            return calendar.date(byAdding: .day, value: 1, to: tripDate) ?? tripDate
        }

        return tripDate
    }

    /// Parse hour from time string for overnight detection
    private func parseHourFromTimeString(_ timeString: String) -> Int? {
        let cleaned = timeString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleaned.count == 4 {
            return Int(cleaned.prefix(2))
        } else if cleaned.count == 3 {
            return Int(cleaned.prefix(1))
        } else if cleaned.count <= 2 {
            return Int(cleaned)
        }
        return nil
    }

    private func calculateHoursInRange(from: Date, to: Date) -> Double {
        var totalMinutes: Int = 0
        let calendar = Calendar.current
        let fromStart = calendar.startOfDay(for: from)
        let toStart = calendar.startOfDay(for: to)

        for trip in store.trips {
            for leg in trip.legs {
                // Use effective leg date with overnight detection
                let legDate = effectiveLegDate(for: leg, tripDate: trip.date)
                let legDateStart = calendar.startOfDay(for: legDate)

                if legDateStart >= fromStart && legDateStart <= toStart {
                    totalMinutes += leg.blockMinutes()
                }
            }
        }

        return Double(totalMinutes) / 60.0
    }

    private func calculateHoursOnDate(_ date: Date) -> Double {
        var totalMinutes: Int = 0
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        for trip in store.trips {
            for leg in trip.legs {
                // Use effective leg date with overnight detection
                let legDate = calendar.startOfDay(for: effectiveLegDate(for: leg, tripDate: trip.date))

                if legDate == targetDate {
                    totalMinutes += leg.blockMinutes()
                }
            }
        }

        return Double(totalMinutes) / 60.0
    }
    
    private func calculateRolling30At(date: Date) -> Double {
        let thirtyDaysBefore = Calendar.current.date(byAdding: .day, value: -30, to: date)!
        return calculateHoursInRange(from: thirtyDaysBefore, to: date)
    }
    
    private func getLegsOnDate(_ date: Date) -> [R30LegInfo] {
        var legs: [R30LegInfo] = []
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        for trip in store.trips {
            for leg in trip.legs {
                // Use effective leg date with overnight detection
                let legDate = calendar.startOfDay(for: effectiveLegDate(for: leg, tripDate: trip.date))

                if legDate == targetDate {
                    legs.append(R30LegInfo(
                        tripNumber: trip.tripNumber,
                        departure: leg.departure,
                        arrival: leg.arrival,
                        blockMinutes: leg.blockMinutes(),
                        aircraft: trip.aircraft
                    ))
                }
            }
        }

        return legs
    }
    
    // MARK: - Export
    
    private func exportComplianceReport() {
        let report = generateComplianceReport()
        
        let fileName = "Rolling30Day_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try report.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingExport = false
            showingShareSheet = true
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
    
    private func generateComplianceReport() -> String {
        var report = """
        ═══════════════════════════════════════════════════════════════
        FAR PART 121 ROLLING 30-DAY COMPLIANCE REPORT
        ═══════════════════════════════════════════════════════════════
        Generated: \(Date().formatted(date: .long, time: .shortened))
        
        CURRENT STATUS
        ──────────────────────────────────────────────────────────────
        Rolling 30-Day Total:  \(String(format: "%.1f", currentRolling30Hours)) hours
        Regulatory Limit:      100.0 hours
        Remaining Capacity:    \(String(format: "%.1f", remainingHours)) hours
        Status:                \(statusText)
        
        DAILY BREAKDOWN (Last 30 Days)
        ──────────────────────────────────────────────────────────────
        Date          Hours    Legs    Details
        ──────────────────────────────────────────────────────────────
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        for dayData in rolling30DayData.reversed() {
            if dayData.flightHours > 0 {
                let legDetails = dayData.legs.map { "\($0.departure)-\($0.arrival)" }.joined(separator: ", ")
                report += "\n\(dateFormatter.string(from: dayData.date))    \(String(format: "%5.1f", dayData.flightHours))    \(dayData.legCount)       \(legDetails)"
            }
        }
        
        report += """
        
        
        UPCOMING DROP-OFFS (Next 7 Days)
        ──────────────────────────────────────────────────────────────
        """
        
        if upcomingDropOffs.isEmpty {
            report += "\nNo hours dropping off in the next 7 days"
        } else {
            for dropOff in upcomingDropOffs {
                report += "\n\(dateFormatter.string(from: dropOff.date)): -\(String(format: "%.1f", dropOff.hours)) hours (from \(dateFormatter.string(from: dropOff.originalFlightDate)))"
            }
        }
        
        report += """
        
        
        ═══════════════════════════════════════════════════════════════
        This report is for personal reference only.
        Always verify compliance with official company records.
        ═══════════════════════════════════════════════════════════════
        """
        
        return report
    }
}

// MARK: - Supporting Data Structures (Prefixed with R30 to avoid conflicts)

struct R30DayData: Identifiable {
    let id = UUID()
    let date: Date
    let flightHours: Double
    let legCount: Int
    let legs: [R30LegInfo]
}

struct R30LegInfo {
    let tripNumber: String
    let departure: String
    let arrival: String
    let blockMinutes: Int
    let aircraft: String
    
    var blockHoursFormatted: String {
        let hours = blockMinutes / 60
        let mins = blockMinutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

struct R30ChartPoint {
    let date: Date
    let rollingTotal: Double
    let dailyHours: Double
}

struct R30DropOff {
    let date: Date
    let hours: Double
    let originalFlightDate: Date
}

// MARK: - Supporting Views (Prefixed with R30 to avoid conflicts)

struct R30StatusIndicator: View {
    let label: String
    let value: String
    let color: Color
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(isIPad ? .title3 : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct R30DropOffCard: View {
    let dropOff: R30DropOff
    let isIPad: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(dropOff.date, format: .dateTime.month(.abbreviated).day())
                .font(isIPad ? .headline : .subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                Text(String(format: "%.1f", dropOff.hours))
                    .fontWeight(.bold)
            }
            .font(isIPad ? .title3 : .subheadline)
            .foregroundColor(.green)
            
            Text("hrs return")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct R30DayCell: View {
    let dayData: R30DayData
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayData.date, format: .dateTime.day())
                .font(.headline)
            
            if dayData.flightHours > 0 {
                Text(String(format: "%.1f", dayData.flightHours))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(dayData.flightHours > 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct R30DayRowView: View {
    let dayData: R30DayData
    
    var body: some View {
        HStack {
            Text(dayData.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text("\(dayData.legCount) legs")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(String(format: "%.1f hrs", dayData.flightHours))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct R30DayDetailSheet: View {
    let dayData: R30DayData
    let store: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Total Block Time")
                        Spacer()
                        Text(String(format: "%.1f hours", dayData.flightHours))
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Flight Legs")
                        Spacer()
                        Text("\(dayData.legCount)")
                    }
                }
                
                Section("Flight Legs") {
                    ForEach(dayData.legs, id: \.departure) { leg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(leg.departure) → \(leg.arrival)")
                                    .font(.headline)
                                Spacer()
                                Text(leg.blockHoursFormatted)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("Trip \(leg.tripNumber)")
                                Text("•")
                                Text(leg.aircraft)
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(dayData.date.formatted(date: .long, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct R30ExportSheet: View {
    let data: [R30DayData]
    let currentHours: Double
    let onExport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Export Compliance Report")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Current rolling 30-day hours", systemImage: "clock")
                    Label("Daily breakdown with flight details", systemImage: "list.bullet")
                    Label("Upcoming drop-off schedule", systemImage: "calendar")
                    Label("Status and remaining capacity", systemImage: "checkmark.shield")
                }
                .foregroundColor(.gray)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Button {
                    onExport()
                } label: {
                    Text("Generate Report")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Legacy Chart (iOS 15 fallback)

struct R30LegacyChartView: View {
    let data: [R30ChartPoint]
    let isIPad: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let maxHours = 110.0
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Grid lines
                ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                    Path { path in
                        let y = height - (CGFloat(value) / maxHours * height)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
                
                // 100 hour limit line
                Path { path in
                    let y = height - (100 / maxHours * height)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                // Data line
                Path { path in
                    guard !data.isEmpty else { return }
                    
                    let stepX = width / CGFloat(data.count - 1)
                    
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(point.rollingTotal) / maxHours * height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 3)
            }
        }
    }
}

// MARK: - Preview

struct Rolling30DayComplianceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Rolling30DayComplianceView(store: SwiftDataLogBookStore.preview)
        }
    }
}

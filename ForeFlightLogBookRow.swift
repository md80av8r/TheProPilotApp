//ForeFlightLogBookRow.swift - Updated with FAR 117 Tracking

import SwiftUI

struct ForeFlightLogbookRow: View {
    let trip: Trip
    @ObservedObject var store: SwiftDataLogBookStore
    @State private var showingLimitsDetail = false
    
    // Cache the FAR117 calculation to avoid recalculating on every render
    // Only recalculates when trip.date or store.trips changes
    @State private var cachedStatus: FAR117Status?
    @State private var lastCalculatedDate: Date?
    
    // Computed properties for proper display
    private var displayTitle: String {
        switch trip.tripType {
        case .operating:
            return trip.tripNumber.isEmpty ? "Operating Flight" : "Trip #\(trip.tripNumber)"
        case .deadhead:
            if let flightNumber = trip.deadheadFlightNumber, !flightNumber.isEmpty {
                return "DH: \(flightNumber)"
            } else if let airline = trip.deadheadAirline, !airline.isEmpty {
                return "DH: \(airline)"
            } else {
                return "Deadhead"
            }
        case .simulator:
            return "Sim: \(trip.aircraft)"
        }
    }

    private var routeDisplay: String {
        // Simulator trips don't have routes
        if trip.tripType == .simulator {
            return "Training Session"
        }
        
        // No legs
        guard !trip.legs.isEmpty else {
            return "No Route"
        }
        
        // Build full route chain from legs: DEP1 → ARR1 → ARR2 ...
        // We prefer to show each leg's departure and then the final arrival without duplicates.
        let legs = trip.legs
        var segments: [String] = []
        for (index, leg) in legs.enumerated() {
            let dep = leg.departure.isEmpty ? "?" : leg.departure
            let arr = leg.arrival.isEmpty ? "?" : leg.arrival
            if index == 0 {
                segments.append(dep)
            }
            segments.append(arr)
        }
        
        // Join with arrow
        return segments.joined(separator: " → ")
    }

    private var titleColor: Color {
        switch trip.tripType {
        case .operating:
            return .white
        case .deadhead:
            return LogbookTheme.accentOrange.opacity(0.9)
        case .simulator:
            return LogbookTheme.accentGreen.opacity(0.9)
        }
    }
    
    private var statusBadge: some View {
        Group {
            if trip.status != .completed {
                HStack(spacing: 4) {
                    Circle()
                        .fill(trip.status.color)
                        .frame(width: 6, height: 6)
                    Text(trip.status.displayName)
                        .font(.caption2)
                        .foregroundColor(trip.status.color)
                }
            }
        }
    }

    /// Mismatch warning icon - shown when logged block time differs from NOC roster
    private var mismatchWarningBadge: some View {
        Group {
            if trip.hasBlockTimeMismatch {
                let severity = trip.worstMismatchSeverity
                Image(systemName: severity.symbolName)
                    .font(.caption)
                    .foregroundColor(mismatchColor(for: severity))
                    .help("Block time mismatch with roster")
            }
        }
    }

    private func mismatchColor(for severity: MismatchSeverity) -> Color {
        switch severity {
        case .none: return .green
        case .minor: return .yellow
        case .moderate: return .orange
        case .significant: return .red
        }
    }
    
    private var far117Status: FAR117Status {
        // Only recalculate if needed (date changed or never calculated)
        if cachedStatus == nil || lastCalculatedDate != trip.date {
            let status = calculateFAR117Limits(for: trip.date, store: store)
            // Update cache on next render cycle
            DispatchQueue.main.async {
                self.cachedStatus = status
                self.lastCalculatedDate = trip.date
            }
            return status
        }
        return cachedStatus ?? calculateFAR117Limits(for: trip.date, store: store)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundColor(titleColor)

                        statusBadge

                        mismatchWarningBadge
                    }
                    
                    Group {
                        if trip.tripType == .simulator {
                            Text("Training Session")
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.accentBlue)
                        } else if trip.legs.isEmpty {
                            Text("No Route")
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.accentBlue)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(trip.legs.enumerated()), id: \.offset) { _, leg in
                                    let dep = leg.departure.isEmpty ? "?" : leg.departure
                                    let arr = leg.arrival.isEmpty ? "?" : leg.arrival
                                    Text("\(dep) → \(arr)")
                                        .font(.subheadline)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text(trip.aircraft)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        Text(trip.pilotRole.rawValue)
                            .font(.caption)
                            .foregroundColor(trip.pilotRole == .captain ? LogbookTheme.accentGreen : LogbookTheme.accentBlue)
                    }
                    
                    if let perDiemText = formatPerDiem() {
                        Text(perDiemText)
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.formattedTotalTime)
                        .font(.title2.bold())
                        .foregroundColor(trip.tripType == .operating ? LogbookTheme.accentGreen : LogbookTheme.accentOrange)
                    
                    Text(trip.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(trip.tripType.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(trip.tripType == .operating ? LogbookTheme.textSecondary : LogbookTheme.accentOrange.opacity(0.7))
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            if far117Status.showWarning {
                Button(action: { showingLimitsDetail.toggle() }) {
                    FAR117LimitsBar(status: far117Status)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            borderGradientStartColor.opacity(0.6),
                            borderGradientEndColor.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: LogbookTheme.accentBlue.opacity(0.15), radius: 6, x: 0, y: 3)
        .overlay(
            // Left accent bar for deadhead flights
            RoundedRectangle(cornerRadius: 4)
                .fill(trip.tripType == .deadhead ? LogbookTheme.accentOrange : Color.clear)
                .frame(width: 5)
                .padding(.leading, 3),
            alignment: .leading
        )
        .sheet(isPresented: $showingLimitsDetail) {
            FAR117DetailView(status: far117Status, tripDate: trip.date)
        }
    }
    
    // Gradient colors based on trip type/status
    private var borderGradientStartColor: Color {
        switch trip.tripType {
        case .operating:
            return trip.status == .completed ? LogbookTheme.accentGreen : LogbookTheme.accentGreen
        case .deadhead:
            return LogbookTheme.accentOrange
        case .simulator:
            return LogbookTheme.accentGreen
        }
    }
    
    private var borderGradientEndColor: Color {
        switch trip.tripType {
        case .operating:
            return trip.status == .completed ? LogbookTheme.accentBlue : LogbookTheme.accentBlue
        case .deadhead:
            return LogbookTheme.accentOrange.opacity(0.7)
        case .simulator:
            return LogbookTheme.accentBlue
        }
    }
    
    private var borderColor: Color {
        switch trip.tripType {
        case .operating:
            return trip.status == .completed ? LogbookTheme.accentGreen.opacity(0.8) : LogbookTheme.accentBlue.opacity(0.8)
        case .deadhead:
            return LogbookTheme.accentOrange.opacity(0.8)
        case .simulator:
            return LogbookTheme.accentGreen.opacity(0.8)
        }
    }
    
    private func formatPerDiem() -> String? {
        if trip.legs.count > 1 {
            return "Multi-leg (\(trip.legs.count) legs)"
        }
        
        if trip.tripType == .operating && trip.totalBlockMinutes > 0 {
            let hours = trip.totalBlockMinutes / 60
            if hours >= 4 {
                return "Per Diem Eligible"
            }
        }
        
        return nil
    }
}

// MARK: - FAR 117 Limits Bar
struct FAR117LimitsBar: View {
    let status: FAR117Status
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.criticalWarning ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.caption2)
                    .foregroundColor(status.criticalWarning ? .red : .orange)
                
                Text("FAR 117 Limits")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Tap for details")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 6) {
                LimitIndicator(
                    label: "24h",
                    current: status.hours24,
                    limit: 8.0,
                    isWarning: status.hours24 >= 7.2
                )
                
                LimitIndicator(
                    label: "7d",
                    current: status.hours7Day,
                    limit: 60.0,
                    isWarning: status.hours7Day >= 54.0
                )
                
                LimitIndicator(
                    label: "28d",
                    current: status.hours28Day,
                    limit: 190.0,
                    isWarning: status.hours28Day >= 171.0
                )
            }
        }
        .padding(8)
        .background(status.criticalWarning ? Color.red.opacity(0.2) : Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}

struct LimitIndicator: View {
    let label: String
    let current: Double
    let limit: Double
    let isWarning: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(isWarning ? Color.red : Color.green)
                    .frame(width: max(0, min(1.0, current / limit)) * 40, height: 4)
            }
            .frame(width: 40)
            
            Text(String(format: "%.1f", current))
                .font(.caption2.bold())
                .foregroundColor(isWarning ? .red : .white)
        }
    }
}

// MARK: - FAR 117 Status Model
struct FAR117Status {
    let hours24: Double
    let hours7Day: Double
    let hours28Day: Double
    let hoursAnnual: Double
    
    var showWarning: Bool {
        hours24 >= 7.2 || hours7Day >= 54.0 || hours28Day >= 171.0
    }
    
    var criticalWarning: Bool {
        hours24 >= 7.5 || hours7Day >= 57.0 || hours28Day >= 180.0
    }
}

// MARK: - Calculate FAR 117 Limits (Real-Time Aware)
@MainActor
func calculateFAR117Limits(for date: Date, store: SwiftDataLogBookStore) -> FAR117Status {
    let calendar = Calendar.current
    
    let date24HoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
    let date7DaysAgo = calendar.date(byAdding: .day, value: -6, to: date) ?? date
    let date28DaysAgo = calendar.date(byAdding: .day, value: -28, to: date) ?? date
    let date365DaysAgo = calendar.date(byAdding: .day, value: -365, to: date) ?? date
    
    var hours24: Double = 0
    var hours7Day: Double = 0
    var hours28Day: Double = 0
    var hoursAnnual: Double = 0
    
    for trip in store.trips where trip.tripType == .operating {
        let tripDate = trip.date
        
        // For 24-hour lookback, check each leg individually by OUT time
        for leg in trip.legs {
            if let outDateTime = parseTimeWithDate(timeString: leg.outTime, date: tripDate) {
                let blockMinutes = leg.blockMinutes()
                let blockHours = Double(blockMinutes) / 60.0
                
                // Only count if leg OUT time is within the 24-hour window
                if outDateTime >= date24HoursAgo && outDateTime <= date {
                    hours24 += blockHours
                }
            }
        }
        
        // For longer periods, use trip date (simpler and more performant)
        let blockHours = Double(trip.totalBlockMinutes) / 60.0
        
        if tripDate >= date7DaysAgo && tripDate <= date {
            hours7Day += blockHours
        }
        
        if tripDate >= date28DaysAgo && tripDate <= date {
            hours28Day += blockHours
        }
        
        if tripDate >= date365DaysAgo && tripDate <= date {
            hoursAnnual += blockHours
        }
    }
    
    return FAR117Status(
        hours24: hours24,
        hours7Day: hours7Day,
        hours28Day: hours28Day,
        hoursAnnual: hoursAnnual
    )
}

// MARK: - Helper for Time Parsing
private func parseTimeWithDate(timeString: String, date: Date) -> Date? {
    let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTime.isEmpty else { return nil }
    
    let calendar = Calendar.current
    
    // Handle multiple time formats
    let cleanedTime = trimmedTime
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".", with: "")
    
    // Extract hours and minutes from various formats
    var hours: Int?
    var minutes: Int?
    
    if cleanedTime.count == 4 {
        // Format: "0800" or "1425"
        hours = Int(cleanedTime.prefix(2))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count == 3 {
        // Format: "800" (missing leading zero)
        hours = Int(cleanedTime.prefix(1))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count == 1 || cleanedTime.count == 2 {
        // Format: "8" or "08" (hours only)
        hours = Int(cleanedTime)
        minutes = 0
    }
    
    guard let validHours = hours,
          let validMinutes = minutes,
          validHours >= 0 && validHours <= 23,
          validMinutes >= 0 && validMinutes <= 59 else {
        print("❌ Failed to parse time: '\(timeString)' -> cleaned: '\(cleanedTime)'")
        return nil
    }
    
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = validHours
    components.minute = validMinutes
    components.second = 0
    
    let result = calendar.date(from: components)
    // print("✅ Parsed time: '\(timeString)' -> \(result?.formatted(date: .omitted, time: .shortened) ?? "nil")")
    return result
}

// MARK: - FAR 117 Detail View
// MARK: - FAR 117 Detail View
struct FAR117DetailView: View {
    let status: FAR117Status
    let tripDate: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // NEW: Chart Link Section
                Section {
                    NavigationLink(destination: FAR121ComplianceView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Visual Timeline Chart")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("See when hours drop off")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("As of \(tripDate.formatted(date: .abbreviated, time: .shortened))") {
                    LimitRow(
                        title: "Rolling 24 Hours",
                        current: status.hours24,
                        limit: 8.0,
                        regulation: "§117.11"
                    )
                    
                    LimitRow(
                        title: "Rolling 7 Days",
                        current: status.hours7Day,
                        limit: 60.0,
                        regulation: "§117.23(b)"
                    )
                    
                    LimitRow(
                        title: "Rolling 28 Days",
                        current: status.hours28Day,
                        limit: 190.0,
                        regulation: "§117.23(b)"
                    )
                    
                    LimitRow(
                        title: "Rolling 365 Days",
                        current: status.hoursAnnual,
                        limit: 1000.0,
                        regulation: "§117.23(b)"
                    )
                }
                
                Section("Legend") {
                    HStack {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("Within limits")
                    }
                    HStack {
                        Circle().fill(Color.orange).frame(width: 10, height: 10)
                        Text("Approaching limit (90%+)")
                    }
                    HStack {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Critical (95%+)")
                    }
                }
            }
            .navigationTitle("FAR Part 117 Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LimitRow: View {
    let title: String
    let current: Double
    let limit: Double
    let regulation: String
    
    private var safeLimit: Double { max(0, limit) }
    private var safeCurrent: Double { max(0, current) }
    private var percentage: Double {
        guard safeLimit > 0 else { return 0 }
        return min(max((safeCurrent / safeLimit) * 100.0, 0), 100)
    }
    
    private var statusColor: Color {
        if percentage >= 95 { return .red }
        if percentage >= 90 { return .orange }
        return .green
    }
    
    private var remainingClamped: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeLimit - safeCurrent)
    }
    
    private var overBy: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeCurrent - safeLimit)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(regulation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(String(format: "%.1f hrs", safeCurrent))
                    .font(.title2.bold())
                    .foregroundColor(statusColor)
                
                Text("of \(Int(safeLimit)) hrs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", percentage))
                    .font(.title3.bold())
                    .foregroundColor(statusColor)
            }
            
            ProgressView(value: min(safeCurrent, safeLimit), total: max(safeLimit, 1))
                .tint(statusColor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            if safeCurrent <= safeLimit {
                if percentage >= 90 {
                    Text("⚠️ Approaching limit - \(String(format: "%.1f", remainingClamped)) hours remaining")
                        .font(.caption)
                        .foregroundColor(statusColor)
                } else {
                    Text("\(String(format: "%.1f", remainingClamped)) hours remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Over by \(String(format: "%.1f", overBy)) hours")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Real-Time 24-Hour Lookback Status
struct Current24HourStatusRow: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @State private var currentTime = Date()
    
    private var status: TwentyFourHourStatus {
        calculate24HourStatus()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(status.statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("24 Hr Lookback")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(status.timeWindowDisplay)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", status.hoursInLast24))
                        .font(.title.bold())
                        .foregroundColor(status.statusColor)
                    Text("hrs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(String(format: "%.1f hrs remaining", status.remainingBlockHours))
                    .font(.caption)
                    .foregroundColor(status.remainingBlockHours <= 1.0 ? .red : .gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.statusColor.opacity(0.6), lineWidth: 2)
        )
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    // FIXED VERSION - Replace the calculate24HourStatus function in ForeFlightLogBookRow.swift
    // Around line 655-698

        private func calculate24HourStatus() -> TwentyFourHourStatus {
            let now = Date()
            let calendar = Calendar.current
            let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: now)!
            
            var totalBlockMinutes = 0
            var firstOutTime: Date? = nil
            var lastInTime: Date? = nil
            
            for trip in store.trips where trip.tripType == .operating {
                for leg in trip.legs {
                    // CRITICAL FIX: Only count COMPLETED legs (with both OUT and IN times)
                    // within the 24-hour window to avoid counting duty time
                    guard let outDateTime = parseTimeWithDate(timeString: leg.outTime, date: trip.date),
                          let inDateTime = parseTimeWithDate(timeString: leg.inTime, date: trip.date) else {
                        // Skip legs that don't have both OUT and IN times
                        // This prevents counting active legs as duty time
                        continue
                    }
                    
                    // Only count if BOTH OUT and IN times are within the last 24 hours
                    // This prevents counting partial legs or duty time
                    if outDateTime >= twentyFourHoursAgo && inDateTime <= now {
                        totalBlockMinutes += leg.blockMinutes()
                        
                        if firstOutTime == nil || outDateTime < firstOutTime! {
                            firstOutTime = outDateTime
                        }
                        
                        if lastInTime == nil || inDateTime > lastInTime! {
                            lastInTime = inDateTime
                        }
                    }
                }
            }
            
            let hoursInLast24 = Double(totalBlockMinutes) / 60.0
            let remainingHours = max(0, 8.0 - hoursInLast24)
            
            return TwentyFourHourStatus(
                hoursInLast24: hoursInLast24,
                remainingBlockHours: remainingHours,
                firstOutTime: firstOutTime,
                lastInTime: lastInTime
            )
        }
    
    private func parseTimeWithDate(timeString: String, date: Date) -> Date? {
        guard !timeString.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let cleanedTime = timeString.replacingOccurrences(of: ":", with: "")
        
        guard cleanedTime.count == 4,
              let hours = Int(cleanedTime.prefix(2)),
              let minutes = Int(cleanedTime.suffix(2)) else {
            return nil
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hours
        components.minute = minutes
        components.second = 0
        
        return calendar.date(from: components)
    }
}

// MARK: - 24-Hour Status Data Model
struct TwentyFourHourStatus {
    let hoursInLast24: Double
    let remainingBlockHours: Double
    let firstOutTime: Date?
    let lastInTime: Date?
    let lookbackLimit: Double = 8.0
    
    var timeWindowDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let firstOut = firstOutTime, let lastIn = lastInTime {
            return "\(formatter.string(from: firstOut)) - \(formatter.string(from: lastIn))"
        } else if let firstOut = firstOutTime {
            return "Started \(formatter.string(from: firstOut))"
        } else {
            return "No flights in last 24 hours"
        }
    }
    
    var statusColor: Color {
        if remainingBlockHours <= 0.5 { return .red }
        if remainingBlockHours <= 1.5 { return .orange }
        return .green
    }
}

// MARK: - Current FAR 117 Status View (All Limits)
struct CurrentFAR117StatusView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @State private var showingLimitsDetail = false
    @AppStorage("far117StatusExpanded") private var isExpanded: Bool = true

    private var currentStatus: FAR117Status {
        calculateFAR117Limits(for: Date(), store: store)
    }

    private var statusColor: Color {
        if currentStatus.criticalWarning { return .red }
        if currentStatus.showWarning { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with collapse/expand control
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gauge.high")
                        .foregroundColor(statusColor)
                    
                    Text("Current FAR 117 Status")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    // Show compact status when collapsed
                    if !isExpanded {
                        compactStatusView
                    }
                    
                    // Chevron rotates based on state
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details view
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(statusColor.opacity(0.3))
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 16) {
                        CurrentLimitDisplay(
                            label: "In 24 Hrs",
                            current: currentStatus.hours24,
                            limit: 8,
                            isWarning: currentStatus.hours24 >= 7.2
                        )
                        
                        CurrentLimitDisplay(
                            label: "In 7 Days",
                            current: currentStatus.hours7Day,
                            limit: 60,
                            isWarning: currentStatus.hours7Day >= 54.0
                        )
                        
                        CurrentLimitDisplay(
                            label: "In 28 Days",
                            current: currentStatus.hours28Day,
                            limit: 190,
                            isWarning: currentStatus.hours28Day >= 171.0
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.6), lineWidth: 2)
        )
        // Tap on the entire card (when expanded) to show details
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                showingLimitsDetail = true
            }
        }
        .sheet(isPresented: $showingLimitsDetail) {
            // ✅ Calculate status inside the sheet closure to avoid scope issues
            FAR117DetailView(status: calculateFAR117Limits(for: Date(), store: store), tripDate: Date())
        }
    }
    
    // MARK: - Compact Status View (shown when collapsed)
    private var compactStatusView: some View {
        HStack(spacing: 8) {
            // Show most critical metric (24 hours)
            Text(String(format: "%.1f", currentStatus.hours24))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(currentStatus.hours24 >= 7.2 ? .orange : .green)
            
            Text("/")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Text("8h")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            // Status indicator
            Image(systemName: currentStatus.criticalWarning ? "exclamationmark.triangle.fill" :
                              currentStatus.showWarning ? "exclamationmark.circle.fill" :
                              "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(statusColor)
        }
        .padding(.trailing, 8)
    }
}

struct CurrentLimitDisplay: View {
    let label: String
    let current: Double
    let limit: Int
    let isWarning: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", current))
                    .font(.title3.bold())
                    .foregroundColor(isWarning ? .orange : .green)  // Changed from .white to .green
                Text("/ \(limit)h")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Calculate flight time limits using configurable settings from DutyLimitSettingsStore
@MainActor
func calculateConfigurableLimits(for date: Date, store: SwiftDataLogBookStore) -> ConfigurableLimitStatus {
    let settings = DutyLimitSettingsStore.shared.configuration
    let calendar = Calendar.current
    
    // Skip if tracking disabled or Part 91
    guard DutyLimitSettingsStore.shared.trackingEnabled,
          settings.operationType != .part91 else {
        return ConfigurableLimitStatus(settings: settings)
    }
    
    var status = ConfigurableLimitStatus(settings: settings)
    
    // Calculate lookback dates
    let date7DaysAgo = calendar.date(byAdding: .day, value: -7, to: date) ?? date
    let dateRollingAgo = calendar.date(byAdding: .day, value: -settings.rollingPeriodDays, to: date) ?? date
    let date365DaysAgo = calendar.date(byAdding: .day, value: -365, to: date) ?? date
    
    // Get all operating trips
    let operatingTrips = store.trips.filter { $0.tripType == .operating }
    
    // Track totals
    var flightTime7Day: Double = 0
    var dutyTime7Day: Double = 0
    var dutyTimeRolling: Double = 0
    
    // *** CRITICAL FIX: Use leg.flightDate ?? trip.date for each leg ***
    // This matches how Rolling30DayComplianceView should calculate (per-leg dates)
    for trip in operatingTrips {
        let tripDate = trip.date
        
        // Duty hours still use trip date (duty is for the whole trip, not per leg)
        let dutyHours = trip.totalDutyHours
        
        // But flight time must be calculated PER LEG using each leg's actual date
        for leg in trip.legs {
            let legDate = leg.flightDate ?? tripDate  // Use leg's actual flight date
            let legBlockHours = Double(leg.blockMinutes()) / 60.0
            
            // 7-day flight time calculations (per leg date)
            if legDate >= date7DaysAgo && legDate <= date {
                flightTime7Day += legBlockHours
            }
            
            // Rolling period flight time (per leg date)
            if settings.flightTimeRolling.enabled && legDate >= dateRollingAgo && legDate <= date {
                status.flightTimeRolling += legBlockHours
            }
            
            // 7-day flight time (if that specific limit enabled, per leg date)
            if settings.flightTime7Day.enabled && legDate >= date7DaysAgo && legDate <= date {
                status.flightTime7Day += legBlockHours
            }
            
            // 365-day flight time (per leg date)
            if settings.flightTime365Day.enabled && legDate >= date365DaysAgo && legDate <= date {
                status.flightTime365Day += legBlockHours
            }
        }
        
        // Duty time calculations still use trip date
        if tripDate >= date7DaysAgo && tripDate <= date {
            dutyTime7Day += dutyHours
        }
        
        if tripDate >= dateRollingAgo && tripDate <= date {
            dutyTimeRolling += dutyHours
        }
    }
    
    // Calculate per-FDP flight time
    if settings.perFDPFlightLimit.enabled {
        // Check if currently in rest (either manual timer or auto-detected from trips)
        let isInRestFromTimer = DutyTimerManager.shared.isInRest || !DutyTimerManager.shared.isOnDuty
        let isInRestFromTrips = isCurrentlyInRest(store: store, minRestHours: settings.restRequirement.minimumRestHours)

        if isInRestFromTimer || isInRestFromTrips {
            // Not on duty = no active FDP = 0 hours
            status.currentFDPFlightTime = 0.0
            status.isInRest = true
        } else {
            // On duty - calculate flight time since last rest
            status.currentFDPFlightTime = calculateCurrentFDPFlightTime(
                for: date,
                store: store,
                resetsAfterRest: settings.perFDPFlightLimit.resetsAfterRest
            )
            status.isInRest = false
        }

        let hour = calendar.component(.hour, from: date)
        status.isDayReportTime = (hour >= 5 && hour < 20)
    }
    
    // FDP times - Use ACTUAL DUTY HOURS (not flight time)
    if settings.fdp7Day.enabled {
        status.fdpTime7Day = dutyTime7Day  // Actual duty hours!
    }
    
    if settings.fdpRolling.enabled {
        status.fdpTimeRolling = dutyTimeRolling
    }
    
    // DEBUG: Print rolling flight time calculation (DISABLED - was causing excessive logging)
    // This gets called every time a row is rendered, which can be 50+ times on a scroll
    // Uncomment only if you need to debug a specific calculation issue
    /*
    if settings.flightTimeRolling.enabled {
        print("\n🔍 30-Day Rolling Calculation:")
        print("   Period: Last \(settings.rollingPeriodDays) days")
        print("   Total Flight Time: \(String(format: "%.1f", status.flightTimeRolling)) hrs")
        print("   Limit: \(settings.flightTimeRolling.hours) hrs")
        print("   Remaining: \(String(format: "%.1f", settings.flightTimeRolling.hours - status.flightTimeRolling)) hrs")
        print("   Percentage: \(String(format: "%.0f", (status.flightTimeRolling / settings.flightTimeRolling.hours) * 100))%")
        if status.flightTimeRolling < 0 {
            print("   ⚠️ NEGATIVE FLIGHT TIME DETECTED!")
        }
    }
    */
    
    return status
}

/// Calculate flight time in current FDP (since last rest period)
@MainActor
private func calculateCurrentFDPFlightTime(for date: Date, store: SwiftDataLogBookStore, resetsAfterRest: Bool) -> Double {
    let calendar = Calendar.current
    let settings = DutyLimitSettingsStore.shared.configuration

    guard resetsAfterRest else {
        // If doesn't reset, use 24-hour lookback
        let date24HoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        return calculateFlightTimeInWindow(from: date24HoursAgo, to: date, store: store)
    }

    // Build a chronological list of all leg times (OUT and IN) to find rest gaps
    var legTimes: [(outTime: Date, inTime: Date)] = []

    let operatingTrips = store.trips.filter { $0.tripType == .operating }

    for trip in operatingTrips {
        for leg in trip.legs {
            let legDate = leg.flightDate ?? trip.date

            guard let outDateTime = parseTimeWithDateForLimits(timeString: leg.outTime, date: legDate) else {
                continue
            }

            // For IN time, detect overnight flights and add a day if needed
            var inDate = legDate
            if !leg.outTime.isEmpty && !leg.inTime.isEmpty {
                if let outHour = parseHourFromTimeString(leg.outTime),
                   let inHour = parseHourFromTimeString(leg.inTime) {
                    if outHour >= 12 && inHour < 12 {
                        inDate = calendar.date(byAdding: .day, value: 1, to: legDate) ?? legDate
                    }
                }
            }

            guard let inDateTime = parseTimeWithDateForLimits(timeString: leg.inTime, date: inDate) else {
                continue
            }

            legTimes.append((outTime: outDateTime, inTime: inDateTime))
        }
    }

    // Sort by OUT time chronologically
    legTimes.sort { $0.outTime < $1.outTime }

    // Find the most recent rest period by looking for gaps >= minimum rest hours
    // Work backwards from now to find where the current FDP started
    var fdpStartTime: Date? = nil
    let minRestHours = settings.restRequirement.minimumRestHours

    // Filter to only legs before now
    let pastLegs = legTimes.filter { $0.inTime <= date }

    if pastLegs.count > 1 {
        // Check gaps between consecutive legs (from most recent going backwards)
        for i in stride(from: pastLegs.count - 1, through: 1, by: -1) {
            let currentLegOut = pastLegs[i].outTime
            let previousLegIn = pastLegs[i - 1].inTime

            let gapHours = currentLegOut.timeIntervalSince(previousLegIn) / 3600.0

            if gapHours >= minRestHours {
                // Found a rest period! FDP started at this leg's OUT time
                fdpStartTime = currentLegOut
                break
            }
        }
    }

    // If no rest found, or only one leg, use 24-hour lookback as fallback
    let startDate = fdpStartTime ?? calendar.date(byAdding: .hour, value: -24, to: date) ?? date
    return calculateFlightTimeInWindow(from: startDate, to: date, store: store)
}

/// Calculate flight time within a specific window
@MainActor
private func calculateFlightTimeInWindow(from startDate: Date, to endDate: Date, store: SwiftDataLogBookStore) -> Double {
    var totalMinutes = 0
    let calendar = Calendar.current

    for trip in store.trips where trip.tripType == .operating {
        for leg in trip.legs {
            // Use leg.flightDate for the OUT time's date
            let legDate = leg.flightDate ?? trip.date

            guard let outDateTime = parseTimeWithDateForLimits(timeString: leg.outTime, date: legDate) else {
                continue
            }

            // For IN time, detect overnight flights and add a day if needed
            var inDate = legDate
            if !leg.outTime.isEmpty && !leg.inTime.isEmpty {
                if let outHour = parseHourFromTimeString(leg.outTime),
                   let inHour = parseHourFromTimeString(leg.inTime) {
                    // Overnight detection: OUT in afternoon/evening (12+), IN in early morning (0-11)
                    if outHour >= 12 && inHour < 12 {
                        inDate = calendar.date(byAdding: .day, value: 1, to: legDate) ?? legDate
                    }
                }
            }

            guard let inDateTime = parseTimeWithDateForLimits(timeString: leg.inTime, date: inDate) else {
                continue
            }

            // Only count completed legs within the window
            if outDateTime >= startDate && inDateTime <= endDate {
                totalMinutes += leg.blockMinutes()
            }
        }
    }

    return Double(totalMinutes) / 60.0
}

/// Parse hour component from time string (helper for overnight detection)
private func parseHourFromTimeString(_ timeString: String) -> Int? {
    let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTime.isEmpty else { return nil }

    let cleanedTime = trimmedTime
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".", with: "")

    if cleanedTime.count == 4 {
        return Int(cleanedTime.prefix(2))
    } else if cleanedTime.count == 3 {
        return Int(cleanedTime.prefix(1))
    } else if cleanedTime.count == 1 || cleanedTime.count == 2 {
        return Int(cleanedTime)
    }

    return nil
}

/// Check if currently in rest period based on trip data
/// Returns true if the last flight ended more than minRestHours ago
@MainActor
private func isCurrentlyInRest(store: SwiftDataLogBookStore, minRestHours: Double) -> Bool {
    let calendar = Calendar.current
    let now = Date()

    // Find the most recent IN time from all operating trips
    var mostRecentInTime: Date? = nil

    for trip in store.trips where trip.tripType == .operating {
        for leg in trip.legs {
            let legDate = leg.flightDate ?? trip.date

            // Parse IN time with overnight detection
            var inDate = legDate
            if !leg.outTime.isEmpty && !leg.inTime.isEmpty {
                if let outHour = parseHourFromTimeString(leg.outTime),
                   let inHour = parseHourFromTimeString(leg.inTime) {
                    if outHour >= 12 && inHour < 12 {
                        inDate = calendar.date(byAdding: .day, value: 1, to: legDate) ?? legDate
                    }
                }
            }

            guard let inDateTime = parseTimeWithDateForLimits(timeString: leg.inTime, date: inDate) else {
                continue
            }

            // Only consider past flights
            if inDateTime <= now {
                if mostRecentInTime == nil || inDateTime > mostRecentInTime! {
                    mostRecentInTime = inDateTime
                }
            }
        }
    }

    // If no flights found, assume in rest
    guard let lastIn = mostRecentInTime else {
        return true
    }

    // Check if time since last IN >= minimum rest hours
    let hoursSinceLastFlight = now.timeIntervalSince(lastIn) / 3600.0
    return hoursSinceLastFlight >= minRestHours
}

/// Parse time string with date for limit calculations
func parseTimeWithDateForLimits(timeString: String, date: Date) -> Date? {
    let trimmedTime = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTime.isEmpty else { return nil }
    
    let calendar = Calendar.current
    let cleanedTime = trimmedTime
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".", with: "")
    
    var hours: Int?
    var minutes: Int?
    
    if cleanedTime.count == 4 {
        hours = Int(cleanedTime.prefix(2))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count == 3 {
        hours = Int(cleanedTime.prefix(1))
        minutes = Int(cleanedTime.suffix(2))
    } else if cleanedTime.count == 1 || cleanedTime.count == 2 {
        hours = Int(cleanedTime)
        minutes = 0
    }
    
    guard let validHours = hours,
          let validMinutes = minutes,
          validHours >= 0 && validHours <= 23,
          validMinutes >= 0 && validMinutes <= 59 else {
        return nil
    }
    
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = validHours
    components.minute = validMinutes
    components.second = 0
    
    return calendar.date(from: components)
}

// MARK: - Configurable Limits Status View
/// Updated status view that uses configurable settings
struct ConfigurableLimitsStatusView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @StateObject private var settingsStore = DutyLimitSettingsStore.shared
    @StateObject private var offDutyManager = OffDutyStatusManager.shared
    @StateObject private var dutyTimerManager = DutyTimerManager.shared
    @State private var showingLimitsDetail = false
    @State private var showingSettings = false
    @AppStorage("limitsStatusExpanded") private var isExpanded: Bool = true

    @State private var preparedStatus: ConfigurableLimitStatus? = nil
    @State private var currentTime = Date()

    // Timer to update countdown every 60 seconds
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var currentStatus: ConfigurableLimitStatus {
        calculateConfigurableLimits(for: Date(), store: store)
    }

    private var statusColor: Color {
        if currentStatus.criticalWarning { return .red }
        if currentStatus.showWarning { return .orange }
        return .green
    }

    var body: some View {
        // Don't show if tracking disabled or Part 91
        if !settingsStore.trackingEnabled || settingsStore.configuration.operationType == .part91 {
            EmptyView()
        } else {
            mainContent
                .onReceive(timer) { _ in
                    currentTime = Date()
                }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                headerContent
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded view
            if isExpanded {
                expandedContent
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.6), lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                // Prepare a fully calculated status before presenting the sheet
                let status = calculateConfigurableLimits(for: Date(), store: store)
                preparedStatus = status
                showingLimitsDetail = true
            }
        }
        .sheet(isPresented: $showingLimitsDetail) {
            let statusToShow = preparedStatus ?? calculateConfigurableLimits(for: Date(), store: store)
            ConfigurableLimitsDetailView(status: statusToShow, tripDate: Date())
        }
        .sheet(isPresented: $showingSettings) {
            DutyLimitSettingsView()
        }
    }
    
    private var headerContent: some View {
        HStack {
            Image(systemName: "gauge.high")
                .foregroundColor(statusColor)
            
            Text("Flight Time Limits")
                .font(.headline)
                .foregroundColor(.white)
            
            // Operation type badge
            Text(settingsStore.configuration.operationType.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(LogbookTheme.accentBlue.opacity(0.3))
                .cornerRadius(4)
            
            Spacer()
            
            // Settings button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 8)
            
            if !isExpanded {
                compactStatusView
            }
            
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            Divider()
                .background(statusColor.opacity(0.3))
                .padding(.horizontal, 16)

            // Determine if we should show rest banner vs normal limits
            // Check if truly "on duty" - must have duty timer running AND start time within 24 hours
            let hasValidDutyPeriod: Bool = {
                guard dutyTimerManager.isOnDuty,
                      let startTime = dutyTimerManager.dutyStartTime else {
                    return false
                }
                // Duty periods can't be longer than 24 hours - if start time is older, it's stale
                let hoursSinceStart = Date().timeIntervalSince(startTime) / 3600
                return hoursSinceStart < 24
            }()

            // Priority 1: If OffDutyManager says we're off duty (from NOC calendar)
            // Priority 2: If DutyTimerManager says we're in rest
            // Priority 3: If no valid duty period is running
            if offDutyManager.isOffDuty {
                restBannerView
            } else if dutyTimerManager.isInRest {
                restBannerView
            } else if !hasValidDutyPeriod {
                // No valid duty period - show rest banner
                restBannerView
            } else {
                // Valid duty period in progress - show normal limits
                normalLimitsView
            }
        }
    }
    
    // MARK: - OFF Duty Banner (DISABLED - Manager doesn't exist yet)
    private var offDutyBannerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("OFF DUTY")
                    .font(.headline.bold())
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            
            Text("Currently Off Duty")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    // MARK: - REST Banner
    private var restBannerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("OFF DUTY / REST")
                    .font(.headline.bold())
                    .foregroundColor(.purple)

                Spacer()
            }

            // Show countdown to next duty if available from NOC calendar
            if let timeUntilDuty = offDutyManager.formattedTimeUntilDuty {
                VStack(spacing: 4) {
                    Text("Back on duty in")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Text(timeUntilDuty)
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    if let nextDutyTime = offDutyManager.formattedNextDutyTime {
                        Text("(\(nextDutyTime))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            // Show rest elapsed time if duty timer is tracking rest
            else if let restStart = dutyTimerManager.restStartTime {
                // Use currentTime state to force refresh on timer tick
                let restElapsed = currentTime.timeIntervalSince(restStart)
                let hours = Int(restElapsed) / 3600
                let minutes = (Int(restElapsed) % 3600) / 60

                VStack(spacing: 4) {
                    Text("In rest for")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Text(String(format: "%dh %02dm", hours, minutes))
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("(Legal rest: 10h minimum)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            // Fallback: just show "Not Currently On Duty"
            else {
                Text("Not Currently On Duty")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                Text("Per-FDP flight time will start counting when you begin a new duty period")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    // MARK: - Normal Limits View
    private var normalLimitsView: some View {
        HStack(spacing: 4) {  // Reduced from 12
            if settingsStore.configuration.perFDPFlightLimit.enabled {
                ConfigurableLimitDisplay(
                    label: "Blk",  // Block time this FDP
                    current: currentStatus.currentFDPFlightTime,
                    limit: currentStatus.perFDPLimit,
                    threshold: settingsStore.configuration.warningThresholdPercent
                )
            }

            if settingsStore.configuration.flightTimeRolling.enabled {
                ConfigurableLimitDisplay(
                    label: "\(settingsStore.configuration.rollingPeriodDays)d Blk",  // Rolling block time
                    current: currentStatus.flightTimeRolling,
                    limit: settingsStore.configuration.flightTimeRolling.hours,
                    threshold: settingsStore.configuration.warningThresholdPercent
                )
            }

            if settingsStore.configuration.fdp7Day.enabled {
                ConfigurableLimitDisplay(
                    label: "7d Duty",  // 7-day duty time
                    current: currentStatus.fdpTime7Day,
                    limit: settingsStore.configuration.fdp7Day.hours,
                    threshold: settingsStore.configuration.warningThresholdPercent
                )
            }

            if settingsStore.configuration.flightTime365Day.enabled {
                ConfigurableLimitDisplay(
                    label: "Annual",  // Annual block time
                    current: currentStatus.flightTime365Day,
                    limit: settingsStore.configuration.flightTime365Day.hours,
                    threshold: settingsStore.configuration.warningThresholdPercent
                )
            }
        }
        .padding(.horizontal, 8)  // Reduced from 16
        .padding(.vertical, 12)
    }
    
    private var compactStatusView: some View {
        HStack(spacing: 8) {
            if settingsStore.configuration.flightTimeRolling.enabled {
                let limit = settingsStore.configuration.flightTimeRolling.hours
                Text(String(format: "%.0f", currentStatus.flightTimeRolling))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(currentStatus.flightTimeRolling / limit >= settingsStore.configuration.warningThresholdPercent ? .orange : .green)
                
                Text("/")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text("\(Int(limit))h")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Image(systemName: currentStatus.criticalWarning ? "exclamationmark.triangle.fill" :
                              currentStatus.showWarning ? "exclamationmark.circle.fill" :
                              "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(statusColor)
        }
        .padding(.trailing, 8)
    }
}

// MARK: - Configurable Limit Display
struct ConfigurableLimitDisplay: View {
    let label: String
    let current: Double
    let limit: Double
    let threshold: Double
    
    private var safeLimit: Double { max(0, limit) }
    private var safeCurrent: Double { max(0, current) }
    private var ratio: Double {
        guard safeLimit > 0 else { return 0 }
        return min(max(safeCurrent / safeLimit, 0), 1)
    }
    
    private var isWarning: Bool {
        guard safeLimit > 0 else { return false }
        return (safeCurrent / safeLimit) >= threshold
    }
    
    private var isCritical: Bool {
        guard safeLimit > 0 else { return false }
        return (safeCurrent / safeLimit) >= 0.95
    }
    
    private var isOverLimit: Bool {
        return safeCurrent > safeLimit
    }
    
    private var displayColor: Color {
        if isOverLimit { return .red }
        if isCritical { return .red }
        if isWarning { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(String(format: "%.0f", safeCurrent))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(displayColor)
                Text("/\(formatLimit(safeLimit))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatLimit(_ value: Double) -> String {
        if value >= 1000 {
            return "1kh"
        } else {
            return "\(Int(value))h"
        }
    }
}

// MARK: - Configurable Limits Detail View
struct ConfigurableLimitsDetailView: View {
    let status: ConfigurableLimitStatus
    let tripDate: Date
    @Environment(\.dismiss) var dismiss
    @StateObject private var settingsStore = DutyLimitSettingsStore.shared
    
    var body: some View {
        NavigationView {
            List {
                // Settings Link
                Section {
                    NavigationLink(destination: DutyLimitSettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .font(.title2)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Configure Limits")
                                    .font(.headline)
                                
                                Text("Adjust for your operation type")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Chart Link
                Section {
                    NavigationLink(destination: FAR121ComplianceView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Visual Timeline Chart")
                                    .font(.headline)
                                
                                Text("See when hours drop off")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Current Limits
                Section("Current Status - \(settingsStore.configuration.operationType.rawValue)") {
                    ForEach(status.getAllLimitStatuses(), id: \.name) { limitStatus in
                        ConfigurableLimitRow(status: limitStatus)
                    }
                }
                
                // Legend
                Section("Legend") {
                    HStack {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("Within limits")
                    }
                    HStack {
                        Circle().fill(Color.orange).frame(width: 10, height: 10)
                        Text("Approaching limit (\(Int(settingsStore.configuration.warningThresholdPercent * 100))%+)")
                    }
                    HStack {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Critical (\(Int(settingsStore.configuration.criticalThresholdPercent * 100))%+)")
                    }
                }
            }
            .navigationTitle("Flight Time Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ConfigurableLimitRow: View {
    let status: LimitStatus
    
    // Calculate time elapsed since going off duty (DISABLED - managers don't exist)
    private var offDutyElapsedText: String {
        return ""
    }
    
    // Calculate time elapsed since going into rest (DISABLED - managers don't exist)
    private var restElapsedText: String {
        return ""
    }
    
    // Safe computed helpers
    private var safeLimit: Double { max(0, status.limit) }
    private var safeCurrent: Double { max(0, status.current) }
    private var cappedPercentage: Double {
        guard safeLimit > 0 else { return 0 }
        return min(max((safeCurrent / safeLimit) * 100.0, 0), 100)
    }
    private var remainingClamped: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeLimit - safeCurrent)
    }
    private var overBy: Double {
        guard safeLimit > 0 else { return 0 }
        return max(0, safeCurrent - safeLimit)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.name)
                    .font(.headline)
                Spacer()
                Text(status.regulation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(String(format: "%.1f hrs", status.current))
                    .font(.title2.bold())
                    .foregroundColor(status.statusColor)
                
                Text("of \(Int(status.limit)) hrs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", cappedPercentage))
                    .font(.title3.bold())
                    .foregroundColor(status.statusColor)
            }
            
            ProgressView(value: min(safeCurrent, safeLimit), total: max(safeLimit, 1))
                .tint(status.statusColor)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Show status for all limit types
            if status.name == "Per-FDP Flight Time" {
                // For Per-FDP, check if off duty
                if DutyTimerManager.shared.isInRest || !DutyTimerManager.shared.isOnDuty {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("OFF DUTY / REST")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                } else {
                    if safeCurrent <= safeLimit {
                        Text("\(status.periodDescription) • \(String(format: "%.1f", remainingClamped)) hrs remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(status.periodDescription) • Over by \(String(format: "%.1f", overBy)) hrs")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else {
                // For other limit types, show normal period info
                if safeCurrent <= safeLimit {
                    Text("\(status.periodDescription) • \(String(format: "%.1f", remainingClamped)) hrs remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(status.periodDescription) • Over by \(String(format: "%.1f", overBy)) hrs")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Configurable Limits Bar (for trip rows)
struct ConfigurableLimitsBar: View {
    let status: ConfigurableLimitStatus
    @StateObject private var settingsStore = DutyLimitSettingsStore.shared
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.criticalWarning ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.caption2)
                    .foregroundColor(status.criticalWarning ? .red : .orange)
                
                Text("Flight Time Limits")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Tap for details")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 6) {
                if settingsStore.configuration.perFDPFlightLimit.enabled {
                    SmallLimitIndicator(
                        label: "FDP",
                        current: status.currentFDPFlightTime,
                        limit: status.perFDPLimit,
                        threshold: settingsStore.configuration.warningThresholdPercent
                    )
                }
                
                if settingsStore.configuration.flightTimeRolling.enabled {
                    SmallLimitIndicator(
                        label: "\(settingsStore.configuration.rollingPeriodDays)d",
                        current: status.flightTimeRolling,
                        limit: settingsStore.configuration.flightTimeRolling.hours,
                        threshold: settingsStore.configuration.warningThresholdPercent
                    )
                }
                
                if settingsStore.configuration.fdp7Day.enabled {
                    SmallLimitIndicator(
                        label: "7d FDP",
                        current: status.fdpTime7Day,
                        limit: settingsStore.configuration.fdp7Day.hours,
                        threshold: settingsStore.configuration.warningThresholdPercent
                    )
                }
            }
        }
        .padding(8)
        .background(status.criticalWarning ? Color.red.opacity(0.2) : Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}

struct SmallLimitIndicator: View {
    let label: String
    let current: Double
    let limit: Double
    let threshold: Double
    
    private var safeLimit: Double { max(0, limit) }
    private var safeCurrent: Double { max(0, current) }
    private var fillRatio: Double {
        guard safeLimit > 0 else { return 0 }
        return min(max(safeCurrent / safeLimit, 0), 1)
    }
    
    private var isWarning: Bool {
        guard safeLimit > 0 else { return false }
        return (safeCurrent / safeLimit) >= threshold
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(isWarning ? Color.red : Color.green)
                    .frame(width: fillRatio * 40, height: 4)
            }
            .frame(width: 40)
            
            Text(String(format: "%.0f", safeCurrent))
                .font(.caption2.bold())
                .foregroundColor(isWarning ? .red : .white)
        }
    }
}

// MARK: - Duty Start Time Editor

/// Editable duty start time view for trip detail
struct DutyStartTimeEditor: View {
    @Binding var trip: Trip
    @State private var showingTimePicker = false
    @State private var selectedTime: Date = Date()
    
    private var displayTime: String {
        guard let dutyStart = trip.effectiveDutyStartTime else {
            return "Not Set"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dutyStart)
    }
    
    private var isAutoCalculated: Bool {
        trip.dutyStartTime == nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.orange)
                
                Text("Duty Start Time")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isAutoCalculated {
                    Text("Auto")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(4)
                }
            }
            
            HStack {
                // Time display
                Button(action: {
                    // Initialize picker with current effective time
                    if let dutyStart = trip.effectiveDutyStartTime {
                        selectedTime = dutyStart
                    } else {
                        selectedTime = Date()
                    }
                    showingTimePicker = true
                }) {
                    HStack {
                        Text(displayTime)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Reset to auto button
                if !isAutoCalculated {
                    Button(action: {
                        trip.dutyStartTime = nil  // Reset to auto-calculate
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Auto")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                    }
                }
            }
            
            // Info text
            if isAutoCalculated {
                Text("Calculated as 1 hour before first OUT time")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("Manually set - tap Auto to recalculate")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .sheet(isPresented: $showingTimePicker) {
            DutyTimePickerSheet(
                selectedTime: $selectedTime,
                tripDate: trip.date,
                onSave: { newTime in
                    trip.dutyStartTime = newTime
                    showingTimePicker = false
                },
                onCancel: {
                    showingTimePicker = false
                }
            )
        }
    }
}

/// Time picker sheet for duty start time
struct DutyTimePickerSheet: View {
    @Binding var selectedTime: Date
    let tripDate: Date
    let onSave: (Date) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Set Duty Start Time")
                    .font(.title2.bold())
                    .padding(.top)
                
                Text(tripDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                DatePicker(
                    "Duty Start",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                // Quick presets
                VStack(spacing: 12) {
                    Text("Quick Presets")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        PresetButton(title: "-2h", offset: -120, tripDate: tripDate, selectedTime: $selectedTime)
                        PresetButton(title: "-1.5h", offset: -90, tripDate: tripDate, selectedTime: $selectedTime)
                        PresetButton(title: "-1h", offset: -60, tripDate: tripDate, selectedTime: $selectedTime)
                        PresetButton(title: "-45m", offset: -45, tripDate: tripDate, selectedTime: $selectedTime)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedTime)
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PresetButton: View {
    let title: String
    let offset: Int  // minutes before first OUT
    let tripDate: Date
    @Binding var selectedTime: Date
    
    var body: some View {
        Button(action: {
            // This would ideally use first OUT time, but for now just adjust current selection
            if let adjusted = Calendar.current.date(byAdding: .minute, value: offset, to: selectedTime) {
                selectedTime = adjusted
            }
        }) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(8)
        }
    }
}

// MARK: - Duty Timer Integration Display

/// Shows live duty timer status for active trip
struct LiveDutyTimerDisplay: View {
    @ObservedObject var dutyTimerManager = DutyTimerManager.shared
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: dutyTimerManager.isOnDuty ? "timer.circle.fill" : "timer.circle")
                    .foregroundColor(dutyTimerManager.isOnDuty ? .green : .gray)
                    .font(.title3)
                
                Text("Live Duty Timer")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if dutyTimerManager.isOnDuty {
                    Text("ACTIVE")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            if dutyTimerManager.isOnDuty {
                VStack(spacing: 12) {
                    // Elapsed time
                    HStack {
                        Text("Duty Time Elapsed:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(dutyTimerManager.formattedElapsedTime())
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Time remaining
                    HStack {
                        Text("Time Remaining:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(dutyTimerManager.formattedTimeRemaining())
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(dutyStatusColor)
                    }
                    
                    // Status indicator
                    HStack {
                        Image(systemName: dutyTimerManager.dutyStatus().icon)
                            .foregroundColor(dutyTimerManager.dutyStatus().color)
                        Text(dutyStatusText)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Info text
                    Text("This duty time will be automatically saved when you complete Trip #\(trip.tripNumber)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
            } else {
                Text("No active duty timer. Duty times will be auto-calculated from flight times.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var dutyStatusColor: Color {
        switch dutyTimerManager.dutyStatus() {
        case .notOnDuty: return .gray
        case .normal: return .green
        case .warning: return .orange
        case .criticalWarning, .limitReached: return .red
        }
    }
    
    private var dutyStatusText: String {
        switch dutyTimerManager.dutyStatus() {
        case .notOnDuty: return "Not on duty"
        case .normal: return "Within limits"
        case .warning: return "Approaching limit"
        case .criticalWarning: return "Critical - approaching limit"
        case .limitReached: return "⚠️ LIMIT EXCEEDED"
        }
    }
}

/// Compact duty time summary for completed trips
struct CompletedDutyTimeSummary: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.blue)
                
                Text("Duty Time Summary")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if trip.dutyStartTime != nil {
                    Text("Recorded")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Text("Auto-Calc")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            VStack(spacing: 8) {
                // Duty period
                if let start = trip.effectiveDutyStartTime, let end = trip.effectiveDutyEndTime {
                    HStack {
                        Text("Duty Period:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(start.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .monospaced))
                            Text("to")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(end.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .monospaced))
                        }
                        .foregroundColor(.white)
                    }
                }
                
                // Total duty hours
                HStack {
                    Text("Total Duty Time:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.2f hours", trip.totalDutyHours))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Comparison to flight time
                let blockHours = Double(trip.totalBlockMinutes) / 60.0
                let dutyOverhead = trip.totalDutyHours - blockHours
                HStack {
                    Text("Pre/Post Flight Time:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "+%.1f hours", dutyOverhead))
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}



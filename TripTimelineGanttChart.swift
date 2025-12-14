//
//  TripTimelineGanttChart.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/6/25.
//  Fixed: Bars now extend full 30 days continuously from left to right

import SwiftUI
import Charts

// MARK: - Trip Timeline Gantt Chart View
struct TripTimelineGanttChart: View {
    let logbookStore: LogBookStore
    @State private var selectedTrip: TripGanttData?
    
    private var ganttData: [TripGanttData] {
        calculateGanttData()
    }
    
    private var nextRestoration: (date: Date, hours: Double)? {
        // Get the soonest drop-off that's in the future
        ganttData
            .filter { $0.dropOffInfo.date > Date() }
            .sorted { $0.dropOffInfo.date < $1.dropOffInfo.date }
            .first?.dropOffInfo
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Enhanced Summary Header
            summaryHeader
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // MARK: - Gantt Chart
            ScrollView(.horizontal, showsIndicators: true) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Timeline header
                        timelineHeader
                        
                        // Trip bars - sorted by flight date (most recent at top)
                        ForEach(ganttData) { tripData in
                            TripGanttRow(
                                tripData: tripData,
                                dateRange: dateRange,
                                totalDays: totalDays,
                                isSelected: selectedTrip?.id == tripData.id,
                                onTap: {
                                    withAnimation {
                                        selectedTrip = selectedTrip?.id == tripData.id ? nil : tripData
                                    }
                                }
                            )
                        }
                        
                        // Empty state
                        if ganttData.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No trips in the last 30 days")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Completed trips will appear here")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                }
                .frame(minHeight: 400)
            }
            
            // MARK: - Selected Trip Details
            if let selected = selectedTrip {
                selectedTripDetails(selected)
            }
        }
    }
    
    // MARK: - Summary Header
    private var summaryHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date(), style: .date)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let next = nextRestoration {
                        Text("Next restore: +\(String(format: "%.1f", next.hours))h on \(next.date, style: .date)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("No upcoming restorations")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.1f", currentTotal))")
                            .font(.title.bold())
                            .foregroundColor(statusColor)
                        Text("/ 100 hrs")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(String(format: "%.1f", max(0, 100 - currentTotal))) hrs available")
                        .font(.caption)
                        .foregroundColor(100 - currentTotal > 10 ? .green : .orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    // MARK: - Timeline Header
    private var timelineHeader: some View {
        HStack(spacing: 0) {
            // Left label space
            Color.clear
                .frame(width: 180)
            
            // Timeline
            ZStack(alignment: .topLeading) {
                // Background grid lines
                ForEach(dateMarkers, id: \.self) { date in
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 1)
                        .offset(x: xPosition(for: date))
                }
                
                // Date labels
                ForEach(dateMarkers, id: \.self) { date in
                    Text(formatDateLabel(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(x: xPosition(for: date) - 15)
                }
                .offset(y: 5)
                
                // TODAY marker
                VStack(spacing: 0) {
                    Text("TODAY")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 2, height: 40)
                }
                .offset(x: xPosition(for: Date()) - 15, y: 20)
                
                // Restoration markers (when hours come back)
                ForEach(Array(restorationMarkers.enumerated()), id: \.offset) { index, marker in
                    if marker.date > Date() { // Only show future restorations
                        VStack(spacing: 2) {
                            Text("+\(String(format: "%.1f", marker.hours))h")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .offset(x: xPosition(for: marker.date) - 20, y: 22)
                    }
                }
            }
            .frame(width: CGFloat(totalDays) * pointsPerDay, height: 60)
        }
        .frame(height: 60)
        .background(Color(.systemGray6).opacity(0.2))
    }
    
    // MARK: - Selected Trip Details
    private func selectedTripDetails(_ tripData: TripGanttData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trip Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { selectedTrip = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tripData.tripNumber)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    Text(tripData.route)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(tripData.pilotRole) • \(tripData.aircraft)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Flown: \(tripData.flightDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", tripData.blockHours)) hrs")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    
                    if tripData.daysUntilDropOff > 0 {
                        Text("Drops in \(tripData.daysUntilDropOff) days")
                            .font(.caption)
                            .foregroundColor(tripData.ageColor)
                    } else {
                        Text("Dropped off")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Drop: \(tripData.dropOffInfo.date, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Constants
    private let pointsPerDay: CGFloat = 25 // Width per day in points
    
    // MARK: - Calculations
    
    private var currentTotal: Double {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        let recentTrips = operatingTrips.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        
        return recentTrips.reduce(0.0) { total, trip in
            total + (Double(trip.totalBlockMinutes) / 60.0)
        }
    }
    
    private var statusColor: Color {
        if currentTotal >= 100 { return .red }
        if currentTotal >= 90 { return .orange }
        if currentTotal >= 80 { return .yellow }
        return .green
    }
    
    private func calculateGanttData() -> [TripGanttData] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get trips from the last 30 days that are still "in the bank"
        // A trip is in the bank if it was flown within the last 30 days
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        let operatingTrips = logbookStore.trips.filter { $0.tripType == .operating }
        let recentTrips = operatingTrips.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        
        // Sort by flight date - most recent at TOP
        let sortedTrips = recentTrips.sorted { $0.date > $1.date }
        
        return sortedTrips.map { trip in
            let blockHours = Double(trip.totalBlockMinutes) / 60.0
            let dropOffDate = calendar.date(byAdding: .day, value: 30, to: trip.date)!
            let daysUntil = max(0, calendar.dateComponents([.day], from: today, to: dropOffDate).day ?? 0)
            
            return TripGanttData(
                id: trip.id,
                tripNumber: trip.displayTitle,
                route: trip.fullRouteString,
                aircraft: trip.aircraft,
                pilotRole: trip.pilotRole.rawValue,
                flightDate: trip.date,
                blockHours: blockHours,
                dropOffInfo: (date: dropOffDate, hours: blockHours),
                daysUntilDropOff: daysUntil
            )
        }
    }
    
    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = Date()
        // Show from 35 days ago to 35 days in future (70 day window)
        let start = calendar.date(byAdding: .day, value: -35, to: today)!
        let end = calendar.date(byAdding: .day, value: 35, to: today)!
        return (start, end)
    }
    
    private var totalDays: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 70
    }
    
    private var dateMarkers: [Date] {
        let calendar = Calendar.current
        var markers: [Date] = []
        var current = dateRange.start
        
        // Every 7 days
        while current <= dateRange.end {
            markers.append(current)
            current = calendar.date(byAdding: .day, value: 7, to: current)!
        }
        
        return markers
    }
    
    private var restorationMarkers: [(date: Date, hours: Double)] {
        // Group drop-offs by date and sum hours
        var markers: [Date: Double] = [:]
        for data in ganttData {
            let day = Calendar.current.startOfDay(for: data.dropOffInfo.date)
            markers[day, default: 0] += data.dropOffInfo.hours
        }
        return markers.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    
    private func xPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: dateRange.start, to: date).day ?? 0
        return CGFloat(daysSinceStart) * pointsPerDay
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Trip Gantt Row
struct TripGanttRow: View {
    let tripData: TripGanttData
    let dateRange: (start: Date, end: Date)
    let totalDays: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    private let pointsPerDay: CGFloat = 25
    
    var body: some View {
        HStack(spacing: 0) {
            // Left label
            VStack(alignment: .leading, spacing: 2) {
                Text(tripData.tripNumber)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(tripData.route)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("\(String(format: "%.1f", tripData.blockHours))h")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                    
                    if tripData.daysUntilDropOff > 0 {
                        Text("• \(tripData.daysUntilDropOff)d left")
                            .font(.caption2)
                            .foregroundColor(tripData.ageColor)
                    }
                }
            }
            .frame(width: 180, alignment: .leading)
            .padding(.leading, 8)
            .padding(.vertical, 4)
            
            // Gantt bar area
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.clear)
                
                // The 30-day bar
                ContinuousTripBar(
                    tripData: tripData,
                    dateRange: dateRange,
                    pointsPerDay: pointsPerDay
                )
            }
            .frame(width: CGFloat(totalDays) * pointsPerDay)
        }
        .frame(height: 55)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Continuous Trip Bar (Full 30-day span)
struct ContinuousTripBar: View {
    let tripData: TripGanttData
    let dateRange: (start: Date, end: Date)
    let pointsPerDay: CGFloat
    
    private var startX: CGFloat {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: dateRange.start, to: tripData.flightDate).day ?? 0
        return CGFloat(max(0, daysSinceStart)) * pointsPerDay
    }
    
    private var barWidth: CGFloat {
        // Bar spans exactly 30 days
        return 30.0 * pointsPerDay
    }
    
    private var solidWidth: CGFloat {
        // Solid portion represents block hours (as fraction of 24 hours = 1 day width)
        let hoursAsPoints = (tripData.blockHours / 24.0) * pointsPerDay
        // Minimum visible width
        return max(hoursAsPoints, 20)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Full 30-day bar (light background showing the "decay" period)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: tripData.ageColor.opacity(0.6), location: 0.0),
                            .init(color: tripData.ageColor.opacity(0.4), location: 0.1),
                            .init(color: tripData.ageColor.opacity(0.2), location: 0.3),
                            .init(color: tripData.ageColor.opacity(0.1), location: 0.6),
                            .init(color: tripData.ageColor.opacity(0.05), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: barWidth, height: 28)
                .offset(x: startX)
            
            // Solid block time indicator at the start
            RoundedRectangle(cornerRadius: 4)
                .fill(tripData.ageColor)
                .frame(width: solidWidth, height: 28)
                .offset(x: startX)
            
            // Drop-off marker at end of bar
            Circle()
                .fill(tripData.ageColor)
                .frame(width: 8, height: 8)
                .offset(x: startX + barWidth - 4)
            
            // Block hours label
            Text("\(String(format: "%.1f", tripData.blockHours))h")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(tripData.ageColor.opacity(0.9))
                .cornerRadius(3)
                .offset(x: startX + 4)
        }
    }
}

// MARK: - Data Models

struct TripGanttData: Identifiable {
    let id: UUID
    let tripNumber: String
    let route: String
    let aircraft: String
    let pilotRole: String
    let flightDate: Date
    let blockHours: Double
    let dropOffInfo: (date: Date, hours: Double)
    let daysUntilDropOff: Int
    
    var ageColor: Color {
        if daysUntilDropOff > 20 { return .green }
        if daysUntilDropOff > 10 { return .yellow }
        if daysUntilDropOff > 5 { return .orange }
        return .red
    }
}

// MARK: - Preview
struct TripTimelineGanttChart_Previews: PreviewProvider {
    static var previews: some View {
        TripTimelineGanttChart(logbookStore: LogBookStore())
            .preferredColorScheme(.dark)
    }
}

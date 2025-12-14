import SwiftUI

// MARK: - Grouped Roster Row (Matches existing ScheduleRowView styling)
struct GroupedRosterRow: View {
    let group: RosterDisplayGroup
    @State private var isExpanded = false
    
    var body: some View {
        if group.isGrouped && group.groupType == .consecutiveOffDays {
            // Grouped consecutive off days
            groupedOffDaysCard
        } else {
            // Single item - use existing ScheduleRowView styling for non-grouped items
            singleItemCard
        }
    }
    
    // MARK: - Grouped Off Days Card (matching ScheduleRowView styling)
    private var groupedOffDaysCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main collapsed view
            HStack(spacing: 12) {
                // Green status indicator (matching ScheduleRowView)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green)
                    .frame(width: 6)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🏖️ \(group.displayTitle)")
                            .font(.subheadline.bold())
                            .foregroundColor(LogbookTheme.textPrimary)
                        
                        Spacer()
                        
                        // Expand/collapse chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    // Consecutive days text
                    Text("\(group.daysCount) consecutive days")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    // Date range
                    Text(group.dateRangeText)
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    // Back on duty info
                    if let nextDuty = group.nextDutyDate {
                        HStack {
                            Text("Back on duty:")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.textTertiary)
                            
                            Text(nextDuty, style: .date)
                                .font(.caption2.bold())
                                .foregroundColor(LogbookTheme.textSecondary)
                            
                            Text(nextDuty, style: .time)
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.textTertiary)
                            
                            Spacer()
                            
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
            .background(RoundedRectangle(cornerRadius: 10).fill(LogbookTheme.cardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.8), lineWidth: 1)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded detail view
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.items) { item in
                        expandedDayRow(item)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // Individual day row when expanded
    private func expandedDayRow(_ item: BasicScheduleItem) -> some View {
        HStack(spacing: 12) {
            // Thin green line
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green.opacity(0.5))
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.date, style: .date)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                
                HStack {
                    Text("Start:")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textTertiary)
                    Text(item.blockOut, style: .time)
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Spacer()
                    
                    Text("End:")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textTertiary)
                    Text(item.blockIn, style: .time)
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
            }
        }
        .padding(8)
        .background(LogbookTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Single Item Card (for non-grouped items like flights, rest, etc.)
    private var singleItemCard: some View {
        Group {
            if let item = group.items.first {
                SimplifiedRosterItemRow(item: item)
            }
        }
    }
}

// MARK: - Simplified Single Item Display (matching ScheduleRowView)
struct SimplifiedRosterItemRow: View {
    let item: BasicScheduleItem
    
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
            // Status indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(statusColor)
                .frame(width: 6)
                .opacity(isPastFlight ? 0.5 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Trip number with icon
                    HStack(spacing: 4) {
                        if item.tripNumber.uppercased().contains("REST") {
                            Text("🛏️")
                        } else if item.tripNumber.uppercased().contains("OFF") {
                            Text("🏖️")
                        }
                        Text(item.tripNumber)
                            .font(.subheadline.bold())
                            .foregroundColor(isPastFlight ? LogbookTheme.textSecondary : LogbookTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Times
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
                
                // Route (hide KOFF for off duty)
                if item.status == .activeTrip || item.status == .deadhead {
                    if !item.departure.isEmpty && !item.arrival.isEmpty {
                        Text("\(item.departure) → \(item.arrival)")
                            .font(.subheadline)
                            .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.accentBlue)
                    }
                } else if item.status == .other {
                    // For rest/off - show location if available and not "KOFF"
                    if !item.departure.isEmpty && !item.departure.contains("OFF") {
                        Text(item.departure)
                            .font(.subheadline)
                            .foregroundColor(isPastFlight ? LogbookTheme.textTertiary : LogbookTheme.textSecondary)
                    }
                }
                
                // Duration and status
                HStack {
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
                .stroke(statusColor.opacity(isPastFlight ? 0.3 : 0.8), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        let upper = item.tripNumber.uppercased()
        if upper.contains("REST") {
            return .purple
        } else if upper.contains("OFF") {
            return .green
        } else {
            return item.status.color
        }
    }
}

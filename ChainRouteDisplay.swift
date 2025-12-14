import SwiftUI
import Foundation

// MARK: - Chain Route Display Components

struct ChainRouteDisplay: View {
    let legs: [FlightLeg]
    let isCompact: Bool
    let showTimes: Bool
    
    init(legs: [FlightLeg], isCompact: Bool = false, showTimes: Bool = false) {
        self.legs = legs
        self.isCompact = isCompact
        self.showTimes = showTimes
    }
    
    // Calculate if we need compact display based on total airports
    private var needsCompactDisplay: Bool {
        let totalAirports = legs.count + 1 // departure + all arrivals
        return totalAirports > 4 // Use compact if more than 4 airports
    }
    
    // Remove "K" prefix for US airports to save space
    private func compactAirport(_ code: String) -> String {
        if code.hasPrefix("K") && code.count == 4 {
            return String(code.dropFirst()) // Remove "K" prefix
        }
        return code
    }
    
    var body: some View {
        if legs.isEmpty {
            Text("No legs")
                .font(.caption)
                .foregroundColor(.gray)
        } else if legs.count == 1 {
            // Single leg - always normal display
            HStack(spacing: 4) {
                Text(legs[0].departure)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.accentBlue)
                Text(legs[0].arrival)
            }
            .font(isCompact ? .caption : .subheadline)
            .foregroundColor(LogbookTheme.accentBlue)
        } else {
            // Multi-leg chain - conditional compact display
            if needsCompactDisplay {
                // Too many airports - use vertical separators and remove K prefix
                HStack(spacing: 3) {
                    ForEach(0..<legs.count, id: \.self) { index in
                        Group {
                            if index == 0 {
                                // First airport - keep full code
                                Text(legs[index].departure)
                                    .fontWeight(.medium)
                            }
                            
                            // Vertical separator
                            Text("|")
                                .foregroundColor(.gray)
                                .font(.caption2)
                            
                            // Destination airport - compact intermediate, full for final
                            Text(index == legs.count - 1 ?
                                 legs[index].arrival :
                                 compactAirport(legs[index].arrival))
                                .fontWeight(index == legs.count - 1 ? .medium : .regular)
                        }
                    }
                }
                .font(isCompact ? .caption2 : .caption)
                .foregroundColor(LogbookTheme.accentBlue)
            } else {
                // Few airports - use normal display with arrows
                HStack(spacing: 2) {
                    ForEach(0..<legs.count, id: \.self) { index in
                        Group {
                            if index == 0 {
                                // First airport
                                Text(legs[index].departure)
                                    .fontWeight(.medium)
                            }
                            
                            // Arrow
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentBlue)
                            
                            // Destination airport
                            Text(legs[index].arrival)
                                .fontWeight(index == legs.count - 1 ? .medium : .regular)
                        }
                    }
                }
                .font(isCompact ? .caption : .subheadline)
                .foregroundColor(LogbookTheme.accentBlue)
            }
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(4)
    }
}

// MARK: - Enhanced Logbook Row with Chain Route

struct EnhancedLogbookRow: View {
    let trip: Trip
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                // Status Badge (if not completed)
                if trip.status != .completed {
                    HStack {
                        StatusBadge(status: trip.status)
                        Spacer()
                    }
                }
                
                // CHAIN ROUTE DISPLAY
                ChainRouteDisplay(legs: trip.legs, isCompact: false, showTimes: false)
                
                // Trip Summary
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block Time")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatLogbookTotal(minutes: trip.totalBlockMinutes))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                    
                    Spacer()
                    
                    // Show pilot role
                    VStack(alignment: .center, spacing: 2) {
                        Text("Role")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(trip.pilotRole.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(trip.legs.count) leg\(trip.legs.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(trip.aircraft)
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Duty Timer View
struct DutyTimerView: View {
    let startTime: Date
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(formattedDutyTime)
            .font(.subheadline.bold().monospacedDigit())
            .foregroundColor(LogbookTheme.accentOrange)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private var formattedDutyTime: String {
        let interval = currentTime.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

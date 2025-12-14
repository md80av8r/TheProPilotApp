import SwiftUI

// MARK: - FAR 117 Status Banner
struct FAR117StatusBanner: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var currentTime = Date()
    
    // Timer to update countdown every 60 seconds
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if let status = scheduleStore.currentRosterStatus, status.isActive {
                activeStatusBanner(status)
                    .onReceive(timer) { _ in
                        currentTime = Date()
                    }
            }
        }
    }
    
    private func activeStatusBanner(_ status: RosterStatusInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Icon
                Text(status.icon)
                    .font(.title2)
                
                // Status title
                Text(status.displayTitle)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                // Checkmark indicator
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
            }
            
            // Countdown timer
            HStack(spacing: 4) {
                Text("Back on duty in")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(status.formattedTimeRemaining)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                if let nextDuty = scheduleStore.nextDutyPeriod {
                    Text("(")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    +
                    Text(nextDuty, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    +
                    Text(", ")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    +
                    Text(nextDuty, style: .time)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    +
                    Text(")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.color.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.color.opacity(0.8), lineWidth: 2)
        )
        .shadow(color: status.color.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Compact Status Badge (for embedding in other views)
struct CompactRosterStatusBadge: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    
    var body: some View {
        Group {
            if let status = scheduleStore.currentRosterStatus, status.isActive {
                HStack(spacing: 6) {
                    Text(status.icon)
                        .font(.caption)
                    
                    Text(status.displayTitle)
                        .font(.caption.bold())
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(status.formattedTimeRemaining)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(status.color)
                )
                .foregroundColor(.white)
            }
        }
    }
}

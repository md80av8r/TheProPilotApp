import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes
struct DutyTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic content that changes during the activity
        var currentPhase: String
        var dutyTime: String
        var nextEvent: String?
        var estimatedTimeToNext: String?
        var lastUpdated: Date
    }
    
    // Static content that doesn't change during the activity
    var tripNumber: String
    var aircraft: String
    var route: String
    var startTime: Date
}

// MARK: - Live Activity Views
struct DutyTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DutyTimerAttributes.self) { context in
            // Lock screen/banner UI goes here
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here when tapped
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimal(context: context)
            }
        }
    }
    
    // MARK: - Lock Screen View
    @ViewBuilder
    func lockScreenView(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text("Flight \(context.attributes.tripNumber)")
                    .font(.headline)
                Spacer()
                Text(context.state.dutyTime)
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.primary)
            }
            
            HStack {
                Text(context.attributes.aircraft)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(context.attributes.route)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(context.state.currentPhase)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(phaseColor(context.state.currentPhase).opacity(0.2))
                    .foregroundColor(phaseColor(context.state.currentPhase))
                    .cornerRadius(4)
            }
            
            if let nextEvent = context.state.nextEvent,
               let timeToNext = context.state.estimatedTimeToNext {
                HStack {
                    Text("Next: \(nextEvent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("in \(timeToNext)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Dynamic Island Views
    @ViewBuilder
    func compactLeading(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "airplane")
                .foregroundColor(.blue)
                .font(.caption)
            Text(context.attributes.tripNumber)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    func compactTrailing(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        Text(context.state.dutyTime)
            .font(.caption.monospacedDigit())
            .foregroundColor(.primary)
    }
    
    @ViewBuilder
    func minimal(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        Image(systemName: "airplane")
            .foregroundColor(.blue)
            .font(.system(size: 12))
    }
    
    @ViewBuilder
    func expandedLeading(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text("Flight \(context.attributes.tripNumber)")
                    .font(.subheadline.weight(.medium))
            }
            
            Text(context.attributes.aircraft)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    func expandedTrailing(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(context.state.dutyTime)
                .font(.title2.monospacedDigit())
                .foregroundColor(.primary)
            
            Text("On Duty")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    func expandedBottom(context: ActivityViewContext<DutyTimerAttributes>) -> some View {
        VStack(spacing: 8) {
            // Route and Phase
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Route")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.attributes.route)
                        .font(.subheadline.weight(.medium))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Current Phase")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(context.state.currentPhase)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(phaseColor(context.state.currentPhase).opacity(0.2))
                        .foregroundColor(phaseColor(context.state.currentPhase))
                        .cornerRadius(4)
                }
            }
            
            // Next Event (if available)
            if let nextEvent = context.state.nextEvent,
               let timeToNext = context.state.estimatedTimeToNext {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(nextEvent)
                            .font(.subheadline.weight(.medium))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Estimated Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timeToNext)
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func phaseColor(_ phase: String) -> Color {
        switch phase.lowercased() {
        case "Pre-Flight":
            return .orange
        case "taxi":
            return .yellow
        case "takeoff", "climbing":
            return .green
        case "cruise":
            return .blue
        case "descent", "approach":
            return .purple
        case "landing":
            return .red
        case "arrived":
            return .gray
        default:
            return .primary
        }
    }
}

// MARK: - Preview
#if DEBUG
struct DutyTimerLiveActivity_Previews: PreviewProvider {
    static let attributes = DutyTimerAttributes(
        tripNumber: "4555",
        aircraft: "N837US",
        route: "KMQY → KLRD",
        startTime: Date()
    )
    
    static let contentState = DutyTimerAttributes.ContentState(
        currentPhase: "Pre-Flight",
        dutyTime: "1:23",
        nextEvent: "Departure",
        estimatedTimeToNext: "15 min",
        lastUpdated: Date()
    )
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
#endif

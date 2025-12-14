import WidgetKit
import SwiftUI

@main
struct ProPilotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Include both the home screen widget AND the Live Activity widget
        ProPilotHomeWidget()
        PilotDutyLiveActivityWidget()
    }
}

// MARK: - Home Screen Widget (Regular Widget)
struct ProPilotHomeWidget: Widget {
    let kind: String = "ProPilotHomeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ProPilotHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("ProPilot Status")
        .description("Shows your current flight duty status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            isOnDuty: false,
            dutyTime: "0:00",
            tripNumber: "------",
            aircraft: "----",
            departure: "----",
            arrival: "----",
            flightStatus: "OFF DUTY",
            nextAction: "Start Duty"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = getCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let currentEntry = getCurrentEntry()
        
        // Update every 1 minute for real-time duty timer
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func getCurrentEntry() -> SimpleEntry {
        // Read from shared UserDefaults (same as complications)
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
            return SimpleEntry(
                date: Date(),
                isOnDuty: false,
                dutyTime: "0:00",
                tripNumber: "------",
                aircraft: "----",
                departure: "----",
                arrival: "----",
                flightStatus: "OFF DUTY",
                nextAction: "Start Duty"
            )
        }
        
        let isOnDuty = sharedDefaults.bool(forKey: "isOnDuty")
        let dutyTime = sharedDefaults.string(forKey: "dutyTimeRemaining") ?? "0:00"
        let tripNumber = sharedDefaults.string(forKey: "currentTripNumber") ?? "------"
        let aircraft = sharedDefaults.string(forKey: "currentAircraft") ?? "----"
        
        // Get departure and arrival from current flight
        let departure = sharedDefaults.string(forKey: "currentDeparture") ?? "----"
        let arrival = sharedDefaults.string(forKey: "currentArrival") ?? "----"
        
        // Get flight status and next action
        let flightStatus = sharedDefaults.string(forKey: "flightStatus") ?? (isOnDuty ? "ON DUTY" : "OFF DUTY")
        let nextAction = sharedDefaults.string(forKey: "nextFlightAction") ?? "OUT"
        
        return SimpleEntry(
            date: Date(),
            isOnDuty: isOnDuty,
            dutyTime: dutyTime,
            tripNumber: tripNumber,
            aircraft: aircraft,
            departure: departure,
            arrival: arrival,
            flightStatus: flightStatus,
            nextAction: nextAction
        )
    }
}

// MARK: - Widget Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let isOnDuty: Bool
    let dutyTime: String
    let tripNumber: String
    let aircraft: String
    let departure: String
    let arrival: String
    let flightStatus: String
    let nextAction: String
}

// MARK: - Widget View
struct ProPilotHomeWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 6) {
            // Compact Header
            HStack(spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text("ProPilot")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.isOnDuty ? "ON DUTY" : "OFF DUTY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(entry.isOnDuty ? .green : .gray)
                
                if entry.isOnDuty {
                    VStack(alignment: .leading, spacing: 4) {
                        // Trip Number
                        Text(entry.tripNumber)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        // Route
                        if entry.departure != "----" && entry.arrival != "----" {
                            HStack(spacing: 4) {
                                Text(entry.departure)
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue)
                                Text(entry.arrival)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        
                        // Duty Time
                        HStack(spacing: 4) {
                            Text("Duty:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(entry.dutyTime)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                } else {
                    Text("Ready")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                gradient: Gradient(colors: [.black, .blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Status & Route
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    Text("ProPilot")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if entry.isOnDuty {
                    // Route Display
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROUTE")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if entry.departure != "----" || entry.arrival != "----" {
                            HStack(spacing: 6) {
                                Text(entry.departure)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text(entry.arrival)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("No Route")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Aircraft
                    if entry.aircraft != "----" {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(entry.aircraft)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // OFF DUTY Badge
                    Text("OFF DUTY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .cornerRadius(12)
                    
                    Text("Ready for duty")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side - Trip Info & Status
            if entry.isOnDuty {
                VStack(alignment: .leading, spacing: 10) {
                    // Trip Number
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRIP")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(entry.tripNumber)
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    // Flight Status Badge
                    HStack {
                        Circle()
                            .fill(getStatusColor(entry.flightStatus))
                            .frame(width: 6, height: 6)
                        Text(entry.flightStatus)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(getStatusColor(entry.flightStatus))
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Next Action
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(getNextActionText(entry.nextAction))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // Duty Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DUTY TIME")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(entry.dutyTime)
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                gradient: Gradient(colors: [.black, .blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func getStatusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PREFLIGHT", "OFF DUTY":
            return .gray
        case "TAXI OUT":
            return .yellow
        case "EN ROUTE", "ENROUTE":
            return .green
        case "APPROACH":
            return .orange
        case "COMPLETE":
            return .blue
        default:
            return .white
        }
    }
    
    private func getNextActionText(_ action: String) -> String {
        switch action.uppercased() {
        case "OUT":
            return "Set OUT time"
        case "OFF":
            return "Set OFF time"
        case "ON":
            return "Set ON time"
        case "IN":
            return "Set IN time"
        case "COMPLETE":
            return "Flight Complete"
        default:
            return action
        }
    }
}

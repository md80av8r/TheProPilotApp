//
//  PilotDutyLiveActivityWidget.swift
//  ProPilot Widget Extension
//
//  Live Activity Widget for Dynamic Island integration
//

import SwiftUI
import WidgetKit
import ActivityKit

struct PilotDutyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PilotDutyAttributes.self) { context in
            // Lock Screen View
            PilotDutyLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                // Expanded Region
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip \(context.attributes.tripNumber)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        Text(context.attributes.aircraftType)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duty Time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(context.state.dutyTimeFormatted)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: context.state.flightPhase.icon)
                                .foregroundColor(context.state.flightPhase.color)
                                .font(.system(size: 16))
                            
                            Text(context.state.flightPhase.rawValue)
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !context.attributes.departure.isEmpty && !context.attributes.arrival.isEmpty {
                            HStack(spacing: 8) {
                                Text(context.attributes.departure)
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(context.attributes.arrival)
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Show flight times if any are set
                        if context.state.hasActiveFlightTimes {
                            HStack(spacing: 16) {
                                FlightTimeView(label: "OUT", time: context.state.blockOutTime)
                                FlightTimeView(label: "OFF", time: context.state.blockOffTime)
                                FlightTimeView(label: "ON", time: context.state.blockOnTime)
                                FlightTimeView(label: "IN", time: context.state.blockInTime)
                            }
                            .font(.caption2.monospacedDigit())
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Next: \(context.state.flightPhase.nextAction)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let nextDep = context.state.nextLegDeparture,
                           let nextArr = context.state.nextLegArrival {
                            HStack(spacing: 4) {
                                Text(nextDep)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text(nextArr)
                            }
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        }
                    }
                }
            } compactLeading: {
                // Compact Leading (left side of notch)
                HStack(spacing: 4) {
                    Image(systemName: context.state.flightPhase.icon)
                        .foregroundColor(context.state.flightPhase.color)
                        .font(.system(size: 12))
                    
                    if !context.attributes.departure.isEmpty {
                        Text(context.attributes.departure)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                }
            } compactTrailing: {
                // Compact Trailing (right side of notch)
                Text(context.state.dutyTimeFormatted)
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundColor(.orange)
            } minimal: {
                // Minimal (when multiple activities are active)
                Image(systemName: context.state.flightPhase.icon)
                    .foregroundColor(context.state.flightPhase.color)
                    .font(.system(size: 12))
            }
        }
    }
}

// MARK: - Supporting Views

struct PilotDutyLockScreenView: View {
    let context: ActivityViewContext<PilotDutyAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with trip info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .foregroundColor(.orange)
                        Text("ACTIVE DUTY")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                    
                    Text("Trip \(context.attributes.tripNumber)")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    if !context.attributes.aircraftType.isEmpty {
                        Text(context.attributes.aircraftType)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duty Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(context.state.dutyTimeFormatted)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(.orange)
                }
            }
            
            // Flight phase and route
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: context.state.flightPhase.icon)
                        .foregroundColor(context.state.flightPhase.color)
                        .font(.system(size: 20))
                    
                    Text(context.state.flightPhase.rawValue)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                if !context.attributes.departure.isEmpty && !context.attributes.arrival.isEmpty {
                    HStack {
                        Text(context.attributes.departure)
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(context.attributes.arrival)
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("Next: \(context.state.flightPhase.nextAction)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Flight times (if any are set)
            if context.state.hasActiveFlightTimes {
                HStack(spacing: 0) {
                    FlightTimeView(label: "OUT", time: context.state.blockOutTime)
                        .frame(maxWidth: .infinity)
                    
                    FlightTimeView(label: "OFF", time: context.state.blockOffTime)
                        .frame(maxWidth: .infinity)
                    
                    FlightTimeView(label: "ON", time: context.state.blockOnTime)
                        .frame(maxWidth: .infinity)
                    
                    FlightTimeView(label: "IN", time: context.state.blockInTime)
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            // Next leg info (if available)
            if let nextDep = context.state.nextLegDeparture,
               let nextArr = context.state.nextLegArrival,
               nextDep != context.attributes.departure || nextArr != context.attributes.arrival {
                HStack {
                    Text("Next Leg:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(nextDep)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(nextArr)
                    }
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black, .gray.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct FlightTimeView: View {
    let label: String
    let time: String?
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Text(time ?? "--:--")
                .font(.caption.monospacedDigit())
                .foregroundColor(time != nil ? .white : .secondary)
        }
    }
}

// MARK: - Widget Bundle
// Note: ProPilotWidgetsBundle should be declared in a separate file
// This widget will be added to the existing bundle

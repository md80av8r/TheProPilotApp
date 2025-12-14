//
//  TripCompletionSummaryView.swift
//  TheProPilotApp Watch App
//
//  Trip completion screen with flight/block time breakdown per leg
//

import SwiftUI

struct TripCompletionSummaryView: View {
    let trip: WatchTripSummary
    let onEndTrip: () -> Void
    let onAddAnotherLeg: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                headerSection
                
                // Total Times
                totalTimesSection
                
                // Per-Leg Breakdown
                legBreakdownSection
                
                // Actions
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle("Trip Complete")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Block In Time Reached")
                .font(.headline)
                .foregroundColor(.white)
            
            if let currentLeg = trip.legs.last {
                Text("\(currentLeg.departure) → \(currentLeg.arrival)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Total Times
    private var totalTimesSection: some View {
        VStack(spacing: 12) {
            Text("TOTAL TIMES")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                // Total Flight Time
                TimeCard(
                    title: "Flight",
                    time: trip.totalFlightTime,
                    icon: "airplane",
                    color: .green
                )
                
                // Total Block Time
                TimeCard(
                    title: "Block",
                    time: trip.totalBlockTime,
                    icon: "clock.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Leg Breakdown
    private var legBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEG BREAKDOWN")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ForEach(Array(trip.legs.enumerated()), id: \.offset) { index, leg in
                LegSummaryRow(legNumber: index + 1, leg: leg)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Add Another Leg
            Button(action: {
                onAddAnotherLeg()
                dismiss()
            }) {
                Label("Add Another Leg", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // End Trip
            Button(action: {
                onEndTrip()
                dismiss()
            }) {
                Label("End Trip", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Time Card Component
struct TimeCard: View {
    let title: String
    let time: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(time)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Leg Summary Row
struct LegSummaryRow: View {
    let legNumber: Int
    let leg: WatchLegSummary
    
    var body: some View {
        VStack(spacing: 8) {
            // Leg Header
            HStack {
                Text("Leg \(legNumber)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(leg.departure) → \(leg.arrival)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Times Row
            HStack(spacing: 12) {
                // Flight Time
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(leg.flightTime)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Block Time
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(leg.blockTime)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Times Detail (OUT/OFF/ON/IN)
            VStack(spacing: 4) {
                timesDetailRow
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var timesDetailRow: some View {
        HStack(spacing: 8) {
            TimeLabel("OUT", leg.outTime, .blue)
            TimeLabel("OFF", leg.offTime, .green)
            TimeLabel("ON", leg.onTime, .orange)
            TimeLabel("IN", leg.inTime, .purple)
        }
    }
}

// MARK: - Time Label Component
private struct TimeLabel: View {
    let label: String
    let time: String
    let color: Color
    
    init(_ label: String, _ time: String, _ color: Color) {
        self.label = label
        self.time = time
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Models
struct WatchTripSummary {
    let legs: [WatchLegSummary]
    let totalFlightTime: String
    let totalBlockTime: String
}

struct WatchLegSummary {
    let departure: String
    let arrival: String
    let outTime: String
    let offTime: String
    let onTime: String
    let inTime: String
    let flightTime: String
    let blockTime: String
}

// MARK: - Preview
struct TripCompletionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        TripCompletionSummaryView(
            trip: WatchTripSummary(
                legs: [
                    WatchLegSummary(
                        departure: "KLRD",
                        arrival: "KMQY",
                        outTime: "1430",
                        offTime: "1445",
                        onTime: "1630",
                        inTime: "1642",
                        flightTime: "1:45",
                        blockTime: "2:12"
                    ),
                    WatchLegSummary(
                        departure: "KMQY",
                        arrival: "KLRD",
                        outTime: "1700",
                        offTime: "1715",
                        onTime: "1900",
                        inTime: "1910",
                        flightTime: "1:45",
                        blockTime: "2:10"
                    )
                ],
                totalFlightTime: "3:30",
                totalBlockTime: "4:22"
            ),
            onEndTrip: {},
            onAddAnotherLeg: {}
        )
    }
}

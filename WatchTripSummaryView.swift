// WatchTripSummaryView.swift
// Beautiful trip completion summary with per-leg breakdown

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchTripSummaryView: View {
    let trip: WatchTrip
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var showingShareSheet = false
    @State private var animateIn = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success Header
                successHeader
                
                // Trip Overview
                tripOverviewCard
                
                // Time Summary
                timeSummaryCard
                
                // Per-Leg Breakdown
                legBreakdownSection
                
                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Trip Complete")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Success Header
    private var successHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: animateIn)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .scaleEffect(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: animateIn)
            }
            
            Text("Trip Completed!")
                .font(.title3.bold())
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.3), value: animateIn)
            
            Text(trip.tripNumber)
                .font(.headline)
                .foregroundColor(.blue)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.4), value: animateIn)
        }
        .padding()
    }
    
    // MARK: - Trip Overview Card
    private var tripOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.circle.fill")
                    .foregroundColor(.blue)
                Text("Trip Overview")
                    .font(.headline)
            }
            
            Divider()
            
            overviewRow(icon: "number", label: "Trip", value: trip.tripNumber)
            overviewRow(icon: "airplane", label: "Aircraft", value: trip.aircraft)
            overviewRow(icon: "calendar", label: "Date", value: formatDate(trip.date))
            overviewRow(icon: "location.fill", label: "Legs", value: "\(trip.legs.count)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(0.5), value: animateIn)
    }
    
    private func overviewRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.gray)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }
    
    // MARK: - Time Summary Card
    private var timeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text("Time Summary")
                    .font(.headline)
            }
            
            Divider()
            
            // Total Block Time
            timeRow(
                icon: "clock.badge.checkmark.fill",
                label: "Block Time",
                time: formatMinutes(trip.totalBlockMinutes),
                color: .blue
            )
            
            // Total Flight Time
            timeRow(
                icon: "airplane.circle.fill",
                label: "Flight Time",
                time: formatMinutes(trip.totalFlightMinutes),
                color: .green
            )
            
            // Duty Time (if available)
            if let dutyStart = trip.dutyStart, let dutyEnd = trip.dutyEnd {
                let dutyMinutes = Int(dutyEnd.timeIntervalSince(dutyStart) / 60)
                timeRow(
                    icon: "briefcase.fill",
                    label: "Duty Time",
                    time: formatMinutes(dutyMinutes),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(0.6), value: animateIn)
    }
    
    private func timeRow(icon: String, label: String, time: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(time)
                .font(.headline)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Leg Breakdown Section
    private var legBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundColor(.purple)
                Text("Legs")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(trip.legs.enumerated()), id: \.element.id) { index, leg in
                    legCard(leg: leg, index: index)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.easeOut(duration: 0.3).delay(0.7 + Double(index) * 0.1), value: animateIn)
                }
            }
        }
    }
    
    private func legCard(leg: WatchLeg, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Leg Header
            HStack {
                Text("Leg \(index + 1)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(6)
                
                Text("\(leg.origin) → \(leg.destination)")
                    .font(.subheadline.bold())
                
                Spacer()
            }
            
            // Leg Times
            VStack(spacing: 4) {
                legTimeRow(label: "Block", time: formatMinutes(leg.blockMinutes), icon: "clock")
                legTimeRow(label: "Flight", time: formatMinutes(leg.flightMinutes), icon: "airplane")
            }
            
            // Leg Details
            HStack {
                detailPill(icon: "number", text: leg.flightNumber)
                if !leg.tailNumber.isEmpty {
                    detailPill(icon: "airplane", text: leg.tailNumber)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func legTimeRow(label: String, time: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.caption)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(time)
                .font(.caption.bold())
        }
    }
    
    private func detailPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(4)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                syncToPhone()
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("Sync to iPhone")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Done")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.easeIn(duration: 0.3).delay(1.0), value: animateIn)
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    private func syncToPhone() {
        // Send trip completion to iPhone
        let message: [String: Any] = [
            "type": "tripComplete",
            "tripId": trip.id.uuidString,
            "tripNumber": trip.tripNumber,
            "aircraft": trip.aircraft,
            "date": trip.date.timeIntervalSince1970,
            "totalBlockMinutes": trip.totalBlockMinutes,
            "totalFlightMinutes": trip.totalFlightMinutes,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessageToPhone(message, description: "trip complete")
        
        // Show feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
}

// MARK: - Watch Trip Models
struct WatchTrip: Codable, Identifiable {
    let id: UUID
    let tripNumber: String
    let aircraft: String
    let date: Date
    let dutyStart: Date?
    let dutyEnd: Date?
    let legs: [WatchLeg]
    
    var totalBlockMinutes: Int {
        legs.reduce(0) { $0 + $1.blockMinutes }
    }
    
    var totalFlightMinutes: Int {
        legs.reduce(0) { $0 + $1.flightMinutes }
    }
}

struct WatchLeg: Codable, Identifiable {
    let id: UUID
    let flightNumber: String
    let origin: String
    let destination: String
    let tailNumber: String
    let blockMinutes: Int
    let flightMinutes: Int
    let departureTime: Date?
    let arrivalTime: Date?
}

// MARK: - Preview
struct WatchTripSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTrip = WatchTrip(
            id: UUID(),
            tripNumber: "DAY 1234",
            aircraft: "B737-800",
            date: Date(),
            dutyStart: Date().addingTimeInterval(-28800),
            dutyEnd: Date(),
            legs: [
                WatchLeg(
                    id: UUID(),
                    flightNumber: "AA1234",
                    origin: "DFW",
                    destination: "LAX",
                    tailNumber: "N123AA",
                    blockMinutes: 180,
                    flightMinutes: 165,
                    departureTime: Date().addingTimeInterval(-10800),
                    arrivalTime: Date().addingTimeInterval(-7200)
                ),
                WatchLeg(
                    id: UUID(),
                    flightNumber: "AA5678",
                    origin: "LAX",
                    destination: "SFO",
                    tailNumber: "N123AA",
                    blockMinutes: 90,
                    flightMinutes: 75,
                    departureTime: Date().addingTimeInterval(-3600),
                    arrivalTime: Date()
                )
            ]
        )
        
        NavigationView {
            WatchTripSummaryView(trip: sampleTrip)
                .environmentObject(WatchConnectivityManager.shared)
        }
    }
}

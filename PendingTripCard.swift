//
//  PendingTripCard.swift
//  TheProPilotApp
//
//  Enhanced trip card with manual leg addition support
//

import SwiftUI

struct PendingTripCard: View {
    @ObservedObject var tripService = TripGenerationService.shared
    @ObservedObject var settings = TripGenerationSettings.shared
    @EnvironmentObject var logbookStore: SwiftDataLogBookStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    
    let pendingTrip: PendingRosterTrip
    @State private var showingAddLegsSheet = false
    @State private var showingCreateConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Trip Header
            tripHeader
            
            // Trip Details
            VStack(alignment: .leading, spacing: 16) {
                // Route with legs
                routeSection
                
                // Show time
                if let showTime = pendingTrip.formattedShowTime {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(LogbookTheme.accentOrange)
                        Text("Show Time: \(showTime)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let timeUntil = pendingTrip.formattedTimeUntilShow {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("in \(timeUntil)")
                                    .font(.caption)
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                }
                
                // Leg count and block time
                HStack {
                    Label("\(pendingTrip.legCount) leg\(pendingTrip.legCount != 1 ? "s" : "")", systemImage: "airplane.departure")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(pendingTrip.formattedBlockTime)
                            .font(.caption)
                    }
                    .foregroundColor(LogbookTheme.accentOrange)
                }
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Actions
            actionButtons
        }
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddLegsSheet) {
            AddLegsToTripSheet(
                pendingTrip: pendingTrip,
                onLegsAdded: { selectedLegs in
                    TripGenerationService.shared.addLegsToPendingTrip(
                        pendingTrip,
                        selectedLegs: selectedLegs
                    )
                }
            )
            .environmentObject(scheduleStore)
        }
        .alert("Create Trip?", isPresented: $showingCreateConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                tripService.approvePendingTrip(pendingTrip, logbookStore: logbookStore)
            }
        } message: {
            Text("Create trip \(pendingTrip.tripNumber) with \(pendingTrip.legCount) leg\(pendingTrip.legCount != 1 ? "s" : "")?")
        }
    }
    
    // MARK: - Trip Header
    
    private var tripHeader: some View {
        HStack {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(LogbookTheme.accentGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("New Trip Detected")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(pendingTrip.tripNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(formatDate(pendingTrip.tripDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(LogbookTheme.navy.opacity(0.5))
    }
    
    // MARK: - Route Section
    
    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Route visualization
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pendingTrip.legs.indices, id: \.self) { index in
                        let leg = pendingTrip.legs[index]
                        
                        HStack(spacing: 8) {
                            // Departure
                            VStack(spacing: 2) {
                                Text(leg.departure)
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentBlue)
                                
                                Text(leg.formattedScheduledOut)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            // Arrow with flight number
                            VStack(spacing: 2) {
                                Image(systemName: leg.isDeadhead ? "arrow.right.circle" : "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(leg.isDeadhead ? .orange : .gray)
                                
                                Text(leg.flightNumber)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Final arrival
                    if let lastLeg = pendingTrip.legs.last {
                        VStack(spacing: 2) {
                            Text(lastLeg.arrival)
                                .font(.headline)
                                .foregroundColor(LogbookTheme.accentBlue)
                            
                            Text(lastLeg.formattedScheduledIn)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 0) {
            // Manual Mode: Add Legs button
            if settings.tripGroupingMode == .manual {
                Button {
                    showingAddLegsSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add More Legs")
                    }
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .background(LogbookTheme.accentBlue.opacity(0.15))
                
                Divider()
                    .background(Color.white.opacity(0.2))
            }
            
            // Create Trip Button
            Button {
                if settings.requireConfirmation {
                    showingCreateConfirmation = true
                } else {
                    tripService.approvePendingTrip(pendingTrip, logbookStore: logbookStore)
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Trip")
                }
                .font(.headline)
                .foregroundColor(LogbookTheme.navy)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentGreen)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Bottom Actions
            HStack(spacing: 0) {
                Button {
                    tripService.remindLater(pendingTrip)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                        Text("Later")
                    }
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                Button(role: .destructive) {
                    tripService.dismissPendingTrip(pendingTrip)
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Dismiss")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    let sampleTrip = PendingRosterTrip(
        id: UUID(),
        detectedDate: Date(),
        tripDate: Date(),
        tripNumber: "JUS323",
        legs: [
            PendingLeg(
                id: UUID(),
                flightNumber: "JUS323",
                departure: "KDTW",
                arrival: "KCLE",
                scheduledOut: Date().addingTimeInterval(3600),
                scheduledIn: Date().addingTimeInterval(7200),
                isDeadhead: false,
                rosterSourceId: UUID().uuidString
            ),
            PendingLeg(
                id: UUID(),
                flightNumber: "JUS324",
                departure: "KCLE",
                arrival: "KMSP",
                scheduledOut: Date().addingTimeInterval(10800),
                scheduledIn: Date().addingTimeInterval(14400),
                isDeadhead: false,
                rosterSourceId: UUID().uuidString
            )
        ],
        totalBlockMinutes: 120,
        showTime: Date().addingTimeInterval(3600),
        rosterSourceIds: [UUID().uuidString, UUID().uuidString],
        alarmSettings: nil,
        userAction: .pending
    )
    
    let logbookStore = LogBookStore()
    let nocSettings = NOCSettingsStore()
    let scheduleStore = ScheduleStore(settings: nocSettings)
    
    ZStack {
        LogbookTheme.navy.ignoresSafeArea()
        
        PendingTripCard(pendingTrip: sampleTrip)
            .padding()
            .environmentObject(logbookStore)
            .environmentObject(scheduleStore)
    }
}

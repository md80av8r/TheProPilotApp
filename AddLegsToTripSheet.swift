//
//  AddLegsToTripSheet.swift
//  TheProPilotApp
//
//  Manual leg selection sheet for building trips
//

import SwiftUI

struct AddLegsToTripSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scheduleStore: ScheduleStore
    
    let pendingTrip: PendingRosterTrip
    let onLegsAdded: ([BasicScheduleItem]) -> Void
    
    @State private var selectedLegIds: Set<UUID> = []
    @State private var availableLegs: [BasicScheduleItem] = []
    @State private var showingSuccess = false
    
    private var selectedLegs: [BasicScheduleItem] {
        availableLegs.filter { selectedLegIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Current Trip Summary
                    currentTripHeader
                    
                    // Available Legs List
                    if availableLegs.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(availableLegs) { leg in
                                    legRow(leg)
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // Bottom Action Bar
                    if !availableLegs.isEmpty {
                        bottomActionBar
                    }
                }
            }
            .navigationTitle("Add Legs to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .overlay {
                if showingSuccess {
                    successToast
                }
            }
        }
        .onAppear {
            loadAvailableLegs()
        }
    }
    
    // MARK: - Current Trip Header
    
    private var currentTripHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.departure")
                    .font(.title3)
                    .foregroundColor(LogbookTheme.accentGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Trip")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(pendingTrip.tripNumber)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(pendingTrip.legCount) leg\(pendingTrip.legCount != 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(pendingTrip.formattedBlockTime)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            
            // Route Summary
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pendingTrip.legs.indices, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(pendingTrip.legs[index].departure)
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            if index < pendingTrip.legs.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    if let lastLeg = pendingTrip.legs.last {
                        Text(lastLeg.arrival)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
        }
        .padding()
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Leg Row
    
    private func legRow(_ leg: BasicScheduleItem) -> some View {
        let isSelected = selectedLegIds.contains(leg.id)
        let connects = connectsToPendingTrip(leg)
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    selectedLegIds.remove(leg.id)
                } else {
                    selectedLegIds.insert(leg.id)
                }
            }
        } label: {
            HStack(spacing: 16) {
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? LogbookTheme.accentGreen : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(LogbookTheme.accentGreen)
                            .frame(width: 16, height: 16)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(LogbookTheme.navy)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Flight Number
                    HStack {
                        Text(extractCleanFlightNumber(leg.tripNumber))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if leg.status == .deadhead {
                            Text("DH")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.3))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Connection indicator
                        if connects {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text("Connects")
                                    .font(.caption2)
                            }
                            .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                    
                    // Route
                    HStack(spacing: 8) {
                        Text(leg.departure)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(leg.arrival)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    // Times
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatTime(leg.blockOut))
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                        
                        Text("→")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text(formatTime(leg.blockIn))
                                .font(.caption)
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Block time
                        let blockMinutes = Int(leg.totalBlockTime / 60)
                        let hours = blockMinutes / 60
                        let mins = blockMinutes % 60
                        Text(String(format: "%d:%02d", hours, mins))
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentOrange)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .opacity(isSelected ? 1 : 0.3)
            }
            .padding()
            .background(isSelected ? LogbookTheme.accentGreen.opacity(0.15) : LogbookTheme.navyLight)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? LogbookTheme.accentGreen : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            if !selectedLegIds.isEmpty {
                // Selection Summary
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                    
                    Text("\(selectedLegIds.count) leg\(selectedLegIds.count != 1 ? "s" : "") selected")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    let additionalBlock = selectedLegs.reduce(0) { $0 + Int($1.totalBlockTime / 60) }
                    let hours = additionalBlock / 60
                    let mins = additionalBlock % 60
                    Text("+\(String(format: "%d:%02d", hours, mins))")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                .padding(.horizontal)
            }
            
            Button {
                addSelectedLegs()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedLegIds.isEmpty ? "Select legs to add" : "Add \(selectedLegIds.count) Leg\(selectedLegIds.count != 1 ? "s" : "")")
                }
                .font(.headline)
                .foregroundColor(selectedLegIds.isEmpty ? .gray : LogbookTheme.navy)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedLegIds.isEmpty ? Color.gray.opacity(0.3) : LogbookTheme.accentGreen)
                .cornerRadius(12)
            }
            .disabled(selectedLegIds.isEmpty)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(LogbookTheme.navy)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Additional Legs Found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("No more flights available on this day to add to your trip.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Success Toast
    
    private var successToast: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(LogbookTheme.accentGreen)
                Text("Legs added to trip!")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(10)
            .shadow(radius: 10)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showingSuccess)
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableLegs() {
        availableLegs = TripGenerationService.shared.getAvailableLegsForPendingTrip(
            pendingTrip,
            allRosterItems: scheduleStore.items
        )
    }
    
    private func connectsToPendingTrip(_ leg: BasicScheduleItem) -> Bool {
        // Check if this leg departs from where the pending trip ends
        guard let lastLeg = pendingTrip.legs.last else { return false }
        return lastLeg.arrival == leg.departure
    }
    
    private func addSelectedLegs() {
        let legsToAdd = selectedLegs
        
        onLegsAdded(legsToAdd)
        
        // Show success feedback
        withAnimation {
            showingSuccess = true
        }
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date) + "Z"
    }
    
    private func extractCleanFlightNumber(_ input: String) -> String {
        let withoutReg = input.components(separatedBy: "(").first ?? input
        return withoutReg.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview
#Preview {
    let samplePendingTrip = PendingRosterTrip(
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
                scheduledOut: Date(),
                scheduledIn: Date().addingTimeInterval(3600),
                isDeadhead: false,
                rosterSourceId: UUID().uuidString
            )
        ],
        totalBlockMinutes: 60,
        showTime: Date(),
        rosterSourceIds: [UUID().uuidString],
        alarmSettings: nil,
        userAction: .pending
    )
    
    let nocSettings = NOCSettingsStore()
    let scheduleStore = ScheduleStore(settings: nocSettings)
    
    AddLegsToTripSheet(
        pendingTrip: samplePendingTrip,
        onLegsAdded: { legs in
            print("Added \(legs.count) legs")
        }
    )
    .environmentObject(scheduleStore)
}

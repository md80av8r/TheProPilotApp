//
//  TripGenerationSettingsRow.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/29/25.
//
import SwiftUI

// MARK: - Trip Generation Settings Row
struct TripGenerationSettingsRow: View {
    @ObservedObject var settings = TripGenerationSettings.shared
    @ObservedObject var tripService = TripGenerationService.shared
    @State private var showingSettings = false
    @State private var showingPendingTrips = false
    
    var body: some View {
        Section(header: Text("Smart Trip Generation").foregroundColor(.white)) {
            Toggle(isOn: $settings.enableRosterTripGeneration) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("Auto-Detect Trips")
                            .foregroundColor(.white)  // ADD THIS
                        Text("Create trips from NOC roster")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .listRowBackground(LogbookTheme.navyLight)  // ADD THIS
            
            Button {
                showingSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("Trip Generation Settings")
                        .foregroundColor(.white)  // ADD THIS
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .listRowBackground(LogbookTheme.navyLight)  // ADD THIS
            
            if !tripService.pendingTrips.isEmpty {
                Button {
                    showingPendingTrips = true
                } label: {
                    HStack {
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(.orange)
                        Text("Pending Trips")
                            .foregroundColor(.white)  // ADD THIS
                        Spacer()
                        Text("\(tripService.pendingTrips.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)  // ADD THIS
            }
        }
        .sheet(isPresented: $showingSettings) {
            TripGenerationSettingsView()
        }
        .sheet(isPresented: $showingPendingTrips) {
            PendingTripsView()
        }
    }
}

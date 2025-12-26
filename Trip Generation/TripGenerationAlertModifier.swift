//
//  NewTripDetectedAlert.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/29/25.
//

import SwiftUI

// MARK: - New Trip Alert View
struct NewTripDetectedAlert: View {
    let pendingTrip: PendingRosterTrip
    let onCreateTrip: () -> Void
    let onRemindLater: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "airplane.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("New Trip Detected")
                        .font(.headline)
                    Text(formatDate(pendingTrip.tripDate))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pendingTrip.tripNumber)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(pendingTrip.legCount) leg\(pendingTrip.legCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(pendingTrip.routeSummary)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                if let showTime = pendingTrip.formattedShowTime {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Show Time: \(showTime)")
                            .font(.subheadline)
                    }
                }
                
                if let countdown = pendingTrip.formattedTimeUntilShow {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text("In \(countdown)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 10) {
                Button(action: onCreateTrip) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Trip")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                HStack(spacing: 10) {
                    Button(action: onRemindLater) {
                        HStack {
                            Image(systemName: "clock")
                            Text("Later")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Dismiss")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Alert Modifier
struct TripGenerationAlertModifier: ViewModifier {
    @ObservedObject var tripService = TripGenerationService.shared

    // CHANGED: Use explicit property instead of EnvironmentObject to avoid injection order crashes
    var logbookStore: SwiftDataLogBookStore
    
    @State private var currentPendingTrip: PendingRosterTrip?
    @State private var showingPendingTripsList = false
    @State private var dismissedTripToast: String?
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .newRosterTripsDetected)) { notification in
                // Ensure UI updates happen on main thread
                DispatchQueue.main.async {
                    if let trips = notification.userInfo?["trips"] as? [PendingRosterTrip],
                       let firstTrip = trips.first {
                        currentPendingTrip = firstTrip
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pendingTripDismissed)) { notification in
                if let tripNumber = notification.userInfo?["tripNumber"] as? String {
                    dismissedTripToast = "\(tripNumber) dismissed - won't appear again"
                    
                    // Auto-hide toast after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        dismissedTripToast = nil
                    }
                }
            }
            .overlay(alignment: .bottom) {
                // Toast for dismissed trip feedback
                if let toastMessage = dismissedTripToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toastMessage)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(25)
                    .shadow(radius: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: dismissedTripToast)
                }
            }
            .sheet(item: $currentPendingTrip) { pending in
                NavigationView {
                    NewTripDetectedAlert(
                        pendingTrip: pending,
                        onCreateTrip: {
                            tripService.approvePendingTrip(pending, logbookStore: logbookStore)
                            currentPendingTrip = nil
                            checkForMorePendingTrips()
                        },
                        onRemindLater: {
                            tripService.remindLater(pending)
                            currentPendingTrip = nil
                            checkForMorePendingTrips()
                        },
                        onDismiss: {
                            tripService.dismissPendingTrip(pending)
                            currentPendingTrip = nil
                            checkForMorePendingTrips()
                        }
                    )
                    .navigationTitle("New Trip")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if tripService.pendingTrips.count > 1 {
                                Button("View All (\(tripService.pendingTrips.count))") {
                                    currentPendingTrip = nil
                                    showingPendingTripsList = true
                                }
                            }
                        }
                    }
                }
                // Explicitly inject environment object into the sheet
                .environmentObject(logbookStore)
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingPendingTripsList) {
                PendingTripsView()
                    .environmentObject(logbookStore)
            }
    }
    
    private func checkForMorePendingTrips() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let nextTrip = tripService.pendingTrips.first(where: { $0.userAction == .pending }) {
                currentPendingTrip = nextTrip
            }
        }
    }
}

// MARK: - View Extension
extension View {
    // CHANGED: Accept store parameter
    func withTripGenerationAlerts(store: SwiftDataLogBookStore) -> some View {
        self.modifier(TripGenerationAlertModifier(logbookStore: store))
    }
}

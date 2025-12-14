//
//  PendingTripsHelperView.swift
//  TheProPilotApp
//
//  Quick helper view for Schedule & Timers showing pending trips and dismissed items
//

import SwiftUI

// MARK: - Compact Widget for Slide-Out Panel
/// A compact version for embedding in the TabManager's slide-out More panel
struct PendingTripsCompactWidget: View {
    @ObservedObject var tripGenService = TripGenerationService.shared
    @ObservedObject var dismissedManager = DismissedRosterItemsManager.shared
    
    let onSelectTab: (String) -> Void
    
    @State private var showingPendingDetail = false
    @State private var showingDismissedItems = false
    
    private var dismissedCount: Int {
        dismissedManager.getCurrentlyDismissed().count
    }
    
    private var hasPendingItems: Bool {
        !tripGenService.pendingTrips.isEmpty || dismissedCount > 0
    }
    
    var body: some View {
        if hasPendingItems {
            VStack(spacing: 8) {
                // Pending trips from NOC
                if !tripGenService.pendingTrips.isEmpty {
                    Button {
                        showingPendingDetail = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(LogbookTheme.accentOrange)
                                .frame(width: 24)
                            
                            Text("Pending Trips")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(tripGenService.pendingTrips.count)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LogbookTheme.accentOrange)
                                .cornerRadius(10)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Dismissed items
                if dismissedCount > 0 {
                    Button {
                        showingDismissedItems = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "eye.slash.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("Dismissed Trips")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(dismissedCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray)
                                .cornerRadius(10)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Quick links row
                HStack(spacing: 12) {
                    // Trip Generation Settings
                    Button {
                        onSelectTab("tripGeneration")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                            Text("Settings")
                                .font(.caption)
                        }
                        .foregroundColor(LogbookTheme.accentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LogbookTheme.accentBlue.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Refresh
                    Button {
                        NotificationCenter.default.post(
                            name: .requestRosterDataForTripGeneration,
                            object: nil
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("Refresh")
                                .font(.caption)
                        }
                        .foregroundColor(LogbookTheme.accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LogbookTheme.accentGreen.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(LogbookTheme.navyLight.opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .sheet(isPresented: $showingPendingDetail) {
                PendingTripsSheetView()
            }
            .sheet(isPresented: $showingDismissedItems) {
                DismissedRosterItemsView()
            }
        }
    }
}

// MARK: - Standalone Sheet View (no store required)
/// Used by the compact widget when LogBookStore isn't available
struct PendingTripsSheetView: View {
    @ObservedObject var tripGenService = TripGenerationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if tripGenService.pendingTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(tripGenService.pendingTrips) { pending in
                        PendingTripRowCompact(
                            pending: pending,
                            onDismiss: {
                                tripGenService.dismissPendingTrip(pending)
                            },
                            onRemindLater: {
                                tripGenService.remindLater(pending)
                            }
                        )
                    }
                }
                
                // Info section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("To create trips from pending items, go to the Logbook tab and use the + button.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy)
            .navigationTitle("Pending Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(LogbookTheme.successGreen)
            Text("No Pending Trips")
                .font(.headline)
                .foregroundColor(.white)
            Text("New trips from your NOC roster will appear here for review")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Compact Pending Trip Row
struct PendingTripRowCompact: View {
    let pending: PendingRosterTrip
    let onDismiss: () -> Void
    let onRemindLater: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(pending.tripNumber)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(dateFormatter.string(from: pending.tripDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Route info
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text("\(pending.legCount) leg(s)")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onRemindLater) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Later")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentOrange)
                    .cornerRadius(8)
                }
                
                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Dismiss")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .listRowBackground(LogbookTheme.navyLight)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

// MARK: - Full Helper View (for List-based layouts)
struct PendingTripsHelperView: View {
    @ObservedObject var tripGenService = TripGenerationService.shared
    @ObservedObject var dismissedManager = DismissedRosterItemsManager.shared
    @ObservedObject var store: LogBookStore
    
    @State private var showingPendingDetail = false
    @State private var showingDismissedItems = false
    @State private var showingTripGenSettings = false
    
    private var dismissedCount: Int {
        dismissedManager.getCurrentlyDismissed().count
    }
    
    // Planning status trips (created but not yet active)
    private var standbyTrips: [Trip] {
        store.trips.filter { $0.status == .planning }
    }
    
    var body: some View {
        Section {
            // Pending Trips from NOC (awaiting approval)
            if !tripGenService.pendingTrips.isEmpty {
                Button {
                    showingPendingDetail = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LogbookTheme.accentOrange.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "airplane.circle.fill")
                                .font(.title2)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pending Trips")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(tripGenService.pendingTrips.count) trip(s) awaiting review")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                        
                        Spacer()
                        
                        Text("\(tripGenService.pendingTrips.count)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LogbookTheme.accentOrange)
                            .cornerRadius(12)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Standby Trips (planning status)
            if !standbyTrips.isEmpty {
                NavigationLink {
                    StandbyTripsListView(trips: standbyTrips, store: store)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LogbookTheme.warningYellow.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "clock.badge.questionmark.fill")
                                .font(.title2)
                                .foregroundColor(LogbookTheme.warningYellow)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Standby Trips")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(standbyTrips.count) trip(s) in planning")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.warningYellow)
                        }
                        
                        Spacer()
                        
                        Text("\(standbyTrips.count)")
                            .font(.title3.bold())
                            .foregroundColor(LogbookTheme.navy)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(LogbookTheme.warningYellow)
                            .cornerRadius(12)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Dismissed Items
            if dismissedCount > 0 {
                Button {
                    showingDismissedItems = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "eye.slash.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dismissed Trips")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(dismissedCount) hidden trip(s)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Quick Settings Links
            quickSettingsRow
            
        } header: {
            HStack {
                Text("TRIP MANAGEMENT")
                Spacer()
                if tripGenService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .sheet(isPresented: $showingPendingDetail) {
            PendingTripsDetailView(store: store)
        }
        .sheet(isPresented: $showingDismissedItems) {
            DismissedRosterItemsView()
        }
        .sheet(isPresented: $showingTripGenSettings) {
            TripGenerationSettingsView()
        }
    }
    
    // MARK: - Quick Settings Row
    private var quickSettingsRow: some View {
        HStack(spacing: 16) {
            // Trip Generation Settings
            Button {
                showingTripGenSettings = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title3)
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text("Trip Gen")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(LogbookTheme.navy.opacity(0.5))
                .cornerRadius(8)
            }
            
            // Refresh button
            Button {
                refreshTrips()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(LogbookTheme.accentOrange)
                    Text("Refresh")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(LogbookTheme.navy.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(LogbookTheme.navyLight)
    }
    
    private func refreshTrips() {
        NotificationCenter.default.post(
            name: .requestRosterDataForTripGeneration,
            object: nil
        )
    }
}

// MARK: - Pending Trips Detail View
struct PendingTripsDetailView: View {
    @ObservedObject var tripGenService = TripGenerationService.shared
    @ObservedObject var store: LogBookStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if tripGenService.pendingTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(tripGenService.pendingTrips) { pending in
                        PendingTripRowFull(
                            pending: pending,
                            onApprove: {
                                tripGenService.approvePendingTrip(pending, logbookStore: store)
                            },
                            onDismiss: {
                                tripGenService.dismissPendingTrip(pending)
                            },
                            onRemindLater: {
                                tripGenService.remindLater(pending)
                            }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy)
            .navigationTitle("Pending Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(LogbookTheme.successGreen)
            Text("No Pending Trips")
                .font(.headline)
                .foregroundColor(.white)
            Text("New trips from your NOC roster will appear here for review")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Full Pending Trip Row (with approve button)
struct PendingTripRowFull: View {
    let pending: PendingRosterTrip
    let onApprove: () -> Void
    let onDismiss: () -> Void
    let onRemindLater: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(pending.tripNumber)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(dateFormatter.string(from: pending.tripDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Route info
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text("\(pending.legCount) leg(s)")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onApprove) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Create")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentGreen)
                    .cornerRadius(8)
                }
                
                Button(action: onRemindLater) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Later")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentOrange)
                    .cornerRadius(8)
                }
                
                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Dismiss")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .listRowBackground(LogbookTheme.navyLight)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

// MARK: - Standby Trips List View
struct StandbyTripsListView: View {
    let trips: [Trip]
    @ObservedObject var store: LogBookStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(trips) { trip in
                StandbyTripRow(trip: trip, store: store)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LogbookTheme.navy)
        .navigationTitle("Standby Trips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Standby Trip Row
struct StandbyTripRow: View {
    let trip: Trip
    @ObservedObject var store: LogBookStore
    @State private var showingActivateAlert = false
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.tripNumber)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let firstLeg = trip.legs.first, let lastLeg = trip.legs.last {
                        Text("\(firstLeg.departure) → \(lastLeg.arrival)")
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                
                Spacer()
                
                // Planning badge
                Text("PLANNING")
                    .font(.caption2.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LogbookTheme.warningYellow)
                    .cornerRadius(6)
            }
            
            // Details
            HStack {
                Label(dateFormatter.string(from: trip.date), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Label("\(trip.legs.count) leg(s)", systemImage: "airplane")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Activate button
            Button {
                showingActivateAlert = true
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Activate Trip")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LogbookTheme.accentGreen)
                .cornerRadius(8)
            }
        }
        .padding()
        .listRowBackground(LogbookTheme.navyLight)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .alert("Activate Trip?", isPresented: $showingActivateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Activate") {
                activateTrip()
            }
        } message: {
            Text("This will change \(trip.tripNumber) from Planning to Active status.")
        }
    }
    
    private func activateTrip() {
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = store.trips[index]
            updatedTrip.status = .active
            store.trips[index] = updatedTrip
            store.save()
        }
    }
}

// MARK: - Preview
struct PendingTripsHelperView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            PendingTripsHelperView(store: LogBookStore())
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LogbookTheme.navy)
        .preferredColorScheme(.dark)
    }
}

//
//  RosterToTripHelper.swift
//  TheProPilotApp
//
//  Handles manual addition of roster items to trips
//

import SwiftUI

// MARK: - Roster to Trip Helper
class RosterToTripHelper {
    static let shared = RosterToTripHelper()
    private init() {}
    
    /// Format Date to time string (HHmm format)
    private func formatTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    /// Convert a BasicScheduleItem to a FlightLeg
    func createLeg(from rosterItem: BasicScheduleItem) -> FlightLeg {
        // Extract flight number (remove tail number in parentheses if present)
        let flightNumber = rosterItem.tripNumber
            .replacingOccurrences(of: " \\(N\\w+\\)", with: "", options: .regularExpression)
        
        // Create the leg with roster data
        // Keep OUT and IN times from roster (shows scheduled times)
        // Leave OFF and ON empty so leg isn't considered "complete"
        var leg = FlightLeg()
        leg.departure = rosterItem.departure
        leg.arrival = rosterItem.arrival
        leg.flightNumber = flightNumber
        
        // ✅ Keep scheduled OUT and IN times (visible to pilot)
        leg.outTime = formatTimeString(from: rosterItem.blockOut)
        leg.inTime = formatTimeString(from: rosterItem.blockIn)
        
        // ✅ Leave OFF and ON empty - leg won't be "complete" until these are filled
        leg.offTime = ""
        leg.onTime = ""
        
        leg.isDeadhead = rosterItem.status == .deadhead
        leg.status = .standby  // New legs start as standby
        
        // Store SCHEDULED times for variance tracking and sorting
        leg.scheduledOut = rosterItem.blockOut
        leg.scheduledIn = rosterItem.blockIn
        leg.scheduledFlightNumber = flightNumber
        leg.rosterSourceId = rosterItem.id.uuidString
        
        return leg
    }
    
    /// Add a roster item as a new leg to an existing trip
    func addToTrip(_ rosterItem: BasicScheduleItem, trip: Trip, store: LogBookStore) {
        let newLeg = createLeg(from: rosterItem)
        
        // Find the trip and add the leg
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = store.trips[index]
            
            // Add to the first logpage's legs
            if updatedTrip.logpages.isEmpty {
                updatedTrip.logpages = [Logpage(pageNumber: 1, tatStart: "", legs: [newLeg])]
            } else {
                updatedTrip.logpages[0].legs.append(newLeg)
                
                // Sort legs by scheduledOut DATE (not just time!)
                // This handles overnight trips where leg 2 is after midnight (01:00 > 21:00 when dates are considered)
                updatedTrip.logpages[0].legs.sort { leg1, leg2 in
                    // BEST: Compare full Date objects (includes date + time)
                    if let sched1 = leg1.scheduledOut, let sched2 = leg2.scheduledOut {
                        return sched1 < sched2
                    }
                    
                    // FALLBACK: If one has scheduledOut and other doesn't
                    // Legs WITH scheduledOut (new roster legs) go AFTER legs without (active legs being flown)
                    if leg1.scheduledOut != nil && leg2.scheduledOut == nil {
                        // leg1 is new roster leg, leg2 is being flown - leg2 goes first
                        return false
                    }
                    if leg1.scheduledOut == nil && leg2.scheduledOut != nil {
                        // leg1 is being flown, leg2 is new roster leg - leg1 goes first
                        return true
                    }
                    
                    // LAST RESORT: Neither has scheduledOut - keep original order
                    // (This shouldn't happen for roster-added legs)
                    return false
                }
            }
            
            // Update roster source IDs
            var sourceIds = updatedTrip.rosterSourceIds ?? []
            sourceIds.append(rosterItem.id.uuidString)
            updatedTrip.rosterSourceIds = sourceIds
            
            store.trips[index] = updatedTrip
            store.save()
            
            print("✅ Added leg \(newLeg.flightNumber) to trip \(trip.tripNumber)")
            
            // Post notification for UI feedback
            NotificationCenter.default.post(
                name: .legAddedToTrip,
                object: nil,
                userInfo: ["tripNumber": trip.tripNumber, "flightNumber": newLeg.flightNumber]
            )
        }
    }
    
    /// Create a new trip from a single roster item
    func createNewTrip(from rosterItem: BasicScheduleItem, store: LogBookStore) -> Trip {
        let leg = createLeg(from: rosterItem)
        
        // Leg stays .standby until user activates the trip
        // This allows pre-building trips days in advance
        
        // Extract base trip number for the trip
        let tripNumber = extractTripNumber(from: rosterItem.tripNumber)
        
        // Trip initializer order: tripNumber, aircraft, date, tatStart, crew, notes, legs
        let newTrip = Trip(
            tripNumber: tripNumber,
            aircraft: "",  // Will be filled in later
            date: rosterItem.date,
            tatStart: "",  // Will be filled in later
            crew: [],
            notes: "Created from NOC roster",
            legs: [leg],
            status: .planning,  // Stays planning until user activates
            rosterSourceIds: [rosterItem.id.uuidString],
            scheduledShowTime: rosterItem.blockOut
        )
        
        store.trips.insert(newTrip, at: 0)
        store.save()
        
        print("✅ Created new trip \(tripNumber) from roster item (status: planning)")
        
        // Post notification for UI feedback
        NotificationCenter.default.post(
            name: .tripCreatedFromRoster,
            object: nil,
            userInfo: ["tripNumber": tripNumber]
        )
        
        return newTrip
    }
    
    /// Extract clean trip number
    private func extractTripNumber(from raw: String) -> String {
        // Remove tail number in parentheses: "UJ318 (N123AB)" → "UJ318"
        let cleaned = raw.replacingOccurrences(of: " \\(N\\w+\\)", with: "", options: .regularExpression)
        
        // If it's just digits, add UJ prefix
        if cleaned.allSatisfy({ $0.isNumber }) {
            return "UJ\(cleaned)"
        }
        
        return cleaned
    }
    
    // MARK: - Trip Activation
    
    /// Activate a planning trip - sets trip to active and first leg to active
    func activateTrip(_ trip: Trip, store: LogBookStore) {
        guard let index = store.trips.firstIndex(where: { $0.id == trip.id }) else {
            print("❌ Could not find trip to activate")
            return
        }
        
        var updatedTrip = store.trips[index]
        
        // Set trip status to active
        updatedTrip.status = .active
        
        // Find first non-completed, non-skipped leg and set it to active
        for i in 0..<updatedTrip.legs.count {
            let leg = updatedTrip.legs[i]
            if leg.status == .standby {
                updatedTrip.legs[i].status = .active
                print("✅ Activated leg \(i + 1): \(leg.departure) → \(leg.arrival)")
                break  // Only activate the first standby leg
            }
        }
        
        store.trips[index] = updatedTrip
        store.save()
        
        print("✅ Activated trip \(trip.tripNumber)")
        
        // Post notification for UI feedback
        NotificationCenter.default.post(
            name: .tripActivated,
            object: nil,
            userInfo: ["tripNumber": trip.tripNumber]
        )
    }
    
    /// Check if a trip needs activation (is planning with all standby legs)
    func tripNeedsActivation(_ trip: Trip) -> Bool {
        // Trip must be in planning status
        guard trip.status == .planning else { return false }
        
        // All legs must be standby (none active yet)
        return trip.legs.allSatisfy { $0.status == .standby || $0.status == .completed || $0.status == .skipped }
    }
    
    /// Get trips that this roster item could be added to
    /// (Active or Planning trips that haven't departed yet)
    func eligibleTrips(for rosterItem: BasicScheduleItem, in store: LogBookStore) -> [Trip] {
        return store.trips.filter { trip in
            // Only active or planning trips
            guard trip.status == .active || trip.status == .planning else { return false }
            
            // Trip should have legs
            guard !trip.legs.isEmpty else { return true } // Empty trip is eligible
            
            // Check if the roster item fits chronologically
            // (its OUT time is after the last leg's IN time, or it's the same day)
            if let lastLeg = trip.legs.last {
                let lastInTime = Int(lastLeg.inTime.filter(\.isWholeNumber)) ?? 0
                let rosterOutTime = Int(formatTimeString(from: rosterItem.blockOut).filter(\.isWholeNumber)) ?? 0
                
                // Same day check
                let sameDay = Calendar.current.isDate(trip.date, inSameDayAs: rosterItem.date)
                
                // Allow if roster OUT is after last IN, or same day
                let isAfter = rosterOutTime > lastInTime
                return sameDay || isAfter
            }
            
            return true
        }
    }
}

// MARK: - Roster Item Action Sheet View
struct RosterItemActionSheet: View {
    let rosterItem: BasicScheduleItem
    let store: LogBookStore
    @Binding var isPresented: Bool
    @State private var showingTripPicker = false
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    
    var eligibleTrips: [Trip] {
        RosterToTripHelper.shared.eligibleTrips(for: rosterItem, in: store)
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    
    var body: some View {
        NavigationView {
            List {
                // Item info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(rosterItem.tripNumber)
                            .font(.headline)
                        
                        HStack {
                            Text(rosterItem.departure)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            
                            Text(rosterItem.arrival)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text(formatDate(rosterItem.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(timeFormatter.string(from: rosterItem.blockOut)) - \(timeFormatter.string(from: rosterItem.blockIn))Z")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Actions section
                Section("Add to Trip") {
                    // Create new trip option
                    Button {
                        let newTrip = RosterToTripHelper.shared.createNewTrip(from: rosterItem, store: store)
                        successMessage = "Created trip \(newTrip.tripNumber)"
                        showingSuccessToast = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isPresented = false
                        }
                    } label: {
                        Label("Create New Trip", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    
                    // Add to existing trip options
                    if !eligibleTrips.isEmpty {
                        ForEach(eligibleTrips) { trip in
                            Button {
                                RosterToTripHelper.shared.addToTrip(rosterItem, trip: trip, store: store)
                                successMessage = "Added to \(trip.tripNumber)"
                                showingSuccessToast = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    isPresented = false
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add to \(trip.tripNumber)")
                                            .foregroundColor(.primary)
                                        
                                        if !trip.legs.isEmpty {
                                            Text("\(trip.legs.count) leg(s) • \(trip.routeString)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Status badge
                                    Text(trip.status.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(trip.status == .active ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        .foregroundColor(trip.status == .active ? .green : .orange)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    } else {
                        Text("No eligible trips found")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .overlay {
                if showingSuccessToast {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showingSuccessToast)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names for Roster-to-Trip Feature
extension Notification.Name {
    static let legAddedToTrip = Notification.Name("legAddedToTrip")
    static let tripCreatedFromRoster = Notification.Name("tripCreatedFromRoster")
    static let tripActivated = Notification.Name("tripActivated")
}

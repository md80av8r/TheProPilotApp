//
//  TripGenerationServiceSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/1/25.
//


//
//  TripGenerationService+ContinuationDetection.swift
//  ProPilotApp
//
//  Smart continuation detection for multi-leg trips
//

import Foundation

extension TripGenerationService {
    
    // MARK: - Continuation Detection
    
    /// Check if a roster flight should continue an existing trip
    func detectContinuation(
        for flight: BasicScheduleItem,
        existingTrips: [Trip]
    ) -> ContinuationDetectionResult {
        
        // Find active or planning trips from same day or previous day
        let relevantTrips = existingTrips.filter { trip in
            guard trip.status == .active || trip.status == .planning else { return false }
            
            // Check if trip is from same day or within 24 hours
            let timeDiff = abs(flight.date.timeIntervalSince(trip.date))
            return timeDiff < (24 * 3600)
        }
        
        guard !relevantTrips.isEmpty else {
            return .newTrip
        }
        
        // Check each potential continuation
        var bestMatch: (trip: Trip, confidence: ContinuationPrompt.ContinuationConfidence, reason: String)?
        
        for trip in relevantTrips {
            if let match = evaluateContinuation(flight: flight, trip: trip) {
                // Keep the highest confidence match
                if bestMatch == nil || match.confidence.rawValue > bestMatch!.confidence.rawValue {
                    bestMatch = match
                }
            }
        }
        
        if let match = bestMatch {
            let prompt = ContinuationPrompt(
                newFlight: flight,
                existingTrip: match.trip,
                matchReason: match.reason,
                confidence: match.confidence
            )
            return .askUserAboutContinuation(prompt)
        }
        
        return .newTrip
    }
    
    /// Evaluate if a flight continues a specific trip
    private func evaluateContinuation(
        flight: BasicScheduleItem,
        trip: Trip
    ) -> (trip: Trip, confidence: ContinuationPrompt.ContinuationConfidence, reason: String)? {
        
        guard let lastLeg = trip.legs.last else { return nil }
        
        // Calculate time gap between last leg and new flight
        // Use actual block times from roster data for accuracy
        let lastLegEnd: Date
        if let scheduledIn = lastLeg.scheduledIn {
            // Best case: we have the scheduled in time from roster
            lastLegEnd = scheduledIn
        } else {
            // Fallback: estimate based on scheduled out + flight time
            // This helps with overnight trips that span date boundaries
            if let scheduledOut = lastLeg.scheduledOut,
               let scheduledIn = lastLeg.scheduledIn {
                lastLegEnd = scheduledIn
            } else {
                // Last resort: use trip date (may be inaccurate for multi-day trips)
                lastLegEnd = trip.date
                print("⚠️ No scheduled times for last leg - using trip date as fallback")
            }
        }

        // Calculate time gap using ACTUAL block times (not calendar dates)
        let timeGap = flight.blockOut.timeIntervalSince(lastLegEnd)
        let hoursGap = timeGap / 3600

        print("⏱️ Time gap for \(flight.tripNumber): \(formatHours(hoursGap)) after last leg")

        // Rule out if gap is negative (flight before last leg) or too large (> 12 hours)
        guard timeGap >= 0 && hoursGap < 12 else {
            print("❌ Gap out of range: \(formatHours(hoursGap))")
            return nil
        }

        // HIGH CONFIDENCE: Route continues (departure matches last arrival)
        if lastLeg.arrival == flight.departure {
            let reason = "Route continues: \(lastLeg.arrival) → \(flight.arrival)"
            print("✅ HIGH confidence continuation detected")
            return (trip, .high, reason)
        }

        // MEDIUM CONFIDENCE: Same duty period, reasonable timing (< 4 hours)
        if hoursGap < 4 {
            let reason = "Same duty period (\(formatHours(hoursGap)) between legs)"
            print("✅ MEDIUM confidence continuation detected")
            return (trip, .medium, reason)
        }

        // LOW CONFIDENCE: Longer gap but still within duty day (< 8 hours)
        // Note: Don't use calendar date comparison - it fails for overnight trips
        if hoursGap < 8 {
            let reason = "Possible continuation (\(formatHours(hoursGap)) gap)"
            print("✅ LOW confidence continuation detected")
            return (trip, .low, reason)
        }

        print("❌ No continuation detected - gap too large")
        return nil
    }
    
    // MARK: - Continuation Actions
    
    /// Add flight as new leg to existing trip
    func addLegToTrip(
        flight: BasicScheduleItem,
        trip: Trip,
        logbookStore: SwiftDataLogBookStore
    ) {
        guard let tripIndex = logbookStore.trips.firstIndex(where: { $0.id == trip.id }) else {
            print("❌ Could not find trip to add leg")
            return
        }
        
        // Create new leg from roster flight
        var newLeg = FlightLeg()
        newLeg.id = UUID()
        newLeg.departure = flight.departure
        newLeg.arrival = flight.arrival
        newLeg.flightNumber = extractCleanFlightNumber(flight.tripNumber)
        newLeg.isDeadhead = flight.status == .deadhead
        
        // Set scheduled times
        newLeg.scheduledOut = flight.blockOut
        newLeg.scheduledIn = flight.blockIn
        newLeg.scheduledFlightNumber = extractCleanFlightNumber(flight.tripNumber)
        
        // Store roster source ID
        newLeg.rosterSourceId = flight.id.uuidString
        
        // Pre-populate actual times if enabled
        if settings.prePopulateScheduledTimes {
            let formatter = DateFormatter()
            formatter.dateFormat = "HHmm"
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            newLeg.outTime = formatter.string(from: flight.blockOut)
            newLeg.inTime = formatter.string(from: flight.blockIn)
        }
        
        // Set leg status to standby (user can activate when ready)
        newLeg.status = .standby
        
        // Add leg to trip
        logbookStore.trips[tripIndex].legs.append(newLeg)
        
        // Save and sync
        logbookStore.save()
        logbookStore.syncToCloud(trip: logbookStore.trips[tripIndex])
        
        print("✅ Added leg \(newLeg.flightNumber) to trip #\(trip.tripNumber)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .legAddedToTrip,
            object: nil,
            userInfo: [
                "tripId": trip.id.uuidString,
                "legId": newLeg.id.uuidString
            ]
        )
    }
    
    /// Extract clean flight number from roster trip number
    private func extractCleanFlightNumber(_ input: String) -> String {
        // Remove aircraft registration if present (e.g., "UJ743 (N12345)" -> "UJ743")
        let withoutReg = input.components(separatedBy: "(").first ?? input
        return withoutReg.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helpers
    
    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))min"
        } else if hours < 2 {
            return "1hr \(Int((hours - 1) * 60))min"
        } else {
            return "\(Int(hours))hrs"
        }
    }
}

// MARK: - Confidence Sorting
extension ContinuationPrompt.ContinuationConfidence {
    var rawValue: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let legAddedToTrip = Notification.Name("legAddedToTrip")
    static let continuationPromptShown = Notification.Name("continuationPromptShown")
}

//
//  TripCountingSettings.swift
//  ProPilot App
//
//  Trip counting configuration for different airline pay structures
//

import Foundation
import Combine

/// Settings for how trips are counted and displayed
class TripCountingSettings: ObservableObject {
    static let shared = TripCountingSettings()

    private let defaults = UserDefaults.appGroup ?? UserDefaults.standard

    // MARK: - Trip Counting Method

    /// How trips should be counted
    enum CountingMethod: String, CaseIterable {
        case byTripNumber = "tripNumber"  // Each unique trip number = 1 trip (USA Jet style)
        case byDutyPeriod = "dutyPeriod"  // All legs in one duty period = 1 trip
        case byCalendarDay = "calendarDay" // All legs on same calendar day = 1 trip

        var displayName: String {
            switch self {
            case .byTripNumber: return "By Trip Number"
            case .byDutyPeriod: return "By Duty Period"
            case .byCalendarDay: return "By Calendar Day"
            }
        }

        var description: String {
            switch self {
            case .byTripNumber:
                return "Each unique trip number counts as one trip. Perfect for airlines like USA Jet where each trip number = trip pay."
            case .byDutyPeriod:
                return "All legs within a single duty period count as one trip. Good for multi-day pairings."
            case .byCalendarDay:
                return "All legs on the same calendar day count as one trip."
            }
        }
    }

    @Published var countingMethod: CountingMethod {
        didSet {
            defaults.set(countingMethod.rawValue, forKey: "tripCountingMethod")
        }
    }

    // MARK: - Deadhead Handling

    /// Whether to count deadhead trips in the trip count
    @Published var includeDeadheadsInCount: Bool {
        didSet {
            defaults.set(includeDeadheadsInCount, forKey: "includeDeadheadsInCount")
        }
    }

    // MARK: - Initialization

    private init() {
        // Load counting method
        if let savedMethod = defaults.string(forKey: "tripCountingMethod"),
           let method = CountingMethod(rawValue: savedMethod) {
            self.countingMethod = method
        } else {
            self.countingMethod = .byTripNumber  // Default to trip number counting
        }

        // Load deadhead setting (default to FALSE - don't count deadheads)
        self.includeDeadheadsInCount = defaults.bool(forKey: "includeDeadheadsInCount")
        // Note: defaults.bool returns false if key doesn't exist, which is what we want
    }

    // MARK: - Trip Counting Logic

    /// Count trips based on the current settings
    func countTrips(from trips: [Trip]) -> Int {
        let tripsToCount: [Trip]

        // First, filter deadheads if needed
        if includeDeadheadsInCount {
            tripsToCount = trips
        } else {
            tripsToCount = trips.filter { !$0.isDeadhead }
        }

        // Then count based on method
        switch countingMethod {
        case .byTripNumber:
            // Count unique trip numbers
            let uniqueTripNumbers = Set(tripsToCount.map { $0.tripNumber })
            return uniqueTripNumbers.count

        case .byDutyPeriod:
            // Count by unique duty periods (using TAT start as identifier)
            // Group trips that have the same TAT start time
            var dutyPeriods: Set<String> = []
            for trip in tripsToCount {
                let tatKey = trip.tatStart.isEmpty ? trip.id.uuidString : trip.tatStart
                dutyPeriods.insert(tatKey)
            }
            return dutyPeriods.count

        case .byCalendarDay:
            // Count by unique calendar days
            let calendar = Calendar.current
            var uniqueDays: Set<DateComponents> = []
            for trip in tripsToCount {
                let components = calendar.dateComponents([.year, .month, .day], from: trip.date)
                uniqueDays.insert(components)
            }
            return uniqueDays.count
        }
    }

    /// Get description text for the trip count display
    func tripCountDescription(count: Int) -> String {
        let tripWord = count == 1 ? "trip" : "trips"

        switch countingMethod {
        case .byTripNumber:
            return "\(count) \(tripWord)"
        case .byDutyPeriod:
            return "\(count) duty period\(count == 1 ? "" : "s")"
        case .byCalendarDay:
            return "\(count) \(tripWord) (\(count) day\(count == 1 ? "" : "s"))"
        }
    }
}

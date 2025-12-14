//
//  FlightLeg+TimeValidation.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 8/23/25.
//

// FlightLeg+TimeValidation.swift
// Restores helpers that Helpers.swift expects (used by per-diem calculations)

import Foundation

// NOTE: This keeps the public API that Helpers.swift calls:
//   FlightLeg.isValidTime(_:)  and (optionally) FlightLeg.parseGMTTimeToDate(_:on:)
// If you already have these somewhere else, delete this file to avoid duplicates.
extension FlightLeg {
    /// Returns true if the string looks like a valid Zulu time in HHMM (or HMM) format.
    public static func isValidTime(_ timeString: String) -> Bool {
        // FIXED: Keep filter closure on one line
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return false }
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        guard let hh = Int(padded.prefix(2)), let mm = Int(padded.suffix(2)) else { return false }
        return (0..<24).contains(hh) && (0..<60).contains(mm)
    }

    /// Optional: If other code needs it, converts an HHMM/HMM Zulu string to a Date on the given flightDate (UTC)
    public static func parseGMTTimeToDate(_ timeString: String, on flightDate: Date) -> Date? {
        // FIXED: Keep filter closure on one line
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return nil }
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        guard let hh = Int(padded.prefix(2)), let mm = Int(padded.suffix(2)),
              (0..<24).contains(hh), (0..<60).contains(mm) else { return nil }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: flightDate)
        comps.hour = hh
        comps.minute = mm
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "GMT")
        return Calendar.current.date(from: comps)
    }
}

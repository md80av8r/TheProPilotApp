//
//  FlightLeg+Validation.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 8/23/25.
//


// FlightLeg+Validation.swift
// Adds static helpers that Helpers.swift expects

import Foundation

extension FlightLeg {
    /// Validate a Zulu time string in HHMM or HMM format.
    public static func isValidTime(_ timeString: String) -> Bool {
        let digits = timeString.filter { $0.isWholeNumber }
        guard digits.count >= 3 else { return false }
        
        // Pad to 4 digits if needed (e.g. "800" -> "0800")
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        guard let hh = Int(padded.prefix(2)),
              let mm = Int(padded.suffix(2)) else { return false }
        
        return (0..<24).contains(hh) && (0..<60).contains(mm)
    }

    /// Convert an HHMM/HMM GMT time string to a Date on the given flight date.
    public static func parseGMTTimeToDate(_ timeString: String, on flightDate: Date) -> Date? {
        let digits = timeString.filter { $0.isWholeNumber }
        guard digits.count >= 3 else { return nil }
        
        let padded = digits.count < 4
            ? String(repeating: "0", count: 4 - digits.count) + digits
            : String(digits.prefix(4))
        
        guard let hh = Int(padded.prefix(2)),
              let mm = Int(padded.suffix(2)),
              (0..<24).contains(hh), (0..<60).contains(mm) else { return nil }
        
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: flightDate)
        comps.hour = hh
        comps.minute = mm
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "GMT")
        
        return Calendar.current.date(from: comps)
    }
}

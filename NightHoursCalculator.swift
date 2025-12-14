// NightHoursCalculator.swift - Fixed Night Hours Calculation
// Properly calculates night hours for flights that cross into night (e.g., daytime departure, nighttime arrival)
import Foundation
import CoreLocation

// MARK: - Enhanced Night Hours Calculator
class NightHoursCalculator {
    private let airportManager = AirportDatabaseManager()
    
    // Civil twilight offset in minutes (FAA definition: sun 6° below horizon)
    private let civilTwilightOffsetMinutes: Int = 30
    
    // MARK: - Public Interface
    
    /// Calculate night hours for a flight based on FAA regulations (civil twilight to civil twilight)
    /// This properly handles flights that:
    /// - Depart in daylight and arrive at night
    /// - Depart at night and arrive in daylight
    /// - Are entirely at night
    /// - Cross multiple twilight boundaries
    ///
    /// - Parameters:
    ///   - departure: Departure airport ICAO code
    ///   - arrival: Arrival airport ICAO code
    ///   - outTime: OUT time in GMT/Zulu
    ///   - inTime: IN time in GMT/Zulu
    ///   - flightDate: The actual date of the flight
    /// - Returns: Night hours in seconds (TimeInterval)
    func calculateNightHours(
        departure: String,
        arrival: String,
        outTime: Date,
        inTime: Date,
        flightDate: Date
    ) async -> TimeInterval {
        
        // Use async airport lookup from your existing AirportDatabaseManager
        async let depInfoTask = airportManager.getAirportInfo(departure)
        async let arrInfoTask = airportManager.getAirportInfo(arrival)
        
        let (depInfo, arrInfo) = await (depInfoTask, arrInfoTask)
        
        guard let depInfo = depInfo, let arrInfo = arrInfo else {
            print("⚠️ Night calc: Missing airport info, using estimation")
            return estimateNightHours(outTime: outTime, inTime: inTime, flightDate: flightDate)
        }
        
        // Get twilight times for departure airport
        let depTwilight = calculateTwilightTimes(
            for: depInfo.coordinate,
            date: flightDate,
            timeZoneId: depInfo.timeZoneIdentifier
        )
        
        // Get twilight times for arrival airport
        let arrTwilight = calculateTwilightTimes(
            for: arrInfo.coordinate,
            date: flightDate,
            timeZoneId: arrInfo.timeZoneIdentifier
        )
        
        // Also check next day in case of overnight flight
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: flightDate) ?? flightDate
        let depTwilightNextDay = calculateTwilightTimes(
            for: depInfo.coordinate,
            date: nextDay,
            timeZoneId: depInfo.timeZoneIdentifier
        )
        let arrTwilightNextDay = calculateTwilightTimes(
            for: arrInfo.coordinate,
            date: nextDay,
            timeZoneId: arrInfo.timeZoneIdentifier
        )
        
        // Build night periods (sunset to sunrise)
        var nightPeriods: [(start: Date, end: Date)] = []
        
        // Night period 1: Evening of flight date to morning of next day (departure airport)
        if let eveningSunset = depTwilight.eveningCivilTwilight,
           let morningSunrise = depTwilightNextDay.morningCivilTwilight {
            nightPeriods.append((start: eveningSunset, end: morningSunrise))
        }
        
        // Night period 2: Evening of flight date to morning of next day (arrival airport)
        if let eveningSunset = arrTwilight.eveningCivilTwilight,
           let morningSunrise = arrTwilightNextDay.morningCivilTwilight {
            nightPeriods.append((start: eveningSunset, end: morningSunrise))
        }
        
        // Night period before departure (if applicable - very early morning flights)
        if let morningSunrise = depTwilight.morningCivilTwilight {
            let startOfDay = Calendar.current.startOfDay(for: flightDate)
            nightPeriods.append((start: startOfDay, end: morningSunrise))
        }
        
        // Calculate total night time by finding overlap between flight and night periods
        let totalNightSeconds = calculateOverlapWithNightPeriods(
            flightStart: outTime,
            flightEnd: inTime,
            nightPeriods: nightPeriods
        )
        
        print("🌙 Night calculation: \(departure)→\(arrival)")
        print("   Flight: \(formatTime(outTime)) - \(formatTime(inTime)) UTC")
        print("   Night periods checked: \(nightPeriods.count)")
        print("   Night time: \(formatDuration(totalNightSeconds))")
        
        return totalNightSeconds
    }
    
    /// Check if a specific time is during night (for takeoff/landing tracking)
    /// - Parameters:
    ///   - time: The time to check (in GMT/Zulu)
    ///   - airportCode: ICAO code of the airport
    ///   - date: The date of the operation
    /// - Returns: True if the time is during night (after evening civil twilight or before morning civil twilight)
    func isNightTime(
        time: Date,
        airportCode: String,
        date: Date
    ) async -> Bool {
        guard let airportInfo = await airportManager.getAirportInfo(airportCode) else {
            // Fallback: use simple hour check
            let hour = Calendar.current.component(.hour, from: time)
            return hour >= 19 || hour < 6
        }
        
        let twilight = calculateTwilightTimes(
            for: airportInfo.coordinate,
            date: date,
            timeZoneId: airportInfo.timeZoneIdentifier
        )
        
        // Check if time is before morning twilight
        if let morning = twilight.morningCivilTwilight, time < morning {
            return true
        }
        
        // Check if time is after evening twilight
        if let evening = twilight.eveningCivilTwilight, time > evening {
            return true
        }
        
        return false
    }
    
    /// Determine if takeoff was at night
    func isNightTakeoff(offTime: Date, departureAirport: String, flightDate: Date) async -> Bool {
        return await isNightTime(time: offTime, airportCode: departureAirport, date: flightDate)
    }
    
    /// Determine if landing was at night
    func isNightLanding(onTime: Date, arrivalAirport: String, flightDate: Date) async -> Bool {
        return await isNightTime(time: onTime, airportCode: arrivalAirport, date: flightDate)
    }
    
    // MARK: - Twilight Calculation
    
    struct TwilightTimes {
        let morningCivilTwilight: Date?  // End of night (sunrise - 30min approx)
        let eveningCivilTwilight: Date?  // Start of night (sunset + 30min approx)
    }
    
    private func calculateTwilightTimes(
        for coordinate: CLLocationCoordinate2D,
        date: Date,
        timeZoneId: String
    ) -> TwilightTimes {
        
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: timeZoneId) ?? TimeZone.current
        
        // Get base sunset/sunrise times using simple solar calculation
        let (sunriseHour, sunriseMinute) = calculateSunrise(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: timeZone
        )
        
        let (sunsetHour, sunsetMinute) = calculateSunset(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: timeZone
        )
        
        // Create morning civil twilight (approximately 30 minutes before sunrise)
        var morningComponents = calendar.dateComponents(in: timeZone, from: date)
        morningComponents.hour = sunriseHour
        morningComponents.minute = sunriseMinute - civilTwilightOffsetMinutes
        morningComponents.second = 0
        
        // Handle minute underflow
        if morningComponents.minute! < 0 {
            morningComponents.minute! += 60
            morningComponents.hour! -= 1
        }
        
        let morningTwilight = calendar.date(from: morningComponents)
        
        // Create evening civil twilight (approximately 30 minutes after sunset)
        var eveningComponents = calendar.dateComponents(in: timeZone, from: date)
        eveningComponents.hour = sunsetHour
        eveningComponents.minute = sunsetMinute + civilTwilightOffsetMinutes
        eveningComponents.second = 0
        
        // Handle minute overflow
        if eveningComponents.minute! >= 60 {
            eveningComponents.minute! -= 60
            eveningComponents.hour! += 1
        }
        
        let eveningTwilight = calendar.date(from: eveningComponents)
        
        return TwilightTimes(
            morningCivilTwilight: morningTwilight,
            eveningCivilTwilight: eveningTwilight
        )
    }
    
    // MARK: - Solar Calculations (Simplified)
    
    private func calculateSunrise(
        latitude: Double,
        longitude: Double,
        date: Date,
        timeZone: TimeZone
    ) -> (hour: Int, minute: Int) {
        // Simplified sunrise calculation
        // Based on latitude and day of year
        
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // Base sunrise time (6:00 at equator, equinox)
        var baseHour = 6.0
        
        // Latitude adjustment (higher latitudes = earlier summer sunrise, later winter sunrise)
        let latitudeEffect = abs(latitude) / 90.0 * 2.0  // Up to 2 hours adjustment
        
        // Seasonal adjustment based on day of year
        // Day 172 = summer solstice (longest day in northern hemisphere)
        // Day 355 = winter solstice (shortest day in northern hemisphere)
        let daysFromSummerSolstice = abs(dayOfYear - 172)
        let seasonalFactor = Double(daysFromSummerSolstice) / 183.0  // 0 at summer, 1 at winter
        
        if latitude >= 0 {
            // Northern hemisphere
            baseHour -= latitudeEffect * (1.0 - seasonalFactor)  // Earlier in summer
            baseHour += latitudeEffect * seasonalFactor          // Later in winter
        } else {
            // Southern hemisphere (reversed seasons)
            baseHour += latitudeEffect * (1.0 - seasonalFactor)
            baseHour -= latitudeEffect * seasonalFactor
        }
        
        // Longitude adjustment (15° = 1 hour, relative to timezone center)
        let tzOffset = Double(timeZone.secondsFromGMT()) / 3600.0
        let tzCenterLongitude = tzOffset * 15.0
        let longitudeAdjustment = (longitude - tzCenterLongitude) / 15.0 * -1.0
        baseHour += longitudeAdjustment
        
        // Clamp to reasonable values
        baseHour = max(4.0, min(9.0, baseHour))
        
        let hour = Int(baseHour)
        let minute = Int((baseHour - Double(hour)) * 60)
        
        return (hour, minute)
    }
    
    private func calculateSunset(
        latitude: Double,
        longitude: Double,
        date: Date,
        timeZone: TimeZone
    ) -> (hour: Int, minute: Int) {
        // Simplified sunset calculation
        
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // Base sunset time (18:00 at equator, equinox)
        var baseHour = 18.0
        
        // Latitude adjustment
        let latitudeEffect = abs(latitude) / 90.0 * 2.0
        
        // Seasonal adjustment
        let daysFromSummerSolstice = abs(dayOfYear - 172)
        let seasonalFactor = Double(daysFromSummerSolstice) / 183.0
        
        if latitude >= 0 {
            // Northern hemisphere
            baseHour += latitudeEffect * (1.0 - seasonalFactor)  // Later in summer
            baseHour -= latitudeEffect * seasonalFactor          // Earlier in winter
        } else {
            // Southern hemisphere
            baseHour -= latitudeEffect * (1.0 - seasonalFactor)
            baseHour += latitudeEffect * seasonalFactor
        }
        
        // Longitude adjustment
        let tzOffset = Double(timeZone.secondsFromGMT()) / 3600.0
        let tzCenterLongitude = tzOffset * 15.0
        let longitudeAdjustment = (longitude - tzCenterLongitude) / 15.0 * -1.0
        baseHour += longitudeAdjustment
        
        // Clamp to reasonable values
        baseHour = max(16.0, min(21.0, baseHour))
        
        let hour = Int(baseHour)
        let minute = Int((baseHour - Double(hour)) * 60)
        
        return (hour, minute)
    }
    
    // MARK: - Night Time Overlap Calculation
    
    private func calculateOverlapWithNightPeriods(
        flightStart: Date,
        flightEnd: Date,
        nightPeriods: [(start: Date, end: Date)]
    ) -> TimeInterval {
        
        // Merge overlapping night periods first
        let mergedPeriods = mergeOverlappingPeriods(nightPeriods)
        
        var totalNightTime: TimeInterval = 0
        
        for nightPeriod in mergedPeriods {
            // Find the overlap between flight time and this night period
            let overlapStart = max(flightStart, nightPeriod.start)
            let overlapEnd = min(flightEnd, nightPeriod.end)
            
            if overlapStart < overlapEnd {
                let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
                totalNightTime += overlapDuration
                
                print("   ↳ Night overlap: \(formatTime(overlapStart)) - \(formatTime(overlapEnd)) = \(formatDuration(overlapDuration))")
            }
        }
        
        return totalNightTime
    }
    
    private func mergeOverlappingPeriods(_ periods: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !periods.isEmpty else { return [] }
        
        let sorted = periods.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]
        
        for period in sorted.dropFirst() {
            let lastIndex = merged.count - 1
            if period.start <= merged[lastIndex].end {
                // Overlapping or adjacent - merge
                merged[lastIndex].end = max(merged[lastIndex].end, period.end)
            } else {
                // No overlap - add new period
                merged.append(period)
            }
        }
        
        return merged
    }
    
    // MARK: - Fallback Estimation
    
    private func estimateNightHours(outTime: Date, inTime: Date, flightDate: Date) -> TimeInterval {
        let calendar = Calendar.current
        var totalNightTime: TimeInterval = 0
        
        // Sample every 15 minutes during the flight
        var currentTime = outTime
        let sampleInterval: TimeInterval = 15 * 60  // 15 minutes
        
        while currentTime < inTime {
            let hour = calendar.component(.hour, from: currentTime)
            
            // Rough estimate: night is between 7 PM (19:00) and 6 AM (06:00)
            let isNight = hour >= 19 || hour < 6
            
            if isNight {
                let segmentEnd = min(currentTime.addingTimeInterval(sampleInterval), inTime)
                let segmentDuration = segmentEnd.timeIntervalSince(currentTime)
                totalNightTime += segmentDuration
            }
            
            currentTime = currentTime.addingTimeInterval(sampleInterval)
        }
        
        print("⚠️ Used estimated night hours: \(formatDuration(totalNightTime))")
        return totalNightTime
    }
    
    // MARK: - Convenience Methods
    
    /// Get airport name for display purposes
    func getAirportName(for icao: String) async -> String {
        if let info = await airportManager.getAirportInfo(icao) {
            return info.airportName
        }
        return "Unknown Airport"
    }
    
    /// Get cache status for debugging
    func getCacheStatus() -> (staticCount: Int, dynamicCount: Int) {
        let staticCount = airportManager.getAllBuiltInAirports().count
        let dynamicCount = airportManager.getAllAirports().count
        return (staticCount: staticCount, dynamicCount: dynamicCount)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

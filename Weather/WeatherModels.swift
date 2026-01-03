//
//  WeatherModels.swift
//  TheProPilotApp
//
//  Unified Weather Data Models
//  Shared across Weather Tab, Weather Banner, and Airport Detail Views
//

import Foundation
import SwiftUI

// MARK: - Primary METAR Model (from aviationweather.gov API)
struct RawMETAR: Codable {
    let icaoId: String
    let rawOb: String
    let flightCategory: String?
    let temp: Double?
    let dewp: Double?
    let wdirRaw: WindDirection?
    let wspd: Int?
    let wgst: Int?
    let visibRaw: VisibilityValue?
    let altim: Double?       // Altimeter in inHg (e.g., 29.92)
    let slp: Double?         // Sea level pressure in hPa/mb (e.g., 1013.25)
    let elev: Double?        // Station elevation in meters from API
    let cover: String?
    let wxString: String?
    let obsTime: Int?        // Unix timestamp
    let reportTime: String?

    enum CodingKeys: String, CodingKey {
        case icaoId, rawOb, flightCategory, temp, dewp, wspd, wgst, altim, slp, elev, cover, wxString, obsTime, reportTime
        case wdirRaw = "wdir"
        case visibRaw = "visib"
    }

    /// Station elevation in feet (converted from meters)
    var elevationFeet: Int? {
        guard let elevMeters = elev else { return nil }
        return Int(elevMeters * 3.28084)
    }
    
    // MARK: - Computed Properties
    
    var windDirection: Int? {
        if case .degrees(let value) = wdirRaw {
            return value
        }
        return nil
    }
    
    var visibility: Double? {
        guard let visibVal = visibRaw else { return nil }
        
        switch visibVal {
        case .number(let value):
            return value
        case .text(let str):
            if str.contains("+") {
                return 10.0
            }
            return Double(str)
        }
    }
    
    var observationTime: String? {
        if let reportTime = reportTime {
            return reportTime
        }
        if let timestamp = obsTime {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date)
        }
        return nil
    }

    /// Observation time formatted in local timezone with timezone abbreviation
    var observationTimeLocal: String? {
        guard let timestamp = obsTime else { return nil }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        let timeString = formatter.string(from: date)

        // Get timezone abbreviation (e.g., "EST", "PST", "CDT")
        let tzAbbrev = TimeZone.current.abbreviation() ?? "Local"
        return "\(timeString) \(tzAbbrev)"
    }
    
    var timeAgo: String {
        guard let timestamp = obsTime else { return "Unknown" }
        
        let observationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let elapsed = now.timeIntervalSince(observationDate)
        
        let minutes = Int(elapsed / 60)
        let hours = Int(elapsed / 3600)
        let days = Int(elapsed / 86400)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else if hours < 24 {
            return "\(hours) hr"
        } else {
            return "\(days) day"
        }
    }
    
    /// Temperature/Dewpoint spread in °C (useful for icing risk)
    var tempDewpointSpread: Double? {
        guard let t = temp, let d = dewp else { return nil }
        return t - d
    }
    
    /// Check if icing conditions are likely (spread ≤ 3°C)
    var isIcingRisk: Bool {
        guard let spread = tempDewpointSpread else { return false }
        return spread <= 3.0
    }
    
    /// Relative humidity percentage
    var relativeHumidity: Int? {
        guard let t = temp, let d = dewp else { return nil }
        let humidity = 100 * (exp((17.625 * d) / (243.04 + d)) / exp((17.625 * t) / (243.04 + t)))
        return Int(humidity)
    }
}

// MARK: - TAF Model
struct RawTAF: Codable {
    let icaoId: String
    let rawTAF: String
    let issueTimeRaw: IssueTimeValue?

    enum CodingKeys: String, CodingKey {
        case icaoId, rawTAF
        case issueTimeRaw = "issueTime"
    }

    var issueTimeString: String? {
        guard let issueTimeVal = issueTimeRaw else { return nil }

        switch issueTimeVal {
        case .timestamp(let timestamp):
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd, HH:mm'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date)
        case .string(let str):
            return str
        }
    }
}

// Handle issueTime that can be Int (timestamp) or String
enum IssueTimeValue: Codable {
    case timestamp(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .timestamp(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                IssueTimeValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or String for issueTime"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .timestamp(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Wind Direction Enum (handles both Int and String)
enum WindDirection: Codable {
    case degrees(Int)
    case text(String)  // "VRB" for variable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .degrees(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                WindDirection.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or String for wind direction"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .degrees(let value):
            try container.encode(value)
        case .text(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Visibility Value Enum (handles both Double and String)
enum VisibilityValue: Codable {
    case number(Double)
    case text(String)  // "10+" or "1/2SM"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                VisibilityValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Double or String for visibility"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .text(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Legacy Weather Models (for backwards compatibility)

/// Legacy WeatherData model (used by AirportWeatherService)
struct WeatherData {
    let rawText: String
    let observedTime: String?
    let wind: String?
    let visibility: String?
    let temperature: String?
    let altimeter: String?
}

/// Legacy Airport Weather model (for Weather Tab)
struct AirportWeather: Identifiable {
    let id = UUID()
    let icao: String
    let name: String
    let metar: METARData?
    let taf: TAFData?
    let hasTAF: Bool
    var isFavorite: Bool
    var distance: Double?
}

/// Legacy METAR model (for Weather Tab)
struct METARData {
    let rawOb: String
    let flightCategory: String?
    let temp: Double?
    let dewpoint: Double?
    let windDir: Int?
    let windSpeed: Int?
    let windGust: Int?
    let visibility: Double?
    let altimeter: Double?
    let clouds: String?
    let wxString: String?
    let obsTime: String?
    
    var categoryColor: Color {
        switch flightCategory {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return .purple
        default: return .gray
        }
    }
    
    var humidity: Int? {
        guard let t = temp, let d = dewpoint else { return nil }
        let humidity = 100 * (exp((17.625 * d) / (243.04 + d)) / exp((17.625 * t) / (243.04 + t)))
        return Int(humidity)
    }
}

/// Legacy TAF model (for Weather Tab)
struct TAFData {
    let rawTAF: String
    let issueTime: String?
    let validFrom: String?
    let validTo: String?
}

// MARK: - Helper Extensions

extension RawMETAR {
    /// Convert to formatted pressure string based on user preference
    func formattedPressure(useInHg: Bool) -> String? {
        if useInHg {
            // Use altim - but check if it's in millibars (> 100) and convert
            guard let pressure = altim else { return nil }
            // API sometimes returns millibars in altim field (e.g., 1013.25 instead of 29.92)
            let pressureInHg = pressure > 100 ? pressure / 33.8639 : pressure
            return String(format: "%.2f inHg", pressureInHg)
        } else {
            // Use slp (sea level pressure in hPa/mb), or convert altim if slp unavailable
            if let pressure = slp {
                return String(format: "%.0f mb", pressure)
            } else if let pressure = altim {
                // Convert from inHg to mb if needed
                let pressureMb = pressure > 100 ? pressure : pressure * 33.8639
                return String(format: "%.0f mb", pressureMb)
            }
            return nil
        }
    }
    
    /// Get pressure value based on user preference
    func pressureValue(useInHg: Bool) -> Double? {
        return useInHg ? altim : slp
    }
    
    /// Convert temperature to formatted string based on user preference
    func formattedTemperature(_ celsius: Double?, useCelsius: Bool) -> String? {
        guard let temp = celsius else { return nil }
        if useCelsius {
            return String(format: "%.0f°C", temp)
        } else {
            let fahrenheit = (temp * 9/5) + 32
            return String(format: "%.0f°F", fahrenheit)
        }
    }
    
    /// Temperature in user's preferred unit
    func temperature(useCelsius: Bool) -> String? {
        return formattedTemperature(temp, useCelsius: useCelsius)
    }
    
    /// Dewpoint in user's preferred unit
    func dewpoint(useCelsius: Bool) -> String? {
        return formattedTemperature(dewp, useCelsius: useCelsius)
    }
    
    /// Temperature and dewpoint combined string
    func temperatureAndDewpoint(useCelsius: Bool) -> String? {
        guard let t = temp, let d = dewp else { return nil }
        if useCelsius {
            return "\(Int(t))°C / \(Int(d))°C"
        } else {
            let tempF = (t * 9/5) + 32
            let dewF = (d * 9/5) + 32
            return "\(Int(tempF))°F / \(Int(dewF))°F"
        }
    }
}

// MARK: - Flight Category Colors
extension String {
    var flightCategoryColor: Color {
        switch self {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return .purple
        default: return .gray
        }
    }
}

// MARK: - MOS (Model Output Statistics) Data Models
// Data from Iowa State Mesonet: https://mesonet.agron.iastate.edu/api/1/mos.json

struct MOSResponse: Codable {
    let data: [MOSForecast]?

    private enum CodingKeys: String, CodingKey {
        case data
    }

    // Handle flexible response structure including pandas DataFrame format
    init(from decoder: Decoder) throws {
        // Try pandas DataFrame format first: {"schema": {...}, "data": [...]}
        if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self),
           let forecasts = try? keyedContainer.decode([MOSForecast].self, forKey: .data) {
            self.data = forecasts
            return
        }

        // Try direct array format
        if let container = try? decoder.singleValueContainer(),
           let array = try? container.decode([MOSForecast].self) {
            self.data = array
            return
        }

        self.data = nil
    }
}

struct MOSForecast: Codable, Identifiable {
    var id: String { "\(station ?? "")-\(ftime ?? "")" }

    let station: String?
    let model: String?
    let runtime: String?      // Model run time
    let ftime: String?        // Forecast valid time
    let tmp: Int?             // Temperature (°F)
    let dpt: Int?             // Dewpoint (°F)
    let wdr: Int?             // Wind direction (multiply by 10 for degrees)
    let wsp: Int?             // Wind speed (knots)
    let wgs: Int?             // Wind gust (knots)
    let p06: Int?             // 6-hour precipitation probability (%)
    let p12: Int?             // 12-hour precipitation probability (%)
    let qpf: String?          // Quantitative Precipitation Forecast
    let cld: String?          // Cloud cover (CL=Clear, FW=Few, SC=Scattered, BK=Broken, OV=Overcast)
    let vis: Int?             // Visibility category
    let obv: String?          // Obstruction to vision
    let poz: Int?             // Probability of freezing precip (%)
    let pos: Int?             // Probability of snow (%)
    let typ: String?          // Precipitation type

    // Computed properties
    var windDirectionDegrees: Int? {
        guard let dir = wdr else { return nil }
        return dir * 10
    }

    var cloudCoverDescription: String {
        switch cld?.uppercased() {
        case "CL": return "Clear"
        case "FW": return "Few"
        case "SC": return "Scattered"
        case "BK": return "Broken"
        case "OV": return "Overcast"
        default: return cld ?? "N/A"
        }
    }

    var forecastTime: Date? {
        guard let ftime = ftime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ftime) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ftime)
    }

    var forecastHourString: String {
        guard let date = forecastTime else { return ftime ?? "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Winds Aloft Model
struct WindsAloftData: Identifiable {
    var id: Int { altitude }

    let altitude: Int         // Altitude in feet (3000, 6000, 9000, etc.)
    let direction: Int?       // Wind direction in degrees
    let speed: Int?           // Wind speed in knots
    let temperature: Int?     // Temperature in Celsius (only above 6000ft)
    let sourceStation: String? // The station this data came from (if different from requested airport)

    init(altitude: Int, direction: Int?, speed: Int?, temperature: Int?, sourceStation: String? = nil) {
        self.altitude = altitude
        self.direction = direction
        self.speed = speed
        self.temperature = temperature
        self.sourceStation = sourceStation
    }

    var windString: String {
        guard let dir = direction, let spd = speed else { return "N/A" }
        if dir == 0 && spd == 0 {
            return "Calm"
        } else if dir == 990 {
            return "Light & Variable"
        }
        return "\(String(format: "%03d", dir))@\(spd)"
    }
}

// MARK: - Daily Forecast Model (from weather.gov)
struct DailyForecastData: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)" }

    let date: Date
    let name: String          // "Today", "Tonight", "Monday", etc.
    let highTemp: Int?
    let lowTemp: Int?
    let shortForecast: String // "Partly Cloudy"
    let detailedForecast: String
    let precipChance: Int?
    let icon: String          // SF Symbol name
    let windSpeed: String?    // "5 to 10 mph" or "15 mph"
    let windDirection: String? // "SSE", "W", "NNW"
    let isDaytime: Bool

    var temperatureString: String {
        if let high = highTemp, let low = lowTemp {
            return "\(high)°/\(low)°"
        } else if let high = highTemp {
            return "High: \(high)°"
        } else if let low = lowTemp {
            return "Low: \(low)°"
        }
        return "N/A"
    }

    var windString: String? {
        guard let speed = windSpeed, !speed.isEmpty else { return nil }
        if let dir = windDirection, !dir.isEmpty {
            return "\(dir) \(speed)"
        }
        return speed
    }
}

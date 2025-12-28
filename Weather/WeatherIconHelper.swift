//
//  WeatherIconHelper.swift
//  TheProPilotApp
//
//  Centralized weather icon and color system
//  Used by: WeatherConditionIcon, WeatherBannerView, WeatherTab, etc.
//

import SwiftUI

/// Centralized weather icon logic for consistent weather visualization across the app
struct WeatherIconHelper {
    
    // MARK: - Weather Icon Selection
    
    /// Get the appropriate SF Symbol for weather conditions
    /// - Parameters:
    ///   - weather: RawMETAR data
    ///   - filled: Whether to use filled variants (default: true)
    /// - Returns: SF Symbol name
    static func icon(for weather: RawMETAR?, filled: Bool = true) -> String {
        guard let weather = weather else {
            return filled ? "cloud.fill" : "cloud"
        }
        
        let wx = weather.wxString?.uppercased() ?? ""
        let raw = weather.rawOb.uppercased()
        
        // Check time of day for sun/moon
        let isNight = isNightTime()
        let sunMoonBase = isNight ? "cloud.moon" : "cloud.sun"
        let suffix = filled ? ".fill" : ""
        
        // PRIORITY ORDER (most severe first)
        
        // Thunderstorms (highest priority - most dangerous)
        if wx.contains("TS") || raw.contains("TS") {
            return "cloud.bolt.rain.fill"  // Always filled for emphasis
        }
        
        // Heavy rain
        if wx.contains("+RA") || wx.contains("TSRA") {
            return "cloud.heavyrain\(suffix)"
        }
        
        // Rain
        if wx.contains("RA") || wx.contains("-RA") {
            return "cloud.rain\(suffix)"
        }
        
        // Drizzle
        if wx.contains("DZ") {
            return "cloud.drizzle\(suffix)"
        }
        
        // Snow
        if wx.contains("SN") || wx.contains("+SN") || wx.contains("-SN") {
            return "cloud.snow\(suffix)"
        }
        
        // Sleet / Freezing rain
        if wx.contains("FZRA") || wx.contains("PL") {
            return "cloud.sleet\(suffix)"
        }
        
        // Hail
        if wx.contains("GR") || wx.contains("GS") {
            return "cloud.hail\(suffix)"
        }
        
        // Fog / Mist / Haze
        if wx.contains("FG") || wx.contains("BR") || wx.contains("HZ") {
            return "cloud.fog\(suffix)"
        }
        
        // Check cloud coverage from raw METAR
        // Overcast / Broken
        if raw.contains("OVC") || raw.contains("BKN") {
            return "cloud\(suffix)"
        }
        
        // Scattered
        if raw.contains("SCT") {
            return "\(sunMoonBase)\(suffix)"
        }
        
        // Few clouds
        if raw.contains("FEW") {
            return "\(sunMoonBase)\(suffix)"
        }
        
        // Clear skies (CLR or SKC in METAR)
        if raw.contains(" CLR ") || raw.contains(" SKC ") {
            return isNight ? "moon.stars\(suffix)" : "sun.max\(suffix)"
        }
        
        // Default to cloud with sun/moon
        return filled ? "\(sunMoonBase).fill" : sunMoonBase
    }
    
    // MARK: - Weather Color Selection
    
    /// Get the appropriate color for weather conditions
    /// - Parameter weather: RawMETAR data
    /// - Returns: Color for the weather condition
    static func color(for weather: RawMETAR?) -> Color {
        guard let weather = weather else {
            return .gray
        }
        
        let wx = weather.wxString?.uppercased() ?? ""
        
        // PRIORITY ORDER (most severe first)
        
        // Thunderstorms - purple (severe weather)
        if wx.contains("TS") {
            return Color.purple
        }
        
        // Heavy precipitation - dark blue
        if wx.contains("+RA") || wx.contains("+SN") || wx.contains("TSRA") {
            return Color.blue.opacity(0.8)
        }
        
        // Rain/Snow/Drizzle - blue
        if wx.contains("RA") || wx.contains("SN") || wx.contains("DZ") {
            return Color.blue
        }
        
        // Freezing/Sleet - cyan (icing conditions)
        if wx.contains("FZRA") || wx.contains("PL") {
            return Color.cyan
        }
        
        // Fog/Mist/Haze - gray
        if wx.contains("FG") || wx.contains("BR") || wx.contains("HZ") {
            return Color.gray
        }
        
        // Check flight category (fallback for conditions without precipitation)
        if let category = weather.flightCategory {
            switch category {
            case "VFR":
                return Color.green
            case "MVFR":
                return Color.blue
            case "IFR":
                return Color.orange
            case "LIFR":
                return Color.red
            default:
                return Color.gray
            }
        }
        
        return LogbookTheme.accentBlue
    }
    
    // MARK: - Weather Description
    
    /// Get a human-readable description of weather conditions
    /// - Parameter weather: RawMETAR data
    /// - Returns: Text description (e.g., "Thunderstorms", "Light Rain", "Clear Skies")
    static func description(for weather: RawMETAR?) -> String {
        guard let weather = weather else {
            return "Unknown"
        }
        
        let wx = weather.wxString?.uppercased() ?? ""
        let raw = weather.rawOb.uppercased()
        
        // Priority order
        if wx.contains("TS") || raw.contains("TS") {
            return "Thunderstorms"
        }
        
        if wx.contains("+RA") || wx.contains("TSRA") {
            return "Heavy Rain"
        }
        
        if wx.contains("RA") {
            return wx.contains("-RA") ? "Light Rain" : "Rain"
        }
        
        if wx.contains("DZ") {
            return "Drizzle"
        }
        
        if wx.contains("+SN") {
            return "Heavy Snow"
        }
        
        if wx.contains("SN") {
            return wx.contains("-SN") ? "Light Snow" : "Snow"
        }
        
        if wx.contains("FZRA") {
            return "Freezing Rain"
        }
        
        if wx.contains("PL") {
            return "Ice Pellets"
        }
        
        if wx.contains("GR") || wx.contains("GS") {
            return "Hail"
        }
        
        if wx.contains("FG") {
            return "Fog"
        }
        
        if wx.contains("BR") {
            return "Mist"
        }
        
        if wx.contains("HZ") {
            return "Haze"
        }
        
        // Check cloud coverage
        if raw.contains("OVC") {
            return "Overcast"
        }
        
        if raw.contains("BKN") {
            return "Broken Clouds"
        }
        
        if raw.contains("SCT") {
            return "Scattered Clouds"
        }
        
        if raw.contains("FEW") {
            return "Few Clouds"
        }
        
        if raw.contains(" CLR ") || raw.contains(" SKC ") {
            return "Clear Skies"
        }
        
        // Fallback to flight category
        if let category = weather.flightCategory {
            return category
        }
        
        return "Unknown"
    }
    
    // MARK: - Helper Methods
    
    /// Check if it's nighttime (simple 6pm-6am check)
    /// For more accurate results, use sunrise/sunset times based on location
    private static func isNightTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 6
    }
    
    /// Check if conditions are severe (requiring immediate attention)
    static func isSevereWeather(_ weather: RawMETAR?) -> Bool {
        guard let weather = weather else { return false }
        
        let wx = weather.wxString?.uppercased() ?? ""
        
        // Severe conditions
        return wx.contains("TS") ||        // Thunderstorms
               wx.contains("+RA") ||       // Heavy rain
               wx.contains("+SN") ||       // Heavy snow
               wx.contains("FZRA") ||      // Freezing rain
               wx.contains("GR") ||        // Hail
               weather.flightCategory == "LIFR"  // Low IFR
    }
    
    /// Check if icing conditions are present
    static func hasIcingConditions(_ weather: RawMETAR?) -> Bool {
        guard let weather = weather else { return false }
        
        let wx = weather.wxString?.uppercased() ?? ""
        
        return wx.contains("FZRA") ||      // Freezing rain
               wx.contains("FZDZ") ||      // Freezing drizzle
               wx.contains("PL") ||        // Ice pellets
               weather.isIcingRisk         // Temp/dewpoint spread check
    }
}

// MARK: - Weather Icon View Component

/// Reusable weather icon view with consistent styling
struct WeatherIcon: View {
    let weather: RawMETAR?
    let size: CGFloat
    let filled: Bool
    let showBackground: Bool
    
    init(weather: RawMETAR?, size: CGFloat = 24, filled: Bool = true, showBackground: Bool = false) {
        self.weather = weather
        self.size = size
        self.filled = filled
        self.showBackground = showBackground
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                Circle()
                    .fill(WeatherIconHelper.color(for: weather).opacity(0.2))
                    .frame(width: size * 1.5, height: size * 1.5)
            }
            
            Image(systemName: WeatherIconHelper.icon(for: weather, filled: filled))
                .font(.system(size: size, weight: .medium))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(WeatherIconHelper.color(for: weather))
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
struct WeatherIconHelper_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Weather Icon System")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .padding()
                
                // Sample weather conditions with unique IDs
                ForEach(Array(sampleConditions.enumerated()), id: \.offset) { index, sample in
                    HStack {
                        WeatherIcon(weather: sample.weather, size: 30, showBackground: true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            Text(WeatherIconHelper.description(for: sample.weather))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if let category = sample.weather?.flightCategory {
                            Text(category)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(WeatherIconHelper.color(for: sample.weather))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // Sample weather conditions for preview
    static var sampleConditions: [(title: String, weather: RawMETAR?)] {
        return [
            (title: "Thunderstorms", weather: createMockMETAR(wx: "TS", category: "IFR")),
            (title: "Heavy Rain", weather: createMockMETAR(wx: "+RA", category: "MVFR")),
            (title: "Light Rain", weather: createMockMETAR(wx: "-RA", category: "MVFR")),
            (title: "Snow", weather: createMockMETAR(wx: "SN", category: "IFR")),
            (title: "Freezing Rain", weather: createMockMETAR(wx: "FZRA", category: "LIFR")),
            (title: "Fog", weather: createMockMETAR(wx: "FG", category: "LIFR")),
            (title: "Overcast", weather: createMockMETAR(wx: "", category: "MVFR", raw: "OVC010")),
            (title: "Scattered", weather: createMockMETAR(wx: "", category: "VFR", raw: "SCT040")),
            (title: "Clear", weather: createMockMETAR(wx: "", category: "VFR", raw: "CLR"))
        ]
    }
    
    // Helper to create mock METAR data for preview
    static func createMockMETAR(wx: String, category: String, raw: String = "") -> RawMETAR {
        // Create minimal mock data for preview
        return RawMETAR(
            icaoId: "KORD",
            rawOb: raw.isEmpty ? "KORD 121856Z 27015KT 10SM \(wx) 20/18 A2990" : "KORD 121856Z 27015KT 10SM \(raw) 20/18 A2990",
            flightCategory: category,
            temp: 20,
            dewp: 18,
            wdirRaw: .degrees(270),
            wspd: 15,
            wgst: nil,
            visibRaw: .number(10),
            altim: 29.90,
            slp: 1013.25,
            elev: nil,
            cover: raw.isEmpty ? nil : raw,
            wxString: wx.isEmpty ? nil : wx,
            obsTime: Int(Date().timeIntervalSince1970),
            reportTime: nil
        )
    }
}
#endif

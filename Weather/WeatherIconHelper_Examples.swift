//
//  EXAMPLE: Using WeatherIconHelper Throughout the App
//
//  This file shows practical examples of how to use the centralized
//  weather icon system in different contexts across the app.
//

import SwiftUI

// MARK: - Example 1: Simple Weather Display in List

struct AirportWeatherRow: View {
    let airport: String
    let weather: RawMETAR?
    
    var body: some View {
        HStack(spacing: 12) {
            // ✅ Easy 1-line weather icon
            WeatherIcon(weather: weather, size: 24, showBackground: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(airport)
                    .font(.headline)
                
                Text(WeatherIconHelper.description(for: weather))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let category = weather?.flightCategory {
                Text(category)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WeatherIconHelper.color(for: weather))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Example 2: Weather Alert Badge

struct WeatherAlertBadge: View {
    let weather: RawMETAR?
    
    var body: some View {
        if WeatherIconHelper.isSevereWeather(weather) {
            HStack(spacing: 4) {
                WeatherIcon(weather: weather, size: 16)
                
                Text("SEVERE WEATHER")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        } else if WeatherIconHelper.hasIcingConditions(weather) {
            HStack(spacing: 4) {
                Image(systemName: "snowflake")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Text("ICING CONDITIONS")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.cyan)
            .cornerRadius(6)
        }
    }
}

// MARK: - Example 3: Airport Detail Header

struct AirportDetailHeader: View {
    let airport: String
    let weather: RawMETAR?
    
    var body: some View {
        VStack(spacing: 12) {
            // Large weather icon
            WeatherIcon(weather: weather, size: 60, showBackground: true)
            
            Text(airport)
                .font(.largeTitle.bold())
            
            Text(WeatherIconHelper.description(for: weather))
                .font(.title3)
                .foregroundColor(.gray)
            
            if let category = weather?.flightCategory {
                Text(category)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(WeatherIconHelper.color(for: weather))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

// MARK: - Example 4: Compact Weather Card

struct CompactWeatherCard: View {
    let airport: String
    let weather: RawMETAR?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(airport)
                    .font(.headline.bold())
                
                Spacer()
                
                WeatherIcon(weather: weather, size: 24)
            }
            
            if let temp = weather?.temperature(useCelsius: false) {
                Text(temp)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            Text(WeatherIconHelper.description(for: weather))
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WeatherIconHelper.color(for: weather).opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(WeatherIconHelper.color(for: weather).opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Example 5: Multi-Airport Weather Strip

struct WeatherStripView: View {
    let airports: [String: RawMETAR]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(airports.keys.sorted()), id: \.self) { airport in
                    VStack(spacing: 8) {
                        WeatherIcon(weather: airports[airport], size: 32, showBackground: true)
                        
                        Text(airport)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        if let temp = airports[airport]?.temperature(useCelsius: false) {
                            Text(temp)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 80, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Example 6: Weather Notification Content

struct WeatherNotificationView: View {
    let weather: RawMETAR?
    let airport: String
    
    var body: some View {
        HStack(spacing: 16) {
            WeatherIcon(weather: weather, size: 40, showBackground: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather Update")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                
                Text("\(airport): \(WeatherIconHelper.description(for: weather))")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if WeatherIconHelper.isSevereWeather(weather) {
                    Text("⚠️ Severe weather conditions")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }
}

// MARK: - Example 7: Widget Weather Display

struct WidgetWeatherView: View {
    let weather: RawMETAR?
    let airport: String
    
    var body: some View {
        VStack(spacing: 4) {
            WeatherIcon(weather: weather, size: 32)
            
            Text(airport)
                .font(.caption.bold())
            
            if let temp = weather?.temperature(useCelsius: false) {
                Text(temp)
                    .font(.title3.bold())
            }
            
            Text(WeatherIconHelper.description(for: weather))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
    }
}

// MARK: - Example 8: Route Weather Overview

struct RouteWeatherView: View {
    let route: [(airport: String, weather: RawMETAR?)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Weather")
                .font(.headline)
            
            ForEach(Array(route.enumerated()), id: \.offset) { index, leg in
                HStack(spacing: 12) {
                    // Position indicator
                    ZStack {
                        Circle()
                            .fill(WeatherIconHelper.color(for: leg.weather).opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    
                    // Weather icon
                    WeatherIcon(weather: leg.weather, size: 24)
                    
                    // Airport and conditions
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.airport)
                            .font(.subheadline.bold())
                        
                        Text(WeatherIconHelper.description(for: leg.weather))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Warning badges
                    if WeatherIconHelper.isSevereWeather(leg.weather) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else if WeatherIconHelper.hasIcingConditions(leg.weather) {
                        Image(systemName: "snowflake")
                            .foregroundColor(.cyan)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
                
                if index < route.count - 1 {
                    Image(systemName: "arrow.down")
                        .foregroundColor(.gray)
                        .padding(.leading, 16)
                }
            }
        }
    }
}

// MARK: - Example 9: Using Helper Functions Directly

struct WeatherAnalysisView: View {
    let weather: RawMETAR?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Get icon name directly
            let iconName = WeatherIconHelper.icon(for: weather, filled: true)
            Image(systemName: iconName)
                .font(.largeTitle)
                .foregroundColor(WeatherIconHelper.color(for: weather))
            
            // Get description
            Text(WeatherIconHelper.description(for: weather))
                .font(.headline)
            
            // Check conditions
            if WeatherIconHelper.isSevereWeather(weather) {
                Label("Severe Weather Alert", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
            
            if WeatherIconHelper.hasIcingConditions(weather) {
                Label("Icing Conditions Present", systemImage: "snowflake")
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Example 10: Watch App Complication

@available(watchOS 9.0, *)
struct WeatherComplicationView: View {
    let weather: RawMETAR?
    
    var body: some View {
        VStack(spacing: 2) {
            // Use smaller icon for watch
            Image(systemName: WeatherIconHelper.icon(for: weather, filled: true))
                .font(.system(size: 20))
                .foregroundColor(WeatherIconHelper.color(for: weather))
            
            if let category = weather?.flightCategory {
                Text(category)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(WeatherIconHelper.color(for: weather))
            }
        }
    }
}

// MARK: - Usage Tips

/*
 
 QUICK START GUIDE:
 ==================
 
 1. BASIC USAGE (Easiest):
    WeatherIcon(weather: myWeather)
 
 2. CUSTOM SIZE:
    WeatherIcon(weather: myWeather, size: 32)
 
 3. WITH BACKGROUND:
    WeatherIcon(weather: myWeather, size: 24, showBackground: true)
 
 4. GET ICON NAME:
    let iconName = WeatherIconHelper.icon(for: weather)
 
 5. GET COLOR:
    let color = WeatherIconHelper.color(for: weather)
 
 6. GET DESCRIPTION:
    let description = WeatherIconHelper.description(for: weather)
 
 7. CHECK SEVERITY:
    if WeatherIconHelper.isSevereWeather(weather) { ... }
 
 8. CHECK ICING:
    if WeatherIconHelper.hasIcingConditions(weather) { ... }
 
 
 BEST PRACTICES:
 ===============
 
 ✅ DO:
 - Use WeatherIcon view for consistency
 - Check for nil weather data
 - Use appropriate sizes for context (16-24 for lists, 32-48 for headers)
 - Show backgrounds when icon needs emphasis
 - Check severe weather and icing conditions when relevant
 
 ❌ DON'T:
 - Hardcode weather icon names
 - Hardcode weather colors
 - Parse METAR strings directly for icon selection
 - Create custom weather icon logic
 - Forget to handle nil weather data
 
 */

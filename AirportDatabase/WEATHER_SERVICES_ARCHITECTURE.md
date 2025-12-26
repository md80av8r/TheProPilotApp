//
//  WEATHER_SERVICES_ARCHITECTURE.md
//  TheProPilotApp
//
//  Weather Service Architecture Documentation
//

# Weather Services Architecture

ProPilot App has **two distinct weather services** for different purposes:

---

## 1. WeatherService (WeatherData.swift)

**Purpose:** Powers the Weather Tab with favorite airports list

**Type:** `ObservableObject` (SwiftUI integration)

**Location:** `WeatherData.swift`

**Usage:**
```swift
// In Weather Tab View
@StateObject private var weatherService = WeatherService()

// Features:
weatherService.airports          // List of favorite airports with weather
weatherService.addAirport("KDTW")
weatherService.removeAirport("KDTW")
weatherService.refresh()
weatherService.setSortOption(.temperature)
```

**Key Features:**
- ✅ Manages list of favorite airports
- ✅ Fetches multiple airports at once
- ✅ Sorting options (alphabetical, temperature, wind, etc.)
- ✅ Persistent favorites via UserDefaults
- ✅ Observable for real-time UI updates

**Data Models:**
- `AirportWeather` - Airport with weather data
- `METARData` - Parsed METAR information
- `RawMETAR` - Raw API response

---

## 2. AirportWeatherService (WeatherService.swift)

**Purpose:** Fetch weather for individual airports (e.g., in detail views)

**Type:** Singleton service

**Location:** `AirportDatabase/WeatherService.swift`

**Usage:**
```swift
// In Airport Detail View
let weather = try await AirportWeatherService.shared.getWeather(for: "KDTW")

// Returns:
struct WeatherResponse {
    let metar: WeatherData?
    let taf: WeatherData?
}
```

**Key Features:**
- ✅ Simple async/await API
- ✅ Fetches both METAR and TAF
- ✅ Concurrent fetching (parallel requests)
- ✅ Used by `AirportDetailView` and `AirportDatabaseView`

**Data Models:**
- `WeatherData` - Generic weather data structure
- `WeatherResponse` - METAR + TAF combined
- `WeatherError` - Error types

---

## When to Use Which Service

### Use `WeatherService` (from WeatherData.swift) when:
- ✅ Showing multiple airports in a list
- ✅ Building the main Weather tab
- ✅ Need sorting/filtering capabilities
- ✅ Managing user favorites
- ✅ Need SwiftUI @Published updates

**Example Views:**
- `WeatherView` (main weather tab)
- `WeatherBannerView`

### Use `AirportWeatherService` (from WeatherService.swift) when:
- ✅ Showing single airport detail
- ✅ Quick weather lookup
- ✅ Need both METAR and TAF
- ✅ Non-list context

**Example Views:**
- `AirportDetailView`
- `AirportDatabaseView` (detail modal)

---

## API Endpoints

Both services use **aviationweather.gov** API:

### METAR Endpoint
```
https://aviationweather.gov/api/data/metar?ids={ICAO}&format=json
```

### TAF Endpoint
```
https://aviationweather.gov/api/data/taf?ids={ICAO}&format=json
```

### Multiple Airports (WeatherService)
```
https://aviationweather.gov/api/data/metar?ids=KDTW,KATL,KJFK&format=json
```

---

## Alternative Services (Included but Not Active)

### CheckWXService
- Requires API key
- More detailed parsing
- Rate limits apply

### AWCTextDataService
- Plain text METAR/TAF
- Simpler parsing
- No JSON required

To use alternatives, replace the service in your view:
```swift
let service = CheckWXService(apiKey: "YOUR_KEY")
let metar = try await service.fetchMETAR(for: "KDTW")
```

---

## Data Flow

### Weather Tab Flow:
```
User opens Weather Tab
    ↓
WeatherView initializes
    ↓
@StateObject var weatherService = WeatherService()
    ↓
weatherService.loadFavorites()
    ↓
Fetches weather for favorite airports
    ↓
Updates @Published airports array
    ↓
UI refreshes automatically
```

### Airport Detail Flow:
```
User taps airport in database
    ↓
AirportDetailView(airport: info)
    ↓
AirportDetailViewModel.loadWeather()
    ↓
AirportWeatherService.shared.getWeather(for: icao)
    ↓
Fetches METAR + TAF concurrently
    ↓
Returns WeatherResponse
    ↓
Updates @Published metar/taf
    ↓
UI shows weather data
```

---

## Error Handling

Both services use `WeatherError` enum:

```swift
enum WeatherError: Error {
    case invalidURL      // Malformed API URL
    case networkError    // HTTP errors, no connection
    case parsingError    // JSON decode failed
    case notFound        // Airport/data not found
}
```

**Usage:**
```swift
do {
    let weather = try await AirportWeatherService.shared.getWeather(for: "KDTW")
    // Use weather data
} catch {
    print("Weather error: \(error)")
    // Show error to user
}
```

---

## Future Enhancements

### Potential Improvements:
1. **Caching** - Store recent weather data to reduce API calls
2. **Background Refresh** - Update weather automatically
3. **Notifications** - Alert on weather changes
4. **History** - Track weather over time
5. **Unified Service** - Consider merging services with protocols

### Cache Strategy:
```swift
class WeatherCache {
    private var cache: [String: (weather: WeatherData, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func get(for icao: String) -> WeatherData? {
        guard let cached = cache[icao],
              Date().timeIntervalSince(cached.timestamp) < cacheTimeout else {
            return nil
        }
        return cached.weather
    }
    
    func set(_ weather: WeatherData, for icao: String) {
        cache[icao] = (weather, Date())
    }
}
```

---

## Testing

### Unit Tests:
```swift
import Testing

@Suite("Weather Service Tests")
struct WeatherServiceTests {
    
    @Test("Fetch METAR for KDTW")
    func testFetchMETAR() async throws {
        let service = AirportWeatherService.shared
        let weather = try await service.getWeather(for: "KDTW")
        
        #expect(weather.metar != nil)
        #expect(weather.metar?.rawText.contains("KDTW") == true)
    }
    
    @Test("Handle invalid ICAO")
    func testInvalidICAO() async throws {
        let service = AirportWeatherService.shared
        
        await #expect(throws: WeatherError.self) {
            try await service.getWeather(for: "XXXX")
        }
    }
}
```

---

## Troubleshooting

### Weather Not Loading?

1. **Check Internet Connection**
   - aviationweather.gov requires internet access
   
2. **Verify ICAO Code**
   - Must be valid 4-letter code (e.g., "KDTW")
   - Case-insensitive but uppercase recommended
   
3. **API Status**
   - Check https://aviationweather.gov/data/api/
   - API may be down for maintenance

4. **Rate Limiting**
   - Multiple rapid requests may be throttled
   - Add delays between bulk fetches

### Debug Mode:

Enable console logging:
```swift
// In WeatherService
print("🌐 Fetching weather from: \(url.absoluteString)")
print("📡 HTTP Status: \(httpResponse.statusCode)")
print("📄 Raw JSON response: \(jsonString)")
```

---

## Summary

| Feature | WeatherService | AirportWeatherService |
|---------|---------------|----------------------|
| **File** | WeatherData.swift | WeatherService.swift |
| **Type** | ObservableObject | Singleton |
| **Purpose** | Weather tab list | Single airport detail |
| **Usage** | `@StateObject` | `await service.getWeather()` |
| **Data** | Multiple airports | Single airport |
| **Features** | Sort, favorites, persist | METAR + TAF fetch |

Both services work together to provide comprehensive weather data throughout the app! 🌤️✈️

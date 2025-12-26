# Weather Condition Icon - Live Visual Weather Display

## Overview
Replaced the simple cloud toggle button with a **live weather condition icon** that shows real-time weather at the nearest airport using colored SF Symbols.

---

## Features

### 🎨 Dynamic Weather Icons
The icon automatically changes based on actual weather conditions:

**Precipitation:**
- ⛈️ `cloud.bolt.rain.fill` - Thunderstorms (purple)
- 🌧️ `cloud.heavyrain.fill` - Heavy rain (dark blue)
- 🌦️ `cloud.rain.fill` - Rain (blue)
- 🌧️ `cloud.drizzle.fill` - Drizzle (blue)
- ❄️ `cloud.snow.fill` - Snow (blue)
- 🌨️ `cloud.sleet.fill` - Sleet/Freezing rain (cyan)
- 🌨️ `cloud.hail.fill` - Hail (blue)

**Visibility:**
- 🌫️ `cloud.fog.fill` - Fog/Mist/Haze (gray)

**Sky Conditions:**
- ☁️ `cloud.fill` - Overcast/Broken clouds (gray)
- ⛅ `cloud.sun.fill` - Scattered/Few clouds (day)
- 🌙 `cloud.moon.fill` - Scattered/Few clouds (night)
- ☀️ `sun.max.fill` - Clear skies (day)
- 🌟 `moon.stars.fill` - Clear skies (night)

### 🎯 Smart Airport Selection
Priority order:
1. **Active trip departure airport** (if trip exists)
2. **Current airport** (from GPS)
3. **Nearest airport** (from location)

### 🌈 Color Coding by Flight Category
- 🟢 **Green** - VFR (Visual Flight Rules)
- 🔵 **Blue** - MVFR (Marginal VFR)
- 🟠 **Orange** - IFR (Instrument Flight Rules)
- 🔴 **Red** - LIFR (Low IFR)

### 🌓 Day/Night Awareness
Icon automatically switches between sun and moon symbols based on time:
- **Day (6am-6pm):** Uses `cloud.sun.fill`
- **Night (6pm-6am):** Uses `cloud.moon.fill`

---

## Implementation

### Component Structure
```swift
struct WeatherConditionIcon: View {
    let activeTrip: Trip?
    let isExpanded: Bool
    let onTap: () -> Void
    
    @StateObject private var weatherService = BannerWeatherService()
    @EnvironmentObject private var locationManager: PilotLocationManager
}
```

### Weather Detection Logic
```swift
private var weatherIcon: String {
    guard let weather = weatherService.currentWeather else {
        return isExpanded ? "cloud.fill" : "cloud"
    }
    
    let wx = weather.wxString?.uppercased() ?? ""
    let raw = weather.rawOb.uppercased()
    
    // Priority order:
    // 1. Thunderstorms
    // 2. Precipitation type (heavy rain > rain > drizzle)
    // 3. Winter weather (snow, sleet, hail)
    // 4. Visibility (fog, mist, haze)
    // 5. Cloud coverage
    // 6. Clear skies
}
```

### Color Logic
```swift
private var weatherColor: Color {
    // Priority:
    // 1. Severe weather (thunderstorms = purple)
    // 2. Precipitation intensity
    // 3. Flight category (VFR/MVFR/IFR/LIFR)
}
```

---

## Usage in ContentView

### Before:
```swift
// Simple toggle button
Button(action: { showingWeatherBanner.toggle() }) {
    Image(systemName: showingWeatherBanner ? "cloud.fill" : "cloud")
        .foregroundColor(showingWeatherBanner ? LogbookTheme.accentBlue : .gray)
}
```

### After:
```swift
// Live weather condition icon
WeatherConditionIcon(
    activeTrip: activeTrip,
    isExpanded: showingWeatherBanner,
    onTap: {
        withAnimation(.spring(response: 0.3)) {
            showingWeatherBanner.toggle()
        }
    }
)
```

---

## Visual Examples

### Clear Day - VFR
```
☀️ sun.max.fill (green)
"KDTW clear skies, 10SM visibility"
```

### Scattered Clouds - Day
```
⛅ cloud.sun.fill (green/blue)
"KDTW SCT025, MVFR"
```

### Rain - IFR
```
🌧️ cloud.rain.fill (orange)
"KDTW -RA OVC008, IFR"
```

### Thunderstorms - LIFR
```
⛈️ cloud.bolt.rain.fill (purple)
"KDTW +TSRA OVC003, LIFR"
```

### Fog - IFR
```
🌫️ cloud.fog.fill (gray)
"KDTW FG 1/4SM, IFR"
```

### Clear Night - VFR
```
🌟 moon.stars.fill (green)
"KDTW clear skies at night"
```

---

## Auto-Update Behavior

The icon automatically refreshes when:
1. **Location changes** - Uses `locationManager.currentAirport`
2. **Active trip changes** - Uses new departure airport
3. **Weather data updates** - Via `BannerWeatherService`

```swift
.onAppear {
    loadWeather()
}
.onChange(of: locationManager.currentAirport) { _, _ in
    loadWeather()
}
.onChange(of: activeTrip?.legs.first?.departure) { _, _ in
    loadWeather()
}
```

---

## Weather Source

Uses existing `BannerWeatherService` which fetches from:
- **aviationweather.gov API**
- Returns `METARData` with:
  - `wxString` - Weather phenomena (RA, SN, TS, etc.)
  - `clouds` - Cloud coverage (CLR, FEW, SCT, BKN, OVC)
  - `flightCategory` - VFR/MVFR/IFR/LIFR
  - `rawOb` - Full METAR text

---

## SF Symbol Multicolor Support

Uses `.symbolRenderingMode(.multicolor)` to enable built-in colors:
```swift
Image(systemName: weatherIcon)
    .symbolRenderingMode(.multicolor)
    .foregroundStyle(weatherColor)
```

This allows symbols like `cloud.sun.fill` to show:
- ☁️ White cloud
- ☀️ Yellow sun
- ⛈️ Purple lightning bolt

---

## METAR Weather Code Reference

### Precipitation Intensity:
- `-` Light (e.g., `-RA` = light rain)
- (no prefix) Moderate (e.g., `RA` = moderate rain)
- `+` Heavy (e.g., `+RA` = heavy rain)

### Weather Phenomena:
- `RA` - Rain
- `DZ` - Drizzle
- `SN` - Snow
- `SG` - Snow grains
- `PL` - Ice pellets (sleet)
- `GR` - Hail
- `GS` - Small hail
- `TS` - Thunderstorm
- `FZRA` - Freezing rain
- `FG` - Fog
- `BR` - Mist
- `HZ` - Haze

### Cloud Coverage:
- `CLR` / `SKC` - Clear
- `FEW` - Few clouds (1-2 oktas)
- `SCT` - Scattered (3-4 oktas)
- `BKN` - Broken (5-7 oktas)
- `OVC` - Overcast (8 oktas)

---

## User Experience

### Pilot's View:
1. **Glance at icon** - Instantly see current weather
2. **Color indicates severity** - Purple storm vs green VFR
3. **Tap to expand** - See full weather banner with details
4. **Auto-updates** - Always shows nearest/relevant airport

### Smart Context:
- **Before flight:** Shows current airport weather
- **During flight:** Shows departure airport weather
- **After landing:** Switches to new airport automatically

---

## Benefits

### ✅ At-a-Glance Awareness
- No need to tap to see basic conditions
- Icon + color tells the story instantly
- Particularly useful for quick weather checks

### ✅ Pilot-Focused
- Uses aviation weather codes (METAR)
- Shows flight category colors
- Prioritizes operationally significant weather

### ✅ Beautiful & Native
- Uses iOS SF Symbols
- Multicolor support for rich visuals
- Smooth animations and transitions

### ✅ Smart & Automatic
- No manual refresh needed
- Context-aware (trip vs location)
- Day/night aware

---

## Future Enhancements (Optional)

### 1. Temperature Display
```swift
// Show temp on long press
Text("\(temp)°")
    .font(.caption2)
    .foregroundColor(.white)
```

### 2. Wind Indicator
```swift
// Rotate icon based on wind direction
.rotationEffect(.degrees(Double(windDirection)))
```

### 3. Trend Arrows
```swift
// Show if conditions improving/worsening
Image(systemName: "arrow.up")
```

### 4. Alert Badge
```swift
// Show red dot for significant weather
.badge(hasSignificantWeather ? "!" : "")
```

---

## Testing Scenarios

### VFR Day - Clear
- Icon: ☀️ `sun.max.fill`
- Color: Green
- METAR: `KDTW 121453Z 27008KT 10SM CLR 22/12`

### MVFR Day - Scattered
- Icon: ⛅ `cloud.sun.fill`
- Color: Blue
- METAR: `KDTW 121453Z 27008KT 5SM SCT025`

### IFR - Rain
- Icon: 🌧️ `cloud.rain.fill`
- Color: Orange
- METAR: `KDTW 121453Z 27008KT 2SM -RA OVC008`

### LIFR - Thunderstorm
- Icon: ⛈️ `cloud.bolt.rain.fill`
- Color: Purple
- METAR: `KDTW 121453Z 27015G25KT 1/2SM +TSRA BKN004 OVC010`

### Night - Clear
- Icon: 🌟 `moon.stars.fill`
- Color: Green
- Time: 10pm local

---

## Summary

The weather icon now provides:
- **Live weather conditions** at nearest airport
- **Colored SF Symbols** matching actual weather
- **Flight category awareness** (VFR/MVFR/IFR/LIFR)
- **Day/night mode** (sun vs moon)
- **Auto-updates** based on location and trip
- **Tap to expand** full weather banner

**Result:** Pilots get instant visual weather awareness without leaving the main screen! ⛅✈️

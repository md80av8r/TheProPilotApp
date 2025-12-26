# Airport Detail Views - Complete Wiring Map

## Overview
There are **TWO different** Airport Detail Views in the app, serving different features with different data models.

---

## 1. AirportDetailViewEnhanced (NEW)

### Location
**File:** `/repo/AirportDetailView.swift`  
**Struct:** `AirportDetailViewEnhanced`

### Purpose
Enhanced airport details with ForeFlight-style tabs for the **Airport Database** feature.

### Data Model
```swift
let airport: AirportInfo
```

**AirportInfo properties:**
- `icaoCode: String`
- `name: String`
- `coordinate: CLLocationCoordinate2D`
- `timeZone: TimeZone?`
- `source: String`
- `dateAdded: Date`

### Features
- **Info Tab:** Airport information and map
- **Weather Tab:** METAR, TAF, D-ATIS
- **FBO Tab:** FBO information
- **Ops Tab:** Operations information
- **Reviews Tab:** Pilot reviews and ratings (CloudKit)

### Wired From
```swift
// File: AirportDatabaseView.swift (Line 60-63)
.sheet(item: $selectedAirport) { airport in
    AirportDetailViewEnhanced(airport: airport)
}
```

### Navigation Flow
```
ContentView
└── Tab: "airportDatabase"
    └── AirportDatabaseView
        ├── Search Tab → tap airport
        ├── Nearby Tab → tap airport
        └── Favorites Tab → tap airport
            └── AirportDetailViewEnhanced (sheet presentation)
```

### Entry Point in ContentView
```swift
// File: ContentView.swift (Line 979-981)
case "airportDatabase":
    AirportDatabaseView()
        .preferredColorScheme(.dark)
```

---

## 2. AirportDetailView (OLD)

### Location
**File:** `/repo/AreaGuideView.swift` (Line 212+)  
**Struct:** `AirportDetailView`

### Purpose
Original airport detail view for the **Area Guide** feature.

### Data Model
```swift
@State var airport: AirportExperience
```

**AirportExperience properties:**
- `code: String`
- `name: String`
- `averageRating: Double`
- `reviews: [Review]`
- Other legacy properties

### Features
- Airport code and name
- Star rating display
- Reviews list
- Write review button
- Nearby restaurants (Google Places API)
- Nearby hotels (Google Places API)
- Layover guide information

### Wired From
```swift
// File: AreaGuideView.swift (Line 182)
NavigationLink(destination: AirportDetailView(airport: airport)) {
    AirportCardRow(airport: airport)
}
```

### Navigation Flow
```
AreaGuideView
└── List of airports
    └── Tap airport card
        └── AirportDetailView (navigation push)
```

---

## Why Two Different Views?

### Different Use Cases

| Feature | AirportDetailViewEnhanced | AirportDetailView (old) |
|---------|--------------------------|------------------------|
| **Purpose** | Comprehensive airport database | Layover guide |
| **Data Source** | AirportDatabaseManager + CloudKit | Area Guide data |
| **Model** | AirportInfo | AirportExperience |
| **Weather** | ✅ METAR/TAF/D-ATIS | ❌ |
| **Frequencies** | ✅ Radio frequencies | ❌ |
| **Reviews** | ✅ CloudKit reviews | ✅ Legacy reviews |
| **Nearby Places** | ❌ | ✅ Google Places |
| **Map** | ✅ Airport location | ❌ |
| **Presentation** | Sheet | Navigation Push |

---

## Complete Navigation Map

```
ContentView (Main App)
│
├── Tab: "airportDatabase"
│   └── AirportDatabaseView
│       ├── Search Tab
│       ├── Nearby Tab
│       └── Favorites Tab
│           └── [Tap Airport]
│               └── AirportDetailViewEnhanced ← NEW (Sheet)
│                   ├── Info Tab
│                   ├── Weather Tab (METAR/TAF/D-ATIS)
│                   ├── FBO Tab
│                   ├── Ops Tab
│                   └── Reviews Tab
│                       └── AirportReviewSheet
│
└── (Other location - Area Guide feature)
    └── AreaGuideView
        └── [Tap Airport Card]
            └── AirportDetailView ← OLD (Navigation)
                ├── Reviews
                ├── Nearby Restaurants
                └── Nearby Hotels
```

---

## Naming Convention

### Current Names:
- `AirportDetailViewEnhanced` - NEW, feature-complete
- `AirportDetailView` - OLD, legacy area guide

### Why "Enhanced"?
The name `AirportDetailViewEnhanced` was chosen to:
1. **Avoid conflicts** with existing `AirportDetailView`
2. **Indicate it's the newer** implementation
3. **Show it has more features** (weather, frequencies, etc.)

### Alternative Considered:
The documentation mentioned renaming to `AirportDatabaseDetailView`, but the implementation uses `AirportDetailViewEnhanced` instead. Both names work to avoid the conflict.

---

## Key Files Reference

### Airport Database Feature:
```
/repo/
├── AirportDatabaseView.swift          # Main list view
├── AirportDetailView.swift            # Contains AirportDetailViewEnhanced
├── AirportDatabaseManager.swift       # Data manager
└── WeatherService.swift               # Weather service (AirportWeatherService)
```

### Area Guide Feature:
```
/repo/
└── AreaGuideView.swift                # Contains old AirportDetailView
```

### Main App:
```
/repo/
└── ContentView.swift                  # App tabs and routing
```

---

## Usage Examples

### Opening AirportDetailViewEnhanced:
```swift
// From AirportDatabaseView
@State private var selectedAirport: AirportInfo?

// Present as sheet
.sheet(item: $selectedAirport) { airport in
    AirportDetailViewEnhanced(airport: airport)
}
```

### Opening AirportDetailView (old):
```swift
// From AreaGuideView
NavigationLink(destination: AirportDetailView(airport: airportExperience)) {
    AirportCardRow(airport: airportExperience)
}
```

---

## Testing Checklist

### AirportDetailViewEnhanced (NEW):
- [ ] Open Airport Database from main tabs
- [ ] Search for airport (e.g., KDTW)
- [ ] Tap airport card
- [ ] Sheet presents AirportDetailViewEnhanced
- [ ] All tabs work (Info, Weather, FBO, Ops, Reviews)
- [ ] Can write reviews
- [ ] Can favorite/unfavorite

### AirportDetailView (OLD):
- [ ] Open Area Guide (if available)
- [ ] Tap airport card
- [ ] Navigation pushes to AirportDetailView
- [ ] Can view reviews
- [ ] Can see nearby places

---

## Future Considerations

### Potential Consolidation:
In the future, you might want to:
1. **Migrate** old `AirportDetailView` to use `AirportInfo` model
2. **Merge** both views into one
3. **Deprecate** the old view if no longer needed
4. **Keep both** if they serve distinct purposes

### Current Status: ✅ Both Work
Both views coexist peacefully with different names and purposes.

---

## Summary

### ✅ AirportDetailViewEnhanced is wired to:
1. **AirportDatabaseView** (primary usage)
   - Search tab
   - Nearby tab
   - Favorites tab
   
2. **Accessed via ContentView** tab: `"airportDatabase"`

3. **Presentation:** Sheet modal

4. **Model:** `AirportInfo` from `AirportDatabaseManager`

### ✅ AirportDetailView (old) is wired to:
1. **AreaGuideView** (legacy usage)
2. **Presentation:** Navigation push
3. **Model:** `AirportExperience`

**No conflicts** between the two views thanks to different naming! 🎉

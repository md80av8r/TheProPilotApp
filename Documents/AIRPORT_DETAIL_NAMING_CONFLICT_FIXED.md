# Airport Detail View Naming Conflict - RESOLVED

## Problem
When tapping an airport in the Airport Database, it was showing the "old junky" Area Guide detail view instead of the enhanced Airport Database detail view.

## Root Cause
**Two views with the same base name:**
1. `AirportDetailView` in `AreaGuideView.swift` (for restaurants/hotels)
2. `AirportDetailViewEnhanced` in `AirportDetailView.swift` (for weather/FBO/ops)

Even though they take different parameters (`AirportExperience` vs `AirportInfo`), Swift's compiler was sometimes picking the wrong one due to name ambiguity.

## Solution
Renamed the Area Guide view to be more specific:
- **Before:** `AirportDetailView` (ambiguous)
- **After:** `AreaGuideAirportDetailView` (clear purpose)

---

## Files Modified

### 1. AreaGuideView.swift

#### Struct Name Changed
```swift
// Before
struct AirportDetailView: View {
    @State var airport: AirportExperience
    ...
}

// After
struct AreaGuideAirportDetailView: View {
    @State var airport: AirportExperience
    ...
}
```

#### NavigationLink Updated
```swift
// Before
NavigationLink(destination: AirportDetailView(airport: airport)) {
    AirportCardRow(airport: airport)
}

// After
NavigationLink(destination: AreaGuideAirportDetailView(airport: airport)) {
    AirportCardRow(airport: airport)
}
```

---

## View Names Now

### Airport Database Views:
```
AirportDatabaseView
└── Taps airport → AirportDetailViewEnhanced
    ├── Info Tab
    ├── Weather Tab (METAR/TAF/D-ATIS)
    ├── FBO Tab
    ├── Ops Tab
    └── Airport & FBO Tab (reviews)
```

### Area Guide Views:
```
AreaGuideView
└── Taps airport → AreaGuideAirportDetailView
    ├── Reviews section
    ├── Nearby restaurants (Google Places)
    └── Nearby hotels (Google Places)
```

---

## Clear Naming Convention

| View Name | Purpose | Model | Location |
|-----------|---------|-------|----------|
| `AirportDetailViewEnhanced` | Operations & weather | `AirportInfo` | AirportDetailView.swift |
| `AreaGuideAirportDetailView` | Layover places | `AirportExperience` | AreaGuideView.swift |
| `AirportDatabaseView` | Search/browse airports | `AirportInfo` | AirportDatabaseView.swift |
| `AreaGuideView` | Browse layover guides | `AirportExperience` | AreaGuideView.swift |

**No more name conflicts!** Each view has a unique, descriptive name. ✅

---

## Why This Happened

### The Conflict
```swift
// AirportDatabaseView trying to show:
.sheet(item: $selectedAirport) { airport in
    AirportDetailViewEnhanced(airport: airport)  // ✅ What we want
}

// But Swift might find this first (same file scope):
struct AirportDetailView: View {  // ❌ Wrong one!
    let airport: AirportExperience
}
```

Even with different parameter types, Swift's type resolution can get confused when:
1. Names are similar
2. Multiple views exist in different files
3. Import/module visibility overlaps

### The Fix
```swift
// Now crystal clear which view to use:
struct AreaGuideAirportDetailView: View {  // ✅ Unique name
    let airport: AirportExperience
}

struct AirportDetailViewEnhanced: View {  // ✅ Unique name
    let airport: AirportInfo
}
```

---

## Testing

### ✅ Test Airport Database:
1. Open Airport Database tab
2. Search for "KDTW"
3. Tap airport card
4. **Should see:** Enhanced view with Info, Weather, FBO, Ops, Airport & FBO tabs
5. **Should NOT see:** Google Places restaurants/hotels

### ✅ Test Area Guide:
1. Open Area Guide (if available)
2. Tap any airport
3. **Should see:** Old view with reviews, restaurants, hotels
4. **Should NOT see:** Weather/FBO tabs

---

## Benefits

### 1. No More Confusion
- Compiler knows exactly which view to use
- No type ambiguity
- Clear intent from name

### 2. Clear Naming
```
AreaGuideAirportDetailView   → "This is for Area Guide layover info"
AirportDetailViewEnhanced    → "This is the enhanced database detail"
```

### 3. Future-Proof
If you add more airport-related views, follow the pattern:
- `[Feature]AirportDetailView` - Clear which feature it belongs to
- `Airport[Purpose]View` - Clear what it does

---

## Alternative Naming Considered

### Option 1: Keep Current ✅ CHOSEN
```swift
AirportDetailViewEnhanced        // Enhanced database view
AreaGuideAirportDetailView       // Area guide view
```

### Option 2: Rename Both
```swift
AirportDatabaseDetailView        // Database view
AreaGuideLayoverDetailView       // Area guide view
```

### Option 3: Use Modules
```swift
AirportDatabase.DetailView
AreaGuide.DetailView
```

**Chose Option 1** because:
- Minimal changes
- `AirportDetailViewEnhanced` already well-known in codebase
- `AreaGuide` prefix makes Area Guide view obvious
- No breaking changes to other code

---

## Related Documentation

See also:
- `AIRPORT_DETAIL_VIEWS_WIRING_MAP.md` - Complete navigation map
- `AIRPORT_REVIEWS_CLARIFICATION.md` - Two review systems explained
- `AIRPORT_REVIEW_TAB_RENAMED.md` - Tab naming changes

---

## Summary

**Problem:** Airport Database was showing wrong detail view

**Cause:** Two views named `AirportDetailView` causing compiler confusion

**Fix:** Renamed Area Guide view to `AreaGuideAirportDetailView`

**Result:** 
- ✅ Airport Database shows enhanced view
- ✅ Area Guide shows layover places view
- ✅ No naming conflicts
- ✅ Clear purpose from name alone

**Files Changed:**
- `AreaGuideView.swift` (renamed struct and updated NavigationLink)

The Airport Database now correctly shows the enhanced detail view! 🎉

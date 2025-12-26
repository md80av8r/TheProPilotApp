//
//  AIRPORTREVIEWSHEET_FIXES.md
//  TheProPilotApp
//
//  AirportReviewSheet Build Error Fixes - December 23, 2025
//

# AirportReviewSheet Build Errors Fixed ✅

## Summary
Fixed 3 build errors in `AirportDatabase/AirportReviewSheet.swift` related to incorrect model initialization.

---

## Issues Fixed

### 1. Extra argument 'serviceQuality' in call (Line 186)

**Error:** `serviceQuality` parameter doesn't exist in `PilotReview` initializer

**Problem:**
```swift
let review = PilotReview(
    ...
    serviceQuality: serviceQuality  // ❌ Not in initializer
)
```

**Actual PilotReview Initializer:**
```swift
init(
    id: UUID = UUID(),
    airportCode: String,
    pilotName: String,
    rating: Int,
    content: String,
    title: String? = nil,
    date: Date = Date(),
    fboName: String? = nil,
    fuelPrice: Double? = nil,
    crewCarAvailable: Bool? = nil,
    cloudKitRecordID: String? = nil
)
```

**Solution:**
```swift
var review = PilotReview(
    airportCode: airport.icaoCode,
    pilotName: pilotName,
    rating: rating,
    content: reviewContent,
    date: Date(),
    fboName: fboName.isEmpty ? nil : fboName,
    fuelPrice: Double(fuelPrice),
    crewCarAvailable: crewCarAvailable
)

// Set serviceQuality separately (it's a var, not in initializer)
review.serviceQuality = serviceQuality
```

**Key Changes:**
- ✅ Removed `serviceQuality` from initializer
- ✅ Set it as a property after creation
- ✅ Changed `let` to `var` to allow mutation
- ✅ Fixed `fboName` to pass nil if empty

---

### 2. Extra arguments in Preview (Line 240)

**Error:** Preview using wrong `AirportInfo` initializer

**Problem:**
```swift
AirportInfo(
    icaoCode: "KDTW",
    name: "Detroit Metropolitan Wayne County Airport",
    latitude: 42.2124,        // ❌ These properties
    longitude: -83.3534,      // ❌ don't exist
    elevation: 645,           // ❌ in the actual
    city: "Detroit",          // ❌ model
    type: "large_airport",
    iataCode: "DTW"
)
```

**Actual Model:**
```swift
struct AirportInfo {
    let icaoCode: String
    let name: String
    let coordinate: CLLocationCoordinate2D  // ← Single coordinate object
    let timeZone: String?
    let source: AirportSource
    let dateAdded: Date
    var averageRating: Double?
    var reviewCount: Int?
}
```

**Solution:**
```swift
AirportInfo(
    icaoCode: "KDTW",
    name: "Detroit Metropolitan Wayne County Airport",
    coordinate: CLLocationCoordinate2D(
        latitude: 42.2124,
        longitude: -83.3534
    ),
    timeZone: "America/Detroit",
    source: .csvImport,
    dateAdded: Date(),
    averageRating: 4.5,
    reviewCount: 12
)
```

---

### 3. Cannot convert Double to CLLocationCoordinate2D (Line 243)

**Error:** Trying to pass separate lat/lon instead of coordinate object

**Cause:** Same as issue #2 - wrong model structure

**Solution:** Use `coordinate: CLLocationCoordinate2D(latitude:longitude:)` instead of separate properties

---

## Files Modified

### AirportReviewSheet.swift

1. ✅ **Added import** - `import CoreLocation` for `CLLocationCoordinate2D`
2. ✅ **Fixed submitReview()** - Proper `PilotReview` initialization
3. ✅ **Fixed Preview** - Correct `AirportInfo` initialization

---

## Code Changes Summary

### Before:
```swift
// ❌ Wrong
let review = PilotReview(
    airportCode: airport.icaoCode,
    pilotName: pilotName,
    rating: rating,
    content: reviewContent,
    date: Date(),
    fboName: fboName,
    fuelPrice: Double(fuelPrice) ?? 0,
    crewCarAvailable: crewCarAvailable,
    serviceQuality: serviceQuality  // Not in initializer
)
```

### After:
```swift
// ✅ Correct
var review = PilotReview(
    airportCode: airport.icaoCode,
    pilotName: pilotName,
    rating: rating,
    content: reviewContent,
    date: Date(),
    fboName: fboName.isEmpty ? nil : fboName,
    fuelPrice: Double(fuelPrice),
    crewCarAvailable: crewCarAvailable
)
review.serviceQuality = serviceQuality  // Set after
```

---

## Key Lessons

### 1. **Struct Initialization vs Property Assignment**
Some properties need to be set **after** initialization if they're not part of the init parameters:

```swift
var instance = MyStruct(param1: value1)
instance.optionalProperty = value2  // Set after init
```

### 2. **Optional Handling**
When passing optional strings, check if empty:

```swift
// Instead of:
fboName: fboName  // Passes "" if empty

// Use:
fboName: fboName.isEmpty ? nil : fboName  // Passes nil if empty
```

### 3. **Coordinate Objects**
Modern Swift location APIs use coordinate objects, not separate properties:

```swift
// ❌ Old way (doesn't exist in model)
latitude: 42.2124
longitude: -83.3534

// ✅ New way
coordinate: CLLocationCoordinate2D(latitude: 42.2124, longitude: -83.3534)
```

---

## Testing Checklist

After build succeeds:

- [ ] Build project (⌘B) - Should succeed
- [ ] Open Airport Database
- [ ] Tap an airport
- [ ] Tap "Reviews" tab
- [ ] Tap "Write a Review" button
- [ ] **Fill out review form:**
  - [ ] Enter pilot name
  - [ ] Select rating
  - [ ] Write review content
  - [ ] (Optional) Add FBO info
  - [ ] (Optional) Add fuel price
  - [ ] (Optional) Toggle crew car
  - [ ] (Optional) Rate service quality
- [ ] **Submit review:**
  - [ ] Tap "Submit Review"
  - [ ] Loading indicator shows
  - [ ] Sheet dismisses
  - [ ] Review appears in list

---

## Summary

✅ **All 3 errors fixed**
✅ **Proper model initialization**
✅ **Ready to build and test**

The review submission now correctly:
- Uses the actual `PilotReview` initializer
- Sets additional properties after creation
- Uses the correct `AirportInfo` model structure
- Handles optional values properly

# Airport Reviews - Two Different Review Systems

## Overview
The app has **TWO separate review systems** for different purposes, which can be confusing. This document clarifies the distinction.

---

## 1. Airport/FBO Reviews (AirportDetailViewEnhanced)

### Purpose
**Operational reviews** - Reviews of the airport itself, FBO service, facilities, and operations.

### Location
- **File:** `AirportDetailView.swift`
- **View:** `AirportDetailViewEnhanced` → "Reviews" tab
- **Sheet:** `AirportReviewSheet.swift`

### What Pilots Review
```
✈️ Airport Operations & Services:
   - Overall airport experience
   - FBO service quality
   - Fuel prices
   - Crew car availability
   - Landing fees
   - Ground handling
   - General aviation facilities
```

### Review Fields
```swift
struct AirportReviewSheet {
    @State private var pilotName = ""
    @State private var rating = 5                    // Overall airport rating
    @State private var reviewContent = ""            // General review text
    @State private var fboName = ""                  // Which FBO (Signature, Atlantic, etc.)
    @State private var fuelPrice: String = ""        // $/gallon
    @State private var crewCarAvailable = false      // Crew car yes/no
    @State private var serviceQuality = 3            // FBO service rating
}
```

### Example Review
```
"Great airport! Signature FBO has excellent service.
Fuel was $6.50/gal. Free crew car available.
Quick turns, no landing fees for overnight stays."
```

### Data Model
```swift
struct PilotReview {
    let icaoCode: String
    let pilotName: String
    let rating: Int
    let content: String
    let fboName: String?
    let fuelPrice: Double?
    let crewCarAvailable: Bool
    let serviceQuality: Int?
    let timestamp: Date
}
```

### Navigation
```
Airport Database
└── Tap Airport
    └── AirportDetailViewEnhanced
        └── Reviews Tab
            └── Write Review
                └── AirportReviewSheet (airport/FBO review)
```

---

## 2. Places Reviews (Area Guide)

### Purpose
**Layover guide** - Reviews of restaurants, hotels, and attractions near airports for crew layovers.

### Location
- **File:** `AreaGuideView.swift`
- **View:** `AirportDetailView` (old)
- **Intent:** Help pilots find good places to eat/stay during layovers

### What Pilots Review
```
🍽️ Nearby Places:
   - Restaurants
   - Hotels
   - Bars/entertainment
   - Shopping
   - Attractions
   - Transportation options
```

### Review Fields
```swift
// (Based on AreaGuideView implementation)
struct PlaceReview {
    let placeName: String           // "Joe's Steakhouse"
    let placeType: String           // "Restaurant"
    let rating: Double              // 1-5 stars
    let reviewText: String          // Written review
    let priceRange: String?         // "$", "$$", "$$$"
    // ... other place-specific fields
}
```

### Example Review
```
"Joe's Steakhouse - 10 min from hotel
Amazing ribeye! Great crew meal spot.
Walking distance from Marriott. $$$"
```

### Features
- Google Places API integration
- Nearby restaurants search
- Nearby hotels search
- Distance from airport

### Navigation
```
Area Guide
└── Tap Airport Card
    └── AirportDetailView (old)
        ├── View reviews of nearby places
        ├── See restaurants (Google Places)
        ├── See hotels (Google Places)
        └── Write review of a place
```

---

## Comparison Table

| Feature | Airport/FBO Reviews | Places Reviews |
|---------|---------------------|----------------|
| **Purpose** | Rate airport operations | Rate layover locations |
| **Scope** | Airport, FBO, services | Restaurants, hotels, attractions |
| **View** | AirportDetailViewEnhanced | AirportDetailView (old) |
| **File** | AirportDetailView.swift | AreaGuideView.swift |
| **Review About** | The airport itself | Places NEAR the airport |
| **Use Case** | "Should I stop here for fuel?" | "Where should I eat on layover?" |
| **Fields** | FBO name, fuel price, crew car | Place name, price range, distance |
| **Data Source** | CloudKit (PilotReview) | Local/Firebase (AirportExperience) |
| **Integration** | Airport Database | Area Guide |

---

## User Stories

### Airport/FBO Reviews
> **As a pilot**, I want to know if an airport has good FBO service and fair fuel prices **so I can plan my fuel stops**.

```
Scenario: Captain needs fuel stop
Given: Flying from LAX to JFK
When: Looking at KORD airport
Then: See reviews about FBO service, fuel prices, crew car
Decision: "Atlantic FBO has great service, fuel is $6.20/gal, I'll stop here"
```

### Places Reviews
> **As a pilot**, I want to know good restaurants and hotels near my layover airport **so I can have a great layover experience**.

```
Scenario: Crew on overnight layover
Given: Overnight stay at KATL
When: Looking at Area Guide for KATL
Then: See reviews of nearby restaurants and hotels
Decision: "Joe's Steakhouse is walking distance and highly rated, let's go there"
```

---

## Why Two Separate Systems?

### Different Questions Being Answered

**Airport Database (AirportDetailViewEnhanced):**
- "Is this a good airport for GA?"
- "How much is fuel?"
- "Is the FBO friendly?"
- "Are there landing fees?"
- "Can I get a crew car?"

**Area Guide (AirportDetailView):**
- "Where can I eat dinner tonight?"
- "What hotels are nearby?"
- "Are there any good bars?"
- "What's within walking distance?"
- "Where do other crews like to go?"

### Different Data Needs

**Airport Reviews:**
- Tied to ICAO code
- Operational details
- Service ratings
- Pricing information
- Facilities availability

**Places Reviews:**
- Tied to physical locations
- Google Places data
- Restaurant/hotel specific
- Distance from airport/hotel
- Type of cuisine/amenities

---

## Potential Confusion Points

### ⚠️ Confusion #1: "Reviews" Tab Name
Both systems have "reviews," but they review different things:
- ✈️ Airport reviews = "How's the airport?"
- 🍽️ Place reviews = "Where should I eat?"

### ⚠️ Confusion #2: Same Airport, Different Views
```
KDTW in Airport Database:
└── Reviews Tab = "FBO service was great, fuel $6.50"

KDTW in Area Guide:
└── Reviews = "Try the BBQ place on Main St!"
```

### ⚠️ Confusion #3: Model Names
```swift
PilotReview         // Airport/FBO review (CloudKit)
AirportExperience   // Area guide with place reviews
```

---

## Recommendations

### For Clarity, Consider:

1. **Rename Tabs**
   ```swift
   // Current (ambiguous)
   case reviews = "Reviews"
   
   // Better (specific)
   case airportReviews = "Airport Reviews"
   case fboReviews = "FBO & Services"
   case operationsReviews = "Ops & Services"
   ```

2. **Update Sheet Titles**
   ```swift
   // AirportReviewSheet
   Text("Review this Airport")          // Clear it's about the airport
   Text("How was your experience at \(airport.icaoCode)?")
   
   // Area Guide
   Text("Review a Place")               // Clear it's about a location
   Text("Share your layover recommendations")
   ```

3. **Add Contextual Help**
   ```swift
   // In AirportDetailViewEnhanced
   Text("Share your experience with this airport's FBO, fuel prices, and services")
   
   // In Area Guide
   Text("Share your favorite restaurants and hotels near this airport")
   ```

---

## Current Implementation Status

### ✅ Working Correctly
- Both review systems exist and work independently
- No data conflicts (different models)
- Serve different use cases

### ⚠️ Potentially Confusing
- Both use term "Reviews"
- Not obvious which reviews are which
- Users might expect to see restaurant reviews in Airport Database

### 💡 Suggested Improvements
1. Rename "Reviews" tab to "Airport & FBO"
2. Add descriptive text explaining what to review
3. Consider merging both into one comprehensive view later
4. Add category badges (🛫 Airport, 🍽️ Food, 🏨 Hotel)

---

## Summary

### Two Review Systems:

1. **AirportDetailViewEnhanced → "Reviews" Tab**
   - Reviews the **airport and FBO services**
   - Fields: FBO name, fuel price, crew car, service quality
   - Use case: Operational planning
   - Access: Airport Database → tap airport → Reviews tab

2. **AreaGuideView → AirportDetailView**
   - Reviews **restaurants, hotels, and places** near airports
   - Fields: Place name, type, price range, distance
   - Use case: Layover planning
   - Access: Area Guide → tap airport → view places

### Both are valuable, just for different purposes! ✈️🍽️

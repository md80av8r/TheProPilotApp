# ProPilot Paywall System Architecture

## 🏗️ System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      ProPilot App                            │
│                                                              │
│  ┌─────────────┐                         ┌────────────────┐ │
│  │ ContentView │────────────checks───────▶│ Trial Checker │ │
│  └─────────────┘                         └────────────────┘ │
│         │                                         │          │
│         │ creates trip                            │          │
│         ▼                                         │          │
│  ┌──────────────┐      increments     ┌──────────▼────────┐ │
│  │ LogBookStore │─────────────────────▶│ Trip Counter (5) │ │
│  └──────────────┘                     └───────────────────┘ │
│         │                                         │          │
│         │                              ┌──────────▼────────┐ │
│  ┌──────▼───────┐      checks          │ Day Counter (7)  │ │
│  │ LogbookView  │─────────────────────▶└──────────────────┘ │
│  └──────────────┘                              │            │
│         │                                      │            │
│         │ delete blocked                       │            │
│         │                                      │            │
│         └────────▶ showingPaywall = true ◀─────┘            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   PaywallView                        │   │
│  │  ┌─────────────┐         ┌──────────────────────┐   │   │
│  │  │ Monthly     │         │ Annual (Best Value)  │   │   │
│  │  │ $9.99/month │         │ $79.99/year          │   │   │
│  │  └─────────────┘         └──────────────────────┘   │   │
│  │           └──────────┬──────────┘                   │   │
│  │                      │                              │   │
│  │                      ▼                              │   │
│  │           ┌─────────────────────┐                  │   │
│  │           │ SubscriptionManager │                  │   │
│  │           │   (StoreKit 2)      │                  │   │
│  │           └─────────────────────┘                  │   │
│  │                      │                              │   │
│  │                      ▼                              │   │
│  │              [ Apple IAP ]                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow Diagrams

### Flow 1: Creating a Trip (Within Limits)

```
User taps "New Trip"
         │
         ▼
   Check canCreateTrip
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  YES        NO
    │         │
    ▼         └──▶ Show Paywall
Show Form
    │
    ▼
User fills out trip
    │
    ▼
Tap "Save"
    │
    ▼
LogBookStore.addTrip()
    │
    ▼
SubscriptionStatusChecker.incrementTripCount()
    │
    ▼
Counter: 4 → 5
    │
    ▼
Check if limit reached
    │
    ▼
Update banner
```

### Flow 2: Creating 6th Trip (Trial Exhausted)

```
User taps "New Trip"
         │
         ▼
   Check canCreateTrip
         │
         ▼
    trips = 5/5 ❌
         │
         ▼
    return false
         │
         ▼
  showingPaywall = true
         │
         ▼
┌─────────────────────┐
│   PaywallView       │
│                     │
│ "Trial Ended"       │
│ "5 trip limit"      │
│                     │
│ [Subscribe Now]     │
└─────────────────────┘
```

### Flow 3: Deleting a Trip (Trial Exhausted)

```
User swipes to delete
         │
         ▼
handleDeleteRequest(trip)
         │
         ▼
   Check canDeleteTrip
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  YES        NO
    │         │
    ▼         └──▶ Show Paywall ❌
Show confirmation
    │
    ▼
User confirms
    │
    ▼
Delete trip
```

### Flow 4: Subscription Purchase

```
User in PaywallView
         │
         ▼
Tap "Annual - $79.99"
         │
         ▼
selectedProduct = annual
         │
         ▼
Tap "Subscribe Now"
         │
         ▼
SubscriptionManager.purchase(annual)
         │
         ▼
    StoreKit 2 API
         │
         ▼
    Apple IAP
         │
    ┌────┴────┐
    │         │
    ▼         ▼
SUCCESS   FAILURE
    │         │
    │         └──▶ Show Error
    ▼
Update subscriptionStatus
    │
    ▼
isSubscribed = true
    │
    ▼
Dismiss Paywall
    │
    ▼
┌────────────────────┐
│ User can now:      │
│ ✅ Create trips    │
│ ✅ Delete trips    │
│ ✅ Unlimited       │
└────────────────────┘
```

---

## 🧩 Component Relationships

### Core Components

```
┌───────────────────────────────────────────────────────┐
│ SubscriptionStatusChecker (Singleton)                 │
│                                                       │
│ Properties:                                           │
│  • totalTripsCreated: Int (UserDefaults)              │
│  • installDate: Date (UserDefaults)                   │
│  • trialStatus: TrialStatus (computed)                │
│                                                       │
│ Methods:                                              │
│  • incrementTripCount() → void                        │
│  • updateTrialStatus() → void                         │
│  • canCreateTrip → Bool                               │
│  • canDeleteTrip → Bool                               │
│  • shouldShowPaywall → Bool                           │
│                                                       │
│ Used by:                                              │
│  → ContentView (for "New Trip" button)                │
│  → LogbookView (for delete protection)                │
│  → TrialStatusBanner (for display)                    │
│  → PaywallView (for trial info)                       │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ SubscriptionManager (Singleton)                       │
│                                                       │
│ Properties:                                           │
│  • availableProducts: [Product]                       │
│  • subscriptionStatus: SubscriptionStatus             │
│  • isSubscribed: Bool                                 │
│                                                       │
│ Methods:                                              │
│  • loadProducts() async                               │
│  • purchase(_ product: Product) async throws          │
│  • restorePurchases() async                           │
│  • checkSubscriptionStatus() async                    │
│                                                       │
│ Used by:                                              │
│  → PaywallView (purchase flow)                        │
│  → SubscriptionStatusChecker (status checks)          │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ PaywallView                                           │
│                                                       │
│ Displays:                                             │
│  • Trial status card                                  │
│  • Subscription options (monthly/annual)              │
│  • Features list (5 items)                            │
│  • Subscribe button                                   │
│  • Restore purchases link                             │
│  • Terms & privacy links                              │
│                                                       │
│ Triggers:                                             │
│  • When canCreateTrip = false                         │
│  • When canDeleteTrip = false                         │
│  • Manual trigger from Settings                       │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ TrialStatusBanner                                     │
│                                                       │
│ Shows when:                                           │
│  • trialStatus = .active                              │
│  • Displays trips/days remaining                      │
│                                                       │
│ UI:                                                   │
│  • Orange background                                  │
│  • Clock icon                                         │
│  • "X free trips remaining"                           │
│  • "Tap to upgrade" button                            │
│                                                       │
│ Location:                                             │
│  → Below header in logbookContent                     │
└───────────────────────────────────────────────────────┘
```

---

## 🔐 UserDefaults Storage

### Keys & Values

```
UserDefaults.standard
├── "app_install_date"
│   └── Date (2024-12-23 10:30:00)
│
└── "total_trips_ever_created"
    └── Int (5)

Purpose:
• Install date → Calculate days since install
• Trip counter → Prevent gaming by deleting trips
• Persists across app launches
• NOT cleared by app reinstall (attached to Apple ID)
```

---

## 🎯 Trial Logic Decision Tree

```
User Action: Create Trip
         │
         ▼
    Get current status
         │
         ▼
    Is subscribed?
         │
    ┌────┴────┐
    │         │
   YES       NO
    │         │
    │         ▼
    │    Calculate trips created
    │         │
    │    ┌────┴────┐
    │    │         │
    │   < 5       ≥ 5
    │    │         │
    │    │         └──▶ Trial EXHAUSTED → Show Paywall
    │    │
    │    ▼
    │ Calculate days since install
    │    │
    │  ┌─┴─┐
    │  │   │
    │ < 7  ≥ 7
    │  │   │
    │  │   └──▶ Trial EXPIRED → Show Paywall
    │  │
    │  ▼
    │ Trial ACTIVE → Allow
    │  │
    └──┴──▶ CREATE TRIP ✅
```

---

## 🧪 State Transitions

### Trial State Machine

```
┌─────────────┐
│   ACTIVE    │ ← Initial state (new user)
│ (trips < 5) │
│ (days < 7)  │
└──────┬──────┘
       │
       │ Create trip #5
       │ OR wait 7 days
       ▼
┌──────────────┐
│  EXHAUSTED   │
│ (trips = 5)  │
│ OR           │
│  EXPIRED     │
│ (days = 7)   │
└──────┬───────┘
       │
       │ Purchase subscription
       ▼
┌──────────────┐
│ SUBSCRIBED   │ ← Terminal state (unlocked)
│ (unlimited)  │
└──────────────┘
       │
       │ Subscription expires
       │ (renewal fails)
       ▼
┌──────────────┐
│  EXHAUSTED   │ ← Back to limited
└──────────────┘
```

---

## 💾 Persistence Strategy

### What Gets Saved

```
LogBookStore (JSON file):
├── trips: [Trip]
│   ├── Trip #1
│   ├── Trip #2
│   ├── Trip #3
│   ├── Trip #4
│   └── Trip #5
└── perDiemRate: Double

UserDefaults:
├── app_install_date: Date
│   └── Used for 7-day calculation
└── total_trips_ever_created: Int
    └── Increments on every addTrip()
    └── Never decrements (anti-gaming)

StoreKit (Apple Servers):
└── Subscription receipts
    └── Validated by SubscriptionManager
```

### Why This Design?

**Trip Counter in UserDefaults (not Trip array count):**
- ✅ Prevents gaming by deleting trips
- ✅ Persists across app reinstalls
- ✅ Simple integer increment
- ✅ No complex synchronization

**Install Date in UserDefaults:**
- ✅ Single source of truth
- ✅ Can't be manipulated by user
- ✅ Validated on app launch

---

## 🔄 Integration Points

### Where Trial Checks Happen

```swift
// ContentView.swift (Line ~1450)
Button(action: {
    if trialChecker.canCreateTrip {  // ← CHECK HERE
        showTripSheet = true
    } else {
        showingPaywall = true
    }
}) {
    Label("New Flight", systemImage: "airplane.departure")
}

// LogBookStore.swift (Line ~347)
func addTrip(_ trip: Trip) {
    trips.append(trip)
    SubscriptionStatusChecker.shared.incrementTripCount()  // ← INCREMENT HERE
    save()
}

// LogbookView.swift (Line ~254)
private func handleDeleteRequest(_ trip: Trip) {
    if trialChecker.canDeleteTrip {  // ← CHECK HERE
        confirmDelete()
    } else {
        showingPaywall = true
    }
}

// LogbookContent (Line ~1115)
TrialStatusBanner()  // ← DISPLAY STATUS HERE
```

---

## 📦 File Dependencies

```
PaywallView.swift
├── imports SubscriptionManager
├── imports SubscriptionStatusChecker
└── uses StoreKit

SubscriptionManager.swift
├── imports StoreKit
└── standalone (no dependencies)

SubscriptionStatusChecker.swift
├── imports Foundation
├── depends on SubscriptionManager.isSubscribed
└── stores in UserDefaults

SubscriptionGateModifier.swift
├── imports SubscriptionStatusChecker
└── imports PaywallView

ContentView.swift
├── imports SubscriptionStatusChecker
├── imports PaywallView
└── imports LogBookStore

LogBookStore.swift
└── imports SubscriptionStatusChecker

LogbookView.swift
├── imports SubscriptionStatusChecker
└── imports PaywallView
```

---

## 🎨 UI Component Hierarchy

```
ContentView
├── NavigationView
│   └── VStack
│       ├── ZuluClockView
│       ├── addTripButton (with trial check)
│       ├── TrialStatusBanner ← NEW
│       ├── ConfigurableLimitsStatusView
│       ├── ActiveTripBanner
│       └── OrganizedLogbookView
│           └── List
│               ├── CollapsibleSection (with delete check)
│               │   └── TripRow
│               │       └── .swipeActions (with trial check)
│               └── ...
└── .sheet(isPresented: $showingPaywall) ← NEW
    └── PaywallView
        ├── headerSection
        ├── trialStatusCard
        ├── subscriptionOptionsSection
        │   ├── Monthly ($9.99)
        │   └── Annual ($79.99) [BEST VALUE]
        ├── featuresSection
        ├── purchaseButton
        └── footerSection
```

---

## 🧬 Type Definitions

### TrialStatus Enum

```swift
enum TrialStatus {
    case active           // < 5 trips AND < 7 days
    case tripsExhausted   // ≥ 5 trips
    case timeExpired      // ≥ 7 days
    case subscribed       // Has active subscription
}
```

### SubscriptionStatus Enum

```swift
enum SubscriptionStatus {
    case notSubscribed
    case subscribed(expirationDate: Date?)
    case expired
    case inGracePeriod
}
```

---

## 🔬 Testing Architecture

### Test Hooks

```swift
#if DEBUG
// Reset trial for testing
func resetTrial() {
    UserDefaults.standard.removeObject(forKey: installDateKey)
    UserDefaults.standard.removeObject(forKey: totalTripsCreatedKey)
    setupInstallDate()
    loadTotalTripsCreated()
    updateTrialStatus()
}

// Fast-forward time
private let trialDays = 0  // Change from 7 to 0

// Force subscription status
func setSubscribed(_ value: Bool) {
    // For testing only
}
#endif
```

---

## 📱 Platform Support

### iOS Compatibility

```
Minimum: iOS 17.0
Target: iOS 18.0+

Supported Devices:
✅ iPhone (all sizes)
✅ iPad (all sizes)
✅ iPhone SE
❌ Apple Watch (subscriptions managed on phone)
```

### Localization Support

```
Current: English only
Future: Multi-language support
- French, German, Spanish
- Japanese, Chinese
- Trial status strings
- Paywall UI strings
```

---

## 🚀 Performance Considerations

### Lightweight Design

```
SubscriptionStatusChecker:
├── Singleton (shared instance)
├── UserDefaults reads (cached)
├── Simple integer comparison
├── No network calls
└── O(1) complexity

SubscriptionManager:
├── Singleton (shared instance)
├── StoreKit 2 async/await
├── Cached product list
├── Background receipt validation
└── Minimal memory footprint
```

---

**Architecture Document**  
Created: December 23, 2024  
Version: 1.0  
Status: Production Ready

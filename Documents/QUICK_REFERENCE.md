# 📋 Quick Reference: Jumpseat Finder Integration

## File Checklist

```
✅ FlightScheduleService.swift         - API backend
✅ JumpseatFinderView.swift            - Main UI
✅ SubscriptionService.swift           - Subscription management
✅ JumpseatFinderView+Subscription.swift  - Protected version
✅ TabManager.swift                    - Updated (line 26)
✅ ContentView.swift                   - Updated (line ~2200)
✅ JUMPSEAT_INTEGRATION.md             - Full documentation
✅ INTEGRATION_SUMMARY.md              - This file
```

## Quick Commands

### Build & Run
```bash
# In Xcode: ⌘R
# Navigate: More → Jumpseat Finder
```

### Test Search
```
From: KMEM
To: KATL
Date: Today
→ Tap Search
→ See 3 mock flights
```

### Get API Key
```
1. Visit: aviationstack.com/signup/free
2. Copy access key
3. App → Jumpseat Finder → ⚙️ Settings
4. Paste key
```

### Enable Paywall
```swift
// In ContentView.swift:
case "jumpseat": ProtectedJumpseatFinderView()
```

### Test Subscription
```swift
// Grant Pro access:
SubscriptionService.shared.upgradeToProForTesting()

// Reset to Free:
SubscriptionService.shared.resetToFreeForTesting()
```

## Code Snippets

### Check if user has Pro
```swift
if SubscriptionService.shared.canUseJumpseatFinder {
    // Show feature
} else {
    // Show paywall
}
```

### Search flights programmatically
```swift
let results = try await FlightScheduleService.shared.searchFlights(
    from: "KMEM",
    to: "KATL",
    date: Date()
)
```

### Use mock data
```swift
let mockFlights = FlightScheduleService.shared.getMockFlights(
    from: "KMEM",
    to: "KATL"
)
```

## API Pricing

| Tier | Requests | Cost | Users |
|------|----------|------|-------|
| Free | 100/month | $0 | 1-2 |
| Starter | 10,000/month | $50 | 160 |
| Pro | 100,000/month | $200 | 1,600 |

## Revenue Model

```
Subscription: $4.99/month
API Cost: $50/month (160 users)
Apple Cut: 15% (~$120)
Profit: $628/month
```

## Error Handling

| Error | Meaning | Solution |
|-------|---------|----------|
| Rate limit exceeded | Too many API calls | Wait 1 hour or upgrade plan |
| Invalid URL | Malformed airport code | Check ICAO/IATA format |
| No API key | Missing configuration | Add key in settings |
| Network error | No internet | Enable mock data |

## Testing Matrix

| Scenario | Input | Expected |
|----------|-------|----------|
| Valid search | KMEM→KATL | List of flights |
| IATA codes | MEM→ATL | Auto-convert, show flights |
| Invalid airport | XXXX→YYYY | "No flights found" |
| No API key | Any search | Mock flights (3 results) |
| Empty fields | "" → "" | Disabled search button |
| Pro check | Free tier | Show paywall |
| Pro check | Pro tier | Show full feature |

## UI Colors (LogbookTheme)

```swift
Navy:         #0C0F1E  (main background)
Navy Light:   #1A1E2E  (cards)
Navy Dark:    #05070F  (sidebar)
Accent Blue:  #4A9FFF  (primary)
Accent Green: #4CAF50  (success)
Field BG:     rgba(255,255,255,0.05)
```

## Tab Location

```
Bottom Tab Bar (iPhone):
├── Logbook
├── Schedule
├── Time Away
├── More
    └── Jumpseat Network
        └── Jumpseat Finder ← HERE

Sidebar (iPad):
├── Logbook
├── Schedule
├── Time Away
└── More
    └── Jumpseat Network
        └── Jumpseat Finder ← HERE
```

## Phase 2 Features (Coming Soon)

- [ ] Load predictor (Green/Yellow/Red)
- [ ] Crowdsourced load reports
- [ ] Push notifications
- [ ] Saved routes
- [ ] Calendar integration
- [ ] Airline filters
- [ ] Flight tracking

## Support Links

- [AviationStack API](https://aviationstack.com/documentation)
- [RevenueCat Docs](https://www.revenuecat.com/docs/)
- [StoreKit 2](https://developer.apple.com/documentation/storekit)

## Common Issues

**Q: Flights not showing?**
A: Check API key or use mock mode

**Q: How to test without API key?**
A: App automatically uses mock data

**Q: How to bypass paywall?**
A: Enable development mode in SubscriptionService

**Q: How to change pricing?**
A: Update SubscriptionTier.pro.monthlyPrice

**Q: Where to add more airlines?**
A: Mock data in FlightScheduleService.getMockFlights()

---

**Ready to fly! ✈️**

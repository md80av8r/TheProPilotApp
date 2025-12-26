# Quick Start: Manual Trip Grouping

## For Users

### **Enable Manual Mode**
1. Open ProPilot
2. Tap **Tab Manager** → **Schedule & Operations**
3. Tap **Trip Generation**
4. Under "Trip Detection", change from **Automatic** to **Manual**
5. Done! ✅

### **Using Manual Mode**
When NOC sync completes:

1. **You'll see separate notifications** for each leg
   - Example: "JUS323 - 1 leg", "JUS324 - 1 leg"

2. **Tap any notification** to open the trip card

3. **Review the first leg** then tap **"Add More Legs"**

4. **Select additional legs**
   - Tap to select (shows checkmark ✓)
   - Connecting flights show 🔗 badge
   - See total block time update

5. **Tap "Add X Legs"** to add them to your trip

6. **Tap "Create Trip"** when ready

---

## For Developers

### **Quick Integration**

Replace your pending trip UI with:

```swift
import SwiftUI

// In your view
ForEach(TripGenerationService.shared.pendingTrips) { trip in
    PendingTripCard(pendingTrip: trip)
        .environmentObject(logbookStore)
        .environmentObject(scheduleStore)
}
```

That's it! The card automatically shows "Add Legs" in manual mode.

### **Testing Manual Mode**

```swift
// Set to manual mode
TripGenerationSettings.shared.tripGroupingMode = .manual

// Trigger NOC sync
// Each leg becomes a separate pending trip

// Check result
print(TripGenerationService.shared.pendingTrips.count) 
// Should equal number of legs (not grouped)
```

### **Accessing Available Legs**

```swift
let availableLegs = TripGenerationService.shared.getAvailableLegsForPendingTrip(
    myPendingTrip,
    allRosterItems: scheduleStore.items
)
// Returns legs on same/next day not already in trip
```

---

## Key Files

| File | Purpose |
|------|---------|
| `AddLegsToTripSheet.swift` | Leg selection interface |
| `PendingTripCard.swift` | Trip card with "Add Legs" button |
| `TripGenerationSettings.swift` | Mode enum and setting |
| `TripGenerationService.swift` | Grouping logic & API |
| `TripGenerationSettingsView.swift` | Settings UI |

---

## Behavior Differences

| Aspect | Automatic Mode | Manual Mode |
|--------|---------------|-------------|
| **Grouping** | Auto (<12h gaps) | User selects |
| **Notifications** | 1 per trip | 1 per leg |
| **User Steps** | 1 tap to create | Multiple taps to build |
| **Best For** | Predictable schedules | Complex/irregular ops |
| **Pending Trips** | Multi-leg groups | Single legs |

---

## Common Patterns

### **Pattern 1: Standard 3-leg trip**
```
Automatic: 1 notification → 1 tap → Done
Manual: 3 notifications → select all → create
```

### **Pattern 2: Split duty**
```
Legs: JUS323 (10:00), rest, JUS340 (22:00)
Automatic: 2 trips (>12h gap)
Manual: User decides to combine or separate
```

### **Pattern 3: Deadhead positioning**
```
Legs: Deadhead DTW→ORD, JUS500 ORD→LAX
Automatic: 1 trip (if <12h gap)
Manual: User can separate DH from revenue
```

---

## Troubleshooting

**Q: "Add Legs" button not showing?**  
A: Check Settings → Trip Generation → Trip Grouping = Manual

**Q: No legs available to add?**  
A: Normal if no other flights same day or all already added

**Q: Can I remove legs after adding?**  
A: Not yet - dismiss trip and recreate if needed

**Q: Can I switch modes anytime?**  
A: Yes! New mode applies to next NOC sync

---

## Tips

1. **Use Automatic** for routine schedules (saves time)
2. **Use Manual** when you need control over trip composition
3. **Look for 🔗 badge** - connecting flights are highlighted
4. **Block time updates** as you add legs (shows in sheet footer)
5. **"Later" button** postpones decision without dismissing

---

## Support

For issues or questions:
- Check `MANUAL_TRIP_GROUPING_DOCS.md` for full documentation
- Review console logs for trip grouping debug info
- Test with NOCTestView to generate sample trips

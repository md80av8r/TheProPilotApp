# Quick Testing Guide - Paywall Integration

## 🚀 Fast Test (5 minutes)

### Test 1: Create 5 Trips (Trip Limit)
```
1. Launch app
2. Tap "New Trip" → Fill out Trip #1 → Save
   → Should show banner: "4 free trips remaining"
   
3. Tap "New Trip" → Fill out Trip #2 → Save
   → Banner updates: "3 free trips remaining"
   
4. Tap "New Trip" → Fill out Trip #3 → Save
   → Banner updates: "2 free trips remaining"
   
5. Tap "New Trip" → Fill out Trip #4 → Save
   → Banner updates: "1 free trip remaining"
   
6. Tap "New Trip" → Fill out Trip #5 → Save
   → Banner updates: "Free trial ended"
   → "New Trip" button turns GRAY
   
7. Tap "New Trip" → ⚠️ PAYWALL APPEARS ✅
```

### Test 2: Delete Protection
```
1. With 5 trips created (trial exhausted)
2. Swipe left on any trip
3. Tap "Delete" → ⚠️ PAYWALL APPEARS ✅
```

### Test 3: Anti-Gaming Protection
```
1. With 5 trips created (paywall showing)
2. Subscribe (or use restore for testing)
3. Delete Trip #5
4. Now you have 4 trips showing
5. Open SubscriptionStatusChecker
6. Check counter → should still show 5/5
7. Unsubscribe (for testing)
8. Try "New Trip" → ⚠️ STILL BLOCKED ✅
   (Can't game it by deleting trips!)
```

---

## 🕐 Fast-Forward Time Test (Test 7-Day Limit)

**To test without waiting 7 days:**

1. Open `SubscriptionStatusChecker.swift`
2. Find line ~30:
   ```swift
   private let trialDays = 7
   ```
3. Change to:
   ```swift
   private let trialDays = 0  // ⚠️ TESTING ONLY
   ```
4. Rerun app
5. Banner should show: "Free trial ended - 7 day period expired"
6. Try "New Trip" → ⚠️ PAYWALL APPEARS ✅
7. **IMPORTANT:** Change back to 7 before submitting!

---

## 💳 Purchase Flow Test

### Test in Simulator (Sandbox)
```
1. Create 5 trips (exhaust trial)
2. Tap "New Trip" → Paywall appears
3. Select "Annual - $79.99/year"
4. Tap "Subscribe Now"
5. Confirm purchase (no real charge in simulator)
6. Paywall dismisses
7. "New Trip" button turns GREEN ✅
8. Tap "New Trip" → Form appears ✅
9. Create Trip #6 → Works! ✅
```

### Visual Checklist
- [ ] Paywall has gradient background (blue/purple)
- [ ] Shows trial status card
- [ ] Shows two subscription options (monthly/annual)
- [ ] Annual has "BEST VALUE" badge
- [ ] Shows 5 feature checkmarks
- [ ] "Subscribe Now" button is visible
- [ ] "Restore Purchases" link at bottom
- [ ] "Terms & Privacy" links at bottom

---

## 🔍 Console Logs to Watch For

When testing, check Xcode console for these messages:

### Good Logs (Everything Working):
```
📅 First launch - install date saved: 2024-12-23
📊 Total trips ever created: 0
➕ Trip count incremented: 1/5
✅ Trial active: 4 trips, 7 days remaining
➕ Trip count incremented: 2/5
✅ Trial active: 3 trips, 7 days remaining
[... continues ...]
➕ Trip count incremented: 5/5
🚫 Trial exhausted: Hit trip limit (5/5)
```

### Warning Logs (Need Attention):
```
⚠️ No install date found - user may have deleted app data
⚠️ Trial checker not initialized
⚠️ SubscriptionManager not available
```

---

## 🐛 Common Issues & Fixes

### Issue: Banner Not Showing
**Fix:** Add `TrialStatusBanner()` to ContentView around line 1115

### Issue: Button Still Green After 5 Trips
**Fix:** Check `trialChecker.canCreateTrip` in button logic

### Issue: Can Still Delete After Trial
**Fix:** Verify `handleDeleteRequest` checks `trialChecker.canDeleteTrip`

### Issue: Counter Resets to 0
**Fix:** Check UserDefaults key: `total_trips_ever_created`

### Issue: Paywall Not Appearing
**Fix:** Make sure `PaywallView.swift` is added to target

---

## 📱 Device-Specific Testing

### iPhone Testing
- [ ] Portrait mode works
- [ ] Landscape mode works
- [ ] Banner appears below header
- [ ] Paywall is full screen
- [ ] Button becomes disabled (gray)

### iPad Testing
- [ ] Split view works
- [ ] Banner appears in detail pane
- [ ] Paywall centers properly
- [ ] Button responds correctly

---

## ✅ Final Pre-Launch Checklist

Before submitting to App Store:

1. **Code Check:**
   - [ ] `trialDays = 7` (not 0)
   - [ ] `maxFreeTrips = 5` (not changed)
   - [ ] No `#if DEBUG` code in production

2. **App Store Connect:**
   - [ ] Subscriptions created (monthly + annual)
   - [ ] Product IDs match exactly
   - [ ] 7-day free trial enabled on BOTH
   - [ ] Banking info complete
   - [ ] Tax forms signed

3. **Legal:**
   - [ ] Privacy Policy URL works
   - [ ] Terms of Service URL works
   - [ ] Both linked in PaywallView

4. **Testing:**
   - [ ] Tested on real device (not just simulator)
   - [ ] Tested purchase flow
   - [ ] Tested restore purchases
   - [ ] Tested all 3 trip types (Flight, Deadhead, Sim)
   - [ ] Tested delete blocking
   - [ ] Tested banner appearance

---

## 🎯 Success Criteria

Your integration is working if:

1. ✅ Can create 5 trips without paywall
2. ✅ 6th trip shows paywall
3. ✅ Banner shows trip count
4. ✅ Banner shows day count
5. ✅ Delete blocked after trial
6. ✅ Button turns gray after trial
7. ✅ Purchase unlocks everything
8. ✅ Deleting trips doesn't reset counter

---

## 🚀 Quick Commands

### Reset Trial (for testing):
Add this button to Settings or ContentView:
```swift
#if DEBUG
Button("🔄 Reset Trial (Debug)") {
    SubscriptionStatusChecker.shared.resetTrial()
}
.foregroundColor(.red)
#endif
```

### Print Trial Status:
Add anywhere for debugging:
```swift
let checker = SubscriptionStatusChecker.shared
print("=== TRIAL STATUS ===")
print("Status: \(checker.trialStatus)")
print("Total trips created: \(checker.totalTripsCreated)/5")
print("Days remaining: \(checker.daysRemaining)/7")
print("Trips remaining: \(checker.tripsRemaining)/5")
print("Can create trip: \(checker.canCreateTrip)")
print("Can delete trip: \(checker.canDeleteTrip)")
print("Should show paywall: \(checker.shouldShowPaywall)")
print("==================")
```

### Force Show Paywall (for testing):
In ContentView, temporarily change:
```swift
Button(action: {
    showingPaywall = true  // Force show for testing
}) {
    Text("Test Paywall")
}
```

---

## 📊 Expected Behavior Matrix

| Scenario | Trips Created | Days Passed | Can Create? | Can Delete? | Shows Paywall? |
|----------|--------------|-------------|-------------|-------------|----------------|
| New user | 0 | 0 | ✅ Yes | ✅ Yes | ❌ No |
| After 3 trips | 3 | 2 | ✅ Yes | ✅ Yes | ❌ No |
| 5th trip | 5 | 3 | ❌ No | ❌ No | ✅ Yes |
| After 7 days | 3 | 7 | ❌ No | ❌ No | ✅ Yes |
| Subscribed | 10 | 20 | ✅ Yes | ✅ Yes | ❌ No |

---

**Testing Document**  
Created: December 23, 2024  
For: ProPilot Paywall Integration  
Status: Ready for QA

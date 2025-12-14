# Quick Start: Testing Watch-Phone Sync Fixes

## 🏃 5-Minute Quick Test

### 1. Build and Install (1 min)
```
1. Open Xcode
2. Select Watch scheme
3. Build and run on physical Apple Watch
4. Wait for installation to complete
```

### 2. Verify Timezone Display (1 min)
```
✓ Open Flight Times on watch
✓ Look for badge at top-right: [ZULU] or [LOCAL]
✓ Open Settings → Toggle "Zulu Time"
✓ Go back to Flight Times
✓ Verify badge changed color and text
```

### 3. Test Basic Sync (2 min)
```
✓ On watch: Tap "Set OUT Now"
✓ Verify time appears immediately on watch
✓ On phone: Open active trip
✓ Verify OUT time matches (accounting for timezone)
✓ On phone: Change OUT time
✓ On watch: Verify time updates within 2 seconds
```

### 4. Test Time Entry (1 min)
```
✓ On watch: Tap OFF time button
✓ Choose "Pick Time"
✓ Verify dual-clock display shows both Zulu and Local
✓ Tap timezone badge to toggle
✓ Set a time
✓ Verify it appears on phone
```

## ✅ Pass Criteria
- Badge displays correct timezone mode
- Times format correctly with/without "Z" suffix  
- Toggling preference updates display immediately
- Times sync both directions within 2 seconds
- Manual time entry respects timezone preference

## ❌ If Tests Fail

### Badge Doesn't Show or Wrong Color
**Fix:** Restart watch app, verify App Group enabled

### Times Don't Sync
**Fix:** 
1. Check iPhone is unlocked
2. Check Bluetooth enabled
3. Open Watch Settings → Tap "Reconnect"

### Times Wrong by Hours
**This is normal!** Phone stores UTC, watch displays preference.
- Phone "1430" = 2:30 PM UTC
- Watch "09:30" = 2:30 PM UTC shown in EST
- Both are correct ✅

## 📖 Full Documentation

For detailed technical info, troubleshooting, and testing scenarios:
- `README_WATCH_FIXES.md` - Complete guide
- `WATCH_SYNC_FIXES.md` - Technical deep dive
- `CHANGES_SUMMARY.md` - What changed

## 🎯 Expected Results

### Before Fixes
```
Flight Times
┌──────────┬──────────┐
│ OUT      │ OFF      │
│ --:--    │ --:--    │  ← No indicator, always UTC
└──────────┴──────────┘

Settings: No timezone option
```

### After Fixes
```
Flight Times          [🌍 ZULU]
┌──────────┬──────────┐
│ OUT      │ OFF      │
│ 14:30Z   │ 15:45Z   │  ← Clear indicator + Z suffix
└──────────┴──────────┘

Settings: ⚙️ Time Display toggle added
```

## 🚀 Ready to Ship?

Run through all test scenarios in `README_WATCH_FIXES.md` section "🧪 Testing Scenarios" for comprehensive verification.

---

**Happy Testing!** 🎉

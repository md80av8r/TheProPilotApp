# 🚀 GPX Testing Quick Reference Card

## 📦 What You Got
- **GPXTestPlayer.swift** - Playback engine
- **GPXTestIntegration.swift** - App integration + UI
- **Watch improvements** - Colors, haptics, timezone display
- **Complete docs** - Guides and troubleshooting

## ⚡ 30-Second Start

```swift
// Add this to your navigation:
NavigationLink("GPX Testing") {
    GPXTestingView()
        .environmentObject(locationManager)
}
```

## 🎮 Testing Steps

1. **Open GPX Testing view**
2. **Tap "Load KYIP-KDTW Test Flight"**
3. **Set speed to 10x**
4. **Press Play ▶️**
5. **Watch for triggers** (console + UI)

## 🎯 What to Expect

| Time (10x) | Event | Speed | Action |
|------------|-------|-------|--------|
| 0:00 | Start | 0 kts | Airport: KYIP |
| 0:35 | Takeoff | 84 kts | **OFF time** |
| 1:00 | Cruise | 250 kts | Flying |
| 1:39 | Landing | 54 kts | **ON time** |
| 2:00 | End | 0 kts | Airport: KDTW |

## 📊 Speed Presets

- **20x** → 1 min (smoke test)
- **10x** → 2 min (quick test) ⭐
- **5x** → 4 min (normal test)
- **1x** → 20 min (realistic)
- **0.5x** → 40 min (debugging)

## 🎨 Watch Features Added

- 🔵 **OUT** button = Blue
- 🟠 **OFF** button = Orange  
- 🟣 **ON** button = Purple
- 🟢 **IN** button = Green
- 🕐 **Timezone badge** = Shows Zulu/Local
- 📳 **Haptics** = All interactions
- ⏰ **24-hour format** = Always

## 🐛 Quick Fixes

| Problem | Solution |
|---------|----------|
| No file loaded | Add .gpx to Copy Bundle Resources |
| No triggers | Enable test mode toggle |
| Wrong times | Check Zulu/Local preference |
| Too fast/slow | Adjust playback speed |

## 📍 Key Trigger Points

```
TAKEOFF (OFF time):
- Speed crosses ≥ 80 knots
- Must be at airport
- Log: "🛫 Triggering takeoffRollStarted"

LANDING (ON time):
- Speed drops < 60 knots
- After being fast (≥ 80 kts)
- Within 10 minutes of fast roll
- Must be at airport
- Log: "🛬 Triggering landingRollDecel"
```

## 🎯 Success Checklist

- [ ] GPX file loads (30 points)
- [ ] Playback starts
- [ ] Speed changes (0→250→0)
- [ ] Altitude changes (200→3000→200)
- [ ] KYIP detected
- [ ] OFF time at ~84 kts
- [ ] ON time at ~54 kts
- [ ] KDTW detected
- [ ] Console shows triggers
- [ ] Times in flight log

## 💡 Pro Tips

1. Use **10x speed** for most testing
2. Watch **console logs** for details
3. Test **both Zulu and Local**
4. **Reset** between test runs
5. Try **different speeds** to find your workflow

## 🔗 Full Documentation

- **Integration** → `QUICK_INTEGRATION_GUIDE.md`
- **Testing Guide** → `GPX_TEST_GUIDE.md`
- **Watch Updates** → `WATCH_VIEW_IMPROVEMENTS.md`
- **Complete Summary** → `GPX_TESTING_SUMMARY.md`

## 📝 Console Logs to Look For

```bash
✅ Loaded 30 track points from GPX
▶️ Starting GPX playback at 10.0x speed
🏢 Entered KYIP geofence (simulated)
📍 [7/30] Speed: 84 kts
🛫 TAKEOFF: Speed crossed 80 kts
🛫 TEST MODE: Triggering takeoffRollStarted
📍 [21/30] Speed: 54 kts
🛬 LANDING: Speed dropped below 60 kts
🛬 TEST MODE: Triggering landingRollDecel
🏢 Entered KDTW geofence (simulated)
✅ GPX playback completed
```

## 🎊 That's It!

**You're ready to test your flight tracking app without leaving the ground!**

Questions? Check the full docs. Need help? All guides are in your repo.

---

**Happy Testing!** 🛫✈️🛬

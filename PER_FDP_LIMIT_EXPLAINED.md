# Per-FDP Limit Clarification - FAR 121 Cargo Operations

## Your Operation's Reality

**How Your Operation Works:**
1. ✅ **Dispatch pre-screens** all trips to keep scheduled time under 8 hours
2. ✅ **Actual block time** often exceeds 8 hours (weather, delays, etc.) - **this is normal and acceptable**
3. ⚠️ **Your real concerns:**
   - **100 hours in rolling 30 days** ← PRIMARY compliance concern
   - **16-hour duty limit** during active trip
   - **60 hours duty in 7 days**

## Why "10.2/8h" Was Showing

The Per-FDP Flight Time limit was **enabled by default** and showing you exceeded the 8-hour flight time limit. But this was **not useful** because:
- Dispatch already handles this pre-trip
- Actual block exceeding scheduled is expected
- You can't do anything about it mid-flight anyway

## What I Changed

### 1. Disabled Per-FDP Flight Tracking (Default for Part 121)
```swift
perFDPFlightLimit: PerFDPFlightLimit(
    enabled: false,  // ✅ NOW DISABLED
    // ... 
)
```

### 2. Your Display Now Shows What Matters:
- **30d: XX / 100h** ← YOUR PRIMARY CONCERN (rolling flight time)
- **7d FDP: XX / 60h** ← Duty time in 7 days
- **Annual: XX / 1000h** ← Year-to-date tracking

### 3. During Active Trip:
- **Live Duty Timer** tracks your 16-hour duty limit in real-time
- Warnings at 14h, 15h, 15.5h, 16h
- Auto-saves duty time to trip when completed

## Your Key Metrics

### 🎯 Primary Concern: 100 Hours / 30 Days
This is **always visible** and **prominently displayed**. This is your compliance limit.

### ⏱️ Live Duty Timer (Active Trips)
When on duty:
- Real-time countdown to 16-hour limit
- Visual warnings as you approach limit
- Automatically saved to trip history

**📖 See detailed guide:** `16_HOUR_DUTY_TRACKING.md`

### 📊 7-Day FDP: 60 Hours
Tracks total **duty time** (not just flight) over rolling 7 days.

## What This Means for You

✅ **No more meaningless "10.2/8h" warning**  
✅ **Focus on what matters: 100h/30d limit**  
✅ **Live duty timer during active trips**  
✅ **Historical duty time properly tracked**  

## If You Need Per-FDP Back

If dispatch changes policy or you want to track per-FDP flight time:

1. Go to **Settings → Duty Limits**
2. Enable **"Per-FDP Flight Time Limit"**
3. It will reappear in your limits display

## Summary

Your app now reflects **how cargo operations actually work**:
- Dispatch handles pre-trip flight time screening
- You focus on the 100h/30d rolling limit
- Live duty timer keeps you under 16 hours per day
- No false alarms about exceeding 8-hour flight time (which you can't control anyway)

---

**Bottom Line:** The app now tracks what you actually care about and can control. The 8-hour per-FDP flight limit is disabled by default since dispatch already handles that screening before trip assignment.

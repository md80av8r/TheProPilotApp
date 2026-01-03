# NOC Schedule Revision Notification System

## Overview
The NOC (Network Operations Center) notification system intelligently alerts pilots when their schedule has changed and requires confirmation. The system is designed to avoid notification spam while ensuring important changes aren't missed.

## How It Works

### 1. **Schedule Change Detection**
When your NOC schedule is synced (either manually or via auto-sync), the system:
- Generates a cryptographic hash of **future events only** (today and beyond)
- Ignores past events (already flown)
- Strips out metadata timestamps that change on every sync (DTSTAMP, LAST-MODIFIED, CREATED)
- Compares the new hash with the previously stored hash

**Result**: Only actual schedule content changes trigger detection, not technical metadata updates.

### 2. **Relevance Filtering**
Not all changes are urgent. The system applies smart filtering:
- **Alert Window**: Only changes within the next N days (default 7) trigger alerts
- **Far-future changes** (e.g., schedule changes 3 months out) are detected but don't trigger notifications
- You can adjust the alert window: 3, 5, 7, 14, or 30 days

**Why?** Far-future changes often get revised multiple times. Only near-term changes require immediate attention.

### 3. **Deduplication**
To prevent notification spam from auto-sync:
- Each notification is tied to a specific schedule hash
- If the same schedule revision is synced multiple times, only ONE notification is sent
- The system remembers: "I already told you about this change"

**Example:**
- 9:00 AM: Schedule changes, notification sent ✅
- 10:00 AM: Auto-sync runs, same schedule → no notification 🔇
- 11:00 AM: Auto-sync runs, same schedule → no notification 🔇
- 2:00 PM: Schedule changes AGAIN → new notification sent ✅

### 4. **Throttling**
Even if a schedule changes multiple times, notifications are throttled:
- **Default**: Maximum one notification per 12 hours
- **Adjustable**: 6, 12, 24, or 48 hours
- Prevents alert fatigue from rapid schedule changes

**Why?** If your schedule is revised 5 times in one day, you don't need 5 notifications. The throttle ensures you're aware but not overwhelmed.

### 5. **Quiet Hours**
Respect your rest periods:
- Set quiet hours (e.g., 10 PM - 6 AM)
- Revision notifications will be suppressed during this window
- The revision flag still sets (you'll see it in the app)
- When quiet hours end, you won't get a flood of old notifications

**Toggle**: You can choose whether revision alerts respect quiet hours (enabled by default)

## User Controls

### Available Settings (NOC Alerts Screen)

#### **Master Control**
- ✅ **NOC Alerts**: Master on/off switch for all NOC notifications

#### **Schedule Change Alerts**
- ✅ **Schedule Revision Alerts**: Enable/disable revision notifications
- ✅ **Show Revision Banner**: Display in-app banner for pending revisions
- ✅ **Alert Sound**: Notification sound on/off
- ✅ **Alert Window**: Choose urgency window (3-30 days)
  - **3 days**: Only very near-term changes
  - **7 days** (default): Next week's changes
  - **14 days**: Two-week window
  - **30 days**: Full month ahead
- ✅ **Notification Throttle**: Minimum time between alerts
  - **6 hours**: More frequent updates
  - **12 hours** (default): Balanced approach
  - **24 hours**: Once per day maximum
  - **48 hours**: Very conservative

#### **Background Sync**
- ✅ **Auto-Sync**: Automatically check for schedule changes
- ✅ **Sync Frequency**: 15 min, 30 min, 1h, 2h, 4h
- ℹ️ **Last Sync Time**: See when data was last updated

#### **Quiet Hours**
- ✅ **Quiet Hours**: Enable/disable
- ✅ **Apply to Revisions**: Whether revision alerts respect quiet hours
- ⏰ **Start/End Time**: Set your rest period

#### **Status**
- 📊 **Pending Revision**: Shows if you have unconfirmed changes
- 📅 **Time Since Detection**: How long the revision has been pending
- 🔗 **Confirm Button**: Quick link to open NOC portal

## How Notifications Are Triggered

### ✅ **You WILL Get a Notification When:**
1. A **new** schedule change is detected within your alert window
2. It's **not** during quiet hours (if enabled)
3. You haven't received a notification within the throttle period
4. The schedule hash is **different** from the last notification

### 🔇 **You WON'T Get a Notification When:**
1. Auto-sync runs but schedule is **unchanged**
2. A change is detected but it's **beyond your alert window** (e.g., 45 days out with a 7-day window)
3. You've **already been notified** about this exact schedule version
4. It's during **quiet hours** (if enabled)
5. A notification was sent within the **throttle window** (e.g., 12 hours ago)
6. You've **disabled** revision notifications

## Notification Flow Example

### Scenario: Schedule Change on Tuesday Morning

**9:00 AM** - NOC publishes revision for flights on Friday
- ✅ Auto-sync detects change
- ✅ Within 7-day alert window
- ✅ Not in quiet hours
- ✅ No recent notification (12h throttle clear)
- **→ NOTIFICATION SENT** 📱

**10:00 AM** - Auto-sync runs again
- ⚙️ Same schedule hash
- 🔇 Already notified about this version
- **→ NO NOTIFICATION** (deduplication)

**2:00 PM** - NOC updates revision again
- ✅ New schedule hash detected
- ❌ Notification sent 5 hours ago (12h throttle active)
- **→ NO NOTIFICATION** (throttled)

**9:00 PM** - User confirms revision in NOC portal
- ✅ Revision flag cleared
- ✅ Notification dismissed

**Next Day 10:00 AM** - Auto-sync runs
- ⚙️ Schedule stable (hash matches)
- ✅ No pending revision
- **→ NO NOTIFICATION** (all clear)

## Advanced Features

### **Automatic Expiration**
Pending revisions auto-clear after 24 hours if the schedule becomes stable. This prevents stale alerts from old changes.

### **Schedule Hash Technology**
- Uses SHA-256 cryptographic hashing
- Only hashes **future events** (past events filtered out daily)
- Normalizes content (removes timestamps)
- Sorts events for consistent comparison

### **Multi-Layer Protection**
The system has **5 layers** of duplicate prevention:
1. **Hash comparison** - Is schedule actually different?
2. **Relevance check** - Are changes in the alert window?
3. **Deduplication** - Already notified about this version?
4. **Throttling** - Too soon since last notification?
5. **Quiet hours** - Should we suppress right now?

## Logging & Debugging

All notification decisions are logged to the console with emoji markers:

- `✅` - Success or positive action
- `🔔` - Change detected
- `🔇` - Notification suppressed (with reason)
- `⚠️` - Warning or important state
- `❌` - Error
- `📝` - Informational note

### Common Log Messages

```
🔔 Future schedule change detected!
🔇 Revision already pending for this schedule version - skipping duplicate alert
🔇 Notification throttled - sent 5.2h ago (min: 12h)
🔇 Notification suppressed - currently in quiet hours
✅ Revision notification sent: Schedule changes for Jan 5, Jan 6
```

## Recommendations

### **For Most Pilots (Default)**
- ✅ Revision Alerts: **Enabled**
- ⏰ Alert Window: **7 days**
- 🕐 Throttle: **12 hours**
- 🌙 Quiet Hours: **10 PM - 6 AM**

### **For High-Frequency Schedulers**
If your schedule changes frequently:
- ⏰ Alert Window: **3-5 days** (only very near-term)
- 🕐 Throttle: **24 hours** (less frequent alerts)
- 📱 Consider disabling auto-sync and syncing manually

### **For Reserve Pilots**
If you're on reserve with volatile scheduling:
- ⏰ Alert Window: **3 days** (very short window)
- 🕐 Throttle: **6 hours** (more responsive)
- 🔔 Enable sync notifications to know when new trips appear

### **For Commuters**
If you need uninterrupted rest:
- 🌙 Quiet Hours: **Extended** (e.g., 9 PM - 7 AM)
- ✅ Apply to Revisions: **Enabled**
- 🕐 Throttle: **24 hours** (conservative)

## FAQ

### Q: Why didn't I get notified about a schedule change?
**A:** Check these factors:
1. Was the change beyond your alert window? (Settings shows current window)
2. Are you in quiet hours?
3. Did you receive a notification recently? (Check throttle setting)
4. Is "Revision Alerts" enabled?
5. Was it truly a content change, or just a metadata update?

### Q: I'm getting duplicate notifications!
**A:** This should be rare with the new system. Check:
1. Ensure you're running the latest version
2. Review console logs (look for "🔇" messages)
3. Try increasing the throttle window to 24 hours

### Q: Will I miss important changes with quiet hours?
**A:** No! Quiet hours only suppress the notification sound/alert. The pending revision flag still sets, and you'll see it in the app. When you open the app, you'll be prompted to confirm.

### Q: How do I confirm a revision?
**A:** Three ways:
1. Tap the notification when it arrives
2. Use the "Confirm" button in NOC Alert Settings
3. The in-app revision banner (if enabled)

All three open the NOC portal where you can review and confirm the changes.

### Q: What happens if my schedule changes while I'm flying?
**A:** If the change occurs during quiet hours (e.g., red-eye flight):
- Notification suppressed during your rest
- Revision flag sets in the app
- You'll see the pending revision when you wake up
- No retroactive notification flood

### Q: Can I test the notification system?
**A:** Currently, notifications only fire on real schedule changes. To test:
1. Ensure "Revision Alerts" is enabled
2. Set auto-sync to 15 minutes
3. Have your scheduler make a small test change in NOC
4. Wait for the next sync cycle
5. You should receive a notification

## Technical Details

### Dependencies
- **CryptoKit**: For SHA-256 hashing
- **UserNotifications**: For local notifications
- **Combine**: For reactive data flow
- **UserDefaults**: For persistence (uses App Group for widget sharing)

### Performance
- Hash generation: ~10-50ms (depends on calendar size)
- Memory footprint: Minimal (only stores hash strings)
- Battery impact: Negligible (leverages iOS background refresh)

### Privacy
- All processing happens on-device
- No schedule data is transmitted
- Notifications use standard iOS privacy protections

## Troubleshooting

### Issue: No notifications at all
**Solution:**
1. Check Settings → Notifications → [App Name] → Allow Notifications ✅
2. Ensure "NOC Alerts" master toggle is enabled
3. Verify "Revision Alerts" is enabled
4. Check that you're not always in quiet hours

### Issue: Too many notifications
**Solution:**
1. Increase throttle window to 24 or 48 hours
2. Reduce alert window to 3-5 days
3. Enable quiet hours during your typical rest periods
4. Contact your scheduler about excessive schedule changes

### Issue: Notification delayed
**Solution:**
- Auto-sync runs at the configured interval (default 60 minutes)
- If you need immediate updates, manually sync in NOC Settings
- Consider reducing sync interval to 15 or 30 minutes

## Future Enhancements (Roadmap)

Potential future features:
- 🎯 Notification priorities (minor vs. major changes)
- 📊 Change summary in notification (e.g., "Flight time changed by 2 hours")
- 🔗 Deep linking directly to revision in NOC
- 📱 Interactive notifications (Confirm/Dismiss actions)
- 🌍 Time zone awareness for commuters
- 📈 Notification history log

---

**Version:** 1.0 (January 2026)  
**Last Updated:** User control enhancements with alert window and throttle settings

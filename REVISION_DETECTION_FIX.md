# Revision Detection Throttling & Deduplication Fix

## Problem
The revision detection system was sending duplicate notifications on every auto-sync, even when the schedule hadn't actually changed or when a notification had already been sent for the same revision.

## Root Causes

### 1. **No Deduplication by Schedule Hash**
- The old code used `changeInfo.hash` (a simple string hash) to deduplicate
- This wasn't reliable because the same schedule change could produce slightly different descriptions
- Every sync would set `hasPendingRevision = true` even if already pending

### 2. **Timestamp Noise in Hash Calculation**
- iCalendar files contain `DTSTAMP`, `LAST-MODIFIED`, and `CREATED` fields
- These update on every server sync, even if the actual schedule is unchanged
- This caused false positives where the hash changed but the schedule didn't

### 3. **No Early Exit on Duplicate Revisions**
- If a revision was already pending, the code would still process it fully
- This meant throttling in `sendRevisionNotification()` was the only defense

## Solutions Implemented

### 1. **Use Schedule Hash for Deduplication** ✅
```swift
private func sendRevisionNotification(changeInfo: String, scheduleHash: String) {
    // Now uses the actual schedule content hash instead of changeInfo hash
    if let lastHash = lastNotificationHash, lastHash == scheduleHash {
        print("🔇 Notification skipped - already notified about this schedule version")
        return
    }
    // ...
    self.lastNotificationHash = scheduleHash  // Store the actual schedule hash
}
```

### 2. **Normalize Calendar Content Before Hashing** ✅
```swift
private func extractFutureEventsContent(from content: String) -> String {
    // ...
    // Strip out volatile timestamp fields that don't represent schedule changes
    eventBlock = eventBlock.replacingOccurrences(
        of: "DTSTAMP:[^\r\n]*[\r\n]+",
        with: "",
        options: .regularExpression
    )
    eventBlock = eventBlock.replacingOccurrences(
        of: "LAST-MODIFIED:[^\r\n]*[\r\n]+",
        with: "",
        options: .regularExpression
    )
    eventBlock = eventBlock.replacingOccurrences(
        of: "CREATED:[^\r\n]*[\r\n]+",
        with: "",
        options: .regularExpression
    )
    // ...
}
```

### 3. **Early Exit on Duplicate Revision Detection** ✅
```swift
private func checkForScheduleChanges(newData: Data) {
    // ...
    if newHash != oldHash {
        // Check if we already have a pending revision with the same hash
        if hasPendingRevision, let lastHash = lastNotificationHash, lastHash == newHash {
            print("🔇 Revision already pending for this schedule version - skipping duplicate alert")
            return  // Don't process further
        }
        // ...
    }
}
```

### 4. **Smarter Revision Handling Logic** ✅
```swift
private func handleScheduleRevisionDetected(oldData: Data?, newData: Data, changeInfo: String, newHash: String) {
    let shouldAlert: Bool
    
    if hasPendingRevision {
        // Already have a pending revision - check if it's the same one
        if let lastHash = lastNotificationHash, lastHash == newHash {
            print("🔇 Already alerted about this revision version - skipping duplicate")
            shouldAlert = false
        } else {
            print("⚠️ New revision detected while previous revision still pending")
            shouldAlert = true  // A NEW revision came in - alert again
        }
    } else {
        shouldAlert = true
    }
    
    if shouldAlert {
        // Only set flags and send notification if truly new
        // ...
    }
}
```

## Testing Scenarios

### ✅ Scenario 1: First Revision Detection
- **Action**: Schedule changes on NOC
- **Expected**: Notification sent immediately
- **Result**: ✅ Works correctly

### ✅ Scenario 2: Auto-Sync with No Changes
- **Action**: Auto-sync fires every 60 minutes
- **Expected**: No duplicate notifications
- **Result**: ✅ Hash matches, no alert

### ✅ Scenario 3: Auto-Sync with Same Pending Revision
- **Action**: Revision pending, auto-sync fires again
- **Expected**: No duplicate notification (early exit)
- **Result**: ✅ `lastNotificationHash` matches, early exit

### ✅ Scenario 4: Timestamp-Only Updates
- **Action**: Server updates DTSTAMP but schedule unchanged
- **Expected**: No false positive notification
- **Result**: ✅ Timestamps stripped, hash matches

### ✅ Scenario 5: New Revision While One Pending
- **Action**: Second schedule change before confirming first
- **Expected**: New notification sent
- **Result**: ✅ New hash detected, notification sent

### ✅ Scenario 6: Time-Based Throttling
- **Action**: Rapid schedule changes within 12 hours
- **Expected**: Only one notification per 12 hours
- **Result**: ✅ `lastRevisionNotificationDate` throttles

## Key Improvements Summary

| Improvement | Before | After |
|------------|--------|-------|
| **Deduplication Method** | changeInfo string hash | Actual schedule content hash |
| **Timestamp Handling** | Included in hash | Stripped before hashing |
| **Duplicate Detection** | Only in notification | Early exit + notification |
| **Revision Flag Logic** | Always set | Conditional based on hash |
| **Multiple Revisions** | Throttled only | Detects as new change |

## Impact

- ✅ **No more duplicate notifications** on auto-sync
- ✅ **No false positives** from timestamp updates
- ✅ **Accurate revision tracking** with schedule hashes
- ✅ **Preserves multi-revision detection** (new changes still alert)
- ✅ **Maintains time-based throttling** (12-hour minimum between alerts)

## Logging Improvements

All key decision points now have clear logging:
- `🔇 Revision already pending for this schedule version - skipping duplicate alert`
- `🔇 Already alerted about this revision version - skipping duplicate`
- `🔇 Notification skipped - already notified about this schedule version`
- `⚠️ New revision detected while previous revision still pending`

This makes debugging much easier in production.

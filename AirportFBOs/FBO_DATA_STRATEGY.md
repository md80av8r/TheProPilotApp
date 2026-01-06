# FBO Data Management Strategy

## 📊 Architecture Overview

ProPilot uses a **three-tier hybrid approach** for FBO data management, combining the reliability of shipped data with the freshness of crowdsourced updates.

### The Three Tiers

```
┌─────────────────────────────────────────────────────────────┐
│                      USER VIEW (App)                        │
│                    Merged FBO Data                          │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
                    Smart Merge Algorithm
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
┌───────▼────────┐                      ┌──────────▼──────────┐
│  CSV Baseline  │                      │  CloudKit Public DB │
│   (Verified)   │                      │  (Crowdsourced)     │
│                │                      │                     │
│  • 164 FBOs    │                      │  • User additions   │
│  • 82 airports │                      │  • Fuel updates     │
│  • Curated     │                      │  • Reviews          │
│  • Offline     │                      │  • Real-time        │
└────────────────┘                      └─────────────────────┘
```

### 1. CSV Baseline (`propilot_fbos.csv`)

**Purpose:** Provide verified, offline-first FBO data

**Characteristics:**
- ✅ Bundled with app (works offline)
- ✅ Curated and verified by you
- ✅ Version-controlled (incremented when CSV updates)
- ✅ Marked with `isVerified: true` and `updatedBy: "CSV Import"`
- ✅ Updated via app releases

**Use Cases:**
- Initial data load
- Offline operation
- Quality baseline for major FBOs

### 2. CloudKit Public Database

**Purpose:** Enable community contributions and real-time updates

**Characteristics:**
- 🌐 Synced across all users
- 📱 Real-time fuel price updates
- 👥 User-contributed FBO additions
- ⭐ Ratings and reviews
- 🔄 Automatically synced

**Use Cases:**
- User adds a new FBO
- Pilot updates fuel prices
- Community ratings/reviews
- FBO details change (phone, hours, etc.)

### 3. Preferred FBOs (Local UserDefaults)

**Purpose:** Personal FBO preferences per airport

**Characteristics:**
- 📍 Per-airport user choice
- 🔔 Custom notification distance
- 📞 Quick contact info
- 💾 Device-local (not synced)

**Use Cases:**
- Personal FBO preferences
- Quick-dial notifications
- Route planning

---

## 🔄 Smart Merge Algorithm

When CloudKit data is fetched, the app intelligently merges it with CSV baseline data:

### Merge Rules (Priority Order)

1. **FBO Identification**
   - Normalize names (lowercase, remove "Aviation", "FBO", extra spaces)
   - Match CSV FBOs with CloudKit FBOs by name

2. **Contact Information**
   - CloudKit wins for phone, UNICOM, website (if from user, not CSV import)
   - Assumption: Users provide more current contact info

3. **Amenities**
   - Use **OR logic**: If either source says "has crew cars", mark true
   - Reasoning: Amenities are additive (more info = better)

4. **Fuel Prices** ⛽
   - **ALWAYS use the newest data** (by `fuelPriceDate`)
   - Source doesn't matter—freshness is critical
   - CSV may have baseline, but user updates are time-sensitive

5. **Fees**
   - Prefer CloudKit if available (user-reported)
   - Fall back to CSV baseline

6. **Ratings**
   - Use CloudKit ratings (community-driven)
   - CSV doesn't include ratings

7. **Verification Status**
   - Keep `isVerified: true` if either source is verified
   - CSV entries are always verified

8. **CloudKit Record ID**
   - Always preserve for syncing
   - Enables future updates from CloudKit

### Example Merge Scenario

**CSV Entry:**
```swift
CrowdsourcedFBO(
    name: "Signature Aviation",
    phoneNumber: "415-555-0100",
    unicomFrequency: "130.60",
    jetAPrice: 6.50,  // From when CSV was created
    fuelPriceDate: nil,
    hasCrewCars: true,
    isVerified: true,
    updatedBy: "CSV Import"
)
```

**CloudKit Entry (User Update):**
```swift
CrowdsourcedFBO(
    name: "Signature Aviation",
    phoneNumber: "415-555-0101",  // Updated phone
    unicomFrequency: "130.60",
    jetAPrice: 7.25,  // Current price!
    fuelPriceDate: Date() - 2 days,  // Recent
    hasCrewCars: true,
    hasCrewLounge: true,  // New amenity!
    isVerified: false,
    updatedBy: "user123",
    cloudKitRecordID: "abc-123"
)
```

**Merged Result:**
```swift
CrowdsourcedFBO(
    name: "Signature Aviation",
    phoneNumber: "415-555-0101",  // ← CloudKit (newer)
    unicomFrequency: "130.60",
    jetAPrice: 7.25,              // ← CloudKit (newer fuel price)
    fuelPriceDate: Date() - 2 days,
    hasCrewCars: true,            // ← Both sources
    hasCrewLounge: true,          // ← CloudKit (additive)
    isVerified: true,             // ← CSV (keep verified status)
    updatedBy: "user123",
    cloudKitRecordID: "abc-123"   // ← CloudKit (enable sync)
)
```

---

## 🎯 User Experience Flow

### First Launch (New User)
1. ✅ CSV FBOs load immediately (164 FBOs available offline)
2. 🌐 CloudKit fetch starts in background
3. 🔄 Merge completes within seconds
4. 📱 User sees combined dataset

### Subsequent Launches
1. 💾 Cached FBOs load instantly (CSV + previous CloudKit data)
2. 🌐 CloudKit fetch updates in background
3. 🔄 Merge preserves CSV baseline + new user contributions

### User Adds New FBO
1. ✍️ User fills out FBO form
2. 💾 Saved locally immediately
3. ☁️ Uploaded to CloudKit
4. 🌍 Other users receive it on next sync

### User Updates Fuel Price
1. ⛽ Quick fuel update sheet
2. 💾 Local cache updated
3. ☁️ CloudKit updated with timestamp + reporter
4. 🌍 Other users get fresh prices

---

## 📝 Best Practices for CSV Updates

### When to Update CSV
- ✅ New major FBOs open
- ✅ FBOs permanently close
- ✅ Significant amenity changes
- ✅ Verified contact info changes
- ✅ Baseline fuel price adjustments (quarterly?)

### When NOT to Update CSV
- ❌ Daily fuel price changes (use CloudKit)
- ❌ Temporary closures
- ❌ Minor info updates (let users handle via CloudKit)

### CSV Update Process
1. Edit `propilot_fbos.csv`
2. Increment `currentFBOCSVVersion` in `AirportDatabaseManager.swift`
3. Test with fresh install
4. Release new app version

### Version Increment
```swift
// In AirportDatabaseManager.swift
private let currentFBOCSVVersion = 3  // ← Increment this
```

**Result:** On next app launch, CSV is reloaded and merged with CloudKit data.

---

## 🔒 Data Protection & Quality

### CSV Data (Verified) - PROTECTED
- ✅ Curated by you
- ✅ Trusted source
- ✅ Always marked `isVerified: true`
- 🛡️ **Cannot be deleted by users**
- 🔄 Restored on each CSV version update

### Protection Rules

| FBO Type | Can Edit | Can Delete | Badge |
|----------|----------|------------|-------|
| Verified (CSV) | ✅ Enhance only | ❌ Protected | 🔵 "Verified" |
| User-Created | ✅ Full edit | ✅ Allowed | None |
| Duplicate of Verified | ✅ Full edit | ✅ Cleanup allowed | 🟠 "DUPLICATE" |

### Duplicate Prevention System

**At Creation Time:**
1. User tries to add FBO with existing name
2. System detects duplicate using fuzzy matching:
   - "Signature" matches "Signature Aviation"
   - "Atlantic FBO" matches "Atlantic Aviation"
3. If duplicate of **verified FBO**: User's data is **merged** into verified entry
4. If duplicate of **user FBO**: Error shown, user must edit existing entry

**At Display Time:**
1. Duplicates are flagged with orange "DUPLICATE" badge
2. Footer message: "Swipe left on duplicate entries to remove them"
3. Swipe action shows "Delete Duplicate" button
4. Verified FBOs have no swipe action (protected)

### Deletion Protection Code
```swift
func deleteCrowdsourcedFBO(_ fbo: CrowdsourcedFBO) async throws {
    // PROTECT verified FBOs
    if fbo.isVerified {
        throw NSError(domain: "FBOProtection", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "This FBO is from the verified database and cannot be deleted."])
    }
    // Allow deletion of non-verified FBOs...
}
```

### CloudKit Data (Crowdsourced)
- ⚠️ User-submitted (trust varies)
- ⭐ Use ratings/review counts as quality signals
- 🛡️ Cannot delete verified entries
- 🔄 Merges with verified data intelligently

### Future Enhancements (Optional)
1. **Admin Panel:** Review user submissions before publish
2. **Verification System:** Mark user submissions as verified
3. **Reputation System:** Trusted users get higher merge priority
4. **Expiration:** Mark fuel prices as stale after X days
5. **Conflict Resolution UI:** Let users choose when duplicates exist

---

## 🐛 Troubleshooting

### "FBOs not showing up"
**Issue:** FBOs load from CSV but disappear after CloudKit fetch

**Fix:** Smart merge now prevents this—CloudKit merge is additive

**Debug:**
```
🏢 FBOTabContent: Loaded X cached FBOs for KXXX
🔄 FBO merge for KXXX: X local + Y cloud = Z merged
🏢 FBOTabContent: After smart merge, displaying Z FBOs
```

### "Duplicate FBOs showing"
**Issue:** CSV and CloudKit have slightly different names

**Fix:** Name normalization in merge algorithm

**Example:**
- CSV: "Signature Aviation"
- CloudKit: "Signature Aviation FBO"
- Normalized: "signature" (matches!)

### "Old fuel prices showing"
**Issue:** CSV baseline price is old

**Solution:** User updates fuel price → CloudKit → overwrites CSV baseline in merge

---

## 🚀 Migration Strategy for Existing Users

If you already have users with CloudKit data:

1. **CSV ships with v2**
   - CSV loads for all users
   - Existing CloudKit data preserved
   - Merge combines both sources

2. **User sees more FBOs**
   - Their previous CloudKit submissions
   - PLUS new CSV baseline entries
   - PLUS other users' CloudKit submissions

3. **No data loss**
   - Merge is non-destructive
   - Cache stores everything
   - CloudKit record IDs preserved

---

## 📊 Monitoring & Analytics (Optional)

Track these metrics to understand data usage:

- **CSV Coverage:** % of user's viewed airports with CSV FBOs
- **CloudKit Activity:** New FBO additions per day
- **Fuel Updates:** How often users update prices
- **Stale Data:** Airports with no updates in 90+ days
- **Popular FBOs:** Most-viewed FBOs (update CSV for these)

---

## 🎓 Summary

**Architecture Decision:** ✅ Hybrid (CSV + CloudKit)

**Why It Works:**
- 📦 Offline-first (CSV baseline)
- 🌐 Real-time crowdsourcing (CloudKit)
- 🔄 Smart merge (best of both worlds)
- 📈 Scalable (users help populate data)
- 💾 No single point of failure

**User Benefit:**
- Instant data on first launch
- Fresh fuel prices from community
- Contribute and help other pilots
- Works offline with baseline data

**Developer Benefit:**
- Control quality with CSV baseline
- Community builds the dataset
- CloudKit handles sync/storage
- Easy updates via app releases

---

## 🔮 Future Considerations

### Phase 1 (Current)
- ✅ CSV baseline
- ✅ CloudKit crowdsourcing
- ✅ Smart merge

### Phase 2 (Future)
- 🔄 Push notifications for nearby fuel price updates
- 📊 FBO comparison tool
- 🗺️ FBO search/filter
- ⭐ FBO rating system

### Phase 3 (Advanced)
- 🤖 AI-detected stale data
- 📸 Photo uploads for FBOs
- 💬 FBO comments/tips
- 🏆 Contributor leaderboard

---

**Last Updated:** 2026-01-03
**Current CSV Version:** 3
**Total CSV FBOs:** 164 (82 airports)

---

## 🔧 Key Functions Reference

### AirportDatabaseManager.swift

| Function | Purpose |
|----------|---------|
| `loadFBOsFromCSV()` | Load verified FBOs from bundled CSV |
| `saveCrowdsourcedFBO(_:)` | Save FBO locally first, then sync to CloudKit |
| `deleteCrowdsourcedFBO(_:)` | Delete FBO (protected for verified) |
| `findDuplicateFBO(name:airportCode:)` | Fuzzy match to detect duplicates |
| `isDuplicateOfVerified(_:)` | Check if FBO duplicates a verified entry |
| `canDeleteFBO(_:)` | Returns false for verified FBOs |
| `shouldOfferDuplicateDeletion(_:)` | Returns true for non-verified duplicates |
| `mergeFBOData(local:cloud:)` | Smart merge algorithm |

### FBOBannerView.swift

| Component | Purpose |
|-----------|---------|
| `PreferredFBOEditorSheet` | FBO chooser (list + add new) |
| `FBOListRow` | Displays FBO with verified/duplicate badges |
| `CrowdsourcedFBOEditorSheet` | Edit/add FBO form |

# Airport Database Manager Migration Guide
**Date:** December 23, 2024  
**Action:** Migrating to new CSV-based + pilot reviews system

---

## ✅ Step 1: Backup Complete
- [x] Backup created before migration

---

## 📦 Step 2: Get the CSV File

You need `propilot_airports.csv` - a standard aviation database.

### **Option A: Use OurAirports Database (Recommended)**
1. Go to: https://ourairports.com/data/
2. Download: **airports.csv** (free, updated monthly)
3. Rename to: `propilot_airports.csv`
4. Add to your Xcode project

### **Option B: I'll Create a Starter CSV**
I can create a CSV with ~500 major airports to get you started.

### **CSV Format Required:**
```
id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,continent,iso_country,iso_region,municipality,scheduled_service,icao_code,iata_code
1,KATL,large_airport,Hartsfield-Jackson Atlanta International Airport,33.6367,-84.428101,1026,NA,US,US-GA,Atlanta,yes,KATL,ATL
```

---

## 🔧 Step 3: Replace AirportDatabaseManager.swift

1. **Delete current file:**
   - Select `AirportDatabaseManager.swift` in Xcode
   - Right-click → Delete → Move to Trash

2. **Create new file:**
   - File → New → File → Swift File
   - Name: `AirportDatabaseManager.swift`
   - Paste the new code

---

## 🔍 Step 4: Find and Fix References

Based on my search, you have **very few references** to update!

### Files That Might Need Updates:
- ✅ `AirportDatabaseTestView.swift` - Already doesn't use it
- ✅ `AreaGuideView.swift` - Already doesn't use it
- ✅ `JumpseatFinderView.swift` - Check if it uses airport lookups

### Common Changes Needed:

**Property Name Changes:**
```swift
// OLD:
manager.cloudAirports
manager.isDownloadingDatabase
manager.downloadProgress
manager.lookupStatus

// NEW:
manager.airports
manager.isLoading
// (no progress property)
manager.loadingMessage
```

**Method Changes:**
```swift
// OLD:
await manager.downloadAirportDatabase()

// NEW:
await manager.fetchCloudKitUpdates()
// (or nothing - loads automatically!)
```

---

## 🧪 Step 5: Test the Migration

### **Test 1: Airport Lookup**
```swift
let manager = AirportDatabaseManager.shared
print("Total airports: \(manager.airports.count)")

if let airport = manager.getAirport(for: "KATL") {
    print("Found: \(airport.name)")
} else {
    print("❌ Not found!")
}
```

### **Test 2: Search**
```swift
let results = manager.searchAirports(query: "Atlanta")
print("Search results: \(results.count)")
```

### **Test 3: Get Name**
```swift
let name = manager.getAirportName(for: "KYIP")
print("Airport name: \(name)")
```

---

## 🆕 Step 6: Use New Features (Optional)

### **Pilot Reviews**

Add a review button to your airport detail views:

```swift
Button("Write Review") {
    let review = PilotReview(
        airportCode: "KYIP",
        pilotName: "Captain Smith",
        rating: 5,
        content: "Great FBO service!",
        fboName: "Signature"
    )
    
    Task {
        try await AirportDatabaseManager.shared.submitReview(review)
    }
}
```

Fetch reviews:

```swift
Task {
    let reviews = try await AirportDatabaseManager.shared.fetchReviews(for: "KYIP")
    print("Found \(reviews.count) reviews")
}
```

---

## ⚠️ Potential Issues & Solutions

### **Issue 1: CSV File Not Found**
```
❌ propilot_airports.csv not found in bundle
```
**Solution:** Make sure CSV is added to your app target (check box in File Inspector)

### **Issue 2: Empty Airports Dictionary**
```
Total airports: 0
```
**Solutions:**
- Check CSV file is in bundle
- Check console for parse errors
- Verify CSV format matches expected columns

### **Issue 3: CloudKit Updates Fail**
```
❌ CloudKit update failed: [error]
```
**Solution:** This is OK! App works offline with CSV. CloudKit is just for updates.

---

## 🎯 Migration Checklist

### Before Migration:
- [x] Backup created
- [ ] CSV file downloaded
- [ ] CSV file added to Xcode project (target checked)

### During Migration:
- [ ] Old AirportDatabaseManager.swift deleted
- [ ] New AirportDatabaseManager.swift added
- [ ] Project builds successfully
- [ ] No compiler errors

### After Migration:
- [ ] Test airport lookup works
- [ ] Test search works
- [ ] Test getAirportName works
- [ ] Console shows "Loaded X airports from CSV"
- [ ] (Optional) Test pilot reviews

### If Issues:
- [ ] Check console for CSV load messages
- [ ] Verify CSV file is in correct format
- [ ] Check CSV file is in app bundle
- [ ] Restore from backup if needed

---

## 📊 What Changed

### **Data Source:**
- **OLD:** CloudKit on-demand download
- **NEW:** Local CSV + CloudKit updates

### **Startup:**
- **OLD:** Empty until download triggered
- **NEW:** Instant (loads from CSV)

### **Offline:**
- **OLD:** Doesn't work without internet
- **NEW:** Works perfectly offline

### **New Features:**
- ✅ Pilot reviews system
- ✅ Airport ratings
- ✅ Automatic background sync
- ✅ Faster startup

---

## 🚀 Ready to Migrate?

1. Get the CSV file (Step 2)
2. Add CSV to Xcode
3. Replace the Swift file (Step 3)
4. Build and test (Step 5)
5. Done! ✅

---

**Need help?** Check console logs for:
- `📦 Loading airports from CSV...`
- `✅ Loaded X airports from CSV`
- `❌ propilot_airports.csv not found`

---

**Migration Status:** Ready to begin  
**Risk Level:** Low (code doesn't heavily use it)  
**Backup:** ✅ Complete

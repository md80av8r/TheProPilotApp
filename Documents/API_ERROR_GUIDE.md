# 🔍 Common API Errors & Solutions

## Possible API Errors After Rebuild:

### 1. **HTTP 401 - Unauthorized**
**Cause:** Invalid or missing API key

**Solution:**
- Go to: Jumpseat Finder → Settings (gear icon)
- **Clear** the API key field (leave it empty)
- Tap Done
- Search again → Should show mock data ✅

---

### 2. **HTTP 403 - Forbidden**
**Cause:** API key doesn't have permission

**Solution:**
- Sign up for new key: https://aviationstack.com/signup/free
- Copy new key
- Paste in Settings
- Try again

---

### 3. **HTTP 429 - Rate Limit Exceeded**
**Cause:** Too many requests (free tier = 100/month)

**Solution:**
- Wait 1 hour for rate limit to reset
- OR use mock data (clear API key in Settings)
- OR upgrade API plan

---

### 4. **"Invalid response" or JSON decode error**
**Cause:** API returned unexpected format

**Solution:**
- This is now handled automatically
- App will fall back to mock data
- No action needed from user

---

### 5. **Network Error (after ATS fix)**
**Cause:** DNS issue or API down

**Solution:**
- Check internet connection
- Try different network (WiFi vs cellular)
- Use mock data as fallback

---

## Quick Troubleshooting:

### If you see ANY API error:

**Option A: Use Mock Data (Always Works)**
```
1. Settings → Delete API key
2. Leave field empty
3. Done
4. Search → See 3 mock flights ✅
```

**Option B: Debug the API Call**

Add this to `FlightScheduleService.swift` to see what's happening:

```swift
func searchFlights(...) async throws -> [FlightSchedule] {
    let userApiKey = UserDefaults.standard.string(forKey: "aviationStackAPIKey") ?? ""
    
    // ✅ ADD THIS DEBUG LINE:
    print("🔑 Using API key: \(userApiKey.isEmpty ? "NONE (will use mock data)" : userApiKey)")
    
    guard !userApiKey.isEmpty else {
        print("📦 No API key - returning mock data")
        throw FlightScheduleError.noAPIKey
    }
    
    // ... rest of function
}
```

Then check Xcode console to see what's happening.

---

## Expected Behavior:

### ✅ With NO API Key (Default):
```
Search KMEM → KATL
↓
Shows 3 mock flights:
- Delta DL1234
- American AA5678  
- United UA9012
```

### ✅ With VALID API Key:
```
Search KMEM → KATL
↓
Shows real flights from AviationStack API
(May be 0 results if no flights scheduled)
```

### ✅ With INVALID API Key:
```
Search KMEM → KATL
↓
Shows error message
OR
Falls back to mock data
```

---

## Most Common Issue:

**You entered an API key in Settings but it's invalid**

### Quick Fix:
1. Open Settings in app
2. **Delete everything in API key field**
3. Leave it completely empty
4. Tap Done
5. Search again

The app is designed to automatically use mock data when no API key is present. This is perfect for testing!

---

## If Mock Data Isn't Showing:

Check `JumpseatFinderView.swift` line ~640:

```swift
catch let error as FlightScheduleError {
    // If no API key or error, use mock data for demo
    if case .noAPIKey = error {
        flights = FlightScheduleService.shared.getMockFlights(from: from, to: to)
        hasSearched = true
    } else {
        throw error  // ← This might be throwing before mock data loads
    }
}
```

**Better error handling:**
```swift
catch let error as FlightScheduleError {
    // Always use mock data on any API error during testing
    flights = FlightScheduleService.shared.getMockFlights(from: from, to: to)
    hasSearched = true
    print("⚠️ API error, using mock data: \(error)")
}
```

---

## Status Check:

After rebuild, test these scenarios:

| Scenario | Expected Result |
|----------|----------------|
| Empty API key | ✅ Shows 3 mock flights |
| Invalid API key | ❓ Shows error OR mock data |
| Valid API key | ✅ Shows real flights |
| No internet | ❓ Shows error OR mock data |

---

Let me know what error message you see after the rebuild and I'll help debug it!

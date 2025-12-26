# 🔧 Fix: App Transport Security Error

## Problem

You're seeing this error:
```
Network Error: The resource could not be loaded...
App Transport Security Policy requires secure connection
```

## Root Cause

**AviationStack's free API uses HTTP (not HTTPS):**
```swift
// FlightScheduleService.swift - Line 73
private let baseURL = "http://api.aviationstack.com/v1"  // ❌ HTTP (insecure)
```

iOS blocks insecure HTTP connections by default for security.

---

## Solution 1: Allow HTTP for AviationStack (Recommended for Development)

### Step 1: Open Info.plist

1. In Xcode, expand your project in the navigator
2. Find `Info.plist` (usually in the root or in a folder with your app name)
3. Right-click → Open As → **Source Code**

### Step 2: Add Exception for AviationStack

Add this XML **inside** the `<dict>` tag (usually right before `</dict>`):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.aviationstack.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Step 3: Complete Info.plist Example

Your Info.plist should look like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys here -->
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleDisplayName</key>
    <string>ProPilot</string>
    
    <!-- ADD THIS SECTION ⬇️ -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.aviationstack.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
    <!-- END NEW SECTION ⬆️ -->
    
    <!-- Rest of your existing keys -->
</dict>
</plist>
```

### Step 4: Clean Build

1. Product → Clean Build Folder (⌘⇧K)
2. Build (⌘B)
3. Run (⌘R)

---

## Solution 2: Use HTTPS Instead (Requires Paid Plan)

AviationStack's **paid plans** ($50+/month) offer HTTPS endpoints.

If you upgrade, change the URL:

```swift
// FlightScheduleService.swift
private let baseURL = "https://api.aviationstack.com/v1"  // ✅ HTTPS (secure)
```

Then you won't need the Info.plist exception.

---

## Solution 3: Proxy Through Your Backend (Production Approach)

For production, use a secure backend that calls AviationStack for you:

```
User App (HTTPS) → Your Server (HTTPS) → AviationStack (HTTP)
```

**Your server** handles the insecure connection, exposing only HTTPS to users.

### Example Backend (Node.js)

```javascript
// server.js
const express = require('express');
const fetch = require('node-fetch');
const app = express();

app.get('/api/flights', async (req, res) => {
    const { from, to, date } = req.query;
    
    // Call AviationStack (HTTP is fine on server)
    const response = await fetch(
        `http://api.aviationstack.com/v1/flights?access_key=${API_KEY}&dep_iata=${from}&arr_iata=${to}`
    );
    
    const data = await response.json();
    res.json(data);  // Return as HTTPS to app
});

app.listen(3000);
```

### Update App to Use Your Backend

```swift
// FlightScheduleService.swift
private let baseURL = "https://your-api.yourapp.com/api"  // ✅ Your HTTPS server
```

---

## Security Considerations

### ⚠️ Important Notes:

1. **Development:** It's OK to allow HTTP for testing
2. **Production:** Apple may reject your app if you allow HTTP unnecessarily
3. **Best Practice:** Use HTTPS or proxy through your backend

### App Store Review

Apple will ask **why** you need HTTP exceptions. Valid reasons:
- ✅ "Third-party API only offers HTTP on free tier"
- ✅ "Upgrading to HTTPS in production version"
- ❌ "We forgot to use HTTPS" (will be rejected)

---

## Recommended Approach

### For Now (Testing):
✅ Use **Solution 1** (Info.plist exception)
- Allows you to test the API immediately
- No cost
- Works with free AviationStack tier

### For Beta:
🔄 Consider **Solution 2** (Paid AviationStack)
- Upgrade to $50/month plan
- Change URL to HTTPS
- Remove Info.plist exception

### For Production:
🚀 Use **Solution 3** (Your Backend)
- Most secure
- Hides your API key
- Validates subscriptions server-side
- Costs ~$5/month (AWS Lambda)

---

## Quick Copy-Paste Fix

### If Using Property List View in Xcode:

1. Open `Info.plist`
2. Right-click in the list → **Add Row**
3. Key: `App Transport Security Settings`
4. Type: Dictionary
5. Expand it → Right-click → **Add Row**
6. Key: `Exception Domains`
7. Type: Dictionary
8. Expand it → Right-click → **Add Row**
9. Key: `api.aviationstack.com`
10. Type: Dictionary
11. Expand it → Right-click → **Add Row**
12. Key: `Allow Arbitrary Loads`
13. Type: Boolean
14. Value: **YES**

---

## Visual Guide

### Before (Error):
```
App → http://api.aviationstack.com ❌ BLOCKED by iOS
```

### After (Working):
```
App → http://api.aviationstack.com ✅ ALLOWED (Info.plist exception)
```

### Production (Best):
```
App → https://your-server.com → http://api.aviationstack.com ✅ SECURE
```

---

## Testing the Fix

### 1. Add Info.plist exception (see above)
### 2. Add your API key:

```swift
// In Jumpseat Finder → Settings
Paste your AviationStack API key
```

### 3. Search for flights:

```
From: KMEM
To: KATL
Date: Today
```

### Expected Result:
✅ **Real flights displayed** (not mock data)
✅ **No network error**

### If Still Getting Errors:

Check the API key is valid:
```bash
# Test in browser:
http://api.aviationstack.com/v1/flights?access_key=YOUR_KEY&dep_iata=MEM&arr_iata=ATL

# Should return JSON with flights
```

---

## Alternative: Stick with Mock Data

If you're not ready to deal with API keys and HTTP exceptions, you can **keep using mock data**:

### Current Behavior:
```swift
// JumpseatFinderView.swift - Line 642
catch let error as FlightScheduleError {
    if case .noAPIKey = error {
        flights = FlightScheduleService.shared.getMockFlights(from: from, to: to)
        hasSearched = true
    }
}
```

**Mock data is automatically used when:**
- ❌ No API key configured
- ❌ API returns an error
- ✅ Perfect for development/testing

To force mock data:
```swift
// FlightScheduleService.swift
private let apiKey = ""  // Leave empty = always use mock data
```

---

## Summary

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Info.plist Exception** | ✅ Quick<br>✅ Free<br>✅ Works immediately | ⚠️ Insecure<br>⚠️ App Store scrutiny | Development/Testing |
| **Paid HTTPS API** | ✅ Secure<br>✅ Simple | ❌ $50/month | Beta/Small production |
| **Your Backend Proxy** | ✅ Most secure<br>✅ Hides API key<br>✅ Control costs | ❌ More complex<br>❌ Requires server | Production |
| **Mock Data Only** | ✅ Free<br>✅ No setup | ❌ Not real data | Development only |

---

## Recommended Action: Use Info.plist Exception Now

**Copy this XML and add it to your Info.plist:**

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.aviationstack.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

Then rebuild and test! 🚀

# Jumpseat Finder Integration Guide

## Overview

The **Jumpseat Finder** feature has been successfully integrated into TheProPilotApp. This feature helps professional pilots find commute flights between airports using real-time flight schedule data.

## ✅ What's Been Integrated

### 1. **FlightScheduleService.swift** - API Backend
- **AviationStack API integration** (free tier: 100 requests/month)
- Flight schedule search between two airports
- ICAO to IATA code conversion
- Mock data support for testing without API key
- Error handling for rate limits and API errors

### 2. **JumpseatFinderView.swift** - User Interface
- Clean search form (From/To airports + Date)
- Real-time flight results with:
  - Airline & flight number
  - Departure/arrival times (Zulu format)
  - Gate & terminal information
  - Aircraft type
  - Flight status (scheduled, active, landed, cancelled)
- Flight detail view with pro tips
- Settings panel for API key configuration

### 3. **Tab Integration**
- Added to the "More" panel under **Jumpseat Network** section
- Accessible from: More → Jumpseat Finder
- Icon: `person.2.fill` (cyan color)
- ID: `"jumpseat"`

## 🚀 How to Use

### For Users:
1. Open the app and go to **More** → **Jumpseat Finder**
2. Enter departure airport (e.g., `KMEM` or `MEM`)
3. Enter arrival airport (e.g., `KATL` or `ATL`)
4. Select date (defaults to today)
5. Tap **Search Flights**
6. Browse results and tap any flight for details

### For Development:

#### **Getting an API Key (Free)**
1. Visit [aviationstack.com/signup/free](https://aviationstack.com/signup/free)
2. Sign up for a free account
3. Copy your **access key** from the dashboard
4. In the app, go to **Jumpseat Finder** → **Settings** (gear icon)
5. Paste your API key

#### **Testing Without API Key**
The app includes **mock data** that automatically activates when:
- No API key is configured
- API returns an error
- You're testing locally

## 📋 File Structure

```
TheProPilotApp/
├── FlightScheduleService.swift    # API service (AviationStack)
├── JumpseatFinderView.swift       # UI views
├── TabManager.swift                # Updated with jumpseat tab
├── ContentView.swift               # Updated router for jumpseat case
└── AreaGuideView.swift             # Existing (unchanged)
```

## 🔧 Configuration

### API Key Storage
- Stored in `@AppStorage("aviationStackAPIKey")`
- Secure field in settings
- Never hardcoded in source files

### API Endpoints Used
```
GET http://api.aviationstack.com/v1/flights
Parameters:
- access_key: YOUR_API_KEY
- dep_iata: DepartureCode
- arr_iata: ArrivalCode
- flight_date: YYYY-MM-DD
```

## 🎯 Features Implemented (Phase 1)

### ✅ Completed:
- [x] Flight schedule search (origin → destination)
- [x] Real-time flight times
- [x] Airline information
- [x] Gate & terminal display
- [x] Aircraft type
- [x] Flight status tracking
- [x] Date selection
- [x] Mock data for testing
- [x] API key configuration
- [x] Error handling
- [x] Beautiful dark UI matching LogbookTheme

### 🔜 Future Enhancements (Phase 2):
- [ ] **Load Predictor** - Estimate seat availability based on booking class
- [ ] **Crowdsourced loads** - Let pilots report actual loads
- [ ] **Push notifications** - Alert when flights open up
- [ ] **Saved routes** - Quick access to frequent commutes
- [ ] **Calendar integration** - Sync with duty schedule
- [ ] **Multiple airlines filter** - Show only specific carriers

## 💰 Cost Analysis (As per your document)

### Free Tier:
- **100 requests/month** = ~3 searches per day
- **Cost:** $0
- **Perfect for:** Light users testing the feature

### Paid Plan:
- **$50/month** = 10,000 requests
- **Supports:** ~160 active daily users (60 searches/month each)
- **Revenue potential:** $4.99/month × 160 users = **$798/month**
- **Profit margin:** $628/month after API costs

### Security Note:
⚠️ **Never hardcode API keys in the app code!**
- Use `@AppStorage` for user-entered keys
- For production, implement a **proxy backend** (Firebase Functions / AWS Lambda)
- Validate subscriptions before making API calls

## 🧪 Testing Checklist

### Test Cases:
1. **Search with valid airports:**
   - Input: `KMEM` → `KATL`
   - Expected: List of flights displayed

2. **Search with IATA codes:**
   - Input: `MEM` → `ATL`
   - Expected: Automatic conversion to IATA, results displayed

3. **Search with invalid airport:**
   - Input: `XXXX` → `YYYY`
   - Expected: "No flights found" message

4. **Search without API key:**
   - Expected: Mock flights displayed (Demo mode)

5. **Tap flight card:**
   - Expected: Navigate to detailed view with times, gates, pro tips

6. **Swap airports:**
   - Expected: From/To fields switch values

7. **Change date:**
   - Expected: Search updates to new date

## 🎨 UI Components

### Theme Colors (LogbookTheme):
- **Navy:** `#0C0F1E` - Main background
- **Navy Light:** `#1A1E2E` - Cards
- **Navy Dark:** `#05070F` - Sidebar
- **Accent Blue:** `#4A9FFF` - Primary actions
- **Accent Green:** `#4CAF50` - Success states
- **Field Background:** `rgba(255,255,255,0.05)` - Input fields

### Custom Components:
- `JumpseatTextFieldStyle` - Monospaced, large text fields
- `FlightResultCard` - Main flight display card
- `FlightDetailView` - Full-screen flight details
- `JumpseatSettingsView` - API key configuration

## 📱 Screenshots Concepts

### Search View:
```
┌─────────────────────────────┐
│ 🛫 Find Your Commute        │
│ Search for available flights│
├─────────────────────────────┤
│ From: KMEM                  │
│ ⇅                           │
│ To: KATL                    │
│ Date: Dec 16, 2025          │
│ [Search Flights]            │
└─────────────────────────────┘
```

### Results View:
```
┌─────────────────────────────┐
│ 3 Flights Found             │
├─────────────────────────────┤
│ Delta Air Lines  [SCHEDULED]│
│ DL1234                      │
│                             │
│ KMEM       →       KATL     │
│ 1400Z              1700Z    │
│                             │
│ B738 • Gate A12 • Term A    │
│ ● Likely Available          │
└─────────────────────────────┘
```

## 🐛 Known Issues / Limitations

1. **AviationStack API limitations:**
   - Only returns scheduled flights (not all carriers report to them)
   - No real-time load information
   - May have delays in updates

2. **Phase 1 Limitations:**
   - No seat/load availability data (Phase 2 feature)
   - No flight tracking (requires FlightAware integration)
   - No offline mode (requires local caching)

## 📚 Related Documentation

- **airportInfo.txt** - Original requirements document
- **AreaGuideView.swift** - Related feature (airport reviews)
- **TabManager.swift** - Tab navigation system
- **LogbookTheme** - App-wide design system

## 🔗 External Resources

- [AviationStack API Docs](https://aviationstack.com/documentation)
- [FlightAware AeroAPI](https://www.flightaware.com/commercial/aeroapi/) - Alternative API
- [PassRider](https://passrider.com) - Competitor reference

## ✅ Integration Checklist

- [x] Created FlightScheduleService.swift
- [x] Created JumpseatFinderView.swift
- [x] Updated TabManager.swift with jumpseat tab
- [x] Updated ContentView.swift with jumpseat case
- [x] Added icon color mapping
- [x] Implemented mock data for testing
- [x] Added settings view for API key
- [x] Implemented error handling
- [x] Dark theme integration complete

## 🎉 Ready to Test!

The Jumpseat Finder is now fully integrated and ready for testing. Users can:
1. Access it from the More panel
2. Search flights without API key (mock mode)
3. Configure API key in settings for real data
4. View detailed flight information
5. Plan their commutes efficiently

**Next Steps:**
1. Test the feature end-to-end
2. Sign up for AviationStack API (free tier)
3. Add API key in settings
4. Search real flights!

---

**Note:** This feature is designed as a **freemium** offering:
- **Free tier:** Basic logbook access
- **Pro tier ($2.99-$4.99/month):** Jumpseat Finder, Live Tracking, Sync, etc.

Implement subscription checks before calling the API in production!

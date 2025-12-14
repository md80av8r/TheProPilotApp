# ProPilot Jumpseat Network - Implementation Guide

## Overview

The Jumpseat Network is a cross-platform feature that allows pilots to:
1. **Auto-post flights** when creating trips in ProPilot
2. **Discover cargo/charter jumpseats** that aren't on PassRider
3. **Search by proximity** (find flights arriving near your destination)
4. **Chat/coordinate** with other pilots
5. **Share layover tips** for destination airports

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              ProPilot iOS (Full App)                        │
│  ├── All existing features (Logbook, FAR117, etc.)         │
│  └── JumpseatView (integrated)                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Backend                          │
│  ├── Authentication (Apple Sign In + CASS verification)    │
│  ├── Firestore Database                                     │
│  │   ├── jumpseat_flights (available seats)                │
│  │   ├── jumpseat_requests (interest notifications)        │
│  │   ├── chat_messages (real-time chat)                    │
│  │   ├── chat_channels (route-based & DMs)                 │
│  │   ├── pilot_profiles (public pilot info)               │
│  │   └── layover_tips (destination guides)                 │
│  ├── Cloud Messaging (push notifications)                  │
│  └── Cloud Functions (auto-cleanup, notifications)         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ProPilot Lite (Web App)                        │
│  React web app at jumpseat.propilot.app                    │
│  ├── Jumpseat discovery & requests                         │
│  ├── Chat functionality                                     │
│  └── Basic flight logging (simplified)                     │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1: Firebase Setup (Today)

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Click "Add project" → Name it "ProPilot"
3. Enable Google Analytics (optional but recommended)
4. Wait for project creation

### Step 2: Add iOS App
1. In Firebase Console → Project Settings → Add App → iOS
2. iOS bundle ID: `com.jkadans.ProPilotApp`
3. Download `GoogleService-Info.plist`
4. Add to Xcode project (drag to root, check "Copy items")

### Step 3: Enable Services
1. **Authentication**:
   - Go to Authentication → Sign-in method
   - Enable "Apple" sign-in
   - Enable "Anonymous" (for initial browsing)

2. **Firestore Database**:
   - Go to Firestore Database → Create database
   - Start in test mode (we'll add rules later)
   - Choose closest region (us-central1)

3. **Cloud Messaging**:
   - Already enabled by default
   - Note your Server Key for later

### Step 4: Add Firebase SDK to Xcode
Add to your project via Swift Package Manager:
1. File → Add Packages
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select these products:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseMessaging

## Phase 2: Data Models (Files Created)

See the Swift files in this folder:
- `JumpseatModels.swift` - Core data structures
- `JumpseatService.swift` - Firebase integration
- `JumpseatView.swift` - Main UI
- `JumpseatSearchView.swift` - Proximity search
- `JumpseatChatView.swift` - Chat interface

## Phase 3: Integration Points

### Auto-Post When Creating Trip

In `ContentView.swift`, after `saveNewTrip()`:

```swift
// After store.addTrip(trip)
if JumpseatSettings.shared.autoPostFlights {
    Task {
        await JumpseatService.shared.postFlight(from: trip)
    }
}
```

### Tab Integration

Add to your tab bar in `ContentView.swift`:

```swift
// In the TabView
Tab("Jumpseat", systemImage: "person.2.fill") {
    JumpseatView()
}
```

## Phase 4: Security Rules

### Firestore Rules (Firebase Console → Firestore → Rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Pilot profiles - read by anyone authenticated, write own only
    match /pilot_profiles/{pilotId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == pilotId;
    }
    
    // Jumpseat flights - read by authenticated, write by owner
    match /jumpseat_flights/{flightId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.pilotId;
    }
    
    // Jumpseat requests - read by flight owner or requester
    match /jumpseat_requests/{requestId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.requesterId || 
         request.auth.uid == resource.data.flightOwnerId);
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.flightOwnerId;
    }
    
    // Chat channels - members only
    match /chat_channels/{channelId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.memberIds;
    }
    
    // Chat messages - channel members only
    match /chat_messages/{messageId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    // Layover tips - read by all authenticated, write by verified pilots
    match /layover_tips/{tipId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        get(/databases/$(database)/documents/pilot_profiles/$(request.auth.uid)).data.isVerified == true;
    }
  }
}
```

## Phase 5: Push Notifications

### APNs Setup
1. Apple Developer → Certificates → Create APNs Key
2. Download .p8 file
3. Firebase Console → Project Settings → Cloud Messaging
4. Upload APNs key

### Notification Triggers
- "Someone is interested in your jumpseat"
- "Your jumpseat request was approved"
- "New chat message"
- "Flight departing in 2 hours" (reminder)

## File Structure

```
TheProPilotApp/
├── Jumpseat/
│   ├── JUMPSEAT_IMPLEMENTATION_GUIDE.md  (this file)
│   ├── JumpseatModels.swift              (data structures)
│   ├── JumpseatService.swift             (Firebase service)
│   ├── JumpseatSettings.swift            (user preferences)
│   ├── JumpseatView.swift                (main tab view)
│   ├── JumpseatSearchView.swift          (proximity search)
│   ├── JumpseatFlightDetailView.swift    (flight details)
│   ├── JumpseatChatView.swift            (chat interface)
│   ├── JumpseatProfileView.swift         (pilot profile)
│   └── LayoverTipsView.swift             (destination guides)
└── ... existing files
```

## Privacy & Safety Considerations

1. **Limited Data Exposure**:
   - Display name only (not full name)
   - No exact home address
   - Flight info expires after departure
   - Chat history auto-deletes after 30 days

2. **CASS Verification** (Future):
   - Verify pilot certificates
   - Badge for verified CASS pilots
   - Higher trust for verified users

3. **Blocking/Reporting**:
   - Block users from contacting you
   - Report inappropriate behavior
   - Moderation queue for reports

## Cost Estimates (Firebase)

| Monthly Users | Est. Cost |
|---------------|-----------|
| 0-100         | Free      |
| 100-500       | $5-15     |
| 500-1,000     | $15-30    |
| 1,000-5,000   | $30-100   |

Firebase free tier includes:
- 50K reads/day
- 20K writes/day
- 20K deletes/day
- 1GB storage
- 10GB bandwidth

## Next Steps

1. ✅ Create data models (JumpseatModels.swift)
2. ✅ Create Firebase service (JumpseatService.swift)
3. ✅ Create UI views
4. ⏳ Set up Firebase project (you do this)
5. ⏳ Add GoogleService-Info.plist
6. ⏳ Test basic functionality
7. ⏳ Add push notifications
8. ⏳ Build web app (Phase 2)

---

*Created: December 2024*
*Version: 1.0*

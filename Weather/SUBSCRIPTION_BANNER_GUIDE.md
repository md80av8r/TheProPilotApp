# Subscription Banner Integration Guide

## Overview
The `SubscriptionPromptBanner` provides multiple UI components to guide users toward subscribing when they hit trial limits.

## Components Available

### 1. **SubscriptionPromptBanner** (Full Banner)
A prominent banner that appears at the top of views when trial is exceeded.

**Features:**
- Shows appropriate icon and message based on trial status
- Two action buttons: "Subscribe to Pro" and "Learn More"
- Dismissible with X button
- Auto-opens PaywallView when buttons are tapped
- Gradient background with dynamic colors

**Usage:**
```swift
import SwiftUI

struct TripsView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Banner appears here automatically when trial exceeded
            SubscriptionPromptBanner()
            
            // Your existing content
            List {
                // trips...
            }
        }
    }
}
```

**Or use the view modifier:**
```swift
struct TripsView: View {
    var body: some View {
        List {
            // trips...
        }
        .withSubscriptionBanner() // Adds banner at top
    }
}
```

### 2. **CompactSubscriptionPromptBanner** (Small Badge)
A compact button-style banner for navigation bars or toolbars.

**Usage:**
```swift
struct SomeView: View {
    var body: some View {
        NavigationView {
            List {
                // content...
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CompactSubscriptionPromptBanner()
                }
            }
        }
    }
}
```

### 3. **TrialWarningBanner** (Early Warning)
Shows when trial is about to end (1 trip or 1 day remaining).

**Usage:**
```swift
struct TripsView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Warning appears when close to limit
            TrialWarningBanner()
            
            // Your content
            List {
                // trips...
            }
        }
    }
}
```

## Recommended Integration Points

### Main Trips View (Primary Location)
```swift
struct TripsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Full banner when trial exceeded
                SubscriptionPromptBanner()
                
                // Warning banner when close to limit
                TrialWarningBanner()
                
                // Trip list
                List {
                    // Your trips...
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Compact badge alternative
                    CompactSubscriptionPromptBanner()
                }
            }
        }
    }
}
```

### Flight Logging View
```swift
struct FlightLogView: View {
    @ObservedObject var trialChecker = SubscriptionStatusChecker.shared
    
    var body: some View {
        Form {
            // If trial exceeded, show banner at top
            if trialChecker.shouldShowPaywall {
                Section {
                    SubscriptionPromptBanner()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Rest of form...
        }
    }
}
```

### Tab Bar / Main View
```swift
struct ContentView: View {
    var body: some View {
        TabView {
            TripsView()
                .tabItem {
                    Label("Trips", systemImage: "airplane")
                }
            
            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book")
                }
        }
        .withSubscriptionBanner() // Shows banner across entire tab view
    }
}
```

## Customization Options

### Custom Banner Colors
```swift
// Modify bannerBackgroundColor in SubscriptionPromptBanner.swift
private var bannerBackgroundColor: Color {
    switch trialChecker.trialStatus {
    case .tripsExhausted:
        return Color.blue // Change to your brand color
    case .timeExpired:
        return Color.purple // Change to your brand color
    default:
        return Color.orange
    }
}
```

### Custom Messages
```swift
// Modify bannerMessage in SubscriptionPromptBanner.swift
private var bannerMessage: String {
    switch trialChecker.trialStatus {
    case .tripsExhausted:
        return "Your custom message here"
    case .timeExpired:
        return "Your custom message here"
    default:
        return "Subscribe to unlock all features"
    }
}
```

## Testing

### Test Banner Appearance
```swift
#if DEBUG
// In your preview or test view:
SubscriptionStatusChecker.shared.resetTrial()

// Simulate trip limit reached:
for _ in 0..<5 {
    SubscriptionStatusChecker.shared.incrementTripCount()
}

// Banner should now appear
#endif
```

### Preview All States
```swift
#Preview("Trial Active - Warning") {
    // Set trips remaining to 1
    TrialWarningBanner()
}

#Preview("Trial Exceeded - Trips") {
    // Set trips to 5
    SubscriptionPromptBanner()
}

#Preview("Trial Exceeded - Time") {
    // Set days to 7+
    SubscriptionPromptBanner()
}
```

## User Flow

### 1. Trial Active (0-4 trips, 0-6 days)
- ✅ No banners shown
- User can create trips normally

### 2. Trial Warning (4 trips or 6 days)
- ⚠️ **TrialWarningBanner** appears
- Shows "1 trip remaining" or "1 day remaining"
- User can still create trips
- Can dismiss warning temporarily

### 3. Trial Exceeded (5+ trips or 7+ days)
- 🚫 **SubscriptionPromptBanner** appears
- Shows "Free Trial Limit Reached" or "Free Trial Expired"
- User cannot create new trips
- "Subscribe to Pro" button opens PaywallView
- "Learn More" button also opens PaywallView
- Can dismiss banner, but it reappears on next launch

### 4. Subscribed
- ✅ No banners shown
- All features unlocked

## Implementation Checklist

- [ ] Add `SubscriptionPromptBanner.swift` to project
- [ ] Add full banner to main TripsView
- [ ] Add compact banner to navigation bar (optional)
- [ ] Add trial warning banner before limit (recommended)
- [ ] Test banner appearance when trial exceeded
- [ ] Test "Subscribe to Pro" button opens PaywallView
- [ ] Test banner dismissal works
- [ ] Test banner reappears after dismissal on next launch
- [ ] Verify banner doesn't show when subscribed
- [ ] Customize colors/messages to match brand

## Additional Features

### Persistent Reminder
The banner automatically reappears even if dismissed because:
- `isDismissed` is a `@State` variable (resets on view recreation)
- Trial checker continuously monitors status
- Banner only hides when user subscribes

### Auto-Hide After Subscribe
The banner automatically hides when:
```swift
if trialChecker.shouldShowPaywall && !isDismissed {
    // shouldShowPaywall returns false when subscribed
    // Banner won't render
}
```

### Deep Link to PaywallView
You can also programmatically show the paywall:
```swift
@State private var showPaywall = false

Button("Upgrade Now") {
    showPaywall = true
}
.sheet(isPresented: $showPaywall) {
    PaywallView()
}
```

## Troubleshooting

### Banner not showing?
1. Check trial status: `SubscriptionStatusChecker.shared.trialStatus`
2. Verify trip count: `SubscriptionStatusChecker.shared.totalTripsCreated`
3. Check subscription status: `SubscriptionManager.shared.isSubscribed`

### Banner showing when it shouldn't?
1. Verify user has active subscription
2. Check `shouldShowPaywall` property
3. Ensure subscription check is updating

### PaywallView not opening?
1. Verify `showPaywall` state is toggling
2. Check sheet presentation is properly configured
3. Ensure PaywallView is imported

## Support

For additional help:
- Check `SubscriptionStatusChecker.swift` for trial logic
- Check `PaywallView.swift` for subscription UI
- Check `SubscriptionManager.swift` for StoreKit integration

# Quick Start: Using Duty Time Integration

## For Developers: Adding UI Components

### 1. Show Live Duty Timer in Active Trip Detail

```swift
import SwiftUI

struct TripDetailView: View {
    @Binding var trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ... other trip details ...
                
                // Show live duty timer if trip is active
                if trip.status == .active {
                    LiveDutyTimerDisplay(trip: trip)
                }
                
                // ... more trip details ...
            }
            .padding()
        }
    }
}
```

### 2. Show Duty Summary for Completed Trips

```swift
import SwiftUI

struct CompletedTripView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ... flight details ...
                
                // Show duty time summary
                CompletedDutyTimeSummary(trip: trip)
                
                // ... other summaries ...
            }
            .padding()
        }
    }
}
```

### 3. Allow Manual Duty Time Editing

```swift
import SwiftUI

struct TripEditView: View {
    @Binding var trip: Trip
    
    var body: some View {
        Form {
            // ... other fields ...
            
            Section(header: Text("Duty Time")) {
                DutyStartTimeEditor(trip: $trip)
            }
            
            // ... more fields ...
        }
    }
}
```

### 4. Manual Duty Timer Control

If you want to add manual start/stop buttons:

```swift
struct ManualDutyTimerControls: View {
    @ObservedObject var dutyManager = DutyTimerManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            if dutyManager.isOnDuty {
                // Show timer is active
                VStack {
                    Text("ON DUTY")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text(dutyManager.formattedElapsedTime())
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Button("End Duty") {
                    dutyManager.endDuty()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button("Start Duty") {
                    dutyManager.startDuty()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}
```

## For Pilots: How to Use

### Automatic Mode (Recommended)

1. **Create a trip** with status "Active"
2. **Duty timer starts automatically** when:
   - Trip becomes active, OR
   - You record first OUT time
3. **Timer runs in background** with these features:
   - ⏰ Updates every second
   - 🔔 Warns at 14h, 15h, 15.5h, 16h
   - ⌚ Syncs to Apple Watch
   - 📱 Updates home screen widget
4. **Complete the trip** → Duty time auto-saved!

### Manual Override

If automatic duty start didn't match your actual duty start:

1. Open the **completed trip**
2. Tap **"Duty Start Time"** section
3. Choose from presets or use time picker:
   - `-2h` = 2 hours before first OUT
   - `-1.5h` = 90 minutes before
   - `-1h` = 60 minutes before (default)
   - `-45m` = 45 minutes before
   - Or pick exact time
4. Tap **"Save"**
5. FDP calculations automatically update!

### Reset to Auto-Calculation

Changed your mind about manual time?

1. Open trip with manual duty time
2. Look for **orange "Manually set"** label
3. Tap **"Auto"** button
4. System recalculates from flight times

## Troubleshooting

### "No active duty timer" message

**Why:** Duty timer wasn't running during this trip

**Solution:** 
- Trip will use auto-calculated times (first OUT - 1h)
- You can manually edit if needed
- This is normal for imported/past trips

### Duty time seems wrong

**Check:**
1. Were your flight times entered correctly?
2. Did you start duty earlier than 1 hour before first OUT?
3. If so, manually edit the duty start time

**Auto-calculation logic:**
- Start: First OUT time - 60 minutes
- End: Last IN time + 15 minutes

### Want to pre-start duty timer

If you report to duty before creating the trip:

1. Create trip as "Active"
2. Timer starts immediately
3. Add flight legs later
4. When you complete trip, all times captured correctly

### FDP calculations not updating

**After changing duty times:**
- LogBook should recalculate automatically
- If not, try:
  1. Pull to refresh logbook view
  2. Restart app
  3. Check DutyLimitSettings are enabled

## Pro Tips

💡 **Create trip early:** Create your trip as "Active" when you report for duty, even if you don't know all legs yet

💡 **Trust the defaults:** The 1-hour pre-duty buffer is FAA standard for Part 121

💡 **Edit later:** You can always adjust duty times after completing a trip

💡 **Watch integration:** Duty timer syncs to Apple Watch - check it anytime!

💡 **Widget:** Add the duty timer widget to home screen for quick glance

## Keyboard Shortcuts (iPad)

When editing duty time:
- `⌘S` - Save changes
- `⌘Z` - Undo (revert to auto)
- `ESC` - Cancel editing

## Accessibility

- VoiceOver fully supported
- Dynamic Type respected
- High contrast mode compatible
- Haptic feedback on warnings

---

**Questions?** Check `DUTY_TIMER_TRIP_INTEGRATION.md` for technical details.

# GPX Testing - Leg Advancement Issue Fix

## **Problem Description**

When testing multi-leg trips with GPX playback:
- ✅ Leg 1 OFF time captured automatically
- ✅ Leg 1 ON time captured automatically  
- ❌ **After landing, Leg 2 shows "On Standby" instead of becoming active**
- ❌ User must manually switch to Leg 2

## **Root Cause**

The auto-time system captures flight times correctly, but **does not automatically advance to the next leg** when a leg is complete. The UI logic expects the user to:

1. Manually review the completed leg
2. Tap a "Complete Leg" or "Next Leg" button
3. Then begin the next leg

This works fine for **real flights** where there's time between legs, but breaks **GPX testing** where legs happen in rapid succession.

## **Solution Implemented**

### **1. Added Auto-Advancement Notification**

In `GPXTestIntegration.swift`, when ON time is captured:

```swift
if timeType == "ON" {
    landingDetected = true
    lastEventMessage = "🛬 ON Time at \(Int(speedKts)) kts"
    
    // AUTO-ADVANCE TO NEXT LEG after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        print("🔄 Auto-checking leg completion after ON time")
        self.checkAndAdvanceToNextLeg()
    }
}
```

### **2. Added Helper Method**

```swift
private func checkAndAdvanceToNextLeg() {
    NotificationCenter.default.post(
        name: Notification.Name("checkLegCompletion"),
        object: nil
    )
    print("🔄 Checking leg completion and advancing if needed")
}
```

### **3. Main App Must Listen for Notification**

Your main trip/leg management code needs to listen for `"checkLegCompletion"` and:

1. Check if the current leg has all 4 times (OUT, OFF, ON, IN)
2. If complete, automatically select the next leg
3. Update the UI to show the next leg as active

## **Implementation in Your Main App**

You'll need to add this observer where your trip/leg management happens (likely in `DataEntryView` or similar):

```swift
.onAppear {
    // Listen for auto-leg advancement from GPX testing
    NotificationCenter.default.addObserver(
        forName: Notification.Name("checkLegCompletion"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.autoAdvanceToNextLegIfComplete()
    }
}

private func autoAdvanceToNextLegIfComplete() {
    guard let trip = currentTrip else { return }
    
    // Find current leg index
    let currentLegIndex = trip.legs.firstIndex { leg in
        leg.inTime.isEmpty // First leg without IN time
    } ?? 0
    
    let currentLeg = trip.legs[currentLegIndex]
    
    // Check if leg is complete (has all 4 times)
    let isComplete = !currentLeg.outTime.isEmpty && 
                     !currentLeg.offTime.isEmpty && 
                     !currentLeg.onTime.isEmpty && 
                     !currentLeg.inTime.isEmpty
    
    if isComplete {
        // Advance to next leg
        if currentLegIndex + 1 < trip.legs.count {
            selectedLegIndex = currentLegIndex + 1
            print("✅ Auto-advanced to Leg \(selectedLegIndex + 1)")
            
            // Update UI state
            objectWillChange.send()
        } else {
            print("🏁 Trip complete - no more legs")
        }
    }
}
```

## **Alternative: Manual Workaround**

If you can't implement auto-advancement right now, you can manually advance legs during GPX testing:

### **During GPX Playback:**

1. **Watch for ON time** to be captured
2. **Manually tap the next leg** in your UI
3. **Continue playback** for the next leg

### **Using the "Clear Times" Button:**

The GPX testing interface has a "Clear All Flight Times" button - use this to:
- Reset all times for the current leg
- Re-run the same leg multiple times
- Test different scenarios

## **Why 3 Second Delay?**

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 3.0)
```

The 3-second delay ensures:
- ✅ ON time is fully saved to storage
- ✅ UI has time to update
- ✅ Any pending saves are completed
- ✅ User can see the ON time before advancing

You can adjust this to 1-2 seconds if needed for faster testing.

## **Testing the Fix**

### **Expected Behavior:**

1. Load a multi-leg GPX file (like DTW → CLE → DTW)
2. Start playback
3. Watch Leg 1:
   - OFF time captured at ~80 kts ✅
   - ON time captured at ~55 kts ✅
4. **After 3 seconds, Leg 2 should automatically become active** ✅
5. Leg 2 continues:
   - OFF time captured at ~80 kts ✅
   - ON time captured at ~55 kts ✅
6. Trip marked complete ✅

### **Debug Logging:**

Look for these console messages:

```
🛬 ON Time at 55 kts
🔄 Auto-checking leg completion after ON time
🔄 Checking leg completion and advancing if needed
✅ Auto-advanced to Leg 2
```

## **Summary**

The fix adds **automatic leg advancement** during GPX testing by:

1. ✅ Detecting when ON time is captured
2. ✅ Waiting 3 seconds for everything to save
3. ✅ Posting a `checkLegCompletion` notification
4. ✅ Your app checks if leg is complete
5. ✅ If complete, automatically select next leg

This makes GPX testing seamless for multi-leg trips! 🚀

## **Next Steps**

1. Add the `checkLegCompletion` observer to your trip management code
2. Implement the `autoAdvanceToNextLegIfComplete()` method
3. Test with a multi-leg GPX file
4. Verify legs advance automatically after landing

If you need help implementing the observer in your main app, let me know which file handles your leg selection UI!

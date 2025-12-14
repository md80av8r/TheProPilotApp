# GPX Testing - "Leg On Standby" Issue - Root Cause & Solution

## **Problem Summary**

After Leg 1 completes during GPX testing:
- ✅ Leg 1 has all 4 times (OUT, OFF, ON, IN)
- ✅ Leg 1 marked as complete
- ❌ **Leg 2 shows "On Standby" instead of Active**
- ❌ Auto-times for Leg 2 don't capture

## **Root Cause Analysis**

The system **already has automatic leg advancement logic** in `Trip.swift`:

```swift
mutating func checkAndAdvanceLeg(at index: Int) {
    // Check if leg is complete (has all 4 times)
    let isComplete = !leg.outTime.isEmpty && 
                     !leg.offTime.isEmpty && 
                     !leg.onTime.isEmpty && 
                     !leg.inTime.isEmpty
    
    // If complete and currently active, advance to next
    if isComplete && leg.status == .active {
        completeActiveLeg(activateNext: true)  // This should activate Leg 2
    }
}
```

This is being called from `LogBookStore.swift` after each auto-time capture.

### **Why It's Not Working:**

When you "Add Leg" manually after Leg 1 completes:

1. **Timing Issue**: Leg 1 might be marked complete **before** Leg 2 is added
2. **Status Not Initialized**: New leg is created with `.standby` status
3. **Auto-Advance Already Ran**: The `checkAndAdvanceLeg` ran when Leg 1 got its IN time, but Leg 2 didn't exist yet

## **The Workflow Problem**

### **What Should Happen:**
```
1. Create trip with 2 legs upfront
2. Both legs initialized: Leg 1 = .active, Leg 2 = .standby
3. Leg 1 completes → Auto-advance to Leg 2
4. Leg 2 becomes .active → Receives auto-times
```

### **What's Happening Instead:**
```
1. Create trip with 1 leg
2. Leg 1 = .active
3. Leg 1 completes → No Leg 2 to advance to
4. Manually add Leg 2 → Created with .standby status
5. Leg 2 stays .standby → Doesn't receive auto-times
```

## **Solution Options**

### **Option 1: Create All Legs Before Starting GPX Test** ⭐ **RECOMMENDED**

Before starting GPX playback:

1. **Add ALL legs** to your trip:
   ```
   - Leg 1: KDTW → KCLE
   - Leg 2: KCLE → KDTW
   ```

2. **Then start GPX playback**
   - Leg 1 will auto-complete
   - Leg 2 will auto-activate
   - All auto-times will work

### **Option 2: Manually Activate Leg After Adding**

When you add a new leg:

1. Add the leg
2. **Manually tap to activate it** (if your UI has this option)
3. Continue GPX playback

### **Option 3: Auto-Activate When Adding Leg** (Code Change Needed)

Modify your "Add Leg" logic to automatically activate the new leg if there's no active leg:

```swift
func addLeg(_ leg: FlightLeg, to tripIndex: Int) {
    trips[tripIndex].addLegToCurrentLogpage(leg)
    
    // If no active leg exists, activate this new leg
    if trips[tripIndex].activeLegIndex == nil {
        let newLegIndex = trips[tripIndex].legs.count - 1
        trips[tripIndex].activateLeg(at: newLegIndex)
        print("✅ Auto-activated new leg as no active leg existed")
    }
    
    save()
}
```

### **Option 4: Enhanced GPX Testing - Monitor Leg Status**

Update `GPXTestIntegration.swift` to display current active leg:

```swift
Section("Trip Status") {
    if let activeLegIndex = trip?.activeLegIndex {
        Label("Active Leg: \(activeLegIndex + 1)", systemImage: "checkmark.circle.fill")
            .foregroundColor(.green)
    } else if let nextStandbyIndex = trip?.nextStandbyLegIndex {
        Label("Next Leg on Standby: \(nextStandbyIndex + 1)", systemImage: "pause.circle")
            .foregroundColor(.orange)
    } else {
        Label("No active leg", systemImage: "exclamationmark.triangle")
            .foregroundColor(.red)
    }
}
```

## **Immediate Workaround for Testing**

For your current test session:

### **Method 1: Pre-Create Legs**
1. **Stop GPX playback**
2. **Add Leg 2** to your trip now (KCLE → KDTW)
3. **Tap Leg 2** to make it active (if your UI allows)
4. **Resume GPX playback** - it should now capture times for Leg 2

### **Method 2: Restart with All Legs**
1. **Clear current trip** (or create new one)
2. **Add both legs upfront**:
   - Leg 1: KDTW → KCLE
   - Leg 2: KCLE → KDTW
3. **Start GPX playback** - both legs will auto-advance properly

## **Check Current Leg Status**

Add this to your console to see what's happening:

```swift
print("🔍 Trip Status:")
print("   Active Leg Index: \(trip.activeLegIndex ?? -1)")
print("   Next Standby Index: \(trip.nextStandbyLegIndex ?? -1)")
print("   Leg Statuses: \(trip.legs.map { $0.status })")
```

## **Long-Term Fix**

The best solution is to modify your "Add Leg" functionality to:

1. **Check if there's currently an active leg**
2. **If NO active leg**, automatically activate the new leg
3. **If there IS an active leg**, add as standby (current behavior)

This ensures that:
- ✅ First leg added is always active
- ✅ Legs added during a trip stay on standby
- ✅ When a trip is complete, adding a new leg activates it

## **Testing Checklist**

- [ ] Create trip with **2 legs before** starting GPX
- [ ] Verify Leg 1 status = `.active`
- [ ] Verify Leg 2 status = `.standby`
- [ ] Start GPX playback
- [ ] Leg 1: OFF time captured at 80 kts
- [ ] Leg 1: ON time captured at 55 kts
- [ ] **Check console**: "✅ Completed leg 1"
- [ ] **Check console**: "✅ Activated leg 2"
- [ ] Leg 2: OFF time captured at 80 kts
- [ ] Leg 2: ON time captured at 55 kts
- [ ] Both legs complete!

## **Summary**

The issue isn't a bug in the auto-time logic - it's a **workflow timing issue**. The system needs both legs to exist BEFORE completing Leg 1. 

**Quick Fix**: Create all legs upfront before starting GPX testing.

**Long-Term Fix**: Enhance "Add Leg" to auto-activate when no active leg exists.

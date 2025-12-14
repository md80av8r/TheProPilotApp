# REST STATUS INTEGRATION - Implementation Guide

## ✅ Completed Steps

### 1. Created RestStatusManager.swift ✅
- Singleton class to track rest status
- Updates from NOC parsed events
- Caches rest status
- Provides formatted time strings

### 2. Added Rest Properties to ConfigurableLimitStatus ✅
In `DutyLimitSettings.swift`:
- `isInRest: Bool`
- `restEndTime: Date?`
- `formattedRestEnd: String?`
- `formattedRestEndZulu: String?`

## 🔧 Remaining Integration Points

### 3. Update calculateConfigurableLimits() 
**File:** `ForeFlightLogBookRow.swift` (around line 911)

**Add at the beginning of the function:**
```swift
let restManager = RestStatusManager.shared
restManager.refreshStatus()  // Update based on current time

if restManager.isInRest {
    status.isInRest = true
    status.restEndTime = restManager.restEndTime
    status.currentFDPFlightTime = 0  // Zero out FDP when in rest
}
```

### 4. Hook Up NOC Parsing
**File:** Wherever `ICalFlightParser.parseCalendarString()` is called

**After parsing, add:**
```swift
let (flights, events) = ICalFlightParser.parseCalendarString(content)

// ADD THIS LINE:
RestStatusManager.shared.updateFromNOCEvents(events, flights: flights)
```

**Likely locations:**
- `NOCSettingsStore.swift` - in fetchRosterCalendar() success handler
- `ICalDiagnosticView.swift` - in parseICalData()

### 5. Add REST Badge to UI
**File:** `ForeFlightLogBookRow.swift` in `ConfigurableLimitsStatusView`

**In `headerContent` (around line 1176):**
```swift
// After operation type badge, add:
if currentStatus.isInRest {
    HStack(spacing: 4) {
        Image(systemName: "moon.zzz.fill")
            .font(.caption2)
        Text("REST")
            .font(.caption2.bold())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.blue.opacity(0.3))
    .foregroundColor(.blue)
    .cornerRadius(4)
}
```

### 6. Add Rest Banner to expandedContent
**File:** `ForeFlightLogBookRow.swift`

**In `expandedContent`, after the Divider:**
```swift
// REST STATUS BANNER (if in rest)
if currentStatus.isInRest {
    restStatusBanner
}
```

**Then add this new computed property:**
```swift
private var restStatusBanner: some View {
    HStack {
        Image(systemName: "moon.zzz.fill")
            .font(.title2)
            .foregroundColor(.blue)
        
        VStack(alignment: .leading, spacing: 2) {
            Text("Currently In Rest")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            
            if let endTime = currentStatus.formattedRestEnd,
               let endTimeZulu = currentStatus.formattedRestEndZulu {
                Text("Until \(endTime) (\(endTimeZulu))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        
        Spacer()
        
        // Countdown to rest end
        if let restEnd = currentStatus.restEndTime {
            RestCountdownView(endTime: restEnd)
        }
    }
    .padding()
    .background(Color.blue.opacity(0.15))
    .cornerRadius(8)
    .padding(.horizontal, 8)
    .padding(.top, 8)
}
```

### 7. Create RestCountdownView
**File:** `ForeFlightLogBookRow.swift` or create `RestCountdownView.swift`

```swift
struct RestCountdownView: View {
    let endTime: Date
    @State private var timeRemaining: TimeInterval = 0
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formattedTimeRemaining)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
            
            Text("remaining")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private var formattedTimeRemaining: String {
        guard timeRemaining > 0 else { return "0:00" }
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, endTime.timeIntervalSince(Date()))
    }
}
```

### 8. Update Per-FDP Display When In Rest
**File:** `ForeFlightLogBookRow.swift` in `expandedContent`

**Replace the Per-FDP ConfigurableLimitDisplay with:**
```swift
if settingsStore.configuration.perFDPFlightLimit.enabled {
    if currentStatus.isInRest {
        // Show "In Rest" instead of FDP time
        VStack(spacing: 2) {
            Text("Per FDP")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text("REST")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
    } else {
        ConfigurableLimitDisplay(
            label: "FDP Flt",
            current: currentStatus.currentFDPFlightTime,
            limit: currentStatus.perFDPLimit,
            threshold: settingsStore.configuration.warningThresholdPercent
        )
    }
}
```

### 9. Update compactStatusView for Rest
**File:** `ForeFlightLogBookRow.swift` around line 1259

**Replace with:**
```swift
private var compactStatusView: some View {
    HStack(spacing: 8) {
        if currentStatus.isInRest {
            // Show rest indicator when collapsed
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 12))
                Text("REST")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.blue)
        } else if settingsStore.configuration.flightTimeRolling.enabled {
            let limit = settingsStore.configuration.flightTimeRolling.hours
            Text(String(format: "%.0f", currentStatus.flightTimeRolling))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(currentStatus.flightTimeRolling / limit >= settingsStore.configuration.warningThresholdPercent ? .orange : .green)
            
            Text("/")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Text("\(Int(limit))h")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        
        Image(systemName: currentStatus.isInRest ? "moon.zzz.fill" :
                          currentStatus.criticalWarning ? "exclamationmark.triangle.fill" :
                          currentStatus.showWarning ? "exclamationmark.circle.fill" :
                          "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(currentStatus.isInRest ? .blue : statusColor)
    }
    .padding(.trailing, 8)
}
```

### 10. Add Trip Extension for NOC Duty Times
**File:** `Trip.swift` at the end

```swift
// MARK: - NOC Integration
extension Trip {
    /// Apply duty times from NOC parsed flight data
    mutating func applyNOCDutyTimes(from flight: ParsedFlightData) {
        // CI (Check In) = Duty Start
        if let checkIn = flight.checkIn {
            self.dutyStartTime = checkIn
        }
        
        // CO (Check Out) = Duty End
        if let checkOut = flight.checkOut {
            self.dutyEndTime = checkOut
        }
        
        // Calculate duty minutes if both are set
        if let start = self.dutyStartTime, let end = self.dutyEndTime {
            self.dutyMinutes = Int(end.timeIntervalSince(start) / 60)
        }
        
        print("✈️ Applied NOC duty times: \(self.dutyStartTime?.description ?? "nil") - \(self.dutyEndTime?.description ?? "nil")")
    }
}
```

## 📍 Where to Hook Up NOC Parsing

Looking at your `ICalDiagnosticView.swift`, you parse NOC data in `parseICalData()`:

```swift
private func parseICalData(_ data: Data) {
    // ... existing code ...
    
    // Use the new parser
    let (flights, events) = ICalFlightParser.parseCalendarString(content)
    parsedFlights = flights
    parsedNonFlightEvents = events
    
    // ✅ ADD THIS LINE:
    RestStatusManager.shared.updateFromNOCEvents(events, flights: flights)
    
    print("📋 iCal Diagnostic: Found \(flights.count) flights, \(events.count) events")
    
    // ... rest of code ...
}
```

## 🎯 Testing the Integration

1. **Fetch NOC data** with rest periods (OFF, WOFF events)
2. **Check console logs** for "😴 Currently in REST until..."
3. **Open Flight Time Limits** card - should show blue "REST" badge
4. **Expand the card** - should show rest banner with countdown
5. **Per-FDP should show "REST"** instead of hours when in rest period
6. **After rest ends** - badge should disappear, FDP should start counting again

## 🐛 Troubleshooting

**Rest not detected:**
- Check if NOC data has OFF/WOFF events with correct start/end times
- Check console logs for "😴 Currently in REST"
- Verify `ParsedNonFlightEvent.isRest` is returning true

**Badge not showing:**
- Verify `currentStatus.isInRest == true`
- Check if `ConfigurableLimitsStatusView` is using updated code
- Make sure `RestStatusManager.shared.refreshStatus()` is being called

**FDP still showing hours during rest:**
- Check if `currentStatus.isInRest` is true
- Verify the if/else logic in expandedContent
- Make sure `calculateConfigurableLimits` sets `status.isInRest = true`

## 📊 Expected Behavior

### When In Rest:
```
┌────────────────────────────────────────┐
│ 🌙 Flight Time Limits  [121] [REST]  │
├────────────────────────────────────────┤
│ 😴 Currently In Rest                   │
│ Until 3:00 PM (1500Z)      8:30        │
│                           remaining    │
├────────────────────────────────────────┤
│  Per FDP    30d      7d FDP   Annual  │
│   REST     85/100h  52/60h  856/1000h │
└────────────────────────────────────────┘
```

### When Not In Rest:
```
┌────────────────────────────────────────┐
│ ⚡ Flight Time Limits       [121]      │
├────────────────────────────────────────┤
│  30d      7d FDP     Annual            │
│ 85/100h   52/60h    856/1000h          │
└────────────────────────────────────────┘
```

---

## ⚡ Quick Implementation Checklist

- [x] Create `RestStatusManager.swift`
- [x] Add rest properties to `ConfigurableLimitStatus`
- [ ] Update `calculateConfigurableLimits()` to check rest
- [ ] Hook up NOC parsing to call `RestStatusManager.shared.updateFromNOCEvents()`
- [ ] Add REST badge to header
- [ ] Add rest banner to expanded view
- [ ] Create `RestCountdownView`
- [ ] Update Per-FDP display for rest
- [ ] Update compact status view
- [ ] Add `Trip.applyNOCDutyTimes()` extension

Next step: Would you like me to implement the remaining UI changes, or would you prefer to do them incrementally?

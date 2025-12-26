//
//  SEARCH_INTEGRATION_GUIDE.md
//  How to Add Search to TheProPilotApp
//

# Search Integration Guide

## ✅ Files Fixed and Ready

### LogbookSearchView.swift
- ✅ Fixed to use `LogBookStore` (not ScheduleStore)
- ✅ Fixed Trip properties (`aircraft` not `aircraftType`)
- ✅ Fixed FlightLeg properties (`departure`/`arrival` not `departureAirport`/`arrivalAirport`)
- ✅ Fixed crew access (`trip.crew` not `trip.crewMembers`)
- ✅ Fixed night flight detection (using `nightLanding`/`nightTakeoff` booleans)
- ✅ Added TripDetailSheetView for viewing search results
- ✅ Ready to integrate!

## Integration Steps

### Step 1: Add Search Button to Logbook View

In your `ContentView.swift`, find the logbook toolbar section (around line 938) and add a search button:

```swift
// MARK: - Header Section with Zulu Clock & Weather Toggle
HStack(alignment: .center) {
    ZuluClockView()
    
    Spacer()
    
    // NEW: Search button
    Button(action: {
        showSearch = true
    }) {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.gray)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.clear)
            )
    }
    .padding(.trailing, 8)
    
    // Weather Toggle Button
    Button(action: {
        withAnimation(.spring(response: 0.3)) {
            showingWeatherBanner.toggle()
        }
    }) {
        Image(systemName: showingWeatherBanner ? "cloud.fill" : "cloud")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(showingWeatherBanner ? LogbookTheme.accentBlue : .gray)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(showingWeatherBanner ? LogbookTheme.accentBlue.opacity(0.2) : Color.clear)
            )
    }
    .padding(.trailing, 8)
    
    addTripButton
}
```

### Step 2: Add State Variable

Add this to your ContentView state variables (around line 67):

```swift
@State private var showSearch = false  // ✅ NEW: Search sheet
```

### Step 3: Add Sheet Presenter

In your `sheetPresenters` computed property (search for "sheetPresenters" in ContentView), add:

```swift
// Search sheet
.sheet(isPresented: $showSearch) {
    LogbookSearchView()
        .environmentObject(store)
}
```

Or if you don't have a centralized sheet presenter, add it directly to your body:

```swift
var body: some View {
    // ... your existing content
}
.sheet(isPresented: $showSearch) {
    LogbookSearchView()
        .environmentObject(store)
}
```

## Alternative: Add to Navigation Bar (iPad/Mac Style)

If you prefer a navigation bar button instead:

```swift
.toolbar {
    // Your existing toolbar items
    
    // NEW: Search in navigation bar
    ToolbarItem(placement: .navigationBarLeading) {
        Button(action: { showSearch = true }) {
            Label("Search", systemImage: "magnifyingglass")
        }
    }
}
```

## Alternative: Use Native .searchable (iOS 15+)

For a built-in search bar in the navigation:

```swift
private var logbookContent: some View {
    VStack(spacing: 0) {
        // ... your existing logbook content
    }
    .searchable(
        text: $searchText,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search flights..."
    ) {
        // Search suggestions
        if !searchText.isEmpty {
            ForEach(quickSearchSuggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .searchCompletion(suggestion)
            }
        }
    }
}

// Add this computed property
private var quickSearchSuggestions: [String] {
    let airports = Set(store.trips.flatMap { $0.legs.flatMap { [$0.departure, $0.arrival] } })
    return Array(airports).prefix(5).sorted()
}
```

## Features Available in LogbookSearchView

### Search Scopes
- **All** - Searches everything
- **Airports** - Only departure/arrival airports
- **Trip #** - Trip numbers only
- **Aircraft** - Aircraft type
- **Notes** - Trip notes

### Filters
- **Date Range**: Last 30 Days, Last 90 Days, This Year, All Time
- **Aircraft Type**: Filter by specific aircraft
- **Minimum Flight Time**: Filter flights by hours
- **Night Flights Only**: Show only flights with night operations

### Results
- Shows trip number, date, route, flight time
- Displays night flight indicator
- Shows aircraft type
- Tap to view full trip details
- Live results count

## Testing Checklist

- [ ] Search button appears in logbook header
- [ ] Tapping button opens search modal
- [ ] Can search for airports (e.g., "KYIP")
- [ ] Can search for trip numbers (e.g., "7583")
- [ ] Can search for aircraft (e.g., "MD-88")
- [ ] Can search notes
- [ ] Scope picker works (All, Airports, Trip #, etc.)
- [ ] Aircraft filter works
- [ ] Date range filter works
- [ ] Flight time slider works
- [ ] Night flights toggle works
- [ ] Clear filters works
- [ ] Tapping result shows trip detail
- [ ] Close button returns to logbook
- [ ] Works on iPhone and iPad

## Keyboard Shortcuts (Optional - iPad/Mac)

Add Command+F shortcut for power users:

```swift
var body: some View {
    // ... your content
}
.commands {
    CommandMenu("Search") {
        Button("Find Flights...") {
            showSearch = true
        }
        .keyboardShortcut("f", modifiers: .command)
    }
}
```

## Customization Options

### Change Search Placeholder

In `LogbookSearchView.swift` line 40:

```swift
TextField("Search flights...", text: $searchText)
// Change to:
TextField("Search by airport, trip #, or aircraft...", text: $searchText)
```

### Add Custom Filters

Add new filter options in `SearchFiltersSheet`:

```swift
Section("Pilot Role") {
    Picker("Position", selection: $selectedRole) {
        Text("All Positions").tag(nil as PilotRole?)
        ForEach(PilotRole.allCases, id: \.self) { role in
            Text(role.rawValue).tag(role as PilotRole?)
        }
    }
}
```

### Modify Result Display

Edit `SearchResultRow` to show different information:

```swift
// Add pilot role badge
if trip.pilotRole == .captain {
    Text("CA")
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(4)
}
```

## Performance Tips

### For Large Logbooks (500+ trips)

1. **Debounce Search**: Add delay to prevent filtering on every keystroke

```swift
@State private var searchTask: Task<Void, Never>?

var body: some View {
    // ... content
}
.onChange(of: searchText) { newValue in
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        if !Task.isCancelled {
            performSearch(newValue)
        }
    }
}
```

2. **Limit Results**: Show only first 100 results

```swift
private var filteredTrips: [Trip] {
    // ... existing filter logic
    return trips.sorted { $0.date > $1.date }.prefix(100)
}
```

3. **Add Pagination**: Load more as user scrolls

## Search Analytics (Optional)

Track what users search for:

```swift
private func logSearchQuery(_ query: String) {
    // Your analytics code
    Analytics.logEvent("logbook_search", parameters: [
        "query": query,
        "scope": searchScope.rawValue,
        "results_count": filteredTrips.count
    ])
}
```

## Common Issues

### Issue: "Type 'ScheduleStore' has no member 'shared'"
**Fixed**: Changed to use `@EnvironmentObject private var store: LogBookStore`

### Issue: "Value of type 'Trip' has no member 'aircraftType'"
**Fixed**: Changed to use `trip.aircraft` (your actual property name)

### Issue: "Value of type 'FlightLeg' has no member 'departureAirport'"
**Fixed**: Changed to use `leg.departure` and `leg.arrival`

### Issue: Search not finding results
**Solution**: Check that your trips have data in the fields you're searching (airports, trip numbers, etc.)

### Issue: Search button not visible
**Solution**: Make sure you added the button to the correct HStack in your logbook header

## Future Enhancements

Ideas for improving search:

1. **Search History**: Save recent searches
2. **Smart Suggestions**: Learn from user behavior
3. **Voice Search**: Add speech-to-text
4. **Barcode Scanning**: Scan aircraft tail numbers
5. **Export Results**: Share filtered trips
6. **Saved Searches**: Create custom search filters
7. **Fuzzy Matching**: Find "KIPY" when searching "KYIP"
8. **Regular Expressions**: Power user searches

## Summary

✅ **LogbookSearchView.swift** is now compatible with your data model
✅ **TripDetailSheetView** added for viewing search results
✅ All properties fixed to match your Trip and FlightLeg models
✅ Uses `@EnvironmentObject` for proper data flow
✅ Ready to integrate into ContentView

**Next Steps:**
1. Add search button to logbook header
2. Add `@State private var showSearch = false`
3. Add `.sheet(isPresented: $showSearch)`
4. Test searching for airports, trip numbers, aircraft
5. Enjoy powerful search! 🔍

## Questions?

If search doesn't work:
1. Check that `store.trips` has data
2. Verify search button opens the sheet
3. Test with known trip numbers or airports
4. Check console for any errors

Happy searching! ✈️🔍

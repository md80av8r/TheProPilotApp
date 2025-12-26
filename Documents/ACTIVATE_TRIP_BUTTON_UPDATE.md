# Activate Trip Button UI Update

## Changes Made

### 1. Moved "Activate Trip" Button to Standby Leg Row
Previously, there was a large "Activate Trip" button displayed at the bottom of the trip banner for trips in planning status. This has been replaced with a more compact, inline button.

**Location**: First standby leg row (top of the upcoming legs section)

**New Design**:
- Compact button replacing the "Standby" badge
- Translucent green background (`LogbookTheme.accentGreen.opacity(0.8)`)
- White text
- Appears only on the **first standby leg** when the trip needs activation
- Other standby legs continue to show the regular gray "Standby" badge

### 2. Removed Large Bottom Button
The large "Activate Trip" button that appeared near the bottom of the banner (above the scanner buttons) has been removed.

## Benefits

✅ **Better Visual Hierarchy**: The activate button is now right next to the first leg that will be activated

✅ **Space Efficient**: Saves vertical space in the banner by removing the large bottom button

✅ **Contextual**: The button appears exactly where it's needed - on the first leg to be flown

✅ **Cleaner UI**: Reduces visual clutter while maintaining the same functionality

## Technical Details

### Code Changes in `ActiveTripBannerView.swift`

#### 1. Updated `standbyLegRow(leg:index:)` method:
```swift
// Show Activate button only for the first standby leg if trip needs activation
if tripNeedsActivation && index == trip.legs.firstIndex(where: { $0.status == .standby }) {
    Button(action: {
        onActivateTrip?()
    }) {
        Text("Activate Trip")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LogbookTheme.accentGreen.opacity(0.8)
            )
            .cornerRadius(6)
    }
} else {
    // Regular standby badge for other legs
    Text("Standby")
        .font(.caption2)
        .foregroundColor(.gray)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(4)
}
```

#### 2. Removed from `mainBannerContent`:
- Removed the conditional block that displayed `activateTripButton`
- The `activateTripButton` view is now unused and can be removed in future cleanup

## Visual Comparison

### Before:
```
┌─────────────────────────────┐
│ YIP → DTW        [Standby]  │  ← Gray badge
│ 23:00  --:--  --:--  23:30  │
├─────────────────────────────┤
│ DTW → CLE        [Standby]  │
│ 00:15  --:--  --:--  00:50  │
├─────────────────────────────┤
│ CLE → YIP        [Standby]  │
│ 01:35  --:--  --:--  02:15  │
└─────────────────────────────┘
...
────────────────────────────────
┌─────────────────────────────┐
│  ▶  Activate Trip           │  ← Large button at bottom
│     Start flying YIP → DTW  │
└─────────────────────────────┘
```

### After:
```
┌─────────────────────────────┐
│ YIP → DTW   [Activate Trip] │  ← Green button (first leg only)
│ 23:00  --:--  --:--  23:30  │
├─────────────────────────────┤
│ DTW → CLE        [Standby]  │  ← Regular badge (other legs)
│ 00:15  --:--  --:--  00:50  │
├─────────────────────────────┤
│ CLE → YIP        [Standby]  │
│ 01:35  --:--  --:--  02:15  │
└─────────────────────────────┘
...
────────────────────────────────
(Large button removed)
```

## Styling Details

### Activate Button (New Inline):
- **Font**: `.caption2.bold()`
- **Text Color**: White
- **Background**: `LogbookTheme.accentGreen.opacity(0.8)` (translucent green)
- **Padding**: Horizontal 10pt, Vertical 6pt
- **Corner Radius**: 6pt

### Regular Standby Badge:
- **Font**: `.caption2`
- **Text Color**: Gray
- **Background**: `Color.gray.opacity(0.2)`
- **Padding**: Horizontal 6pt, Vertical 2pt
- **Corner Radius**: 4pt

## Testing Checklist

- [ ] Create a test trip in planning status with multiple legs
- [ ] Verify "Activate Trip" button appears on first standby leg only
- [ ] Verify other standby legs show regular "Standby" badge
- [ ] Tap "Activate Trip" and confirm trip activates correctly
- [ ] Verify button has translucent green appearance
- [ ] Verify large bottom button is no longer displayed
- [ ] Test on different screen sizes (iPhone SE, standard, Plus, Max)

## Files Modified

- `ActiveTripBannerView.swift`
  - Modified `standbyLegRow(leg:index:)` to conditionally show activate button
  - Removed `activateTripButton` from main banner content flow

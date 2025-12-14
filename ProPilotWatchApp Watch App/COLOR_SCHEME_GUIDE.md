# Watch View Color Scheme Guide

## Time Button Colors

### Visual Color Map
```
┌─────────────────────────────────────┐
│  OUT (Blue 🔵)    OFF (Orange 🟠)   │
│  ┌───────────┐   ┌───────────┐     │
│  │    OUT    │   │    OFF    │     │
│  │   1530Z   │   │   1545Z   │     │
│  └───────────┘   └───────────┘     │
│                                     │
│  ON (Purple 🟣)   IN (Green 🟢)     │
│  ┌───────────┐   ┌───────────┐     │
│  │    ON     │   │    IN     │     │
│  │   1730Z   │   │   1745Z   │     │
│  └───────────┘   └───────────┘     │
└─────────────────────────────────────┘
```

## Color Coding Rationale

### 🔵 OUT (Blue)
- **Meaning**: Beginning of duty/flight
- **Association**: "Blue sky ahead" - start of journey
- **Contrast**: Cool color for beginning

### 🟠 OFF (Orange)
- **Meaning**: Wheels up, airborne
- **Association**: "Orange glow" of engines, warm takeoff
- **Contrast**: Warm transitional color

### 🟣 ON (Purple)
- **Meaning**: Wheels down, landed
- **Association**: "Purple twilight" of approach, descent
- **Contrast**: Cool transitional color

### 🟢 IN (Green)
- **Meaning**: Parked, duty complete
- **Association**: "Green means go/good/done" - safe arrival
- **Contrast**: Universal "all clear" color

## Timezone Indicators

### 🔵 ZULU TIME (Blue Badge)
```
┌──────────────────┐
│ 🕐 ZULU TIME     │  ← Blue background
└──────────────────┘
```
- Blue color matches aviation standard UTC indicators
- Professional, international standard
- Time format: `1530Z` (24-hour + Z suffix)

### 🟠 LOCAL TIME (Orange Badge)
```
┌──────────────────┐
│ 🕐 LOCAL TIME    │  ← Orange background
└──────────────────┘
```
- Orange indicates "caution - this is local time"
- Warmer color = personal/local context
- Time format: `15:30` (24-hour with colon)

## Time Display Formats

### When ZULU is selected:
```
OUT: 1530Z
OFF: 1545Z
ON:  1730Z
IN:  1745Z
```
- No colons (compact format)
- Z suffix clearly indicates UTC
- Consistent with aviation NOTAMs and flight plans

### When LOCAL is selected:
```
OUT: 15:30
OFF: 15:45
ON:  17:30
IN:  17:45
```
- Colon separator (readable format)
- No Z suffix
- Still 24-hour (not 3:30 PM)

## Button States

### Empty State (No Time Set)
```
┌───────────┐
│    OUT    │  ← Gray text
│   --:--   │  ← Gray background (10% opacity)
└───────────┘  ← Gray border (30% opacity)
```

### Set State (Time Recorded)
```
┌───────────┐
│    OUT    │  ← Secondary text
│   1530Z   │  ← Primary text (bold)
└───────────┘  ← Colored background (15% opacity)
              ← Colored border (100%, 1.5px)
```

## Accessibility Considerations

### Color Independence
- Each button also differs by:
  - Position (grid layout)
  - Label text (OUT/OFF/ON/IN)
  - Sequence (chronological order)
- Colors are supplementary, not primary identifier

### Contrast Ratios
- All text meets WCAG AA standards
- Border + background provides clear boundaries
- Monospaced font enhances readability

### Haptic Feedback
- Every button press provides tactile confirmation
- Users don't need to look at screen to confirm tap
- Different haptic patterns (click vs. success) provide context

## Design Philosophy

**Progressive Disclosure**
1. Pilot sees connection status first
2. Then flight number and route
3. Then timezone mode (prominent)
4. Then color-coded time grid
5. Finally calculations (when all times set)

**Aviation Standard Alignment**
- Colors chosen to NOT conflict with standard aviation meanings
- Red/Yellow avoided (typically mean warnings/cautions)
- Blue/Green align with "normal operations" 
- Orange/Purple are neutral transition states

**Glanceability**
- Large, distinct colors visible at arm's length
- High contrast borders when time is set
- Clear visual hierarchy

---

## Quick Reference Card

| Button | Color  | Means | Format (Zulu) | Format (Local) |
|--------|--------|-------|---------------|----------------|
| OUT    | 🔵 Blue   | Push back | 1530Z | 15:30 |
| OFF    | 🟠 Orange | Wheels up | 1545Z | 15:45 |
| ON     | 🟣 Purple | Touchdown | 1730Z | 17:30 |
| IN     | 🟢 Green  | Parked    | 1745Z | 17:45 |

**Remember**: 
- Blue badge = Zulu/UTC time
- Orange badge = Local time
- All times use 24-hour format
- Haptic feedback on every interaction

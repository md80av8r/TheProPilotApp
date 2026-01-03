# 📋 ProPilot App Quick Reference

## Core Features

### Flight Logbook
- **New Trip**: Tap green "+" button
- **Edit Trip**: Tap any trip to open details
- **Add Leg**: Inside trip, tap "Add Leg"
- **Times**: OUT → OFF → ON → IN format
- **Block Time**: OUT to IN (auto-calculated)
- **Flight Time**: OFF to ON (auto-calculated)

### GPS Track Recording
```
Auto-starts: On takeoff (>80 knots)
Auto-stops: On landing (<60 knots)
Storage: Local JSON files per leg
```

**Export Options:**
- **GPX**: Standard GPS format
- **KML**: Google Earth 3D format with animated tour

**View Tracks:**
1. Open Trip Details
2. Scroll to "GPS Track Logs" section
3. Tap track to view details
4. Share or open in Google Earth

### Auto Time Logging
```
Takeoff Detection: 80+ knots
Landing Detection: 60 knots
Rounding: Optional 5-minute intervals
Time Zone: Zulu or Local
```

**Settings Location:** Settings > Auto Time Logging

### Airport Proximity Alerts
```
Geofencing: 20 priority airports
Triggers:
  • Duty timer start prompt
  • OPS calling reminder
  • FBO proximity alerts
```

**Settings Location:** Settings > Airport Proximity

---

## File Locations

### Key Swift Files
```
GPS/FlightTrackRecorder.swift     - Track recording service
GPS/FlightTrackViewerView.swift   - Track viewer & export
GPS/GPSSpeedMonitor.swift         - Speed-based auto-time
PilotLocationManager.swift        - Geofencing & proximity
DataEntryView.swift               - Trip/leg editing (track section)
SettingsView.swift                - All settings UI
```

### Data Storage
```
Tracks:  Documents/FlightTracks/{legId}.json
Backups: Documents/Backups/
Config:  UserDefaults + AppStorage
Sync:    iCloud CloudKit
```

---

## Export Formats

### GPX (GPS Exchange Format)
- Compatible with: ForeFlight, Garmin, most GPS apps
- Contains: Lat/lon, altitude, speed, timestamps
- Use for: Sharing with other aviation apps

### KML (Keyhole Markup Language)
- Compatible with: Google Earth, Google Maps
- Contains: 3D flight path, markers, animated tour
- Use for: Visual flight replay in Google Earth
- Features: Departure/arrival markers, altitude extrusion

---

## Notification Names

### GPS & Location
```swift
.arrivedAtAirport        // Triggered by geofence entry
.departedAirport         // Triggered by geofence exit
.takeoffRollStarted      // Speed > 80 kts
.landingRollDecel        // Speed < 60 kts
.autoTimeTriggered       // OFF or ON time captured
```

### Sync & Data
```swift
.syncStateChanged        // CloudKit sync status
.dataExported            // Export completed
.dataImported            // Import completed
.dataRecoveryAvailable   // Recovery option ready
```

### Watch Integration
```swift
.startDutyFromWatch      // Duty started on Watch
.endDutyFromWatch        // Duty ended on Watch
.setOutTimeFromWatch     // OUT time from Watch
.setInTimeFromWatch      // IN time from Watch
```

---

## Quick Commands

### Build & Run
```bash
# Xcode: ⌘R
xcodebuild -project TheProPilotApp.xcodeproj \
  -scheme ProPilotApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

### Test GPS Features
```
1. Open Settings > Auto Time Logging
2. Enable Auto Time
3. Use GPX Test Player (Debug menu)
4. Load test GPX file
5. Verify triggers fire correctly
```

### Check Track Logs
```swift
let recorder = FlightTrackRecorder.shared
let track = recorder.loadTrack(for: legId)
print("Points: \(track?.trackPoints.count ?? 0)")
```

---

## Settings Sections

| Section | Location | Key Features |
|---------|----------|--------------|
| Auto Time | Settings | Speed thresholds, rounding |
| Proximity | Settings | Geofencing, OPS calling |
| CloudKit | More > Airport DB > ⚙️ | Sync diagnostics |
| NOC Import | More > NOC Schedule | Roster import |
| Backup | Settings | Manual/auto backup |

---

## Common Tasks

### Enable GPS Tracking
1. Settings > Auto Time Logging
2. Toggle "Enable GPS Speed Tracking"
3. Grant "Always" location permission

### Export Flight Track
1. Open trip with recorded track
2. Tap "GPS Track Logs"
3. Select track
4. Choose GPX or KML format
5. Tap "Share" or "Open in Google Earth"

### View in Google Earth
1. Export as KML
2. Tap "Open in Google Earth"
3. Or share KML file, open in GE app
4. Use "Fly Along Flight Path" tour

### Check Proximity Status
1. Settings > Airport Proximity
2. View active geofences (20 airports)
3. See last detection events

---

## Troubleshooting

### Track Not Recording
- Check: Location permission = "Always"
- Check: Auto Time Logging enabled
- Check: Speed threshold (80 kts default)
- Verify: GPS signal strength

### Export Shows Blank Sheet
- Fixed in latest version
- Fallback UI shows error message
- Check file system permissions

### Airports Show "UNKN"
- Detection requires 10+ track points
- First/last points used for nearest airport
- Airport DB must be loaded

### Google Earth Won't Open
- Install Google Earth app
- KML shared via share sheet
- Check LSApplicationQueriesSchemes in Info.plist

---

## Recent Updates

### January 2026
- ✅ KML export with 3D flight path
- ✅ Google Earth integration
- ✅ Track logs in DataEntryView
- ✅ Detected OFF/ON times from GPS
- ✅ Airport proximity settings in Settings
- ✅ Help articles for new GPS features
- ✅ Universal Search updated with GPS items

### December 2025
- ✅ GPS Track Recording system
- ✅ Auto-time logging with speed detection
- ✅ Geofencing for airport proximity
- ✅ GPS spoofing detection
- ✅ CloudKit sync improvements

---

## Support

- **Email**: support@propilotapp.com
- **App Store**: [Rate & Review](https://apps.apple.com/app/id6748836146?action=write-review)
- **Help**: In-app Help & Support section

---

**Built with ❤️ for professional pilots**

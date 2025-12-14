# ProPilot App - Function & File Index

## Quick Reference Guide
*Last Updated: December 2024*
*~150+ Swift files organized by feature*

---

## 🎯 CORE APP STRUCTURE

### Main Entry Points
| File | Purpose |
|------|---------|
| `ProPilotApp.swift` | App entry, background tasks, initialization |
| `ContentView.swift` | Main view controller, tab navigation, notification handlers |
| `TabManager.swift` | Tab configuration, ordering, visibility |

### Data Models
| File | Purpose |
|------|---------|
| `Trip.swift` | Trip, Logpage, FlightLeg models, status methods |
| `FlightLeg.swift` | Flight leg model, time calculations |
| `FlightLeg+Validation.swift` | Leg validation logic |
| `FlightLeg+TimeValidation.swift` | Time validation extensions |
| `CrewMember.swift` | Crew data model |
| `TripType.swift` | Trip type enum (Operating, Deadhead, Simulator) |
| `FlightEntry.swift` | Import/export flight entry model |

### Data Persistence
| File | Purpose |
|------|---------|
| `LogBookStore.swift` | Main trip storage, CloudKit sync, CRUD operations |
| `CloudKitManager.swift` | CloudKit sync for trips |
| `UserDefaults+AppGroup.swift` | App Group UserDefaults helpers |
| `AppBackupData.swift` | Backup data structures |

---

## ✈️ TRIP MANAGEMENT

### Trip Creation & Editing
| File | Purpose |
|------|---------|
| `DataEntryView.swift` | New/Edit trip form, time entry, crew management |
| `LandscapeDataEntryView.swift` | Landscape-optimized trip entry |
| `ActiveTripBannerView.swift` | Active trip display, live time entry |
| `TripCompletionSummaryView.swift` | Trip completion summary |

### Trip Display
| File | Purpose |
|------|---------|
| `LogbookView.swift` | Trip list display |
| `AllLegsView.swift` | All legs across trips |
| `HorizontalLogView.swift` | Horizontal logbook format |
| `LogPageTableView.swift` | Logpage table view |
| `BottomSheetTripsView.swift` | Bottom sheet trip selector |

### Trip Generation (NOC Roster)
| File | Purpose |
|------|---------|
| `TripGenerationService.swift` | Auto-create trips from roster |
| `TripGenerationSettings.swift` | Trip generation preferences |
| `TripGenerationSettingsView.swift` | Settings UI |
| `TripGenerationAlertModifier.swift` | Alert for new trips |
| `RosterToTripHelper.swift` | Roster to trip conversion |
| `PendingTripsHelperView.swift` | Pending trip approval UI |

---

## 🛫 AIRCRAFT DATABASE

### Unified System (NEW)
| File | Purpose |
|------|---------|
| `UnifiedAircraftDatabase.swift` | Aircraft model, CloudKit sync, ForeFlight export |
| `UnifiedAircraftView.swift` | Aircraft list UI, add/edit/delete |

### Legacy (TO DELETE)
| File | Purpose |
|------|---------|
| `AircraftDatabase.swift` | OLD - Internal aircraft tracking |
| `EnhancedAircraftManagementView.swift` | OLD - Aircraft management UI |
| `AircraftLibrary/` folder | OLD - ForeFlight export system |
| `AircraftDefinition.swift` | OLD - Aircraft definition model |
| `AircraftLibraryStore.swift` | OLD - Aircraft library storage |
| `AircraftLibraryView.swift` | OLD - Aircraft library UI |
| `AircraftManagementView.swift` | OLD - Basic aircraft management |
| `AircraftHistoryManager.swift` | Aircraft usage history |

---

## ⏱️ TIMERS & DUTY TRACKING

### Duty Timer
| File | Purpose |
|------|---------|
| `DutyTimerManager.swift` | Duty time tracking logic |
| `DutyTimerLiveActivity.swift` | Dynamic Island / Live Activity |
| `DutyLimitSettings.swift` | FAR 121 duty limits (16hr, 100hr/30day) |
| `DutyLimitSettingsView.swift` | Duty limit settings UI |

### Flexible Timers
| File | Purpose |
|------|---------|
| `FlexibleTimerManager.swift` | Custom timer management |
| `FlexibleTimerView.swift` | Timer display UI |
| `ForeFlightStyleTimerView.swift` | ForeFlight-style timer |

### Clocks
| File | Purpose |
|------|---------|
| `ClocksView.swift` | Multi-timezone clocks |
| `ClocksAndTimersView.swift` | Combined clocks/timers view |
| `ClocksAndTimersSettingsView.swift` | Clock settings |
| `GMTClockOverlay.swift` | GMT clock overlay |
| `GMTClockPill.swift` | Compact GMT display |
| `GMTClockSettings.swift` | GMT clock preferences |

### FAR Compliance
| File | Purpose |
|------|---------|
| `FAR117ComplianceView.swift` | FAR 117 compliance display |
| `FAR117SettingsView.swift` | FAR 117 settings |
| `Rolling30DayComplianceView.swift` | 30-day rolling limits |
| `RestStatusManager.swift` | Rest tracking |

---

## 📍 GPS & AUTO-TIME

### GPS Tracking
| File | Purpose |
|------|---------|
| `GPSSpeedMonitor.swift` | Speed tracking, takeoff/landing detection |
| `PilotLocationManager.swift` | Airport proximity detection |
| `GPSRAIMManager.swift` | GPS RAIM status |
| `SimpleGPSSignalView.swift` | GPS signal indicator |

### Auto-Time System
| File | Purpose |
|------|---------|
| `AutoTimeSettings.swift` | Zulu/Local, rounding, thresholds |
| `AutoTimeSettingsView.swift` | Auto-time settings UI |
| `AutoTimeLoggingSettingsView.swift` | Logging preferences |

### Time Utilities
| File | Purpose |
|------|---------|
| `TimeDisplayUtility.swift` | Time display formatting |
| `TimeFormattingUtilities.swift` | Time format helpers |
| `TimeRoundingUtility.swift` | 5-minute rounding |
| `SmartTimeEntryField.swift` | Smart time entry component |
| `TranslucentTimePicker.swift` | Overlay time picker |
| `TripDateUtility.swift` | Trip date helpers |

---

## 📅 NOC ROSTER / SCHEDULE

### Calendar Sync
| File | Purpose |
|------|---------|
| `NOCSettingsStore.swift` | Calendar sync, credentials, URL handling |
| `NOCSettingsView.swift` | NOC settings UI |
| `NOCWebView.swift` | NOC web portal |
| `NOCWebPortalView.swift` | Web portal container |
| `ICalDiagnosticView.swift` | iCal debug view |

### Schedule Display
| File | Purpose |
|------|---------|
| `ScheduleCalendarView.swift` | Calendar view of schedule |
| `ScheduleDataAnalyzer.swift` | Schedule analysis |
| `NOCRosterGanttView.swift` | Gantt chart of roster |
| `TripTimelineGanttChart.swift` | Trip timeline display |

### Roster Items
| File | Purpose |
|------|---------|
| `RosterModels.swift` | Roster item models |
| `BasicScheduleItem.swift` | Basic schedule item |
| `SwipeableRosterItemRow.swift` | Swipeable roster row |
| `DismissedRosterItem.swift` | Dismissed roster tracking |
| `DismissedRosterItemsView.swift` | Dismissed items UI |
| `NOCRevisionAlertBanner.swift` | Roster revision alerts |

---

## 📄 DOCUMENT SCANNING

### Scanner
| File | Purpose |
|------|---------|
| `DocumentScannerView.swift` | Camera document scanner |
| `TripScannerView.swift` | Trip-specific scanner |
| `DocumentCropProcessor.swift` | Document cropping |
| `DocumentCropSettingsView.swift` | Crop settings |
| `DocumentPicker.swift` | File picker |

### Document Storage
| File | Purpose |
|------|---------|
| `DocumentStore.swift` | Document persistence |
| `TripDocumentManager.swift` | Trip document organization |
| `TripDocumentListView.swift` | Document list UI |
| `TripFolderBrowserView.swift` | Folder browser |
| `DocumentDeletionManager.swift` | Document cleanup |

### PDF
| File | Purpose |
|------|---------|
| `PDFThumbnailGenerator.swift` | PDF thumbnail creation |
| `PDFThumbnailView.swift` | PDF thumbnail display |

### Email Integration
| File | Purpose |
|------|---------|
| `EmailComposerView.swift` | Email composer |
| `EmailSettings.swift` | Email preferences |
| `EmailSettingsView.swift` | Email settings UI |
| `DocumentEmailConfig.swift` | Document email config |
| `DocumentEmailData.swift` | Email data model |
| `ScannerEmailConfigView.swift` | Scanner email settings |

---

## 📊 IMPORT / EXPORT

### Unified Manager
| File | Purpose |
|------|---------|
| `UnifiedLogbookManager.swift` | ForeFlight & LogTen Pro import/export |
| `LogbookFormat.swift` | Format definitions |
| `ForeFlightLogBookRow.swift` | ForeFlight row format |

### Export Views
| File | Purpose |
|------|---------|
| `ExportView.swift` | Export UI |
| `LegsExportView.swift` | Legs export |
| `LegsReportView.swift` | Legs report |
| `TemplateGeneratorView.swift` | Template generation |

### Electronic Logbook
| File | Purpose |
|------|---------|
| `ElectronicLogbookViewer.swift` | E-logbook viewer |
| `SimpleElectronicLogbookView.swift` | Simple e-logbook |
| `ElectronicLogbookHelpView.swift` | Help documentation |

### Data Management
| File | Purpose |
|------|---------|
| `DataManagementView.swift` | Data management UI |
| `DataBackupSettingsView.swift` | Backup settings |
| `BackupFileHandler.swift` | Backup file handling |
| `DataValidatorView.swift` | Data validation |

---

## ⌚ APPLE WATCH

### Connectivity
| File | Purpose |
|------|---------|
| `PhoneWatchConnectivity.swift` | iPhone ↔ Watch communication |
| `WatchPhoneLegSyncManager.swift` | Leg sync between devices |
| `WatchConnectivityStatusView.swift` | Connection status |
| `iPhoneWatchSettingsView.swift` | Watch settings |
| `AppleWatchStatusView.swift` | Watch status display |

### Watch UI Components
| File | Purpose |
|------|---------|
| `WatchSmartTimePicker.swift` | Watch time picker |
| `WatchTheme.swift` | Watch theming |
| `WatchTripSummaryView.swift` | Watch trip summary |

---

## 🏢 AIRLINE CONFIGURATION

### Settings
| File | Purpose |
|------|---------|
| `AirlineSettings.swift` | Airline preferences model |
| `AirlineSettingsView.swift` | Airline settings UI |
| `AirlineConfigurationView.swift` | Full airline config |
| `HomeBaseConfigurationView.swift` | Home base setup |

### OPS Integration
| File | Purpose |
|------|---------|
| `OPSCallingManager.swift` | OPS phone call handling |
| `NOCQuickAccessButton.swift` | Quick NOC access |

---

## 🌍 AIRPORTS

### Database
| File | Purpose |
|------|---------|
| `AirportDatabaseManager.swift` | Airport database |
| `CloudAirport.swift` | CloudKit airport model |
| `EnhancedAirportCodeManager.swift` | Airport code lookup |
| `UserAirportCodeMappings.swift` | Custom airport mappings |

### UI Components
| File | Purpose |
|------|---------|
| `EnhancedICAOTextField.swift` | ICAO autocomplete field |
| `AreaGuideView.swift` | Airport area guide |
| `AreaGuideCloudKit 2.swift` | CloudKit area guide |

---

## 👥 CREW MANAGEMENT

| File | Purpose |
|------|---------|
| `CrewContactManager.swift` | Crew contact storage |
| `CrewContactsView.swift` | Crew contacts UI |
| `CrewImportHelperView.swift` | Crew import helper |

---

## 💰 PER DIEM

| File | Purpose |
|------|---------|
| `PerDiemTabView.swift` | Per diem main view |
| `PerDiemSummaryView.swift` | Per diem summary |
| `PerDiemSettingsView.swift` | Per diem settings |
| `CurrencyRate.swift` | Currency rates |

---

## 🔔 LIVE ACTIVITIES

| File | Purpose |
|------|---------|
| `PilotActivityManager.swift` | Live Activity management |
| `DutyTimerLiveActivity.swift` | Duty timer Live Activity |
| `LiveActivityDebugView.swift` | Debug view |

---

## 🎨 UI COMPONENTS & THEMING

### Theme
| File | Purpose |
|------|---------|
| `LogbookTheme.swift` | App colors, styling |
| `LogbookUIComponents.swift` | Reusable UI components |

### Components
| File | Purpose |
|------|---------|
| `GradientGlowButton.swift` | Glowing button style |
| `ChainRouteDisplay.swift` | Route chain display |
| `SnappingScrollView.swift` | Snapping scroll behavior |
| `MoreRowItem.swift` | More tab row item |

---

## ⚙️ SETTINGS

| File | Purpose |
|------|---------|
| `SettingsView.swift` | Main settings |
| `MoreTabView.swift` | More tab content |
| `NotificationSettingsView.swift` | Notification settings |
| `TimerSettingsView.swift` | Timer settings |
| `ProximitySettingsView.swift` | Proximity settings |

---

## 🔧 UTILITIES & HELPERS

| File | Purpose |
|------|---------|
| `Helpers.swift` | General helpers |
| `AppConstants.swift` | App constants |
| `AppMonitor.swift` | App monitoring |
| `NotificationNames.swift` | Notification name constants |
| `CompilationFixes.swift` | Compilation workarounds |
| `ShareSheet.swift` | Share sheet |
| `TripCreationSettings.swift` | Trip creation preferences |

---

## 🧪 TESTING & DEBUG

| File | Purpose |
|------|---------|
| `GPXTestPlayer.swift` | GPX file playback |
| `GPXTestIntegration.swift` | GPX test integration |
| `AutoCompleteTestView.swift` | Autocomplete testing |
| `FlightTrackingUtility.swift` | Flight tracking debug |

---

## 📱 WIDGETS

| Folder | Purpose |
|--------|---------|
| `ProPilotWidgets/` | Home screen widgets |

---

## 🔌 EXTERNAL INTEGRATIONS

### FlightAware
| File | Purpose |
|------|---------|
| `FlightAwareManager.swift` | FlightAware API |
| `FlightAwareModels.swift` | FlightAware models |
| `FlightAwareViews.swift` | FlightAware UI |
| `FlightAwareCredentials.swift` | API credentials |
| `FlightAwareIntegration.swift` | Integration logic |

### Jumpseat Network
| Folder | Purpose |
|--------|---------|
| `Jumpseat/` | Jumpseat network feature |

### eAPIS
| Folder | Purpose |
|--------|---------|
| `eAPIS/` | eAPIS integration |

---

## 📚 DOCUMENTATION FILES

| File | Purpose |
|------|---------|
| `PROPILOT_SYSTEM_ARCHITECTURE.md` | System architecture reference |
| `PROPILOT_FUNCTION_INDEX.md` | This file! |
| `16_HOUR_DUTY_TRACKING.md` | Duty tracking docs |
| `DUTY_TIME_*.md` | Duty time documentation |
| `GPX_*.md` | GPX testing docs |
| `*_INTEGRATION_GUIDE.md` | Integration guides |

---

## 🗑️ FILES TO CLEAN UP (Legacy/Unused)

These files can be deleted after confirming the new unified systems work:

```
AircraftDatabase.swift
EnhancedAircraftManagementView.swift
AircraftLibrary/ (folder)
AircraftDefinition.swift
AircraftLibraryStore.swift
AircraftLibraryView.swift
AircraftManagementView.swift
ComprehensiveLogbookStore.swift (if replaced)
FlexibleTimerView 2.swift (duplicate)
AreaGuideCloudKit 2.swift 15-15-08-521.swift (duplicate)
Untitled.swift
*.zip files (old backups)
```

---

## 🔍 QUICK SEARCH BY FEATURE

### "I want to change how trips are created"
→ `DataEntryView.swift`, `TripGenerationService.swift`

### "I want to modify the aircraft database"
→ `UnifiedAircraftDatabase.swift`, `UnifiedAircraftView.swift`

### "I want to change ForeFlight export"
→ `UnifiedLogbookManager.swift`

### "I want to modify GPS auto-time"
→ `GPSSpeedMonitor.swift`, `AutoTimeSettings.swift`

### "I want to change duty time limits"
→ `DutyLimitSettings.swift`, `DutyTimerManager.swift`

### "I want to modify the NOC roster sync"
→ `NOCSettingsStore.swift`, `TripGenerationService.swift`

### "I want to change CloudKit sync"
→ `CloudKitManager.swift`, `LogBookStore.swift`, `UnifiedAircraftDatabase.swift`

### "I want to modify Watch connectivity"
→ `PhoneWatchConnectivity.swift`, `WatchPhoneLegSyncManager.swift`

### "I want to change the main UI layout"
→ `ContentView.swift`, `TabManager.swift`

### "I want to add a new settings page"
→ `MoreTabView.swift`, `SettingsView.swift`

---

*Total: ~150 Swift files across 15+ feature areas*

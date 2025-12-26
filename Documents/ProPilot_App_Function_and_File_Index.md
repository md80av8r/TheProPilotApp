# ProPilot App - Function and File Index
## Complete Reference Guide - Updated December 22, 2024

---

## 📱 App Overview

**ProPilot** is a professional flight logbook and crew management app for airline pilots. It tracks flight time, duty periods, schedules, compliance, and provides comprehensive flight operations tools.

**Platform:** iOS 17+ (iPhone & iPad)  
**Language:** Swift  
**Architecture:** SwiftUI with MVVM pattern  
**Data Storage:** CloudKit + Local JSON

---

## 🗂️ Core Architecture

### Main Entry Point
```
TheProPilotApp.swift
├── ContentView (main UI container)
├── LogBookStore (flight data)
├── ScheduleStore (roster data)
├── PilotActivityManager (live activities)
└── NOCSettingsStore (schedule import settings)
```

### Navigation Structure
```
CustomizableTabView (TabManager.swift)
├── Logbook Tab (visible)
├── Schedule Tab (visible)
├── Time Away Tab (visible)
├── Dynamic Recent Tab (4th slot)
└── More Tab (slide-out panel with 25+ features)
```

---

## 📁 File Organization by Category

### 🎯 Core Data Models

#### **Trip.swift** (989 lines)
**Purpose:** Main flight trip model with logpage support

**Key Structs:**
- `Trip` - Complete trip with legs, crew, times
- `Logpage` - Page-based flight logging
- `TripStatus` - Planning/Active/Completed
- `PilotRole` - Captain/First Officer/Solo
- `TripType` - Operating/Deadhead/Simulator

**Key Properties:**
- `legs: [FlightLeg]` - Flight legs (flattened from logpages)
- `logpages: [Logpage]` - Page-based structure
- `crew: [CrewMember]` - Crew roster
- `pilotRole: PilotRole` - Position on trip
- `status: TripStatus` - Trip state
- `dutyStartTime/dutyEndTime: Date?` - Duty period tracking

**Key Methods:**
- `updateLeg(at:with:)` - Update individual leg
- `activeLeg` - Get currently active leg
- `totalFlightMinutes` - Calculate total flight time
- `totalBlockMinutes` - Calculate total block time
- `routeString` - Generate route display

---

#### **FlightLeg.swift** (472 lines)
**Purpose:** Individual flight segment model

**Key Structs:**
- `FlightLeg` - Single flight leg
- `LegStatus` - Standby/Active/Completed/Skipped
- `LegPilotRole` - PF/PM tracking per leg
- `ScheduleVariance` - Compare actual vs scheduled times

**Key Properties:**
- `departure/arrival: String` - Airport codes
- `outTime/offTime/onTime/inTime: String` - OOOI times
- `status: LegStatus` - Leg progression state
- `legPilotRole: LegPilotRole` - PF or PM
- `nightTakeoff/nightLanding: Bool` - Currency tracking
- `scheduledOut/scheduledIn: Date?` - Roster times

**Key Methods:**
- `blockMinutes()` - Calculate block time
- `calculateFlightMinutes()` - Calculate flight time
- `outTimeVarianceMinutes` - Compare to schedule
- `parseTime()` - Convert string to Date

---

### 💾 Data Stores

#### **LogBookStore.swift** (940 lines)
**Purpose:** Main data persistence and sync

**Key Class:**
- `LogBookStore: ObservableObject`

**Key Published Properties:**
- `@Published var trips: [Trip]` - All trips
- `@Published var perDiemRate: Double` - Per diem rate

**Key Methods:**
- `loadWithRecovery()` - Load data with error handling
- `save()` - Save to JSON file
- `addTrip(_:)` - Add new trip
- `updateTrip(_:at:)` - Update existing trip
- `deleteTrip(at:)` - Remove trip
- `recoverDataWithCrewMemberMigration()` - Data recovery
- `createBackup()` - Manual backup
- `restoreFromBackup()` - Restore from backup

**Storage Location:**
```swift
FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.propilot.app"
)
```

---

#### **ScheduleStore.swift**
**Purpose:** NOC schedule and roster management

**Key Class:**
- `ScheduleStore: ObservableObject`

**Key Methods:**
- `importSchedule(from:)` - Import NOC HTML
- `parseNOCSchedule()` - Parse schedule data
- `convertToTrips()` - Generate trips from schedule

---

### 🎨 Main Views

#### **ContentView.swift** (2596 lines)
**Purpose:** Main app container and navigation

**Key Struct:**
- `ContentView: View`

**Layout Modes:**
- `iPhoneTabLayout` - Tab bar navigation
- `iPadNavigationLayout` - Split view navigation

**Key Sub-Views:**
- `logbookTab` - Main logbook interface
- `logbookContent` - Scrollable logbook list
- `scheduleTab` - Schedule calendar view
- `perDiemTab` - Time away tracking

**Key Functions:**
- `contentForTab(_ tabId:)` - Route tab IDs to views
- `setupContentView()` - Initialize app state
- `checkIfShouldShowWelcome()` - First-run experience
- `handleFileImport()` - CSV import handler

**Tab ID Mapping:**
```swift
case "logbook" → logbookTab
case "schedule" → scheduleTab
case "perDiem" → perDiemTab
case "help" → HelpView()
case "search" → LogbookSearchView()
// ... 25+ more tabs
```

---

#### **TabManager.swift** (Current File - 1000+ lines)
**Purpose:** Customizable tab system with More panel

**Key Classes:**
- `CustomizableTabManager` - Tab configuration manager
- `TabItem` - Tab definition model

**Key Structs:**
- `CustomizableTabView` - Main tab container
- `MorePanelOverlay` - Slide-out More panel
- `TabEditorView` - Tab customization UI

**Tab Sections (31 total tabs):**
1. **Main Visible** (3): Logbook, Schedule, Time Away
2. **Apple Watch** (1): Watch Status
3. **Airline & Aircraft** (2): Config, Aircraft DB
4. **Flight Logging** (3): Auto Time, Scanner, Email
5. **Schedule & Operations** (3): NOC Import, Trip Gen, Crew
6. **Clocks & Timers** (1): World Clock
7. **Flight Tools** (6): Airport DB, GPS/RAIM, Weather, Area Guide, Calculator, Ops
8. **Tracking & Reports** (6): Limits, 30-Day, FAR 121, Fleet, Legs, E-Logbook
9. **Documents & Data** (3): Documents, Notes, Backup
10. **Help & Support** (2): Help, Search ⭐ NEW
11. **Jumpseat Network** (1): Jumpseat Finder
12. **Beta Testing** (3): NOC Test, GPX Test, Airport Test

**Key Methods:**
- `setupDefaultTabs()` - Initialize tab definitions
- `updateTabArrays()` - Refresh visible/more tabs
- `moveTab(_:toVisible:)` - Move tab between sections
- `setRecentTab(_:)` - Update dynamic 4th tab

---

### 🆕 New Features (Just Added!)

#### **LogbookWelcomeView.swift**
**Purpose:** First-run onboarding experience

**Key Structs:**
- `LogbookWelcomeView` - Main welcome screen
- `WelcomeActionCard` - Action button cards

**Actions:**
1. Log Your First Flight
2. Import NOC Schedule
3. Import Existing Logbook (CSV)
4. Skip (explore on own)

**Integration:**
- Shown once for new users
- Replaces scary "data loss" warning
- Uses `@AppStorage` for state tracking

---

#### **LogbookSearchView.swift** ⭐ FIXED
**Purpose:** Advanced flight search with filters

**Key Structs:**
- `LogbookSearchView` - Main search interface
- `SearchResultRow` - Individual result display
- `SearchFiltersSheet` - Advanced filter panel
- `TripDetailSheetView` - Result detail view
- `SearchStatBox` - Statistics display

**Search Scopes:**
- All (search everything)
- Airports (departure/arrival)
- Trip # (trip numbers)
- Aircraft (aircraft type)
- Notes (trip notes)

**Filters:**
- Date Range (30/90 days, this year, all time)
- Aircraft Type (filter by aircraft)
- Minimum Flight Time (hours)
- Night Flights Only (toggle)

**Key Methods:**
- `searchMatches(trip:query:scope:)` - Search algorithm
- `matchesAirports()` - Airport-specific search
- `filteredTrips` - Computed filtered results

**Fixed Issues:**
- ✅ Uses `LogBookStore` (not ScheduleStore)
- ✅ Uses `trip.aircraft` (not aircraftType)
- ✅ Uses `leg.departure/arrival` (not departureAirport)
- ✅ Renamed `SearchStatBox` (not StatBox - conflict resolved)

---

#### **HelpView.swift** ⭐ FIXED
**Purpose:** In-app help and support system

**Key Structs:**
- `HelpView` - Main help interface
- `HelpSection` - Collapsible help categories
- `HelpArticleRow` - Individual article
- `HelpQuickActionRow` - Action buttons

**Sections:**
1. **Quick Actions:**
   - Contact Support (email)
   - Video Tutorials (web)
   - What's New (changelog)

2. **Getting Started:**
   - Logging Your First Flight
   - Importing NOC Schedule
   - Understanding Duty Time

3. **Features & Tools:**
   - CloudKit Sync
   - Flight Time Limits
   - CSV Import/Export
   - Apple Watch App

4. **FAQ:**
   - Backup logbook
   - Offline use
   - Calculation accuracy
   - Pro subscription

5. **Troubleshooting:**
   - Sync not working
   - Missing trips
   - NOC import issues

6. **About:**
   - Version info
   - Privacy Policy
   - Terms of Service
   - Rate App

**Fixed Issues:**
- ✅ Fixed `.tertiaryLabel` → `Color(.tertiaryLabel)`

---

### 📊 Compliance & Tracking

#### **FAR121ComplianceView.swift**
**Purpose:** Track FAR 121 flight time limits

**Monitors:**
- 30-Day Flight Time (100 hours)
- Annual Flight Time (1,000 hours)
- 30-Day FDP (Flight Duty Period)
- Rest requirements

---

#### **Rolling30DayComplianceView.swift**
**Purpose:** Rolling 30-day flight time tracking

**Features:**
- Daily breakdown
- Running totals
- Projection
- Warning thresholds

---

#### **DutyTimerManager.swift**
**Purpose:** Real-time duty period tracking

**Key Class:**
- `DutyTimerManager: ObservableObject`

**Key Methods:**
- `startDuty()` - Begin duty period
- `endDuty()` - Complete duty period
- `pauseDuty()` - Pause timer
- `calculateRemainingTime()` - Time until limit

---

### 🛠️ Utility Views

#### **TripScannerView.swift** (1308 lines)
**Purpose:** Document scanning with VisionKit

**Features:**
- Scan fuel receipts
- Scan logbook pages
- Scan general documents
- OCR text extraction
- PDF generation

---

#### **ExportView.swift** (1471 lines)
**Purpose:** CSV export for ForeFlight/Excel

**Formats:**
- ForeFlight CSV
- Standard logbook CSV
- Custom date range
- Email integration

---

#### **AllLegsView.swift** (810 lines)
**Purpose:** Comprehensive flight legs report

**Features:**
- All legs across trips
- Sortable columns
- Filter by date
- Export capability
- Statistics summary

---

### 🌐 Network & Sync

#### **PhoneWatchConnectivity.swift** (1778 lines)
**Purpose:** iPhone ↔ Apple Watch sync

**Key Class:**
- `PhoneWatchConnectivity: ObservableObject`

**Syncs:**
- Current trip status
- Active leg times
- Duty timer state
- Quick actions

**Key Methods:**
- `syncCurrentLegToWatch()` - Send leg data
- `handleWatchMessage()` - Receive watch updates
- `updateWatchComplications()` - Update complications

---

### ⚙️ Settings & Configuration

#### **AirlineSettingsStore.swift**
**Purpose:** Airline-specific settings

**Settings:**
- Airline name/code
- Base airport
- Duty time rules
- Rest period rules
- Currency requirements

---

#### **NOCSettingsStore.swift**
**Purpose:** NOC schedule import configuration

**Settings:**
- Email parser rules
- Airline-specific parsing
- Auto-import preferences
- Schedule format

---

#### **AutoTimeSettings.swift**
**Purpose:** Automatic time logging via GPS

**Features:**
- Detect takeoff (45+ knots)
- Detect landing (< 30 knots)
- Auto-populate OFF/ON times
- Configurable thresholds

---

### 🎨 UI Components

#### **LogbookTheme.swift**
**Purpose:** App-wide theming

**Colors:**
```swift
static let navy = Color(hex: "#1C2A3A")
static let navyLight = Color(hex: "#2C3E50")
static let navyDark = Color(hex: "#0D1822")
static let accentBlue = Color(hex: "#3498DB")
static let accentGreen = Color(hex: "#2ECC71")
static let accentOrange = Color(hex: "#E67E22")
static let warningYellow = Color(hex: "#F39C12")
static let textSecondary = Color(hex: "#95A5A6")
```

---

#### **ActiveTripBanner.swift**
**Purpose:** Current trip quick actions

**Features:**
- Current leg display
- Quick time edit
- Scan fuel receipt
- Scan documents
- Complete trip button

---

#### **ConfigurableLimitsStatusView.swift**
**Purpose:** FAR 117 compliance card

**Displays:**
- Current duty time
- Remaining duty time
- Flight time limits
- Rest requirements
- Visual warnings

---

### 📍 Location & Maps

#### **PilotLocationManager.swift**
**Purpose:** GPS tracking for auto-time

**Features:**
- Speed monitoring
- Airport proximity
- Takeoff/landing detection
- Background tracking

---

#### **AirportDatabaseManager.swift**
**Purpose:** Airport data management

**Features:**
- 40,000+ airports
- ICAO/IATA codes
- Coordinates
- Runway data
- Search functionality

---

### 📅 Schedule Management

#### **ScheduleCalendarView.swift** (2622 lines)
**Purpose:** Monthly calendar with trips

**Features:**
- Month/week/day views
- Trip overlays
- Duty period visualization
- Day-off tracking
- Quick trip navigation

---

#### **NOCTestView.swift**
**Purpose:** Test NOC schedule parsing

**Features:**
- Paste NOC HTML
- Parse and preview
- Validate trips
- Debug parser issues

---

## 🔧 Key Functions Reference

### Data Management

```swift
// LogBookStore
func addTrip(_ trip: Trip)
func updateTrip(_ trip: Trip, at index: Int)
func deleteTrip(at index: Int)
func save()
func loadWithRecovery()
func recoverDataWithCrewMemberMigration() -> Bool

// ScheduleStore
func importSchedule(from html: String)
func parseNOCSchedule(_ html: String) -> [Trip]
func syncWithLogbook()
```

### Time Calculations

```swift
// FlightLeg
func blockMinutes() -> Int
func calculateFlightMinutes() -> Int
func parseTime(_ time: String) -> Date?

// Trip
var totalFlightMinutes: Int { get }
var totalBlockMinutes: Int { get }
func updateLeg(at index: Int, with leg: FlightLeg)
```

### Search & Filter

```swift
// LogbookSearchView
func searchMatches(trip: Trip, query: String, scope: SearchScope) -> Bool
func matchesAirports(trip: Trip, query: String) -> Bool
var filteredTrips: [Trip] { get }
```

### Navigation

```swift
// TabManager
func setupDefaultTabs()
func moveTab(_ tab: TabItem, toVisible: Bool)
func setRecentTab(_ tabID: String)
func updateTabArrays()

// ContentView
func contentForTab(_ tabId: String) -> some View
func checkIfShouldShowWelcome()
```

---

## 🗺️ Data Flow

### Trip Creation Flow
```
1. User taps "New Trip" → showTripSheet = true
2. TripFormView appears
3. User enters trip number, date, aircraft
4. Add flight legs (departure, arrival, times)
5. Tap "Save Trip"
6. ContentView.saveTripAndActivate()
7. LogBookStore.addTrip()
8. Save to JSON file
9. Sync to CloudKit
10. Update Watch complications
```

### Time Tracking Flow
```
1. Trip is active (status = .active)
2. User taps time field in ActiveTripBanner
3. Edit time dialog appears
4. User enters 4-digit time (e.g., "1430")
5. ContentView.onEditTime() validates
6. Updates leg in logpage structure
7. LogBookStore.updateTrip()
8. Recalculates flight/block times
9. Syncs to Watch
10. Updates Live Activity
```

### NOC Import Flow
```
1. User forwards NOC email
2. Copies HTML content
3. Opens NOC Import → pastes HTML
4. NOCParser.parseSchedule()
5. Extracts flights, times, aircraft
6. Generates Trip objects
7. ScheduleStore.importSchedule()
8. User reviews and confirms
9. Converts to LogBookStore trips
10. Sets scheduled times on legs
```

---

## 🎯 State Management

### Published Properties

**LogBookStore:**
- `@Published var trips: [Trip]`
- `@Published var perDiemRate: Double`

**ScheduleStore:**
- `@Published var scheduledTrips: [Trip]`
- `@Published var lastImportDate: Date?`

**TabManager:**
- `@Published var availableTabs: [TabItem]`
- `@Published var visibleTabs: [TabItem]`
- `@Published var moreTabs: [TabItem]`

**DutyTimerManager:**
- `@Published var isOnDuty: Bool`
- `@Published var dutyStartTime: Date?`
- `@Published var dutyElapsedSeconds: TimeInterval`

### AppStorage Keys

```swift
@AppStorage("hasEverHadTrips") var hasEverHadTrips = false
@AppStorage("hasSeenWelcome") var hasSeenWelcome = false
@AppStorage("TabConfiguration") // Tab customization
@AppStorage("RecentTabID") // Last used More tab
```

---

## 🐛 Common Issues & Solutions

### Issue: Trips not saving
**Location:** LogBookStore.swift  
**Solution:** Check file permissions in App Group container  
**Function:** `save()` line ~100

### Issue: Times not calculating
**Location:** FlightLeg.swift  
**Solution:** Verify time format (4 digits, e.g., "1430")  
**Function:** `parseTime()` line ~150

### Issue: NOC import fails
**Location:** NOCParser.swift  
**Solution:** Check HTML format matches parser rules  
**Function:** `parseSchedule()` line ~50

### Issue: Watch not syncing
**Location:** PhoneWatchConnectivity.swift  
**Solution:** Verify Watch Connectivity is active  
**Function:** `syncCurrentLegToWatch()` line ~200

### Issue: Tabs missing after update
**Location:** TabManager.swift  
**Solution:** Reset tab configuration  
**Function:** `resetToDefaults()` line ~280

---

## 📋 Testing Checklist

### Core Functionality
- [ ] Add new trip
- [ ] Edit existing trip
- [ ] Delete trip
- [ ] Calculate flight time
- [ ] Calculate block time
- [ ] Track duty time

### Data Persistence
- [ ] Save trips to disk
- [ ] Load trips on launch
- [ ] Recover from backup
- [ ] Export to CSV
- [ ] Import from CSV

### Compliance Tracking
- [ ] 30-day flight time
- [ ] Annual flight time
- [ ] Duty period limits
- [ ] Rest requirements

### New Features
- [ ] Welcome screen (first launch)
- [ ] Search trips (all scopes)
- [ ] Search filters
- [ ] Help view access
- [ ] Tab customization

### Watch Integration
- [ ] Sync active trip
- [ ] Update complications
- [ ] Send times from Watch
- [ ] Duty timer sync

---

## 🔄 Version History

**December 22, 2024:**
- ✅ Added LogbookWelcomeView for first-run experience
- ✅ Added LogbookSearchView with advanced filters
- ✅ Added HelpView with comprehensive help system
- ✅ Fixed StatBox naming conflict (SearchStatBox)
- ✅ Fixed Color.tertiaryLabel issue
- ✅ Added Help & Support section to More panel
- ✅ Updated TabManager with 31 total tabs

**Previous Updates:**
- Added Trip Generation settings
- Added Airport Database management
- Added Area Guide feature
- Implemented Liquid Glass design
- Enhanced Watch complications

---

## 📞 Support & Resources

**File This Document:** `ProPilot App - Function and File Index.md`  
**Last Updated:** December 22, 2024  
**Total Files:** 50+  
**Total Lines of Code:** ~25,000  
**Primary Language:** Swift  
**Framework:** SwiftUI  
**Minimum iOS:** 17.0  

**Quick Reference:**
- Main entry: `TheProPilotApp.swift`
- Data store: `LogBookStore.swift`
- Main view: `ContentView.swift`
- Navigation: `TabManager.swift`
- Trip model: `Trip.swift`
- Leg model: `FlightLeg.swift`

---

## 🎉 Summary

ProPilot is a comprehensive professional pilot logbook with:
- ✅ 31 accessible features via customizable tabs
- ✅ Advanced flight search with filters
- ✅ In-app help and support system
- ✅ First-run onboarding experience
- ✅ CloudKit sync across devices
- ✅ Apple Watch integration
- ✅ FAR 121 compliance tracking
- ✅ NOC schedule integration
- ✅ Auto-time logging via GPS
- ✅ Document scanning
- ✅ CSV import/export
- ✅ Customizable per diem tracking

**Architecture:** Clean MVVM with SwiftUI  
**Storage:** CloudKit + Local JSON  
**Platform:** iOS 17+ (iPhone & iPad)  
**Watch:** watchOS 10+  

---

**End of Index** ✈️

// TripGenerationService.swift - Smart Trip Detection and Generation from NOC Roster
import Foundation
import Combine
import UserNotifications

// MARK: - Trip Generation Service
class TripGenerationService: ObservableObject {
    static let shared = TripGenerationService()
    
    // MARK: - Published Properties
    @Published var pendingTrips: [PendingRosterTrip] = []
    @Published var isProcessing: Bool = false
    @Published var lastProcessedDate: Date?
    @Published var detectionStatus: String = "Idle"
    
    // MARK: - Dependencies
    private var settings: TripGenerationSettings { TripGenerationSettings.shared }
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults
    private let pendingTripsKey = "PendingRosterTrips"
    private let dismissedPendingTripsKey = "DismissedPendingTripIdentifiers"
    private let dismissedManager = DismissedRosterItemsManager.shared
    private var dismissedPendingIdentifiers: Set<String> = []
    
    // MARK: - Initialization
    private init() {
        if let groupDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
            self.userDefaults = groupDefaults
        } else {
            self.userDefaults = .standard
        }
        
        loadDismissedIdentifiers()
        loadPendingTrips()
        setupNOCSyncObserver()
    }
    
    // MARK: - Dismissed Identifiers Management
    private func loadDismissedIdentifiers() {
        if let identifiers = userDefaults.stringArray(forKey: dismissedPendingTripsKey) {
            dismissedPendingIdentifiers = Set(identifiers)
            print("📋 Loaded \(dismissedPendingIdentifiers.count) dismissed roster items")
            
            // Clean up old dismissed identifiers (older than 30 days)
            cleanupOldDismissedIdentifiers()
        }
    }
    
    private func saveDismissedIdentifiers() {
        userDefaults.set(Array(dismissedPendingIdentifiers), forKey: dismissedPendingTripsKey)
        userDefaults.synchronize()
    }
    
    /// Remove dismissed identifiers older than 30 days
    private func cleanupOldDismissedIdentifiers() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffString = dateFormatter.string(from: thirtyDaysAgo)
        
        let originalCount = dismissedPendingIdentifiers.count
        dismissedPendingIdentifiers = dismissedPendingIdentifiers.filter { identifier in
            // Identifier format: "UJ318_20251202"
            guard let dateString = identifier.split(separator: "_").last else { return true }
            return String(dateString) >= cutoffString
        }
        
        let removedCount = originalCount - dismissedPendingIdentifiers.count
        if removedCount > 0 {
            print("🧹 Cleaned up \(removedCount) old dismissed identifiers")
            saveDismissedIdentifiers()
        }
    }
    
    /// Check if a trip identifier (tripNumber + date combo) was previously dismissed
    private func isDismissedPendingTrip(_ tripNumber: String, date: Date) -> Bool {
        let identifier = makePendingTripIdentifier(tripNumber, date: date)
        return dismissedPendingIdentifiers.contains(identifier)
    }
    
    /// Create a unique identifier for a pending trip
    private func makePendingTripIdentifier(_ tripNumber: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return "\(tripNumber)_\(dateFormatter.string(from: date))"
    }
    
    // MARK: - NOC Sync Observer
    private func setupNOCSyncObserver() {
        NotificationCenter.default.publisher(for: .nocSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      self.settings.enableRosterTripGeneration,
                      let userInfo = notification.userInfo,
                      let success = userInfo["success"] as? Bool,
                      success else { return }
                
                print("📅 NOC sync completed - checking for new trips...")
                self.processRosterForNewTrips()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Processing Logic
    
    /// Process roster items and detect new trips
    func processRosterForNewTrips(scheduleStore: ScheduleStore? = nil, logbookStore: LogBookStore? = nil) {
        guard settings.enableRosterTripGeneration else {
            detectionStatus = "Trip generation disabled"
            return
        }
        
        isProcessing = true
        detectionStatus = "Scanning roster..."
        
        // We need access to ScheduleStore to get roster items
        // This would typically be injected or accessed via environment
        // For now, we'll post a notification requesting the data
        
        NotificationCenter.default.post(
            name: .requestRosterDataForTripGeneration,
            object: nil
        )
    }
    


    /// Process roster items (called when data is available)
    func processRosterItems(_ items: [BasicScheduleItem], existingTrips: [Trip]) {
        isProcessing = true
        detectionStatus = "Analyzing \(items.count) roster items..."
        
        // Filter to only actual flights
        let flightItems = items.filter { isActualFlight($0) }
        print("📊 Found \(flightItems.count) actual flights in roster")
        
        // ✅ Filter out dismissed items
        let nonDismissedFlights = flightItems.filter { !dismissedManager.isDismissed($0) }
        print("📊 After filtering dismissed: \(nonDismissedFlights.count) flights")
        
        // Apply time filter based on user settings
        let cutoffDate = settings.tripDetectionTimeFilter.cutoffDate
        let filteredByTime = nonDismissedFlights.filter { flight in
            // Filter by blockIn (when flight ends)
            guard flight.blockIn > cutoffDate else { return false }
            
            // Also filter by blockOut (showTime) - don't suggest trips that already departed
            let graceHours = settings.tripDetectionTimeFilter.staleShowTimeHours
            let showTimeCutoff = Date().addingTimeInterval(-Double(graceHours) * 3600)
            
            if flight.blockOut < showTimeCutoff {
                print("🗑️ Skipping \(flight.tripNumber) - departed \(flight.blockOut), stale")
                return false
            }
            
            return true
        }
        print("📊 After time filter (\(settings.tripDetectionTimeFilter.displayName)): \(filteredByTime.count) flights")
        
        // Group flights into trips (by date/duty period)
        let groupedTrips = groupFlightsIntoTrips(filteredByTime)
        print("📊 Grouped into \(groupedTrips.count) potential trips")
        
        // Process each trip group as a whole (not individual flights)
        var pendingNew: [PendingRosterTrip] = []
        var continuationPrompts: [ContinuationPrompt] = []
        
        for tripGroup in groupedTrips {
            guard let firstFlight = tripGroup.first else { continue }
            
            // Get the primary trip number for this group (most common, or first)
            let primaryTripNumber = getMostCommonTripNumber(tripGroup) ?? firstFlight.tripNumber
            
            // Check if this trip was previously dismissed
            if isDismissedPendingTrip(primaryTripNumber, date: firstFlight.date) {
                print("⏭️ Skipping \(primaryTripNumber) (\(tripGroup.count) legs) - previously dismissed")
                continue
            }
            
            // Check if FIRST flight continues an existing trip in the logbook
            let continuationResult = detectContinuation(for: firstFlight, existingTrips: existingTrips)
            
            switch continuationResult {
            case .askUserAboutContinuation(let prompt):
                // First flight continues an existing trip - prompt user
                continuationPrompts.append(prompt)
                print("🔀 Continuation detected: \(primaryTripNumber) continues Trip #\(prompt.existingTrip.tripNumber)")
                
                // If there are more flights in this group, they'll be handled as additional continuations
                // or added when user approves the continuation
                
            case .autoContinuation:
                // Future: auto-add without asking
                break
                
            case .newTrip:
                // Check if this trip already exists in logbook
                let alreadyExists = existingTrips.contains { existing in
                    let sameDay = Calendar.current.isDate(existing.date, inSameDayAs: firstFlight.date)
                    let sameDeparture = existing.legs.first?.departure == firstFlight.departure
                    
                    // Also check if trip numbers match (for multi-leg trips)
                    let sameTripNumber = existing.tripNumber == primaryTripNumber ||
                                         existing.legs.contains { $0.flightNumber == primaryTripNumber }
                    
                    return sameDay && (sameDeparture || sameTripNumber)
                }
                
                if !alreadyExists {
                    // Create ONE pending trip with ALL flights in the group
                    let pending = createPendingTrip(from: tripGroup)
                    pendingNew.append(pending)
                    print("📋 New trip: \(primaryTripNumber) with \(tripGroup.count) leg(s)")
                    print("   Route: \(pending.routeSummary)")
                } else {
                    print("⏭️ Skipping \(primaryTripNumber) - already exists in logbook")
                }
            }
        }
        
        print("📊 Final: \(pendingNew.count) new trips, \(continuationPrompts.count) continuations detected")
        
        // Update pending trips list
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Merge with existing pending trips (avoid duplicates)
            for newPending in pendingNew {
                if !self.pendingTrips.contains(where: { $0.tripDate == newPending.tripDate && $0.tripNumber == newPending.tripNumber }) {
                    self.pendingTrips.append(newPending)
                }
            }
            
            self.savePendingTrips()
            self.isProcessing = false
            self.lastProcessedDate = Date()
            self.detectionStatus = "Found \(pendingNew.count) new trip(s), \(continuationPrompts.count) continuation(s)"
            
            // Notify if new trips detected
            if !pendingNew.isEmpty && self.settings.notifyOnNewTripsDetected {
                self.notifyNewTripsDetected(pendingNew)
            }
            
            // Post notification for new trips
            if !pendingNew.isEmpty {
                NotificationCenter.default.post(
                    name: .newRosterTripsDetected,
                    object: nil,
                    userInfo: ["trips": pendingNew]
                )
            }
            
            // ✅ Post notification for continuations
            if !continuationPrompts.isEmpty {
                NotificationCenter.default.post(
                    name: .continuationPromptsDetected,
                    object: nil,
                    userInfo: ["prompts": continuationPrompts]
                )
            }
        }
    }
    
    // MARK: - Flight Filtering Logic
    
    /// Determines if a schedule item is an actual flight (not rest, duty marker, etc.)
    func isActualFlight(_ item: BasicScheduleItem) -> Bool {
        // EXCLUDE by status
        guard item.status == .activeTrip || item.status == .deadhead else {
            return false
        }
        
        // If deadheads are disabled, exclude them
        if item.status == .deadhead && !settings.includeDeadheads {
            return false
        }
        
        let tripNumber = item.tripNumber.uppercased()
        
        // EXCLUDE known non-flight items
        let excludePatterns = [
            "ON DUTY", "OFF DUTY", "REST", "DAY OFF", "WOFF",
            "VACATION", "VAC", "SICK", "TRAINING", "TRG",
            "GROUND", "GRD", "STANDBY", "STB", "UNKNOWN"
        ]
        
        for pattern in excludePatterns {
            if tripNumber.contains(pattern) {
                return false
            }
        }
        
        // EXCLUDE 20h+ block times (duty period placeholders)
        if item.totalBlockTime >= (20 * 3600) {
            return false
        }
        
        // REQUIRE valid airport pair
        guard !item.departure.isEmpty && !item.arrival.isEmpty else {
            return false
        }
        
        // REQUIRE flight number pattern (UJ followed by digits, or just 3-4 digits)
        let hasFlightNumber = tripNumber.contains("UJ") ||
                              tripNumber.range(of: #"^\d{3,4}"#, options: .regularExpression) != nil ||
                              tripNumber.range(of: #"[A-Z]{2}\d+"#, options: .regularExpression) != nil
        
        return hasFlightNumber
    }
    
    // MARK: - Trip Grouping Logic
    
    /// Group individual flights into logical trips (by date/duty period)
    private func groupFlightsIntoTrips(_ flights: [BasicScheduleItem]) -> [[BasicScheduleItem]] {
        guard !flights.isEmpty else { return [] }
        
        // Sort by date
        let sorted = flights.sorted { $0.date < $1.date }
        
        var trips: [[BasicScheduleItem]] = []
        var currentTrip: [BasicScheduleItem] = []
        var lastFlightEnd: Date?
        
        for flight in sorted {
            // Start new trip if:
            // 1. First flight
            // 2. Gap > 12 hours from last flight
            // 3. Different calendar date (new duty day)
            
            let shouldStartNewTrip: Bool
            
            if let lastEnd = lastFlightEnd {
                let gap = flight.date.timeIntervalSince(lastEnd)
                let hoursGap = gap / 3600
                
                // Check if different calendar day
                let calendar = Calendar.current
                let sameDay = calendar.isDate(flight.date, inSameDayAs: lastEnd)
                
                shouldStartNewTrip = hoursGap > 12 || !sameDay
            } else {
                shouldStartNewTrip = true
            }
            
            if shouldStartNewTrip && !currentTrip.isEmpty {
                trips.append(currentTrip)
                currentTrip = []
            }
            
            currentTrip.append(flight)
            lastFlightEnd = flight.blockIn
        }
        
        // Don't forget the last trip
        if !currentTrip.isEmpty {
            trips.append(currentTrip)
        }
        
        return trips
    }
    
    // MARK: - Duplicate Detection
    
    /// Get the most common trip number from a group of flights
    private func getMostCommonTripNumber(_ flights: [BasicScheduleItem]) -> String? {
        guard !flights.isEmpty else { return nil }
        
        // Count occurrences of each trip number
        var counts: [String: Int] = [:]
        for flight in flights {
            let tripNum = extractCleanFlightNumber(flight.tripNumber)
            counts[tripNum, default: 0] += 1
        }
        
        // Return the most common one
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Filter out trips that already exist in the logbook
    private func filterExistingTrips(_ tripGroups: [[BasicScheduleItem]], existingTrips: [Trip]) -> [[BasicScheduleItem]] {
        return tripGroups.filter { group in
            guard let firstFlight = group.first else { return false }
            
            // Check if a trip exists with same date and similar route
            let tripDate = firstFlight.date
            let firstDeparture = firstFlight.departure
            
            let exists = existingTrips.contains { existing in
                // Same calendar day
                let sameDay = Calendar.current.isDate(existing.date, inSameDayAs: tripDate)
                
                // Same first departure
                let sameDeparture = existing.legs.first?.departure == firstDeparture
                
                return sameDay && sameDeparture
            }
            
            return !exists
        }
    }
    
    // MARK: - Pending Trip Creation
    
    /// Create a PendingRosterTrip from grouped flights
    private func createPendingTrip(from flights: [BasicScheduleItem]) -> PendingRosterTrip {
        let legs = flights.map { flight -> PendingLeg in
            PendingLeg(
                id: UUID(),
                flightNumber: extractCleanFlightNumber(flight.tripNumber),
                departure: flight.departure,
                arrival: flight.arrival,
                scheduledOut: flight.blockOut,
                scheduledIn: flight.blockIn,
                isDeadhead: flight.status == .deadhead,
                rosterSourceId: flight.id.uuidString
            )
        }
        
        let totalBlock = flights.reduce(0) { $0 + Int(max(0, $1.totalBlockTime) / 60) }
        let showTime = flights.first?.blockOut
        
        // Use the most common trip number, or the first one if all different
        let tripNumber = getMostCommonTripNumber(flights) ??
                         extractCleanFlightNumber(flights.first?.tripNumber ?? "Unknown")
        
        return PendingRosterTrip(
            id: UUID(),
            detectedDate: Date(),
            tripDate: flights.first?.date ?? Date(),
            tripNumber: tripNumber,
            legs: legs,
            totalBlockMinutes: totalBlock,
            showTime: showTime,
            rosterSourceIds: flights.map { $0.id.uuidString },
            alarmSettings: settings.defaultAlarmSettings,
            userAction: .pending
        )
    }
    
    /// Extract clean flight number from roster trip number
    private func extractCleanFlightNumber(_ input: String) -> String {
        // Remove aircraft registration if present (e.g., "UJ743 (N12345)" -> "UJ743")
        let withoutReg = input.components(separatedBy: "(").first ?? input
        return withoutReg.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Continuation Detection
    
    /// Detect if a flight might be a continuation of an existing trip
    private func detectContinuation(for flight: BasicScheduleItem, existingTrips: [Trip]) -> ContinuationDetectionResult {
        // Look for trips on the same day or previous day
        let calendar = Calendar.current
        let flightDate = calendar.startOfDay(for: flight.date)
        
        for trip in existingTrips {
            let tripDate = calendar.startOfDay(for: trip.date)
            
            // Check if same day or next day
            let daysDiff = calendar.dateComponents([.day], from: tripDate, to: flightDate).day ?? 0
            guard daysDiff >= 0 && daysDiff <= 1 else { continue }
            
            // Check if this flight departs from where the trip ended
            guard let lastLeg = trip.legs.last else { continue }
            
            if lastLeg.arrival == flight.departure {
                // This might be a continuation!
                let timeGap = flight.date.timeIntervalSince(trip.legs.last?.scheduledIn ?? trip.date)
                let hoursGap = timeGap / 3600
                
                // If gap is reasonable (< 4 hours), ask user
                if hoursGap > 0 && hoursGap < 4 {
                    let prompt = ContinuationPrompt(
                        newFlight: flight,
                        existingTrip: trip,
                        matchReason: "This flight departs from \(flight.departure) where trip \(trip.tripNumber) ended.",
                        confidence: .high
                    )
                    return .askUserAboutContinuation(prompt)
                }
            }
        }
        
        return .newTrip
    }
    
    /// Add a flight as a new leg to an existing trip
    func addLegToTrip(flight: BasicScheduleItem, trip: Trip, logbookStore: LogBookStore) {
        var leg = FlightLeg()
        leg.id = UUID()
        leg.departure = flight.departure
        leg.arrival = flight.arrival
        leg.flightNumber = extractCleanFlightNumber(flight.tripNumber)
        leg.isDeadhead = flight.status == .deadhead
        leg.scheduledOut = flight.blockOut
        leg.scheduledIn = flight.blockIn
        leg.scheduledFlightNumber = leg.flightNumber
        leg.rosterSourceId = flight.id.uuidString
        leg.status = .standby
        
        // Pre-populate times if enabled
        if settings.prePopulateScheduledTimes {
            let formatter = DateFormatter()
            formatter.dateFormat = "HHmm"
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            leg.outTime = formatter.string(from: flight.blockOut)
            leg.inTime = formatter.string(from: flight.blockIn)
        }
        
        // Add to trip
        if let tripIndex = logbookStore.trips.firstIndex(where: { $0.id == trip.id }) {
            logbookStore.trips[tripIndex].legs.append(leg)
            logbookStore.objectWillChange.send()
            
            print("✅ Added leg \(leg.flightNumber) to trip \(trip.tripNumber)")
            
            NotificationCenter.default.post(
                name: .tripUpdatedWithNewLeg,
                object: nil,
                userInfo: ["trip": trip, "leg": leg]
            )
        }
    }
    
    // MARK: - Public API for Continuation Handling
    
    /// Create a trip directly from a roster flight (used when user chooses "Create Separate Trip")
    func createTripFromContinuationPrompt(_ flight: BasicScheduleItem, logbookStore: LogBookStore) {
        let pending = createPendingTrip(from: [flight])
        approvePendingTrip(pending, logbookStore: logbookStore)
    }

    
    // MARK: - Trip Creation
    
    /// Create actual Trip from PendingRosterTrip
    func createTrip(from pending: PendingRosterTrip, logbookStore: LogBookStore) -> Trip {
        // Convert pending legs to FlightLegs
        var flightLegs: [FlightLeg] = []
        
        for (index, pendingLeg) in pending.legs.enumerated() {
            var leg = FlightLeg()
            leg.id = UUID()
            leg.departure = pendingLeg.departure
            leg.arrival = pendingLeg.arrival
            leg.flightNumber = pendingLeg.flightNumber
            leg.isDeadhead = pendingLeg.isDeadhead
            
            // Set scheduled times
            leg.scheduledOut = pendingLeg.scheduledOut
            leg.scheduledIn = pendingLeg.scheduledIn
            leg.scheduledFlightNumber = pendingLeg.flightNumber
            leg.rosterSourceId = pendingLeg.rosterSourceId
            
            // Pre-populate actual times from schedule if enabled
            if settings.prePopulateScheduledTimes {
                let formatter = DateFormatter()
                formatter.dateFormat = "HHmm"
                formatter.timeZone = TimeZone(identifier: "UTC")
                
                leg.outTime = formatter.string(from: pendingLeg.scheduledOut)
                leg.inTime = formatter.string(from: pendingLeg.scheduledIn)
            }
            
            // Set leg status: first leg active, rest standby
            leg.status = (index == 0) ? .active : .standby
            
            flightLegs.append(leg)
        }
        
        // Create the trip
        let trip = Trip(
            tripNumber: pending.tripNumber,
            aircraft: settings.defaultAircraft,
            date: pending.tripDate,
            tatStart: "",
            crew: [],
            notes: "Created from NOC roster",
            legs: flightLegs,
            tripType: pending.legs.allSatisfy({ $0.isDeadhead }) ? .deadhead : .operating,
            status: .planning
        )
        
        // Add to logbook
        logbookStore.addTrip(trip)
        
        // Remove from pending
        removePendingTrip(pending)
        
        // Schedule alarm if enabled
        if let alarmSettings = pending.alarmSettings, alarmSettings.enabled {
            scheduleShowTimeAlarm(for: trip, settings: alarmSettings)
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .rosterTripCreated,
            object: nil,
            userInfo: ["trip": trip]
        )
        
        print("✅ Created trip \(trip.tripNumber) from roster with \(trip.legs.count) legs")
        
        return trip
    }
    
    // MARK: - Pending Trip Management
    
    func approvePendingTrip(_ pending: PendingRosterTrip, logbookStore: LogBookStore) {
        _ = createTrip(from: pending, logbookStore: logbookStore)
    }
    
    func dismissPendingTrip(_ pending: PendingRosterTrip) {
        if let index = pendingTrips.firstIndex(where: { $0.id == pending.id }) {
            pendingTrips[index].userAction = .dismissed
        }
        
        // Track this trip as dismissed so it won't reappear
        let identifier = makePendingTripIdentifier(pending.tripNumber, date: pending.tripDate)
        dismissedPendingIdentifiers.insert(identifier)
        saveDismissedIdentifiers()
        
        print("🚫 Dismissed trip \(pending.tripNumber) - won't appear again")
        
        removePendingTrip(pending)
        
        // Post notification for UI feedback
        NotificationCenter.default.post(
            name: .pendingTripDismissed,
            object: nil,
            userInfo: ["tripNumber": pending.tripNumber]
        )
    }
    
    func remindLater(_ pending: PendingRosterTrip) {
        if let index = pendingTrips.firstIndex(where: { $0.id == pending.id }) {
            pendingTrips[index].userAction = .remindLater
        }
        savePendingTrips()
    }
    
    private func removePendingTrip(_ pending: PendingRosterTrip) {
        pendingTrips.removeAll { $0.id == pending.id }
        savePendingTrips()
    }
    
    func clearAllPendingTrips() {
        pendingTrips.removeAll()
        savePendingTrips()
    }
    
    // MARK: - Persistence
    
    private func savePendingTrips() {
        if let data = try? JSONEncoder().encode(pendingTrips) {
            userDefaults.set(data, forKey: pendingTripsKey)
            userDefaults.synchronize()
        }
    }
    
    private func loadPendingTrips() {
        guard let data = userDefaults.data(forKey: pendingTripsKey),
              let trips = try? JSONDecoder().decode([PendingRosterTrip].self, from: data) else {
            return
        }
        
        let now = Date()
        let graceHours = settings.tripDetectionTimeFilter.staleShowTimeHours
        let staleCutoff = now.addingTimeInterval(-Double(graceHours) * 3600)
        
        // Filter out:
        // 1. Trips older than 7 days (by trip date)
        // 2. Trips where showTime has passed beyond grace period
        // 3. Trips that aren't pending
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        
        let validTrips = trips.filter { trip in
            // Must be pending action
            guard trip.userAction == .pending else { return false }
            
            // Trip date must be within 7 days
            guard trip.tripDate > sevenDaysAgo else {
                print("🗑️ Filtering stale trip \(trip.tripNumber) - trip date too old")
                return false
            }
            
            // If we have a showTime, check if it's stale
            if let showTime = trip.showTime {
                if showTime < staleCutoff {
                    print("🗑️ Filtering stale trip \(trip.tripNumber) - showTime \(showTime) passed \(graceHours)+ hours ago")
                    return false
                }
            }
            
            return true
        }
        
        let filteredCount = trips.count - validTrips.count
        if filteredCount > 0 {
            print("🧹 Auto-cleared \(filteredCount) stale pending trip(s)")
        }
        
        pendingTrips = validTrips
        
        // Save cleaned list
        if filteredCount > 0 {
            savePendingTrips()
        }
    }
    
    // MARK: - Notifications
    
    private func notifyNewTripsDetected(_ trips: [PendingRosterTrip]) {
        let content = UNMutableNotificationContent()
        
        if trips.count == 1 {
            let trip = trips[0]
            content.title = "New Trip Detected"
            content.body = "\(trip.tripNumber) on \(formatDate(trip.tripDate)) - \(trip.legCount) leg(s)"
        } else {
            content.title = "\(trips.count) New Trips Detected"
            content.body = "Tap to review and create trips from your roster"
        }
        
        content.sound = .default
        content.categoryIdentifier = "NEW_ROSTER_TRIP"
        
        let request = UNNotificationRequest(
            identifier: "roster-trip-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleShowTimeAlarm(for trip: Trip, settings: TripAlarmSettings) {
        guard let firstLeg = trip.legs.first,
              let showTime = firstLeg.scheduledOut else { return }
        
        let alarmTime = showTime.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
        
        // Don't schedule if alarm time is in the past
        guard alarmTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Show Time Reminder"
        content.body = "Trip \(trip.tripNumber) - Show time in \(settings.reminderMinutesBefore) minutes"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(settings.alarmSound.systemSoundName))
        content.categoryIdentifier = "SHOW_TIME_ALARM"
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "showtime-\(trip.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule show time alarm: \(error)")
            } else {
                print("✅ Scheduled show time alarm for \(alarmTime)")
            }
        }
        
        // Also post to Watch for countdown display
        if settings.showCountdownOnWatch {
            NotificationCenter.default.post(
                name: .watchShowTimeCountdown,
                object: nil,
                userInfo: [
                    "tripNumber": trip.tripNumber,
                    "showTime": showTime,
                    "alarmTime": alarmTime
                ]
            )
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Roster Data Listener Setup
extension TripGenerationService {
    func setupRosterDataListener(logbookStore: LogBookStore) {
        NotificationCenter.default.addObserver(
            forName: .rosterDataReadyForTripGeneration,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  self.settings.enableRosterTripGeneration,
                  let items = notification.userInfo?["items"] as? [BasicScheduleItem] else {
                return
            }
            print("📅 Received roster data - checking for new trips...")
            self.processRosterItems(items, existingTrips: logbookStore.trips)
        }
        print("✅ Trip generation roster listener setup complete")
    }
}

// MARK: - Additional Notification Names
extension Notification.Name {
    static let rosterDataReadyForTripGeneration = Notification.Name("rosterDataReadyForTripGeneration")
    static let requestRosterDataForTripGeneration = Notification.Name("requestRosterDataForTripGeneration")
    static let watchShowTimeCountdown = Notification.Name("watchShowTimeCountdown")
    static let continuationPromptsDetected = Notification.Name("continuationPromptsDetected")
    static let tripUpdatedWithNewLeg = Notification.Name("tripUpdatedWithNewLeg")
    static let pendingTripDismissed = Notification.Name("pendingTripDismissed")
}

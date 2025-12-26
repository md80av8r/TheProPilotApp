import SwiftUI
import Combine

// MARK: - Basic Schedule Item Model
struct BasicScheduleItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let tripNumber: String
    let departure: String
    let arrival: String
    let blockOut: Date
    let blockOff: Date
    let blockOn: Date
    let blockIn: Date
    let summary: String
    let status: ScheduleStatus
    let scheduledBlockMinutes: Int?  // BLH from roster (e.g., "01:35" = 95 minutes)

    // MARK: - New NOC Roster Fields (CloudKit sync)
    let nocUID: String?                    // Server's unique ID (e.g., "117760")
    let nocTimestamp: Date?                // DTSTAMP - when roster was last modified on server
    let isLastLegOfTrip: Bool              // RD: X marker - indicates end of trip
    let tripGroupId: String?               // Groups legs into same trip (e.g., "UJ325")
    let checkInTime: Date?                 // CI - Show time
    let checkOutTime: Date?                // CO - Release time
    let scheduledDeparture: Date?          // STD - Wheels off time
    let scheduledArrival: Date?            // STA - Wheels on time
    let scheduledFlightMinutes: Int?       // Duration (flight time, not block)
    let aircraftType: String?              // e.g., "M88", "M83"
    let tailNumber: String?                // e.g., "N832US"

    // MARK: - Legacy Initializer (backward compatibility)
    init(date: Date, tripNumber: String, departure: String, arrival: String,
         blockOut: Date, blockOff: Date, blockOn: Date, blockIn: Date, summary: String,
         scheduledBlockMinutes: Int? = nil) {
        self.id = UUID()
        self.date = date
        self.tripNumber = tripNumber
        self.departure = departure
        self.arrival = arrival
        self.blockOut = blockOut
        self.blockOff = blockOff
        self.blockOn = blockOn
        self.blockIn = blockIn
        self.summary = summary
        self.status = .activeTrip
        self.scheduledBlockMinutes = scheduledBlockMinutes
        // New fields default to nil/false
        self.nocUID = nil
        self.nocTimestamp = nil
        self.isLastLegOfTrip = false
        self.tripGroupId = nil
        self.checkInTime = nil
        self.checkOutTime = nil
        self.scheduledDeparture = nil
        self.scheduledArrival = nil
        self.scheduledFlightMinutes = nil
        self.aircraftType = nil
        self.tailNumber = nil
    }

    init(date: Date, tripNumber: String, departure: String, arrival: String,
         blockOut: Date, blockOff: Date, blockOn: Date, blockIn: Date, summary: String,
         status: ScheduleStatus, scheduledBlockMinutes: Int? = nil) {
        self.id = UUID()
        self.date = date
        self.tripNumber = tripNumber
        self.departure = departure
        self.arrival = arrival
        self.blockOut = blockOut
        self.blockOff = blockOff
        self.blockOn = blockOn
        self.blockIn = blockIn
        self.summary = summary
        self.status = status
        self.scheduledBlockMinutes = scheduledBlockMinutes
        // New fields default to nil/false
        self.nocUID = nil
        self.nocTimestamp = nil
        self.isLastLegOfTrip = false
        self.tripGroupId = nil
        self.checkInTime = nil
        self.checkOutTime = nil
        self.scheduledDeparture = nil
        self.scheduledArrival = nil
        self.scheduledFlightMinutes = nil
        self.aircraftType = nil
        self.tailNumber = nil
    }

    // MARK: - Full Initializer with all NOC fields
    init(date: Date, tripNumber: String, departure: String, arrival: String,
         blockOut: Date, blockOff: Date, blockOn: Date, blockIn: Date, summary: String,
         status: ScheduleStatus, scheduledBlockMinutes: Int?,
         nocUID: String?, nocTimestamp: Date?, isLastLegOfTrip: Bool, tripGroupId: String?,
         checkInTime: Date?, checkOutTime: Date?, scheduledDeparture: Date?, scheduledArrival: Date?,
         scheduledFlightMinutes: Int?, aircraftType: String?, tailNumber: String?) {
        self.id = UUID()
        self.date = date
        self.tripNumber = tripNumber
        self.departure = departure
        self.arrival = arrival
        self.blockOut = blockOut
        self.blockOff = blockOff
        self.blockOn = blockOn
        self.blockIn = blockIn
        self.summary = summary
        self.status = status
        self.scheduledBlockMinutes = scheduledBlockMinutes
        self.nocUID = nocUID
        self.nocTimestamp = nocTimestamp
        self.isLastLegOfTrip = isLastLegOfTrip
        self.tripGroupId = tripGroupId
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.scheduledFlightMinutes = scheduledFlightMinutes
        self.aircraftType = aircraftType
        self.tailNumber = tailNumber
    }
    
    // MARK: - Computed Properties for Display
    
    /// Duration from start to end (duty period for most items, NOT block time)
    var totalDuration: TimeInterval {
        blockIn.timeIntervalSince(blockOut)
    }
    
    /// Legacy property - renamed for clarity but kept for compatibility
    var totalBlockTime: TimeInterval {
        totalDuration
    }
    
    /// Returns true if this is an actual flight (has block time)
    var isActualFlight: Bool {
        status == .activeTrip && !tripNumber.uppercased().contains("ON DUTY") &&
        !tripNumber.uppercased().contains("REST") && !tripNumber.uppercased().contains("OFF")
    }
    
    /// The appropriate duration label based on item type
    var durationLabel: String {
        switch status {
        case .activeTrip:
            // For flights, this is duty period (show to release), not block
            return "Duty Period"
        case .onDuty:
            return "Duty Period"
        case .deadhead:
            return "Duty Period"
        case .other:
            // Check if it's rest
            let upper = tripNumber.uppercased()
            if upper.contains("REST") {
                return "Rest Period"
            } else if upper.contains("OFF") || upper.contains("WOFF") {
                return "Day Off"
            } else {
                return "Duration"
            }
        }
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    /// Check if duration should be displayed (hide for day off, etc.)
    var shouldShowDuration: Bool {
        let upper = tripNumber.uppercased()
        // Don't show duration for day off items or items with 24h+ placeholder durations
        if upper.contains("OFF") && !upper.contains("WOFF") && totalDuration >= 23 * 3600 {
            return false
        }
        return true
    }
    
    /// The time label - "Show Time" for flights, "Start" for duty periods
    var startTimeLabel: String {
        switch status {
        case .activeTrip, .deadhead:
            return "Show Time"
        case .onDuty:
            return "Duty Start"
        case .other:
            let upper = tripNumber.uppercased()
            if upper.contains("REST") {
                return "Rest Start"
            }
            return "Start"
        }
    }
    
    /// The end time label
    var endTimeLabel: String {
        switch status {
        case .activeTrip, .deadhead:
            return "Release"
        case .onDuty:
            return "Duty End"
        case .other:
            let upper = tripNumber.uppercased()
            if upper.contains("REST") {
                return "Rest End"
            }
            return "End"
        }
    }
    
    /// Display title that cleans up "KOFF" → "Off Duty"
    var displayTitle: String {
        let upper = tripNumber.uppercased()
        if upper.contains("OFF") && !upper.contains("WOFF") {
            return "Off Duty"
        }
        return tripNumber
    }
    
    /// Get formatted display for Off Duty items with home base on second line
    /// Usage: In your view, call this method passing the airline settings home base
    func formattedOffDutyDisplay(homeBase: String) -> (line1: String, line2: String?) {
        let upper = tripNumber.uppercased()
        if upper.contains("OFF") && !upper.contains("WOFF") {
            return ("Off Duty", homeBase.isEmpty ? nil : homeBase)
        }
        return (displayTitle, nil)
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: BasicScheduleItem, rhs: BasicScheduleItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.tripNumber == rhs.tripNumber &&
        lhs.departure == rhs.departure &&
        lhs.arrival == rhs.arrival
    }
    
    enum ScheduleStatus: String, Codable, CaseIterable {
        case activeTrip
        case onDuty
        case deadhead
        case other
        
        var color: Color {
            switch self {
            case .activeTrip: return .red
            case .onDuty: return .blue
            case .deadhead: return .orange
            case .other: return .gray
            }
        }
        
        var displayName: String {
            switch self {
            case .activeTrip: return "Flight"
            case .onDuty: return "Duty"
            case .deadhead: return "Deadhead"
            case .other: return "Other"
            }
        }
    }
}

// MARK: - Roster Trip Model
struct RosterTrip: Identifiable {
    let id: UUID
    let tripNumber: String
    let legs: [BasicScheduleItem]
    let startDate: Date
    let endDate: Date
    let totalBlockTime: TimeInterval
    let departure: String
    let arrival: String
    
    var legCount: Int { legs.count }
    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }
    var formattedBlockTime: String {
        let hours = Int(totalBlockTime) / 3600
        let minutes = (Int(totalBlockTime) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}


// MARK: - NOC Settings Store (MOVED TO NOCSettingsStore.swift)
// Note: The NOCSettingsStore class has been moved to its own file
// to avoid duplication and improve code organization.

// MARK: - Schedule Store
class ScheduleStore: ObservableObject {
    @Published var items: [BasicScheduleItem] = [] { didSet { saveScheduleItems() } }
    @Published var parseStatus: String = "No data"
    @Published var lastUpdateTime: Date?
    
    private let scheduleItemsKey = "ScheduleItems"
    private let scheduleMetadataKey = "ScheduleMetadata"
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    private var cancellables = Set<AnyCancellable>()
    private weak var nocSettings: NOCSettingsStore?
    
    init(settings: NOCSettingsStore) {
        self.nocSettings = settings
        loadScheduleItems()
        setupNOCDataBinding(settings)
    }
    
    private func setupNOCDataBinding(_ settings: NOCSettingsStore) {
        settings.$calendarData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let data = data else {
                    self?.items = []
                    self?.parseStatus = "No calendar data"
                    return
                }
                self?.parseStatus = "Parsing \(data.count) bytes..."
                self?.parseICS(data)
            }
            .store(in: &cancellables)
    }
    
    private func checkForNewTrips() {
        // ✅ Use futureItems for trip generation (today + future only)
        // Past items should be visible in calendar but not generate new trips
        let validItems = futureItems
        
        NotificationCenter.default.post(
            name: .rosterDataReadyForTripGeneration,
            object: nil,
            userInfo: ["items": validItems]
        )
        
        let dismissedCount = items.count - validItems.count
        let pastCount = nonDismissedItems.count - validItems.count
        if dismissedCount > 0 || pastCount > 0 {
            print("📋 Posted \(validItems.count) future roster items (\(dismissedCount) dismissed, \(pastCount) past)")
        } else {
            print("📋 Posted \(validItems.count) roster items for trip generation")
        }
    }
    
    var actualTrips: [RosterTrip] {
        // ✅ Start with non-dismissed items only
        let sortedItems = nonDismissedItems.sorted { $0.date < $1.date }
        var trips: [RosterTrip] = []
        var currentTripLegs: [BasicScheduleItem] = []
        
        for item in sortedItems {
            switch item.status {
            case .activeTrip:
                currentTripLegs.append(item)
            case .onDuty, .other:
                if !currentTripLegs.isEmpty {
                    let trip = createTripFromLegs(currentTripLegs)
                    trips.append(trip)
                    currentTripLegs = []
                }
            case .deadhead:
                currentTripLegs.append(item)
            }
        }
        
        if !currentTripLegs.isEmpty {
            let trip = createTripFromLegs(currentTripLegs)
            trips.append(trip)
        }
        
        return trips
    }
    
    private func createTripFromLegs(_ legs: [BasicScheduleItem]) -> RosterTrip {
        guard !legs.isEmpty else {
            fatalError("Cannot create trip from empty legs")
        }
        
        let tripNumber = determineTripNumber(from: legs)
        
        return RosterTrip(
            id: UUID(),
            tripNumber: tripNumber,
            legs: legs,
            startDate: legs.first!.date,
            endDate: legs.last!.date,
            totalBlockTime: legs.reduce(0) { $0 + $1.totalBlockTime },
            departure: legs.first!.departure,
            arrival: legs.last!.arrival
        )
    }
    
    private func determineTripNumber(from legs: [BasicScheduleItem]) -> String {
        let flightNumbers = legs.compactMap { extractFlightNumber($0.tripNumber) }
        
        if flightNumbers.isEmpty { return "Unknown" }
        
        let counts = Dictionary(grouping: flightNumbers, by: { $0 })
            .mapValues { $0.count }
        
        return counts.max(by: { $0.value < $1.value })?.key ?? flightNumbers.first!
    }
    
    private func extractFlightNumber(_ input: String) -> String? {
        let patterns = [
            #"JU\d+"#,
            #"USA\d+"#,
            #"[A-Z]{2}\d+"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                return String(input[Range(match.range, in: input)!])
            }
        }
        return nil
    }
    
    private func saveScheduleItems() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults?.set(data, forKey: scheduleItemsKey)
            
            let metadata: [String: Any] = [
                "lastSaved": Date(),
                "itemCount": items.count,
                "dateRange": items.isEmpty ? "Empty" : "\(items.first!.date) to \(items.last!.date)"
            ]
            userDefaults?.set(metadata, forKey: scheduleMetadataKey)
            userDefaults?.synchronize()
            
            print("✅ Saved \(items.count) schedule items")
        } catch {
            print("❌ Failed to save schedule items: \(error)")
        }
    }
    
    private func loadScheduleItems() {
        guard let data = userDefaults?.data(forKey: scheduleItemsKey) else {
            parseStatus = "No offline schedule found"
            return
        }
        
        do {
            let loadedItems = try JSONDecoder().decode([BasicScheduleItem].self, from: data)
            
            // Keep 1 year of history (365 days)
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let currentItems = loadedItems.filter { $0.date >= oneYearAgo }
            
            items = currentItems.sorted { $0.date < $1.date }
            
            if let metadata = userDefaults?.dictionary(forKey: scheduleMetadataKey),
               let lastSaved = metadata["lastSaved"] as? Date {
                lastUpdateTime = lastSaved
                let daysSince = Date().timeIntervalSince(lastSaved) / (24 * 60 * 60)
                parseStatus = "Loaded \(currentItems.count) offline trips (\(Int(daysSince)) days old)"
            } else {
                parseStatus = "Loaded \(currentItems.count) offline trips"
            }
            
            print("📅 Loaded \(currentItems.count) schedule items (1 year history)")
        } catch {
            parseStatus = "Failed to load offline schedule: \(error.localizedDescription)"
        }
    }
    
    func clearOfflineSchedule() {
        userDefaults?.removeObject(forKey: scheduleItemsKey)
        userDefaults?.removeObject(forKey: scheduleMetadataKey)
        userDefaults?.synchronize()
        items = []
        parseStatus = "Offline schedule cleared"
    }
    
    /// Clear duplicates from the current schedule
    /// Call this to remove legacy duplicates where IATA/ICAO codes weren't normalized
    func deduplicateExistingItems() {
        var seenKeys = Set<String>()
        var uniqueItems: [BasicScheduleItem] = []
        var duplicateCount = 0
        
        // Sort by date so newer items are kept
        let sortedItems = items.sorted { $0.date > $1.date }
        
        for item in sortedItems {
            let key = createDeduplicationKey(
                date: item.date,
                tripNumber: item.tripNumber,
                departure: item.departure,
                arrival: item.arrival
            )
            
            if !seenKeys.contains(key) {
                uniqueItems.append(item)
                seenKeys.insert(key)
            } else {
                duplicateCount += 1
                print("🗑️ Removing duplicate: \(item.tripNumber) \(item.departure)→\(item.arrival)")
            }
        }
        
        if duplicateCount > 0 {
            items = uniqueItems.sorted { $0.date < $1.date }
            print("✅ Removed \(duplicateCount) duplicate schedule items")
            parseStatus = "Removed \(duplicateCount) duplicates"
        } else {
            print("✅ No duplicates found")
        }
    }

    private func parseICS(_ data: Data) {
        guard let content = String(data: data, encoding: .utf8) else {
            parseStatus = "Failed to decode calendar data"
            return
        }
        
        parseStatus = "Processing calendar content..."
        
        // ✅ STEP 1: Extract REST and OFF duty events using ICalFlightParser
        let (flights, events) = ICalFlightParser.parseCalendarString(content)
        
        // ✅ STEP 2: Update REST status manager
        RestStatusManager.shared.updateFromNOCEvents(events, flights: flights)
        print("🛏️ Updated REST status from \(events.count) NOC events")
        
        // ✅ STEP 3: Update OFF duty status manager
        OffDutyStatusManager.shared.updateFromNOCEvents(events, flights: flights)
        print("🏠 Updated OFF duty status from \(events.count) NOC events")
        
        let lines = content.components(separatedBy: .newlines)
        var currentEvent: [String: String] = [:]
        var parsed: [BasicScheduleItem] = []
        var eventCount = 0

        func resetEvent() { currentEvent = [:] }
        resetEvent()

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine == "BEGIN:VEVENT" {
                resetEvent()
                eventCount += 1
            } else if trimmedLine == "END:VEVENT" {
                if let item = makeEnhancedItem(from: currentEvent) {
                    parsed.append(item)
                }
            } else if trimmedLine.contains(":") {
                let parts = trimmedLine.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let key = parts[0].components(separatedBy: ";")[0]
                    let value = parts[1]
                    
                    if key == "DESCRIPTION" {
                        currentEvent[key] = value
                    } else {
                        currentEvent[key] = value
                    }
                }
            } else if trimmedLine.hasPrefix(" ") && currentEvent["DESCRIPTION"] != nil {
                currentEvent["DESCRIPTION"]! += "\n" + trimmedLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // MERGE new items with existing archived items
            // This preserves historical data while adding new/updated items
            let existingItems = self.items
            var mergedItems: [BasicScheduleItem] = []
            
            // Create a lookup by normalized key for deduplication
            // Uses createDeduplicationKey which normalizes IATA→ICAO to prevent duplicates
            var seenKeys = Set<String>()
            
            // Add new items first (they have the latest data)
            for item in parsed {
                let key = self.createDeduplicationKey(
                    date: item.date,
                    tripNumber: item.tripNumber,
                    departure: item.departure,
                    arrival: item.arrival
                )
                if !seenKeys.contains(key) {
                    mergedItems.append(item)
                    seenKeys.insert(key)
                    // DEBUG: Commented out excessive print statement (fires for every roster item)
                    // print("📝 Added new item: \(item.tripNumber) \(item.departure)→\(item.arrival)")
                } else {
                    // DEBUG: Commented out excessive print statement
                    // print("⚠️ Skipped duplicate: \(item.tripNumber) \(item.departure)→\(item.arrival)")
                }
            }
            
            // Add existing items that aren't duplicates (preserves historical data)
            for item in existingItems {
                let key = self.createDeduplicationKey(
                    date: item.date,
                    tripNumber: item.tripNumber,
                    departure: item.departure,
                    arrival: item.arrival
                )
                if !seenKeys.contains(key) {
                    mergedItems.append(item)
                    seenKeys.insert(key)
                }
            }
            
            // Sort by date and apply retention limit (keep 1 year of history)
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            self.items = mergedItems
                .filter { $0.date >= oneYearAgo }
                .sorted { $0.date < $1.date }
            
            self.lastUpdateTime = Date()
            
            let newCount = parsed.count
            let archivedCount = self.items.count - newCount
            if archivedCount > 0 {
                self.parseStatus = "Loaded \(newCount) new + \(archivedCount) archived items"
            } else {
                self.parseStatus = "Loaded \(parsed.count) trips from \(eventCount) events"
            }
            
            print("📅 Schedule merged: \(newCount) new, \(self.items.count) total (keeping 1 year history)")
            
            self.checkForNewTrips()
        }
    }

    private func makeEnhancedItem(from dict: [String: String]) -> BasicScheduleItem? {
        guard let summary = dict["SUMMARY"],
              let dtStart = dict["DTSTART"],
              let dtEnd = dict["DTEND"] else {
            return nil
        }

        guard let startDate = parseICSDate(dtStart),
              let endDate = parseICSDate(dtEnd) else {
            return nil
        }

        // Extract UID and DTSTAMP from the event
        let nocUID = dict["UID"]
        let nocTimestamp = dict["DTSTAMP"].flatMap { parseICSDate($0) }

        if let description = dict["DESCRIPTION"], !description.isEmpty {
            let parsedInfo = parseDetailedFlightInfo(description, summary: summary, startDate: startDate)

            let taxiOut = 15 * 60.0
            let taxiIn = 10 * 60.0

            return BasicScheduleItem(
                date: startDate,
                tripNumber: parsedInfo.tripNumber,
                departure: parsedInfo.departure,
                arrival: parsedInfo.arrival,
                blockOut: startDate,
                blockOff: startDate.addingTimeInterval(taxiOut),
                blockOn: endDate.addingTimeInterval(-taxiIn),
                blockIn: endDate,
                summary: "\(summary) | \(description)",
                status: parsedInfo.status,
                scheduledBlockMinutes: parsedInfo.blhMinutes,
                nocUID: nocUID,
                nocTimestamp: nocTimestamp,
                isLastLegOfTrip: parsedInfo.isLastLegOfTrip,
                tripGroupId: parsedInfo.tripGroupId,
                checkInTime: parsedInfo.checkInTime,
                checkOutTime: parsedInfo.checkOutTime,
                scheduledDeparture: parsedInfo.scheduledDeparture,
                scheduledArrival: parsedInfo.scheduledArrival,
                scheduledFlightMinutes: parsedInfo.scheduledFlightMinutes,
                aircraftType: parsedInfo.aircraftType,
                tailNumber: parsedInfo.tailNumber
            )
        } else {
            let (tripNumber, departure, arrival, status) = parseUSAJetSummary(summary)

            let taxiOut = 15 * 60.0
            let taxiIn = 10 * 60.0

            return BasicScheduleItem(
                date: startDate,
                tripNumber: tripNumber,
                departure: departure,
                arrival: arrival,
                blockOut: startDate,
                blockOff: startDate.addingTimeInterval(taxiOut),
                blockOn: endDate.addingTimeInterval(-taxiIn),
                blockIn: endDate,
                summary: summary,
                status: status,
                scheduledBlockMinutes: nil,
                nocUID: nocUID,
                nocTimestamp: nocTimestamp,
                isLastLegOfTrip: false,
                tripGroupId: nil,
                checkInTime: nil,
                checkOutTime: nil,
                scheduledDeparture: nil,
                scheduledArrival: nil,
                scheduledFlightMinutes: nil,
                aircraftType: nil,
                tailNumber: nil
            )
        }
    }
    
    // MARK: - Parsed Flight Info Result
    struct ParsedFlightInfo {
        let tripNumber: String
        let departure: String
        let arrival: String
        let status: BasicScheduleItem.ScheduleStatus
        let blhMinutes: Int?
        let isLastLegOfTrip: Bool
        let tripGroupId: String?
        let checkInTime: Date?
        let checkOutTime: Date?
        let scheduledDeparture: Date?
        let scheduledArrival: Date?
        let scheduledFlightMinutes: Int?
        let aircraftType: String?
        let tailNumber: String?
    }

    private func parseDetailedFlightInfo(_ description: String, summary: String, startDate: Date) -> ParsedFlightInfo {
        // Extracts all NOC fields from the DESCRIPTION field
        let lines = description.components(separatedBy: .newlines)

        // Non-airport keywords to exclude from airport code parsing
        let nonAirportKeywords = ["HOL", "HOLIDAY", "NEW", "YEAR", "DAY", "EVE", "OFF"]

        var tripNumber = "Unknown"
        var departure = ""
        var arrival = ""
        var status: BasicScheduleItem.ScheduleStatus = .activeTrip
        var blhMinutes: Int? = nil
        var scheduledFlightMinutes: Int? = nil
        var isLastLegOfTrip = false
        var tripGroupId: String? = nil
        var checkInTime: Date? = nil
        var checkOutTime: Date? = nil
        var scheduledDeparture: Date? = nil
        var scheduledArrival: Date? = nil
        var aircraftType: String? = nil
        var tailNumber: String? = nil

        // Join all lines for pattern matching (handles line wrapping)
        let fullDescription = description.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
        let upperDescription = fullDescription.uppercased()

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            // Extract flight info: "UJ518 YIP-LRD" pattern
            if let regex = try? NSRegularExpression(pattern: #"UJ(\d+).*?([A-Z]{3})\s*[-–]\s*([A-Z]{3})"#),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {

                if let flightRange = Range(match.range(at: 1), in: trimmedLine) {
                    tripNumber = "UJ" + String(trimmedLine[flightRange])
                    tripGroupId = tripNumber  // Use flight number as trip group ID
                }
                if let depRange = Range(match.range(at: 2), in: trimmedLine) {
                    let depCode = String(trimmedLine[depRange])
                    if !nonAirportKeywords.contains(depCode) {
                        departure = convertToICAO(depCode)
                    }
                }
                if let arrRange = Range(match.range(at: 3), in: trimmedLine) {
                    let arrCode = String(trimmedLine[arrRange])
                    if !nonAirportKeywords.contains(arrCode) {
                        arrival = convertToICAO(arrCode)
                    }
                }
                status = .activeTrip
            }

            // Extract BLH (Block Hours): "BLH: 01:35"
            if trimmedLine.contains("BLH") {
                if let blhRegex = try? NSRegularExpression(pattern: #"BLH[:\s]*(\d{1,2}):(\d{2})"#, options: .caseInsensitive),
                   let blhMatch = blhRegex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                    if let hoursRange = Range(blhMatch.range(at: 1), in: trimmedLine),
                       let minsRange = Range(blhMatch.range(at: 2), in: trimmedLine),
                       let hours = Int(trimmedLine[hoursRange]),
                       let mins = Int(trimmedLine[minsRange]) {
                        blhMinutes = hours * 60 + mins
                    }
                }
            }

            // Extract Duration (flight time): "Duration: 03:05"
            if trimmedLine.contains("DURATION") {
                if let durationRegex = try? NSRegularExpression(pattern: #"DURATION[:\s]*(\d{1,2}):(\d{2})"#, options: .caseInsensitive),
                   let durationMatch = durationRegex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                    if let hoursRange = Range(durationMatch.range(at: 1), in: trimmedLine),
                       let minsRange = Range(durationMatch.range(at: 2), in: trimmedLine),
                       let hours = Int(trimmedLine[hoursRange]),
                       let mins = Int(trimmedLine[minsRange]) {
                        scheduledFlightMinutes = hours * 60 + mins
                    }
                }
            }

            // Extract Aircraft: "Aircraft: M88 - MD-83 - N832US"
            if trimmedLine.contains("AIRCRAFT:") {
                let aircraftParts = trimmedLine.replacingOccurrences(of: "AIRCRAFT:", with: "")
                    .components(separatedBy: " - ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // First part is aircraft type (e.g., "M88")
                if let firstPart = aircraftParts.first {
                    aircraftType = firstPart
                }
                // Last part is tail number if starts with N (e.g., "N832US")
                if let lastPart = aircraftParts.last, lastPart.hasPrefix("N") {
                    tailNumber = lastPart
                    if tripNumber != "Unknown" {
                        tripNumber = "\(tripNumber) (\(lastPart))"
                    }
                }
            }

            // Detect status from content
            if trimmedLine.contains("REST") || trimmedLine.contains("OFF DUTY") || summary.uppercased().contains("REST") {
                status = .other
            } else if summary.uppercased().contains("ON DUTY") {
                status = .onDuty
            } else if extractFlightNumber(summary) != nil || extractFlightNumber(trimmedLine) != nil {
                status = .activeTrip
            }
        }

        // Extract RD: X marker for isLastLegOfTrip (critical for trip grouping!)
        // Pattern: "RD: X" or "RD: L,X" where X indicates last leg of trip
        if let rdRegex = try? NSRegularExpression(pattern: #"RD:\s*([A-Z,]+)"#, options: .caseInsensitive),
           let rdMatch = rdRegex.firstMatch(in: upperDescription, range: NSRange(upperDescription.startIndex..., in: upperDescription)),
           let rdRange = Range(rdMatch.range(at: 1), in: upperDescription) {
            let rdValue = String(upperDescription[rdRange])
            isLastLegOfTrip = rdValue.contains("X")
        }

        // Extract CI (Check-In/Show time): "CI 1645Z"
        if let ciRegex = try? NSRegularExpression(pattern: #"CI\s+(\d{4})Z"#, options: .caseInsensitive),
           let ciMatch = ciRegex.firstMatch(in: upperDescription, range: NSRange(upperDescription.startIndex..., in: upperDescription)),
           let ciRange = Range(ciMatch.range(at: 1), in: upperDescription) {
            let ciTimeStr = String(upperDescription[ciRange])
            checkInTime = parseZuluTime(ciTimeStr, referenceDate: startDate)
        }

        // Extract CO (Check-Out/Release time): "CO 0045Z"
        if let coRegex = try? NSRegularExpression(pattern: #"CO\s+(\d{4})Z"#, options: .caseInsensitive),
           let coMatch = coRegex.firstMatch(in: upperDescription, range: NSRange(upperDescription.startIndex..., in: upperDescription)),
           let coRange = Range(coMatch.range(at: 1), in: upperDescription) {
            let coTimeStr = String(upperDescription[coRange])
            checkOutTime = parseZuluTime(coTimeStr, referenceDate: startDate)
        }

        // Extract STD (Scheduled Time of Departure/Wheels Off): "STD 1715Z"
        if let stdRegex = try? NSRegularExpression(pattern: #"STD\s+(\d{4})Z"#, options: .caseInsensitive),
           let stdMatch = stdRegex.firstMatch(in: upperDescription, range: NSRange(upperDescription.startIndex..., in: upperDescription)),
           let stdRange = Range(stdMatch.range(at: 1), in: upperDescription) {
            let stdTimeStr = String(upperDescription[stdRange])
            scheduledDeparture = parseZuluTime(stdTimeStr, referenceDate: startDate)
        }

        // Extract STA (Scheduled Time of Arrival/Wheels On): "STA 1945Z"
        if let staRegex = try? NSRegularExpression(pattern: #"STA\s+(\d{4})Z"#, options: .caseInsensitive),
           let staMatch = staRegex.firstMatch(in: upperDescription, range: NSRange(upperDescription.startIndex..., in: upperDescription)),
           let staRange = Range(staMatch.range(at: 1), in: upperDescription) {
            let staTimeStr = String(upperDescription[staRange])
            scheduledArrival = parseZuluTime(staTimeStr, referenceDate: startDate)
        }

        // Fallback to summary parsing if we couldn't extract info from description
        if tripNumber == "Unknown" || departure.isEmpty {
            let fallback = parseUSAJetSummary(summary)
            return ParsedFlightInfo(
                tripNumber: fallback.0,
                departure: fallback.1,
                arrival: fallback.2,
                status: fallback.3,
                blhMinutes: blhMinutes,
                isLastLegOfTrip: isLastLegOfTrip,
                tripGroupId: tripGroupId,
                checkInTime: checkInTime,
                checkOutTime: checkOutTime,
                scheduledDeparture: scheduledDeparture,
                scheduledArrival: scheduledArrival,
                scheduledFlightMinutes: scheduledFlightMinutes,
                aircraftType: aircraftType,
                tailNumber: tailNumber
            )
        }

        return ParsedFlightInfo(
            tripNumber: tripNumber,
            departure: departure,
            arrival: arrival,
            status: status,
            blhMinutes: blhMinutes,
            isLastLegOfTrip: isLastLegOfTrip,
            tripGroupId: tripGroupId,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            scheduledDeparture: scheduledDeparture,
            scheduledArrival: scheduledArrival,
            scheduledFlightMinutes: scheduledFlightMinutes,
            aircraftType: aircraftType,
            tailNumber: tailNumber
        )
    }

    /// Parse a Zulu time string (e.g., "1645") to a Date using the reference date
    private func parseZuluTime(_ timeStr: String, referenceDate: Date) -> Date? {
        guard timeStr.count == 4,
              let hours = Int(timeStr.prefix(2)),
              let minutes = Int(timeStr.suffix(2)),
              hours < 24 && minutes < 60 else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hours
        components.minute = minutes
        components.second = 0

        guard var result = calendar.date(from: components) else { return nil }

        // Handle overnight flights - if time is earlier than reference, it's probably next day
        if result < referenceDate {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        }

        return result
    }
    
    // MARK: - Comprehensive IATA to ICAO Conversion
    
    /// Master IATA→ICAO mapping dictionary
    /// This is used to normalize all airport codes to ICAO format
    private static let iataToIcaoMap: [String: String] = [
        // USA - Major Hubs
        "YIP": "KYIP", "DTW": "KDTW", "ORD": "KORD", "MDW": "KMDW", "LAX": "KLAX",
        "LAS": "KLAS", "PHX": "KPHX", "DEN": "KDEN", "ATL": "KATL", "MIA": "KMIA",
        "JFK": "KJFK", "LGA": "KLGA", "EWR": "KEWR", "BOS": "KBOS", "DCA": "KDCA",
        "IAD": "KIAD", "BWI": "KBWI", "PHL": "KPHL", "CLT": "KCLT", "MSP": "KMSP",
        "SEA": "KSEA", "SFO": "KSFO", "PDX": "KPDX", "LRD": "KLRD", "ELP": "KELP",
        "SAT": "KSAT", "AUS": "KAUS", "DFW": "KDFW", "DAL": "KDAL", "IAH": "KIAH",
        "HOU": "KHOU", "FLL": "KFLL", "MCO": "KMCO", "TPA": "KTPA",
        
        // USA - Additional commonly used
        "SDF": "KSDF",  // Louisville Muhammad Ali International
        "IND": "KIND",  // Indianapolis International
        "CVG": "KCVG",  // Cincinnati/Northern Kentucky
        "CMH": "KCMH",  // Columbus John Glenn
        "CLE": "KCLE",  // Cleveland Hopkins
        "PIT": "KPIT",  // Pittsburgh International
        "MEM": "KMEM",  // Memphis International
        "BNA": "KBNA",  // Nashville International
        "STL": "KSTL",  // St. Louis Lambert
        "MCI": "KMCI",  // Kansas City International
        "OMA": "KOMA",  // Omaha Eppley
        "DSM": "KDSM",  // Des Moines International
        "MSN": "KMSN",  // Madison Dane County
        "MKE": "KMKE",  // Milwaukee Mitchell
        "GRR": "KGRR",  // Grand Rapids Gerald R. Ford
        "ABQ": "KABQ",  // Albuquerque International
        "TUS": "KTUS",  // Tucson International
        "SAN": "KSAN",  // San Diego International
        "OAK": "KOAK",  // Oakland International
        "SJC": "KSJC",  // San Jose Mineta
        "SMF": "KSMF",  // Sacramento International
        "RNO": "KRNO",  // Reno-Tahoe International
        "SLC": "KSLC",  // Salt Lake City International
        "BOI": "KBOI",  // Boise Airport
        "PSC": "KPSC",  // Tri-Cities (Pasco)
        "GEG": "KGEG",  // Spokane International
        "ANC": "PANC", // Anchorage Ted Stevens
        "HNL": "PHNL", // Honolulu Daniel K. Inouye
        "OGG": "PHOG", // Maui Kahului
        
        // USA - Texas/Border region (USA Jet frequent)
        "CRP": "KCRP",  // Corpus Christi
        "MFE": "KMFE",  // McAllen Miller
        "BRO": "KBRO",  // Brownsville/South Padre
        "HRL": "KHRL",  // Valley International (Harlingen)
        "MAF": "KMAF",  // Midland International
        "LBB": "KLBB",  // Lubbock Preston Smith
        "AMA": "KAMA",  // Amarillo Rick Husband
        "OKC": "KOKC",  // Oklahoma City Will Rogers
        "TUL": "KTUL",  // Tulsa International
        "ICT": "KICT",  // Wichita Dwight D. Eisenhower
        "LIT": "KLIT",  // Little Rock Bill & Hillary Clinton
        "XNA": "KXNA",  // Northwest Arkansas Regional
        "SHV": "KSHV",  // Shreveport Regional
        "BTR": "KBTR",  // Baton Rouge Metropolitan
        "MSY": "KMSY",  // New Orleans Louis Armstrong
        "GPT": "KGPT",  // Gulfport-Biloxi
        "MOB": "KMOB",  // Mobile Regional
        "JAN": "KJAN",  // Jackson-Medgar Wiley Evers
        "BHM": "KBHM",  // Birmingham-Shuttlesworth
        "HSV": "KHSV",  // Huntsville International
        "CHA": "KCHA",  // Chattanooga Metropolitan
        "TYS": "KTYS",  // McGhee Tyson (Knoxville)
        "GSO": "KGSO",  // Piedmont Triad
        "RDU": "KRDU",  // Raleigh-Durham
        "RIC": "KRIC",  // Richmond International
        "ORF": "KORF",  // Norfolk International
        "JAX": "KJAX",  // Jacksonville International
        "RSW": "KRSW",  // Southwest Florida (Fort Myers)
        "PBI": "KPBI",  // Palm Beach International
        "SRQ": "KSRQ",  // Sarasota-Bradenton
        "SAV": "KSAV",  // Savannah/Hilton Head
        "CHS": "KCHS",  // Charleston International
        "MYR": "KMYR",  // Myrtle Beach International
        "CAE": "KCAE",  // Columbia Metropolitan
        "AGS": "KAGS",  // Augusta Regional
        "HUF": "KHUF",  // Terre Haute Regional (Indiana)
        "YQG": "CYQG",  // Windsor International (Ontario) - added to Canada section too

        
        // Mexico - All common IATA codes
        "MEX": "MMMX",  // Mexico City International
        "CUN": "MMUN",  // Cancún International
        "GDL": "MMGL",  // Guadalajara International
        "TIJ": "MMTJ",  // Tijuana General Abelardo
        "MTY": "MMMY",  // Monterrey International
        "PVR": "MMPR",  // Puerto Vallarta
        "CZM": "MMCZ",  // Cozumel International
        "MZT": "MMMZ",  // Mazatlán General Rafael
        "SJD": "MMSD",  // Los Cabos International
        "QRO": "MMQT",  // Querétaro Intercontinental
        "CUU": "MMCU",  // Chihuahua General Roberto Fierro ⭐ ADDED
        "BJX": "MMLO",  // León/Guanajuato Del Bajío
        "AGU": "MMAS",  // Aguascalientes
        "SLP": "MMSP",  // San Luis Potosí
        "ZCL": "MMZC",  // Zacatecas
        "CUL": "MMCL",  // Culiacán
        "HMO": "MMHO",  // Hermosillo
        "OAX": "MMOX",  // Oaxaca
        "PBC": "MMPB",  // Puebla
        "VER": "MMVR",  // Veracruz
        "VSA": "MMVA",  // Villahermosa
        "MID": "MMMD",  // Mérida
        "CME": "MMCE",  // Ciudad del Carmen
        "TAM": "MMTM",  // Tampico
        "NLD": "MMNL",  // Nuevo Laredo
        "REX": "MMRX",  // Reynosa
        "MAM": "MMMA",  // Matamoros
        "LAP": "MMLP",  // La Paz
        "ZLO": "MMZO",  // Manzanillo
        "ZIH": "MMZH",  // Ixtapa-Zihuatanejo
        "ACA": "MMAA",  // Acapulco
        "TAP": "MMTP",  // Tapachula
        "SLW": "MMIO",  // Los Mochis International
        
        // Canada
        "YYZ": "CYYZ",  // Toronto Pearson
        "YVR": "CYVR",  // Vancouver
        "YUL": "CYUL",  // Montreal-Trudeau
        "YYC": "CYYC",  // Calgary
        "YEG": "CYEG",  // Edmonton
        "YOW": "CYOW",  // Ottawa
        "YWG": "CYWG",  // Winnipeg
        "YHZ": "CYHZ",  // Halifax
        "YQB": "CYQB",  // Quebec City
        "YXE": "CYXE",  // Saskatoon
        "YQR": "CYQR",  // Regina
        "YLW": "CYLW",  // Kelowna
        "YXX": "CYXX",  // Abbotsford
        "YYJ": "CYYJ",  // Victoria
        "YZF": "CYZF",  // Yellowknife
        "YXY": "CYXY",  // Whitehorse
        
        // Caribbean
        "NAS": "MYNN",  // Nassau (Bahamas)
        "SJU": "TJSJ",  // San Juan (Puerto Rico)
        "STT": "TIST",  // St. Thomas
        "STX": "TISX",  // St. Croix
        "SXM": "TNCM",  // St. Maarten
        "CUR": "TNCC",  // Curaçao
        "AUA": "TNCA",  // Aruba
        "BON": "TNCB",  // Bonaire
        "POS": "TTPP",  // Port of Spain (Trinidad)
        "BGI": "TBPB",  // Barbados
        "PUJ": "MDPC",  // Punta Cana (Dominican Republic)
        "SDQ": "MDSD",  // Santo Domingo
        "STI": "MDST",  // Santiago (Dominican Republic)
        "KIN": "MKJP",  // Kingston (Jamaica)
        "MBJ": "MKJS",  // Montego Bay
        "HAV": "MUHA",  // Havana (Cuba)
        "GCM": "MWCR",  // Grand Cayman
        "BZE": "MZBZ",  // Belize City
        
        // Central America
        "GUA": "MGGT",  // Guatemala City
        "SAL": "MSLP",  // San Salvador
        "TGU": "MHTG",  // Tegucigalpa (Honduras)
        "MGA": "MNMG",  // Managua (Nicaragua)
        "SJO": "MROC",  // San José (Costa Rica)
        "PTY": "MPTO",  // Panama City Tocumen
    ]
    
    private func convertToICAO(_ code: String) -> String {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🔧 FIX: Filter out non-airport keywords FIRST before any conversion
        let nonAirportKeywords = ["HOL", "HOLIDAY", "NEW", "YEAR", "DAY", "EVE", "OFF", "DUTY"]
        if nonAirportKeywords.contains(cleanCode) {
            return cleanCode  // Return as-is, don't convert to airport code
        }
        
        // Already ICAO format (4 letters starting with K, C, M, P, T, etc.)
        if cleanCode.count == 4 {
            let firstChar = cleanCode.first!
            if "KCMPTOELSW".contains(firstChar) {
                return cleanCode
            }
        }
        
        // Check user-added mappings first (highest priority)
        if let userICAO = UserAirportCodeMappings.shared.getICAO(for: cleanCode) {
            print("📍 Using user mapping: \(cleanCode) → \(userICAO)")
            return userICAO
        }
        
        // Look up in our built-in IATA map
        if let icao = Self.iataToIcaoMap[cleanCode] {
            return icao
        }
        
        // If 3-letter US code, try adding K prefix
        if cleanCode.count == 3 && cleanCode.allSatisfy({ $0.isLetter }) {
            return "K" + cleanCode
        }
        
        return cleanCode
    }
    
    /// Create a deduplication key that normalizes airport codes
    /// This prevents duplicates when same flight appears with IATA vs ICAO codes
    private func createDeduplicationKey(date: Date, tripNumber: String, departure: String, arrival: String) -> String {
        // Normalize both departure and arrival to ICAO
        let normalizedDep = convertToICAO(departure)
        let normalizedArr = convertToICAO(arrival)
        
        // Extract just the flight number portion (remove aircraft tail)
        let cleanTripNumber = tripNumber.components(separatedBy: " (").first ?? tripNumber
        
        // Use date rounded to nearest hour (to handle slight time variations)
        let roundedDate = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded() * 3600)
        
        return "\(roundedDate.timeIntervalSince1970)-\(cleanTripNumber)-\(normalizedDep)-\(normalizedArr)"
    }
    
    private func parseUSAJetSummary(_ summary: String) -> (tripNumber: String, departure: String, arrival: String, status: BasicScheduleItem.ScheduleStatus) {
        let upperSummary = summary.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // USA Jet specific duty codes mapping
        let dutyCodeMap: [String: (type: String, status: BasicScheduleItem.ScheduleStatus)] = [
            "OND": ("On Duty", .onDuty),
            "OFF": ("Off Duty", .other),
            "KOFF": ("Off Duty", .other),  // 🔥 ADDED: KOFF from NOC calendar
            "LB1": ("Line 1", .activeTrip),
            "LB2": ("Line 2", .activeTrip),
            "LB3": ("Line 3", .activeTrip),
            "LB4": ("Line 4", .activeTrip),
            "LB5": ("Line 5", .activeTrip),
            "LB6": ("Line 6", .activeTrip),
            "REST": ("Rest", .other),
            "WOFF": ("Working Day Off", .other),
            "VAC": ("Vacation", .other),
            "SICK": ("Sick", .other),
            "TRG": ("Training", .onDuty),
            "SIMR": ("Simulator", .onDuty),
            "GRD": ("Ground", .onDuty),
            "STB": ("Standby", .onDuty),
            "DH": ("Deadhead", .deadhead),
            "DEADHEAD": ("Deadhead", .deadhead)
        ]
        
        var tripNumber = "Unknown"
        var departure = ""
        var arrival = ""
        var status: BasicScheduleItem.ScheduleStatus = .other
        
        // Split the summary into components
        let components = upperSummary.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Parse the first component (duty code or flight number)
        if let firstComponent = components.first {
            // Check if it's a known duty code
            if let dutyInfo = dutyCodeMap[firstComponent] {
                tripNumber = dutyInfo.type
                status = dutyInfo.status
            }
            // ✅ FIXED: Generic flight number parsing (works with any airline code, not just "JUS")
            // Matches patterns like: JUS123, AAL456, DAL789, etc.
            else if let regex = try? NSRegularExpression(pattern: #"([A-Z]{2,3})(\d+)"#),
                    let match = regex.firstMatch(in: firstComponent, range: NSRange(firstComponent.startIndex..., in: firstComponent)),
                    let codeRange = Range(match.range(at: 1), in: firstComponent),
                    let numRange = Range(match.range(at: 2), in: firstComponent) {
                let code = String(firstComponent[codeRange])
                let number = String(firstComponent[numRange])
                tripNumber = "\(code)\(number)"  // Keep full flight number
                status = .activeTrip
            }
            // Check if it starts with just digits (trip number)
            else if let regex = try? NSRegularExpression(pattern: #"^(\d{3,4})"#),
                    let match = regex.firstMatch(in: firstComponent, range: NSRange(firstComponent.startIndex..., in: firstComponent)),
                    let range = Range(match.range(at: 1), in: firstComponent) {
                tripNumber = String(firstComponent[range])
                status = .activeTrip
            }
            // Use the raw code as trip identifier
            else {
                tripNumber = firstComponent
            }
        }
        
        // 🔧 FIX: List of non-airport keywords to exclude from airport parsing
        let nonAirportKeywords = ["HOL", "HOLIDAY", "NEW", "YEAR", "DAY", "EVE", "OFF"]
        
        // Extract airport codes from remaining components
        var airports: [String] = []
        for component in components {
            // 🔧 FIX: Skip non-airport keywords before processing
            if nonAirportKeywords.contains(component) {
                continue
            }
            
            // Check if it's already an ICAO code (K + 3 letters)
            if component.hasPrefix("K") && component.count == 4 {
                airports.append(component)
            }
            // Check if it's a 3-letter IATA code
            else if component.count == 3 && component.allSatisfy(\.isLetter) {
                airports.append(convertToICAO(component))
            }
        }
        
        // Parse route information
        if airports.count >= 1 {
            departure = airports[0]
            // ✅ REMOVED: No longer assume KYIP as default return base
            // Each airline configures their own home base in settings
            if airports.count >= 2 {
                arrival = airports[1]
            }
        }
        
        // Special handling for specific patterns
        if upperSummary.contains("WOFF") {
            status = .other
            tripNumber = "Working Day Off"
        } else if upperSummary.contains("REST") {
            status = .other
            tripNumber = "Rest"
        } else if upperSummary.contains("VAC") {
            status = .other
            tripNumber = "Vacation"
        }
        
        // Enhanced trip number formatting
        if tripNumber.hasPrefix("LB") {
            let lineNumber = tripNumber.replacingOccurrences(of: "LB", with: "")
            tripNumber = "Line \(lineNumber)"
            status = .activeTrip
        }
        
        return (tripNumber, departure, arrival, status)
    }
    
    private func parseICSDate(_ dateString: String) -> Date? {
        let cleanDateString = dateString.replacingOccurrences(of: "TZID=", with: "")
            .components(separatedBy: ":").last ?? dateString
        
        let formatters: [(String, TimeZone?)] = [
            ("yyyyMMdd'T'HHmmss'Z'", TimeZone(abbreviation: "UTC")),
            ("yyyyMMdd'T'HHmmss", TimeZone.current),
            ("yyyyMMdd", TimeZone.current)
        ]
        
        for (format, timeZone) in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = timeZone
            if let date = formatter.date(from: cleanDateString) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - Dismissed Items Filtering
extension ScheduleStore {
    /// Get only non-dismissed schedule items
    var nonDismissedItems: [BasicScheduleItem] {
        let dismissedManager = DismissedRosterItemsManager.shared
        return items.filter { item in
            !dismissedManager.isDismissed(item)
        }
    }
    
    /// Get items that should show in UI (non-dismissed)
    /// Now includes PAST dates so users can view historical schedule
    var visibleItems: [BasicScheduleItem] {
        let dismissedManager = DismissedRosterItemsManager.shared
        
        return items.filter { item in
            // Filter out dismissed items only - show ALL dates (past, today, future)
            !dismissedManager.isDismissed(item)
        }.sorted { $0.date < $1.date }
    }
    
    /// Get only future items (for trip generation)
    var futureItems: [BasicScheduleItem] {
        let dismissedManager = DismissedRosterItemsManager.shared
        let today = Calendar.current.startOfDay(for: Date())
        
        return items.filter { item in
            guard !dismissedManager.isDismissed(item) else { return false }
            return item.date >= today
        }
    }
    
    // 🔥 NEW: Check if currently in a rest or off-duty period
    /// Returns true if there's a current Off Duty, Rest, or WOFF event covering NOW
    var isCurrentlyInRestOrOffDuty: Bool {
        let now = Date()
        
        return nonDismissedItems.contains { item in
            let upper = item.tripNumber.uppercased()
            let isOffDutyType = upper.contains("OFF") || upper.contains("REST")
            
            // Check if the item time range covers NOW
            let coversNow = item.blockOut <= now && item.blockIn >= now
            
            if isOffDutyType && coversNow {
                print("🛏️ Currently in Rest/Off Duty: \(item.tripNumber)")
                print("   Start: \(item.blockOut.formatted(date: .abbreviated, time: .shortened))")
                print("   End: \(item.blockIn.formatted(date: .abbreviated, time: .shortened))")
                return true
            }
            
            return false
        }
    }
    
    /// Get items for a specific date range
    func items(from startDate: Date, to endDate: Date) -> [BasicScheduleItem] {
        let dismissedManager = DismissedRosterItemsManager.shared
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate).addingTimeInterval(86400) // Include end date
        
        return items.filter { item in
            guard !dismissedManager.isDismissed(item) else { return false }
            return item.date >= start && item.date < end
        }.sorted { $0.date < $1.date }
    }
    
    /// Get items for the past N days
    func pastItems(days: Int) -> [BasicScheduleItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let pastDate = Calendar.current.date(byAdding: .day, value: -days, to: today) ?? today
        return items(from: pastDate, to: today)
    }
}
// ═══════════════════════════════════════════════════════════════
// ADD THIS EXTENSION TO ScheduleStore
// Place it RIGHT AFTER the "Dismissed Items Filtering" extension
// ═══════════════════════════════════════════════════════════════

// Add this AFTER the closing brace of the "Dismissed Items Filtering" extension

// MARK: - Duty Status Management
extension ScheduleStore {
    /// Restore duty status from NOC calendar data
    /// Called after test operations to ensure clean state
    func restoreDutyStatusFromNOC() {
        print("🔄 ScheduleStore: Restoring duty status from NOC...")
        
        guard let nocSettings = nocSettings else {
            print("⚠️ NOC settings not available")
            return
        }
        
        guard let calendarData = nocSettings.calendarData else {
            print("⚠️ No NOC calendar data available")
            return
        }
        
        guard let content = String(data: calendarData, encoding: .utf8) else {
            print("⚠️ Failed to decode calendar data")
            return
        }
        
        let (flights, events) = ICalFlightParser.parseCalendarString(content)
        
        OffDutyStatusManager.shared.updateFromNOCEvents(events, flights: flights)
        RestStatusManager.shared.updateFromNOCEvents(events, flights: flights)
        
        print("✅ Duty status restored:")
        print("   OFF DUTY: \(OffDutyStatusManager.shared.isOffDuty)")
        print("   IN REST: \(RestStatusManager.shared.isInRest)")
        
        if OffDutyStatusManager.shared.isOffDuty {
            if let endTime = OffDutyStatusManager.shared.offDutyEndTime {
                print("   OFF DUTY ENDS: \(endTime)")
            }
        }
        
        if RestStatusManager.shared.isInRest {
            if let endTime = RestStatusManager.shared.restEndTime {
                print("   REST ENDS: \(endTime)")
            }
        }
    }
}
// DAYS OFF & REST PERIOD IMPROVEMENTS

// MARK: - Grouped Roster Display Model
/// Groups consecutive off days into a single display item
struct RosterDisplayGroup: Identifiable {
    let id = UUID()
    let items: [BasicScheduleItem]
    let groupType: GroupType
    
    enum GroupType {
        case singleItem
        case consecutiveOffDays
        case consecutiveRestDays
    }
    
    var isGrouped: Bool {
        items.count > 1
    }
    
    var displayTitle: String {
        switch groupType {
        case .singleItem:
            return items.first?.tripNumber ?? "Unknown"
        case .consecutiveOffDays:
            return "Off Duty"
        case .consecutiveRestDays:
            return "Rest Period"
        }
    }
    
    var startDate: Date {
        items.first?.blockOut ?? Date()
    }
    
    var endDate: Date {
        items.last?.blockIn ?? Date()
    }
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var daysCount: Int {
        items.count
    }
    
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if items.count == 1 {
            return formatter.string(from: startDate)
        } else {
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start)-\(end), 2025"
        }
    }
    
    var nextDutyDate: Date? {
        // Calculate when next duty period begins (after off days/rest ends)
        return endDate
    }
}

// MARK: - Enhanced Schedule Store with Grouping
extension ScheduleStore {
    
    /// Group roster items for display
    /// - Consecutive off days become a single group
    /// - Rest periods remain separate
    /// - Flight items remain separate
    func groupedDisplayItems() -> [RosterDisplayGroup] {
        var groups: [RosterDisplayGroup] = []
        var currentOffDays: [BasicScheduleItem] = []
        
        let sortedItems = visibleItems.sorted { $0.date < $1.date }
        
        for item in sortedItems {
            let itemType = classifyRosterItem(item)
            
            switch itemType {
            case .offDuty:
                // Accumulate consecutive off days
                currentOffDays.append(item)
                
            case .rest:
                // Flush any accumulated off days first
                if !currentOffDays.isEmpty {
                    groups.append(RosterDisplayGroup(
                        items: currentOffDays,
                        groupType: .consecutiveOffDays
                    ))
                    currentOffDays = []
                }
                // Add rest as single item
                groups.append(RosterDisplayGroup(
                    items: [item],
                    groupType: .singleItem
                ))
                
            case .flight, .onDuty, .other:
                // Flush any accumulated off days
                if !currentOffDays.isEmpty {
                    groups.append(RosterDisplayGroup(
                        items: currentOffDays,
                        groupType: .consecutiveOffDays
                    ))
                    currentOffDays = []
                }
                // Add as single item
                groups.append(RosterDisplayGroup(
                    items: [item],
                    groupType: .singleItem
                ))
            }
        }
        
        // Flush any remaining off days
        if !currentOffDays.isEmpty {
            groups.append(RosterDisplayGroup(
                items: currentOffDays,
                groupType: .consecutiveOffDays
            ))
        }
        
        return groups
    }
    
    /// Classify a roster item for grouping purposes
    private func classifyRosterItem(_ item: BasicScheduleItem) -> RosterItemType {
        let upper = item.tripNumber.uppercased()
        
        // Off duty detection
        if upper.contains("OFF") && !upper.contains("WOFF") && !upper.contains("OFF TIME") {
            // Check if it's actually a long placeholder (24h+)
            if item.totalDuration >= 23 * 3600 {
                return .offDuty
            }
        }
        
        // Rest detection
        if upper.contains("REST") {
            return .rest
        }
        
        // On duty detection
        if item.status == .onDuty || upper.contains("ON DUTY") {
            return .onDuty
        }
        
        // Flight detection
        if item.status == .activeTrip || item.status == .deadhead {
            return .flight
        }
        
        return .other
    }
    
    enum RosterItemType {
        case flight
        case offDuty
        case rest
        case onDuty
        case other
    }
    
    /// Get the current active roster item (rest or off duty)
    var currentRosterStatus: RosterStatusInfo? {
        let now = Date()
        
        // Find any roster item that is currently active
        for item in visibleItems {
            if item.blockOut <= now && item.blockIn > now {
                let type = classifyRosterItem(item)
                
                switch type {
                case .rest:
                    return RosterStatusInfo(
                        type: .rest,
                        startTime: item.blockOut,
                        endTime: item.blockIn,
                        location: item.departure
                    )
                case .offDuty:
                    // Find if part of a consecutive group
                    let groups = groupedDisplayItems()
                    if let group = groups.first(where: { $0.items.contains(where: { $0.id == item.id }) }),
                       group.groupType == .consecutiveOffDays {
                        return RosterStatusInfo(
                            type: .offDay,
                            startTime: group.startDate,
                            endTime: group.endDate,
                            location: "",
                            consecutiveDays: group.daysCount
                        )
                    }
                    return nil
                    
                case .onDuty:
                    return RosterStatusInfo(
                        type: .onDuty,
                        startTime: item.blockOut,
                        endTime: item.blockIn,
                        location: item.departure
                    )
                default:
                    continue
                }
            }
        }
        
        return nil
    }
    
    /// Get the next scheduled duty period (for countdown display)
    var nextDutyPeriod: Date? {
        let now = Date()
        
        // Find the next flight or on-duty item
        for item in visibleItems.sorted(by: { $0.date < $1.date }) {
            if item.blockOut > now {
                let type = classifyRosterItem(item)
                if type == .flight || type == .onDuty {
                    return item.blockOut
                }
            }
        }
        
        return nil
    }
}

// MARK: - Roster Status Information
struct RosterStatusInfo {
    let type: StatusType
    let startTime: Date
    let endTime: Date
    let location: String
    let consecutiveDays: Int?
    
    init(type: StatusType, startTime: Date, endTime: Date, location: String, consecutiveDays: Int? = nil) {
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.consecutiveDays = consecutiveDays
    }
    
    enum StatusType {
        case rest
        case offDay
        case onDuty
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }
    
    var timeRemaining: TimeInterval {
        return max(0, endTime.timeIntervalSince(Date()))
    }
    
    var formattedTimeRemaining: String {
        let total = Int(timeRemaining)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var displayTitle: String {
        switch type {
        case .rest:
            return "Rest"
        case .offDay:
            if let days = consecutiveDays, days > 1 {
                return "Off Duty - Day \(currentDayNumber) of \(days)"
            }
            return "Off Duty"
        case .onDuty:
            return "On Duty"
        }
    }
    
    var currentDayNumber: Int {
        guard let days = consecutiveDays else { return 1 }
        let elapsed = Date().timeIntervalSince(startTime)
        let dayNumber = Int(elapsed / 86400) + 1
        return min(dayNumber, days)
    }
    
    var icon: String {
        switch type {
        case .rest:
            return "🛏️"
        case .offDay:
            return "🏖️"
        case .onDuty:
            return "✈️"
        }
    }
    
    var color: Color {
        switch type {
        case .rest:
            return .purple
        case .offDay:
            return .green
        case .onDuty:
            return .orange
        }
    }
}

// MARK: - Auto-Activation for Rest Periods
extension ScheduleStore {
    
    /// Check and auto-activate rest periods that should be active now
    func checkAndActivateRestPeriods() {
        let now = Date()
        
        for item in items {
            // Check if this is a rest period that should be active
            if item.tripNumber.uppercased().contains("REST") &&
               item.blockOut <= now &&
               item.blockIn > now {
                
                // Rest period is currently active
                // Post notification that rest is active
                NotificationCenter.default.post(
                    name: .restPeriodBecameActive,
                    object: nil,
                    userInfo: [
                        "startTime": item.blockOut,
                        "endTime": item.blockIn,
                        "location": item.departure
                    ]
                )
                
                print("🛏️ Rest period auto-activated: \(item.blockOut) → \(item.blockIn)")
            }
        }
    }
    
    /// Monitor for rest period transitions
    func startRestPeriodMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndActivateRestPeriods()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let restPeriodBecameActive = Notification.Name("restPeriodBecameActive")
    static let offDutyPeriodBecameActive = Notification.Name("offDutyPeriodBecameActive")
}

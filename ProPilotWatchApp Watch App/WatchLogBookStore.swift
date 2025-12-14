import Foundation

class WatchLogBookStore {
    static let shared = WatchLogBookStore()
    
    private let fileURL: URL = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") else {
            fatalError("Unable to access App Group container")
        }
        return container.appendingPathComponent("logbook.json")
    }()
    
    private init() {}
    
    // MARK: - Load Trips
    
    func loadTrips() -> [Trip] {
        do {
            let data = try Data(contentsOf: fileURL)
            let trips = try JSONDecoder().decode([Trip].self, from: data)
            print("⌚ Loaded \(trips.count) trips from App Group")
            return trips
        } catch {
            print("⌚ Failed to load trips: \(error)")
            return []
        }
    }
    
    // MARK: - Save Trips
    
    func saveTrips(_ trips: [Trip]) {
        do {
            let data = try JSONEncoder().encode(trips)
            try data.write(to: fileURL)
            print("⌚ Saved \(trips.count) trips to App Group")
        } catch {
            print("⌚ Failed to save trips: \(error)")
        }
    }
    
    // MARK: - Add Trip (Thread-Safe)
    
    func addTrip(_ trip: Trip) {
        var trips = loadTrips()
        trips.append(trip)
        saveTrips(trips)
        print("⌚ Added new trip: \(trip.tripNumber)")
    }
    
    // MARK: - Update Trip
    
    func updateTrip(_ trip: Trip) {
        var trips = loadTrips()
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveTrips(trips)
            print("⌚ Updated trip: \(trip.tripNumber)")
        } else {
            print("⌚ Trip not found for update: \(trip.id)")
        }
    }
    
    // MARK: - Get Current Active Trip
    
    func getCurrentActiveTrip() -> Trip? {
        let trips = loadTrips()
        return trips.first(where: { $0.status == .active || $0.status == .planning })
    }
    
    // MARK: - Create Trip from Watch
    
    func createTripFromDutyStart(tripNumber: String, aircraft: String, date: Date) -> Trip {
        // Use JSONEncoder/Decoder as a workaround to create a basic trip
        let tripDict: [String: Any] = [
            "id": UUID().uuidString,
            "tripNumber": tripNumber,
            "aircraft": aircraft,
            "date": date.timeIntervalSince1970,
            "tatStart": formatTime(date),
            "crew": [],
            "notes": "Created from Apple Watch",
            "legs": [],
            "tripType": "operating",
            "status": "active",
            "pilotRole": "captain",
            "receiptCount": 0,
            "logbookPageSent": false,
            "perDiemStarted": date.timeIntervalSince1970,
            "logpages": []
        ]
        
        // This is a hack but will work if enums aren't available
        let jsonData = try! JSONSerialization.data(withJSONObject: tripDict)
        let trip = try! JSONDecoder().decode(Trip.self, from: jsonData)
        
        addTrip(trip)
        print("⌚ Created new trip from duty start: \(tripNumber)")
        return trip
    }
    
    // MARK: - Update Flight Times
    
    func updateFlightTime(tripId: UUID, legIndex: Int, timeType: String, time: Date) {
        var trips = loadTrips()
        
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripId }) else {
            print("⌚ Trip not found: \(tripId)")
            return
        }
        
        var trip = trips[tripIndex]
        
        // Ensure leg exists
        if legIndex >= trip.legs.count {
            print("⌚ Leg index out of bounds")
            return
        }
        
        var leg = trip.legs[legIndex]
        
        // Update the appropriate time
        switch timeType {
        case "OUT":
            leg.outTime = formatTime(time)
        case "OFF":
            leg.offTime = formatTime(time)
        case "ON":
            leg.onTime = formatTime(time)
        case "IN":
            leg.inTime = formatTime(time)
        default:
            print("⌚ Unknown time type: \(timeType)")
            return
        }
        
        trip.legs[legIndex] = leg
        trips[tripIndex] = trip
        
        saveTrips(trips)
        print("⌚ Updated \(timeType) time for trip \(trip.tripNumber)")
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
}

// JumpseatModels.swift - Data Models for Jumpseat Network
// ProPilot App - Cross-platform pilot ride-share system

import Foundation
import CoreLocation

// MARK: - Jumpseat Flight (Available Seat Posting)

/// A flight with an available jumpseat, auto-posted from Trip creation
struct JumpseatFlight: Identifiable, Codable {
    var id: String = UUID().uuidString
    
    // Flight Information
    var departure: String           // ICAO code (e.g., "KLRD")
    var arrival: String             // ICAO code (e.g., "KPTK")
    var date: Date                  // Flight date
    var estimatedOut: String        // Scheduled OUT time "1430"
    var estimatedIn: String         // Scheduled IN time "1830"
    var aircraft: String            // Aircraft type (e.g., "B737")
    var operatorName: String        // Company name (e.g., "USA Jet")
    var flightNumber: String        // Optional flight number
    
    // Jumpseat Details
    var seatsAvailable: Int = 1     // Usually 1-2
    var jumpseatType: JumpseatType = .cockpit
    var cassRequired: Bool = true   // Part 121 = true
    var notes: String = ""          // Additional info
    
    // Pilot Information (limited for privacy)
    var pilotId: String             // Firebase Auth UID
    var pilotDisplayName: String    // Public display name
    var pilotRating: Double?        // Community rating (1-5)
    
    // Status & Tracking
    var status: JumpseatFlightStatus = .available
    var interestedPilotIds: [String] = []  // UIDs of interested pilots
    var approvedPilotId: String?    // UID of approved jumpseat rider
    
    // Timestamps
    var createdAt: Date = Date()
    var expiresAt: Date             // Auto-delete after departure
    
    // Location for proximity search
    var arrivalLat: Double?
    var arrivalLon: Double?
    var departureLat: Double?
    var departureLon: Double?
    
    // Source tracking
    var sourceTripId: String?       // Link back to ProPilot Trip
    
    // MARK: - Computed Properties
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var hasInterestedPilots: Bool {
        !interestedPilotIds.isEmpty
    }
    
    var interestedCount: Int {
        interestedPilotIds.count
    }
    
    var routeString: String {
        "\(departure) → \(arrival)"
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var displayTime: String {
        "\(estimatedOut)Z"
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }
    
    var relativeDateString: String {
        if isToday { return "Today" }
        if isTomorrow { return "Tomorrow" }
        return displayDate
    }
}

// MARK: - Jumpseat Type

enum JumpseatType: String, Codable, CaseIterable {
    case cockpit = "Cockpit"
    case cabin = "Cabin"
    case either = "Either"
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .cockpit: return "airplane.circle"
        case .cabin: return "chair.lounge"
        case .either: return "checkmark.circle"
        }
    }
}

// MARK: - Flight Status

enum JumpseatFlightStatus: String, Codable {
    case available = "Available"
    case claimed = "Claimed"        // Someone approved
    case departed = "Departed"      // Flight has left
    case completed = "Completed"    // Flight landed
    case cancelled = "Cancelled"    // Pilot cancelled posting
    
    var displayName: String { rawValue }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .claimed: return "orange"
        case .departed: return "blue"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Jumpseat Request

/// A request from a pilot interested in a jumpseat
struct JumpseatRequest: Identifiable, Codable {
    var id: String = UUID().uuidString
    
    // Request Details
    var flightId: String            // The JumpseatFlight being requested
    var flightOwnerId: String       // UID of flight poster (for queries)
    
    // Requester Info
    var requesterId: String         // Firebase Auth UID
    var requesterName: String       // Display name
    var requesterAirline: String    // Their employer
    var message: String             // Personal message
    
    // Status
    var status: RequestStatus = .pending
    var responseMessage: String?    // Flight owner's response
    
    // Timestamps
    var createdAt: Date = Date()
    var respondedAt: Date?
    
    // MARK: - Computed
    
    var isPending: Bool {
        status == .pending
    }
}

enum RequestStatus: String, Codable {
    case pending = "Pending"
    case approved = "Approved"
    case denied = "Denied"
    case withdrawn = "Withdrawn"    // Requester cancelled
    
    var displayName: String { rawValue }
}

// MARK: - Pilot Profile (Public Info)

struct PilotProfile: Identifiable, Codable {
    var id: String                  // Firebase Auth UID
    
    // Public Info
    var displayName: String         // Shown to others
    var airline: String             // Employer
    var homeBase: String            // ICAO code
    var memberSince: Date
    
    // Verification
    var isVerified: Bool = false    // CASS verified
    var cassNumber: String?         // Not displayed, just verified
    
    // Stats
    var flightsPosted: Int = 0
    var jumpseatsGiven: Int = 0
    var jumpseatsReceived: Int = 0
    var rating: Double?             // 1-5 stars
    var ratingCount: Int = 0
    
    // Preferences
    var preferredAircraft: [String] = []
    var notificationsEnabled: Bool = true
    
    // Privacy
    var showOnlineStatus: Bool = true
    var allowDirectMessages: Bool = true
    
    // Blocking
    var blockedUserIds: [String] = []
}

// MARK: - Chat Models

struct ChatChannel: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: ChannelType
    var name: String                // For route channels: "KLRD-KPTK"
    var memberIds: [String]         // Participant UIDs
    var createdAt: Date = Date()
    var lastMessageAt: Date?
    var lastMessagePreview: String?
    
    // For flight-specific chats
    var flightId: String?
}

enum ChannelType: String, Codable {
    case direct = "Direct"          // 1:1 conversation
    case flight = "Flight"          // Specific flight discussion
    case route = "Route"            // Route-based community (KLRD-DTW area)
    case general = "General"        // General pilot lounge
}

struct ChatMessage: Identifiable, Codable {
    var id: String = UUID().uuidString
    var channelId: String
    var authorId: String
    var authorName: String
    var content: String
    var timestamp: Date = Date()
    var isRead: Bool = false
    
    // Optional attachments
    var imageURL: String?
    var flightReference: String?    // Link to a JumpseatFlight
}

// MARK: - Layover Tips

struct LayoverTip: Identifiable, Codable {
    var id: String = UUID().uuidString
    var airportCode: String         // ICAO
    var category: TipCategory
    var title: String
    var content: String
    var authorId: String
    var authorName: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var upvotes: Int = 0
    var downvotes: Int = 0
    
    // Location (optional)
    var placeName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var phoneNumber: String?
    var website: String?
    
    var netScore: Int {
        upvotes - downvotes
    }
}

enum TipCategory: String, Codable, CaseIterable {
    case hotel = "Hotels"
    case food = "Food & Restaurants"
    case transportation = "Transportation"
    case fitness = "Fitness & Gym"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case services = "Services"
    case safety = "Safety Tips"
    case other = "Other"
    
    var iconName: String {
        switch self {
        case .hotel: return "bed.double"
        case .food: return "fork.knife"
        case .transportation: return "car"
        case .fitness: return "figure.run"
        case .entertainment: return "theatermasks"
        case .shopping: return "bag"
        case .services: return "wrench.and.screwdriver"
        case .safety: return "exclamationmark.shield"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Search/Filter Models

struct JumpseatSearchCriteria {
    var nearAirport: String?        // Find flights arriving near this airport
    var radiusNM: Double = 50       // Search radius in nautical miles
    var fromDate: Date = Date()
    var toDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var aircraftTypes: [String] = []
    var cassOnly: Bool = false
    var excludeOwnFlights: Bool = true
}

// MARK: - Notification Types

enum JumpseatNotificationType: String, Codable {
    case newInterest = "Someone is interested in your jumpseat"
    case requestApproved = "Your jumpseat request was approved"
    case requestDenied = "Your jumpseat request was denied"
    case newMessage = "New chat message"
    case flightReminder = "Your jumpseat flight departs soon"
    case flightCancelled = "A jumpseat you requested has been cancelled"
}

// MARK: - Helper Extensions

extension JumpseatFlight {
    /// Create from existing ProPilot Trip
    static func fromTrip(_ trip: Trip, pilotId: String, pilotName: String, operatorName: String) -> JumpseatFlight? {
        guard let firstLeg = trip.legs.first,
              let lastLeg = trip.legs.last else {
            return nil
        }
        
        // Calculate expiration (departure time + 1 hour)
        var expirationDate = trip.date
        if let outTime = parseTimeString(firstLeg.outTime) {
            expirationDate = Calendar.current.date(bySettingHour: outTime.hour, minute: outTime.minute, second: 0, of: trip.date) ?? trip.date
            expirationDate = Calendar.current.date(byAdding: .hour, value: 1, to: expirationDate) ?? expirationDate
        } else {
            // Default to end of day if no OUT time
            expirationDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: trip.date) ?? trip.date
        }
        
        return JumpseatFlight(
            departure: firstLeg.departure,
            arrival: lastLeg.arrival,
            date: trip.date,
            estimatedOut: firstLeg.outTime.isEmpty ? "TBD" : firstLeg.outTime,
            estimatedIn: lastLeg.inTime.isEmpty ? "TBD" : lastLeg.inTime,
            aircraft: trip.aircraft,
            operatorName: operatorName,
            flightNumber: firstLeg.flightNumber,
            pilotId: pilotId,
            pilotDisplayName: pilotName,
            expiresAt: expirationDate,
            sourceTripId: trip.id.uuidString
        )
    }
    
    private static func parseTimeString(_ time: String) -> (hour: Int, minute: Int)? {
        let digits = time.filter { $0.isNumber }
        guard digits.count >= 3 else { return nil }
        
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        guard let hour = Int(padded.prefix(2)),
              let minute = Int(padded.suffix(2)) else { return nil }
        
        return (hour, minute)
    }
}

// MARK: - Sample Data for Testing

#if DEBUG
extension JumpseatFlight {
    static var sampleFlights: [JumpseatFlight] {
        [
            JumpseatFlight(
                departure: "KLRD",
                arrival: "KPTK",
                date: Date(),
                estimatedOut: "1430",
                estimatedIn: "1830",
                aircraft: "B737",
                operatorName: "USA Jet",
                flightNumber: "UJ1234",
                pilotId: "sample1",
                pilotDisplayName: "Capt. Mike",
                expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                arrivalLat: 42.6653,
                arrivalLon: -83.4201
            ),
            JumpseatFlight(
                departure: "KMEM",
                arrival: "KYIP",
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                estimatedOut: "0830",
                estimatedIn: "1145",
                aircraft: "B767",
                operatorName: "Atlas Air",
                flightNumber: "",
                cassRequired: true,
                pilotId: "sample2",
                pilotDisplayName: "FO Sarah",
                expiresAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                arrivalLat: 42.2379,
                arrivalLon: -83.5303
            )
        ]
    }
}
#endif

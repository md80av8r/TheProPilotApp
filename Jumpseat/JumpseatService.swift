// JumpseatService.swift - Firebase Integration for Jumpseat Network
// ProPilot App

import Foundation
import Combine
import CoreLocation
//import FirebaseCore
// import FirebaseAuth
// import FirebaseFirestore

/// Service for managing Jumpseat Network data via Firebase
@MainActor
class JumpseatService: ObservableObject {
    static let shared = JumpseatService()
    
    // MARK: - Published State
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var currentProfile: PilotProfile?
    @Published var myPostedFlights: [JumpseatFlight] = []
    @Published var nearbyFlights: [JumpseatFlight] = []
    @Published var myRequests: [JumpseatRequest] = []
    @Published var incomingRequests: [JumpseatRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let settings = JumpseatSettings.shared
    
    // Firebase references
    private let db = Firestore.firestore()
    private var flightsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    
    // MARK: - Initialization
    
    private init() {
        setupAuthListener()
    }
    
    deinit {
        flightsListener?.remove()
        requestsListener?.remove()
    }
    
    // MARK: - Authentication
    
    nonisolated private func setupAuthListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isAuthenticated = user != nil
                self.currentUserId = user?.uid
                self.settings.userId = user?.uid
                
                if let userId = user?.uid {
                    self.loadProfile(userId: userId)
                    self.startListeners()
                } else {
                    self.currentProfile = nil
                    self.stopListeners()
                }
            }
        }
        
        print("📡 JumpseatService initialized with Firebase")
    }
    
    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        
        try await Auth.auth().signIn(with: credential)
        print("✅ Signed in with Apple")
    }
    
    /// Sign in anonymously (for browsing)
    func signInAnonymously() async throws {
        try await Auth.auth().signInAnonymously()
        print("✅ Signed in anonymously")
    }
    
    /// Sign out
    func signOut() throws {
        try Auth.auth().signOut()
        isAuthenticated = false
        currentUserId = nil
        currentProfile = nil
        print("✅ Signed out")
    }
    
    // MARK: - Profile Management
    
    nonisolated private func loadProfile(userId: String) {
        Firestore.firestore().collection("pilot_profiles").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error loading profile: \(error)")
                return
            }
            
            if let data = snapshot?.data() {
                do {
                    let profile = try Firestore.Decoder().decode(PilotProfile.self, from: data)
                    Task { @MainActor [weak self] in
                        self?.currentProfile = profile
                    }
                    print("✅ Loaded profile for \(userId)")
                } catch {
                    print("❌ Error decoding profile: \(error)")
                }
            }
        }
    }
    
    /// Create or update pilot profile
    func saveProfile(_ profile: PilotProfile) async throws {
        guard let userId = currentUserId else { throw JumpseatError.notAuthenticated }
        
        var profileToSave = profile
        profileToSave.id = userId
        
        let data = try Firestore.Encoder().encode(profileToSave)
        try await db.collection("pilot_profiles").document(userId).setData(data, merge: true)
        
        self.currentProfile = profileToSave
        
        print("✅ Saved profile for \(userId)")
    }
    
    // MARK: - Flight Posting
    
    /// Post a new jumpseat flight (called from trip creation)
    func postFlight(from trip: Trip) async throws {
        guard settings.canPostFlights else {
            throw JumpseatError.profileIncomplete
        }
        
        guard let userId = currentUserId ?? settings.userId else {
            throw JumpseatError.notAuthenticated
        }
        
        guard var flight = JumpseatFlight.fromTrip(
            trip,
            pilotId: userId,
            pilotName: settings.displayName,
            operatorName: settings.operatorName
        ) else {
            throw JumpseatError.invalidTrip
        }
        
        // Apply default settings
        flight.seatsAvailable = settings.defaultSeatsAvailable
        flight.jumpseatType = settings.defaultJumpseatType
        flight.cassRequired = settings.defaultCassRequired
        
        // Add coordinates if available (for proximity search)
        if let coords = getAirportCoordinates(flight.arrival) {
            flight.arrivalLat = coords.latitude
            flight.arrivalLon = coords.longitude
        }
        if let coords = getAirportCoordinates(flight.departure) {
            flight.departureLat = coords.latitude
            flight.departureLon = coords.longitude
        }
        
        let data = try Firestore.Encoder().encode(flight)
        try await db.collection("jumpseat_flights").document(flight.id).setData(data)
        
        // Update profile stats
        if var profile = currentProfile {
            profile.flightsPosted += 1
            try await saveProfile(profile)
        }
        
        print("✅ Posted flight: \(flight.routeString)")
        
        // Add to local list for UI
        self.myPostedFlights.append(flight)
    }
    
    /// Update an existing flight posting
    func updateFlight(_ flight: JumpseatFlight) async throws {
        let data = try Firestore.Encoder().encode(flight)
        try await db.collection("jumpseat_flights").document(flight.id).setData(data)
        print("✅ Updated flight: \(flight.id)")
    }
    
    /// Cancel/delete a flight posting
    func cancelFlight(_ flightId: String) async throws {
        try await db.collection("jumpseat_flights").document(flightId).delete()
        
        self.myPostedFlights.removeAll { $0.id == flightId }
        
        print("✅ Cancelled flight: \(flightId)")
    }
    
    // MARK: - Flight Search
    
    /// Search for available jumpseats
    func searchFlights(criteria: JumpseatSearchCriteria) async throws -> [JumpseatFlight] {
        var query: Query = db.collection("jumpseat_flights")
            .whereField("status", isEqualTo: JumpseatFlightStatus.available.rawValue)
            .whereField("date", isGreaterThanOrEqualTo: criteria.fromDate)
            .whereField("date", isLessThanOrEqualTo: criteria.toDate)
        
        if criteria.cassOnly {
            query = query.whereField("cassRequired", isEqualTo: true)
        }
        
        let snapshot = try await query.getDocuments()
        
        var flights = snapshot.documents.compactMap { doc -> JumpseatFlight? in
            try? doc.data(as: JumpseatFlight.self)
        }
        
        // Filter out own flights if requested
        if criteria.excludeOwnFlights, let userId = currentUserId {
            flights = flights.filter { $0.pilotId != userId }
        }
        
        // Filter by proximity if searching near an airport
        if let nearAirport = criteria.nearAirport,
           let targetCoords = getAirportCoordinates(nearAirport) {
            flights = flights.filter { flight in
                guard let lat = flight.arrivalLat, let lon = flight.arrivalLon else {
                    return false
                }
                let flightCoords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let distance = targetCoords.distanceInNM(to: flightCoords)
                return distance <= criteria.radiusNM
            }
        }
        
        return flights.sorted { $0.date < $1.date }
    }
    
    /// Search for flights arriving near a specific airport
    func searchFlightsNear(airport: String, radiusNM: Double = 50) async throws -> [JumpseatFlight] {
        let criteria = JumpseatSearchCriteria(
            nearAirport: airport,
            radiusNM: radiusNM
        )
        return try await searchFlights(criteria: criteria)
    }
    
    // MARK: - Jumpseat Requests
    
    /// Express interest in a jumpseat
    func requestJumpseat(flight: JumpseatFlight, message: String) async throws {
        guard let userId = currentUserId else {
            throw JumpseatError.notAuthenticated
        }
        
        let request = JumpseatRequest(
            flightId: flight.id,
            flightOwnerId: flight.pilotId,
            requesterId: userId,
            requesterName: settings.displayName,
            requesterAirline: settings.operatorName,
            message: message
        )
        
        let data = try Firestore.Encoder().encode(request)
        try await db.collection("jumpseat_requests").document(request.id).setData(data)
        
        // Add requester to flight's interested list
        try await db.collection("jumpseat_flights").document(flight.id).updateData([
            "interestedPilotIds": FieldValue.arrayUnion([userId])
        ])
        
        print("✅ Requested jumpseat on flight: \(flight.id)")
        
        self.myRequests.append(request)
    }
    
    /// Respond to a jumpseat request (approve/deny)
    func respondToRequest(_ request: JumpseatRequest, approved: Bool, message: String? = nil) async throws {
        var updatedRequest = request
        updatedRequest.status = approved ? .approved : .denied
        updatedRequest.responseMessage = message
        updatedRequest.respondedAt = Date()
        
        let data = try Firestore.Encoder().encode(updatedRequest)
        try await db.collection("jumpseat_requests").document(request.id).setData(data)
        
        if approved {
            // Update flight to claimed status
            try await db.collection("jumpseat_flights").document(request.flightId).updateData([
                "status": JumpseatFlightStatus.claimed.rawValue,
                "approvedPilotId": request.requesterId
            ])
            
            // Update profile stats
            if var profile = currentProfile {
                profile.jumpseatsGiven += 1
                try await saveProfile(profile)
            }
        }
        
        print("✅ Responded to request: \(request.id) - \(approved ? "Approved" : "Denied")")
    }
    
    // MARK: - Real-time Listeners
    
    private func startListeners() {
        guard let userId = currentUserId else { return }
        
        // Listen for my posted flights
        flightsListener = db.collection("jumpseat_flights")
            .whereField("pilotId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                
                let flights = documents.compactMap { doc -> JumpseatFlight? in
                    try? doc.data(as: JumpseatFlight.self)
                }
                
                Task { @MainActor [weak self] in
                    self?.myPostedFlights = flights
                }
            }
        
        // Listen for incoming requests on my flights
        requestsListener = db.collection("jumpseat_requests")
            .whereField("flightOwnerId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                
                let requests = documents.compactMap { doc -> JumpseatRequest? in
                    try? doc.data(as: JumpseatRequest.self)
                }
                
                Task { @MainActor [weak self] in
                    self?.incomingRequests = requests.filter { $0.status == .pending }
                }
            }
        
        print("✅ Started Firestore listeners")
    }
    
    private func stopListeners() {
        flightsListener?.remove()
        requestsListener?.remove()
        flightsListener = nil
        requestsListener = nil
        print("✅ Stopped Firestore listeners")
    }
    
    // MARK: - Helper Functions
    
    private func getAirportCoordinates(_ icao: String) -> CLLocationCoordinate2D? {
        // TODO: Use AirportDatabaseManager to look up coordinates
        // For now, return nil - coordinates will be added later
        return nil
    }
}

// MARK: - Errors

enum JumpseatError: LocalizedError {
    case notAuthenticated
    case profileIncomplete
    case invalidTrip
    case networkError(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to use the Jumpseat Network"
        case .profileIncomplete:
            return "Please complete your profile before posting flights"
        case .invalidTrip:
            return "Unable to create jumpseat posting from this trip"
        case .networkError(let message):
            return "Network error: \(message)"
        case .permissionDenied:
            return "You don't have permission to perform this action"
        }
    }
}

// MARK: - CLLocationCoordinate2D Extension (for proximity calculations)

extension CLLocationCoordinate2D {
    /// Calculate distance to another coordinate in nautical miles
    func distanceInNM(to destination: CLLocationCoordinate2D) -> Double {
        let earthRadiusNM = 3440.065  // Earth radius in nautical miles
        
        let lat1 = self.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLat = (destination.latitude - self.latitude) * .pi / 180
        let deltaLon = (destination.longitude - self.longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadiusNM * c
    }
}

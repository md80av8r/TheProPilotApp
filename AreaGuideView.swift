//
//  AreaGuideView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans
//

import SwiftUI
import MapKit

// MARK: - UI Data Models

struct AirportExperience: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let city: String
    let state: String
    let elevation: String
    let coordinate: CLLocationCoordinate2D
    var reviews: [PilotReview]
    
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }
}

enum ReviewTag: String, CaseIterable {
    case fbo = "FBO Service"
    case food = "Crew Food"
    case overnight = "Overnight"
    case approach = "Approach"
    case fees = "Fees"
    
    var color: Color {
        switch self {
        case .fbo: return .blue
        case .food: return .orange
        case .overnight: return .purple
        case .approach: return .red
        case .fees: return .green
        }
    }
}

struct NearbyPlace: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let rating: Double
    let isOpen: Bool?
}

struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
}

struct GooglePlace: Codable {
    let name: String
    let vicinity: String?
    let geometry: GoogleGeometry
    let rating: Double?
    let opening_hours: GoogleOpeningHours?
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

struct GoogleOpeningHours: Codable {
    let open_now: Bool?
}

// MARK: - Main View

struct AreaGuideView: View {
    @StateObject private var viewModel = AreaGuideViewModel()
    @State private var searchText = ""
    @State private var isAddingAirport = false
    @State private var addAirportError: String?
    @AppStorage("recentTab") private var recentTab: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search by code or city (e.g., KLRD or Laredo)", text: $searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .keyboardType(.asciiCapable)
                            .onChange(of: searchText) { oldValue, newValue in
                                Task { await viewModel.refreshSearch(newValue) }
                            }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(10)
                    .padding()
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let filtered = viewModel.filteredAirports(text: searchText)
                            
                            if filtered.isEmpty && !searchText.isEmpty && isValidAirportCode(searchText) {
                                VStack(spacing: 16) {
                                    Image(systemName: "airplane.circle")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    
                                    Text("Airport '\(searchText.uppercased())' not found")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Would you like to add it to the database?")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: { addAirport(code: searchText) }) {
                                        HStack {
                                            if isAddingAirport {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "plus.circle.fill")
                                            }
                                            Text(isAddingAirport ? "Validating..." : "Add Airport")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(LogbookTheme.accentBlue)
                                        .cornerRadius(12)
                                    }
                                    .disabled(isAddingAirport)
                                    .padding(.horizontal, 40)
                                    
                                    if let error = addAirportError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 40)
                                    }
                                }
                                .padding(.top, 60)
                            } else if filtered.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    
                                    Text("No airports found")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Try searching by airport code (e.g., KLRD) or city (e.g., Laredo)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(filtered) { airport in
                                    NavigationLink(destination: AreaGuideAirportDetailView(airport: airport)) {
                                        AirportCardRow(airport: airport)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .onAppear { recentTab = "Area Guide" }
            .navigationTitle("Area Guide")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadAirportsFromBundle(matching: nil) }
        }
    }
    
    private func isValidAirportCode(_ code: String) -> Bool {
        let cleaned = code.trimmingCharacters(in: .whitespaces).uppercased()
        return cleaned.count >= 3 && cleaned.count <= 4 && cleaned.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private func addAirport(code: String) {
        // Bundled database - cannot add airports dynamically
        isAddingAirport = false
        addAirportError = "Airport not found in database. Only pre-loaded airports are available."
    }
}
// MARK: - Area Guide Airport Detail View (Places/Layover Guide)

struct AreaGuideAirportDetailView: View {
    @State var airport: AirportExperience
    @State private var showingWriteReview = false
    @State private var isLoading = false
    @State private var restaurants: [NearbyPlace] = []
    @State private var hotels: [NearbyPlace] = []
    @State private var isLoadingPlaces = false
    
    // 🔑 Your Google Places API Key
    private let googlePlacesAPIKey = "AIzaSyCqM6b8bD8lRdDsRHkLzlu2gA4y-uWqjXU"
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(airport.code)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if airport.averageRating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", airport.averageRating))
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                            }
                        }
                        
                        Text(airport.name)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 16) {
                            Label(airport.city + ", " + airport.state, systemImage: "location")
                            Label(airport.elevation, systemImage: "arrow.up")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    Map {
                        Marker(airport.code, coordinate: airport.coordinate)
                            .tint(.blue)
                    }
                    .mapStyle(.standard)
                    .frame(height: 200)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "fork.knife")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Nearby Restaurants")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        if isLoadingPlaces {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading...")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else if !restaurants.isEmpty {
                            ForEach(restaurants.prefix(5)) { place in
                                PlaceRow(place: place, from: airport.coordinate)
                            }
                        } else {
                            Text("No restaurants found nearby")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Nearby Hotels")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        if isLoadingPlaces {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading...")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else if !hotels.isEmpty {
                            ForEach(hotels.prefix(5)) { place in
                                PlaceRow(place: place, from: airport.coordinate)
                            }
                        } else {
                            Text("No hotels found nearby")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Transportation")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: openUber) {
                            HStack {
                                Image(systemName: "figure.walk")
                                Text("Request Uber/Lyft")
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                        
                        Button(action: searchRentalCars) {
                            HStack {
                                Image(systemName: "car.2.fill")
                                Text("Find Rental Cars")
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    Button(action: { showingWriteReview = true }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Write a Review")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pilot Reviews (\(airport.reviews.count))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if airport.reviews.isEmpty {
                            Text("No reviews yet. Be the first to share your experience!")
                                .foregroundColor(.gray)
                                .italic()
                                .padding()
                        } else {
                            ForEach(airport.reviews) { review in
                                ReviewCard(review: review)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWriteReview) {
            WriteReviewSheet(airportCode: airport.code) { review in
                saveReview(review)
            }
        }
        .task {
            await loadReviews()
            await loadNearbyPlaces()
        }
    }
    
    private func loadReviews() async {
        isLoading = true
        do {
            let cloudReviews = try await AreaGuideCloudKit.shared.fetchReviews(for: airport.code)
            
            await MainActor.run {
                airport.reviews = cloudReviews.map { cr in
                    PilotReview(
                        airportCode: airport.code,
                        pilotName: cr.pilotName,
                        rating: cr.rating,
                        content: cr.content,
                        title: cr.title,
                        date: cr.date
                    )
                }
                isLoading = false
            }
        } catch {
            print("Failed to load reviews: \(error)")
            isLoading = false
        }
    }
    
    private func loadNearbyPlaces() async {
        isLoadingPlaces = true
        
        async let restaurantsTask = fetchNearbyPlaces(type: "restaurant")
        async let hotelsTask = fetchNearbyPlaces(type: "lodging")
        
        let (fetchedRestaurants, fetchedHotels) = await (restaurantsTask, hotelsTask)
        
        restaurants = fetchedRestaurants
        hotels = fetchedHotels
        isLoadingPlaces = false
    }
    
    private func fetchNearbyPlaces(type: String) async -> [NearbyPlace] {
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(airport.coordinate.latitude),\(airport.coordinate.longitude)&radius=8000&type=\(type)&key=\(googlePlacesAPIKey)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            
            return response.results.map { result in
                NearbyPlace(
                    name: result.name,
                    address: result.vicinity ?? "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: result.geometry.location.lat,
                        longitude: result.geometry.location.lng
                    ),
                    rating: result.rating ?? 0,
                    isOpen: result.opening_hours?.open_now
                )
            }
        } catch {
            print("Error fetching places: \(error)")
            return []
        }
    }
    
    private func saveReview(_ review: PilotReview) {
        Task {
            do {
                let cloudReview = CloudReview(
                    pilotName: review.pilotName,
                    rating: review.rating,
                    date: review.date,
                    title: review.title ?? "",
                    content: review.content,
                    tags: review.tags ?? []
                )
                
                try await AreaGuideCloudKit.shared.saveReview(cloudReview, for: airport.code)
                await loadReviews()
            } catch {
                print("Failed to save review: \(error)")
            }
        }
    }
    
    private func openUber() {
        let uberURL = "uber://?client_id=&action=setPickup&pickup[latitude]=\(airport.coordinate.latitude)&pickup[longitude]=\(airport.coordinate.longitude)"
        
        if let url = URL(string: uberURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            if let url = URL(string: "https://apps.apple.com/us/app/uber/id368677368") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func searchRentalCars() {
        let query = "rental+cars+near+\(airport.code)+airport"
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Place Row

struct PlaceRow: View {
    let place: NearbyPlace
    let from: CLLocationCoordinate2D
    
    var distance: String {
        let airportLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let distanceMeters = airportLocation.distance(from: placeLocation)
        let distanceMiles = distanceMeters / 1609.34
        return String(format: "%.1f mi", distanceMiles)
    }
    
    var body: some View {
        Button(action: openInMaps) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        if place.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", place.rating))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let isOpen = place.isOpen {
                            Text(isOpen ? "Open" : "Closed")
                                .font(.caption)
                                .foregroundColor(isOpen ? .green : .red)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            .padding(12)
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(8)
        }
    }
    
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: place.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Airport Card Row

struct AirportCardRow: View {
    let airport: AirportExperience
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LogbookTheme.accentBlue)
                    .frame(width: 60, height: 60)
                Text(airport.code)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(airport.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(airport.city, systemImage: "location")
                    Label(airport.elevation, systemImage: "arrow.up")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                if airport.averageRating > 0 {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(airport.averageRating.rounded()) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= Int(airport.averageRating.rounded()) ? .yellow : .gray)
                        }
                        Text("(\(airport.reviews.count))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: PilotReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.pilotName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(review.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= review.rating ? .yellow : .gray)
                    }
                }
            }
            
            if let title = review.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text(review.content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            if let tags = review.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tagString in
                            if let reviewTag = ReviewTag(rawValue: tagString) {
                                Text(reviewTag.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(reviewTag.color.opacity(0.3))
                                    .foregroundColor(reviewTag.color)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

// MARK: - Write Review Sheet

struct WriteReviewSheet: View {
    let airportCode: String
    let onSave: (PilotReview) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var pilotName = ""
    @State private var rating = 5
    @State private var title = ""
    @State private var content = ""
    @State private var selectedTags: Set<ReviewTag> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pilot Info")) {
                    TextField("Your Name", text: $pilotName)
                }
                
                Section(header: Text("Rating")) {
                    Picker("Rating", selection: $rating) {
                        ForEach(1...5, id: \.self) { star in
                            HStack {
                                ForEach(1...star, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                }
                                Text("\(star) Star\(star > 1 ? "s" : "")")
                            }
                            .tag(star)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Review")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Tags")) {
                    ForEach(ReviewTag.allCases, id: \.self) { tag in
                        Button(action: { toggleTag(tag) }) {
                            HStack {
                                Text(tag.rawValue)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Write Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveReview() }
                        .disabled(pilotName.isEmpty || title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func toggleTag(_ tag: ReviewTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func saveReview() {
        var review = PilotReview(
            airportCode: airportCode,
            pilotName: pilotName,
            rating: rating,
            content: content,
            title: title,
            date: Date()
        )
        // Convert ReviewTag enum to string array for storage
        review.tags = selectedTags.map { $0.rawValue }
        onSave(review)
        dismiss()
    }
}

// MARK: - View Model

class AreaGuideViewModel: ObservableObject {
    @Published var airports: [AirportExperience] = []
    
    func filteredAirports(text: String) -> [AirportExperience] {
        return BundledAirportDatabase.shared.searchAirports(query: text)
    }
    
    @MainActor
    func refreshSearch(_ text: String) async {
        await loadAirportsFromBundle(matching: text)
    }
    
    @MainActor
    func loadAirportsFromBundle(matching text: String? = nil) async {
        // Load from bundled CSV file (instant, offline)
        airports = BundledAirportDatabase.shared.searchAirports(query: text ?? "")
    }
}

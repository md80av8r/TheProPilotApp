//
//  AreaGuideView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans
//

import SwiftUI
import MapKit

// MARK: - UI Data Models (NOT CloudKit models)

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

struct PilotReview: Identifiable {
    let id = UUID()
    let pilotName: String
    let rating: Int
    let date: Date
    let title: String
    let content: String
    let tags: [ReviewTag]
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
                    // Search Bar
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
                    
                    // List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let filtered = viewModel.filteredAirports(text: searchText)
                            
                            if filtered.isEmpty && !searchText.isEmpty && isValidAirportCode(searchText) {
                                // Valid code format but not found - show Add Airport
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
                                // No results
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
                                // Show results
                                ForEach(filtered) { airport in
                                    NavigationLink(destination: AirportDetailView(airport: airport)) {
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
            .task { await viewModel.loadAirportsFromCloud(matching: nil) }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidAirportCode(_ code: String) -> Bool {
        let cleaned = code.trimmingCharacters(in: .whitespaces).uppercased()
        return cleaned.count >= 3 && cleaned.count <= 4 && cleaned.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private func addAirport(code: String) {
        isAddingAirport = true
        addAirportError = nil
        
        Task {
            do {
                let airport = try await AreaGuideCloudKit.shared.fetchOrCreateAirport(code: code)
                
                await MainActor.run {
                    let experience = AirportExperience(
                        code: airport.code,
                        name: airport.name,
                        city: airport.city,
                        state: airport.state,
                        elevation: airport.elevation,
                        coordinate: airport.coordinate,
                        reviews: []
                    )
                    viewModel.airports.append(experience)
                    searchText = ""
                    isAddingAirport = false
                }
            } catch {
                await MainActor.run {
                    addAirportError = error.localizedDescription
                    isAddingAirport = false
                }
            }
        }
    }
}

// MARK: - Airport Detail View

struct AirportDetailView: View {
    @State var airport: AirportExperience
    @State private var showingWriteReview = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
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
                    
                    // Map
                    Map {
                        Marker(airport.code, coordinate: airport.coordinate)
                            .tint(.blue)
                    }
                    .mapStyle(.standard)
                    .frame(height: 200)
                    .cornerRadius(12)
                    
                    // Write Review Button
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
                    
                    // Reviews Section
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
        }
    }
    
    private func loadReviews() async {
        isLoading = true
        do {
            let cloudReviews = try await AreaGuideCloudKit.shared.fetchReviews(for: airport.code)
            
            await MainActor.run {
                airport.reviews = cloudReviews.map { cr in
                    PilotReview(
                        pilotName: cr.pilotName,
                        rating: cr.rating,
                        date: cr.date,
                        title: cr.title,
                        content: cr.content,
                        tags: cr.tags.compactMap { ReviewTag(rawValue: $0) }
                    )
                }
                isLoading = false
            }
        } catch {
            print("Failed to load reviews: \(error)")
            isLoading = false
        }
    }
    
    private func saveReview(_ review: PilotReview) {
        Task {
            do {
                let cloudReview = CloudReview(
                    pilotName: review.pilotName,
                    rating: review.rating,
                    date: review.date,
                    title: review.title,
                    content: review.content,
                    tags: review.tags.map { $0.rawValue }
                )
                
                try await AreaGuideCloudKit.shared.saveReview(cloudReview, for: airport.code)
                await loadReviews()
            } catch {
                print("Failed to save review: \(error)")
            }
        }
    }
}

// MARK: - Airport Card Row

struct AirportCardRow: View {
    let airport: AirportExperience
    
    var body: some View {
        HStack(spacing: 16) {
            // Airport Code Badge
            ZStack {
                Circle()
                    .fill(LogbookTheme.accentBlue)
                    .frame(width: 60, height: 60)
                Text(airport.code)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Airport Info
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
            
            Text(review.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(review.content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            if !review.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.tags, id: \.self) { tag in
                            Text(tag.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tag.color.opacity(0.3))
                                .foregroundColor(tag.color)
                                .cornerRadius(8)
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
    @State private var fboName = ""
    @State private var crewCarAvailable = false
    
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
                
                Section(header: Text("Additional Info")) {
                    TextField("FBO Name (optional)", text: $fboName)
                    Toggle("Crew Car Available", isOn: $crewCarAvailable)
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
        let review = PilotReview(
            pilotName: pilotName,
            rating: rating,
            date: Date(),
            title: title,
            content: content,
            tags: Array(selectedTags)
        )
        onSave(review)
        dismiss()
    }
}

// MARK: - View Model

class AreaGuideViewModel: ObservableObject {
    @Published var airports: [AirportExperience] = []
    
    func filteredAirports(text: String) -> [AirportExperience] {
        if text.isEmpty { return airports }
        return airports.filter {
            $0.code.localizedCaseInsensitiveContains(text) ||
            $0.city.localizedCaseInsensitiveContains(text) ||
            $0.name.localizedCaseInsensitiveContains(text)
        }
    }
    
    @MainActor
    func refreshSearch(_ text: String) async {
        await loadAirportsFromCloud(matching: text)
    }
    
    @MainActor
    func loadAirportsFromCloud(matching text: String? = nil) async {
        do {
            // Fetch all airports from CloudKit
            let cloudAirports = try await AreaGuideCloudKit.shared.fetchAllAirports()
            
            // Convert to AirportExperience
            let allAirports = cloudAirports.map { ca in
                AirportExperience(
                    code: ca.code,
                    name: ca.name,
                    city: ca.city,
                    state: ca.state,
                    elevation: ca.elevation,
                    coordinate: ca.coordinate,
                    reviews: []
                )
            }
            
            // Filter client-side by code, city, or name
            if let searchText = text, !searchText.isEmpty {
                self.airports = allAirports.filter {
                    $0.code.localizedCaseInsensitiveContains(searchText) ||
                    $0.city.localizedCaseInsensitiveContains(searchText) ||
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
            } else {
                self.airports = allAirports
            }
        } catch {
            print("Failed to load airports from CloudKit: \(error)")
        }
    }
}

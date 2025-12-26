//
//  AirportDetailView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


//
//  AirportDetailView.swift
//  TheProPilotApp
//
//  Comprehensive airport details with weather, frequencies, and reviews
//

import SwiftUI
import MapKit

// Renamed to avoid conflict with existing AirportDetailView elsewhere
struct AirportDatabaseDetailView: View {
    let airport: AirportInfo
    @StateObject private var viewModel: AirportDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReviewSheet = false
    @State private var selectedTab: DetailTab = .overview
    
    init(airport: AirportInfo) {
        self.airport = airport
        _viewModel = StateObject(wrappedValue: AirportDetailViewModel(airport: airport))
    }
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case weather = "Weather"
        case frequencies = "Frequencies"
        case reviews = "Reviews"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .weather: return "cloud.sun.fill"
            case .frequencies: return "antenna.radiowaves.left.and.right"
            case .reviews: return "star.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content
                    ScrollView {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .weather:
                            weatherContent
                        case .frequencies:
                            frequenciesContent
                        case .reviews:
                            reviewsContent
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    favoriteButton
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                AirportReviewSheet(airport: airport) {
                    viewModel.loadReviews()
                }
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // ICAO and Name
            VStack(spacing: 8) {
                Text(airport.icaoCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(LogbookTheme.accentGreen)
                
                Text(airport.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let timeZone = airport.timeZone, !timeZone.isEmpty {
                    Label(timeZone, systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Quick stats
            HStack(spacing: 20) {
                StatBadge(
                    icon: "location.circle.fill",
                    label: "Coordinates",
                    value: String(format: "%.2f°", airport.coordinate.latitude)
                )
                
                if viewModel.averageRating > 0 {
                    StatBadge(
                        icon: "star.fill",
                        label: "Rating",
                        value: String(format: "%.1f", viewModel.averageRating),
                        color: .yellow
                    )
                }
                
                if viewModel.reviewCount > 0 {
                    StatBadge(
                        icon: "person.2.fill",
                        label: "Reviews",
                        value: "\(viewModel.reviewCount)"
                    )
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
    }
    
    private var favoriteButton: some View {
        Button(action: {
            viewModel.toggleFavorite()
        }) {
            Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                .font(.title3)
                .foregroundColor(viewModel.isFavorite ? .yellow : .gray)
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ?
                            LogbookTheme.accentGreen : Color.clear
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Map
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: airport.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            )) {
                Marker(airport.icaoCode, coordinate: airport.coordinate)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Coordinates
            InfoCard(title: "Coordinates") {
                VStack(spacing: 8) {
                    InfoRow(
                        label: "Latitude",
                        value: String(format: "%.6f°", airport.coordinate.latitude)
                    )
                    InfoRow(
                        label: "Longitude",
                        value: String(format: "%.6f°", airport.coordinate.longitude)
                    )
                }
            }
            
            // Type and Services
            InfoCard(title: "Airport Information") {
                VStack(spacing: 8) {
                    InfoRow(label: "ICAO", value: airport.icaoCode)
                    InfoRow(label: "Source", value: airport.source.rawValue)
                    if let timeZone = airport.timeZone {
                        InfoRow(label: "Time Zone", value: timeZone)
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Weather Content
    
    private var weatherContent: some View {
        VStack(spacing: 16) {
            if viewModel.isLoadingWeather {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding()
            } else if let metar = viewModel.metar {
                MetarCard(metar: metar)
            } else {
                WeatherUnavailableView()
            }
            
            if let taf = viewModel.taf {
                TafCard(taf: taf)
            }
        }
        .padding()
    }
    
    // MARK: - Frequencies Content
    
    private var frequenciesContent: some View {
        VStack(spacing: 16) {
            if viewModel.frequencies.isEmpty {
                NoFrequenciesView()
            } else {
                ForEach(viewModel.frequencies) { frequency in
                    FrequencyCard(frequency: frequency)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Reviews Content
    
    private var reviewsContent: some View {
        VStack(spacing: 16) {
            // Add Review Button
            Button(action: { showReviewSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Write a Review")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentGreen)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Reviews List
            if viewModel.reviews.isEmpty {
                NoReviewsView()
            } else {
                ForEach(viewModel.reviews) { review in
                    AirportReviewCard(review: review)
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = LogbookTheme.accentBlue
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}

struct MetarCard: View {
    let metar: WeatherData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("METAR")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(metar.observedTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(metar.rawText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            
            // Decoded
            VStack(spacing: 8) {
                if let wind = metar.wind {
                    InfoRow(label: "Wind", value: wind)
                }
                if let visibility = metar.visibility {
                    InfoRow(label: "Visibility", value: visibility)
                }
                if let temp = metar.temperature {
                    InfoRow(label: "Temperature", value: temp)
                }
                if let altimeter = metar.altimeter {
                    InfoRow(label: "Altimeter", value: altimeter)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct TafCard: View {
    let taf: WeatherData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(LogbookTheme.accentGreen)
                Text("TAF")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(taf.observedTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(taf.rawText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct FrequencyCard: View {
    let frequency: RadioFrequency
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(frequency.type)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if !frequency.description.isEmpty {
                    Text(frequency.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text(frequency.frequency)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(LogbookTheme.accentGreen)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct AirportReviewCard: View {
    let review: PilotReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.pilotName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(review.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(index < review.rating ? .yellow : .gray)
                    }
                }
            }
            
            // Content
            if !review.content.isEmpty {
                Text(review.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            // FBO Info
            if let fboName = review.fboName, !fboName.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 6) {
                    Label(fboName, systemImage: "building.2.fill")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    if let fuelPrice = review.fuelPrice, fuelPrice > 0 {
                        Text("Fuel: $\(String(format: "%.2f", fuelPrice))/gal")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct WeatherUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Weather Unavailable")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Weather data not available for this airport")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct NoFrequenciesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Frequencies")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Frequency data not available")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct NoReviewsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Reviews Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Be the first to review this airport!")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

// MARK: - View Model

@MainActor
class AirportDetailViewModel: ObservableObject {
    let airport: AirportInfo
    @Published var metar: WeatherData?
    @Published var taf: WeatherData?
    @Published var frequencies: [RadioFrequency] = []
    @Published var reviews: [PilotReview] = []
    @Published var isLoadingWeather = false
    @Published var isFavorite = false
    @Published var averageRating: Double = 0
    @Published var reviewCount: Int = 0
    
    private let weatherService = AirportWeatherService.shared
    private let dbManager = AirportDatabaseManager.shared
    
    init(airport: AirportInfo) {
        self.airport = airport
        checkFavoriteStatus()
    }
    
    func loadData() {
        loadWeather()
        loadFrequencies()
        loadReviews()
    }
    
    func loadWeather() {
        isLoadingWeather = true
        
        Task {
            do {
                let weather = try await weatherService.getWeather(for: airport.icaoCode)
                self.metar = weather.metar
                self.taf = weather.taf
            } catch {
                print("Weather error: \(error)")
            }
            isLoadingWeather = false
        }
    }
    
    func loadFrequencies() {
        // Parse frequencies from airport data if available
        frequencies = parseFrequencies(from: airport)
    }
    
    func loadReviews() {
        Task {
            do {
                reviews = try await dbManager.fetchReviews(for: airport.icaoCode)
                calculateRating()
            } catch {
                print("Error loading reviews: \(error)")
                reviews = []
            }
        }
    }
    
    func calculateRating() {
        guard !reviews.isEmpty else {
            averageRating = 0
            reviewCount = 0
            return
        }
        
        let sum = reviews.reduce(0) { $0 + $1.rating }
        averageRating = Double(sum) / Double(reviews.count)
        reviewCount = reviews.count
    }
    
    func checkFavoriteStatus() {
        let favorites = UserDefaults.standard.stringArray(forKey: "FavoriteAirports") ?? []
        isFavorite = favorites.contains(airport.icaoCode)
    }
    
    func toggleFavorite() {
        var favorites = UserDefaults.standard.stringArray(forKey: "FavoriteAirports") ?? []
        
        if isFavorite {
            favorites.removeAll { $0 == airport.icaoCode }
        } else {
            favorites.append(airport.icaoCode)
        }
        
        UserDefaults.standard.set(favorites, forKey: "FavoriteAirports")
        isFavorite.toggle()
    }
    
    private func parseFrequencies(from airport: AirportInfo) -> [RadioFrequency] {
        // This would parse frequency data from the airport
        // For now, return empty - you can add frequency data to your CSV
        return []
    }
}

// MARK: - Supporting Models

struct WeatherData: Identifiable {
    let id = UUID()
    let rawText: String
    let observedTime: String
    var wind: String?
    var visibility: String?
    var temperature: String?
    var altimeter: String?
}

struct RadioFrequency: Identifiable {
    let id = UUID()
    let type: String // Tower, Ground, ATIS, etc.
    let frequency: String
    let description: String
}

// MARK: - Preview

struct AirportDatabaseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AirportDatabaseDetailView(airport: AirportInfo(
            icaoCode: "KDTW",
            name: "Detroit Metropolitan Wayne County Airport",
            coordinate: CLLocationCoordinate2D(latitude: 42.2124, longitude: -83.3534),
            timeZone: "America/Detroit",
            source: .csvImport,
            dateAdded: Date(),
            averageRating: 4.5,
            reviewCount: 12
        ))
    }
}
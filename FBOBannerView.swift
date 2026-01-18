//
//  FBOBannerView.swift
//  TheProPilotApp
//
//  FBO Contact Banner for home screen
//  Shows preferred FBO info and UNICOM frequency for destination airport
//

import SwiftUI
import CoreLocation

// MARK: - FBO Banner View
struct FBOBannerView: View {
    let activeTrip: Trip?
    @ObservedObject private var airportDB = AirportDatabaseManager.shared
    @StateObject private var locationManager = FBOLocationManager()
    @State private var showingFBOEditor = false
    @State private var selectedAirport: AirportInfo?
    @State private var searchText: String = ""
    @State private var searchResult: AirportInfo?

    // Route navigation state (like WeatherBannerView)
    @State private var routeAirports: [String] = []
    @State private var selectedAirportIndex: Int = 0

    // Crowdsourced FBO state
    @State private var crowdsourcedFBOs: [CrowdsourcedFBO] = []
    @State private var selectedFBOIndex: Int = 0
    @State private var isLoadingFBOs: Bool = false
    @State private var lastFetchedAirportCode: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header and content
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("FBO CONTACT")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()

                    if let airport = currentSelectedAirport {
                        HStack(spacing: 4) {
                            Text(airport.icaoCode)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(LogbookTheme.accentGreen)
                            if routeAirports.count > 1 {
                                Text("(\(selectedAirportIndex + 1)/\(routeAirports.count))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                if let airport = currentSelectedAirport {
                    // FBO Info Card - now uses crowdsourced FBOs
                    FBOContactCardV2(
                        airport: airport,
                        crowdsourcedFBO: currentSelectedFBO,
                        fboCount: crowdsourcedFBOs.count,
                        selectedFBOIndex: selectedFBOIndex,
                        distanceNM: distanceToAirport(airport),
                        isLoading: isLoadingFBOs,
                        onEditFBO: {
                            selectedAirport = airport
                            showingFBOEditor = true
                        },
                        onPreviousFBO: {
                            withAnimation {
                                selectedFBOIndex = (selectedFBOIndex - 1 + crowdsourcedFBOs.count) % crowdsourcedFBOs.count
                            }
                        },
                        onNextFBO: {
                            withAnimation {
                                selectedFBOIndex = (selectedFBOIndex + 1) % crowdsourcedFBOs.count
                            }
                        }
                    )
                } else {
                    // No destination set
                    noDestinationView
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Airport Navigation Chevrons (like WeatherBannerView)
            if routeAirports.count > 1 {
                Divider()
                    .background(Color.white.opacity(0.1))
                airportNavigationBar
            }
        }
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LogbookTheme.accentGreen.opacity(0.6),
                            LogbookTheme.accentBlue.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .sheet(isPresented: $showingFBOEditor) {
            if let airport = selectedAirport {
                PreferredFBOEditorSheet(airport: airport)
            }
        }
        .onAppear {
            extractRouteAirports()
            fetchFBOsForCurrentAirport()
        }
        .onChange(of: activeTrip?.id) { _, _ in
            extractRouteAirports()
            fetchFBOsForCurrentAirport()
        }
        .onChange(of: selectedAirportIndex) { _, _ in
            fetchFBOsForCurrentAirport()
        }
    }

    // MARK: - FBO Data Fetching
    private func fetchFBOsForCurrentAirport() {
        guard let airport = currentSelectedAirport else {
            crowdsourcedFBOs = []
            selectedFBOIndex = 0
            isLoadingFBOs = false
            lastFetchedAirportCode = ""
            return
        }

        // Prevent redundant fetches for the same airport
        guard airport.icaoCode != lastFetchedAirportCode else {
            return
        }
        lastFetchedAirportCode = airport.icaoCode

        // First load from cache
        let cachedFBOs = airportDB.getFBOs(for: airport.icaoCode)
        crowdsourcedFBOs = cachedFBOs
        selectedFBOIndex = 0

        // Only show loading if we don't have cached data
        isLoadingFBOs = cachedFBOs.isEmpty

        // Then fetch from CloudKit
        Task {
            do {
                let fbos = try await airportDB.fetchCrowdsourcedFBOs(for: airport.icaoCode)
                await MainActor.run {
                    crowdsourcedFBOs = fbos
                    selectedFBOIndex = 0
                    isLoadingFBOs = false
                }
            } catch {
                // Handle "record type not found" gracefully - schema doesn't exist yet
                // This is expected when no one has added FBOs yet
                print("⚠️ FBO fetch: \(error.localizedDescription)")
                await MainActor.run {
                    // Keep any cached data, just stop loading
                    isLoadingFBOs = false
                }
            }
        }
    }

    private var currentSelectedFBO: CrowdsourcedFBO? {
        guard !crowdsourcedFBOs.isEmpty, selectedFBOIndex < crowdsourcedFBOs.count else {
            return nil
        }
        return crowdsourcedFBOs[selectedFBOIndex]
    }

    // MARK: - Airport Navigation Bar
    private var airportNavigationBar: some View {
        HStack(spacing: 0) {
            // Previous Airport
            Button(action: {
                withAnimation {
                    selectedAirportIndex = (selectedAirportIndex - 1 + routeAirports.count) % routeAirports.count
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                    Text(previousAirportCode)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 20)

            // Next Airport
            Button(action: {
                withAnimation {
                    selectedAirportIndex = (selectedAirportIndex + 1) % routeAirports.count
                }
            }) {
                HStack(spacing: 4) {
                    Text(nextAirportCode)
                        .font(.system(size: 11, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Route Extraction
    private func extractRouteAirports() {
        guard let trip = activeTrip else {
            routeAirports = []
            selectedAirportIndex = 0
            return
        }

        var airports: [String] = []

        // Get all unique airports from the trip legs
        for leg in trip.legs {
            if !leg.departure.isEmpty && !airports.contains(leg.departure) {
                airports.append(leg.departure)
            }
            if !leg.arrival.isEmpty && !airports.contains(leg.arrival) {
                airports.append(leg.arrival)
            }
        }

        routeAirports = airports
        selectedAirportIndex = 0
    }

    // MARK: - Current Selected Airport
    private var currentSelectedAirport: AirportInfo? {
        guard !routeAirports.isEmpty, selectedAirportIndex < routeAirports.count else {
            return nil
        }
        return airportDB.getAirport(for: routeAirports[selectedAirportIndex])
    }

    private var previousAirportCode: String {
        guard routeAirports.count > 1 else { return "" }
        let prevIndex = (selectedAirportIndex - 1 + routeAirports.count) % routeAirports.count
        return routeAirports[prevIndex]
    }

    private var nextAirportCode: String {
        guard routeAirports.count > 1 else { return "" }
        let nextIndex = (selectedAirportIndex + 1) % routeAirports.count
        return routeAirports[nextIndex]
    }

    private func distanceToAirport(_ airport: AirportInfo) -> Double? {
        guard let currentLoc = locationManager.currentLocation else {
            return nil
        }

        let destLocation = CLLocation(
            latitude: airport.coordinate.latitude,
            longitude: airport.coordinate.longitude
        )

        // Convert meters to nautical miles
        return currentLoc.distance(from: destLocation) / 1852.0
    }

    private var noDestinationView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "airplane.circle")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text("No Active Destination")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Start a trip or search for an airport")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }

                Spacer()
            }

            // Airport search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search airport (ICAO)", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .autocapitalization(.allCharacters)
                    .onChange(of: searchText) { _, newValue in
                        searchText = newValue.uppercased()
                        if newValue.count >= 3 {
                            searchForAirport(newValue)
                        } else {
                            searchResult = nil
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = ""; searchResult = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)

            // Search result
            if let airport = searchResult {
                Button(action: {
                    selectedAirport = airport
                    showingFBOEditor = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airport.icaoCode)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text(airport.name)
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("Set FBO")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LogbookTheme.accentGreen)
                            .cornerRadius(6)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func searchForAirport(_ query: String) {
        searchResult = airportDB.getAirport(for: query.uppercased())
    }
}

// MARK: - FBO Contact Card V2 (Crowdsourced)
struct FBOContactCardV2: View {
    let airport: AirportInfo
    let crowdsourcedFBO: CrowdsourcedFBO?
    let fboCount: Int
    let selectedFBOIndex: Int
    let distanceNM: Double?
    let isLoading: Bool
    let onEditFBO: () -> Void
    let onPreviousFBO: () -> Void
    let onNextFBO: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Airport Name
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(airport.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let distance = distanceNM {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(String(format: "%.0f nm", distance))
                                .font(.caption)

                            if distance <= 120 {
                                Text("• CONTACT NOW")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(LogbookTheme.accentOrange)
                            }
                        }
                        .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: onEditFBO) {
                    Image(systemName: crowdsourcedFBO != nil ? "pencil.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // FBO and Frequency Info
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(0.8)
                    Text("Loading FBOs...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let fbo = crowdsourcedFBO {
                crowdsourcedFBOView(fbo)
            } else {
                noFBOView
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private func crowdsourcedFBOView(_ fbo: CrowdsourcedFBO) -> some View {
        VStack(spacing: 8) {
            // FBO Name with cycling controls
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(LogbookTheme.accentGreen)

                if fboCount > 1 {
                    Button(action: onPreviousFBO) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }

                Text(fbo.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if fboCount > 1 {
                    Button(action: onNextFBO) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }

                    Text("(\(selectedFBOIndex + 1)/\(fboCount))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Verified badge
                if fbo.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }

            // UNICOM Frequency
            if let unicom = fbo.unicomFrequency ?? airport.unicomFrequency ?? airport.primaryContactFrequency {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.cyan)
                    Text("UNICOM")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(unicom)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
            }

            // Phone number if available
            if let phone = fbo.phoneNumber {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                    Text(phone)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        let cleanPhone = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                        if let url = URL(string: "tel:\(cleanPhone)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Call")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                }
            }

            // Fuel prices if available
            if fbo.jetAPrice != nil || fbo.avGasPrice != nil {
                HStack(spacing: 12) {
                    if let jetA = fbo.jetAPrice {
                        HStack(spacing: 4) {
                            Text("Jet-A")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(String(format: "$%.2f", jetA))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    if let avgas = fbo.avGasPrice {
                        HStack(spacing: 4) {
                            Text("100LL")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(String(format: "$%.2f", avgas))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    if let date = fbo.fuelPriceDate {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Amenities row
            amenitiesRow(fbo)
        }
    }

    private func amenitiesRow(_ fbo: CrowdsourcedFBO) -> some View {
        let amenities: [(icon: String, label: String, available: Bool)] = [
            ("car.fill", "Crew Car", fbo.hasCrewCars),
            ("sofa.fill", "Lounge", fbo.hasCrewLounge),
            ("wrench.fill", "Mx", fbo.hasMaintenance),
            ("snowflake", "Deice", fbo.hasDeice),
            ("drop.fill", "Lav", fbo.hasLav)
        ]

        let availableAmenities = amenities.filter { $0.available }

        return Group {
            if !availableAmenities.isEmpty {
                HStack(spacing: 8) {
                    ForEach(availableAmenities.prefix(4), id: \.label) { amenity in
                        HStack(spacing: 2) {
                            Image(systemName: amenity.icon)
                                .font(.caption2)
                            Text(amenity.label)
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                    }
                    if availableAmenities.count > 4 {
                        Text("+\(availableAmenities.count - 4)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
    }

    private var noFBOView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.gray)
                Text("No FBO data yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()

                Button(action: onEditFBO) {
                    Text("Add FBO")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(LogbookTheme.accentGreen)
                        .cornerRadius(6)
                }
            }

            // Show airport's default frequency if available
            if let freq = airport.primaryContactFrequency {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.cyan)
                    Text(airport.towerFrequency != nil ? "TWR" : "UNICOM/CTAF")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(freq)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
            }

            Text("Be the first to add FBO info for pilots!")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
                .italic()
        }
    }
}

// MARK: - Common FBO Names for Auto-Complete
private let commonFBONames: [String] = [
    "Signature Flight Support",
    "Atlantic Aviation",
    "Million Air",
    "Jet Aviation",
    "TAC Air",
    "Sheltair",
    "Ross Aviation",
    "Pentastar Aviation",
    "XJet",
    "Executive Air Terminal",
    "Western Aircraft",
    "Landmark Aviation",
    "Henriksen Jet Center",
    "Heritage Aviation",
    "Clay Lacy Aviation",
    "Castle & Cooke Aviation",
    "Cutter Aviation",
    "Eagle Aviation",
    "Hawthorne Global Aviation Services",
    "Meridian",
    "Modern Aviation",
    "Orion Jet Center",
    "Paragon Aviation",
    "Priester Aviation",
    "Rectrix Aviation",
    "Republic Jet Center",
    "Sky Harbour",
    "Spirit Aeronautics",
    "World Fuel Services",
    "Avfuel"
]

// MARK: - Phone Number Formatter
private func formatPhoneNumber(_ input: String) -> String {
    // Strip all non-digits
    let digits = input.filter { $0.isNumber }

    // Build formatted string
    var result = ""
    for (index, digit) in digits.prefix(10).enumerated() {
        if index == 0 {
            result += "("
        }
        result += String(digit)
        if index == 2 {
            result += ") "
        } else if index == 5 {
            result += "-"
        }
    }
    return result
}

// MARK: - Crowdsourced FBO Editor Sheet
struct CrowdsourcedFBOEditorSheet: View {
    let airport: AirportInfo
    var existingFBO: CrowdsourcedFBO?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var airportDB = AirportDatabaseManager.shared

    // Basic info
    @State private var fboName: String = ""
    @State private var unicomFrequency: String = ""
    @State private var phoneNumber: String = ""
    @State private var website: String = ""

    // Auto-complete state
    @State private var showingSuggestions: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    // Fuel prices
    @State private var jetAPrice: String = ""
    @State private var avGasPrice: String = ""

    // Amenities
    @State private var hasCrewCars: Bool = false
    @State private var hasCrewLounge: Bool = false
    @State private var hasCatering: Bool = false
    @State private var hasMaintenance: Bool = false
    @State private var hasHangars: Bool = false
    @State private var hasDeice: Bool = false
    @State private var hasOxygen: Bool = false
    @State private var hasGPU: Bool = false
    @State private var hasLav: Bool = false

    // Fees
    @State private var rampFee: String = ""
    @State private var rampFeeWaived: Bool = false
    @State private var handlingFee: String = ""
    @State private var overnightFee: String = ""

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    // Filtered FBO suggestions based on input
    private var filteredSuggestions: [String] {
        guard !fboName.isEmpty, fboName.count >= 2 else { return [] }
        let lowercasedInput = fboName.lowercased()
        return commonFBONames.filter { $0.lowercased().contains(lowercasedInput) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Airport")) {
                    HStack {
                        Text(airport.icaoCode)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                        Text("-")
                        Text(airport.name)
                            .lineLimit(1)
                    }
                }

                Section(header: Text("FBO Information")) {
                    // FBO Name with auto-complete
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("FBO Name (e.g., Signature Flight Support)", text: $fboName)
                            .focused($isNameFieldFocused)
                            .onChange(of: fboName) { _, newValue in
                                showingSuggestions = !newValue.isEmpty && isNameFieldFocused
                            }
                            .onChange(of: isNameFieldFocused) { _, focused in
                                showingSuggestions = focused && !fboName.isEmpty
                            }

                        // Auto-complete suggestions
                        if showingSuggestions && !filteredSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredSuggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        fboName = suggestion
                                        showingSuggestions = false
                                        isNameFieldFocused = false
                                    }) {
                                        HStack {
                                            Image(systemName: "building.2.fill")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Text(suggestion)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                    }
                                    if suggestion != filteredSuggestions.last {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.top, 4)
                        }
                    }

                    TextField("UNICOM Frequency (e.g., 122.950)", text: $unicomFrequency)
                        .keyboardType(.decimalPad)

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: phoneNumber) { _, newValue in
                            let formatted = formatPhoneNumber(newValue)
                            if formatted != newValue {
                                phoneNumber = formatted
                            }
                        }

                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("Fuel Prices (optional)")) {
                    HStack {
                        Text("Jet-A")
                        Spacer()
                        TextField("$0.00", text: $jetAPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("100LL")
                        Spacer()
                        TextField("$0.00", text: $avGasPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section(header: Text("Amenities")) {
                    Toggle("Crew Cars", isOn: $hasCrewCars)
                    Toggle("Crew Lounge", isOn: $hasCrewLounge)
                    Toggle("Catering", isOn: $hasCatering)
                    Toggle("Maintenance", isOn: $hasMaintenance)
                    Toggle("Hangar Space", isOn: $hasHangars)
                    Toggle("Deicing", isOn: $hasDeice)
                    Toggle("Oxygen Service", isOn: $hasOxygen)
                    Toggle("GPU Available", isOn: $hasGPU)
                    Toggle("Lavatory Service", isOn: $hasLav)
                }

                Section(header: Text("Fees (optional)")) {
                    HStack {
                        Text("Ramp Fee")
                        Spacer()
                        TextField("$0.00", text: $rampFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Toggle("Ramp Fee Waived w/ Fuel", isOn: $rampFeeWaived)
                    HStack {
                        Text("Handling Fee")
                        Spacer()
                        TextField("$0.00", text: $handlingFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Overnight Fee")
                        Spacer()
                        TextField("$0.00", text: $overnightFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "globe")
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("This FBO info will be shared with all pilots")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle(existingFBO != nil ? "Edit FBO" : "Add FBO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveFBO()
                        }
                        .disabled(fboName.isEmpty)
                    }
                }
            }
            .onAppear {
                loadExistingFBO()
            }
        }
    }

    private func loadExistingFBO() {
        if let existing = existingFBO {
            fboName = existing.name
            unicomFrequency = existing.unicomFrequency ?? ""
            phoneNumber = existing.phoneNumber ?? ""
            website = existing.website ?? ""
            jetAPrice = existing.jetAPrice.map { String(format: "%.2f", $0) } ?? ""
            avGasPrice = existing.avGasPrice.map { String(format: "%.2f", $0) } ?? ""
            hasCrewCars = existing.hasCrewCars
            hasCrewLounge = existing.hasCrewLounge
            hasCatering = existing.hasCatering
            hasMaintenance = existing.hasMaintenance
            hasHangars = existing.hasHangars
            hasDeice = existing.hasDeice
            hasOxygen = existing.hasOxygen
            hasGPU = existing.hasGPU
            hasLav = existing.hasLav
            rampFee = existing.rampFee.map { String(format: "%.2f", $0) } ?? ""
            rampFeeWaived = existing.rampFeeWaived
            handlingFee = existing.handlingFee.map { String(format: "%.2f", $0) } ?? ""
            overnightFee = existing.overnightFee.map { String(format: "%.2f", $0) } ?? ""
        } else {
            // Pre-fill with airport's default UNICOM if available
            unicomFrequency = airport.unicomFrequency ?? airport.ctafFrequency ?? ""
        }
    }

    private func saveFBO() {
        isSaving = true
        errorMessage = nil

        let fbo = CrowdsourcedFBO(
            id: existingFBO?.id ?? UUID(),
            airportCode: airport.icaoCode,
            name: fboName,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            unicomFrequency: unicomFrequency.isEmpty ? nil : unicomFrequency,
            website: website.isEmpty ? nil : website,
            jetAPrice: Double(jetAPrice),
            avGasPrice: Double(avGasPrice),
            fuelPriceDate: (Double(jetAPrice) != nil || Double(avGasPrice) != nil) ? Date() : nil,
            fuelPriceReporter: nil,
            hasCrewCars: hasCrewCars,
            hasCrewLounge: hasCrewLounge,
            hasCatering: hasCatering,
            hasMaintenance: hasMaintenance,
            hasHangars: hasHangars,
            hasDeice: hasDeice,
            hasOxygen: hasOxygen,
            hasGPU: hasGPU,
            hasLav: hasLav,
            handlingFee: Double(handlingFee),
            overnightFee: Double(overnightFee),
            rampFee: Double(rampFee),
            rampFeeWaived: rampFeeWaived,
            averageRating: existingFBO?.averageRating,
            ratingCount: existingFBO?.ratingCount,
            lastUpdated: Date(),
            updatedBy: nil,
            cloudKitRecordID: existingFBO?.cloudKitRecordID,
            isVerified: existingFBO?.isVerified ?? false
        )

        Task {
            do {
                print("🏢 Saving FBO '\(fbo.name)' for \(fbo.airportCode) to CloudKit...")
                try await airportDB.saveCrowdsourcedFBO(fbo)
                print("✅ FBO saved successfully!")
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("❌ FBO save failed: \(error)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Legacy Preferred FBO Editor (keeping for backwards compatibility)
struct PreferredFBOEditorSheet: View {
    let airport: AirportInfo
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var airportDB = AirportDatabaseManager.shared
    @State private var showingAddNewFBO = false
    @State private var selectedFBOToEdit: CrowdsourcedFBO?
    @State private var fbos: [CrowdsourcedFBO] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading FBOs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if fbos.isEmpty {
                    // No FBOs - go directly to add new
                    CrowdsourcedFBOEditorSheet(airport: airport, existingFBO: nil)
                } else {
                    // Show FBO list with option to add new
                    fboListView
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("FBOs at \(airport.icaoCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !fbos.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingAddNewFBO = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNewFBO) {
            CrowdsourcedFBOEditorSheet(airport: airport, existingFBO: nil)
        }
        .sheet(item: $selectedFBOToEdit) { fbo in
            CrowdsourcedFBOEditorSheet(airport: airport, existingFBO: fbo)
        }
        .onAppear {
            loadFBOs()
        }
    }

    private var fboListView: some View {
        List {
            Section {
                ForEach(fbos) { fbo in
                    FBOListRow(fbo: fbo) {
                        selectedFBOToEdit = fbo
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Only show delete for duplicates or user-created FBOs
                        if airportDB.canDeleteFBO(fbo) {
                            Button(role: .destructive) {
                                deleteFBO(fbo)
                            } label: {
                                if airportDB.shouldOfferDuplicateDeletion(fbo) {
                                    Label("Delete Duplicate", systemImage: "trash")
                                } else {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    // Show duplicate warning badge
                    .overlay(alignment: .topTrailing) {
                        if airportDB.shouldOfferDuplicateDeletion(fbo) {
                            Text("DUPLICATE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                                .offset(x: -8, y: -4)
                        }
                    }
                }
            } header: {
                Text("Select an FBO or tap + to add new")
            } footer: {
                if fbos.contains(where: { airportDB.shouldOfferDuplicateDeletion($0) }) {
                    Text("Swipe left on duplicate entries to remove them.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteFBO(_ fbo: CrowdsourcedFBO) {
        Task {
            do {
                try await airportDB.deleteCrowdsourcedFBO(fbo)
                await MainActor.run {
                    fbos.removeAll { $0.id == fbo.id }
                }
            } catch {
                print("❌ Failed to delete FBO: \(error.localizedDescription)")
            }
        }
    }

    private func loadFBOs() {
        // Load cached FBOs first
        fbos = airportDB.getFBOs(for: airport.icaoCode)
        isLoading = false

        // Then fetch from CloudKit
        Task {
            do {
                let cloudFBOs = try await airportDB.fetchCrowdsourcedFBOs(for: airport.icaoCode)
                await MainActor.run {
                    fbos = cloudFBOs
                }
            } catch {
                print("⚠️ FBO fetch error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - FBO List Row
struct FBOListRow: View {
    let fbo: CrowdsourcedFBO
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Verified badge or standard icon
                ZStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(LogbookTheme.accentGreen)
                        .font(.title3)

                    if fbo.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption2)
                            .offset(x: 10, y: -10)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(fbo.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if fbo.isVerified {
                            Text("Verified")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 12) {
                        if let phone = fbo.phoneNumber, !phone.isEmpty {
                            Label(phone, systemImage: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let unicom = fbo.unicomFrequency, !unicom.isEmpty {
                            Label(unicom, systemImage: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Amenities summary
                    let amenities = fbo.amenitiesSummary
                    if !amenities.isEmpty {
                        Text(amenities)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }
}

// Extension to get amenities summary
extension CrowdsourcedFBO {
    var amenitiesSummary: String {
        var items: [String] = []
        if hasCrewCars { items.append("Crew Cars") }
        if hasCrewLounge { items.append("Lounge") }
        if hasCatering { items.append("Catering") }
        if hasMaintenance { items.append("Mx") }
        if hasHangars { items.append("Hangars") }
        if hasDeice { items.append("Deice") }
        return items.joined(separator: " • ")
    }
}

// MARK: - FBO Icon (Toggle Button)
struct FBOIcon: View {
    let activeTrip: Trip?
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var hasFBOData = false
    private let airportDB = AirportDatabaseManager.shared

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 18))
                .foregroundColor(isExpanded ? LogbookTheme.accentGreen : (hasFBOData ? LogbookTheme.accentGreen : .gray.opacity(0.6)))
        }
        .onAppear {
            checkFBOData()
        }
        .onChange(of: activeTrip?.legs.last?.arrival) { _, _ in
            checkFBOData()
        }
    }

    private func checkFBOData() {
        guard let trip = activeTrip,
              let lastLeg = trip.legs.last,
              !lastLeg.arrival.isEmpty else {
            hasFBOData = false
            return
        }
        // Check crowdsourced FBOs first, then fall back to preferred FBOs
        let crowdsourcedFBOs = airportDB.getFBOs(for: lastLeg.arrival)
        hasFBOData = !crowdsourcedFBOs.isEmpty || airportDB.getPreferredFBO(for: lastLeg.arrival) != nil
    }
}

// MARK: - FBO Location Manager
class FBOLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}

// MARK: - Preview
#Preview {
    VStack {
        FBOBannerView(activeTrip: nil)
            .padding()

        Spacer()
    }
    .background(LogbookTheme.navy)
}

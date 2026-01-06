//
//  AirportDetailViewEnhanced.swift
//  TheProPilotApp
//
//  Enhanced airport details with ForeFlight-style tabs
//  Combines existing reviews/favorites with enhanced weather and ops info
//

import SwiftUI
import MapKit
import PDFKit

// MARK: - FAA Chart Service

class FAAChartService {
    static let shared = FAAChartService()

    // FAA digital airport diagrams are available at:
    // https://aeronav.faa.gov/d-tpp/[cycle]/[filename].pdf
    // Cycle updates every 28 days

    /// Returns the current AIRAC cycle string (yycc). Falls back to the previous cycle if today's date is within a potential gap.
    /// Note: Computing AIRAC cycles locally can drift. Prefer using an index API when available.
    private func getCurrentCycle() -> String {
        // Known AIRAC base (Cycle 2401 began on 2024-01-25). Each cycle is 28 days.
        let calendar = Calendar(identifier: .gregorian)
        let baseComponents = DateComponents(calendar: calendar, year: 2024, month: 1, day: 25)
        guard let baseDate = baseComponents.date else { return "2401" }

        // Compute cycles since base in whole 28-day intervals
        let now = Date()
        let days = calendar.dateComponents([.day], from: baseDate, to: now).day ?? 0
        let cyclesSinceBase = max(0, days / 28)

        // Derive year and cycle index from base (which was 01 in 2024)
        // We avoid assuming exactly 13 per year by rolling months forward by 28 days.
        // Compute the current cycle start date by adding cyclesSinceBase * 28 days to base.
        guard let currentCycleStart = calendar.date(byAdding: .day, value: cyclesSinceBase * 28, to: baseDate) else {
            return "2401"
        }

        // Derive yy and cycle number within the year by counting how many 28-day steps from Jan 1 of that year.
        let year = calendar.component(.year, from: currentCycleStart)
        let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysFromJan1 = calendar.dateComponents([.day], from: jan1, to: currentCycleStart).day ?? 0
        let cycleInYear = (daysFromJan1 / 28) + 1
        let yy = year % 100

        return String(format: "%02d%02d", yy, cycleInYear)
    }

    func fetchAirportDiagramURL(for icaoCode: String) async -> URL? {
        // Convert ICAO to FAA ID (remove K prefix for US airports)
        let faaId = icaoCode.hasPrefix("K") && icaoCode.count == 4
            ? String(icaoCode.dropFirst())
            : icaoCode

        // Method 1: Try AviationAPI.com (free, reliable)
        if let url = await tryAviationAPI(faaId: faaId) {
            return url
        }

        // Method 2: Try direct FAA URL patterns
        if let url = await tryDirectFAAPatterns(faaId: faaId, icaoCode: icaoCode) {
            return url
        }

        // Method 3: Try the FAA DTPP API
        if let url = await tryFAADTPPAPI(faaId: faaId) {
            return url
        }

        return nil
    }

    private func tryAviationAPI(faaId: String) async -> URL? {
        // AviationAPI provides free access to FAA charts
        let apiURL = "https://api.aviationapi.com/v1/charts?apt=\(faaId)&group=2"

        guard let url = URL(string: apiURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            // Parse response - it returns an object with airport code as key
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let charts = json[faaId] as? [[String: Any]] {
                // Log chart names for debugging
                let names = charts.compactMap { $0["chart_name"] as? String }
                print("AviationAPI charts for \(faaId): \(names)")

                // Look for Airport Diagram (APD) chart (relaxed matching)
                for chart in charts {
                    if let chartName = chart["chart_name"] as? String,
                       chartName.uppercased().contains("AIRPORT DIAGRAM") || chartName.uppercased().contains("APD"),
                       let pdfUrl = chart["pdf_path"] as? String,
                       let finalURL = URL(string: pdfUrl) {
                        return finalURL
                    }
                }
            } else {
                if let body = String(data: data, encoding: .utf8) {
                    print("AviationAPI unexpected response for \(faaId): \(body)")
                }
            }
        } catch {
            print("AviationAPI error: \(error)")
        }

        return nil
    }

    private func tryDirectFAAPatterns(faaId: String, icaoCode: String) async -> URL? {
        // Direct filename patterns are unreliable because FAA files are numeric per-procedure.
        // We avoid guessing to prevent repeated 404s. Prefer using an index API.
        print("Skipping direct FAA pattern guess for \(faaId)/\(icaoCode)")
        return nil
    }

    private func tryFAADTPPAPI(faaId: String) async -> URL? {
        let apiURL = "https://soa.smext.faa.gov/apra/dtpp/chart?apt=\(faaId)&type=APD"
        guard let url = URL(string: apiURL) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                print("FAA DTPP API HTTP \(http.statusCode) for \(faaId): \(body)")
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = json.first,
               let pdfPath = first["pdf_path"] as? String {
                // Some responses provide relative paths (e.g., /d-tpp/2408/xxxx.pdf)
                if pdfPath.lowercased().hasPrefix("http") {
                    return URL(string: pdfPath)
                } else {
                    return URL(string: "https://aeronav.faa.gov\(pdfPath)")
                }
            } else {
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                print("FAA DTPP API unexpected response for \(faaId): \(body)")
            }
        } catch {
            print("FAA DTPP API error for \(faaId): \(error)")
        }

        return nil
    }

    func downloadDiagram(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("Diagram download failed (HTTP \(code)) from: \(url.absoluteString)")
            throw URLError(.badServerResponse)
        }

        return data
    }
}

// MARK: - PDF Viewer

struct PDFViewer: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(LogbookTheme.navy)

        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            uiView.document = document
        }
    }
}

// MARK: - Compact Frequency Bar

struct FrequencyBarView: View {
    let frequencies: [(type: String, freq: String)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(frequencies.enumerated()), id: \.offset) { _, freq in
                    FrequencyChip(type: freq.type, frequency: freq.freq)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(LogbookTheme.navyLight)
    }
}

struct FrequencyChip: View {
    let type: String
    let frequency: String

    var chipColor: Color {
        switch type.uppercased() {
        case "TWR", "TOWER": return .red
        case "GND", "GROUND": return .green
        case "ATIS", "AWOS", "ASOS": return .blue
        case "APP", "DEP", "APPROACH", "DEPARTURE": return .purple
        case "CTAF", "UNICOM": return .orange
        case "CLR", "CLNC", "CLEARANCE": return .cyan
        default: return LogbookTheme.accentBlue
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(type.prefix(4).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(chipColor)
            Text(frequency)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(chipColor.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(chipColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AirportDetailViewEnhanced: View {
    let airport: AirportInfo
    @StateObject private var viewModel: EnhancedAirportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReviewSheet = false
    @State private var selectedMainTab: MainTab = .weather
    @State private var selectedWeatherTab: WeatherTab = .metar
    
    init(airport: AirportInfo) {
        self.airport = airport
        _viewModel = StateObject(wrappedValue: EnhancedAirportViewModel(airport: airport))
    }
    
    enum MainTab: String, CaseIterable, Identifiable {
        case info = "Info"
        case weather = "Weather"
        case fbo = "FBO"
        case area = "Area"
        case ops = "Ops"
        case reviews = "Reviews"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .weather: return "cloud.sun.fill"
            case .fbo: return "fuelpump.fill"
            case .area: return "map.fill"
            case .ops: return "building.2.fill"
            case .reviews: return "star.fill"
            }
        }
    }
    
    enum WeatherTab: String, CaseIterable, Identifiable {
        case metar = "METAR"
        case taf = "TAF"
        case datis = "D-ATIS"
        case mos = "MOS"
        case daily = "Daily"
        case winds = "Winds"

        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Main Tabs
                    mainTabSelector

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Content
                    if selectedMainTab == .weather {
                        // Use the comprehensive weather tab content (same as WeatherBanner sheet)
                        AirportWeatherTabContent(
                            airportCode: airport.icaoCode,
                            airportCoordinate: airport.coordinate
                        )
                    } else {
                        ScrollView {
                            contentView
                                .padding()
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
                    .lineLimit(2)
                
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
                    label: "Location",
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
    
    // MARK: - Tab Selectors
    
    private var mainTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MainTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMainTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedMainTab == tab ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedMainTab == tab ?
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
    
    private var weatherSubTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(WeatherTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeatherTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedWeatherTab == tab ? LogbookTheme.accentGreen : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedWeatherTab == tab ?
                                Color.white.opacity(0.1) : Color.clear
                            )
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedMainTab {
        case .info:
            InfoTabContent(airport: airport)
        case .weather:
            // Weather is now handled by AirportWeatherTabContent above
            EmptyView()
        case .fbo:
            FBOTabContent(viewModel: viewModel, airport: airport)
        case .area:
            AreaTabContent(airport: airport)
        case .ops:
            OpsTabContent(airport: airport)
        case .reviews:
            reviewsContent
        }
    }
    
    // MARK: - Reviews Content (Airport & FBO reviews)
    
    private var reviewsContent: some View {
        VStack(spacing: 16) {
            // Clarification text
            Text("Share your experience with this airport's FBO service, fuel prices, and facilities")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Add Review Button
            Button(action: { showReviewSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Review Airport & FBO")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentGreen)
                .cornerRadius(12)
            }
            
            // Reviews List
            if viewModel.reviews.isEmpty {
                NoReviewsView()
            } else {
                ForEach(viewModel.reviews) { review in
                    AirportReviewCard(review: review)
                }
            }
        }
    }
}

// MARK: - Info Tab Content

struct InfoTabContent: View {
    let airport: AirportInfo
    @State private var diagramData: Data?
    @State private var isLoadingDiagram = false
    @State private var diagramError: String?
    @State private var showDiagramSheet = false

    // Check if this is a US airport (ICAO starts with K or is a US territory)
    private var isUSAirport: Bool {
        let code = airport.icaoCode.uppercased()
        return code.hasPrefix("K") ||  // Continental US
               code.hasPrefix("PH") || // Hawaii
               code.hasPrefix("PA") || // Alaska
               code.hasPrefix("PG") || // Guam
               code.hasPrefix("TJ")    // Puerto Rico
    }

    // Build frequency list for the bar
    private var frequencyList: [(type: String, freq: String)] {
        var freqs: [(type: String, freq: String)] = []

        if !airport.parsedFrequencies.isEmpty {
            freqs = airport.parsedFrequencies.map { ($0.type, $0.frequency) }
        } else {
            if let ctaf = airport.ctafFrequency { freqs.append(("CTAF", ctaf)) }
            if let tower = airport.towerFrequency { freqs.append(("TWR", tower)) }
            if let ground = airport.groundFrequency { freqs.append(("GND", ground)) }
            if let atis = airport.atisFrequency { freqs.append(("ATIS", atis)) }
            if let unicom = airport.unicomFrequency { freqs.append(("UNICOM", unicom)) }
        }

        return freqs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Frequency Bar at the very top
            if !frequencyList.isEmpty {
                FrequencyBarView(frequencies: frequencyList)
            }

            ScrollView {
                VStack(spacing: 16) {
                    // FAA Airport Diagram Section (US airports only)
                    if isUSAirport {
                        SectionCard(title: "Airport Diagram") {
                            VStack(spacing: 12) {
                                if let data = diagramData {
                                    // Show thumbnail preview
                                    Button(action: { showDiagramSheet = true }) {
                                        ZStack {
                                            PDFViewer(data: data)
                                                .frame(height: 200)
                                                .cornerRadius(8)
                                                .allowsHitTesting(false)

                                            // Overlay tap hint
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Label("Tap to expand", systemImage: "arrow.up.left.and.arrow.down.right")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                        .padding(8)
                                                        .background(Color.black.opacity(0.6))
                                                        .cornerRadius(6)
                                                        .padding(8)
                                                }
                                            }
                                        }
                                    }
                                } else if isLoadingDiagram {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Searching FAA charts...")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(height: 100)
                                } else if let error = diagramError {
                                    VStack(spacing: 8) {
                                        Image(systemName: "doc.richtext")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                        Button("Try Again") {
                                            downloadDiagram()
                                        }
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .padding(.top, 4)
                                    }
                                    .frame(height: 100)
                                } else {
                                    // Download button
                                    VStack(spacing: 12) {
                                        Image(systemName: "doc.richtext")
                                            .font(.system(size: 36))
                                            .foregroundColor(.gray)

                                        Text("Tap to search for FAA airport diagram")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)

                                        Button(action: downloadDiagram) {
                                            HStack {
                                                Image(systemName: "magnifyingglass")
                                                Text("Find Diagram")
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(LogbookTheme.accentBlue)
                                            .cornerRadius(8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }

                    // Map
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: airport.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )) {
                        Marker(airport.icaoCode, coordinate: airport.coordinate)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)

                    // Basic Information
                    SectionCard(title: "Airport Information") {
                        InfoRow(label: "ICAO Code", value: airport.icaoCode)
                        InfoRow(label: "Name", value: airport.name)
                        if !airport.locationString.isEmpty {
                            InfoRow(label: "Location", value: airport.locationString)
                        }
                        if let elevation = airport.elevation, !elevation.isEmpty {
                            InfoRow(label: "Elevation", value: elevation)
                        } else if let elevFeet = airport.elevationFeet {
                            InfoRow(label: "Elevation", value: "\(elevFeet) ft")
                        }
                        if let timeZone = airport.timeZone, !timeZone.isEmpty {
                            InfoRow(label: "Time Zone", value: timeZone)
                        }
                    }

                    // Runways Section
                    if !airport.parsedRunways.isEmpty || airport.longestRunway != nil {
                        SectionCard(title: "Runways") {
                            VStack(spacing: 8) {
                                if !airport.parsedRunways.isEmpty {
                                    ForEach(Array(airport.parsedRunways.enumerated()), id: \.offset) { _, runway in
                                        HStack {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .foregroundColor(LogbookTheme.accentBlue)
                                                .frame(width: 24)
                                            Text(runway.name)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(runway.length)
                                                .foregroundColor(.gray)
                                            if !runway.surface.isEmpty {
                                                Text("•")
                                                    .foregroundColor(.gray)
                                                Text(runway.surface)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .font(.subheadline)
                                    }
                                } else if let longest = airport.longestRunway {
                                    HStack {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .foregroundColor(LogbookTheme.accentBlue)
                                        Text("Longest Runway")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text("\(longest) ft")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        if let surface = airport.runwaySurface {
                                            Text("• \(surface)")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .font(.subheadline)
                                }

                                if airport.hasLightedRunway == true {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                            .frame(width: 24)
                                        Text("Lighted Runway")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Navaids Section
                    if !airport.parsedNavaids.isEmpty || airport.vorIdent != nil || airport.ndbIdent != nil {
                        SectionCard(title: "Navaids") {
                            VStack(spacing: 8) {
                                if !airport.parsedNavaids.isEmpty {
                                    ForEach(Array(airport.parsedNavaids.enumerated()), id: \.offset) { _, navaid in
                                        NavaidRow(ident: navaid.ident, type: navaid.type, frequency: navaid.frequency)
                                    }
                                } else {
                                    if let vorIdent = airport.vorIdent, let vorFreq = airport.vorFrequency {
                                        NavaidRow(ident: vorIdent, type: "VOR", frequency: vorFreq)
                                    }
                                    if let ndbIdent = airport.ndbIdent, let ndbFreq = airport.ndbFrequency {
                                        NavaidRow(ident: ndbIdent, type: "NDB", frequency: ndbFreq)
                                    }
                                    if let dmeIdent = airport.dmeIdent {
                                        let dmeInfo = airport.dmeChannel ?? ""
                                        NavaidRow(ident: dmeIdent, type: "DME", frequency: dmeInfo)
                                    }
                                }
                            }
                        }
                    }

                    // Local Tips/Comments Section
                    if !airport.parsedComments.isEmpty {
                        SectionCard(title: "Local Pilot Tips") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(airport.parsedComments.prefix(5).enumerated()), id: \.offset) { _, comment in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "quote.opening")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                            .font(.caption)
                                        Text(comment)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                if airport.parsedComments.count > 5 {
                                    Text("+ \(airport.parsedComments.count - 5) more tips")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    // Coordinates
                    SectionCard(title: "Coordinates") {
                        InfoRow(
                            label: "Latitude",
                            value: String(format: "%.6f°", airport.coordinate.latitude)
                        )
                        InfoRow(
                            label: "Longitude",
                            value: String(format: "%.6f°", airport.coordinate.longitude)
                        )
                    }

                    // External Links Section
                    if airport.wikipediaLink != nil || airport.homeLink != nil {
                        SectionCard(title: "External Links") {
                            VStack(spacing: 12) {
                                if let wikiLink = airport.wikipediaLink, let url = URL(string: wikiLink) {
                                    Link(destination: url) {
                                        HStack {
                                            Image(systemName: "book.fill")
                                                .foregroundColor(.blue)
                                                .frame(width: 24)
                                            Text("Wikipedia")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .foregroundColor(.gray)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                                if let homeLink = airport.homeLink, let url = URL(string: homeLink) {
                                    Link(destination: url) {
                                        HStack {
                                            Image(systemName: "globe")
                                                .foregroundColor(LogbookTheme.accentGreen)
                                                .frame(width: 24)
                                            Text("Official Website")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .foregroundColor(.gray)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showDiagramSheet) {
            DiagramFullScreenView(data: diagramData, airportCode: airport.icaoCode)
        }
    }

    private func downloadDiagram() {
        isLoadingDiagram = true
        diagramError = nil

        Task {
            do {
                if let url = await FAAChartService.shared.fetchAirportDiagramURL(for: airport.icaoCode) {
                    let data = try await FAAChartService.shared.downloadDiagram(from: url)
                    await MainActor.run {
                        self.diagramData = data
                        self.isLoadingDiagram = false
                    }
                } else {
                    await MainActor.run {
                        self.diagramError = "No diagram found via AviationAPI/FAA index"
                        self.isLoadingDiagram = false
                    }
                    print("No diagram URL found for \(airport.icaoCode)")
                }
            } catch {
                await MainActor.run {
                    self.diagramError = "Failed to download: \(error.localizedDescription)"
                    self.isLoadingDiagram = false
                }
                print("Diagram download error for \(airport.icaoCode): \(error)")
            }
        }
    }
}

// MARK: - Full Screen Diagram View

struct DiagramFullScreenView: View {
    let data: Data?
    let airportCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()

                if let data = data {
                    PDFViewer(data: data)
                } else {
                    Text("No diagram available")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("\(airportCode) Diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
    }
}

// MARK: - Frequency Row

struct FrequencyRow: View {
    let type: String
    let frequency: String

    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(frequencyColor)
                .frame(width: 24)
            Text(type)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(frequency)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(LogbookTheme.accentGreen)
        }
        .font(.subheadline)
    }

    var frequencyColor: Color {
        switch type.uppercased() {
        case "TWR", "TOWER": return .red
        case "GND", "GROUND": return .green
        case "ATIS", "AWOS", "ASOS": return .blue
        case "APP", "DEP", "APPROACH", "DEPARTURE": return .purple
        case "CTAF", "UNICOM": return .orange
        default: return LogbookTheme.accentBlue
        }
    }
}

// MARK: - Navaid Row

struct NavaidRow: View {
    let ident: String
    let type: String
    let frequency: String

    var body: some View {
        HStack {
            Image(systemName: navaidIcon)
                .foregroundColor(navaidColor)
                .frame(width: 24)
            Text(ident)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("(\(type))")
                .foregroundColor(.gray)
            Spacer()
            Text(frequency)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(LogbookTheme.accentGreen)
        }
        .font(.subheadline)
    }

    var navaidIcon: String {
        switch type.uppercased() {
        case "VOR", "VORTAC", "VOR-DME": return "target"
        case "NDB": return "dot.radiowaves.left.and.right"
        case "DME": return "ruler"
        case "TACAN": return "star.circle"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    var navaidColor: Color {
        switch type.uppercased() {
        case "VOR", "VORTAC", "VOR-DME": return .cyan
        case "NDB": return .orange
        case "DME": return .purple
        case "TACAN": return .yellow
        default: return LogbookTheme.accentBlue
        }
    }
}

// MARK: - METAR Tab Content

struct METARTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingWeather {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let metar = viewModel.metarData {
                // Current Conditions Card
                SectionCard(title: "Current Conditions") {
                    VStack(spacing: 12) {
                        if let wind = metar.wind {
                            ConditionRow(
                                icon: "wind",
                                iconColor: LogbookTheme.accentBlue,
                                label: "Wind",
                                value: wind
                            )
                        }
                        
                        if let visibility = metar.visibility {
                            ConditionRow(
                                icon: "eye",
                                iconColor: LogbookTheme.accentBlue,
                                label: "Visibility",
                                value: visibility
                            )
                        }
                        
                        if let temp = metar.temperature {
                            ConditionRow(
                                icon: "thermometer",
                                iconColor: .red,
                                label: "Temp/Dewpoint",
                                value: temp
                            )
                        }
                        
                        if let altimeter = metar.altimeter {
                            ConditionRow(
                                icon: "gauge",
                                iconColor: .purple,
                                label: "Altimeter",
                                value: altimeter
                            )
                        }
                    }
                }
                
                // Raw METAR
                SectionCard(title: "Raw METAR") {
                    Text(metar.rawText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                }
                
                // Observation Time
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text("Observed: \(metar.observedTime ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                WeatherUnavailableView()
            }
        }
    }
}

// MARK: - TAF Tab Content

struct TAFTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingWeather {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let taf = viewModel.tafData {
                // Raw TAF
                SectionCard(title: "Terminal Aerodrome Forecast") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(taf.rawText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                    }
                }
                
                // Issue Time
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text("Issued: \(taf.observedTime ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                
                // Parsing note
                Text("TAF contains forecast conditions for the next 24-30 hours. Check raw TAF for FM (From), TEMPO (Temporary), and BECMG (Becoming) change groups.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            } else {
                WeatherUnavailableView()
            }
        }
    }
}

// MARK: - D-ATIS Tab Content

struct DATISTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingDATIS {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                        .scaleEffect(1.5)
                    Text("Fetching D-ATIS...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let datis = viewModel.datisText {
                // Information Code
                SectionCard(title: "Current D-ATIS") {
                    if let code = viewModel.datisCode {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Information")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(code)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                            Spacer()
                        }
                    }
                }
                
                // D-ATIS Content
                SectionCard(title: "Broadcast") {
                    Text(datis)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                
            } else {
                SectionCard(title: "D-ATIS Unavailable") {
                    VStack(spacing: 12) {
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("D-ATIS not available for this airport")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

// MARK: - MOS Tab Content

struct MOSTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingMOS {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !viewModel.mosData.isEmpty {
                SectionCard(title: "Model Output Statistics (GFS)") {
                    VStack(spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("Time")
                                .frame(width: 50, alignment: .leading)
                            Text("Temp")
                                .frame(width: 45, alignment: .center)
                            Text("Dew")
                                .frame(width: 45, alignment: .center)
                            Text("Wind")
                                .frame(width: 60, alignment: .center)
                            Text("Sky")
                                .frame(width: 40, alignment: .center)
                            Text("POP")
                                .frame(width: 35, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)

                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Data rows
                        ForEach(viewModel.mosData.prefix(12)) { forecast in
                            HStack(spacing: 0) {
                                Text(forecast.forecastHourString)
                                    .frame(width: 50, alignment: .leading)
                                    .foregroundColor(.white)

                                if let temp = forecast.tmp {
                                    Text("\(temp)°")
                                        .frame(width: 45, alignment: .center)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("--")
                                        .frame(width: 45, alignment: .center)
                                        .foregroundColor(.gray)
                                }

                                if let dew = forecast.dpt {
                                    Text("\(dew)°")
                                        .frame(width: 45, alignment: .center)
                                        .foregroundColor(.cyan)
                                } else {
                                    Text("--")
                                        .frame(width: 45, alignment: .center)
                                        .foregroundColor(.gray)
                                }

                                if let dir = forecast.windDirectionDegrees, let spd = forecast.wsp {
                                    Text("\(String(format: "%03d", dir))@\(spd)")
                                        .frame(width: 60, alignment: .center)
                                        .foregroundColor(.white)
                                } else {
                                    Text("--")
                                        .frame(width: 60, alignment: .center)
                                        .foregroundColor(.gray)
                                }

                                Text(forecast.cld ?? "--")
                                    .frame(width: 40, alignment: .center)
                                    .foregroundColor(.white)

                                if let pop = forecast.p06 {
                                    Text("\(pop)%")
                                        .frame(width: 35, alignment: .trailing)
                                        .foregroundColor(pop > 50 ? .blue : .gray)
                                } else {
                                    Text("--")
                                        .frame(width: 35, alignment: .trailing)
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.vertical, 4)
                        }
                    }
                }

                Text("MOS provides computer-generated weather forecasts from NOAA's GFS model")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                SectionCard(title: "MOS Unavailable") {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Model Output Statistics not available")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Daily Forecast Tab Content

struct DailyForecastTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingDaily {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !viewModel.dailyForecastData.isEmpty {
                SectionCard(title: "7-Day Forecast") {
                    VStack(spacing: 0) {
                        ForEach(viewModel.dailyForecastData.prefix(10)) { forecast in
                            HStack(spacing: 12) {
                                Text(forecast.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 80, alignment: .leading)

                                Image(systemName: forecast.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)

                                Text(forecast.shortForecast)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let high = forecast.highTemp {
                                    Text("\(high)°")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.orange)
                                } else if let low = forecast.lowTemp {
                                    Text("\(low)°")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }

                                if let precip = forecast.precipChance, precip > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "drop.fill")
                                            .font(.system(size: 9))
                                        Text("\(precip)%")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(precip > 50 ? .blue : .gray)
                                    .frame(width: 40, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 6)

                            if forecast.id != viewModel.dailyForecastData.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }

                Text("Forecast data from weather.gov")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                SectionCard(title: "Forecast Unavailable") {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Daily forecast not available")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Winds Aloft Tab Content

struct WindsAloftTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingWinds {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentGreen))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !viewModel.windsAloftData.isEmpty {
                SectionCard(title: "Winds Aloft") {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                            Text("Altitude")
                                .frame(width: 70, alignment: .leading)
                            Text("Wind")
                                .frame(width: 100, alignment: .center)
                            Text("Temp")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)

                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Data rows
                        ForEach(viewModel.windsAloftData) { wind in
                            HStack(spacing: 0) {
                                Text("\(wind.altitude)'")
                                    .frame(width: 70, alignment: .leading)
                                    .foregroundColor(.white)

                                Text(wind.windString)
                                    .frame(width: 100, alignment: .center)
                                    .foregroundColor(.cyan)

                                if let temp = wind.temperature {
                                    Text("\(temp)°C")
                                        .frame(width: 60, alignment: .trailing)
                                        .foregroundColor(temp < 0 ? .cyan : .orange)
                                } else {
                                    Text("--")
                                        .frame(width: 60, alignment: .trailing)
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 4)
                        }
                    }
                }

                Text("Winds aloft from aviationweather.gov")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                SectionCard(title: "Winds Aloft Unavailable") {
                    VStack(spacing: 12) {
                        Image(systemName: "wind")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Winds aloft data not available")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

// MARK: - FBO Tab Content

struct FBOTabContent: View {
    @ObservedObject var viewModel: EnhancedAirportViewModel
    let airport: AirportInfo
    @StateObject private var airportManager = AirportDatabaseManager.shared
    @State private var crowdsourcedFBOs: [CrowdsourcedFBO] = []
    @State private var isLoading = false
    @State private var showAddFBO = false
    @State private var selectedFBO: CrowdsourcedFBO?
    @State private var showFuelPriceUpdate = false
    @State private var fuelUpdateFBO: CrowdsourcedFBO?

    var body: some View {
        VStack(spacing: 16) {
            // Add FBO Button
            Button(action: { showAddFBO = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add FBO")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentBlue)
                .cornerRadius(12)
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding()
            }

            // Crowdsourced FBOs
            if !crowdsourcedFBOs.isEmpty {
                ForEach(crowdsourcedFBOs) { fbo in
                    CrowdsourcedFBOCard(
                        fbo: fbo,
                        onEdit: { selectedFBO = fbo },
                        onUpdateFuel: {
                            fuelUpdateFBO = fbo
                            showFuelPriceUpdate = true
                        }
                    )
                }
            }

            // Legacy FBO info from reviews
            if let fboInfo = viewModel.fboInfo {
                // FBO Name (from reviews)
                if !fboInfo.names.isEmpty {
                    SectionCard(title: "FBOs from Reviews") {
                        ForEach(Array(fboInfo.names.enumerated()), id: \.offset) { _, name in
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                Text(name)
                                    .foregroundColor(.white)
                                Spacer()
                                // Quick add button to promote to crowdsourced
                                Button(action: {
                                    promoteToFBO(name: name)
                                }) {
                                    Image(systemName: "arrow.up.circle")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                            }
                        }
                        Text("Tap arrow to add as editable FBO")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Fuel Prices (from reviews)
                if !fboInfo.fuelPrices.isEmpty {
                    SectionCard(title: "Fuel Prices from Reviews") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(fboInfo.fuelPrices, id: \.self) { price in
                                HStack {
                                    Image(systemName: "fuelpump.fill")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                    Text("Jet A")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", price))/gal")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }

                            Text("Prices from pilot reviews - may not be current")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                }

                // Amenities (from reviews)
                if fboInfo.hasCrewCars || fboInfo.hasCrewLounge || fboInfo.hasCatering {
                    SectionCard(title: "Amenities from Reviews") {
                        VStack(spacing: 8) {
                            if fboInfo.hasCrewCars {
                                ServiceRow(icon: "car.fill", service: "Crew Cars", available: true)
                            }
                            if fboInfo.hasCrewLounge {
                                ServiceRow(icon: "bed.double.fill", service: "Crew Lounge", available: true)
                            }
                            if fboInfo.hasCatering {
                                ServiceRow(icon: "fork.knife", service: "Catering", available: true)
                            }
                            if fboInfo.hasMaintenance {
                                ServiceRow(icon: "wrench.fill", service: "Maintenance", available: true)
                            }
                        }
                    }
                }
            }

            // Empty state
            if crowdsourcedFBOs.isEmpty && viewModel.fboInfo == nil {
                SectionCard(title: "FBO Information") {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)

                        Text("No FBO information available yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("Tap 'Add FBO' to share FBO details with other pilots!")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .onAppear {
            loadFBOs()
        }
        .sheet(isPresented: $showAddFBO, onDismiss: { Task { await loadFBOsAsync() } }) {
            CrowdsourcedFBOEditorSheet(airport: airport, existingFBO: nil)
        }
        .sheet(item: $selectedFBO, onDismiss: { Task { await loadFBOsAsync() } }) { fbo in
            CrowdsourcedFBOEditorSheet(airport: airport, existingFBO: fbo)
        }
        .sheet(isPresented: $showFuelPriceUpdate) {
            if let fbo = fuelUpdateFBO {
                QuickFuelUpdateSheet(fbo: fbo) { jetA, avGas in
                    Task {
                        try? await airportManager.updateFuelPrice(
                            for: fbo.id,
                            airportCode: fbo.airportCode,
                            jetAPrice: jetA,
                            avGasPrice: avGas
                        )
                        await loadFBOsAsync()
                    }
                }
            }
        }
    }

    private func loadFBOs() {
        crowdsourcedFBOs = airportManager.getFBOs(for: airport.icaoCode)
        Task {
            await loadFBOsAsync()
        }
    }

    private func loadFBOsAsync() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fbos = try await airportManager.fetchCrowdsourcedFBOs(for: airport.icaoCode)
            await MainActor.run {
                crowdsourcedFBOs = fbos
            }
        } catch {
            print("Error loading FBOs: \(error)")
        }
    }

    private func promoteToFBO(name: String) {
        let newFBO = CrowdsourcedFBO(
            airportCode: airport.icaoCode,
            name: name
        )
        Task {
            try? await airportManager.saveCrowdsourcedFBO(newFBO)
            await loadFBOsAsync()
        }
    }
}

// MARK: - Crowdsourced FBO Card
struct CrowdsourcedFBOCard: View {
    let fbo: CrowdsourcedFBO
    var onEdit: () -> Void
    var onUpdateFuel: () -> Void
    @ObservedObject private var airportDB = AirportDatabaseManager.shared
    @State private var notifyDistance: Double = 120  // User-configurable notification distance

    /// Check if this FBO is set as the preferred FBO for notifications
    private var isPreferredFBO: Bool {
        airportDB.getPreferredFBO(for: fbo.airportCode)?.fboName == fbo.name
    }

    /// Get current notification distance from preferred FBO
    private var currentNotifyDistance: Double {
        airportDB.getPreferredFBO(for: fbo.airportCode)?.notifyAtDistance ?? 120
    }

    var body: some View {
        SectionCard(title: fbo.name) {
            VStack(alignment: .leading, spacing: 12) {
                // Contact info
                if let phone = fbo.phoneNumber {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Link(phone, destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))")!)
                            .foregroundColor(.white)
                    }
                }

                if let unicom = fbo.unicomFrequency {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("UNICOM: \(unicom)")
                            .foregroundColor(.white)
                    }
                }

                // Fuel Prices
                if fbo.jetAPrice != nil || fbo.avGasPrice != nil {
                    Divider().background(Color.gray.opacity(0.3))
                    HStack {
                        if let jetA = fbo.jetAPrice {
                            VStack {
                                Text("Jet A")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", jetA))")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                        Spacer()
                        if let avGas = fbo.avGasPrice {
                            VStack {
                                Text("AvGas")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", avGas))")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                        Spacer()
                        if let age = fbo.fuelPriceAge {
                            Text(age)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

                    Button(action: onUpdateFuel) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                            Text("Update Fuel Price")
                        }
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                }

                // Amenities
                let amenities = getAmenities()
                if !amenities.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(amenities, id: \.0) { icon, name in
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .font(.caption)
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // Fees
                if fbo.rampFee != nil || fbo.handlingFee != nil {
                    Divider().background(Color.gray.opacity(0.3))
                    HStack {
                        if let ramp = fbo.rampFee {
                            VStack(alignment: .leading) {
                                Text("Ramp Fee")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                HStack(spacing: 4) {
                                    Text("$\(Int(ramp))")
                                        .foregroundColor(.white)
                                    if fbo.rampFeeWaived {
                                        Text("(waived w/fuel)")
                                            .font(.caption2)
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                }
                            }
                        }
                        Spacer()
                        if let handling = fbo.handlingFee {
                            VStack(alignment: .trailing) {
                                Text("Handling")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("$\(Int(handling))")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // Set as My FBO button (for proximity notifications)
                Divider().background(Color.gray.opacity(0.3))
                VStack(spacing: 8) {
                    Button(action: togglePreferredFBO) {
                        HStack {
                            Image(systemName: isPreferredFBO ? "bell.fill" : "bell")
                                .foregroundColor(isPreferredFBO ? LogbookTheme.accentGreen : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPreferredFBO ? "My FBO - Notifications On" : "Set as My FBO")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(isPreferredFBO ? LogbookTheme.accentGreen : .white)
                                Text(isPreferredFBO ? "Notify at \(Int(notifyDistance)) nm" : "Get notified when approaching this airport")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: isPreferredFBO ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isPreferredFBO ? LogbookTheme.accentGreen : .gray)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(isPreferredFBO ? LogbookTheme.accentGreen.opacity(0.15) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Distance slider (only shown when FBO is set as preferred)
                    if isPreferredFBO {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Notify at:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(Int(notifyDistance)) nm")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                            Slider(value: $notifyDistance, in: 20...200, step: 5)
                                .tint(LogbookTheme.accentGreen)
                                .onChange(of: notifyDistance) { _, newValue in
                                    updateNotifyDistance(newValue)
                                }
                            HStack {
                                Text("20 nm")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Turboprop")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.7))
                                Spacer()
                                Text("200 nm")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .onAppear {
                    // Initialize slider with current saved value
                    notifyDistance = currentNotifyDistance
                }

                // Edit button row
                Divider().background(Color.gray.opacity(0.3))
                HStack {
                    if fbo.isVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Verified")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    Spacer()
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil.circle")
                            Text("Edit")
                        }
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
        }
    }

    private func togglePreferredFBO() {
        if isPreferredFBO {
            // Remove preferred FBO
            airportDB.removePreferredFBO(for: fbo.airportCode)
        } else {
            // Set this FBO as preferred for notifications
            let preferredFBO = PreferredFBO(
                airportCode: fbo.airportCode,
                fboName: fbo.name,
                unicomFrequency: fbo.unicomFrequency,
                phoneNumber: fbo.phoneNumber,
                notes: nil,
                notifyAtDistance: notifyDistance  // Use current slider value
            )
            airportDB.setPreferredFBO(preferredFBO)
        }
    }

    /// Update the notification distance for the preferred FBO
    private func updateNotifyDistance(_ distance: Double) {
        guard let existingFBO = airportDB.getPreferredFBO(for: fbo.airportCode) else { return }
        let updatedFBO = PreferredFBO(
            airportCode: existingFBO.airportCode,
            fboName: existingFBO.fboName,
            unicomFrequency: existingFBO.unicomFrequency,
            phoneNumber: existingFBO.phoneNumber,
            notes: existingFBO.notes,
            notifyAtDistance: distance
        )
        airportDB.setPreferredFBO(updatedFBO)
    }

    private func getAmenities() -> [(String, String)] {
        var amenities: [(String, String)] = []
        if fbo.hasCrewCars { amenities.append(("car.fill", "Crew Car")) }
        if fbo.hasCrewLounge { amenities.append(("bed.double.fill", "Lounge")) }
        if fbo.hasCatering { amenities.append(("fork.knife", "Catering")) }
        if fbo.hasMaintenance { amenities.append(("wrench.fill", "Mx")) }
        if fbo.hasHangars { amenities.append(("square.stack.3d.up.fill", "Hangars")) }
        if fbo.hasDeice { amenities.append(("snowflake", "Deice")) }
        if fbo.hasOxygen { amenities.append(("lungs.fill", "O2")) }
        if fbo.hasGPU { amenities.append(("bolt.fill", "GPU")) }
        if fbo.hasLav { amenities.append(("drop.fill", "Lav")) }
        return amenities
    }
}

// MARK: - Quick Fuel Update Sheet
struct QuickFuelUpdateSheet: View {
    let fbo: CrowdsourcedFBO
    var onSave: (Double?, Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var jetAPrice: String
    @State private var avGasPrice: String

    init(fbo: CrowdsourcedFBO, onSave: @escaping (Double?, Double?) -> Void) {
        self.fbo = fbo
        self.onSave = onSave
        _jetAPrice = State(initialValue: fbo.jetAPrice.map { String(format: "%.2f", $0) } ?? "")
        _avGasPrice = State(initialValue: fbo.avGasPrice.map { String(format: "%.2f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Update Fuel Prices at \(fbo.name)") {
                    HStack {
                        Text("Jet A")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $jetAPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("/gal")
                    }
                    HStack {
                        Text("AvGas 100LL")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $avGasPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("/gal")
                    }
                }

                Section {
                    Text("Thank you for helping keep fuel prices current!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Update Fuel Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Double(jetAPrice), Double(avGasPrice))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Ops Tab Content (Cargo-Specific!)

struct OpsTabContent: View {
    let airport: AirportInfo
    
    var body: some View {
        VStack(spacing: 16) {
            // Airport Operations
            SectionCard(title: "Airport Operations") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("✈️ Check NOTAMs for current operational status")
                    Text("📞 Contact airport operations for:")
                    Text("   • Ramp availability and fees")
                    Text("   • After-hours procedures")
                    Text("   • Fuel availability")
                    Text("   • Customs coordination")
                }
                .font(.subheadline)
                .foregroundColor(.white)
            }
            
            // Cargo Operations Note
            SectionCard(title: "Cargo Operations") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🚚 For cargo operations, verify:")
                    Text("   • Cargo handler availability")
                    Text("   • Weight restrictions")
                    Text("   • Dangerous goods approval")
                    Text("   • Customs hours (international)")
                    Text("   • Ramp space for your aircraft")
                }
                .font(.subheadline)
                .foregroundColor(.white)
            }
            
            // Add to reviews prompt
            SectionCard(title: "Share Your Experience") {
                VStack(spacing: 12) {
                    Text("Help other cargo pilots by reviewing this airport!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("Include details about handlers, ramp fees, customs, and any operational notes.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Area Tab Content (Nearby Places)

struct AreaTabContent: View {
    let airport: AirportInfo
    @State private var restaurants: [NearbyPlace] = []
    @State private var hotels: [NearbyPlace] = []
    @State private var isLoading = false

    // Google Places API Key (from AreaGuideView)
    private let googlePlacesAPIKey = "AIzaSyCqM6b8bD8lRdDsRHkLzlu2gA4y-uWqjXU"

    var body: some View {
        VStack(spacing: 16) {
            // Map with airport marker
            Map {
                Marker(airport.icaoCode, coordinate: airport.coordinate)
                    .tint(.blue)

                // Restaurant markers
                ForEach(restaurants.prefix(5)) { place in
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(.orange)
                }

                // Hotel markers
                ForEach(hotels.prefix(5)) { place in
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(.purple)
                }
            }
            .mapStyle(.standard)
            .frame(height: 200)
            .cornerRadius(12)

            // Restaurants Section
            SectionCard(title: "Nearby Restaurants") {
                if isLoading {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Loading...").foregroundColor(.gray)
                    }
                } else if restaurants.isEmpty {
                    Text("No restaurants found nearby")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(restaurants.prefix(5)) { place in
                        AreaPlaceRow(place: place, from: airport.coordinate)
                    }
                }
            }

            // Hotels Section
            SectionCard(title: "Nearby Hotels") {
                if isLoading {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Loading...").foregroundColor(.gray)
                    }
                } else if hotels.isEmpty {
                    Text("No hotels found nearby")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(hotels.prefix(5)) { place in
                        AreaPlaceRow(place: place, from: airport.coordinate)
                    }
                }
            }

            // Transportation Section
            SectionCard(title: "Transportation") {
                VStack(spacing: 8) {
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
            }
        }
        .task {
            await loadNearbyPlaces()
        }
    }

    private func loadNearbyPlaces() async {
        isLoading = true
        async let restaurantsTask = fetchNearbyPlaces(type: "restaurant")
        async let hotelsTask = fetchNearbyPlaces(type: "lodging")
        let (fetchedRestaurants, fetchedHotels) = await (restaurantsTask, hotelsTask)
        restaurants = fetchedRestaurants
        hotels = fetchedHotels
        isLoading = false
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

    private func openUber() {
        let uberURL = "uber://?client_id=&action=setPickup&pickup[latitude]=\(airport.coordinate.latitude)&pickup[longitude]=\(airport.coordinate.longitude)"
        if let url = URL(string: uberURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "https://apps.apple.com/us/app/uber/id368677368") {
            UIApplication.shared.open(url)
        }
    }

    private func searchRentalCars() {
        let query = "rental+cars+near+\(airport.icaoCode)+airport"
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Area Place Row (for nearby places)
struct AreaPlaceRow: View {
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

                Image(systemName: "arrow.up.right.circle")
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            .padding(12)
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(8)
        }
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Supporting Views

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
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
    }
}

struct ConditionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.gray)
                .frame(minWidth: 100, alignment: .leading)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}

struct ServiceRow: View {
    let icon: String
    let service: String
    let available: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(available ? LogbookTheme.accentBlue : .gray)
                .frame(width: 30)
            Text(service)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(available ? LogbookTheme.accentGreen : .gray)
        }
        .font(.subheadline)
    }
}

// MARK: - FBO Info Model

struct FBOInfo {
    let names: [String]
    let fuelPrices: [Double]
    let hasCrewCars: Bool
    let hasCrewLounge: Bool
    let hasCatering: Bool
    let hasMaintenance: Bool
}

// MARK: - Enhanced View Model

@MainActor
class EnhancedAirportViewModel: ObservableObject {
    let airport: AirportInfo
    
    // Weather (uses existing WeatherData model)
    @Published var metarData: WeatherData?
    @Published var tafData: WeatherData?
    @Published var isLoadingWeather = false

    // D-ATIS
    @Published var datisText: String?
    @Published var datisCode: String?
    @Published var isLoadingDATIS = false

    // MOS Data
    @Published var mosData: [MOSForecast] = []
    @Published var isLoadingMOS = false

    // Daily Forecast
    @Published var dailyForecastData: [DailyForecastData] = []
    @Published var isLoadingDaily = false

    // Winds Aloft
    @Published var windsAloftData: [WindsAloftData] = []
    @Published var isLoadingWinds = false

    // Reviews and FBO
    @Published var reviews: [PilotReview] = []
    @Published var fboInfo: FBOInfo?
    
    // Favorites
    @Published var isFavorite = false
    @Published var averageRating: Double = 0
    @Published var reviewCount: Int = 0
    
    private let weatherService = AirportWeatherService.shared
    private let bannerWeatherService = BannerWeatherService.shared
    private let dbManager = AirportDatabaseManager.shared

    init(airport: AirportInfo) {
        self.airport = airport
        self.averageRating = airport.averageRating ?? 0
        self.reviewCount = airport.reviewCount ?? 0
        checkFavoriteStatus()
    }

    func loadData() {
        loadWeather()
        loadDATIS()
        loadReviews()
        loadMOS()
        loadDailyForecast()
        loadWindsAloft()
    }
    
    func loadWeather() {
        isLoadingWeather = true
        
        Task {
            do {
                let weather = try await weatherService.getWeather(for: airport.icaoCode)
                self.metarData = weather.metar
                self.tafData = weather.taf
            } catch {
                print("Weather error: \(error)")
            }
            isLoadingWeather = false
        }
    }
    
    func loadDATIS() {
        isLoadingDATIS = true
        
        Task {
            // Try multiple D-ATIS sources
            let sources = [
                "https://datis.clowd.io/api/\(airport.icaoCode)",
                "https://api.aviationapi.com/v1/weather/station/\(airport.icaoCode)/atis"
            ]
            
            for source in sources {
                if let datis = try? await fetchDATIS(from: source) {
                    self.datisText = datis.text
                    self.datisCode = datis.code
                    self.isLoadingDATIS = false
                    return
                }
            }
            
            // No D-ATIS available
            self.isLoadingDATIS = false
        }
    }
    
    private func fetchDATIS(from urlString: String) async throws -> (text: String, code: String?) {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Try to parse JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let text = json["datis"] as? String ?? json["text"] as? String ?? ""
            let code = json["code"] as? String ?? extractCodeFromText(text)
            return (text, code)
        }
        
        // Fallback to plain text
        if let text = String(data: data, encoding: .utf8) {
            return (text, extractCodeFromText(text))
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    private func extractCodeFromText(_ text: String) -> String? {
        // Try to extract information letter (ALPHA, BRAVO, etc.)
        let pattern = "INFORMATION\\s+([A-Z]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    func loadReviews() {
        Task {
            do {
                reviews = try await dbManager.fetchReviews(for: airport.icaoCode)
                calculateRating()
                extractFBOInfo()
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
    
    func extractFBOInfo() {
        guard !reviews.isEmpty else {
            fboInfo = nil
            return
        }
        
        var names = Set<String>()
        var fuelPrices: [Double] = []
        var hasCrewCars = false
        var hasCrewLounge = false
        var hasCatering = false
        var hasMaintenance = false
        
        for review in reviews {
            if let fboName = review.fboName, !fboName.isEmpty {
                names.insert(fboName)
            }
            if let price = review.fuelPrice, price > 0 {
                fuelPrices.append(price)
            }
            if review.fboHasCrewCars == true { hasCrewCars = true }
            if review.fboHasCrewLounge == true { hasCrewLounge = true }
            if review.fboHasCatering == true { hasCatering = true }
            if review.fboHasMaintenance == true { hasMaintenance = true }
        }
        
        fboInfo = FBOInfo(
            names: Array(names),
            fuelPrices: fuelPrices.sorted().suffix(3).reversed(),  // Last 3 prices
            hasCrewCars: hasCrewCars,
            hasCrewLounge: hasCrewLounge,
            hasCatering: hasCatering,
            hasMaintenance: hasMaintenance
        )
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

    // MARK: - MOS Loading

    func loadMOS() {
        guard mosData.isEmpty else { return }
        isLoadingMOS = true

        Task {
            do {
                let forecasts = try await bannerWeatherService.fetchMOS(for: airport.icaoCode)
                self.mosData = forecasts
            } catch {
                print("MOS error: \(error)")
            }
            isLoadingMOS = false
        }
    }

    // MARK: - Daily Forecast Loading

    func loadDailyForecast() {
        guard dailyForecastData.isEmpty else { return }
        isLoadingDaily = true

        Task {
            do {
                let forecasts = try await bannerWeatherService.fetchDailyForecast(
                    latitude: airport.coordinate.latitude,
                    longitude: airport.coordinate.longitude
                )
                self.dailyForecastData = forecasts
            } catch {
                print("Daily forecast error: \(error)")
            }
            isLoadingDaily = false
        }
    }

    // MARK: - Winds Aloft Loading

    func loadWindsAloft() {
        guard windsAloftData.isEmpty else { return }
        isLoadingWinds = true

        Task {
            do {
                let winds = try await bannerWeatherService.fetchWindsAloft(for: airport.icaoCode)
                self.windsAloftData = winds
            } catch {
                print("Winds aloft error: \(error)")
            }
            isLoadingWinds = false
        }
    }
}

// MARK: - Preview

// MARK: - Supporting View Components

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
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
                .frame(minWidth: 100, alignment: .leading)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .font(.subheadline)
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
                    
                    if let title = review.title {
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < review.rating ? "star.fill" : "star")
                            .foregroundColor(index < review.rating ? .yellow : .gray)
                            .font(.caption)
                    }
                }
            }
            
            // Content
            Text(review.content)
                .font(.body)
                .foregroundColor(.white)
            
            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(review.date, style: .date)
                    .font(.caption)
                Spacer()
            }
            .foregroundColor(.gray)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct WeatherUnavailableView: View {
    var body: some View {
        SectionCard(title: "Weather Unavailable") {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Weather data is currently unavailable for this airport")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

struct NoReviewsView: View {
    var body: some View {
        SectionCard(title: "No Reviews Yet") {
            VStack(spacing: 12) {
                Image(systemName: "star")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("No reviews yet for this airport")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Be the first to share your experience!")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

// Note: AirportReviewSheet is defined in AirportReviewSheet.swift

#Preview {
    AirportDetailViewEnhanced(airport: AirportInfo(
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


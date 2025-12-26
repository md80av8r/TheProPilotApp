//
//  AirportDetailViewEnhanced.swift
//  TheProPilotApp
//
//  Enhanced airport details with ForeFlight-style tabs
//  Combines existing reviews/favorites with enhanced weather and ops info
//

import SwiftUI
import MapKit

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
        case ops = "Ops"
        case reviews = "Airport & FBO"  // Renamed for clarity - reviews of airport/FBO services, not places
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .weather: return "cloud.sun.fill"
            case .fbo: return "fuelpump.fill"
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
                    
                    // Weather Sub-tabs (if weather selected)
                    if selectedMainTab == .weather {
                        weatherSubTabSelector
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Content
                    ScrollView {
                        contentView
                            .padding()
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
            weatherContent
        case .fbo:
            FBOTabContent(viewModel: viewModel)
        case .ops:
            OpsTabContent(airport: airport)
        case .reviews:
            reviewsContent
        }
    }
    
    @ViewBuilder
    private var weatherContent: some View {
        switch selectedWeatherTab {
        case .metar:
            METARTabContent(viewModel: viewModel)
        case .taf:
            TAFTabContent(viewModel: viewModel)
        case .datis:
            DATISTabContent(viewModel: viewModel)
        case .mos:
            MOSTabContent(viewModel: viewModel)
        case .daily:
            DailyForecastTabContent(viewModel: viewModel)
        case .winds:
            WindsAloftTabContent(viewModel: viewModel)
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
    
    var body: some View {
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
            
            // Basic Information
            SectionCard(title: "Airport Information") {
                InfoRow(label: "ICAO Code", value: airport.icaoCode)
                InfoRow(label: "Name", value: airport.name)
                InfoRow(label: "Source", value: airport.source.rawValue)
                if let timeZone = airport.timeZone {
                    InfoRow(label: "Time Zone", value: timeZone)
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

    var body: some View {
        VStack(spacing: 16) {
            if let fboInfo = viewModel.fboInfo {
                // FBO Name (from reviews)
                if !fboInfo.names.isEmpty {
                    SectionCard(title: "FBOs at this Airport") {
                        ForEach(Array(fboInfo.names.enumerated()), id: \.offset) { _, name in
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                Text(name)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                }

                // Fuel Prices (from reviews)
                if !fboInfo.fuelPrices.isEmpty {
                    SectionCard(title: "Recent Fuel Prices") {
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
                    SectionCard(title: "Amenities") {
                        VStack(spacing: 8) {
                            if fboInfo.hasCrewCars {
                                ServiceRow(
                                    icon: "car.fill",
                                    service: "Crew Cars",
                                    available: true
                                )
                            }
                            if fboInfo.hasCrewLounge {
                                ServiceRow(
                                    icon: "bed.double.fill",
                                    service: "Crew Lounge",
                                    available: true
                                )
                            }
                            if fboInfo.hasCatering {
                                ServiceRow(
                                    icon: "fork.knife",
                                    service: "Catering",
                                    available: true
                                )
                            }
                            if fboInfo.hasMaintenance {
                                ServiceRow(
                                    icon: "wrench.fill",
                                    service: "Maintenance",
                                    available: true
                                )
                            }
                        }
                    }
                }
            } else {
                // No FBO data yet
                SectionCard(title: "FBO Information") {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No FBO information available yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Be the first to review this airport and share FBO details!")
                            .font(.caption)
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

//
//  AirportWeatherTabContent.swift
//  TheProPilotApp
//
//  Weather tab content for AirportDetailView - uses the same comprehensive weather display
//  as WeatherBannerView's WeatherDetailSheet but adapted for single-airport use.
//

import SwiftUI

/// Weather tab content for airport detail view - single airport version of WeatherDetailSheet
struct AirportWeatherTabContent: View {
    let airportCode: String
    let airportCoordinate: CLLocationCoordinate2D?

    @ObservedObject var weatherService = BannerWeatherService.shared
    @ObservedObject var settingsStore = NOCSettingsStore.shared

    @State private var selectedWeatherTab: WeatherDisplayTab = .metar
    @State private var weatherData: [String: RawMETAR] = [:]
    @State private var tafData: [String: RawTAF] = [:]
    @State private var mosData: [String: [MOSForecast]] = [:]
    @State private var windsAloftData: [String: [WindsAloftData]] = [:]
    @State private var dailyForecastData: [DailyForecastData] = []
    @State private var datisData: [String: DATISData] = [:]

    @State private var isLoadingMETAR = false
    @State private var isLoadingTAF = false
    @State private var isLoadingMOS = false
    @State private var isLoadingWinds = false
    @State private var isLoadingDaily = false
    @State private var isLoadingDATIS = false
    @State private var isLoadingRunways = false
    @State private var selectedRunwayIndex = 0
    @State private var showDecodedTAF = false

    private var currentWeather: RawMETAR? {
        return weatherData[airportCode]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Weather Tab Selector
            weatherTabSelector

            Divider()
                .background(Color.white.opacity(0.2))

            // Tab Content
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedWeatherTab {
                    case .metar:
                        enhancedMETARView
                    case .datis:
                        datisView
                    case .taf:
                        tafView
                    case .mos:
                        mosView
                    case .daily:
                        dailyForecastView
                    case .winds:
                        windsAloftView
                    case .images:
                        weatherImagesView
                    }
                }
            }
        }
        .onAppear {
            loadDataForCurrentTab()
        }
        .onChange(of: selectedWeatherTab) { _, _ in
            loadDataForCurrentTab()
        }
    }

    // MARK: - Weather Tab Selector
    private var weatherTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(WeatherDisplayTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeatherTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedWeatherTab == tab ? .bold : .medium))
                                .foregroundColor(selectedWeatherTab == tab ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                            Rectangle()
                                .fill(selectedWeatherTab == tab ? LogbookTheme.accentGreen : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(LogbookTheme.navyLight)
    }

    // MARK: - Load Data
    private func loadDataForCurrentTab() {
        switch selectedWeatherTab {
        case .metar:
            loadMETAR()
            loadRunways()
        case .datis:
            loadDATIS()
        case .taf:
            loadTAF()
        case .mos:
            loadMOS()
        case .daily:
            loadDailyForecast()
        case .winds:
            loadWindsAloft()
        case .images:
            // Images are loaded from web URLs, no pre-fetching needed
            break
        }
    }

    private func loadMETAR() {
        guard weatherData[airportCode] == nil else { return }
        isLoadingMETAR = true

        Task {
            do {
                let metar = try await weatherService.fetchMETAR(for: airportCode)
                await MainActor.run {
                    weatherData[airportCode] = metar
                    isLoadingMETAR = false
                }
            } catch {
                print("⚠️ Failed to fetch METAR for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingMETAR = false
                }
            }
        }
    }

    private func loadRunways() {
        guard weatherService.cachedRunways[airportCode] == nil else { return }
        isLoadingRunways = true

        Task {
            do {
                _ = try await weatherService.fetchRunways(for: airportCode)
                await MainActor.run {
                    isLoadingRunways = false
                }
            } catch {
                print("⚠️ Failed to fetch runways for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingRunways = false
                }
            }
        }
    }

    private func loadTAF() {
        guard tafData[airportCode] == nil else { return }
        isLoadingTAF = true

        Task {
            do {
                let taf = try await weatherService.fetchTAF(for: airportCode)
                await MainActor.run {
                    tafData[airportCode] = taf
                    isLoadingTAF = false
                }
            } catch {
                print("⚠️ Failed to fetch TAF for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingTAF = false
                }
            }
        }
    }

    private func loadMOS() {
        guard mosData[airportCode] == nil else { return }
        isLoadingMOS = true

        Task {
            do {
                let forecasts = try await weatherService.fetchMOS(for: airportCode)
                await MainActor.run {
                    mosData[airportCode] = forecasts
                    isLoadingMOS = false
                }
            } catch {
                print("⚠️ Failed to fetch MOS for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingMOS = false
                }
            }
        }
    }

    private func loadWindsAloft() {
        guard windsAloftData[airportCode] == nil else { return }
        isLoadingWinds = true

        Task {
            do {
                let winds = try await weatherService.fetchWindsAloft(for: airportCode)
                await MainActor.run {
                    windsAloftData[airportCode] = winds
                    isLoadingWinds = false
                }
            } catch {
                print("⚠️ Failed to fetch winds aloft for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingWinds = false
                }
            }
        }
    }

    private func loadDailyForecast() {
        guard dailyForecastData.isEmpty else { return }
        guard let coordinate = airportCoordinate else { return }
        isLoadingDaily = true

        Task {
            do {
                let forecasts = try await weatherService.fetchDailyForecast(latitude: coordinate.latitude, longitude: coordinate.longitude)
                await MainActor.run {
                    dailyForecastData = forecasts
                    isLoadingDaily = false
                }
            } catch {
                print("⚠️ Failed to fetch daily forecast: \(error)")
                await MainActor.run {
                    isLoadingDaily = false
                }
            }
        }
    }

    private func loadDATIS() {
        guard datisData[airportCode] == nil else { return }
        isLoadingDATIS = true

        Task {
            do {
                let datis = try await weatherService.fetchDATIS(for: airportCode)
                await MainActor.run {
                    datisData[airportCode] = datis
                    isLoadingDATIS = false
                }
            } catch {
                print("⚠️ Failed to fetch D-ATIS for \(airportCode): \(error)")
                await MainActor.run {
                    isLoadingDATIS = false
                }
            }
        }
    }

    // MARK: - Enhanced METAR View
    private var enhancedMETARView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weather = currentWeather {
                // Flight Category Header
                HStack {
                    if let category = weather.flightCategory {
                        flightCategoryBadge(category)
                    }

                    Spacer()

                    Text(weather.timeAgo)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(timeAgeColor(weather))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(timeAgeColor(weather).opacity(0.2))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Raw METAR
                Text(weather.rawOb)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor(weather.flightCategory))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)

                // Parsed Weather Data
                parsedWeatherTable(weather)
                    .padding(.horizontal, 12)

                // Runway Analysis
                runwayAnalysisSection(weather)

            } else if isLoadingMETAR {
                loadingView
            } else {
                noDataView("No METAR data available")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - D-ATIS View
    private var datisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Digital ATIS - \(airportCode)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if let datis = datisData[airportCode], let letter = datis.informationLetter {
                    Text("INFO \(letter)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                }

                if isLoadingDATIS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let datis = datisData[airportCode] {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let arrivalATIS = datis.arrivalATIS {
                            atisSection(type: "ARRIVAL", icon: "airplane.arrival", color: .cyan, text: arrivalATIS)
                        }

                        if let departureATIS = datis.departureATIS, departureATIS != datis.arrivalATIS {
                            atisSection(type: "DEPARTURE", icon: "airplane.departure", color: .orange, text: departureATIS)
                        }

                        if datis.arrivalATIS == nil && datis.departureATIS == nil,
                           let combinedATIS = datis.combinedATIS {
                            atisSection(type: "ATIS", icon: "airplane", color: .green, text: combinedATIS)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingDATIS {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No D-ATIS available for \(airportCode)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("D-ATIS is typically available at major airports")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
    }

    private func atisSection(type: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(type)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }

    // MARK: - TAF View
    private var tafView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let taf = tafData[airportCode] {
                HStack {
                    Text("Terminal Aerodrome Forecast")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if let issueTime = taf.issueTimeString {
                        Text(issueTime)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Toggle between raw and decoded
                HStack {
                    Button(action: { showDecodedTAF = false }) {
                        Text("Raw")
                            .font(.system(size: 12, weight: showDecodedTAF ? .regular : .bold))
                            .foregroundColor(showDecodedTAF ? .gray : .cyan)
                    }

                    Text("|")
                        .foregroundColor(.gray)

                    Button(action: { showDecodedTAF = true }) {
                        Text("Decoded")
                            .font(.system(size: 12, weight: showDecodedTAF ? .bold : .regular))
                            .foregroundColor(showDecodedTAF ? .cyan : .gray)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)

                if showDecodedTAF {
                    decodedTAFView(taf.rawTAF)
                } else {
                    Text(taf.rawTAF)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                }

            } else if isLoadingTAF {
                loadingView
            } else {
                noDataView("No TAF available for \(airportCode)")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - MOS View
    private var mosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Output Statistics (GFS)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingMOS {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let forecasts = mosData[airportCode], !forecasts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(forecasts.prefix(12))) { forecast in
                            mosRowCard(forecast)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(minHeight: 250)
            } else if isLoadingMOS {
                loadingView
            } else {
                noDataView("No MOS data available for \(airportCode)")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Daily Forecast View
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("7-Day Forecast")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isLoadingDaily {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if !dailyForecastData.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(dailyForecastData.prefix(14)) { forecast in
                            dailyForecastRow(forecast)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingDaily {
                loadingView
            } else {
                noDataView("No daily forecast available")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Winds Aloft View
    private var windsAloftView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let winds = windsAloftData[airportCode],
                   let firstWind = winds.first,
                   let sourceStation = firstWind.sourceStation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Winds Aloft - \(airportCode)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("(from \(sourceStation))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Winds Aloft")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                if isLoadingWinds {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let winds = windsAloftData[airportCode], !winds.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(winds) { wind in
                            windsAloftRow(wind)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else if isLoadingWinds {
                loadingView
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No winds aloft data for \(airportCode)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Winds aloft uses limited reporting stations")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Weather Images View
    @State private var selectedImageTab: Int = 0
    @State private var fullScreenImageURL: String? = nil
    @State private var fullScreenImageTitle: String = ""

    private var weatherImagesView: some View {
        VStack(spacing: 8) {
            // Image type selector - now with 5 options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedImageTab = index
                            }
                        } label: {
                            Text(imageTabName(index))
                                .font(.system(size: 12, weight: selectedImageTab == index ? .bold : .medium))
                                .foregroundColor(selectedImageTab == index ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedImageTab == index ? LogbookTheme.accentGreen.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 8)

            // Content based on selected tab
            if selectedImageTab == 4 {
                // Winds Aloft Charts - different layout
                windsAloftChartsView
            } else {
                // Swipeable regions for radar/satellite/infrared
                TabView {
                    ForEach(regionsForCurrentTab, id: \.name) { region in
                        VStack(spacing: 8) {
                            Text(region.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            let urlString: String = {
                                switch selectedImageTab {
                                case 0: return region.radarStormURL ?? region.radarURL  // Color radar
                                case 1: return region.radarURL       // Base reflectivity
                                case 2: return region.satelliteURL   // Satellite
                                case 3: return region.infraredURL    // Infrared
                                default: return region.radarURL
                                }
                            }()

                            let imageTitle = "\(region.name) - \(imageTabName(selectedImageTab))"
                            weatherImageContent(urlString: urlString, title: imageTitle)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(minHeight: 350)
            }
        }
        .padding(.bottom, 12)
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageURL != nil },
            set: { if !$0 { fullScreenImageURL = nil } }
        )) {
            FullScreenImageViewer(
                urlString: fullScreenImageURL ?? "",
                title: fullScreenImageTitle,
                onDismiss: { fullScreenImageURL = nil }
            )
        }
    }

    private func imageTabName(_ index: Int) -> String {
        switch index {
        case 0: return "Radar"
        case 1: return "Base Refl"
        case 2: return "Satellite"
        case 3: return "Infrared"
        case 4: return "Winds Aloft"
        default: return ""
        }
    }

    private var regionsForCurrentTab: [WeatherRegion] {
        allWeatherRegions
    }

    // MARK: - Winds Aloft Charts View
    @State private var selectedWindsAltitude: Int = 0

    private var windsAloftChartsView: some View {
        VStack(spacing: 8) {
            // Altitude selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(windsAloftAltitudes.enumerated()), id: \.offset) { index, alt in
                        Button {
                            selectedWindsAltitude = index
                        } label: {
                            Text(alt.label)
                                .font(.system(size: 11, weight: selectedWindsAltitude == index ? .bold : .medium))
                                .foregroundColor(selectedWindsAltitude == index ? .white : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedWindsAltitude == index ? Color.cyan.opacity(0.3) : Color.black.opacity(0.3))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            // Winds aloft chart image
            if selectedWindsAltitude < windsAloftAltitudes.count {
                let altInfo = windsAloftAltitudes[selectedWindsAltitude]

                VStack(spacing: 4) {
                    Text("Winds at \(altInfo.label)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Valid for 12-hour forecast period")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                weatherImageContent(urlString: altInfo.url, title: "Winds Aloft - \(altInfo.label)")
                    .frame(minHeight: 300)
            }

            // Legend
            windsAloftLegend
        }
        .frame(minHeight: 400)
    }

    private var windsAloftLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wind Barbs Legend")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                legendItem(text: "Short line = 5kt")
                legendItem(text: "Long line = 10kt")
                legendItem(text: "Flag = 50kt")
            }
            .font(.system(size: 10))
            .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }

    private func legendItem(text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: 4, height: 4)
            Text(text)
        }
    }

    private struct WindsAloftAltitude {
        let label: String
        let url: String
    }

    private var windsAloftAltitudes: [WindsAloftAltitude] {
        // Aviation Weather Center Winds Aloft charts
        // These show forecast winds at various flight levels
        [
            WindsAloftAltitude(label: "3,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_000.gif"),
            WindsAloftAltitude(label: "6,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_060.gif"),
            WindsAloftAltitude(label: "9,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_090.gif"),
            WindsAloftAltitude(label: "12,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_120.gif"),
            WindsAloftAltitude(label: "18,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_180.gif"),
            WindsAloftAltitude(label: "24,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_240.gif"),
            WindsAloftAltitude(label: "30,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_300.gif"),
            WindsAloftAltitude(label: "34,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_340.gif"),
            WindsAloftAltitude(label: "39,000'", url: "https://aviationweather.gov/data/products/progs/F006_wnd_lt_390.gif"),
        ]
    }

    private func weatherImageContent(urlString: String, title: String = "") -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .frame(height: 280)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .onTapGesture {
                                fullScreenImageURL = urlString
                                fullScreenImageTitle = title
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(6)
                                    .padding(8)
                            }
                    case .failure:
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                Text("Failed to load")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .frame(height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
    }

    private struct WeatherRegion {
        let name: String
        let radarStormURL: String?  // Colorized NEXRAD radar with precipitation intensity
        let radarURL: String        // Base reflectivity (grayscale)
        let satelliteURL: String
        let infraredURL: String
    }

    private var allWeatherRegions: [WeatherRegion] {
        // Note: radarStormURL uses Aviation Weather Center's NEXRAD composite which shows
        // colorized precipitation intensity (green=light, yellow=moderate, red=heavy, purple=extreme)
        [
            WeatherRegion(
                name: "CONUS",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_conus.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/CONUS-LARGE_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/CONUS/GEOCOLOR/1250x750.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/CONUS/13/1250x750.jpg"
            ),
            WeatherRegion(
                name: "Northeast",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_ne.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/NORTHEAST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/ne/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/ne/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southeast",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_se.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHEAST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/se/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/se/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Great Lakes",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_cgl.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/CENTGRLAKES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/cgl/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/cgl/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Upper Mississippi",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_umv.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/UPPERMISSVLY_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/umv/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/umv/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Mississippi",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_smv.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHMISSVLY_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/smv/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/smv/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Plains",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_sp.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHPLAINS_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sp/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sp/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Northern Rockies",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_nr.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/NORTHROCKIES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/nr/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/nr/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Southern Rockies",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_sr.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/SOUTHROCKIES_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sr/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/sr/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Pacific Northwest",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_pnw.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/PACNORTHWEST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/pnw/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/pnw/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Pacific Southwest",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_psw.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/PACSOUTHWEST_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/psw/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/psw/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Alaska",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_ak.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/ALASKA_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/ak/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/ak/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Hawaii",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_hi.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/HAWAII_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/hi/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES18/ABI/SECTOR/hi/13/1200x1200.jpg"
            ),
            WeatherRegion(
                name: "Caribbean",
                radarStormURL: "https://aviationweather.gov/data/products/radar/rad_rala_car.gif",
                radarURL: "https://radar.weather.gov/ridge/standard/CARIB_0.gif",
                satelliteURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/car/GEOCOLOR/1200x1200.jpg",
                infraredURL: "https://cdn.star.nesdis.noaa.gov/GOES19/ABI/SECTOR/car/13/1200x1200.jpg"
            )
        ]
    }

    // MARK: - Helper Views
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private func noDataView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - Flight Category Badge
    private func flightCategoryBadge(_ category: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(categoryColor(category))
                .frame(width: 12, height: 12)

            Text(category)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(categoryColor(category))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor(category).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Parsed Weather Table
    private func parsedWeatherTable(_ weather: RawMETAR) -> some View {
        VStack(spacing: 8) {
            // Time
            if let obsTime = weather.observationTimeLocal {
                weatherTableRow(label: "Time", value: obsTime)
            }

            weatherTableRow(label: "Wind", value: windString(for: weather))

            if let vis = weather.visibility {
                weatherTableRow(label: "Visibility", value: "\(visibilityString(for: vis)) sm")
            }

            // RVR
            if let rvrString = parseRVR(from: weather.rawOb) {
                weatherTableRow(label: "RVR", value: rvrString)
            }

            // Clouds
            cloudLayersRow(rawMetar: weather.rawOb, flightCategory: weather.flightCategory)

            // Weather Phenomena
            if let wxString = weather.wxString, !wxString.isEmpty {
                weatherTableRow(label: "Weather", value: formatWeatherPhenomena(wxString))
            }

            // Temperature
            if let temp = weather.temp {
                let celsius = Int(temp)
                let fahrenheit = Int((temp * 9/5) + 32)
                let spread = weather.dewp.map { abs(temp - $0) } ?? 99
                temperatureRowWithCaution(
                    label: "Temperature",
                    value: "\(celsius)°C (\(fahrenheit)°F)",
                    showCaution: spread <= 3
                )
            }

            if let dewp = weather.dewp {
                let celsius = Int(dewp)
                let fahrenheit = Int((dewp * 9/5) + 32)
                weatherTableRow(label: "Dewpoint", value: "\(celsius)°C (\(fahrenheit)°F)")
            }

            if let pressureText = weather.formattedPressure(useInHg: settingsStore.usePressureInHg) {
                weatherTableRow(label: "Altimeter", value: pressureText)
            }

            if let humidity = weather.relativeHumidity {
                weatherTableRow(label: "Humidity", value: "\(humidity)%")
            }

            if let temp = weather.temp, let altim = weather.altim {
                let altimInHg = altim > 100 ? altim / 33.8639 : altim
                let elevation = Double(weather.elevationFeet ?? 0)
                let densityAlt = calculateDensityAltitude(temp: temp, altimeter: altimInHg, elevation: elevation)
                weatherTableRow(label: "Density Altitude", value: "\(densityAlt)'")
            }
        }
    }

    private func weatherTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    private func temperatureRowWithCaution(label: String, value: String, showCaution: Bool) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)

                    if showCaution {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 22)
    }

    // MARK: - Cloud Layers Row
    private func cloudLayersRow(rawMetar: String, flightCategory: String?) -> some View {
        let layers = parseCloudLayersArray(rawMetar)
        let lineCount = max(1, layers.count)
        let color = flightCategoryColor(flightCategory)

        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                Text("Clouds (AGL)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    if layers.isEmpty {
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(color)
                    } else {
                        ForEach(layers, id: \.self) { layer in
                            Text(layer)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(color)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: CGFloat(lineCount) * 20)
    }

    private func parseCloudLayersArray(_ rawMetar: String) -> [String] {
        let components = rawMetar.uppercased().components(separatedBy: " ")
        var cloudLayers: [(altitude: Int, description: String)] = []

        for component in components {
            if component == "SKC" || component == "CLR" || component == "CAVOK" {
                return ["Clear"]
            }

            var cover = ""
            var altitude = ""

            if component.hasPrefix("VV") {
                altitude = String(component.dropFirst(2))
                if let altNum = Int(altitude.prefix(while: { $0.isNumber })) {
                    let feet = altNum * 100
                    cloudLayers.append((feet, "Vertical Vis \(formatCloudAltitude(feet))"))
                }
                continue
            } else if component.hasPrefix("FEW") {
                cover = "Few"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("SCT") {
                cover = "Scattered"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("BKN") {
                cover = "Broken"
                altitude = String(component.dropFirst(3))
            } else if component.hasPrefix("OVC") {
                cover = "Overcast"
                altitude = String(component.dropFirst(3))
            }

            let altDigits = altitude.prefix(while: { $0.isNumber })
            if let altNum = Int(altDigits), !cover.isEmpty {
                let feet = altNum * 100
                cloudLayers.append((feet, "\(cover) \(formatCloudAltitude(feet))"))
            }
        }

        let sorted = cloudLayers.sorted { $0.altitude < $1.altitude }
        return sorted.map { $0.description }
    }

    private func formatCloudAltitude(_ feet: Int) -> String {
        if feet >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: feet)) ?? "\(feet)")'"
        }
        return "\(feet)'"
    }

    // MARK: - Runway Analysis Section
    private func runwayAnalysisSection(_ weather: RawMETAR) -> some View {
        Group {
            if let runways = weatherService.cachedRunways[airportCode],
               !runways.isEmpty {
                let windDir = weather.windDirection ?? 0
                let windSpeed = weather.wspd ?? 0

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                runwayWindCompassView(
                    windDirection: windDir,
                    windSpeed: windSpeed,
                    runways: runways
                )

            } else if isLoadingRunways {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading runway data...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }

    // MARK: - Runway Wind Compass View
    private func runwayWindCompassView(windDirection: Int, windSpeed: Int, runways: [RunwayInfo]) -> some View {
        let safeIndex = min(selectedRunwayIndex, runways.count - 1)
        let currentRunway = runways[max(0, safeIndex)]
        let runwayHeading = Double(currentRunway.heading)
        let windDir = Double(windDirection)
        let windSpd = Double(windSpeed)

        let angleDiff = (windDir - runwayHeading) * .pi / 180
        let headwind = Int(round(cos(angleDiff) * windSpd))
        let crosswind = Int(round(sin(angleDiff) * windSpd))

        let compassRotation = -runwayHeading
        let windRelativeToRunway = windDir - runwayHeading

        return VStack(spacing: 12) {
            HStack {
                Text("Runway Analysis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Wind: \(String(format: "%03d", windDirection))° @ \(windSpeed)kt")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)

            // Runway selector
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if selectedRunwayIndex > 0 {
                            selectedRunwayIndex -= 1
                        } else {
                            selectedRunwayIndex = runways.count - 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("RWY \(currentRunway.ident)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("\(currentRunway.length)ft × \(currentRunway.width)ft")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if selectedRunwayIndex < runways.count - 1 {
                            selectedRunwayIndex += 1
                        } else {
                            selectedRunwayIndex = 0
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)

            // HSI-Style Compass
            ZStack {
                HSICompassRoseView()
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(compassRotation))
                    .animation(.easeInOut(duration: 0.3), value: runwayHeading)

                WindParticlesView(speed: windSpd)
                    .id("wind-\(windDirection)-\(windSpeed)-\(Int(runwayHeading))")
                    .mask(Circle().padding(4))
                    .rotationEffect(.degrees(windRelativeToRunway))
                    .frame(width: 240, height: 240)
                    .opacity(windSpd > 0 ? 1.0 : 0)

                HSIRunwayGraphic(runwayIdent: currentRunway.ident)
                    .frame(width: 160, height: 160)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)

                HSIWindArrowGraphic(relativeDirection: windRelativeToRunway, speed: windSpd)
                    .frame(width: 200, height: 200)
            }
            .frame(height: 260)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < 0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if selectedRunwayIndex < runways.count - 1 {
                                    selectedRunwayIndex += 1
                                } else {
                                    selectedRunwayIndex = 0
                                }
                            }
                        } else if value.translation.width > 0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if selectedRunwayIndex > 0 {
                                    selectedRunwayIndex -= 1
                                } else {
                                    selectedRunwayIndex = runways.count - 1
                                }
                            }
                        }
                    }
            )

            // Wind component cards
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: headwind >= 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(headwind))")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                        Text("kt")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(headwind >= 0 ? LogbookTheme.accentGreen : .red)

                    Text(headwind >= 0 ? "HEADWIND" : "TAILWIND")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: crosswind > 0 ? "arrow.right" : (crosswind < 0 ? "arrow.left" : "minus"))
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(crosswind))")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                        Text("kt")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(abs(crosswind) <= 10 ? LogbookTheme.accentGreen : (abs(crosswind) <= 20 ? .orange : .red))

                    Text("CROSSWIND")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            .padding(.horizontal, 12)

            // Page indicator dots
            if runways.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<runways.count, id: \.self) { index in
                        Circle()
                            .fill(index == safeIndex ? LogbookTheme.accentGreen : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - MOS Row Card
    private func mosRowCard(_ forecast: MOSForecast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: mosCloudIcon(forecast))
                    .font(.system(size: 16))
                    .foregroundColor(mosIconColor(forecast))
                    .symbolRenderingMode(.multicolor)

                Text(mosTimeHeader(forecast))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)

                Spacer()

                if let pop = forecast.p06 ?? forecast.p12, pop >= 30 {
                    Text("\(pop)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pop >= 70 ? Color.blue : Color.blue.opacity(0.6))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)

            if let tmp = forecast.tmp, let dpt = forecast.dpt {
                mosTableRow(label: "Temperature", value: "\(tmp)°F / \(dpt)°F dew")
            } else if let tmp = forecast.tmp {
                mosTableRow(label: "Temperature", value: "\(tmp)°F")
            }

            if let wdr = forecast.windDirectionDegrees, let wsp = forecast.wsp {
                let windStr = wsp == 0 ? "Calm" : "\(String(format: "%03d", wdr))° at \(wsp)kt"
                mosTableRow(label: "Wind", value: windStr)
            }

            mosTableRow(label: "Sky", value: forecast.cloudCoverDescription)

            if let pop = forecast.p06 ?? forecast.p12, pop > 0 {
                mosTableRow(label: "Precip", value: "\(pop)% chance")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    private func mosTableRow(label: String, value: String) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    private func mosCloudIcon(_ forecast: MOSForecast) -> String {
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            if forecast.pos ?? 0 >= 30 {
                return "cloud.snow.fill"
            }
            return "cloud.rain.fill"
        }

        if let obv = forecast.obv?.uppercased() {
            if obv.contains("FG") {
                return "cloud.fog.fill"
            }
            if obv.contains("HZ") || obv.contains("BR") {
                return "cloud.fog.fill"
            }
        }

        switch forecast.cld?.uppercased() {
        case "CL": return "sun.max.fill"
        case "FW", "SC": return "cloud.sun.fill"
        case "BK", "OV": return "cloud.fill"
        default: return "cloud.fill"
        }
    }

    private func mosIconColor(_ forecast: MOSForecast) -> Color {
        if let pop = forecast.p06 ?? forecast.p12, pop >= 50 {
            return .blue
        }

        if let obv = forecast.obv?.uppercased(), obv.contains("FG") {
            return .gray
        }

        switch forecast.cld?.uppercased() {
        case "CL": return .yellow
        case "FW", "SC": return .cyan
        case "BK", "OV": return .gray
        default: return .gray
        }
    }

    private func mosTimeHeader(_ forecast: MOSForecast) -> String {
        guard let date = forecast.forecastTime else { return forecast.forecastHourString }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    // MARK: - Daily Forecast Row
    private func dailyForecastRow(_ forecast: DailyForecastData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: forecast.icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(dailyForecastColor(for: forecast))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(forecast.shortForecast)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                if let high = forecast.highTemp {
                    Text("\(high)°")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                } else if let low = forecast.lowTemp {
                    Text("\(low)°")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                if let precip = forecast.precipChance, precip > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("\(precip)%")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                }
            }

            if let windString = forecast.windString {
                HStack(spacing: 4) {
                    Spacer()
                        .frame(width: 30)
                    Image(systemName: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(windString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    private func dailyForecastColor(for forecast: DailyForecastData) -> Color {
        let text = forecast.shortForecast.lowercased()
        let icon = forecast.icon.lowercased()

        if text.contains("thunder") || icon.contains("bolt") { return .purple }
        if text.contains("rain") || text.contains("shower") || icon.contains("rain") { return .blue }
        if text.contains("snow") || text.contains("ice") || text.contains("sleet") || icon.contains("snow") { return .cyan }
        if text.contains("fog") || text.contains("haze") || text.contains("mist") || icon.contains("fog") { return .gray }
        if text.contains("cloudy") || text.contains("overcast") || icon.contains("cloud") { return Color.gray.opacity(0.8) }
        if text.contains("sunny") || text.contains("clear") || icon.contains("sun") { return .yellow }
        if icon.contains("moon") { return Color.blue.opacity(0.7) }

        return .cyan
    }

    // MARK: - Winds Aloft Row
    private func windsAloftRow(_ wind: WindsAloftData) -> some View {
        HStack {
            Text("\(wind.altitude / 1000)K")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .leading)

            Text(wind.windString)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            if let temp = wind.temperature {
                Text("\(temp)°C")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: - Decoded TAF View
    private func decodedTAFView(_ rawTAF: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let groups = parseTAFGroups(rawTAF)
                let overallCategory = groups.first?.flightCategory

                Text(rawTAF)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor(overallCategory))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)

                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: group.cloudIcon)
                                .font(.system(size: 16))
                                .foregroundColor(categoryColor(group.flightCategory))
                                .symbolRenderingMode(.multicolor)

                            Text(group.header)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(group.headerColor)

                            Spacer()

                            if let category = group.flightCategory {
                                Text(category)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor(category))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.bottom, 4)

                        ForEach(group.rows, id: \.label) { row in
                            tafTableRow(label: row.label, value: row.value, category: group.flightCategory)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(minHeight: 150)
    }

    private func tafTableRow(label: String, value: String, category: String? = nil) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 20) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width * 0.35, alignment: .trailing)

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(categoryColor(category))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    private struct TAFGroup {
        let header: String
        let headerColor: Color
        let rows: [TAFRow]
        let flightCategory: String?
        let cloudIcon: String

        init(header: String, headerColor: Color, rows: [TAFRow], flightCategory: String? = nil, cloudIcon: String = "cloud.fill") {
            self.header = header
            self.headerColor = headerColor
            self.rows = rows
            self.flightCategory = flightCategory
            self.cloudIcon = cloudIcon
        }
    }

    private struct TAFRow: Hashable {
        let label: String
        let value: String
    }

    private func parseTAFGroups(_ rawTAF: String) -> [TAFGroup] {
        var groups: [TAFGroup] = []

        let normalized = rawTAF
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        let pattern = "(TAF\\s+\\w+|FM\\d+|TEMPO\\s+\\d+\\/\\d+|BECMG\\s+\\d+\\/\\d+|PROB\\d+\\s+\\d+\\/\\d+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        guard let matches = regex?.matches(in: normalized, options: [], range: NSRange(normalized.startIndex..., in: normalized)) else {
            let analysis = analyzeTAFSegment(normalized)
            return [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: analysis.category, cloudIcon: analysis.icon)]
        }

        var lastEnd = normalized.startIndex

        for match in matches {
            guard let range = Range(match.range, in: normalized) else { continue }

            if lastEnd < range.lowerBound {
                let segment = String(normalized[lastEnd..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !segment.isEmpty && !groups.isEmpty {
                    let analysis = analyzeTAFSegment(segment)
                    groups[groups.count - 1] = TAFGroup(
                        header: groups[groups.count - 1].header,
                        headerColor: groups[groups.count - 1].headerColor,
                        rows: groups[groups.count - 1].rows + decodeTAFSegment(segment),
                        flightCategory: analysis.category,
                        cloudIcon: analysis.icon
                    )
                }
            }

            let matchText = String(normalized[range])
            let (header, color) = getTAFGroupHeader(matchText)
            groups.append(TAFGroup(header: header, headerColor: color, rows: []))

            lastEnd = range.upperBound
        }

        if lastEnd < normalized.endIndex {
            let segment = String(normalized[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !segment.isEmpty && !groups.isEmpty {
                let analysis = analyzeTAFSegment(segment)
                groups[groups.count - 1] = TAFGroup(
                    header: groups[groups.count - 1].header,
                    headerColor: groups[groups.count - 1].headerColor,
                    rows: decodeTAFSegment(segment),
                    flightCategory: analysis.category,
                    cloudIcon: analysis.icon
                )
            }
        }

        let defaultAnalysis = analyzeTAFSegment(normalized)
        return groups.isEmpty ? [TAFGroup(header: "Forecast", headerColor: .cyan, rows: decodeTAFSegment(normalized), flightCategory: defaultAnalysis.category, cloudIcon: defaultAnalysis.icon)] : groups
    }

    private func getTAFGroupHeader(_ match: String) -> (String, Color) {
        if match.hasPrefix("TAF") {
            return ("Initial Forecast", .green)
        } else if match.hasPrefix("FM") {
            let digits = match.dropFirst(2)
            if digits.count >= 4 {
                let hour = String(digits.prefix(4).suffix(2))
                return ("From \(hour)00Z", .cyan)
            }
            return ("From", .cyan)
        } else if match.contains("TEMPO") {
            return ("Temporary", .orange)
        } else if match.contains("BECMG") {
            return ("Becoming", .yellow)
        } else if match.contains("PROB") {
            let probMatch = match.prefix(while: { $0.isNumber || $0 == "B" || $0 == "O" || $0 == "R" || $0 == "P" })
            let prob = probMatch.filter { $0.isNumber }
            return ("Probability \(prob)%", .purple)
        }
        return ("Forecast", .cyan)
    }

    private func analyzeTAFSegment(_ segment: String) -> (category: String?, icon: String) {
        let upper = segment.uppercased()

        if upper.contains("TS") { return ("IFR", "cloud.bolt.rain.fill") }
        if upper.contains("+RA") || upper.contains("TSRA") { return ("IFR", "cloud.heavyrain.fill") }
        if upper.contains("RA") || upper.contains("-RA") { return ("MVFR", "cloud.rain.fill") }
        if upper.contains("SN") || upper.contains("+SN") { return ("IFR", "cloud.snow.fill") }
        if upper.contains("FZRA") || upper.contains("FZDZ") { return ("LIFR", "cloud.sleet.fill") }
        if upper.contains("FG") { return ("LIFR", "cloud.fog.fill") }
        if upper.contains("BR") || upper.contains("HZ") { return ("MVFR", "cloud.fog.fill") }
        if upper.contains("1/4SM") || upper.contains("1/2SM") || upper.contains("3/4SM") || upper.contains("0SM") { return ("LIFR", "cloud.fill") }
        if let _ = upper.range(of: "\\b[12]SM\\b", options: .regularExpression) { return ("IFR", "cloud.fill") }
        if upper.contains("1 1/2SM") || upper.contains("2 1/2SM") { return ("IFR", "cloud.fill") }
        if let _ = upper.range(of: "\\b[345]SM\\b", options: .regularExpression) { return ("MVFR", "cloud.fill") }

        if upper.contains("OVC") {
            if let range = upper.range(of: "OVC\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)) {
                    if height < 5 { return ("LIFR", "cloud.fill") }
                    else if height < 10 { return ("IFR", "cloud.fill") }
                    else if height <= 30 { return ("MVFR", "cloud.fill") }
                    return ("VFR", "cloud.fill")
                }
            }
            return ("MVFR", "cloud.fill")
        }
        if upper.contains("BKN") {
            if let range = upper.range(of: "BKN\\d{3}", options: .regularExpression) {
                let match = String(upper[range])
                if let height = Int(match.dropFirst(3)) {
                    if height < 5 { return ("LIFR", "cloud.fill") }
                    else if height < 10 { return ("IFR", "cloud.fill") }
                    else if height <= 30 { return ("MVFR", "cloud.fill") }
                    return ("VFR", "cloud.fill")
                }
            }
            return ("VFR", "cloud.fill")
        }
        if upper.contains("SCT") { return ("VFR", "cloud.sun.fill") }
        if upper.contains("FEW") { return ("VFR", "cloud.sun.fill") }
        if upper.contains("SKC") || upper.contains("CLR") || upper.contains("CAVOK") { return ("VFR", "sun.max.fill") }
        if upper.contains("P6SM") || upper.contains("9999") { return ("VFR", "cloud.sun.fill") }

        return (nil, "cloud.fill")
    }

    private func decodeTAFSegment(_ segment: String) -> [TAFRow] {
        var decoded: [TAFRow] = []
        let parts = segment.components(separatedBy: " ").filter { !$0.isEmpty }

        for part in parts {
            if let row = decodeTAFElement(part) {
                decoded.append(row)
            }
        }

        return decoded
    }

    private func decodeTAFElement(_ element: String) -> TAFRow? {
        let upper = element.uppercased()

        if upper.count == 4 && upper.first?.isLetter == true { return nil }
        if upper.contains("/") && upper.count == 9 { return nil }

        if upper.hasSuffix("KT") {
            let windPart = upper.dropLast(2)
            if windPart.count >= 5 {
                let dir = String(windPart.prefix(3))
                let remaining = windPart.dropFirst(3)

                if remaining.contains("G") {
                    let gustParts = remaining.components(separatedBy: "G")
                    if gustParts.count == 2 {
                        return TAFRow(label: "Wind", value: "\(dir)° at \(gustParts[0])kt gusting \(gustParts[1])kt")
                    }
                }
                return TAFRow(label: "Wind", value: "\(dir)° at \(remaining)kt")
            }
        }

        if upper == "P6SM" || upper == "9999" {
            return TAFRow(label: "Visibility", value: "6+ SM")
        }
        if upper.hasSuffix("SM") {
            let vis = upper.dropLast(2)
            return TAFRow(label: "Visibility", value: "\(vis) SM")
        }
        if upper.count == 4, let meters = Int(upper), meters > 0 && meters <= 9999 {
            let miles = Double(meters) / 1609.34
            if miles >= 6 {
                return TAFRow(label: "Visibility", value: "6+ SM")
            } else if miles >= 1 {
                return TAFRow(label: "Visibility", value: String(format: "%.0f SM", miles))
            } else {
                return TAFRow(label: "Visibility", value: String(format: "%.1f SM", miles))
            }
        }

        if upper.hasPrefix("FEW") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Few \(heightFt)'")
        }
        if upper.hasPrefix("SCT") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Scattered \(heightFt)'")
        }
        if upper.hasPrefix("BKN") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Broken \(heightFt)'")
        }
        if upper.hasPrefix("OVC") {
            let height = upper.dropFirst(3)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Clouds", value: "Overcast \(heightFt)'")
        }
        if upper == "SKC" || upper == "CLR" {
            return TAFRow(label: "Clouds", value: "Clear")
        }
        if upper.hasPrefix("VV") {
            let height = upper.dropFirst(2)
            let heightFt = (Int(height) ?? 0) * 100
            return TAFRow(label: "Visibility", value: "Vertical \(heightFt)'")
        }

        switch upper {
        case "RA": return TAFRow(label: "Weather", value: "Rain")
        case "-RA": return TAFRow(label: "Weather", value: "Light rain")
        case "+RA": return TAFRow(label: "Weather", value: "Heavy rain")
        case "SN": return TAFRow(label: "Weather", value: "Snow")
        case "-SN": return TAFRow(label: "Weather", value: "Light snow")
        case "+SN": return TAFRow(label: "Weather", value: "Heavy snow")
        case "TS": return TAFRow(label: "Weather", value: "Thunderstorm")
        case "TSRA": return TAFRow(label: "Weather", value: "Thunderstorm with rain")
        case "FG": return TAFRow(label: "Weather", value: "Fog")
        case "BR": return TAFRow(label: "Weather", value: "Mist")
        case "HZ": return TAFRow(label: "Weather", value: "Haze")
        case "FU": return TAFRow(label: "Weather", value: "Smoke")
        case "DZ": return TAFRow(label: "Weather", value: "Drizzle")
        case "FZRA": return TAFRow(label: "Weather", value: "Freezing rain")
        case "FZDZ": return TAFRow(label: "Weather", value: "Freezing drizzle")
        case "SH": return TAFRow(label: "Weather", value: "Showers")
        case "SHRA": return TAFRow(label: "Weather", value: "Rain showers")
        case "-SHRA": return TAFRow(label: "Weather", value: "Light rain showers")
        case "+SHRA": return TAFRow(label: "Weather", value: "Heavy rain showers")
        case "SHSN": return TAFRow(label: "Weather", value: "Snow showers")
        case "NSW": return TAFRow(label: "Weather", value: "No significant weather")
        case "CAVOK": return TAFRow(label: "Conditions", value: "Ceiling and visibility OK")
        default: break
        }

        return nil
    }

    // MARK: - Helper Functions
    private func categoryColor(_ category: String?) -> Color {
        guard let category = category else { return .gray }
        switch category {
        case "VFR": return .green
        case "MVFR": return .blue
        case "IFR": return .red
        case "LIFR": return Color(red: 1.0, green: 0.0, blue: 1.0)
        default: return .gray
        }
    }

    private func flightCategoryColor(_ category: String?) -> Color {
        guard let cat = category?.uppercased() else { return .cyan }
        switch cat {
        case "VFR": return .green
        case "MVFR": return .yellow
        case "IFR": return .red
        case "LIFR": return Color(red: 1.0, green: 0.0, blue: 1.0)
        default: return .cyan
        }
    }

    private func timeAgeColor(_ weather: RawMETAR) -> Color {
        guard let timestamp = weather.obsTime else { return .gray }

        let observationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let elapsed = Date().timeIntervalSince(observationDate)
        let minutes = Int(elapsed / 60)

        if minutes < 30 { return .green }
        else if minutes < 60 { return .yellow }
        else if minutes < 120 { return .orange }
        else { return .red }
    }

    private func windString(for weather: RawMETAR) -> String {
        if let dir = weather.windDirection, let speed = weather.wspd {
            if speed == 0 { return "Winds calm" }
            if let gust = weather.wgst {
                return "\(String(format: "%03d", dir))° at \(speed) kts gusting \(gust)"
            }
            return "\(String(format: "%03d", dir))° at \(speed) kts"
        } else if let speed = weather.wspd, speed > 0 {
            if let gust = weather.wgst {
                return "Variable at \(speed) kts gusting \(gust)"
            }
            return "Variable at \(speed) kts"
        }
        return "Winds calm"
    }

    private func visibilityString(for vis: Double) -> String {
        if vis >= 10 { return "10+" }
        if vis >= 6 { return "6+" }

        let tolerance = 0.01
        if abs(vis - 0.25) < tolerance { return "¼" }
        if abs(vis - 0.5) < tolerance { return "½" }
        if abs(vis - 0.75) < tolerance { return "¾" }
        if abs(vis - 1.0) < tolerance { return "1" }
        if abs(vis - 1.25) < tolerance { return "1¼" }
        if abs(vis - 1.5) < tolerance { return "1½" }
        if abs(vis - 1.75) < tolerance { return "1¾" }
        if abs(vis - 2.0) < tolerance { return "2" }
        if abs(vis - 2.5) < tolerance { return "2½" }
        if abs(vis - 3.0) < tolerance { return "3" }
        if abs(vis - 4.0) < tolerance { return "4" }
        if abs(vis - 5.0) < tolerance { return "5" }

        if vis == floor(vis) {
            return String(format: "%.0f", vis)
        }
        return String(format: "%.1f", vis)
    }

    private func calculateDensityAltitude(temp: Double, altimeter: Double, elevation: Double) -> Int {
        let isaTemp = 15.0 - (elevation / 1000.0 * 2.0)
        let tempDeviation = temp - isaTemp
        let pressureAlt = (29.92 - altimeter) * 1000 + elevation
        let densityAlt = pressureAlt + (120 * tempDeviation)
        return Int(densityAlt)
    }

    private func parseRVR(from rawMetar: String) -> String? {
        let pattern = "R\\d{2}[LRC]?\\/[PM]?\\d{4}(V[PM]?\\d{4})?FT"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: rawMetar, options: [], range: NSRange(rawMetar.startIndex..., in: rawMetar)),
           let range = Range(match.range, in: rawMetar) {
            return String(rawMetar[range])
        }
        return nil
    }

    private func formatWeatherPhenomena(_ wxString: String) -> String {
        let phenomena: [String: String] = [
            "RA": "Rain", "-RA": "Light Rain", "+RA": "Heavy Rain",
            "SN": "Snow", "-SN": "Light Snow", "+SN": "Heavy Snow",
            "TS": "Thunderstorm", "TSRA": "Thunderstorm w/Rain",
            "FG": "Fog", "BR": "Mist", "HZ": "Haze", "FU": "Smoke",
            "DZ": "Drizzle", "FZRA": "Freezing Rain", "FZDZ": "Freezing Drizzle",
            "SH": "Showers", "SHRA": "Rain Showers", "-SHRA": "Light Rain Showers",
            "GR": "Hail", "GS": "Small Hail", "PE": "Ice Pellets",
            "BLSN": "Blowing Snow", "DRSN": "Drifting Snow",
            "VCSH": "Showers Vicinity", "VCTS": "Thunderstorm Vicinity"
        ]

        let parts = wxString.components(separatedBy: " ")
        let decoded = parts.map { phenomena[$0.uppercased()] ?? $0 }
        return decoded.joined(separator: ", ")
    }
}

// MARK: - Full Screen Image Viewer with Pinch to Zoom
struct FullScreenImageViewer: View {
    let urlString: String
    let title: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            // Image with gestures
            GeometryReader { geometry in
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 1.0), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            if scale < 1.0 {
                                                withAnimation(.spring()) {
                                                    scale = 1.0
                                                    offset = .zero
                                                }
                                            }
                                        }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                                .gesture(
                                    TapGesture(count: 2)
                                        .onEnded {
                                            withAnimation(.spring()) {
                                                if scale > 1.0 {
                                                    scale = 1.0
                                                    offset = .zero
                                                    lastOffset = .zero
                                                } else {
                                                    scale = 2.5
                                                }
                                            }
                                        }
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Failed to load image")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }

            // Header overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("Pinch to zoom • Double-tap to toggle • Swipe down to close")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe down to dismiss (only when not zoomed)
                    if scale <= 1.0 && value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
        .statusBar(hidden: true)
    }
}

import CoreLocation

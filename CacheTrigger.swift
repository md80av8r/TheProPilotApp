//
//  WeatherCacheService.swift
//  ProPilotApp
//
//  Weather caching service for offline access during flights
//  Caches at OUT time (primary) and OFF time (failsafe)
//

import Foundation

/// When the cache was triggered
enum CacheTrigger: String, Codable {
    case outTime  // Cached when OUT time set (at gate, strong signal)
    case offTime  // Cached when OFF time detected (takeoff roll, failsafe)
}

/// Cached weather data for a specific leg
struct CachedWeatherData: Codable {
    let legId: UUID
    let departureICAO: String
    let arrivalICAO: String
    let cachedAt: Date
    let trigger: CacheTrigger
    
    // Weather products
    var departureMETAR: RawMETAR?
    var arrivalMETAR: RawMETAR?
    var departureTAF: RawTAF?
    var arrivalTAF: RawTAF?
    var departureMOS: MOSForecast?
    var arrivalMOS: MOSForecast?
    var departureWindsAloft: [WindsAloftLevel]?
    var arrivalWindsAloft: [WindsAloftLevel]?
    var departureDailyForecasts: [DailyForecast]?
    var arrivalDailyForecasts: [DailyForecast]?
    var departureDATIS: String?
    var arrivalDATIS: String?
    
    // Weather images (stored as Data)
    var departureRadarImage: Data?
    var arrivalRadarImage: Data?
    var departureSatelliteImage: Data?
    var arrivalSatelliteImage: Data?
    
    /// Human-readable time since cache
    var timeAgo: String {
        let interval = Date().timeIntervalSince(cachedAt)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        
        if hours > 0 {
            return "Cached \(hours)h ago"
        } else if minutes > 0 {
            return "Cached \(minutes)m ago"
        } else {
            return "Cached just now"
        }
    }
}

/// Service for caching and retrieving weather data
actor WeatherCacheService {
    static let shared = WeatherCacheService()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        // Store caches in Documents/WeatherCache
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("WeatherCache", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Cache weather for a leg (called at OUT or OFF time)
    func cacheWeatherForLeg(
        legId: UUID,
        departureICAO: String,
        arrivalICAO: String,
        trigger: CacheTrigger
    ) async {
        print("☁️ Caching weather for leg \(legId.uuidString.prefix(8))... (\(trigger.rawValue))")
        print("   \(departureICAO) → \(arrivalICAO)")
        
        // Check if already cached (avoid duplicate caching)
        if let existing = loadCachedWeather(for: legId) {
            print("   ⚠️ Already cached at \(existing.trigger.rawValue) - skipping")
            return
        }
        
        var cache = CachedWeatherData(
            legId: legId,
            departureICAO: departureICAO,
            arrivalICAO: arrivalICAO,
            cachedAt: Date(),
            trigger: trigger
        )
        
        // Fetch all weather products for both airports
        async let depMETAR = fetchMETAR(for: departureICAO)
        async let arrMETAR = fetchMETAR(for: arrivalICAO)
        async let depTAF = fetchTAF(for: departureICAO)
        async let arrTAF = fetchTAF(for: arrivalICAO)
        async let depMOS = fetchMOS(for: departureICAO)
        async let arrMOS = fetchMOS(for: arrivalICAO)
        async let depWinds = fetchWindsAloft(for: departureICAO)
        async let arrWinds = fetchWindsAloft(for: arrivalICAO)
        async let depDaily = fetchDailyForecast(for: departureICAO)
        async let arrDaily = fetchDailyForecast(for: arrivalICAO)
        async let depDATIS = fetchDATIS(for: departureICAO)
        async let arrDATIS = fetchDATIS(for: arrivalICAO)
        
        // Await all results
        cache.departureMETAR = await depMETAR
        cache.arrivalMETAR = await arrMETAR
        cache.departureTAF = await depTAF
        cache.arrivalTAF = await arrTAF
        cache.departureMOS = await depMOS
        cache.arrivalMOS = await arrMOS
        cache.departureWindsAloft = await depWinds
        cache.arrivalWindsAloft = await arrWinds
        cache.departureDailyForecasts = await depDaily
        cache.arrivalDailyForecasts = await arrDaily
        cache.departureDATIS = await depDATIS
        cache.arrivalDATIS = await arrDATIS
        
        // Save to disk
        saveCache(cache)
        
        let productsCount = [
            cache.departureMETAR, cache.arrivalMETAR,
            cache.departureTAF, cache.arrivalTAF,
            cache.departureMOS, cache.arrivalMOS,
            cache.departureWindsAloft, cache.arrivalWindsAloft
        ].compactMap { $0 }.count
        
        print("   ✅ Cached \(productsCount) weather products")
    }
    
    /// Load cached weather for a leg
    func loadCachedWeather(for legId: UUID) -> CachedWeatherData? {
        let fileURL = cacheDirectory.appendingPathComponent("\(legId.uuidString).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(CachedWeatherData.self, from: data)
            print("☁️ Loaded cached weather for leg \(legId.uuidString.prefix(8))")
            return cache
        } catch {
            print("❌ Failed to load cache: \(error)")
            return nil
        }
    }
    
    /// Check if weather is cached for a leg
    func hasCachedWeather(for legId: UUID) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent("\(legId.uuidString).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Delete cache for a leg (e.g., when trip completed)
    func deleteCachedWeather(for legId: UUID) {
        let fileURL = cacheDirectory.appendingPathComponent("\(legId.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
        print("🗑️ Deleted weather cache for leg \(legId.uuidString.prefix(8))")
    }
    
    /// Cache a weather image for a leg
    func cacheWeatherImage(for legId: UUID, imageType: String, imageData: Data) {
        guard var cache = loadCachedWeather(for: legId) else {
            print("⚠️ No cache found for leg \(legId.uuidString.prefix(8)) - can't save image")
            return
        }
        
        // Store image data
        switch imageType {
        case "departureRadar":
            cache.departureRadarImage = imageData
        case "arrivalRadar":
            cache.arrivalRadarImage = imageData
        case "departureSatellite":
            cache.departureSatelliteImage = imageData
        case "arrivalSatellite":
            cache.arrivalSatelliteImage = imageData
        default:
            break
        }
        
        saveCache(cache)
        print("☁️ Cached \(imageType) image (\(imageData.count / 1024)KB)")
    }
    
    /// Cleanup old caches (7+ days old)
    func cleanupOldCaches() {
        let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        var deletedCount = 0
        for fileURL in contents ?? [] {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < sevenDaysAgo {
                try? fileManager.removeItem(at: fileURL)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            print("🗑️ Cleaned up \(deletedCount) old weather caches")
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveCache(_ cache: CachedWeatherData) {
        let fileURL = cacheDirectory.appendingPathComponent("\(cache.legId.uuidString).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cache)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save cache: \(error)")
        }
    }
    
    // MARK: - Weather Fetching
    
    private func fetchMETAR(for icao: String) async -> RawMETAR? {
        do {
            return try await BannerWeatherService.shared.fetchMETAR(for: icao)
        } catch {
            print("⚠️ Failed to fetch METAR for \(icao): \(error)")
            return nil
        }
    }
    
    private func fetchTAF(for icao: String) async -> RawTAF? {
        do {
            return try await BannerWeatherService.shared.fetchTAF(for: icao)
        } catch {
            print("⚠️ Failed to fetch TAF for \(icao): \(error)")
            return nil
        }
    }
    
    private func fetchMOS(for icao: String) async -> MOSForecast? {
        do {
            return try await BannerWeatherService.shared.fetchMOS(for: icao)
        } catch {
            print("⚠️ Failed to fetch MOS for \(icao): \(error)")
            return nil
        }
    }
    
    private func fetchWindsAloft(for icao: String) async -> [WindsAloftLevel]? {
        do {
            return try await BannerWeatherService.shared.fetchWindsAloft(for: icao)
        } catch {
            print("⚠️ Failed to fetch Winds Aloft for \(icao): \(error)")
            return nil
        }
    }
    
    private func fetchDailyForecast(for icao: String) async -> [DailyForecast]? {
        do {
            return try await BannerWeatherService.shared.fetchDailyForecast(for: icao)
        } catch {
            print("⚠️ Failed to fetch Daily Forecast for \(icao): \(error)")
            return nil
        }
    }
    
    private func fetchDATIS(for icao: String) async -> String? {
        do {
            return try await BannerWeatherService.shared.fetchDATIS(for: icao)
        } catch {
            print("⚠️ Failed to fetch DATIS for \(icao): \(error)")
            return nil
        }
    }
}
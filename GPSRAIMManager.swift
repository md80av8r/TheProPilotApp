// GPSRAIMManager.swift - Professional GPS/RAIM system for aviation
import SwiftUI
import CoreLocation
import CoreMotion
import simd

// MARK: - GPS Flight Phase
enum GPSFlightPhase: String, CaseIterable {
    case ground = "Ground"
    case taxi = "Taxi"
    case takeoffLanding = "Takeoff/Landing"
    case cruise = "Cruise"
    
    var color: Color {
        switch self {
        case .ground: return .gray
        case .taxi: return .orange
        case .takeoffLanding: return .yellow
        case .cruise: return .green
        }
    }
}

// MARK: - Enhanced RAIM Data Structures
struct EnhancedSatelliteData {
    let satelliteID: Int
    let position: SIMD3<Double>  // ECEF coordinates (meters)
    let pseudorange: Double      // Measured pseudorange (meters)
    let elevation: Double        // Elevation angle (radians)
    let azimuth: Double          // Azimuth angle (radians)
    let signalStrength: Double   // C/N0 ratio (dB-Hz)
    let ephemerisAge: TimeInterval // Age of ephemeris data (seconds)
    let constellation: SatelliteConstellation
    let isUsed: Bool
    
    // Convert to legacy GPSSatellite for UI compatibility
    var legacySatellite: GPSSatellite {
        return GPSSatellite(
            id: satelliteID,
            elevation: elevation * 180.0 / .pi, // Convert to degrees
            azimuth: azimuth * 180.0 / .pi,     // Convert to degrees
            snr: signalStrength,
            isUsed: isUsed,
            constellation: constellation
        )
    }
}

struct EnhancedRAIMResult {
    let status: EnhancedRAIMStatus
    let testStatistic: Double
    let threshold: Double
    let horizontalProtectionLevel: Double
    let verticalProtectionLevel: Double
    let faultySatellites: [Int]
    let dop: EnhancedDOPValues
    let confidence: Double
    let integrityRisk: Double
}

struct EnhancedDOPValues {
    let hdop: Double  // Horizontal DOP
    let vdop: Double  // Vertical DOP
    let pdop: Double  // Position DOP
    let gdop: Double  // Geometric DOP
    let tdop: Double  // Time DOP
}

enum EnhancedRAIMStatus {
    case available(quality: RAIMQuality)
    case caution(reason: String)
    case unavailable(reason: String)
    case faultDetected(satellites: [Int])
    
    // Convert to legacy RAIMStatus for UI compatibility
    var legacyStatus: RAIMStatus {
        switch self {
        case .available: return .available
        case .caution: return .caution
        case .unavailable: return .unavailable
        case .faultDetected: return .caution
        }
    }
}

enum RAIMQuality {
    case excellent  // HPL < 10m, >8 satellites
    case good       // HPL < 25m, 6-8 satellites
    case adequate   // HPL < 40m, 5-6 satellites
    case marginal   // HPL > 40m, 5 satellites
}

// MARK: - GPS/RAIM Manager (Enhanced)
class GPSRAIMManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Legacy UI properties (maintained for compatibility)
    @Published var satellites: [GPSSatellite] = []
    @Published var raimStatus: RAIMStatus = .unavailable
    @Published var gpsAccuracy: GPSAccuracy = .invalid
    @Published var horizontalAccuracy: Double = 0
    @Published var verticalAccuracy: Double = 0
    @Published var currentSpeed: Double = 0 // Knots
    @Published var currentHeading: Double = 0
    @Published var altitude: Double = 0 // Feet MSL
    @Published var isGPSValid = false
    @Published var satelliteCount = 0
    @Published var pdop: Double = 99.0
    @Published var hdop: Double = 99.0
    @Published var vdop: Double = 99.0

    // Enhanced RAIM properties
    @Published var enhancedRAIMResult: EnhancedRAIMResult?
    @Published var enhancedSatellites: [EnhancedSatelliteData] = []
    @Published var protectionLevels: (horizontal: Double, vertical: Double) = (999.0, 999.0)
    @Published var integrityRisk: Double = 1.0
    @Published var faultySatelliteIDs: [Int] = []

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var lastLocation: CLLocation?
    private var speedSamples: [Double] = []
    
    // Enhanced RAIM Configuration
    private let probabilityOfFalseAlarm: Double = 1.0/15000.0
    private let probabilityOfMissedDetection: Double = 0.001
    private let measurementNoiseStd: Double = 2.0
    private let clockBiasNoiseStd: Double = 10.0
    private let minSatellitesForFD: Int = 5
    private let minSatellitesForFDE: Int = 6
    private let minElevationAngle: Double = 5.0 * .pi / 180.0

    override init() {
        super.init()
        setupGPS()
        setupMotionSensors()
    }

    private func setupGPS() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 0
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupMotionSensors() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                self?.processMotionData(motion)
            }
        }
    }

    func startGPSMonitoring() {
        locationManager.startUpdatingLocation()
        simulateEnhancedSatelliteData()
    }

    func stopGPSMonitoring() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Location Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        updateGPSMetrics(location)
        performEnhancedRAIMAnalysis(location)
        calculateSpeed(location)

        lastLocation = location
    }

    private func updateGPSMetrics(_ location: CLLocation) {
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        altitude = location.altitude * 3.28084

        if horizontalAccuracy < 0 {
            gpsAccuracy = .invalid
        } else if horizontalAccuracy <= 3 {
            gpsAccuracy = .excellent
        } else if horizontalAccuracy <= 5 {
            gpsAccuracy = .good
        } else if horizontalAccuracy <= 10 {
            gpsAccuracy = .fair
        } else {
            gpsAccuracy = .poor
        }

        isGPSValid = horizontalAccuracy > 0 && horizontalAccuracy < 20
    }

    private func calculateSpeed(_ location: CLLocation) {
        let speedMPS = location.speed
        if speedMPS >= 0 {
            currentSpeed = speedMPS * 1.94384
            speedSamples.append(currentSpeed)

            if speedSamples.count > 10 {
                speedSamples.removeFirst()
            }
        }

        if location.course >= 0 {
            currentHeading = location.course
        }
    }

    // MARK: - Enhanced RAIM Analysis
    private func performEnhancedRAIMAnalysis(_ location: CLLocation) {
        guard enhancedSatellites.count >= 4 else {
            setUnavailableRAIM(reason: "Insufficient satellites")
            return
        }
        
        let validSatellites = filterValidSatellites(enhancedSatellites)
        guard validSatellites.count >= 4 else {
            setUnavailableRAIM(reason: "Insufficient valid satellites")
            return
        }
        
        // Compute enhanced RAIM
        let result = computeEnhancedRAIM(userPosition: location, satellites: validSatellites)
        
        // Update published properties
        enhancedRAIMResult = result
        protectionLevels = (result.horizontalProtectionLevel, result.verticalProtectionLevel)
        integrityRisk = result.integrityRisk
        faultySatelliteIDs = result.faultySatellites
        
        // Update legacy properties for UI compatibility
        raimStatus = result.status.legacyStatus
        pdop = result.dop.pdop
        hdop = result.dop.hdop
        vdop = result.dop.vdop
        
        // Convert enhanced satellites to legacy format
        satellites = enhancedSatellites.map { $0.legacySatellite }
        satelliteCount = satellites.count
    }
    
    private func setUnavailableRAIM(reason: String) {
        let unavailableResult = EnhancedRAIMResult(
            status: .unavailable(reason: reason),
            testStatistic: 0, threshold: 0,
            horizontalProtectionLevel: 999.0, verticalProtectionLevel: 999.0,
            faultySatellites: [],
            dop: EnhancedDOPValues(hdop: 99, vdop: 99, pdop: 99, gdop: 99, tdop: 99),
            confidence: 0.0, integrityRisk: 1.0
        )
        
        enhancedRAIMResult = unavailableResult
        raimStatus = .unavailable
        pdop = 99.0
        hdop = 99.0
        vdop = 99.0
    }

    // MARK: - Enhanced RAIM Computation
    private func computeEnhancedRAIM(userPosition: CLLocation, satellites: [EnhancedSatelliteData]) -> EnhancedRAIMResult {
        
        // Compute DOP values
        let dopValues = computeEnhancedDOPValues(userPosition: userPosition, satellites: satellites)
        
        guard satellites.count >= minSatellitesForFD else {
            return EnhancedRAIMResult(
                status: .unavailable(reason: "Need ≥5 satellites for RAIM"),
                testStatistic: 0, threshold: 0,
                horizontalProtectionLevel: 999.0, verticalProtectionLevel: 999.0,
                faultySatellites: [],
                dop: dopValues, confidence: 0.0, integrityRisk: 1.0
            )
        }
        
        // Perform fault detection
        let faultDetectionResult = performEnhancedFaultDetection(
            userPosition: userPosition,
            satellites: satellites
        )
        
        // Compute protection levels
        let protectionLevels = computeEnhancedProtectionLevels(
            userPosition: userPosition,
            satellites: satellites,
            dopValues: dopValues
        )
        
        // Determine RAIM status
        let status = determineEnhancedRAIMStatus(
            satellites: satellites,
            faultDetected: faultDetectionResult.faultDetected,
            faultySatellites: faultDetectionResult.faultySatellites,
            hpl: protectionLevels.horizontal,
            vpl: protectionLevels.vertical,
            dopValues: dopValues
        )
        
        let confidence = calculateEnhancedConfidence(dopValues: dopValues, satelliteCount: satellites.count)
        let integrityRisk = calculateIntegrityRisk(protectionLevels: protectionLevels, dopValues: dopValues)
        
        return EnhancedRAIMResult(
            status: status,
            testStatistic: faultDetectionResult.testStatistic,
            threshold: faultDetectionResult.threshold,
            horizontalProtectionLevel: protectionLevels.horizontal,
            verticalProtectionLevel: protectionLevels.vertical,
            faultySatellites: faultDetectionResult.faultySatellites,
            dop: dopValues,
            confidence: confidence,
            integrityRisk: integrityRisk
        )
    }
    
    // MARK: - Enhanced RAIM Helper Functions
    
    private func filterValidSatellites(_ satellites: [EnhancedSatelliteData]) -> [EnhancedSatelliteData] {
        return satellites.filter { satellite in
            satellite.elevation >= minElevationAngle &&
            satellite.signalStrength >= 30.0 &&
            satellite.ephemerisAge <= 14400.0
        }
    }
    
    private func computeEnhancedDOPValues(userPosition: CLLocation, satellites: [EnhancedSatelliteData]) -> EnhancedDOPValues {
        // Warning 1: Replaced `userECEF` with `_` as it was initialized but never used.
        let _ = convertLLAtoECEF(
            lat: userPosition.coordinate.latitude * .pi / 180.0,
            lon: userPosition.coordinate.longitude * .pi / 180.0,
            alt: userPosition.altitude
        )
        
        // Simplified DOP calculation for integration
        let baseDOP = max(1.0, horizontalAccuracy / 2.0)
        let geometricFactor = 1.0 + (1.0 / Double(satellites.count))
        
        return EnhancedDOPValues(
            hdop: baseDOP * 0.8 * geometricFactor,
            vdop: baseDOP * 1.2 * geometricFactor,
            pdop: baseDOP * geometricFactor,
            gdop: baseDOP * 1.4 * geometricFactor,
            tdop: baseDOP * 0.6 * geometricFactor
        )
    }
    
    private func performEnhancedFaultDetection(userPosition: CLLocation, satellites: [EnhancedSatelliteData]) -> (faultDetected: Bool, testStatistic: Double, threshold: Double, faultySatellites: [Int]) {
        
        let userECEF = convertLLAtoECEF(
            lat: userPosition.coordinate.latitude * .pi / 180.0,
            lon: userPosition.coordinate.longitude * .pi / 180.0,
            alt: userPosition.altitude
        )
        
        // Compute residuals
        var residuals = [Double]()
        for satellite in satellites {
            let expectedRange = length(satellite.position - userECEF)
            let residual = satellite.pseudorange - expectedRange
            residuals.append(residual)
        }
        
        // Chi-square test statistic
        let testStatistic = computeChiSquareStatistic(residuals: residuals)
        
        // Compute threshold
        let degreesOfFreedom = satellites.count - 4
        let threshold = computeChiSquareThreshold(
            probabilityOfFalseAlarm: probabilityOfFalseAlarm,
            degreesOfFreedom: degreesOfFreedom
        )
        
        var faultySatellites = [Int]()
        let faultDetected = testStatistic > threshold
        
        if faultDetected && satellites.count >= minSatellitesForFDE {
            faultySatellites = performEnhancedFaultExclusion(satellites: satellites, residuals: residuals)
        }
        
        return (faultDetected, testStatistic, threshold, faultySatellites)
    }
    
    private func computeEnhancedProtectionLevels(userPosition: CLLocation, satellites: [EnhancedSatelliteData], dopValues: EnhancedDOPValues) -> (horizontal: Double, vertical: Double) {
        
        // Compute protection levels based on DOP and measurement noise
        let k_md = 5.33 // Aviation integrity factor
        
        let horizontalProtectionLevel = k_md * measurementNoiseStd * dopValues.hdop
        let verticalProtectionLevel = k_md * measurementNoiseStd * dopValues.vdop
        
        return (horizontalProtectionLevel, verticalProtectionLevel)
    }
    
    private func determineEnhancedRAIMStatus(satellites: [EnhancedSatelliteData], faultDetected: Bool, faultySatellites: [Int], hpl: Double, vpl: Double, dopValues: EnhancedDOPValues) -> EnhancedRAIMStatus {
        
        if faultDetected {
            if faultySatellites.isEmpty {
                return .caution(reason: "Fault detected but unable to isolate")
            } else {
                return .faultDetected(satellites: faultySatellites)
            }
        }
        
        let quality: RAIMQuality
        if hpl < 10.0 && satellites.count >= 8 {
            quality = .excellent
        } else if hpl < 25.0 && satellites.count >= 6 {
            quality = .good
        } else if hpl < 40.0 && satellites.count >= 5 {
            quality = .adequate
        } else if satellites.count >= 5 {
            quality = .marginal
        } else {
            return .unavailable(reason: "Insufficient satellites for RAIM")
        }
        
        return .available(quality: quality)
    }
    
    // MARK: - Enhanced Helper Functions
    
    private func computeChiSquareStatistic(residuals: [Double]) -> Double {
        let variance = measurementNoiseStd * measurementNoiseStd
        return residuals.map { $0 * $0 / variance }.reduce(0, +)
    }
    
    private func computeChiSquareThreshold(probabilityOfFalseAlarm: Double, degreesOfFreedom: Int) -> Double {
        let alpha = probabilityOfFalseAlarm
        
        switch degreesOfFreedom {
        case 1: return alpha <= 0.001 ? 10.83 : (alpha <= 0.01 ? 6.63 : 3.84)
        case 2: return alpha <= 0.001 ? 13.82 : (alpha <= 0.01 ? 9.21 : 5.99)
        case 3: return alpha <= 0.001 ? 16.27 : (alpha <= 0.01 ? 11.34 : 7.81)
        case 4: return alpha <= 0.001 ? 18.47 : (alpha <= 0.01 ? 13.28 : 9.49)
        default: return 15.0 + Double(degreesOfFreedom - 4) * 2.0
        }
    }
    
    private func performEnhancedFaultExclusion(satellites: [EnhancedSatelliteData], residuals: [Double]) -> [Int] {
        var faultySatellites = [Int]()
        
        let indexedResiduals = residuals.enumerated().map { ($0.offset, abs($0.element)) }
        let sortedByResidual = indexedResiduals.sorted { $0.1 > $1.1 }
        
        let threshold = 3.0 * measurementNoiseStd
        
        for (index, residual) in sortedByResidual {
            if residual > threshold {
                faultySatellites.append(satellites[index].satelliteID)
            }
        }
        
        return faultySatellites
    }
    
    private func calculateEnhancedConfidence(dopValues: EnhancedDOPValues, satelliteCount: Int) -> Double {
        let geometricFactor = max(0.0, min(1.0, 1.0 / dopValues.pdop))
        let countFactor = min(1.0, Double(satelliteCount) / 12.0)
        return (geometricFactor + countFactor) / 2.0
    }
    
    private func calculateIntegrityRisk(protectionLevels: (horizontal: Double, vertical: Double), dopValues: EnhancedDOPValues) -> Double {
        let hplFactor = min(1.0, protectionLevels.horizontal / 40.0)
        let vplFactor = min(1.0, protectionLevels.vertical / 50.0)
        let dopFactor = min(1.0, dopValues.pdop / 6.0)
        
        return (hplFactor + vplFactor + dopFactor) / 3.0
    }
    
    // MARK: - Coordinate Conversion Utilities
    
    private func convertLLAtoECEF(lat: Double, lon: Double, alt: Double) -> SIMD3<Double> {
        let a = 6378137.0  // WGS84 semi-major axis
        let f = 1.0/298.257223563  // WGS84 flattening
        let e2 = f * (2.0 - f)  // First eccentricity squared
        
        let N = a / sqrt(1.0 - e2 * sin(lat) * sin(lat))
        
        let x = (N + alt) * cos(lat) * cos(lon)
        let y = (N + alt) * cos(lat) * sin(lon)
        let z = (N * (1.0 - e2) + alt) * sin(lat)
        
        return SIMD3<Double>(x, y, z)
    }

    private func processMotionData(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let _ = sqrt(acceleration.x * acceleration.x +
                     acceleration.y * acceleration.y +
                     acceleration.z * acceleration.z)
    }

    // MARK: - Enhanced Satellite Simulation
    private func simulateEnhancedSatelliteData() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.generateEnhancedSatellites()
        }
    }

    private func generateEnhancedSatellites() {
        var newSatellites: [EnhancedSatelliteData] = []
        let satCount = Int.random(in: 8...12)

        // Generate GPS satellites
        for i in 1...satCount {
            let elevation = Double.random(in: 15...85) * .pi / 180.0
            let azimuth = Double.random(in: 0...360) * .pi / 180.0
            let snr = Double.random(in: 25...50)
            
            // Simulate ECEF position (simplified)
            let satPosition = simulateECEFPosition(elevation: elevation, azimuth: azimuth)
            let pseudorange = Double.random(in: 20000000...25000000) // ~20-25k km typical
            
            let satellite = EnhancedSatelliteData(
                satelliteID: i,
                position: satPosition,
                pseudorange: pseudorange,
                elevation: elevation,
                azimuth: azimuth,
                signalStrength: snr,
                ephemerisAge: Double.random(in: 0...3600), // 0-1 hour
                constellation: .gps,
                isUsed: i <= 6
            )
            newSatellites.append(satellite)
        }

        // Add GLONASS satellites
        for i in 65...67 {
            let elevation = Double.random(in: 20...70) * .pi / 180.0
            let azimuth = Double.random(in: 0...360) * .pi / 180.0
            let snr = Double.random(in: 20...45)
            
            let satPosition = simulateECEFPosition(elevation: elevation, azimuth: azimuth)
            let pseudorange = Double.random(in: 20000000...25000000)
            
            let satellite = EnhancedSatelliteData(
                satelliteID: i,
                position: satPosition,
                pseudorange: pseudorange,
                elevation: elevation,
                azimuth: azimuth,
                signalStrength: snr,
                ephemerisAge: Double.random(in: 0...3600),
                constellation: .glonass,
                isUsed: false
            )
            newSatellites.append(satellite)
        }

        enhancedSatellites = newSatellites
    }
    
    private func simulateECEFPosition(elevation: Double, azimuth: Double) -> SIMD3<Double> {
        // Simplified satellite position simulation
        let radius = 26560000.0 // GPS orbital radius (~26,560 km)
        let x = radius * cos(elevation) * cos(azimuth)
        let y = radius * cos(elevation) * sin(azimuth)
        let z = radius * sin(elevation)
        return SIMD3<Double>(x, y, z)
    }

    func detectFlightPhase() -> GPSFlightPhase {
        let avgSpeed = speedSamples.isEmpty ? 0 : speedSamples.reduce(0, +) / Double(speedSamples.count)

        if avgSpeed < 5 {
            return .ground
        } else if avgSpeed < 80 {
            return .taxi
        } else if avgSpeed > 80 && avgSpeed < 120 {
            return .takeoffLanding
        } else {
            return .cruise
        }
    }
}

// MARK: - Legacy Data Models (maintained for UI compatibility)
struct GPSSatellite: Identifiable, Equatable {
    let id: Int
    let elevation: Double // Degrees above horizon
    let azimuth: Double   // Degrees from north
    let snr: Double       // Signal-to-noise ratio
    let isUsed: Bool      // Used in position calculation
    let constellation: SatelliteConstellation

    var signalStrength: SignalStrength {
        if snr >= 40 { return .excellent }
        else if snr >= 30 { return .good }
        else if snr >= 20 { return .fair }
        else { return .poor }
    }
}

enum SatelliteConstellation: String, CaseIterable, Comparable {
    case gps = "GPS"
    case glonass = "GLONASS"
    case galileo = "Galileo"
    case beidou = "BeiDou"

    var color: Color {
        switch self {
        case .gps: return .blue
        case .glonass: return .red
        case .galileo: return .green
        case .beidou: return .orange
        }
    }

    static func < (lhs: SatelliteConstellation, rhs: SatelliteConstellation) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum SignalStrength: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

enum RAIMStatus: String, CaseIterable {
    case available = "RAIM Available"
    case caution = "RAIM Caution"
    case unavailable = "RAIM Unavailable"

    var color: Color {
        switch self {
        case .available: return .green
        case .caution: return .orange
        case .unavailable: return .red
        }
    }
}

enum GPSAccuracy: String, CaseIterable {
    case excellent = "Excellent (<3m)"
    case good = "Good (3-5m)"
    case fair = "Fair (5-10m)"
    case poor = "Poor (>10m)"
    case invalid = "Invalid"

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .invalid: return .gray
        }
    }
}

// MARK: - GPS Display View (Enhanced but backward-compatible)
struct GPSRAIMView: View {
    @StateObject private var gpsManager = GPSRAIMManager()
    @State private var selectedSatellite: GPSSatellite? = nil
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Status Bar
                EnhancedGPSStatusBar(gpsManager: gpsManager)

                Divider()

                // Main Display with Enhanced Tab
                TabView(selection: $selectedTab) {
                    // Compass View
                    CompassView(satellites: gpsManager.satellites,
                                selectedSatellite: $selectedSatellite)
                        .tabItem {
                            Image(systemName: "location.circle")
                            Text("Compass")
                        }
                        .tag(0)

                    // Improved Signal Strength View (interactive)
                    SignalStrengthView(
                        satellites: gpsManager.satellites,
                        selectedSatellite: $selectedSatellite
                    )
                    .tabItem {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Signals")
                    }
                    .tag(1)

                    // Enhanced DOP Values View
                    EnhancedDOPView(gpsManager: gpsManager)
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Precision")
                        }
                        .tag(2)
                    
                    // New Enhanced RAIM Tab
                    EnhancedRAIMView(gpsManager: gpsManager)
                        .tabItem {
                            Image(systemName: "shield.checkered")
                            Text("RAIM")
                        }
                        .tag(3)
                }
                // FIXED: iOS 17+ onChange syntax (zero-parameter version)
                .onChange(of: gpsManager.satellites) {
                    // Keep selectedSatellite reference coherent when satellite array refreshes
                    if let sel = selectedSatellite,
                       let refreshed = gpsManager.satellites.first(where: { $0.id == sel.id }) {
                        selectedSatellite = refreshed
                    } else if selectedSatellite != nil &&
                                !gpsManager.satellites.contains(where: { $0.id == selectedSatellite!.id }) {
                        selectedSatellite = nil
                    }
                }

                // Enhanced Bottom Status
                EnhancedGPSBottomStatus(gpsManager: gpsManager)
            }
            .navigationTitle("GPS/RAIM")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                gpsManager.startGPSMonitoring()
            }
            .onDisappear {
                gpsManager.stopGPSMonitoring()
            }
        }
    }
}

// MARK: - Enhanced UI Components

struct EnhancedGPSStatusBar: View {
    @ObservedObject var gpsManager: GPSRAIMManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GPS Status")
                    .font(.caption.bold())
                Text(gpsManager.gpsAccuracy.rawValue)
                    .font(.caption2)
                    .foregroundColor(gpsManager.gpsAccuracy.color)
            }

            Spacer()

            VStack(alignment: .center, spacing: 2) {
                Text("RAIM")
                    .font(.caption.bold())
                if let result = gpsManager.enhancedRAIMResult {
                    switch result.status {
                    case .available(let quality):
                        Text("Available (\(qualityText(quality)))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    case .caution(_):
                        Text("Caution")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    case .unavailable(_):
                        Text("Unavailable")
                            .font(.caption2)
                            .foregroundColor(.red)
                    case .faultDetected(_):
                        Text("Fault Detected")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                } else {
                    Text("Computing...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Satellites")
                    .font(.caption.bold())
                Text("\(gpsManager.satelliteCount)")
                    .font(.caption2)
                    .foregroundColor(gpsManager.satelliteCount >= 4 ? .green : .red)
            }
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
    
    private func qualityText(_ quality: RAIMQuality) -> String {
        switch quality {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .adequate: return "Adequate"
        case .marginal: return "Marginal"
        }
    }
}

struct EnhancedGPSBottomStatus: View {
    @ObservedObject var gpsManager: GPSRAIMManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Speed: \(Int(gpsManager.currentSpeed)) kts")
                    .font(.caption.bold())
                Text("Phase: \(gpsManager.detectFlightPhase().rawValue)")
                    .font(.caption2)
                    .foregroundColor(gpsManager.detectFlightPhase().color)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 2) {
                if let result = gpsManager.enhancedRAIMResult {
                    Text("HPL: \(String(format: "%.1f", result.horizontalProtectionLevel))m")
                        .font(.caption.bold())
                        .foregroundColor(result.horizontalProtectionLevel < 40 ? .green : .orange)
                    Text("Conf: \(String(format: "%.0f", result.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(result.confidence > 0.8 ? .green : .orange)
                } else {
                    Text("HPL: Computing...")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Alt: \(Int(gpsManager.altitude)) ft")
                    .font(.caption.bold())
                Text("Acc: ±\(Int(gpsManager.horizontalAccuracy))m")
                    .font(.caption2)
                    .foregroundColor(gpsManager.horizontalAccuracy < 20 ? .green : .orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

struct EnhancedRAIMView: View {
    @ObservedObject var gpsManager: GPSRAIMManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let result = gpsManager.enhancedRAIMResult {
                    // RAIM Status Section
                    RAIMStatusSection(result: result)
                    
                    // Protection Levels Section
                    ProtectionLevelsSection(result: result)
                    
                    // Fault Detection Section
                    FaultDetectionSection(result: result)
                    
                    // Statistical Information
                    StatisticalInfoSection(result: result)
                    
                } else {
                    Text("Computing Enhanced RAIM...")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color.black)
    }
}

struct RAIMStatusSection: View {
    let result: EnhancedRAIMResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAIM Status")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                statusIcon
                Text(statusText)
                    .foregroundColor(statusColor)
                Spacer()
                Text("Conf: \(String(format: "%.0f", result.confidence * 100))%")
                    .foregroundColor(result.confidence > 0.8 ? .green : .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusIcon: some View {
        switch result.status {
        case .available:
            return Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
        case .caution:
            return Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
        case .unavailable:
            return Image(systemName: "xmark.shield.fill")
                .foregroundColor(.red)
        case .faultDetected:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var statusText: String {
        switch result.status {
        case .available(let quality):
            return "Available (\(qualityText(quality)))"
        case .caution(let reason):
            return "Caution: \(reason)"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        case .faultDetected(let satellites):
            return "Fault Detected in \(satellites.count) satellites"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .available: return .green
        case .caution: return .orange
        case .unavailable: return .red
        case .faultDetected: return .red
        }
    }
    
    private func qualityText(_ quality: RAIMQuality) -> String {
        switch quality {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .adequate: return "Adequate"
        case .marginal: return "Marginal"
        }
    }
}

struct ProtectionLevelsSection: View {
    let result: EnhancedRAIMResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protection Levels")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("HPL: \(String(format: "%.1f", result.horizontalProtectionLevel)) m")
                        .foregroundColor(result.horizontalProtectionLevel < 40 ? .green : .orange)
                    Text("VPL: \(String(format: "%.1f", result.verticalProtectionLevel)) m")
                        .foregroundColor(result.verticalProtectionLevel < 50 ? .green : .orange)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Risk: \(String(format: "%.3f", result.integrityRisk))")
                        .foregroundColor(result.integrityRisk < 0.1 ? .green : .red)
                    Text("Alert Limit: 40m")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FaultDetectionSection: View {
    let result: EnhancedRAIMResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fault Detection")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Stat: \(String(format: "%.2f", result.testStatistic))")
                        .foregroundColor(.white)
                    Text("Threshold: \(String(format: "%.2f", result.threshold))")
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if result.faultySatellites.isEmpty {
                        Text("No Faults")
                            .foregroundColor(.green)
                    } else {
                        Text("Faulty: \(result.faultySatellites.map(String.init).joined(separator: ", "))")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatisticalInfoSection: View {
    let result: EnhancedRAIMResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistical Information")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 4) {
                HStack {
                    Text("PDOP:")
                    Spacer()
                    Text(String(format: "%.2f", result.dop.pdop))
                        .foregroundColor(dopColor(result.dop.pdop))
                }
                HStack {
                    Text("HDOP:")
                    Spacer()
                    Text(String(format: "%.2f", result.dop.hdop))
                        .foregroundColor(dopColor(result.dop.hdop))
                }
                HStack {
                    Text("VDOP:")
                    Spacer()
                    Text(String(format: "%.2f", result.dop.vdop))
                        .foregroundColor(dopColor(result.dop.vdop))
                }
                HStack {
                    Text("GDOP:")
                    Spacer()
                    Text(String(format: "%.2f", result.dop.gdop))
                        .foregroundColor(dopColor(result.dop.gdop))
                }
            }
            .font(.caption)
            .foregroundColor(.white)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func dopColor(_ value: Double) -> Color {
        if value <= 2.0 { return .green }
        else if value <= 5.0 { return .orange }
        else { return .red }
    }
}

// MARK: - Enhanced DOP View
struct EnhancedDOPView: View {
    @ObservedObject var gpsManager: GPSRAIMManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Dilution of Precision")
                .font(.headline)
                .foregroundColor(.white)
            
            if let result = gpsManager.enhancedRAIMResult {
                VStack(spacing: 16) {
                    EnhancedDOPRowView(title: "PDOP", value: result.dop.pdop, description: "Position Dilution")
                    EnhancedDOPRowView(title: "HDOP", value: result.dop.hdop, description: "Horizontal Dilution")
                    EnhancedDOPRowView(title: "VDOP", value: result.dop.vdop, description: "Vertical Dilution")
                    EnhancedDOPRowView(title: "GDOP", value: result.dop.gdop, description: "Geometric Dilution")
                    EnhancedDOPRowView(title: "TDOP", value: result.dop.tdop, description: "Time Dilution")
                }
            } else {
                // Fallback to legacy DOP values
                VStack(spacing: 16) {
                    DOPRowView(title: "PDOP", value: gpsManager.pdop, description: "Position Dilution")
                    DOPRowView(title: "HDOP", value: gpsManager.hdop, description: "Horizontal Dilution")
                    DOPRowView(title: "VDOP", value: gpsManager.vdop, description: "Vertical Dilution")
                }
            }
            
            Text("Lower values indicate better precision")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
}

struct EnhancedDOPRowView: View {
    let title: String
    let value: Double
    let description: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", value))
                    .font(.title.bold())
                    .foregroundColor(dopColor)
                Text(dopQuality)
                    .font(.caption2)
                    .foregroundColor(dopColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var dopColor: Color {
        if value <= 2.0 { return .green }
        else if value <= 5.0 { return .orange }
        else { return .red }
    }

    private var dopQuality: String {
        if value <= 1.0 { return "Ideal" }
        else if value <= 2.0 { return "Excellent" }
        else if value <= 5.0 { return "Good" }
        else if value <= 10.0 { return "Moderate" }
        else { return "Poor" }
    }
}

// MARK: - Existing UI Components (unchanged for compatibility)

struct CompassView: View {
    let satellites: [GPSSatellite]
    @Binding var selectedSatellite: GPSSatellite?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: 300, height: 300)

            ForEach([30, 60], id: \.self) { elevation in
                let circleSize = elevationCircleSize(elevation: elevation)
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: circleSize, height: circleSize)
            }

            CardinalDirectionsView()

            ForEach(satellites) { satellite in
                SatelliteIcon(satellite: satellite, isSelected: selectedSatellite?.id == satellite.id)
                    .position(satellitePosition(satellite))
                    .onTapGesture {
                        selectedSatellite = satellite
                    }
            }

            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
    }

    private func satellitePosition(_ satellite: GPSSatellite) -> CGPoint {
        let compassRadius: CGFloat = 150
        let elevation = satellite.elevation
        let azimuth = satellite.azimuth

        let radius = compassRadius * CGFloat(90 - elevation) / 90
        let angleInDegrees = azimuth - 90
        let angleInRadians = CGFloat(angleInDegrees) * .pi / 180

        let centerX: CGFloat = compassRadius
        let centerY: CGFloat = compassRadius
        let x = centerX + radius * cos(angleInRadians)
        let y = centerY + radius * sin(angleInRadians)

        return CGPoint(x: x, y: y)
    }

    private func elevationCircleSize(elevation: Int) -> CGFloat {
        return 300 * CGFloat(90 - Double(elevation)) / 90
    }
}

struct CardinalDirectionsView: View {
    private func directionOffsets(direction: String) -> (x: CGFloat, y: CGFloat) {
        switch direction {
        case "N": return (0, -160)
        case "S": return (0, 160)
        case "E": return (160, 0)
        case "W": return (-160, 0)
        default: return (0, 0)
        }
    }

    var body: some View {
        ForEach(["N", "E", "S", "W"], id: \.self) { direction in
            let offsets = directionOffsets(direction: direction)
            Text(direction)
                .font(.headline.bold())
                .foregroundColor(.white)
                .offset(x: offsets.x, y: offsets.y)
        }
    }
}

struct SatelliteIcon: View {
    let satellite: GPSSatellite
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(satellite.constellation.color)
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                .overlay(
                    Circle()
                        .stroke(satellite.isUsed ? Color.white : Color.gray, lineWidth: 2)
                )

            Text("\(satellite.id)")
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
        .shadow(color: isSelected ? .white.opacity(0.8) : .clear, radius: isSelected ? 6 : 0)
    }
}

// ===== Improved Signal Strength Views (NEW) =====

enum SignalSortKey: String, CaseIterable {
    case snr = "SNR"
    case elevation = "Elevation"
    case id = "ID"
}

struct SignalStrengthView: View {
    let satellites: [GPSSatellite]
    @Binding var selectedSatellite: GPSSatellite?

    @State private var sortKey: SignalSortKey = .snr
    @State private var groupByConstellation: Bool = true
    @State private var usedOnly: Bool = false

    private var filtered: [GPSSatellite] {
        usedOnly ? satellites.filter { $0.isUsed } : satellites
    }

    private var sorted: [GPSSatellite] {
        switch sortKey {
        case .snr:
            return filtered.sorted { ($0.snr, $0.isUsed ? 1 : 0) > ($1.snr, $1.isUsed ? 1 : 0) }
        case .elevation:
            return filtered.sorted { ($0.elevation, $0.snr) > ($1.elevation, $1.snr) }
        case .id:
            return filtered.sorted { $0.id < $1.id }
        }
    }

    private var groups: [(SatelliteConstellation, [GPSSatellite])] {
        Dictionary(grouping: sorted, by: { $0.constellation })
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private var avgSNR: Double {
        guard !filtered.isEmpty else { return 0 }
        return filtered.map { $0.snr }.reduce(0, +) / Double(filtered.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Controls
            HStack(spacing: 12) {
                Picker("Sort", selection: $sortKey) {
                    ForEach(SignalSortKey.allCases, id: \.self) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Group", isOn: $groupByConstellation)
                    .toggleStyle(.switch)
                    .frame(width: 110, alignment: .leading)

                Toggle("Used only", isOn: $usedOnly)
                    .toggleStyle(.switch)
            }
            .padding(.horizontal)

            // Quick Stats
            HStack {
                statPill(title: "Total", value: "\(satellites.count)")
                statPill(title: "Used", value: "\(satellites.filter{$0.isUsed}.count)")
                statPill(title: "Avg SNR", value: String(format: "%.1f dB", avgSNR))
                Spacer()
            }
            .padding(.horizontal)

            // List
            if satellites.isEmpty {
                Text("No satellites available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        if groupByConstellation {
                            ForEach(groups, id: \.0) { (const, sats) in
                                GroupBox(label:
                                            HStack {
                                                Circle().fill(const.color).frame(width: 8, height: 8)
                                                Text(const.rawValue).font(.caption).foregroundColor(.white)
                                                Spacer()
                                            }
                                         ) {
                                    VStack(spacing: 4) {
                                        ForEach(sats) { sat in
                                            SatelliteSignalRow(
                                                satellite: sat,
                                                isSelected: selectedSatellite?.id == sat.id,
                                                onTap: { selectedSatellite = sat }
                                            )
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .groupBoxStyle(.automatic)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            ForEach(sorted) { sat in
                                SatelliteSignalRow(
                                    satellite: sat,
                                    isSelected: selectedSatellite?.id == sat.id,
                                    onTap: { selectedSatellite = sat }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private func statPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value).font(.caption.bold()).foregroundColor(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.gray.opacity(0.15))
        .clipShape(Capsule())
    }
}

// Selectable row w/ highlight
struct SatelliteSignalRow: View {
    let satellite: GPSSatellite
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(satellite.constellation.color).frame(width: 8, height: 8)
                    Text("\(satellite.constellation.rawValue) \(satellite.id)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    if satellite.isUsed {
                        Text("USED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                Text("Elev: \(Int(satellite.elevation))°  Az: \(Int(satellite.azimuth))°")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(satellite.snr)) dB")
                    .font(.caption.bold())
                    .foregroundColor(satellite.signalStrength.color)
                Text(satellite.signalStrength.rawValue)
                    .font(.caption2)
                    .foregroundColor(satellite.signalStrength.color)
            }

            ProgressView(value: min(max(satellite.snr, 0), 50), total: 50)
                .progressViewStyle(LinearProgressViewStyle(tint: satellite.signalStrength.color))
                .frame(width: 70)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white.opacity(0.6) : (satellite.isUsed ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3)), lineWidth: isSelected ? 1.2 : 0.8)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// ===== End of Improved
// MARK: - Fallback DOP Row (used when enhanced result is nil)
struct DOPRowView: View {
    let title: String
    let value: Double
    let description: String

    var body: some View {
        HStack {
            // Left
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Right
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.title.bold())
                    .foregroundColor(dopColor)
                Text(dopQuality)
                    .font(.caption2)
                    .foregroundColor(dopColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var dopColor: Color {
        if value <= 2.0 { return .green }
        else if value <= 5.0 { return .orange }
        else { return .red }
    }

    private var dopQuality: String {
        if value <= 1.0 { return "Ideal" }
        else if value <= 2.0 { return "Excellent" }
        else if value <= 5.0 { return "Good" }
        else if value <= 10.0 { return "Moderate" }
        else { return "Poor" }
    }
}

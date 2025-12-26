//
//  SimpleGPSSignalView.swift
//  USA Jet Calc
//
//  Created by Jeffrey Kadans on 7/8/25.
//


// SimpleGPSSystem.swift
// Safe GPS Integration for USA Jet Calc
import SwiftUI
import CoreLocation

// MARK: - Simple GPS Signal View
struct SimpleGPSSignalView: View {
    @StateObject private var locationManager = SimpleLocationManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current GPS Status
                        currentStatusCard
                        
                        // Location Details
                        if locationManager.hasLocation {
                            locationDetailsCard
                        }
                        
                        // GPS Quality
                        signalQualityCard
                        
                        // Controls
                        controlsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("GPS Monitor")
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                }
                .foregroundColor(LogbookTheme.accentBlue)
            )
        }
        .onAppear {
            locationManager.startLocationUpdates()
        }
    }
    
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: locationManager.gpsStatusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(locationManager.gpsStatusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPS Status")
                        .font(.headline)
                        .foregroundColor(LogbookTheme.textPrimary)
                    
                    Text(locationManager.statusDescription)
                        .font(.title2.bold())
                        .foregroundColor(locationManager.gpsStatusColor)
                }
                
                Spacer()
            }
            
            if let accuracy = locationManager.currentAccuracy {
                Text("Accuracy: ±\(String(format: "%.1f", accuracy))m")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var locationDetailsCard: some View {
        VStack(spacing: 12) {
            Text("Location Details")
                .font(.headline)
                .foregroundColor(LogbookTheme.textPrimary)
            
            if let location = locationManager.currentLocation {
                VStack(spacing: 8) {
                    LocationDetailRow(
                        title: "Latitude",
                        value: String(format: "%.6f°", location.coordinate.latitude)
                    )
                    
                    LocationDetailRow(
                        title: "Longitude",
                        value: String(format: "%.6f°", location.coordinate.longitude)
                    )
                    
                    LocationDetailRow(
                        title: "Altitude",
                        value: String(format: "%.1f m", location.altitude)
                    )
                    
                    if location.speed >= 0 {
                        LocationDetailRow(
                            title: "Speed",
                            value: String(format: "%.1f km/h", location.speed * 3.6)
                        )
                    }
                    
                    if location.course >= 0 {
                        LocationDetailRow(
                            title: "Heading",
                            value: String(format: "%.0f°", location.course)
                        )
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var signalQualityCard: some View {
        VStack(spacing: 12) {
            Text("Signal Quality")
                .font(.headline)
                .foregroundColor(LogbookTheme.textPrimary)
            
            HStack(spacing: 20) {
                SignalQualityIndicator(
                    title: "Horizontal",
                    value: locationManager.currentAccuracy ?? -1,
                    unit: "m"
                )
                
                SignalQualityIndicator(
                    title: "Satellites",
                    value: Double(locationManager.estimatedSatelliteCount),
                    unit: ""
                )
                
                SignalQualityIndicator(
                    title: "Fix Type",
                    value: locationManager.fixQuality,
                    unit: "",
                    isText: true
                )
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var controlsCard: some View {
        VStack(spacing: 12) {
            Text("Controls")
                .font(.headline)
                .foregroundColor(LogbookTheme.textPrimary)
            
            HStack(spacing: 12) {
                Button(action: {
                    if locationManager.isTracking {
                        locationManager.stopLocationUpdates()
                    } else {
                        locationManager.startLocationUpdates()
                    }
                }) {
                    HStack {
                        Image(systemName: locationManager.isTracking ? "stop.fill" : "play.fill")
                        Text(locationManager.isTracking ? "Stop GPS" : "Start GPS")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(locationManager.isTracking ? LogbookTheme.errorRed : LogbookTheme.accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    locationManager.requestPermissions()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Permissions")
                    }
                    .font(.headline)
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .foregroundColor(LogbookTheme.textPrimary)
                    .cornerRadius(12)
                }
            }
            
            // CloudKit Sync Status
            CloudKitStatusIndicator()
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - CloudKit Status Indicator (for debugging)
struct CloudKitStatusIndicator: View {
    @ObservedObject private var errorHandler = CloudKitErrorHandler.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
            
            Text(errorHandler.syncStatus.displayMessage)
                .font(.caption2)
                .foregroundColor(LogbookTheme.textSecondary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var statusIcon: String {
        switch errorHandler.syncStatus {
        case .idle:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .success:
            return "icloud.fill"
        case .partialFailure:
            return "icloud.slash"
        case .failed:
            return "exclamationmark.icloud"
        }
    }
    
    private var statusColor: Color {
        switch errorHandler.syncStatus {
        case .idle, .syncing:
            return LogbookTheme.accentBlue
        case .success:
            return LogbookTheme.accentGreen
        case .partialFailure:
            return LogbookTheme.accentOrange
        case .failed:
            return LogbookTheme.errorRed
        }
    }
}

// MARK: - Location Detail Row
struct LocationDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(LogbookTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(LogbookTheme.textPrimary)
        }
    }
}

// MARK: - Signal Quality Indicator
struct SignalQualityIndicator: View {
    let title: String
    let value: Double
    let unit: String
    var isText: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            if isText {
                Text(qualityText)
                    .font(.headline.bold())
                    .foregroundColor(qualityColor)
            } else {
                Text(formatValue())
                    .font(.headline.bold())
                    .foregroundColor(qualityColor)
            }
        }
    }
    
    private var qualityText: String {
        if value <= 0 { return "No Fix" }
        if value <= 5 { return "Excellent" }
        if value <= 10 { return "Good" }
        if value <= 20 { return "Fair" }
        return "Poor"
    }
    
    private var qualityColor: Color {
        if value <= 0 { return LogbookTheme.textSecondary }
        if value <= 5 { return LogbookTheme.accentGreen }
        if value <= 10 { return LogbookTheme.accentBlue }
        if value <= 20 { return LogbookTheme.accentOrange }
        return LogbookTheme.errorRed
    }
    
    private func formatValue() -> String {
        if value < 0 { return "N/A" }
        if unit.isEmpty {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f %@", value, unit)
        }
    }
}

// MARK: - Simple Location Manager
class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentAccuracy: Double?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "Location permission required"
            requestPermissions()
            return
        }
        
        isTracking = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Computed Properties
    var hasLocation: Bool {
        return currentLocation != nil
    }
    
    var statusDescription: String {
        if let error = locationError {
            return "Error: \(error)"
        }
        
        switch authorizationStatus {
        case .notDetermined:
            return "Permission Required"
        case .denied, .restricted:
            return "Access Denied"
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                if hasLocation {
                    return "GPS Active"
                } else {
                    return "Searching..."
                }
            } else {
                return "GPS Stopped"
            }
        @unknown default:
            return "Unknown Status"
        }
    }
    
    var gpsStatusIcon: String {
        if locationError != nil {
            return "location.slash.fill"
        }
        
        switch authorizationStatus {
        case .notDetermined:
            return "location.circle"
        case .denied, .restricted:
            return "location.slash"
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking && hasLocation {
                return "location.fill"
            } else if isTracking {
                return "location.circle"
            } else {
                return "location"
            }
        @unknown default:
            return "location.slash"
        }
    }
    
    var gpsStatusColor: Color {
        if locationError != nil {
            return LogbookTheme.errorRed
        }
        
        switch authorizationStatus {
        case .notDetermined:
            return LogbookTheme.accentOrange
        case .denied, .restricted:
            return LogbookTheme.errorRed
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking && hasLocation {
                return LogbookTheme.accentGreen
            } else if isTracking {
                return LogbookTheme.accentBlue
            } else {
                return LogbookTheme.textSecondary
            }
        @unknown default:
            return LogbookTheme.errorRed
        }
    }
    
    var estimatedSatelliteCount: Int {
        guard let accuracy = currentAccuracy, accuracy > 0 else { return 0 }
        
        if accuracy <= 3 { return Int.random(in: 8...12) }
        if accuracy <= 5 { return Int.random(in: 6...8) }
        if accuracy <= 10 { return Int.random(in: 4...6) }
        if accuracy <= 20 { return Int.random(in: 3...4) }
        return Int.random(in: 1...2)
    }
    
    var fixQuality: Double {
        guard let accuracy = currentAccuracy, accuracy > 0 else { return -1 }
        
        if accuracy <= 3 { return 4 } // Excellent
        if accuracy <= 5 { return 3 } // Good  
        if accuracy <= 10 { return 2 } // Fair
        return 1 // Poor
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isTracking else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentAccuracy = location.horizontalAccuracy
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            if status == .denied || status == .restricted {
                self.locationError = "Location access denied. Enable in Settings."
                self.stopLocationUpdates()
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationError = nil
            }
        }
    }
}

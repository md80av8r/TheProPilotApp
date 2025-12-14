//
//  ProximitySettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/18/25.
//


import SwiftUI
import CoreLocation

struct ProximitySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = PilotLocationManager()
    
    // Proximity radius options in meters
    @AppStorage("airportProximityRadius") private var proximityRadius: Double = 1000
    @AppStorage("autoStartDutyOnArrival") private var autoStartDuty = false
    @AppStorage("autoFillAirports") private var autoFillAirports = true
    @AppStorage("showArrivalNotifications") private var showNotifications = true
    @AppStorage("watchTriggersGeofence") private var watchTriggersGeofence = true
    
    // Local state for testing
    @State private var isTesting = false
    @State private var testResult: String = ""
    
    private let radiusOptions: [(label: String, value: Double)] = [
        ("0.5 km", 500),
        ("1 km", 1000),
        ("2 km", 2000),
        ("5 km", 5000),
        ("10 km", 10000)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Detection Radius
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Airport Detection Radius")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("How close to an airport before ProPilot detects arrival")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Picker("Radius", selection: $proximityRadius) {
                            ForEach(radiusOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: proximityRadius) { oldValue, newValue in
                            updateGeofenceRadius(newValue)
                        }
                    }
                } header: {
                    Label("DETECTION RANGE", systemImage: "location.circle")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // MARK: - Automation Settings
                Section {
                    Toggle(isOn: $autoStartDuty) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Start Duty")
                            Text("Automatically start duty timer on arrival")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Toggle(isOn: $autoFillAirports) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Fill Airports")
                            Text("Automatically fill departure/arrival codes")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Toggle(isOn: $showNotifications) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Arrival Alerts")
                            Text("Display notification when arriving at airport")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Label("AUTOMATION", systemImage: "gearshape.2")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // MARK: - Watch Integration
                Section {
                    Toggle(isOn: $watchTriggersGeofence) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch Triggers Detection")
                            Text("Allow Apple Watch to trigger airport detection")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if watchTriggersGeofence {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Watch will use phone's location for detection")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Label("APPLE WATCH", systemImage: "applewatch")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // MARK: - Current Status
                Section {
                    HStack {
                        Text("Location Status")
                        Spacer()
                        Text(locationManager.locationStatus)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    if let currentAirport = locationManager.currentAirport {
                        HStack {
                            Text("Current Airport")
                            Spacer()
                            Text(currentAirport)
                                .foregroundColor(LogbookTheme.accentBlue)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    if !locationManager.nearbyAirports.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nearby Airports")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            ForEach(locationManager.nearbyAirports.prefix(3), id: \.icao) { airport in
                                HStack {
                                    Text(airport.icao)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(LogbookTheme.accentBlue)
                                    Text(airport.name)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(String(format: "%.1f", airport.distance / 1000)) km")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } header: {
                    Label("STATUS", systemImage: "location.fill")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // MARK: - Test Functions
                Section {
                    Button(action: testCurrentLocation) {
                        HStack {
                            Image(systemName: "location.magnifyingglass")
                            Text("Test Current Location")
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTesting)
                    
                    Button(action: refreshGeofences) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Refresh Geofences")
                        }
                    }
                    
                    Button(action: simulateArrival) {
                        HStack {
                            Image(systemName: "airplane.arrival")
                            Text("Simulate Airport Arrival")
                        }
                    }
                    
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } header: {
                    Label("TESTING", systemImage: "wrench.and.screwdriver")
                        .foregroundColor(LogbookTheme.accentBlue)
                } footer: {
                    Text("Test functions help verify proximity detection is working correctly")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Proximity Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            locationManager.startLocationServices()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateGeofenceRadius(_ newRadius: Double) {
        // Post notification to update all geofences with new radius
        NotificationCenter.default.post(
            name: Notification.Name("updateGeofenceRadius"),
            object: nil,
            userInfo: ["radius": newRadius]
        )
        
        print("📍 Updated geofence radius to \(newRadius) meters")
        
        // Refresh geofences with new radius
        locationManager.refreshGeofences()
    }
    
    private func testCurrentLocation() {
        isTesting = true
        testResult = "Testing..."
        
        locationManager.forceLocationUpdate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            isTesting = false
            
            if let airport = locationManager.nearbyAirports.first {
                let distanceKm = airport.distance / 1000
                testResult = "Nearest: \(airport.icao) at \(String(format: "%.1f", distanceKm)) km"
                print("✈️ Test result: \(airport.icao) at \(String(format: "%.1f", distanceKm)) km")
            } else if locationManager.currentLocation != nil {
                testResult = "No airports nearby"
                print("❌ No airports found nearby")
            } else {
                testResult = "Location unavailable"
                print("❌ Location not available")
            }
        }
    }
    
    private func refreshGeofences() {
        print("🔄 Refreshing all geofences")
        testResult = "Refreshing geofences..."
        locationManager.refreshGeofences()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = "Geofences refreshed"
        }
    }
    
    private func simulateArrival() {
        print("✈️ Simulating airport arrival")
        testResult = "Simulating arrival at KYIP..."
        locationManager.simulateAirportArrival("KYIP")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = "Arrival simulation sent"
        }
    }
}
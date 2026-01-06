//
//  FBOProximityNotificationService.swift
//  TheProPilotApp
//
//  Monitors aircraft position and triggers notifications when approaching
//  airports with preferred FBOs set (default: ~120nm out for radio contact)
//

import Foundation
import CoreLocation
import UserNotifications
import Combine

// MARK: - FBO Proximity Notification Service
class FBOProximityNotificationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = FBOProximityNotificationService()

    @Published var isMonitoring = false
    @Published var nearbyFBOAlerts: [(airport: AirportInfo, fbo: PreferredFBO, distanceNM: Double)] = []

    private let locationManager = CLLocationManager()
    private let airportDB = AirportDatabaseManager.shared
    private var notifiedAirports: Set<String> = []  // Track which airports we've already sent notification
    private var lastCheckLocation: CLLocation?
    private var checkTimer: Timer?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        requestNotificationPermission()
    }

    // MARK: - Start/Stop Monitoring

    /// Start monitoring for FBO proximity alerts
    func startMonitoring() {
        guard !isMonitoring else { return }

        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        isMonitoring = true

        // Check every 30 seconds for proximity
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkProximity()
        }

        print("📡 FBO Proximity Monitoring: Started")
    }

    /// Stop monitoring for FBO proximity alerts
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        checkTimer?.invalidate()
        checkTimer = nil
        isMonitoring = false
        notifiedAirports.removeAll()

        print("📡 FBO Proximity Monitoring: Stopped")
    }

    /// Reset notifications for a specific airport (allows re-notification)
    func resetNotification(for icaoCode: String) {
        let icao = icaoCode.uppercased()
        notifiedAirports.remove(icao)
    }

    /// Reset all notifications (e.g., when starting a new trip)
    func resetAllNotifications() {
        notifiedAirports.removeAll()
    }

    // MARK: - Location Delegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Only check if we've moved significantly (at least 1nm = ~1852 meters)
        if let last = lastCheckLocation {
            let distance = location.distance(from: last)
            if distance < 1852 { return }  // Less than 1 nautical mile
        }

        lastCheckLocation = location
        checkProximity()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ FBO Proximity Location Error: \(error.localizedDescription)")
    }

    // MARK: - Proximity Check

    private func checkProximity() {
        guard let currentLocation = lastCheckLocation else { return }

        // NOTE: This service ONLY alerts for airports with a PreferredFBO set.
        // To get notified when approaching an airport, the user must set a preferred FBO
        // for that airport in the app settings (Airport Details -> Set as Preferred FBO).

        // Get airports needing FBO contact (only returns airports with preferred FBOs set)
        let nearbyAirports = airportDB.getAirportsNeedingFBOContact(
            from: currentLocation,
            withinNM: 200  // Check up to 200nm out
        )

        // Debug: Log how many preferred FBOs are being monitored
        if nearbyAirports.isEmpty {
            let totalPreferredFBOs = airportDB.preferredFBOs.count
            if totalPreferredFBOs == 0 {
                print("📡 FBO Proximity: No preferred FBOs set - notifications will not trigger")
            } else {
                print("📡 FBO Proximity: \(totalPreferredFBOs) preferred FBO(s) set, none within 200nm")
            }
        } else {
            print("📡 FBO Proximity: Found \(nearbyAirports.count) airport(s) with preferred FBOs within range")
        }

        DispatchQueue.main.async {
            self.nearbyFBOAlerts = nearbyAirports
        }

        // Check each airport for notification threshold (user-configured distance)
        for item in nearbyAirports {
            let icao = item.airport.icaoCode.uppercased()
            let distance = item.distanceNM

            // Skip if we've already sent notification for this airport
            guard !notifiedAirports.contains(icao) else { continue }

            // Check if within user-configured notification distance
            if distance <= item.fbo.notifyAtDistance {
                print("📻 FBO Alert triggering for \(icao) at \(String(format: "%.1f", distance))nm (threshold: \(item.fbo.notifyAtDistance)nm)")
                sendFBOContactNotification(
                    airport: item.airport,
                    fbo: item.fbo,
                    distanceNM: distance
                )
                notifiedAirports.insert(icao)
            } else {
                print("📡 \(icao): \(String(format: "%.1f", distance))nm away, notification at \(item.fbo.notifyAtDistance)nm")
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted for FBO alerts")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }

    private func sendFBOContactNotification(airport: AirportInfo, fbo: PreferredFBO, distanceNM: Double) {
        let content = UNMutableNotificationContent()
        content.title = "📻 Contact \(fbo.fboName)"
        content.subtitle = "\(airport.icaoCode) - \(String(format: "%.0f", distanceNM)) nm"

        // Build body with UNICOM frequency
        var bodyParts: [String] = []
        let unicomFrequency = fbo.unicomFrequency ?? airport.unicomFrequency ?? airport.primaryContactFrequency

        if let unicom = unicomFrequency {
            bodyParts.append("UNICOM: \(unicom)")
        }

        if let notes = fbo.notes, !notes.isEmpty {
            bodyParts.append(notes)
        }

        content.body = bodyParts.joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = "FBO_CONTACT"

        // Add action buttons
        let contactAction = UNNotificationAction(
            identifier: "FBO_CONTACTED",
            title: "Contacted",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "FBO_SNOOZE",
            title: "Remind in 10nm",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "FBO_CONTACT",
            actions: [contactAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: "fbo-\(airport.icaoCode)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send FBO notification: \(error)")
            } else {
                print("📬 FBO Contact notification sent for \(airport.icaoCode)")
            }
        }

        // Send alert to Apple Watch with haptic vibration
        PhoneWatchConnectivity.shared.sendFBOAlertToWatch(
            airportCode: airport.icaoCode,
            fboName: fbo.fboName,
            distanceNM: distanceNM,
            unicomFrequency: unicomFrequency
        )
    }
}

// MARK: - FBO Proximity Alert View (for in-app display)
import SwiftUI

struct FBOProximityAlertBadge: View {
    @ObservedObject var proximityService = FBOProximityNotificationService.shared

    var body: some View {
        if let nearest = proximityService.nearbyFBOAlerts.first {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact \(nearest.fbo.fboName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text(nearest.airport.icaoCode)
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("•")
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.0f", nearest.distanceNM)) nm")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        if let freq = nearest.fbo.unicomFrequency ?? nearest.airport.primaryContactFrequency {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(freq)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    proximityService.resetNotification(for: nearest.airport.icaoCode)
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Integration with Trip Start
extension FBOProximityNotificationService {

    /// Call this when a trip starts to begin monitoring
    func onTripStarted(trip: Trip) {
        resetAllNotifications()
        startMonitoring()
        print("📡 FBO monitoring started for trip: \(trip.tripNumber)")
    }

    /// Call this when a trip ends to stop monitoring
    func onTripEnded() {
        stopMonitoring()
        resetAllNotifications()
        print("📡 FBO monitoring stopped - trip ended")
    }

    /// Get the contact frequency for a destination
    func getDestinationContactInfo(for trip: Trip) -> (airport: AirportInfo, fbo: PreferredFBO?, frequency: String?)? {
        guard let lastLeg = trip.legs.last,
              !lastLeg.arrival.isEmpty,
              let airport = airportDB.getAirport(for: lastLeg.arrival) else {
            return nil
        }

        let fbo = airportDB.getPreferredFBO(for: airport.icaoCode)
        let frequency = fbo?.unicomFrequency ?? airport.primaryContactFrequency

        return (airport: airport, fbo: fbo, frequency: frequency)
    }
}

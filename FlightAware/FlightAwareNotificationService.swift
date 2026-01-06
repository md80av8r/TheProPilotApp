//
//  FlightAwareNotificationService.swift
//  TheProPilotApp
//
//  Handles flight share notifications for FlightAware integration
//

import Foundation
import UserNotifications
import UIKit

/// Service for sending flight share prompts and handling notification actions
class FlightAwareNotificationService {
    static let shared = FlightAwareNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification identifiers
    private let categoryIdentifier = "FLIGHTAWARE_SHARE"
    private let shareActionIdentifier = "SHARE_FLIGHT"
    private let dismissActionIdentifier = "DISMISS"

    // Track which flights have already prompted (avoid spamming)
    private var promptedFlights: Set<String> = []

    private init() {
        setupNotificationCategory()
    }

    // MARK: - Setup

    private func setupNotificationCategory() {
        let shareAction = UNNotificationAction(
            identifier: shareActionIdentifier,
            title: "Share Flight",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: dismissActionIdentifier,
            title: "Not Now",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [shareAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Permission

    /// Request notification permission if not already granted
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            } catch {
                print("[FlightAware] Notification permission error: \(error)")
                return false
            }
        case .denied, .ephemeral:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Send Notifications

    /// Send a notification prompting the user to share their flight
    func sendFlightSharePrompt(for flight: FAFlightCache, leg: FlightLeg) async {
        // Check if we've already prompted for this flight
        let flightKey = flight.faFlightId
        guard !promptedFlights.contains(flightKey) else {
            print("[FlightAware] Already prompted for flight: \(flightKey)")
            return
        }

        // Request permission if needed
        guard await requestPermissionIfNeeded() else {
            print("[FlightAware] Notification permission not granted")
            return
        }

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = "Your flight is ready to track!"

        let route = "\(flight.originCode ?? leg.departure) → \(flight.destinationCode ?? leg.arrival)"
        if let eta = flight.etaDisplay {
            content.body = "\(flight.ident): \(route)\nETA: \(eta)"
        } else {
            content.body = "\(flight.ident): \(route)"
        }

        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        // Store flight data for action handling
        content.userInfo = [
            "faFlightId": flight.faFlightId,
            "ident": flight.ident,
            "trackingURL": flight.trackingURL?.absoluteString ?? "",
            "route": route
        ]

        // Create request (deliver immediately)
        let request = UNNotificationRequest(
            identifier: "flightaware_share_\(flightKey)",
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await notificationCenter.add(request)
            promptedFlights.insert(flightKey)
            print("[FlightAware] Share notification sent for: \(flight.ident)")
        } catch {
            print("[FlightAware] Failed to send notification: \(error)")
        }
    }

    /// Send an ETA update notification
    func sendETAUpdate(for flight: FAFlightCache, previousETA: Date?, newETA: Date) async {
        guard await requestPermissionIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Flight ETA Updated"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")

        if let previous = previousETA {
            let diff = Int(newETA.timeIntervalSince(previous) / 60)
            if diff > 0 {
                content.body = "\(flight.ident): Delayed \(diff) min. New ETA: \(formatter.string(from: newETA))"
            } else {
                content.body = "\(flight.ident): Earlier by \(abs(diff)) min. New ETA: \(formatter.string(from: newETA))"
            }
        } else {
            content.body = "\(flight.ident): ETA \(formatter.string(from: newETA))"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flightaware_eta_\(flight.faFlightId)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Action Handling

    /// Handle notification action response
    func handleNotificationAction(response: UNNotificationResponse) {
        guard response.notification.request.content.categoryIdentifier == categoryIdentifier else {
            return
        }

        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case shareActionIdentifier:
            handleShareAction(userInfo: userInfo)
        case dismissActionIdentifier:
            // Just dismiss, nothing to do
            break
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleShareAction(userInfo: userInfo)
        default:
            break
        }
    }

    private func handleShareAction(userInfo: [AnyHashable: Any]) {
        guard let urlString = userInfo["trackingURL"] as? String,
              let url = URL(string: urlString),
              let ident = userInfo["ident"] as? String,
              let route = userInfo["route"] as? String else {
            return
        }

        // Post notification to show share sheet from main app
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .flightAwareShareRequested,
                object: nil,
                userInfo: [
                    "url": url,
                    "ident": ident,
                    "route": route
                ]
            )
        }
    }

    // MARK: - Share Helpers

    /// Create a shareable text for the flight
    static func shareText(for flight: FAFlightCache) -> String {
        var text = "Track my flight: \(flight.ident)"

        if let origin = flight.originCode, let dest = flight.destinationCode {
            text += "\n\(origin) → \(dest)"
        }

        if let eta = flight.etaDisplay {
            text += "\nETA: \(eta)"
        }

        if let url = flight.trackingURL {
            text += "\n\(url.absoluteString)"
        }

        return text
    }

    /// Create items for UIActivityViewController
    static func shareItems(for flight: FAFlightCache) -> [Any] {
        var items: [Any] = [shareText(for: flight)]

        if let url = flight.trackingURL {
            items.append(url)
        }

        return items
    }

    // MARK: - Cleanup

    /// Clear prompted flights cache (call when app becomes active or trip ends)
    func clearPromptedCache() {
        promptedFlights.removeAll()
    }

    /// Remove pending notifications for a specific flight
    func cancelNotifications(for flightId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "flightaware_share_\(flightId)",
            "flightaware_eta_\(flightId)"
        ])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [
            "flightaware_share_\(flightId)",
            "flightaware_eta_\(flightId)"
        ])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let flightAwareShareRequested = Notification.Name("flightAwareShareRequested")
    static let flightAwareDataUpdated = Notification.Name("flightAwareDataUpdated")
}

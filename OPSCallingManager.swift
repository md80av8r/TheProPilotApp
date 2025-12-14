//
//  OPSCallingManager.swift
//  ProPilotApp
//
//  Enhanced with automatic OPS calling based on location events
//

import SwiftUI
import Foundation

// MARK: - Notification Names Extension

class OPSCallingManager: ObservableObject {
    @Published var opsPhoneNumber: String = ""
    @Published var currentAirline: String = ""
    @Published var autoCallEnabled = true
    @Published var lastCallTime: Date?
    @Published var callLog: [OPSCall] = []
    
    private let defaults = UserDefaults.standard
    private let opsPhoneNumberKey = "opsPhoneNumber"
    private let currentAirlineKey = "currentAirline"
    private let autoCallEnabledKey = "autoCallEnabled"
    
    struct OPSCall: Codable {
        let timestamp: Date
        let reason: String
        let airport: String
        let phoneNumber: String
        let wasAutomatic: Bool
    }
    
    enum CallReason {
        case dutyStart
        case dutyEnd
        case arrivalAtBase
        case departureFromBase
        case emergency
        case manual
        
        var description: String {
            switch self {
            case .dutyStart: return "Duty Start"
            case .dutyEnd: return "Duty End"
            case .arrivalAtBase: return "Arrival at Base"
            case .departureFromBase: return "Departure from Base"
            case .emergency: return "Emergency"
            case .manual: return "Manual Call"
            }
        }
    }
    
    // Default phone numbers - can be overridden by user
    private let defaultAirlines: [String: String] = [
        "USA Jet": "734-482-0888",
        "American": "800-433-7300",
        "Delta": "800-221-1212",
        "United": "800-864-8331",
        "Southwest": "800-435-9792"
    ]
    
    init() {
        // Load saved settings
        loadSettings()
        setupNotificationObservers()
    }
    
    private func loadSettings() {
        currentAirline = defaults.string(forKey: currentAirlineKey) ?? "USA Jet"
        autoCallEnabled = defaults.bool(forKey: autoCallEnabledKey)
        
        // Try to load custom phone number first, fall back to default
        if let savedNumber = defaults.string(forKey: opsPhoneNumberKey), !savedNumber.isEmpty {
            opsPhoneNumber = savedNumber
        } else {
            opsPhoneNumber = defaultAirlines[currentAirline] ?? ""
        }
        
        print("📞 OPS: Loaded settings - Airline: \(currentAirline), Phone: \(opsPhoneNumber)")
    }
    
    private func saveSettings() {
        defaults.set(opsPhoneNumber, forKey: opsPhoneNumberKey)
        defaults.set(currentAirline, forKey: currentAirlineKey)
        defaults.set(autoCallEnabled, forKey: autoCallEnabledKey)
        print("📞 OPS: Saved settings")
    }
    
    private func setupNotificationObservers() {
        // Listen for automatic location-based events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDutyStart),
            name: .startDutyFromWatch,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDutyEnd),
            name: .endDutyFromWatch,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAirportArrival),
            name: .arrivedAtAirport,
            object: nil
        )
        
        print("🛩️ OPSCallingManager: Set up notification observers")
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleDutyStart(_ notification: Notification) {
        guard autoCallEnabled else { return }
        
        let airport = notification.userInfo?["airport"] as? String ?? "Unknown"
        print("🛩️ OPS: Auto-detected duty start at \(airport)")
        
        if shouldAutoCall(for: .dutyStart, at: airport) {
            scheduleAutoCall(reason: .dutyStart, airport: airport)
        }
    }
    
    @objc private func handleDutyEnd(_ notification: Notification) {
        guard autoCallEnabled else { return }
        
        let airport = notification.userInfo?["airport"] as? String ?? "Unknown"
        print("🛩️ OPS: Auto-detected duty end at \(airport)")
        
        if shouldAutoCall(for: .dutyEnd, at: airport) {
            scheduleAutoCall(reason: .dutyEnd, airport: airport)
        }
    }
    
    @objc private func handleAirportArrival(_ notification: Notification) {
        guard autoCallEnabled else { return }
        
        let airport = notification.userInfo?["airport"] as? String ?? "Unknown"
        print("🛩️ OPS: Arrived at \(airport)")
        
        // Check if this is arrival at home base (KYIP for USA Jet)
        if isHomeBase(airport) && shouldAutoCall(for: .arrivalAtBase, at: airport) {
            scheduleAutoCall(reason: .arrivalAtBase, airport: airport)
        }
    }
    
    // MARK: - Auto-Call Logic
    
    private func shouldAutoCall(for reason: CallReason, at airport: String) -> Bool {
        // Don't call too frequently (minimum 15 minutes between calls)
        if let lastCall = lastCallTime,
           Date().timeIntervalSince(lastCall) < 900 { // 15 minutes
            print("🛩️ OPS: Skipping auto-call (too recent)")
            return false
        }
        
        // Only auto-call for certain scenarios
        switch reason {
        case .dutyStart:
            return isHomeBase(airport) // Only call when starting duty at home base
        case .dutyEnd:
            return isHomeBase(airport) // Only call when ending duty at home base
        case .arrivalAtBase:
            return true // Always call when arriving at base
        case .departureFromBase:
            return false // Don't auto-call on departure
        case .emergency, .manual:
            return true
        }
    }
    
    private func isHomeBase(_ airport: String) -> Bool {
        // Define home bases for different airlines
        let homeBases: [String: [String]] = [
            "USA Jet": ["KYIP", "KDET"], // Willow Run, Detroit City
            "American": ["KDFW", "KMIA", "KORD", "KPHX"],
            "Delta": ["KATL", "KORD", "KLAX", "KJFK"],
            "United": ["KORD", "KDEN", "KIAH", "KEWR"],
            "Southwest": ["KDFW", "KPHX", "KBWI", "KDEN"]
        ]
        
        return homeBases[currentAirline]?.contains(airport) ?? false
    }
    
    private func scheduleAutoCall(reason: CallReason, airport: String) {
        // Give a small delay for user to cancel if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.callOPS(reason: reason, airport: airport, isAutomatic: true)
        }
    }
    
    // MARK: - OPS Configuration
    
    func setupOPSNumber(for airline: String, customNumber: String? = nil) {
        currentAirline = airline
        
        if let custom = customNumber, !custom.isEmpty {
            // User provided a custom number
            opsPhoneNumber = custom
        } else {
            // Use default for this airline or keep existing custom number
            if let savedNumber = defaults.string(forKey: opsPhoneNumberKey), !savedNumber.isEmpty {
                opsPhoneNumber = savedNumber
            } else {
                opsPhoneNumber = defaultAirlines[airline] ?? ""
            }
        }
        
        saveSettings()
        print("📞 OPS: Set up for \(airline) - \(opsPhoneNumber)")
    }
    
    func updateOPSPhoneNumber(_ newNumber: String) {
        opsPhoneNumber = newNumber
        saveSettings()
        print("📞 OPS: Updated phone number to \(newNumber)")
    }
    
    func getDefaultPhoneNumber(for airline: String) -> String? {
        return defaultAirlines[airline]
    }
    
    func callOPS(reason: CallReason = .manual, airport: String = "Unknown", isAutomatic: Bool = false) {
        guard !opsPhoneNumber.isEmpty else {
            print("🛩️ OPS: No phone number configured")
            return
        }
        
        // Log the call
        let call = OPSCall(
            timestamp: Date(),
            reason: reason.description,
            airport: airport,
            phoneNumber: opsPhoneNumber,
            wasAutomatic: isAutomatic
        )
        callLog.append(call)
        lastCallTime = Date()
        
        print("🛩️ OPS: Calling \(opsPhoneNumber) - \(reason.description) at \(airport)")
        
        // Make the actual phone call
        guard let url = URL(string: "tel://\(opsPhoneNumber)") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            print("🛩️ OPS: Cannot make phone calls on this device")
        }
        
        // Show notification
        showCallNotification(reason: reason, airport: airport, isAutomatic: isAutomatic)
    }
    
    private func showCallNotification(reason: CallReason, airport: String, isAutomatic: Bool) {
        let title = isAutomatic ? "Auto-Calling OPS" : "Calling OPS"
        let body = "\(reason.description) at \(airport)"
        
        // You can integrate this with your notification system
        print("🛩️ Notification: \(title) - \(body)")
    }
    
    // MARK: - Manual Call Interface
    
    func callOPSForDutyStart(at airport: String) {
        callOPS(reason: .dutyStart, airport: airport, isAutomatic: false)
    }
    
    func callOPSForDutyEnd(at airport: String) {
        callOPS(reason: .dutyEnd, airport: airport, isAutomatic: false)
    }
    
    func callOPSEmergency() {
        callOPS(reason: .emergency, airport: "Unknown", isAutomatic: false)
    }
    
    // MARK: - Configuration
    
    func toggleAutoCall() {
        autoCallEnabled.toggle()
        saveSettings()
        print("🛩️ OPS: Auto-call \(autoCallEnabled ? "enabled" : "disabled")")
    }
    
    func getAvailableAirlines() -> [String] {
        return Array(defaultAirlines.keys).sorted()
    }
    
    func hasOPSNumber() -> Bool {
        return !opsPhoneNumber.isEmpty
    }
    
    func getFormattedOPSNumber() -> String {
        guard !opsPhoneNumber.isEmpty else { return "Not configured" }
        
        // Format phone number for display
        let cleaned = opsPhoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleaned.count == 10 {
            let area = String(cleaned.prefix(3))
            let middle = String(cleaned.dropFirst(3).prefix(3))
            let last = String(cleaned.suffix(4))
            return "(\(area)) \(middle)-\(last)"
        }
        
        return opsPhoneNumber
    }
    
    func getRecentCalls(limit: Int = 10) -> [OPSCall] {
        return Array(callLog.suffix(limit).reversed())
    }
    
    func clearCallLog() {
        callLog.removeAll()
        print("🛩️ OPS: Call log cleared")
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> String {
        var info = "🛩️ OPS CALLING DEBUG:\n"
        info += "• Airline: \(currentAirline)\n"
        info += "• Phone: \(getFormattedOPSNumber())\n"
        info += "• Auto-call: \(autoCallEnabled ? "Enabled" : "Disabled")\n"
        info += "• Last call: \(lastCallTime?.formatted() ?? "Never")\n"
        info += "• Total calls: \(callLog.count)\n"
        
        if !callLog.isEmpty {
            info += "• Recent calls:\n"
            for call in getRecentCalls(limit: 3) {
                let auto = call.wasAutomatic ? " (Auto)" : ""
                info += "  - \(call.reason) at \(call.airport)\(auto)\n"
            }
        }
        
        return info
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

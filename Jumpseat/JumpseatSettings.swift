// JumpseatSettings.swift - User Preferences for Jumpseat Network
// ProPilot App

import Foundation
import SwiftUI
import Combine

/// Manages user preferences for the Jumpseat Network feature
class JumpseatSettings: ObservableObject {
    static let shared = JumpseatSettings()
    
    // MARK: - Published Properties
    
    @Published var autoPostFlights: Bool { didSet { save() } }
    @Published var defaultSeatsAvailable: Int { didSet { save() } }
    @Published var defaultJumpseatType: JumpseatType { didSet { save() } }
    @Published var defaultCassRequired: Bool { didSet { save() } }
    @Published var operatorName: String { didSet { save() } }
    @Published var displayName: String { didSet { save() } }
    @Published var homeBase: String { didSet { save() } }
    @Published var defaultSearchRadius: Double { didSet { save() } }
    @Published var notificationsEnabled: Bool { didSet { save() } }
    @Published var notifyOnInterest: Bool { didSet { save() } }
    @Published var notifyOnMessages: Bool { didSet { save() } }
    @Published var notifyBeforeDeparture: Bool { didSet { save() } }
    @Published var departureReminderHours: Int { didSet { save() } }
    @Published var allowDirectMessages: Bool { didSet { save() } }
    @Published var showOnlineStatus: Bool { didSet { save() } }
    @Published var includeTripNotes: Bool { didSet { save() } }
    @Published var autoDeleteAfterDeparture: Bool { didSet { save() } }
    @Published var userId: String?
    @Published var hasCompletedOnboarding: Bool { didSet { save() } }
    @Published var lastSyncTime: Date?
    
    private let defaults = UserDefaults.standard
    private let keyPrefix = "jumpseat_"
    
    private init() {
        // Initialize all properties with default values first
        self.autoPostFlights = false
        self.defaultSeatsAvailable = 1
        self.defaultJumpseatType = .cockpit
        self.defaultCassRequired = true
        self.operatorName = ""
        self.displayName = ""
        self.homeBase = ""
        self.defaultSearchRadius = 50
        self.notificationsEnabled = true
        self.notifyOnInterest = true
        self.notifyOnMessages = true
        self.notifyBeforeDeparture = true
        self.departureReminderHours = 2
        self.allowDirectMessages = true
        self.showOnlineStatus = true
        self.includeTripNotes = false
        self.autoDeleteAfterDeparture = true
        self.hasCompletedOnboarding = false
        self.lastSyncTime = nil
        self.userId = nil
        
        // Now load from UserDefaults
        loadFromDefaults()
    }
    
    private func loadFromDefaults() {
        autoPostFlights = defaults.bool(forKey: keyPrefix + "autoPostFlights")
        
        let seats = defaults.integer(forKey: keyPrefix + "defaultSeatsAvailable")
        defaultSeatsAvailable = seats == 0 ? 1 : seats
        
        if let typeRaw = defaults.string(forKey: keyPrefix + "defaultJumpseatType"),
           let type = JumpseatType(rawValue: typeRaw) {
            defaultJumpseatType = type
        }
        
        if defaults.object(forKey: keyPrefix + "defaultCassRequired") != nil {
            defaultCassRequired = defaults.bool(forKey: keyPrefix + "defaultCassRequired")
        }
        
        operatorName = defaults.string(forKey: keyPrefix + "operatorName") ?? ""
        displayName = defaults.string(forKey: keyPrefix + "displayName") ?? ""
        homeBase = defaults.string(forKey: keyPrefix + "homeBase") ?? ""
        
        let radius = defaults.double(forKey: keyPrefix + "defaultSearchRadius")
        defaultSearchRadius = radius == 0 ? 50 : radius
        
        if defaults.object(forKey: keyPrefix + "notificationsEnabled") != nil {
            notificationsEnabled = defaults.bool(forKey: keyPrefix + "notificationsEnabled")
        }
        if defaults.object(forKey: keyPrefix + "notifyOnInterest") != nil {
            notifyOnInterest = defaults.bool(forKey: keyPrefix + "notifyOnInterest")
        }
        if defaults.object(forKey: keyPrefix + "notifyOnMessages") != nil {
            notifyOnMessages = defaults.bool(forKey: keyPrefix + "notifyOnMessages")
        }
        if defaults.object(forKey: keyPrefix + "notifyBeforeDeparture") != nil {
            notifyBeforeDeparture = defaults.bool(forKey: keyPrefix + "notifyBeforeDeparture")
        }
        
        let hours = defaults.integer(forKey: keyPrefix + "departureReminderHours")
        departureReminderHours = hours == 0 ? 2 : hours
        
        if defaults.object(forKey: keyPrefix + "allowDirectMessages") != nil {
            allowDirectMessages = defaults.bool(forKey: keyPrefix + "allowDirectMessages")
        }
        if defaults.object(forKey: keyPrefix + "showOnlineStatus") != nil {
            showOnlineStatus = defaults.bool(forKey: keyPrefix + "showOnlineStatus")
        }
        includeTripNotes = defaults.bool(forKey: keyPrefix + "includeTripNotes")
        if defaults.object(forKey: keyPrefix + "autoDeleteAfterDeparture") != nil {
            autoDeleteAfterDeparture = defaults.bool(forKey: keyPrefix + "autoDeleteAfterDeparture")
        }
        hasCompletedOnboarding = defaults.bool(forKey: keyPrefix + "hasCompletedOnboarding")
        lastSyncTime = defaults.object(forKey: keyPrefix + "lastSyncTime") as? Date
    }
    
    private func save() {
        defaults.set(autoPostFlights, forKey: keyPrefix + "autoPostFlights")
        defaults.set(defaultSeatsAvailable, forKey: keyPrefix + "defaultSeatsAvailable")
        defaults.set(defaultJumpseatType.rawValue, forKey: keyPrefix + "defaultJumpseatType")
        defaults.set(defaultCassRequired, forKey: keyPrefix + "defaultCassRequired")
        defaults.set(operatorName, forKey: keyPrefix + "operatorName")
        defaults.set(displayName, forKey: keyPrefix + "displayName")
        defaults.set(homeBase, forKey: keyPrefix + "homeBase")
        defaults.set(defaultSearchRadius, forKey: keyPrefix + "defaultSearchRadius")
        defaults.set(notificationsEnabled, forKey: keyPrefix + "notificationsEnabled")
        defaults.set(notifyOnInterest, forKey: keyPrefix + "notifyOnInterest")
        defaults.set(notifyOnMessages, forKey: keyPrefix + "notifyOnMessages")
        defaults.set(notifyBeforeDeparture, forKey: keyPrefix + "notifyBeforeDeparture")
        defaults.set(departureReminderHours, forKey: keyPrefix + "departureReminderHours")
        defaults.set(allowDirectMessages, forKey: keyPrefix + "allowDirectMessages")
        defaults.set(showOnlineStatus, forKey: keyPrefix + "showOnlineStatus")
        defaults.set(includeTripNotes, forKey: keyPrefix + "includeTripNotes")
        defaults.set(autoDeleteAfterDeparture, forKey: keyPrefix + "autoDeleteAfterDeparture")
        defaults.set(hasCompletedOnboarding, forKey: keyPrefix + "hasCompletedOnboarding")
        if let syncTime = lastSyncTime {
            defaults.set(syncTime, forKey: keyPrefix + "lastSyncTime")
        }
    }
    
    var canPostFlights: Bool {
        !displayName.isEmpty && !operatorName.isEmpty
    }
    
    var isProfileComplete: Bool {
        !displayName.isEmpty && !operatorName.isEmpty && !homeBase.isEmpty
    }
    
    func resetToDefaults() {
        autoPostFlights = false
        defaultSeatsAvailable = 1
        defaultJumpseatType = .cockpit
        defaultCassRequired = true
        defaultSearchRadius = 50
        notificationsEnabled = true
        notifyOnInterest = true
        notifyOnMessages = true
        notifyBeforeDeparture = true
        departureReminderHours = 2
        allowDirectMessages = true
        showOnlineStatus = true
        includeTripNotes = false
        autoDeleteAfterDeparture = true
    }
}

// MARK: - Settings View

struct JumpseatSettingsView: View {
    @ObservedObject var settings = JumpseatSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Display Name", text: $settings.displayName)
                    TextField("Airline/Operator", text: $settings.operatorName)
                    TextField("Home Base (ICAO)", text: $settings.homeBase)
                        .textInputAutocapitalization(.characters)
                } header: { Text("Your Profile") }
                
                Section {
                    Toggle("Auto-Post Flights", isOn: $settings.autoPostFlights)
                    if settings.autoPostFlights {
                        Stepper("Default Seats: \(settings.defaultSeatsAvailable)", value: $settings.defaultSeatsAvailable, in: 1...4)
                        Picker("Jumpseat Type", selection: $settings.defaultJumpseatType) {
                            ForEach(JumpseatType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Toggle("CASS Required", isOn: $settings.defaultCassRequired)
                    }
                } header: { Text("Flight Posting") }
                
                Section {
                    HStack {
                        Text("Search Radius")
                        Spacer()
                        Text("\(Int(settings.defaultSearchRadius)) NM").foregroundColor(.secondary)
                    }
                    Slider(value: $settings.defaultSearchRadius, in: 10...200, step: 10)
                } header: { Text("Search") }
                
                Section {
                    Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                } header: { Text("Notifications") }
                
                Section {
                    Toggle("Allow Direct Messages", isOn: $settings.allowDirectMessages)
                    Toggle("Auto-Delete After Departure", isOn: $settings.autoDeleteAfterDeparture)
                } header: { Text("Privacy") }
            }
            .navigationTitle("Jumpseat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

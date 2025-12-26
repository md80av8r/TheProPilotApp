//
//  DutyTimeSettingsStore.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/22/25.
//


//
//  DutyTimeSettingsStore.swift
//  TheProPilotApp
//
//  Settings for automatic duty time calculation
//

import Foundation
import SwiftUI

/// Settings for duty time calculation
@MainActor
class DutyTimeSettingsStore: ObservableObject {
    static let shared = DutyTimeSettingsStore()
    
    // MARK: - Published Properties
    
    /// Master toggle for duty time tracking
    @AppStorage("dutyTimeTrackingEnabled") var trackingEnabled: Bool = true
    
    /// Calculation method
    @AppStorage("dutyTimeCalculationMethod") private var calculationMethodRaw: String = DutyCalculationMethod.automatic.rawValue
    
    var calculationMethod: DutyCalculationMethod {
        get { DutyCalculationMethod(rawValue: calculationMethodRaw) ?? .automatic }
        set { calculationMethodRaw = newValue.rawValue }
    }
    
    /// Pre-flight time (minutes before first block OUT)
    @AppStorage("dutyPreFlightMinutes") var preFlightMinutes: Int = 60
    
    /// Post-flight time (minutes after last block IN)
    @AppStorage("dutyPostFlightMinutes") var postFlightMinutes: Int = 15
    
    /// Allow manual edits per trip
    @AppStorage("dutyAllowManualEdits") var allowManualEdits: Bool = true
    
    /// Manual mode: Enable geofencing prompts
    @AppStorage("dutyGeofencingEnabled") var geofencingEnabled: Bool = true
    
    /// Manual mode: Enable duty timer
    @AppStorage("dutyTimerEnabled") var timerEnabled: Bool = true
    
    private init() {}
}

/// Duty time calculation method
enum DutyCalculationMethod: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case manual = "Manual"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .automatic:
            return "Auto-calculate based on flight times"
        case .manual:
            return "Use geofencing and duty timer"
        }
    }
    
    var icon: String {
        switch self {
        case .automatic: return "clock.badge.checkmark"
        case .manual: return "timer.circle"
        }
    }
}
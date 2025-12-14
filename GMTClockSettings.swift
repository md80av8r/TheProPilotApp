//
//  GMTClockSettings.swift
//  Created on 12/03/2025
//

import SwiftUI
import Observation

/// Observable settings for the persistent GMT clock display
@Observable
final class GMTClockSettings {
    /// Shared instance for app-wide access
    static let shared = GMTClockSettings()
    
    /// Whether the GMT clock pill should be visible
    var isClockVisible: Bool {
        didSet {
            UserDefaults.standard.set(isClockVisible, forKey: "GMTClockVisible")
        }
    }
    
    private init() {
        // Load saved preference, default to false
        self.isClockVisible = UserDefaults.standard.bool(forKey: "GMTClockVisible")
    }
}

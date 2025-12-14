//
//  TripCreationSettings.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/1/25.
//


import Foundation
import Combine

// MARK: - Trip Creation Settings
class TripCreationSettings: ObservableObject {
    static let shared = TripCreationSettings()
    
    @Published var allowWatchTripCreation: Bool {
        didSet {
            UserDefaults.standard.set(allowWatchTripCreation, forKey: "allowWatchTripCreation")
        }
    }
    
    @Published var preferredTripCreationDevice: TripCreationDevice {
        didSet {
            UserDefaults.standard.set(preferredTripCreationDevice.rawValue, forKey: "preferredTripCreationDevice")
        }
    }
    
    private init() {
        self.allowWatchTripCreation = UserDefaults.standard.object(forKey: "allowWatchTripCreation") as? Bool ?? false
        
        let deviceRawValue = UserDefaults.standard.string(forKey: "preferredTripCreationDevice") ?? TripCreationDevice.iPhone.rawValue
        self.preferredTripCreationDevice = TripCreationDevice(rawValue: deviceRawValue) ?? .iPhone
    }
    
    enum TripCreationDevice: String, CaseIterable {
        case iPhone = "iPhone"
        case watch = "Apple Watch"
        
        var displayName: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .iPhone: return "iphone"
            case .watch: return "applewatch"
            }
        }
        
        var description: String {
            switch self {
            case .iPhone:
                return "Trips must be created from the iPhone app with full trip details"
            case .watch:
                return "Trips can be created directly from Apple Watch when starting duty"
            }
        }
    }
}
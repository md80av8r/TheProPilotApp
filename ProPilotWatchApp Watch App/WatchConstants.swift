// WatchConstants.swift - Watch Configuration and Constants
import SwiftUI

// MARK: - Watch Theme Colors
struct WatchTheme {
    static let primaryBlue = Color.blue
    static let primaryGreen = Color.green
    static let primaryOrange = Color.orange
    static let primaryRed = Color.red
    static let primaryPurple = Color.purple
    
    static let successGreen = Color.green
    static let warningOrange = Color.orange
    static let dangerRed = Color.red
    static let infoBlue = Color.blue
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.6)
    
    static let backgroundPrimary = Color.black
    static let backgroundSecondary = Color.gray.opacity(0.1)
}

// MARK: - Watch Layout Constants
struct WatchLayout {
    static let cornerRadius: CGFloat = 8
    static let smallCornerRadius: CGFloat = 4
    static let buttonHeight: CGFloat = 32
    static let smallButtonHeight: CGFloat = 24
    
    static let standardPadding: CGFloat = 8
    static let smallPadding: CGFloat = 4
    static let largePadding: CGFloat = 12
    
    static let iconSize: CGFloat = 20
    static let largeIconSize: CGFloat = 32
}

// MARK: - Watch Animation Constants
struct WatchAnimations {
    static let quickDuration: TimeInterval = 0.2
    static let standardDuration: TimeInterval = 0.3
    static let slowDuration: TimeInterval = 0.5
    
    static let quickAnimation = Animation.easeInOut(duration: quickDuration)
    static let standardAnimation = Animation.easeInOut(duration: standardDuration)
    static let slowAnimation = Animation.easeInOut(duration: slowDuration)
}

// MARK: - Watch Timing Constants
struct WatchTiming {
    static let refreshInterval: TimeInterval = 1.0 // 1 second for duty timer
    static let connectionTimeout: TimeInterval = 5.0
    static let messageTimeout: TimeInterval = 3.0
    
    // Speed thresholds for automatic time detection
    //static let takeoffSpeedThreshold: Double = 80.0 // knots
    //static let landingSpeedThreshold: Double = 40.0 // knots
}

// MARK: - Watch Configuration
struct WatchConfig {
    static let enableHaptics = true
    static let enableComplications = true
    static let enableDebugLogging = true
    
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 1.0
    
    // Display preferences
    static let showSeconds = true
    static let use24HourFormat = true
    static let showSpeedWhenMoving = true
}

// MARK: - Watch Feedback Messages
struct WatchFeedback {
    static let dutyStarted = "Duty timer started"
    static let dutyEnded = "Duty timer ended"
    static let timeRecorded = "Time recorded"
    static let opsCallRequested = "Calling OPS..."
    static let connectionLost = "Phone disconnected"
    static let connectionRestored = "Phone connected"
    
    static let errorGeneric = "Something went wrong"
    static let errorConnection = "Connection failed"
    static let errorTimeout = "Request timed out"
}

// MARK: - Watch Button Configurations
struct WatchButtonConfig {
    struct DutyTimer {
        static let startTitle = "Start Duty"
        static let endTitle = "End Duty"
        static let startColor = WatchTheme.successGreen
        static let endColor = WatchTheme.dangerRed
    }
    
    struct FlightTimes {
        static let outTitle = "OUT"
        static let offTitle = "OFF"
        static let onTitle = "ON"
        static let inTitle = "IN"
        
        static let outColor = WatchTheme.primaryBlue
        static let offColor = WatchTheme.successGreen
        static let onColor = WatchTheme.warningOrange
        static let inColor = WatchTheme.primaryPurple
    }
    
    struct OPS {
        static let callTitle = "Call OPS"
        static let releaseTitle = "Flight Release"
        static let callColor = WatchTheme.successGreen
        static let releaseColor = WatchTheme.infoBlue
    }
}

// MARK: - Watch Status Icons
struct WatchIcons {
    static let connected = "wifi"
    static let disconnected = "wifi.slash"
    static let dutyOn = "clock.fill"
    static let dutyOff = "clock"
    static let flight = "airplane"
    static let phone = "phone.fill"
    static let location = "location.fill"
    static let speed = "speedometer"
    static let warning = "exclamationmark.triangle.fill"
    static let success = "checkmark.circle.fill"
    static let error = "xmark.circle.fill"
}

// MARK: - Watch Display Formats
struct WatchDisplayFormats {
    static let dutyTimeFormat = "%02d:%02d:%02d"
    static let shortTimeFormat = "%02d:%02d"
    static let flightTimeFormat = "HH:mm"
    static let speedFormat = "%.0f kts"
    static let distanceFormat = "%.1f nm"
}

// MARK: - Watch User Preferences (could be stored in UserDefaults)
class WatchPreferences: ObservableObject {
    @Published var enableHapticFeedback = true
    @Published var enableAutoTimeCapture = true
    @Published var showSpeedDisplay = true
    @Published var preferredTimeFormat: TimeFormat = .twentyFourHour
    
    enum TimeFormat: String, CaseIterable {
        case twelveHour = "12h"
        case twentyFourHour = "24h"
        
        var displayName: String {
            switch self {
            case .twelveHour: return "12 Hour"
            case .twentyFourHour: return "24 Hour"
            }
        }
    }
}

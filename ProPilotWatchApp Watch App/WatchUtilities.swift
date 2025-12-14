// WatchUtilities.swift - Watch Helper Functions
import Foundation
import WatchKit

// MARK: - Watch Haptic Feedback
class WatchHaptics {
    static func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
    
    static func playFailure() {
        WKInterfaceDevice.current().play(.failure)
    }
    
    static func playClick() {
        WKInterfaceDevice.current().play(.click)
    }
    
    static func playStart() {
        WKInterfaceDevice.current().play(.start)
    }
    
    static func playStop() {
        WKInterfaceDevice.current().play(.stop)
    }
}

// MARK: - Watch Time Formatting
struct WatchTimeFormatter {
    static func formatDutyTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    static func formatFlightTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Use Zulu time
        return formatter.string(from: date)
    }
    
    static func formatLocalTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    static func formatSpeed(_ knots: Double) -> String {
        return String(format: "%.0f kts", knots)
    }
}

// MARK: - Watch Message Types
enum WatchMessageType: String, CaseIterable {
    case startDuty = "startDuty"
    case endDuty = "endDuty"
    case setTime = "setTime"
    case callOPS = "callOPS"
    case dutyTimer = "dutyTimer"
    case flightUpdate = "flightUpdate"
    case locationUpdate = "locationUpdate"
}

// MARK: - Watch Flight Time Types
enum FlightTimeType: String, CaseIterable {
    case OUT = "OUT"
    case OFF = "OFF"
    case ON = "ON"
    case IN = "IN"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: String {
        switch self {
        case .OUT: return "blue"
        case .OFF: return "green"
        case .ON: return "orange"
        case .IN: return "purple"
        }
    }
}

// MARK: - Watch Connection Status
enum WatchConnectionStatus {
    case connected
    case disconnected
    case connecting
    case error(String)
    
    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - Watch Debug Logger
class WatchLogger {
    static func log(_ message: String, category: String = "WATCH") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[\(timestamp)] [\(category)] \(message)")
    }
    
    static func logMessage(_ type: WatchMessageType, direction: MessageDirection) {
        let arrow = direction == .sent ? "→" : "←"
        log("\(arrow) \(type.rawValue)", category: "MESSAGE")
    }
    
    enum MessageDirection {
        case sent, received
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// LogbookTheme.swift - Color and Style Definitions (Updated)
import SwiftUI

struct LogbookTheme {
    // MARK: - Primary Colors
    static let navy = Color(red: 0.05, green: 0.05, blue: 0.10)  // Main navy background
    static let navyDark = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let navyLight = Color(red: 0.1, green: 0.1, blue: 0.17)
    static let fieldBackground = Color(red: 0.15, green: 0.15, blue: 0.17)
    
    // MARK: - Accent Colors
    static let accentBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let accentYellow = Color(red: 1.0, green: 0.8, blue: 0.2)  // Added for fuel button
    static let accentPurple = Color(red: 0.6, green: 0.4, blue: 1.0)  // Added for document button
    static let accentRed = Color(red: 1.0, green: 0.3, blue: 0.3)     // Added as alias
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    
    // MARK: - Status Colors
    static let errorRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let successGreen = accentGreen
    
    // MARK: - Additional Colors
    static let divider = Color.white.opacity(0.2)
    static let overlay = Color.black.opacity(0.5)
    static let cardBackground = Color.white.opacity(0.05)
    
    // MARK: - Time Picker Colors
    static let pickerBackground = Color.white.opacity(0.08)  // For ultraThinMaterial alternative
    static let pickerBorder = Color.white.opacity(0.15)
    static let pickerUTCBadge = accentBlue
    
}

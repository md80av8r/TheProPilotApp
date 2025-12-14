//
//  SmartTimeEntryField.swift
//  TheProPilotApp
//
//  Smart time entry with tap-to-fill and long-press picker
//  Respects Zulu/Local time preference for current time
//  Created by Jeffrey Kadans on 11/15/25.
//

import SwiftUI

/// Smart time entry field that supports:
/// - TAP: Fill with current time (Zulu or Local based on settings)
/// - LONG PRESS: Open time picker to manually select time
/// ✅ Now reads from App Group for iPhone/Watch sync
struct SmartTimeEntryField: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var timeString: String // e.g., "1430" or "0930"
    let baseDate: Date // The trip date for context
    var showLabel: Bool = true // Control label visibility
    
    @State private var justTapped = false
    @State private var showingPicker = false
    @State private var selectedTime = Date()
    
    // ✅ Read from App Group for sync with Watch
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    init(label: String, icon: String, color: Color, timeString: Binding<String>, baseDate: Date, showLabel: Bool = true) {
        self.label = label
        self.icon = icon
        self.color = color
        self._timeString = timeString
        self.baseDate = baseDate
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label with icon (only if showLabel is true)
            if showLabel {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Time display with tap and long press
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                justTapped ? color.opacity(0.8) : Color.white.opacity(0.15),
                                lineWidth: justTapped ? 2 : 1
                            )
                    )
                
                // Time text
                HStack {
                    Text(displayTime)
                        .font(.system(showLabel ? .title3 : .caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    
                    // Visual hint
                    if timeString.isEmpty && showLabel {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    } else if justTapped {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.trailing, 8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: showLabel ? 44 : 32)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                handleLongPress()
            }
        }
        .sheet(isPresented: $showingPicker) {
            timePickerSheet
                .interactiveDismissDisabled(false)
        }
    }
    
    // MARK: - Display Time
    private var displayTime: String {
        if timeString.isEmpty {
            return "----"
        }
        
        // Format the stored time string for display
        if let time = parseTime(timeString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm"  // Always 24-hour format
            formatter.timeZone = useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
            return formatter.string(from: time)
        }
        
        // Fallback to raw string formatted
        return formatTimeString(timeString)
    }
    
    private func formatTimeString(_ input: String) -> String {
        guard input.count >= 3 else { return input }
        
        // Handle HHmm format - always display as 24-hour
        if input.count == 4 {
            let hours = String(input.prefix(2))
            let minutes = String(input.suffix(2))
            return "\(hours):\(minutes)"
        }
        
        return input
    }
    
    // MARK: - Tap Handler (Fill Current Time)
    private func handleTap() {
        // Get current time in the user's preferred timezone
        let currentTime = Date()
        
        // Format to HHmm string
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
        
        timeString = formatter.string(from: currentTime)
        selectedTime = currentTime
        
        // Visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            justTapped = true
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Clear the checkmark after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                justTapped = false
            }
        }
        
        print("📍 \(label) tapped - filled with current \(useZuluTime ? "Zulu" : "Local") time: \(timeString)")
    }
    
    // MARK: - Long Press Handler (Show Picker)
    private func handleLongPress() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Parse existing time or use current
        if let existingTime = parseTime(timeString) {
            selectedTime = existingTime
        } else {
            selectedTime = Date()
        }
        
        showingPicker = true
        print("⏰ \(label) long-pressed - opening picker")
    }
    
    // MARK: - Time Parsing
    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
        
        // Clean the input (remove colons, spaces, Z suffix)
        let cleanedTime = timeString.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "Z", with: "")
        
        if let parsedTime = formatter.date(from: cleanedTime) {
            // Combine the parsed time with the base date
            var calendar = Calendar.current
            calendar.timeZone = useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
            
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            
            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute
            combined.timeZone = calendar.timeZone
            
            return calendar.date(from: combined)
        }
        
        return nil
    }
    
    // MARK: - Ultra-Simple Time Picker Sheet
    private var timePickerSheet: some View {
        NavigationView {
            ZStack {
                Color(LogbookTheme.navy).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Time format indicator
                    HStack(spacing: 8) {
                        Image(systemName: useZuluTime ? "globe" : "location.fill")
                            .font(.caption)
                        Text("24-hour") // Always 24-hour format
                            .font(.caption)
                        Text("•")
                            .font(.caption)
                        Text(useZuluTime ? "UTC/Zulu" : "Local")
                            .font(.caption)
                    }
                    .foregroundStyle(LogbookTheme.textSecondary)
                    
                    // Translucent time picker
                    TranslucentTimePicker(
                        timeType: label,
                        initialTime: selectedTime,
                        useZuluTime: useZuluTime,
                        onTimeSet: { time in
                            selectedTime = time
                            savePickedTime()
                            showingPicker = false
                        },
                        onCancel: {
                            showingPicker = false
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("\(label) Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
    }
    
    private func savePickedTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
        timeString = formatter.string(from: selectedTime)
        print("✅ \(label) time set to: \(timeString)")
    }
}

// MARK: - Usage in DataEntryView

/*
 Replace the existing time field TextFields with SmartTimeEntryField:
 
 // OLD:
 TextField("0800", text: $legs[legIndex].outTime)
     .textFieldStyle(LogbookTextFieldStyle())
     .keyboardType(.numberPad)
 
 // NEW:
 SmartTimeEntryField(
     label: "OUT",
     icon: "arrow.up.circle.fill",
     color: .blue,
     timeString: $legs[legIndex].outTime,
     baseDate: date
 )
 
 */

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            SmartTimeEntryField(
                label: "OUT",
                icon: "arrow.up.circle.fill",
                color: Color.blue,
                timeString: .constant(""),
                baseDate: Date()
            )
            
            SmartTimeEntryField(
                label: "OFF",
                icon: "airplane.departure",
                color: Color.green,
                timeString: .constant("1430"),
                baseDate: Date()
            )
            
            SmartTimeEntryField(
                label: "ON",
                icon: "airplane.arrival",
                color: Color.orange,
                timeString: .constant(""),
                baseDate: Date()
            )
            
            SmartTimeEntryField(
                label: "IN",
                icon: "arrow.down.circle.fill",
                color: Color.blue,
                timeString: .constant(""),
                baseDate: Date()
            )
        }
        .padding()
    }
}

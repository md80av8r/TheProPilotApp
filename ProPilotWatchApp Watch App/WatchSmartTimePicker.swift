// WatchSmartTimePicker.swift
// Modern time picker with tap-to-insert current time and long-press to edit

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchSmartTimePicker: View {
    let title: String
    @Binding var time: Date?
    let timeType: TimeFieldType
    
    @State private var showingManualPicker = false
    @State private var tempTime: Date = Date()
    @State private var justSet = false
    
    // Read Zulu/Local setting from app group
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            // Time Display Button
            Button(action: {
                // Single tap: Insert current time
                setCurrentTime()
            }) {
                HStack {
                    Image(systemName: timeType.icon)
                        .foregroundColor(timeType.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let time = time {
                            Text(formatTime(time))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(formatTimeWithSeconds(time))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        } else {
                            Text("Tap to set")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Show checkmark if just set
                    if justSet {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
                .background(time != nil ? timeType.color.opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        // Long press: Open manual editor
                        openManualEditor()
                    }
            )
            
            // Quick action hint
            if time == nil {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                    Text("Tap for now • Hold to edit")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showingManualPicker) {
            manualTimePickerSheet
        }
        .animation(.spring(response: 0.3), value: justSet)
    }
    
    // MARK: - Manual Time Picker Sheet
    private var manualTimePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit \(title)")
                    .font(.headline)
                    .padding(.top)
                
                // Time zone indicator badge
                HStack(spacing: 4) {
                    Image(systemName: useZuluTime ? "globe" : "location.fill")
                        .font(.caption2)
                    Text(useZuluTime ? "UTC" : "Local")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(useZuluTime ? .blue : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((useZuluTime ? Color.blue : Color.orange).opacity(0.2))
                .cornerRadius(6)
                
                // Unified picker for both UTC and local time
                AviationWatchTimePicker(
                    date: $tempTime,
                    timeZone: useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
                )
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Set Button
                    Button(action: {
                        time = tempTime
                        showingManualPicker = false
                        flashCheckmark()
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.success)
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Set Time")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Clear Button
                    if time != nil {
                        Button(action: {
                            time = nil
                            showingManualPicker = false
                            #if os(watchOS)
                            WKInterfaceDevice.current().play(.click)
                            #endif
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Cancel Button
                    Button("Cancel") {
                        showingManualPicker = false
                    }
                    .foregroundColor(.gray)
                }
                .padding()
            }
            .background(Color.black)
        }
    }
    
    // MARK: - Actions
    private func setCurrentTime() {
        time = Date()
        flashCheckmark()
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    private func openManualEditor() {
        tempTime = time ?? Date()
        showingManualPicker = true
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    private func flashCheckmark() {
        withAnimation {
            justSet = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                justSet = false
            }
        }
    }
    
    // MARK: - Formatters
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if useZuluTime {
            // Zulu mode: 24-hour format in UTC
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            formatter.dateFormat = "HH:mm"
        } else {
            // Local mode: 12-hour format with AM/PM in local timezone
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatTimeWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if useZuluTime {
            // Zulu mode: 24-hour format in UTC with 'Z' suffix
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            formatter.dateFormat = "HH:mm:ss'Z'"
        } else {
            // Local mode: 12-hour format with seconds in local timezone
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "h:mm:ss a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Time Field Type
enum TimeFieldType {
    case out, off, on, inTime
    case dutyStart, dutyEnd
    
    var icon: String {
        switch self {
        case .out: return "arrow.right.circle"
        case .off: return "airplane.departure"
        case .on: return "airplane.arrival"
        case .inTime: return "arrow.left.circle"
        case .dutyStart: return "briefcase"
        case .dutyEnd: return "briefcase.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .out: return .blue
        case .off: return .green
        case .on: return .orange
        case .inTime: return .purple
        case .dutyStart: return .cyan
        case .dutyEnd: return .indigo
        }
    }
    
    var displayName: String {
        switch self {
        case .out: return "Out"
        case .off: return "Off"
        case .on: return "On"
        case .inTime: return "In"
        case .dutyStart: return "Duty Start"
        case .dutyEnd: return "Duty End"
        }
    }
}

// MARK: - Compact Time Picker Row (for list-style layouts)
struct WatchCompactTimePicker: View {
    let label: String
    let icon: String
    @Binding var time: Date?
    let color: Color
    
    @State private var showingPicker = false
    @State private var tempTime: Date = Date()
    
    // Read Zulu/Local setting from app group
    @AppStorage("useZuluTime", store: UserDefaults(suiteName: "group.com.propilot.app"))
    private var useZuluTime: Bool = true
    
    var body: some View {
        Button(action: {
            setCurrentTime()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                if let time = time {
                    Text(formatTime(time))
                        .font(.headline)
                        .foregroundColor(color)
                } else {
                    Text("--:--")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    tempTime = time ?? Date()
                    showingPicker = true
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }
        )
        .sheet(isPresented: $showingPicker) {
            VStack(spacing: 16) {
                Text("Edit \(label)")
                    .font(.headline)
                
                // Time zone indicator
                HStack(spacing: 4) {
                    Image(systemName: useZuluTime ? "globe" : "location.fill")
                        .font(.caption2)
                    Text(useZuluTime ? "UTC" : "Local")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(useZuluTime ? .blue : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((useZuluTime ? Color.blue : Color.orange).opacity(0.2))
                .cornerRadius(6)
                
                // Unified picker for both UTC and local time
                AviationWatchTimePicker(
                    date: $tempTime,
                    timeZone: useZuluTime ? TimeZone(abbreviation: "UTC")! : TimeZone.current
                )
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingPicker = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Set") {
                        time = tempTime
                        showingPicker = false
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.success)
                        #endif
                    }
                    .foregroundColor(.green)
                }
            }
            .padding()
        }
    }
    
    private func setCurrentTime() {
        time = Date()
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if useZuluTime {
            // Zulu mode: 24-hour format in UTC
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            formatter.dateFormat = "HH:mm"
        } else {
            // Local mode: 12-hour format with AM/PM in local timezone
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Time Picker Group (for multiple times in one view)
struct WatchTimePickerGroup: View {
    let title: String
    @Binding var out: Date?
    @Binding var off: Date?
    @Binding var on: Date?
    @Binding var inTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                WatchCompactTimePicker(label: "Out", icon: "arrow.right.circle", time: $out, color: .blue)
                WatchCompactTimePicker(label: "Off", icon: "airplane.departure", time: $off, color: .green)
                WatchCompactTimePicker(label: "On", icon: "airplane.arrival", time: $on, color: .orange)
                WatchCompactTimePicker(label: "In", icon: "arrow.left.circle", time: $inTime, color: .purple)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Preview
struct WatchSmartTimePicker_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                WatchSmartTimePicker(
                    title: "Out Time",
                    time: .constant(Date()),
                    timeType: .out
                )
                
                WatchSmartTimePicker(
                    title: "Off Time",
                    time: .constant(nil),
                    timeType: .off
                )
                
                WatchTimePickerGroup(
                    title: "Flight Times",
                    out: .constant(Date()),
                    off: .constant(Date()),
                    on: .constant(Date()),
                    inTime: .constant(Date())
                )
            }
            .padding()
        }
    }
}

// TranslucentTimePicker.swift
// Universal 24-hour time picker with LogbookTheme styling
// Works across the entire ProPilotApp

import SwiftUI

struct TranslucentTimePicker: View {
    let timeType: String
    let initialTime: Date
    let useZuluTime: Bool
    let onTimeSet: (Date) -> Void
    let onCancel: () -> Void
    let onClear: (() -> Void)?  // Optional clear callback
    
    @State private var selectedTime: Date
    @State private var displayTimeZone: TimeZone
    
    init(
        timeType: String,
        initialTime: Date = Date(),
        useZuluTime: Bool = false,
        onTimeSet: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void,
        onClear: (() -> Void)? = nil  // Optional clear handler
    ) {
        self.timeType = timeType
        self.initialTime = initialTime
        self.useZuluTime = useZuluTime
        self.onTimeSet = onTimeSet
        self.onCancel = onCancel
        self.onClear = onClear
        
        _selectedTime = State(initialValue: initialTime)
        _displayTimeZone = State(initialValue: useZuluTime ? TimeZone(identifier: "UTC")! : TimeZone.current)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Time display with optional UTC badge
            HStack(spacing: 12) {
                Text(formatSelectedTime())
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .foregroundColor(LogbookTheme.textPrimary)
                
                if useZuluTime {
                    Text("UTC")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(LogbookTheme.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Divider
            Divider()
                .background(LogbookTheme.divider)
                .padding(.horizontal, 20)
            
            // 24-HOUR TIME PICKER - FORCES 24-HOUR FORMAT
            DatePicker(
                "Time",
                selection: $selectedTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, displayTimeZone)
            .environment(\.locale, Locale(identifier: "en_GB"))  // UK locale = 24-hour format
            .environment(\.calendar, Calendar(identifier: .iso8601))
            .frame(height: 216)
            .clipped()
            .padding(.vertical, 8)
            
            // Divider
            Divider()
                .background(LogbookTheme.divider)
                .padding(.horizontal, 20)
            
            // Action buttons
            VStack(spacing: 12) {
                // Set button
                Button {
                    onTimeSet(selectedTime)
                } label: {
                    Text("Set \(timeType)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LogbookTheme.accentGreen)
                        .cornerRadius(14)
                }
                
                // Clear button (if handler provided)
                if let clearHandler = onClear {
                    Button {
                        clearHandler()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear \(timeType)")
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LogbookTheme.warningYellow)
                        .cornerRadius(14)
                    }
                }
                
                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LogbookTheme.errorRed.opacity(0.8))
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        )
        .onAppear {
            selectedTime = initialTime
            displayTimeZone = useZuluTime ? TimeZone(identifier: "UTC")! : TimeZone.current
        }
    }
    
    private func formatSelectedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "HH:mm"
        var timeString = formatter.string(from: selectedTime)
        if useZuluTime {
            timeString += "Z"
        }
        return timeString
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LogbookTheme.navy.ignoresSafeArea()
        
        TranslucentTimePicker(
            timeType: "OUT",
            initialTime: Date(),
            useZuluTime: true,
            onTimeSet: { _ in },
            onCancel: { }
        )
    }
}

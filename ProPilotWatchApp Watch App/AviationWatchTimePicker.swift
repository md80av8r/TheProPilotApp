//
//  AviationWatchTimePicker.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/13/25.
//


import SwiftUI
import WatchKit

struct AviationWatchTimePicker: View {
    @Binding var date: Date
    let timeZone: TimeZone
    
    // Track previous values for haptic feedback
    @State private var previousHour: Int = 0
    @State private var previousMinute: Int = 0
    
    // ✅ Explicit initializer fixes the "Ambiguous use" error
    init(date: Binding<Date>, timeZone: TimeZone) {
        self._date = date
        self.timeZone = timeZone
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // HOUR PICKER (0-23)
            Picker("Hour", selection: Binding(
                get: {
                    var calendar = Calendar.current
                    calendar.timeZone = timeZone
                    return calendar.component(.hour, from: date)
                },
                set: { newHour in
                    var calendar = Calendar.current
                    calendar.timeZone = timeZone
                    // Preserve all components, just update hour
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    components.hour = newHour
                    
                    if let newDate = calendar.date(from: components) {
                        date = newDate
                        
                        // ✅ HAPTIC FEEDBACK: Play click when hour changes
                        if newHour != previousHour {
                            WKInterfaceDevice.current().play(.click)
                            previousHour = newHour
                        }
                    }
                }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour))
                        .font(.title2)
                        .tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 65)
            .labelsHidden() // ✅ Hides "Hour" text so layout fits

            // SEPARATOR
            Text(":")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)

            // MINUTE PICKER (0-59)
            Picker("Minute", selection: Binding(
                get: {
                    var calendar = Calendar.current
                    calendar.timeZone = timeZone
                    return calendar.component(.minute, from: date)
                },
                set: { newMinute in
                    var calendar = Calendar.current
                    calendar.timeZone = timeZone
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    components.minute = newMinute
                    
                    if let newDate = calendar.date(from: components) {
                        date = newDate
                        
                        // ✅ HAPTIC FEEDBACK: Play click when minute changes
                        if newMinute != previousMinute {
                            WKInterfaceDevice.current().play(.click)
                            previousMinute = newMinute
                        }
                    }
                }
            )) {
                ForEach(0..<60, id: \.self) { minute in
                    Text(String(format: "%02d", minute))
                        .font(.title2)
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 65)
            .labelsHidden() // ✅ Hides "Minute" text so layout fits
        }
        .frame(height: 120)
        .onAppear {
            // Initialize previous values when picker appears
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            previousHour = calendar.component(.hour, from: date)
            previousMinute = calendar.component(.minute, from: date)
        }
    }
}
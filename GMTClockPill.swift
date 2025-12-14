//
//  GMTClockPill.swift
//  Created on 12/03/2025
//

import SwiftUI

/// A floating pill-shaped display showing current GMT time in 24-hour format
struct GMTClockPill: View {
    @State private var currentTime = Date()
    
    // Timer that updates every second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(formattedGMTTime)
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.black.opacity(0.75))
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .onReceive(timer) { newTime in
                currentTime = newTime
            }
    }
    
    /// Formats the current time as GMT in 24-hour format (e.g., "GMT 14:32:05")
    private var formattedGMTTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "HH:mm:ss"
        return "GMT \(formatter.string(from: currentTime))"
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        VStack {
            Spacer()
            GMTClockPill()
            Spacer()
        }
    }
}

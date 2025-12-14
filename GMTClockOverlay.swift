//
//  GMTClockOverlay.swift
//  Created on 12/03/2025
//

import SwiftUI

/// View modifier that adds the GMT clock pill overlay to any view
struct GMTClockOverlay: ViewModifier {
    // Use direct observation of the shared instance
    var settings = GMTClockSettings.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if settings.isClockVisible {
                    GMTClockPill()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: settings.isClockVisible)
                }
            }
    }
}

extension View {
    /// Adds a persistent GMT clock pill overlay that can be toggled via GMTClockSettings
    func gmtClockOverlay() -> some View {
        modifier(GMTClockOverlay())
    }
}

#Preview {
    NavigationStack {
        List {
            ForEach(0..<20) { index in
                Text("Item \(index)")
            }
        }
        .navigationTitle("Sample View")
        .gmtClockOverlay()
    }
    .onAppear {
        GMTClockSettings.shared.isClockVisible = true
    }
}

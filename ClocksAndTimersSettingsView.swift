//
//  ClocksAndTimersSettingsView.swift
//  Created on 12/03/2025
//

import SwiftUI

/// Settings view for Clocks and Timers preferences
struct ClocksAndTimersSettingsView: View {
    @Bindable var clockSettings = GMTClockSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Show GMT Clock", isOn: $clockSettings.isClockVisible)
            } header: {
                Text("Display Options")
            } footer: {
                Text("Display a persistent 24-hour GMT clock at the top of all screens.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Spacer()
                        GMTClockPill()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Clocks & Timers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ClocksAndTimersSettingsView()
    }
}

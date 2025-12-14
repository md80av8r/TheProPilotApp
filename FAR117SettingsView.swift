//
//  FAR117SettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/28/25.
//


// FAR117SettingsView.swift
// Configure FAR 117 flight time limits and rest requirements
import SwiftUI

struct FAR117SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // FAR 117 Settings
    @AppStorage("far117Enabled") private var far117Enabled: Bool = true
    @AppStorage("far117ShowWarnings") private var showWarnings: Bool = true
    @AppStorage("far117WarningThreshold") private var warningThreshold: Double = 0.9 // 90% of limit
    @AppStorage("far117AugmentedCrew") private var augmentedCrew: Bool = false
    @AppStorage("far117AcclimatizedBase") private var acclimatizedBase: String = "KYIP"
    
    // Notification Settings
    @AppStorage("far117NotifyApproachingLimit") private var notifyApproaching: Bool = true
    @AppStorage("far117NotifyRestRequired") private var notifyRestRequired: Bool = true
    
    var body: some View {
        NavigationView {
            List {
                // Enable/Disable
                Section {
                    Toggle("Enable FAR 117 Tracking", isOn: $far117Enabled)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentGreen)
                        .listRowBackground(LogbookTheme.navyLight)
                } footer: {
                    Text("Track flight duty period limits under FAR Part 117")
                        .foregroundColor(.gray)
                }
                
                if far117Enabled {
                    // Crew Configuration
                    Section {
                        Toggle("Augmented Crew Operations", isOn: $augmentedCrew)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentBlue)
                            .listRowBackground(LogbookTheme.navyLight)
                        
                        HStack {
                            Text("Acclimatized Base")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("ICAO", text: $acclimatizedBase)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(LogbookTheme.accentBlue)
                                .textInputAutocapitalization(.characters)
                                .frame(width: 80)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    } header: {
                        Text("Crew Configuration")
                            .foregroundColor(.white)
                    } footer: {
                        Text("Augmented crew allows extended flight duty periods")
                            .foregroundColor(.gray)
                    }
                    
                    // Warning Settings
                    Section {
                        Toggle("Show Limit Warnings", isOn: $showWarnings)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.warningYellow)
                            .listRowBackground(LogbookTheme.navyLight)
                        
                        if showWarnings {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Warning Threshold: \(Int(warningThreshold * 100))%")
                                    .foregroundColor(.white)
                                
                                Slider(value: $warningThreshold, in: 0.7...0.95, step: 0.05)
                                    .tint(LogbookTheme.warningYellow)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(LogbookTheme.navyLight)
                        }
                    } header: {
                        Text("Warning Settings")
                            .foregroundColor(.white)
                    }
                    
                    // Notifications
                    Section {
                        Toggle("Notify When Approaching Limit", isOn: $notifyApproaching)
                            .foregroundColor(.white)
                            .tint(LogbookTheme.accentOrange)
                            .listRowBackground(LogbookTheme.navyLight)
                        
                        Toggle("Notify When Rest Required", isOn: $notifyRestRequired)
                            .foregroundColor(.white)
                            .tint(.red)
                            .listRowBackground(LogbookTheme.navyLight)
                    } header: {
                        Text("Notifications")
                            .foregroundColor(.white)
                    }
                    
                    // FAR 117 Reference
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("FAR 117 Quick Reference")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            FAR117ReferenceRow(title: "Max FDP (2 segments)", value: "9-14 hrs", note: "Based on start time")
                            FAR117ReferenceRow(title: "Max Flight Time", value: "8-9 hrs", note: "Unaugmented")
                            FAR117ReferenceRow(title: "Max Flight Time", value: "13-17 hrs", note: "Augmented")
                            FAR117ReferenceRow(title: "Min Rest Period", value: "10 hrs", note: "8 hrs uninterrupted sleep")
                            FAR117ReferenceRow(title: "Weekly Limit", value: "60 hrs", note: "Flight time")
                            FAR117ReferenceRow(title: "28-Day Limit", value: "100 hrs", note: "Flight time")
                            FAR117ReferenceRow(title: "365-Day Limit", value: "1000 hrs", note: "Flight time")
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(LogbookTheme.navyLight)
                    } header: {
                        Text("Reference")
                            .foregroundColor(.white)
                    }
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("FAR 117 Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
}

struct FAR117ReferenceRow: View {
    let title: String
    let value: String
    let note: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(note)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(LogbookTheme.accentBlue)
        }
    }
}

#if DEBUG
struct FAR117SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FAR117SettingsView()
    }
}
#endif
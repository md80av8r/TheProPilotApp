//
//  AirlineConfigurationView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/16/25.
//


// AirlineConfigurationView.swift
// Consolidated airline settings - all in one place
import SwiftUI

struct AirlineConfigurationView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingQuickSetup = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Quick Setup Section
                Section(header: Text("Quick Setup").foregroundColor(.white)) {
                    Button(action: {
                        showingQuickSetup = true
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick Setup Wizard")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Configure for major airlines instantly")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Basic Information Section
                Section(header: Text("Basic Information").foregroundColor(.white)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Airline Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("USA Jet Airlines", text: $airlineSettings.settings.airlineName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Callsign")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("USA JET", text: $airlineSettings.settings.fleetCallsign)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Home Base Airport")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            TextField("ICAO Code", text: $airlineSettings.settings.homeBaseAirport)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.allCharacters)
                                .frame(width: 100)
                            
                            if !airlineSettings.settings.homeBaseAirport.isEmpty {
                                Text(airlineSettings.settings.homeBaseAirport)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Timer Settings Section
                Section(header: Text("Timer & Alarms").foregroundColor(.white)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Timer Alarms", isOn: $airlineSettings.settings.enableTimerAlarms)
                            .foregroundColor(.white)
                        
                        if airlineSettings.settings.enableTimerAlarms {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alarm Sound")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Picker("Sound", selection: $airlineSettings.settings.selectedAlarmSound) {
                                    ForEach(AlarmSound.allCases, id: \.self) { sound in
                                        Text(sound.displayName).tag(sound)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alarm Volume")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Slider(value: $airlineSettings.settings.alarmVolume, in: 0...1)
                                    .accentColor(LogbookTheme.accentBlue)
                            }
                        }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Company Email Section
                Section(header: Text("Company Email").foregroundColor(.white)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Company Email")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("ops@airline.com", text: $airlineSettings.settings.companyEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    Text("Used for crew scheduling, operations, and default email recipients")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Current Configuration Display
                if !airlineSettings.settings.airlineName.isEmpty {
                    Section(header: Text("Current Configuration").foregroundColor(.white)) {
                        VStack(alignment: .leading, spacing: 12) {
                            ConfigRowDisplay(
                                icon: "building.2.fill",
                                label: "Airline",
                                value: airlineSettings.settings.airlineName,
                                color: LogbookTheme.accentBlue
                            )
                            
                            if !airlineSettings.settings.fleetCallsign.isEmpty {
                                ConfigRowDisplay(
                                    icon: "antenna.radiowaves.left.and.right",
                                    label: "Callsign",
                                    value: airlineSettings.settings.fleetCallsign,
                                    color: LogbookTheme.accentGreen
                                )
                            }
                            
                            if !airlineSettings.settings.homeBaseAirport.isEmpty {
                                ConfigRowDisplay(
                                    icon: "house.fill",
                                    label: "Home Base",
                                    value: airlineSettings.settings.homeBaseAirport,
                                    color: LogbookTheme.accentOrange
                                )
                            }
                            
                            if airlineSettings.settings.enableTimerAlarms {
                                ConfigRowDisplay(
                                    icon: "alarm.fill",
                                    label: "Alarms",
                                    value: airlineSettings.settings.selectedAlarmSound.displayName,
                                    color: .purple
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Airline Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        airlineSettings.saveSettings()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .sheet(isPresented: $showingQuickSetup) {
                AirlineQuickSetupView(airlineSettings: airlineSettings)
            }
        }
    }
}

// MARK: - Configuration Row Display
struct ConfigRowDisplay: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
    }
}


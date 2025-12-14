// DutyLimitSettingsView.swift
// Comprehensive settings UI for flight time and duty limits
// Created for TheProPilotApp

import SwiftUI

struct DutyLimitSettingsView: View {
    @StateObject private var settingsStore = DutyLimitSettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPresetConfirmation = false
    @State private var pendingPreset: OperationType?
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Master Enable Section
                Section {
                    Toggle("Enable Duty Limit Tracking", isOn: $settingsStore.trackingEnabled)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentGreen)
                } footer: {
                    Text("Track flight time and duty period limits based on your operation type")
                        .foregroundColor(.gray)
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                if settingsStore.trackingEnabled {
                    // MARK: - Operation Type Selection
                    operationTypeSection
                    
                    // MARK: - Rolling Period Selection (Part 121/Custom only)
                    if settingsStore.configuration.operationType == .part121 ||
                       settingsStore.configuration.operationType == .custom {
                        rollingPeriodSection
                    }
                    
                    // MARK: - Per-FDP Flight Time Limits
                    if settingsStore.configuration.operationType != .part91 {
                        perFDPLimitsSection
                    }
                    
                    // MARK: - Cumulative Flight Time Limits
                    if settingsStore.configuration.operationType != .part91 {
                        cumulativeFlightTimeLimitsSection
                    }
                    
                    // MARK: - FDP Limits (Part 121 only)
                    if settingsStore.configuration.operationType == .part121 ||
                       settingsStore.configuration.operationType == .custom {
                        fdpLimitsSection
                    }
                    
                    // MARK: - Rest Requirements
                    if settingsStore.configuration.operationType != .part91 {
                        restRequirementsSection
                    }
                    
                    // MARK: - Warning Thresholds
                    warningThresholdsSection
                    
                    // MARK: - Display Options
                    displayOptionsSection
                    
                    // MARK: - Quick Reference
                    quickReferenceSection
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Flight Time Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .alert("Apply Preset?", isPresented: $showingPresetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Apply") {
                    if let preset = pendingPreset {
                        settingsStore.applyPreset(preset)
                    }
                }
            } message: {
                Text("This will replace your current settings with the \(pendingPreset?.rawValue ?? "") preset values.")
            }
        }
    }
    
    // MARK: - Operation Type Section
    private var operationTypeSection: some View {
        Section {
            ForEach(OperationType.allCases, id: \.self) { type in
                Button {
                    if type != settingsStore.configuration.operationType {
                        pendingPreset = type
                        showingPresetConfirmation = true
                    }
                } label: {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(settingsStore.configuration.operationType == type ? LogbookTheme.accentGreen : .gray)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if settingsStore.configuration.operationType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
        } header: {
            Text("Operation Type")
                .foregroundColor(.white)
        } footer: {
            Text("Select your operation type to apply standard regulatory limits, or choose Custom to set your own.")
                .foregroundColor(.gray)
        }
        .textCase(nil)
    }
    
    // MARK: - Rolling Period Section
    private var rollingPeriodSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rolling Period for Cumulative Limits")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Picker("Rolling Period", selection: Binding(
                    get: { settingsStore.configuration.rollingPeriodDays },
                    set: { settingsStore.setRollingPeriod($0) }
                )) {
                    Text("28 Days (FAR 117 Standard)").tag(28)
                    Text("30 Days (More Restrictive)").tag(30)
                    Text("31 Days (Calendar Month)").tag(31)
                }
                .pickerStyle(.segmented)
                
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text("Your company uses a \(settingsStore.configuration.rollingPeriodDays)-day rolling period. 30 days is more restrictive than the FAR 117 standard of 28 days (672 hours).")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Company Ops Specs")
                .foregroundColor(.white)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Per-FDP Flight Time Limits Section
    private var perFDPLimitsSection: some View {
        Section {
            Toggle("Track Per-FDP Flight Time", isOn: $settingsStore.configuration.perFDPFlightLimit.enabled)
                .foregroundColor(.white)
                .tint(LogbookTheme.accentGreen)
            
            if settingsStore.configuration.perFDPFlightLimit.enabled {
                VStack(alignment: .leading, spacing: 16) {
                    // Day Limit
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day Report Time (0500-1959)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text("Maximum flight time when reporting during day hours")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack {
                            TextField("9", value: $settingsStore.configuration.perFDPFlightLimit.dayHours, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("hrs")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Night Limit
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Night Report Time (2000-0459)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text("Maximum flight time when reporting during night hours")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack {
                            TextField("8", value: $settingsStore.configuration.perFDPFlightLimit.nightHours, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("hrs")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Reset after rest toggle
                    Toggle("Resets After Legal Rest Period", isOn: $settingsStore.configuration.perFDPFlightLimit.resetsAfterRest)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentBlue)
                    
                    if settingsStore.configuration.perFDPFlightLimit.resetsAfterRest {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("Per FAR 117, flight time limits are per-FDP and reset after receiving a legal rest period (10 hours with 8 hours sleep opportunity)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Per-Duty Period Flight Time")
                .foregroundColor(.white)
        } footer: {
            Text("FAR 117.11 - Flight time limits per flight duty period based on report time")
                .foregroundColor(.gray)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Cumulative Flight Time Limits Section
    private var cumulativeFlightTimeLimitsSection: some View {
        Section {
            // 7-Day Limit (Part 135)
            if settingsStore.configuration.operationType == .part135 ||
               settingsStore.configuration.operationType == .custom {
                LimitConfigRow(
                    title: "7-Day Flight Time",
                    subtitle: "Rolling 168 hours",
                    limit: $settingsStore.configuration.flightTime7Day,
                    defaultHours: 34
                )
            }
            
            // Rolling Period Limit
            LimitConfigRow(
                title: "\(settingsStore.configuration.rollingPeriodDays)-Day Flight Time",
                subtitle: "Rolling \(settingsStore.configuration.rollingPeriodDays * 24) hours",
                limit: Binding(
                    get: { settingsStore.configuration.flightTimeRolling },
                    set: { newValue in
                        var updated = newValue
                        updated.periodDays = settingsStore.configuration.rollingPeriodDays
                        settingsStore.configuration.flightTimeRolling = updated
                    }
                ),
                defaultHours: 100
            )
            
            // 365-Day Limit
            LimitConfigRow(
                title: "Annual Flight Time",
                subtitle: "Rolling 365 days",
                limit: $settingsStore.configuration.flightTime365Day,
                defaultHours: settingsStore.configuration.operationType == .part135 ? 1200 : 1000
            )
        } header: {
            Text("Cumulative Flight Time Limits")
                .foregroundColor(.white)
        } footer: {
            Text(settingsStore.configuration.operationType == .part121 ?
                 "FAR 117.23(b) - Cumulative flight time limitations" :
                 "FAR 135.267 - Flight time limitations")
                .foregroundColor(.gray)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - FDP Limits Section
    private var fdpLimitsSection: some View {
        Section {
            // 7-Day FDP
            FDPLimitConfigRow(
                title: "7-Day FDP",
                subtitle: "Rolling 168 hours",
                limit: $settingsStore.configuration.fdp7Day,
                defaultHours: 60
            )
            
            // Rolling Period FDP
            FDPLimitConfigRow(
                title: "\(settingsStore.configuration.rollingPeriodDays)-Day FDP",
                subtitle: "Rolling \(settingsStore.configuration.rollingPeriodDays * 24) hours",
                limit: Binding(
                    get: { settingsStore.configuration.fdpRolling },
                    set: { newValue in
                        var updated = newValue
                        updated.periodDays = settingsStore.configuration.rollingPeriodDays
                        settingsStore.configuration.fdpRolling = updated
                    }
                ),
                defaultHours: 190
            )
        } header: {
            Text("Cumulative FDP Limits")
                .foregroundColor(.white)
        } footer: {
            Text("FAR 117.23(c) - Flight duty period limitations")
                .foregroundColor(.gray)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Rest Requirements Section
    private var restRequirementsSection: some View {
        Section {
            Toggle("Track Rest Requirements", isOn: $settingsStore.configuration.restRequirement.enabled)
                .foregroundColor(.white)
                .tint(LogbookTheme.accentGreen)
            
            if settingsStore.configuration.restRequirement.enabled {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Minimum Rest Period")
                            .foregroundColor(.white)
                        Spacer()
                        HStack {
                            TextField("10", value: $settingsStore.configuration.restRequirement.minimumRestHours, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("hrs")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("Sleep Opportunity")
                            .foregroundColor(.white)
                        Spacer()
                        HStack {
                            TextField("8", value: $settingsStore.configuration.restRequirement.sleepOpportunityHours, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("hrs")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekly Rest Requirement")
                                .foregroundColor(.white)
                            Text("Consecutive hours free from duty in 7 days")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack {
                            TextField("30", value: $settingsStore.configuration.restRequirement.requiredInPeriodHours, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("hrs")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Rest Requirements")
                .foregroundColor(.white)
        } footer: {
            Text("FAR 117.25 - Required rest periods before duty")
                .foregroundColor(.gray)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Warning Thresholds Section
    private var warningThresholdsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                        Text("Warning Threshold")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(settingsStore.configuration.warningThresholdPercent * 100))%")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    
                    Slider(
                        value: $settingsStore.configuration.warningThresholdPercent,
                        in: 0.70...0.95,
                        step: 0.05
                    )
                    .tint(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Critical Threshold")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(settingsStore.configuration.criticalThresholdPercent * 100))%")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    
                    Slider(
                        value: $settingsStore.configuration.criticalThresholdPercent,
                        in: 0.85...1.0,
                        step: 0.05
                    )
                    .tint(.red)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Alert Thresholds")
                .foregroundColor(.white)
        } footer: {
            Text("Set when warnings appear as you approach your limits")
                .foregroundColor(.gray)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Display Options Section
    private var displayOptionsSection: some View {
        Section {
            Toggle("Show Warnings on Trip Rows", isOn: $settingsStore.showWarningsOnTripRows)
                .foregroundColor(.white)
                .tint(LogbookTheme.accentGreen)
            
            Toggle("Notify When Approaching Limits", isOn: $settingsStore.notifyApproachingLimits)
                .foregroundColor(.white)
                .tint(LogbookTheme.accentBlue)
        } header: {
            Text("Display & Notifications")
                .foregroundColor(.white)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Quick Reference Section
    private var quickReferenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Configuration Summary")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                if settingsStore.configuration.operationType == .part91 {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("No regulatory limits tracked for Part 91 operations")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ForEach(getActiveLimitsSummary(), id: \.title) { item in
                        QuickReferenceRow(
                            title: item.title,
                            value: item.value,
                            note: item.note
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Quick Reference")
                .foregroundColor(.white)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .textCase(nil)
    }
    
    // MARK: - Helper Methods
    
    private func getActiveLimitsSummary() -> [(title: String, value: String, note: String)] {
        var items: [(String, String, String)] = []
        let config = settingsStore.configuration
        
        if config.perFDPFlightLimit.enabled {
            items.append((
                "Per-FDP Flight Time",
                "\(Int(config.perFDPFlightLimit.dayHours))/\(Int(config.perFDPFlightLimit.nightHours)) hrs",
                "Day/Night"
            ))
        }
        
        if config.flightTime7Day.enabled {
            items.append((
                "7-Day Flight Time",
                "\(Int(config.flightTime7Day.hours)) hrs",
                "§135.267"
            ))
        }
        
        if config.flightTimeRolling.enabled {
            items.append((
                "\(config.rollingPeriodDays)-Day Flight Time",
                "\(Int(config.flightTimeRolling.hours)) hrs",
                config.operationType == .part121 ? "§117.23(b)" : "§135.267"
            ))
        }
        
        if config.flightTime365Day.enabled {
            items.append((
                "Annual Flight Time",
                "\(Int(config.flightTime365Day.hours)) hrs",
                "§117.23(b)"
            ))
        }
        
        if config.fdp7Day.enabled {
            items.append((
                "7-Day FDP",
                "\(Int(config.fdp7Day.hours)) hrs",
                "§117.23(c)"
            ))
        }
        
        if config.fdpRolling.enabled {
            items.append((
                "\(config.rollingPeriodDays)-Day FDP",
                "\(Int(config.fdpRolling.hours)) hrs",
                "§117.23(c)"
            ))
        }
        
        if config.restRequirement.enabled {
            items.append((
                "Min Rest Period",
                "\(Int(config.restRequirement.minimumRestHours)) hrs",
                "§117.25"
            ))
        }
        
        return items
    }
}

// MARK: - Supporting Views

struct LimitConfigRow: View {
    let title: String
    let subtitle: String
    @Binding var limit: FlightTimeLimit
    let defaultHours: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $limit.enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .tint(LogbookTheme.accentGreen)
            
            if limit.enabled {
                HStack {
                    Text("Limit")
                        .foregroundColor(.gray)
                    Spacer()
                    HStack {
                        TextField("\(Int(defaultHours))", value: $limit.hours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("hours")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FDPLimitConfigRow: View {
    let title: String
    let subtitle: String
    @Binding var limit: FDPLimit
    let defaultHours: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $limit.enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .tint(LogbookTheme.accentGreen)
            
            if limit.enabled {
                HStack {
                    Text("Limit")
                        .foregroundColor(.gray)
                    Spacer()
                    HStack {
                        TextField("\(Int(defaultHours))", value: $limit.hours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("hours")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickReferenceRow: View {
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

// MARK: - Preview

#if DEBUG
struct DutyLimitSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DutyLimitSettingsView()
    }
}
#endif

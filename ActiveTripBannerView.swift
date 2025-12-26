// ActiveTripBannerView.swift
// Complete working implementation with translucent modal using overlay
// Tap = fill current time, Long Press = show picker with Clear option
// ✅ FIXED: Uses Trip.activeLegIndex as single source of truth for leg advancement

import SwiftUI
import Foundation

// MARK: - Time Picker Configuration
struct TimePickerConfig {
    let type: String
    let initialTime: Date
    let onSet: (String, String) -> Void
}

struct ActiveTripBanner: View {
    let trip: Trip
    let onScanFuel: () -> Void
    let onScanDocument: (TripDocumentType) -> Void
    let onScanLogPage: () -> Void
    let onCompleteTrip: () -> Void
    let onEditTime: (String, String) -> Void
    let onAddLeg: () -> Void
    var onActivateTrip: (() -> Void)? = nil  // NEW: Optional callback for activating trip
    @Binding var dutyStartTime: Date?
    
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var autoTimeSettings = AutoTimeSettings.shared
    
    @State private var showingEndTripConfirmation = false
    @State private var showingDocumentPicker = false
    @State private var activeTimePickerConfig: TimePickerConfig? = nil

    // Returns current time string in HHmm respecting Zulu/Local setting
    private func currentTimeString() -> String {
        let now = Date()
        
        // Apply rounding if enabled
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(now, enabled: shouldRound)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        
        let timeString = formatter.string(from: roundedTime)
        
        // Log if rounding occurred
        if shouldRound {
            let originalString = formatter.string(from: now)
            if originalString != timeString {
                print("⏱️ Manual time rounded: \(originalString) → \(timeString)")
            }
        }
        
        return timeString
    }

    // Auto-fill logic moved to ContentView where we have accurate trip state
    
    // MARK: - Smart Leg Sequencing
    
    /// Helper to check if a leg has all 4 times filled
    private func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
        return !leg.outTime.isEmpty &&
               !leg.offTime.isEmpty &&
               !leg.onTime.isEmpty &&
               !leg.inTime.isEmpty
    }
    
    /// ✅ FIX: Single source of truth for current leg
    /// Returns the index from Trip.activeLegIndex - no duplication of logic
    /// When checkAndAdvanceLeg() updates the trip, SwiftUI automatically refreshes this
    private var currentLegIndex: Int? {
        return trip.activeLegIndex
    }
    
    private var allLegsComplete: Bool {
        // Check if all legs are either completed, skipped, or have all times filled
        for leg in trip.legs {
            // If leg is active/standby but doesn't have all times filled, not done yet
            if (leg.status == .active || leg.status == .standby) && !isLegFullyCompleted(leg) {
                return false
            }
        }
        
        // All legs are either completed, skipped, or have all times filled
        return !trip.legs.isEmpty
    }
    
    /// Check if there are upcoming legs AFTER excluding the current one (or first if planning)
    private var hasRemainingUpcomingLegs: Bool {
        let currentIdx = currentLegIndex
        
        for (index, leg) in trip.legs.enumerated() {
            // Skip if not standby
            guard leg.status == .standby else { continue }
            
            // Skip if this is the current leg (being shown in active section)
            if let currentIdx = currentIdx, index == currentIdx {
                continue
            }
            
            // If trip needs activation, skip the first leg (shown in planning section)
            if tripNeedsActivation && index == 0 {
                continue
            }
            
            // This is a true upcoming leg - it's standby and not the current/first one
            return true
        }
        
        return false
    }
    
    /// Check if trip needs activation (planning status with no active legs)
    private var tripNeedsActivation: Bool {
        // Trip must be in planning status
        guard trip.status == .planning else { return false }
        
        // No legs should be active yet
        let hasActiveLeg = trip.legs.contains { $0.status == .active }
        return !hasActiveLeg
    }
    
    var body: some View {
        ZStack {
            // Main banner content
            mainBannerContent
            
            // Translucent Time Picker Overlay
            if let config = activeTimePickerConfig {
                timePickerOverlay(config: config)
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentTypePicker { selectedType in
                onScanDocument(selectedType)
            }
        }
        .confirmationDialog(
            "End Trip #\(trip.tripNumber)?",
            isPresented: $showingEndTripConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Trip", role: .destructive) {
                onCompleteTrip()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to end Trip #\(trip.tripNumber)?\n\nOnce ended, you cannot reactivate this trip. Make sure all flight legs and times are correct.")
        }
    }
    
    // MARK: - Main Banner Content
    private var mainBannerContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Column Headers
                columnHeadersView
                
                // TAT Start
                if !trip.tatStart.isEmpty {
                    tatStartView
                }
                
                // Completed Legs (status == .completed OR all times filled)
                ForEach(Array(trip.legs.enumerated()), id: \.element.id) { index, leg in
                    if leg.status == .completed || isLegFullyCompleted(leg) {
                        completedLegRow(leg: leg, index: index)
                        
                        // Add divider after each completed leg
                        Divider()
                            .background(LogbookTheme.accentGreen.opacity(0.3))
                            .padding(.horizontal, 16)
                    }
                }
                
                // Current Leg (from trip.activeLegIndex) OR first leg if trip needs activation
                if let legIndex = currentLegIndex {
                    currentLegView(leg: trip.legs[legIndex], index: legIndex)
                    
                    // Add divider after current leg
                    Divider()
                        .background(LogbookTheme.accentGreen.opacity(0.5))
                        .padding(.horizontal, 16)
                } else if tripNeedsActivation, let firstLeg = trip.legs.first {
                    // Show first leg with activate button when trip is in planning status
                    planningLegView(leg: firstLeg, index: 0)
                    
                    // Add divider after planning leg
                    Divider()
                        .background(LogbookTheme.accentGreen.opacity(0.5))
                        .padding(.horizontal, 16)
                }
                
                // Standby legs info (if any AFTER excluding current or first)
                if hasRemainingUpcomingLegs {
                    standbyLegsInfoView
                }
                
                // Totals Section (below legs)
                if !trip.legs.isEmpty {
                    totalsView
                }
                
                // TAT End
                if !trip.formattedFinalTAT.isEmpty {
                    tatEndView
                }
                
                // Instructions
                instructionsView
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 16)
                
                // Scanner Functions
                scannerButtonsView
                
                // Action Buttons
                if allLegsComplete {
                    actionButtonsView
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.70)
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LogbookTheme.accentGreen.opacity(0.6),
                            LogbookTheme.accentBlue.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: LogbookTheme.accentBlue.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Time Picker Overlay
    private func timePickerOverlay(config: TimePickerConfig) -> some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.1)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        activeTimePickerConfig = nil
                    }
                }
                .transition(.opacity)
            
            // Time picker at the bottom
            VStack(spacing: 0) {
                Spacer()
                
                TranslucentTimePicker(
                    timeType: displayLabelForField(config.type),
                    initialTime: config.initialTime,
                    useZuluTime: AutoTimeSettings.shared.useZuluTime,
                    onTimeSet: { time in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HHmm"
                        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
                        let timeString = formatter.string(from: time)
                        config.onSet(config.type, timeString)
                        
                        print("⏱️ \(config.type) set via picker: \(timeString) (\(AutoTimeSettings.shared.useZuluTime ? "Zulu" : "Local"))")
                        
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    },
                    onClear: {
                        // Clear the time field by setting empty string
                        config.onSet(config.type, "")
                        
                        print("⏱️ \(config.type) cleared")
                        
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
    }
    
    // Helper to get display label from field name
    private func displayLabelForField(_ field: String) -> String {
        switch field {
        case "deadheadOutTime": return "OUT"
        case "deadheadInTime": return "IN"
        default: return field
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: trip.isDeadhead ? "airplane.circle.fill" : "airplane.departure")
                    .font(.title2)
                    .foregroundColor(trip.isDeadhead ? LogbookTheme.accentOrange : LogbookTheme.accentGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.isDeadhead ? "Deadhead #\(trip.tripNumber)" : "Trip #\(trip.tripNumber)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(formatTripDate())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Time zone indicator
            HStack(spacing: 4) {
                Image(systemName: AutoTimeSettings.shared.useZuluTime ? "globe" : "location.fill")
                    .font(.caption2)
                Text(AutoTimeSettings.shared.useZuluTime ? "ZULU" : "LOCAL")
                    .font(.caption.bold())
            }
            .foregroundColor(LogbookTheme.accentBlue.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Column Headers
    private var columnHeadersView: some View {
        HStack(spacing: 4) {
            ForEach(["OUT", "OFF", "ON", "IN"], id: \.self) { label in
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
            
            Text("FLT")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(width: 50)
            
            Text("BLK")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(width: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(LogbookTheme.fieldBackground.opacity(0.5))
    }
    
    // MARK: - Completed Leg Row
    private func completedLegRow(leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(leg.departure) → \(leg.arrival)")
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            HStack(spacing: 4) {
                Text(formatTime(leg.outTime))
                    .frame(maxWidth: .infinity)
                Text(formatTime(leg.offTime))
                    .frame(maxWidth: .infinity)
                Text(formatTime(leg.onTime))
                    .frame(maxWidth: .infinity)
                Text(formatTime(leg.inTime))
                    .frame(maxWidth: .infinity)
                Text(leg.formattedFlightTimeWithPlus)
                    .frame(width: 50)
                    .foregroundColor(LogbookTheme.accentGreen)
                Text(leg.formattedBlockTimeWithPlus)
                    .frame(width: 50)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            .font(.subheadline.monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Current Leg View
    private func currentLegView(leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                Label {
                    Text("\(leg.departure) → \(leg.arrival)")
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                } icon: {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                
                // FlightAware share button (only if OUT time exists)
                if !leg.outTime.isEmpty && !leg.flightNumber.isEmpty {
                    Button(action: {
                        shareFlightAwareLink(for: leg)
                    }) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 14))
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(6)
                            .background(LogbookTheme.fieldBackground)
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                statusBadge(for: leg)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            HStack(spacing: 4) {
                // Show different time fields for deadhead vs regular flights
                if leg.isDeadhead {
                    // Deadhead: Show OUT and IN only
                    ForEach([
                        ("OUT", leg.deadheadOutTime),
                        ("IN", leg.deadheadInTime)
                    ], id: \.0) { label, time in
                        InteractiveTimeCell(
                            label: label,
                            time: time,
                            onEdit: { fieldLabel, newTime in
                                // Map to deadhead fields
                                let deadheadField = fieldLabel == "OUT" ? "deadheadOutTime" : "deadheadInTime"
                                onEditTime(deadheadField, newTime)
                            },
                            onShowPicker: { initialTime in
                                withAnimation(.spring()) {
                                    activeTimePickerConfig = TimePickerConfig(
                                        type: label == "OUT" ? "deadheadOutTime" : "deadheadInTime",
                                        initialTime: initialTime,
                                        onSet: { fieldName, newTime in
                                            onEditTime(fieldName, newTime)
                                        }
                                    )
                                }
                            },
                            showLabel: false
                        )
                    }
                    
                    // Spacer to push block time to right
                    Spacer()
                } else {
                    // Regular flight: Show all four times - explicit to avoid closure capture issues
                    InteractiveTimeCell(
                        label: "OUT",
                        time: leg.outTime,
                        onEdit: { field, value in
                            onEditTime("OUT", value)
                        },
                        onShowPicker: { initialTime in
                            withAnimation(.spring()) {
                                activeTimePickerConfig = TimePickerConfig(
                                    type: "OUT",
                                    initialTime: initialTime,
                                    onSet: { field, value in
                                        onEditTime("OUT", value)
                                    }
                                )
                            }
                        },
                        showLabel: false
                    )
                    
                    InteractiveTimeCell(
                        label: "OFF",
                        time: leg.offTime,
                        onEdit: { field, value in
                            onEditTime("OFF", value)
                        },
                        onShowPicker: { initialTime in
                            withAnimation(.spring()) {
                                activeTimePickerConfig = TimePickerConfig(
                                    type: "OFF",
                                    initialTime: initialTime,
                                    onSet: { field, value in
                                        onEditTime("OFF", value)
                                    }
                                )
                            }
                        },
                        showLabel: false
                    )
                    
                    InteractiveTimeCell(
                        label: "ON",
                        time: leg.onTime,
                        onEdit: { field, value in
                            onEditTime("ON", value)
                        },
                        onShowPicker: { initialTime in
                            withAnimation(.spring()) {
                                activeTimePickerConfig = TimePickerConfig(
                                    type: "ON",
                                    initialTime: initialTime,
                                    onSet: { field, value in
                                        onEditTime("ON", value)
                                    }
                                )
                            }
                        },
                        showLabel: false
                    )
                    
                    InteractiveTimeCell(
                        label: "IN",
                        time: leg.inTime,
                        onEdit: { field, value in
                            onEditTime("IN", value)
                        },
                        onShowPicker: { initialTime in
                            withAnimation(.spring()) {
                                activeTimePickerConfig = TimePickerConfig(
                                    type: "IN",
                                    initialTime: initialTime,
                                    onSet: { field, value in
                                        onEditTime("IN", value)
                                    }
                                )
                            }
                        },
                        showLabel: false
                    )
                    
                    // Flight time only for regular flights
                    Text(leg.formattedFlightTimeWithPlus)
                        .frame(width: 50)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(leg.calculateFlightMinutes() > 0 ? LogbookTheme.accentGreen : .gray)
                }
                
                // Block time for both types
                Text(leg.formattedBlockTimeWithPlus)
                    .frame(width: 50)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(leg.blockMinutes() > 0 ? LogbookTheme.accentBlue : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            Divider()
                .background(LogbookTheme.accentGreen.opacity(0.5))
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Planning Leg View (first leg with activate button)
    private func planningLegView(leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                Label {
                    Text("\(leg.departure) → \(leg.arrival)")
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.accentOrange.opacity(0.8))
                } icon: {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                
                Spacer()
                
                // Activate Trip button
                Button(action: {
                    onActivateTrip?()
                }) {
                    Text("Activate Trip")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            LogbookTheme.accentGreen.opacity(0.8)
                        )
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Time row - show scheduled OUT/IN, empty OFF/ON
            HStack(spacing: 4) {
                // OUT (scheduled)
                VStack(spacing: 2) {
                    Text(formatTime(leg.outTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(leg.outTime.isEmpty ? .gray.opacity(0.5) : LogbookTheme.accentOrange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                // OFF (empty)
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(maxWidth: .infinity)
                
                // ON (empty)
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(maxWidth: .infinity)
                
                // IN (scheduled)
                VStack(spacing: 2) {
                    Text(formatTime(leg.inTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(leg.inTime.isEmpty ? .gray.opacity(0.5) : LogbookTheme.accentOrange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                // FLT placeholder
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(width: 50)
                
                // BLK placeholder
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(LogbookTheme.accentOrange.opacity(0.05))
    }
    
    // Helper function for status badge
    private func statusBadge(for leg: FlightLeg) -> some View {
        let (text, color): (String, Color)
        
        if leg.isDeadhead {
            // Deadhead status: Only check OUT and IN
            if leg.deadheadOutTime.isEmpty {
                (text, color) = ("Awaiting OUT", LogbookTheme.accentOrange)
            } else if leg.deadheadInTime.isEmpty {
                (text, color) = ("Awaiting IN", LogbookTheme.errorRed)
            } else {
                (text, color) = ("Complete", LogbookTheme.successGreen)
            }
        } else {
            // Regular flight status: Check all four times
            if leg.outTime.isEmpty {
                (text, color) = ("Awaiting OUT", LogbookTheme.accentOrange)
            } else if leg.offTime.isEmpty {
                (text, color) = ("Awaiting OFF", LogbookTheme.accentBlue)
            } else if leg.onTime.isEmpty {
                (text, color) = ("Awaiting ON", LogbookTheme.accentGreen)
            } else if leg.inTime.isEmpty {
                (text, color) = ("Awaiting IN", LogbookTheme.errorRed)
            } else {
                (text, color) = ("Complete", LogbookTheme.successGreen)
            }
        }
        
        return Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .cornerRadius(6)
    }
    
    // MARK: - Standby Legs Info View
    private var standbyLegsInfoView: some View {
        VStack(spacing: 0) {
            let standbyLegs = getStandbyLegs()
            
            // Header showing count
            HStack {
                Image(systemName: "clock.badge")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentOrange)
                
                Text("\(standbyLegs.count) upcoming leg\(standbyLegs.count == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentOrange)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(LogbookTheme.accentOrange.opacity(0.1))
            
            // Show each standby leg
            ForEach(Array(standbyLegs.indices), id: \.self) { i in
                let (actualIndex, leg) = standbyLegs[i]
                standbyLegRow(leg: leg, actualIndex: actualIndex)
                
                if i < standbyLegs.count - 1 {
                    Divider()
                        .background(LogbookTheme.accentOrange.opacity(0.2))
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Helper to get standby legs
    private func getStandbyLegs() -> [(Int, FlightLeg)] {
        let currentIdx = currentLegIndex
        var result: [(Int, FlightLeg)] = []
        
        for (index, leg) in trip.legs.enumerated() {
            // Must be standby status
            guard leg.status == .standby else { continue }
            
            // Exclude if this is the current leg (shown in active section)
            if let currentIdx = currentIdx, index == currentIdx {
                continue
            }
            
            // Exclude if this is the first leg and trip needs activation (shown in planning section)
            if tripNeedsActivation && index == 0 {
                continue
            }
            
            result.append((index, leg))
        }
        
        return result
    }
    
    // MARK: - Standby Leg Row (shows scheduled times, grayed out)
    private func standbyLegRow(leg: FlightLeg, actualIndex: Int) -> some View {
        VStack(spacing: 4) {
            // Route header with standby indicator
            HStack {
                // Deadhead indicator if applicable
                if leg.isDeadhead {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                
                Text("\(leg.departure) → \(leg.arrival)")
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.accentOrange.opacity(0.8))
                
                Spacer()
                
                // Regular standby badge
                Text("Standby")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            
            // Time row - show scheduled OUT/IN, empty OFF/ON
            HStack(spacing: 4) {
                // OUT (scheduled)
                VStack(spacing: 2) {
                    Text(formatTime(leg.outTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(leg.outTime.isEmpty ? .gray.opacity(0.5) : LogbookTheme.accentOrange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                // OFF (empty)
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(maxWidth: .infinity)
                
                // ON (empty)
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(maxWidth: .infinity)
                
                // IN (scheduled)
                VStack(spacing: 2) {
                    Text(formatTime(leg.inTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(leg.inTime.isEmpty ? .gray.opacity(0.5) : LogbookTheme.accentOrange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                // FLT placeholder
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(width: 50)
                
                // BLK placeholder
                Text("--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray.opacity(0.4))
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .background(LogbookTheme.accentOrange.opacity(0.05))
    }
    
    // MARK: - TAT Views
    private var tatStartView: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Text("TAT Start:")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Text(trip.formattedTATStart)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(LogbookTheme.accentGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var tatEndView: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Text("TAT End:")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Text(trip.formattedFinalTAT)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(LogbookTheme.errorRed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // MARK: - Totals View
    private var totalsView: some View {
        let totalFlight = trip.legs.reduce(0) { $0 + $1.calculateFlightMinutes() }
        let totalBlock = trip.legs.reduce(0) { $0 + $1.blockMinutes() }
        
        return HStack {
            Spacer()
            
            if !trip.isDeadhead {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Flight")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatDuration(totalFlight))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                .padding(.trailing, 16)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Block")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(formatDuration(totalBlock))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(LogbookTheme.accentBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Instructions View
    private var instructionsView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "hand.tap.fill")
                    .font(.caption2)
                Text("Tap time = fill current")
                    .font(.caption2)
                Text("•")
                    .font(.caption2)
                Image(systemName: "hand.tap")
                    .font(.caption2)
                Text("Hold = pick time")
                    .font(.caption2)
            }
            .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Activate Trip Button
    private var activateTripButton: some View {
        Button(action: {
            onActivateTrip?()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activate Trip")
                        .font(.headline.bold())
                    Text("Start flying \(trip.legs.first?.departure ?? "") → \(trip.legs.first?.arrival ?? "")")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        LogbookTheme.accentGreen,
                        LogbookTheme.accentGreen.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Scanner Buttons View
    private var scannerButtonsView: some View {
        HStack(spacing: 8) {
            // Fuel button only for non-deadhead trips
            if !trip.isDeadhead {
                Button(action: onScanFuel) {
                    HStack(spacing: 6) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 14))
                        Text("Fuel")
                            .font(.caption.bold())
                    }
                    .foregroundColor(LogbookTheme.warningYellow)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LogbookTheme.warningYellow.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Docs button for all trip types
            Button(action: { showingDocumentPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 14))
                    Text(trip.isDeadhead ? "Scan Receipt" : "Docs")
                        .font(.caption.bold())
                }
                .foregroundColor(LogbookTheme.accentBlue)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                )
            }
            .frame(maxWidth: trip.isDeadhead ? .infinity : nil)
            
            // Only show Log Page for non-deadhead trips
            if !trip.isDeadhead {
                Button(action: onScanLogPage) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 14))
                        Text("Log Page")
                            .font(.caption.bold())
                    }
                    .foregroundColor(LogbookTheme.accentOrange)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LogbookTheme.accentOrange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Only show Add Leg for non-deadhead trips
            if !trip.isDeadhead {
                Button(action: onAddLeg) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Leg")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(8)
                }
                .accessibilityIdentifier("addNextLegButton")
            }
            
            // Share Trip button
            ShareTripButton(trip: trip, style: .custom)
            
            // End Trip button for all trip types
            Button(action: { showingEndTripConfirmation = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text(trip.isDeadhead ? "End Deadhead" : "End Trip")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LogbookTheme.accentGreen)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Helper Functions
    private func generateFlightAwareURL(for leg: FlightLeg) -> String? {
        guard !leg.flightNumber.isEmpty,
              !leg.departure.isEmpty,
              !leg.arrival.isEmpty,
              !leg.outTime.isEmpty else {
            return nil
        }
        
        // Format date as YYYYMMDD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateString = dateFormatter.string(from: trip.date)
        
        // Use OUT time (already in HHmm format) + Z
        let timeString = leg.outTime + "Z"
        
        // Build URL
        let urlString = "https://www.flightaware.com/live/flight/\(leg.flightNumber)/history/\(dateString)/\(timeString)/\(leg.departure)/\(leg.arrival)"
        
        return urlString
    }
    
    private func shareFlightAwareLink(for leg: FlightLeg) {
        guard let urlString = generateFlightAwareURL(for: leg),
              URL(string: urlString) != nil else {
            print("❌ Unable to generate FlightAware URL")
            return
        }
        
        // Copy to clipboard
        UIPasteboard.general.string = urlString
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Open share sheet
        let message = "Track my flight \(leg.flightNumber): \(leg.departure) → \(leg.arrival)\n\n\(urlString)"
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
        
        print("✈️ FlightAware link shared: \(urlString)")
    }
    
    private func formatTripDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(abbreviation: "UTC") : TimeZone.current
        let dateStr = formatter.string(from: trip.date)
        let suffix = AutoTimeSettings.shared.useZuluTime ? " (UTC)" : ""
        return dateStr + suffix
    }
    
    private func formatTime(_ time: String) -> String {
        if time.isEmpty {
            return "----"
        }
        if time.count == 4 {
            let hours = String(time.prefix(2))
            let minutes = String(time.suffix(2))
            return "\(hours):\(minutes)"
        }
        return time
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes == 0 {
            return "0:00"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - Interactive Time Cell
/// Tap = fill with current time (Zulu/Local based on settings)
/// Long Press = open time picker with Clear option
struct InteractiveTimeCell: View {
    let label: String
    let time: String
    let onEdit: (String, String) -> Void
    let onShowPicker: (Date) -> Void
    var showLabel: Bool = true
    
    @State private var justTapped = false
    
    var body: some View {
        VStack(spacing: 4) {
            if showLabel {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(time.isEmpty ? .gray : LogbookTheme.accentBlue)
            }
            Text(displayTime)
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundColor(time.isEmpty ? .gray.opacity(0.7) : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, showLabel ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(time.isEmpty ? LogbookTheme.fieldBackground.opacity(0.5) : LogbookTheme.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            justTapped ? LogbookTheme.accentGreen :
                                time.isEmpty ? Color.gray.opacity(0.3) : LogbookTheme.accentBlue.opacity(0.5),
                            lineWidth: justTapped ? 2.5 : 1.5
                        )
                )
                .shadow(
                    color: justTapped ? LogbookTheme.accentGreen.opacity(0.3) : Color.clear,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            handleLongPress()
        }
    }
    
    private var displayTime: String {
        if time.isEmpty {
            return "--:--"
        }
        if time.count == 4 {
            let hours = String(time.prefix(2))
            let minutes = String(time.suffix(2))
            return "\(hours):\(minutes)"
        }
        return time
    }
    
    private func handleTap() {
        // Fill with current time directly (respects Zulu/Local setting)
        let currentTime = Date()
        
        // Apply rounding if enabled
        let shouldRound = AutoTimeSettings.shared.roundTimesToFiveMinutes
        let roundedTime = TimeRoundingUtility.roundToNearestFiveMinutes(currentTime, enabled: shouldRound)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        let timeString = formatter.string(from: roundedTime)
        
        // Log if rounding occurred
        if shouldRound {
            let originalString = formatter.string(from: currentTime)
            if originalString != timeString {
                print("⏱️ \(label) time rounded: \(originalString) → \(timeString)")
            }
        }
        
        // Send the actual time string, not "NOW"
        onEdit(label, timeString)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            justTapped = true
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                justTapped = false
            }
        }
        
        print("⏱️ \(label) tapped - filled with current \(AutoTimeSettings.shared.useZuluTime ? "Zulu" : "Local") time: \(timeString)")
    }
    
    private func handleLongPress() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        let initialTime = parseTimeToDate() ?? Date()
        onShowPicker(initialTime)
        
        print("⏱️ \(label) long-pressed - opening picker")
    }
    
    private func parseTimeToDate() -> Date? {
        guard time.count == 4 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = AutoTimeSettings.shared.useZuluTime ? TimeZone(identifier: "UTC") : TimeZone.current
        return formatter.date(from: time)
    }
}

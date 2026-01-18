// ActiveTripBannerView.swift
// Complete working implementation with translucent modal using overlay
// Tap = fill current time, Long Press = show picker with Clear option
// ✅ FIXED: Uses Trip.activeLegIndex as single source of truth for leg advancement

import SwiftUI
import Foundation

// MARK: - Route Display with Flow Delay Indicator
struct RouteDisplayWithFlowStatus: View {
    let departure: String
    let arrival: String
    let textColor: Color
    let iconColor: Color?
    let showIcon: Bool

    @State private var arrivalHasDelay = false
    @State private var arrivalFlowStatus: AirportFlowStatus?

    init(departure: String, arrival: String, textColor: Color, iconColor: Color? = nil, showIcon: Bool = false) {
        self.departure = departure
        self.arrival = arrival
        self.textColor = textColor
        self.iconColor = iconColor
        self.showIcon = showIcon
    }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon, let iconColor = iconColor {
                Image(systemName: "airplane")
                    .font(.caption)
                    .foregroundColor(iconColor)
            }

            Text(departure)
                .font(.subheadline.bold())
                .foregroundColor(textColor)

            Text("→")
                .font(.subheadline.bold())
                .foregroundColor(textColor.opacity(0.7))

            // Arrival with flow delay indicator
            HStack(spacing: 3) {
                Text(arrival)
                    .font(.subheadline.bold())
                    .foregroundColor(arrivalHasDelay ? delayColor : textColor)

                if arrivalHasDelay {
                    flowDelayBadge
                }
            }
        }
        .task {
            await checkFlowStatus()
        }
    }

    private var delayColor: Color {
        guard let status = arrivalFlowStatus else { return textColor }
        if status.closure != nil { return .purple }
        if status.groundStop != nil { return .red }
        if status.groundDelayProgram != nil { return .orange }
        return textColor
    }

    @ViewBuilder
    private var flowDelayBadge: some View {
        if let status = arrivalFlowStatus {
            if status.closure != nil {
                // Airport closed
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
            } else if status.groundStop != nil {
                // Ground stop
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            } else if let gdp = status.groundDelayProgram {
                // GDP - show delay time
                HStack(spacing: 2) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 9))
                    if let mins = gdp.averageMinutes {
                        Text("\(mins)m")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
            }
        }
    }

    private func checkFlowStatus() async {
        do {
            let status = try await NASStatusService.shared.getAirportStatus(for: arrival)
            await MainActor.run {
                arrivalFlowStatus = status
                arrivalHasDelay = status.hasAnyDelay
                print("✈️ Flow check for \(arrival): hasDelay=\(status.hasAnyDelay), GDP=\(status.groundDelayProgram?.averageDelay ?? "none")")
            }
        } catch {
            print("⚠️ Flow check failed for \(arrival): \(error)")
        }
    }
}

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
    let onToggleGroundOps: (() -> Void)?  // NEW: Callback for toggling ground ops mode
    var onActivateTrip: (() -> Void)? = nil  // NEW: Optional callback for activating trip
    var onAddTaxiLeg: ((Int, String) -> Void)? = nil  // NEW: Callback for adding taxi leg (afterIndex, airport)
    var onEditTrip: (() -> Void)? = nil  // NEW: Callback for opening DataEntry to edit trip
    @Binding var dutyStartTime: Date?

    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var autoTimeSettings = AutoTimeSettings.shared
    @ObservedObject var dutyTimerManager = DutyTimerManager.shared
    
    @State private var showingEndTripConfirmation = false
    @State private var showingDocumentPicker = false
    @State private var activeTimePickerConfig: TimePickerConfig? = nil
    @State private var showingTaxiPlacementPicker = false
    @State private var taxiButtonActive = false  // Toggle state for taxi button
    @State private var isCollapsed = false  // Collapse/expand state for banner

    // FlightAware data
    @State private var flightAwareData: [String: FAFlightCache] = [:]
    @State private var isLoadingFlightAware = false

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
    
    /// Helper to check if a leg has all required times filled
    private func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
        if leg.isGroundOperationsOnly {
            // Ground ops only needs OUT and IN
            return !leg.outTime.isEmpty && !leg.inTime.isEmpty
        } else if leg.isDeadhead {
            // Deadhead needs deadhead OUT and IN
            return !leg.deadheadOutTime.isEmpty && !leg.deadheadInTime.isEmpty
        } else {
            // Regular flight needs all 4 times
            return !leg.outTime.isEmpty &&
                   !leg.offTime.isEmpty &&
                   !leg.onTime.isEmpty &&
                   !leg.inTime.isEmpty
        }
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
                .zIndex(0)  // Ensure main content is behind overlay

            // Translucent Time Picker Overlay
            if let config = activeTimePickerConfig {
                timePickerOverlay(config: config)
                    .zIndex(1)  // Ensure overlay is in front
                    .transition(.opacity)
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
        .confirmationDialog(
            "Insert Taxi Leg",
            isPresented: $showingTaxiPlacementPicker,
            titleVisibility: .visible
        ) {
            // Option to insert BEFORE the first leg
            if !trip.legs.isEmpty {
                Button("Before Leg 1: \(trip.legs[0].departure) → \(trip.legs[0].arrival)") {
                    insertTaxiLeg(beforeIndex: 0)
                }
            }

            // Options to insert AFTER each leg
            ForEach(Array(trip.legs.enumerated()), id: \.element.id) { index, leg in
                Button("After Leg \(index + 1): \(leg.departure) → \(leg.arrival)") {
                    insertTaxiLeg(afterIndex: index)
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Where would you like to insert the taxi leg?")
        }
        .onAppear {
            loadFlightAwareData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flightAwareDataUpdated)) { notification in
            if let tripId = notification.userInfo?["tripId"] as? String,
               tripId == trip.id.uuidString,
               let data = notification.userInfo?["flightData"] as? [String: FAFlightCache] {
                flightAwareData = data
            }
        }
    }

    // MARK: - FlightAware Data Loading

    private func loadFlightAwareData() {
        guard FlightAwareRepository.shared.isReady,
              airlineSettings.settings.enableFlightAwareTracking else {
            return
        }

        let prefix = airlineSettings.settings.flightNumberPrefix
        guard !prefix.isEmpty else { return }

        isLoadingFlightAware = true

        Task {
            let results = await FlightAwareRepository.shared.lookupFlightsForTrip(trip, airlinePrefix: prefix)
            await MainActor.run {
                flightAwareData = results
                isLoadingFlightAware = false
            }
        }
    }

    // MARK: - FlightAware Info View

    private func flightAwareInfoView(_ data: FAFlightCache) -> some View {
        VStack(spacing: 6) {
            // Route string
            if let route = data.route, !route.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)

                    Text(route)
                        .font(.caption.monospaced())
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
            }

            HStack(spacing: 12) {
                // Gate info
                if let gates = data.gateDisplay {
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text(gates)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }

                // ETA
                if let eta = data.etaDisplay {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.accentOrange)
                        Text("ETA: \(eta)")
                            .font(.caption.bold())
                            .foregroundColor(.white)

                        // Time remaining
                        if let remaining = data.timeToArrival {
                            let hours = Int(remaining / 3600)
                            let mins = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
                            Text("(\(hours)h \(mins)m)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Status badge
                if let status = data.status {
                    Text(status)
                        .font(.caption2.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 2)
                        .background(statusColor(for: status).opacity(0.3))
                        .foregroundColor(statusColor(for: status))
                        .cornerRadius(4)
                }
            }
        } //ACTIVE TRIP BANNER PADDING
        .padding(.horizontal, 8)   // Reduced from 12 to 8
        .padding(.vertical, 4)     // Reduced from 6 to 4
        .background(LogbookTheme.navyLight.opacity(0.5))
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "scheduled": return .blue
        case "en route", "in flight", "active": return LogbookTheme.accentGreen
        case "landed": return .cyan
        case "arrived": return LogbookTheme.accentGreen
        case "delayed": return .orange
        case "cancelled": return .red
        case "diverted": return .purple
        default: return .gray
        }
    }

    // MARK: - Main Banner Content
    private var mainBannerContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header (always visible)
                headerView

                // Content (collapsible)
                if !isCollapsed {
                    // Prominent Duty Timer Display (if on duty)
                    if dutyTimerManager.isOnDuty {
                        prominentDutyTimerView
                    }

                    // FlightAware Route/ETA Info (if available)
                    if let currentLegIdx = currentLegIndex ?? (tripNeedsActivation ? 0 : nil),
                       currentLegIdx < trip.legs.count {
                        let currentLeg = trip.legs[currentLegIdx]
                        if let faData = flightAwareData[currentLeg.id.uuidString] {
                            flightAwareInfoView(faData)
                        }
                    }

                    // Add Taxi button + TAT Start (combined row)
                    taxiButtonAndTatStartView

                // Column Headers
                columnHeadersView
                
                // Completed Legs (status == .completed OR all times filled)
                // IMPORTANT: Exclude the current active leg - it's shown separately below
                ForEach(Array(trip.legs.enumerated()), id: \.element.id) { index, leg in
                    // Only show if: (completed OR fully filled) AND NOT the current active leg
                    let isCurrentLeg = currentLegIndex == index
                    let shouldShow = (leg.status == .completed || isLegFullyCompleted(leg)) && !isCurrentLeg

                    if shouldShow {
                        completedLegRow(leg: leg, index: index)

                        // Add divider after each completed leg
                        Divider()
                            .background(LogbookTheme.accentGreen.opacity(0.3))
                            .padding(.horizontal, 6)  // Reduced from 10
                    }
                }
                
                // Current Leg (from trip.activeLegIndex) OR first leg if trip needs activation
                if let legIndex = currentLegIndex {
                    let leg = trip.legs[legIndex]
                    // If leg has all times filled, show as completed (non-interactive)
                    // This handles the case where Watch created a new leg but old leg wasn't marked complete
                    if isLegFullyCompleted(leg) {
                        completedLegRow(leg: leg, index: legIndex)
                    } else {
                        currentLegView(leg: leg, index: legIndex)
                    }

                    // Add divider after current leg
                    Divider()
                        .background(LogbookTheme.accentGreen.opacity(0.5))
                        .padding(.horizontal, 6)  // Reduced from 10
                } else if tripNeedsActivation, let firstLeg = trip.legs.first {
                    // Show first leg with activate button when trip is in planning status
                    planningLegView(leg: firstLeg, index: 0)
                    
                    // Add divider after planning leg
                    Divider()
                        .background(LogbookTheme.accentGreen.opacity(0.5))
                        .padding(.horizontal, 6)  // Reduced from 10
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
                    .padding(.horizontal, 6)  // Reduced from 10
                
                    // Scanner Functions
                    scannerButtonsView

                    // Action Buttons
                    if allLegsComplete {
                        actionButtonsView
                    }
                }  // End of !isCollapsed
            }
        }
        .padding(.horizontal, 4)  // Reduced to 4 for minimal padding
        .padding(.vertical, 4)    // Reduced to 4 for minimal padding
        .frame(minHeight: 0, maxHeight: UIScreen.main.bounds.height * 0.70)  // Flexible height, max 70%
        .fixedSize(horizontal: false, vertical: true)  // Allow content to size itself vertically
        .background(
            // Darker, more opaque background for better contrast
            LogbookTheme.navy.opacity(0.95)
        )
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
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Time Picker Overlay
    private func timePickerOverlay(config: TimePickerConfig) -> some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.1)
                .ignoresSafeArea()
                .allowsHitTesting(true)  // Only intercept hits when visible
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
                        print("⏱️ \(config.type) cleared - dismissing picker first")

                        // IMPORTANT: Dismiss picker FIRST to prevent UI blocking
                        withAnimation(.spring()) {
                            activeTimePickerConfig = nil
                        }

                        // Then clear the time field after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            config.onSet(config.type, "")
                            print("⏱️ \(config.type) time cleared")
                        }
                    }
                )
                .padding(.horizontal, 6)  // Reduced from 10
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

            // Time zone toggle button (Zulu/Local)
            Button(action: {
                AutoTimeSettings.shared.useZuluTime.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: AutoTimeSettings.shared.useZuluTime ? "globe" : "clock")
                        .font(.caption)
                    Text(AutoTimeSettings.shared.useZuluTime ? "UTC" : "Local")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AutoTimeSettings.shared.useZuluTime ? Color.cyan.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(AutoTimeSettings.shared.useZuluTime ? .cyan : .orange)
                .cornerRadius(8)
            }

            // Collapse/Expand button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isCollapsed.toggle()
                }
            }) {
                Image(systemName: isCollapsed ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
        }
        .padding(.horizontal, 8)   // Reduced from 10 to 8
        .padding(.vertical, 8)
    }

    // MARK: - Prominent Duty Timer Display
    private var prominentDutyTimerView: some View {
        HStack(spacing: 8) {
            // Status indicator dot
            Circle()
                .fill(dutyTimerManager.dutyStatus().color)
                .frame(width: 8, height: 8)

            // ON DUTY label
            Text("ON DUTY")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Elapsed time (compact but visible)
            Text(dutyTimerManager.formattedElapsedTime())
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(dutyTimerManager.dutyStatus().color)

            // Time remaining (compact)
            let remaining = dutyTimerManager.timeRemaining()
            let hours = Int(remaining) / 3600
            let minutes = Int(remaining) / 60 % 60
            Text("(\(hours)h \(minutes)m)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(dutyTimerManager.dutyStatus().color.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(dutyTimerManager.dutyStatus().color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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
        .padding(.horizontal, 8)   // Reduced from 10 to 8
        .padding(.vertical, 4)     // Reduced from 6 to 4
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.top, 6)          // Reduced from 8
            
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.bottom, 6)       // Reduced from 8
        }
    }
    
    // MARK: - Current Leg View
    private func currentLegView(leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                // Route display with flow delay indicator
                RouteDisplayWithFlowStatus(
                    departure: leg.departure,
                    arrival: leg.arrival,
                    textColor: LogbookTheme.accentBlue,
                    iconColor: LogbookTheme.accentGreen,
                    showIcon: true
                )

                // Ground Operations Toggle (simple icon button)
                if let onToggleGroundOps = onToggleGroundOps {
                    Button(action: onToggleGroundOps) {
                        Image(systemName: leg.isGroundOperationsOnly ? "airplane.fill" : "airplane")
                            .font(.system(size: 14))
                            .foregroundColor(leg.isGroundOperationsOnly ? LogbookTheme.accentOrange : LogbookTheme.textTertiary)
                    }
                }

                // FlightAware share button (only if OUT time exists and has flight/trip number OR aircraft N-number)
                let hasFlightIdentifier = !leg.flightNumber.isEmpty || !trip.tripNumber.isEmpty || !trip.aircraft.isEmpty
                if !leg.outTime.isEmpty && hasFlightIdentifier {
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.top, 6)          // Reduced from 8
            
            HStack(spacing: 4) {
                // Show different time fields based on leg type
                if leg.isGroundOperationsOnly {
                    // Ground ops: Show OUT and IN interactive, OFF/ON grayed out
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

                    // OFF - disabled/grayed
                    Text("--:--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    // ON - disabled/grayed
                    Text("--:--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

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

                    // Flight time shows 0:00 for ground ops
                    Text("0:00")
                        .frame(width: 50)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.gray.opacity(0.5))

                } else if leg.isDeadhead {
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.bottom, 6)       // Reduced from 8
            
            Divider()
                .background(LogbookTheme.accentGreen.opacity(0.5))
                .padding(.horizontal, 6)  // Reduced from 10
        }
    }
    
    // MARK: - Planning Leg View (first leg with activate button)
    private func planningLegView(leg: FlightLeg, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                // Route display with flow delay indicator
                RouteDisplayWithFlowStatus(
                    departure: leg.departure,
                    arrival: leg.arrival,
                    textColor: LogbookTheme.accentOrange.opacity(0.8),
                    iconColor: LogbookTheme.accentOrange,
                    showIcon: true
                )

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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.top, 6)          // Reduced from 8
            
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.bottom, 6)       // Reduced from 8
        }
        .background(LogbookTheme.accentOrange.opacity(0.05))
    }
    
    // Helper function for status badge
    private func statusBadge(for leg: FlightLeg) -> some View {
        let (text, color): (String, Color)

        if leg.isGroundOperationsOnly {
            // Ground ops status: Only check OUT and IN
            if leg.outTime.isEmpty {
                (text, color) = ("Awaiting OUT", LogbookTheme.accentOrange)
            } else if leg.inTime.isEmpty {
                (text, color) = ("Awaiting IN", LogbookTheme.errorRed)
            } else {
                (text, color) = ("Complete", LogbookTheme.successGreen)
            }
        } else if leg.isDeadhead {
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.vertical, 4)     // Reduced from 6
            .background(LogbookTheme.accentOrange.opacity(0.1))
            
            // Show each standby leg
            ForEach(Array(standbyLegs.indices), id: \.self) { i in
                let (actualIndex, leg) = standbyLegs[i]
                standbyLegRow(leg: leg, actualIndex: actualIndex)
                
                if i < standbyLegs.count - 1 {
                    Divider()
                        .background(LogbookTheme.accentOrange.opacity(0.2))
                        .padding(.horizontal, 6)  // Reduced from 10
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
                // Route display with flow delay indicator
                RouteDisplayWithFlowStatus(
                    departure: leg.departure,
                    arrival: leg.arrival,
                    textColor: LogbookTheme.accentOrange.opacity(0.8),
                    iconColor: leg.isDeadhead ? LogbookTheme.accentOrange : nil,
                    showIcon: leg.isDeadhead
                )

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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.top, 4)          // Reduced from 6
            
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
            .padding(.horizontal, 6)  // Reduced from 10
            .padding(.bottom, 4)       // Reduced from 6
        }
        .background(LogbookTheme.accentOrange.opacity(0.05))
    }
    
    // MARK: - TAT Views
    // Combined view: Add Taxi button (left) + TAT Start (right)
    private var taxiButtonAndTatStartView: some View {
        HStack {
            // Add Taxi button on the left (toggle: tap to activate, tap again to cancel)
            Button(action: {
                if taxiButtonActive {
                    // Second tap: Cancel
                    taxiButtonActive = false
                } else {
                    // First tap: Activate
                    taxiButtonActive = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: taxiButtonActive ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 12))
                    Text(taxiButtonActive ? "Tap to Confirm" : "Taxi")
                        .font(.caption.bold())
                }
                .foregroundColor(taxiButtonActive ? .green : LogbookTheme.accentOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((taxiButtonActive ? Color.green : LogbookTheme.accentOrange).opacity(0.2))
                .cornerRadius(6)
            }

            // Show placement picker when confirmed
            if taxiButtonActive {
                Button(action: {
                    showingTaxiPlacementPicker = true
                    taxiButtonActive = false  // Reset after opening picker
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                        Text("Insert")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
                }
            }

            Spacer()

            // TAT Start on the right
            if !trip.tatStart.isEmpty {
                HStack(spacing: 4) {
                    Text("TAT Start:")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Text(trip.formattedTATStart)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.vertical, 4)
    }

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
        .padding(.horizontal, 6)  // Reduced from 10
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
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.vertical, 4)
    }
    
    // MARK: - Totals View
    private var totalsView: some View {
        let totalFlight = trip.legs.reduce(0) { $0 + $1.calculateFlightMinutes() }
        let totalBlock = trip.legs.reduce(0) { $0 + $1.blockMinutes() }

        return HStack {
            // Night time (if any) - left side
            if !trip.isDeadhead {
                NightTimeTotalView(legs: trip.legs, tripDate: trip.date)
            }

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
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.vertical, 6)     // Reduced from 8
    }

    // MARK: - Night Time Total View (async loading)
    struct NightTimeTotalView: View {
        let legs: [FlightLeg]
        let tripDate: Date

        @State private var totalNightMinutes: Int = 0
        @State private var isLoading = true

        var body: some View {
            Group {
                if totalNightMinutes > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.stars.fill")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Night")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentOrange)
                        }
                        Text(formatNightDuration(totalNightMinutes))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundColor(LogbookTheme.accentOrange)
                    }
                } else if isLoading {
                    // Optional: show loading indicator
                    EmptyView()
                }
            }
            .task {
                await loadNightMinutes()
            }
        }

        private func loadNightMinutes() async {
            var total = 0

            for leg in legs {
                // Use trip date as base, leg may have its own flightDate
                let legDate = leg.flightDate ?? tripDate
                let nightMins = await leg.nightMinutes(flightDate: legDate)
                total += nightMins
            }

            await MainActor.run {
                totalNightMinutes = total
                isLoading = false
            }
        }

        private func formatNightDuration(_ minutes: Int) -> String {
            if minutes == 0 { return "0:00" }
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d", hours, mins)
        }
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
            .padding(.horizontal, 10)  // Reduced from 12
            .padding(.vertical, 12)     // Reduced from 14
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
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.vertical, 6)     // Reduced from 8
    }
    
    // MARK: - Scanner Buttons View
    private var scannerButtonsView: some View {
        HStack(spacing: 8) {
            // Edit Trip button (pencil icon)
            Button(action: {
                onEditTrip?()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 14))
                    Text("Edit")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }

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
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.vertical, 6)     // Reduced from 8
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
        .padding(.horizontal, 6)  // Reduced from 10
        .padding(.bottom, 10)      // Reduced from 12
    }
    
    // MARK: - Helper Functions
    private func generateFlightAwareURL(for leg: FlightLeg) -> String? {
        // Priority: leg flight number > trip number > aircraft N-number (for Part 91)
        var flightIdentifier = ""
        if !leg.flightNumber.isEmpty {
            flightIdentifier = leg.flightNumber
        } else if !trip.tripNumber.isEmpty {
            flightIdentifier = trip.tripNumber
        } else if !trip.aircraft.isEmpty {
            flightIdentifier = trip.aircraft  // Part 91: Use N-number
        }

        guard !flightIdentifier.isEmpty,
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
        let urlString = "https://www.flightaware.com/live/flight/\(flightIdentifier)/history/\(dateString)/\(timeString)/\(leg.departure)/\(leg.arrival)"

        return urlString
    }
    
    private func shareFlightAwareLink(for leg: FlightLeg) {
        guard let urlString = generateFlightAwareURL(for: leg),
              URL(string: urlString) != nil else {
            print("❌ Unable to generate FlightAware URL")
            return
        }

        // Priority: leg flight number > trip number > aircraft N-number (for Part 91)
        var flightIdentifier = ""
        if !leg.flightNumber.isEmpty {
            flightIdentifier = leg.flightNumber
        } else if !trip.tripNumber.isEmpty {
            flightIdentifier = trip.tripNumber
        } else if !trip.aircraft.isEmpty {
            flightIdentifier = trip.aircraft  // Part 91: Use N-number
        }

        // Copy to clipboard
        UIPasteboard.general.string = urlString

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Open share sheet
        let message = "Track my flight \(flightIdentifier): \(leg.departure) → \(leg.arrival)\n\n\(urlString)"
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

    // MARK: - Insert Taxi Leg
    private func insertTaxiLeg(beforeIndex: Int) {
        print("🚕 User selected to insert taxi leg BEFORE index \(beforeIndex)")

        // Use the departure airport of the leg we're inserting before
        let taxiAirport = trip.legs[beforeIndex].departure

        print("🚕 Taxi leg will be at \(taxiAirport) (same departure/arrival)")
        print("📍 Selected placement: Before leg \(beforeIndex + 1)")

        // Call the callback if provided, otherwise fall back to onAddLeg
        if let onAddTaxiLeg = onAddTaxiLeg {
            // Use negative index to indicate "before" position
            onAddTaxiLeg(-beforeIndex - 1, taxiAirport)
        } else {
            print("⚠️ onAddTaxiLeg not implemented - falling back to onAddLeg")
            onAddLeg()
        }
    }

    private func insertTaxiLeg(afterIndex: Int) {
        print("🚕 User selected to insert taxi leg AFTER index \(afterIndex)")

        // Determine the airport for the taxi leg
        let taxiAirport: String
        if afterIndex < trip.legs.count {
            // Use the arrival airport of the leg we're inserting after
            taxiAirport = trip.legs[afterIndex].arrival
        } else {
            // Inserting at the end - use last leg's arrival
            taxiAirport = trip.legs.last?.arrival ?? ""
        }

        print("🚕 Taxi leg will be at \(taxiAirport) (same departure/arrival)")
        print("📍 Selected placement: After leg \(afterIndex + 1)")

        // Call the callback if provided, otherwise fall back to onAddLeg
        if let onAddTaxiLeg = onAddTaxiLeg {
            onAddTaxiLeg(afterIndex, taxiAirport)
        } else {
            print("⚠️ onAddTaxiLeg not implemented - falling back to onAddLeg")
            onAddLeg()
        }
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

// OrganizedLogbookView.swift - Collapsible Time-based Logbook Organization with Snapping
import SwiftUI
import MessageUI

struct OrganizedLogbookView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var store: LogBookStore
    @State private var expandedSections: Set<String> = ["current", "today", "thisWeek"]
    @State private var tripToDelete: Trip?
    @State private var showDeleteConfirmation = false
    @State private var tripToReactivate: Trip?
    @State private var showReactivateConfirmation = false
    @StateObject private var autoTimeSettings = AutoTimeSettings.shared
    @State private var showingTimeZoneSheet = false
    
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented: Bool = false
    
    // Add closure parameter for trip selection
    var onTripSelected: ((Int) -> Void)?
    
    // iPad detection
    private var isPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        // iPad: No NavigationView wrapper (already inside NavigationSplitView)
        // iPhone: Wrap in NavigationView for standalone use
        Group {
            if isPad {
                logbookListContent
            } else {
                NavigationView {
                    logbookListContent
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareTripRequest)) { notification in
            if let trip = notification.object as? Trip {
                shareTrip(trip)
            }
        }
    }
    
    // MARK: - Main List Content
    private var logbookListContent: some View {
            List {
                // Current Duty Period
                if let currentDutyTrips = getCurrentDutyTrips(), !currentDutyTrips.isEmpty {
                    CollapsibleSection(
                        id: "current",
                        title: "CURRENT DUTY PERIOD",
                        trips: currentDutyTrips,
                        isExpanded: expandedSections.contains("current"),
                        accentColor: .green,
                        store: store,
                        onTripSelected: onTripSelected,
                        onDeleteRequest: handleDeleteRequest,
                        onReactivateRequest: handleReactivateRequest
                    ) {
                        toggleSection("current")
                    }
                }
                
                // Today
                CollapsibleSection(
                    id: "today",
                    title: "TODAY",
                    trips: getTripsForToday(),
                    isExpanded: expandedSections.contains("today"),
                    accentColor: LogbookTheme.accentBlue,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("today")
                }
                
                // This Week
                CollapsibleSection(
                    id: "thisWeek",
                    title: "THIS WEEK",
                    trips: getTripsForThisWeek(),
                    isExpanded: expandedSections.contains("thisWeek"),
                    accentColor: LogbookTheme.accentBlue,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("thisWeek")
                }
                
                // This Month
                CollapsibleSection(
                    id: "thisMonth",
                    title: "THIS MONTH (\(getCurrentMonthName()))",
                    trips: getTripsForThisMonth(),
                    isExpanded: expandedSections.contains("thisMonth"),
                    accentColor: LogbookTheme.accentGreen,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("thisMonth")
                }
                
                // Last 30 Days
                CollapsibleSection(
                    id: "last30",
                    title: "LAST 30 DAYS",
                    trips: getTripsForLast30Days(),
                    isExpanded: expandedSections.contains("last30"),
                    accentColor: LogbookTheme.accentBlue,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("last30")
                }
                
                // Last 90 Days
                CollapsibleSection(
                    id: "last90",
                    title: "LAST 90 DAYS",
                    trips: getTripsForLast90Days(),
                    isExpanded: expandedSections.contains("last90"),
                    accentColor: LogbookTheme.accentBlue,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("last90")
                }
                
                // By Month (Previous months)
                Section(header: SectionHeaderView(
                    title: "BY MONTH",
                    tripCount: nil,
                    totalHours: nil,
                    isExpanded: expandedSections.contains("byMonth"),
                    accentColor: LogbookTheme.textSecondary,
                    action: { toggleSection("byMonth") }
                )) {
                    if expandedSections.contains("byMonth") {
                        ForEach(getPreviousMonths(), id: \.self) { monthYear in
                            MonthRow(
                                monthYear: monthYear,
                                trips: getTripsForMonth(monthYear),
                                isExpanded: expandedSections.contains(monthYear),
                                store: store,
                                onTripSelected: onTripSelected,
                                onDeleteRequest: handleDeleteRequest,
                                onReactivateRequest: handleReactivateRequest,
                                onToggle: { toggleSection(monthYear) }
                            )
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navy)
                
                // All Trips
                CollapsibleSection(
                    id: "all",
                    title: "ALL TRIPS",
                    trips: store.trips.sorted(by: { $0.date > $1.date }),
                    isExpanded: expandedSections.contains("all"),
                    accentColor: LogbookTheme.textSecondary,
                    store: store,
                    onTripSelected: onTripSelected,
                    onDeleteRequest: handleDeleteRequest,
                    onReactivateRequest: handleReactivateRequest
                ) {
                    toggleSection("all")
                }
        }
        .listStyle(.plain)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
        .background(LogbookTheme.navy)
        .scrollContentBackground(.hidden)
        .navigationBarHidden(false)
        //.navigationTitle("Logbook")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingTimeZoneSheet = true
                }) {
                    HStack(spacing: 1) {
                        Image(systemName: autoTimeSettings.useZuluTime ? "globe" : "clock")
                            .font(.caption)
                        Text(autoTimeSettings.useZuluTime ? "UTC" : "Local")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(autoTimeSettings.useZuluTime ? Color.cyan.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(autoTimeSettings.useZuluTime ? .cyan : .orange)
                    .cornerRadius(8)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if let latestTrip = store.trips.sorted(by: { $0.date > $1.date }).first {
                    Button {
                        shareTrip(latestTrip)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share latest trip")
                }
            }
        }
        .sheet(isPresented: $showingTimeZoneSheet) {
            TimeZoneSettingsSheet()
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityViewControllerRepresentable(activityItems: shareItems)
                .ignoresSafeArea()
        }
        .confirmationDialog(
                "Delete Trip",
                isPresented: $showDeleteConfirmation,
                presenting: tripToDelete
            ) { trip in
                Button("Delete", role: .destructive) {
                    deleteTrip(trip)
                }
                Button("Cancel", role: .cancel) {}
            } message: { trip in
                Text("Are you sure you want to delete this trip?")
            }
        .confirmationDialog(
                "Reactivate Trip",
                isPresented: $showReactivateConfirmation,
                presenting: tripToReactivate
            ) { trip in
                Button("Reactivate") {
                    reactivateTrip(trip)
                }
                Button("Cancel", role: .cancel) {}
            } message: { trip in
                Text("Reactivate trip \(trip.tripNumber)? This will set it as your active trip.")
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // iPad: fill detail pane
    }
    
    private func handleDeleteRequest(_ trip: Trip) {
        tripToDelete = trip
        showDeleteConfirmation = true
    }
    
    private func deleteTrip(_ trip: Trip) {
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            store.deleteTrip(at: IndexSet(integer: index))
        }
        tripToDelete = nil
    }
    
    private func handleReactivateRequest(_ trip: Trip) {
        tripToReactivate = trip
        showReactivateConfirmation = true
    }
    
    private func reactivateTrip(_ trip: Trip) {
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = trip
            updatedTrip.status = .active
            
            // If no perDiemStarted, set it to now
            if updatedTrip.perDiemStarted == nil {
                updatedTrip.perDiemStarted = Date()
            }
            
            // Clear perDiemEnded since we're reactivating
            updatedTrip.perDiemEnded = nil
            
            store.updateTrip(updatedTrip, at: index)
            
            // Notify watch and other systems
            NotificationCenter.default.post(
                name: .tripStatusChanged,
                object: updatedTrip
            )
            
            print("✅ Reactivated trip: \(trip.tripNumber)")
        }
        tripToReactivate = nil
    }
    
    private func toggleSection(_ id: String) {
        withAnimation {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
            } else {
                expandedSections.insert(id)
            }
        }
    }
    
    // MARK: - Model Access Helpers (strongly typed)
    private func tripNumberDisplay(_ trip: Trip) -> String { trip.tripNumber }
    private func crewDisplay(_ trip: Trip) -> String {
        trip.crew.map { $0.name }.joined(separator: ", ")
    }
    private func crewEmails(_ trip: Trip) -> [String] {
        trip.crew.map { $0.email }.filter { !$0.isEmpty }
    }
    private func legsArray(_ trip: Trip) -> [FlightLeg] { trip.legs }

    private func legDeparture(_ leg: FlightLeg) -> String { leg.departure }
    private func legArrival(_ leg: FlightLeg) -> String { leg.arrival }
    private func legTimeDisplay(_ leg: FlightLeg, key: String) -> String {
        switch key {
        case "out": return leg.outTime
        case "off": return leg.offTime
        case "on":  return leg.onTime
        case "in":  return leg.inTime
        default: return "—"
        }
    }

    // Additional Trip field helpers
    private func flightNumber(_ trip: Trip) -> String? { trip.deadheadFlightNumber ?? trip.legs.first?.flightNumber }
    private func tailNumber(_ trip: Trip) -> String? { trip.aircraft }
    private func aircraftType(_ trip: Trip) -> String? { nil }
    private func routeSummary(_ trip: Trip) -> String? { trip.routeString }
    private func remarks(_ trip: Trip) -> String? { trip.notes }
    private func picName(_ trip: Trip) -> String? { trip.crew.first { $0.role.localizedCaseInsensitiveContains("captain") }?.name }
    private func sicName(_ trip: Trip) -> String? { trip.crew.first { $0.role.localizedCaseInsensitiveContains("first officer") }?.name }
    private func totalBlock(_ trip: Trip) -> String? { trip.formattedTotalTimeWithCommaPlus }
    private func totalFlight(_ trip: Trip) -> String? { trip.formattedFlightTimeWithCommaPlus }
    private func dutyStart(_ trip: Trip) -> String? { trip.tatStart }
    private func dutyEnd(_ trip: Trip) -> String? { trip.formattedFinalTAT }

    // Per-leg optional field helpers
    private func legFlightNumber(_ leg: FlightLeg) -> String? { leg.flightNumber }
    private func legTail(_ leg: FlightLeg) -> String? { tailNumberForLeg(leg) }
    private func legAircraftType(_ leg: FlightLeg) -> String? { nil }
    private func legCruiseAlt(_ leg: FlightLeg) -> String? { nil }
    private func legFuelOut(_ leg: FlightLeg) -> String? { nil }
    private func legFuelIn(_ leg: FlightLeg) -> String? { nil }
    private func legBlockTime(_ leg: FlightLeg) -> String? { leg.formattedBlockTime }
    private func legAirTime(_ leg: FlightLeg) -> String? { leg.formattedFlightTime }
    private func legRemarks(_ leg: FlightLeg) -> String? { nil }

    private func tailNumberForLeg(_ leg: FlightLeg) -> String? { nil }

    // MARK: - Sharing Helpers
    private func shareTrip(_ trip: Trip) {
        // 1) Build a PDF of the log sheet
        let pdfURL = exportTripPDF(trip)
        // 2) Optional: Include an app deep link payload so ProPilot can import directly
        let deepLink = buildProPilotDeepLink(for: trip)

        var items: [Any] = []
        if let pdfURL = pdfURL { items.append(pdfURL) }
        if let deepLink = deepLink { items.append(deepLink) }

        // 3) Prefer email with crewmembers auto-CC when available, but fall back to activity sheet
        if MFMailComposeViewController.canSendMail(), let pdfURL = pdfURL {
            presentMailComposer(subject: "Trip #\(trip.tripNumber) - \(trip.routeString) - \(formattedDate(trip.date))", body: mailBody(for: trip), attachmentURL: pdfURL, cc: crewEmails(trip))
        } else {
            shareItems = items.isEmpty ? ["Trip: \(tripNumberDisplay(trip))"] : items
            isShareSheetPresented = true
        }
    }

    private func renderAsImage(view: AnyView) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        let targetSize = controller.view.intrinsicContentSize == .zero ? CGSize(width: UIScreen.main.bounds.width - 40, height: 120) : controller.view.intrinsicContentSize
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.sizeToFit()

        let size = controller.view.bounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: - PDF Export & Mail Helpers
    private func exportTripPDF(_ trip: Trip) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter at 72 dpi
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("Trip_\(tripNumberDisplay(trip))_\(Int(trip.date.timeIntervalSince1970)).pdf")
        do {
            try renderer.writePDF(to: tmpURL, withActions: { ctx in
                ctx.beginPage()
                drawLogSheet(for: trip)
            })
            return tmpURL
        } catch {
            print("PDF export failed: \(error)")
            return nil
        }
    }

    private func drawLogSheet(for trip: Trip) {
        // Page setup
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter 8.5x11 at 72 dpi
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - margin * 2
        let left = margin
        let top = margin

        // Background
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(pageRect)

        // Title: AIRCRAFT FLIGHT LOG
        let title = "AIRCRAFT FLIGHT LOG"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: left, y: top), withAttributes: titleAttrs)

        var cursorY = top + 28

        // Helper to draw labeled boxes
        func drawLabeled(_ label: String, value: String?, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, labelWidth: CGFloat = 80) {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            // Label
            (label + ":").draw(at: CGPoint(x: x, y: y + 3), withAttributes: labelAttrs)
            // Box
            let boxX = x + labelWidth
            let boxRect = CGRect(x: boxX, y: y, width: w - labelWidth, height: h)
            UIColor.black.setStroke()
            UIBezierPath(rect: boxRect).stroke()
            // Value
            if let v = value, !v.isEmpty {
                let inset = boxRect.insetBy(dx: 6, dy: 4)
                v.draw(in: inset, withAttributes: valueAttrs)
            }
        }

        // Header row: Date, Aircraft Type, 'N' Number, Trip Number
        let rowH: CGFloat = 22
        let colW = contentWidth / 4
        drawLabeled("DATE", value: formattedDate(trip.date), x: left, y: cursorY, w: colW, h: rowH)
        drawLabeled("AIRCRAFT TYPE", value: nil, x: left + colW, y: cursorY, w: colW, h: rowH)
        drawLabeled("'N' NUMBER", value: trip.aircraft, x: left + colW * 2, y: cursorY, w: colW, h: rowH)
        drawLabeled("TRIP NUMBER", value: trip.tripNumber, x: left + colW * 3, y: cursorY, w: colW, h: rowH)
        cursorY += rowH + 8

        // Crew row: CAPT LAST NAME / IN / SIGNATURE, F/O LAST NAME / IN, F/E LAST NAME / IN
        func lastName(for roleContains: String) -> String? {
            trip.crew.first { $0.role.localizedCaseInsensitiveContains(roleContains) }?.name.split(separator: " ").last.map(String.init)
        }
        let crewColW = contentWidth / 3
        drawLabeled("CAPT LAST NAME", value: lastName(for: "captain"), x: left, y: cursorY, w: crewColW, h: rowH, labelWidth: 110)
        drawLabeled("IN", value: nil, x: left + crewColW, y: cursorY, w: crewColW/2, h: rowH, labelWidth: 30)
        drawLabeled("CAPT SIGNATURE", value: nil, x: left + crewColW + crewColW/2, y: cursorY, w: crewColW/2, h: rowH, labelWidth: 110)
        cursorY += rowH + 4
        drawLabeled("F/O LAST NAME", value: lastName(for: "first officer"), x: left, y: cursorY, w: crewColW, h: rowH, labelWidth: 110)
        drawLabeled("IN", value: nil, x: left + crewColW, y: cursorY, w: crewColW, h: rowH, labelWidth: 30)
        drawLabeled("F/E LAST NAME", value: nil, x: left + crewColW * 2, y: cursorY, w: crewColW, h: rowH, labelWidth: 110)

        // Right-side panel: PREVIOUS TAT / TOTAL FLIGHT THIS PAGE / NEW TAT / NOTES-REMARKS
        let panelX = left + contentWidth - 220
        let panelW: CGFloat = 220
        var panelY = top + 28
        let panelRowH: CGFloat = 20
        drawLabeled("PREVIOUS TAT", value: trip.tatStart, x: panelX, y: panelY, w: panelW, h: panelRowH, labelWidth: 120)
        panelY += panelRowH + 6
        // TOTAL FLIGHT THIS PAGE computed later; placeholder box for now, then draw actual value after table
        let totalFlightThisPageRect = CGRect(x: panelX + 120, y: panelY, width: panelW - 120, height: panelRowH)
        UIColor.black.setStroke(); UIBezierPath(rect: totalFlightThisPageRect).stroke()
        "TOTAL FLIGHT THIS PAGE:".draw(at: CGPoint(x: panelX, y: panelY + 3), withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: UIColor.darkGray])
        panelY += panelRowH + 6
        drawLabeled("NEW TAT", value: trip.formattedFinalTAT, x: panelX, y: panelY, w: panelW, h: panelRowH, labelWidth: 120)
        panelY += panelRowH + 6
        // NOTES/REMARKS area
        let notesLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        "NOTES/REMARKS:".draw(at: CGPoint(x: panelX, y: panelY), withAttributes: notesLabelAttrs)
        panelY += 14
        let notesRect = CGRect(x: panelX, y: panelY, width: panelW, height: 120)
        UIColor.black.setStroke(); UIBezierPath(rect: notesRect).stroke()
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        trip.notes.draw(in: notesRect.insetBy(dx: 6, dy: 6), withAttributes: noteAttrs)

        // Move cursor below crew rows for the main table
        cursorY += rowH * 2 + 8

        // Routing + GMT Block and Flight Times table
        // Columns optimized to fit page width (540 points available after margins)
        struct Col { let title: String; let width: CGFloat }
        let cols: [Col] = [
            Col(title: "Leg", width: 30),            // Leg number
            Col(title: "FROM", width: 50),           // Departure airport
            Col(title: "TO", width: 50),             // Arrival airport
            Col(title: "OUT", width: 55),            // Out time
            Col(title: "OFF", width: 55),            // Off time
            Col(title: "ON", width: 55),             // On time
            Col(title: "IN", width: 55),             // In time
            Col(title: "TOTAL\nFLIGHT", width: 70),  // Flight time
            Col(title: "TOTAL\nBLOCK", width: 70),   // Block time
            Col(title: "LNDS\nC LND", width: 50)     // Landings
        ]
        // Total: 30+50+50+55+55+55+55+70+70+50 = 540 points ✅ Perfect fit!
        let tableX = left
        let headerH: CGFloat = 18
        var colX = tableX
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        for col in cols {
            let rect = CGRect(x: colX, y: cursorY, width: col.width, height: headerH)
            UIColor.black.setStroke(); UIBezierPath(rect: rect).stroke()
            col.title.draw(in: rect.insetBy(dx: 4, dy: 2), withAttributes: headerAttrs)
            colX += col.width
        }
        cursorY += headerH

        // Rows: up to 5 legs per page
        let rowH2: CGFloat = 20
        let legsPerPage = 5
        let legs = trip.legs
        var pageFlightMinutes = 0

        func drawRow(_ idx: Int, _ leg: FlightLeg) {
            var x = tableX
            let cells: [String] = [
                String(idx + 1),                        // Leg number
                leg.departure,                          // FROM
                leg.arrival,                            // TO
                formatTimeForPDF(leg.outTime),          // OUT (formatted: 20:49)
                formatTimeForPDF(leg.offTime),          // OFF (formatted: 20:49)
                formatTimeForPDF(leg.onTime),           // ON (formatted: 20:49)
                formatTimeForPDF(leg.inTime),           // IN (formatted: 20:49)
                leg.formattedFlightTime,                // TOTAL FLIGHT
                leg.formattedBlockTime,                 // TOTAL BLOCK
                ""                                      // LNDS (empty for now)
            ]
            for (i, col) in cols.enumerated() {
                let rect = CGRect(x: x, y: cursorY, width: col.width, height: rowH2)
                UIColor.black.setStroke(); UIBezierPath(rect: rect).stroke()
                let val = i < cells.count ? cells[i] : ""
                val.draw(in: rect.insetBy(dx: 4, dy: 3), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
                x += col.width
            }
        }

        let startIndex = 0
        let endIndex = min(legs.count, legsPerPage)
        for i in startIndex..<endIndex {
            drawRow(i, legs[i])
            cursorY += rowH2
            pageFlightMinutes += legs[i].calculateFlightMinutes()
        }

        // Totals row
        var totalsX = tableX
        // "TOTAL:" label spans first 7 columns (Leg, FROM, TO, OUT, OFF, ON, IN)
        let totalsLabelWidth = cols[0].width + cols[1].width + cols[2].width + cols[3].width + cols[4].width + cols[5].width + cols[6].width
        let totalsLabelRect = CGRect(x: totalsX, y: cursorY, width: totalsLabelWidth, height: rowH2)
        UIColor.black.setStroke(); UIBezierPath(rect: totalsLabelRect).stroke()
        "TOTAL:".draw(in: totalsLabelRect.insetBy(dx: 6, dy: 3), withAttributes: headerAttrs)
        totalsX += totalsLabelWidth
        
        // TOTAL FLIGHT (page) - column 7
        let totalFlightStr = minutesToHPlusM(pageFlightMinutes)
        let tfRect = CGRect(x: totalsX, y: cursorY, width: cols[7].width, height: rowH2)
        UIColor.black.setStroke(); UIBezierPath(rect: tfRect).stroke()
        totalFlightStr.draw(in: tfRect.insetBy(dx: 4, dy: 3), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
        totalsX += cols[7].width
        
        // TOTAL BLOCK (page) - column 8
        let pageBlockMinutes = legs[startIndex..<endIndex].reduce(0) { $0 + $1.blockMinutes() }
        let tbRect = CGRect(x: totalsX, y: cursorY, width: cols[8].width, height: rowH2)
        UIColor.black.setStroke(); UIBezierPath(rect: tbRect).stroke()
        minutesToHPlusM(pageBlockMinutes).draw(in: tbRect.insetBy(dx: 4, dy: 3), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
        totalsX += cols[8].width
        
        // LNDS column - column 9 (empty)
        let lndsRect = CGRect(x: totalsX, y: cursorY, width: cols[9].width, height: rowH2)
        UIColor.black.setStroke(); UIBezierPath(rect: lndsRect).stroke()
        
        cursorY += rowH2 + 10

        // Write TOTAL FLIGHT THIS PAGE into the right panel box
        let panelValueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        totalFlightStr.draw(in: totalFlightThisPageRect.insetBy(dx: 6, dy: 4), withAttributes: panelValueAttrs)

        // Lower sections (Fuel, Discrepancies, Action Taken, Parts, Airworthiness) — layout only, empty
        func sectionHeader(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat) -> CGFloat {
            let h: CGFloat = 18
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: x, y: y, width: w, height: h)).stroke()
            title.draw(in: CGRect(x: x + 6, y: y + 2, width: w - 12, height: h - 4), withAttributes: headerAttrs)
            return y + h
        }
        // Fuel/Oil/Invoice subtable
        cursorY = sectionHeader("FUEL / OIL / INVOICE", x: left, y: cursorY, w: contentWidth)
        let fuelRows = 3
        for _ in 0..<fuelRows {
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: left, y: cursorY, width: contentWidth, height: rowH2)).stroke()
            cursorY += rowH2
        }
        cursorY += 8
        // Discrepancies / Action Taken
        cursorY = sectionHeader("DISCREPANCIES", x: left, y: cursorY, w: contentWidth/2)
        let actionX = left + contentWidth/2
        _ = sectionHeader("ACTION TAKEN", x: actionX, y: cursorY - 18, w: contentWidth/2)
        let discRows = 3
        for _ in 0..<discRows {
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: left, y: cursorY, width: contentWidth/2, height: rowH2*2)).stroke()
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: actionX, y: cursorY, width: contentWidth/2, height: rowH2*2)).stroke()
            cursorY += rowH2*2
        }
        cursorY += 8
        // Parts table
        cursorY = sectionHeader("DISC. #    P/N    S/N OFF    S/N ON    POS.", x: left, y: cursorY, w: contentWidth)
        for _ in 0..<3 {
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: left, y: cursorY, width: contentWidth, height: rowH2)).stroke()
            cursorY += rowH2
        }
        cursorY += 8
        // Airworthiness release
        cursorY = sectionHeader("AIRWORTHINESS RELEASE", x: left, y: cursorY, w: contentWidth)
        for _ in 0..<2 {
            UIColor.black.setStroke(); UIBezierPath(rect: CGRect(x: left, y: cursorY, width: contentWidth, height: rowH2)).stroke()
            cursorY += rowH2
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    /// Format time string for PDF display (2049 → 20:49)
    private func formatTimeForPDF(_ timeString: String) -> String {
        guard !timeString.isEmpty else { return "" }
        // If already formatted with colon, return as-is
        if timeString.contains(":") {
            return timeString
        }
        // Format HHMM to HH:MM
        if timeString.count == 4 {
            let hh = timeString.prefix(2)
            let mm = timeString.suffix(2)
            return "\(hh):\(mm)"
        }
        return timeString
    }

    private func minutesToHPlusM(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d+%02d", h, m)
    }

    private func mailBody(for trip: Trip) -> String {
        var body = "Trip Details:\n"
        body += "- Trip Number: \(trip.tripNumber)\n"
        body += "- Aircraft: \(trip.aircraft)\n"
        body += "- Date: \(formattedDate(trip.date))\n"
        body += "- Route: \(trip.routeString)\n"
        body += "- PIC: \(picName(trip) ?? "N/A")\n"
        body += "- SIC: \(sicName(trip) ?? "N/A")\n\n"
        body += "Flight Times:\n"
        body += "- Total Block: \(trip.formattedTotalTimeWithCommaPlus)\n"
        body += "- Total Flight: \(trip.formattedFlightTimeWithCommaPlus)\n"
        body += "- TAT Start: \(trip.tatStart)\n"
        body += "- TAT End: \(trip.formattedFinalTAT)\n\n"
        // Trip details
        func add(_ label: String, _ value: String?) { if let v = value, !v.isEmpty { body += "\(label): \(v)\n" } }
        add("Flight #", flightNumber(trip))
        add("Tail", tailNumber(trip))
        add("Type", aircraftType(trip))
        add("Route", routeSummary(trip))
        add("PIC", picName(trip))
        add("SIC", sicName(trip))
        add("Duty Start", dutyStart(trip))
        add("Duty End", dutyEnd(trip))
        add("Total Block", totalBlock(trip))
        add("Total Flight", totalFlight(trip))
        add("Remarks", remarks(trip))
        body += "\nLegs:\n"
        for (i, leg) in legsArray(trip).enumerated() {
            var line = "\(i + 1). \(legDeparture(leg)) → \(legArrival(leg))  OUT: \(legTimeDisplay(leg, key: "out"))  OFF: \(legTimeDisplay(leg, key: "off"))  ON: \(legTimeDisplay(leg, key: "on"))  IN: \(legTimeDisplay(leg, key: "in"))"
            func append(_ label: String, _ v: String?) { if let v, !v.isEmpty { line += "  \(label): \(v)" } }
            append("FLT", legFlightNumber(leg))
            append("Blk", legBlockTime(leg))
            append("Air", legAirTime(leg))
            if let r = legRemarks(leg), !r.isEmpty { line += "\n    Remarks: \(r)" }
            body += line + "\n"
        }
        return body
    }

    private func buildProPilotDeepLink(for trip: Trip) -> URL? {
        // Custom URL scheme for app-to-app import (configure your URL scheme: propilot://)
        // Encode a minimal payload (e.g., trip id or JSON) as a URL parameter
        guard let data = try? JSONEncoder().encode(trip),
              let json = String(data: data, encoding: .utf8) else { return nil }
        let escaped = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "propilot://importTrip?payload=\(escaped)")
    }

    private func presentMailComposer(subject: String, body: String, attachmentURL: URL, cc: [String]) {
        let composer = MFMailComposeViewController()
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setCcRecipients(cc)
        if let data = try? Data(contentsOf: attachmentURL) {
            composer.addAttachmentData(data, mimeType: "application/pdf", fileName: attachmentURL.lastPathComponent)
        }
        // Bridge to UIKit presentation
        UIApplication.shared.topMostViewController()?.present(composer, animated: true)
    }
    
    // MARK: - Data Filtering Methods
    
    private func getCurrentDutyTrips() -> [Trip]? {
        let activeTrips = store.trips.filter { $0.status == .active || $0.status == .planning }
        return activeTrips.isEmpty ? nil : activeTrips.sorted(by: { $0.date > $1.date })
    }
    
    private func getTripsForToday() -> [Trip] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.trips.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.sorted(by: { $0.date > $1.date })
    }
    
    private func getTripsForThisWeek() -> [Trip] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return store.trips.filter { $0.date >= weekStart }.sorted(by: { $0.date > $1.date })
    }
    
    private func getTripsForThisMonth() -> [Trip] {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        return store.trips.filter { $0.date >= monthStart }.sorted(by: { $0.date > $1.date })
    }
    
    private func getTripsForLast30Days() -> [Trip] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return store.trips.filter { $0.date >= thirtyDaysAgo }.sorted(by: { $0.date > $1.date })
    }
    
    private func getTripsForLast90Days() -> [Trip] {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return store.trips.filter { $0.date >= ninetyDaysAgo }.sorted(by: { $0.date > $1.date })
    }
    
    private func getPreviousMonths() -> [String] {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        var months: [String] = []
        for i in 1...12 {
            var components = DateComponents()
            components.month = -i
            if let date = calendar.date(byAdding: components, to: Date()) {
                let month = calendar.component(.month, from: date)
                let year = calendar.component(.year, from: date)
                
                if month != currentMonth || year != currentYear {
                    let monthName = date.formatted(.dateTime.month(.wide).year())
                    months.append(monthName)
                }
            }
        }
        return months
    }
    
    private func getTripsForMonth(_ monthYear: String) -> [Trip] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        guard let targetDate = formatter.date(from: monthYear) else { return [] }
        
        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: targetDate)
        let targetYear = calendar.component(.year, from: targetDate)
        
        return store.trips.filter { trip in
            let tripMonth = calendar.component(.month, from: trip.date)
            let tripYear = calendar.component(.year, from: trip.date)
            return tripMonth == targetMonth && tripYear == targetYear
        }.sorted(by: { $0.date > $1.date })
    }
    
    private func getCurrentMonthName() -> String {
        Date().formatted(.dateTime.month(.wide))
    }
}

// MARK: - Collapsible Section
struct CollapsibleSection: View {
    let id: String
    let title: String
    let trips: [Trip]
    let isExpanded: Bool
    let accentColor: Color
    let store: LogBookStore
    var onTripSelected: ((Int) -> Void)?
    var onDeleteRequest: ((Trip) -> Void)?
    var onReactivateRequest: ((Trip) -> Void)?
    let onToggle: () -> Void
    
    var totalHours: String {
        let totalMinutes = trips.reduce(0) { $0 + $1.totalBlockMinutes }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var body: some View {
        Section(header: SectionHeaderView(
            title: title,
            tripCount: trips.count,
            totalHours: totalHours,
            isExpanded: isExpanded,
            accentColor: accentColor,
            action: onToggle
        )) {
            if isExpanded {
                if trips.isEmpty {
                    Text("No trips")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .listRowBackground(LogbookTheme.navy)
                } else {
                    ForEach(trips) { trip in
                        Button(action: {
                            // ✅ Haptic feedback on selection
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                onTripSelected?(index)
                            }
                        }) {
                            ForeFlightLogbookRow(trip: trip, store: store)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(LogbookTheme.navy)
                        .id(trip.id)  // ✅ Required for iOS 17+ snapping
                        .scrollTransition { content, phase in  // ✅ Snapping animation
                            content
                                .opacity(phase.isIdentity ? 1 : 0.85)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                .blur(radius: phase.isIdentity ? 0 : 0.5)  // ✅ Subtle blur
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                // Share this trip
                                if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                    // Use parent view helper via NotificationCenter bridge
                                    NotificationCenter.default.post(name: .shareTripRequest, object: store.trips[index])
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                            
                            Button(role: .destructive) {
                                onDeleteRequest?(trip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            // Reactivate option - only for completed trips
                            if trip.status == .completed {
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    onReactivateRequest?(trip)
                                } label: {
                                    Label("Reactivate Trip", systemImage: "arrow.counterclockwise.circle.fill")
                                }
                            }
                            
                            // View Details
                            Button {
                                if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                    onTripSelected?(index)
                                }
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }
                            
                            Divider()
                            
                            // Share
                            Button {
                                if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                    NotificationCenter.default.post(name: .shareTripRequest, object: store.trips[index])
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            // Delete
                            Button(role: .destructive) {
                                onDeleteRequest?(trip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDeleteRequest?(trips[index])
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Section Header View
struct SectionHeaderView: View {
    let title: String
    let tripCount: Int?
    let totalHours: String?
    let isExpanded: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // ✅ Haptic feedback on section toggle
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.textSecondary)
                
                Spacer()
                
                if let count = tripCount, let hours = totalHours {
                    HStack(spacing: 8) {
                        Text("\(count) trip\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(accentColor)
                        
                        Text("•")
                            .foregroundColor(LogbookTheme.textSecondary)
                        
                        Text(hours)
                            .font(.caption.bold())
                            .foregroundColor(accentColor)
                    }
                }
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)  // ✅ Smooth chevron rotation
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Month Row
struct MonthRow: View {
    let monthYear: String
    let trips: [Trip]
    let isExpanded: Bool
    let store: LogBookStore
    var onTripSelected: ((Int) -> Void)?
    var onDeleteRequest: ((Trip) -> Void)?
    var onReactivateRequest: ((Trip) -> Void)?
    let onToggle: () -> Void
    
    var totalHours: String {
        let totalMinutes = trips.reduce(0) { $0 + $1.totalBlockMinutes }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                // ✅ Haptic feedback on month toggle
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onToggle()
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                        .frame(width: 20)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)  // ✅ Smooth chevron
                    
                    Text(monthYear)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(trips.count) trips")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text("•")
                        .foregroundColor(LogbookTheme.textSecondary)
                        .font(.caption)
                    
                    Text(totalHours)
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                ForEach(trips) { trip in
                    Button(action: {
                        // ✅ Haptic feedback on selection
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                            onTripSelected?(index)
                        }
                    }) {
                        ForeFlightLogbookRow(trip: trip, store: store)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(LogbookTheme.navy)
                    .id(trip.id)  // ✅ Required for iOS 17+ snapping
                    .scrollTransition { content, phase in  // ✅ Snapping animation
                        content
                            .opacity(phase.isIdentity ? 1 : 0.85)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                            .blur(radius: phase.isIdentity ? 0 : 0.5)  // ✅ Subtle blur
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            // Share this trip
                            if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                // Use parent view helper via NotificationCenter bridge
                                NotificationCenter.default.post(name: .shareTripRequest, object: store.trips[index])
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            onDeleteRequest?(trip)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        // Reactivate option - only for completed trips
                        if trip.status == .completed {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                onReactivateRequest?(trip)
                            } label: {
                                Label("Reactivate Trip", systemImage: "arrow.counterclockwise.circle.fill")
                            }
                        }
                        
                        // View Details
                        Button {
                            if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                onTripSelected?(index)
                            }
                        } label: {
                            Label("View Details", systemImage: "info.circle")
                        }
                        
                        Divider()
                        
                        // Share
                        Button {
                            if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                NotificationCenter.default.post(name: .shareTripRequest, object: store.trips[index])
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        // Delete
                        Button(role: .destructive) {
                            onDeleteRequest?(trip)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        onDeleteRequest?(trips[index])
                    }
                }
            }
        }
        .listRowBackground(LogbookTheme.navy)
    }
}

// MARK: - Time Zone Settings Sheet
struct TimeZoneSettingsSheet: View {
    @StateObject private var settings = AutoTimeSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: settings.useZuluTime ? "globe" : "clock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(settings.useZuluTime ? .cyan : .orange)
                    
                    Text("Time Zone Setting")
                        .font(.title2.bold())
                    
                    Text("Choose how times are logged in your logbook")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Options
                VStack(spacing: 16) {
                    // Zulu/UTC Option
                    Button(action: {
                        withAnimation(.spring()) {
                            settings.useZuluTime = true
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(.cyan)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("UTC/Zulu Time")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Aviation standard • Always 24-hour")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: settings.useZuluTime ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(settings.useZuluTime ? .cyan : .gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(settings.useZuluTime ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(settings.useZuluTime ? Color.cyan : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Local Time Option
                    Button(action: {
                        withAnimation(.spring()) {
                            settings.useZuluTime = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Local Time")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Based on device timezone • 24-hour")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: !settings.useZuluTime ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(!settings.useZuluTime ? .orange : .gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(!settings.useZuluTime ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(!settings.useZuluTime ? Color.orange : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Info
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("This setting syncs with Flight Operations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("All time pickers will use this timezone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

extension Notification.Name {
    static let shareTripRequest = Notification.Name("shareTripRequest")
}

// MARK: - UIKit ActivityViewController Representable
import UIKit

struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}

// MARK: - Preview
struct OrganizedLogbookView_Previews: PreviewProvider {
    static var previews: some View {
        OrganizedLogbookView(store: LogBookStore())
            .preferredColorScheme(.dark)
    }
}

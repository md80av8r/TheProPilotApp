// ICalDiagnosticView.swift
// Diagnostic tool to inspect raw iCal data from NOC feed
// This helps identify ALL available fields that might contain block times

import SwiftUI

struct ICalDiagnosticView: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    @State private var rawICalContent: String = ""
    @State private var parsedEvents: [DiagnosticICalEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedEvent: DiagnosticICalEvent?
    @State private var showRawData = false
    @State private var copiedRawData = false
    
    // New: Parsed flight data
    @State private var parsedFlights: [ParsedFlightData] = []
    @State private var parsedNonFlightEvents: [ParsedNonFlightEvent] = []
    @State private var viewMode: ViewMode = .flights
    
    enum ViewMode: String, CaseIterable {
        case flights = "Flights"
        case events = "Events"
        case raw = "Raw"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header stats
                statsHeader
                
                // Toggle between view modes
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch viewMode {
                case .flights:
                    parsedFlightsView
                case .events:
                    parsedEventsListView
                case .raw:
                    rawDataView
                }
            }
            .navigationTitle("iCal Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        fetchAndParseICalData()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if let data = nocSettings.calendarData {
                    parseICalData(data)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
    
    // MARK: - Stats Header
    private var statsHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                DiagnosticStatBox(title: "Flights", value: "\(parsedFlights.count)", color: .blue)
                DiagnosticStatBox(title: "Events", value: "\(parsedNonFlightEvents.count)", color: .orange)
                DiagnosticStatBox(title: "Total BLH", value: totalBlockHoursFormatted, color: .green)
            }
            
            if let lastSync = nocSettings.lastSyncTime {
                Text("Last sync: \(lastSync, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
    }
    
    // MARK: - Parsed Flights View
    private var parsedFlightsView: some View {
        List {
            // Group flights by trip
            let trips = ICalFlightParser.groupIntoTrips(parsedFlights)
            
            ForEach(Array(trips.enumerated()), id: \.offset) { index, tripFlights in
                Section {
                    ForEach(tripFlights, id: \.uid) { flight in
                        ICalFlightRowView(flight: flight)  // RENAMED to avoid conflict
                    }
                } header: {
                    if let first = tripFlights.first {
                        HStack {
                            Text(first.flightNumber)
                                .font(.headline)
                            Spacer()
                            Text("BLH: \(ICalFlightParser.formatBlockHours(ICalFlightParser.totalBlockHours(for: tripFlights)))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // Also show deadheads
            let deadheads = parsedFlights.filter { $0.isDeadhead }
            if !deadheads.isEmpty {
                Section("Deadheads") {
                    ForEach(deadheads, id: \.uid) { flight in
                        HStack {
                            Image(systemName: "airplane")
                                .foregroundColor(.gray)
                            Text("\(flight.flightNumber) \(flight.origin)-\(flight.destination)")
                            Spacer()
                            if let std = flight.scheduledDeparture {
                                Text(formatZuluTime(std))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Parsed Events List View
    private var parsedEventsListView: some View {
        List {
            // Group by event type
            let grouped = Dictionary(grouping: parsedNonFlightEvents) { $0.eventType }
            
            ForEach(grouped.keys.sorted(), id: \.self) { eventType in
                Section(eventType) {
                    ForEach(grouped[eventType] ?? [], id: \.uid) { event in
                        HStack {
                            eventIcon(for: event.eventType)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.eventDescription)
                                    .font(.subheadline)
                                Text("\(formatDate(event.startTime)) - \(event.location)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if let notes = event.notes {
                                    Text(notes)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Old Parsed Events View (for raw field inspection)
    private var parsedEventsView: some View {
        List {
            // Show unique fields found across all events
            Section("All Fields Found in iCal") {
                ForEach(allUniqueFields.sorted(), id: \.self) { field in
                    HStack {
                        Text(field)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        
                        // Highlight potentially useful fields
                        if isBlockTimeField(field) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            // Show each event
            Section("Events (\(parsedEvents.count))") {
                ForEach(parsedEvents) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.summary ?? "No Summary")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                if let start = event.dtStart {
                                    Text("Start: \(start)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                if let end = event.dtEnd {
                                    Text("End: \(end)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Show field count for this event
                            Text("\(event.allFields.count) fields")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            
                            // Preview description if exists
                            if let desc = event.description, !desc.isEmpty {
                                Text(desc.prefix(100) + (desc.count > 100 ? "..." : ""))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Raw Data View
    private var rawDataView: some View {
        VStack(spacing: 0) {
            // Copy button bar
            HStack {
                Text("\(rawICalContent.count) characters")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    UIPasteboard.general.string = rawICalContent
                    copiedRawData = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedRawData = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedRawData ? "checkmark" : "doc.on.clipboard")
                        Text(copiedRawData ? "Copied!" : "Copy All")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(copiedRawData ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            
            ScrollView {
                Text(rawICalContent.isEmpty ? "No data loaded. Tap refresh to fetch." : rawICalContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color.black)
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalBlockHoursFormatted: String {
        let total = parsedFlights.compactMap { $0.blockHours }.reduce(0, +)
        return ICalFlightParser.formatBlockHours(total)
    }
    
    private var uniqueFieldCount: Int {
        allUniqueFields.count
    }
    
    private var eventsWithDescription: Int {
        parsedEvents.filter { $0.description != nil && !$0.description!.isEmpty }.count
    }
    
    private var allUniqueFields: Set<String> {
        var fields = Set<String>()
        for event in parsedEvents {
            for key in event.allFields.keys {
                fields.insert(key)
            }
        }
        return fields
    }
    
    /// Check if a field name might contain block time info
    private func isBlockTimeField(_ field: String) -> Bool {
        let blockTimeKeywords = [
            "BLOCK", "BLK", "BLH", "FLIGHT", "FLT",
            "ACTUAL", "OUT", "OFF", "ON", "IN",
            "DEPARTURE", "ARRIVAL", "DEP", "ARR",
            "DURATION", "TIME", "HOUR"
        ]
        let upper = field.uppercased()
        return blockTimeKeywords.contains { upper.contains($0) }
    }
    
    // MARK: - Data Fetching
    
    private func fetchAndParseICalData() {
        isLoading = true
        errorMessage = nil
        
        // If we have cached data, use it
        if let data = nocSettings.calendarData {
            parseICalData(data)
            isLoading = false
            return
        }
        
        // Otherwise trigger a fresh fetch
        nocSettings.fetchRosterCalendar()
        
        // Wait for data
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if let data = nocSettings.calendarData {
                parseICalData(data)
            } else {
                errorMessage = "No data received. Check credentials."
            }
            isLoading = false
        }
    }
    
    private func parseICalData(_ data: Data) {
        guard let content = String(data: data, encoding: .utf8) else {
            errorMessage = "Failed to decode data as UTF-8"
            return
        }
        
        rawICalContent = content
        
        // Use the new parser
        let (flights, events) = ICalFlightParser.parseCalendarString(content)
        parsedFlights = flights
        parsedNonFlightEvents = events
        
        print("📋 iCal Diagnostic: Found \(flights.count) flights, \(events.count) events")
        
        // Also parse old way for raw field inspection
        var oldEvents: [DiagnosticICalEvent] = []
        var currentEvent: [String: String] = [:]
        var inEvent = false
        var currentKey: String?
        var currentValue: String = ""
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // Handle line folding (lines starting with space are continuations)
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if let key = currentKey {
                    currentValue += line.trimmingCharacters(in: .whitespaces)
                    currentEvent[key] = currentValue
                }
                continue
            }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine == "BEGIN:VEVENT" {
                inEvent = true
                currentEvent = [:]
                currentKey = nil
            } else if trimmedLine == "END:VEVENT" {
                if inEvent && !currentEvent.isEmpty {
                    oldEvents.append(DiagnosticICalEvent(fields: currentEvent))
                }
                inEvent = false
                currentEvent = [:]
                currentKey = nil
            } else if inEvent && trimmedLine.contains(":") {
                // Parse field
                let parts = trimmedLine.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    // Handle fields with parameters like "DTSTART;TZID=America/New_York:20251206T140000"
                    let keyPart = parts[0]
                    let key = keyPart.components(separatedBy: ";").first ?? keyPart
                    let value = parts[1]
                    
                    currentKey = key
                    currentValue = value
                    currentEvent[key] = value
                    
                    // Also store the full key with parameters
                    if keyPart != key {
                        currentEvent[keyPart] = value
                    }
                }
            }
        }
        
        parsedEvents = oldEvents.sorted { ($0.dtStart ?? "") > ($1.dtStart ?? "") }
    }
}

// MARK: - iCal Event Model
struct DiagnosticICalEvent: Identifiable {
    let id = UUID()
    let allFields: [String: String]
    
    init(fields: [String: String]) {
        self.allFields = fields
    }
    
    var summary: String? { allFields["SUMMARY"] }
    var description: String? { allFields["DESCRIPTION"] }
    var dtStart: String? { allFields["DTSTART"] }
    var dtEnd: String? { allFields["DTEND"] }
    var location: String? { allFields["LOCATION"] }
    var uid: String? { allFields["UID"] }
    
    /// Get all X- custom fields (airline-specific data often lives here!)
    var customFields: [String: String] {
        allFields.filter { $0.key.hasPrefix("X-") }
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: DiagnosticICalEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Summary
                if let summary = event.summary {
                    Section("Summary") {
                        Text(summary)
                            .font(.headline)
                    }
                }
                
                // Standard Fields
                Section("Standard Fields") {
                    ForEach(standardFields, id: \.0) { key, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(value)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                // Custom X- Fields (often contains airline-specific data!)
                if !event.customFields.isEmpty {
                    Section("Custom Fields (X-)") {
                        ForEach(event.customFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                                Text(value)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                
                // Description (often contains detailed flight info)
                if let desc = event.description, !desc.isEmpty {
                    Section("Description (Full)") {
                        Text(desc)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                // All Fields (raw)
                Section("All Fields (Raw)") {
                    ForEach(event.allFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                }
            }
        }
    }
    
    private var standardFields: [(String, String)] {
        let standardKeys = ["DTSTART", "DTEND", "LOCATION", "UID", "CREATED", "LAST-MODIFIED", "SEQUENCE", "STATUS", "TRANSP"]
        return standardKeys.compactMap { key in
            if let value = event.allFields[key] {
                return (key, value)
            }
            return nil
        }
    }
    
    private func copyToClipboard() {
        var text = "iCal Event Data\n"
        text += "===============\n\n"
        for (key, value) in event.allFields.sorted(by: { $0.key < $1.key }) {
            text += "\(key): \(value)\n"
        }
        UIPasteboard.general.string = text
    }
}

// MARK: - Helper Views (Local to avoid conflicts)
private struct DiagnosticStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Formatters
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f
}()

// MARK: - iCal Flight Row View (RENAMED from FlightRowView to avoid conflict)
struct ICalFlightRowView: View {
    let flight: ParsedFlightData
    
    private let zuluFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HHmm'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Route and role
            HStack {
                Text("\(flight.origin) → \(flight.destination)")
                    .font(.headline)
                if let role = flight.role {
                    Text("(\(role))")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                Spacer()
                if let tail = flight.tailNumber {
                    Text(tail)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Times row
            HStack(spacing: 16) {
                if let ci = flight.checkIn {
                    VStack(alignment: .leading) {
                        Text("CI")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(zuluFormatter.string(from: ci))
                            .font(.caption.monospaced())
                    }
                }
                
                if let std = flight.scheduledDeparture {
                    VStack(alignment: .leading) {
                        Text("STD")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(zuluFormatter.string(from: std))
                            .font(.caption.monospaced())
                            .foregroundColor(.green)
                    }
                }
                
                if let sta = flight.scheduledArrival {
                    VStack(alignment: .leading) {
                        Text("STA")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text(zuluFormatter.string(from: sta))
                            .font(.caption.monospaced())
                            .foregroundColor(.red)
                    }
                }
                
                if let co = flight.checkOut {
                    VStack(alignment: .leading) {
                        Text("CO")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(zuluFormatter.string(from: co))
                            .font(.caption.monospaced())
                    }
                }
                
                Spacer()
                
                if let blh = flight.blockHoursFormatted {
                    VStack(alignment: .trailing) {
                        Text("BLH")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(blh)
                            .font(.subheadline.bold().monospaced())
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Aircraft type
            if let type = flight.aircraftType {
                Text("Aircraft: \(type)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Extensions for ICalDiagnosticView

extension ICalDiagnosticView {
    func formatZuluTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HHmm'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HHmm'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
    
    func eventIcon(for eventType: String) -> some View {
        let (icon, color): (String, Color) = {
            switch eventType {
            case "OFF": return ("moon.fill", .purple)
            case "WOFF": return ("moon.stars.fill", .orange)
            case "OND": return ("briefcase.fill", .blue)
            case "REST": return ("bed.double.fill", .green)
            case "HOL": return ("gift.fill", .red)
            case "1/7": return ("calendar.badge.clock", .cyan)
            default:
                if eventType.hasPrefix("SB") || eventType.hasPrefix("LB") {
                    return ("clock.badge.questionmark.fill", .yellow)
                }
                return ("questionmark.circle", .gray)
            }
        }()
        
        return Image(systemName: icon)
            .foregroundColor(color)
    }
}

// MARK: - Preview
struct ICalDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        ICalDiagnosticView(nocSettings: NOCSettingsStore())
    }
}

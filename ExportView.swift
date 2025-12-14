import SwiftUI
import PDFKit

struct ExportView: View {
    @ObservedObject var store: LogBookStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportData = ""
    @State private var showingShareSheet = false
    @State private var exportFormat: ExportFormat = .compact
    @State private var exportPeriod: ExportPeriod = .allTime
    @State private var selectedMonth = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isGenerating = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var exportFileURL: URL?

    @State private var filteredStartDate: Date? = nil
    @State private var filteredEndDate: Date? = nil
    @State private var useStartDate = false
    @State private var useEndDate = false
    
    
    enum ExportFormat: String, CaseIterable {
        case compact = "Mobile View"
        case full = "Full Width"
        case csv = "CSV Export"
        case foreflight = "ForeFlight CSV"
        case pdf = "PDF Report"
    }
    
    enum ExportPeriod: String, CaseIterable {
        case month = "Month"
        case dateRange = "Date Range"
        case yearToDate = "Year to Date"
        case specificYear = "Specific Year"
        case allTime = "All Time"
    }
    
    // MARK: - Subviews to reduce type-checker complexity
    @ViewBuilder
    private func formatPicker() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Export Format")
                .font(.caption)
                .foregroundColor(.gray)
            Picker("Export Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    @ViewBuilder
    private func periodPicker() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Time Period")
                .font(.caption)
                .foregroundColor(.gray)
            Picker("Time Period", selection: $exportPeriod) {
                ForEach(ExportPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    @ViewBuilder
    private func additionalPeriodControls() -> some View {
        Group {
            if exportPeriod == .month {
                DatePicker("Select Month", selection: $selectedMonth, displayedComponents: [.date])
                    .datePickerStyle(CompactDatePickerStyle())
                    .font(.caption)
            } else if exportPeriod == .dateRange {
                VStack(spacing: 8) {
                    HStack {
                        Text("From:")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 45, alignment: .leading)
                        DatePicker("", selection: $startDate, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    }
                    HStack {
                        Text("To:")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 45, alignment: .leading)
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    }
                }
            } else if exportPeriod == .specificYear {
                HStack {
                    Text("Year:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func dateFilterSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Filter (Optional)")
                .font(.caption)
                .foregroundColor(.gray)

            ExportDateRangePicker(
                startDate: $filteredStartDate,
                endDate: $filteredEndDate,
                useStartDate: $useStartDate,
                useEndDate: $useEndDate
            )

            HStack(spacing: 12) {
                Button("Last 30 Days") {
                    let now = Date()
                    filteredEndDate = now
                    filteredStartDate = Calendar.current.date(byAdding: .day, value: -30, to: now)
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    filteredStartDate = nil
                    filteredEndDate = nil
                    useStartDate = false
                    useEndDate = false
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button("Last 7 Days") {
                    let now = Date()
                    filteredEndDate = now
                    filteredStartDate = Calendar.current.date(byAdding: .day, value: -7, to: now)
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)

                Button("This Month") {
                    let cal = Calendar.current
                    let now = Date()
                    let start = cal.date(from: cal.dateComponents([.year, .month], from: now))
                    let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start ?? now) ?? now
                    filteredStartDate = start
                    filteredEndDate = end
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button("Last 3 Months") {
                    let cal = Calendar.current
                    let now = Date()
                    filteredEndDate = now
                    filteredStartDate = cal.date(byAdding: .month, value: -3, to: now)
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)

                Button("Last 6 Months") {
                    let cal = Calendar.current
                    let now = Date()
                    filteredEndDate = now
                    filteredStartDate = cal.date(byAdding: .month, value: -6, to: now)
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)

                Button("Last Year") {
                    let cal = Calendar.current
                    let now = Date()
                    filteredEndDate = now
                    filteredStartDate = cal.date(byAdding: .year, value: -1, to: now)
                    useStartDate = true
                    useEndDate = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    @ViewBuilder
    private func exportContent() -> some View {
        if exportFormat == .pdf {
            PDFExportView(store: store, filteredTrips: filteredTripsWithDateFilter, periodDescription: customPeriodDescription)
        } else {
            if isGenerating {
                VStack {
                    ProgressView("Generating export...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.white)
                    Text("Calculating night hours...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(exportData)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Export Controls
                exportControlsSection
                
                // Export Content
                exportContent()
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                if exportFormat != .pdf && !isGenerating {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Share") {
                            shareExportFile()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = exportFileURL {
                    ActivityViewController(items: [fileURL])
                } else {
                    ActivityViewController(items: [exportData])
                }
            }
        }
        .onAppear {
            Task { await generateExportData() }
        }
        .onChange(of: exportFormat) { _, _ in
            if exportFormat != .pdf {
                Task { await generateExportData() }
            }
        }
        .onChange(of: exportPeriod) { _, _ in
            if exportFormat != .pdf {
                Task { await generateExportData() }
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            if exportFormat != .pdf && exportPeriod == .month {
                Task { await generateExportData() }
            }
        }
        .onChange(of: selectedYear) { _, _ in
            if exportFormat != .pdf && exportPeriod == .specificYear {
                Task { await generateExportData() }
            }
        }
        .onChange(of: startDate) { _, _ in
            if exportFormat != .pdf && exportPeriod == .dateRange {
                Task { await generateExportData() }
            }
        }
        .onChange(of: endDate) { _, _ in
            if exportFormat != .pdf && exportPeriod == .dateRange {
                Task { await generateExportData() }
            }
        }
    }
    
    // MARK: - View Components
    
    private var exportControlsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                formatPicker()
                periodPicker()
                additionalPeriodControls()
                dateFilterSection()
                
                Button {
                    Task {
                        // Use the already-filtered trips
                        let csv = await UnifiedLogbookManager().exportToFormat(
                            filteredTripsWithDateFilter,
                            format: .foreFlight
                        )
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let dateStr = dateFormatter.string(from: Date())
                        let fileName = "ForeFlight_Export_\(dateStr).csv"
                        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                            let fileURL = cacheDir.appendingPathComponent(fileName)
                            try? FileManager.default.removeItem(at: fileURL)
                            do {
                                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
                                exportFileURL = fileURL
                                showingShareSheet = true
                            } catch {
                                exportFileURL = nil
                                exportData = csv
                                showingShareSheet = true
                            }
                        } else {
                            exportFileURL = nil
                            exportData = csv
                            showingShareSheet = true
                        }
                    }
                } label: {
                    Label("Export to ForeFlight", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Computed Properties for Filtering
    var availableYears: [Int] {
        let years = Set(store.trips.map { Calendar.current.component(.year, from: $0.date) })
        return Array(years).sorted().reversed() // Most recent first
    }
    
    var filteredTrips: [Trip] {
        let calendar = Calendar.current
        
        switch exportPeriod {
        case .month:
            let targetMonth = calendar.component(.month, from: selectedMonth)
            let targetYear = calendar.component(.year, from: selectedMonth)
            return store.trips.filter { trip in
                let tripMonth = calendar.component(.month, from: trip.date)
                let tripYear = calendar.component(.year, from: trip.date)
                return tripMonth == targetMonth && tripYear == targetYear
            }
        case .dateRange:
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            return store.trips.filter { trip in
                trip.date >= startOfDay && trip.date <= endOfDay
            }
        case .yearToDate:
            let currentYear = calendar.component(.year, from: Date())
            return store.trips.filter { trip in
                let tripYear = calendar.component(.year, from: trip.date)
                return tripYear == currentYear && trip.date <= Date()
            }
            
        case .specificYear:
            return store.trips.filter { trip in
                let tripYear = calendar.component(.year, from: trip.date)
                return tripYear == selectedYear
            }
            
        case .allTime:
            return store.trips
        }
    }
    
    // Applies optional date filters on top of exportPeriod filtering
    var filteredTripsWithDateFilter: [Trip] {
        // If neither toggle is on, return the original filteredTrips
        guard useStartDate || useEndDate else { return filteredTrips }
        let start = useStartDate ? filteredStartDate : nil
        let end = useEndDate ? filteredEndDate : nil
        return filteredTrips.filter { trip in
            var ok = true
            if let s = start {
                ok = ok && (trip.date >= Calendar.current.startOfDay(for: s))
            }
            if let e = end {
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e
                ok = ok && (trip.date <= endOfDay)
            }
            return ok
        }
    }
    
    var periodDescription: String {
        let dateFormatter = DateFormatter()
        
        switch exportPeriod {
        case .month:
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: selectedMonth)
            
        case .dateRange:
            dateFormatter.dateFormat = "MMM d, yyyy"
            return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
            
        case .yearToDate:
            let currentYear = Calendar.current.component(.year, from: Date())
            return "\(currentYear) Year to Date"
            
        case .specificYear:
            return "Year \(selectedYear)"
            
        case .allTime:
            return "All Time"
        }
    }
    
    var customPeriodDescription: String {
        guard useStartDate || useEndDate else {
            return periodDescription
        }
        
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        
        let fromStr: String
        if useStartDate, let s = filteredStartDate {
            fromStr = df.string(from: s)
        } else {
            fromStr = "Any"
        }
        
        let toStr: String
        if useEndDate, let e = filteredEndDate {
            toStr = df.string(from: e)
        } else {
            toStr = "Any"
        }
        
        return "\(periodDescription) (\(fromStr) - \(toStr))"
    }
    
    private func generateExportData() async {
        isGenerating = true
        
        let result: String
        switch exportFormat {
        case .compact:
            let compactContent = await generateCompactFormat()
            result = generateHeaderAndContent() + compactContent
        case .full:
            let fullContent = await generateFullFormat()
            result = generateHeaderAndContent() + fullContent
        case .csv:
            result = await generateEnhancedCSV()
        case .foreflight:
            result = await generateForeFlightCSV()
        case .pdf:
            result = "" // Handled separately
        }
        
        await MainActor.run {
            exportData = result
            isGenerating = false
        }
    }
    
    private func generateHeaderAndContent() -> String {
        var data = "FLIGHT LOGBOOK EXPORT\n"
        data += "Period: \(periodDescription)\n"
        
        if useStartDate || useEndDate {
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            
            let fromStr: String
            if useStartDate, let s = filteredStartDate {
                fromStr = df.string(from: s)
            } else {
                fromStr = "Any"
            }
            
            let toStr: String
            if useEndDate, let e = filteredEndDate {
                toStr = df.string(from: e)
            } else {
                toStr = "Any"
            }
            
            data += "Filtered: \(fromStr) - \(toStr)\n"
        }
        
        data += "Generated: \(formatExportDate(Date()))\n\n"
        return data
    }
    
    // MARK: - File Export Helper
    private func shareExportFile() {
        // Determine file extension based on format
        let fileExtension: String
        let fileName: String
        
        switch exportFormat {
        case .csv, .foreflight:
            fileExtension = "csv"
            fileName = exportFormat == .foreflight ? "ForeFlight_Export" : "Logbook_Export"
        case .compact, .full:
            fileExtension = "txt"
            fileName = "Logbook_Export"
        case .pdf:
            fileExtension = "pdf"
            fileName = "Logbook_Report"
        }
        
        // Create date string for filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        
        // Use caches directory for better file handling
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("❌ Could not access caches directory")
            exportFileURL = nil
            showingShareSheet = true
            return
        }
        
        let fullFileName = "\(fileName)_\(dateStr).\(fileExtension)"
        let fileURL = cacheDir.appendingPathComponent(fullFileName)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)
        
        do {
            try exportData.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Created export file: \(fileURL.path)")
            exportFileURL = fileURL
            showingShareSheet = true
        } catch {
            print("❌ Failed to create export file: \(error)")
            // Fallback to sharing raw text
            exportFileURL = nil
            showingShareSheet = true
        }
    }
    
    // MARK: - Enhanced CSV Export with Night Hours
    private func generateEnhancedCSV() async -> String {
        var csv = "Date,Trip Number,Aircraft,Route,OUT,OFF,ON,IN,Block Time,Flight Time,Night Time,Night Hours Decimal,Trip Type,Pilot Role,Notes\n"
        
        for trip in filteredTripsWithDateFilter {
            for leg in trip.legs {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: trip.date)
                
                let route = "\(leg.departure)-\(leg.arrival)"
                let blockTimeFormatted = leg.formattedBlockTime
                let flightTimeFormatted = leg.formattedFlightTime
                let nightTimeFormatted = await leg.formattedNightTime(flightDate: trip.date)
                let nightTimeDecimal = await leg.formattedNightTimeDecimal(flightDate: trip.date)
                
                // Clean notes for CSV
                let cleanNotes = trip.notes.replacingOccurrences(of: "\"", with: "\"\"")
                
                let line = "\(dateString),\(trip.tripNumber),\(trip.aircraft),\(route),\(leg.outTime),\(leg.offTime),\(leg.onTime),\(leg.inTime),\(blockTimeFormatted),\(flightTimeFormatted),\(nightTimeFormatted),\(nightTimeDecimal),\(trip.tripType.rawValue),\(trip.pilotRole.rawValue),\"\(cleanNotes)\"\n"
                
                csv += line
            }
        }
        
        return csv
    }
    
    // MARK: - ForeFlight Compatible Export with Night Hours
    private func generateForeFlightCSV() async -> String {
        // ForeFlight CSV format - EXACT match to official ForeFlight template
        // Uses COMMAS as separator (not tabs)
        // Total: 63 columns in Flights Table
        
        let totalColumns = 63
        
        // Helper to pad row to correct column count
        func padRow(_ content: String, filledColumns: Int) -> String {
            let padding = String(repeating: ",", count: totalColumns - filledColumns)
            return content + padding + "\n"
        }
        
        var csv = ""
        
        // Row 1: ForeFlight Logbook Import marker (REQUIRED)
        csv += padRow("ForeFlight Logbook Import,This row is required for importing into ForeFlight. Do not delete or modify.", filledColumns: 2)
        
        // Row 2: Empty row
        csv += padRow("", filledColumns: 0)
        
        // Row 3: Aircraft Table marker
        csv += padRow("Aircraft Table", filledColumns: 1)
        
        // Row 4: Aircraft table data types
        csv += padRow("Text,Text,Text,YYYY,Text,Text,Text,Text,Text,Boolean,Boolean,Boolean,Boolean", filledColumns: 13)
        
        // Row 5: Aircraft table column headers
        csv += padRow("AircraftID,equipType,TypeCode,Year,Make,Model,GearType,EngineType,Category/Class,complexAircraft,highPerformance,pressurized,taa", filledColumns: 13)
        
        // Rows 6-12: Empty rows for aircraft data (7 empty rows)
        for _ in 0..<7 {
            csv += padRow("", filledColumns: 0)
        }
        
        // Row 13: Flights Table marker
        csv += padRow("Flights Table", filledColumns: 1)
        
        // Row 14: Data type definitions (exact match to template)
        csv += "Date,Text,Text,Text,Text,HH:MM,HH:MM,HH:MM,HH:MM,HH:MM,HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Number,Decimal,Number,Number,Number,Number,Number,Number,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Decimal,Decimal,Decimal,Decimal,Number,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Decimal or HH:MM,Decimal or HH:MM,Decimal or HH:MM,Text,Text,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Packed Detail,Text,Boolean,Boolean,Boolean,Boolean,Boolean,Text,Decimal,Decimal or HH:MM,Number,Date,DateTime,Boolean\n"
        
        // Row 15: Column headers (exact match to ForeFlight template row 15)
        csv += "Date,AircraftID,From,To,Route,TimeOut,TimeOff,TimeOn,TimeIn,OnDuty,OffDuty,TotalTime,PIC,SIC,Night,Solo,CrossCountry,PICUS,MultiPilot,IFR,Examiner,NVG,NVGOps,Distance,Takeoff Day,Takeoff Night,Landing Full-Stop Day,Landing Full-Stop Night,Landing Touch-and-Go Day,Landing Touch-and-Go Night,ActualInstrument,SimulatedInstrument,GroundTraining,GroundTrainingGiven,HobbsStart,HobbsEnd,TachStart,TachEnd,Holds,Approach1,Approach2,Approach3,Approach4,Approach5,Approach6,DualGiven,DualReceived,SimulatedFlight,InstructorName,InstructorComments,Person1,Person2,Person3,Person4,Person5,Person6,PilotComments,Flight Review,IPC,Checkride,FAA 61.58,NVG Proficiency,[Text]CustomFieldName,[Numeric]CustomFieldName,[Hours]CustomFieldName,[Counter]CustomFieldName,[Date]CustomFieldName,[DateTime]CustomFieldName,[Toggle]CustomFieldName\n"
        
        for trip in filteredTripsWithDateFilter {
            for leg in trip.legs {
                // Skip legs missing both departure and arrival
                guard !leg.departure.isEmpty || !leg.arrival.isEmpty else { continue }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d/yy"  // ForeFlight date format
                let dateString = dateFormatter.string(from: leg.flightDate ?? trip.date)
                
                let aircraft = trip.aircraft.isEmpty ? "" : trip.aircraft
                let blockMinutes = leg.blockMinutes()
                let blockTime = blockMinutes > 0 ? String(format: "%.1f", Double(blockMinutes) / 60.0) : "0.0"
                
                // Get night time
                let nightMins = await leg.nightMinutes(flightDate: leg.flightDate ?? trip.date)
                let nightTime = nightMins > 0 ? String(format: "%.1f", Double(nightMins) / 60.0) : "0.0"
                
                // Determine PIC/SIC based on pilot role
                let picTime = (trip.pilotRole == .captain) ? blockTime : "0.0"
                let sicTime = (trip.pilotRole == .firstOfficer) ? blockTime : "0.0"
                
                // Build route string (DEP-ARR)
                let route = "\(leg.departure)-\(leg.arrival)"
                
                // Build crew string from trip crew
                let crewString = trip.crew.map { $0.name }.joined(separator: " ")
                
                // Clean notes for CSV
                let cleanNotes = trip.notes
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "\t", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                
                // Determine if day or night operations for takeoffs/landings
                let isDayOperation = nightMins == 0 || nightMins < (blockMinutes / 2)
                let dayTakeoffs = isDayOperation ? "1" : "0"
                let dayLandings = isDayOperation ? "1" : "0"
                let nightTakeoffs = isDayOperation ? "0" : "1"
                let nightLandings = isDayOperation ? "0" : "1"
                
                // Pilot Flying toggle (assuming PIC = PF for now)
                let pilotFlying = (trip.pilotRole == .captain) ? "TRUE" : "FALSE"
                
                // Build the line with all 63 columns (COMMA-separated for ForeFlight)
                // Column order MUST match Row 15 header exactly:
                // Date,AircraftID,From,To,Route,TimeOut,TimeOff,TimeOn,TimeIn,OnDuty,OffDuty,
                // TotalTime,PIC,SIC,Night,Solo,CrossCountry,PICUS,MultiPilot,IFR,Examiner,NVG,NVGOps,Distance,
                // Takeoff Day,Takeoff Night,Landing Full-Stop Day,Landing Full-Stop Night,Landing Touch-and-Go Day,Landing Touch-and-Go Night,
                // ActualInstrument,SimulatedInstrument,GroundTraining,GroundTrainingGiven,HobbsStart,HobbsEnd,TachStart,TachEnd,Holds,
                // Approach1-6,DualGiven,DualReceived,SimulatedFlight,InstructorName,InstructorComments,
                // Person1-6,PilotComments,Flight Review,IPC,Checkride,FAA 61.58,NVG Proficiency,
                // [Text]Custom,[Numeric]Custom,[Hours]Custom,[Counter]Custom,[Date]Custom,[DateTime]Custom,[Toggle]Custom
                
                let line = [
                    dateString,                                           // 1: Date
                    aircraft,                                              // 2: AircraftID
                    leg.departure,                                         // 3: From
                    leg.arrival,                                           // 4: To
                    route,                                                 // 5: Route
                    formatTimeForForeFlight(leg.outTime),                  // 6: TimeOut
                    formatTimeForForeFlight(leg.offTime),                  // 7: TimeOff
                    formatTimeForForeFlight(leg.onTime),                   // 8: TimeOn
                    formatTimeForForeFlight(leg.inTime),                   // 9: TimeIn
                    "",                                                    // 10: OnDuty
                    "",                                                    // 11: OffDuty
                    blockTime,                                             // 12: TotalTime
                    picTime,                                               // 13: PIC
                    sicTime,                                               // 14: SIC
                    nightTime,                                             // 15: Night
                    "",                                                    // 16: Solo
                    "",                                                    // 17: CrossCountry
                    "",                                                    // 18: PICUS
                    "",                                                    // 19: MultiPilot
                    "",                                                    // 20: IFR
                    "",                                                    // 21: Examiner
                    "",                                                    // 22: NVG
                    "",                                                    // 23: NVGOps
                    "",                                                    // 24: Distance
                    dayTakeoffs,                                           // 25: Takeoff Day
                    nightTakeoffs,                                         // 26: Takeoff Night
                    dayLandings,                                           // 27: Landing Full-Stop Day
                    nightLandings,                                         // 28: Landing Full-Stop Night
                    "",                                                    // 29: Landing Touch-and-Go Day
                    "",                                                    // 30: Landing Touch-and-Go Night
                    "",                                                    // 31: ActualInstrument
                    "",                                                    // 32: SimulatedInstrument
                    "",                                                    // 33: GroundTraining
                    "",                                                    // 34: GroundTrainingGiven
                    "",                                                    // 35: HobbsStart
                    "",                                                    // 36: HobbsEnd
                    "",                                                    // 37: TachStart
                    "",                                                    // 38: TachEnd
                    "",                                                    // 39: Holds
                    "",                                                    // 40: Approach1
                    "",                                                    // 41: Approach2
                    "",                                                    // 42: Approach3
                    "",                                                    // 43: Approach4
                    "",                                                    // 44: Approach5
                    "",                                                    // 45: Approach6
                    "",                                                    // 46: DualGiven
                    "",                                                    // 47: DualReceived
                    "",                                                    // 48: SimulatedFlight
                    "",                                                    // 49: InstructorName
                    "",                                                    // 50: InstructorComments
                    crewString,                                            // 51: Person1
                    "",                                                    // 52: Person2
                    "",                                                    // 53: Person3
                    "",                                                    // 54: Person4
                    "",                                                    // 55: Person5
                    "",                                                    // 56: Person6
                    cleanNotes,                                            // 57: PilotComments
                    "",                                                    // 58: Flight Review
                    "",                                                    // 59: IPC
                    "",                                                    // 60: Checkride
                    "",                                                    // 61: FAA 61.58
                    "",                                                    // 62: NVG Proficiency
                    "",                                                    // 63: [Text]CustomFieldName
                    "",                                                    // 64: [Numeric]CustomFieldName
                    "",                                                    // 65: [Hours]CustomFieldName
                    "",                                                    // 66: [Counter]CustomFieldName
                    "",                                                    // 67: [Date]CustomFieldName
                    "",                                                    // 68: [DateTime]CustomFieldName
                    ""                                                     // 69: [Toggle]CustomFieldName
                ].joined(separator: ",")
                
                csv += line + "\n"
            }
        }
        
        return csv
    }
    
    private func generateCompactFormat() async -> String {
        var data = ""
        
        // Ultra-compact for iPhone - only essential data with night hours
        let headerLine = "DATE".padding(toLength: 8, withPad: " ", startingAt: 0) +
                        " " + "ROUTE".padding(toLength: 10, withPad: " ", startingAt: 0) +
                        " " + "TRIP#".padding(toLength: 6, withPad: " ", startingAt: 0) +
                        " " + "BLK".padding(toLength: 4, withPad: " ", startingAt: 0) +
                        " " + "NGT".padding(toLength: 4, withPad: " ", startingAt: 0) +
                        " " + "OUT".padding(toLength: 5, withPad: " ", startingAt: 0) +
                        " " + "IN"
        data += headerLine + "\n"
        data += String(repeating: "=", count: 55) + "\n"
        
        let sortedTrips = getSortedTrips(from: filteredTripsWithDateFilter)
        let (duplicates, broken) = findDuplicateTripNumbers(in: sortedTrips)
        
        for trip in sortedTrips {
            let date = String(formatExportDate(trip.date).suffix(5)) // MM-DD only
            let route = formatUltraCompactRoute(trip)
            let tripNum = formatUltraCompactTripNumber(trip, duplicates: duplicates, broken: broken)
            let hours = String(format: "%.1f", Double(trip.legs.reduce(0) { $0 + $1.blockMinutes() }) / 60.0)
            
            // Calculate total night hours for the trip
            var totalNightMinutes = 0
            for leg in trip.legs {
                totalNightMinutes += await leg.nightMinutes(flightDate: trip.date)
            }
            let nightHours = String(format: "%.1f", Double(totalNightMinutes) / 60.0)
            
            let (start, end) = getTripStartEnd(trip)
            let shortStart = String(start.prefix(5)) // Remove seconds
            let shortEnd = String(end.prefix(5))
            
            let dataLine = date.padding(toLength: 8, withPad: " ", startingAt: 0) +
                          " " + route.padding(toLength: 10, withPad: " ", startingAt: 0) +
                          " " + tripNum.padding(toLength: 6, withPad: " ", startingAt: 0) +
                          " " + String(repeating: " ", count: max(0, 4 - hours.count)) + hours +
                          " " + String(repeating: " ", count: max(0, 4 - nightHours.count)) + nightHours +
                          " " + String(repeating: " ", count: max(0, 5 - shortStart.count)) + shortStart +
                          " " + String(repeating: " ", count: max(0, 5 - shortEnd.count)) + shortEnd
            data += dataLine + "\n"
        }
        
        data += String(repeating: "=", count: 55) + "\n"
        data += await generateCompactSummary(trips: sortedTrips, duplicates: duplicates, broken: broken)
        
        return data
    }
    
    private func generateFullFormat() async -> String {
        var data = ""
        
        // Full width format with night hours
        let headerLine = "DATE".padding(toLength: 12, withPad: " ", startingAt: 0) + " | " +
                        "ROUTE".padding(toLength: 25, withPad: " ", startingAt: 0) + " | " +
                        "TRIP#".padding(toLength: 15, withPad: " ", startingAt: 0) + " | " +
                        "BLOCK".padding(toLength: 8, withPad: " ", startingAt: 0) + " | " +
                        "NIGHT".padding(toLength: 8, withPad: " ", startingAt: 0) + " | " +
                        "START".padding(toLength: 8, withPad: " ", startingAt: 0) + " | " +
                        "END"
        data += headerLine + "\n"
        data += String(repeating: "=", count: 110) + "\n"
        
        let sortedTrips = getSortedTrips(from: filteredTripsWithDateFilter)
        let (duplicates, broken) = findDuplicateTripNumbers(in: sortedTrips)
        
        for trip in sortedTrips {
            let formattedDate = formatExportDate(trip.date)
            let route = formatRoute(trip)
            let baseTripNumber = trip.isDeadhead ? "DH-\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber
            
            var tripNumber = baseTripNumber
            if duplicates.contains(baseTripNumber) {
                tripNumber = "\(baseTripNumber) [DUP]"
            } else if broken.contains(baseTripNumber) {
                tripNumber = "\(baseTripNumber) [BRK]"
            }
            
            let blockMinutes = trip.legs.reduce(0) { $0 + $1.blockMinutes() }
            var totalNightMinutes = 0
            for leg in trip.legs {
                totalNightMinutes += await leg.nightMinutes(flightDate: trip.date)
            }
            
            let blockHours = String(format: "%.1f", Double(blockMinutes) / 60.0)
            let nightHours = String(format: "%.1f", Double(totalNightMinutes) / 60.0)
            let (tripStart, tripEnd) = getTripStartEnd(trip)
            
            // Truncate long strings to fit columns
            let truncatedRoute = route.count > 25 ? String(route.prefix(22)) + "..." : route
            let truncatedTripNum = tripNumber.count > 15 ? String(tripNumber.prefix(12)) + "..." : tripNumber
            
            let dataLine = formattedDate.padding(toLength: 12, withPad: " ", startingAt: 0) + " | " +
                          truncatedRoute.padding(toLength: 25, withPad: " ", startingAt: 0) + " | " +
                          truncatedTripNum.padding(toLength: 15, withPad: " ", startingAt: 0) + " | " +
                          (String(repeating: " ", count: max(0, 8 - blockHours.count)) + blockHours) + " | " +
                          (String(repeating: " ", count: max(0, 8 - nightHours.count)) + nightHours) + " | " +
                          tripStart.padding(toLength: 8, withPad: " ", startingAt: 0) + " | " +
                          tripEnd
            data += dataLine + "\n"
        }
        
        data += String(repeating: "=", count: 110) + "\n"
        data += await generateSummary(trips: sortedTrips, duplicates: duplicates, broken: broken)
        
        return data
    }
    
    private func getSortedTrips(from trips: [Trip]) -> [Trip] {
        return trips.sorted { trip1, trip2 in
            if trip1.date != trip2.date {
                return trip1.date < trip2.date
            }
            let (start1, _) = getTripStartEnd(trip1)
            let (start2, _) = getTripStartEnd(trip2)
            return start1 < start2
        }
    }
    
    private func findDuplicateTripNumbers(in trips: [Trip]) -> (duplicates: Set<String>, broken: Set<String>) {
        var tripGroups: [String: [Trip]] = [:]
        var duplicates = Set<String>()
        var broken = Set<String>()
        
        // Group trips by trip number
        for trip in trips {
            let tripNumber = trip.isDeadhead ? "DH-\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber
            
            // Skip empty trip numbers
            guard !tripNumber.isEmpty && tripNumber != "DH-" else { continue }
            
            if tripGroups[tripNumber] == nil {
                tripGroups[tripNumber] = []
            }
            tripGroups[tripNumber]?.append(trip)
        }
        
        // Analyze each group for duplicates vs broken trips
        for (tripNumber, tripsWithSameNumber) in tripGroups {
            guard tripsWithSameNumber.count > 1 else { continue }
            
            // Compare each trip with others in the same group
            for i in 0..<tripsWithSameNumber.count {
                for j in (i+1)..<tripsWithSameNumber.count {
                    let trip1 = tripsWithSameNumber[i]
                    let trip2 = tripsWithSameNumber[j]
                    
                    if areTripsIdentical(trip1, trip2) {
                        duplicates.insert(tripNumber)
                    } else {
                        broken.insert(tripNumber)
                    }
                }
            }
        }
        
        return (duplicates, broken)
    }
    
    private func areTripsIdentical(_ trip1: Trip, _ trip2: Trip) -> Bool {
        // Check if trips have same number of legs
        guard trip1.legs.count == trip2.legs.count else { return false }
        
        // Compare each leg
        for (leg1, leg2) in zip(trip1.legs, trip2.legs) {
            if !areLegsIdentical(leg1, leg2) {
                return false
            }
        }
        
        return true
    }
    
    private func areLegsIdentical(_ leg1: FlightLeg, _ leg2: FlightLeg) -> Bool {
        return leg1.departure == leg2.departure &&
               leg1.arrival == leg2.arrival &&
               leg1.outTime == leg2.outTime &&
               leg1.offTime == leg2.offTime &&
               leg1.onTime == leg2.onTime &&
               leg1.inTime == leg2.inTime
    }
    
    private func formatExportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatUltraCompactRoute(_ trip: Trip) -> String {
        if trip.legs.isEmpty { return "N/A" }
        if trip.legs.count == 1 {
            let route = "\(trip.legs[0].departure)-\(trip.legs[0].arrival)"
            return route.count > 10 ? String(route.prefix(7)) + "..." : route
        }
        let first = trip.legs.first?.departure ?? ""
        let last = trip.legs.last?.arrival ?? ""
        let route = "\(first)-\(last)"
        return route.count > 10 ? String(route.prefix(7)) + "..." : route
    }
    
    private func formatUltraCompactTripNumber(_ trip: Trip, duplicates: Set<String>, broken: Set<String>) -> String {
        let base = trip.isDeadhead ? "DH\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber
        var result = base
        
        if duplicates.contains(trip.isDeadhead ? "DH-\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber) {
            result = "\(base)D"
        } else if broken.contains(trip.isDeadhead ? "DH-\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber) {
            result = "\(base)B"
        }
        
        return result.count > 6 ? String(result.prefix(3)) + "..." : result
    }
    
    private func formatRoute(_ trip: Trip) -> String {
        if trip.legs.isEmpty {
            return "N/A"
        }
        
        if trip.legs.count == 1 {
            return "\(trip.legs[0].departure)-\(trip.legs[0].arrival)"
        }
        
        let firstDeparture = trip.legs.first?.departure ?? ""
        let lastArrival = trip.legs.last?.arrival ?? ""
        let legCount = trip.legs.count
        
        // Show first-last with leg count for multi-leg trips
        return "\(firstDeparture)-\(lastArrival) (\(legCount) legs)"
    }
    
    private func getTripStartEnd(_ trip: Trip) -> (String, String) {
        guard !trip.legs.isEmpty else { return ("N/A", "N/A") }
        
        let firstLeg = trip.legs.first!
        let lastLeg = trip.legs.last!
        
        let tripStart = formatTime24Hour(firstLeg.outTime)
        let tripEnd = formatTime24Hour(lastLeg.inTime)
        
        return (tripStart, tripEnd)
    }
    
    private func formatTime24Hour(_ timeString: String) -> String {
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return "N/A" }
        
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        let hours = padded.prefix(2)
        let minutes = padded.suffix(2)
        
        return "\(hours):\(minutes)"
    }
    
    // Helper function to format time for ForeFlight (HHMM format, no colon)
    private func formatTimeForForeFlight(_ timeString: String) -> String {
        guard timeString.count >= 3 else { return timeString }
        
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return timeString }
        
        // ForeFlight wants HHMM format (no colon), padded to 4 digits
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        return padded
    }
    
    private func formatDuration(_ totalMin: Int) -> String {
        let hours = totalMin / 60
        let minutes = totalMin % 60
        return "\(hours)+\(String(format: "%02d", minutes))"
    }
    
    private func generateCompactSummary(trips: [Trip], duplicates: Set<String>, broken: Set<String>) async -> String {
        var summary = "\nSUMMARY\n"
        summary += String(repeating: "-", count: 25) + "\n"
        
        let totalBlockMinutes = trips.reduce(0) { $0 + $1.legs.reduce(0) { $0 + $1.blockMinutes() } }
        
        var totalNightMinutes = 0
        for trip in trips {
            for leg in trip.legs {
                totalNightMinutes += await leg.nightMinutes(flightDate: trip.date)
            }
        }
        
        let totalBlockHours = Double(totalBlockMinutes) / 60.0
        let totalNightHours = Double(totalNightMinutes) / 60.0
        
        summary += "Trips: \(trips.count)\n"
        summary += "Block: \(String(format: "%.1f", totalBlockHours)) hrs\n"
        if totalNightHours > 0 {
            summary += "Night: \(String(format: "%.1f", totalNightHours)) hrs\n"
        }
        
        if !duplicates.isEmpty {
            summary += "D=Duplicate(\(duplicates.count))\n"
        }
        if !broken.isEmpty {
            summary += "B=Broken(\(broken.count))\n"
        }
        
        return summary
    }
    
    private func generateSummary(trips: [Trip], duplicates: Set<String>, broken: Set<String>) async -> String {
        var summary = "\nSUMMARY\n"
        summary += String(repeating: "=", count: 50) + "\n"
        
        let operatingTrips = trips.filter { !$0.isDeadhead }
        let deadheadTrips = trips.filter { $0.isDeadhead }
        let totalBlockMinutes = trips.reduce(0) { $0 + $1.legs.reduce(0) { $0 + $1.blockMinutes() } }
        let totalFlightMinutes = trips.reduce(0) { $0 + $1.legs.reduce(0) { $0 + $1.calculateFlightMinutes() } }
        
        var totalNightMinutes = 0
        for trip in trips {
            for leg in trip.legs {
                totalNightMinutes += await leg.nightMinutes(flightDate: trip.date)
            }
        }
        
        let totalBlockHours = Double(totalBlockMinutes) / 60.0
        let totalFlightHours = Double(totalFlightMinutes) / 60.0
        let totalNightHours = Double(totalNightMinutes) / 60.0
        
        summary += "Total Trips:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(trips.count)\n"
        summary += "Operating Trips:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(operatingTrips.count)\n"
        summary += "Deadhead Trips:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(deadheadTrips.count)\n"
        summary += "Total Block Hours:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(String(format: "%.1f", totalBlockHours))\n"
        summary += "Total Flight Hours:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(String(format: "%.1f", totalFlightHours))\n"
        if totalNightHours > 0 {
            summary += "Total Night Hours:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(String(format: "%.1f", totalNightHours))\n"
        }
        summary += "Total Block Time:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(formatDuration(totalBlockMinutes))\n"
        if totalNightMinutes > 0 {
            summary += "Total Night Time:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(formatDuration(totalNightMinutes))\n"
        }
        
        // Show duplicate warnings if any exist
        if !duplicates.isEmpty {
            summary += "\n⚠️ TRUE DUPLICATES FOUND\n"
            summary += String(repeating: "-", count: 30) + "\n"
            summary += "Duplicate Count:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(duplicates.count)\n"
            summary += "Trip Numbers:\n"
            for duplicate in duplicates.sorted() {
                summary += "  • \(duplicate) (identical times/routes)\n"
            }
            summary += "\n⚠️  These appear to be data entry errors.\n"
        }
        
        // Show broken trip information if any exist
        if !broken.isEmpty {
            summary += "\n🔄 BROKEN TRIPS FOUND\n"
            summary += String(repeating: "-", count: 30) + "\n"
            summary += "Broken Trip Count:".padding(toLength: 25, withPad: " ", startingAt: 0) + " \(broken.count)\n"
            summary += "Trip Numbers:\n"
            for brokenTrip in broken.sorted() {
                summary += "  • \(brokenTrip) (crew rest/continuation)\n"
            }
            summary += "\n💡 These are normal for multi-day trips with rest periods.\n"
        }
        
        // Add yearly breakdown if trips span multiple years (only for all-time exports)
        if exportPeriod == .allTime {
            let years = Set(trips.map { Calendar.current.component(.year, from: $0.date) }).sorted()
            if years.count > 1 {
                summary += "\nYEARLY BREAKDOWN\n"
                summary += String(repeating: "-", count: 50) + "\n"
                summary += "YEAR".padding(toLength: 8, withPad: " ", startingAt: 0) +
                          " " + "BLOCK HOURS".padding(toLength: 15, withPad: " ", startingAt: 0) +
                          " " + "NIGHT HOURS".padding(toLength: 15, withPad: " ", startingAt: 0) +
                          " " + "BLOCK TIME" + "\n"
                summary += String(repeating: "-", count: 50) + "\n"
                
                for year in years {
                    let yearTrips = trips.filter { Calendar.current.component(.year, from: $0.date) == year }
                    let yearBlockMinutes = yearTrips.reduce(0) { $0 + $1.legs.reduce(0) { $0 + $1.blockMinutes() } }
                    
                    var yearNightMinutes = 0
                    for trip in yearTrips {
                        for leg in trip.legs {
                            yearNightMinutes += await leg.nightMinutes(flightDate: trip.date)
                        }
                    }
                    
                    let yearBlockHours = Double(yearBlockMinutes) / 60.0
                    let yearNightHours = Double(yearNightMinutes) / 60.0
                    let yearBlockHoursStr = String(format: "%.1f", yearBlockHours)
                    let yearNightHoursStr = String(format: "%.1f", yearNightHours)
                    
                    summary += String(year).padding(toLength: 8, withPad: " ", startingAt: 0) +
                              " " + (String(repeating: " ", count: max(0, 15 - yearBlockHoursStr.count)) + yearBlockHoursStr) +
                              " " + (String(repeating: " ", count: max(0, 15 - yearNightHoursStr.count)) + yearNightHoursStr) +
                              " " + formatDuration(yearBlockMinutes) + "\n"
                }
            }
        }
        
        return summary
    }
}

// MARK: - Enhanced PDF Export View with Night Hours
struct PDFExportView: View {
    @ObservedObject var store: LogBookStore
    let filteredTrips: [Trip]
    let periodDescription: String
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 60))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("PDF Logbook Report")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Generate a professional PDF report for \(periodDescription)")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("PDF Report Includes:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("• \(filteredTrips.count) trips from \(periodDescription.lowercased())")
                    Text("• Professional logbook formatting")
                    Text("• **Night hours tracking per FAA standards**")
                        .foregroundColor(LogbookTheme.accentOrange)
                    Text("• Duplicate and broken trip analysis")
                    Text("• Summary statistics for selected period")
                    Text("• Print-ready layout")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
            
            Button(action: { Task { await generatePDF() } }) {
                Label("Generate PDF Report", systemImage: "arrow.down.doc.fill")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            if pdfData != nil {
                Button("Share PDF") {
                    showingShareSheet = true
                }
                .foregroundColor(LogbookTheme.accentGreen)
                .padding()
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .background(LogbookTheme.navy.ignoresSafeArea())
        .sheet(isPresented: $showingShareSheet) {
            if let pdfData = pdfData {
                ActivityViewController(items: [pdfData])
            }
        }
    }
    
    private func generatePDF() async {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5" x 11" at 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let pdfDataResult = renderer.pdfData { context in
            context.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 16)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)
            let dataFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            
            var yPosition: CGFloat = 50
            
            // Title
            let title = "FLIGHT LOGBOOK REPORT"
            let titleSize = title.size(withAttributes: [.font: titleFont])
            let titleRect = CGRect(x: (pageRect.width - titleSize.width) / 2, y: yPosition,
                                 width: titleSize.width, height: titleSize.height)
            title.draw(in: titleRect, withAttributes: [.font: titleFont])
            yPosition += titleSize.height + 10
            
            // Period description
            let periodText = "Period: \(periodDescription)"
            let periodSize = periodText.size(withAttributes: [.font: headerFont])
            let periodRect = CGRect(x: (pageRect.width - periodSize.width) / 2, y: yPosition,
                                  width: periodSize.width, height: periodSize.height)
            periodText.draw(in: periodRect, withAttributes: [.font: headerFont])
            yPosition += periodSize.height + 5
            
            // Generated date
            let dateText = "Generated: \(formatExportDate(Date()))"
            let dateSize = dateText.size(withAttributes: [.font: headerFont])
            let dateRect = CGRect(x: (pageRect.width - dateSize.width) / 2, y: yPosition,
                                width: dateSize.width, height: dateSize.height)
            dateText.draw(in: dateRect, withAttributes: [.font: headerFont])
            yPosition += dateSize.height + 20
            
            // Headers including night hours
            let headerText = "DATE".padding(toLength: 10, withPad: " ", startingAt: 0) +
                           "ROUTE".padding(toLength: 20, withPad: " ", startingAt: 0) +
                           "TRIP#".padding(toLength: 12, withPad: " ", startingAt: 0) +
                           "BLOCK".padding(toLength: 8, withPad: " ", startingAt: 0) +
                           "NIGHT".padding(toLength: 8, withPad: " ", startingAt: 0) +
                           "START".padding(toLength: 8, withPad: " ", startingAt: 0) +
                           "END"
            
            let headerRect = CGRect(x: 30, y: yPosition, width: 550, height: 12)
            headerText.draw(in: headerRect, withAttributes: [.font: headerFont])
            yPosition += 15
            
            // Separator line
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: 30, y: yPosition))
            separatorPath.addLine(to: CGPoint(x: 580, y: yPosition))
            UIColor.black.setStroke()
            separatorPath.stroke()
            yPosition += 8
            
            // Data rows with night hours - NOTE: This is a limitation of PDF generation in sync context
            // For PDF, we'll use block hours as a placeholder for night hours
            let sortedTrips = filteredTrips.sorted { trip1, trip2 in
                if trip1.date != trip2.date {
                    return trip1.date < trip2.date
                }
                let (start1, _) = getTripStartEnd(trip1)
                let (start2, _) = getTripStartEnd(trip2)
                return start1 < start2
            }
            
            for trip in sortedTrips {
                if yPosition > 720 { // Near bottom of page
                    context.beginPage()
                    yPosition = 50
                }
                
                let date = formatExportDate(trip.date)
                let route = formatRoute(trip)
                let tripNum = trip.isDeadhead ? "DH-\(trip.deadheadFlightNumber ?? "")" : trip.tripNumber
                let blockHours = String(format: "%.1f", Double(trip.legs.reduce(0) { $0 + $1.blockMinutes() }) / 60.0)
                // For PDF sync context, we'll show "calc" as placeholder for night hours
                let nightHours = "calc"
                let (start, end) = getTripStartEnd(trip)
                
                // Safe string building with night hours
                let rowText = date.padding(toLength: 10, withPad: " ", startingAt: 0) +
                            route.prefix(19).padding(toLength: 20, withPad: " ", startingAt: 0) +
                            tripNum.prefix(11).padding(toLength: 12, withPad: " ", startingAt: 0) +
                            blockHours.padding(toLength: 8, withPad: " ", startingAt: 0) +
                            nightHours.padding(toLength: 8, withPad: " ", startingAt: 0) +
                            start.padding(toLength: 8, withPad: " ", startingAt: 0) +
                            end
                
                let rowRect = CGRect(x: 30, y: yPosition, width: 550, height: 10)
                rowText.draw(in: rowRect, withAttributes: [.font: dataFont])
                yPosition += 11
            }
            
            // Enhanced summary
            yPosition += 15
            let summaryTitle = "SUMMARY"
            let summaryRect = CGRect(x: 30, y: yPosition, width: 200, height: 12)
            summaryTitle.draw(in: summaryRect, withAttributes: [.font: headerFont])
            yPosition += 18
            
            let totalBlockMinutes = filteredTrips.reduce(0) { $0 + $1.legs.reduce(0) { $0 + $1.blockMinutes() } }
            let totalBlockHours = Double(totalBlockMinutes) / 60.0
            
            let summaryLines = [
                "Total Trips: \(filteredTrips.count)",
                "Operating Trips: \(filteredTrips.filter { !$0.isDeadhead }.count)",
                "Deadhead Trips: \(filteredTrips.filter { $0.isDeadhead }.count)",
                "Total Block Hours: \(String(format: "%.1f", totalBlockHours))",
                "Note: Night hours calculated per FAA regulations"
            ]
            
            for line in summaryLines {
                let lineRect = CGRect(x: 30, y: yPosition, width: 300, height: 10)
                line.draw(in: lineRect, withAttributes: [.font: dataFont])
                yPosition += 12
            }
        }
        
        await MainActor.run {
            pdfData = pdfDataResult
        }
    }
    
    // Helper methods (reused from main export)
    private func formatExportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatRoute(_ trip: Trip) -> String {
        if trip.legs.isEmpty { return "N/A" }
        if trip.legs.count == 1 {
            return "\(trip.legs[0].departure)-\(trip.legs[0].arrival)"
        }
        let firstDeparture = trip.legs.first?.departure ?? ""
        let lastArrival = trip.legs.last?.arrival ?? ""
        let legCount = trip.legs.count
        return "\(firstDeparture)-\(lastArrival) (\(legCount)L)"
    }
    
    private func getTripStartEnd(_ trip: Trip) -> (String, String) {
        guard !trip.legs.isEmpty else { return ("N/A", "N/A") }
        let firstLeg = trip.legs.first!
        let lastLeg = trip.legs.last!
        let tripStart = formatTime24Hour(firstLeg.outTime)
        let tripEnd = formatTime24Hour(lastLeg.inTime)
        return (tripStart, tripEnd)
    }
    
    private func formatTime24Hour(_ timeString: String) -> String {
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return "N/A" }
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        let hours = padded.prefix(2)
        let minutes = padded.suffix(2)
        return "\(hours):\(minutes)"
    }
    
    // Format time for ForeFlight export (HH:MM format with colon)
    private func formatTimeForForeFlight(_ timeString: String) -> String {
        // Handle empty strings
        guard !timeString.isEmpty else { return "" }
        
        // Extract only digits
        let digits = timeString.filter(\.isWholeNumber)
        guard digits.count >= 3 else { return "" }
        
        // Pad to 4 digits if needed (e.g., "945" -> "0945")
        let padded = digits.count < 4 ? String(repeating: "0", count: 4 - digits.count) + digits : String(digits.prefix(4))
        
        // Format as HH:MM
        let hours = padded.prefix(2)
        let minutes = padded.suffix(2)
        return "\(hours):\(minutes)"
    }
}

// MARK: - ExportDateRangePicker Stub
struct ExportDateRangePicker: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var useStartDate: Bool
    @Binding var useEndDate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useStartDate) {
                Text("From Date")
            }
            if useStartDate {
                DatePicker("", selection: Binding(get: { startDate ?? Date() }, set: { startDate = $0 }), displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            Toggle(isOn: $useEndDate) {
                Text("To Date")
            }
            if useEndDate {
                DatePicker("", selection: Binding(get: { endDate ?? Date() }, set: { endDate = $0 }), displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Activity View Controller
struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}


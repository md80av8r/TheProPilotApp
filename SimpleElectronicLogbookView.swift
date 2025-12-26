// SimpleElectronicLogbookView.swift
// Final version using existing FlightEntry from FlightEntry.swift
import SwiftUI
import UniformTypeIdentifiers

struct SimpleElectronicLogbookView: View {
    let mainStore: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = UnifiedLogbookManager()
    
    @State private var showingFilePicker = false
    @State private var showingFormatPicker = false
    @State private var showingShareSheet = false
    @State private var showingLogbookViewer = false
    @State private var selectedFormat: LogbookFormat = .foreFlight
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var exportData = ""
    @State private var templateData = ""
    @State private var actionType: ActionType = .template
    
    // Date filtering
    @State private var useStartDate = false
    @State private var useEndDate = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    
    enum ActionType {
        case template, export
    }
    
    // MARK: - Computed Properties
    private var filteredTrips: [Trip] {
        var trips = mainStore.trips
        
        if useStartDate {
            trips = trips.filter { $0.date >= startDate }
        }
        
        if useEndDate {
            trips = trips.filter { $0.date <= endDate }
        }
        
        return trips
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Text("Electronic Logbook")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Import from or export to ForeFlight and LogTen Pro")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // ForeFlight Gold Standard Notice
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("ForeFlight Integration")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        
                        Text("ForeFlight is our gold standard format. All imports and exports follow ForeFlight's decimal time format (2.5 hours) and field structure for maximum compatibility.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Current Data Summary
                    if !mainStore.trips.isEmpty {
                        LogbookSummaryCard(
                            tripCount: mainStore.trips.count,
                            legCount: mainStore.trips.allLegs.count,
                            totalMinutes: mainStore.trips.totalBlockMinutes()
                        )
                        
                        // View Logbook Button
                        Button(action: { showingLogbookViewer = true }) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("View Electronic Logbook")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(LogbookTheme.accentBlue.opacity(0.3))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Date Range Filter Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Date Range Filter")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Text("Filter which trips to export by date")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 16) {
                            // Start Date
                            HStack {
                                Toggle("", isOn: $useStartDate)
                                    .labelsHidden()
                                
                                Text("From:")
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .disabled(!useStartDate)
                                    .opacity(useStartDate ? 1.0 : 0.5)
                            }
                            
                            // End Date
                            HStack {
                                Toggle("", isOn: $useEndDate)
                                    .labelsHidden()
                                
                                Text("To:")
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .disabled(!useEndDate)
                                    .opacity(useEndDate ? 1.0 : 0.5)
                            }
                            
                            // Quick preset buttons
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    DatePresetButton(title: "Last 30 Days") {
                                        useStartDate = true
                                        useEndDate = false
                                        startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                                    }
                                    
                                    DatePresetButton(title: "Last 90 Days") {
                                        useStartDate = true
                                        useEndDate = false
                                        startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                                    }
                                    
                                    DatePresetButton(title: "This Month") {
                                        useStartDate = true
                                        useEndDate = true
                                        let now = Date()
                                        startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
                                        endDate = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? now
                                    }
                                    
                                    DatePresetButton(title: "This Year") {
                                        useStartDate = true
                                        useEndDate = false
                                        let now = Date()
                                        startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: now), month: 1, day: 1)) ?? now
                                    }
                                    
                                    DatePresetButton(title: "Clear") {
                                        useStartDate = false
                                        useEndDate = false
                                    }
                                }
                            }
                            
                            // Summary text
                            if useStartDate || useEndDate {
                                let filteredCount = filteredTrips.count
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .font(.caption)
                                    Text("Will export \(filteredCount) of \(mainStore.trips.count) trips")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(12)
                    
                    // Main Actions
                    VStack(spacing: 16) {
                        // Import Section
                        LogbookActionSection(
                            title: "Import Flights",
                            subtitle: "Add flights from ForeFlight or LogTen Pro",
                            icon: "square.and.arrow.down.fill",
                            color: LogbookTheme.accentGreen
                        ) {
                            VStack(spacing: 12) {
                                Button("Import CSV File") {
                                    showingFilePicker = true
                                }
                                .buttonStyle(PrimaryActionButtonStyle(color: LogbookTheme.accentGreen))
                                
                                Button("Download Template") {
                                    actionType = .template
                                    showingFormatPicker = true
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                        
                        // Export Section
                        if !mainStore.trips.isEmpty {
                            let exportCount = useStartDate || useEndDate ? filteredTrips.count : mainStore.trips.count
                            LogbookActionSection(
                                title: "Export Flights",
                                subtitle: "Export \(exportCount) trip\(exportCount == 1 ? "" : "s") to other apps",
                                icon: "square.and.arrow.up.fill",
                                color: LogbookTheme.accentBlue
                            ) {
                                Button("Export to CSV") {
                                    actionType = .export
                                    showingFormatPicker = true
                                }
                                .buttonStyle(PrimaryActionButtonStyle(color: LogbookTheme.accentBlue))
                            }
                        }
                    }
                    
                    // Status Message
                    if !statusMessage.isEmpty {
                        LogbookStatusMessageView(message: statusMessage, isProcessing: isProcessing)
                    }
                    
                    // Enhanced Help Section
                    LogbookHelpCard()
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Electronic Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") { dismiss() }
            )
        }
        .sheet(isPresented: $showingFilePicker) {
            LogbookDocumentPicker { url in
                handleFileImport(url)
            }
        }
        .sheet(isPresented: $showingFormatPicker) {
            SimplifiedFormatSelectionView(
                selectedFormat: $selectedFormat,
                onTemplate: { format in
                    print("🔍 Template button pressed for format: \(format.displayName)")
                    selectedFormat = format
                    templateData = manager.generateTemplate(for: format)
                    print("🔍 Template data length: \(templateData.count)")
                    showingShareSheet = true
                    print("🔍 Setting showingShareSheet = true")
                },
                onExport: { format in
                    selectedFormat = format
                    Task { await handleExport(format) }
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            shareSheetContent
        }
        .sheet(isPresented: $showingLogbookViewer) {
            ElectronicLogbookViewer(store: mainStore)
        }
    }
    
    // MARK: - Share Sheet Content
    @ViewBuilder
    private var shareSheetContent: some View {
        if !exportData.isEmpty {
            ActivityViewController(items: [createCSVFile(content: exportData, type: "Export")])
        } else if !templateData.isEmpty {
            ActivityViewController(items: [createCSVFile(content: templateData, type: "Template")])
        } else {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("No Data Available")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("There was an issue generating the template. Please try again.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    showingShareSheet = false
                }
                .buttonStyle(PrimaryActionButtonStyle(color: LogbookTheme.accentBlue))
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
        }
    }
    
    // MARK: - Actions
    private func handleFileImport(_ url: URL) {
        isProcessing = true
        statusMessage = "Importing flights..."
        
        Task {
            let result = await manager.importFromFile(url)
            
            await MainActor.run {
                isProcessing = false
                statusMessage = result.message
                
                if result.success {
                    // Convert FlightEntry to trips and add to store
                    for entry in result.entries {
                        let trip = convertFlightEntryToTrip(entry)
                        mainStore.addTrip(trip)
                    }
                    
                    // Clear message after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        statusMessage = ""
                    }
                }
            }
        }
    }
    
    private func handleExport(_ format: LogbookFormat) async {
        await MainActor.run {
            isProcessing = true
            statusMessage = "Generating export..."
        }
        
        // Use date filtering if enabled
        let csvData = await manager.exportToFormat(
            mainStore.trips,
            format: format,
            startDate: useStartDate ? startDate : nil,
            endDate: useEndDate ? endDate : nil
        )
        
        let filteredCount = filteredTrips.count
        
        await MainActor.run {
            exportData = csvData
            isProcessing = false
            statusMessage = "Export ready - \(filteredCount) trips exported"
            showingShareSheet = true
            
            // Clear message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                statusMessage = ""
            }
        }
    }
    
    private func createCSVFile(content: String, type: String) -> URL {
        let formatName = selectedFormat == .foreFlight ? "ForeFlight" : "LogTenPro"
        let fileName = "ProPilot_\(type)_\(formatName)_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        print("🔍 Creating CSV file: \(fileName)")
        print("🔍 Content length: \(content.count)")
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            print("✅ CSV file created successfully")
        } catch {
            print("❌ Failed to create CSV file: \(error)")
        }
        
        return tempURL
    }
    
    // MARK: - Conversion function for FlightEntry to Trip
    private func convertFlightEntryToTrip(_ entry: FlightEntry) -> Trip {
        // Create flight leg from FlightEntry
        let leg = FlightLeg(
            departure: entry.departure,
            arrival: entry.arrival,
            outTime: formatTimeFromDate(entry.blockOut),
            offTime: formatTimeFromDate(entry.blockOut.addingTimeInterval(300)),
            onTime: formatTimeFromDate(entry.blockIn.addingTimeInterval(-300)),
            inTime: formatTimeFromDate(entry.blockIn)
        )
        
        // Extract crew names from remarks if available
        var captainName = ""
        var firstOfficerName = ""
        
        // FIXED: Parse space-separated crew names from remarks
        if !entry.remarks.isEmpty {
            // Remove extra notes and split by spaces to get names
            let cleanRemarks = entry.remarks.replacingOccurrences(of: "Test", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let words = cleanRemarks.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty && $0 != "Test" }
            
            if words.count >= 2 {
                captainName = words[0]  // "Kadans"
                firstOfficerName = words[1]  // "Smith"
            } else if words.count == 1 {
                captainName = words[0]
                firstOfficerName = "IMPORTED FO"
            }
        }
        
        let crew = [
            CrewMember(role: "Captain", name: captainName),
            CrewMember(role: "First Officer", name: firstOfficerName)
        ]
        
        return Trip(
            id: UUID(),
            tripNumber: entry.tripNumber ?? "IMPORTED_\(Int(entry.date.timeIntervalSince1970))",
            aircraft: entry.aircraftType,
            date: entry.date,
            tatStart: formatTimeFromDate(entry.blockOut),
            crew: crew,
            notes: entry.remarks,
            legs: [leg],
            tripType: entry.isDeadhead ? .deadhead : .operating,
            deadheadAirline: entry.isDeadhead ? extractAirlineFromTripNumber(entry.tripNumber ?? "") : nil,
            deadheadFlightNumber: entry.isDeadhead ? entry.tripNumber : nil,
            status: .completed,
            pilotRole: entry.pilotRole,
            receiptCount: 0,
            logbookPageSent: false,
            perDiemStarted: nil,
            perDiemEnded: nil
        )
    }
    
    private func formatTimeFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        return formatter.string(from: date)
    }
    
    private func extractAirlineFromTripNumber(_ tripNumber: String) -> String? {
        let letters = tripNumber.prefix { $0.isLetter }
        return letters.isEmpty ? nil : String(letters)
    }
}

// MARK: - Format Selection View (unchanged)
struct SimplifiedFormatSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFormat: LogbookFormat
    let onTemplate: (LogbookFormat) -> Void
    let onExport: (LogbookFormat) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Select Format")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Choose your preferred logbook format")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 12) {
                    FormatCard(
                        format: .foreFlight,
                        isSelected: selectedFormat == .foreFlight,
                        isPrimary: true
                    ) {
                        selectedFormat = .foreFlight
                    }
                    
                    FormatCard(
                        format: .logTenPro,
                        isSelected: selectedFormat == .logTenPro,
                        isPrimary: false
                    ) {
                        selectedFormat = .logTenPro
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Download Template") {
                        onTemplate(selectedFormat)
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: LogbookTheme.accentGreen))
                    
                    Button("Export Flights") {
                        onExport(selectedFormat)
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: LogbookTheme.accentBlue))
                }
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Cancel") { dismiss() }
            )
        }
    }
}

// MARK: - Supporting Views (unchanged)
struct FormatCard: View {
    let format: LogbookFormat
    let isSelected: Bool
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: format.iconName)
                        .font(.title2)
                        .foregroundColor(format.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(format.displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if isPrimary {
                                Text("GOLD STANDARD")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.yellow)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(formatDescription)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(format.color)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    FormatDetailRow(icon: "clock", text: timeFormatDescription)
                    FormatDetailRow(icon: "doc.text", text: fieldsDescription)
                    if isPrimary {
                        FormatDetailRow(icon: "checkmark.seal", text: "Industry standard format")
                    }
                }
            }
            .padding()
            .background(isSelected ? format.color.opacity(0.15) : LogbookTheme.fieldBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? format.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formatDescription: String {
        switch format {
        case .foreFlight:
            return "Most popular EFB - our gold standard"
        case .logTenPro:
            return "Professional logging application"
        }
    }
    
    private var timeFormatDescription: String {
        switch format {
        case .foreFlight:
            return "Decimal hours (2.5 = 2h 30m)"
        case .logTenPro:
            return "Hours:Minutes (2:30)"
        }
    }
    
    private var fieldsDescription: String {
        switch format {
        case .foreFlight:
            return "Standard pilot logbook fields"
        case .logTenPro:
            return "Extended logging fields"
        }
    }
}

struct FormatDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 12)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct LogbookHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("Integration Guide")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                LogbookHelpRow(number: "1", text: "Export from ForeFlight: Menu → Logbook → Export → CSV")
                LogbookHelpRow(number: "2", text: "Import here: Use 'Import CSV File' button above")
                LogbookHelpRow(number: "3", text: "Export from ProPilot: Use 'Export to CSV' for other apps")
                LogbookHelpRow(number: "4", text: "Templates: Download sample CSV files for manual entry")
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ForeFlight Note:")
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text("ProPilot uses ForeFlight's decimal time format (2.5 hours) and field structure for maximum compatibility with your existing workflow.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

// MARK: - Date Preset Button
struct DatePresetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(LogbookTheme.accentBlue.opacity(0.3))
                .cornerRadius(8)
        }
    }
}

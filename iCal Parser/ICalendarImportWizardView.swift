//
//  ICalendarImportWizardView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import SwiftUI

// MARK: - Import Wizard Main View

struct ICalendarImportWizardView: View {
    @StateObject private var viewModel = ImportWizardViewModel()
    @EnvironmentObject var logbookStore: SwiftDataLogBookStore  // Your existing store
    @EnvironmentObject var importMappingStore: ImportMappingStore  // New store
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: viewModel.progress)
                    .padding()
                
                // Content based on current step
                Group {
                    switch viewModel.currentStep {
                    case .selectFile:
                        FileSelectionView(viewModel: viewModel)
                    case .previewSample:
                        SamplePreviewView(viewModel: viewModel)
                    case .mapFields:
                        FieldMappingView(viewModel: viewModel)
                    case .configure:
                        ConfigurationView(viewModel: viewModel)
                    case .preview:
                        ImportPreviewView(viewModel: viewModel)
                    case .import:
                        ImportProgressView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                HStack {
                    if viewModel.currentStep != .selectFile {
                        Button("Back") {
                            viewModel.previousStep()
                        }
                    }
                    
                    Spacer()
                    
                    Button(viewModel.nextButtonTitle) {
                        if viewModel.currentStep == .import && viewModel.importResult != nil {
                            // Import is complete, dismiss
                            dismiss()
                        } else {
                            viewModel.nextStep()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canProceed)
                }
                .padding()
            }
            .navigationTitle("Import Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.logbookStore = logbookStore
                viewModel.mappingStore = importMappingStore
                viewModel.loadSavedMappings()
            }
        }
    }
}

// MARK: - Wizard Steps

enum ImportWizardStep: Int, CaseIterable {
    case selectFile = 0
    case previewSample
    case mapFields
    case configure
    case preview
    case `import`
    
    var title: String {
        switch self {
        case .selectFile: return "Select File"
        case .previewSample: return "Preview Sample"
        case .mapFields: return "Map Fields"
        case .configure: return "Configure"
        case .preview: return "Preview Import"
        case .import: return "Import"
        }
    }
}

// MARK: - View Model

@MainActor
class ImportWizardViewModel: ObservableObject {
    @Published var currentStep: ImportWizardStep = .selectFile
    @Published var selectedFileURL: URL?
    @Published var sampleEvents: [ICalEvent] = []
    @Published var mapping: ImportMapping = .generic
    @Published var parsedEvents: [ParsedCalendarEvent] = []
    @Published var importResult: ImportResult?
    @Published var isImporting = false
    
    // References to stores
    var logbookStore: SwiftDataLogBookStore?
    var mappingStore: ImportMappingStore?
    
    var progress: Double {
        Double(currentStep.rawValue) / Double(ImportWizardStep.allCases.count - 1)
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .selectFile:
            return selectedFileURL != nil
        case .previewSample:
            return !sampleEvents.isEmpty
        case .mapFields:
            return mapping.fieldMappings.count > 0
        case .configure:
            return true
        case .preview:
            return !parsedEvents.isEmpty
        case .import:
            return importResult != nil && !isImporting
        }
    }
    
    var nextButtonTitle: String {
        switch currentStep {
        case .import:
            return "Done"
        case .preview:
            return isImporting ? "Importing..." : "Import"
        default:
            return "Next"
        }
    }
    
    func loadSavedMappings() {
        // Load mappings from store
        if let savedMappings = mappingStore?.savedMappings, !savedMappings.isEmpty {
            // Use default mapping if available, otherwise use first mapping
            if let defaultMapping = savedMappings.first(where: { $0.isDefault }) {
                mapping = defaultMapping
            } else {
                mapping = savedMappings[0]
            }
        }
    }
    
    func nextStep() {
        switch currentStep {
        case .selectFile:
            loadSampleEvents()
            currentStep = .previewSample
        case .previewSample:
            currentStep = .mapFields
        case .mapFields:
            currentStep = .configure
        case .configure:
            previewImport()
            currentStep = .preview
        case .preview:
            performImport()
            currentStep = .import
        case .import:
            // Done - close wizard
            break
        }
    }
    
    func previousStep() {
        guard let previousStep = ImportWizardStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = previousStep
    }
    
    private func loadSampleEvents() {
        guard let url = selectedFileURL else { return }
        
        do {
            let content = try String(contentsOf: url)
            let result = ICalendarParser.parse(content)
            
            if case .success(let events) = result {
                // Take first 3 events as samples
                sampleEvents = Array(events.prefix(3))
            }
        } catch {
            print("Error loading file: \(error)")
        }
    }
    
    private func previewImport() {
        guard let url = selectedFileURL else { return }
        
        do {
            let content = try String(contentsOf: url)
            let result = ICalendarImportEngine.importCalendar(
                icsContent: content,
                using: mapping
            )
            
            importResult = result
            
            // Create preview of parsed events (first 10)
            let parseResult = ICalendarParser.parse(content)
            if case .success(let events) = parseResult {
                parsedEvents = Array(events.prefix(10)).map { event in
                    var parsed = ParsedCalendarEvent(rawEvent: event)
                    
                    // Extract data for preview
                    for fieldMapping in mapping.fieldMappings {
                        if let value = FieldExtractor.extract(
                            field: fieldMapping.targetField,
                            from: event,
                            using: fieldMapping
                        ) {
                            parsed.extractedData[fieldMapping.targetField] = value
                        }
                    }
                    
                    return parsed
                }
            }
        } catch {
            print("Error previewing import: \(error)")
        }
    }
    
    private func performImport() {
        isImporting = true
        
        guard let result = importResult else { 
            isImporting = false
            return 
        }
        
        // Save each trip to LogBookStore using existing save method
        Task {
            for trip in result.createdTrips {
                logbookStore?.saveTrip(trip)
            }
            
            // Wait a moment for saves to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isImporting = false
                print("✅ Import complete: \(result.createdTrips.count) trips saved")
            }
        }
    }
}

// MARK: - File Selection View

struct FileSelectionView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    @State private var showFilePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Import Your Schedule")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select an iCalendar (.ics) file from your airline's NOC system")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let url = viewModel.selectedFileURL {
                HStack {
                    Image(systemName: "doc.text")
                    Text(url.lastPathComponent)
                    Spacer()
                    Button("Change") {
                        showFilePicker = true
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Select File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            
            // Preset templates
            VStack(alignment: .leading, spacing: 12) {
                Text("Or use a preset template:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    viewModel.mapping = .usaJetRAIDO
                } label: {
                    HStack {
                        Image(systemName: "airplane")
                        Text("NOC RAIDO")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .opacity(viewModel.mapping.name == "USA Jet RAIDO" ? 1 : 0)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.calendarEvent, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.selectedFileURL = url
                }
            case .failure(let error):
                print("Error selecting file: \(error)")
            }
        }
    }
}

// MARK: - Sample Preview View

struct SamplePreviewView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sample Events")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Here are some sample events from your file. We'll use these to set up field mapping.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.sampleEvents, id: \.uid) { event in
                        SampleEventCard(event: event)
                    }
                }
                .padding()
            }
        }
    }
}

struct SampleEventCard: View {
    let event: ICalEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.summary ?? "No Summary")
                .font(.headline)
            
            if let description = event.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            if let location = event.location {
                HStack {
                    Image(systemName: "location")
                    Text(location)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock")
                if let start = event.dtstart {
                    Text(start, style: .date)
                    Text(start, style: .time)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Field Mapping View

struct FieldMappingView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Map Your Fields")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Match the fields from your airline's calendar to the app's fields")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            List {
                ForEach($viewModel.mapping.fieldMappings) { $mapping in
                    FieldMappingRow(mapping: $mapping)
                }
                
                Button {
                    viewModel.mapping.fieldMappings.append(
                        iCalFieldMapping(
                            sourceField: .summary,
                            targetField: .flightNumber
                        )
                    )
                } label: {
                    Label("Add Field Mapping", systemImage: "plus.circle")
                }
            }
        }
    }
}

struct FieldMappingRow: View {
    @Binding var mapping: iCalFieldMapping
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("From", selection: $mapping.sourceField) {
                    ForEach(iCalField.allCases, id: \.self) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                Picker("To", selection: $mapping.targetField) {
                    ForEach(AppField.allCases, id: \.self) { field in
                        Text(field.rawValue).tag(field)
                    }
                }
            }
            
            if let rule = mapping.extractionRule {
                Text("Pattern: \(rule.pattern ?? "None")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Configuration View

struct ConfigurationView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    
    var body: some View {
        Form {
            Section("Timezone Preferences") {
                Picker("Preferred Timezone", selection: $viewModel.mapping.timezonePreference.preferredTimezone) {
                    ForEach(TimezoneOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                Toggle("Show Both Timezones", isOn: $viewModel.mapping.timezonePreference.showBothTimezones)
            }
            
            Section("Import Filters") {
                Toggle("Import Flights", isOn: $viewModel.mapping.activityFilters.importFlights)
                Toggle("Import Duty Days", isOn: $viewModel.mapping.activityFilters.importDutyDays)
                Toggle("Import Days Off", isOn: $viewModel.mapping.activityFilters.importDaysOff)
                Toggle("Import Rest Periods", isOn: $viewModel.mapping.activityFilters.importRest)
                Toggle("Import Deadheads", isOn: $viewModel.mapping.activityFilters.importDeadheads)
            }
            
            Section {
                TextField("Mapping Name", text: $viewModel.mapping.name)
                Toggle("Set as Default", isOn: $viewModel.mapping.isDefault)
            }
        }
    }
}

// MARK: - Import Preview View

struct ImportPreviewView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Preview")
                .font(.headline)
                .padding(.horizontal)
            
            if let result = viewModel.importResult {
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(label: "Total Events", value: "\(result.totalEvents)")
                    StatRow(label: "Will Import", value: "\(result.successfulImports)", color: .green)
                    StatRow(label: "Will Skip", value: "\(result.skippedEvents)", color: .orange)
                    StatRow(label: "Trips Created", value: "\(result.createdTrips.count)", color: .blue)
                    
                    if !result.errors.isEmpty {
                        StatRow(label: "Errors", value: "\(result.errors.count)", color: .red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Text("Sample Flights")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.parsedEvents.prefix(5)) { event in
                        ParsedEventCard(event: event)
                    }
                }
                .padding()
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ParsedEventCard: View {
    let event: ParsedCalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.eventType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(eventTypeColor.opacity(0.2))
                    .foregroundColor(eventTypeColor)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            if let flightNum = event.extractedData[.flightNumber] {
                Text(flightNum)
                    .font(.headline)
            }
            
            if let dep = event.extractedData[.departureAirport],
               let arr = event.extractedData[.arrivalAirport] {
                Text("\(dep) → \(arr)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let aircraft = event.extractedData[.aircraft] {
                HStack {
                    Image(systemName: "airplane")
                    Text(aircraft)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    var eventTypeColor: Color {
        switch event.eventType {
        case .flight: return .blue
        case .dutyDay: return .orange
        case .dayOff: return .green
        case .rest: return .purple
        case .deadhead: return .gray
        case .unknown: return .red
        }
    }
}

// MARK: - Import Progress View

struct ImportProgressView: View {
    @ObservedObject var viewModel: ImportWizardViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isImporting {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Importing your schedule...")
                    .font(.headline)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Import Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let result = viewModel.importResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Successfully imported \(result.successfulImports) flights")
                        Text("Created \(result.createdTrips.count) trips")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ICalendarImportWizardView()
}

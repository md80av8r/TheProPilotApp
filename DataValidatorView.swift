//
//  DataValidatorView.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 7/17/25.
//


//
//  DataValidatorView.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 7/17/25.
//

import SwiftUI

struct DataValidatorView: View {
    @Binding var data: [FlightEntry]
    let format: LogbookFormat
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logbookStore = ComprehensiveLogbookStore()
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingImportConfirmation = false
    @State private var validationResults: ValidationResults?
    @State private var isValidating = false
    
    struct ValidationResults {
        let validEntries: [FlightEntry]
        let invalidEntries: [FlightEntry]
        let warnings: [ValidationWarning]
        let duplicates: [FlightEntry]
        
        var totalEntries: Int { validEntries.count + invalidEntries.count }
        var hasIssues: Bool { !invalidEntries.isEmpty || !warnings.isEmpty || !duplicates.isEmpty }
    }
    
    struct ValidationWarning {
        let entry: FlightEntry
        let issue: String
        let severity: Severity
        
        enum Severity {
            case low, medium, high
            
            var color: Color {
                switch self {
                case .low: return .yellow
                case .medium: return .orange
                case .high: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .low: return "exclamationmark.triangle"
                case .medium: return "exclamationmark.triangle.fill"
                case .high: return "xmark.octagon.fill"
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Validation Status Header
                if let results = validationResults {
                    ValidationStatusView(results: results)
                }
                
                // Data List
                if isValidating {
                    validatingView
                } else if let results = validationResults {
                    dataListView(results: results)
                } else {
                    EmptyView()
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Data Validation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let results = validationResults, !results.validEntries.isEmpty {
                        Button("Import Valid") {
                            showingImportConfirmation = true
                        }
                        .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
        }
        .onAppear {
            validateData()
        }
        .alert("Import Confirmation", isPresented: $showingImportConfirmation) {
            Button("Cancel") { }
            Button("Import \(validationResults?.validEntries.count ?? 0) Flights") {
                importValidEntries()
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            if let results = validationResults {
                Text("Import \(results.validEntries.count) valid flight entries into your logbook?")
            }
        }
    }
    
    private var validatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(LogbookTheme.accentBlue)
            
            Text("Validating Flight Data...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Checking for errors, duplicates, and missing information")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func dataListView(results: ValidationResults) -> some View {
        List {
            // Valid Entries Section
            if !results.validEntries.isEmpty {
                Section(header: 
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Valid Entries (\(results.validEntries.count))")
                            .foregroundColor(.white)
                    }
                ) {
                    ForEach(results.validEntries) { entry in
                        ValidFlightEntryRow(entry: entry)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Invalid Entries Section
            if !results.invalidEntries.isEmpty {
                Section(header: 
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Invalid Entries (\(results.invalidEntries.count))")
                            .foregroundColor(.white)
                    }
                ) {
                    ForEach(results.invalidEntries) { entry in
                        InvalidFlightEntryRow(entry: entry)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Warnings Section
            if !results.warnings.isEmpty {
                Section(header: 
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Warnings (\(results.warnings.count))")
                            .foregroundColor(.white)
                    }
                ) {
                    ForEach(results.warnings.indices, id: \.self) { index in
                        WarningRow(warning: results.warnings[index])
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            
            // Duplicates Section
            if !results.duplicates.isEmpty {
                Section(header: 
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.yellow)
                        Text("Potential Duplicates (\(results.duplicates.count))")
                            .foregroundColor(.white)
                    }
                ) {
                    ForEach(results.duplicates) { entry in
                        DuplicateFlightEntryRow(entry: entry)
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    private func validateData() {
        isValidating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = performValidation()
            
            DispatchQueue.main.async {
                self.validationResults = results
                self.isValidating = false
            }
        }
    }
    
    private func performValidation() -> ValidationResults {
        var validEntries: [FlightEntry] = []
        var invalidEntries: [FlightEntry] = []
        var warnings: [ValidationWarning] = []
        var duplicates: [FlightEntry] = []
        
        // Check each entry for validity
        for entry in data {
            if isValidEntry(entry) {
                validEntries.append(entry)
                
                // Check for warnings
                let entryWarnings = checkForWarnings(entry)
                warnings.append(contentsOf: entryWarnings)
            } else {
                invalidEntries.append(entry)
            }
        }
        
        // Check for duplicates
        duplicates = findDuplicates(in: validEntries)
        
        return ValidationResults(
            validEntries: validEntries,
            invalidEntries: invalidEntries,
            warnings: warnings,
            duplicates: duplicates
        )
    }
    
    private func isValidEntry(_ entry: FlightEntry) -> Bool {
        // Basic validation rules
        guard !entry.aircraftType.isEmpty else { return false }
        guard !entry.departure.isEmpty else { return false }
        guard !entry.arrival.isEmpty else { return false }
        guard entry.totalTime > 0 else { return false }
        guard entry.date <= Date() else { return false } // No future flights
        
        return true
    }
    
    private func checkForWarnings(_ entry: FlightEntry) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        // Check for unusually long flights
        if entry.totalTime > 14 * 3600 { // More than 14 hours
            warnings.append(ValidationWarning(
                entry: entry,
                issue: "Flight time exceeds 14 hours",
                severity: .medium
            ))
        }
        
        // Check for missing aircraft registration
        if entry.aircraftRegistration.isEmpty {
            warnings.append(ValidationWarning(
                entry: entry,
                issue: "Missing aircraft registration",
                severity: .low
            ))
        }
        
        // Check for unusual night time (more than total time)
        if entry.nightTime > entry.totalTime {
            warnings.append(ValidationWarning(
                entry: entry,
                issue: "Night time exceeds total time",
                severity: .high
            ))
        }
        
        // Check for PIC + SIC time mismatch
        if (entry.picTime + entry.sicTime) > entry.totalTime {
            warnings.append(ValidationWarning(
                entry: entry,
                issue: "PIC + SIC time exceeds total time",
                severity: .high
            ))
        }
        
        return warnings
    }
    
    private func findDuplicates(in entries: [FlightEntry]) -> [FlightEntry] {
        var duplicates: [FlightEntry] = []
        var seen: Set<String> = []
        
        for entry in entries {
            let key = "\(entry.date)\(entry.departure)\(entry.arrival)\(entry.totalTime)"
            if seen.contains(key) {
                duplicates.append(entry)
            } else {
                seen.insert(key)
            }
        }
        
        return duplicates
    }
    
    private func importValidEntries() {
        guard let results = validationResults else { return }
        
        // Add valid entries to the comprehensive logbook store
        for entry in results.validEntries {
            logbookStore.flightEntries.append(entry)
        }
        
        dismiss()
    }
}

// MARK: - Supporting Views

struct ValidationStatusView: View {
    let results: DataValidatorView.ValidationResults
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: results.hasIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(results.hasIssues ? .orange : .green)
                
                Text("Validation Complete")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatusItem(
                    title: "Total",
                    count: results.totalEntries,
                    color: .white
                )
                
                StatusItem(
                    title: "Valid",
                    count: results.validEntries.count,
                    color: .green
                )
                
                if !results.invalidEntries.isEmpty {
                    StatusItem(
                        title: "Invalid",
                        count: results.invalidEntries.count,
                        color: .red
                    )
                }
                
                if !results.warnings.isEmpty {
                    StatusItem(
                        title: "Warnings",
                        count: results.warnings.count,
                        color: .orange
                    )
                }
                
                if !results.duplicates.isEmpty {
                    StatusItem(
                        title: "Duplicates",
                        count: results.duplicates.count,
                        color: .yellow
                    )
                }
                
                Spacer()
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
    }
}

struct StatusItem: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct ValidFlightEntryRow: View {
    let entry: FlightEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(entry.departure) → \(entry.arrival)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text(entry.aircraftType)
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Spacer()
                
                Text(entry.formattedTotalTime)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentGreen)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InvalidFlightEntryRow: View {
    let entry: FlightEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(entry.departure) → \(entry.arrival)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            
            Text("Missing required data or invalid values")
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct WarningRow: View {
    let warning: DataValidatorView.ValidationWarning
    
    var body: some View {
        HStack {
            Image(systemName: warning.severity.icon)
                .foregroundColor(warning.severity.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(warning.entry.departure) → \(warning.entry.arrival)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(warning.issue)
                    .font(.caption)
                    .foregroundColor(warning.severity.color)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct DuplicateFlightEntryRow: View {
    let entry: FlightEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(entry.departure) → \(entry.arrival)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.yellow)
            }
            
            Text("Possible duplicate flight")
                .font(.caption)
                .foregroundColor(.yellow)
        }
        .padding(.vertical, 4)
    }
}
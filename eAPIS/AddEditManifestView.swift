//
//  AddEditManifestView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import SwiftUI

struct AddEditManifestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    
    let manifest: EAPISManifest?
    @State private var editedManifest: EAPISManifest
    @State private var selectedPassengerIDs: Set<String>
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPassengerPicker = false
    
    init(manifest: EAPISManifest?) {
        self.manifest = manifest
        let initialManifest = manifest ?? EAPISManifest()
        _editedManifest = State(initialValue: initialManifest)
        _selectedPassengerIDs = State(initialValue: Set(initialManifest.passengerIDs))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Flight Information
                Section("Flight Information") {
                    TextField("Flight Number", text: $editedManifest.flightNumber)
                        .textContentType(.flightNumber)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Aircraft Registration", text: $editedManifest.aircraftRegistration)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Aircraft Type", text: $editedManifest.aircraftType)
                        .autocapitalization(.allCharacters)
                }
                
                // Route
                Section("Route") {
                    TextField("Departure Airport (ICAO)", text: $editedManifest.departureAirport)
                        .autocapitalization(.allCharacters)
                    
                    DatePicker("Departure Date", selection: $editedManifest.departureDate, displayedComponents: .date)
                    
                    DatePicker("Departure Time (UTC)", selection: $editedManifest.departureTime, displayedComponents: .hourAndMinute)
                    
                    TextField("Arrival Airport (ICAO)", text: $editedManifest.arrivalAirport)
                        .autocapitalization(.allCharacters)
                    
                    DatePicker("Estimated Arrival Date", selection: $editedManifest.estimatedArrivalDate, displayedComponents: .date)
                    
                    DatePicker("Estimated Arrival Time (UTC)", selection: $editedManifest.estimatedArrivalTime, displayedComponents: .hourAndMinute)
                }
                
                // Crew
                Section("Crew Information") {
                    TextField("Pilot in Command", text: $editedManifest.pilotInCommand)
                    
                    TextField("Pilot License Number", text: $editedManifest.pilotLicense)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Co-Pilot (Optional)", text: Binding(
                        get: { editedManifest.copilotName ?? "" },
                        set: { editedManifest.copilotName = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Co-Pilot License (Optional)", text: Binding(
                        get: { editedManifest.copilotLicense ?? "" },
                        set: { editedManifest.copilotLicense = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                // Passengers
                Section {
                    Button {
                        showingPassengerPicker = true
                    } label: {
                        HStack {
                            Text("Passengers")
                            Spacer()
                            Text("\(selectedPassengerIDs.count) selected")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !selectedPassengerIDs.isEmpty {
                        ForEach(Array(selectedPassengerIDs), id: \.self) { passengerID in
                            if let passenger = cloudKitManager.getPassenger(byID: passengerID) {
                                HStack {
                                    Text(passenger.fullName)
                                    Spacer()
                                    Button {
                                        selectedPassengerIDs.remove(passengerID)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Purpose & Customs
                Section("Purpose & Customs") {
                    Picker("Purpose of Flight", selection: $editedManifest.purposeOfFlight) {
                        ForEach(EAPISManifest.FlightPurpose.allCases, id: \.self) { purpose in
                            Text(purpose.rawValue).tag(purpose)
                        }
                    }
                    
                    if editedManifest.purposeOfFlight.requiresDetails {
                        TextField("Purpose Details", text: $editedManifest.customsPurpose)
                    }
                    
                    CountryPicker(title: "Country of Origin", selection: $editedManifest.countryOfOrigin)
                    
                    CountryPicker(title: "Destination Country", selection: $editedManifest.destinationCountry)
                    
                    Toggle("Goods to Declare", isOn: $editedManifest.customsDeclarations)
                    
                    if editedManifest.customsDeclarations {
                        TextEditor(text: $editedManifest.declarationDetails)
                            .frame(minHeight: 60)
                    }
                }
                
                // Status
                Section("Status") {
                    Picker("Manifest Status", selection: $editedManifest.status) {
                        ForEach([EAPISManifest.ManifestStatus.draft, .readyToFile, .filed, .archived], id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    
                    if editedManifest.status == .filed {
                        TextField("Confirmation Number", text: Binding(
                            get: { editedManifest.confirmationNumber ?? "" },
                            set: { editedManifest.confirmationNumber = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $editedManifest.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(manifest == nil ? "New Manifest" : "Edit Manifest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveManifest()
                    }
                    .disabled(isSaving || !isValid)
                }
            }
            .sheet(isPresented: $showingPassengerPicker) {
                PassengerPickerView(selectedPassengerIDs: $selectedPassengerIDs)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !editedManifest.flightNumber.isEmpty &&
        !editedManifest.aircraftRegistration.isEmpty &&
        !editedManifest.departureAirport.isEmpty &&
        !editedManifest.arrivalAirport.isEmpty &&
        !editedManifest.pilotInCommand.isEmpty &&
        !editedManifest.pilotLicense.isEmpty &&
        !selectedPassengerIDs.isEmpty
    }
    
    private func saveManifest() {
        editedManifest.passengerIDs = Array(selectedPassengerIDs)
        isSaving = true
        
        Task {
            do {
                try await cloudKitManager.saveManifest(editedManifest)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Passenger Picker View
struct PassengerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    @Binding var selectedPassengerIDs: Set<String>
    @State private var searchText = ""
    
    var filteredPassengers: [Passenger] {
        if searchText.isEmpty {
            return cloudKitManager.passengers
        } else {
            return cloudKitManager.passengers.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if cloudKitManager.passengers.isEmpty {
                    Text("No passengers available. Add passengers first.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredPassengers) { passenger in
                        Button {
                            if selectedPassengerIDs.contains(passenger.id) {
                                selectedPassengerIDs.remove(passenger.id)
                            } else {
                                selectedPassengerIDs.insert(passenger.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(passenger.fullName)
                                        .foregroundColor(.primary)
                                    Text(passenger.passportNumber)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPassengerIDs.contains(passenger.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search passengers")
            .navigationTitle("Select Passengers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Manifest Detail View
struct ManifestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    
    let manifest: EAPISManifest
    @State private var showingEdit = false
    @State private var showingDocumentExport = false
    @State private var showingDeleteConfirmation = false
    
    private var passengers: [Passenger] {
        cloudKitManager.getPassengers(byIDs: manifest.passengerIDs)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        StatusBadge(status: manifest.status)
                    }
                    
                    if let confirmation = manifest.confirmationNumber, !confirmation.isEmpty {
                        DetailRow(label: "Confirmation", value: confirmation)
                    }
                    
                    if let filedDate = manifest.filedDate {
                        DetailRow(label: "Filed", value: formatDate(filedDate))
                    }
                }
                
                // Flight Info
                Section("Flight Information") {
                    DetailRow(label: "Flight Number", value: manifest.flightNumber)
                    DetailRow(label: "Aircraft", value: manifest.aircraftRegistration)
                    DetailRow(label: "Type", value: manifest.aircraftType)
                }
                
                // Route
                Section("Route") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Departure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(manifest.departureAirport)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Arrival")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(manifest.arrivalAirport)
                                .font(.headline)
                        }
                    }
                    
                    DetailRow(label: "Departure", value: formatDateTime(manifest.departureDate, manifest.departureTime))
                    DetailRow(label: "Estimated Arrival", value: formatDateTime(manifest.estimatedArrivalDate, manifest.estimatedArrivalTime))
                }
                
                // Crew
                Section("Crew") {
                    DetailRow(label: "PIC", value: manifest.pilotInCommand)
                    DetailRow(label: "License", value: manifest.pilotLicense)
                    
                    if let copilot = manifest.copilotName, !copilot.isEmpty {
                        DetailRow(label: "Co-Pilot", value: copilot)
                        if let license = manifest.copilotLicense {
                            DetailRow(label: "Co-Pilot License", value: license)
                        }
                    }
                }
                
                // Passengers
                Section("Passengers (\(passengers.count))") {
                    ForEach(passengers) { passenger in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(passenger.fullName)
                                .font(.headline)
                            Text("Passport: \(passenger.passportNumber) • \(getCountryName(passenger.nationality))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Purpose & Customs
                Section("Purpose & Customs") {
                    DetailRow(label: "Purpose", value: manifest.purposeOfFlight.rawValue)
                    DetailRow(label: "Origin", value: getCountryName(manifest.countryOfOrigin))
                    DetailRow(label: "Destination", value: getCountryName(manifest.destinationCountry))
                    DetailRow(label: "Goods to Declare", value: manifest.customsDeclarations ? "Yes" : "No")
                    
                    if manifest.customsDeclarations && !manifest.declarationDetails.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Declaration Details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(manifest.declarationDetails)
                        }
                    }
                }
                
                // Notes
                if !manifest.notes.isEmpty {
                    Section("Notes") {
                        Text(manifest.notes)
                    }
                }
                
                // Actions
                Section {
                    Button {
                        showingDocumentExport = true
                    } label: {
                        Label("Generate Documents", systemImage: "doc.text")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Manifest", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Manifest Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEdit = true
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                AddEditManifestView(manifest: manifest)
            }
            .sheet(isPresented: $showingDocumentExport) {
                DocumentExportView(manifest: manifest, passengers: passengers)
            }
            .confirmationDialog("Delete Manifest", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteManifest()
                }
            } message: {
                Text("Are you sure you want to delete this manifest? This action cannot be undone.")
            }
        }
    }
    
    private func deleteManifest() {
        Task {
            try? await cloudKitManager.deleteManifest(manifest)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date, _ time: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        timeFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        return "\(dateFormatter.string(from: date)) at \(timeFormatter.string(from: time))Z"
    }
    
    private func getCountryName(_ code: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forRegionCode: code) ?? code
    }
}

#Preview {
    AddEditManifestView(manifest: nil)
}
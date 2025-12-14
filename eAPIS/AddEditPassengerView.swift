//
//  AddEditPassengerView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import SwiftUI

struct AddEditPassengerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    
    let passenger: Passenger?
    @State private var editedPassenger: Passenger
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(passenger: Passenger?) {
        self.passenger = passenger
        _editedPassenger = State(initialValue: passenger ?? Passenger())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Personal Information
                Section("Personal Information") {
                    TextField("First Name", text: $editedPassenger.firstName)
                        .textContentType(.givenName)
                    
                    TextField("Middle Name (Optional)", text: $editedPassenger.middleName)
                        .textContentType(.middleName)
                    
                    TextField("Last Name", text: $editedPassenger.lastName)
                        .textContentType(.familyName)
                    
                    DatePicker("Date of Birth", selection: $editedPassenger.dateOfBirth, displayedComponents: .date)
                    
                    Picker("Gender", selection: $editedPassenger.gender) {
                        ForEach(Passenger.Gender.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                }
                
                // Travel Documents
                Section("Travel Documents") {
                    TextField("Passport Number", text: $editedPassenger.passportNumber)
                        .textContentType(.none)
                        .autocapitalization(.allCharacters)
                    
                    CountryPicker(title: "Passport Issuing Country", selection: $editedPassenger.passportIssuingCountry)
                    
                    DatePicker("Passport Expiration", selection: $editedPassenger.passportExpirationDate, displayedComponents: .date)
                    
                    if editedPassenger.passportExpiresWithin6Months {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Passport expires within 6 months")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    CountryPicker(title: "Nationality", selection: $editedPassenger.nationality)
                }
                
                // Address
                Section("Address") {
                    TextField("Street Address", text: $editedPassenger.streetAddress)
                        .textContentType(.streetAddressLine1)
                    
                    TextField("City", text: $editedPassenger.city)
                        .textContentType(.addressCity)
                    
                    TextField("State/Province", text: $editedPassenger.state)
                        .textContentType(.addressState)
                    
                    TextField("Postal Code", text: $editedPassenger.postalCode)
                        .textContentType(.postalCode)
                    
                    CountryPicker(title: "Country", selection: $editedPassenger.country)
                }
                
                // Contact Information
                Section("Contact Information") {
                    TextField("Phone Number", text: $editedPassenger.phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
                    TextField("Email", text: $editedPassenger.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                // Additional Information
                Section("Additional Information") {
                    TextField("Weight (lbs) - Optional", value: $editedPassenger.weight, format: .number)
                        .keyboardType(.numberPad)
                    
                    TextField("Frequent Flyer # - Optional", text: Binding(
                        get: { editedPassenger.frequentFlyerNumber ?? "" },
                        set: { editedPassenger.frequentFlyerNumber = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Known Traveler # - Optional", text: Binding(
                        get: { editedPassenger.knownTravelerNumber ?? "" },
                        set: { editedPassenger.knownTravelerNumber = $0.isEmpty ? nil : $0 }
                    ))
                    
                    Toggle("Favorite", isOn: $editedPassenger.isFavorite)
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $editedPassenger.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(passenger == nil ? "Add Passenger" : "Edit Passenger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePassenger()
                    }
                    .disabled(isSaving || !editedPassenger.isValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePassenger() {
        guard editedPassenger.isValid else {
            errorMessage = editedPassenger.validationErrors.joined(separator: "\n")
            showingError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                try await cloudKitManager.savePassenger(editedPassenger)
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

// MARK: - Country Picker
struct CountryPicker: View {
    let title: String
    @Binding var selection: String
    @State private var searchText = ""
    
    private var countries: [String: String] {
        let locale = Locale(identifier: "en_US")
        return Locale.isoRegionCodes.reduce(into: [:]) { dict, code in
            if let name = locale.localizedString(forRegionCode: code) {
                dict[code] = name
            }
        }
    }
    
    private var filteredCountries: [(code: String, name: String)] {
        let sorted = countries.sorted { $0.value < $1.value }
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationLink {
            List {
                ForEach(filteredCountries, id: \.code) { country in
                    Button {
                        selection = country.code
                    } label: {
                        HStack {
                            Text(country.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selection == country.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(countries[selection] ?? selection)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Passenger Detail View
struct PassengerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    
    let passenger: Passenger
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Personal Info
                Section("Personal Information") {
                    DetailRow(label: "Full Name", value: passenger.fullName)
                    DetailRow(label: "Date of Birth", value: formatDate(passenger.dateOfBirth))
                    DetailRow(label: "Age", value: "\(passenger.age) years")
                    DetailRow(label: "Gender", value: passenger.gender.displayName)
                }
                
                // Travel Documents
                Section("Travel Documents") {
                    DetailRow(label: "Passport Number", value: passenger.passportNumber)
                    DetailRow(label: "Issuing Country", value: getCountryName(passenger.passportIssuingCountry))
                    DetailRow(label: "Expiration", value: formatDate(passenger.passportExpirationDate))
                    DetailRow(label: "Nationality", value: getCountryName(passenger.nationality))
                    
                    if passenger.passportExpiresWithin6Months {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Passport expires soon")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Address
                Section("Address") {
                    DetailRow(label: "Street", value: passenger.streetAddress)
                    DetailRow(label: "City", value: passenger.city)
                    DetailRow(label: "State", value: passenger.state)
                    DetailRow(label: "Postal Code", value: passenger.postalCode)
                    DetailRow(label: "Country", value: getCountryName(passenger.country))
                }
                
                // Contact
                Section("Contact") {
                    if !passenger.phoneNumber.isEmpty {
                        DetailRow(label: "Phone", value: passenger.phoneNumber)
                    }
                    if !passenger.email.isEmpty {
                        DetailRow(label: "Email", value: passenger.email)
                    }
                }
                
                // Additional
                Section("Additional Information") {
                    if let weight = passenger.weight {
                        DetailRow(label: "Weight", value: "\(weight) lbs")
                    }
                    if let ffn = passenger.frequentFlyerNumber, !ffn.isEmpty {
                        DetailRow(label: "Frequent Flyer", value: ffn)
                    }
                    if let ktn = passenger.knownTravelerNumber, !ktn.isEmpty {
                        DetailRow(label: "Known Traveler", value: ktn)
                    }
                    if passenger.isFavorite {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Favorite")
                        }
                    }
                }
                
                // Notes
                if !passenger.notes.isEmpty {
                    Section("Notes") {
                        Text(passenger.notes)
                    }
                }
                
                // Actions
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Passenger")
                        }
                    }
                }
            }
            .navigationTitle("Passenger Details")
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
                AddEditPassengerView(passenger: passenger)
            }
            .confirmationDialog("Delete Passenger", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deletePassenger()
                }
            } message: {
                Text("Are you sure you want to delete \(passenger.fullName)? This action cannot be undone.")
            }
        }
    }
    
    private func deletePassenger() {
        Task {
            try? await cloudKitManager.deletePassenger(passenger)
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
    
    private func getCountryName(_ code: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forRegionCode: code) ?? code
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    AddEditPassengerView(passenger: nil)
}
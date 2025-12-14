//
//  CrewContactManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/5/25.
//

import Foundation
import Contacts
import SwiftUI
import MessageUI

    
    
// MARK: - Crew Contact Model
struct CrewContact: Identifiable, Codable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String?
    var company: String?
    var role: CrewRole?
    var dateAdded: Date
    
    // Computed property for full name display
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    // Computed property for formal display (Last, First)
    var formalName: String {
        "\(lastName), \(firstName)".trimmingCharacters(in: .whitespaces)
    }
    
    // Legacy name property for backward compatibility
    var name: String {
        get { fullName }
        set {
            let components = newValue.split(separator: " ", maxSplits: 1)
            firstName = String(components.first ?? "")
            lastName = components.count > 1 ? String(components[1]) : ""
        }
    }
    
    init(id: UUID = UUID(), firstName: String, lastName: String, email: String, phoneNumber: String? = nil, companyName: String? = nil, role: CrewRole? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.company = companyName
        self.role = role
        self.dateAdded = Date()
    }
    
    // Legacy init for backward compatibility
    init(id: UUID = UUID(), name: String, email: String, phoneNumber: String? = nil, companyName: String? = nil, role: CrewRole? = nil) {
        let components = name.split(separator: " ", maxSplits: 1)
        self.init(
            id: id,
            firstName: String(components.first ?? ""),
            lastName: components.count > 1 ? String(components[1]) : "",
            email: email,
            phoneNumber: phoneNumber,
            companyName: companyName,
            role: role
        )
    }
}

enum CrewRole: String, Codable, CaseIterable {
    case captain = "Captain"
    case firstOfficer = "First Officer"
    case loadMaster = "Load Master"
    case mechanic = "Mechanic"
    case dispatcher = "Dispatcher"
    
    var icon: String {
        switch self {
        case .captain: return "person.fill.viewfinder"
        case .firstOfficer: return "person.fill"
        case .loadMaster: return "shippingbox.fill"
        case .mechanic: return "wrench.and.screwdriver.fill"
        case .dispatcher: return "antenna.radiowaves.left.and.right"
        }
    }
}

// MARK: - Crew Contact Manager
class CrewContactManager: NSObject, ObservableObject {
    @Published var contacts: [CrewContact] = []
    
    private let userDefaults = UserDefaults.standard
    private let contactsKey = "crewContacts"
    
    override init() {
        super.init()
        loadContacts()
    }
    
    func addContact(_ contact: CrewContact) {
        contacts.append(contact)
        saveContacts()
    }
    
    func updateContact(_ contact: CrewContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            saveContacts()
        }
    }
    
    func deleteContact(_ contact: CrewContact) {
        contacts.removeAll { $0.id == contact.id }
        saveContacts()
    }
    
    func findContact(byName name: String) -> CrewContact? {
        contacts.first { $0.fullName.lowercased() == name.lowercased() }
    }
    
    func searchContacts(_ query: String, filterByCompany: String? = nil) -> [CrewContact] {
        var results = contacts
        
        // Filter by company if specified
        if let company = filterByCompany, !company.isEmpty {
            results = results.filter {
                $0.company?.lowercased() == company.lowercased()
            }
        }
        
        // Then filter by search query
        if !query.isEmpty {
            let lowercased = query.lowercased()
            results = results.filter {
                $0.firstName.lowercased().contains(lowercased) ||
                $0.lastName.lowercased().contains(lowercased) ||
                $0.fullName.lowercased().contains(lowercased) ||
                $0.email.lowercased().contains(lowercased) ||
                ($0.company?.lowercased().contains(lowercased) ?? false)
            }
        }
        
        // Sort by last name, then first name
        return results.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
    }
    
    func getUniqueCompanies() -> [String] {
        let companies = contacts.compactMap { $0.company }
        return Array(Set(companies)).sorted()
    }
    
    func getEmailsForCrew(_ crewMembers: [CrewMember]) -> [String] {
        var emails: [String] = []
        
        for member in crewMembers where !member.name.isEmpty {
            if let contact = findContact(byName: member.name) {
                emails.append(contact.email)
            }
        }
        
        return emails
    }
    
    // MARK: - NEW CSV IMPORT FUNCTION
    func importFromCSV(_ csvContent: String) throws -> Int {
        print("🔄 Starting CSV import...")
        
        let lines = csvContent.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            throw ContactImportError.importFailed
        }
        
        var importedCount = 0
        var header: [String] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Parse CSV line (handle quoted fields)
            let columns = parseCSVLine(trimmedLine)
            
            if index == 0 {
                // First line is header - detect column structure
                header = columns.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                print("📋 CSV Header detected: \(header)")
                continue
            }
            
            // Skip if not enough columns
            guard columns.count >= 3 else {
                print("⚠️ Skipping line \(index): insufficient columns")
                continue
            }
            
            do {
                let contact = try parseContactFromCSVLine(columns, header: header, lineNumber: index)
                
                // Check for duplicates
                if findContact(byName: contact.fullName) == nil {
                    addContact(contact)
                    importedCount += 1
                    print("✅ Imported: \(contact.fullName)")
                } else {
                    print("⏭️ Skipped duplicate: \(contact.fullName)")
                }
            } catch {
                print("❌ Error parsing line \(index): \(error)")
                continue
            }
        }
        
        print("🎉 CSV import complete: \(importedCount) contacts imported")
        return importedCount
    }
    
    private func parseContactFromCSVLine(_ columns: [String], header: [String], lineNumber: Int) throws -> CrewContact {
        // Auto-detect column structure based on header and content
        var firstName = ""
        var lastName = ""
        var email = ""
        var phoneNumber: String? = nil
        var company: String? = nil
        var role: CrewRole? = nil
        
        // Try to map columns intelligently
        if header.contains("last name") || header.contains("lastname") {
            // Standard format: Last Name, First Name, Email, Phone, Company, Role
            if columns.count >= 6 {
                lastName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                firstName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                email = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                phoneNumber = cleanPhoneNumber(columns[3])
                company = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                role = parseCrewRole(columns[5])
            } else if columns.count >= 3 {
                lastName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                firstName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                email = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                if columns.count > 3 { phoneNumber = cleanPhoneNumber(columns[3]) }
                if columns.count > 4 { company = columns[4].trimmingCharacters(in: .whitespacesAndNewlines) }
                if columns.count > 5 { role = parseCrewRole(columns[5]) }
            }
        } else if header.contains("full name") || header.contains("name") {
            // Full name format: Full Name, Email, Phone, Company, Role
            if columns.count >= 5 {
                let nameComponents = columns[0].split(separator: " ", maxSplits: 1)
                firstName = String(nameComponents.first ?? "")
                lastName = nameComponents.count > 1 ? String(nameComponents[1]) : ""
                email = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                phoneNumber = cleanPhoneNumber(columns[2])
                company = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                role = parseCrewRole(columns[4])
            } else if columns.count >= 2 {
                let nameComponents = columns[0].split(separator: " ", maxSplits: 1)
                firstName = String(nameComponents.first ?? "")
                lastName = nameComponents.count > 1 ? String(nameComponents[1]) : ""
                email = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if columns.count > 2 { phoneNumber = cleanPhoneNumber(columns[2]) }
                if columns.count > 3 { company = columns[3].trimmingCharacters(in: .whitespacesAndNewlines) }
                if columns.count > 4 { role = parseCrewRole(columns[4]) }
            }
        } else {
            // Fallback: assume order based on content detection
            if columns.count >= 3 {
                // Try to detect email column
                var emailIndex = -1
                for (i, column) in columns.enumerated() {
                    if column.contains("@") && column.contains(".") {
                        emailIndex = i
                        break
                    }
                }
                
                if emailIndex == 2 && columns.count >= 3 {
                    // Likely: LastName, FirstName, Email, Phone, Company, Role
                    lastName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    firstName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    email = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    if columns.count > 3 { phoneNumber = cleanPhoneNumber(columns[3]) }
                    if columns.count > 4 { company = columns[4].trimmingCharacters(in: .whitespacesAndNewlines) }
                    if columns.count > 5 { role = parseCrewRole(columns[5]) }
                } else if emailIndex == 1 && columns.count >= 2 {
                    // Likely: FullName, Email, Phone, Company, Role
                    let nameComponents = columns[0].split(separator: " ", maxSplits: 1)
                    firstName = String(nameComponents.first ?? "")
                    lastName = nameComponents.count > 1 ? String(nameComponents[1]) : ""
                    email = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if columns.count > 2 { phoneNumber = cleanPhoneNumber(columns[2]) }
                    if columns.count > 3 { company = columns[3].trimmingCharacters(in: .whitespacesAndNewlines) }
                    if columns.count > 4 { role = parseCrewRole(columns[4]) }
                }
            }
        }
        
        // Validation
        guard !firstName.isEmpty || !lastName.isEmpty else {
            throw ContactImportError.importFailed
        }
        
        guard !email.isEmpty, email.contains("@") else {
            throw ContactImportError.importFailed
        }
        
        return CrewContact(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber?.isEmpty == false ? phoneNumber : nil,
            companyName: company?.isEmpty == false ? company : nil,
            role: role
        )
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last column
        columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return columns
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String? {
        let cleaned = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
    
    private func parseCrewRole(_ roleString: String) -> CrewRole? {
        let role = roleString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch role {
        case "captain", "cpt", "ca":
            return .captain
        case "first officer", "fo", "first":
            return .firstOfficer
        case "load master", "loadmaster", "lm", "load":
            return .loadMaster
        case "mechanic", "mech":
            return .mechanic
        case "dispatcher", "dispatch":
            return .dispatcher
        default:
            return nil
        }
    }
    
    // MARK: - CSV EXPORT FUNCTION
    func exportCSV() -> String {
        var csvContent = "Last Name,First Name,Email,Phone Number,Company,Crew Position\n"
        
        for contact in contacts.sorted(by: { $0.lastName.lowercased() < $1.lastName.lowercased() }) {
            let lastName = escapeCSVField(contact.lastName)
            let firstName = escapeCSVField(contact.firstName)
            let email = escapeCSVField(contact.email)
            let phone = escapeCSVField(contact.phoneNumber ?? "")
            let company = escapeCSVField(contact.company ?? "")
            let role = escapeCSVField(contact.role?.rawValue ?? "")
            
            csvContent += "\(lastName),\(firstName),\(email),\(phone),\(company),\(role)\n"
        }
        
        return csvContent
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // MARK: - Clear All Contacts
    func clearAllContacts() {
        contacts.removeAll()
        saveContacts()
        print("🗑️ All contacts cleared")
    }
    
    func importFromPhoneContacts() async throws -> [CrewContact] {
        let store = CNContactStore()
        
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        if status == .notDetermined {
            try await store.requestAccess(for: .contacts)
        }
        
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            throw ContactImportError.accessDenied
        }
        
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactOrganizationNameKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var importedContacts: [CrewContact] = []
        
        try store.enumerateContacts(with: request) { contact, _ in
            guard let emailAddress = contact.emailAddresses.first?.value as String? else {
                return
            }
            
            let firstName = contact.givenName
            let lastName = contact.familyName
            let phone = contact.phoneNumbers.first?.value.stringValue
            let companyName = contact.organizationName.isEmpty ? nil : contact.organizationName
            
            let crewContact = CrewContact(
                firstName: firstName,
                lastName: lastName,
                email: emailAddress,
                phoneNumber: phone,
                companyName: companyName,
                role: nil
            )
            
            importedContacts.append(crewContact)
        }
        
        return importedContacts
    }
    
    func saveContacts() {
        if let encoded = try? JSONEncoder().encode(contacts) {
            userDefaults.set(encoded, forKey: contactsKey)
        }
    }
    
    private func loadContacts() {
        guard let data = userDefaults.data(forKey: contactsKey),
              let decoded = try? JSONDecoder().decode([CrewContact].self, from: data) else {
            return
        }
        contacts = decoded
    }
}

enum ContactImportError: LocalizedError {
    case accessDenied
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to contacts was denied. Please enable in Settings > Privacy > Contacts."
        case .importFailed:
            return "Failed to import contacts. Please try again."
        }
    }
}

// MARK: - Contact Picker View with CSV Import Option
struct CrewContactPickerView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Binding var selectedName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingImport = false
    @State private var showingAdd = false
    @State private var showingCSVImport = false
    @State private var selectedCompany: String? = nil
    @State private var selectedRole: CrewRole? = nil
    @State private var showingClearConfirmation = false
    
    var filteredContacts: [CrewContact] {
        var results = contactManager.searchContacts(searchText, filterByCompany: selectedCompany)
        
        // Filter by role if selected
        if let role = selectedRole {
            results = results.filter { $0.role == role }
        }
        
        return results
    }
    
    // Group contacts by role for sectioned display
    var contactsByRole: [(CrewRole?, [CrewContact])] {
        let grouped = Dictionary(grouping: filteredContacts) { $0.role }
        let sortedKeys = grouped.keys.sorted { role1, role2 in
            guard let r1 = role1, let r2 = role2 else {
                return role1 != nil // Put nil (no role) at end
            }
            return r1.rawValue < r2.rawValue
        }
        return sortedKeys.map { ($0, grouped[$0] ?? []) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchSection
                roleFilterSection
                companyFilterSection
                contactsContentSection
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Select Crew Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    menuButton
                }
            }
        }
        .alert("Import Contacts", isPresented: $showingImport) {
            Button("Import") {
                Task { await importContacts() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Import contacts from your phone? Only contacts with email addresses will be imported.")
        }
        .sheet(isPresented: $showingAdd) {
            AddCrewContactView(contactManager: contactManager)
        }
        .sheet(isPresented: $showingCSVImport) {
            CSVImportView(contactManager: contactManager)
        }
    }
    
    // MARK: - View Components
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var roleFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { selectedRole = nil }) {
                    Text("All Crew")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedRole == nil ? LogbookTheme.accentGreen : LogbookTheme.fieldBackground)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                ForEach(CrewRole.allCases, id: \.self) { role in
                    Button(action: { selectedRole = role }) {
                        HStack(spacing: 4) {
                            Image(systemName: role.icon)
                                .font(.caption2)
                            Text(role.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedRole == role ? LogbookTheme.accentBlue : LogbookTheme.fieldBackground)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var companyFilterSection: some View {
        if !contactManager.getUniqueCompanies().isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    allCompaniesButton
                    
                    ForEach(contactManager.getUniqueCompanies(), id: \.self) { company in
                        companyFilterButton(company: company)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var allCompaniesButton: some View {
        Button(action: { selectedCompany = nil }) {
            Text("All")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCompany == nil ? LogbookTheme.accentBlue : LogbookTheme.fieldBackground)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
    }
    
    private func companyFilterButton(company: String) -> some View {
        Button(action: { selectedCompany = company }) {
            Text(company)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCompany == company ? LogbookTheme.accentBlue : LogbookTheme.fieldBackground)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private var contactsContentSection: some View {
        if filteredContacts.isEmpty {
            emptyStateView
        } else {
            contactsListBySections
        }
    }
    
    private var contactsListBySections: some View {
        List {
            ForEach(contactsByRole, id: \.0) { role, contacts in
                if !contacts.isEmpty {
                    Section(header: sectionHeader(for: role)) {
                        ForEach(contacts) { contact in
                            contactRow(contact: contact)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let contact = contacts[index]
                                contactManager.deleteContact(contact)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(LogbookTheme.navy)
    }
    
    private func sectionHeader(for role: CrewRole?) -> some View {
        HStack {
            if let role = role {
                Image(systemName: role.icon)
                    .foregroundColor(LogbookTheme.accentBlue)
                Text(role.rawValue + "s")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            } else {
                Text("Unassigned Role")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(LogbookTheme.navyLight)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(getEmptyStateTitle())
                .font(.headline)
                .foregroundColor(.white)
            
            Text(getEmptyStateSubtitle())
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if selectedCompany == nil && selectedRole == nil {
                VStack(spacing: 12) {
                    Button(action: { showingCSVImport = true }) {
                        Label("Import from CSV", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .padding()
                            .background(LogbookTheme.accentGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { showingAdd = true }) {
                        Label("Add Manually", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(LogbookTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LogbookTheme.navy)
    }
    
    private func getEmptyStateTitle() -> String {
        if let role = selectedRole {
            return "No \(role.rawValue)s"
        } else if let company = selectedCompany {
            return "No contacts at \(company)"
        } else {
            return "No Crew Contacts"
        }
    }
    
    private func getEmptyStateSubtitle() -> String {
        if selectedRole != nil || selectedCompany != nil {
            return "Try selecting different filters or add contacts manually"
        } else {
            return "Import your CSV file or add contacts manually"
        }
    }
    
    // MARK: - Enhanced Contact Row with Phone Actions
    private func contactRow(contact: CrewContact) -> some View {
        Button(action: {
            selectedName = contact.fullName
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.fullName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(contact.email)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let company = contact.company {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                    
                    // Phone number display
                    if let phone = contact.phoneNumber, !phone.isEmpty {
                        Text(formatPhoneNumber(phone))
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
                
                Spacer()
                
                // Phone action buttons
                if let phone = contact.phoneNumber, !phone.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: { callContact(phone) }) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { textContact(phone) }) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if let role = contact.role {
                    Image(systemName: role.icon)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .listRowBackground(LogbookTheme.navyLight)
    }
    
    // MARK: - Phone Helper Functions
    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter(\.isWholeNumber)
        
        guard digits.count == 10 else { return number }
        
        let areaCode = String(digits.prefix(3))
        let exchange = String(digits.dropFirst(3).prefix(3))
        let number = String(digits.suffix(4))
        
        return "(\(areaCode)) \(exchange)-\(number)"
    }
    
    private func callContact(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.filter(\.isWholeNumber)
        print("Calling: \(cleanedNumber)")
        
        if let url = URL(string: "tel:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func textContact(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.filter(\.isWholeNumber)
        print("Texting: \(cleanedNumber)")
        
        // Try different SMS URL formats
        let smsURLs = [
            "sms:\(cleanedNumber)",
            "sms://\(cleanedNumber)",
            "sms:+1\(cleanedNumber)"
        ]
        
        for smsURL in smsURLs {
            if let url = URL(string: smsURL), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // Fallback: Open Messages app without number
        if let url = URL(string: "sms:") {
            UIApplication.shared.open(url)
        }
    }
    
    private var menuButton: some View {
        Menu {
            Button(action: { showingCSVImport = true }) {
                Label("Import from CSV", systemImage: "doc.badge.plus")
            }
            
            Button(action: { showingImport = true }) {
                Label("Import from Phone Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            
            Button(action: { showingAdd = true }) {
                Label("Add Manually", systemImage: "plus.circle")
            }
            
            if !contactManager.contacts.isEmpty {
                Divider()
                
                Button(action: exportContacts) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive, action: {
                                showingClearConfirmation = true
                            }) {
                                Label("Clear All Contacts", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .alert("Clear All Contacts", isPresented: $showingClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete All", role: .destructive) {
                            contactManager.clearAllContacts()
                        }
                    } message: {
                        Text("Are you sure you want to delete all \(contactManager.contacts.count) contacts? This action cannot be undone.")
                    }
                }
    
    private func exportContacts() {
        let csvContent = contactManager.exportCSV()
        let activityViewController = UIActivityViewController(activityItems: [csvContent], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
    
    private func importContacts() async {
        do {
            let imported = try await contactManager.importFromPhoneContacts()
            
            await MainActor.run {
                for contact in imported {
                    if contactManager.findContact(byName: contact.fullName) == nil {
                        contactManager.addContact(contact)
                    }
                }
                
                print("✅ Imported \(imported.count) contacts")
            }
        } catch ContactImportError.accessDenied {
            print("❌ Contact access denied - check Settings → ProPilot → Contacts")
        } catch {
            print("❌ Import error: \(error)")
        }
    }
}

// MARK: - CSV Import View
struct CSVImportView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var csvText = ""
    @State private var showingDocumentPicker = false
    @State private var importedCount = 0
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Contacts from CSV")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Expected format:\nLast Name, First Name, Email, Phone Number, Company, Crew Position")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CSV Content:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextEditor(text: $csvText)
                        .frame(minHeight: 200)
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button(action: { showingDocumentPicker = true }) {
                    Label("Choose CSV File", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LogbookTheme.accentGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                if !csvText.isEmpty {
                    Button(action: importCSV) {
                        Text("Import Contacts")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LogbookTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadCSVFile(from: url)
                }
            case .failure(let error):
                errorMessage = "Failed to load file: \(error.localizedDescription)"
                showingError = true
            }
        }
        .alert("Import Successful", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Successfully imported \(importedCount) contacts!")
        }
        .alert("Import Failed", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCSVFile(from url: URL) {
        // Start accessing security-scoped resource
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            // Stop accessing when done
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            csvText = content
            print("✅ Successfully loaded CSV file from: \(url.lastPathComponent)")
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)\n\nPlease make sure the file is accessible and try again."
            showingError = true
            print("❌ Failed to load CSV: \(error)")
        }
    }
    
    private func importCSV() {
        do {
            importedCount = try contactManager.importFromCSV(csvText)
            showingSuccess = true
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}


// MARK: - Message Composer for Group Texts
struct MessageComposer: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let recipients: [String]
    let body: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposer
        
        init(_ parent: MessageComposer) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            parent.isPresented = false
        }
    }
}

extension CrewContactManager: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        print("Message composer finished with result: \(result.rawValue)")
        
        switch result {
        case .cancelled:
            print("User cancelled message")
        case .sent:
            print("Message sent successfully")
        case .failed:
            print("Message failed to send")
        @unknown default:
            print("Unknown message result")
        }
        
        controller.dismiss(animated: true)
    }
}

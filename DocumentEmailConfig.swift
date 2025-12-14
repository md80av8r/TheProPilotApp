//
//  DocumentEmailSettings.swift
//  ProPilotApp
//
//  Per-document-type email configuration with contact autocomplete
//

import SwiftUI

// MARK: - Email Contact Store (Saved/Recent Emails)
class EmailContactStore: ObservableObject {
    static let shared = EmailContactStore()
    
    @Published var savedEmails: [SavedEmailContact] = []
    
    private let storageKey = "savedEmailContacts_v1"
    
    struct SavedEmailContact: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var name: String
        var email: String
        var category: String  // "crew", "dispatch", "company", "other"
        var lastUsed: Date = Date()
        
        var displayName: String {
            name.isEmpty ? email : "\(name) <\(email)>"
        }
    }
    
    init() {
        loadContacts()
    }
    
    // MARK: - Add/Update Contact
    func addOrUpdateContact(name: String = "", email: String, category: String = "other") {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else { return }
        
        if let index = savedEmails.firstIndex(where: { $0.email.lowercased() == trimmedEmail }) {
            // Update existing
            savedEmails[index].lastUsed = Date()
            if !name.isEmpty {
                savedEmails[index].name = name
            }
        } else {
            // Add new
            let contact = SavedEmailContact(name: name, email: trimmedEmail, category: category)
            savedEmails.append(contact)
        }
        
        saveContacts()
    }
    
    // MARK: - Search Contacts
    func searchContacts(query: String) -> [SavedEmailContact] {
        guard !query.isEmpty else {
            return savedEmails.sorted { $0.lastUsed > $1.lastUsed }
        }
        
        let lowercaseQuery = query.lowercased()
        return savedEmails.filter {
            $0.email.lowercased().contains(lowercaseQuery) ||
            $0.name.lowercased().contains(lowercaseQuery)
        }
        .sorted { $0.lastUsed > $1.lastUsed }
    }
    
    // MARK: - Get Contacts by Category
    func contacts(forCategory category: String) -> [SavedEmailContact] {
        savedEmails.filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }
    
    // MARK: - Import from Crew Manager
    func importFromCrewManager(_ crewManager: CrewContactManager) {
        for contact in crewManager.contacts {
            if !contact.email.isEmpty {
                addOrUpdateContact(name: contact.name, email: contact.email, category: "crew")
            }
        }
    }
    
    // MARK: - Delete Contact
    func deleteContact(_ contact: SavedEmailContact) {
        savedEmails.removeAll { $0.id == contact.id }
        saveContacts()
    }
    
    // MARK: - Persistence
    private func saveContacts() {
        if let data = try? JSONEncoder().encode(savedEmails) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SavedEmailContact].self, from: data) {
            savedEmails = decoded
        }
    }
}

// MARK: - Email Autocomplete Field
struct EmailAutocompleteField: View {
    let label: String
    @Binding var email: String
    var placeholder: String = "email@company.com"
    var onEmailSelected: ((String) -> Void)? = nil
    
    @StateObject private var contactStore = EmailContactStore.shared
    @State private var showingSuggestions = false
    @State private var showingContactPicker = false
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    private var suggestions: [EmailContactStore.SavedEmailContact] {
        contactStore.searchContacts(query: email)
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onChange(of: email) { oldValue, newValue in
                        showingSuggestions = isFocused && !newValue.isEmpty && !suggestions.isEmpty
                    }
                    .onChange(of: isFocused) { oldValue, focused in
                        if focused && !email.isEmpty {
                            showingSuggestions = !suggestions.isEmpty
                        } else {
                            // Delay hiding to allow tap on suggestion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showingSuggestions = false
                            }
                        }
                    }
                // Contact picker button
                Button(action: { showingContactPicker = true }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            
            // Suggestions dropdown
            if showingSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { contact in
                        Button(action: {
                            email = contact.email
                            showingSuggestions = false
                            isFocused = false
                            onEmailSelected?(contact.email)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if !contact.name.isEmpty {
                                        Text(contact.name)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                    }
                                    Text(contact.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Category badge
                                Text(contact.category.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor(contact.category).opacity(0.2))
                                    .foregroundColor(categoryColor(contact.category))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if contact.id != suggestions.last?.id {
                            Divider()
                        }
                    }
                }
                .background(LogbookTheme.cardBackground)
                .cornerRadius(8)
                .shadow(radius: 4)
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            EmailContactPickerView(
                selectedEmail: $email,
                onSelect: { selectedEmail in
                    email = selectedEmail
                    onEmailSelected?(selectedEmail)
                }
            )
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "crew": return .blue
        case "dispatch": return .orange
        case "company": return .green
        default: return .gray
        }
    }
}

// MARK: - Email Contact Picker View
struct EmailContactPickerView: View {
    @Binding var selectedEmail: String
    var onSelect: ((String) -> Void)? = nil
    
    @StateObject private var contactStore = EmailContactStore.shared
    @StateObject private var crewManager = CrewContactManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var newContactName = ""
    @State private var newContactEmail = ""
    @State private var newContactCategory = "other"
    
    private var filteredContacts: [EmailContactStore.SavedEmailContact] {
        contactStore.searchContacts(query: searchText)
    }
    
    private var crewEmails: [EmailContactStore.SavedEmailContact] {
        crewManager.contacts.compactMap { crew in
            guard !crew.email.isEmpty else { return nil }
            return EmailContactStore.SavedEmailContact(
                name: crew.name,
                email: crew.email,
                category: "crew"
            )
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Search bar
                Section {
                    TextField("Search contacts...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                
                // Crew Contacts
                if !crewEmails.isEmpty && searchText.isEmpty {
                    Section(header: Text("Crew Contacts")) {
                        ForEach(crewEmails) { contact in
                            contactRow(contact)
                        }
                    }
                }
                
                // Saved Contacts
                if !filteredContacts.isEmpty {
                    Section(header: Text(searchText.isEmpty ? "Saved Contacts" : "Search Results")) {
                        ForEach(filteredContacts) { contact in
                            contactRow(contact)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                contactStore.deleteContact(filteredContacts[index])
                            }
                        }
                    }
                }
                
                // Add New Contact
                Section {
                    Button(action: { showingAddContact = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Contact")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Import from Crew
                if crewEmails.count > contactStore.contacts(forCategory: "crew").count {
                    Section {
                        Button(action: {
                            contactStore.importFromCrewManager(crewManager)
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Import All Crew Contacts")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddContact) {
            addContactSheet
        }
    }
    
    private func contactRow(_ contact: EmailContactStore.SavedEmailContact) -> some View {
        Button(action: {
            selectedEmail = contact.email
            onSelect?(contact.email)
            
            // Save to recent
            contactStore.addOrUpdateContact(
                name: contact.name,
                email: contact.email,
                category: contact.category
            )
            
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !contact.name.isEmpty {
                        Text(contact.name)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    Text(contact.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var addContactSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Info")) {
                    TextField("Name (optional)", text: $newContactName)
                    
                    TextField("Email", text: $newContactEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $newContactCategory) {
                        Text("Crew").tag("crew")
                        Text("Dispatch").tag("dispatch")
                        Text("Company").tag("company")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddContact = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        contactStore.addOrUpdateContact(
                            name: newContactName,
                            email: newContactEmail,
                            category: newContactCategory
                        )
                        newContactName = ""
                        newContactEmail = ""
                        newContactCategory = "other"
                        showingAddContact = false
                    }
                    .disabled(newContactEmail.isEmpty || !newContactEmail.contains("@"))
                }
            }
        }
    }
}

// MARK: - Document Email Configuration
struct DocumentEmailConfig: Codable, Equatable {
    var toEmail: String = ""
    var ccEmail: String = ""
    var subjectFields: [EmailField] = []
    var bodyFields: [EmailField] = []
    var autoIncludeCrewCC: Bool = false
    
    func generateSubject(for trip: Trip, documentType: TripDocumentType) -> String {
        // Always start with Trip Number and Document Type
        var subjectParts: [String] = ["Trip \(trip.tripNumber)", documentType.rawValue]
        
        // Add any additional selected fields
        let additionalParts = subjectFields.compactMap { field -> String? in
            // Skip tripNumber since we already added it
            if field == .tripNumber { return nil }
            let value = field.getValue(from: trip)
            return value.isEmpty || value == "N/A" ? nil : value
        }
        
        subjectParts.append(contentsOf: additionalParts)
        
        return subjectParts.joined(separator: " - ")
    }
    
    func generateBody(for trip: Trip, documentType: TripDocumentType, fileName: String, fileSize: String? = nil) -> String {
        var body = ""
        
        body += "\(documentType.rawValue.uppercased())\n"
        body += String(repeating: "=", count: documentType.rawValue.count) + "\n\n"
        
        for field in bodyFields {
            let label = field.rawValue
            let value = field.getValue(from: trip)
            if !value.isEmpty && value != "N/A" {
                body += "\(label): \(value)\n"
            }
        }
        
        body += "\n"
        body += "Attached: \(fileName)\n"
        if let size = fileSize {
            body += "Size: \(size)\n"
        }
        
        body += "\n---\n"
        body += "Sent from ProPilot App\n"
        
        return body
    }
}

// MARK: - Document Email Settings Store
class DocumentEmailSettingsStore: ObservableObject {
    static let shared = DocumentEmailSettingsStore()
    
    @Published var configs: [TripDocumentType: DocumentEmailConfig] = [:]
    @Published var globalCCEmail: String = ""
    @Published var alwaysAddGlobalCC: Bool = false
    @Published var documentTypeOrder: [TripDocumentType] = []  // Custom order
    
    private let defaults = UserDefaults.standard
    private let storageKey = "documentEmailConfigs_v3"
    private let globalCCKey = "documentEmailGlobalCC"
    private let globalCCEnabledKey = "documentEmailGlobalCCEnabled"
    private let orderKey = "documentTypeOrder_v1"
    
    // Get ordered document types (custom order or default)
    var orderedDocumentTypes: [TripDocumentType] {
        if documentTypeOrder.isEmpty {
            return TripDocumentType.allCases.map { $0 }
        }
        // Ensure all types are included (in case new ones were added)
        var ordered = documentTypeOrder.filter { TripDocumentType.allCases.contains($0) }
        for docType in TripDocumentType.allCases {
            if !ordered.contains(docType) {
                ordered.append(docType)
            }
        }
        return ordered
    }
    
    func updateOrder(_ newOrder: [TripDocumentType]) {
        documentTypeOrder = newOrder
        saveOrder()
    }
    
    private func saveOrder() {
        let rawValues = documentTypeOrder.map { $0.rawValue }
        defaults.set(rawValues, forKey: orderKey)
    }
    
    private func loadOrder() {
        if let rawValues = defaults.stringArray(forKey: orderKey) {
            documentTypeOrder = rawValues.compactMap { TripDocumentType(rawValue: $0) }
        }
    }
    
    init() {
        loadConfigs()
        loadOrder()
    }
    
    func getConfig(for documentType: TripDocumentType) -> DocumentEmailConfig {
        if let config = configs[documentType] {
            return config
        }
        return createDefaultConfig(for: documentType)
    }
    
    func setConfig(_ config: DocumentEmailConfig, for documentType: TripDocumentType) {
        configs[documentType] = config
        saveConfigs()
        
        // Save email to contacts for autocomplete
        if !config.toEmail.isEmpty {
            EmailContactStore.shared.addOrUpdateContact(email: config.toEmail, category: "company")
        }
    }
    
    private func createDefaultConfig(for documentType: TripDocumentType) -> DocumentEmailConfig {
        switch documentType {
        case .fuelReceipt:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .aircraft, .departure, .arrival],
                bodyFields: [.tripNumber, .aircraft, .date, .departure, .arrival, .blockTime]
            )
        case .customsGendec:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .aircraft, .arrival],
                bodyFields: [.tripNumber, .aircraft, .date, .departure, .arrival, .crew]
            )
        case .groundHandler:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .arrival],
                bodyFields: [.tripNumber, .aircraft, .arrival, .blockTime]
            )
        case .shipper:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .departure, .arrival],
                bodyFields: [.tripNumber, .aircraft, .departure, .arrival]
            )
        case .reweighForm:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .aircraft],
                bodyFields: [.tripNumber, .aircraft, .date]
            )
        case .loadManifest:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .departure, .arrival],
                bodyFields: [.tripNumber, .aircraft, .date, .departure, .arrival]
            )
        case .weatherBriefing:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .departure, .arrival, .date],
                bodyFields: [.tripNumber, .departure, .arrival, .date]
            )
        case .logPage:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .aircraft, .date],
                bodyFields: [.tripNumber, .aircraft, .date, .route, .crew, .blockTime],
                autoIncludeCrewCC: true
            )
        case .other:
            return DocumentEmailConfig(
                subjectFields: [.tripNumber, .aircraft],
                bodyFields: [.tripNumber, .aircraft, .date]
            )
        }
    }
    
    func getToEmail(for documentType: TripDocumentType) -> String {
        return getConfig(for: documentType).toEmail
    }
    
    func getCCEmails(for documentType: TripDocumentType, trip: Trip? = nil, crewManager: CrewContactManager? = nil) -> [String] {
        var emails: [String] = []
        let config = getConfig(for: documentType)
        
        if !config.ccEmail.isEmpty {
            emails.append(contentsOf: parseEmails(config.ccEmail))
        }
        
        if alwaysAddGlobalCC && !globalCCEmail.isEmpty {
            emails.append(contentsOf: parseEmails(globalCCEmail))
        }
        
        if config.autoIncludeCrewCC, let trip = trip, let crewManager = crewManager {
            let crewEmails = crewManager.getEmailsForCrew(trip.crew)
            emails.append(contentsOf: crewEmails)
        }
        
        return emails.unique()
    }
    
    private func parseEmails(_ emailString: String) -> [String] {
        return emailString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.contains("@") }
    }
    
    func saveConfigs() {
        var codableConfigs: [String: DocumentEmailConfig] = [:]
        for (key, value) in configs {
            codableConfigs[key.rawValue] = value
        }
        
        if let data = try? JSONEncoder().encode(codableConfigs) {
            defaults.set(data, forKey: storageKey)
        }
        
        defaults.set(globalCCEmail, forKey: globalCCKey)
        defaults.set(alwaysAddGlobalCC, forKey: globalCCEnabledKey)
    }
    
    private func loadConfigs() {
        globalCCEmail = defaults.string(forKey: globalCCKey) ?? ""
        alwaysAddGlobalCC = defaults.bool(forKey: globalCCEnabledKey)
        
        guard let data = defaults.data(forKey: storageKey),
              let codableConfigs = try? JSONDecoder().decode([String: DocumentEmailConfig].self, from: data) else {
            return
        }
        
        for (key, value) in codableConfigs {
            if let docType = TripDocumentType(rawValue: key) {
                configs[docType] = value
            }
        }
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Document Email Settings View
struct DocumentEmailSettingsView: View {
    @StateObject private var settings = DocumentEmailSettingsStore.shared
    @StateObject private var contactStore = EmailContactStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingManageContacts = false
    @State private var documentTypes: [TripDocumentType] = []
    @State private var isReordering = false
    
    var body: some View {
        NavigationView {
            List {
                // Manage Contacts
                Section {
                    Button(action: { showingManageContacts = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading) {
                                Text("Manage Contacts")
                                Text("\(contactStore.savedEmails.count) saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Quick Access")
                } footer: {
                    Text("Add contacts for faster email autofill")
                }
                
                // Document Types with reordering
                Section {
                    ForEach(documentTypes, id: \.self) { docType in
                        if isReordering {
                            // Reorder mode - show drag handles, no navigation
                            HStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                
                                DocumentTypeEmailRow(
                                    documentType: docType,
                                    config: settings.getConfig(for: docType)
                                )
                            }
                        } else {
                            // Normal mode - navigation enabled
                            NavigationLink {
                                DocumentTypeEmailConfigView(
                                    documentType: docType,
                                    settings: settings
                                )
                            } label: {
                                DocumentTypeEmailRow(
                                    documentType: docType,
                                    config: settings.getConfig(for: docType)
                                )
                            }
                        }
                    }
                    .onMove { from, to in
                        documentTypes.move(fromOffsets: from, toOffset: to)
                        settings.updateOrder(documentTypes)
                    }
                } header: {
                    HStack {
                        Text("Document Types")
                        Spacer()
                        Button(isReordering ? "Done" : "Reorder") {
                            withAnimation {
                                isReordering.toggle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                } footer: {
                    Text(isReordering ?
                         "Drag ≡ to reorder document types in the picker." :
                         "Tap a document type to configure its email.")
                }
                .environment(\.editMode, isReordering ? .constant(.active) : .constant(.inactive))
                
                // Global CC
                Section {
                    Toggle(isOn: $settings.alwaysAddGlobalCC) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            
                            Text("Always CC Additional Email")
                        }
                    }
                    .tint(.blue)
                    .onChange(of: settings.alwaysAddGlobalCC) { _, _ in
                        settings.saveConfigs()
                    }
                    
                    if settings.alwaysAddGlobalCC {
                        EmailAutocompleteField(
                            label: "Global CC Email",
                            email: $settings.globalCCEmail,
                            placeholder: "dispatch@company.com"
                        )
                        .onChange(of: settings.globalCCEmail) { _, _ in
                            settings.saveConfigs()
                        }
                        
                        Text("Separate multiple emails with commas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Global CC")
                } footer: {
                    Text("This email will be CC'd on ALL scanned documents.")
                }
            }
            .navigationTitle("Document Emails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingManageContacts) {
            ManageContactsView()
        }
        .onAppear {
            // Load document types in saved order
            documentTypes = settings.orderedDocumentTypes
        }
    }
}

// MARK: - Manage Contacts View
struct ManageContactsView: View {
    @StateObject private var contactStore = EmailContactStore.shared
    @StateObject private var crewManager = CrewContactManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddContact = false
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var newCategory = "other"
    
    var body: some View {
        NavigationView {
            List {
                // Crew section
                if !crewManager.contacts.isEmpty {
                    Section(header: Text("Crew Contacts")) {
                        ForEach(crewManager.contacts.filter { !$0.email.isEmpty }) { crew in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(crew.name)
                                        .font(.body)
                                    Text(crew.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Crew")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Button(action: {
                            contactStore.importFromCrewManager(crewManager)
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Import All to Saved Contacts")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Saved contacts by category
                ForEach(["dispatch", "company", "other"], id: \.self) { category in
                    let contacts = contactStore.contacts(forCategory: category)
                    if !contacts.isEmpty {
                        Section(header: Text(category.capitalized)) {
                            ForEach(contacts) { contact in
                                HStack {
                                    VStack(alignment: .leading) {
                                        if !contact.name.isEmpty {
                                            Text(contact.name)
                                                .font(.body)
                                        }
                                        Text(contact.email)
                                            .font(contact.name.isEmpty ? .body : .caption)
                                            .foregroundColor(contact.name.isEmpty ? .primary : .secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .onDelete { indexSet in
                                indexSet.forEach { index in
                                    contactStore.deleteContact(contacts[index])
                                }
                            }
                        }
                    }
                }
                
                // Add new
                Section {
                    Button(action: { showingAddContact = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Contact")
                        }
                    }
                }
            }
            .navigationTitle("Manage Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddContact) {
            NavigationView {
                Form {
                    Section(header: Text("Contact Info")) {
                        TextField("Name (optional)", text: $newName)
                        TextField("Email", text: $newEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    Section(header: Text("Category")) {
                        Picker("Category", selection: $newCategory) {
                            Text("Dispatch").tag("dispatch")
                            Text("Company").tag("company")
                            Text("Other").tag("other")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle("Add Contact")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { showingAddContact = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            contactStore.addOrUpdateContact(name: newName, email: newEmail, category: newCategory)
                            newName = ""
                            newEmail = ""
                            newCategory = "other"
                            showingAddContact = false
                        }
                        .disabled(newEmail.isEmpty || !newEmail.contains("@"))
                    }
                }
            }
        }
    }
}

// MARK: - Document Type Email Row
struct DocumentTypeEmailRow: View {
    let documentType: TripDocumentType
    let config: DocumentEmailConfig
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: documentType.icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(documentType.rawValue)
                    .foregroundColor(.white)
                
                if !config.toEmail.isEmpty {
                    Text(config.toEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No recipient set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            if config.autoIncludeCrewCC {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Document Type Email Config View
struct DocumentTypeEmailConfigView: View {
    let documentType: TripDocumentType
    @ObservedObject var settings: DocumentEmailSettingsStore
    
    @State private var toEmail: String = ""
    @State private var ccEmail: String = ""
    @State private var orderedSubjectFields: [EmailField] = []  // Enabled fields in order
    @State private var orderedBodyFields: [EmailField] = []     // Enabled fields in order
    @State private var autoIncludeCrewCC: Bool = false
    @State private var isEditingSubject: Bool = false
    @State private var isEditingBody: Bool = false
    
    // Available fields not yet added
    private var availableSubjectFieldsToAdd: [EmailField] {
        documentType.availableSubjectFields.filter { !orderedSubjectFields.contains($0) }
    }
    
    private var availableBodyFieldsToAdd: [EmailField] {
        documentType.availableBodyFields.filter { !orderedBodyFields.contains($0) }
    }
    
    var body: some View {
        Form {
            // Email Recipients with Autocomplete
            Section {
                EmailAutocompleteField(
                    label: "To:",
                    email: $toEmail,
                    placeholder: "recipient@company.com",
                    onEmailSelected: { _ in saveConfig() }
                )
                .onChange(of: toEmail) { _, _ in saveConfig() }
                                
                EmailAutocompleteField(
                    label: "CC:",
                    email: $ccEmail,
                    placeholder: "cc@company.com",
                    onEmailSelected: { _ in saveConfig() }
                )
                .onChange(of: ccEmail) { _, _ in saveConfig() }
                
                Text("Separate multiple emails with commas")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Toggle(isOn: $autoIncludeCrewCC) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("Auto-CC Crew Members")
                    }
                }
                .tint(.blue)
                .onChange(of: autoIncludeCrewCC) { _, _ in saveConfig() }
                
            } header: {
                Text("Recipients")
            } footer: {
                if autoIncludeCrewCC {
                    Text("Crew members from the trip will be automatically added to CC using their emails from your Crew Contacts.")
                }
            }
            
            // Subject Line Fields - Reorderable
            Section {
                if orderedSubjectFields.isEmpty {
                    Text("No fields selected")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(orderedSubjectFields, id: \.self) { field in
                        HStack(spacing: 12) {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            Text(field.rawValue)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Remove button
                            Button(action: {
                                withAnimation {
                                    orderedSubjectFields.removeAll { $0 == field }
                                    saveConfig()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { from, to in
                        orderedSubjectFields.move(fromOffsets: from, toOffset: to)
                        saveConfig()
                    }
                }
                
                // Add field button/picker
                if !availableSubjectFieldsToAdd.isEmpty {
                    Menu {
                        ForEach(availableSubjectFieldsToAdd, id: \.self) { field in
                            Button(field.rawValue) {
                                withAnimation {
                                    orderedSubjectFields.append(field)
                                    saveConfig()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Field")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Subject Line Fields")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drag ≡ to reorder • Tap ⊖ to remove")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Preview: \(previewSubject)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .environment(\.editMode, .constant(.active))  // Always show drag handles
            
            // Body Content Fields - Reorderable
            Section {
                if orderedBodyFields.isEmpty {
                    Text("No fields selected")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(orderedBodyFields, id: \.self) { field in
                        HStack(spacing: 12) {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            Text(field.rawValue)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Remove button
                            Button(action: {
                                withAnimation {
                                    orderedBodyFields.removeAll { $0 == field }
                                    saveConfig()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { from, to in
                        orderedBodyFields.move(fromOffsets: from, toOffset: to)
                        saveConfig()
                    }
                }
                
                // Add field button/picker
                if !availableBodyFieldsToAdd.isEmpty {
                    Menu {
                        ForEach(availableBodyFieldsToAdd, id: \.self) { field in
                            Button(field.rawValue) {
                                withAnimation {
                                    orderedBodyFields.append(field)
                                    saveConfig()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Field")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Email Body Fields")
            } footer: {
                Text("Drag ≡ to reorder • Tap ⊖ to remove")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .environment(\.editMode, .constant(.active))  // Always show drag handles
        }
        .navigationTitle(documentType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadConfig()
        }
    }
    
    private var previewSubject: String {
        // Always include Trip Number and Document Type
        var parts: [String] = ["Trip 7774096", documentType.rawValue]
        
        // Add selected fields in order (except tripNumber which is already included)
        let additionalParts = orderedSubjectFields.filter { $0 != .tripNumber }.map { field -> String in
            switch field {
            case .tripNumber: return "Trip 7774096"
            case .aircraft: return "N832US"
            case .date: return "Nov 25, 2025"
            case .departure: return "KLRD"
            case .arrival: return "MMCU"
            case .crew: return "Kadans/Ansteth"
            case .route: return "KLRD-MMCU"
            default: return field.rawValue
            }
        }
        
        parts.append(contentsOf: additionalParts)
        return parts.joined(separator: " - ")
    }
    
    private func loadConfig() {
        let config = settings.getConfig(for: documentType)
        toEmail = config.toEmail
        ccEmail = config.ccEmail
        orderedSubjectFields = config.subjectFields
        orderedBodyFields = config.bodyFields
        autoIncludeCrewCC = config.autoIncludeCrewCC
    }
    
    private func saveConfig() {
        let config = DocumentEmailConfig(
            toEmail: toEmail,
            ccEmail: ccEmail,
            subjectFields: orderedSubjectFields,
            bodyFields: orderedBodyFields,
            autoIncludeCrewCC: autoIncludeCrewCC
        )
        settings.setConfig(config, for: documentType)
    }
}

// MARK: - Preview
#Preview {
    DocumentEmailSettingsView()
}

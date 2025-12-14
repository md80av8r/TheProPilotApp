// CrewContactsView.swift
// Crew contact management for ProPilot
import SwiftUI

struct CrewContactsView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var selectedContact: CrewContact?
    @State private var showingEditSheet = false
    
    var filteredContacts: [CrewContact] {
        if searchText.isEmpty {
            return contactManager.contacts.sorted { $0.name < $1.name }
        } else {
            return contactManager.contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText) ||
                (contact.phoneNumber ?? "").localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Master-Detail layout
                iPadLayout
            } else {
                // iPhone: List layout
                iPhoneLayout
            }
        }
        .background(LogbookTheme.navy)
        .navigationTitle("Crew Contacts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddContact = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddCrewContactView(contactManager: contactManager)
        }
        .sheet(item: $selectedContact) { contact in
            EditCrewContactView(contactManager: contactManager, contact: contact)
        }
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        List {
            if filteredContacts.isEmpty {
                EmptyContactsView(searchText: searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredContacts) { contact in
                    CrewContactRow(contact: contact)
                        .listRowBackground(LogbookTheme.navyLight)
                        .onTapGesture {
                            selectedContact = contact
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteContact(contact)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                selectedContact = contact
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, prompt: "Search crew members")
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationSplitView {
            // Master: Crew list
            List(filteredContacts, selection: $selectedContact) { contact in
                CrewContactRow(contact: contact)
                    .listRowBackground(LogbookTheme.navyLight)
                    .tag(contact)
            }
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $searchText, prompt: "Search crew members")
            .scrollContentBackground(.hidden)
            .navigationTitle("Crew Contacts")
        } detail: {
            // Detail: Contact details
            if let contact = selectedContact {
                CrewContactDetailView(
                    contact: contact,
                    contactManager: contactManager,
                    onEdit: {
                        showingEditSheet = true
                    },
                    onDelete: {
                        deleteContact(contact)
                        selectedContact = nil
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Select a crew member")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LogbookTheme.navy)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let contact = selectedContact {
                EditCrewContactView(contactManager: contactManager, contact: contact)
            }
        }
    }
    
    private func deleteContact(_ contact: CrewContact) {
        withAnimation {
            contactManager.deleteContact(contact)
        }
    }
}

// MARK: - Crew Contact Row
struct CrewContactRow: View {
    let contact: CrewContact
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 50, height: 50)
                
                Text(contact.initials)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if !contact.email.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.caption)
                        Text(contact.email)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                if let phone = contact.phoneNumber, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text(phone)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            LogbookTheme.accentBlue,
            LogbookTheme.accentGreen,
            LogbookTheme.accentOrange,
            .purple,
            .pink,
            .cyan
        ]
        let index = abs(contact.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Crew Contact Detail View
struct CrewContactDetailView: View {
    let contact: CrewContact
    let contactManager: CrewContactManager
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with avatar
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(avatarColor)
                            .frame(width: 100, height: 100)
                        
                        Text(contact.initials)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(contact.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let role = contact.role {
                        HStack(spacing: 8) {
                            Image(systemName: role.icon)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text(role.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                
                // Contact Information Cards
                VStack(spacing: 16) {
                    if !contact.email.isEmpty {
                        ContactInfoCard(
                            icon: "envelope.fill",
                            label: "Email",
                            value: contact.email,
                            color: LogbookTheme.accentBlue,
                            action: {
                                let url = URL(string: "mailto:\(contact.email)")!
                                UIApplication.shared.open(url)
                            }
                        )
                    }
                    
                    if let phone = contact.phoneNumber, !phone.isEmpty {
                        ContactInfoCard(
                            icon: "phone.fill",
                            label: "Phone",
                            value: phone,
                            color: LogbookTheme.accentGreen,
                            action: {
                                let cleaned = phone.filter { $0.isNumber }
                                if let url = URL(string: "tel:\(cleaned)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                    }
                    
                    if let company = contact.company, !company.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(LogbookTheme.accentOrange)
                                Text("Company")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text(company)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Contact")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LogbookTheme.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Contact")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
        }
        .background(LogbookTheme.navy)
        .alert("Delete Contact", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(contact.name)?")
        }
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            LogbookTheme.accentBlue,
            LogbookTheme.accentGreen,
            LogbookTheme.accentOrange,
            .purple,
            .pink,
            .cyan
        ]
        let index = abs(contact.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Contact Info Card
struct ContactInfoCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(value)
                        .font(.body)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(color)
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
}

// MARK: - Empty Contacts View
struct EmptyContactsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "person.3.fill" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Crew Contacts" : "No Results")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "Tap + to add your first crew member" : "Try a different search term")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Add Crew Contact View
struct AddCrewContactView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var company = ""
    @State private var selectedRole: CrewRole?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information").foregroundColor(.white)) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                Section(header: Text("Additional Info").foregroundColor(.white)) {
                    TextField("Company", text: $company)
                    
                    Picker("Role", selection: $selectedRole) {
                        Text("None").tag(nil as CrewRole?)
                        ForEach(CrewRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.rawValue)
                            }.tag(role as CrewRole?)
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
        }
    }
    
    private func saveContact() {
        let contact = CrewContact(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            companyName: company.isEmpty ? nil : company,
            role: selectedRole
        )
        contactManager.addContact(contact)
        dismiss()
    }
}

// MARK: - Edit Crew Contact View
struct EditCrewContactView: View {
    @ObservedObject var contactManager: CrewContactManager
    let contact: CrewContact
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var company = ""
    @State private var selectedRole: CrewRole?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information").foregroundColor(.white)) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                .listRowBackground(LogbookTheme.navyLight)
                
                Section(header: Text("Additional Info").foregroundColor(.white)) {
                    TextField("Company", text: $company)
                    
                    Picker("Role", selection: $selectedRole) {
                        Text("None").tag(nil as CrewRole?)
                        ForEach(CrewRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.rawValue)
                            }.tag(role as CrewRole?)
                        }
                    }
                }
                .listRowBackground(LogbookTheme.navyLight)
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .onAppear {
                loadContact()
            }
        }
    }
    
    private func loadContact() {
        firstName = contact.firstName
        lastName = contact.lastName
        email = contact.email
        phoneNumber = contact.phoneNumber ?? ""
        company = contact.company ?? ""
        selectedRole = contact.role
    }
    
    private func saveChanges() {
        var updatedContact = contact
        updatedContact.firstName = firstName
        updatedContact.lastName = lastName
        updatedContact.email = email
        updatedContact.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        updatedContact.company = company.isEmpty ? nil : company
        updatedContact.role = selectedRole
        contactManager.updateContact(updatedContact)
        dismiss()
    }
}

// MARK: - CrewContact Extension for Initials
extension CrewContact {
    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return first + last
    }
}

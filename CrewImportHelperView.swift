//
//  CrewImportHelperView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/5/25.
//

// MARK: - Crew Import/Export Helper
import SwiftUI
import UniformTypeIdentifiers

struct CrewImportHelperView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var showingExportSheet = false
    @State private var importStatus = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Quick Import Options") {
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(LogbookTheme.accentBlue)
                            VStack(alignment: .leading) {
                                Text("Import from Spreadsheet")
                                    .foregroundColor(.white)
                                Text("CSV or Excel file with crew contacts")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Button(action: { showingExportSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(LogbookTheme.accentGreen)
                            VStack(alignment: .leading) {
                                Text("Export Contacts")
                                    .foregroundColor(.white)
                                Text("Save current contacts as CSV")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section("Template Import") {
                    Button(action: { createSampleData() }) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(LogbookTheme.accentOrange)
                            VStack(alignment: .leading) {
                                Text("Create Sample Crew")
                                    .foregroundColor(.white)
                                Text("Add common airline crew roles")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section("Import Format") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CORRECTED CSV Format Expected:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Last Name, First Name, Email, Phone Number, Company, Crew Position")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Text("Smith, John, john@airline.com, (555)123-4567, ABC Airlines, Captain")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Text("Doe, Jane, jane@airline.com, (555)567-8901, ABC Airlines, First Officer")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
                }
                
                if !importStatus.isEmpty {
                    Section("Import Status") {
                        Text(importStatus)
                            .foregroundColor(importStatus.contains("Error") ? .red : LogbookTheme.accentGreen)
                    }
                }
            }
            .navigationTitle("Crew Import Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportContactsView(contactManager: contactManager)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        isImporting = true
        importStatus = "Importing..."
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importStatus = "Error: No file selected"
                return
            }
            
            importFromCSV(url: url)
            
        case .failure(let error):
            importStatus = "Error: \(error.localizedDescription)"
        }
        
        isImporting = false
    }
    
    // MARK: - FIXED CSV IMPORT FUNCTION
    private func importFromCSV(url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                importStatus = "Error: Cannot access file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // Use the ContactManager's robust import function
            let importedCount = try contactManager.importFromCSV(content)
            importStatus = "✅ Successfully imported \(importedCount) contacts"
            
        } catch {
            importStatus = "Error: \(error.localizedDescription)"
        }
    }
    
    private func createSampleData() {
        let sampleContacts = [
            CrewContact(firstName: "John", lastName: "Smith", email: "john.smith@airline.com", phoneNumber: "555-0101", companyName: "ABC Airlines", role: .captain),
            CrewContact(firstName: "Sarah", lastName: "Johnson", email: "sarah.j@airline.com", phoneNumber: "555-0102", companyName: "ABC Airlines", role: .firstOfficer),
            CrewContact(firstName: "Mike", lastName: "Wilson", email: "mike.w@airline.com", phoneNumber: "555-0103", companyName: "ABC Airlines", role: .loadMaster),
            CrewContact(firstName: "Lisa", lastName: "Brown", email: "lisa.b@airline.com", phoneNumber: "555-0104", companyName: "ABC Airlines", role: .mechanic),
            CrewContact(firstName: "Tom", lastName: "Davis", email: "tom.d@airline.com", phoneNumber: "555-0105", companyName: "ABC Airlines", role: .dispatcher)
        ]
        
        var addedCount = 0
        for contact in sampleContacts {
            if contactManager.findContact(byName: contact.fullName) == nil {
                contactManager.addContact(contact)
                addedCount += 1
            }
        }
        
        importStatus = "✅ Added \(addedCount) sample contacts"
    }
}

// MARK: - Export Contacts View (FIXED)
struct ExportContactsView: View {
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    @State private var exportStatus = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LogbookTheme.accentGreen)
                
                VStack(spacing: 8) {
                    Text("Export Contacts")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Export \(contactManager.contacts.count) contacts as CSV")
                        .foregroundColor(.gray)
                }
                
                Button(action: exportContacts) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Create CSV File")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if !exportStatus.isEmpty {
                    Text(exportStatus)
                        .foregroundColor(LogbookTheme.accentGreen)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - FIXED EXPORT FUNCTION
    private func exportContacts() {
        // Use the ContactManager's fixed export function
        let csvContent = contactManager.exportCSV()
        
        // Save to app documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = documentsPath.appendingPathComponent("ProPilot_Contacts_\(DateFormatter.filenameDateFormatter.string(from: Date())).csv")
            
            do {
                try csvContent.write(to: filePath, atomically: true, encoding: .utf8)
                exportStatus = "✅ Exported to: \(filePath.lastPathComponent)"
                
                // Show share sheet
                let activityVC = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true)
                }
                
            } catch {
                exportStatus = "❌ Export failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter
    }()
}

// MARK: - Enhanced Crew Picker with Recents
struct QuickCrewPickerView: View {
    @Binding var crew: [CrewMember]
    @ObservedObject var contactManager: CrewContactManager
    @Environment(\.dismiss) private var dismiss
    
    // Recent crew members storage
    @AppStorage("recent_crew_members") private var recentCrewData: Data = Data()
    
    private var recentCrew: [CrewContact] {
        if let decoded = try? JSONDecoder().decode([CrewContact].self, from: recentCrewData) {
            return Array(decoded.prefix(12)) // Show last 12
        }
        return []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !recentCrew.isEmpty {
                        recentCrewSection
                    }
                    
                    frequentCrewSection
                    allContactsSection
                }
                .padding()
            }
            .navigationTitle("Quick Crew Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var recentCrewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Crew Members")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(recentCrew.prefix(6), id: \.id) { contact in
                    quickContactButton(contact: contact)
                }
            }
        }
    }
    
    private var frequentCrewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequent Crew")
                .font(.headline)
                .foregroundColor(.white)
            
            let frequentContacts = getFrequentContacts()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(frequentContacts.prefix(6), id: \.id) { contact in
                    quickContactButton(contact: contact)
                }
            }
        }
    }
    
    private var allContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Contacts")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                ForEach(contactManager.contacts, id: \.id) { contact in
                    contactRowButton(contact: contact)
                }
            }
        }
    }
    
    private func quickContactButton(contact: CrewContact) -> some View {
        Button(action: { addToCrew(contact) }) {
            VStack(spacing: 4) {
                HStack {
                    if let role = contact.role {
                        Image(systemName: role.icon)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let company = contact.company {
                        Text(company)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(8)
        }
    }
    
    private func contactRowButton(contact: CrewContact) -> some View {
        Button(action: { addToCrew(contact) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(contact.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let role = contact.role {
                    Image(systemName: role.icon)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                Image(systemName: "plus.circle")
                    .foregroundColor(LogbookTheme.accentGreen)
            }
            .padding()
            .background(LogbookTheme.fieldBackground)
            .cornerRadius(8)
        }
    }
    
    private func addToCrew(_ contact: CrewContact) {
        let defaultRole = contact.role?.rawValue ?? "First Officer"
        let newMember = CrewMember(role: defaultRole, name: contact.fullName)
        
        // Don't add duplicates
        if !crew.contains(where: { $0.name.lowercased() == contact.fullName.lowercased() }) {
            crew.append(newMember)
            saveAsRecentCrew(contact)
        }
    }
    
    private func saveAsRecentCrew(_ contact: CrewContact) {
        var recent = recentCrew
        recent.removeAll { $0.fullName.lowercased() == contact.fullName.lowercased() }
        recent.insert(contact, at: 0)
        
        if recent.count > 20 {
            recent = Array(recent.prefix(20))
        }
        
        if let encoded = try? JSONEncoder().encode(recent) {
            recentCrewData = encoded
        }
    }
    
    private func getFrequentContacts() -> [CrewContact] {
        // This could be enhanced with actual usage frequency tracking
        return Array(contactManager.contacts.prefix(6))
    }
}

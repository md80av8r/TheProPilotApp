//
//  EnhancedICAOTextField.swift - FIXED VERSION (No blocking dropdowns)
//  USA Jet Calc
//
//  Created by Jeffrey Kadans on 7/8/25.
//

import SwiftUI
import Foundation
import MessageUI

// MARK: - FIXED: Enhanced ICAO TextField (No Dropdown)
struct EnhancedICAOTextField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    let placeholder: String
    
    // Store frequently used ICAO codes
    @AppStorage("frequent_icao_codes") private var frequentICAOData: Data = Data()
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(LogbookTextFieldStyle())
            .focused($isFocused)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .onChange(of: text) { oldValue, newValue in
                // Limit to 4 characters and force uppercase
                let filtered = String(newValue.prefix(4).uppercased().filter { $0.isLetter })
                if filtered != newValue {
                    text = filtered
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused && !text.isEmpty && text.count == 4 {
                    saveFrequentICAO(text)
                }
            }
            .onAppear {
                loadFrequentICAOCodes()
            }
    }
    
    private func saveFrequentICAO(_ code: String) {
        var codes = getFrequentICAOCodes()
        codes.removeAll { $0 == code }
        codes.insert(code, at: 0)
        
        if codes.count > 20 {
            codes = Array(codes.prefix(20))
        }
        
        if let encoded = try? JSONEncoder().encode(codes) {
            frequentICAOData = encoded
        }
    }
    
    private func getFrequentICAOCodes() -> [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: frequentICAOData) {
            return decoded
        }
        return []
    }
    
    private func loadFrequentICAOCodes() {
        if frequentICAOData.isEmpty {
            frequentICAOData = Data()
        }
    }
}

// MARK: - FIXED: Enhanced Pilot Name TextField (No Dropdown)
struct EnhancedPilotNameTextField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    let placeholder: String
    let crewRole: String
    
    @AppStorage("pilot_names") private var pilotNamesData: Data = Data()
    @AppStorage("loadmaster_names") private var loadmasterNamesData: Data = Data()
    
    private var isLoadMaster: Bool {
        crewRole.localizedCaseInsensitiveContains("load") ||
        crewRole.localizedCaseInsensitiveContains("master")
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(LogbookTextFieldStyle())
            .focused($isFocused)
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .onChange(of: text) { oldValue, newValue in
                let formatted = formatPilotName(newValue)
                if formatted != newValue {
                    text = formatted
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    savePilotName(text)
                }
            }
    }
    
    private func formatPilotName(_ name: String) -> String {
        return name.split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }
    
    private func savePilotName(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let formattedName = formatPilotName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if isLoadMaster {
            saveToLoadmasterNames(formattedName)
        } else {
            saveToPilotNames(formattedName)
        }
    }
    
    private func saveToPilotNames(_ name: String) {
        var names = getPilotNames()
        names.removeAll { $0.lowercased() == name.lowercased() }
        names.insert(name, at: 0)
        
        if names.count > 50 {
            names = Array(names.prefix(50))
        }
        
        if let encoded = try? JSONEncoder().encode(names) {
            pilotNamesData = encoded
        }
    }
    
    private func saveToLoadmasterNames(_ name: String) {
        var names = getLoadmasterNames()
        names.removeAll { $0.lowercased() == name.lowercased() }
        names.insert(name, at: 0)
        
        if names.count > 30 {
            names = Array(names.prefix(30))
        }
        
        if let encoded = try? JSONEncoder().encode(names) {
            loadmasterNamesData = encoded
        }
    }
    
    private func getPilotNames() -> [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: pilotNamesData) {
            return decoded
        }
        return []
    }
    
    private func getLoadmasterNames() -> [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: loadmasterNamesData) {
            return decoded
        }
        return []
    }
}

// MARK: - Enhanced Crew Name TextField WITH Auto-Complete Dropdown
struct EnhancedCrewNameTextField: View {
    @Binding var text: String
    @ObservedObject var contactManager: CrewContactManager
    @FocusState private var isFocused: Bool
    @State private var showingContactPicker = false
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    
    let placeholder: String
    let crewRole: String
    
    @AppStorage("pilot_names") private var pilotNamesData: Data = Data()
    @AppStorage("loadmaster_names") private var loadmasterNamesData: Data = Data()
    
    private var isLoadMaster: Bool {
        crewRole.localizedCaseInsensitiveContains("load") ||
        crewRole.localizedCaseInsensitiveContains("master")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(LogbookTextFieldStyle())
                    .focused($isFocused)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .onChange(of: text) { oldValue, newValue in
                        let formatted = formatPilotName(newValue)
                        if formatted != newValue {
                            text = formatted
                        }
                        updateSuggestions()
                    }
                    .onChange(of: isFocused) { _, focused in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if focused {
                                updateSuggestions()
                            } else {
                                showingSuggestions = false
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    savePilotName(text)
                                }
                            }
                        }
                    }
                
                // Contact picker button
                Button(action: {
                    showingContactPicker = true
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(LogbookTheme.accentBlue)
                        .font(.title3)
                        .padding(8)
                        .background(LogbookTheme.fieldBackground)
                        .cornerRadius(6)
                }
            }
            
            // ✅ DROPDOWN SUGGESTIONS
            if showingSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            text = suggestion
                            showingSuggestions = false
                            isFocused = false
                            savePilotName(suggestion)
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.body)
                                    .foregroundColor(.white)
                                Spacer()
                                // Show role badge
                                Text(crewRole)
                                    .font(.caption2)
                                    .foregroundColor(isLoadMaster ? LogbookTheme.accentOrange : LogbookTheme.accentBlue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(
                                            (isLoadMaster ? LogbookTheme.accentOrange : LogbookTheme.accentBlue).opacity(0.2)
                                        )
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.fieldBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if suggestion != suggestions.prefix(5).last {
                            Divider().background(Color.gray.opacity(0.3))
                        }
                    }
                }
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            CrewContactPickerView(
                contactManager: contactManager,
                selectedName: $text
            )
        }
        .onAppear {
            loadSavedNames()
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateSuggestions() {
        let savedNames = getSavedNames()
        
        if text.isEmpty {
            suggestions = Array(savedNames.prefix(5))
            showingSuggestions = !suggestions.isEmpty
        } else {
            suggestions = savedNames.filter { name in
                name.localizedCaseInsensitiveContains(text) && name.lowercased() != text.lowercased()
            }
            showingSuggestions = !suggestions.isEmpty
        }
    }
    
    private func formatPilotName(_ input: String) -> String {
        input.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private func savePilotName(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let formattedName = formatPilotName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        var names = getSavedNames()
        
        // Remove if already exists (to move to front)
        names.removeAll { $0.lowercased() == formattedName.lowercased() }
        
        // Add to front
        names.insert(formattedName, at: 0)
        
        // Keep only last 50 names
        if names.count > 50 {
            names = Array(names.prefix(50))
        }
        
        // Save to appropriate storage
        if let encoded = try? JSONEncoder().encode(names) {
            if isLoadMaster {
                loadmasterNamesData = encoded
            } else {
                pilotNamesData = encoded
            }
        }
    }
    
    private func getSavedNames() -> [String] {
        let data = isLoadMaster ? loadmasterNamesData : pilotNamesData
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return []
    }
    
    private func loadSavedNames() {
        // Initialize storage if empty
        if pilotNamesData.isEmpty {
            pilotNamesData = Data()
        }
        if loadmasterNamesData.isEmpty {
            loadmasterNamesData = Data()
        }
    }
}

// MARK: - Enhanced Crew Management View (Keep As-Is)
struct EnhancedCrewManagementView: View {
    @Binding var crew: [CrewMember]
    @EnvironmentObject var crewContactManager: CrewContactManager
    @FocusState private var focusedField: Int?
    
    // Clipboard fallback states
    @State private var showingGroupTextAlert = false
    @State private var groupTextNumbers = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Crew Members")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    crew.append(CrewMember(role: "Load Master", name: ""))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("Add Crew")
                            .foregroundColor(LogbookTheme.accentGreen)
                            .font(.caption.bold())
                    }
                }
            }
            
            ForEach(crew.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    HStack {
                        // Role picker
                        Menu {
                            Button("Captain") { crew[index].role = "Captain" }
                            Button("First Officer") { crew[index].role = "First Officer" }
                            Button("Load Master") { crew[index].role = "Load Master" }
                            Button("Observer") { crew[index].role = "Observer" }
                            Button("Check Airman") { crew[index].role = "Check Airman" }
                        } label: {
                            HStack {
                                Text(crew[index].role)
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        if crew.count > 2 {
                            Button("Remove") {
                                crew.remove(at: index)
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    
                    // Enhanced name field with contact picker
                    crewMemberRow(for: index)
                }
                .padding()
                .background(
                    crew[index].role.localizedCaseInsensitiveContains("load") ?
                    LogbookTheme.accentOrange.opacity(0.1) :
                    LogbookTheme.fieldBackground
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            crew[index].role.localizedCaseInsensitiveContains("load") ?
                            LogbookTheme.accentOrange.opacity(0.3) :
                            Color.clear,
                            lineWidth: 1
                        )
                )
            }
            
            // Enhanced Group Communication Section
            if !crew.isEmpty && crew.contains(where: { !$0.name.isEmpty }) {
                enhancedGroupCommunicationSection
            }
        }
        .alert("Numbers Copied", isPresented: $showingGroupTextAlert) {
            Button("Open Messages") {
                if let url = URL(string: "sms:") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Phone numbers copied to clipboard:\n\n\(crewMembersWithPhones.map { $0.firstName }.joined(separator: ", "))\n\nPaste in Messages app")
        }
    }
    
    // MARK: - Individual Crew Member Row
    private func crewMemberRow(for index: Int) -> some View {
        VStack(spacing: 8) {
            // Name input with built-in contact picker
            EnhancedCrewNameTextField(
                text: $crew[index].name,
                contactManager: crewContactManager,
                placeholder: "Enter \(crew[index].role.lowercased()) name",
                crewRole: crew[index].role
            )
            .focused($focusedField, equals: index)
            
            // Individual communication buttons (if contact exists)
            if let contact = crewContactManager.findContact(byName: crew[index].name),
               let phone = contact.phoneNumber, !phone.isEmpty {
                individualCommunicationButtons(for: contact)
            }
        }
    }
    
    // MARK: - Individual Communication Buttons
    private func individualCommunicationButtons(for contact: CrewContact) -> some View {
        HStack(spacing: 12) {
            Button(action: { callContact(contact.phoneNumber!) }) {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                    Text("Call \(contact.firstName)")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(12)
            }
            
            Button(action: { textContact(contact.phoneNumber!) }) {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.caption)
                    Text("Text \(contact.firstName)")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Enhanced Group Communication Section
    private var enhancedGroupCommunicationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Group Communication")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(crewMembersWithPhones.count) of \(crew.filter { !$0.name.isEmpty }.count) crew members have phone numbers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !crewMembersWithPhones.isEmpty {
                VStack(spacing: 8) {
                    Button(action: sendGroupText) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.badge.filled.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Group Text All Crew")
                                    .font(.subheadline.bold())
                                Text(crewMembersWithPhones.map { $0.firstName }.joined(separator: ", "))
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .padding()
                        .background(LogbookTheme.accentBlue.opacity(0.2))
                        .foregroundColor(LogbookTheme.accentBlue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Button(action: copyNumbersToClipboard) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy Numbers")
                                    .font(.subheadline.bold())
                                Text("Use with your Messages app")
                                    .font(.caption)
                            }
                            Spacer()
                            Image(systemName: "square.on.square")
                                .font(.caption)
                        }
                        .padding()
                        .background(LogbookTheme.accentGreen.opacity(0.2))
                        .foregroundColor(LogbookTheme.accentGreen)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LogbookTheme.accentGreen.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Add phone numbers to contacts for group messaging")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Properties
    private var crewMembersWithPhones: [CrewContact] {
        crew.compactMap { member in
            guard !member.name.isEmpty,
                  let contact = crewContactManager.findContact(byName: member.name),
                  let phone = contact.phoneNumber, !phone.isEmpty else {
                return nil
            }
            return contact
        }
    }
    
    // MARK: - Communication Functions
    private func callContact(_ phoneNumber: String) {
        let cleanedNumber = normalizePhoneNumber(for: phoneNumber)
        
        if let url = URL(string: "tel:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func textContact(_ phoneNumber: String) {
        let cleanedNumber = normalizePhoneNumber(for: phoneNumber)
        
        if let url = URL(string: "sms:\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendGroupText() {
        let phoneNumbers = crewMembersWithPhones.compactMap { contact -> String? in
            guard let phone = contact.phoneNumber else { return nil }
            return normalizePhoneNumber(for: phone)
        }
        
        guard !phoneNumbers.isEmpty else { return }
        
        guard MFMessageComposeViewController.canSendText() else {
            copyNumbersToClipboard()
            return
        }
        
        let composer = MFMessageComposeViewController()
        composer.recipients = phoneNumbers
        composer.body = "Hey Guys! Another day, another adventure with the best crew around"
        composer.messageComposeDelegate = crewContactManager
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var topController = rootViewController
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                
                topController.present(composer, animated: true)
            }
        }
    }
    
    private func copyNumbersToClipboard() {
        let phoneNumbers = crewMembersWithPhones.compactMap { contact in
            normalizePhoneNumber(for: contact.phoneNumber ?? "")
        }
        
        guard !phoneNumbers.isEmpty else { return }
        
        groupTextNumbers = phoneNumbers.joined(separator: ", ")
        UIPasteboard.general.string = groupTextNumbers
        showingGroupTextAlert = true
    }
    
    private func normalizePhoneNumber(for number: String) -> String {
        var cleanedNumber = number.filter("0123456789+".contains)
        if let plus = cleanedNumber.first, plus == "+" {
            let remaining = String(cleanedNumber.dropFirst())
            cleanedNumber = "+" + remaining.filter(\.isNumber)
        } else {
            cleanedNumber = cleanedNumber.filter(\.isNumber)
        }

        if cleanedNumber.hasPrefix("+1") {
            return cleanedNumber
        } else if cleanedNumber.count == 11 && cleanedNumber.starts(with: "1") {
            return "+" + cleanedNumber
        } else if cleanedNumber.count == 10 {
            return "+1" + cleanedNumber
        }

        return cleanedNumber
    }
}

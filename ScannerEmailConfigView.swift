// ScannerEmailConfigView.swift
// Consolidated scanner email configuration settings
import SwiftUI

struct ScannerEmailConfigView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempLogbookEmail: String = ""
    @State private var tempReceiptsEmail: String = ""
    @State private var tempMaintenanceEmail: String = ""
    @State private var tempGeneralEmail: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Instructions Section
                Section(header: Text("About").foregroundColor(.white)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Configure email destinations for scanned documents")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("Smart Auto-Fill: First email populates all empty fields")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Email Destinations Section
                Section(header: Text("Email Destinations").foregroundColor(.white)) {
                    // Logbook Pages Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Logbook Pages")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("logbook@airline.com", text: $tempLogbookEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: tempLogbookEmail) { oldValue, newValue in
                                airlineSettings.settings.logbookEmail = newValue
                                autoFillEmptyFields(from: newValue)
                            }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Fuel Receipts Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("Fuel Receipts")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("receipts@airline.com", text: $tempReceiptsEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: tempReceiptsEmail) { oldValue, newValue in
                                airlineSettings.settings.receiptsEmail = newValue
                            }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // Maintenance Logs Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Maintenance Logs")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("maintenance@airline.com", text: $tempMaintenanceEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: tempMaintenanceEmail) { oldValue, newValue in
                                airlineSettings.settings.maintenanceEmail = newValue
                            }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    // General Documents Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.purple)
                            Text("General Documents")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        TextField("documents@airline.com", text: $tempGeneralEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: tempGeneralEmail) { oldValue, newValue in
                                airlineSettings.settings.generalEmail = newValue
                            }
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
                
                // MARK: - Auto-Send Section
                Section(header: Text("Sending Options").foregroundColor(.white)) {
                    Toggle("Auto-Send Fuel Receipts", isOn: Binding(
                        get: { airlineSettings.settings.autoSendReceipts },
                        set: { airlineSettings.settings.autoSendReceipts = $0 }
                    ))
                    .foregroundColor(.white)
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    if airlineSettings.settings.autoSendReceipts {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                Text("Fuel receipts will be sent automatically after scanning")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                            
                            Text("Other documents will still require manual sending")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                }
                
                // MARK: - Current Configuration Display
                if airlineSettings.settings.hasValidScannerEmails {
                    Section(header: Text("Current Configuration").foregroundColor(.white)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(airlineSettings.settings.configuredEmailCount) email destination\(airlineSettings.settings.configuredEmailCount == 1 ? "" : "s") configured")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            ForEach(configuredEmails, id: \.label) { config in
                                EmailConfigDisplay(
                                    icon: config.icon,
                                    label: config.label,
                                    email: config.email,
                                    color: config.color
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                }
                
                // MARK: - Actions Section
                Section {
                    Button(action: {
                        clearAllEmails()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Clear All Emails")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Scanner Email Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        airlineSettings.saveSettings()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .onAppear {
                loadCurrentEmails()
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var configuredEmails: [(icon: String, label: String, email: String, color: Color)] {
        var emails: [(icon: String, label: String, email: String, color: Color)] = []
        
        if !airlineSettings.settings.logbookEmail.isEmpty {
            emails.append(("book.closed.fill", "Logbook", airlineSettings.settings.logbookEmail, LogbookTheme.accentBlue))
        }
        if !airlineSettings.settings.receiptsEmail.isEmpty {
            emails.append(("fuelpump.fill", "Receipts", airlineSettings.settings.receiptsEmail, LogbookTheme.accentGreen))
        }
        if !airlineSettings.settings.maintenanceEmail.isEmpty {
            emails.append(("wrench.and.screwdriver.fill", "Maintenance", airlineSettings.settings.maintenanceEmail, LogbookTheme.accentOrange))
        }
        if !airlineSettings.settings.generalEmail.isEmpty {
            emails.append(("doc.fill", "General", airlineSettings.settings.generalEmail, .purple))
        }
        
        return emails
    }
    
    // MARK: - Helper Functions
    
    private func loadCurrentEmails() {
        tempLogbookEmail = airlineSettings.settings.logbookEmail
        tempReceiptsEmail = airlineSettings.settings.receiptsEmail
        tempMaintenanceEmail = airlineSettings.settings.maintenanceEmail
        tempGeneralEmail = airlineSettings.settings.generalEmail
    }
    
    private func autoFillEmptyFields(from email: String) {
        guard !email.isEmpty, email.contains("@") else { return }
        
        // Auto-fill empty fields with the first entered email
        if tempReceiptsEmail.isEmpty {
            tempReceiptsEmail = email
            airlineSettings.settings.receiptsEmail = email
        }
        if tempMaintenanceEmail.isEmpty {
            tempMaintenanceEmail = email
            airlineSettings.settings.maintenanceEmail = email
        }
        if tempGeneralEmail.isEmpty {
            tempGeneralEmail = email
            airlineSettings.settings.generalEmail = email
        }
        
        // Save after auto-fill
        airlineSettings.saveSettings()
        
        // Provide haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func clearAllEmails() {
        tempLogbookEmail = ""
        tempReceiptsEmail = ""
        tempMaintenanceEmail = ""
        tempGeneralEmail = ""
        
        airlineSettings.settings.logbookEmail = ""
        airlineSettings.settings.receiptsEmail = ""
        airlineSettings.settings.maintenanceEmail = ""
        airlineSettings.settings.generalEmail = ""
        
        airlineSettings.saveSettings()
        
        // Provide haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

// MARK: - Email Config Display Component
struct EmailConfigDisplay: View {
    let icon: String
    let label: String
    let email: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(email)
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
    }
}

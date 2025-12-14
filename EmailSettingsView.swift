import SwiftUI

/// View for configuring email-related settings
struct EmailSettingsView: View {
    @ObservedObject var settings: EmailSettingsStore

    var body: some View {
        Form {
            Section(header: Text("Emails")) {
                TextField("Logbook Email", text: $settings.settings.logbookEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Receipts Email", text: $settings.settings.receiptsEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("General Email", text: $settings.settings.generalEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            Section(header: Text("Options")) {
                Toggle("Auto-send Receipts", isOn: $settings.settings.autoSendReceipts)
                Toggle("Include Aircraft In Subject", isOn: $settings.settings.includeAircraftInSubject)
                Toggle("Include Route In Email", isOn: $settings.settings.includeRouteInEmail)
            }
        }
        .navigationTitle("Email Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    settings.saveSettings()
                }
            }
        }
    }
}

struct EmailSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EmailSettingsView(settings: EmailSettingsStore())
        }
    }
}

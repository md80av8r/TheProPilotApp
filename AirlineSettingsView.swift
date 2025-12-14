import SwiftUI

/// View for configuring airline-specific settings
struct AirlineSettingsView: View {
    @ObservedObject var settings: AirlineSettingsStore

    var body: some View {
        Form {
            Section(header: Text("Airline Info")) {
                TextField("Airline Name", text: $settings.settings.airlineName)
                TextField("Home Base Airport", text: $settings.settings.homeBaseAirport)
                TextField("Fleet Callsign", text: $settings.settings.fleetCallsign)
            }
            Section(header: Text("Contacts")) {
                TextField("Company Email", text: $settings.settings.companyEmail)
                TextField("Logbook Email", text: $settings.settings.logbookEmail)
                TextField("Receipts Email", text: $settings.settings.receiptsEmail)
            }
            Section(header: Text("Alarms")) {
                Toggle("Enable Timer Alarms", isOn: $settings.settings.enableTimerAlarms)
                NavigationLink(destination: SoundPickerView(selectedSound: $settings.settings.selectedAlarmSound)) {
                    HStack {
                        Text("Alarm Sound")
                        Spacer()
                        Text(settings.settings.selectedAlarmSound.displayName)
                            .foregroundColor(.gray)
                    }
                }
                Slider(value: $settings.settings.alarmVolume, in: 0...1) {
                    Text("Alarm Volume")
                }
            }
        }
        .navigationTitle("Airline Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    settings.saveSettings()
                }
            }
        }
    }
}

struct AirlineSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AirlineSettingsView(settings: AirlineSettingsStore())
        }
    }
}

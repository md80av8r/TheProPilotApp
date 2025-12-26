// ===== AirlineSettings.swift - Clean Fixed Version =====
import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Airline Settings Store
class AirlineSettingsStore: ObservableObject {
    @Published var settings = AirlineSettings()
    
    private let userDefaults = UserDefaults.shared
    private let settingsKey = "AirlineSettings"
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
        objectWillChange.send()
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AirlineSettings.self, from: data) {
            settings = decoded
        }
    }
    
    func resetToDefaults() {
        settings = AirlineSettings()
        saveSettings()
    }
}

// MARK: - Airline Settings Data Model
struct AirlineSettings: Codable {
    var airlineName: String = ""  // ✅ CHANGED - No hardcoded airline, user must configure
    var homeBaseAirport: String = ""  // ✅ CHANGED - No hardcoded airport, user must configure
    var fleetCallsign: String = ""  // ✅ CHANGED - No hardcoded callsign, user must configure
    var flightNumberPrefix: String = ""  // ✅ ADDED - Flight number prefix for trip entry (e.g., "JUS" for JUS123)
    var enableTimerAlarms: Bool = true
    var selectedAlarmSound: AlarmSound = .chime
    var alarmVolume: Double = 0.8
    var companyEmail: String = ""
    var logbookEmail: String = ""
    var receiptsEmail: String = ""
    var maintenanceEmail: String = ""  // ✅ ADDED - For maintenance logs
    var generalEmail: String = ""      // ✅ ADDED - For general documents
    var autoSendReceipts: Bool = false // ✅ ADDED - Auto-send fuel receipts
    var hasCompletedInitialSetup: Bool = false
    
    // FIXED: Simplified computed properties to avoid compiler timeout
    var defaultLogbookEmail: String {
        let cleanName = airlineName.lowercased().replacingOccurrences(of: " ", with: "")
        return "logpage@\(cleanName).aero"
    }
    
    var defaultReceiptsEmail: String {
        let cleanName = airlineName.lowercased().replacingOccurrences(of: " ", with: "")
        return "receipts@\(cleanName).aero"
    }
    
    var defaultMaintenanceEmail: String {
        let cleanName = airlineName.lowercased().replacingOccurrences(of: " ", with: "")
        return "maintenance@\(cleanName).aero"
    }
    
    var defaultGeneralEmail: String {
        let cleanName = airlineName.lowercased().replacingOccurrences(of: " ", with: "")
        return "documents@\(cleanName).aero"
    }
    
    // Helper to check if scanner emails are configured
    var hasValidScannerEmails: Bool {
        return !logbookEmail.isEmpty ||
               !receiptsEmail.isEmpty ||
               !maintenanceEmail.isEmpty ||
               !generalEmail.isEmpty
    }
    
    // Count of configured email destinations
    var configuredEmailCount: Int {
        var count = 0
        if !logbookEmail.isEmpty { count += 1 }
        if !receiptsEmail.isEmpty { count += 1 }
        if !maintenanceEmail.isEmpty { count += 1 }
        if !generalEmail.isEmpty { count += 1 }
        return count
    }
    
    // FIXED: Simplified validation to avoid compiler timeout
    var isValidConfiguration: Bool {
        let hasHomeBase = !homeBaseAirport.isEmpty
        let hasCallsign = !fleetCallsign.isEmpty
        let hasAirlineName = !airlineName.isEmpty
        return hasHomeBase && hasCallsign && hasAirlineName
    }
}

// MARK: - Alarm Sound Options
enum AlarmSound: String, CaseIterable, Codable {
    case chime = "chime"
    case bell = "bell"
    case digital = "digital"
    case classic = "classic"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .chime: return "Chime"
        case .bell: return "Bell"
        case .digital: return "Digital Beep"
        case .classic: return "Classic Alarm"
        case .urgent: return "Urgent Alert"
        }
    }
    
    var systemSoundID: UInt32 {
        switch self {
        case .chime: return 1000
        case .bell: return 1005
        case .digital: return 1057
        case .classic: return 1004
        case .urgent: return 1006
        }
    }
    
    // ADD THIS:
    var systemSoundName: String {
        switch self {
        case .chime: return "chime.caf"
        case .bell: return "bell.caf"
        case .digital: return "digital.caf"
        case .classic: return "classic.caf"
        case .urgent: return "urgent.caf"
        }
    }
}

// MARK: - Sound Picker View
struct SoundPickerView: View {
    @Binding var selectedSound: AlarmSound
    @Environment(\.dismiss) private var dismiss
    @State private var testingSound: AlarmSound?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(AlarmSound.allCases, id: \.self) { sound in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sound.displayName)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Text("System sound")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                testSound(sound)
                            }) {
                                Image(systemName: testingSound == sound ? "speaker.wave.3.fill" : "play.circle")
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .font(.title2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if selectedSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundColor(LogbookTheme.accentGreen)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSound = sound
                        }
                    }
                } header: {
                    Text("Available Alarm Sounds")
                        .foregroundColor(.gray)
                }
            }
            .listStyle(.insetGrouped)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Alarm Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    private func testSound(_ sound: AlarmSound) {
        testingSound = sound
        AudioServicesPlaySystemSound(sound.systemSoundID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            testingSound = nil
        }
    }
}

// MARK: - Airport Database Helper
struct AirportDatabase {
    static let airportTimezones: [String: String] = [
        "KATL": "America/New_York",
        "KLAX": "America/Los_Angeles",
        "KORD": "America/Chicago",
        "KDFW": "America/Chicago",
        "KDEN": "America/Denver",
        "KJFK": "America/New_York",
        "KSFO": "America/Los_Angeles",
        "KLAS": "America/Los_Angeles",
        "KPHX": "America/Phoenix",
        "KMIA": "America/New_York",
        "KMDW": "America/Chicago",
        "KDAL": "America/Chicago",
        "KBWI": "America/New_York",
        "KOAK": "America/Los_Angeles",
        "KYIP": "America/Detroit",
        "KDET": "America/Detroit",
        "KBOS": "America/New_York",
        "KSEA": "America/Los_Angeles",
        "KMSP": "America/Chicago",
        "KMEM": "America/Chicago",
        "KCVG": "America/New_York",
        "KCLT": "America/New_York",
        "KPHL": "America/New_York",
        "KULS": "America/New_York",
        "KANC": "America/Anchorage"
    ]
    
    static func timeZone(for icaoCode: String) -> TimeZone {
        let identifier = airportTimezones[icaoCode] ?? "America/New_York"
        return TimeZone(identifier: identifier) ?? TimeZone.current
    }
    
    static let majorAirlines: [String: AirlinePreset] = [
        "AAL": AirlinePreset(name: "American Airlines", callsign: "AAL", hub: "KDFW"),
        "DAL": AirlinePreset(name: "Delta Air Lines", callsign: "DAL", hub: "KATL"),
        "UAL": AirlinePreset(name: "United Airlines", callsign: "UAL", hub: "KORD"),
        "SWA": AirlinePreset(name: "Southwest Airlines", callsign: "SWA", hub: "KMDW"),
        "JBU": AirlinePreset(name: "JetBlue Airways", callsign: "JBU", hub: "KJFK"),
        "ASA": AirlinePreset(name: "Alaska Airlines", callsign: "ASA", hub: "KSEA"),
        "FFT": AirlinePreset(name: "Frontier Airlines", callsign: "FFT", hub: "KDEN"),
        "NKS": AirlinePreset(name: "Spirit Airlines", callsign: "NKS", hub: "KMIA"),
        "JUS": AirlinePreset(name: "USA Jet", callsign: "JUS", hub: "KYIP")
    ]
}

struct AirlinePreset {
    let name: String
    let callsign: String
    let hub: String
}

// MARK: - Airline Quick Setup View
struct AirlineQuickSetupView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAirline: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text("Quick Airline Setup")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Select your airline for automatic configuration")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(AirportDatabase.majorAirlines.keys.sorted()), id: \.self) { callsign in
                            let airline = AirportDatabase.majorAirlines[callsign]!
                            
                            Button(action: {
                                selectedAirline = callsign
                                setupAirline(airline, callsign: callsign)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(airline.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Callsign: \(callsign) • Hub: \(airline.hub)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedAirline == callsign {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                }
                                .padding()
                                .background(selectedAirline == callsign ? LogbookTheme.accentBlue.opacity(0.2) : LogbookTheme.navyLight)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedAirline == callsign ? LogbookTheme.accentBlue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            selectedAirline = "CUSTOM"
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Custom Airline")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Set up manually")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "gearshape")
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if selectedAirline != nil && selectedAirline != "CUSTOM" {
                    Button("Apply Configuration") {
                        airlineSettings.saveSettings()
                        dismiss()
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Airline Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
    
    private func setupAirline(_ airline: AirlinePreset, callsign: String) {
        airlineSettings.settings.airlineName = airline.name
        airlineSettings.settings.fleetCallsign = callsign
        airlineSettings.settings.flightNumberPrefix = callsign  // ✅ ADDED - Auto-set flight number prefix
        airlineSettings.settings.homeBaseAirport = airline.hub
        airlineSettings.settings.logbookEmail = airlineSettings.settings.defaultLogbookEmail
        airlineSettings.settings.receiptsEmail = airlineSettings.settings.defaultReceiptsEmail
    }
}

// MARK: - Helper functions
func playAirlineSystemSound(_ soundID: UInt32) {
    AudioServicesPlaySystemSound(soundID)
}

func playAirlineSystemVibration() {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
}

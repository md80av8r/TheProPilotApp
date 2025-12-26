//
//  WeatherSettingsView.swift (EXAMPLE)
//  TheProPilotApp
//
//  Example Settings View for Weather Preferences
//

import SwiftUI

struct WeatherSettingsView: View {
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    
    var body: some View {
        Form {
            Section(header: Text("Weather Display")) {
                // Pressure Unit Toggle
                Toggle(isOn: $settingsStore.usePressureInHg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Altimeter Setting in inHg")
                            .font(.body)
                        
                        Text(settingsStore.usePressureInHg ? "29.92 inHg (US Standard)" : "1013 mb/hPa (International)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Temperature Unit Toggle
                Toggle(isOn: $settingsStore.useCelsius) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temperature in Celsius")
                            .font(.body)
                        
                        Text(settingsStore.useCelsius ? "15°C (Aviation Standard)" : "59°F")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Preview
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(.blue)
                        Text("Pressure:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formatExamplePressure())
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("Temperature:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formatExampleTemperature())
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Section(footer: footerText) {
                EmptyView()
            }
        }
        .navigationTitle("Weather Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatExamplePressure() -> String {
        if settingsStore.usePressureInHg {
            return "29.92 inHg"
        } else {
            return "1013 mb"
        }
    }
    
    private func formatExampleTemperature() -> String {
        if settingsStore.useCelsius {
            return "15°C"
        } else {
            return "59°F"
        }
    }
    
    private var footerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pressure: " + (settingsStore.usePressureInHg
                 ? "Standard US altimeter setting format. Used for setting your altimeter before flight."
                 : "International standard pressure format (hectopascals/millibars). 1 inHg ≈ 33.86 mb"))
            
            Text("Temperature: " + (settingsStore.useCelsius
                 ? "Celsius is the aviation standard worldwide."
                 : "Fahrenheit is commonly used in the United States."))
        }
        .font(.caption)
        .foregroundColor(.gray)
    }
}

// MARK: - Alternative: Picker Style

struct WeatherSettingsPickerView: View {
    @ObservedObject var settingsStore = NOCSettingsStore.shared
    
    enum PressureUnit: String, CaseIterable, Identifiable {
        case inHg = "inHg"
        case millibar = "mb/hPa"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .inHg: return "29.92 inHg (US)"
            case .millibar: return "1013 mb (Intl)"
            }
        }
    }
    
    private var selectedUnit: PressureUnit {
        settingsStore.usePressureInHg ? .inHg : .millibar
    }
    
    var body: some View {
        Form {
            Section(header: Text("Pressure Units")) {
                Picker("Altimeter Format", selection: Binding(
                    get: { settingsStore.usePressureInHg ? PressureUnit.inHg : PressureUnit.millibar },
                    set: { settingsStore.usePressureInHg = ($0 == .inHg) }
                )) {
                    ForEach(PressureUnit.allCases) { unit in
                        Text(unit.description).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Standard Pressure")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(selectedUnit == .inHg ? "29.92 inHg" : "1013.25 mb")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "gauge")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Weather Settings")
    }
}

// MARK: - How to Add to Your Settings

/*
 To integrate into your main SettingsView:
 
 1. Add a navigation link:
 
    NavigationLink(destination: WeatherSettingsView()) {
        Label("Weather Display", systemImage: "cloud.sun")
    }
 
 2. Or add directly in Settings:
 
    Section(header: Text("Weather")) {
        Toggle("Pressure in inHg", isOn: $settingsStore.usePressureInHg)
    }
 
 3. The setting automatically saves and updates all weather views!
 */

// MARK: - Preview

#if DEBUG
struct WeatherSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeatherSettingsView()
        }
        
        NavigationView {
            WeatherSettingsPickerView()
        }
    }
}
#endif

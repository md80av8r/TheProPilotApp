//
//  PerDiemSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/28/25.
//


// PerDiemSettingsView.swift
// Configure per diem rates and calculation settings
import SwiftUI

struct PerDiemSettingsView: View {
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("perDiemDailyRate") private var dailyRate: Double = 2.10
    @AppStorage("perDiemHourlyRate") private var hourlyRate: Double = 2.10
    @AppStorage("perDiemCalculationMethod") private var calculationMethod: String = "hourly"
    @AppStorage("perDiemMinimumHours") private var minimumHours: Double = 4.0
    @AppStorage("perDiemIncludeLayover") private var includeLayover: Bool = true
    @AppStorage("perDiemTaxable") private var isTaxable: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // Rate Settings
                Section {
                    HStack {
                        Text("Hourly Rate")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("Rate", value: $hourlyRate, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(LogbookTheme.accentGreen)
                            .frame(width: 100)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    HStack {
                        Text("Daily Rate (24hr)")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("Rate", value: $dailyRate, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(LogbookTheme.accentGreen)
                            .frame(width: 100)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Per Diem Rates")
                        .foregroundColor(.white)
                } footer: {
                    Text("Standard USA Jet per diem rate is $2.10/hour")
                        .foregroundColor(.gray)
                }
                
                // Calculation Method
                Section {
                    Picker("Calculation Method", selection: $calculationMethod) {
                        Text("Hourly").tag("hourly")
                        Text("Daily").tag("daily")
                        Text("Trip-Based").tag("trip")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(LogbookTheme.navyLight)
                    
                    if calculationMethod == "hourly" {
                        HStack {
                            Text("Minimum Hours")
                                .foregroundColor(.white)
                            Spacer()
                            Stepper("\(minimumHours, specifier: "%.1f") hrs", value: $minimumHours, in: 0...12, step: 0.5)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                } header: {
                    Text("Calculation Method")
                        .foregroundColor(.white)
                }
                
                // Options
                Section {
                    Toggle("Include Layover Time", isOn: $includeLayover)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentGreen)
                        .listRowBackground(LogbookTheme.navyLight)
                    
                    Toggle("Mark as Taxable Income", isOn: $isTaxable)
                        .foregroundColor(.white)
                        .tint(LogbookTheme.accentOrange)
                        .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Options")
                        .foregroundColor(.white)
                } footer: {
                    Text("Consult your tax advisor regarding per diem taxation")
                        .foregroundColor(.gray)
                }
                
                // Quick Reference
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Example Calculations")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("12-hour duty day:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(12 * hourlyRate, specifier: "%.2f")")
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                        
                        HStack {
                            Text("24-hour period:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(24 * hourlyRate, specifier: "%.2f")")
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                        
                        HStack {
                            Text("4-day trip (96 hrs):")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(96 * hourlyRate, specifier: "%.2f")")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Quick Reference")
                        .foregroundColor(.white)
                }
            }
            .background(LogbookTheme.navy)
            .scrollContentBackground(.hidden)
            .navigationTitle("Per Diem Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
}

#if DEBUG
struct PerDiemSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PerDiemSettingsView(airlineSettings: AirlineSettingsStore())
    }
}
#endif
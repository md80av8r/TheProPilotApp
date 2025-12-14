//
//  AutoCompleteTestView.swift
//  USA Jet Calc
//
//  Created by Jeffrey Kadans on 7/8/25.
//


// AutoCompleteTestView.swift - Demo View for Testing Enhanced Auto-Complete
import SwiftUI

struct AutoCompleteTestView: View {
    @State private var departureAirport = ""
    @State private var arrivalAirport = ""
    @State private var captainName = ""
    @State private var firstOfficerName = ""
    @State private var loadMasterName = ""
    // Added for contact import
    @StateObject private var crewContactManager = CrewContactManager()
    
    @State private var testCrew: [CrewMember] = [
        CrewMember(role: "Captain", name: ""),
        CrewMember(role: "First Officer", name: ""),
        CrewMember(role: "Load Master", name: "")
    ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🛩️ Enhanced Auto-Complete Demo")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Test the ICAO and pilot name auto-complete features")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // ICAO Testing Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("✈️ ICAO Auto-Complete Test")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Try typing: YIP, ORD, ATL, MEM, etc.")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Departure Airport")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                EnhancedICAOTextField(
                                    text: $departureAirport,
                                    placeholder: "KYIP"
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Arrival Airport")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                EnhancedICAOTextField(
                                    text: $arrivalAirport,
                                    placeholder: "KORD"
                                )
                            }
                        }
                        
                        // Current values display
                        if !departureAirport.isEmpty || !arrivalAirport.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Route: \(departureAirport) → \(arrivalAirport)")
                                    .font(.headline)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Pilot Names Testing Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("👨‍✈️ Pilot Name Auto-Complete Test")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Try typing common names like: John, Tony, Mike, Sarah, etc.")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Captain")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                EnhancedPilotNameTextField(
                                    text: $captainName,
                                    placeholder: "Enter captain name",
                                    crewRole: "Captain"
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First Officer")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                EnhancedPilotNameTextField(
                                    text: $firstOfficerName,
                                    placeholder: "Enter first officer name",
                                    crewRole: "First Officer"
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Load Master")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                EnhancedPilotNameTextField(
                                    text: $loadMasterName,
                                    placeholder: "Enter load master name",
                                    crewRole: "Load Master"
                                )
                            }
                        }
                        
                        // Current crew display
                        if !captainName.isEmpty || !firstOfficerName.isEmpty || !loadMasterName.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Crew:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if !captainName.isEmpty {
                                    Text("👨‍✈️ Captain: \(captainName)")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                                if !firstOfficerName.isEmpty {
                                    Text("🧑‍✈️ First Officer: \(firstOfficerName)")
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                                if !loadMasterName.isEmpty {
                                    Text("📦 Load Master: \(loadMasterName)")
                                        .foregroundColor(LogbookTheme.accentOrange)
                                }
                            }
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Enhanced Crew Management Test
                    VStack(alignment: .leading, spacing: 16) {
                        Text("👥 Enhanced Crew Management Test")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("This shows the full crew management interface")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        EnhancedCrewManagementView(crew: $testCrew)
                            .environmentObject(crewContactManager)  // Add this line
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Instructions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📋 How It Works")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("✈️")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ICAO Auto-Complete")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("• Stores your frequently used airports")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• Auto-suggests as you type")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• Shows airport names in dropdown")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("👨‍✈️")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pilot Name Auto-Complete")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("• Separate storage for pilots vs load masters")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• Proper name capitalization")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• Role badges in suggestions")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("💾")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Smart Storage")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("• Recent entries appear first")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• No phone autocorrect interference")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("• Automatic deduplication")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    
                    // Clear storage button for testing
                    VStack(spacing: 12) {
                        Text("🧹 Testing Controls")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Button("Clear ICAO History") {
                                UserDefaults.standard.removeObject(forKey: "frequent_icao_codes")
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Clear Pilot Names") {
                                UserDefaults.standard.removeObject(forKey: "pilot_names")
                                UserDefaults.standard.removeObject(forKey: "loadmaster_names")
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        
                        Text("Use these buttons to clear stored data for testing")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Auto-Complete Demo")
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
}

// MARK: - Preview
struct AutoCompleteTestView_Previews: PreviewProvider {
    static var previews: some View {
        AutoCompleteTestView()
    }
}

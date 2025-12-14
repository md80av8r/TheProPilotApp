//
//  AircraftHistoryManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/18/25.
//

import SwiftUI
import Foundation

// MARK: - Aircraft History Manager
class AircraftHistoryManager: ObservableObject {
    @Published var lastUsedAircraft: String?
    
    private let lastAircraftKey = "last_used_aircraft"
    
    init() {
        loadLastAircraft()
    }
    
    func updateLastAircraft(_ aircraft: String) {
        lastUsedAircraft = aircraft
        UserDefaults.standard.set(aircraft, forKey: lastAircraftKey)
    }
    
    private func loadLastAircraft() {
        lastUsedAircraft = UserDefaults.standard.string(forKey: lastAircraftKey)
    }
}

// MARK: - Updated New Trip View with Default Aircraft
struct NewTripView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var aircraftHistoryManager: AircraftHistoryManager
    
    let availableAircraft: [String] = ["N123AB", "N456CD", "N789EF", "N321GH"]
    
    @State private var selectedAircraft: String
    @State private var selectedRole: PilotRole = .captain
    @State private var tripNumber: String = ""
    @State private var departureAirport: String = ""
    @State private var arrivalAirport: String = ""
    
    let onSave: (Trip) -> Void
    
    init(
        aircraftHistoryManager: AircraftHistoryManager,
        onSave: @escaping (Trip) -> Void
    ) {
        self.aircraftHistoryManager = aircraftHistoryManager
        self.onSave = onSave
        
        // Initialize with last used aircraft or first in list
        _selectedAircraft = State(initialValue: aircraftHistoryManager.lastUsedAircraft ?? availableAircraft.first ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Details")) {
                    // Trip Number
                    HStack {
                        Text("Trip #")
                            .foregroundColor(LogbookTheme.textSecondary)
                        TextField("Enter trip number", text: $tripNumber)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Aircraft Picker - Default to last used
                    Picker("Aircraft", selection: $selectedAircraft) {
                        ForEach(availableAircraft, id: \.self) { aircraft in
                            HStack {
                                Text(aircraft)
                                if aircraft == aircraftHistoryManager.lastUsedAircraft {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                }
                            }
                            .tag(aircraft)
                        }
                    }
                    
                    // Role Picker
                    Picker("Role", selection: $selectedRole) {
                        ForEach(PilotRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                }
                
                Section(header: Text("First Leg")) {
                    HStack {
                        Text("From")
                            .foregroundColor(LogbookTheme.textSecondary)
                        TextField("KORD", text: $departureAirport)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("To")
                            .foregroundColor(LogbookTheme.textSecondary)
                        TextField("KJFK", text: $arrivalAirport)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Show which aircraft was last used
                if let lastAircraft = aircraftHistoryManager.lastUsedAircraft {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Defaulted to \(lastAircraft) (last used)")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !tripNumber.isEmpty &&
        !selectedAircraft.isEmpty &&
        !departureAirport.isEmpty &&
        !arrivalAirport.isEmpty
    }
    
    private func createTrip() {
        // Create first leg - FlightLeg has default values for all properties
        var firstLeg = FlightLeg()
        firstLeg.departure = departureAirport.uppercased()
        firstLeg.arrival = arrivalAirport.uppercased()
        
        // Create trip with ALL required parameters
        let newTrip = Trip(
            id: UUID(),
            tripNumber: tripNumber,
            aircraft: selectedAircraft,
            date: Date(),                    // ← ADD: Current date
            tatStart: "",                    // ← ADD: Empty TAT (will be filled later)
            crew: [                          // ← ADD: Default crew
                CrewMember(role: "Captain", name: ""),
                CrewMember(role: "First Officer", name: "")
                  ],
            notes: "",                       // ← ADD: Empty notes
            legs: [firstLeg],
            tripType: .operating,            // ← ADD: Default to operating trip
            status: .planning,               // ← ADD: Start as planning (or .active if you want)
            pilotRole: selectedRole,
            receiptCount: 0,                 // ← ADD: No receipts yet
            logbookPageSent: false,          // ← ADD: Not sent yet
            perDiemStarted: nil,             // ← ADD: No per diem tracking yet
            perDiemEnded: nil                // ← ADD: No per diem tracking yet
        )
        
        // Update last used aircraft
        aircraftHistoryManager.updateLastAircraft(selectedAircraft)
        
        // Save trip
        onSave(newTrip)
        
        dismiss()
    }
    
    // MARK: - Alternative: Quick Start with Last Aircraft Button
    struct QuickStartTripButton: View {
        @ObservedObject var aircraftHistoryManager: AircraftHistoryManager
        let onCreateTrip: (String) -> Void
        
        var body: some View {
            if let lastAircraft = aircraftHistoryManager.lastUsedAircraft {
                Button(action: {
                    onCreateTrip(lastAircraft)
                }) {
                    HStack {
                        Image(systemName: "airplane.departure")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Start Trip")
                                .font(.headline)
                            Text("Using \(lastAircraft)")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(LogbookTheme.accentOrange.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
}

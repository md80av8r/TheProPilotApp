// AircraftLibraryStore.swift
// Persistent storage for aircraft library
// Created December 2025

import Foundation
import SwiftUI

class AircraftLibraryStore: ObservableObject {
    @Published var aircraft: [AircraftDefinition] = []
    
    private let saveKey = "AircraftLibrary"
    private let fileURL: URL
    
    init() {
        // Use App Group for sharing with Watch
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") {
            fileURL = containerURL.appendingPathComponent("aircraft_library.json")
        } else {
            // Fallback to documents directory
            fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("aircraft_library.json")
        }
        
        loadAircraft()
        
        // Add default aircraft if library is empty
        if aircraft.isEmpty {
            addDefaultAircraft()
        }
    }
    
    // MARK: - Default Aircraft Setup
    private func addDefaultAircraft() {
        // Add Jeff's known aircraft
        
        // N17WN - Beechcraft Bonanza
        var bonanza = AircraftTemplates.be36
        bonanza.id = UUID()
        bonanza.registration = "N17WN"
        bonanza.year = nil  // Can be updated later
        aircraft.append(bonanza)
        
        // USA Jet MD-88s
        let usaJetTails = ["N831US", "N832US", "N833US", "N835US", "N837US", "N842US"]
        for tail in usaJetTails {
            var md88 = AircraftTemplates.md88
            md88.id = UUID()
            md88.registration = tail
            aircraft.append(md88)
        }
        
        saveAircraft()
        print("✈️ Added \(aircraft.count) default aircraft to library")
    }
    
    // MARK: - CRUD Operations
    
    func addAircraft(_ newAircraft: AircraftDefinition) {
        // Check for duplicate registration
        if let existingIndex = aircraft.firstIndex(where: { $0.registration.uppercased() == newAircraft.registration.uppercased() }) {
            // Update existing
            aircraft[existingIndex] = newAircraft
            print("✈️ Updated aircraft: \(newAircraft.registration)")
        } else {
            // Add new
            aircraft.append(newAircraft)
            print("✈️ Added new aircraft: \(newAircraft.registration)")
        }
        saveAircraft()
    }
    
    func updateAircraft(_ updatedAircraft: AircraftDefinition) {
        if let index = aircraft.firstIndex(where: { $0.id == updatedAircraft.id }) {
            aircraft[index] = updatedAircraft
            saveAircraft()
            print("✈️ Updated aircraft: \(updatedAircraft.registration)")
        }
    }
    
    func deleteAircraft(_ aircraftToDelete: AircraftDefinition) {
        aircraft.removeAll { $0.id == aircraftToDelete.id }
        saveAircraft()
        print("✈️ Deleted aircraft: \(aircraftToDelete.registration)")
    }
    
    func deleteAircraft(at offsets: IndexSet) {
        let deletedRegs = offsets.map { aircraft[$0].registration }
        aircraft.remove(atOffsets: offsets)
        saveAircraft()
        print("✈️ Deleted aircraft: \(deletedRegs.joined(separator: ", "))")
    }
    
    // MARK: - Lookup Functions
    
    /// Find aircraft by registration (tail number)
    func findAircraft(byRegistration registration: String) -> AircraftDefinition? {
        return aircraft.first { $0.registration.uppercased() == registration.uppercased() }
    }
    
    /// Check if a registration exists in the library
    func hasAircraft(registration: String) -> Bool {
        return aircraft.contains { $0.registration.uppercased() == registration.uppercased() }
    }
    
    /// Get all unique registrations
    var allRegistrations: [String] {
        aircraft.map { $0.registration }.sorted()
    }
    
    /// Find aircraft that match a partial registration
    func searchAircraft(matching query: String) -> [AircraftDefinition] {
        guard !query.isEmpty else { return aircraft }
        let uppercaseQuery = query.uppercased()
        return aircraft.filter {
            $0.registration.uppercased().contains(uppercaseQuery) ||
            $0.typeCode.uppercased().contains(uppercaseQuery) ||
            $0.make.uppercased().contains(uppercaseQuery) ||
            $0.model.uppercased().contains(uppercaseQuery)
        }
    }
    
    // MARK: - Copy/Duplicate Functions
    
    /// Create a copy of an existing aircraft with a new registration
    func copyAircraft(_ source: AircraftDefinition, newRegistration: String) -> AircraftDefinition {
        var copy = source
        copy.id = UUID()
        copy.registration = newRegistration.uppercased()
        return copy
    }
    
    /// Create a new aircraft from a template
    func createFromTemplate(_ template: AircraftDefinition, registration: String) -> AircraftDefinition {
        var newAircraft = template
        newAircraft.id = UUID()
        newAircraft.registration = registration.uppercased()
        return newAircraft
    }
    
    /// Suggest a template based on registration pattern
    func suggestTemplate(for registration: String) -> AircraftDefinition? {
        let upper = registration.uppercased()
        
        // USA Jet pattern (N8xxUS)
        if upper.hasPrefix("N8") && upper.hasSuffix("US") {
            return AircraftTemplates.md88
        }
        
        // Check if similar to existing aircraft
        for existing in aircraft {
            // Same prefix pattern might be same type
            if upper.prefix(3) == existing.registration.prefix(3) {
                return existing
            }
        }
        
        return nil
    }
    
    // MARK: - Persistence
    
    private func saveAircraft() {
        do {
            let data = try JSONEncoder().encode(aircraft)
            try data.write(to: fileURL)
            print("💾 Saved \(aircraft.count) aircraft to library")
        } catch {
            print("❌ Failed to save aircraft library: \(error)")
        }
    }
    
    private func loadAircraft() {
        do {
            let data = try Data(contentsOf: fileURL)
            aircraft = try JSONDecoder().decode([AircraftDefinition].self, from: data)
            print("📂 Loaded \(aircraft.count) aircraft from library")
        } catch {
            print("📂 No existing aircraft library found, will create defaults")
            aircraft = []
        }
    }
    
    // MARK: - Export Support
    
    /// Get ForeFlight Aircraft Table rows for export
    func getForeFlightAircraftRows() -> [String] {
        var rows: [String] = []
        
        for ac in aircraft {
            let row = [
                ac.registration,
                ac.equipmentType.rawValue,
                ac.typeCode,
                ac.year != nil ? String(ac.year!) : "",
                ac.make,
                ac.model,
                ac.gearType.rawValue,
                ac.engineType.rawValue,
                ac.categoryClass.rawValue,
                ac.isComplex ? "TRUE" : "",
                ac.isHighPerformance ? "TRUE" : "",
                ac.isPressurized ? "TRUE" : "",
                ac.isTAA ? "TRUE" : ""
            ].joined(separator: ",")
            
            rows.append(row)
        }
        
        return rows
    }
}

// MARK: - Notification for New Aircraft Detection
extension Notification.Name {
    static let newAircraftDetected = Notification.Name("newAircraftDetected")
}

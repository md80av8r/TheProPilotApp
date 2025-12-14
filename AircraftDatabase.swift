// AircraftDatabase.swift
// Comprehensive Aircraft Database (Uses existing types from FlightEntry.swift)
// Created for ProPilot App

import Foundation
import SwiftUI

// MARK: - Gear Type (New - not defined elsewhere)

enum GearType: String, Codable, CaseIterable {
    case tricycle = "Tricycle"
    case tailwheel = "Tailwheel"
    case floats = "Floats"
    case skis = "Skis"
    case amphibious = "Amphibious"
    case retractable = "Retractable"
    
    var displayName: String { rawValue }
}

// MARK: - Aircraft Model

struct AircraftRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var tailNumber: String
    var typeDesignator: String
    var manufacturer: String
    var model: String
    var category: AircraftCategory
    var aircraftClass: AircraftClass
    var engineType: EngineType
    var engineCount: Int
    var gearType: GearType
    var isComplex: Bool
    var isHighPerformance: Bool
    var isTurbine: Bool
    var isPressurized: Bool
    var isTailwheel: Bool
    var requiresTypeRating: Bool
    var typeRatingDesignation: String?
    var notes: String
    var lastTATValue: String
    var dateAdded: Date
    var isUserAdded: Bool
    
    init(
        id: UUID = UUID(),
        tailNumber: String,
        typeDesignator: String = "",
        manufacturer: String = "",
        model: String = "",
        category: AircraftCategory = .airplane,
        aircraftClass: AircraftClass = .multiEngineLand,
        engineType: EngineType = .turbofan,
        engineCount: Int = 2,
        gearType: GearType = .retractable,
        isComplex: Bool = true,
        isHighPerformance: Bool = true,
        isTurbine: Bool = true,
        isPressurized: Bool = true,
        isTailwheel: Bool = false,
        requiresTypeRating: Bool = false,
        typeRatingDesignation: String? = nil,
        notes: String = "",
        lastTATValue: String = "",
        dateAdded: Date = Date(),
        isUserAdded: Bool = true
    ) {
        self.id = id
        self.tailNumber = tailNumber.uppercased()
        self.typeDesignator = typeDesignator.uppercased()
        self.manufacturer = manufacturer
        self.model = model
        self.category = category
        self.aircraftClass = aircraftClass
        self.engineType = engineType
        self.engineCount = engineCount
        self.gearType = gearType
        self.isComplex = isComplex
        self.isHighPerformance = isHighPerformance
        self.isTurbine = isTurbine
        self.isPressurized = isPressurized
        self.isTailwheel = isTailwheel
        self.requiresTypeRating = requiresTypeRating
        self.typeRatingDesignation = typeRatingDesignation
        self.notes = notes
        self.lastTATValue = lastTATValue
        self.dateAdded = dateAdded
        self.isUserAdded = isUserAdded
    }
    
    var categoryAndClass: String {
        "\(aircraftClass.displayName) - \(engineType.displayName)"
    }
    
    var displayTitle: String {
        if !model.isEmpty {
            return "\(tailNumber) - \(model)"
        } else if !typeDesignator.isEmpty {
            return "\(tailNumber) - \(typeDesignator)"
        }
        return tailNumber
    }
    
    var shortDescription: String {
        var parts: [String] = []
        parts.append(aircraftClass.abbreviation)
        parts.append(engineType.displayName)
        if engineCount > 1 {
            parts.append("\(engineCount) eng")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Aircraft Database Manager

class AircraftDatabaseManager: ObservableObject {
    static let shared = AircraftDatabaseManager()
    
    @Published var aircraft: [AircraftRecord] = [] {
        didSet { saveAircraft() }
    }
    
    @Published var lastUsedTailNumber: String?
    
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    private let aircraftKey = "AircraftDatabaseRecords"
    private let lastUsedKey = "LastUsedAircraftTail"
    
    private init() {
        loadAircraft()
        loadLastUsed()
    }
    
    // MARK: - CRUD Operations
    
    func addAircraft(_ newAircraft: AircraftRecord) {
        guard !aircraft.contains(where: { $0.tailNumber == newAircraft.tailNumber }) else {
            print("⚠️ Aircraft \(newAircraft.tailNumber) already exists")
            return
        }
        
        var aircraftToAdd = newAircraft
        aircraftToAdd.isUserAdded = true
        aircraftToAdd.dateAdded = Date()
        
        aircraft.append(aircraftToAdd)
        aircraft.sort { $0.tailNumber < $1.tailNumber }
        print("✅ Added aircraft: \(newAircraft.tailNumber)")
    }
    
    func updateAircraft(_ updatedAircraft: AircraftRecord) {
        guard let index = aircraft.firstIndex(where: { $0.id == updatedAircraft.id }) else {
            print("❌ Aircraft not found for update: \(updatedAircraft.tailNumber)")
            return
        }
        
        aircraft[index] = updatedAircraft
        print("✅ Updated aircraft: \(updatedAircraft.tailNumber)")
    }
    
    func deleteAircraft(_ aircraftToDelete: AircraftRecord) {
        aircraft.removeAll { $0.id == aircraftToDelete.id }
        print("🗑️ Deleted aircraft: \(aircraftToDelete.tailNumber)")
    }
    
    func deleteAircraft(at offsets: IndexSet) {
        let tailNumbers = offsets.map { aircraft[$0].tailNumber }
        aircraft.remove(atOffsets: offsets)
        print("🗑️ Deleted aircraft: \(tailNumbers.joined(separator: ", "))")
    }
    
    // MARK: - Lookup Methods
    
    func getAircraft(tailNumber: String) -> AircraftRecord? {
        let clean = tailNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return aircraft.first { $0.tailNumber == clean }
    }
    
    func getAircraft(byType typeDesignator: String) -> [AircraftRecord] {
        let clean = typeDesignator.uppercased()
        return aircraft.filter { $0.typeDesignator == clean }
    }
    
    func getAircraft(byClass aircraftClass: AircraftClass) -> [AircraftRecord] {
        return aircraft.filter { $0.aircraftClass == aircraftClass }
    }
    
    var allTailNumbers: [String] {
        aircraft.map { $0.tailNumber }.sorted()
    }
    
    var aircraftByClass: [AircraftClass: [AircraftRecord]] {
        Dictionary(grouping: aircraft, by: { $0.aircraftClass })
    }
    
    // MARK: - TAT Tracking
    
    func updateLastTAT(tailNumber: String, tatValue: String) {
        guard let index = aircraft.firstIndex(where: { $0.tailNumber == tailNumber.uppercased() }) else {
            return
        }
        aircraft[index].lastTATValue = tatValue
        print("📊 Updated TAT for \(tailNumber): \(tatValue)")
    }
    
    func getLastTAT(tailNumber: String) -> String? {
        let ac = getAircraft(tailNumber: tailNumber)
        return ac?.lastTATValue.isEmpty == false ? ac?.lastTATValue : nil
    }
    
    // MARK: - Last Used Tracking
    
    func setLastUsed(_ tailNumber: String) {
        lastUsedTailNumber = tailNumber.uppercased()
        userDefaults?.set(tailNumber.uppercased(), forKey: lastUsedKey)
        print("✈️ Last used aircraft: \(tailNumber)")
    }
    
    private func loadLastUsed() {
        lastUsedTailNumber = userDefaults?.string(forKey: lastUsedKey)
    }
    
    // MARK: - Persistence
    
    private func saveAircraft() {
        do {
            let data = try JSONEncoder().encode(aircraft)
            userDefaults?.set(data, forKey: aircraftKey)
            userDefaults?.synchronize()
            print("💾 Saved \(aircraft.count) aircraft to database")
        } catch {
            print("❌ Failed to save aircraft: \(error)")
        }
    }
    
    private func loadAircraft() {
        if let data = userDefaults?.data(forKey: aircraftKey) {
            do {
                aircraft = try JSONDecoder().decode([AircraftRecord].self, from: data)
                print("📋 Loaded \(aircraft.count) aircraft from database")
            } catch {
                print("❌ Failed to load aircraft: \(error)")
                aircraft = []
            }
        }
        
        if aircraft.isEmpty {
            seedDefaultAircraft()
        }
    }
    
    // MARK: - Default Aircraft (USA Jet Fleet)
    
    private func seedDefaultAircraft() {
        let ac1 = AircraftRecord(
            tailNumber: "N785TW",
            typeDesignator: "DC93",
            manufacturer: "McDonnell Douglas",
            model: "DC-9-30",
            category: .airplane,
            aircraftClass: .multiEngineLand,
            engineType: .turbofan,
            engineCount: 2,
            gearType: .retractable,
            isComplex: true,
            isHighPerformance: true,
            isTurbine: true,
            isPressurized: true,
            isTailwheel: false,
            requiresTypeRating: true,
            typeRatingDesignation: "DC-9",
            isUserAdded: false
        )
        
        let ac2 = AircraftRecord(
            tailNumber: "N216US",
            typeDesignator: "DC93",
            manufacturer: "McDonnell Douglas",
            model: "DC-9-30",
            category: .airplane,
            aircraftClass: .multiEngineLand,
            engineType: .turbofan,
            engineCount: 2,
            gearType: .retractable,
            isComplex: true,
            isHighPerformance: true,
            isTurbine: true,
            isPressurized: true,
            requiresTypeRating: true,
            typeRatingDesignation: "DC-9",
            isUserAdded: false
        )
        
        let ac3 = AircraftRecord(
            tailNumber: "N831US",
            typeDesignator: "MD83",
            manufacturer: "McDonnell Douglas",
            model: "MD-83",
            category: .airplane,
            aircraftClass: .multiEngineLand,
            engineType: .turbofan,
            engineCount: 2,
            gearType: .retractable,
            isComplex: true,
            isHighPerformance: true,
            isTurbine: true,
            isPressurized: true,
            requiresTypeRating: true,
            typeRatingDesignation: "DC-9",
            isUserAdded: false
        )
        
        aircraft = [ac1, ac2, ac3]
        print("🌱 Seeded \(aircraft.count) default aircraft")
    }
    
    // MARK: - Import/Export
    
    func exportToJSON() -> Data? {
        try? JSONEncoder().encode(aircraft)
    }
    
    func importFromJSON(_ data: Data) -> Int {
        guard let imported = try? JSONDecoder().decode([AircraftRecord].self, from: data) else {
            return 0
        }
        
        var addedCount = 0
        for ac in imported {
            if !aircraft.contains(where: { $0.tailNumber == ac.tailNumber }) {
                var newAc = ac
                newAc.id = UUID()
                newAc.isUserAdded = true
                newAc.dateAdded = Date()
                aircraft.append(newAc)
                addedCount += 1
            }
        }
        
        aircraft.sort { $0.tailNumber < $1.tailNumber }
        return addedCount
    }
}

// MARK: - Common Aircraft Types Database (for quick-add)

struct AircraftTypeTemplate {
    let typeDesignator: String
    let manufacturer: String
    let model: String
    let category: AircraftCategory
    let aircraftClass: AircraftClass
    let engineType: EngineType
    let engineCount: Int
    let isComplex: Bool
    let isHighPerformance: Bool
    let isTurbine: Bool
    let isPressurized: Bool
    let requiresTypeRating: Bool
    let typeRatingDesignation: String?
    
    func createAircraft(tailNumber: String) -> AircraftRecord {
        AircraftRecord(
            tailNumber: tailNumber,
            typeDesignator: typeDesignator,
            manufacturer: manufacturer,
            model: model,
            category: category,
            aircraftClass: aircraftClass,
            engineType: engineType,
            engineCount: engineCount,
            gearType: isComplex ? .retractable : .tricycle,
            isComplex: isComplex,
            isHighPerformance: isHighPerformance,
            isTurbine: isTurbine,
            isPressurized: isPressurized,
            isTailwheel: false,
            requiresTypeRating: requiresTypeRating,
            typeRatingDesignation: typeRatingDesignation
        )
    }
}

// MARK: - Common Aircraft Types Provider

struct CommonAircraftTypesProvider {
    
    static func getAllTypes() -> [String: AircraftTypeTemplate] {
        var types: [String: AircraftTypeTemplate] = [:]
        
        // Single Engine Piston
        addSingleEnginePiston(&types)
        
        // Single Engine Turboprop
        addSingleEngineTurboprop(&types)
        
        // Multi Engine Piston
        addMultiEnginePiston(&types)
        
        // Multi Engine Turboprop
        addMultiEngineTurboprop(&types)
        
        // Jets - Light/Medium
        addLightMediumJets(&types)
        
        // Jets - Large (Part 121)
        addLargeJets(&types)
        
        return types
    }
    
    private static func addSingleEnginePiston(_ types: inout [String: AircraftTypeTemplate]) {
        types["C172"] = AircraftTypeTemplate(
            typeDesignator: "C172", manufacturer: "Cessna", model: "172 Skyhawk",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .piston,
            engineCount: 1, isComplex: false, isHighPerformance: false,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["C182"] = AircraftTypeTemplate(
            typeDesignator: "C182", manufacturer: "Cessna", model: "182 Skylane",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .piston,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["PA28"] = AircraftTypeTemplate(
            typeDesignator: "PA28", manufacturer: "Piper", model: "PA-28 Cherokee",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .piston,
            engineCount: 1, isComplex: false, isHighPerformance: false,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["SR22"] = AircraftTypeTemplate(
            typeDesignator: "SR22", manufacturer: "Cirrus", model: "SR22",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .piston,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["BE36"] = AircraftTypeTemplate(
            typeDesignator: "BE36", manufacturer: "Beechcraft", model: "Bonanza A36",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .piston,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
    }
    
    private static func addSingleEngineTurboprop(_ types: inout [String: AircraftTypeTemplate]) {
        types["PC12"] = AircraftTypeTemplate(
            typeDesignator: "PC12", manufacturer: "Pilatus", model: "PC-12",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .turboprop,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["TBM9"] = AircraftTypeTemplate(
            typeDesignator: "TBM9", manufacturer: "Daher", model: "TBM 900",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .turboprop,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["C208"] = AircraftTypeTemplate(
            typeDesignator: "C208", manufacturer: "Cessna", model: "208 Caravan",
            category: .airplane, aircraftClass: .singleEngineLand, engineType: .turboprop,
            engineCount: 1, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
    }
    
    private static func addMultiEnginePiston(_ types: inout [String: AircraftTypeTemplate]) {
        types["BE58"] = AircraftTypeTemplate(
            typeDesignator: "BE58", manufacturer: "Beechcraft", model: "Baron 58",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .piston,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["PA34"] = AircraftTypeTemplate(
            typeDesignator: "PA34", manufacturer: "Piper", model: "PA-34 Seneca",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .piston,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["C310"] = AircraftTypeTemplate(
            typeDesignator: "C310", manufacturer: "Cessna", model: "310",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .piston,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: false, isPressurized: false, requiresTypeRating: false, typeRatingDesignation: nil
        )
    }
    
    private static func addMultiEngineTurboprop(_ types: inout [String: AircraftTypeTemplate]) {
        types["BE20"] = AircraftTypeTemplate(
            typeDesignator: "BE20", manufacturer: "Beechcraft", model: "King Air 200",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turboprop,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: false, typeRatingDesignation: nil
        )
        
        types["BE30"] = AircraftTypeTemplate(
            typeDesignator: "BE30", manufacturer: "Beechcraft", model: "King Air 350",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turboprop,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: false, typeRatingDesignation: nil
        )
    }
    
    private static func addLightMediumJets(_ types: inout [String: AircraftTypeTemplate]) {
        types["C510"] = AircraftTypeTemplate(
            typeDesignator: "C510", manufacturer: "Cessna", model: "Citation Mustang",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "CE-510"
        )
        
        types["C525"] = AircraftTypeTemplate(
            typeDesignator: "C525", manufacturer: "Cessna", model: "Citation CJ1",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "CE-525"
        )
        
        types["C560"] = AircraftTypeTemplate(
            typeDesignator: "C560", manufacturer: "Cessna", model: "Citation V/Ultra",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "CE-560"
        )
        
        types["LJ45"] = AircraftTypeTemplate(
            typeDesignator: "LJ45", manufacturer: "Learjet", model: "45",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "LR-JET"
        )
        
        types["H25B"] = AircraftTypeTemplate(
            typeDesignator: "H25B", manufacturer: "Hawker", model: "800XP",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "HS-125"
        )
    }
    
    private static func addLargeJets(_ types: inout [String: AircraftTypeTemplate]) {
        types["DC93"] = AircraftTypeTemplate(
            typeDesignator: "DC93", manufacturer: "McDonnell Douglas", model: "DC-9-30",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "DC-9"
        )
        
        types["MD83"] = AircraftTypeTemplate(
            typeDesignator: "MD83", manufacturer: "McDonnell Douglas", model: "MD-83",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "DC-9"
        )
        
        types["B737"] = AircraftTypeTemplate(
            typeDesignator: "B737", manufacturer: "Boeing", model: "737",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "B-737"
        )
        
        types["B738"] = AircraftTypeTemplate(
            typeDesignator: "B738", manufacturer: "Boeing", model: "737-800",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "B-737"
        )
        
        types["A320"] = AircraftTypeTemplate(
            typeDesignator: "A320", manufacturer: "Airbus", model: "A320",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "A-320"
        )
        
        types["B752"] = AircraftTypeTemplate(
            typeDesignator: "B752", manufacturer: "Boeing", model: "757-200",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "B-757"
        )
        
        types["B763"] = AircraftTypeTemplate(
            typeDesignator: "B763", manufacturer: "Boeing", model: "767-300",
            category: .airplane, aircraftClass: .multiEngineLand, engineType: .turbofan,
            engineCount: 2, isComplex: true, isHighPerformance: true,
            isTurbine: true, isPressurized: true, requiresTypeRating: true, typeRatingDesignation: "B-767"
        )
    }
}

// Global accessor for common types
let commonAircraftTypes: [String: AircraftTypeTemplate] = CommonAircraftTypesProvider.getAllTypes()

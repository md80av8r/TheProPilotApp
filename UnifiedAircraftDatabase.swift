// UnifiedAircraftDatabase.swift
// Merged Aircraft Database with CloudKit Sync and ForeFlight Export Support
// Created December 2025

import Foundation
import SwiftUI
import CloudKit

// MARK: - ForeFlight Compatible Gear Type
enum ForeFlightGearType: String, Codable, CaseIterable {
    case fixedTricycle = "FT"           // Fixed Tricycle
    case fixedConventional = "FC"       // Fixed Tailwheel
    case retractableTricycle = "RT"     // Retractable Tricycle
    case retractableConventional = "RC" // Retractable Tailwheel
    case amphibious = "AM"              // Amphibious
    case floats = "Floats"
    case skids = "Skids"
    
    var displayName: String {
        switch self {
        case .fixedTricycle: return "Fixed Tricycle"
        case .fixedConventional: return "Fixed Tailwheel"
        case .retractableTricycle: return "Retractable Tricycle"
        case .retractableConventional: return "Retractable Tailwheel"
        case .amphibious: return "Amphibious"
        case .floats: return "Floats"
        case .skids: return "Skids"
        }
    }
    
    var isTailwheel: Bool {
        self == .fixedConventional || self == .retractableConventional
    }
    
    var isRetractable: Bool {
        self == .retractableTricycle || self == .retractableConventional
    }
}

// MARK: - ForeFlight Compatible Engine Type
enum ForeFlightEngineType: String, Codable, CaseIterable {
    case piston = "Piston"
    case turboprop = "Turboprop"
    case turbofan = "Turbofan"
    case turbojet = "Turbojet"
    case turboshaft = "Turboshaft"
    case radial = "Radial"
    case electric = "Electric"
    case diesel = "Diesel"
    case nonPowered = "Non-Powered"
    
    var displayName: String { rawValue }
    
    var isTurbine: Bool {
        switch self {
        case .turboprop, .turbofan, .turbojet, .turboshaft:
            return true
        default:
            return false
        }
    }
}

// MARK: - ForeFlight Compatible Category/Class
enum ForeFlightCategoryClass: String, Codable, CaseIterable {
    case airplaneSingleEngineLand = "airplane_single_engine_land"
    case airplaneSingleEngineSea = "airplane_single_engine_sea"
    case airplaneMultiEngineLand = "airplane_multi_engine_land"
    case airplaneMultiEngineSea = "airplane_multi_engine_sea"
    case rotorcraftHelicopter = "rotorcraft_helicopter"
    case rotorcraftGyroplane = "rotorcraft_gyroplane"
    case glider = "glider"
    case lighterThanAir = "lighter_than_air"
    case poweredLift = "powered_lift"
    case poweredParachute = "powered_parachute_land"
    case weightShiftControl = "weight_shift_control_land"
    case simulator = "simulator"
    case ftd = "ftd"
    case atd = "atd"
    
    var displayName: String {
        switch self {
        case .airplaneSingleEngineLand: return "Airplane Single Engine Land"
        case .airplaneSingleEngineSea: return "Airplane Single Engine Sea"
        case .airplaneMultiEngineLand: return "Airplane Multi Engine Land"
        case .airplaneMultiEngineSea: return "Airplane Multi Engine Sea"
        case .rotorcraftHelicopter: return "Rotorcraft Helicopter"
        case .rotorcraftGyroplane: return "Rotorcraft Gyroplane"
        case .glider: return "Glider"
        case .lighterThanAir: return "Lighter Than Air"
        case .poweredLift: return "Powered Lift"
        case .poweredParachute: return "Powered Parachute"
        case .weightShiftControl: return "Weight Shift Control"
        case .simulator: return "Full Flight Simulator"
        case .ftd: return "Flight Training Device"
        case .atd: return "Aviation Training Device"
        }
    }
    
    var shortName: String {
        switch self {
        case .airplaneSingleEngineLand: return "ASEL"
        case .airplaneSingleEngineSea: return "ASES"
        case .airplaneMultiEngineLand: return "AMEL"
        case .airplaneMultiEngineSea: return "AMES"
        case .rotorcraftHelicopter: return "Heli"
        case .rotorcraftGyroplane: return "Gyro"
        case .glider: return "Glider"
        case .lighterThanAir: return "LTA"
        case .poweredLift: return "PL"
        case .poweredParachute: return "PPC"
        case .weightShiftControl: return "WSC"
        case .simulator: return "FFS"
        case .ftd: return "FTD"
        case .atd: return "ATD"
        }
    }
    
    var isMultiEngine: Bool {
        self == .airplaneMultiEngineLand || self == .airplaneMultiEngineSea
    }
}

// MARK: - Equipment Type (for ForeFlight)
enum EquipmentType: String, Codable, CaseIterable {
    case aircraft = "Aircraft"
    case simulator = "FFS"
    case ftd = "FTD"
    case batd = "BATD"
    case aatd = "AATD"
    
    var displayName: String { rawValue }
}

// MARK: - Unified Aircraft Record
struct Aircraft: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    
    // Core identification
    var tailNumber: String              // Registration (N831US)
    var typeCode: String                // ICAO type designator (MD88, BE36)
    var manufacturer: String            // Make (McDonnell Douglas)
    var model: String                   // Model (MD-88)
    var year: Int?                      // Year of manufacture
    
    // Classification
    var categoryClass: ForeFlightCategoryClass
    var gearType: ForeFlightGearType
    var engineType: ForeFlightEngineType
    var engineCount: Int
    var equipmentType: EquipmentType
    
    // FAA Endorsement Flags
    var isComplex: Bool                 // Flaps, retractable gear, controllable prop
    var isHighPerformance: Bool         // >200 HP
    var isTAA: Bool                     // Technically Advanced Aircraft
    var isPressurized: Bool
    var requiresTypeRating: Bool
    var typeRatingDesignation: String?
    
    // Tracking
    var lastTATValue: String            // Last known TAT for auto-fill
    var notes: String
    var dateAdded: Date
    var dateModified: Date
    var isUserAdded: Bool               // vs seeded default
    
    // CloudKit tracking
    var cloudKitRecordID: String?
    var lastSyncedAt: Date?
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        tailNumber: String,
        typeCode: String = "",
        manufacturer: String = "",
        model: String = "",
        year: Int? = nil,
        categoryClass: ForeFlightCategoryClass = .airplaneMultiEngineLand,
        gearType: ForeFlightGearType = .retractableTricycle,
        engineType: ForeFlightEngineType = .turbofan,
        engineCount: Int = 2,
        equipmentType: EquipmentType = .aircraft,
        isComplex: Bool = true,
        isHighPerformance: Bool = true,
        isTAA: Bool = false,
        isPressurized: Bool = true,
        requiresTypeRating: Bool = false,
        typeRatingDesignation: String? = nil,
        lastTATValue: String = "",
        notes: String = "",
        dateAdded: Date = Date(),
        dateModified: Date = Date(),
        isUserAdded: Bool = true,
        cloudKitRecordID: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.tailNumber = tailNumber.uppercased()
        self.typeCode = typeCode.uppercased()
        self.manufacturer = manufacturer
        self.model = model
        self.year = year
        self.categoryClass = categoryClass
        self.gearType = gearType
        self.engineType = engineType
        self.engineCount = engineCount
        self.equipmentType = equipmentType
        self.isComplex = isComplex
        self.isHighPerformance = isHighPerformance
        self.isTAA = isTAA
        self.isPressurized = isPressurized
        self.requiresTypeRating = requiresTypeRating
        self.typeRatingDesignation = typeRatingDesignation
        self.lastTATValue = lastTATValue
        self.notes = notes
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.isUserAdded = isUserAdded
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncedAt = lastSyncedAt
    }
    
    // MARK: - Computed Properties
    var displayTitle: String {
        if !model.isEmpty {
            return "\(tailNumber) - \(model)"
        } else if !typeCode.isEmpty {
            return "\(tailNumber) - \(typeCode)"
        }
        return tailNumber
    }
    
    var shortDescription: String {
        var parts: [String] = []
        parts.append(categoryClass.shortName)
        parts.append(engineType.displayName)
        if engineCount > 1 {
            parts.append("\(engineCount) eng")
        }
        return parts.joined(separator: " • ")
    }
    
    var isTailwheel: Bool {
        gearType.isTailwheel
    }
    
    var isTurbine: Bool {
        engineType.isTurbine
    }
    
    // MARK: - ForeFlight Export Row
    func foreFlightAircraftRow() -> String {
        // ForeFlight Aircraft Table format: 13 columns
        return [
            tailNumber,                                    // AircraftID
            equipmentType.rawValue,                        // equipType
            typeCode,                                      // TypeCode
            year != nil ? String(year!) : "",              // Year
            manufacturer,                                  // Make
            model,                                         // Model
            gearType.rawValue,                             // GearType
            engineType.rawValue,                           // EngineType
            categoryClass.rawValue,                        // Category/Class
            isComplex ? "TRUE" : "",                       // complexAircraft
            isHighPerformance ? "TRUE" : "",               // highPerformance
            isPressurized ? "TRUE" : "",                   // pressurized
            isTAA ? "TRUE" : ""                            // taa
        ].joined(separator: ",")
    }
    
    // MARK: - CloudKit Conversion
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Aircraft", recordID: recordID)
        
        record["tailNumber"] = tailNumber as NSString
        record["typeCode"] = typeCode as NSString
        record["manufacturer"] = manufacturer as NSString
        record["model"] = model as NSString
        record["year"] = (year ?? 0) as NSNumber
        record["categoryClass"] = categoryClass.rawValue as NSString
        record["gearType"] = gearType.rawValue as NSString
        record["engineType"] = engineType.rawValue as NSString
        record["engineCount"] = engineCount as NSNumber
        record["equipmentType"] = equipmentType.rawValue as NSString
        record["isComplex"] = (isComplex ? 1 : 0) as NSNumber
        record["isHighPerformance"] = (isHighPerformance ? 1 : 0) as NSNumber
        record["isTAA"] = (isTAA ? 1 : 0) as NSNumber
        record["isPressurized"] = (isPressurized ? 1 : 0) as NSNumber
        record["requiresTypeRating"] = (requiresTypeRating ? 1 : 0) as NSNumber
        record["typeRatingDesignation"] = (typeRatingDesignation ?? "") as NSString
        record["lastTATValue"] = lastTATValue as NSString
        record["notes"] = notes as NSString
        record["dateAdded"] = dateAdded as NSDate
        record["dateModified"] = dateModified as NSDate
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> Aircraft? {
        guard let tailNumber = record["tailNumber"] as? String else { return nil }
        
        var aircraft = Aircraft(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            tailNumber: tailNumber
        )
        
        aircraft.typeCode = (record["typeCode"] as? String) ?? ""
        aircraft.manufacturer = (record["manufacturer"] as? String) ?? ""
        aircraft.model = (record["model"] as? String) ?? ""
        
        let yearNum = (record["year"] as? Int) ?? 0
        aircraft.year = yearNum > 0 ? yearNum : nil
        
        if let catClass = record["categoryClass"] as? String,
           let cat = ForeFlightCategoryClass(rawValue: catClass) {
            aircraft.categoryClass = cat
        }
        
        if let gear = record["gearType"] as? String,
           let g = ForeFlightGearType(rawValue: gear) {
            aircraft.gearType = g
        }
        
        if let engine = record["engineType"] as? String,
           let e = ForeFlightEngineType(rawValue: engine) {
            aircraft.engineType = e
        }
        
        aircraft.engineCount = (record["engineCount"] as? Int) ?? 2
        
        if let equip = record["equipmentType"] as? String,
           let eq = EquipmentType(rawValue: equip) {
            aircraft.equipmentType = eq
        }
        
        aircraft.isComplex = ((record["isComplex"] as? Int) ?? 0) == 1
        aircraft.isHighPerformance = ((record["isHighPerformance"] as? Int) ?? 0) == 1
        aircraft.isTAA = ((record["isTAA"] as? Int) ?? 0) == 1
        aircraft.isPressurized = ((record["isPressurized"] as? Int) ?? 0) == 1
        aircraft.requiresTypeRating = ((record["requiresTypeRating"] as? Int) ?? 0) == 1
        
        let typeRating = record["typeRatingDesignation"] as? String
        aircraft.typeRatingDesignation = (typeRating?.isEmpty == false) ? typeRating : nil
        
        aircraft.lastTATValue = (record["lastTATValue"] as? String) ?? ""
        aircraft.notes = (record["notes"] as? String) ?? ""
        aircraft.dateAdded = (record["dateAdded"] as? Date) ?? Date()
        
        // Handle dateModified - could be Date or Int64 (timestamp)
        if let dateModified = record["dateModified"] as? Date {
            aircraft.dateModified = dateModified
        } else if let timestamp = record["dateModified"] as? Int64 {
            aircraft.dateModified = Date(timeIntervalSince1970: Double(timestamp))
        } else if let timestampInt = record["dateModified"] as? Int {
            aircraft.dateModified = Date(timeIntervalSince1970: Double(timestampInt))
        } else {
            aircraft.dateModified = Date()
        }
        
        aircraft.cloudKitRecordID = record.recordID.recordName
        aircraft.lastSyncedAt = Date()
        
        return aircraft
    }
}

// MARK: - Unified Aircraft Database Manager
@MainActor
class UnifiedAircraftDatabase: ObservableObject {
    static let shared = UnifiedAircraftDatabase()
    
    @Published var aircraft: [Aircraft] = []
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private let container = CKContainer(identifier: "iCloud.com.jkadans.ProPilotApp")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    private let localStorageKey = "UnifiedAircraftDatabase"
    
    private init() {
        loadFromLocal()
        
        // Sync from CloudKit on launch
        Task {
            await syncFromCloudKit()
        }
    }
    
    // MARK: - CRUD Operations
    
    func addAircraft(_ newAircraft: Aircraft) {
        guard !aircraft.contains(where: { $0.tailNumber == newAircraft.tailNumber }) else {
            print("⚠️ Aircraft \(newAircraft.tailNumber) already exists")
            return
        }
        
        var ac = newAircraft
        ac.isUserAdded = true
        ac.dateAdded = Date()
        ac.dateModified = Date()
        
        aircraft.append(ac)
        aircraft.sort { $0.tailNumber < $1.tailNumber }
        
        saveToLocal()
        
        // Sync to CloudKit
        Task {
            await saveToCloudKit(ac)
        }
        
        print("✅ Added aircraft: \(newAircraft.tailNumber)")
    }
    
    func updateAircraft(_ updatedAircraft: Aircraft) {
        guard let index = aircraft.firstIndex(where: { $0.id == updatedAircraft.id }) else {
            print("❌ Aircraft not found: \(updatedAircraft.tailNumber)")
            return
        }
        
        var ac = updatedAircraft
        ac.dateModified = Date()
        
        aircraft[index] = ac
        saveToLocal()
        
        // Sync to CloudKit
        Task {
            await saveToCloudKit(ac)
        }
        
        print("✅ Updated aircraft: \(updatedAircraft.tailNumber)")
    }
    
    func deleteAircraft(_ aircraftToDelete: Aircraft) {
        aircraft.removeAll { $0.id == aircraftToDelete.id }
        saveToLocal()
        
        // Delete from CloudKit
        Task {
            await deleteFromCloudKit(aircraftToDelete)
        }
        
        print("🗑️ Deleted aircraft: \(aircraftToDelete.tailNumber)")
    }
    
    // MARK: - Lookup Methods
    
    func findAircraft(byTailNumber tailNumber: String) -> Aircraft? {
        let clean = tailNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return aircraft.first { $0.tailNumber == clean }
    }
    
    func findAircraft(byTypeCode typeCode: String) -> [Aircraft] {
        let clean = typeCode.uppercased()
        return aircraft.filter { $0.typeCode == clean }
    }
    
    func searchAircraft(matching query: String) -> [Aircraft] {
        let search = query.lowercased()
        return aircraft.filter { ac in
            ac.tailNumber.lowercased().contains(search) ||
            ac.typeCode.lowercased().contains(search) ||
            ac.manufacturer.lowercased().contains(search) ||
            ac.model.lowercased().contains(search)
        }
    }
    
    var allTailNumbers: [String] {
        aircraft.map { $0.tailNumber }.sorted()
    }
    
    // MARK: - TAT Tracking
    
    func updateLastTAT(tailNumber: String, tatValue: String) {
        guard let index = aircraft.firstIndex(where: { $0.tailNumber == tailNumber.uppercased() }) else {
            return
        }
        aircraft[index].lastTATValue = tatValue
        aircraft[index].dateModified = Date()
        saveToLocal()
        
        Task {
            await saveToCloudKit(aircraft[index])
        }
        
        print("📊 Updated TAT for \(tailNumber): \(tatValue)")
    }
    
    func getLastTAT(tailNumber: String) -> String? {
        let ac = findAircraft(byTailNumber: tailNumber)
        return ac?.lastTATValue.isEmpty == false ? ac?.lastTATValue : nil
    }
    
    // MARK: - ForeFlight Export
    
    func getForeFlightAircraftRows(for tailNumbers: Set<String>) -> [String] {
        var rows: [String] = []
        
        for tail in tailNumbers.sorted() {
            if let ac = findAircraft(byTailNumber: tail) {
                rows.append(ac.foreFlightAircraftRow())
            } else {
                // Aircraft not in library - add basic row
                rows.append("\(tail),,,,,,,,,,,,")
            }
        }
        
        return rows
    }
    
    // MARK: - Local Persistence
    
    private func saveToLocal() {
        do {
            let data = try JSONEncoder().encode(aircraft)
            userDefaults?.set(data, forKey: localStorageKey)
            userDefaults?.synchronize()
            print("💾 Saved \(aircraft.count) aircraft locally")
        } catch {
            print("❌ Failed to save aircraft locally: \(error)")
        }
    }
    
    private func loadFromLocal() {
        if let data = userDefaults?.data(forKey: localStorageKey) {
            do {
                aircraft = try JSONDecoder().decode([Aircraft].self, from: data)
                print("📋 Loaded \(aircraft.count) aircraft from local storage")
            } catch {
                print("❌ Failed to load aircraft: \(error)")
                aircraft = []
            }
        }
        
        // Seed defaults if empty
        if aircraft.isEmpty {
            seedDefaultAircraft()
        }
    }
    
    // MARK: - CloudKit Sync
    
    func syncFromCloudKit() async {
        print("☁️ Syncing aircraft from CloudKit...")
        isSyncing = true
        syncError = nil
        
        do {
            let query = CKQuery(recordType: "Aircraft", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDB.records(matching: query)
            
            var cloudAircraft: [Aircraft] = []
            for (_, result) in matchResults {
                if case .success(let record) = result,
                   let ac = Aircraft.fromCKRecord(record) {
                    cloudAircraft.append(ac)
                }
            }
            
            print("☁️ Found \(cloudAircraft.count) aircraft in CloudKit")
            
            // Merge: CloudKit wins for conflicts, but keep local-only items
            var mergedAircraft: [Aircraft] = []
            
            // Add all cloud aircraft
            for cloudAc in cloudAircraft {
                mergedAircraft.append(cloudAc)
            }
            
            // Add local-only aircraft (not in cloud yet)
            for localAc in aircraft {
                if !cloudAircraft.contains(where: { $0.id == localAc.id }) {
                    mergedAircraft.append(localAc)
                    // Push to cloud
                    await saveToCloudKit(localAc)
                }
            }
            
            aircraft = mergedAircraft.sorted { $0.tailNumber < $1.tailNumber }
            saveToLocal()
            
            lastSyncTime = Date()
            print("✅ CloudKit sync complete: \(aircraft.count) aircraft")
            
        } catch let error as CKError {
            // Handle "Unknown Item" (schema doesn't exist) gracefully
            if error.errorCode == 11 { // CKError.unknownItem
                print("⚠️ CloudKit schema not set up yet. Aircraft will be stored locally only.")
                print("   To enable sync, create 'Aircraft' record type in CloudKit Dashboard.")
                syncError = "CloudKit schema not configured. Data saved locally."
                
                // Still update lastSyncTime to avoid repeated attempts
                lastSyncTime = Date()
            } else {
                print("❌ CloudKit sync failed: \(error)")
                syncError = error.localizedDescription
            }
        } catch {
            print("❌ CloudKit sync failed: \(error)")
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    private func saveToCloudKit(_ aircraft: Aircraft) async {
        do {
            let record = aircraft.toCKRecord()
            _ = try await privateDB.save(record)
            print("☁️ Saved \(aircraft.tailNumber) to CloudKit")
        } catch let error as CKError {
            if error.errorCode == 11 { // Unknown Item - schema not set up
                print("⚠️ CloudKit schema not configured. \(aircraft.tailNumber) saved locally only.")
            } else {
                print("❌ Failed to save \(aircraft.tailNumber) to CloudKit: \(error)")
            }
        } catch {
            print("❌ Failed to save \(aircraft.tailNumber) to CloudKit: \(error)")
        }
    }
    
    private func deleteFromCloudKit(_ aircraft: Aircraft) async {
        let recordID = CKRecord.ID(recordName: aircraft.id.uuidString)
        do {
            try await privateDB.deleteRecord(withID: recordID)
            print("☁️ Deleted \(aircraft.tailNumber) from CloudKit")
        } catch {
            print("❌ Failed to delete \(aircraft.tailNumber) from CloudKit: \(error)")
        }
    }
    
    // MARK: - Default Aircraft (Your Fleet)
    
    private func seedDefaultAircraft() {
        let defaults: [Aircraft] = [
            // Your Bonanza
            Aircraft(
                tailNumber: "N17WN",
                typeCode: "BE36",
                manufacturer: "Beechcraft",
                model: "Bonanza A36",
                categoryClass: .airplaneSingleEngineLand,
                gearType: .retractableTricycle,
                engineType: .piston,
                engineCount: 1,
                isComplex: true,
                isHighPerformance: true,
                isTAA: false,
                isPressurized: false,
                requiresTypeRating: false,
                isUserAdded: false
            ),
            
            // USA Jet MD-88 Fleet
            Aircraft(
                tailNumber: "N831US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isTAA: false,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            ),
            Aircraft(
                tailNumber: "N832US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            ),
            Aircraft(
                tailNumber: "N833US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            ),
            Aircraft(
                tailNumber: "N835US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            ),
            Aircraft(
                tailNumber: "N837US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            ),
            Aircraft(
                tailNumber: "N842US",
                typeCode: "MD88",
                manufacturer: "McDonnell Douglas",
                model: "MD-88",
                categoryClass: .airplaneMultiEngineLand,
                gearType: .retractableTricycle,
                engineType: .turbofan,
                engineCount: 2,
                isComplex: true,
                isHighPerformance: true,
                isPressurized: true,
                requiresTypeRating: true,
                typeRatingDesignation: "DC-9",
                isUserAdded: false
            )
        ]
        
        aircraft = defaults
        saveToLocal()
        
        // Push to CloudKit
        Task {
            for ac in defaults {
                await saveToCloudKit(ac)
            }
        }
        
        print("🌱 Seeded \(aircraft.count) default aircraft")
    }
    
    // MARK: - Copy/Duplicate
    
    func copyAircraft(_ source: Aircraft, newTailNumber: String) -> Aircraft {
        var newAc = source
        newAc.id = UUID()
        newAc.tailNumber = newTailNumber.uppercased()
        newAc.lastTATValue = ""
        newAc.dateAdded = Date()
        newAc.dateModified = Date()
        newAc.isUserAdded = true
        newAc.cloudKitRecordID = nil
        newAc.lastSyncedAt = nil
        return newAc
    }
}

// MARK: - Aircraft Templates for Quick Add
struct AircraftTemplate {
    let name: String
    let typeCode: String
    let manufacturer: String
    let model: String
    let categoryClass: ForeFlightCategoryClass
    let gearType: ForeFlightGearType
    let engineType: ForeFlightEngineType
    let engineCount: Int
    let isComplex: Bool
    let isHighPerformance: Bool
    let isPressurized: Bool
    let requiresTypeRating: Bool
    let typeRatingDesignation: String?
    
    func createAircraft(tailNumber: String) -> Aircraft {
        Aircraft(
            tailNumber: tailNumber,
            typeCode: typeCode,
            manufacturer: manufacturer,
            model: model,
            categoryClass: categoryClass,
            gearType: gearType,
            engineType: engineType,
            engineCount: engineCount,
            isComplex: isComplex,
            isHighPerformance: isHighPerformance,
            isPressurized: isPressurized,
            requiresTypeRating: requiresTypeRating,
            typeRatingDesignation: typeRatingDesignation
        )
    }
    
    // Pre-built templates
    static let templates: [AircraftTemplate] = [
        // Single Engine Piston
        AircraftTemplate(name: "Cessna 172", typeCode: "C172", manufacturer: "Cessna", model: "172 Skyhawk",
                        categoryClass: .airplaneSingleEngineLand, gearType: .fixedTricycle, engineType: .piston,
                        engineCount: 1, isComplex: false, isHighPerformance: false, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Cessna 182", typeCode: "C182", manufacturer: "Cessna", model: "182 Skylane",
                        categoryClass: .airplaneSingleEngineLand, gearType: .fixedTricycle, engineType: .piston,
                        engineCount: 1, isComplex: true, isHighPerformance: true, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Beechcraft Bonanza A36", typeCode: "BE36", manufacturer: "Beechcraft", model: "Bonanza A36",
                        categoryClass: .airplaneSingleEngineLand, gearType: .retractableTricycle, engineType: .piston,
                        engineCount: 1, isComplex: true, isHighPerformance: true, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Piper Cherokee", typeCode: "P28A", manufacturer: "Piper", model: "PA-28 Cherokee",
                        categoryClass: .airplaneSingleEngineLand, gearType: .fixedTricycle, engineType: .piston,
                        engineCount: 1, isComplex: false, isHighPerformance: false, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Cirrus SR22", typeCode: "SR22", manufacturer: "Cirrus", model: "SR22",
                        categoryClass: .airplaneSingleEngineLand, gearType: .fixedTricycle, engineType: .piston,
                        engineCount: 1, isComplex: false, isHighPerformance: true, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        // Multi Engine Piston
        AircraftTemplate(name: "Beechcraft Baron 58", typeCode: "BE58", manufacturer: "Beechcraft", model: "Baron 58",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .piston,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Piper Seneca", typeCode: "PA34", manufacturer: "Piper", model: "PA-34 Seneca",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .piston,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: false,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        // Turboprops
        AircraftTemplate(name: "King Air 200", typeCode: "BE20", manufacturer: "Beechcraft", model: "King Air 200",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .turboprop,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        AircraftTemplate(name: "Pilatus PC-12", typeCode: "PC12", manufacturer: "Pilatus", model: "PC-12",
                        categoryClass: .airplaneSingleEngineLand, gearType: .retractableTricycle, engineType: .turboprop,
                        engineCount: 1, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: false, typeRatingDesignation: nil),
        
        // Jets
        AircraftTemplate(name: "McDonnell Douglas MD-88", typeCode: "MD88", manufacturer: "McDonnell Douglas", model: "MD-88",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .turbofan,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: true, typeRatingDesignation: "DC-9"),
        
        AircraftTemplate(name: "Boeing 737-800", typeCode: "B738", manufacturer: "Boeing", model: "737-800",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .turbofan,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: true, typeRatingDesignation: "B-737"),
        
        AircraftTemplate(name: "Airbus A320", typeCode: "A320", manufacturer: "Airbus", model: "A320",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .turbofan,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: true, typeRatingDesignation: "A-320"),
        
        AircraftTemplate(name: "Citation CJ1", typeCode: "C525", manufacturer: "Cessna", model: "Citation CJ1",
                        categoryClass: .airplaneMultiEngineLand, gearType: .retractableTricycle, engineType: .turbofan,
                        engineCount: 2, isComplex: true, isHighPerformance: true, isPressurized: true,
                        requiresTypeRating: true, typeRatingDesignation: "CE-525")
    ]
}

// AircraftDefinition.swift
// Aircraft Library data model for ProPilot
// Created December 2025

import Foundation

// MARK: - Aircraft Definition Model
struct AircraftDefinition: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var registration: String        // N833US, N17WN
    var typeCode: String            // MD88, BE36
    var year: Int?                  // 1990
    var make: String                // McDonnell Douglas, Beechcraft
    var model: String               // MD-88, Bonanza A36
    var gearType: AircraftGearType  // RT, FT, etc.
    var engineType: AircraftEngineType  // Turbofan, Piston, etc.
    var categoryClass: AircraftCategoryClass
    var equipmentType: AircraftEquipmentType
    var isComplex: Bool
    var isHighPerformance: Bool
    var isPressurized: Bool
    var isTAA: Bool                 // Technically Advanced Aircraft
    
    // Computed property for display name
    var displayName: String {
        "\(registration) - \(make) \(model)"
    }
    
    // Computed property for short display
    var shortName: String {
        "\(registration) (\(typeCode))"
    }
}

// MARK: - Gear Type
enum AircraftGearType: String, Codable, CaseIterable {
    case fixedTricycle = "FT"
    case fixedTailwheel = "FC"
    case retractableTricycle = "RT"
    case retractableTailwheel = "RC"
    case amphibian = "AM"
    case floats = "Floats"
    case skids = "Skids"
    
    var displayName: String {
        switch self {
        case .fixedTricycle: return "Fixed Tricycle"
        case .fixedTailwheel: return "Fixed Tailwheel"
        case .retractableTricycle: return "Retractable Tricycle"
        case .retractableTailwheel: return "Retractable Tailwheel"
        case .amphibian: return "Amphibian"
        case .floats: return "Floats"
        case .skids: return "Skids"
        }
    }
}

// MARK: - Engine Type
enum AircraftEngineType: String, Codable, CaseIterable {
    case piston = "Piston"
    case turboprop = "Turboprop"
    case turbofan = "Turbofan"
    case turbojet = "Turbojet"
    case turboshaft = "Turboshaft"
    case radial = "Radial"
    case electric = "Electric"
    case diesel = "Diesel"
    case nonPowered = "Non-Powered"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Category/Class (FAA)
enum AircraftCategoryClass: String, Codable, CaseIterable {
    case airplaneSingleEngineLand = "airplane_single_engine_land"
    case airplaneMultiEngineLand = "airplane_multi_engine_land"
    case airplaneSingleEngineSea = "airplane_single_engine_sea"
    case airplaneMultiEngineSea = "airplane_multi_engine_sea"
    case rotorcraftHelicopter = "rotorcraft_helicopter"
    case rotorcraftGyroplane = "rotorcraft_gyroplane"
    case glider = "glider"
    case lighterThanAirAirship = "lighter_than_air_airship"
    case lighterThanAirBalloon = "lighter_than_air_balloon"
    case poweredLift = "powered_lift"
    case poweredParachuteLand = "powered_parachute_land"
    case poweredParachuteSea = "powered_parachute_sea"
    case weightShiftControlLand = "weight_shift_control_land"
    case weightShiftControlSea = "weight_shift_control_sea"
    
    var displayName: String {
        switch self {
        case .airplaneSingleEngineLand: return "Airplane Single-Engine Land"
        case .airplaneMultiEngineLand: return "Airplane Multi-Engine Land"
        case .airplaneSingleEngineSea: return "Airplane Single-Engine Sea"
        case .airplaneMultiEngineSea: return "Airplane Multi-Engine Sea"
        case .rotorcraftHelicopter: return "Rotorcraft Helicopter"
        case .rotorcraftGyroplane: return "Rotorcraft Gyroplane"
        case .glider: return "Glider"
        case .lighterThanAirAirship: return "Lighter Than Air - Airship"
        case .lighterThanAirBalloon: return "Lighter Than Air - Balloon"
        case .poweredLift: return "Powered Lift"
        case .poweredParachuteLand: return "Powered Parachute Land"
        case .poweredParachuteSea: return "Powered Parachute Sea"
        case .weightShiftControlLand: return "Weight-Shift Control Land"
        case .weightShiftControlSea: return "Weight-Shift Control Sea"
        }
    }
    
    var shortName: String {
        switch self {
        case .airplaneSingleEngineLand: return "ASEL"
        case .airplaneMultiEngineLand: return "AMEL"
        case .airplaneSingleEngineSea: return "ASES"
        case .airplaneMultiEngineSea: return "AMES"
        case .rotorcraftHelicopter: return "RH"
        case .rotorcraftGyroplane: return "RG"
        case .glider: return "GL"
        case .lighterThanAirAirship: return "LTA-A"
        case .lighterThanAirBalloon: return "LTA-B"
        case .poweredLift: return "PL"
        case .poweredParachuteLand: return "PPL"
        case .poweredParachuteSea: return "PPS"
        case .weightShiftControlLand: return "WSCL"
        case .weightShiftControlSea: return "WSCS"
        }
    }
}

// MARK: - Equipment Type (FAA)
enum AircraftEquipmentType: String, Codable, CaseIterable {
    case aircraft = "Aircraft"
    case ffs = "FFS"        // Full Flight Simulator
    case ftd = "FTD"        // Flight Training Device
    case batd = "BATD"      // Basic Aviation Training Device
    case aatd = "AATD"      // Advanced Aviation Training Device
    
    var displayName: String {
        switch self {
        case .aircraft: return "Aircraft"
        case .ffs: return "Full Flight Simulator (FFS)"
        case .ftd: return "Flight Training Device (FTD)"
        case .batd: return "Basic Aviation Training Device (BATD)"
        case .aatd: return "Advanced Aviation Training Device (AATD)"
        }
    }
}

// MARK: - Aircraft Templates (Pre-defined configurations)
struct AircraftTemplates {
    
    // MD-88 Template (USA Jet)
    static let md88 = AircraftDefinition(
        registration: "",
        typeCode: "MD88",
        year: nil,
        make: "McDonnell Douglas",
        model: "MD-88",
        gearType: .retractableTricycle,
        engineType: .turbofan,
        categoryClass: .airplaneMultiEngineLand,
        equipmentType: .aircraft,
        isComplex: true,
        isHighPerformance: true,
        isPressurized: true,
        isTAA: false
    )
    
    // Beechcraft Bonanza A36 Template
    static let be36 = AircraftDefinition(
        registration: "",
        typeCode: "BE36",
        year: nil,
        make: "Beechcraft",
        model: "Bonanza A36",
        gearType: .retractableTricycle,
        engineType: .piston,
        categoryClass: .airplaneSingleEngineLand,
        equipmentType: .aircraft,
        isComplex: true,
        isHighPerformance: true,
        isPressurized: false,
        isTAA: false
    )
    
    // Common Templates for quick selection
    static let allTemplates: [(name: String, template: AircraftDefinition)] = [
        ("MD-88 (Airliner)", md88),
        ("Beechcraft Bonanza A36", be36),
        ("Cessna 172 (Basic)", cessna172),
        ("Cessna 182 (High Performance)", cessna182),
        ("Piper Cherokee", piperCherokee),
        ("Boeing 737", boeing737),
        ("Custom (Blank)", blank)
    ]
    
    // Additional common templates
    static let cessna172 = AircraftDefinition(
        registration: "",
        typeCode: "C172",
        year: nil,
        make: "Cessna",
        model: "172 Skyhawk",
        gearType: .fixedTricycle,
        engineType: .piston,
        categoryClass: .airplaneSingleEngineLand,
        equipmentType: .aircraft,
        isComplex: false,
        isHighPerformance: false,
        isPressurized: false,
        isTAA: false
    )
    
    static let cessna182 = AircraftDefinition(
        registration: "",
        typeCode: "C182",
        year: nil,
        make: "Cessna",
        model: "182 Skylane",
        gearType: .fixedTricycle,
        engineType: .piston,
        categoryClass: .airplaneSingleEngineLand,
        equipmentType: .aircraft,
        isComplex: false,
        isHighPerformance: true,
        isPressurized: false,
        isTAA: false
    )
    
    static let piperCherokee = AircraftDefinition(
        registration: "",
        typeCode: "P28A",
        year: nil,
        make: "Piper",
        model: "Cherokee",
        gearType: .fixedTricycle,
        engineType: .piston,
        categoryClass: .airplaneSingleEngineLand,
        equipmentType: .aircraft,
        isComplex: false,
        isHighPerformance: false,
        isPressurized: false,
        isTAA: false
    )
    
    static let boeing737 = AircraftDefinition(
        registration: "",
        typeCode: "B738",
        year: nil,
        make: "Boeing",
        model: "737-800",
        gearType: .retractableTricycle,
        engineType: .turbofan,
        categoryClass: .airplaneMultiEngineLand,
        equipmentType: .aircraft,
        isComplex: true,
        isHighPerformance: true,
        isPressurized: true,
        isTAA: false
    )
    
    static let blank = AircraftDefinition(
        registration: "",
        typeCode: "",
        year: nil,
        make: "",
        model: "",
        gearType: .fixedTricycle,
        engineType: .piston,
        categoryClass: .airplaneSingleEngineLand,
        equipmentType: .aircraft,
        isComplex: false,
        isHighPerformance: false,
        isPressurized: false,
        isTAA: false
    )
}

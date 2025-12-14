// FlightEntry.swift - Clean Implementation (Uses existing PilotRole from Trip.swift)
import Foundation

// MARK: - Aviation Types (Only the ones not already defined)

enum AircraftCategory: String, CaseIterable, Codable {
    case airplane = "Airplane"
    case rotorcraft = "Rotorcraft"
    case glider = "Glider"
    case lightSportAircraft = "Light Sport Aircraft"
    case poweredLift = "Powered Lift"
    case ffs = "Full Flight Simulator"
    case ftd = "Flight Training Device"
    
    var displayName: String { rawValue }
}

enum AircraftClass: String, CaseIterable, Codable {
    case singleEngineLand = "Single Engine Land"
    case singleEngineSea = "Single Engine Sea"
    case multiEngineLand = "Multi Engine Land"
    case multiEngineSea = "Multi Engine Sea"
    case helicopter = "Helicopter"
    case gyroplane = "Gyroplane"
    
    var displayName: String { rawValue }
    var abbreviation: String {
        switch self {
        case .singleEngineLand: return "SEL"
        case .singleEngineSea: return "SES"
        case .multiEngineLand: return "MEL"
        case .multiEngineSea: return "MES"
        case .helicopter: return "HEL"
        case .gyroplane: return "GYR"
        }
    }
}

enum EngineType: String, CaseIterable, Codable {
    case piston = "Piston"
    case turboprop = "Turboprop"
    case turbojet = "Turbojet"
    case turbofan = "Turbofan"
    case electric = "Electric"
    
    var displayName: String { rawValue }
}

enum FlightRules: String, CaseIterable, Codable {
    case vfr = "VFR"
    case ifr = "IFR"
    case svfr = "SVFR"
    
    var displayName: String { rawValue }
}

struct InstrumentApproach: Codable {
    let type: ApproachType
    let runway: String
    let airport: String
    
    enum ApproachType: String, CaseIterable, Codable {
        case ils = "ILS"
        case loc = "LOC"
        case vor = "VOR"
        case ndb = "NDB"
        case gps = "GPS"
        case rnav = "RNAV"
        case rnp = "RNP"
        case tacan = "TACAN"
        case lda = "LDA"
        case sdf = "SDF"
        case visual = "Visual"
        case contact = "Contact"
        
        var displayName: String { rawValue }
    }
}

// MARK: - Flight Entry Model
struct FlightEntry: Identifiable, Codable {
    var id: UUID
    
    // Basic Flight Info
    let date: Date
    let aircraftType: String
    let aircraftRegistration: String
    let departure: String  // ICAO code
    let arrival: String    // ICAO code
    
    // Times (all in seconds for precision)
    let blockOut: Date
    let blockIn: Date
    let totalTime: TimeInterval      // Block time
    let flightTime: TimeInterval     // Actual air time
    let crossCountryTime: TimeInterval
    let nightTime: TimeInterval
    let instrumentTime: TimeInterval
    let simulatedInstrumentTime: TimeInterval
    let dualGivenTime: TimeInterval
    let dualReceivedTime: TimeInterval
    let picTime: TimeInterval        // Pilot in Command
    let sicTime: TimeInterval        // Second in Command
    let soloTime: TimeInterval
    
    // Landings
    let dayLandings: Int
    let nightLandings: Int
    let instrumentLandings: Int
    
    // Pilot Role & Aircraft Category (Uses existing PilotRole from Trip.swift)
    let pilotRole: PilotRole
    let aircraftCategory: AircraftCategory
    let aircraftClass: AircraftClass
    let aircraftEngine: EngineType
    
    // Approaches & Procedures
    let approaches: [InstrumentApproach]
    let holds: Int
    
    // Flight Rules & Conditions
    let flightRules: FlightRules
    let actualInstrument: TimeInterval
    let simulatedInstrument: TimeInterval
    
    // Notes & Additional Info
    let route: String
    let remarks: String
    let flightNumber: String?
    let passengers: Int
    
    // USA Jet specific
    let tripNumber: String?
    let isDeadhead: Bool
    let perDiemEligible: Bool
    
    // MARK: - CodingKeys for Codable
    enum CodingKeys: String, CodingKey {
        case id, date, aircraftType, aircraftRegistration, departure, arrival
        case blockOut, blockIn, totalTime, flightTime, crossCountryTime, nightTime
        case instrumentTime, simulatedInstrumentTime, dualGivenTime, dualReceivedTime
        case picTime, sicTime, soloTime, dayLandings, nightLandings, instrumentLandings
        case pilotRole, aircraftCategory, aircraftClass, aircraftEngine
        case approaches, holds, flightRules, actualInstrument, simulatedInstrument
        case route, remarks, flightNumber, passengers, tripNumber, isDeadhead, perDiemEligible
    }
    
    // Custom initializer to ensure proper UUID generation
    init(date: Date, aircraftType: String, aircraftRegistration: String, departure: String, arrival: String,
         blockOut: Date, blockIn: Date, totalTime: TimeInterval, flightTime: TimeInterval,
         crossCountryTime: TimeInterval, nightTime: TimeInterval, instrumentTime: TimeInterval,
         simulatedInstrumentTime: TimeInterval, dualGivenTime: TimeInterval, dualReceivedTime: TimeInterval,
         picTime: TimeInterval, sicTime: TimeInterval, soloTime: TimeInterval,
         dayLandings: Int, nightLandings: Int, instrumentLandings: Int,
         pilotRole: PilotRole, aircraftCategory: AircraftCategory, aircraftClass: AircraftClass,
         aircraftEngine: EngineType, approaches: [InstrumentApproach], holds: Int,
         flightRules: FlightRules, actualInstrument: TimeInterval, simulatedInstrument: TimeInterval,
         route: String, remarks: String, flightNumber: String?, passengers: Int,
         tripNumber: String?, isDeadhead: Bool, perDiemEligible: Bool) {
        
        self.id = UUID()
        self.date = date
        self.aircraftType = aircraftType
        self.aircraftRegistration = aircraftRegistration
        self.departure = departure
        self.arrival = arrival
        self.blockOut = blockOut
        self.blockIn = blockIn
        self.totalTime = totalTime
        self.flightTime = flightTime
        self.crossCountryTime = crossCountryTime
        self.nightTime = nightTime
        self.instrumentTime = instrumentTime
        self.simulatedInstrumentTime = simulatedInstrumentTime
        self.dualGivenTime = dualGivenTime
        self.dualReceivedTime = dualReceivedTime
        self.picTime = picTime
        self.sicTime = sicTime
        self.soloTime = soloTime
        self.dayLandings = dayLandings
        self.nightLandings = nightLandings
        self.instrumentLandings = instrumentLandings
        self.pilotRole = pilotRole
        self.aircraftCategory = aircraftCategory
        self.aircraftClass = aircraftClass
        self.aircraftEngine = aircraftEngine
        self.approaches = approaches
        self.holds = holds
        self.flightRules = flightRules
        self.actualInstrument = actualInstrument
        self.simulatedInstrument = simulatedInstrument
        self.route = route
        self.remarks = remarks
        self.flightNumber = flightNumber
        self.passengers = passengers
        self.tripNumber = tripNumber
        self.isDeadhead = isDeadhead
        self.perDiemEligible = perDiemEligible
    }
    
    // Codable implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID - try to decode, or create new if not present
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            self.id = decodedId
        } else {
            self.id = UUID()
        }
        
        self.date = try container.decode(Date.self, forKey: .date)
        self.aircraftType = try container.decode(String.self, forKey: .aircraftType)
        self.aircraftRegistration = try container.decode(String.self, forKey: .aircraftRegistration)
        self.departure = try container.decode(String.self, forKey: .departure)
        self.arrival = try container.decode(String.self, forKey: .arrival)
        self.blockOut = try container.decode(Date.self, forKey: .blockOut)
        self.blockIn = try container.decode(Date.self, forKey: .blockIn)
        self.totalTime = try container.decode(TimeInterval.self, forKey: .totalTime)
        self.flightTime = try container.decode(TimeInterval.self, forKey: .flightTime)
        self.crossCountryTime = try container.decode(TimeInterval.self, forKey: .crossCountryTime)
        self.nightTime = try container.decode(TimeInterval.self, forKey: .nightTime)
        self.instrumentTime = try container.decode(TimeInterval.self, forKey: .instrumentTime)
        self.simulatedInstrumentTime = try container.decode(TimeInterval.self, forKey: .simulatedInstrumentTime)
        self.dualGivenTime = try container.decode(TimeInterval.self, forKey: .dualGivenTime)
        self.dualReceivedTime = try container.decode(TimeInterval.self, forKey: .dualReceivedTime)
        self.picTime = try container.decode(TimeInterval.self, forKey: .picTime)
        self.sicTime = try container.decode(TimeInterval.self, forKey: .sicTime)
        self.soloTime = try container.decode(TimeInterval.self, forKey: .soloTime)
        self.dayLandings = try container.decode(Int.self, forKey: .dayLandings)
        self.nightLandings = try container.decode(Int.self, forKey: .nightLandings)
        self.instrumentLandings = try container.decode(Int.self, forKey: .instrumentLandings)
        self.pilotRole = try container.decode(PilotRole.self, forKey: .pilotRole)
        self.aircraftCategory = try container.decode(AircraftCategory.self, forKey: .aircraftCategory)
        self.aircraftClass = try container.decode(AircraftClass.self, forKey: .aircraftClass)
        self.aircraftEngine = try container.decode(EngineType.self, forKey: .aircraftEngine)
        self.approaches = try container.decode([InstrumentApproach].self, forKey: .approaches)
        self.holds = try container.decode(Int.self, forKey: .holds)
        self.flightRules = try container.decode(FlightRules.self, forKey: .flightRules)
        self.actualInstrument = try container.decode(TimeInterval.self, forKey: .actualInstrument)
        self.simulatedInstrument = try container.decode(TimeInterval.self, forKey: .simulatedInstrument)
        self.route = try container.decode(String.self, forKey: .route)
        self.remarks = try container.decode(String.self, forKey: .remarks)
        self.flightNumber = try container.decodeIfPresent(String.self, forKey: .flightNumber)
        self.passengers = try container.decode(Int.self, forKey: .passengers)
        self.tripNumber = try container.decodeIfPresent(String.self, forKey: .tripNumber)
        self.isDeadhead = try container.decode(Bool.self, forKey: .isDeadhead)
        self.perDiemEligible = try container.decode(Bool.self, forKey: .perDiemEligible)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(aircraftType, forKey: .aircraftType)
        try container.encode(aircraftRegistration, forKey: .aircraftRegistration)
        try container.encode(departure, forKey: .departure)
        try container.encode(arrival, forKey: .arrival)
        try container.encode(blockOut, forKey: .blockOut)
        try container.encode(blockIn, forKey: .blockIn)
        try container.encode(totalTime, forKey: .totalTime)
        try container.encode(flightTime, forKey: .flightTime)
        try container.encode(crossCountryTime, forKey: .crossCountryTime)
        try container.encode(nightTime, forKey: .nightTime)
        try container.encode(instrumentTime, forKey: .instrumentTime)
        try container.encode(simulatedInstrumentTime, forKey: .simulatedInstrumentTime)
        try container.encode(dualGivenTime, forKey: .dualGivenTime)
        try container.encode(dualReceivedTime, forKey: .dualReceivedTime)
        try container.encode(picTime, forKey: .picTime)
        try container.encode(sicTime, forKey: .sicTime)
        try container.encode(soloTime, forKey: .soloTime)
        try container.encode(dayLandings, forKey: .dayLandings)
        try container.encode(nightLandings, forKey: .nightLandings)
        try container.encode(instrumentLandings, forKey: .instrumentLandings)
        try container.encode(pilotRole, forKey: .pilotRole)
        try container.encode(aircraftCategory, forKey: .aircraftCategory)
        try container.encode(aircraftClass, forKey: .aircraftClass)
        try container.encode(aircraftEngine, forKey: .aircraftEngine)
        try container.encode(approaches, forKey: .approaches)
        try container.encode(holds, forKey: .holds)
        try container.encode(flightRules, forKey: .flightRules)
        try container.encode(actualInstrument, forKey: .actualInstrument)
        try container.encode(simulatedInstrument, forKey: .simulatedInstrument)
        try container.encode(route, forKey: .route)
        try container.encode(remarks, forKey: .remarks)
        try container.encodeIfPresent(flightNumber, forKey: .flightNumber)
        try container.encode(passengers, forKey: .passengers)
        try container.encodeIfPresent(tripNumber, forKey: .tripNumber)
        try container.encode(isDeadhead, forKey: .isDeadhead)
        try container.encode(perDiemEligible, forKey: .perDiemEligible)
    }
    
    // Computed properties for display
    var formattedTotalTime: String { formatLogbookTime(totalTime) }
    var formattedFlightTime: String { formatLogbookTime(flightTime) }
    var formattedNightTime: String { formatLogbookTime(nightTime) }
    var formattedCrossCountryTime: String { formatLogbookTime(crossCountryTime) }
    var formattedInstrumentTime: String { formatLogbookTime(instrumentTime) }
    var formattedPICTime: String { formatLogbookTime(picTime) }
    var formattedSICTime: String { formatLogbookTime(sicTime) }
    
    private func formatLogbookTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

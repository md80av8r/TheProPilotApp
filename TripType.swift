//
//  TripType.swift
//  ProPilotApp
//
//  Trip types (shared with Watch) and Document types (iOS only)
//

import Foundation

// MARK: - Trip Type (Shared with Watch)
enum TripType: String, CaseIterable, Codable, Equatable {
    case operating = "Operating"
    case deadhead = "Deadhead"
    case simulator = "Simulator"
    
    /// Determines if this trip type counts toward trip pay
    /// Only operating flights count as trips for pay purposes
    var countAsTrip: Bool {
        switch self {
        case .operating:
            return true
        case .deadhead, .simulator:
            return false
        }
    }
    
    /// Determines if this trip type counts toward FAR 117 flight/duty time limits
    /// Operating and deadhead count, but simulator training does not
    var countsTowardFAR117: Bool {
        switch self {
        case .operating, .deadhead:
            return true
        case .simulator:
            return false
        }
    }
    
    /// Display name for UI
    var displayName: String {
        return self.rawValue
    }
    
    /// Icon name for UI display
    var iconName: String {
        switch self {
        case .operating:
            return "airplane"
        case .deadhead:
            return "airplane.departure"
        case .simulator:
            return "gamecontroller.fill"
        }
    }
}

// MARK: - Document Type (iOS Only - for Scanning)
#if !os(watchOS)
enum TripDocumentType: String, CaseIterable, Codable, Equatable {
    case fuelReceipt = "Fuel Receipt"
    case customsGendec = "Customs GENDEC"
    case groundHandler = "Ground Handler Form"
    case shipper = "Shipper"
    case reweighForm = "Re-Weigh Form"
    case loadManifest = "Load Manifest"
    case weatherBriefing = "Weather Briefing"
    case logPage = "Log Page"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .fuelReceipt: return "fuelpump.fill"
        case .customsGendec: return "airplane.departure"
        case .groundHandler: return "person.fill.checkmark"
        case .shipper: return "shippingbox.fill"
        case .reweighForm: return "scalemass.fill"
        case .loadManifest: return "list.clipboard.fill"
        case .weatherBriefing: return "cloud.sun.fill"
        case .logPage: return "doc.text.fill"
        case .other: return "doc.fill"
        }
    }
    
    // Folder name within trip directory
    var folderName: String {
        return rawValue.replacingOccurrences(of: " ", with: "_")
    }
    
    // File name prefix
    var filePrefix: String {
        return rawValue.replacingOccurrences(of: " ", with: "_")
    }
    
    // Email subject template fields that user can select
    var availableSubjectFields: [EmailField] {
        switch self {
        case .fuelReceipt:
            return [.tripNumber, .aircraft, .date, .departure, .arrival]
        case .customsGendec:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .crew]
        case .groundHandler:
            return [.tripNumber, .aircraft, .date, .arrival]
        case .shipper:
            return [.tripNumber, .aircraft, .date, .departure, .arrival]
        case .reweighForm:
            return [.tripNumber, .aircraft, .date]
        case .loadManifest:
            return [.tripNumber, .aircraft, .date, .departure, .arrival]
        case .weatherBriefing:
            return [.tripNumber, .date, .departure, .arrival]
        case .logPage:
            return [.tripNumber, .aircraft, .date, .route, .crew]
        case .other:
            return [.tripNumber, .aircraft, .date]
        }
    }
    
    // Email body template fields
    var availableBodyFields: [EmailField] {
        switch self {
        case .fuelReceipt:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .blockTime]
        case .customsGendec:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .crew, .passengers]
        case .groundHandler:
            return [.tripNumber, .aircraft, .date, .arrival, .blockTime]
        case .shipper:
            return [.tripNumber, .aircraft, .date, .departure, .arrival]
        case .reweighForm:
            return [.tripNumber, .aircraft, .date]
        case .loadManifest:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .blockTime]
        case .weatherBriefing:
            return [.tripNumber, .date, .departure, .arrival]
        case .logPage:
            return [.tripNumber, .aircraft, .date, .route, .crew, .blockTime]
        case .other:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .crew, .blockTime]
        }
    }
    
    // Default subject template (Trip Number ALWAYS FIRST)
    var defaultSubjectTemplate: [EmailField] {
        switch self {
        case .fuelReceipt:
            return [.tripNumber, .aircraft, .departure, .arrival]
        case .customsGendec:
            return [.tripNumber, .aircraft, .arrival]
        case .groundHandler:
            return [.tripNumber, .arrival]
        case .shipper:
            return [.tripNumber, .departure, .arrival]
        case .reweighForm:
            return [.tripNumber, .aircraft]
        case .loadManifest:
            return [.tripNumber, .departure, .arrival]
        case .weatherBriefing:
            return [.tripNumber, .departure, .arrival, .date]
        case .logPage:
            return [.tripNumber, .aircraft, .date]
        case .other:
            return [.tripNumber, .aircraft]
        }
    }
    
    // Default body template
    var defaultBodyTemplate: [EmailField] {
        switch self {
        case .fuelReceipt:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .blockTime]
        case .customsGendec:
            return [.tripNumber, .aircraft, .date, .departure, .arrival, .crew]
        case .groundHandler:
            return [.tripNumber, .aircraft, .arrival, .blockTime]
        case .shipper:
            return [.tripNumber, .aircraft, .departure, .arrival]
        case .reweighForm:
            return [.tripNumber, .aircraft, .date]
        case .loadManifest:
            return [.tripNumber, .aircraft, .date, .departure, .arrival]
        case .weatherBriefing:
            return [.tripNumber, .departure, .arrival, .date]
        case .logPage:
            return [.tripNumber, .aircraft, .date, .route, .crew, .blockTime]
        case .other:
            return [.tripNumber, .aircraft, .date]
        }
    }
}
#endif 

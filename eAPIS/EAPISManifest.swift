//
//  EAPISManifest.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import Foundation
import CloudKit

// MARK: - EAPIS Manifest Model
struct EAPISManifest: Identifiable, Codable {
    var id: String
    
    // Flight Information
    var tripID: String? // Link to ProPilot trip
    var flightNumber: String
    var aircraftRegistration: String
    var aircraftType: String
    
    // Route Information
    var departureAirport: String // ICAO code
    var departureDate: Date
    var departureTime: Date
    var arrivalAirport: String // ICAO code
    var estimatedArrivalDate: Date
    var estimatedArrivalTime: Date
    
    // Crew Information
    var pilotInCommand: String // Pilot's name
    var pilotLicense: String
    var copilotName: String?
    var copilotLicense: String?
    
    // Passengers
    var passengerIDs: [String] // References to Passenger records
    
    // Purpose of Flight
    var purposeOfFlight: FlightPurpose
    var customsPurpose: String // Additional details
    
    // Customs & Border Information
    var countryOfOrigin: String // ISO country code
    var destinationCountry: String // ISO country code
    var customsDeclarations: Bool
    var declarationDetails: String
    
    // Document Status
    var status: ManifestStatus
    var filedDate: Date?
    var confirmationNumber: String?
    
    // Metadata
    var createdDate: Date
    var lastModifiedDate: Date
    var notes: String
    
    // CloudKit
    var recordID: CKRecord.ID?
    var recordChangeTag: String?
    
    enum FlightPurpose: String, Codable, CaseIterable {
        case business = "Business"
        case pleasure = "Pleasure"
        case training = "Training"
        case ferry = "Ferry Flight"
        case cargo = "Cargo"
        case other = "Other"
        
        var requiresDetails: Bool {
            self == .other
        }
    }
    
    enum ManifestStatus: String, Codable {
        case draft = "Draft"
        case readyToFile = "Ready to File"
        case filed = "Filed"
        case archived = "Archived"
        
        var color: String {
            switch self {
            case .draft: return "gray"
            case .readyToFile: return "orange"
            case .filed: return "green"
            case .archived: return "blue"
            }
        }
    }
    
    // MARK: - Initializers
    init(id: String = UUID().uuidString,
         tripID: String? = nil,
         flightNumber: String = "",
         aircraftRegistration: String = "",
         aircraftType: String = "",
         departureAirport: String = "",
         departureDate: Date = Date(),
         departureTime: Date = Date(),
         arrivalAirport: String = "",
         estimatedArrivalDate: Date = Date(),
         estimatedArrivalTime: Date = Date(),
         pilotInCommand: String = "",
         pilotLicense: String = "",
         copilotName: String? = nil,
         copilotLicense: String? = nil,
         passengerIDs: [String] = [],
         purposeOfFlight: FlightPurpose = .business,
         customsPurpose: String = "",
         countryOfOrigin: String = "US",
         destinationCountry: String = "",
         customsDeclarations: Bool = false,
         declarationDetails: String = "",
         status: ManifestStatus = .draft,
         filedDate: Date? = nil,
         confirmationNumber: String? = nil,
         createdDate: Date = Date(),
         lastModifiedDate: Date = Date(),
         notes: String = "",
         recordID: CKRecord.ID? = nil,
         recordChangeTag: String? = nil) {
        self.id = id
        self.tripID = tripID
        self.flightNumber = flightNumber
        self.aircraftRegistration = aircraftRegistration
        self.aircraftType = aircraftType
        self.departureAirport = departureAirport
        self.departureDate = departureDate
        self.departureTime = departureTime
        self.arrivalAirport = arrivalAirport
        self.estimatedArrivalDate = estimatedArrivalDate
        self.estimatedArrivalTime = estimatedArrivalTime
        self.pilotInCommand = pilotInCommand
        self.pilotLicense = pilotLicense
        self.copilotName = copilotName
        self.copilotLicense = copilotLicense
        self.passengerIDs = passengerIDs
        self.purposeOfFlight = purposeOfFlight
        self.customsPurpose = customsPurpose
        self.countryOfOrigin = countryOfOrigin
        self.destinationCountry = destinationCountry
        self.customsDeclarations = customsDeclarations
        self.declarationDetails = declarationDetails
        self.status = status
        self.filedDate = filedDate
        self.confirmationNumber = confirmationNumber
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.notes = notes
        self.recordID = recordID
        self.recordChangeTag = recordChangeTag
    }
    
    // MARK: - Computed Properties
    var totalPassengers: Int {
        passengerIDs.count
    }
    
    var isFiled: Bool {
        status == .filed
    }
    
    var canBeFiled: Bool {
        status == .readyToFile && isValid
    }
    
    // MARK: - Validation
    var isValid: Bool {
        !flightNumber.isEmpty &&
        !aircraftRegistration.isEmpty &&
        !departureAirport.isEmpty &&
        !arrivalAirport.isEmpty &&
        !pilotInCommand.isEmpty &&
        !pilotLicense.isEmpty &&
        !destinationCountry.isEmpty &&
        !passengerIDs.isEmpty
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if flightNumber.isEmpty { errors.append("Flight number is required") }
        if aircraftRegistration.isEmpty { errors.append("Aircraft registration is required") }
        if departureAirport.isEmpty { errors.append("Departure airport is required") }
        if arrivalAirport.isEmpty { errors.append("Arrival airport is required") }
        if pilotInCommand.isEmpty { errors.append("Pilot in command name is required") }
        if pilotLicense.isEmpty { errors.append("Pilot license number is required") }
        if destinationCountry.isEmpty { errors.append("Destination country is required") }
        if passengerIDs.isEmpty { errors.append("At least one passenger is required") }
        
        return errors
    }
    
    // MARK: - CloudKit Conversion
    func toCloudKitRecord() -> CKRecord {
        let record: CKRecord
        if let existingRecordID = recordID {
            record = CKRecord(recordType: "EAPISManifest", recordID: existingRecordID)
        } else {
            record = CKRecord(recordType: "EAPISManifest")
        }
        
        // Flight Information
        if let tripID = tripID {
            record["tripID"] = tripID as CKRecordValue
        }
        record["flightNumber"] = flightNumber as CKRecordValue
        record["aircraftRegistration"] = aircraftRegistration as CKRecordValue
        record["aircraftType"] = aircraftType as CKRecordValue
        
        // Route Information
        record["departureAirport"] = departureAirport as CKRecordValue
        record["departureDate"] = departureDate as CKRecordValue
        record["departureTime"] = departureTime as CKRecordValue
        record["arrivalAirport"] = arrivalAirport as CKRecordValue
        record["estimatedArrivalDate"] = estimatedArrivalDate as CKRecordValue
        record["estimatedArrivalTime"] = estimatedArrivalTime as CKRecordValue
        
        // Crew Information
        record["pilotInCommand"] = pilotInCommand as CKRecordValue
        record["pilotLicense"] = pilotLicense as CKRecordValue
        if let copilotName = copilotName {
            record["copilotName"] = copilotName as CKRecordValue
        }
        if let copilotLicense = copilotLicense {
            record["copilotLicense"] = copilotLicense as CKRecordValue
        }
        
        // Passengers (stored as comma-separated string)
        record["passengerIDs"] = passengerIDs.joined(separator: ",") as CKRecordValue
        
        // Purpose & Customs
        record["purposeOfFlight"] = purposeOfFlight.rawValue as CKRecordValue
        record["customsPurpose"] = customsPurpose as CKRecordValue
        record["countryOfOrigin"] = countryOfOrigin as CKRecordValue
        record["destinationCountry"] = destinationCountry as CKRecordValue
        record["customsDeclarations"] = customsDeclarations ? 1 : 0 as CKRecordValue
        record["declarationDetails"] = declarationDetails as CKRecordValue
        
        // Status
        record["status"] = status.rawValue as CKRecordValue
        if let filedDate = filedDate {
            record["filedDate"] = filedDate as CKRecordValue
        }
        if let confirmationNumber = confirmationNumber {
            record["confirmationNumber"] = confirmationNumber as CKRecordValue
        }
        
        // Metadata
        record["createdDate"] = createdDate as CKRecordValue
        record["lastModifiedDate"] = Date() as CKRecordValue
        record["notes"] = notes as CKRecordValue
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> EAPISManifest? {
        guard let flightNumber = record["flightNumber"] as? String,
              let aircraftRegistration = record["aircraftRegistration"] as? String,
              let departureAirport = record["departureAirport"] as? String,
              let departureDate = record["departureDate"] as? Date,
              let departureTime = record["departureTime"] as? Date,
              let arrivalAirport = record["arrivalAirport"] as? String,
              let estimatedArrivalDate = record["estimatedArrivalDate"] as? Date,
              let estimatedArrivalTime = record["estimatedArrivalTime"] as? Date,
              let pilotInCommand = record["pilotInCommand"] as? String,
              let pilotLicense = record["pilotLicense"] as? String,
              let passengerIDsString = record["passengerIDs"] as? String,
              let purposeString = record["purposeOfFlight"] as? String,
              let purpose = FlightPurpose(rawValue: purposeString),
              let countryOfOrigin = record["countryOfOrigin"] as? String,
              let destinationCountry = record["destinationCountry"] as? String,
              let statusString = record["status"] as? String,
              let status = ManifestStatus(rawValue: statusString) else {
            return nil
        }
        
        let passengerIDs = passengerIDsString.split(separator: ",").map { String($0) }
        
        return EAPISManifest(
            id: record.recordID.recordName,
            tripID: record["tripID"] as? String,
            flightNumber: flightNumber,
            aircraftRegistration: aircraftRegistration,
            aircraftType: record["aircraftType"] as? String ?? "",
            departureAirport: departureAirport,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalAirport: arrivalAirport,
            estimatedArrivalDate: estimatedArrivalDate,
            estimatedArrivalTime: estimatedArrivalTime,
            pilotInCommand: pilotInCommand,
            pilotLicense: pilotLicense,
            copilotName: record["copilotName"] as? String,
            copilotLicense: record["copilotLicense"] as? String,
            passengerIDs: passengerIDs,
            purposeOfFlight: purpose,
            customsPurpose: record["customsPurpose"] as? String ?? "",
            countryOfOrigin: countryOfOrigin,
            destinationCountry: destinationCountry,
            customsDeclarations: (record["customsDeclarations"] as? Int ?? 0) == 1,
            declarationDetails: record["declarationDetails"] as? String ?? "",
            status: status,
            filedDate: record["filedDate"] as? Date,
            confirmationNumber: record["confirmationNumber"] as? String,
            createdDate: record["createdDate"] as? Date ?? Date(),
            lastModifiedDate: record["lastModifiedDate"] as? Date ?? Date(),
            notes: record["notes"] as? String ?? "",
            recordID: record.recordID,
            recordChangeTag: record.recordChangeTag
        )
    }
}
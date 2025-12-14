//
//  Passenger.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import Foundation
import CloudKit

// MARK: - Passenger Model
struct Passenger: Identifiable, Codable, Hashable {
    var id: String
    
    // Personal Information
    var firstName: String
    var middleName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: Gender
    
    // Citizenship & Travel Documents
    var nationality: String // ISO country code
    var passportNumber: String
    var passportIssuingCountry: String // ISO country code
    var passportExpirationDate: Date
    
    // Address Information
    var streetAddress: String
    var city: String
    var state: String
    var postalCode: String
    var country: String // ISO country code
    
    // Contact Information
    var phoneNumber: String
    var email: String
    
    // Additional EAPIS Fields
    var weight: Int? // For weight & balance if needed
    var frequentFlyerNumber: String?
    var knownTravelerNumber: String? // TSA PreCheck/Global Entry
    var redressNumber: String? // For travelers with watch list issues
    
    // Metadata
    var createdDate: Date
    var lastModifiedDate: Date
    var isFavorite: Bool
    var notes: String
    
    // CloudKit
    var recordID: CKRecord.ID?
    var recordChangeTag: String?
    
    enum Gender: String, Codable, CaseIterable {
        case male = "M"
        case female = "F"
        case other = "X"
        
        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .other: return "Other/Unspecified"
            }
        }
    }
    
    // MARK: - Initializers
    init(id: String = UUID().uuidString,
         firstName: String = "",
         middleName: String = "",
         lastName: String = "",
         dateOfBirth: Date = Date(),
         gender: Gender = .male,
         nationality: String = "US",
         passportNumber: String = "",
         passportIssuingCountry: String = "US",
         passportExpirationDate: Date = Date(),
         streetAddress: String = "",
         city: String = "",
         state: String = "",
         postalCode: String = "",
         country: String = "US",
         phoneNumber: String = "",
         email: String = "",
         weight: Int? = nil,
         frequentFlyerNumber: String? = nil,
         knownTravelerNumber: String? = nil,
         redressNumber: String? = nil,
         createdDate: Date = Date(),
         lastModifiedDate: Date = Date(),
         isFavorite: Bool = false,
         notes: String = "",
         recordID: CKRecord.ID? = nil,
         recordChangeTag: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.nationality = nationality
        self.passportNumber = passportNumber
        self.passportIssuingCountry = passportIssuingCountry
        self.passportExpirationDate = passportExpirationDate
        self.streetAddress = streetAddress
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.phoneNumber = phoneNumber
        self.email = email
        self.weight = weight
        self.frequentFlyerNumber = frequentFlyerNumber
        self.knownTravelerNumber = knownTravelerNumber
        self.redressNumber = redressNumber
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.isFavorite = isFavorite
        self.notes = notes
        self.recordID = recordID
        self.recordChangeTag = recordChangeTag
    }
    
    // MARK: - Computed Properties
    var fullName: String {
        let components = [firstName, middleName, lastName].filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }
    
    var lastFirstName: String {
        "\(lastName), \(firstName)"
    }
    
    var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 0
    }
    
    var isPassportExpired: Bool {
        passportExpirationDate < Date()
    }
    
    var passportExpiresWithin6Months: Bool {
        guard let sixMonthsFromNow = Calendar.current.date(byAdding: .month, value: 6, to: Date()) else {
            return false
        }
        return passportExpirationDate < sixMonthsFromNow
    }
    
    // MARK: - Validation
    var isValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !passportNumber.isEmpty &&
        !passportIssuingCountry.isEmpty &&
        !nationality.isEmpty &&
        !isPassportExpired
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if firstName.isEmpty { errors.append("First name is required") }
        if lastName.isEmpty { errors.append("Last name is required") }
        if passportNumber.isEmpty { errors.append("Passport number is required") }
        if passportIssuingCountry.isEmpty { errors.append("Passport issuing country is required") }
        if nationality.isEmpty { errors.append("Nationality is required") }
        if isPassportExpired { errors.append("Passport is expired") }
        if passportExpiresWithin6Months { errors.append("Passport expires within 6 months") }
        
        return errors
    }
    
    // MARK: - CloudKit Conversion
    func toCloudKitRecord() -> CKRecord {
        let record: CKRecord
        if let existingRecordID = recordID {
            record = CKRecord(recordType: "Passenger", recordID: existingRecordID)
        } else {
            record = CKRecord(recordType: "Passenger")
        }
        
        // Personal Information
        record["firstName"] = firstName as CKRecordValue
        record["middleName"] = middleName as CKRecordValue
        record["lastName"] = lastName as CKRecordValue
        record["dateOfBirth"] = dateOfBirth as CKRecordValue
        record["gender"] = gender.rawValue as CKRecordValue
        
        // Citizenship & Travel Documents
        record["nationality"] = nationality as CKRecordValue
        record["passportNumber"] = passportNumber as CKRecordValue
        record["passportIssuingCountry"] = passportIssuingCountry as CKRecordValue
        record["passportExpirationDate"] = passportExpirationDate as CKRecordValue
        
        // Address Information
        record["streetAddress"] = streetAddress as CKRecordValue
        record["city"] = city as CKRecordValue
        record["state"] = state as CKRecordValue
        record["postalCode"] = postalCode as CKRecordValue
        record["country"] = country as CKRecordValue
        
        // Contact Information
        record["phoneNumber"] = phoneNumber as CKRecordValue
        record["email"] = email as CKRecordValue
        
        // Additional Fields
        if let weight = weight {
            record["weight"] = weight as CKRecordValue
        }
        if let ffn = frequentFlyerNumber {
            record["frequentFlyerNumber"] = ffn as CKRecordValue
        }
        if let ktn = knownTravelerNumber {
            record["knownTravelerNumber"] = ktn as CKRecordValue
        }
        if let rn = redressNumber {
            record["redressNumber"] = rn as CKRecordValue
        }
        
        // Metadata
        record["createdDate"] = createdDate as CKRecordValue
        record["lastModifiedDate"] = Date() as CKRecordValue
        record["isFavorite"] = isFavorite ? 1 : 0 as CKRecordValue
        record["notes"] = notes as CKRecordValue
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> Passenger? {
        guard let firstName = record["firstName"] as? String,
              let lastName = record["lastName"] as? String,
              let dateOfBirth = record["dateOfBirth"] as? Date,
              let genderString = record["gender"] as? String,
              let gender = Gender(rawValue: genderString),
              let nationality = record["nationality"] as? String,
              let passportNumber = record["passportNumber"] as? String,
              let passportIssuingCountry = record["passportIssuingCountry"] as? String,
              let passportExpirationDate = record["passportExpirationDate"] as? Date else {
            return nil
        }
        
        return Passenger(
            id: record.recordID.recordName,
            firstName: firstName,
            middleName: record["middleName"] as? String ?? "",
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            nationality: nationality,
            passportNumber: passportNumber,
            passportIssuingCountry: passportIssuingCountry,
            passportExpirationDate: passportExpirationDate,
            streetAddress: record["streetAddress"] as? String ?? "",
            city: record["city"] as? String ?? "",
            state: record["state"] as? String ?? "",
            postalCode: record["postalCode"] as? String ?? "",
            country: record["country"] as? String ?? "US",
            phoneNumber: record["phoneNumber"] as? String ?? "",
            email: record["email"] as? String ?? "",
            weight: record["weight"] as? Int,
            frequentFlyerNumber: record["frequentFlyerNumber"] as? String,
            knownTravelerNumber: record["knownTravelerNumber"] as? String,
            redressNumber: record["redressNumber"] as? String,
            createdDate: record["createdDate"] as? Date ?? Date(),
            lastModifiedDate: record["lastModifiedDate"] as? Date ?? Date(),
            isFavorite: (record["isFavorite"] as? Int ?? 0) == 1,
            notes: record["notes"] as? String ?? "",
            recordID: record.recordID,
            recordChangeTag: record.recordChangeTag
        )
    }
}

// MARK: - Sample Data
extension Passenger {
    static let sample = Passenger(
        firstName: "John",
        middleName: "Michael",
        lastName: "Smith",
        dateOfBirth: Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date(),
        gender: .male,
        nationality: "US",
        passportNumber: "123456789",
        passportIssuingCountry: "US",
        passportExpirationDate: Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date(),
        streetAddress: "123 Main Street",
        city: "Detroit",
        state: "MI",
        postalCode: "48226",
        country: "US",
        phoneNumber: "+1-555-123-4567",
        email: "john.smith@example.com",
        weight: 180,
        isFavorite: true,
        notes: "Frequent passenger - business travel"
    )
}
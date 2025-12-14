//
//  EAPISDocumentGenerator.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import Foundation
import PDFKit

// MARK: - EAPIS Document Generator
class EAPISDocumentGenerator {
    
    // MARK: - GENDEC Format (General Declaration)
    /// Generates a GENDEC (General Declaration) document for international general aviation
    static func generateGENDEC(manifest: EAPISManifest, passengers: [Passenger], pilotInfo: PilotInfo) -> String {
        var gendec = ""
        
        // Header
        gendec += "GENERAL DECLARATION\n"
        gendec += "CIVIL AVIATION (INTERNATIONAL FLIGHT)\n"
        gendec += "=====================================\n\n"
        
        // Owner/Operator Information
        gendec += "Owner or Operator: \(pilotInfo.operatorName)\n"
        gendec += "Nationality and Registration Marks: \(manifest.aircraftRegistration)\n"
        gendec += "Departure from: \(manifest.departureAirport)\n"
        gendec += "Date: \(formatDate(manifest.departureDate))\n"
        gendec += "Destination: \(manifest.arrivalAirport)\n\n"
        
        // Flight Information
        gendec += "Flight Details:\n"
        gendec += "- Flight Number: \(manifest.flightNumber)\n"
        gendec += "- Aircraft Type: \(manifest.aircraftType)\n"
        gendec += "- Departure Time: \(formatTime(manifest.departureTime)) UTC\n"
        gendec += "- Estimated Arrival: \(formatTime(manifest.estimatedArrivalTime)) UTC\n\n"
        
        // Crew Information
        gendec += "Flight Crew:\n"
        gendec += "Pilot-in-Command: \(manifest.pilotInCommand)\n"
        gendec += "License: \(manifest.pilotLicense)\n"
        if let copilot = manifest.copilotName, !copilot.isEmpty {
            gendec += "Co-Pilot: \(copilot)\n"
            if let copilotLicense = manifest.copilotLicense {
                gendec += "License: \(copilotLicense)\n"
            }
        }
        gendec += "\n"
        
        // Passenger Manifest
        gendec += "Passengers on Board: \(passengers.count)\n"
        gendec += "----------------------------------------\n"
        for (index, passenger) in passengers.enumerated() {
            gendec += "\(index + 1). \(passenger.fullName)\n"
            gendec += "   Nationality: \(getCountryName(passenger.nationality))\n"
            gendec += "   Passport: \(passenger.passportNumber) (\(getCountryName(passenger.passportIssuingCountry)))\n"
            gendec += "   DOB: \(formatDate(passenger.dateOfBirth))\n"
            gendec += "\n"
        }
        
        // Customs Declaration
        gendec += "Customs Information:\n"
        gendec += "Purpose of Flight: \(manifest.purposeOfFlight.rawValue)\n"
        gendec += "Goods to Declare: \(manifest.customsDeclarations ? "YES" : "NO")\n"
        if manifest.customsDeclarations && !manifest.declarationDetails.isEmpty {
            gendec += "Details: \(manifest.declarationDetails)\n"
        }
        gendec += "\n"
        
        // Signature Section
        gendec += "----------------------------------------\n"
        gendec += "Signature of Pilot-in-Command:\n"
        gendec += "\n"
        gendec += "Name: \(manifest.pilotInCommand)\n"
        gendec += "Date: \(formatDate(Date()))\n"
        gendec += "Place: \(manifest.departureAirport)\n"
        
        return gendec
    }
    
    // MARK: - Canada eManifest Format
    static func generateCanadaManifest(manifest: EAPISManifest, passengers: [Passenger]) -> String {
        var doc = ""
        
        doc += "CANADA BORDER SERVICES - GENERAL AVIATION eMANIFEST\n"
        doc += "==================================================\n\n"
        
        // Aircraft Information
        doc += "AIRCRAFT INFORMATION\n"
        doc += "Registration: \(manifest.aircraftRegistration)\n"
        doc += "Type: \(manifest.aircraftType)\n"
        doc += "Flight Number: \(manifest.flightNumber)\n\n"
        
        // Flight Details
        doc += "FLIGHT DETAILS\n"
        doc += "Departure: \(manifest.departureAirport)\n"
        doc += "Departure Date/Time: \(formatDateTime(manifest.departureDate, manifest.departureTime))\n"
        doc += "Arrival: \(manifest.arrivalAirport)\n"
        doc += "ETA: \(formatDateTime(manifest.estimatedArrivalDate, manifest.estimatedArrivalTime))\n\n"
        
        // Crew
        doc += "CREW MEMBERS\n"
        doc += "PIC: \(manifest.pilotInCommand) - License: \(manifest.pilotLicense)\n"
        if let copilot = manifest.copilotName, !copilot.isEmpty {
            doc += "SIC: \(copilot)"
            if let license = manifest.copilotLicense {
                doc += " - License: \(license)"
            }
            doc += "\n"
        }
        doc += "\n"
        
        // Passengers
        doc += "PASSENGER MANIFEST\n"
        doc += "Total Passengers: \(passengers.count)\n"
        doc += "--------------------------------------------------\n"
        for passenger in passengers {
            doc += "Name: \(passenger.lastName), \(passenger.firstName) \(passenger.middleName)\n"
            doc += "DOB: \(formatDate(passenger.dateOfBirth))\n"
            doc += "Nationality: \(getCountryName(passenger.nationality))\n"
            doc += "Passport: \(passenger.passportNumber)\n"
            doc += "Issued by: \(getCountryName(passenger.passportIssuingCountry))\n"
            doc += "Expiry: \(formatDate(passenger.passportExpirationDate))\n"
            doc += "Address: \(passenger.streetAddress), \(passenger.city), \(passenger.state) \(passenger.postalCode)\n"
            doc += "--------------------------------------------------\n"
        }
        
        // Purpose
        doc += "\nPURPOSE OF FLIGHT: \(manifest.purposeOfFlight.rawValue)\n"
        if !manifest.customsPurpose.isEmpty {
            doc += "Details: \(manifest.customsPurpose)\n"
        }
        
        // Customs Declaration
        doc += "\nCUSTOMS DECLARATION\n"
        doc += "Goods to Declare: \(manifest.customsDeclarations ? "YES" : "NO")\n"
        if manifest.customsDeclarations {
            doc += "Details: \(manifest.declarationDetails)\n"
        }
        
        return doc
    }
    
    // MARK: - Mexico Format
    static func generateMexicoManifest(manifest: EAPISManifest, passengers: [Passenger]) -> String {
        var doc = ""
        
        doc += "DECLARACIÓN GENERAL DE AVIACIÓN - MÉXICO\n"
        doc += "General Aviation Declaration - Mexico\n"
        doc += "=====================================\n\n"
        
        // Aircraft
        doc += "AERONAVE / AIRCRAFT\n"
        doc += "Matrícula / Registration: \(manifest.aircraftRegistration)\n"
        doc += "Tipo / Type: \(manifest.aircraftType)\n"
        doc += "Número de Vuelo / Flight Number: \(manifest.flightNumber)\n\n"
        
        // Route
        doc += "RUTA / ROUTE\n"
        doc += "Origen / Origin: \(manifest.departureAirport)\n"
        doc += "Destino / Destination: \(manifest.arrivalAirport)\n"
        doc += "Fecha Salida / Departure Date: \(formatDate(manifest.departureDate))\n"
        doc += "Hora Salida / Departure Time: \(formatTime(manifest.departureTime))\n"
        doc += "Hora Estimada Llegada / ETA: \(formatTime(manifest.estimatedArrivalTime))\n\n"
        
        // Crew
        doc += "TRIPULACIÓN / CREW\n"
        doc += "Comandante / PIC: \(manifest.pilotInCommand)\n"
        doc += "Licencia / License: \(manifest.pilotLicense)\n\n"
        
        // Passengers
        doc += "PASAJEROS / PASSENGERS: \(passengers.count)\n"
        doc += "----------------------------------------\n"
        for (i, passenger) in passengers.enumerated() {
            doc += "\(i + 1). \(passenger.fullName)\n"
            doc += "   Pasaporte / Passport: \(passenger.passportNumber)\n"
            doc += "   Nacionalidad / Nationality: \(getCountryName(passenger.nationality))\n"
        }
        doc += "\n"
        
        // Declaration
        doc += "DECLARACIÓN / DECLARATION\n"
        doc += "Propósito / Purpose: \(manifest.purposeOfFlight.rawValue)\n"
        doc += "Mercancías a Declarar / Goods to Declare: \(manifest.customsDeclarations ? "SÍ/YES" : "NO")\n"
        
        return doc
    }
    
    // MARK: - Caribbean/Cuba Format
    static func generateCaribbeanManifest(manifest: EAPISManifest, passengers: [Passenger], destinationCountry: String) -> String {
        var doc = ""
        
        doc += "GENERAL AVIATION MANIFEST\n"
        doc += "Destination: \(destinationCountry)\n"
        doc += "==========================\n\n"
        
        doc += "Aircraft Registration: \(manifest.aircraftRegistration)\n"
        doc += "Aircraft Type: \(manifest.aircraftType)\n"
        doc += "Flight Number: \(manifest.flightNumber)\n\n"
        
        doc += "Departure Airport: \(manifest.departureAirport)\n"
        doc += "Arrival Airport: \(manifest.arrivalAirport)\n"
        doc += "Departure Date: \(formatDate(manifest.departureDate))\n"
        doc += "Departure Time: \(formatTime(manifest.departureTime)) UTC\n"
        doc += "Estimated Arrival: \(formatTime(manifest.estimatedArrivalTime)) UTC\n\n"
        
        doc += "Pilot-in-Command: \(manifest.pilotInCommand)\n"
        doc += "License Number: \(manifest.pilotLicense)\n\n"
        
        doc += "PASSENGER LIST\n"
        doc += "Total: \(passengers.count) passengers\n"
        doc += "-----------------------------------\n"
        
        for passenger in passengers {
            doc += "\nFull Name: \(passenger.fullName)\n"
            doc += "Date of Birth: \(formatDate(passenger.dateOfBirth))\n"
            doc += "Gender: \(passenger.gender.displayName)\n"
            doc += "Nationality: \(getCountryName(passenger.nationality))\n"
            doc += "Passport Number: \(passenger.passportNumber)\n"
            doc += "Passport Country: \(getCountryName(passenger.passportIssuingCountry))\n"
            doc += "Passport Expiry: \(formatDate(passenger.passportExpirationDate))\n"
            doc += "-----------------------------------\n"
        }
        
        doc += "\nPurpose of Flight: \(manifest.purposeOfFlight.rawValue)\n"
        doc += "Customs Declaration: \(manifest.customsDeclarations ? "YES" : "NO")\n"
        
        return doc
    }
    
    // MARK: - Europe Schengen Format
    static func generateEuropeManifest(manifest: EAPISManifest, passengers: [Passenger]) -> String {
        var doc = ""
        
        doc += "GENERAL DECLARATION FOR ENTRY INTO SCHENGEN AREA\n"
        doc += "================================================\n\n"
        
        // Aircraft Details
        doc += "Aircraft Registration: \(manifest.aircraftRegistration)\n"
        doc += "Aircraft Type/Model: \(manifest.aircraftType)\n"
        doc += "Flight Identification: \(manifest.flightNumber)\n\n"
        
        // Flight Plan
        doc += "Departure Aerodrome: \(manifest.departureAirport)\n"
        doc += "Departure Date: \(formatDate(manifest.departureDate))\n"
        doc += "Departure Time (UTC): \(formatTime(manifest.departureTime))\n"
        doc += "Destination Aerodrome: \(manifest.arrivalAirport)\n"
        doc += "ETA (UTC): \(formatTime(manifest.estimatedArrivalTime))\n\n"
        
        // Operator/Owner
        doc += "Operator/Owner Information:\n"
        doc += "Pilot-in-Command: \(manifest.pilotInCommand)\n"
        doc += "License Number: \(manifest.pilotLicense)\n\n"
        
        // Persons on Board
        doc += "PERSONS ON BOARD\n"
        doc += "Crew Members: \(manifest.copilotName != nil ? 2 : 1)\n"
        doc += "Passengers: \(passengers.count)\n"
        doc += "Total: \(passengers.count + (manifest.copilotName != nil ? 2 : 1))\n\n"
        
        // Detailed Passenger List
        doc += "PASSENGER DETAILS\n"
        doc += "================================================================\n"
        for (i, passenger) in passengers.enumerated() {
            doc += "Passenger \(i + 1):\n"
            doc += "  Surname: \(passenger.lastName)\n"
            doc += "  Given Names: \(passenger.firstName) \(passenger.middleName)\n"
            doc += "  Date of Birth: \(formatDate(passenger.dateOfBirth))\n"
            doc += "  Place of Birth: \(passenger.city), \(getCountryName(passenger.country))\n"
            doc += "  Nationality: \(getCountryName(passenger.nationality))\n"
            doc += "  Travel Document Type: Passport\n"
            doc += "  Document Number: \(passenger.passportNumber)\n"
            doc += "  Issuing State: \(getCountryName(passenger.passportIssuingCountry))\n"
            doc += "  Expiry Date: \(formatDate(passenger.passportExpirationDate))\n"
            doc += "  Residential Address: \(passenger.streetAddress), \(passenger.city)\n"
            doc += "================================================================\n"
        }
        
        // Purpose & Customs
        doc += "\nPurpose of Journey: \(manifest.purposeOfFlight.rawValue)\n"
        doc += "Goods to Declare: \(manifest.customsDeclarations ? "YES" : "NO")\n"
        if manifest.customsDeclarations {
            doc += "Declaration: \(manifest.declarationDetails)\n"
        }
        
        doc += "\nI certify that the information provided is correct.\n"
        doc += "Signature: ___________________ Date: \(formatDate(Date()))\n"
        
        return doc
    }
    
    // MARK: - Helper Methods
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
    
    private static func formatDateTime(_ date: Date, _ time: Date) -> String {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var fullDateTime = calendar.dateComponents([.year, .month, .day], from: date)
        fullDateTime.hour = timeComponents.hour
        fullDateTime.minute = timeComponents.minute
        
        guard let combined = calendar.date(from: fullDateTime) else {
            return "\(formatDate(date)) \(formatTime(time))"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HHmm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: combined) + " UTC"
    }
    
    private static func getCountryName(_ code: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forRegionCode: code) ?? code
    }
}

// MARK: - Pilot Info Structure
struct PilotInfo {
    var operatorName: String
    var operatorAddress: String
    var operatorPhone: String
    
    static var `default`: PilotInfo {
        PilotInfo(
            operatorName: "Private Operator",
            operatorAddress: "USA",
            operatorPhone: ""
        )
    }
}

// MARK: - Document Format Enum
enum EAPISDocumentFormat: String, CaseIterable {
    case gendec = "GENDEC (General Declaration)"
    case canada = "Canada eManifest"
    case mexico = "Mexico Declaration"
    case caribbean = "Caribbean/Cuba"
    case europe = "Europe/Schengen"
    
    var description: String {
        rawValue
    }
    
    func generate(manifest: EAPISManifest, passengers: [Passenger], pilotInfo: PilotInfo = .default) -> String {
        switch self {
        case .gendec:
            return EAPISDocumentGenerator.generateGENDEC(manifest: manifest, passengers: passengers, pilotInfo: pilotInfo)
        case .canada:
            return EAPISDocumentGenerator.generateCanadaManifest(manifest: manifest, passengers: passengers)
        case .mexico:
            return EAPISDocumentGenerator.generateMexicoManifest(manifest: manifest, passengers: passengers)
        case .caribbean:
            return EAPISDocumentGenerator.generateCaribbeanManifest(manifest: manifest, passengers: passengers, destinationCountry: "Caribbean")
        case .europe:
            return EAPISDocumentGenerator.generateEuropeManifest(manifest: manifest, passengers: passengers)
        }
    }
}
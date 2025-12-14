//
//  FlightData.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/17/25.
//


import Foundation

struct FlightData: Codable, Equatable {
    let flightNumber: String
    let departureAirport: String
    let arrivalAirport: String
    var outTime: Date?
    var offTime: Date?
    var onTime: Date?
    var inTime: Date?
}
//
//  ContinuationPrompt.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/1/25.
//


//
//  ContinuationModels.swift
//  ProPilotApp
//
//  Models for trip continuation detection
//

import Foundation

// MARK: - Continuation Prompt Model
struct ContinuationPrompt: Identifiable {
    let id = UUID()
    let newFlight: BasicScheduleItem
    let existingTrip: Trip
    let matchReason: String
    let confidence: ContinuationConfidence
    
    enum ContinuationConfidence {
        case high       // Route matches perfectly (departure = last arrival)
        case medium     // Same duty day, close timing
        case low        // Only timing suggests continuation
        
        var description: String {
            switch self {
            case .high: return "Route continues from last leg"
            case .medium: return "Same duty period"
            case .low: return "Similar timing"
            }
        }
    }
    
    var isRouteContinuation: Bool {
        guard let lastLeg = existingTrip.legs.last else { return false }
        return lastLeg.arrival == newFlight.departure
    }
}

// MARK: - Continuation Detection Result
enum ContinuationDetectionResult {
    case newTrip                           // Definitely a new trip
    case askUserAboutContinuation(ContinuationPrompt)  // Possible continuation
    case autoContinuation(Trip)            // Definitely a continuation (if we add auto mode later)
}
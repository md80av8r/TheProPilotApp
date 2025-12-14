//
//  ContinuationPromptView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/1/25.
//


//
//  ContinuationPromptView.swift
//  ProPilotApp
//
//  UI for asking user if new flight continues existing trip
//

import SwiftUI

struct ContinuationPromptView: View {
    let prompt: ContinuationPrompt
    let onAddLeg: () -> Void
    let onNewTrip: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 20) {
                        // New Flight Info
                        newFlightCard
                        
                        // Continuation Indicator
                        continuationIndicator
                        
                        // Existing Trip Info
                        existingTripCard
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
                .background(LogbookTheme.navy)
            }
            .navigationTitle("Continue Trip?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 50))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("New Flight Detected")
                .font(.title2.bold())
                .foregroundColor(LogbookTheme.textPrimary)
            
            Text(prompt.matchReason)
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(LogbookTheme.cardBackground)
    }
    
    // MARK: - New Flight Card
    private var newFlightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.departure")
                    .foregroundColor(LogbookTheme.accentGreen)
                Text("New Flight")
                    .font(.headline)
                    .foregroundColor(LogbookTheme.textPrimary)
                Spacer()
                confidenceBadge
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Flight Number
            HStack {
                Text("Flight")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text(prompt.newFlight.tripNumber)
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            // Route
            HStack {
                Text("Route")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Text(prompt.newFlight.departure)
                        .font(.subheadline.bold())
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text(prompt.newFlight.arrival)
                        .font(.subheadline.bold())
                }
                .foregroundColor(LogbookTheme.textPrimary)
            }
            
            // Block Times
            HStack {
                Text("Block Out")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text(timeFormatter.string(from: prompt.newFlight.blockOut))
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textPrimary)
            }
            
            HStack {
                Text("Block In")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text(timeFormatter.string(from: prompt.newFlight.blockIn))
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textPrimary)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Continuation Indicator
    private var continuationIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .font(.title2)
                .foregroundColor(LogbookTheme.warningYellow)
            
            if prompt.isRouteContinuation {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LogbookTheme.successGreen)
                    Text("Routes Connect")
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.successGreen)
                }
            } else {
                Text("Same Duty Period")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Existing Trip Card
    private var existingTripCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(LogbookTheme.accentOrange)
                Text("Existing Trip")
                    .font(.headline)
                    .foregroundColor(LogbookTheme.textPrimary)
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Trip Number
            HStack {
                Text("Trip")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text("#\(prompt.existingTrip.tripNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            // Current Legs
            HStack {
                Text("Current Legs")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text("\(prompt.existingTrip.legs.count)")
                    .font(.subheadline.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
            }
            
            // Last Leg Route
            if let lastLeg = prompt.existingTrip.legs.last {
                HStack {
                    Text("Last Leg")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(lastLeg.departure)
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        Text(lastLeg.arrival)
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(LogbookTheme.textPrimary)
                }
            }
            
            // Trip Date
            HStack {
                Text("Date")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                Spacer()
                Text(dateFormatter.string(from: prompt.existingTrip.date))
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textPrimary)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Add as Leg (Primary action)
            Button {
                onAddLeg()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add as New Leg")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LogbookTheme.successGreen)
                .cornerRadius(12)
            }
            
            // Create Separate Trip
            Button {
                onNewTrip()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Create Separate Trip")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LogbookTheme.accentBlue)
                .cornerRadius(12)
            }
            
            // Dismiss
            Button {
                onDismiss()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Dismiss")
                }
                .foregroundColor(LogbookTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Confidence Badge
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .font(.caption)
            Text(prompt.confidence.description)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor)
        .cornerRadius(6)
    }
    
    private var confidenceIcon: String {
        switch prompt.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "questionmark.circle.fill"
        }
    }
    
    private var confidenceColor: Color {
        switch prompt.confidence {
        case .high: return LogbookTheme.successGreen
        case .medium: return LogbookTheme.warningYellow
        case .low: return Color.orange
        }
    }
}

// MARK: - Preview
struct ContinuationPromptView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFlight = BasicScheduleItem(
            date: Date(),
            tripNumber: "UJ736",
            departure: "KLRD",
            arrival: "SDF",
            blockOut: Date(),
            blockOff: Date().addingTimeInterval(1800),
            blockOn: Date().addingTimeInterval(5400),
            blockIn: Date().addingTimeInterval(7200),
            summary: "Test Flight"
        )
        
        let sampleTrip = Trip(
            tripNumber: "UJ729",
            aircraft: "N12345",
            date: Date(),
            tatStart: "",
            crew: [],
            notes: "",
            legs: [FlightLeg()],
            tripType: .operating,
            status: .active
        )
        
        let prompt = ContinuationPrompt(
            newFlight: sampleFlight,
            existingTrip: sampleTrip,
            matchReason: "Route continues from last leg",
            confidence: .high
        )
        
        ContinuationPromptView(
            prompt: prompt,
            onAddLeg: {},
            onNewTrip: {},
            onDismiss: {}
        )
    }
}
// JumpseatFlightDetailView.swift - Detailed View of a Jumpseat Flight
// ProPilot App

import SwiftUI

struct JumpseatFlightDetailView: View {
    let flight: JumpseatFlight
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = JumpseatService.shared
    @StateObject private var settings = JumpseatSettings.shared
    
    @State private var showingRequestSheet = false
    @State private var requestMessage = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Route Header
                        routeHeader
                        
                        // Flight Details Card
                        flightDetailsCard
                        
                        // Pilot Info Card
                        pilotInfoCard
                        
                        // Request Button (if not own flight)
                        if flight.pilotId != service.currentUserId {
                            requestButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Flight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRequestSheet) {
                requestSheet
            }
            .alert("Request Sent!", isPresented: $showingSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("The pilot will be notified of your interest. You'll receive a notification when they respond.")
            }
        }
    }
    
    // MARK: - Route Header
    
    private var routeHeader: some View {
        VStack(spacing: 16) {
            // Route Display
            HStack(spacing: 20) {
                // Departure
                VStack(spacing: 4) {
                    Text(flight.departure)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(flight.estimatedOut + "Z")
                        .font(.caption.monospaced())
                        .foregroundColor(.gray)
                }
                
                // Arrow
                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.title)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Arrival
                VStack(spacing: 4) {
                    Text(flight.arrival)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(flight.estimatedIn + "Z")
                        .font(.caption.monospaced())
                        .foregroundColor(.gray)
                }
            }
            
            // Date and Status
            HStack {
                Label(flight.displayDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                JumpseatStatusBadge(status: flight.status)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Flight Details Card
    
    private var flightDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flight Information")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailItem(title: "Aircraft", value: flight.aircraft, icon: "airplane")
                DetailItem(title: "Operator", value: flight.operatorName, icon: "building.2")
                
                if !flight.flightNumber.isEmpty {
                    DetailItem(title: "Flight #", value: flight.flightNumber, icon: "number")
                }
                
                DetailItem(title: "Seats", value: "\(flight.seatsAvailable)", icon: "person")
                DetailItem(title: "Type", value: flight.jumpseatType.displayName, icon: flight.jumpseatType.iconName)
                
                if flight.cassRequired {
                    DetailItem(title: "CASS", value: "Required", icon: "checkmark.shield", valueColor: .blue)
                } else {
                    DetailItem(title: "CASS", value: "Not Required", icon: "xmark.shield", valueColor: .green)
                }
            }
            
            if !flight.notes.isEmpty {
                Divider().background(Color.gray.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(flight.notes)
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Pilot Info Card
    
    private var pilotInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Posted By")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                // Avatar placeholder
                Circle()
                    .fill(LogbookTheme.accentBlue.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(flight.pilotDisplayName.prefix(1)))
                            .font(.title2.bold())
                            .foregroundColor(LogbookTheme.accentBlue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.pilotDisplayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(flight.operatorName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let rating = flight.pilotRating {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        Text("Rating")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Interested pilots count
            if flight.hasInterestedPilots {
                Divider().background(Color.gray.opacity(0.3))
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(LogbookTheme.accentOrange)
                    
                    Text("\(flight.interestedCount) other pilot\(flight.interestedCount == 1 ? "" : "s") interested")
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Request Button
    
    private var requestButton: some View {
        VStack(spacing: 12) {
            Button {
                showingRequestSheet = true
            } label: {
                HStack {
                    Image(systemName: "hand.raised")
                    Text("I'm Interested")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentBlue)
                .cornerRadius(12)
            }
            
            Text("Let the pilot know you'd like this jumpseat")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Request Sheet
    
    private var requestSheet: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Flight Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.routeString)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(flight.displayDate) • \(flight.aircraft)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Your Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Information")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Name:")
                                .foregroundColor(.gray)
                            Text(settings.displayName)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Airline:")
                                .foregroundColor(.gray)
                            Text(settings.operatorName)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Message Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $requestMessage)
                            .frame(height: 100)
                            .padding(8)
                            .background(LogbookTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        
                        Text("Example: \"Trying to get home to Detroit after a trip. Would really appreciate the ride!\"")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Submit Button
                    Button {
                        submitRequest()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSubmitting ? "Sending..." : "Send Request")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(settings.canPostFlights ? LogbookTheme.accentBlue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!settings.canPostFlights || isSubmitting)
                    
                    if !settings.canPostFlights {
                        Text("Please complete your profile before requesting jumpseats")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Request Jumpseat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRequestSheet = false
                    }
                }
            }
        }
    }
    
    private func submitRequest() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await service.requestJumpseat(
                    flight: flight,
                    message: requestMessage.isEmpty ? "Interested in this jumpseat" : requestMessage
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showingRequestSheet = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Detail Item View

struct DetailItem: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(valueColor)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct JumpseatFlightDetailView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatFlightDetailView(flight: JumpseatFlight.sampleFlights[0])
    }
}
#endif

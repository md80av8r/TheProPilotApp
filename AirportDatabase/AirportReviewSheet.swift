//
//  AirportReviewSheet.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


//
//  AirportReviewSheet.swift
//  TheProPilotApp
//
//  Review submission interface for airport database
//

import SwiftUI
import CoreLocation

struct AirportReviewSheet: View {
    let airport: AirportInfo
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var pilotName = ""
    @State private var rating = 5
    @State private var reviewContent = ""
    @State private var fboName = ""
    @State private var fuelPrice: String = ""
    @State private var crewCarAvailable = false
    @State private var serviceQuality = 3
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Airport Header
                        VStack(spacing: 8) {
                            Text(airport.icaoCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(LogbookTheme.accentGreen)
                            
                            Text(airport.name)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        
                        // Pilot Name
                        FormSection(title: "Your Name") {
                            TextField("Pilot Name", text: $pilotName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Rating
                        FormSection(title: "Overall Rating") {
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { rating = star }) {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundColor(star <= rating ? .yellow : .gray)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        // Review Content
                        FormSection(title: "Your Review") {
                            TextEditor(text: $reviewContent)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                        
                        // FBO Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("FBO Information (Optional)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("FBO Name", text: $fboName)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            HStack {
                                Text("Fuel Price:")
                                    .foregroundColor(.gray)
                                TextField("0.00", text: $fuelPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .frame(width: 100)
                                Text("/gal")
                                    .foregroundColor(.gray)
                            }
                            
                            Toggle("Crew Car Available", isOn: $crewCarAvailable)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Service Quality")
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { star in
                                        Button(action: { serviceQuality = star }) {
                                            Image(systemName: star <= serviceQuality ? "star.fill" : "star")
                                                .font(.title3)
                                                .foregroundColor(star <= serviceQuality ? .yellow : .gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        
                        // Submit Button
                        Button(action: submitReview) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Submit Review")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSubmit ? LogbookTheme.accentGreen : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding()
                }
            }
            .navigationTitle("Review Airport & FBO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        !pilotName.isEmpty && !reviewContent.isEmpty
    }
    
    private func submitReview() {
        guard canSubmit else { return }
        
        isSubmitting = true
        
        var review = PilotReview(
            airportCode: airport.icaoCode,
            pilotName: pilotName,
            rating: rating,
            content: reviewContent,
            date: Date(),
            fboName: fboName.isEmpty ? nil : fboName,
            fuelPrice: Double(fuelPrice),
            crewCarAvailable: crewCarAvailable
        )
        
        // Set service quality separately since it's not in the initializer
        review.serviceQuality = serviceQuality
        
        Task {
            do {
                try await AirportDatabaseManager.shared.submitReview(review)
                
                await MainActor.run {
                    isSubmitting = false
                    onSubmit()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    // You could show an error alert here
                    print("Failed to submit review: \(error)")
                }
            }
        }
    }
}

struct FormSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

// MARK: - Preview

struct AirportReviewSheet_Previews: PreviewProvider {
    static var previews: some View {
        AirportReviewSheet(
            airport: AirportInfo(
                icaoCode: "KDTW",
                name: "Detroit Metropolitan Wayne County Airport",
                coordinate: CLLocationCoordinate2D(latitude: 42.2124, longitude: -83.3534),
                timeZone: "America/Detroit",
                source: .csvImport,
                dateAdded: Date(),
                averageRating: 4.5,
                reviewCount: 12
            )
        ) {}
    }
}
// JumpseatProfileSetupView.swift - Initial Profile Setup & Editing
// ProPilot App

import SwiftUI

struct JumpseatProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = JumpseatSettings.shared
    
    @State private var displayName = ""
    @State private var operatorName = ""
    @State private var homeBase = ""
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !operatorName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Form Fields
                        formSection
                        
                        // Privacy Note
                        privacyNote
                        
                        Spacer(minLength: 40)
                        
                        // Save Button
                        saveButton
                    }
                    .padding()
                }
            }
            .navigationTitle(settings.hasCompletedOnboarding ? "Edit Profile" : "Welcome!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if settings.hasCompletedOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                loadExistingValues()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(LogbookTheme.accentBlue)
            
            if !settings.hasCompletedOnboarding {
                Text("Set Up Your Pilot Profile")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("This information helps other pilots identify you when sharing jumpseats.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Display Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                TextField("e.g., Capt. Jeff or FO Smith", text: $displayName)
                    .textContentType(.name)
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(10)
                
                Text("This is how other pilots will see you. Use a nickname or title + last name.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Operator/Airline
            VStack(alignment: .leading, spacing: 8) {
                Text("Airline / Operator")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                TextField("e.g., USA Jet, Atlas Air, NetJets", text: $operatorName)
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(10)
                
                Text("Your employer or the operator you fly for.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Home Base
            VStack(alignment: .leading, spacing: 8) {
                Text("Home Base (Optional)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                TextField("ICAO Code (e.g., KYIP)", text: $homeBase)
                    .textInputAutocapitalization(.characters)
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(10)
                    .onChange(of: homeBase) { _, newValue in
                        homeBase = newValue.uppercased()
                    }
                
                Text("Your domicile or primary airport. Helps with relevant jumpseat suggestions.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground.opacity(0.5))
        .cornerRadius(16)
    }
    
    // MARK: - Privacy Note
    
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundColor(LogbookTheme.accentGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Privacy Matters")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text("We only share your display name and airline with other pilots. Your full name and personal details are never exposed.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        VStack(spacing: 12) {
            Button {
                saveProfile()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    
                    Text(settings.hasCompletedOnboarding ? "Save Changes" : "Get Started")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? LogbookTheme.accentBlue : Color.gray.opacity(0.5))
                .cornerRadius(12)
            }
            .disabled(!isValid || isSubmitting)
            
            if !settings.hasCompletedOnboarding {
                Button("Skip for Now") {
                    settings.hasCompletedOnboarding = true
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadExistingValues() {
        displayName = settings.displayName
        operatorName = settings.operatorName
        homeBase = settings.homeBase
    }
    
    private func saveProfile() {
        guard isValid else { return }
        
        isSubmitting = true
        
        // Save to settings
        settings.displayName = displayName.trimmingCharacters(in: .whitespaces)
        settings.operatorName = operatorName.trimmingCharacters(in: .whitespaces)
        settings.homeBase = homeBase.trimmingCharacters(in: .whitespaces).uppercased()
        settings.hasCompletedOnboarding = true
        
        // TODO: Save to Firebase profile when authenticated
        // For now, just save locally
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct JumpseatProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatProfileSetupView()
    }
}
#endif

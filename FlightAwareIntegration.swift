// FlightAwareIntegration.swift - Main Integration Screens
import Foundation
import SwiftUI

// MARK: - Enhanced FlightAware Data View
struct EnhancedFlightAwareDataView: View {
    @State private var showingLogin = false
    @State private var hasValidatedCredentials = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Quick Action Buttons
                    FlightAwareQuickActionsSection(showingLogin: $showingLogin)
                    
                    // Login status or data
                    if EnhancedFlightAwareManager.shared.isLoggedIn {
                        if EnhancedFlightAwareManager.shared.flightAwareFlights.isEmpty && !EnhancedFlightAwareManager.shared.isLoading {
                            VStack(spacing: 16) {
                                if EnhancedFlightAwareManager.shared.apiStatus != .unknown {
                                    Text("✅ Connected to FlightAware")
                                        .font(.headline)
                                        .foregroundColor(LogbookTheme.accentGreen)
                                    
                                    Text("Account: \(EnhancedFlightAwareManager.shared.apiStatus.description)")
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.textSecondary)
                                }
                                
                                Text("Ready to fetch USA Jet flights")
                                    .foregroundColor(LogbookTheme.textSecondary)
                                
                                Button("Fetch Flights") {
                                    Task {
                                        await EnhancedFlightAwareManager.shared.fetchUSAJetFlights()
                                    }
                                }
                                .font(.headline)
                                .padding()
                                .background(LogbookTheme.accentGreen)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                
                                Button("Manage API Settings") {
                                    showingLogin = true
                                }
                                .font(.caption)
                                .foregroundColor(LogbookTheme.accentBlue)
                            }
                            .padding()
                        } else {
                            FlightAwareFlightDataSection()
                        }
                    } else {
                        FlightAwareLoginPromptSection()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("FlightAware Access")
        }
        .sheet(isPresented: $showingLogin) {
            EnhancedFlightAwareLoginView()
        }
        .onAppear {
            // Validate existing credentials on first load
            if EnhancedFlightAwareManager.shared.isLoggedIn && !hasValidatedCredentials {
                hasValidatedCredentials = true
                Task {
                    await EnhancedFlightAwareManager.shared.validateExistingCredentials()
                }
            }
        }
        .onReceive(EnhancedFlightAwareManager.shared.objectWillChange) { _ in
            // This triggers view updates when the manager changes
        }
    }
}

// MARK: - Enhanced Login View
struct EnhancedFlightAwareLoginView: View {
    @State private var username = ""
    @State private var apiKey = ""
    @State private var showingApiKeyInfo = false
    @State private var showingDebugInfo = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        FlightAwareHeaderSection()
                        
                        // Current Status (if logged in)
                        if EnhancedFlightAwareManager.shared.isLoggedIn {
                            currentStatusSection
                        }
                        
                        // Login Form
                        loginFormSection
                        
                        // Debug Information
                        if !EnhancedFlightAwareManager.shared.debugInfo.isEmpty {
                            FlightAwareDebugSection(showingDebugInfo: $showingDebugInfo)
                        }
                        
                        // Alternative Options
                        FlightAwareAlternativeOptionsSection()
                        
                        // API Information
                        FlightAwareAPIInfoSection()
                    }
                    .padding()
                }
            }
            .navigationTitle("FlightAware")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .onAppear {
            // Pre-fill saved credentials
            if let creds = EnhancedFlightAwareManager.shared.credentials {
                username = creds.username
                apiKey = creds.apiKey
            }
        }
        .onReceive(EnhancedFlightAwareManager.shared.objectWillChange) { _ in
            // This triggers view updates when the manager changes
        }
    }
    
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(LogbookTheme.accentGreen)
                
                Text("Currently Connected")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                Text("Account: \(EnhancedFlightAwareManager.shared.apiStatus.description)")
                    .font(.caption)
                    .foregroundColor(EnhancedFlightAwareManager.shared.apiStatus.color)
                
                Spacer()
                
                Button("Logout") {
                    EnhancedFlightAwareManager.shared.logout()
                    username = ""
                    apiKey = ""
                }
                .font(.caption)
                .foregroundColor(LogbookTheme.errorRed)
            }
            
            Text("You can update your credentials below or close this window.")
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(LogbookTheme.accentGreen.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LogbookTheme.accentGreen.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FlightAware Username")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Enter your FlightAware username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isInputFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Get API Key") {
                        showingApiKeyInfo = true
                    }
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                
                SecureField("Enter your FlightAware API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                    }
            }
            
            if let error = EnhancedFlightAwareManager.shared.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(LogbookTheme.errorRed)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(LogbookTheme.errorRed.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: {
                Task {
                    await EnhancedFlightAwareManager.shared.login(username: username, apiKey: apiKey)
                    if EnhancedFlightAwareManager.shared.isLoggedIn {
                        dismiss()
                    }
                }
            }) {
                HStack {
                    if EnhancedFlightAwareManager.shared.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    Text("Test FlightAware Connection")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(username.isEmpty || apiKey.isEmpty ? LogbookTheme.textSecondary : LogbookTheme.accentGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(username.isEmpty || apiKey.isEmpty || EnhancedFlightAwareManager.shared.isLoading)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

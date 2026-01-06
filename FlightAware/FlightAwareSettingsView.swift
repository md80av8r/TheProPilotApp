//
//  FlightAwareSettingsView.swift
//  TheProPilotApp
//
//  Settings UI for FlightAware API configuration
//

import SwiftUI

struct FlightAwareSettingsView: View {
    @StateObject private var repository = FlightAwareRepository.shared
    @ObservedObject var airlineSettings: AirlineSettingsStore

    @State private var apiKey: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var testResult: TestResult?
    @State private var showAPIKeyInfo: Bool = false

    enum TestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    var body: some View {
        Form {
            // MARK: - API Key Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SecureField("FlightAware API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        if !apiKey.isEmpty {
                            Button {
                                apiKey = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if repository.isConfigured {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key Configured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("FlightAware API")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        showAPIKeyInfo = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text("How to get an API key")
                        }
                        .font(.caption)
                    }
                }
            }

            // MARK: - Save & Test Section
            Section {
                Button {
                    saveAPIKey()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text(repository.isConfigured ? "Update API Key" : "Save API Key")
                    }
                }
                .disabled(apiKey.isEmpty)

                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(!repository.isConfigured || isTestingConnection)

                if let result = testResult {
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isSuccess ? .green : .red)
                        switch result {
                        case .success:
                            Text("Connection successful!")
                                .foregroundColor(.green)
                        case .failure(let message):
                            Text(message)
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }

                if repository.isConfigured {
                    Button(role: .destructive) {
                        clearConfiguration()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove API Key")
                        }
                    }
                }
            }

            // MARK: - Feature Toggles
            Section {
                Toggle(isOn: $airlineSettings.settings.enableFlightAwareTracking) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Flight Tracking")
                            Text("Auto-fetch route and ETA for your flights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "airplane")
                    }
                }

                Toggle(isOn: $airlineSettings.settings.autoShareFlightNotifications) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Share Notifications")
                            Text("Prompt to share your flight when tracking starts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(!airlineSettings.settings.enableFlightAwareTracking)

                Toggle(isOn: $airlineSettings.settings.fetchWeatherImagery) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Weather Imagery")
                            Text("Show radar/satellite in Weather tab")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cloud.sun.rain")
                    }
                }
                .disabled(!airlineSettings.settings.enableFlightAwareTracking)
            } header: {
                Text("Features")
            }

            // MARK: - Tracking Mode Section
            Section {
                Toggle(isOn: $airlineSettings.settings.useNNumberTracking) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("N-Number Tracking")
                            Text("Track by tail number instead of flight number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "airplane.circle")
                    }
                }
                .onChange(of: airlineSettings.settings.useNNumberTracking) {
                    airlineSettings.saveSettings()
                }

                if airlineSettings.settings.useNNumberTracking {
                    HStack {
                        Text("Default N-Number")
                        Spacer()
                        TextField("N12345", text: $airlineSettings.settings.defaultNNumber)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: airlineSettings.settings.defaultNNumber) {
                                airlineSettings.saveSettings()
                            }
                    }
                } else {
                    HStack {
                        Text("Airline Prefix")
                        Spacer()
                        Text(airlineSettings.settings.flightNumberPrefix.isEmpty ? "Not Set" : airlineSettings.settings.flightNumberPrefix)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        Text("Configure your airline callsign prefix in Airline Settings")
                    } label: {
                        Label("Configure Airline", systemImage: "building.2")
                    }
                }
            } header: {
                Text("Tracking Mode")
            } footer: {
                if airlineSettings.settings.useNNumberTracking {
                    Text("FlightAware will track flights by N-number (e.g., N12345). Great for Part 91 and charter operations.")
                } else {
                    Text("FlightAware uses your airline prefix + flight number to track flights. Example: \(airlineSettings.settings.flightNumberPrefix.isEmpty ? "JUS" : airlineSettings.settings.flightNumberPrefix)1302")
                }
            }

            // MARK: - Cache Section
            if !repository.cachedFlights.isEmpty {
                Section {
                    HStack {
                        Text("Cached Flights")
                        Spacer()
                        Text("\(repository.cachedFlights.count)")
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        repository.clearCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Cache")
                        }
                    }
                } header: {
                    Text("Cache")
                }
            }
        }
        .navigationTitle("FlightAware")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAPIKeyInfo) {
            APIKeyInfoSheet()
        }
        .onAppear {
            // Load existing key if present (for display purposes, show masked)
            if repository.isConfigured {
                apiKey = "••••••••••••••••" // Masked display
            }
        }
    }

    // MARK: - Actions

    private func saveAPIKey() {
        // Don't save masked placeholder
        guard !apiKey.starts(with: "••") else { return }
        repository.configure(apiKey: apiKey)
        testResult = nil
    }

    private func testConnection() async {
        isTestingConnection = true
        testResult = nil

        let result = await repository.testConnection()

        await MainActor.run {
            isTestingConnection = false
            switch result {
            case .success:
                testResult = .success
            case .failure(let error):
                testResult = .failure(error.localizedDescription)
            }
        }
    }

    private func clearConfiguration() {
        repository.clearConfiguration()
        apiKey = ""
        testResult = nil
    }
}

// MARK: - API Key Info Sheet

struct APIKeyInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Getting a FlightAware API Key")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        stepView(number: 1, title: "Create Account", description: "Sign up at flightaware.com if you don't have an account")

                        stepView(number: 2, title: "Go to AeroAPI", description: "Visit flightaware.com/aeroapi and sign in")

                        stepView(number: 3, title: "Create API Key", description: "Generate a new API key from your AeroAPI dashboard")

                        stepView(number: 4, title: "Copy Key", description: "Copy your API key and paste it in the settings above")
                    }

                    Divider()

                    Text("API Tier Information")
                        .font(.headline)

                    Text("ProPilot uses the following AeroAPI features:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "airplane", text: "Flight tracking and status")
                        featureRow(icon: "clock", text: "ETA and schedule data")
                        featureRow(icon: "door.left.hand.open", text: "Gate assignments")
                        featureRow(icon: "arrow.triangle.branch", text: "Route information")
                    }
                    .padding(.leading, 8)

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func stepView(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FlightAwareSettingsView(airlineSettings: AirlineSettingsStore())
    }
}

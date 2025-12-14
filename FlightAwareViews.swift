// FlightAwareViews.swift - UI Components for FlightAware Integration
import Foundation
import SwiftUI

// MARK: - Flight Row Component
struct FlightAwareFlightRow: View {
    let flight: FlightAwareFlight
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.displayIdent)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Text(flight.routeString)
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(flight.statusString)
                        .font(.caption.bold())
                        .foregroundColor(statusColor(for: flight.statusString))
                    
                    if let aircraft = flight.aircraft?.type {
                        Text(aircraft)
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
            }
            
            if let origin = flight.origin, let destination = flight.destination {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FROM")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textSecondary)
                        Text(origin.code)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        if let city = origin.city {
                            Text(city)
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TO")
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textSecondary)
                        Text(destination.code)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        if let city = destination.city {
                            Text(city)
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "in flight":
            return LogbookTheme.accentGreen
        case "arrived":
            return LogbookTheme.accentBlue
        case "scheduled":
            return LogbookTheme.accentOrange
        default:
            return LogbookTheme.textSecondary
        }
    }
}

// MARK: - Quick Actions Section
struct FlightAwareQuickActionsSection: View {
    @Binding var showingLogin: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text("USA Jet Fleet Tracking")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button(action: {
                    EnhancedFlightAwareManager.shared.openFlightAwareWithJUSSearch()
                }) {
                    VStack {
                        Image(systemName: "safari")
                            .font(.title)
                        Text("Search Web")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    EnhancedFlightAwareManager.shared.openFlightAwareApp()
                }) {
                    VStack {
                        Image(systemName: "app.badge")
                            .font(.title)
                        Text("Open App")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentGreen)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showingLogin = true
                }) {
                    VStack {
                        Image(systemName: "key")
                            .font(.title)
                        Text("API Login")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentOrange)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Flight Data Section
struct FlightAwareFlightDataSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("USA Jet Flights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if let lastUpdate = EnhancedFlightAwareManager.shared.lastUpdate {
                    Text("Updated: \(lastUpdate, style: .time)")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
            
            // Loading indicator
            if EnhancedFlightAwareManager.shared.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(LogbookTheme.accentBlue)
                    
                    Text("Fetching flight data...")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            
            // Flight list or empty state
            if EnhancedFlightAwareManager.shared.flightAwareFlights.isEmpty && !EnhancedFlightAwareManager.shared.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 40))
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text("No USA Jet flights found")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let error = EnhancedFlightAwareManager.shared.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(LogbookTheme.errorRed)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Refresh") {
                        Task {
                            await EnhancedFlightAwareManager.shared.fetchUSAJetFlights()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(EnhancedFlightAwareManager.shared.flightAwareFlights) { flight in
                        FlightAwareFlightRow(flight: flight)
                    }
                }
            }
            
            // Refresh button
            Button("Refresh Flights") {
                Task {
                    await EnhancedFlightAwareManager.shared.fetchUSAJetFlights()
                }
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(LogbookTheme.accentGreen)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(EnhancedFlightAwareManager.shared.isLoading)
        }
    }
}

// MARK: - Login Prompt Section
struct FlightAwareLoginPromptSection: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.system(size: 40))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("FlightAware API access requires a paid subscription for most users. The web search and mobile app options above provide excellent flight tracking without API costs.")
                .font(.body)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Header Section
struct FlightAwareHeaderSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("FlightAware Integration")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            if EnhancedFlightAwareManager.shared.apiStatus != .unknown {
                Text("Account Type: \(EnhancedFlightAwareManager.shared.apiStatus.description)")
                    .font(.caption)
                    .foregroundColor(EnhancedFlightAwareManager.shared.apiStatus.color)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - API Info Section
struct FlightAwareAPIInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FlightAware API Information")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Free accounts have very limited API access (1-2 calls)")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                
                Text("• Basic plans start at $89/month for regular API access")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                
                Text("• Many users prefer using the FlightAware mobile app or website")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                
                Text("• Enterprise accounts may require special setup")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Alternative Options Section
struct FlightAwareAlternativeOptionsSection: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Alternative Access Methods")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                EnhancedFlightAwareManager.shared.openFlightAwareWithJUSSearch()
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Search JUS Flights on FlightAware.com")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: {
                EnhancedFlightAwareManager.shared.openFlightAwareApp()
            }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open FlightAware Mobile App")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.accentOrange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Debug Section
struct FlightAwareDebugSection: View {
    @Binding var showingDebugInfo: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Information")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(showingDebugInfo ? "Hide" : "Show") {
                    showingDebugInfo.toggle()
                }
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
            }
            
            if showingDebugInfo {
                Text(EnhancedFlightAwareManager.shared.debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(LogbookTheme.textSecondary)
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

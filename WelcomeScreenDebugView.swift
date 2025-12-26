//
//  WelcomeScreenDebugView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/22/25.
//

import SwiftUI

/// Debug view for testing the welcome screen
/// Add this to your Settings or Debug menu to reset welcome screen state
struct WelcomeScreenDebugView: View {
    @AppStorage("hasEverHadTrips") private var hasEverHadTrips = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Has Ever Had Trips")
                    Spacer()
                    Text(hasEverHadTrips ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Has Seen Welcome")
                    Spacer()
                    Text(hasSeenWelcome ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Current State")
            }
            
            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset Welcome Screen", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Debug Actions")
            } footer: {
                Text("This will reset the welcome screen state. Close and reopen the app to see the welcome screen again (only if you have no trips).")
            }
        }
        .navigationTitle("Welcome Screen Debug")
        .confirmationDialog(
            "Reset Welcome Screen?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to New User", role: .destructive) {
                hasEverHadTrips = false
                hasSeenWelcome = false
            }
            
            Button("Mark as Returning User") {
                hasEverHadTrips = true
                hasSeenWelcome = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you want to reset the state. You may need to restart the app to see changes.")
        }
    }
}

// MARK: - Preview
struct WelcomeScreenDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WelcomeScreenDebugView()
        }
    }
}

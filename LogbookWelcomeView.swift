//
//  LogbookWelcomeView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/22/25.
//


//
//  LogbookWelcomeView.swift
//  TheProPilotApp
//
//  Welcome screen for first-time users with empty logbook
//

import SwiftUI

struct LogbookWelcomeView: View {
    @Binding var isPresented: Bool
    let onAddTrip: () -> Void
    let onImportNOC: () -> Void
    let onImportCSV: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)
                
                // Welcome Header
                VStack(spacing: 16) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to Your Logbook")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Your professional flight logging starts here.\nChoose how you'd like to begin:")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Action Cards
                VStack(spacing: 16) {
                    WelcomeActionCard(
                        icon: "plus.circle.fill",
                        iconColor: .blue,
                        title: "Log Your First Flight",
                        description: "Manually add a trip with OUT, OFF, ON, IN times",
                        badge: "Quick Start"
                    ) {
                        isPresented = false
                        onAddTrip()
                    }
                    
                    WelcomeActionCard(
                        icon: "arrow.down.doc.fill",
                        iconColor: .green,
                        title: "Import NOC Schedule",
                        description: "Auto-import your roster from crew portal",
                        badge: "Recommended"
                    ) {
                        isPresented = false
                        onImportNOC()
                    }
                    
                    WelcomeActionCard(
                        icon: "square.and.arrow.down.fill",
                        iconColor: .orange,
                        title: "Import Existing Logbook",
                        description: "Upload CSV from ForeFlight or other apps",
                        badge: nil
                    ) {
                        isPresented = false
                        onImportCSV()
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 40)
                
                // Skip option
                Button(action: { isPresented = false }) {
                    Text("I'll explore on my own")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct WelcomeActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundColor(iconColor)
                    }
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let badge = badge {
                                Text(badge)
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.15))
                                    )
                            }
                        }
                        
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct LogbookWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        LogbookWelcomeView(
            isPresented: .constant(true),
            onAddTrip: {},
            onImportNOC: {},
            onImportCSV: {}
        )
    }
}

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
    var onImportRAIDO: (() -> Void)? = nil

    @State private var showingHelpSheet = false

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

                    // RAIDO import for USA Jet pilots
                    if onImportRAIDO != nil {
                        WelcomeActionCard(
                            icon: "airplane.departure",
                            iconColor: .purple,
                            title: "Import from RAIDO",
                            description: "USA Jet crew scheduling export (JSON)",
                            badge: "USA Jet"
                        ) {
                            isPresented = false
                            onImportRAIDO?()
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Getting Started Tips
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Quick Tips")
                            .font(.headline)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        QuickTipRow(
                            icon: "clock.fill",
                            text: "Block time = OUT to IN, Flight time = OFF to ON"
                        )
                        QuickTipRow(
                            icon: "icloud.fill",
                            text: "Your data syncs automatically across all devices"
                        )
                        QuickTipRow(
                            icon: "calendar",
                            text: "Trips group flights by 10-hour rest breaks"
                        )
                    }

                    Button(action: { showingHelpSheet = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("View Full Help Guide")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
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
        .sheet(isPresented: $showingHelpSheet) {
            GettingStartedHelpSheet()
        }
    }
}

// MARK: - Quick Tip Row
struct QuickTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Getting Started Help Sheet
struct GettingStartedHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Pro Pilot Logbook")
                            .font(.title.bold())

                        Text("Everything you need to track your flights professionally.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Section 1: Understanding Times
                    HelpSectionCard(
                        icon: "clock.fill",
                        iconColor: .blue,
                        title: "Understanding Flight Times",
                        items: [
                            "OUT time: Push back from gate",
                            "OFF time: Wheels leave runway",
                            "ON time: Wheels touch runway",
                            "IN time: Parked at gate",
                            "Block time = OUT to IN",
                            "Flight time = OFF to ON"
                        ]
                    )

                    // Section 2: Trip Organization
                    HelpSectionCard(
                        icon: "folder.fill",
                        iconColor: .orange,
                        title: "How Trips Work",
                        items: [
                            "Trips group your flight legs together",
                            "Legs are grouped by 10-hour rest breaks",
                            "Trip pay tracking (USA Jet pilots)",
                            "Each trip can have multiple legs",
                            "Crew members can be added to trips"
                        ]
                    )

                    // Section 3: Data Import
                    HelpSectionCard(
                        icon: "arrow.down.doc.fill",
                        iconColor: .green,
                        title: "Importing Your Data",
                        items: [
                            "NOC Schedule: Forward crew portal email",
                            "RAIDO Export: USA Jet JSON backup file",
                            "CSV Import: ForeFlight and other apps",
                            "Manual Entry: Add flights one by one"
                        ]
                    )

                    // Section 4: CloudKit Sync
                    HelpSectionCard(
                        icon: "icloud.fill",
                        iconColor: .cyan,
                        title: "iCloud Sync",
                        items: [
                            "Data syncs automatically across devices",
                            "Works on iPhone, iPad, and Apple Watch",
                            "Offline mode - syncs when connected",
                            "End-to-end encrypted in iCloud",
                            "Sign into iCloud in Settings to enable"
                        ]
                    )

                    // Section 5: Pilot Flying/Monitoring
                    HelpSectionCard(
                        icon: "person.2.fill",
                        iconColor: .purple,
                        title: "Pilot Roles",
                        items: [
                            "PF (Pilot Flying): Made the landing",
                            "PM (Pilot Monitoring): Supported the leg",
                            "Automatically tracked from RAIDO 'X' marker",
                            "Can be set manually per leg"
                        ]
                    )

                    // Section 6: Compliance Tracking
                    HelpSectionCard(
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        title: "Compliance Tracking",
                        items: [
                            "30-Day Flight Time (100 hrs limit)",
                            "Annual Flight Time (1,000 hrs limit)",
                            "Duty time tracking with buffers",
                            "Part 121/135 configurable"
                        ]
                    )

                    // Support section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Need More Help?")
                            .font(.headline)

                        HStack(spacing: 16) {
                            Button(action: {
                                if let url = URL(string: "mailto:support@propilotapp.com") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Label("Contact Support", systemImage: "envelope.fill")
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                if let url = URL(string: "https://propilotapp.com/tutorials") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Label("Video Tutorials", systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Getting Started")
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
}

// MARK: - Help Section Card
struct HelpSectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
            onImportCSV: {},
            onImportRAIDO: {}
        )
    }
}

struct GettingStartedHelpSheet_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedHelpSheet()
    }
}

//
//  ElectronicLogbookHelpView.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 7/13/25.
//


// ElectronicLogbookHelpView.swift - Comprehensive Import/Export Guide
import SwiftUI

struct ElectronicLogbookHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab Selection
                Picker("Help Section", selection: $selectedTab) {
                    Text("Import").tag(0)
                    Text("Export").tag(1)
                    Text("Formats").tag(2)
                    Text("Tips").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                ScrollView {
                    switch selectedTab {
                    case 0:
                        ImportHelpView()
                    case 1:
                        ExportHelpView()
                    case 2:
                        FormatsHelpView()
                    case 3:
                        TipsHelpView()
                    default:
                        ImportHelpView()
                    }
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Electronic Logbook Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Import Help
struct ImportHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(
                title: "How to Import Your Logbook",
                icon: "square.and.arrow.down",
                color: LogbookTheme.accentBlue
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**Step 1: Export from your current logbook app**")
                        .foregroundColor(.white)
                    
                    Text("• **ForeFlight**: Logbook → Export → CSV Format")
                        .foregroundColor(.gray)
                    Text("• **LogTen Pro**: File → Export → CSV")
                        .foregroundColor(.gray)
                    Text("• **MyFlightbook**: Logbook → Export → CSV Download")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**Step 2: Choose import format in this app**")
                        .foregroundColor(.white)
                    
                    Text("Tap the import button for your source app (ForeFlight, LogTen Pro, etc.)")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**Step 3: Select your CSV file**")
                        .foregroundColor(.white)
                    
                    Text("Use the file picker to select the exported CSV from your Files app")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**What happens automatically:**")
                        .foregroundColor(.white)
                    
                    Text("✅ Night hours calculated using airport coordinates")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Cross-country time preserved or calculated")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ PIC/SIC times maintained")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Unknown airports automatically looked up")
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
            
            HelpSectionView(
                title: "Supported Import Sources",
                icon: "list.bullet",
                color: LogbookTheme.accentGreen
            ) {
                VStack(spacing: 12) {
                    ImportSourceCard(
                        name: "ForeFlight",
                        description: "Most comprehensive import with all flight data",
                        features: ["All flight times", "Landings", "Approaches", "Notes"],
                        icon: "airplane.departure",
                        color: .blue
                    )
                    
                    ImportSourceCard(
                        name: "LogTen Pro",
                        description: "Professional pilot logbook with detailed tracking",
                        features: ["Flight rules", "Aircraft types", "Crew positions"],
                        icon: "book.closed",
                        color: .green
                    )
                    
                    ImportSourceCard(
                        name: "MyFlightbook",
                        description: "Free online logbook with basic flight tracking",
                        features: ["Basic times", "Aircraft info", "Route data"],
                        icon: "cloud",
                        color: .orange
                    )
                    
                    ImportSourceCard(
                        name: "Generic CSV",
                        description: "Any CSV file with standard logbook columns",
                        features: ["Custom mapping", "Flexible format", "Manual setup"],
                        icon: "doc.text",
                        color: .gray
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - Export Help
struct ExportHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(
                title: "How to Export Your Logbook",
                icon: "square.and.arrow.up",
                color: LogbookTheme.accentGreen
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**Step 1: Choose export format**")
                        .foregroundColor(.white)
                    
                    Text("Select the format that matches where you want to import the data")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**Step 2: Export creates CSV file**")
                        .foregroundColor(.white)
                    
                    Text("The app generates a properly formatted CSV file for your chosen platform")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**Step 3: Share or save the file**")
                        .foregroundColor(.white)
                    
                    Text("• **Share**: Email, AirDrop, or send to another app")
                        .foregroundColor(.gray)
                    Text("• **Save**: Save to Files app for later use")
                        .foregroundColor(.gray)
                    Text("• **Import**: Open directly in target logbook app")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**What's included in exports:**")
                        .foregroundColor(.white)
                    
                    Text("✅ All flight times (Total, PIC, SIC, Night, XC)")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Aircraft information and registration")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Route information (departure/arrival)")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Landing counts and notes")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✅ Calculated night hours (FAA-compliant)")
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
            
            HelpSectionView(
                title: "Export Destinations",
                icon: "arrow.up.doc",
                color: LogbookTheme.accentOrange
            ) {
                VStack(spacing: 12) {
                    ExportDestinationCard(
                        name: "ForeFlight",
                        description: "Import into ForeFlight's logbook system",
                        timeFormat: "Decimal (1.5 hours)",
                        notes: "Perfect for ForeFlight users wanting to sync data"
                    )
                    
                    ExportDestinationCard(
                        name: "LogTen Pro",
                        description: "Professional format for LogTen Pro import",
                        timeFormat: "HH:MM (1:30)",
                        notes: "Includes flight rules and detailed aircraft data"
                    )
                    
                    ExportDestinationCard(
                        name: "Insurance/Employers",
                        description: "Generic format for official submissions",
                        timeFormat: "HH:MM (1:30)",
                        notes: "Clean, professional format for official use"
                    )
                    
                    ExportDestinationCard(
                        name: "Backup/Archive",
                        description: "Complete data backup in standard format",
                        timeFormat: "HH:MM (1:30)",
                        notes: "Preserves all data for long-term storage"
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - Formats Help
struct FormatsHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(
                title: "CSV Format Requirements",
                icon: "doc.text",
                color: LogbookTheme.accentBlue
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("**Required Columns for Import:**")
                        .foregroundColor(.white)
                    
                    Group {
                        FormatRowView(column: "Date", format: "MM/DD/YYYY", example: "07/13/2025")
                        FormatRowView(column: "Aircraft Type", format: "Text", example: "Hawker 800XP")
                        FormatRowView(column: "Departure", format: "ICAO Code", example: "KYIP")
                        FormatRowView(column: "Arrival", format: "ICAO Code", example: "KORD")
                        FormatRowView(column: "Total Time", format: "H:MM or Decimal", example: "2:15 or 2.25")
                    }
                    
                    Divider().background(.gray)
                    
                    Text("**Optional Columns:**")
                        .foregroundColor(.white)
                    
                    Group {
                        FormatRowView(column: "PIC Time", format: "H:MM", example: "2:15")
                        FormatRowView(column: "Night Time", format: "H:MM", example: "0:45")
                        FormatRowView(column: "Cross Country", format: "H:MM", example: "2:15")
                        FormatRowView(column: "Instrument", format: "H:MM", example: "1:30")
                        FormatRowView(column: "Landings", format: "Number", example: "1")
                    }
                }
            }
            
            HelpSectionView(
                title: "Sample CSV Formats",
                icon: "doc.plaintext",
                color: LogbookTheme.accentGreen
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("**ForeFlight Format:**")
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("Date,Aircraft Type,Aircraft ID,From,To,Total Time,PIC,Night,Cross Country\n07/13/2025,Hawker 800XP,N123AB,KYIP,KORD,2.25,2.25,0.75,2.25")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                    }
                    
                    Text("**LogTen Pro Format:**")
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("Date,Aircraft ID,Aircraft Type,Departure,Arrival,Total Duration,PIC,Night\n2025-07-13,N123AB,Hawker 800XP,KYIP,KORD,2:15,2:15,0:45")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(LogbookTheme.accentGreen)
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                    }
                    
                    Text("**Generic Format:**")
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("Date,Aircraft Type,Registration,Departure,Arrival,Total Time,PIC,Night\n2025-07-13,Hawker 800XP,N123AB,KYIP,KORD,2:15,2:15,0:45")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding()
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Tips Help
struct TipsHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSectionView(
                title: "Night Hours Calculation",
                icon: "moon.stars",
                color: .purple
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**How Night Hours Are Calculated:**")
                        .foregroundColor(.white)
                    
                    Text("✓ Uses FAA definition: Civil twilight to civil twilight")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✓ Based on actual airport coordinates (not estimated)")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✓ Accounts for sunset/sunrise at departure and arrival")
                        .foregroundColor(LogbookTheme.accentGreen)
                    Text("✓ Automatically calculated during import")
                        .foregroundColor(LogbookTheme.accentGreen)
                    
                    Divider().background(.gray)
                    
                    Text("**If airport coordinates are missing:**")
                        .foregroundColor(.white)
                    
                    Text("• App automatically looks up unknown airports online")
                        .foregroundColor(.gray)
                    Text("• You can manually add airport coordinates")
                        .foregroundColor(.gray)
                    Text("• Falls back to time-based estimation (6 PM - 6 AM)")
                        .foregroundColor(.gray)
                }
            }
            
            HelpSectionView(
                title: "Troubleshooting Tips",
                icon: "wrench.and.screwdriver",
                color: LogbookTheme.accentOrange
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    TroubleshootingCard(
                        problem: "Import fails or shows 0 entries",
                        solutions: [
                            "Check CSV file has headers in first row",
                            "Ensure dates are in MM/DD/YYYY format",
                            "Remove any special characters from aircraft names",
                            "Try Generic CSV format instead"
                        ]
                    )
                    
                    TroubleshootingCard(
                        problem: "Night hours seem incorrect",
                        solutions: [
                            "Verify airport ICAO codes (KYIP, not YIP)",
                            "Check if airports are in our database",
                            "Add missing airports manually if needed",
                            "Contact support for remote airport additions"
                        ]
                    )
                    
                    TroubleshootingCard(
                        problem: "Times don't match original logbook",
                        solutions: [
                            "Check if source uses decimal vs HH:MM format",
                            "Verify PIC/SIC times were recorded correctly",
                            "Some apps round times differently",
                            "Manual verification may be needed"
                        ]
                    )
                }
            }
            
            HelpSectionView(
                title: "Best Practices",
                icon: "checkmark.seal",
                color: LogbookTheme.accentGreen
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**Before Importing:**")
                        .foregroundColor(.white)
                    
                    Text("• Export a small test batch first (10-20 flights)")
                        .foregroundColor(.gray)
                    Text("• Verify dates and times look correct")
                        .foregroundColor(.gray)
                    Text("• Check that aircraft types are standardized")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**After Importing:**")
                        .foregroundColor(.white)
                    
                    Text("• Review a few entries for accuracy")
                        .foregroundColor(.gray)
                    Text("• Check that night hours look reasonable")
                        .foregroundColor(.gray)
                    Text("• Export a backup copy immediately")
                        .foregroundColor(.gray)
                    
                    Divider().background(.gray)
                    
                    Text("**For Airlines/Employers:**")
                        .foregroundColor(.white)
                    
                    Text("• Use Generic CSV format for maximum compatibility")
                        .foregroundColor(.gray)
                    Text("• Include all required columns (PIC, SIC, Night, XC)")
                        .foregroundColor(.gray)
                    Text("• Add detailed remarks for unusual flights")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
}

// MARK: - Helper Components

struct HelpSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            content
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

struct ImportSourceCard: View {
    let name: String
    let description: String
    let features: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(name)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                ForEach(features, id: \.self) { feature in
                    Text(feature)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(8)
    }
}

struct ExportDestinationCard: View {
    let name: String
    let description: String
    let timeFormat: String
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                Text("Time Format:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(timeFormat)
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Text(notes)
                .font(.caption2)
                .foregroundColor(LogbookTheme.accentGreen)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(8)
    }
}

struct FormatRowView: View {
    let column: String
    let format: String
    let example: String
    
    var body: some View {
        HStack {
            Text(column)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 100, alignment: .leading)
            
            Text(format)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(example)
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
        }
    }
}

struct TroubleshootingCard: View {
    let problem: String
    let solutions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("**Problem:** \(problem)")
                .font(.caption.bold())
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(solutions, id: \.self) { solution in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(LogbookTheme.accentOrange)
                        Text(solution)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(8)
    }
}
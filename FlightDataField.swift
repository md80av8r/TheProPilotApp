// FlightDataField.swift
// Updated for ForeFlight/LogTen Pro only support
import SwiftUI

// MARK: - Template Field Definitions
enum FlightDataField: String, CaseIterable {
    case date = "Date"
    case departure = "Departure"
    case arrival = "Arrival"
    case aircraftType = "Aircraft_Type"
    case aircraftRegistration = "Aircraft_Registration"
    case flightNumber = "Flight_Number"
    case totalTime = "Total_Time"
    case picTime = "PIC_Time"
    case sicTime = "SIC_Time"
    case nightTime = "Night_Time"
    case crossCountryTime = "Cross_Country_Time"
    case instrumentTime = "Instrument_Time"
    case dayLandings = "Day_Landings"
    case nightLandings = "Night_Landings"
    case approaches = "Approaches"
    case outTime = "Out_Time"
    case offTime = "Off_Time"
    case onTime = "On_Time"
    case inTime = "In_Time"
    case route = "Route"
    case crewRole = "Crew_Role"
    case captainName = "Captain_Name"
    case firstOfficerName = "First_Officer_Name"
    case notes = "Notes"
    
    var description: String {
        switch self {
        case .date: return "Flight date (YYYY-MM-DD format)"
        case .departure: return "Departure airport ICAO code (e.g., KJFK)"
        case .arrival: return "Arrival airport ICAO code (e.g., KLAX)"
        case .aircraftType: return "Aircraft type (e.g., B737-800, A320)"
        case .aircraftRegistration: return "Aircraft tail number (e.g., N12345)"
        case .flightNumber: return "Flight number (e.g., UA1234)"
        case .totalTime: return "Total flight time in decimal hours (e.g., 5.2)"
        case .picTime: return "Pilot In Command time in decimal hours"
        case .sicTime: return "Second In Command time in decimal hours"
        case .nightTime: return "Night flight time in decimal hours"
        case .crossCountryTime: return "Cross country time in decimal hours"
        case .instrumentTime: return "Instrument flight time in decimal hours"
        case .dayLandings: return "Number of day landings"
        case .nightLandings: return "Number of night landings"
        case .approaches: return "Number of instrument approaches"
        case .outTime: return "Out time (HHMM format, e.g., 0800)"
        case .offTime: return "Off time (HHMM format, e.g., 0815)"
        case .onTime: return "On time (HHMM format, e.g., 1345)"
        case .inTime: return "In time (HHMM format, e.g., 1400)"
        case .route: return "Flight route or routing"
        case .crewRole: return "Your role (Captain, First Officer, etc.)"
        case .captainName: return "Captain's name"
        case .firstOfficerName: return "First Officer's name"
        case .notes: return "Additional notes or remarks"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .date, .departure, .arrival, .totalTime:
            return true
        default:
            return false
        }
    }
}

// MARK: - Template Generator
class FlightDataTemplateGenerator {
    
    static func generateCSVTemplate(format: LogbookFormat = .foreFlight, includeExamples: Bool = true) -> String {
        let fields = getFieldsForFormat(format)
        let headers = fields.map { $0.rawValue }.joined(separator: ",")
        
        if includeExamples {
            let examples = generateExampleRows(for: fields, format: format)
            return headers + "\n" + examples.joined(separator: "\n")
        } else {
            return headers
        }
    }
    
    static func generateFieldGuide(format: LogbookFormat = .foreFlight) -> [(field: FlightDataField, description: String, required: Bool)] {
        let fields = getFieldsForFormat(format)
        return fields.map { field in
            (field: field, description: field.description, required: field.isRequired)
        }
    }
    
    private static func getFieldsForFormat(_ format: LogbookFormat) -> [FlightDataField] {
        switch format {
        case .foreFlight:
            return [
                .date, .departure, .arrival, .aircraftType, .aircraftRegistration,
                .totalTime, .picTime, .sicTime, .nightTime, .crossCountryTime,
                .instrumentTime, .dayLandings, .nightLandings, .approaches,
                .route, .captainName, .firstOfficerName, .notes
            ]
            
        case .logTenPro:
            return [
                .date, .departure, .arrival, .aircraftType, .aircraftRegistration,
                .flightNumber, .totalTime, .picTime, .sicTime, .nightTime,
                .crossCountryTime, .instrumentTime, .outTime, .offTime,
                .onTime, .inTime, .crewRole, .captainName, .firstOfficerName, .notes
            ]
        }
    }
    
    private static func generateExampleRows(for fields: [FlightDataField], format: LogbookFormat) -> [String] {
        switch format {
        case .foreFlight:
            return [
                "2024-01-15,KJFK,KLAX,B737-800,N12345,5.2,5.2,0.0,0.0,5.2,0.0,1,0,1,JFK-LAX,John Smith,Jane Doe,Smooth flight",
                "2024-01-15,KLAX,KPHX,B737-800,N12345,1.5,1.5,0.0,0.0,1.5,0.0,1,0,1,LAX-PHX,John Smith,Jane Doe,Weather delay 30 min",
                "2024-01-16,KPHX,KORD,B737-800,N12345,3.8,3.8,0.0,1.2,3.8,0.5,1,0,2,PHX-ORD via CIVAP,John Smith,Jane Doe,ILS approach ORD"
            ]
            
        case .logTenPro:
            return [
                "2024-01-15,KJFK,KLAX,B737-800,N12345,UA1234,5.2,5.2,0.0,0.0,5.2,0.0,0800,0815,1345,1400,Captain,John Smith,Jane Doe,Smooth flight",
                "2024-01-15,KLAX,KPHX,B737-800,N12345,UA5678,1.5,1.5,0.0,0.0,1.5,0.0,1500,1515,1630,1645,Captain,John Smith,Jane Doe,Weather delay 30 min",
                "2024-01-16,KPHX,KORD,B737-800,N12345,UA9012,3.8,3.8,0.0,1.2,3.8,0.5,0630,0645,1015,1030,Captain,John Smith,Jane Doe,ILS approach ORD"
            ]
        }
    }
}

// MARK: - Template Download View
struct FlightDataTemplateView: View {
    @State private var selectedFormat: LogbookFormat = .foreFlight
    @State private var includeExamples = true
    @State private var showingShareSheet = false
    @State private var templateContent = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                formatSelectionSection
                optionsSection
                fieldGuideSection
                actionButtonsSection
                
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navy)
            .navigationTitle("Import Template")
            .navigationBarItems(trailing: Button("Done") { /* dismiss */ })
        }
        .sheet(isPresented: $showingShareSheet) {
            if !templateContent.isEmpty {
                ShareSheet(items: [createCSVFile()])
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("Flight Data Import Template")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Generate a CSV template to import your flight data")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Format")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(LogbookFormat.allCases, id: \.self) { format in
                formatButton(for: format)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }

    private func formatButton(for format: LogbookFormat) -> some View {
        Button(action: {
            selectedFormat = format
        }) {
            HStack {
                formatIcon(for: format)
                formatText(for: format)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatIcon(for format: LogbookFormat) -> some View {
        Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
            .foregroundColor(selectedFormat == format ? LogbookTheme.accentBlue : .gray)
    }

    private func formatText(for format: LogbookFormat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(format.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                if format == .foreFlight {
                    Text("GOLD STANDARD")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }
            Text(formatDescription(format))
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
                .foregroundColor(.white)
            
            Toggle("Include Example Data", isOn: $includeExamples)
                .toggleStyle(SwitchToggleStyle(tint: LogbookTheme.accentBlue))
                .foregroundColor(.white)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var fieldGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Guide")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    let fieldGuide = FlightDataTemplateGenerator.generateFieldGuide(format: selectedFormat)
                    
                    ForEach(Array(fieldGuide.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.field.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(item.required ? LogbookTheme.accentGreen : .white)
                                .frame(width: 120, alignment: .leading)
                            
                            Text(item.description)
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                            
                            if item.required {
                                Text("*")
                                    .font(.caption.bold())
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 200)
            
            Text("* Required fields")
                .font(.caption)
                .foregroundColor(LogbookTheme.accentGreen)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("Generate & Download Template") {
                generateTemplate()
                showingShareSheet = true
            }
            .buttonStyle(TemplateButtonStyle(color: LogbookTheme.accentBlue))
            
            Button("Copy Template to Clipboard") {
                generateTemplate()
                UIPasteboard.general.string = templateContent
            }
            .buttonStyle(TemplateButtonStyle(color: LogbookTheme.accentGreen))
        }
    }
    
    private func formatDescription(_ format: LogbookFormat) -> String {
        switch format {
        case .foreFlight:
            return "Compatible with ForeFlight logbook exports - decimal time format"
        case .logTenPro:
            return "Compatible with LogTen Pro exports - includes additional timing fields"
        }
    }
    
    private func generateTemplate() {
        templateContent = FlightDataTemplateGenerator.generateCSVTemplate(
            format: selectedFormat,
            includeExamples: includeExamples
        )
    }
    
    private func createCSVFile() -> URL {
        let fileName = "FlightData_\(selectedFormat.displayName.replacingOccurrences(of: " ", with: "_"))_Template.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try templateContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create CSV file: \(error)")
        }
        
        return tempURL
    }
}

// MARK: - Custom Button Style for Templates
struct TemplateButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Integration with Existing Scanner View
extension DocumentScannerView {
    var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Templates")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Download CSV templates to import flight data from ForeFlight or LogTen Pro")
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Button("Download Import Templates") {
                // Show template view
            }
            .buttonStyle(TemplateButtonStyle(color: LogbookTheme.accentOrange))
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

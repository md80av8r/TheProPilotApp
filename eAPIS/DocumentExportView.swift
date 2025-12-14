//
//  DocumentExportView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import SwiftUI

struct DocumentExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let manifest: EAPISManifest
    let passengers: [Passenger]
    
    @State private var selectedFormat: EAPISDocumentFormat = .gendec
    @State private var generatedDocument: String = ""
    @State private var pilotOperatorName: String = UserDefaults.standard.string(forKey: "pilotOperatorName") ?? "Private Operator"
    @State private var showingShareSheet = false
    @State private var showingPrintSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Format")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(EAPISDocumentFormat.allCases, id: \.self) { format in
                            Text(format.description).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    
                    // Format Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Document Preview
                ScrollView {
                    Text(generatedDocument)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Export Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            shareDocument()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            saveAsTextFile()
                        } label: {
                            Label("Save as File", systemImage: "square.and.arrow.down")
                        }
                        
                        Button {
                            emailDocument()
                        } label: {
                            Label("Email", systemImage: "envelope")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                generateDocument()
            }
            .onChange(of: selectedFormat) { _, _ in
                generateDocument()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = createTextFile() {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private var formatDescription: String {
        switch selectedFormat {
        case .gendec:
            return "Standard General Declaration for international general aviation flights. Accepted by most countries."
        case .canada:
            return "Canada Border Services eManifest format. Required for flights entering Canada."
        case .mexico:
            return "Mexican customs declaration format. Required for flights entering Mexico."
        case .caribbean:
            return "Standard format for Caribbean destinations including Cuba, Bahamas, Cayman Islands, etc."
        case .europe:
            return "Schengen Area entry declaration. Required for flights entering European countries."
        }
    }
    
    private func generateDocument() {
        let pilotInfo = PilotInfo(
            operatorName: pilotOperatorName,
            operatorAddress: "USA",
            operatorPhone: ""
        )
        
        generatedDocument = selectedFormat.generate(
            manifest: manifest,
            passengers: passengers,
            pilotInfo: pilotInfo
        )
    }
    
    private func shareDocument() {
        showingShareSheet = true
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = generatedDocument
        
        // Show feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func createTextFile() -> URL? {
        let fileName = "\(manifest.flightNumber)_\(selectedFormat.rawValue.replacingOccurrences(of: " ", with: "_")).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try generatedDocument.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("❌ Failed to create file: \(error)")
            return nil
        }
    }
    
    private func saveAsTextFile() {
        guard let url = createTextFile() else { return }
        
        // Present activity view controller to save file
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func emailDocument() {
        guard let url = createTextFile() else { return }
        
        let subject = "\(manifest.flightNumber) - \(selectedFormat.description)"
        let body = "Flight manifest attached for \(manifest.flightNumber) from \(manifest.departureAirport) to \(manifest.arrivalAirport)"
        
        // Create mailto URL with attachment (note: iOS mail doesn't support attachments via URL scheme)
        // Instead, we'll share it which allows user to choose email
        let activityVC = UIActivityViewController(
            activityItems: [subject, body, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Format Templates View
struct DocumentFormatTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EAPISDocumentFormat.allCases, id: \.self) { format in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(format.description)
                                .font(.headline)
                            
                            Text(formatRequirements(for: format))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Available Formats")
                } footer: {
                    Text("Select the appropriate format based on your destination country. Each format includes the required information for customs and border control.")
                }
                
                Section("Country-Specific Requirements") {
                    VStack(alignment: .leading, spacing: 12) {
                        requirementRow(
                            country: "Canada",
                            requirements: "• eManifest required for all arrivals\n• Must be filed before departure\n• CANPASS holders may have different requirements"
                        )
                        
                        requirementRow(
                            country: "Mexico",
                            requirements: "• FMM (Forma Migratoria Múltiple) may be required\n• Customs declaration mandatory\n• Tourist card for passengers"
                        )
                        
                        requirementRow(
                            country: "Caribbean",
                            requirements: "• Varies by island\n• Most require advance passenger manifest\n• Some require arrival/departure cards"
                        )
                        
                        requirementRow(
                            country: "Europe (Schengen)",
                            requirements: "• General Declaration required\n• Passport validity: 6 months minimum\n• Visa requirements vary by nationality"
                        )
                    }
                }
            }
            .navigationTitle("Document Formats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatRequirements(for format: EAPISDocumentFormat) -> String {
        switch format {
        case .gendec:
            return "Universal format accepted by most countries. Includes aircraft, crew, passenger, and customs information."
        case .canada:
            return "Required for Canada Border Services. Must include all passenger passport details and address information."
        case .mexico:
            return "Mexican customs format. Includes bilingual headers and specific Mexican requirements."
        case .caribbean:
            return "Standard format for Caribbean destinations. Includes all required passport and travel information."
        case .europe:
            return "Schengen Area format. Requires detailed passenger information including place of birth and residential address."
        }
    }
    
    private func requirementRow(country: String, requirements: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(country)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(requirements)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocumentExportView(
        manifest: EAPISManifest(
            flightNumber: "N123AB",
            aircraftRegistration: "N123AB",
            aircraftType: "B737",
            departureAirport: "KYIP",
            arrivalAirport: "MMCU",
            pilotInCommand: "John Smith",
            pilotLicense: "1234567"
        ),
        passengers: [Passenger.sample]
    )
}
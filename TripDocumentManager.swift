//
//  TripDocumentManager.swift
//  TheProPilotApp
//
//  Complete Smart Document Management System
//  Created by Jeffrey Kadans on 10/18/25.
//
//  NOTE: TripDocumentType enum is now defined in TripType.swift
//

import SwiftUI
import Foundation

// MARK: - Document Metadata
struct TripDocument: Identifiable, Codable {
    let id: UUID
    let tripNumber: String
    let documentType: TripDocumentType
    let fileName: String
    let createdDate: Date
    let relativePath: String  // Stores relative path like "TripDocuments/Trip_123/Receipt.pdf"
    
    init(tripNumber: String, documentType: TripDocumentType, fileName: String, relativePath: String) {
        self.id = UUID()
        self.tripNumber = tripNumber
        self.documentType = documentType
        self.fileName = fileName
        self.createdDate = Date()
        self.relativePath = relativePath
    }
    
    // BACKWARD COMPATIBILITY: Support old documents with absolute paths
    var filePath: String {
        if relativePath.hasPrefix("/") {
            return relativePath
        }
        return Self.documentsDirectory.appendingPathComponent(relativePath).path
    }
    
    // Reconstruct full URL from relative path using current container
    var fileURL: URL? {
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        return Self.documentsDirectory.appendingPathComponent(relativePath)
    }
    
    // Helper to get Documents directory
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Email Field Enum
enum EmailField: String, CaseIterable, Identifiable, Codable {
    case tripNumber = "Trip Number"
    case aircraft = "Aircraft"
    case date = "Date"
    case departure = "Departure"
    case arrival = "Arrival"
    case crew = "Crew"
    case blockTime = "Block Time"
    case passengers = "Passengers"
    case route = "Full Route"
    case notes = "Notes"
    
    var id: String { rawValue }
    
    func getValue(from trip: Trip) -> String {
        switch self {
        case .tripNumber:
            return "Trip #\(trip.tripNumber)"
        case .aircraft:
            return trip.aircraft
        case .date:
            return trip.date.formatted(date: .abbreviated, time: .omitted)
        case .departure:
            return trip.legs.first?.departure ?? "N/A"
        case .arrival:
            return trip.legs.last?.arrival ?? "N/A"
        case .crew:
            return trip.crew.filter { !$0.name.isEmpty }
                .map { "\($0.role): \($0.name)" }
                .joined(separator: ", ")
        case .blockTime:
            return trip.formattedTotalTime
        case .passengers:
            return "N/A"
        case .route:
            return trip.legs.map { "\($0.departure)-\($0.arrival)" }.joined(separator: " > ")
        case .notes:
            return trip.notes
        }
    }
}

// MARK: - Email Template Configuration
struct EmailTemplateConfig: Codable {
    var subjectFields: [EmailField]
    var bodyFields: [EmailField]
    
    func generateSubject(for trip: Trip, documentType: TripDocumentType) -> String {
        let fields = subjectFields.map { $0.getValue(from: trip) }.joined(separator: " - ")
        return "\(fields) - \(documentType.rawValue)"
    }
    
    func generateBody(for trip: Trip, documentType: TripDocumentType, fileName: String) -> String {
        var body = ""
        
        body += "\(documentType.rawValue.uppercased())\n"
        body += String(repeating: "=", count: documentType.rawValue.count) + "\n\n"
        
        for field in bodyFields {
            let label = field.rawValue
            let value = field.getValue(from: trip)
            if !value.isEmpty && value != "N/A" {
                body += "\(label): \(value)\n"
            }
        }
        
        body += "\n"
        body += "Attached: \(fileName)\n"
        body += "\n---\n"
        body += "Sent from ProPilot App\n"
        
        return body
    }
}

// MARK: - Document Manager (Main Class)
class TripDocumentManager: ObservableObject {
    @Published var documents: [TripDocument] = []
    @Published var emailTemplates: [TripDocumentType: EmailTemplateConfig] = [:]
    
    private let documentsKey = "trip_documents"
    private let templatesKey = "email_templates"
    
    init() {
        loadDocuments()
        loadEmailTemplates()
    }
    
    // MARK: - Directory Structure
    func getTripDocumentsDirectory() -> URL {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tripDocsPath = documentsPath.appendingPathComponent("TripDocuments")
        
        if !fileManager.fileExists(atPath: tripDocsPath.path) {
            try? fileManager.createDirectory(at: tripDocsPath, withIntermediateDirectories: true)
        }
        
        return tripDocsPath
    }
    
    func getTripDirectory(tripNumber: String) -> URL {
        let tripDir = getTripDocumentsDirectory().appendingPathComponent("Trip_\(tripNumber)")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: tripDir.path) {
            try? fileManager.createDirectory(at: tripDir, withIntermediateDirectories: true)
        }
        
        return tripDir
    }
    
    func getDocumentTypeDirectory(tripNumber: String, documentType: TripDocumentType) -> URL {
        let tripDir = getTripDirectory(tripNumber: tripNumber)
        let docTypeDir = tripDir.appendingPathComponent(documentType.folderName)
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: docTypeDir.path) {
            try? fileManager.createDirectory(at: docTypeDir, withIntermediateDirectories: true)
        }
        
        return docTypeDir
    }
    
    // MARK: - Add Document with Smart Naming (Trip Number First)
    func addDocument(tripNumber: String, documentType: TripDocumentType, fileName: String, sourceURL: URL) -> Bool {
        let docTypeDir = getDocumentTypeDirectory(tripNumber: tripNumber, documentType: documentType)
        
        // Smart file naming: Trip_12345 - Ground_Handler_Form - 2025-10-18_14-30.pdf
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        
        let smartFileName = "Trip_\(tripNumber) - \(documentType.filePrefix) - \(timestamp).pdf"
        let destinationURL = docTypeDir.appendingPathComponent(smartFileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Calculate relative path from Documents directory
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let relativePath = destinationURL.path.replacingOccurrences(of: documentsDir.path + "/", with: "")
            
            print("📄 Saving document with relative path: \(relativePath)")
            
            let document = TripDocument(
                tripNumber: tripNumber,
                documentType: documentType,
                fileName: smartFileName,
                relativePath: relativePath
            )
            
            documents.append(document)
            saveDocuments()
            
            print("✅ Saved: \(smartFileName)")
            print("📁 Relative Path: \(relativePath)")
            
            return true
        } catch {
            print("❌ Error saving document: \(error)")
            return false
        }
    }
    
    // LEGACY COMPATIBILITY: For old scanner code that passes ScannedDocument
    func addDocument(_ scannedDoc: ScannedDocument, tripNumber: String) -> TripDocument? {
        guard let fileURL = scannedDoc.fileURL else { return nil }
        
        // Convert ScanType to TripDocumentType
        let docType: TripDocumentType = {
            switch scannedDoc.documentType {
            case .fuelReceipt: return .fuelReceipt
            case .logbookPage: return .logPage  // Updated to use .logPage
            case .maintenanceLog: return .other
            case .general: return .other
            }
        }()
        
        let success = addDocument(
            tripNumber: tripNumber,
            documentType: docType,
            fileName: scannedDoc.filename,
            sourceURL: fileURL
        )
        
        return success ? documents.last : nil
    }
    
    // MARK: - Email Template Management
    func getEmailTemplate(for documentType: TripDocumentType) -> EmailTemplateConfig {
        if let template = emailTemplates[documentType] {
            return template
        }
        
        let defaultTemplate = EmailTemplateConfig(
            subjectFields: documentType.defaultSubjectTemplate,
            bodyFields: documentType.defaultBodyTemplate
        )
        emailTemplates[documentType] = defaultTemplate
        saveEmailTemplates()
        return defaultTemplate
    }
    
    func updateEmailTemplate(for documentType: TripDocumentType, template: EmailTemplateConfig) {
        emailTemplates[documentType] = template
        saveEmailTemplates()
    }
    
    // MARK: - Get Documents
    func getDocuments(forTrip tripNumber: String) -> [TripDocument] {
        return documents.filter { $0.tripNumber == tripNumber }
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    func getDocuments(forTrip tripNumber: String, type: TripDocumentType) -> [TripDocument] {
        return documents.filter { $0.tripNumber == tripNumber && $0.documentType == type }
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    // Delete document
    func deleteDocument(_ document: TripDocument) {
        if let fileURL = document.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted document: \(document.fileName)")
        }
        documents.removeAll { $0.id == document.id }
        saveDocuments()
    }
    
    // MARK: - Clear All Documents (Fresh Start)
    func clearAllDocuments(deleteFiles: Bool = true) {
        print("🧹 Clearing all documents...")
        
        if deleteFiles {
            let tripDocsDir = getTripDocumentsDirectory()
            try? FileManager.default.removeItem(at: tripDocsDir)
            print("🗑️ Deleted all files in: \(tripDocsDir.path)")
            
            // Recreate the directory
            try? FileManager.default.createDirectory(at: tripDocsDir, withIntermediateDirectories: true)
        }
        
        documents.removeAll()
        saveDocuments()
        
        print("✅ All documents cleared! Ready for fresh start.")
    }
    
    // MARK: - Open in Files App
    func openTripFolderInFiles(tripNumber: String) {
        let tripDir = getTripDirectory(tripNumber: tripNumber)
        
        if FileManager.default.fileExists(atPath: tripDir.path) {
            let url = tripDir
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                print("📂 Opening Files app at: \(tripDir.path)")
            }
        } else {
            print("❌ Trip directory doesn't exist: \(tripDir.path)")
        }
    }
    
    // MARK: - Persistence
    private func saveDocuments() {
        if let encoded = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(encoded, forKey: documentsKey)
        }
    }
    
    private func loadDocuments() {
        if let data = UserDefaults.standard.data(forKey: documentsKey),
           let decoded = try? JSONDecoder().decode([TripDocument].self, from: data) {
            documents = decoded
            
            let oldDocuments = documents.filter { $0.relativePath.hasPrefix("/") }
            if !oldDocuments.isEmpty {
                print("⚠️ Found \(oldDocuments.count) documents with old absolute paths")
                print("⚠️ These documents may not work after app reinstall")
                print("💡 Consider rescanning these documents or calling clearAllDocuments()")
            } else if !documents.isEmpty {
                print("✅ All documents using relative paths - safe from container changes!")
            }
        }
    }
    
    private func saveEmailTemplates() {
        if let encoded = try? JSONEncoder().encode(emailTemplates) {
            UserDefaults.standard.set(encoded, forKey: templatesKey)
        }
    }
    
    private func loadEmailTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([TripDocumentType: EmailTemplateConfig].self, from: data) {
            emailTemplates = decoded
        }
    }
}

// MARK: - Document Type Picker Sheet

struct DocumentTypePicker: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (TripDocumentType) -> Void
    
    // Use ordered document types from settings
    private var orderedTypes: [TripDocumentType] {
        DocumentEmailSettingsStore.shared.orderedDocumentTypes
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(orderedTypes, id: \.self) { docType in
                    Button(action: {
                        onSelect(docType)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: docType.icon)
                                .font(.title3)
                                .foregroundColor(LogbookTheme.accentOrange)
                                .frame(width: 30)
                            
                            Text(docType.rawValue)
                                .font(.body)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Document Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Trip Documents View
struct TripDocumentsView: View {
    let tripNumber: String
    @ObservedObject var documentManager: TripDocumentManager
    @Environment(\.dismiss) var dismiss
    
    private var groupedDocuments: [TripDocumentType: [TripDocument]] {
        Dictionary(grouping: documentManager.getDocuments(forTrip: tripNumber)) { $0.documentType }
    }
    
    var body: some View {
        NavigationView {
            List {
                if documentManager.getDocuments(forTrip: tripNumber).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No documents yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Scan documents using the buttons on the trip banner")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(TripDocumentType.allCases, id: \.self) { docType in
                        if let docs = groupedDocuments[docType], !docs.isEmpty {
                            Section(header: Text(docType.rawValue)) {
                                ForEach(docs) { document in
                                    TripDocumentRow(document: document)
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { index in
                                        documentManager.deleteDocument(docs[index])
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trip #\(tripNumber) Documents")
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

// MARK: - Trip Document Row
struct TripDocumentRow: View {
    let document: TripDocument
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.documentType.icon)
                .foregroundColor(LogbookTheme.accentOrange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(document.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
                +
                Text(" at ")
                    .font(.caption)
                    .foregroundColor(.gray)
                +
                Text(document.createdDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

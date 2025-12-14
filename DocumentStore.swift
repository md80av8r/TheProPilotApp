//
//  DocumentStore.swift
//  ProPilotApp
//
//  Document Store with PDF support and export functionality
//

import Foundation
import UIKit
import PDFKit

class DocumentStore: ObservableObject {
    @Published var documents: [ScannedDocument] = []
    @Published var searchText = ""
    
    private let documentsKey = "SavedDocumentPaths"
    
    init() {
        print("📄 Initializing enhanced document store with PDF support")
        loadDocuments()
        createDirectoryStructure()
    }
    
    // MARK: - Directory Structure
    private func createDirectoryStructure() {
        let documentsDir = FileManager.getDocumentsDirectory()
        let scannerDir = documentsDir.appendingPathComponent("Scanner")
        let imagesDir = scannerDir.appendingPathComponent("Images")
        let pdfsDir = scannerDir.appendingPathComponent("PDFs")
        let exportsDir = scannerDir.appendingPathComponent("Exports")
        
        FileManager.createDirectoryIfNeeded(at: scannerDir)
        FileManager.createDirectoryIfNeeded(at: imagesDir)
        FileManager.createDirectoryIfNeeded(at: pdfsDir)
        FileManager.createDirectoryIfNeeded(at: exportsDir)
    }
    
    // MARK: - Computed Properties
    var filteredDocuments: [ScannedDocument] {
        if searchText.isEmpty {
            return documents
        }
        return documents.filter { document in
            document.filename.localizedCaseInsensitiveContains(searchText) ||
            document.extractedText?.localizedCaseInsensitiveContains(searchText) == true ||
            document.tags.joined().localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var tripDocuments: [ScannedDocument] {
        return documents.filter { $0.isActiveTrip }
    }
    
    var generalDocuments: [ScannedDocument] {
        return documents.filter { !$0.isActiveTrip }
    }
    
    var documentsByCategory: [String: [ScannedDocument]] {
        Dictionary(grouping: filteredDocuments) { document in
            let baseCategory = document.category
            return document.isActiveTrip ? "Trip \(baseCategory)" : baseCategory
        }
    }
    
    var documentsByFormat: [String: [ScannedDocument]] {
        Dictionary(grouping: filteredDocuments) { $0.fileFormat.rawValue }
    }
    
    var totalStorageUsed: String {
        let totalBytes = documents.reduce(0) { $0 + $1.fileSizeBytes }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    // MARK: - Document Management
    func addDocument(_ document: ScannedDocument) {
        print("📄 Adding document: \(document.filename) (Format: \(document.fileFormat.rawValue), Trip: \(document.isActiveTrip))")
        documents.append(document)
        saveDocuments()
    }
    
    func deleteDocument(_ document: ScannedDocument) {
        print("📄 Deleting document: \(document.filename)")
        
        // Delete associated files
        document.deleteFiles()
        
        // Remove from array
        documents.removeAll { $0.id == document.id }
        saveDocuments()
    }
    
    // MARK: - Export Functions
    func exportDocument(_ document: ScannedDocument) -> URL? {
        guard let fileURL = document.fileURL else { return nil }
        
        let exportsDir = FileManager.getDocumentsDirectory().appendingPathComponent("Scanner/Exports")
        FileManager.createDirectoryIfNeeded(at: exportsDir)
        
        let exportURL = exportsDir.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            // Copy file to exports directory
            if FileManager.default.fileExists(atPath: exportURL.path) {
                try FileManager.default.removeItem(at: exportURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: exportURL)
            
            print("📄 Exported document to: \(exportURL.path)")
            return exportURL
        } catch {
            print("⚠️ Failed to export document: \(error)")
            return nil
        }
    }
    
    // MARK: - Fixed Export Function
    func exportMultipleDocuments(_ documents: [ScannedDocument], as format: OutputFormat) -> URL? {
        guard !documents.isEmpty else { return nil }
        
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        
        switch format {
        case .pdf:
            return createCombinedPDF(from: documents, filename: "Combined_Export_\(timestamp)")
        default:
            return createZipArchive(from: documents, filename: "Documents_Export_\(timestamp)")
        }
    }
    
    private func createCombinedPDF(from documents: [ScannedDocument], filename: String) -> URL? {
        var allImages: [UIImage] = []
        
        for document in documents {
            if let image = document.uiImage {
                allImages.append(image)
            }
        }
        
        guard !allImages.isEmpty else { return nil }
        
        return PDFGenerator.createPDFWithMetadata(
            from: allImages,
            filename: filename,
            title: "ProPilot Document Export",
            author: "ProPilot Scanner",
            subject: "Combined Document Export"
        )
    }
    
    private func createZipArchive(from documents: [ScannedDocument], filename: String) -> URL? {
        // This would require a ZIP library like ZIPFoundation
        // For now, return nil - implement if needed
        print("📄 ZIP export not implemented yet")
        return nil
    }
    
    // MARK: - Sharing
    func saveToPhotos(_ document: ScannedDocument, completion: @escaping (Bool, String) -> Void) {
        guard let image = document.uiImage else {
            completion(false, "Failed to load image")
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, "Saved to Photos")
    }
    
    func shareDocument(_ document: ScannedDocument) -> [Any] {
        var items: [Any] = []
        
        if let fileURL = document.fileURL {
            items.append(fileURL)
        }
        
        if let extractedText = document.extractedText, !extractedText.isEmpty {
            items.append(extractedText)
        }
        
        return items
    }
    
    // MARK: - Persistence
    private func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            UserDefaults.standard.set(data, forKey: documentsKey)
            print("📄 Saved \(documents.count) documents to UserDefaults")
        } catch {
            print("⚠️ Failed to save documents: \(error)")
        }
    }
    
    private func loadDocuments() {
        guard let data = UserDefaults.standard.data(forKey: documentsKey) else {
            print("📄 No saved documents found")
            return
        }
        
        do {
            documents = try JSONDecoder().decode([ScannedDocument].self, from: data)
            print("📄 Loaded \(documents.count) documents from UserDefaults")
        } catch {
            print("⚠️ Failed to load documents: \(error)")
        }
    }
    
    // MARK: - Storage Management
    func cleanupOrphanedFiles() {
        let documentsDir = FileManager.getDocumentsDirectory().appendingPathComponent("Scanner")
        
        // Get all saved document paths
        let savedPaths = Set(documents.compactMap { $0.fileURL?.path } + documents.compactMap { $0.pdfPath })
        
        // Find files not referenced by any document
        if let enumerator = FileManager.default.enumerator(at: documentsDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if !savedPaths.contains(fileURL.path) {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("📄 Cleaned up orphaned file: \(fileURL.path)")
                }
            }
        }
    }
}

// MARK: - Convenience Extensions
extension DateFormatter {
    func apply(closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}


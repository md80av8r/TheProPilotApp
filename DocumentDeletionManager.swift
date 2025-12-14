//
//  DocumentDeletionManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//


//
//  DocumentDeletionManager.swift
//  ProPilotApp
//
//  Handles safe deletion of scanned documents with file system cleanup
//

import Foundation
import SwiftUI

// MARK: - Document Deletion Manager
class DocumentDeletionManager {
    
    static let shared = DocumentDeletionManager()
    
    private init() {}
    
    /// Delete a single document from the file system
    /// - Parameters:
    ///   - document: The scanned document to delete
    ///   - completion: Callback with success status and optional error message
    func deleteDocument(_ document: ScannedDocument, completion: @escaping (Bool, String?) -> Void) {
        guard let fileURL = document.fileURL else {
            completion(false, "Document file path not found")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                
                // Check if file exists
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    DispatchQueue.main.async {
                        completion(false, "File does not exist")
                    }
                    return
                }
                
                // Delete the file
                try fileManager.removeItem(at: fileURL)
                
                DebugLogger.logFileOperation("DELETE", path: fileURL.path, success: true)
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
                
            } catch {
                DebugLogger.logFileOperation("DELETE", path: fileURL.path, success: false)
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    /// Delete multiple documents at once
    /// - Parameters:
    ///   - documents: Array of documents to delete
    ///   - completion: Callback with success count and any errors
    func deleteDocuments(_ documents: [ScannedDocument], completion: @escaping (Int, [String]) -> Void) {
        var successCount = 0
        var errors: [String] = []
        let group = DispatchGroup()
        
        for document in documents {
            group.enter()
            deleteDocument(document) { success, error in
                if success {
                    successCount += 1
                } else if let error = error {
                    errors.append("\(document.filename): \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(successCount, errors)
        }
    }
    
    /// Delete an entire trip folder and all its contents
    /// - Parameters:
    ///   - tripNumber: The trip number/identifier
    ///   - completion: Callback with success status and optional error message
    func deleteTripFolder(_ tripNumber: String, completion: @escaping (Bool, String?) -> Void) {
        let folderURL = getDocumentsDirectory()
            .appendingPathComponent("Scanned Documents", isDirectory: true)
            .appendingPathComponent(tripNumber, isDirectory: true)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                
                // Check if folder exists
                guard fileManager.fileExists(atPath: folderURL.path) else {
                    DispatchQueue.main.async {
                        completion(false, "Folder does not exist")
                    }
                    return
                }
                
                // Delete entire folder
                try fileManager.removeItem(at: folderURL)
                
                DebugLogger.logFileOperation("DELETE FOLDER", path: folderURL.path, success: true)
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
                
            } catch {
                DebugLogger.logFileOperation("DELETE FOLDER", path: folderURL.path, success: false)
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    /// Get the total file size of documents
    /// - Parameter documents: Array of documents to calculate size for
    /// - Returns: Total size in bytes
    func calculateTotalSize(of documents: [ScannedDocument]) -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        for document in documents {
            guard let fileURL = document.fileURL else { continue }
            
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    // MARK: - Helper
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - SwiftUI Extension for Document Lists
extension View {
    /// Add swipe-to-delete functionality to document rows
    func documentSwipeActions(
        document: ScannedDocument,
        onDelete: @escaping (ScannedDocument) -> Void
    ) -> some View {
        self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(document)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Deletion Confirmation Alert
struct DocumentDeletionAlert {
    
    /// Create a single document deletion alert
    static func confirmDelete(
        documentName: String,
        onConfirm: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text("Delete Document?"),
            message: Text("Are you sure you want to delete \"\(documentName)\"? This action cannot be undone."),
            primaryButton: .destructive(Text("Delete")) {
                onConfirm()
            },
            secondaryButton: .cancel()
        )
    }
    
    /// Create a multiple documents deletion alert
    static func confirmDeleteMultiple(
        count: Int,
        totalSize: String,
        onConfirm: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text("Delete \(count) Documents?"),
            message: Text("This will permanently delete \(count) document(s) (\(totalSize)). This action cannot be undone."),
            primaryButton: .destructive(Text("Delete All")) {
                onConfirm()
            },
            secondaryButton: .cancel()
        )
    }
    
    /// Create a trip folder deletion alert
    static func confirmDeleteFolder(
        tripNumber: String,
        documentCount: Int,
        onConfirm: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text("Delete Trip Folder?"),
            message: Text("This will permanently delete trip \(tripNumber) and all \(documentCount) document(s). This action cannot be undone."),
            primaryButton: .destructive(Text("Delete Folder")) {
                onConfirm()
            },
            secondaryButton: .cancel()
        )
    }
}

// MARK: - Deletion Result Toast
struct DeletionResultToast: View {
    let message: String
    let isError: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : LogbookTheme.accentGreen)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
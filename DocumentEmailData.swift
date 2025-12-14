//
//  DocumentEmailData.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/26/25.
//


//
//  DocumentEmailGenerator.swift
//  ProPilotApp
//
//  Generates email content based on document type and user settings
//

import Foundation

// MARK: - Document Email Data
struct DocumentEmailData {
    let toRecipients: [String]
    let ccRecipients: [String]
    let subject: String
    let body: String
    let attachmentURL: URL?
    
    /// Create email data for a scanned document
    /// - Parameters:
    ///   - documentType: The type of document scanned
    ///   - trip: The trip this document belongs to
    ///   - document: The scanned document (optional, for file info)
    ///   - attachmentURL: URL to the PDF file to attach
    ///   - crewManager: CrewContactManager for looking up crew emails (for auto-CC)
    init(
        documentType: TripDocumentType,
        trip: Trip,
        document: TripDocument? = nil,
        attachmentURL: URL? = nil,
        crewManager: CrewContactManager? = nil
    ) {
        let settings = DocumentEmailSettingsStore.shared
        let config = settings.getConfig(for: documentType)
        
        // To recipients
        let toEmail = config.toEmail
        self.toRecipients = toEmail.isEmpty ? [] : [toEmail]
        
        // CC recipients (includes crew if autoIncludeCrewCC is enabled)
        self.ccRecipients = settings.getCCEmails(
            for: documentType,
            trip: trip,
            crewManager: crewManager
        )
        
        // Generate subject
        self.subject = config.generateSubject(for: trip, documentType: documentType)
        
        // Generate body
        let fileName = document?.fileName ?? Self.generateFileName(for: documentType, tripNumber: trip.tripNumber)
        let fileSize = Self.getFileSize(attachmentURL ?? document?.fileURL)
        self.body = config.generateBody(for: trip, documentType: documentType, fileName: fileName, fileSize: fileSize)
        
        // Attachment
        self.attachmentURL = attachmentURL ?? document?.fileURL
    }
    
    // MARK: - Helpers
    private static func generateFileName(for documentType: TripDocumentType, tripNumber: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        return "Trip_\(tripNumber) - \(documentType.filePrefix) - \(timestamp).pdf"
    }
    
    private static func getFileSize(_ url: URL?) -> String? {
        guard let url = url else { return nil }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Convenience Extension for Email Composer
extension DocumentEmailData {
    /// Returns true if we have at least a recipient or the email is ready to send
    var isReady: Bool {
        return !toRecipients.isEmpty || !ccRecipients.isEmpty
    }
    
    /// Combined recipient display string
    var recipientsSummary: String {
        var parts: [String] = []
        if !toRecipients.isEmpty {
            parts.append("To: \(toRecipients.joined(separator: ", "))")
        }
        if !ccRecipients.isEmpty {
            parts.append("CC: \(ccRecipients.joined(separator: ", "))")
        }
        return parts.isEmpty ? "No recipients configured" : parts.joined(separator: " | ")
    }
}
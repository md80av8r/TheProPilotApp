//
//  TripDocumentThumbnailView.swift
//  TheProPilotApp
//
//  Displays thumbnails of scanned documents for a trip in DataEntryView
//  Reuses existing PDFThumbnailView and PDFKitView from the codebase
//

import SwiftUI
import PDFKit

// MARK: - Document Thumbnail Card for DataEntry (unique name to avoid conflict)
struct DataEntryDocumentCard: View {
    let document: TripDocument
    let onTap: () -> Void

    private let thumbnailSize = CGSize(width: 80, height: 100)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Thumbnail using existing PDFThumbnailView (uses fileURL parameter)
                ZStack {
                    PDFThumbnailView(fileURL: document.fileURL, size: thumbnailSize)
                        .cornerRadius(8)

                    // Document type icon overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: document.documentType.icon)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(LogbookTheme.accentOrange.opacity(0.9))
                                )
                        }
                    }
                    .padding(4)
                }
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                )

                // Document type label
                Text(document.documentType.shortName)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Document Thumbnails Strip (Horizontal Scroll)
struct TripDocumentThumbnailStrip: View {
    let tripNumber: String
    @ObservedObject var documentManager: TripDocumentManager
    let onScanDocument: () -> Void

    @State private var selectedDocument: TripDocument?
    @State private var showingPreview = false

    private var documents: [TripDocument] {
        documentManager.getDocuments(forTrip: tripNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(LogbookTheme.accentOrange)
                Text("Scanned Documents")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if !documents.isEmpty {
                    Text("\(documents.count)")
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(LogbookTheme.accentBlue.opacity(0.2))
                        )
                }
            }

            if documents.isEmpty {
                // Empty state
                HStack(spacing: 12) {
                    Button(action: onScanDocument) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.viewfinder")
                                .font(.title2)
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Scan Document")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LogbookTheme.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LogbookTheme.accentOrange.opacity(0.3), lineWidth: 1)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("No documents scanned yet.\nUse the active trip banner to scan.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 8)
            } else {
                // Horizontal scroll of thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Add scan button at the start
                        Button(action: onScanDocument) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LogbookTheme.fieldBackground)
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(LogbookTheme.accentOrange)
                                }
                                .frame(width: 80, height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LogbookTheme.accentOrange.opacity(0.3), lineWidth: 1)
                                )

                                Text("Add")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Document thumbnails
                        ForEach(documents) { document in
                            DataEntryDocumentCard(document: document) {
                                selectedDocument = document
                                showingPreview = true
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
        .sheet(isPresented: $showingPreview) {
            if let document = selectedDocument, let url = document.fileURL {
                DataEntryDocumentPreview(url: url, documentName: document.fileName)
            }
        }
    }
}

// MARK: - Document Preview Sheet (unique name to avoid conflict)
struct DataEntryDocumentPreview: View {
    let url: URL
    let documentName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            // Reuse existing PDFKitView from TripDocumentListView.swift
            PDFKitView(url: url)
                .navigationTitle(documentName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

// MARK: - TripDocumentType Extension for Short Names
extension TripDocumentType {
    var shortName: String {
        switch self {
        case .fuelReceipt: return "Fuel"
        case .customsGendec: return "GenDec"
        case .groundHandler: return "Handler"
        case .shipper: return "Shipper"
        case .reweighForm: return "Reweigh"
        case .loadManifest: return "Manifest"
        case .weatherBriefing: return "Wx"
        case .logPage: return "Log"
        case .other: return "Other"
        }
    }
}

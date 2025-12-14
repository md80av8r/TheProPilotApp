//
//  ShareSheet.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 9/22/25.
//
//  UIKit share sheet wrapper for SwiftUI
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]?
    var onDismiss: (() -> Void)?
    
    init(items: [Any], applicationActivities: [UIActivity]? = nil, onDismiss: (() -> Void)? = nil) {
        self.items = items
        self.applicationActivities = applicationActivities
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        
        // Set completion handler if provided
        if let onDismiss = onDismiss {
            controller.completionWithItemsHandler = { _, _, _, _ in
                onDismiss()
            }
        }
        
        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX,
                                       y: UIScreen.main.bounds.midY,
                                       width: 0,
                                       height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - File Export Helper Extension
extension ShareSheet {
    /// Creates a ShareSheet for exporting data as a file
    /// - Parameters:
    ///   - data: The data to export
    ///   - filename: The filename to use
    ///   - completion: Optional completion handler
    static func forFileExport(data: Data, filename: String, completion: (() -> Void)? = nil) -> ShareSheet {
        // Use documents directory for better handling
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        // Write data to file
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to write file: \(error)")
        }
        
        // Create ShareSheet with cleanup
        return ShareSheet(items: [fileURL], onDismiss: {
            // Clean up file after sharing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            completion?()
        })
    }
}

// MARK: - Share Trip Button View
struct ShareTripButton: View {
    let trip: Trip
    var style: ButtonStyleType = .iconOnly
    
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPreparingShare = false
    
    enum ButtonStyleType {
        case iconOnly
        case labeled
        case menuItem
        case custom  // For inline styling in action bars
    }
    
    var body: some View {
        Group {
            switch style {
            case .iconOnly:
                Button(action: prepareShare) {
                    if isPreparingShare {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isPreparingShare)
                
            case .labeled:
                Button(action: prepareShare) {
                    HStack(spacing: 8) {
                        if isPreparingShare {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Share Trip")
                    }
                }
                .disabled(isPreparingShare)
                
            case .menuItem:
                Button(action: prepareShare) {
                    Label("Share with Crewmember", systemImage: "square.and.arrow.up")
                }
                .disabled(isPreparingShare)
                
            case .custom:
                Button(action: prepareShare) {
                    HStack(spacing: 6) {
                        if isPreparingShare {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 16))
                        }
                        Text("Share")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LogbookTheme.accentOrange)
                    .cornerRadius(8)
                }
                .disabled(isPreparingShare)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url]) {
                    // Clean up temp file after sharing
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        .alert("Share Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func prepareShare() {
        isPreparingShare = true
        
        // Use background queue for file creation
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = TripSharingManager.shared.createShareableFile(for: trip) {
                DispatchQueue.main.async {
                    shareURL = url
                    showShareSheet = true
                    isPreparingShare = false
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Could not create shareable file"
                    showError = true
                    isPreparingShare = false
                }
            }
        }
    }
}

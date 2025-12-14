//
//  PDFThumbnailView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/26/25.
//  Updated: Rotates landscape PDFs to portrait (PDF Expert style)
//

import SwiftUI
import UIKit
import PDFKit

struct PDFThumbnailView: View {
    let fileURL: URL?
    let size: CGSize
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading && fileURL != nil {
                // Loading state - only show if we have a URL to load
                Rectangle()
                    .fill(LogbookTheme.fieldBackground)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LogbookTheme.accentBlue))
                    )
            } else {
                // Error/fallback state (no URL or failed to load)
                Rectangle()
                    .fill(LogbookTheme.fieldBackground)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: size.width * 0.3))
                            .foregroundColor(LogbookTheme.textSecondary)
                    )
            }
        }
        .cornerRadius(6)  // Slightly more rounded for Scanner Pro style
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        // Return early if no URL
        guard let fileURL = fileURL else {
            print("⚠️ PDFThumbnailView: No URL provided")
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        print("🔍 PDFThumbnailView: Loading thumbnail from \(fileURL.path)")
        
        // Generate thumbnail on background thread with rotation for landscape
        let result = await Task.detached(priority: .userInitiated) {
            await MainActor.run {
                generateThumbnailWithRotation(for: fileURL, size: size)
            }
        }.value
        
        await MainActor.run {
            self.thumbnail = result
            self.isLoading = false
            
            if result != nil {
                print("✅ PDFThumbnailView: Thumbnail loaded successfully")
            } else {
                print("❌ PDFThumbnailView: Failed to generate thumbnail for \(fileURL.path)")
            }
        }
    }
    
    /// Generates thumbnail and rotates landscape PDFs to portrait (PDF Expert style)
    private func generateThumbnailWithRotation(for url: URL, size: CGSize) -> UIImage? {
        // First try the existing generator
        if let cached = PDFThumbnailGenerator.shared.generateThumbnail(for: url, size: size) {
            // Check if we need to rotate
            if let document = PDFDocument(url: url),
               let page = document.page(at: 0) {
                let pageRect = page.bounds(for: .mediaBox)
                let isLandscape = pageRect.width > pageRect.height
                
                if isLandscape {
                    // Rotate 90° clockwise to display as portrait
                    return rotateImage(cached, byDegrees: 90)
                }
            }
            return cached
        }
        
        // Fallback: generate directly with PDFKit
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return nil
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        let isLandscape = pageRect.width > pageRect.height
        
        // Generate thumbnail
        let scale: CGFloat = 2.0
        let thumbnailSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        var thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        
        // Rotate landscape PDFs 90° clockwise to display as portrait
        if isLandscape {
            thumbnail = rotateImage(thumbnail, byDegrees: 90) ?? thumbnail
        }
        
        return thumbnail
    }
    
    /// Rotates an image by the specified degrees
    private func rotateImage(_ image: UIImage, byDegrees degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        
        // Calculate new size after rotation
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Move origin to center, rotate, then move back
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        image.draw(in: CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}

// MARK: - Preview-specific version for testing
struct PDFThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Small thumbnail
            PDFThumbnailView(
                fileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
                size: CGSize(width: 60, height: 80)
            )
            
            // Medium thumbnail
            PDFThumbnailView(
                fileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
                size: CGSize(width: 120, height: 160)
            )
            
            // Large thumbnail
            PDFThumbnailView(
                fileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
                size: CGSize(width: 200, height: 260)
            )
        }
        .padding()
        .background(LogbookTheme.navy)
        .preferredColorScheme(.dark)
    }
}

//
//  PDFThumbnailGenerator.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/26/25.
//  Updated: Smart rotation for landscape PDFs (PDF Expert style)
//

import SwiftUI
import PDFKit

class PDFThumbnailGenerator {
    static let shared = PDFThumbnailGenerator()
    
    // Cache for generated thumbnails
    private var thumbnailCache: [URL: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.propilot.thumbnailcache")
    
    private init() {}
    
    /// Generate thumbnail from PDF
    /// - Parameters:
    ///   - url: URL to the PDF file
    ///   - size: Desired thumbnail size (default 200x200)
    /// - Returns: UIImage thumbnail or nil if generation fails
    func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        print("📄 PDFThumbnailGenerator: Attempting to generate thumbnail for \(url.lastPathComponent)")
        print("   Path: \(url.path)")
        print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Check cache first
        if let cached = getCachedThumbnail(for: url) {
            print("✅ PDFThumbnailGenerator: Using cached thumbnail")
            return cached
        }
        
        // Generate new thumbnail
        guard let document = PDFDocument(url: url) else {
            print("❌ PDFThumbnailGenerator: Failed to create PDFDocument from URL")
            return nil
        }
        
        print("   PDF document loaded, page count: \(document.pageCount)")
        
        guard let page = document.page(at: 0) else {
            print("❌ PDFThumbnailGenerator: Failed to get page 0 from document")
            return nil
        }
        
        // Get the page bounds considering rotation
        let pageRect = page.bounds(for: .mediaBox)
        let pageRotation = page.rotation  // PDF's internal rotation (0, 90, 180, 270)
        
        // Determine effective dimensions after PDF's internal rotation
        let effectiveWidth: CGFloat
        let effectiveHeight: CGFloat
        
        if pageRotation == 90 || pageRotation == 270 {
            effectiveWidth = pageRect.height
            effectiveHeight = pageRect.width
        } else {
            effectiveWidth = pageRect.width
            effectiveHeight = pageRect.height
        }
        
        let isLandscape = effectiveWidth > effectiveHeight
        
        print("   Page size: \(pageRect.size)")
        print("   PDF rotation: \(pageRotation)°")
        print("   Effective size: \(effectiveWidth) x \(effectiveHeight)")
        print("   Is landscape: \(isLandscape)")
        print("   Target thumbnail size: \(size)")
        
        // Generate the thumbnail using PDFKit's built-in method (handles rotation correctly)
        let scale: CGFloat = 2.0
        var thumbnail = page.thumbnail(of: CGSize(width: size.width * scale, height: size.height * scale), for: .mediaBox)
        
        // PDF Expert style: If the resulting thumbnail is landscape (wider than tall),
        // rotate it 90° counter-clockwise so it displays as portrait
        if thumbnail.size.width > thumbnail.size.height {
            print("🔄 PDFThumbnailGenerator: Rotating landscape thumbnail to portrait")
            thumbnail = rotateImage(thumbnail, byDegrees: -90) ?? thumbnail
        }
        
        print("✅ PDFThumbnailGenerator: Thumbnail generated successfully (\(thumbnail.size))")
        
        // Cache the thumbnail
        cacheThumbnail(thumbnail, for: url)
        
        return thumbnail
    }
    
    /// Generate thumbnail asynchronously
    func generateThumbnailAsync(for url: URL, size: CGSize = CGSize(width: 200, height: 200), completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let thumbnail = self?.generateThumbnail(for: url, size: size)
            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }
    
    // MARK: - Image Rotation (PDF Expert style)
    
    /// Rotates an image by the specified degrees
    /// - Parameters:
    ///   - image: The image to rotate
    ///   - degrees: Rotation in degrees (positive = clockwise, negative = counter-clockwise)
    /// - Returns: Rotated image
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
    
    // MARK: - Cache Management
    
    private func getCachedThumbnail(for url: URL) -> UIImage? {
        return cacheQueue.sync {
            thumbnailCache[url]
        }
    }
    
    private func cacheThumbnail(_ image: UIImage, for url: URL) {
        cacheQueue.async { [weak self] in
            self?.thumbnailCache[url] = image
        }
    }
    
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.thumbnailCache.removeAll()
            print("🗑️ PDFThumbnailGenerator: Cache cleared")
        }
    }
    
    func clearCache(for url: URL) {
        cacheQueue.async { [weak self] in
            self?.thumbnailCache.removeValue(forKey: url)
        }
    }
}

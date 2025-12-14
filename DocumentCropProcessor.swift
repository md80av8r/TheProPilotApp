//
//  DocumentCropProcessor.swift
//  TheProPilotApp
//
//  Enhanced with Perspective Correction (Homography)
//  Includes legacy support for Side Cropping settings
//

import UIKit
import CoreImage
import Vision

struct DocumentCropProcessor {
    
    // MARK: - NEW: Perspective Correction
    
    /// Apply Perspective Correction (Warping) to an image
    static func applyPerspectiveCorrection(to image: UIImage,
                                           topLeft: CGPoint,
                                           topRight: CGPoint,
                                           bottomLeft: CGPoint,
                                           bottomRight: CGPoint) -> UIImage {
        
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Convert normalized points (0-1) to pixel coordinates
        let w = image.size.width
        let h = image.size.height
        
        // CoreImage uses Cartesian coordinates (origin at bottom-left)
        // We must flip Y for the input points
        let tl = CIVector(x: topLeft.x * w, y: (1 - topLeft.y) * h)
        let tr = CIVector(x: topRight.x * w, y: (1 - topRight.y) * h)
        let bl = CIVector(x: bottomLeft.x * w, y: (1 - bottomLeft.y) * h)
        let br = CIVector(x: bottomRight.x * w, y: (1 - bottomRight.y) * h)
        
        // Use CIPerspectiveCorrection filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(tl, forKey: "inputTopLeft")
        filter.setValue(tr, forKey: "inputTopRight")
        filter.setValue(bl, forKey: "inputBottomLeft")
        filter.setValue(br, forKey: "inputBottomRight")
        
        guard let outputImage = filter.outputImage else { return image }
        
        // Render back to UIImage
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - LEGACY: Side Cropping (Restored for Compatibility)
    
    /// Crop settings for document sides
    struct CropSettings: Codable {
        var leftCropPercentage: CGFloat = 0.0     // 0-50%
        var rightCropPercentage: CGFloat = 0.0    // 0-50%
        var topCropPercentage: CGFloat = 0.0      // 0-50%
        var bottomCropPercentage: CGFloat = 0.0   // 0-50%
        
        var isEnabled: Bool {
            return leftCropPercentage > 0 || rightCropPercentage > 0 ||
                   topCropPercentage > 0 || bottomCropPercentage > 0
        }
    }
    
    /// Apply side cropping to an image (Legacy method)
    static func applyCropping(to image: UIImage, settings: CropSettings) -> UIImage {
        guard settings.isEnabled else { return image }
        
        guard let cgImage = image.cgImage else { return image }
        
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        
        let leftCrop = originalWidth * (settings.leftCropPercentage / 100.0)
        let rightCrop = originalWidth * (settings.rightCropPercentage / 100.0)
        let topCrop = originalHeight * (settings.topCropPercentage / 100.0)
        let bottomCrop = originalHeight * (settings.bottomCropPercentage / 100.0)
        
        let newWidth = originalWidth - leftCrop - rightCrop
        let newHeight = originalHeight - topCrop - bottomCrop
        
        guard newWidth > 0 && newHeight > 0 else { return image }
        
        let cropRect = CGRect(x: leftCrop, y: topCrop, width: newWidth, height: newHeight)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return image }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    static func applyUniformSideCrop(to image: UIImage, sideCropPercentage: CGFloat) -> UIImage {
        let settings = CropSettings(
            leftCropPercentage: sideCropPercentage,
            rightCropPercentage: sideCropPercentage,
            topCropPercentage: 0,
            bottomCropPercentage: 0
        )
        return applyCropping(to: image, settings: settings)
    }
}

// MARK: - UserDefaults Extension (Restored)
extension UserDefaults {
    private static let cropSettingsKey = "DocumentCropSettings"
    
    var documentCropSettings: DocumentCropProcessor.CropSettings {
        get {
            guard let data = data(forKey: Self.cropSettingsKey),
                  let settings = try? JSONDecoder().decode(DocumentCropProcessor.CropSettings.self, from: data) else {
                return DocumentCropProcessor.CropSettings()
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Self.cropSettingsKey)
            }
        }
    }
}

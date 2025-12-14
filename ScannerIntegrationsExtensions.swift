// MinimalScannerFixes.swift - Only adds missing properties/extensions
import SwiftUI
import Vision
import UIKit

// MARK: - Only add missing extensions if needed

// Add folderPath property to ScannedDocument if it doesn't exist
extension ScannedDocument {
    var computedFolderPath: String {
        return URL(fileURLWithPath: imagePath).deletingLastPathComponent().lastPathComponent
    }
}

// Add folderName property to ScanType if it doesn't exist
extension ScanType {
    var computedFolderName: String {
        switch self {
        case .logbookPage: return "LogbookPages"
        case .fuelReceipt: return "FuelReceipts"
        case .maintenanceLog: return "MaintenanceLog"  // ← ADD THIS LINE
        case .general: return "Documents"
        }
    }
}

// MARK: - Smart Auto-Rotation
extension UIImage {
    /// Analyzes text orientation and rotates image if needed
    func fixedOrientationWithTextAnalysis() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        guard let results = request.results, !results.isEmpty else { return self }
        
        // Analyze the aspect ratio of text blocks
        // If text blocks are tall and narrow, the image is likely rotated 90 degrees
        var verticalCount = 0
        var horizontalCount = 0
        
        for observation in results.prefix(10) { // Check top 10 blocks
            let width = observation.boundingBox.width
            let height = observation.boundingBox.height
            
            if height > width * 1.5 {
                verticalCount += 1
            } else if width > height * 1.5 {
                horizontalCount += 1
            }
        }
        
        // If we found mostly vertical text blocks, rotate 90 degrees right
        if verticalCount > horizontalCount {
            print("🔄 Auto-Rotation: Detected sideways text. Rotating...")
            return self.rotated(by: Measurement(value: -90, unit: .degrees)) ?? self
        }
        
        return self
    }
    
    // Helper to rotate image
    func rotated(by angle: Measurement<UnitAngle>) -> UIImage? {
        let radians = CGFloat(angle.converted(to: .radians).value)
        
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians)).integral.size
        // Trim off the extremely small float value to prevent white lines
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: radians)
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

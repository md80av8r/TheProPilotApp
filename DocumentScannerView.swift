//
//  DocumentScannerView.swift
//  ProPilotApp
//
//  Complete enhanced scanner with side cropping, optimization, and document size selection
//
//  REQUIRED FILES:
//  - DocumentCropProcessor.swift (side cropping logic)
//  - DocumentCropSettingsView.swift (crop settings UI)
//

import SwiftUI
import VisionKit
import Vision
import PDFKit
import MessageUI
import AVFoundation
import Combine

// MARK: - Debug Logger
struct DebugLogger {
    static func log(_ message: String) {
        print("[SCANNER DEBUG] \(message)")
    }
    
    static func logFileOperation(_ operation: String, path: String, success: Bool) {
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        print("[FILE DEBUG] \(status): \(operation) - \(path)")
    }
}

// MARK: - File Size Presets
enum FileSizePreset: String, CaseIterable, Codable, Identifiable {
    case small = "Small (132KB)"
    case medium = "Medium (452KB)"
    case large = "Large (926KB)"
    
    var id: String { rawValue }
    
    var targetSizeKB: Int {
        switch self {
        case .small: return 132
        case .medium: return 452
        case .large: return 926
        }
    }
    
    var maxDimension: CGFloat {
        switch self {
        case .small: return 900
        case .medium: return 1400
        case .large: return 1920
        }
    }
    
    var compressionQuality: CGFloat {
        switch self {
        case .small: return 0.45
        case .medium: return 0.65
        case .large: return 0.75
        }
    }
    
    var icon: String {
        switch self {
        case .small: return "doc.text"
        case .medium: return "doc.text.fill"
        case .large: return "doc.richtext.fill"
        }
    }
    
    var description: String {
        switch self {
        case .small: return "Email-friendly, good for receipts"
        case .medium: return "Balanced quality and size"
        case .large: return "High quality, larger files"
        }
    }
}

// MARK: - Scan Type Enum
enum ScanType: String, CaseIterable, Codable {
    case fuelReceipt = "Fuel Receipt"
    case logbookPage = "Logbook Page"
    case maintenanceLog = "Maintenance Log"
    case general = "General Document"
    
    /// Default document size for this scan type
    var defaultDocumentSize: DocumentSize {
        switch self {
        case .fuelReceipt: return .receipt
        case .logbookPage: return .letterLandscape  // Logbook pages are landscape
        case .maintenanceLog: return .letter
        case .general: return .fullPage
        }
    }
}

// MARK: - Output Format
enum OutputFormat: String, CaseIterable, Codable {
    case jpeg = "JPEG"
    case png = "PNG"
    case pdf = "PDF"

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .jpeg, .png: return "photo"
        }
    }
}

// MARK: - Color Mode
enum ColorMode: String, CaseIterable, Codable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "Black & White"
    
    var icon: String {
        switch self {
        case .color: return "paintpalette"
        case .grayscale: return "circle.lefthalf.filled"
        case .blackAndWhite: return "circle.fill"
        }
    }
}

// MARK: - Document Size Options
enum DocumentSize: String, CaseIterable, Identifiable, Codable {
    case receipt = "Receipt"
    case businessCard = "Business Card"
    case letter = "Letter (8.5×11)"
    case letterLandscape = "Letter Landscape (11×8.5)"
    case legal = "Legal (8.5×14)"
    case a4 = "A4"
    case fullPage = "Full Page"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .receipt: return "receipt"
        case .businessCard: return "creditcard"
        case .letterLandscape: return "rectangle.landscape"
        case .letter, .legal, .a4, .fullPage: return "doc.text"
        }
    }
    
    var aspectRatio: CGFloat {
        switch self {
        case .receipt: return 3.0 / 5.0
        case .businessCard: return 3.5 / 2.0
        case .letter: return 8.5 / 11.0
        case .letterLandscape: return 11.0 / 8.5  // Landscape - wider than tall
        case .legal: return 8.5 / 14.0
        case .a4: return 8.27 / 11.69
        case .fullPage: return 8.5 / 11.0
        }
    }
    
    var description: String {
        switch self {
        case .receipt: return "Small receipts (3×5)"
        case .businessCard: return "Business cards"
        case .letter: return "Standard US letter"
        case .letterLandscape: return "Logbook pages, landscape"
        case .legal: return "Legal documents"
        case .a4: return "International standard"
        case .fullPage: return "General documents"
        }
    }
    
    var isLandscape: Bool {
        self == .letterLandscape || self == .businessCard
    }
}

// MARK: - Advanced Crop View (With Side Handles)
struct AdvancedCropView: View {
    @Binding var isPresented: Bool
    let image: UIImage
    let onCropComplete: (UIImage) -> Void
    var onCancel: (() -> Void)? = nil
    var pageNumber: Int? = nil
    var totalPages: Int? = nil
    
    // Corners (0.0 to 1.0)
    @State private var topLeft: CGPoint = CGPoint(x: 0.0, y: 0.0)
    @State private var topRight: CGPoint = CGPoint(x: 1.0, y: 0.0)
    @State private var bottomLeft: CGPoint = CGPoint(x: 0.0, y: 1.0)
    @State private var bottomRight: CGPoint = CGPoint(x: 1.0, y: 1.0)
    
    @State private var imageSize: CGSize = .zero
    @State private var activeHandle: CropHandle?
    @State private var touchLocation: CGPoint = .zero
    
    // Expanded enum to include sides
    enum CropHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case topSide, bottomSide, leftSide, rightSide
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            GeometryReader { imageGeo in
                                Color.clear.onAppear {
                                    imageSize = imageGeo.size
                                }
                            }
                        )
                    
                    if imageSize != .zero {
                        CropOverlay(
                            topLeft: $topLeft,
                            topRight: $topRight,
                            bottomLeft: $bottomLeft,
                            bottomRight: $bottomRight,
                            activeHandle: $activeHandle,
                            touchLocation: $touchLocation,
                            imageSize: imageSize
                        )
                    }
                    
                    // Loupe (Show for any handle interaction)
                    if let _ = activeHandle {
                        MagnifierView(image: image, touchLocation: touchLocation, imageDisplaySize: imageSize)
                            .frame(width: 100, height: 100)
                            .position(x: touchLocation.x, y: touchLocation.y - 80)
                    }
                }
            }
            .navigationTitle(pageNumber != nil ? "Crop Page \(pageNumber!)" : "Crop Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel?(); isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { cropAndComplete() }
                }
            }
        }
    }
    
    private func cropAndComplete() {
        let correctedImage = DocumentCropProcessor.applyPerspectiveCorrection(
            to: image,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
        onCropComplete(correctedImage)
    }
}

// MARK: - Crop Overlay (With Side Logic)
struct CropOverlay: View {
    @Binding var topLeft: CGPoint
    @Binding var topRight: CGPoint
    @Binding var bottomLeft: CGPoint
    @Binding var bottomRight: CGPoint
    @Binding var activeHandle: AdvancedCropView.CropHandle?
    @Binding var touchLocation: CGPoint
    let imageSize: CGSize
    
    // Track start positions for side dragging
    @State private var dragStartTopLeft: CGPoint = .zero
    @State private var dragStartTopRight: CGPoint = .zero
    @State private var dragStartBottomLeft: CGPoint = .zero
    @State private var dragStartBottomRight: CGPoint = .zero
    
    let impactGen = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            // Darken outer area
            Path { path in
                path.addRect(CGRect(origin: .zero, size: imageSize))
                path.addPath(quadPath())
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            
            // Border lines
            quadPath().stroke(Color.white, lineWidth: 2)
            
            // SIDE HANDLES (Pill/Bar shape)
            sideHandle(side: .topSide)
            sideHandle(side: .bottomSide)
            sideHandle(side: .leftSide)
            sideHandle(side: .rightSide)
            
            // CORNER HANDLES (Circles)
            cornerHandle(for: $topLeft, id: .topLeft)
            cornerHandle(for: $topRight, id: .topRight)
            cornerHandle(for: $bottomLeft, id: .bottomLeft)
            cornerHandle(for: $bottomRight, id: .bottomRight)
        }
    }
    
    // MARK: - Corner Handle Logic
    private func cornerHandle(for point: Binding<CGPoint>, id: AdvancedCropView.CropHandle) -> some View {
        let x = point.wrappedValue.x * imageSize.width
        let y = point.wrappedValue.y * imageSize.height
        
        return Circle()
            .fill(Color.white)
            .frame(width: 30, height: 30)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        activeHandle = id
                        touchLocation = value.location
                        
                        let newX = max(0, min(1, value.location.x / imageSize.width))
                        let newY = max(0, min(1, value.location.y / imageSize.height))
                        
                        point.wrappedValue = CGPoint(x: newX, y: newY)
                        impactGen.prepare()
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        impactGen.impactOccurred()
                    }
            )
    }
    
    // MARK: - Side Handle Logic
    private func sideHandle(side: AdvancedCropView.CropHandle) -> some View {
        // Calculate midpoint for handle position
        let p1: CGPoint
        let p2: CGPoint
        
        switch side {
        case .topSide:    (p1, p2) = (topLeft, topRight)
        case .bottomSide: (p1, p2) = (bottomLeft, bottomRight)
        case .leftSide:   (p1, p2) = (topLeft, bottomLeft)
        case .rightSide:  (p1, p2) = (topRight, bottomRight)
        default:          (p1, p2) = (.zero, .zero)
        }
        
        // Midpoint in pixels
        let midX = ((p1.x + p2.x) / 2) * imageSize.width
        let midY = ((p1.y + p2.y) / 2) * imageSize.height
        
        let isVertical = (side == .leftSide || side == .rightSide)
        
        return Capsule()
            .fill(Color.white)
            .frame(width: isVertical ? 6 : 40, height: isVertical ? 40 : 6)
            .shadow(radius: 2)
            .position(x: midX, y: midY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if activeHandle == nil {
                            // Store initial state when drag begins
                            dragStartTopLeft = topLeft
                            dragStartTopRight = topRight
                            dragStartBottomLeft = bottomLeft
                            dragStartBottomRight = bottomRight
                            activeHandle = side
                        }
                        
                        touchLocation = value.location
                        
                        // Calculate delta in normalized coordinates (0-1)
                        let deltaX = value.translation.width / imageSize.width
                        let deltaY = value.translation.height / imageSize.height
                        
                        // Apply delta to specific corners based on side
                        switch side {
                        case .topSide:
                            topLeft.y = clamp(dragStartTopLeft.y + deltaY)
                            topRight.y = clamp(dragStartTopRight.y + deltaY)
                        case .bottomSide:
                            bottomLeft.y = clamp(dragStartBottomLeft.y + deltaY)
                            bottomRight.y = clamp(dragStartBottomRight.y + deltaY)
                        case .leftSide:
                            topLeft.x = clamp(dragStartTopLeft.x + deltaX)
                            bottomLeft.x = clamp(dragStartBottomLeft.x + deltaX)
                        case .rightSide:
                            topRight.x = clamp(dragStartTopRight.x + deltaX)
                            bottomRight.x = clamp(dragStartBottomRight.x + deltaX)
                        default: break
                        }
                        
                        impactGen.prepare()
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        impactGen.impactOccurred()
                    }
            )
    }
    
    private func clamp(_ value: CGFloat) -> CGFloat {
        return max(0, min(1, value))
    }
    
    private func quadPath() -> Path {
        var path = Path()
        path.move(to: pt(topLeft))
        path.addLine(to: pt(topRight))
        path.addLine(to: pt(bottomRight))
        path.addLine(to: pt(bottomLeft))
        path.closeSubpath()
        return path
    }
    
    private func pt(_ norm: CGPoint) -> CGPoint {
        return CGPoint(x: norm.x * imageSize.width, y: norm.y * imageSize.height)
    }
}

// MARK: - Magnifier View
struct MagnifierView: View {
    let image: UIImage
    let touchLocation: CGPoint
    let imageDisplaySize: CGSize
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaleEffect(2.0) // 2x Zoom
                .frame(width: imageDisplaySize.width * 2, height: imageDisplaySize.height * 2)
                .position(x: -touchLocation.x * 2 + 50, y: -touchLocation.y * 2 + 50) // Counter-shift to center content
                .offset(x: imageDisplaySize.width, y: imageDisplaySize.height) // Center alignment fix
            
            // Crosshair
            Image(systemName: "plus")
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .bold))
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
        .shadow(radius: 5)
    }
}

// MARK: - ENHANCED Scanner Settings
class ScannerSettings: ObservableObject, Codable {
    @Published var imageEnhancement: Bool = true
    @Published var ocrEnabled: Bool = false
    @Published var enableCropEditor: Bool = false
    @Published var outputFormat: OutputFormat = .pdf
    @Published var colorMode: ColorMode = .grayscale  // DEFAULT TO GRAYSCALE
    
    @Published var selectedDocumentSize: DocumentSize = .receipt
    @Published var flashlightEnabled: Bool = false
    @Published var autoSendEmail: Bool = true
    @Published var imageQuality: ImageQuality = .balanced
    @Published var fileSizePreset: FileSizePreset = .small  // DEFAULT TO SMALL (132KB)
    
    private static let userDefaultsKey = "scannerSettings"
    private var cancellables = Set<AnyCancellable>()
    
    enum ImageQuality: String, CaseIterable, Codable {
        case high = "High Quality"
        case balanced = "Balanced"
        case fast = "Fast (Lower Quality)"
        
        var compressionQuality: CGFloat {
            switch self {
            case .high: return 0.75      // Reduced from 0.85 - still great quality
            case .balanced: return 0.65  // Reduced from 0.75 - best balance
            case .fast: return 0.50      // Reduced from 0.60 - smallest files
            }
        }
        
        var maxDimension: CGFloat {
            switch self {
            case .high: return 1920      // Reduced from 2400 - still excellent quality
            case .balanced: return 1440  // Reduced from 1920 - good for most docs
            case .fast: return 1200      // Reduced from 1440 - perfect for receipts
            }
        }
    }
    
    enum CodingKeys: CodingKey {
        case imageEnhancement, ocrEnabled, enableCropEditor, outputFormat, colorMode
        case selectedDocumentSize, flashlightEnabled, autoSendEmail, imageQuality, fileSizePreset
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        imageEnhancement = try container.decode(Bool.self, forKey: .imageEnhancement)
        ocrEnabled = try container.decodeIfPresent(Bool.self, forKey: .ocrEnabled) ?? false
        enableCropEditor = try container.decode(Bool.self, forKey: .enableCropEditor)
        outputFormat = try container.decode(OutputFormat.self, forKey: .outputFormat)
        colorMode = try container.decodeIfPresent(ColorMode.self, forKey: .colorMode) ?? .grayscale
        
        selectedDocumentSize = try container.decodeIfPresent(DocumentSize.self, forKey: .selectedDocumentSize) ?? .receipt
        flashlightEnabled = try container.decodeIfPresent(Bool.self, forKey: .flashlightEnabled) ?? false
        autoSendEmail = try container.decodeIfPresent(Bool.self, forKey: .autoSendEmail) ?? true
        imageQuality = try container.decodeIfPresent(ImageQuality.self, forKey: .imageQuality) ?? .balanced
        fileSizePreset = try container.decodeIfPresent(FileSizePreset.self, forKey: .fileSizePreset) ?? .small
        
        setupAutoSave()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(imageEnhancement, forKey: .imageEnhancement)
        try container.encode(ocrEnabled, forKey: .ocrEnabled)
        try container.encode(enableCropEditor, forKey: .enableCropEditor)
        try container.encode(outputFormat, forKey: .outputFormat)
        try container.encode(colorMode, forKey: .colorMode)
        
        try container.encode(selectedDocumentSize, forKey: .selectedDocumentSize)
        try container.encode(flashlightEnabled, forKey: .flashlightEnabled)
        try container.encode(autoSendEmail, forKey: .autoSendEmail)
        try container.encode(imageQuality, forKey: .imageQuality)
        try container.encode(fileSizePreset, forKey: .fileSizePreset)
    }
    
    init() {
        // Try to load saved settings
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(ScannerSettings.self, from: data) {
            DebugLogger.log("📥 Loading saved settings from UserDefaults...")
            DebugLogger.log("   - Color Mode: \(decoded.colorMode.rawValue)")
            DebugLogger.log("   - Crop Editor: \(decoded.enableCropEditor)")
            DebugLogger.log("   - Output Format: \(decoded.outputFormat.rawValue)")
            
            self.imageEnhancement = decoded.imageEnhancement
            self.ocrEnabled = decoded.ocrEnabled
            self.enableCropEditor = decoded.enableCropEditor
            self.outputFormat = decoded.outputFormat
            self.colorMode = decoded.colorMode
            self.selectedDocumentSize = decoded.selectedDocumentSize
            self.flashlightEnabled = decoded.flashlightEnabled
            self.autoSendEmail = decoded.autoSendEmail
            self.imageQuality = decoded.imageQuality
            
            DebugLogger.log("✅ Scanner settings loaded - Color Mode is now: \(self.colorMode.rawValue)")
        } else {
            DebugLogger.log("⚠️ No saved settings found, using defaults - Color Mode: \(self.colorMode.rawValue)")
        }
        
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        // Auto-save whenever any property changes
        Publishers.CombineLatest4(
            $imageEnhancement,
            $ocrEnabled,
            $enableCropEditor,
            $outputFormat
        )
        .dropFirst() // Skip initial values
        .debounce(for: 0.5, scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.save()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $colorMode,
            $selectedDocumentSize,
            $flashlightEnabled,
            $autoSendEmail
        )
        .dropFirst()
        .debounce(for: 0.5, scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.save()
        }
        .store(in: &cancellables)
        
        $imageQuality
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
            DebugLogger.log("💾 Scanner settings saved - Color Mode: \(colorMode.rawValue)")
        }
    }
}

// MARK: - Pre-Scan Configuration View
struct ScannerConfigurationView: View {
    @ObservedObject var settings: ScannerSettings
    let scanType: ScanType
    let onStartScan: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    documentSizePreview
                    documentSizeSection
                    fileSizeSection
                    colorModeSection
                    cameraSettingsSection
                    qualitySettingsSection
                    startScanButton
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Scan Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .onAppear {
                // Set default document size based on scan type
                settings.selectedDocumentSize = scanType.defaultDocumentSize
            }
        }
    }
    
    private var fileSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(LogbookTheme.accentOrange)
                Text("File Size")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(settings.fileSizePreset.description)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Picker("File Size", selection: $settings.fileSizePreset) {
                ForEach(FileSizePreset.allCases) { preset in
                    HStack {
                        Image(systemName: preset.icon)
                        Text(preset.rawValue)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var colorModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("Color Mode")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Grayscale recommended for smaller file sizes")
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Picker("Color Mode", selection: $settings.colorMode) {
                ForEach(ColorMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var documentSizePreview: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            RoundedRectangle(cornerRadius: 8)
                .stroke(LogbookTheme.accentBlue, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .aspectRatio(settings.selectedDocumentSize.aspectRatio, contentMode: .fit)
                .padding(40)
            
            VStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: settings.selectedDocumentSize.icon)
                    Text(settings.selectedDocumentSize.rawValue)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.bottom, 20)
            }
        }
        .frame(height: 280)
        .cornerRadius(12)
    }
    
    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Size")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Select the size that best matches your document")
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(DocumentSize.allCases) { size in
                    DocumentSizeButton(
                        size: size,
                        isSelected: settings.selectedDocumentSize == size
                    ) {
                        settings.selectedDocumentSize = size
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var cameraSettingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: settings.flashlightEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3)
                            .foregroundColor(settings.flashlightEnabled ? .yellow : LogbookTheme.textSecondary)
                        
                        Text("Flashlight")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text("Use in dark environments for better scans")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.flashlightEnabled)
                    .labelsHidden()
                    .tint(LogbookTheme.accentBlue)
            }
            
            Divider()
                .background(LogbookTheme.textSecondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.title3)
                            .foregroundColor(settings.imageEnhancement ? LogbookTheme.accentBlue : LogbookTheme.textSecondary)
                        
                        Text("Image Enhancement")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text("Automatically improve scan quality")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.imageEnhancement)
                    .labelsHidden()
                    .tint(LogbookTheme.accentBlue)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var qualitySettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Speed")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Higher quality takes longer to process")
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Picker("Quality", selection: $settings.imageQuality) {
                ForEach(ScannerSettings.ImageQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var startScanButton: some View {
        Button(action: onStartScan) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title3)
                Text("Start Scanning")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        LogbookTheme.accentBlue,
                        LogbookTheme.accentBlue.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Document Size Button
struct DocumentSizeButton: View {
    let size: DocumentSize
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: size.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : LogbookTheme.textSecondary)
                
                Text(size.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : LogbookTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? LogbookTheme.accentBlue : LogbookTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? LogbookTheme.accentBlue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Scanner Preferences
class ScannerPreferences: ObservableObject {
    @Published var airlineSettings: AirlineSettingsStore
    @Published var autoSendReceipts: Bool = false
    @Published var promptForNewTrip: Bool = true
    @Published var autoCreateTripFolders: Bool = true
    @Published var showFileSavedAlert: Bool = true
    
    private let userDefaults = UserDefaults.shared
    
    init(airlineSettings: AirlineSettingsStore) {
        self.airlineSettings = airlineSettings
        loadPreferences()
    }
    
    var logbookEmail: String {
        get { airlineSettings.settings.logbookEmail }
        set {
            airlineSettings.settings.logbookEmail = newValue
            airlineSettings.saveSettings()
        }
    }
    
    var receiptsEmail: String {
        get { airlineSettings.settings.receiptsEmail }
        set {
            airlineSettings.settings.receiptsEmail = newValue
            airlineSettings.saveSettings()
        }
    }
    
    var generalEmail: String {
        get { airlineSettings.settings.generalEmail }
        set {
            airlineSettings.settings.generalEmail = newValue
            airlineSettings.saveSettings()
        }
    }
    
    func loadPreferences() {
        autoSendReceipts = userDefaults.bool(forKey: "scannerAutoSendReceipts")
        promptForNewTrip = userDefaults.bool(forKey: "scannerPromptForNewTrip")
        autoCreateTripFolders = userDefaults.bool(forKey: "scannerAutoCreateTripFolders")
        showFileSavedAlert = userDefaults.bool(forKey: "scannerShowFileSavedAlert")
        
        if !userDefaults.bool(forKey: "scannerPreferencesInitialized") {
            autoSendReceipts = false
            promptForNewTrip = true
            autoCreateTripFolders = true
            showFileSavedAlert = true
            userDefaults.set(true, forKey: "scannerPreferencesInitialized")
        }
    }
    
    func savePreferences() {
        userDefaults.set(autoSendReceipts, forKey: "scannerAutoSendReceipts")
        userDefaults.set(promptForNewTrip, forKey: "scannerPromptForNewTrip")
        userDefaults.set(autoCreateTripFolders, forKey: "scannerAutoCreateTripFolders")
        userDefaults.set(showFileSavedAlert, forKey: "scannerShowFileSavedAlert")
        airlineSettings.saveSettings()
    }
}


// MARK: - OPTIMIZED Image Processing Extensions
extension UIImage {
    /// Optimize image based on document size and quality settings
    /// NEVER upscales images - only compresses or resizes down
    func optimizedForDocument(size: DocumentSize, quality: ScannerSettings.ImageQuality) -> UIImage? {
        let targetDimension: CGFloat
        switch size {
        case .receipt, .businessCard:
            targetDimension = 900  // Receipts for 240KB PDFs - very aggressive
        case .letter, .letterLandscape, .a4, .fullPage:
            targetDimension = quality.maxDimension
        case .legal:
            targetDimension = quality.maxDimension * 1.2
        }
        
        // Get current max dimension
        let currentMax = max(self.size.width, self.size.height)
        
        DebugLogger.log("Original size: \(self.size), max: \(currentMax), target: \(targetDimension)")
        
        // If image is already smaller than target, just compress it
        if currentMax <= targetDimension {
            DebugLogger.log("Image already small enough - compressing only")
            
            // Use extra compression for receipts/business cards
            let compressionQuality = (size == .receipt || size == .businessCard)
                ? min(quality.compressionQuality, 0.60)
                : quality.compressionQuality
            
            guard let jpegData = self.jpegData(compressionQuality: compressionQuality) else {
                return nil
            }
            return UIImage(data: jpegData)
        }
        
        // Image is too large - resize down then compress
        DebugLogger.log("Resizing image down to \(targetDimension)")
        guard let resized = self.resized(toMaxDimension: targetDimension) else {
            return nil
        }
        
        // Use extra compression for receipts/business cards
        let compressionQuality = (size == .receipt || size == .businessCard)
            ? min(quality.compressionQuality, 0.60)
            : quality.compressionQuality
        
        guard let jpegData = resized.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        
        return UIImage(data: jpegData)
    }
    
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let currentMax = max(size.width, size.height)
        
        // NEVER upscale
        guard currentMax > maxDimension else {
            DebugLogger.log("Resize called but image already small - returning original")
            return self
        }
        
        let scale = maxDimension / currentMax
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        DebugLogger.log("Resizing from \(size) to \(newSize)")
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - ScannedDocument
struct ScannedDocument: Identifiable, Codable, Equatable {
    let id: UUID
    let imagePath: String
    let pdfPath: String?
    let dateScanned: Date
    let documentType: ScanType
    var extractedText: String?
    var tags: [String] = []
    var filename: String
    var category: String
    var fileFormat: OutputFormat
    var tripId: UUID?
    var isActiveTrip: Bool = false
    var fileSizeBytes: Int64 = 0

    init(images: [UIImage],
         type: ScanType,
         format: OutputFormat = .pdf,
         extractedText: String? = nil,
         tripId: UUID? = nil,
         isActiveTrip: Bool = false,
         fileSizePreset: FileSizePreset = .small) {

        DebugLogger.log("=== SCANNED DOCUMENT CREATION START ===")

        self.id = UUID()
        self.dateScanned = Date()
        self.documentType = type
        self.extractedText = extractedText
        self.filename = Self.generateFilename(for: type, format: format, isActiveTrip: isActiveTrip)
        self.category = Self.categoryFor(type: type)
        self.tripId = tripId
        self.isActiveTrip = isActiveTrip
        self.fileFormat = format

        switch format {
        case .pdf:
            if let pdfURL = PDFGenerator.createPDFWithMetadata(
                from: images,
                filename: self.filename,
                title: self.filename,
                author: "ProPilot Scanner",
                subject: type.rawValue,
                fileSizePreset: fileSizePreset
            ) {
                self.pdfPath = pdfURL.path
                self.imagePath = ""
                self.fileSizeBytes = Self.getFileSize(at: pdfURL.path)
            } else {
                self.pdfPath = nil
                self.imagePath = Self.saveImageToDocuments(images.first ?? UIImage(), filename: self.filename, format: .jpeg)
                self.fileSizeBytes = Self.getFileSize(at: self.imagePath)
            }

        case .jpeg, .png:
            let image = images.first ?? UIImage()
            self.imagePath = Self.saveImageToDocuments(image, filename: self.filename, format: format)
            self.pdfPath = nil
            self.fileSizeBytes = Self.getFileSize(at: self.imagePath)
        }

        DebugLogger.log("=== SCANNED DOCUMENT CREATION END ===")
    }

    init(image: UIImage, type: ScanType, extractedText: String? = nil, tripId: UUID? = nil, isActiveTrip: Bool = false) {
        self.init(images: [image], type: type, format: .pdf, extractedText: extractedText, tripId: tripId, isActiveTrip: isActiveTrip)
    }

    private static func generateFilename(for type: ScanType, format: OutputFormat, isActiveTrip: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        let prefix = isActiveTrip ? "Trip_" : ""

        switch type {
        case .fuelReceipt: return "\(prefix)FuelReceipt_\(dateString)"
        case .logbookPage: return "\(prefix)LogbookPage_\(dateString)"
        case .maintenanceLog: return "\(prefix)MaintenanceLog_\(dateString)"
        case .general: return "\(prefix)Document_\(dateString)"
        }
    }

    private static func categoryFor(type: ScanType) -> String {
        switch type {
        case .fuelReceipt: return "Receipts"
        case .logbookPage: return "Logbook"
        case .maintenanceLog: return "Maintenance"
        case .general: return "General"
        }
    }

    private static func saveImageToDocuments(_ image: UIImage, filename: String, format: OutputFormat) -> String {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ""
        }

        let categoryDir = documentsDirectory.appendingPathComponent("Scanner/Images")
        FileManager.createDirectoryIfNeeded(at: categoryDir)
        let imageURL = categoryDir.appendingPathComponent("\(filename).\(format.fileExtension)")

        do {
            // Optimized compression - 0.70 gives ~40% smaller files with negligible quality loss
            let imageData = format == .jpeg ? image.jpegData(compressionQuality: 0.70) : image.pngData()
            guard let data = imageData else { return "" }
            try data.write(to: imageURL)
            DebugLogger.log("💾 Saved \(format.rawValue): \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            return imageURL.path
        } catch {
            DebugLogger.log("❌ Failed to save image: \(error)")
            return ""
        }
    }

    var uiImage: UIImage? {
        if fileFormat == .pdf, let pdfPath = pdfPath, !pdfPath.isEmpty {
            return extractImageFromPDF(path: pdfPath)
        } else if !imagePath.isEmpty {
            return UIImage(contentsOfFile: imagePath)
        }
        return nil
    }

    var pdfDocument: PDFDocument? {
        guard let pdfPath = pdfPath, !pdfPath.isEmpty else { return nil }
        return PDFDocument(url: URL(fileURLWithPath: pdfPath))
    }

    var fileURL: URL? {
        if fileFormat == .pdf, let pdfPath = pdfPath {
            return URL(fileURLWithPath: pdfPath)
        } else if !imagePath.isEmpty {
            return URL(fileURLWithPath: imagePath)
        }
        return nil
    }

    private func extractImageFromPDF(path: String) -> UIImage? {
        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: path)),
              let firstPage = pdfDocument.page(at: 0) else { return nil }

        let pageRect = firstPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        return renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private static func getFileSize(at path: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }

    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    func deleteFiles() {
        if !imagePath.isEmpty {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        if let pdfPath = pdfPath, !pdfPath.isEmpty {
            try? FileManager.default.removeItem(atPath: pdfPath)
        }
    }
}


// MARK: - PDF Generator
class PDFGenerator {
    /// Creates a highly compressed PDF optimized for email with configurable size presets
    static func createPDFWithMetadata(from images: [UIImage],
                                    filename: String,
                                    title: String? = nil,
                                    author: String? = nil,
                                    subject: String? = nil,
                                    fileSizePreset: FileSizePreset = .small) -> URL? {
        guard !images.isEmpty else { return nil }
        
        let documentsDirectory = FileManager.getDocumentsDirectory()
        let scannerDir = documentsDirectory.appendingPathComponent("Scanner")
        FileManager.createDirectoryIfNeeded(at: scannerDir)
        
        let pdfURL = scannerDir.appendingPathComponent("\(filename).pdf")
        
        let targetSizeKB = fileSizePreset.targetSizeKB
        
        // FIRST PASS: Try with preset compression
        let targetSizePerImageKB = (targetSizeKB - 20) / images.count  // Leave 20KB buffer for PDF overhead
        var compressedImages = images.compactMap {
            compressImageForPDF($0,
                              targetFileSizeKB: targetSizePerImageKB,
                              preset: fileSizePreset)
        }
        
        DebugLogger.log("📄 Creating \(fileSizePreset.rawValue) PDF from \(images.count) images (target: \(targetSizeKB)KB)")
        
        var pdfDocument = PDFDocument()
        for (index, image) in compressedImages.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        var attributes: [PDFDocumentAttribute: Any] = [:]
        if let title = title { attributes[.titleAttribute] = title }
        if let author = author { attributes[.authorAttribute] = author }
        if let subject = subject { attributes[.subjectAttribute] = subject }
        attributes[.creatorAttribute] = "ProPilot Scanner"
        attributes[.creationDateAttribute] = Date()
        
        pdfDocument.documentAttributes = attributes
        
        var success = pdfDocument.write(to: pdfURL)
        
        if success {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as? Int64) ?? 0
            let sizeKB = fileSize / 1024
            
            // SECOND PASS: If still too large, recompress more aggressively
            if sizeKB > targetSizeKB {
                DebugLogger.log("📄 PDF too large (\(sizeKB)KB), recompressing...")
                
                let aggressiveTarget = (targetSizeKB - 30) / images.count  // Even more aggressive
                compressedImages = images.compactMap {
                    compressImageForPDF($0,
                                      targetFileSizeKB: aggressiveTarget,
                                      preset: fileSizePreset,
                                      aggressive: true)
                }
                
                pdfDocument = PDFDocument()
                for (index, image) in compressedImages.enumerated() {
                    if let pdfPage = PDFPage(image: image) {
                        pdfDocument.insert(pdfPage, at: index)
                    }
                }
                pdfDocument.documentAttributes = attributes
                success = pdfDocument.write(to: pdfURL)
                
                let newSize = (try? FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as? Int64) ?? 0
                let newSizeKB = newSize / 1024
                DebugLogger.log("📄 PDF recompressed: \(newSizeKB)KB \(newSizeKB <= targetSizeKB ? "✅" : "⚠️ OVER TARGET")")
            } else {
                DebugLogger.log("📄 PDF created: \(sizeKB)KB ✅")
            }
        }
        
        return success ? pdfURL : nil
    }
    
    /// Aggressively compresses an image to fit within target file size
    private static func compressImageForPDF(_ image: UIImage,
                                           targetFileSizeKB: Int,
                                           preset: FileSizePreset,
                                           aggressive: Bool = false) -> UIImage? {
        // Step 1: Resize based on preset and aggressiveness
        let maxDimension: CGFloat = aggressive ? preset.maxDimension * 0.85 : preset.maxDimension
        let resizedImage: UIImage
        
        let currentMax = max(image.size.width, image.size.height)
        if currentMax > maxDimension {
            let scale = maxDimension / currentMax
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            resizedImage = image
        }
        
        // Step 2: Iteratively compress until we hit target size
        var compressionQuality: CGFloat = aggressive ? preset.compressionQuality * 0.8 : preset.compressionQuality
        var compressedData: Data?
        var attempts = 0
        let maxAttempts = 6
        
        while attempts < maxAttempts {
            compressedData = resizedImage.jpegData(compressionQuality: compressionQuality)
            
            if let data = compressedData {
                let sizeKB = data.count / 1024
                
                if sizeKB <= targetFileSizeKB || compressionQuality <= 0.15 {
                    // Success or minimum quality reached
                    DebugLogger.log("📸 Compressed image: \(sizeKB)KB @ \(Int(compressionQuality * 100))% quality")
                    break
                } else {
                    // Too large, reduce quality more aggressively
                    compressionQuality -= (aggressive ? 0.08 : 0.1)
                }
            }
            
            attempts += 1
        }
        
        guard let finalData = compressedData else { return nil }
        return UIImage(data: finalData)
    }
}

// MARK: - Image Enhancement
class ImageEnhancer {
    // Apply color mode conversion (grayscale or black & white)
    static func applyColorMode(image originalImage: UIImage, mode: ColorMode) -> UIImage {
        guard mode != .color else { return originalImage }
        guard let cgImage = originalImage.cgImage else { return originalImage }
        var ciImage = CIImage(cgImage: cgImage)

        switch mode {
        case .color:
            break // No conversion needed
            
        case .grayscale:
            if let bwFilter = CIFilter(name: "CIColorMonochrome") {
                bwFilter.setValue(ciImage, forKey: kCIInputImageKey)
                bwFilter.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
                bwFilter.setValue(1.0, forKey: "inputIntensity")
                if let output = bwFilter.outputImage { ciImage = output }
            }
            
        case .blackAndWhite:
            // First convert to grayscale
            if let bwFilter = CIFilter(name: "CIColorMonochrome") {
                bwFilter.setValue(ciImage, forKey: kCIInputImageKey)
                bwFilter.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")
                bwFilter.setValue(1.0, forKey: "inputIntensity")
                if let output = bwFilter.outputImage { ciImage = output }
            }
            
            // Then apply high contrast threshold
            if let thresholdFilter = CIFilter(name: "CIToneCurve") {
                thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
                thresholdFilter.setValue(CIVector(x: 0, y: 0.1), forKey: "inputPoint0")
                thresholdFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint1")
                thresholdFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
                thresholdFilter.setValue(CIVector(x: 1, y: 0.9), forKey: "inputPoint3")
                if let output = thresholdFilter.outputImage { ciImage = output }
            }
        }

        let context = CIContext(options: nil)
        guard let outputCgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return originalImage
        }

        return UIImage(cgImage: outputCgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }
    
    // Apply document enhancement (sharpening, contrast)
    static func applyEnhancement(image originalImage: UIImage) -> UIImage {
        guard let cgImage = originalImage.cgImage else { return originalImage }
        var ciImage = CIImage(cgImage: cgImage)

        if let enhancerFilter = CIFilter(name: "CIDocumentEnhancer") {
            enhancerFilter.setValue(ciImage, forKey: kCIInputImageKey)
            enhancerFilter.setValue(0.7, forKey: "inputAmount")
            if let enhancedImage = enhancerFilter.outputImage {
                ciImage = enhancedImage
            }
        }

        let context = CIContext(options: nil)
        guard let outputCgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return originalImage
        }

        return UIImage(cgImage: outputCgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }
    
    // Legacy method for backward compatibility
    static func enhance(image originalImage: UIImage, for colorMode: ColorMode) -> UIImage {
        let enhanced = applyEnhancement(image: originalImage)
        return applyColorMode(image: enhanced, mode: colorMode)
    }
}

// MARK: - OCR Processor
class OCRProcessor {
    static func performOCR(on image: UIImage, enabled: Bool) -> String? {
        guard enabled else { return nil }
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
}

// MARK: - Crop Coordinator (Manages crop state outside view hierarchy)
class CropCoordinator: ObservableObject {
    @Published var showingCropEditor = false
    @Published var imagesToCrop: [UIImage] = []
    @Published var currentCropIndex = 0
    @Published var croppedImages: [UIImage] = []
    var onCropComplete: (([UIImage]) -> Void)?
    
    func reset() {
        DebugLogger.log("🔄 Resetting CropCoordinator")
        showingCropEditor = false
        imagesToCrop = []
        currentCropIndex = 0
        croppedImages = []
        onCropComplete = nil
    }
    
    func startCropping(images: [UIImage], completion: @escaping ([UIImage]) -> Void) {
        DebugLogger.log("📸 CropCoordinator: Starting crop with \(images.count) images")
        self.imagesToCrop = images
        self.currentCropIndex = 0
        self.croppedImages = []
        self.onCropComplete = completion
        
        // Present crop editor
        DispatchQueue.main.async {
            self.showingCropEditor = true
            DebugLogger.log("📸 CropCoordinator: showingCropEditor = true")
        }
    }
    
    func cropCompleted(image: UIImage) {
        DebugLogger.log("📸 CropCoordinator: Cropped image \(currentCropIndex + 1) of \(imagesToCrop.count)")
        croppedImages.append(image)
        currentCropIndex += 1
        
        if currentCropIndex < imagesToCrop.count {
            DebugLogger.log("📸 CropCoordinator: Moving to next image")
        } else {
            DebugLogger.log("📸 CropCoordinator: All images cropped, calling completion")
            showingCropEditor = false
            onCropComplete?(croppedImages)
        }
    }
    
    func cropCancelled() {
        DebugLogger.log("📸 CropCoordinator: Crop cancelled, using original images")
        showingCropEditor = false
        onCropComplete?(imagesToCrop)
    }
}

// MARK: - Document Scanner View
struct DocumentScannerView: View {
    @ObservedObject var documentStore: TripDocumentManager
    @Binding var isPresented: Bool
    let scanType: ScanType
    let settings: ScannerSettings
    let preferences: ScannerPreferences
    let tripId: UUID?
    let tripNumber: String?  // ADDED: For organized trip folders
    let isActiveTrip: Bool
    let onError: (String) -> Void
    let onDocumentSaved: ((ScannedDocument) -> Void)?
    let onNeedsCrop: (([UIImage], @escaping ([UIImage]) -> Void) -> Void)?  // NEW: Callback for cropping
    
    @State private var cropCoordinator: ScannerRepresentable.Coordinator?
    
    var body: some View {
        ScannerRepresentable(
            documentStore: documentStore,
            isPresented: $isPresented,
            scanType: scanType,
            settings: settings,
            preferences: preferences,
            tripId: tripId,
            tripNumber: tripNumber,
            isActiveTrip: isActiveTrip,
            onError: onError,
            onDocumentSaved: onDocumentSaved,
            onNeedsCrop: onNeedsCrop,
            cropCoordinator: $cropCoordinator
        )
    }
}

// MARK: - Document Scanner With Crop (Wrapper that handles crop presentation)
struct DocumentScannerWithCrop: View {
    @ObservedObject var documentStore: TripDocumentManager
    @Binding var isPresented: Bool
    let scanType: ScanType
    let settings: ScannerSettings
    let preferences: ScannerPreferences
    let tripId: UUID?
    let tripNumber: String?
    let isActiveTrip: Bool
    let onError: (String) -> Void
    let onDocumentSaved: ((ScannedDocument) -> Void)?
    @ObservedObject var cropCoordinator: CropCoordinator  // ← Changed from @StateObject
    
    var body: some View {
        DocumentScannerView(
            documentStore: documentStore,
            isPresented: $isPresented,
            scanType: scanType,
            settings: settings,
            preferences: preferences,
            tripId: tripId,
            tripNumber: tripNumber,
            isActiveTrip: isActiveTrip,
            onError: onError,
            onDocumentSaved: onDocumentSaved,
            onNeedsCrop: { images, completion in
                DebugLogger.log("📸 onNeedsCrop callback triggered with \(images.count) images")
                cropCoordinator.startCropping(images: images, completion: completion)
            }
        )
    }
}

// MARK: - Scanner Representable (Internal)
struct ScannerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var documentStore: TripDocumentManager
    @Binding var isPresented: Bool
    let scanType: ScanType
    let settings: ScannerSettings
    let preferences: ScannerPreferences
    let tripId: UUID?
    let tripNumber: String?
    let isActiveTrip: Bool
    let onError: (String) -> Void
    let onDocumentSaved: ((ScannedDocument) -> Void)?
    let onNeedsCrop: (([UIImage], @escaping ([UIImage]) -> Void) -> Void)?
    
    @Binding var cropCoordinator: ScannerRepresentable.Coordinator?
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        
        // Set coordinator after view is created (avoid state modification during view update)
        DispatchQueue.main.async {
            self.cropCoordinator = context.coordinator
        }
        
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScannerRepresentable
        var processedImages: [(UIImage, String?)] = []
        var currentImageIndex = 0
        
        init(_ parent: ScannerRepresentable) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            
            DebugLogger.log("Scanner finished with \(scan.pageCount) pages")
            
            // CRITICAL: Dismiss camera FIRST to free resources
            controller.dismiss(animated: true) {
                self.processScannedImages(scan)
            }
        }
        
        private func processScannedImages(_ scan: VNDocumentCameraScan) {
            DispatchQueue.global(qos: .userInitiated).async {
                var processedImages: [(UIImage, String?)] = []
                
                for pageIndex in 0..<scan.pageCount {
                    autoreleasepool {
                        let scannedImage = scan.imageOfPage(at: pageIndex)
                        
                        // FIX: Prevent upscaling - only resize if image is too large
                        let optimizedImage = scannedImage.optimizedForDocument(
                            size: self.parent.settings.selectedDocumentSize,
                            quality: self.parent.settings.imageQuality
                        ) ?? scannedImage
                        
                        DebugLogger.log("Optimized from \(scannedImage.size) to \(optimizedImage.size)")
                        
                        var enhancedImage = optimizedImage
                        
                        // Apply color mode (always, regardless of enhancement toggle)
                        if self.parent.settings.colorMode != .color {
                            enhancedImage = ImageEnhancer.applyColorMode(
                                image: enhancedImage,
                                mode: self.parent.settings.colorMode
                            )
                            DebugLogger.log("Applied color mode: \(self.parent.settings.colorMode.rawValue)")
                        }
                        
                        // Apply document enhancement (optional)
                        if self.parent.settings.imageEnhancement {
                            enhancedImage = ImageEnhancer.applyEnhancement(image: enhancedImage)
                            DebugLogger.log("Applied document enhancement")
                        }
                        
                        // ✂️ AUTO SIDE CROPPING - DISABLED
                        // This was causing double-cropping because VisionKit already
                        // crops to document edges. Uncomment if you want percentage-based
                        // additional cropping on top of VisionKit's auto-crop.
                        //
                        // var finalImage = enhancedImage
                        // let cropSettings = UserDefaults.standard.documentCropSettings
                        // if cropSettings.isEnabled {
                        //     finalImage = DocumentCropProcessor.applyCropping(to: enhancedImage, settings: cropSettings)
                        //     DebugLogger.log("✂️ Applied side cropping to page \(pageIndex + 1)")
                        // }
                        
                        // Use enhanced image directly (VisionKit already cropped to document edges)
                        let finalImage = enhancedImage
                        
                        let extractedText = OCRProcessor.performOCR(
                            on: finalImage,
                            enabled: self.parent.settings.ocrEnabled
                        )
                        
                        processedImages.append((finalImage, extractedText))
                    }
                }
                
                DispatchQueue.main.async {
                    self.processedImages = processedImages
                    
                    DebugLogger.log("🔧 Crop Editor Enabled: \(self.parent.settings.enableCropEditor)")
                    DebugLogger.log("📄 Processed Images Count: \(processedImages.count)")
                    
                    if self.parent.settings.enableCropEditor && !processedImages.isEmpty,
                       let onNeedsCrop = self.parent.onNeedsCrop {
                        // Use callback to let parent handle crop editor presentation
                        DebugLogger.log("✅ Calling onNeedsCrop callback to present crop editor")
                        let images = processedImages.map { $0.0 }
                        onNeedsCrop(images) { croppedImages in
                            // Replace processed images with cropped versions
                            for (index, croppedImage) in croppedImages.enumerated() {
                                if index < self.processedImages.count {
                                    let (_, text) = self.processedImages[index]
                                    self.processedImages[index] = (croppedImage, text)
                                }
                            }
                            // Save document with cropped images
                            self.createAndSaveDocument(from: self.processedImages)
                        }
                    } else {
                        // Skip manual cropping, save directly
                        DebugLogger.log("⏭️ Skipping manual crop editor, saving directly")
                        self.createAndSaveDocument(from: processedImages)
                    }
                }
            }
        }
        
        private func createAndSaveDocument(from processedImages: [(UIImage, String?)]) {
            let allImages = processedImages.map { $0.0 }
            let combinedText = processedImages.compactMap { $0.1 }.joined(separator: "\n")
            
            let document = ScannedDocument(
                images: allImages,
                type: self.parent.scanType,
                format: allImages.count > 1 ? .pdf : self.parent.settings.outputFormat,
                extractedText: combinedText.isEmpty ? nil : combinedText,
                tripId: self.parent.tripId,
                isActiveTrip: self.parent.isActiveTrip,
                fileSizePreset: self.parent.settings.fileSizePreset
            )
            
            // Add document with trip number for organized storage
            if let tripNumber = self.parent.tripNumber {
                // Save to organized trip folder structure
                if let savedDoc = self.parent.documentStore.addDocument(document, tripNumber: tripNumber) {
                    DebugLogger.log("✅ Document saved to Trip #\(tripNumber) folder: \(savedDoc.fileName)")
                } else {
                    DebugLogger.log("❌ Failed to save document to Trip #\(tripNumber) folder")
                }
            } else {
                // No trip number - save to general scanner folder (legacy behavior)
                // The ScannedDocument already saved the file in its init
                DebugLogger.log("⚠️ Document saved to general scanner folder (no trip association)")
                
                
                
            }
            
            // Execute callback or dismiss
            if let callback = self.parent.onDocumentSaved {
                callback(document)
            } else {
                self.parent.isPresented = false
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.parent.isPresented = false
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.parent.onError("Scanner error: \(error.localizedDescription)")
                self.parent.isPresented = false
            }
        }
    }
}
// MARK: - Scanner Settings View
struct ScannerSettingsView: View {
    @ObservedObject var settings: ScannerSettings
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("File Size")) {
                    Picker("PDF Size Target", selection: $settings.fileSizePreset) {
                        ForEach(FileSizePreset.allCases) { preset in
                            VStack(alignment: .leading) {
                                Text(preset.rawValue)
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(preset)
                        }
                    }
                }
                
                Section(header: Text("Default Scan Settings")) {
                    Picker("Default Document Size", selection: $settings.selectedDocumentSize) {
                        ForEach(DocumentSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    
                    Picker("Output Format", selection: $settings.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            HStack {
                                Image(systemName: format.icon)
                                Text(format.rawValue)
                            }
                            .tag(format)
                        }
                    }
                    
                    Picker("Color Mode", selection: $settings.colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section(header: Text("Processing")) {
                    Picker("Processing Speed", selection: $settings.imageQuality) {
                        ForEach(ScannerSettings.ImageQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    Toggle("Image Enhancement", isOn: $settings.imageEnhancement)
                    Toggle("Enable Crop Editor", isOn: $settings.enableCropEditor)
                    Toggle("OCR Text Recognition", isOn: $settings.ocrEnabled)
                    
                    // ✂️ SIDE CROPPING BUTTON - REMOVED
                    // Auto side cropping was disabled because VisionKit already
                    // crops to document edges. The manual crop editor (above toggle)
                    // still allows fine-tuning after scanning.
                }
                
                Section(header: Text("Camera")) {
                    Toggle("Flash by Default", isOn: $settings.flashlightEnabled)
                }
                
                Section(header: Text("Email")) {
                    Toggle("Auto-send after scanning", isOn: $settings.autoSendEmail)
                }
            }
            .navigationTitle("Scanner Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            // Note: Side cropping settings sheet removed - feature disabled
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Simple Document Completion View
struct SimpleDocumentCompletionView: View {
    let document: ScannedDocument
    let preferences: ScannerPreferences
    @Binding var isPresented: Bool
    
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentGreen)
                    
                    VStack(spacing: 8) {
                        Text("Document Saved")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text(document.filename)
                            .font(.headline)
                            .foregroundColor(LogbookTheme.textSecondary)
                        
                        Text("\(document.fileFormat.rawValue) • \(document.formattedFileSize)")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.textTertiary)
                    }
                    
                    if let image = document.uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    }
                    
                    VStack(spacing: 12) {
                        Button("Share Document") {
                            showingShareSheet = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(12)
                        
                        Button("Done") {
                            isPresented = false
                        }
                        .font(.headline)
                        .foregroundColor(LogbookTheme.accentBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LogbookTheme.accentBlue, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = document.fileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
}

// MARK: - Enhanced Scan Button
struct EnhancedScanButton: View {
    let title: String
    let icon: String
    let color: Color
    let destinationEmail: String
    let scanType: ScanType
    let settings: ScannerSettings
    let onConfigured: () -> Void
    @State private var showingConfig = false
    
    var body: some View {
        Button(action: { showingConfig = true }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if !destinationEmail.isEmpty {
                    Text("→ \(destinationEmail)")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingConfig) {
            ScannerConfigurationView(
                settings: settings,
                scanType: scanType,
                onStartScan: {
                    showingConfig = false
                    onConfigured()
                }
            )
        }
    }
}

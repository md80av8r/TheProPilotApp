//
//  EnhancedTripDocumentListView.swift
//  ProPilotApp
//
//  Enhanced document list with swipe-to-delete and bulk operations for TripDocument type
//

import SwiftUI
import PDFKit

// MARK: - PDF Viewer using PDFKit
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        
        // Load the PDF document
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update document if URL changes
        if pdfView.document?.documentURL != url {
            if let document = PDFDocument(url: url) {
                pdfView.document = document
            }
        }
    }
}

// MARK: - Smart PDF Thumbnail (rotates landscape to portrait like PDF Expert)
struct SmartPDFThumbnail: View {
    let url: URL?
    let maxHeight: CGFloat
    
    @State private var thumbnailImage: UIImage?
    
    init(url: URL?, maxHeight: CGFloat = 180) {
        self.url = url
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .frame(maxWidth: .infinity)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(0.707, contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let url = url else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(url: url),
                  let page = document.page(at: 0) else { return }
            
            let pageRect = page.bounds(for: .mediaBox)
            let isLandscape = pageRect.width > pageRect.height
            
            // Generate thumbnail
            let scale: CGFloat = 2.0
            let thumbnailSize = CGSize(
                width: min(pageRect.width, 300) * scale,
                height: min(pageRect.height, 300) * scale
            )
            
            var thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
            
            // Rotate landscape PDFs 90° clockwise to display as portrait
            if isLandscape {
                thumbnail = rotateImage(thumbnail, byDegrees: 90) ?? thumbnail
            }
            
            DispatchQueue.main.async {
                self.thumbnailImage = thumbnail
            }
        }
    }
    
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

// MARK: - Enhanced Trip Document List with Delete
struct TripDocumentListView: View {
    let trip: Trip
    @ObservedObject var documentStore: TripDocumentManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var documents: [TripDocument]
    @State private var selectedDocument: TripDocument?
    @State private var documentToDelete: TripDocument?
    @State private var showingDeleteAlert = false
    @State private var showingDeletionToast = false
    @State private var deletionMessage = ""
    @State private var isDeletionError = false
    @State private var isEditMode = false
    @State private var selectedDocuments: Set<UUID> = []
    
    // Scanner Pro features
    @State private var viewMode: ViewMode = .list
    @State private var searchText = ""
    @State private var selectedCategory: TripDocumentType? = nil
    @State private var showingShareSheet = false
    @State private var itemsToShare: [Any] = []
    
    enum ViewMode {
        case grid, list
    }
    
    init(trip: Trip, documents: [TripDocument], documentStore: TripDocumentManager) {
        self.trip = trip
        self.documentStore = documentStore
        _documents = State(initialValue: documents)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category Filter Bar
                    if !categories.isEmpty && !isEditMode {
                        categoryFilterBar
                    }
                    
                    // Toolbar
                    if !documents.isEmpty {
                        toolbarView
                    }
                    
                    // Document List/Grid
                    if filteredDocuments.isEmpty {
                        emptyStateView
                    } else if viewMode == .grid {
                        documentGridView
                    } else {
                        documentListView
                    }
                }
                
                // Selection Toolbar (Bottom)
                if isEditMode && !selectedDocuments.isEmpty {
                    selectionToolbar
                }
                
                // Toast notification
                if showingDeletionToast {
                    VStack {
                        Spacer()
                        DeletionResultToast(message: deletionMessage, isError: isDeletionError)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 20)
                    }
                    .animation(.spring(), value: showingDeletionToast)
                }
            }
            .navigationTitle(isEditMode ? "\(selectedDocuments.count) Selected" : "Trip \(trip.tripNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditMode ? "Cancel" : "Back") {
                        if isEditMode {
                            isEditMode = false
                            selectedDocuments.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                
                if isEditMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(selectedDocuments.count == filteredDocuments.count ? "Deselect All" : "Select All") {
                            if selectedDocuments.count == filteredDocuments.count {
                                selectedDocuments.removeAll()
                            } else {
                                selectedDocuments = Set(filteredDocuments.map { $0.id })
                            }
                        }
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .alert(isPresented: $showingDeleteAlert) {
                createDeleteAlert()
            }
            .searchable(text: $searchText, prompt: "Search documents")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: itemsToShare)
        }
        .sheet(item: $selectedDocument) { document in
            NavigationView {
                EnhancedTripDocumentDetailView(
                    document: document,
                    onDelete: { deletedDoc in
                        performDeletion(deletedDoc)
                    }
                )
                .navigationTitle(document.fileName)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Toolbar
    private var toolbarView: some View {
        HStack {
            if isEditMode {
                Spacer()
                
                Text("\(selectedDocuments.count) Selected")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            } else {
                Spacer()
                
                Text("\(filteredDocuments.count) Document\(filteredDocuments.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                
                Spacer()
                
                // View Mode Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = viewMode == .grid ? .list : .grid
                    }
                }) {
                    Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                .padding(.trailing, 8)
                
                Button(action: {
                    isEditMode = true
                }) {
                    Image(systemName: "checklist")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(LogbookTheme.navyLight)
    }
    
    // MARK: - Document List
    private var documentListView: some View {
        List {
            ForEach(filteredDocuments) { document in
                if isEditMode {
                    documentRowWithSelection(document)
                } else {
                    documentRowWithSwipe(document)
                }
            }
        }
        .listStyle(.plain)
        .background(LogbookTheme.navy)
    }
    
    // MARK: - Document Row (Normal Mode with Swipe)
    private func documentRowWithSwipe(_ document: TripDocument) -> some View {
        Button(action: {
            selectedDocument = document
        }) {
            EnhancedDocumentListRow(document: document)
        }
        .buttonStyle(.plain)
        .listRowBackground(LogbookTheme.navyLight)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                documentToDelete = document
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                shareDocument(document)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .onLongPressGesture {
            handleLongPress(document)
        }
        // NOTE: Sheet moved to main body to prevent multiple presentations
    }
    
    // MARK: - Document Row (Edit Mode with Checkboxes)
    private func documentRowWithSelection(_ document: TripDocument) -> some View {
        HStack {
            Image(systemName: selectedDocuments.contains(document.id) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(selectedDocuments.contains(document.id) ? LogbookTheme.accentBlue : .gray)
                .imageScale(.large)
            
            EnhancedDocumentListRow(document: document)
        }
        .listRowBackground(LogbookTheme.navyLight)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(document)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Documents" : "No Results")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? "Scanned documents for this trip will appear here" : "Try a different search term or filter")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    private func toggleSelection(_ document: TripDocument) {
        if selectedDocuments.contains(document.id) {
            selectedDocuments.remove(document.id)
        } else {
            selectedDocuments.insert(document.id)
        }
    }
    
    private func createDeleteAlert() -> Alert {
        if let doc = documentToDelete {
            return Alert(
                title: Text("Delete Document?"),
                message: Text("Are you sure you want to delete \"\(doc.fileName)\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    performDeletion(doc)
                },
                secondaryButton: .cancel()
            )
        } else if !selectedDocuments.isEmpty {
            let count = selectedDocuments.count
            let size = formatBytes(calculateTotalSize())
            return Alert(
                title: Text("Delete \(count) Documents?"),
                message: Text("This will permanently delete \(count) document(s) (\(size)). This action cannot be undone."),
                primaryButton: .destructive(Text("Delete All")) {
                    performBulkDeletion()
                },
                secondaryButton: .cancel()
            )
        }
        return Alert(title: Text("Error"))
    }
    
    private func performDeletion(_ document: TripDocument) {
        TripDocumentDeletionManager.shared.deleteDocument(document) { success, error in
            if success {
                // Remove from documentStore
                documentStore.deleteDocument(document)
                
                // Update local array
                withAnimation {
                    documents.removeAll { $0.id == document.id }
                }
                showToast("Document deleted", isError: false)
            } else {
                showToast(error ?? "Failed to delete document", isError: true)
            }
            documentToDelete = nil
        }
    }
    
    private func performBulkDeletion() {
        let docsToDelete = documents.filter { selectedDocuments.contains($0.id) }
        
        TripDocumentDeletionManager.shared.deleteDocuments(docsToDelete) { successCount, errors in
            // Remove from documentStore
            for doc in docsToDelete {
                documentStore.deleteDocument(doc)
            }
            
            // Update local array
            withAnimation {
                documents.removeAll { selectedDocuments.contains($0.id) }
            }
            
            selectedDocuments.removeAll()
            isEditMode = false
            
            if errors.isEmpty {
                showToast("Deleted \(successCount) document\(successCount == 1 ? "" : "s")", isError: false)
            } else {
                showToast("Deleted \(successCount), \(errors.count) failed", isError: true)
            }
        }
    }
    
    private func calculateTotalSize() -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        for document in documents.filter({ selectedDocuments.contains($0.id) }) {
            guard let fileURL = document.fileURL else { continue }
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func showToast(_ message: String, isError: Bool) {
        deletionMessage = message
        isDeletionError = isError
        showingDeletionToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showingDeletionToast = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - New Scanner Pro Features
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryFilterChip(
                    title: "All",
                    icon: "doc.on.doc",
                    isSelected: selectedCategory == nil,
                    count: documents.count
                ) {
                    selectedCategory = nil
                }
                
                ForEach(categories, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        count: documents.filter { $0.documentType == category }.count
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(LogbookTheme.navyLight)
    }
    
    private var documentGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredDocuments) { document in
                    DocumentGridCard(
                        document: document,
                        isSelected: selectedDocuments.contains(document.id),
                        isEditMode: isEditMode
                    ) {
                        if isEditMode {
                            toggleSelection(document)
                        } else {
                            selectedDocument = document
                        }
                    } onLongPress: {
                        handleLongPress(document)
                    }
                }
            }
            .padding()
            .padding(.bottom, isEditMode ? 80 : 0)
        }
    }
    
    private var selectionToolbar: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 20) {
                SelectionToolbarButton(icon: "square.and.arrow.up", title: "Share") {
                    prepareShare()
                }
                
                SelectionToolbarButton(icon: "doc.on.doc", title: "Merge") {
                    // TODO: Implement merge
                }
                .opacity(selectedDocuments.count < 2 ? 0.5 : 1.0)
                .disabled(selectedDocuments.count < 2)
                
                SelectionToolbarButton(icon: "trash", title: "Delete", color: .red) {
                    showingDeleteAlert = true
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LogbookTheme.navyLight)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
            )
            .padding()
        }
    }
    
    private var filteredDocuments: [TripDocument] {
        var docs = documents
        
        // Apply category filter
        if let category = selectedCategory {
            docs = docs.filter { $0.documentType == category }
        }
        
        // Apply search
        if !searchText.isEmpty {
            docs = docs.filter { doc in
                doc.fileName.localizedCaseInsensitiveContains(searchText) ||
                doc.documentType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return docs.sorted { $0.createdDate > $1.createdDate }
    }
    
    private var categories: [TripDocumentType] {
        let uniqueCategories = Set(documents.map { $0.documentType })
        return Array(uniqueCategories).sorted { $0.rawValue < $1.rawValue }
    }
    
    private func handleLongPress(_ document: TripDocument) {
        withAnimation {
            isEditMode = true
            selectedDocuments.insert(document.id)
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func shareDocument(_ document: TripDocument) {
        if let url = document.fileURL {
            itemsToShare = [url]
            showingShareSheet = true
        }
    }
    
    private func prepareShare() {
        let selectedDocs = filteredDocuments.filter { selectedDocuments.contains($0.id) }
        itemsToShare = selectedDocs.compactMap { $0.fileURL }
        showingShareSheet = true
    }
}

// MARK: - New Supporting Views

struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? LogbookTheme.accentBlue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
}

struct DocumentGridCard: View {
    let document: TripDocument
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail - respects natural PDF aspect ratio
                ZStack(alignment: .topTrailing) {
                    SmartPDFThumbnail(url: document.fileURL, maxHeight: 160)
                    
                    if isEditMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.fileName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: document.documentType.icon)
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textSecondary)
                        
                        Text(document.documentType.rawValue)
                            .font(.caption2)
                            .foregroundColor(LogbookTheme.textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                .padding(8)
            }
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPress()
        }
    }
}

struct SelectionToolbarButton: View {
    let icon: String
    let title: String
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(color)
        }
    }
}

// MARK: - Enhanced Document List Row
struct EnhancedDocumentListRow: View {
    let document: TripDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Document thumbnail
            PDFThumbnailView(
                fileURL: document.fileURL,
                size: CGSize(width: 60, height: 80)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: iconForDocumentType(document.documentType))
                        .font(.caption2)
                        .foregroundColor(colorForDocumentType(document.documentType))
                    
                    Text(document.documentType.rawValue)
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text("•")
                        .foregroundColor(LogbookTheme.textTertiary)
                    
                    Text(document.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textTertiary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(LogbookTheme.textTertiary)
        }
        .padding(.vertical, 8)
    }
    
    private func iconForDocumentType(_ type: TripDocumentType) -> String {
        return type.icon
    }
    
    private func colorForDocumentType(_ type: TripDocumentType) -> Color {
        switch type {
        case .fuelReceipt:
            return LogbookTheme.accentGreen
        case .customsGendec:
            return LogbookTheme.accentBlue
        case .groundHandler:
            return LogbookTheme.accentOrange
        case .shipper:
            return .purple
        case .reweighForm:
            return .cyan
        case .loadManifest:
            return LogbookTheme.accentBlue
        case .weatherBriefing:
            return .yellow
        case .logPage:
            return .indigo  // Or whatever color you prefer
        case .other:
            return LogbookTheme.textSecondary
        }
    }
}

// MARK: - Enhanced Trip Document Detail View
struct EnhancedTripDocumentDetailView: View {
    let document: TripDocument
    let onDelete: (TripDocument) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Full PDF Viewer - takes most of the screen
            if let fileURL = document.fileURL {
                PDFKitView(url: fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                // Fallback if no URL
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Unable to load document")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Bottom info panel
            VStack(spacing: 12) {
                // Document details
                VStack(alignment: .leading, spacing: 8) {
                    detailRow(label: "Filename", value: document.fileName)
                    detailRow(label: "Type", value: document.documentType.rawValue)
                    
                    HStack {
                        detailRow(label: "Trip", value: document.tripNumber)
                        Spacer()
                        if let fileSize = getFileSize() {
                            Text(fileSize)
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Share Button
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share Document", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(LogbookTheme.navyLight)
        }
        .background(LogbookTheme.navy)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Document?"),
                message: Text("Are you sure you want to delete \"\(document.fileName)\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(document)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = document.fileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
    }
    
    private func getFileSize() -> String? {
        guard let fileURL = document.fileURL else { return nil }
        let fileManager = FileManager.default
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }
        return nil
    }
}

// MARK: - Trip Document Deletion Manager
class TripDocumentDeletionManager {
    static let shared = TripDocumentDeletionManager()
    
    private init() {}
    
    func deleteDocument(_ document: TripDocument, completion: @escaping (Bool, String?) -> Void) {
        guard let fileURL = document.fileURL else {
            DispatchQueue.main.async {
                completion(false, "Document file path not found")
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    DispatchQueue.main.async {
                        completion(false, "File does not exist")
                    }
                    return
                }
                
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
    
    func deleteDocuments(_ documents: [TripDocument], completion: @escaping (Int, [String]) -> Void) {
        var successCount = 0
        var errors: [String] = []
        let group = DispatchGroup()
        
        for document in documents {
            group.enter()
            deleteDocument(document) { success, error in
                if success {
                    successCount += 1
                } else if let error = error {
                    errors.append("\(document.fileName): \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(successCount, errors)
        }
    }
}

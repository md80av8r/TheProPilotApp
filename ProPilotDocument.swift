//
//  ProPilotDocument.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//


// DocumentsView.swift - File Explorer with PDF Import for ProPilot
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Document Model
struct ProPilotDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var filename: String
    var fileURL: URL
    var dateImported: Date
    var fileSize: Int64
    var documentType: DocumentType
    var tags: [String] = []
    
    enum DocumentType: String, Codable, CaseIterable {
        case pdf = "PDF"
        case image = "Image"
        case text = "Text"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .image: return "photo"
            case .text: return "doc.text"
            case .other: return "doc"
            }
        }
        
        var color: Color {
            switch self {
            case .pdf: return .red
            case .image: return .blue
            case .text: return .green
            case .other: return .gray
            }
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Documents Store
class DocumentsStore: ObservableObject {
    @Published var documents: [ProPilotDocument] = []
    
    private let documentsDirectory: URL = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") else {
            fatalError("Unable to access App Group container")
        }
        let docsDir = container.appendingPathComponent("Documents")
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        return docsDir
    }()
    
    private let metadataURL: URL = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.propilot.app") else {
            fatalError("Unable to access App Group container")
        }
        return container.appendingPathComponent("documents_metadata.json")
    }()
    
    init() {
        load()
    }
    
    func load() {
        do {
            let data = try Data(contentsOf: metadataURL)
            documents = try JSONDecoder().decode([ProPilotDocument].self, from: data)
            print("📁 Loaded \(documents.count) documents")
        } catch {
            print("Failed to load documents metadata: \(error)")
            documents = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: metadataURL)
            print("📁 Saved \(documents.count) documents")
        } catch {
            print("Failed to save documents: \(error)")
        }
    }
    
    func importDocument(from sourceURL: URL) throws -> ProPilotDocument {
        let filename = sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(filename)
        
        // Copy file to documents directory
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Determine document type
        let docType = determineDocumentType(for: destinationURL)
        
        let document = ProPilotDocument(
            filename: filename,
            fileURL: destinationURL,
            dateImported: Date(),
            fileSize: fileSize,
            documentType: docType
        )
        
        documents.insert(document, at: 0)
        save()
        
        return document
    }
    
    func deleteDocument(_ document: ProPilotDocument) {
        // Remove file
        try? FileManager.default.removeItem(at: document.fileURL)
        
        // Remove from list
        documents.removeAll { $0.id == document.id }
        save()
    }
    
    func updateTags(_ document: ProPilotDocument, tags: [String]) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].tags = tags
            save()
        }
    }
    
    private func determineDocumentType(for url: URL) -> ProPilotDocument.DocumentType {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "gif", "heic":
            return .image
        case "txt", "rtf", "doc", "docx":
            return .text
        default:
            return .other
        }
    }
}

// MARK: - Main Documents View
struct DocumentsView: View {
    @StateObject private var documentsStore = DocumentsStore()
    @State private var showingFilePicker = false
    @State private var selectedDocument: ProPilotDocument?
    @State private var showingDocumentDetail = false
    @State private var searchText = ""
    @State private var selectedFilter: ProPilotDocument.DocumentType?
    @State private var sortOption: SortOption = .dateNewest
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case nameAZ = "Name (A-Z)"
        case nameZA = "Name (Z-A)"
        case sizeLargest = "Size (Largest)"
        case sizeSmallest = "Size (Smallest)"
    }
    
    private var filteredAndSortedDocuments: [ProPilotDocument] {
        var result = documentsStore.documents
        
        // Filter by type
        if let filter = selectedFilter {
            result = result.filter { $0.documentType == filter }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.filename.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort
        switch sortOption {
        case .dateNewest:
            result.sort { $0.dateImported > $1.dateImported }
        case .dateOldest:
            result.sort { $0.dateImported < $1.dateImported }
        case .nameAZ:
            result.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
        case .nameZA:
            result.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedDescending }
        case .sizeLargest:
            result.sort { $0.fileSize > $1.fileSize }
        case .sizeSmallest:
            result.sort { $0.fileSize < $1.fileSize }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and sort bar
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search documents...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(LogbookTheme.fieldBackground)
                    .cornerRadius(10)
                    
                    HStack {
                        Menu {
                            Button("All Documents") {
                                selectedFilter = nil
                            }
                            ForEach(ProPilotDocument.DocumentType.allCases, id: \.self) { type in
                                Button(action: { selectedFilter = type }) {
                                    Label(type.rawValue, systemImage: type.icon)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(selectedFilter?.rawValue ?? "All")
                                    .font(.subheadline)
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    sortOption = option
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortOption.rawValue)
                                    .font(.subheadline)
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(LogbookTheme.fieldBackground)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Document count
                HStack {
                    Text("\(filteredAndSortedDocuments.count) document\(filteredAndSortedDocuments.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if filteredAndSortedDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentsList
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(documentsStore: documentsStore)
            }
            .sheet(item: $selectedDocument) { document in
                DocumentDetailView(document: document, documentsStore: documentsStore)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Documents" : "No Results")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? "Tap + to import your first document" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentsList: some View {
        List {
            ForEach(filteredAndSortedDocuments) { document in
                DocumentRowView(document: document)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDocument = document
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                documentsStore.deleteDocument(document)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            shareDocument(document)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
            }
        }
        .listStyle(PlainListStyle())
        .background(LogbookTheme.navy)
        .scrollContentBackground(.hidden)
    }
    
    private func shareDocument(_ document: ProPilotDocument) {
        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Document Row
struct DocumentRowView: View {
    let document: ProPilotDocument
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.documentType.icon)
                .font(.title2)
                .foregroundColor(document.documentType.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.filename)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(document.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(document.dateImported.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if !document.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(document.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(LogbookTheme.accentBlue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LogbookTheme.accentBlue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var documentsStore: DocumentsStore
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .text, .item])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // CRITICAL: Start accessing security-scoped resource for iCloud files
                let accessing = url.startAccessingSecurityScopedResource()
                
                defer {
                    // Always stop accessing when done
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    _ = try parent.documentsStore.importDocument(from: url)
                    print("📁 Imported: \(url.lastPathComponent)")
                } catch {
                    print("❌ Failed to import document: \(error)")
                }
            }
            parent.dismiss()
        }
    }
}

// MARK: - Document Detail View
struct DocumentDetailView: View {
    let document: ProPilotDocument
    @ObservedObject var documentsStore: DocumentsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingTagEditor = false
    @State private var tags: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Document icon and info
                    VStack(spacing: 12) {
                        Image(systemName: document.documentType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(document.documentType.color)
                        
                        Text(document.filename)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Document details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(label: "Type", value: document.documentType.rawValue)
                        DetailRow(label: "Size", value: document.formattedFileSize)
                        DetailRow(label: "Imported", value: document.dateImported.formatted(date: .long, time: .shortened))
                        DetailRow(label: "Location", value: document.fileURL.lastPathComponent)
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Tags section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: { showingTagEditor = true }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                        }
                        
                        if tags.isEmpty {
                            Text("No tags")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(tag: tag) {
                                        removeTag(tag)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // PDF preview for PDF files
                    if document.documentType == .pdf {
                        PDFPreviewView(url: document.fileURL)
                            .frame(height: 400)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { shareDocument() }) {
                            Label("Share Document", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LogbookTheme.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: { openDocument() }) {
                            Label("Open in Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LogbookTheme.accentGreen)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
            .onAppear {
                tags = document.tags
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorView(tags: $tags, onSave: {
                    documentsStore.updateTags(document, tags: tags)
                })
            }
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        documentsStore.updateTags(document, tags: tags)
    }
    
    private func shareDocument() {
        let activityVC = UIActivityViewController(
            activityItems: [document.fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func openDocument() {
        // Open in system Files app
        UIApplication.shared.open(document.fileURL)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(LogbookTheme.accentBlue)
        .cornerRadius(12)
    }
}

// MARK: - PDF Preview
struct PDFPreviewView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(LogbookTheme.fieldBackground)
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Tag Editor
struct TagEditorView: View {
    @Binding var tags: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Add tag field
                HStack {
                    TextField("New tag...", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !tags.contains(trimmed) {
                            tags.append(trimmed)
                            newTag = ""
                        }
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                // Current tags
                List {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                    .onDelete { indexSet in
                        tags.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(PlainListStyle())
                .background(LogbookTheme.navy)
                .scrollContentBackground(.hidden)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

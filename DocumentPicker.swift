// Fixed File Import System - No naming conflicts or permission issues
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Safe File Import Picker (renamed to avoid conflicts)
struct SafeFileImportPicker: UIViewControllerRepresentable {
    let onDocumentPickedWithContent: (String, String) -> Void  // Changed to content, filename
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.commaSeparatedText,
            UTType.text,
            UTType.plainText,
            UTType.data,
            UTType.item // Fallback for any file type
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SafeFileImportPicker
        
        init(_ parent: SafeFileImportPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onError("No file selected")
                return
            }
            
            // Start accessing the security-scoped resource
            let accessGranted = url.startAccessingSecurityScopedResource()
            
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Read the file content IMMEDIATELY while we have access
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let filename = url.lastPathComponent
                
                // Call the updated callback with content directly
                DispatchQueue.main.async {
                    self.parent.onDocumentPickedWithContent(content, filename)
                }
                
            } catch {
                parent.onError("Failed to read file: \(error.localizedDescription)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled - no error needed
        }
    }
}

// MARK: - Simple Import Button View
struct SimpleFileImportView: View {
    @State private var showingFilePicker = false
    @State private var importStatus = ""
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onFileSelected: (String, String) -> Void // (content, filename)
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                showingFilePicker = true
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text("Select File to Import")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("CSV, TXT, and other text files")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(LogbookTheme.navyLight)
                .cornerRadius(16)
            }
            .disabled(isImporting)
            
            if !importStatus.isEmpty {
                HStack {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(importStatus)
                        .font(.subheadline)
                        .foregroundColor(isImporting ? LogbookTheme.accentBlue : LogbookTheme.accentGreen)
                }
                .padding()
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            SafeFileImportPicker(
                onDocumentPickedWithContent: { content, filename in
                    // Content is already read - no permission issues
                    importStatus = "Successfully imported: \(filename)"
                    isImporting = false
                    onFileSelected(content, filename)
                },
                onError: { error in
                    errorMessage = error
                    showingError = true
                }
            )
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Quick Import Integration for Scanner
extension DocumentScannerView {
    var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Documents")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                // Show import view
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                    Text("Import from Files")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.accentOrange)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Usage Example for Logbook Import
struct LogbookFileImportView: View {
    @ObservedObject var logbookStore: ComprehensiveLogbookStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: LogbookFormat = .foreFlight
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                formatSelectionView
                importView
                Spacer()
            }
            .padding()
            .background(LogbookTheme.navy)
            .navigationTitle("Import Logbook")
            .navigationBarItems(trailing: doneButton)
        }
    }
    
    private var headerSection: some View {
        Text("Import Logbook Data")
            .font(.title.bold())
            .foregroundColor(.white)
    }
    
    private var formatSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Format:")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(LogbookFormat.allCases, id: \.self) { format in
                formatSelectionButton(for: format)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private func formatSelectionButton(for format: LogbookFormat) -> some View {
        Button(action: {
            selectedFormat = format
        }) {
            HStack {
                formatIcon(for: format)
                formatText(for: format)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private func formatIcon(for format: LogbookFormat) -> some View {
        Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
            .foregroundColor(selectedFormat == format ? LogbookTheme.accentBlue : .gray)
    }
    
    private func formatText(for format: LogbookFormat) -> some View {
        Text(format.displayName)
            .foregroundColor(.white)
    }
    
    private var importView: some View {
        SimpleFileImportView { content, filename in
            logbookStore.importFromCSV(content, format: selectedFormat)
        }
    }
    
    private var doneButton: some View {
        Button("Done") { dismiss() }
    }
}

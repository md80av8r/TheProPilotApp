//
//  CompleteExcelViewer.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 8/16/25.
//


//
//  CompleteExcelViewer.swift
//  ProPilotApp
//
//  Complete Excel viewer with web viewing, offline storage, and native parsing
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - Main Excel Viewer

struct CompleteExcelViewer: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var parser = ExcelDataParser()
    
    @State private var fileURL = ""
    @State private var savedFiles: [SavedExcelFile] = []
    @State private var viewMode: MainViewMode = .input
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var selectedFile: SavedExcelFile?
    @State private var showingWebView = false
    @State private var showingNativeView = false
    
    enum MainViewMode: String, CaseIterable {
        case input = "Add Files"
        case library = "My Files"
        
        var icon: String {
            switch self {
            case .input: return "plus.circle"
            case .library: return "folder"
            }
        }
    }
    
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var cacheDirectory: URL {
        documentsDirectory.appendingPathComponent("ExcelFiles", isDirectory: true)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                // Mode Picker
                Picker("Mode", selection: $viewMode) {
                    ForEach(MainViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch viewMode {
                        case .input:
                            inputSection
                        case .library:
                            librarySection
                        }
                        
                        helpSection
                    }
                    .padding()
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Excel Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Demo") {
                        loadDemo()
                    }
                    .foregroundColor(.orange)
                }
            }
            .onAppear {
                setupDirectories()
                loadSavedFiles()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .sheet(isPresented: $showingWebView) {
            ExcelWebViewSheet(file: selectedFile, url: fileURL)
        }
        .sheet(isPresented: $showingNativeView) {
            if let workbook = parser.parsedWorkbook {
                ExcelNativeViewSheet(workbook: workbook)
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Teams Excel Viewer")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("View, download, and parse Excel files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            ExcelInputCard(
                fileURL: $fileURL,
                isDownloading: isDownloading,
                downloadProgress: downloadProgress,
                onViewOnline: { showWebView() },
                onDownload: { downloadFile() },
                onParseNative: { parseFromURL() }
            )
        }
    }
    
    private var librarySection: some View {
        VStack(spacing: 16) {
            if savedFiles.isEmpty {
                ExcelEmptyLibraryView()
            } else {
                ForEach(savedFiles) { file in
                    ExcelFileCard(file: file) { action in
                        handleFileAction(file: file, action: action)
                    }
                }
            }
        }
    }
    
    private var helpSection: some View {
        ExcelHelpCard()
    }
    
    // MARK: - Actions
    
    private func showWebView() {
        guard isValidURL(fileURL) else {
            errorMessage = "Please enter a valid SharePoint/Teams URL"
            return
        }
        selectedFile = nil
        showingWebView = true
    }
    
    private func downloadFile() {
        guard isValidURL(fileURL) else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        Task {
            do {
                let file = try await performDownload(url: fileURL)
                await MainActor.run {
                    savedFiles.append(file)
                    saveFilesList()
                    fileURL = ""
                    isDownloading = false
                    downloadProgress = 0.0
                    viewMode = .library
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Download failed: \(error.localizedDescription)"
                    isDownloading = false
                    downloadProgress = 0.0
                }
            }
        }
    }
    
    private func parseFromURL() {
        guard isValidURL(fileURL) else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        Task {
            do {
                // Download temporarily for parsing
                guard let url = URL(string: fileURL) else { throw ExcelError.invalidURL }
                let (data, _) = try await URLSession.shared.data(from: url)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("xlsx")
                
                try data.write(to: tempURL)
                await parser.parseFile(from: tempURL)
                try? FileManager.default.removeItem(at: tempURL)
                
                await MainActor.run {
                    if parser.parsedWorkbook != nil {
                        showingNativeView = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Parse failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleFileAction(file: SavedExcelFile, action: FileAction) {
        switch action {
        case .viewWeb:
            selectedFile = file
            showingWebView = true
            
        case .parseNative:
            let fileURL = cacheDirectory.appendingPathComponent(file.localFileName)
            Task {
                await parser.parseFile(from: fileURL)
                await MainActor.run {
                    if parser.parsedWorkbook != nil {
                        showingNativeView = true
                    }
                }
            }
            
        case .delete:
            deleteFile(file)
        }
    }
    
    private func deleteFile(_ file: SavedExcelFile) {
        let filePath = cacheDirectory.appendingPathComponent(file.localFileName)
        try? fileManager.removeItem(at: filePath)
        savedFiles.removeAll { $0.id == file.id }
        saveFilesList()
    }
    
    private func loadDemo() {
        fileURL = "https://1drv.ms/x/s!AhkXOvFATgJGgQEG_cYWOZTiWHwz"
        viewMode = .input
    }
    
    // MARK: - File Management
    
    private func setupDirectories() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func performDownload(url: String) async throws -> SavedExcelFile {
        guard let downloadURL = URL(string: url) else {
            throw ExcelError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExcelError.downloadFailed
        }
        
        let fileName = extractFileName(from: url)
        let localFileName = "\(UUID().uuidString)_\(fileName)"
        let localURL = cacheDirectory.appendingPathComponent(localFileName)
        
        try data.write(to: localURL)
        
        await MainActor.run {
            downloadProgress = 1.0
        }
        
        return SavedExcelFile(
            id: UUID(),
            name: fileName,
            originalURL: url,
            localFileName: localFileName,
            fileSize: Int64(data.count),
            downloadDate: Date()
        )
    }
    
    private func saveFilesList() {
        if let data = try? JSONEncoder().encode(savedFiles) {
            UserDefaults.standard.set(data, forKey: "excel_files_list")
        }
    }
    
    private func loadSavedFiles() {
        if let data = UserDefaults.standard.data(forKey: "excel_files_list"),
           let files = try? JSONDecoder().decode([SavedExcelFile].self, from: data) {
            savedFiles = files.filter { file in
                let filePath = cacheDirectory.appendingPathComponent(file.localFileName)
                return fileManager.fileExists(atPath: filePath.path)
            }
            
            if savedFiles.count != files.count {
                saveFilesList()
            }
        }
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let validDomains = ["sharepoint.com", "1drv.ms", "officeapps.live.com", "teams.microsoft.com"]
        return validDomains.contains { domain in url.host?.contains(domain) == true }
    }
    
    private func extractFileName(from urlString: String) -> String {
        if let url = URL(string: urlString) {
            let pathComponents = url.pathComponents
            
            for component in pathComponents.reversed() {
                if component.contains(".xlsx") || component.contains(".xls") {
                    return component
                }
            }
            
            if let query = url.query {
                let components = query.components(separatedBy: "&")
                for component in components {
                    if component.contains("sourcedoc=") || component.contains("file=") {
                        let parts = component.split(separator: "=")
                        if parts.count > 1 {
                            return String(parts[1])
                        }
                    }
                }
            }
        }
        
        return "Excel_File_\(Int(Date().timeIntervalSince1970)).xlsx"
    }
}

// MARK: - Supporting Views

struct ExcelInputCard: View {
    @Binding var fileURL: String
    let isDownloading: Bool
    let downloadProgress: Double
    let onViewOnline: () -> Void
    let onDownload: () -> Void
    let onParseNative: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Excel File Link")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("https://company.sharepoint.com/...", text: $fileURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            if isDownloading {
                VStack(spacing: 8) {
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    ProgressView(value: downloadProgress)
                        .tint(.blue)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("📱 View Online") {
                        onViewOnline()
                    }
                    .buttonStyle(ExcelSecondaryButtonStyle())
                    .disabled(fileURL.isEmpty || isDownloading)
                    
                    Button("💾 Download") {
                        onDownload()
                    }
                    .buttonStyle(ExcelPrimaryButtonStyle())
                    .disabled(fileURL.isEmpty || isDownloading)
                }
                
                Button("📊 Parse to Native View") {
                    onParseNative()
                }
                .buttonStyle(ExcelSpecialButtonStyle())
                .disabled(fileURL.isEmpty || isDownloading)
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct ExcelFileCard: View {
    let file: SavedExcelFile
    let onAction: (FileAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                        Text("•")
                        Text("Downloaded \(file.downloadDate, style: .date)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Available Offline")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Button(action: { onAction(.delete) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                Button("📱 Web View") {
                    onAction(.viewWeb)
                }
                .buttonStyle(ExcelSecondaryButtonStyle())
                
                Button("📊 Native View") {
                    onAction(.parseNative)
                }
                .buttonStyle(ExcelPrimaryButtonStyle())
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct ExcelEmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Downloaded Files")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add Excel files from the 'Add Files' tab to view them offline")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ExcelHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("How to get file links:")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open Microsoft Teams")
                Text("2. Find the Excel file in chat or files")
                Text("3. Click the three dots (...) next to the file")
                Text("4. Select 'Copy link' or 'Get link'")
                Text("5. Paste the link in the field above")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

// MARK: - Web View Sheets

struct ExcelWebViewSheet: View {
    let file: SavedExcelFile?
    let url: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            if let file = file {
                // Offline file
                ExcelOfflineWebView(file: file)
                    .navigationTitle(file.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { dismiss() }
                        }
                    }
            } else {
                // Online URL
                ExcelOnlineWebView(url: url)
                    .navigationTitle("Excel File")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }
}

struct ExcelNativeViewSheet: View {
    let workbook: ExcelWorkbookData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ExcelNativeTableView(workbook: workbook)
                .navigationTitle(workbook.fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct ExcelOfflineWebView: View {
    let file: SavedExcelFile
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("ExcelFiles/\(file.localFileName)")
    }
    
    var body: some View {
        ExcelWebViewRepresentable(fileURL: fileURL, isOnline: false)
    }
}

struct ExcelOnlineWebView: View {
    let url: String
    
    var body: some View {
        ExcelWebViewRepresentable(url: url, isOnline: true)
    }
}

struct ExcelWebViewRepresentable: UIViewRepresentable {
    let fileURL: URL?
    let url: String?
    let isOnline: Bool
    
    init(fileURL: URL, isOnline: Bool) {
        self.fileURL = fileURL
        self.url = nil
        self.isOnline = isOnline
    }
    
    init(url: String, isOnline: Bool) {
        self.fileURL = nil
        self.url = url
        self.isOnline = isOnline
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if isOnline, let urlString = url, let webURL = URL(string: urlString) {
            let request = URLRequest(url: webURL)
            webView.load(request)
        } else if let fileURL = fileURL {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        }
    }
}

// MARK: - Native Table View (Simplified)

struct ExcelNativeTableView: View {
    let workbook: ExcelWorkbookData
    @State private var selectedSheet = 0
    @State private var searchText = ""
    
    private var currentSheet: ExcelSheetData {
        workbook.sheets[selectedSheet]
    }
    
    private var filteredRows: [[String]] {
        if searchText.isEmpty {
            return currentSheet.dataRows
        }
        return currentSheet.dataRows.filter { row in
            row.contains { cell in
                cell.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(LogbookTheme.fieldBackground)
            
            // Table
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Headers
                    HStack(spacing: 0) {
                        ForEach(0..<currentSheet.headers.count, id: \.self) { index in
                            Text(currentSheet.headers[index])
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .padding(8)
                                .frame(minWidth: 100, alignment: .leading)
                                .background(LogbookTheme.accentBlue)
                                .border(Color.gray.opacity(0.3), width: 0.5)
                        }
                    }
                    
                    // Data Rows
                    ForEach(0..<filteredRows.count, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<min(filteredRows[rowIndex].count, currentSheet.headers.count), id: \.self) { colIndex in
                                Text(filteredRows[rowIndex][colIndex])
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .background(rowIndex % 2 == 0 ? LogbookTheme.fieldBackground : LogbookTheme.fieldBackground.opacity(0.5))
                                    .border(Color.gray.opacity(0.3), width: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct SavedExcelFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let originalURL: String
    let localFileName: String
    let fileSize: Int64
    let downloadDate: Date
}

struct ExcelWorkbookData {
    let fileName: String
    let sheets: [ExcelSheetData]
    let parseDate: Date
}

struct ExcelSheetData {
    let name: String
    let headers: [String]
    let dataRows: [[String]]
}

enum FileAction {
    case viewWeb
    case parseNative
    case delete
}

enum ExcelError: LocalizedError {
    case invalidURL
    case downloadFailed
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .downloadFailed: return "Download failed"
        case .parseError: return "Parse error"
        }
    }
}

// MARK: - Excel Parser (Simplified)

class ExcelDataParser: ObservableObject {
    @Published var parsedWorkbook: ExcelWorkbookData?
    @Published var isLoading = false
    @Published var progress: Double = 0.0
    
    func parseFile(from url: URL) async {
        await MainActor.run {
            isLoading = true
            progress = 0.0
        }
        
        do {
            let data = try Data(contentsOf: url)
            await updateProgress(0.5)
            
            // Simple CSV parsing for demo
            if url.pathExtension.lowercased() == "csv" {
                let workbook = try parseCSV(data: data, fileName: url.lastPathComponent)
                await updateProgress(1.0)
                
                await MainActor.run {
                    self.parsedWorkbook = workbook
                    self.isLoading = false
                }
            } else {
                // For actual Excel files, would use a library like SheetJS
                throw ExcelError.parseError
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func parseCSV(data: Data, fileName: String) throws -> ExcelWorkbookData {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ExcelError.parseError
        }
        
        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard !lines.isEmpty else {
            throw ExcelError.parseError
        }
        
        let rows = lines.map { line in
            line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let headers = rows.first ?? []
        let dataRows = Array(rows.dropFirst())
        
        let sheet = ExcelSheetData(
            name: "Sheet1",
            headers: headers,
            dataRows: dataRows
        )
        
        return ExcelWorkbookData(
            fileName: fileName,
            sheets: [sheet],
            parseDate: Date()
        )
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            self.progress = value
        }
    }
}

// MARK: - Button Styles

struct ExcelPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(LogbookTheme.accentGreen)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ExcelSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(LogbookTheme.navy)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ExcelSpecialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

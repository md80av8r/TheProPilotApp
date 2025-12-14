//
//  SharePointIntegration.swift
//  ProPilotApp
//
//  Complete SharePoint integration with document support and auto-refresh
//

import SwiftUI
import Foundation
import Combine

// MARK: - Data Models

struct DirectDocumentLink: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var fileType: DocumentFileType
    var updateInterval: UpdateInterval
    var isActive: Bool = true
    var lastUpdated: Date?
    var cachedFilePath: String?
    
    init(name: String, url: String, updateInterval: UpdateInterval) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.updateInterval = updateInterval
        self.fileType = DocumentFileType.fromURL(url)
    }
}

enum DocumentFileType: String, CaseIterable, Codable {
    case csv = "csv"
    case excel = "xlsx"
    case word = "docx"
    case pdf = "pdf"
    case text = "txt"
    case powerpoint = "pptx"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .excel: return "doc.richtext"
        case .word: return "doc.text"
        case .pdf: return "doc.pdf"
        case .text: return "doc.plaintext"
        case .powerpoint: return "doc.presentation"
        case .unknown: return "doc"
        }
    }
    
    var color: Color {
        switch self {
        case .csv: return .green
        case .excel: return .green
        case .word: return .blue
        case .pdf: return .red
        case .text: return .gray
        case .powerpoint: return .orange
        case .unknown: return .gray
        }
    }
    
    static func fromURL(_ url: String) -> DocumentFileType {
        let lowercased = url.lowercased()
        if lowercased.contains(".csv") { return .csv }
        if lowercased.contains(".xlsx") || lowercased.contains(".xls") { return .excel }
        if lowercased.contains(".docx") || lowercased.contains(".doc") { return .word }
        if lowercased.contains(".pdf") { return .pdf }
        if lowercased.contains(".txt") { return .text }
        if lowercased.contains(".pptx") || lowercased.contains(".ppt") { return .powerpoint }
        return .unknown
    }
}

enum UpdateInterval: String, CaseIterable, Codable {
    case manual = "manual"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual Only"
        case .hourly: return "Every Hour"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .manual: return nil
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        }
    }
}

// MARK: - Document File Manager
class DocumentFileManager {
    static let shared = DocumentFileManager()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var sharedDirectory: URL {
        documentsDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
    }
    
    init() {
        createSharedDirectoryIfNeeded()
        print("📁 DocumentFileManager initialized")
        print("📁 Documents directory: \(documentsDirectory.path)")
        print("📁 Shared directory: \(sharedDirectory.path)")
    }
    
    private func createSharedDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: sharedDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
                print("✅ Created shared directory at: \(sharedDirectory.path)")
            } catch {
                print("❌ Failed to create shared directory: \(error)")
            }
        } else {
            print("📁 Shared directory already exists")
        }
    }
    
    func createShareableFile(data: Data, fileName: String) -> URL? {
        print("📁 Creating shareable file: \(fileName) (\(data.count) bytes)")
        
        var fileURL = sharedDirectory.appendingPathComponent(fileName)
        print("📁 Target file path: \(fileURL.path)")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("📁 Removed existing file")
            }
            
            try data.write(to: fileURL)
            print("✅ File written successfully")
            
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            print("📁 File exists after write: \(fileExists)")
            
            if fileExists {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                print("📁 File size on disk: \(attributes[.size] ?? "unknown")")
            }
            
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try fileURL.setResourceValues(resourceValues)
            print("📁 Set resource values")
            
            return fileURL
        } catch {
            print("❌ Failed to create shareable file: \(error)")
            return nil
        }
    }
    
    func cleanupOldFiles() {
        print("🧹 Cleaning up old files...")
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sharedDirectory, includingPropertiesForKeys: [.creationDateKey])
            print("📁 Found \(files.count) files in shared directory")
            
            var deletedCount = 0
            for fileURL in files {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }
            print("🧹 Deleted \(deletedCount) old files")
        } catch {
            print("❌ Failed to cleanup old files: \(error)")
        }
    }
}

// MARK: - Enhanced Teams Integration Manager
@MainActor
class EnhancedTeamsIntegrationManager: ObservableObject {
    @Published var directLinks: [DirectDocumentLink] = []
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private var updateTimers: [UUID: Timer] = [:]
    
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDir = documentsPath.appendingPathComponent("SharePointCache")
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        return cacheDir
    }
    
    init() {
        loadDirectLinks()
        setupUpdateTimers()
    }
    
    func addDirectLink(name: String, url: String, updateInterval: UpdateInterval) {
        let link = DirectDocumentLink(name: name, url: url, updateInterval: updateInterval)
        directLinks.append(link)
        saveDirectLinks()
        
        if updateInterval != .manual {
            setupUpdateTimer(for: link)
        }
        
        Task {
            await downloadDocument(link: link)
        }
    }
    
    func removeDirectLink(_ link: DirectDocumentLink) {
        updateTimers[link.id]?.invalidate()
        updateTimers.removeValue(forKey: link.id)
        
        if let cachedPath = link.cachedFilePath {
            let fileURL = cacheDirectory.appendingPathComponent(cachedPath)
            try? fileManager.removeItem(at: fileURL)
        }
        
        directLinks.removeAll { $0.id == link.id }
        saveDirectLinks()
    }
    
    func updateDirectLink(_ link: DirectDocumentLink, name: String, url: String, updateInterval: UpdateInterval) {
        guard let index = directLinks.firstIndex(where: { $0.id == link.id }) else { return }
        
        directLinks[index].name = name
        directLinks[index].url = url
        directLinks[index].updateInterval = updateInterval
        directLinks[index].fileType = DocumentFileType.fromURL(url)
        
        saveDirectLinks()
        
        updateTimers[link.id]?.invalidate()
        if updateInterval != .manual {
            setupUpdateTimer(for: directLinks[index])
        }
    }
    
    func toggleLinkActive(_ link: DirectDocumentLink) {
        guard let index = directLinks.firstIndex(where: { $0.id == link.id }) else { return }
        
        directLinks[index].isActive.toggle()
        saveDirectLinks()
        
        if directLinks[index].isActive && directLinks[index].updateInterval != .manual {
            setupUpdateTimer(for: directLinks[index])
        } else {
            updateTimers[link.id]?.invalidate()
            updateTimers.removeValue(forKey: link.id)
        }
    }
    
    func manualRefresh(link: DirectDocumentLink) async {
        await downloadDocument(link: link)
    }
    
    private func downloadDocument(link: DirectDocumentLink) async {
        print("📥 Starting download for: \(link.name)")
        print("📥 URL: \(link.url)")
        
        guard let url = URL(string: link.url) else {
            await MainActor.run {
                errorMessage = "Invalid URL for \(link.name): \(link.url)"
                print("❌ Invalid URL: \(link.url)")
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let downloadURL = createDirectDownloadURL(from: url)
            print("📥 Download URL: \(downloadURL.absoluteString)")
            
            var request = URLRequest(url: downloadURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            
            print("📥 Making network request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("📥 Response received:")
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Status code: \(httpResponse.statusCode)")
            }
            print("📥 Data size: \(data.count) bytes")
            
            guard !data.isEmpty else {
                await MainActor.run {
                    errorMessage = "Downloaded file is empty for \(link.name)"
                    isLoading = false
                    print("❌ Downloaded data is empty")
                }
                return
            }
            
            if let htmlContent = String(data: data, encoding: .utf8),
               htmlContent.lowercased().contains("<html") {
                print("⚠️ Received HTML content instead of file:")
                await MainActor.run {
                    errorMessage = "Received HTML instead of file data. The link may require authentication or be invalid."
                    isLoading = false
                }
                return
            }
            
            let fileName = "\(link.id.uuidString)_\(link.name)"
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            
            print("📥 Saving to cache: \(fileURL.path)")
            try data.write(to: fileURL)
            print("✅ File saved successfully")
            
            await MainActor.run {
                if let index = directLinks.firstIndex(where: { $0.id == link.id }) {
                    directLinks[index].lastUpdated = Date()
                    directLinks[index].cachedFilePath = fileName
                    print("✅ Updated link metadata")
                }
                isLoading = false
                saveDirectLinks()
                print("✅ Download completed for: \(link.name)")
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to download \(link.name): \(error.localizedDescription)"
                isLoading = false
                print("❌ Download failed: \(error)")
            }
        }
    }
    
    private func createDirectDownloadURL(from sharePointURL: URL) -> URL {
        var urlString = sharePointURL.absoluteString
        print("🔗 Original URL: \(urlString)")
        
        if urlString.contains("sharepoint.com") {
            print("🔗 Detected SharePoint URL")
            
            if urlString.contains("?") {
                if urlString.contains("download=1") {
                    print("🔗 URL already has download parameter")
                    return sharePointURL
                }
                
                if let baseURL = urlString.components(separatedBy: "?").first {
                    urlString = baseURL + "?download=1"
                    print("🔗 Added download parameter to SharePoint URL")
                }
            } else {
                urlString += "?download=1"
                print("🔗 Added download parameter to SharePoint URL")
            }
            
            if urlString.contains("/_layouts/15/guestaccess.aspx") {
                urlString = urlString.replacingOccurrences(of: "/_layouts/15/guestaccess.aspx", with: "/_layouts/15/download.aspx")
                print("🔗 Converted guest access URL to download URL")
            }
            
        } else if urlString.contains("1drv.ms") {
            print("🔗 Detected OneDrive short URL")
            urlString += urlString.contains("?") ? "&download=1" : "?download=1"
            
        } else if urlString.contains("onedrive.live.com") {
            print("🔗 Detected OneDrive live URL")
            if urlString.contains("view.aspx") {
                urlString = urlString.replacingOccurrences(of: "view.aspx", with: "download.aspx")
                print("🔗 Converted OneDrive view URL to download URL")
            } else {
                urlString += urlString.contains("?") ? "&download=1" : "?download=1"
            }
            
        } else if urlString.contains("teams.microsoft.com") {
            print("🔗 Detected Teams URL")
            if let range = urlString.range(of: "https://"),
               let endRange = urlString.range(of: "&") {
                let potentialURL = String(urlString[range.lowerBound..<endRange.lowerBound])
                if potentialURL.contains("sharepoint.com") {
                    urlString = potentialURL + "?download=1"
                    print("🔗 Extracted SharePoint URL from Teams link")
                }
            }
            
        } else {
            print("🔗 Unknown URL format, using as-is")
        }
        
        let finalURL = URL(string: urlString) ?? sharePointURL
        print("🔗 Final download URL: \(finalURL.absoluteString)")
        
        return finalURL
    }
    
    func getCachedFileData(for link: DirectDocumentLink) -> Data? {
        guard let cachedPath = link.cachedFilePath else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(cachedPath)
        return try? Data(contentsOf: fileURL)
    }
    
    private func setupUpdateTimers() {
        for link in directLinks where link.isActive && link.updateInterval != .manual {
            setupUpdateTimer(for: link)
        }
    }
    
    private func setupUpdateTimer(for link: DirectDocumentLink) {
        guard let interval = link.updateInterval.timeInterval else { return }
        
        updateTimers[link.id]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.downloadDocument(link: link)
            }
        }
        
        updateTimers[link.id] = timer
    }
    
    func authenticate(username: String, tenantId: String, clientId: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            isAuthenticated = true
            isLoading = false
        }
    }
    
    func signOut() {
        isAuthenticated = false
    }
    
    private func loadDirectLinks() {
        if let data = userDefaults.data(forKey: "DirectLinks"),
           let links = try? JSONDecoder().decode([DirectDocumentLink].self, from: data) {
            directLinks = links
        }
    }
    
    private func saveDirectLinks() {
        if let data = try? JSONEncoder().encode(directLinks) {
            userDefaults.set(data, forKey: "DirectLinks")
        }
    }
    
    deinit {
        for timer in updateTimers.values {
            timer.invalidate()
        }
    }
}

// MARK: - Main SharePoint Integration View
struct SharePointIntegrationView: View {
    @StateObject private var manager = EnhancedTeamsIntegrationManager()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("View Mode", selection: $selectedTab) {
                    Text("Direct Links").tag(0)
                    Text("Browse SharePoint").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    DirectLinksTabView(manager: manager)
                } else {
                    SharePointBrowserTabView(manager: manager)
                }
            }
            .navigationTitle("SharePoint Documents")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Direct Links Tab
struct DirectLinksTabView: View {
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @State private var showingAddSheet = false
    @State private var showingTestShare = false
    @State private var testFileURL: URL?
    
    var body: some View {
        VStack {
            if manager.directLinks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Document Links")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Add SharePoint or Teams document links to access them directly and keep them automatically updated.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Button("Add Your First Link") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Test File Sharing") {
                            testFileSharing()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.orange)
                    }
                }
                .padding()
            } else {
                List {
                    ForEach(manager.directLinks) { link in
                        DirectLinkRowView(link: link, manager: manager)
                    }
                    .onDelete(perform: deleteLinks)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Link") {
                    showingAddSheet = true
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddDirectLinkSheetView(manager: manager)
        }
        .sheet(isPresented: $showingTestShare) {
            if let url = testFileURL {
                SimpleShareSheet(activityItems: [url])
            }
        }
        .refreshable {
            await refreshAllLinks()
        }
    }
    
    private func deleteLinks(offsets: IndexSet) {
        for index in offsets {
            manager.removeDirectLink(manager.directLinks[index])
        }
    }
    
    private func refreshAllLinks() async {
        for link in manager.directLinks where link.isActive {
            await manager.manualRefresh(link: link)
        }
    }
    
    private func testFileSharing() {
        print("🧪 Testing file sharing mechanism...")
        
        let csvContent = """
        Name,Email,Department
        John Doe,john@example.com,Engineering
        Jane Smith,jane@example.com,Marketing
        Bob Johnson,bob@example.com,Sales
        """
        
        guard let data = csvContent.data(using: .utf8) else {
            print("❌ Failed to create test data")
            return
        }
        
        guard let fileURL = DocumentFileManager.shared.createShareableFile(
            data: data,
            fileName: "test_file.csv"
        ) else {
            print("❌ Failed to create test file")
            return
        }
        
        print("🧪 Test file created at: \(fileURL.path)")
        testFileURL = fileURL
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🧪 Showing test share sheet")
            showingTestShare = true
        }
    }
}

// MARK: - Enhanced Direct Link Row
struct DirectLinkRowView: View {
    let link: DirectDocumentLink
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @State private var showingEditSheet = false
    @State private var showingDocumentViewer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: link.fileType.icon)
                    .foregroundColor(link.fileType.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(link.updateInterval.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(link.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            if let lastUpdated = link.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Not yet downloaded")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            HStack(spacing: 12) {
                Button("View") {
                    showingDocumentViewer = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Refresh") {
                    Task {
                        await manager.manualRefresh(link: link)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(link.isActive ? "Pause" : "Resume") {
                    manager.toggleLinkActive(link)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(link.isActive ? .orange : .green)
                
                Spacer()
                
                Button("Edit") {
                    showingEditSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            EditDirectLinkSheetView(link: link, manager: manager)
        }
        .sheet(isPresented: $showingDocumentViewer) {
            SafeDocumentViewer(link: link, manager: manager)
        }
    }
}

// MARK: - Share Item Model
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
}

// MARK: - Safe Document Viewer with Item-Based Sheet
struct SafeDocumentViewer: View {
    let link: DirectDocumentLink
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Custom navigation bar
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(link.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if manager.getCachedFileData(for: link) != nil && !isLoading {
                        Button("Share") {
                            shareDocument()
                        }
                        .foregroundColor(.blue)
                    } else {
                        Button("Share") {
                            shareDocument()
                        }
                        .foregroundColor(.blue)
                        .disabled(true)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Main content
                Group {
                    if isLoading {
                        VStack {
                            ProgressView("Loading document...")
                            Text(link.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let data = manager.getCachedFileData(for: link) {
                        DocumentContentDisplayView(
                            data: data,
                            fileType: link.fileType,
                            fileName: link.name,
                            onShare: shareDocument
                        )
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Document Not Available")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("This document hasn't been downloaded yet or the download failed.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            if let error = manager.errorMessage {
                                Text("Error: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button("Download Now") {
                                downloadDocument()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $shareItem) { item in
            RobustShareSheet(shareItem: item)
        }
        .alert("Share Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func downloadDocument() {
        print("🔄 Starting download for: \(link.name)")
        isLoading = true
        Task {
            await manager.manualRefresh(link: link)
            await MainActor.run {
                isLoading = false
                print("🔄 Download completed for: \(link.name)")
            }
        }
    }
    
    private func shareDocument() {
        print("🔄 Starting shareDocument for: \(link.name)")
        
        guard let data = manager.getCachedFileData(for: link) else {
            print("❌ No cached data available for sharing")
            showError("No document data available. Please download the document first.")
            return
        }
        
        print("✅ Found cached data: \(data.count) bytes")
        
        DocumentFileManager.shared.cleanupOldFiles()
        
        guard let fileURL = DocumentFileManager.shared.createShareableFile(data: data, fileName: link.name) else {
            print("❌ Failed to create shareable file")
            showError("Failed to prepare file for sharing. Please try again.")
            return
        }
        
        print("✅ Created shareable file at: \(fileURL.path)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ File does not exist after creation")
            showError("File creation failed. Please try again.")
            return
        }
        
        print("📱 Creating ShareItem with URL: \(fileURL.path)")
        let item = ShareItem(url: fileURL, name: link.name)
        
        // Use item-based sheet presentation - this ensures URL is available
        shareItem = item
        print("📱 ShareItem created and set - sheet will present automatically")
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Robust Share Sheet (with item-based presentation)
struct RobustShareSheet: View {
    let shareItem: ShareItem
    
    var body: some View {
        VStack {
            EnhancedActivityViewController(shareItem: shareItem)
        }
        .onAppear {
            print("📱 RobustShareSheet appeared with item: \(shareItem.name)")
            print("📱 URL: \(shareItem.url.path)")
            print("📱 File exists: \(FileManager.default.fileExists(atPath: shareItem.url.path))")
        }
    }
}

// MARK: - Enhanced Activity View Controller
struct EnhancedActivityViewController: UIViewControllerRepresentable {
    let shareItem: ShareItem
    
    func makeUIViewController(context: Context) -> UIViewController {
        print("📱 === EnhancedActivityViewController makeUIViewController ===")
        print("📱 ShareItem: \(shareItem.name)")
        print("📱 URL: \(shareItem.url.path)")
        
        // Verify file exists and is readable
        let fileExists = FileManager.default.fileExists(atPath: shareItem.url.path)
        print("📱 File exists: \(fileExists)")
        
        guard fileExists else {
            print("❌ File doesn't exist, creating error controller")
            return createErrorViewController(message: "File not found: \(shareItem.name)")
        }
        
        // Get file attributes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: shareItem.url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📱 File size: \(fileSize) bytes")
            
            guard fileSize > 0 else {
                print("❌ File is empty")
                return createErrorViewController(message: "File is empty: \(shareItem.name)")
            }
        } catch {
            print("❌ Cannot read file attributes: \(error)")
            return createErrorViewController(message: "Cannot access file: \(shareItem.name)")
        }
        
        print("📱 Creating UIActivityViewController with valid file")
        let activityController = UIActivityViewController(activityItems: [shareItem.url], applicationActivities: nil)
        
        // Enhanced completion handler
        activityController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            print("📱 === Share Activity Completed ===")
            print("📱 Activity: \(activityType?.rawValue ?? "none")")
            print("📱 Completed: \(completed)")
            print("📱 File: \(shareItem.name)")
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
            }
            if let items = returnedItems {
                print("📦 Returned \(items.count) items")
            }
            print("📱 === End Share Activity ===")
        }
        
        // Configure popover for iPad
        if let popover = activityController.popoverPresentationController {
            print("📱 Configuring iPad popover")
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootView = window.rootViewController?.view {
                
                popover.sourceView = rootView
                popover.sourceRect = CGRect(x: rootView.bounds.midX, y: rootView.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
                print("📱 iPad popover configured successfully")
            } else {
                popover.sourceView = UIView()
                popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                popover.permittedArrowDirections = []
                print("📱 iPad popover fallback configuration")
            }
        }
        
        // Minimal exclusions to maximize sharing options
        activityController.excludedActivityTypes = [.assignToContact, .addToReadingList]
        
        print("📱 UIActivityViewController created successfully")
        return activityController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        print("📱 EnhancedActivityViewController updateUIViewController called")
    }
    
    private func createErrorViewController(message: String) -> UIViewController {
        let errorController = UIViewController()
        errorController.view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Sharing Error"
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        
        errorController.view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: errorController.view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: errorController.view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: errorController.view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: errorController.view.trailingAnchor, constant: -20)
        ])
        
        return errorController
    }
}

// MARK: - Document Content Display
struct DocumentContentDisplayView: View {
    let data: Data
    let fileType: DocumentFileType
    let fileName: String
    let onShare: () -> Void
    
    var body: some View {
        switch fileType {
        case .csv:
            CSVDisplayView(data: data)
        case .excel:
            ExcelFileInfoView(data: data, fileName: fileName, onShare: onShare)
        case .pdf:
            PDFInfoView(data: data, fileName: fileName, onShare: onShare)
        default:
            TextFileDisplayView(data: data, fileName: fileName)
        }
    }
}

// MARK: - Excel File Info View
struct ExcelFileInfoView: View {
    let data: Data
    let fileName: String
    let onShare: () -> Void
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text(fileName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Excel Spreadsheet")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("Size: \(ByteCountFormatter().string(fromByteCount: Int64(data.count)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Information")
                        .font(.headline)
                    
                    HStack {
                        Text("Type:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Microsoft Excel")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Format:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(fileName.hasSuffix(".xlsx") ? "Excel 2007+" : "Excel 97-2003")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Updated:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Just now")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Text("Open with these apps:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        AppSuggestionRow(icon: "📊", name: "Microsoft Excel", description: "Full editing capabilities")
                        AppSuggestionRow(icon: "📈", name: "Numbers", description: "Apple's spreadsheet app")
                        AppSuggestionRow(icon: "📋", name: "Google Sheets", description: "View and edit online")
                        AppSuggestionRow(icon: "📁", name: "Files app", description: "System file viewer")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Button(action: handleShare) {
                        Label("Share/Open File", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button("Copy to Files App") {
                        handleShare()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Text("💡 Tip: Use the share button to open this file in Excel, Numbers, or other compatible apps on your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top)
            }
            .padding()
        }
        .alert("Share Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleShare() {
        print("📊 Excel file share button tapped for: \(fileName)")
        
        guard !data.isEmpty else {
            print("❌ Excel file data is empty")
            showError("File data is empty or corrupted.")
            return
        }
        
        print("📊 Excel file data is valid (\(data.count) bytes), calling onShare")
        onShare()
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - App Suggestion Row
struct AppSuggestionRow: View {
    let icon: String
    let name: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CSV Display View
struct CSVDisplayView: View {
    let data: Data
    @State private var rows: [[String]] = []
    @State private var headers: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("Loading CSV...")
                    Text("Parsing data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Unable to display CSV")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if rows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Empty CSV File")
                        .font(.headline)
                    
                    Text("This CSV file appears to be empty or contains no valid data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !headers.isEmpty {
                            HStack(spacing: 0) {
                                ForEach(headers.indices, id: \.self) { colIndex in
                                    Text(headers[colIndex])
                                        .font(.headline)
                                        .padding(8)
                                        .frame(minWidth: max(120, CGFloat(headers[colIndex].count) * 8 + 16), alignment: .leading)
                                        .background(Color.blue.opacity(0.2))
                                        .border(Color.gray.opacity(0.3), width: 0.5)
                                }
                            }
                        }
                        
                        ForEach(1..<min(rows.count, 101), id: \.self) { rowIndex in
                            HStack(spacing: 0) {
                                ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                                    let cellText = rows[rowIndex][colIndex]
                                    Text(cellText)
                                        .font(.body)
                                        .padding(8)
                                        .frame(minWidth: max(120, CGFloat(cellText.count) * 7 + 16), alignment: .leading)
                                        .background(rowIndex % 2 == 0 ? Color.clear : Color.gray.opacity(0.1))
                                        .border(Color.gray.opacity(0.3), width: 0.5)
                                }
                            }
                        }
                        
                        if rows.count > 101 {
                            HStack {
                                Text("Showing first 100 rows of \(rows.count - 1) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            parseCSVData()
        }
    }
    
    private func parseCSVData() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let content = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    errorMessage = "Unable to read file content. The file may be corrupted or in an unsupported encoding."
                    isLoading = false
                }
                return
            }
            
            let lines = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            guard !lines.isEmpty else {
                DispatchQueue.main.async {
                    errorMessage = "The CSV file is empty."
                    isLoading = false
                }
                return
            }
            
            var parsedRows: [[String]] = []
            
            for line in lines {
                let row = line.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                parsedRows.append(row)
            }
            
            DispatchQueue.main.async {
                self.rows = parsedRows
                self.headers = parsedRows.first ?? []
                self.isLoading = false
            }
        }
    }
}

// MARK: - PDF Info View
struct PDFInfoView: View {
    let data: Data
    let fileName: String
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.pdf")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text(fileName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("PDF Document")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Size: \(ByteCountFormatter().string(fromByteCount: Int64(data.count)))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Share/Open PDF") {
                onShare()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Text File Display View
struct TextFileDisplayView: View {
    let data: Data
    let fileName: String
    
    var body: some View {
        ScrollView {
            if let content = String(data: data, encoding: .utf8) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Cannot display this file type")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - Add Link Sheet
struct AddDirectLinkSheetView: View {
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var url = ""
    @State private var updateInterval = UpdateInterval.hourly
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Document Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("SharePoint/Teams URL", text: $url, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .lineLimit(2...4)
                } header: {
                    Text("Document Details")
                } footer: {
                    Text("Give your document a friendly name and paste the direct link from SharePoint or Teams.")
                }
                
                Section {
                    Picker("Update Frequency", selection: $updateInterval) {
                        ForEach(UpdateInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                } header: {
                    Text("Auto-Update Settings")
                } footer: {
                    Text("Choose how often the document should automatically update. You can always refresh manually.")
                }
            }
            .navigationTitle("Add Document Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addLink()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func addLink() {
        manager.addDirectLink(name: name, url: url, updateInterval: updateInterval)
        dismiss()
    }
}

// MARK: - Edit Link Sheet
struct EditDirectLinkSheetView: View {
    let link: DirectDocumentLink
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var url: String
    @State private var updateInterval: UpdateInterval
    
    init(link: DirectDocumentLink, manager: EnhancedTeamsIntegrationManager) {
        self.link = link
        self.manager = manager
        _name = State(initialValue: link.name)
        _url = State(initialValue: link.url)
        _updateInterval = State(initialValue: link.updateInterval)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Document Details") {
                    TextField("Document Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("SharePoint/Teams URL", text: $url, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .lineLimit(2...4)
                }
                
                Section("Update Settings") {
                    Picker("Update Frequency", selection: $updateInterval) {
                        ForEach(UpdateInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                }
            }
            .navigationTitle("Edit Document Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        manager.updateDirectLink(link, name: name, url: url, updateInterval: updateInterval)
        dismiss()
    }
}

// MARK: - SharePoint Browser Tab
struct SharePointBrowserTabView: View {
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    
    var body: some View {
        VStack {
            if !manager.isAuthenticated {
                SharePointAuthView(manager: manager)
            } else {
                Text("SharePoint browser coming soon...")
                    .foregroundColor(.secondary)
                    .padding()
                
                Button("Sign Out") {
                    manager.signOut()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - SharePoint Auth View
struct SharePointAuthView: View {
    @ObservedObject var manager: EnhancedTeamsIntegrationManager
    @State private var username = ""
    @State private var tenantId = ""
    @State private var clientId = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Connect to SharePoint")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter your Microsoft 365 credentials to browse SharePoint sites.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                TextField("Email", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                
                TextField("Tenant ID", text: $tenantId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                
                TextField("Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
            }
            
            Button("Connect") {
                Task {
                    await manager.authenticate(username: username, tenantId: tenantId, clientId: clientId)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || tenantId.isEmpty || clientId.isEmpty)
            
            if manager.isLoading {
                ProgressView("Connecting...")
            }
            
            if let error = manager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}

// MARK: - Enhanced Share Sheet with Comprehensive Debugging
struct SimpleShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIViewController {
        print("📱 === SimpleShareSheet makeUIViewController called ===")
        print("📱 Creating SimpleShareSheet with \(activityItems.count) items")
        
        // Validate all items first
        var validItems: [Any] = []
        for (index, item) in activityItems.enumerated() {
            if let url = item as? URL {
                print("📁 Item \(index): URL - \(url.path)")
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                print("📁 File exists: \(fileExists)")
                
                if fileExists {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                        print("📁 File size: \(attributes[.size] ?? "unknown")")
                    }
                    validItems.append(url)
                } else {
                    print("❌ File doesn't exist, skipping: \(url.path)")
                }
            } else {
                print("📁 Item \(index): \(type(of: item)) - \(item)")
                validItems.append(item)
            }
        }
        
        guard !validItems.isEmpty else {
            print("❌ No valid items to share, returning error controller")
            let errorController = UIViewController()
            errorController.view.backgroundColor = .systemBackground
            
            let label = UILabel()
            label.text = "No files available to share"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            errorController.view.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: errorController.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: errorController.view.centerYAnchor)
            ])
            
            return errorController
        }
        
        print("📱 Creating UIActivityViewController with \(validItems.count) valid items")
        let controller = UIActivityViewController(activityItems: validItems, applicationActivities: nil)
        
        // Comprehensive completion handler
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            print("📱 === Share Activity Completed ===")
            print("📱 Activity Type: \(activityType?.rawValue ?? "none")")
            print("📱 Completed: \(completed)")
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
            }
            if let returned = returnedItems {
                print("📦 Returned \(returned.count) items")
            }
            print("📱 === End Share Activity ===")
        }
        
        // Configure for iPad with better error handling
        if let popover = controller.popoverPresentationController {
            print("📱 Configuring popover for iPad")
            
            // Try to get the current window
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootViewController = window.rootViewController {
                
                print("📱 Using window root view controller for popover")
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                          y: rootViewController.view.bounds.midY,
                                          width: 0,
                                          height: 0)
                popover.permittedArrowDirections = []
            } else {
                print("📱 Using fallback popover configuration")
                popover.sourceView = UIView()
                popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
        }
        
        // Minimal exclusions
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        print("📱 UIActivityViewController created successfully")
        print("📱 Presenting controller: \(controller)")
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        print("📱 SimpleShareSheet updateUIViewController called")
    }
}

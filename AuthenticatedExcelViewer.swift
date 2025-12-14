//
//  AuthenticatedExcelViewer.swift
//  ProPilotApp
//
//  Excel viewer with Teams authentication for secure file access
//

import SwiftUI
import WebKit
import Foundation

// MARK: - Teams Error (Added to fix scope issue)

enum TeamsError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case networkError(String)
    case fileNotFound
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Microsoft Teams"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .networkError(let message):
            return "Network error: \(message)"
        case .fileNotFound:
            return "Requested file not found"
        case .parseError(let message):
            return "Failed to parse file: \(message)"
        }
    }
}

// MARK: - Main Authenticated Excel Viewer

struct AuthenticatedExcelViewer: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = TeamsAuthManager()
    @StateObject private var parser = ExcelDataParser()
    
    @State private var viewMode: MainViewMode = .login
    @State private var selectedFile: AuthenticatedExcelFile?
    @State private var showingWebView = false
    @State private var showingNativeView = false
    @State private var errorMessage: String?
    
    enum MainViewMode: String, CaseIterable {
        case login = "Sign In"
        case browse = "Browse Files"
        case library = "My Files"
        
        var icon: String {
            switch self {
            case .login: return "person.circle"
            case .browse: return "folder.badge.plus"
            case .library: return "folder"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                if authManager.isAuthenticated {
                    // Mode Picker (only show when authenticated)
                    Picker("Mode", selection: $viewMode) {
                        ForEach([MainViewMode.browse, MainViewMode.library], id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                } else {
                    // Force login mode when not authenticated
                    EmptyView()
                        .onAppear {
                            viewMode = .login
                        }
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch viewMode {
                        case .login:
                            loginSection
                        case .browse:
                            browseSection
                        case .library:
                            librarySection
                        }
                        
                        if authManager.isAuthenticated {
                            helpSection
                        }
                    }
                    .padding()
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Teams Excel Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") {
                            authManager.signOut()
                            viewMode = .login
                        }
                        .foregroundColor(.red)
                    }
                }
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
            if let file = selectedFile {
                AuthenticatedWebViewSheet(file: file, authManager: authManager)
            }
        }
        .sheet(isPresented: $showingNativeView) {
            if let workbook = parser.parsedWorkbook {
                ExcelNativeViewSheet(workbook: workbook)
            }
        }
        .onChange(of: authManager.errorMessage) { _, newError in
            if let error = newError {
                errorMessage = error
                authManager.errorMessage = nil
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: authManager.isAuthenticated ? "checkmark.shield" : "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(authManager.isAuthenticated ? .green : .orange)
            
            Text("Teams Excel Viewer")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            if authManager.isAuthenticated {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Signed in as \(authManager.currentUser ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Text("Sign in to access your company's Excel files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var loginSection: some View {
        VStack(spacing: 20) {
            TeamsLoginCard(authManager: authManager) {
                // On successful login, switch to browse mode
                viewMode = .browse
            }
            
            // Company Setup Help
            TeamsSetupHelpCard()
        }
    }
    
    private var browseSection: some View {
        VStack(spacing: 16) {
            if authManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading your files...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if authManager.availableFiles.isEmpty {
                TeamsEmptyBrowseView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Files")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Refresh") {
                            Task {
                                await authManager.loadAvailableFiles()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    ForEach(authManager.availableFiles) { file in
                        TeamsBrowseFileCard(file: file, authManager: authManager) { action in
                            handleFileAction(file: file, action: action)
                        }
                    }
                }
            }
        }
    }
    
    private var librarySection: some View {
        VStack(spacing: 16) {
            if authManager.downloadedFiles.isEmpty {
                TeamsEmptyLibraryView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Downloaded Files")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("🔴 Offline Ready")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    ForEach(authManager.downloadedFiles) { file in
                        TeamsLibraryFileCard(file: file) { action in
                            handleDownloadedFileAction(file: file, action: action)
                        }
                    }
                }
            }
        }
    }
    
    private var helpSection: some View {
        TeamsFileAccessHelpCard()
    }
    
    // MARK: - Actions
    
    private func handleFileAction(file: AuthenticatedExcelFile, action: TeamsFileAction) {
        switch action {
        case .viewOnline:
            selectedFile = file
            showingWebView = true
            
        case .download:
            Task {
                await authManager.downloadFile(file)
                viewMode = .library
            }
            
        case .parseNative:
            Task {
                do {
                    let tempURL = try await authManager.downloadFileTemporary(file)
                    await parser.parseFile(from: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    await MainActor.run {
                        if parser.parsedWorkbook != nil {
                            showingNativeView = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to parse file: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func handleDownloadedFileAction(file: AuthenticatedExcelFile, action: DownloadedFileAction) {
        switch action {
        case .viewOffline:
            selectedFile = file
            showingWebView = true
            
        case .parseNative:
            Task {
                if let localURL = authManager.getLocalFileURL(for: file) {
                    await parser.parseFile(from: localURL)
                    await MainActor.run {
                        if parser.parsedWorkbook != nil {
                            showingNativeView = true
                        }
                    }
                }
            }
            
        case .delete:
            authManager.deleteDownloadedFile(file)
        }
    }
}

// MARK: - Teams Authentication Manager

@MainActor
class TeamsAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availableFiles: [AuthenticatedExcelFile] = []
    @Published var downloadedFiles: [AuthenticatedExcelFile] = []
    
    private var credentials: TeamsCredentials?
    private let fileManager = FileManager.default
    
    // Public access to domain for URL construction
    var currentDomain: String? {
        return credentials?.domain
    }
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var teamsDirectory: URL {
        documentsDirectory.appendingPathComponent("TeamsFiles", isDirectory: true)
    }
    
    struct TeamsCredentials {
        let username: String
        let password: String
        let domain: String
        let tenantId: String?
    }
    
    init() {
        setupDirectories()
        loadDownloadedFiles()
        loadSavedCredentials()  // Add this line
    }
    
    // MARK: - Authentication
    
    func signIn(username: String, password: String, domain: String = "", tenantId: String = "") async {
        isLoading = true
        errorMessage = nil
        
        // Simulate authentication delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        do {
            // In production, this would make actual API calls to Microsoft Graph
            let success = try await authenticateWithTeams(
                username: username,
                password: password,
                domain: domain,
                tenantId: tenantId
            )
            
            if success {
                credentials = TeamsCredentials(
                    username: username,
                    password: password,
                    domain: domain,
                    tenantId: tenantId.isEmpty ? nil : tenantId
                )
                
                isAuthenticated = true
                currentUser = username
                
                // Load available files after successful authentication
                await loadAvailableFiles()
                
                // Save credentials securely (in production, use Keychain)
                saveCredentials()
                
            } else {
                errorMessage = "Invalid username or password"
            }
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        credentials = nil
        availableFiles = []
        
        // Clear saved credentials
        UserDefaults.standard.removeObject(forKey: "teams_credentials")
        print("📤 Signed out from Teams")
    }
    
    // MARK: - File Operations
    
    func loadAvailableFiles() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        
        do {
            // In production, this would call Microsoft Graph API
            let files = try await fetchFilesFromTeams()
            availableFiles = files
        } catch {
            errorMessage = "Failed to load files: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func downloadFile(_ file: AuthenticatedExcelFile) async {
        guard isAuthenticated else { return }
        
        do {
            let localURL = try await performAuthenticatedDownload(file)
            
            // Add to downloaded files list
            var downloadedFile = file
            downloadedFile.localPath = localURL.lastPathComponent
            downloadedFile.downloadDate = Date()
            
            downloadedFiles.append(downloadedFile)
            saveDownloadedFilesList()
            
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
    }
    
    func downloadFileTemporary(_ file: AuthenticatedExcelFile) async throws -> URL {
        guard isAuthenticated else {
            throw TeamsError.notAuthenticated
        }
        
        // Download to temporary location for parsing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xlsx")
        
        // Simulate download with authentication
        let mockData = generateMockExcelData()
        try mockData.write(to: tempURL)
        
        return tempURL
    }
    
    func deleteDownloadedFile(_ file: AuthenticatedExcelFile) {
        if let localPath = file.localPath {
            let fileURL = teamsDirectory.appendingPathComponent(localPath)
            try? fileManager.removeItem(at: fileURL)
        }
        
        downloadedFiles.removeAll { $0.id == file.id }
        saveDownloadedFilesList()
    }
    
    func getLocalFileURL(for file: AuthenticatedExcelFile) -> URL? {
        guard let localPath = file.localPath else { return nil }
        return teamsDirectory.appendingPathComponent(localPath)
    }
    
    // MARK: - Private Methods
    
    private func authenticateWithTeams(username: String, password: String, domain: String, tenantId: String) async throws -> Bool {
        // In production, this would:
        // 1. Use Microsoft Authentication Library (MSAL)
        // 2. Handle OAuth 2.0 flow
        // 3. Obtain access tokens
        // 4. Validate credentials against Azure AD
        
        // For demo purposes, simulate authentication
        return !username.isEmpty && !password.isEmpty
    }
    
    private func fetchFilesFromTeams() async throws -> [AuthenticatedExcelFile] {
        // In production, this would call Microsoft Graph API:
        // GET https://graph.microsoft.com/v1.0/me/drive/root/children
        // GET https://graph.microsoft.com/v1.0/sites/{site-id}/drive/root/children
        
        // Mock data for demonstration
        return [
            AuthenticatedExcelFile(
                id: UUID(),
                name: "Flight_Schedule_August.xlsx",
                sharePointPath: "/sites/FlightOps/Shared Documents/Schedules/Flight_Schedule_August.xlsx",
                size: 2048000,
                lastModified: Date(),
                createdBy: "Flight Operations",
                fileType: .excel
            ),
            AuthenticatedExcelFile(
                id: UUID(),
                name: "Crew_Roster_Current.xlsx",
                sharePointPath: "/sites/FlightOps/Shared Documents/Crew/Crew_Roster_Current.xlsx",
                size: 1024000,
                lastModified: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                createdBy: "HR Department",
                fileType: .excel
            ),
            AuthenticatedExcelFile(
                id: UUID(),
                name: "Aircraft_Maintenance_Log.csv",
                sharePointPath: "/sites/Maintenance/Shared Documents/Aircraft_Maintenance_Log.csv",
                size: 512000,
                lastModified: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
                createdBy: "Maintenance Team",
                fileType: .csv
            )
        ]
    }
    
    private func performAuthenticatedDownload(_ file: AuthenticatedExcelFile) async throws -> URL {
        // In production, this would:
        // 1. Use authenticated HTTP requests with Bearer token
        // 2. Download from SharePoint/OneDrive API
        // 3. Handle large file downloads with progress
        
        let localFileName = "\(UUID().uuidString)_\(file.name)"
        let localURL = teamsDirectory.appendingPathComponent(localFileName)
        
        // Mock download
        let mockData = generateMockExcelData()
        try mockData.write(to: localURL)
        
        return localURL
    }
    
    private func generateMockExcelData() -> Data {
        let csvContent = """
        Date,Flight,Aircraft,Captain,First Officer,Route,Block Time
        2024-08-16,JUS123,N123AB,John Smith,Jane Doe,DFW-ORD,2:15
        2024-08-16,JUS124,N124CD,Bob Brown,Alice Green,ORD-LAX,3:45
        2024-08-17,JUS125,N125EF,Tom Wilson,Sarah Davis,LAX-DFW,3:30
        """
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func setupDirectories() {
        if !fileManager.fileExists(atPath: teamsDirectory.path) {
            try? fileManager.createDirectory(at: teamsDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func saveCredentials() {
        // In production, use Keychain for secure storage
        if let creds = credentials {
            let savedCreds = [
                "username": creds.username,
                "domain": creds.domain,
                "tenantId": creds.tenantId ?? "",
                "isAuthenticated": "true"
            ]
            UserDefaults.standard.set(savedCreds, forKey: "teams_credentials")
            UserDefaults.standard.synchronize()
            print("💾 Saved Teams credentials for \(creds.username)")
        }
    }
    
    private func loadSavedCredentials() {
        if let savedCreds = UserDefaults.standard.dictionary(forKey: "teams_credentials") as? [String: String],
           let username = savedCreds["username"],
           let domain = savedCreds["domain"],
           savedCreds["isAuthenticated"] == "true" {
            
            // Auto-restore session (in production, would validate token)
            credentials = TeamsCredentials(
                username: username,
                password: "", // Don't save passwords
                domain: domain,
                tenantId: savedCreds["tenantId"]
            )
            
            isAuthenticated = true
            currentUser = username
            
            // Load files automatically
            Task {
                await loadAvailableFiles()
            }
            
            print("🔄 Restored Teams session for \(username)")
        }
    }
    
    private func saveDownloadedFilesList() {
        if let data = try? JSONEncoder().encode(downloadedFiles) {
            UserDefaults.standard.set(data, forKey: "teams_downloaded_files")
        }
    }
    
    private func loadDownloadedFiles() {
        if let data = UserDefaults.standard.data(forKey: "teams_downloaded_files"),
           let files = try? JSONDecoder().decode([AuthenticatedExcelFile].self, from: data) {
            
            // Verify files still exist on disk
            downloadedFiles = files.filter { file in
                guard let localPath = file.localPath else { return false }
                let fileURL = teamsDirectory.appendingPathComponent(localPath)
                return fileManager.fileExists(atPath: fileURL.path)
            }
            
            if downloadedFiles.count != files.count {
                saveDownloadedFilesList()
            }
        }
    }
}

// MARK: - Supporting Views

struct TeamsLoginCard: View {
    @ObservedObject var authManager: TeamsAuthManager
    let onSuccess: () -> Void
    
    @State private var username = ""
    @State private var password = ""
    @State private var domain = ""
    @State private var tenantId = ""
    @State private var rememberCredentials = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
                Text("Company Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username/Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("pilot@yourairline.com", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company Domain (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("yourairline.sharepoint.com", text: $domain)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    Text("💡 Only needed if your company requires it")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tenant ID (Usually Not Needed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Leave blank unless required", text: $tenantId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    Text("💡 Most companies don't require this")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Toggle("Remember me", isOn: $rememberCredentials)
                    .foregroundColor(.white)
            }
            
            Button(action: {
                Task {
                    await authManager.signIn(
                        username: username,
                        password: password,
                        domain: domain,
                        tenantId: tenantId
                    )
                    
                    if authManager.isAuthenticated {
                        onSuccess()
                    }
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    Text(authManager.isLoading ? "Signing In..." : "Sign In")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            
            // Demo credentials button
            Button("Use Demo Credentials") {
                username = "pilot@usajet.com"
                password = "demo123"
                domain = "usajet.sharepoint.com"
                tenantId = ""
            }
            .font(.caption)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct TeamsBrowseFileCard: View {
    let file: AuthenticatedExcelFile
    @ObservedObject var authManager: TeamsAuthManager
    let onAction: (TeamsFileAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: file.fileType.icon)
                    .foregroundColor(file.fileType.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        Text("•")
                        Text("Modified \(file.lastModified, style: .date)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("Created by \(file.createdBy)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("📱 View Online") {
                    onAction(.viewOnline)
                }
                .buttonStyle(TeamsSecondaryButtonStyle())
                
                Button("💾 Download") {
                    onAction(.download)
                }
                .buttonStyle(TeamsPrimaryButtonStyle())
                
                Button("📊 Parse") {
                    onAction(.parseNative)
                }
                .buttonStyle(TeamsSpecialButtonStyle())
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct TeamsLibraryFileCard: View {
    let file: AuthenticatedExcelFile
    let onAction: (DownloadedFileAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: file.fileType.icon)
                    .foregroundColor(file.fileType.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        Text("•")
                        if let downloadDate = file.downloadDate {
                            Text("Downloaded \(downloadDate, style: .date)")
                        }
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
                Button("📱 View Offline") {
                    onAction(.viewOffline)
                }
                .buttonStyle(TeamsSecondaryButtonStyle())
                
                Button("📊 Parse Native") {
                    onAction(.parseNative)
                }
                .buttonStyle(TeamsPrimaryButtonStyle())
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct TeamsSetupHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Need help setting up?")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Contact your IT department for login credentials")
                Text("• Your username is usually your work email")
                Text("• Domain and Tenant ID are optional but may be required")
                Text("• Some companies use single sign-on (SSO)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

struct TeamsEmptyBrowseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Excel Files Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("No Excel files were found in your accessible Teams sites and folders")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct TeamsEmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Downloaded Files")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Download Excel files from 'Browse Files' to access them offline")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct TeamsFileAccessHelpCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
                Text("How file access works:")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Files from Teams sites you have access to")
                Text("• OneDrive for Business files")
                Text("• SharePoint document libraries")
                Text("• Downloaded files work offline")
                Text("• Native parsing shows data in iOS tables")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

// MARK: - Web View Sheet

struct AuthenticatedWebViewSheet: View {
    let file: AuthenticatedExcelFile
    @ObservedObject var authManager: TeamsAuthManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            if let _ = file.localPath,
               let localURL = authManager.getLocalFileURL(for: file) {
                // Offline file
                TeamsOfflineWebView(fileURL: localURL)
                    .navigationTitle(file.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { dismiss() }
                        }
                    }
            } else {
                // Online file - would need authenticated web view
                TeamsOnlineWebView(file: file, authManager: authManager)
                    .navigationTitle(file.name)
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

struct TeamsOfflineWebView: UIViewRepresentable {
    let fileURL: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }
}

struct TeamsOnlineWebView: UIViewRepresentable {
    let file: AuthenticatedExcelFile
    @ObservedObject var authManager: TeamsAuthManager
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // In production, would construct authenticated SharePoint URL
        let sharePointURL = "https://\(authManager.currentDomain ?? "company.sharepoint.com")\(file.sharePointPath)"
        
        if let url = URL(string: sharePointURL) {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Data Models

struct AuthenticatedExcelFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let sharePointPath: String
    let size: Int64
    let lastModified: Date
    let createdBy: String
    let fileType: ExcelFileType
    var localPath: String?
    var downloadDate: Date?
    
    enum ExcelFileType: String, Codable {
        case excel = "xlsx"
        case csv = "csv"
        
        var icon: String {
            switch self {
            case .excel: return "doc.richtext"  // Changed from doc.spreadsheet
            case .csv: return "tablecells"
            }
        }
        
        var color: Color {
            switch self {
            case .excel: return .green
            case .csv: return .blue
            }
        }
    }
}

enum TeamsFileAction {
    case viewOnline
    case download
    case parseNative
}

enum DownloadedFileAction {
    case viewOffline
    case parseNative
    case delete
}

// MARK: - Button Styles

struct TeamsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(LogbookTheme.accentGreen)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct TeamsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(LogbookTheme.navy)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct TeamsSpecialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Note: ExcelDataParser, ExcelWorkbook, and ExcelNativeViewSheet
// are already defined elsewhere in the project

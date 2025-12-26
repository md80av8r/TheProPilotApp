//
//  DataBackupSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/8/25.
//

// DataBackupSettingsView.swift - Complete Import/Export/Sync Settings
import SwiftUI
import UniformTypeIdentifiers

struct DataBackupSettingsView: View {
    @EnvironmentObject var store: SwiftDataLogBookStore
    @StateObject private var cloudSync = CloudKitManager.shared
    
    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var exportedFileURL: URL?
    
    // 🆕 Data Management States
    @State private var showingDeleteConfirmation = false
    @State private var showingDataIntegrityReport = false
    @State private var dataIntegrityReport = ""
    @State private var showingRecoveryOptions = false
    @State private var forceReplaceMode = false  // 🔥 NEW: Flag for force-replace imports
    @State private var showingImportModeChoice = false  // 🔥 NEW: Show merge vs replace choice
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // CloudKit Status Banner (if there are issues)
                    CloudKitStatusBanner()
                    
                    // iCloud Sync Section
                    iCloudSyncSection
                    
                    // Local Backup Section
                    localBackupSection
                    
                    // 🆕 Data Management Section (NEW)
                    dataManagementSection
                    
                    // About Section
                    aboutSection
                }
                .padding()
            }
        }
        .navigationTitle("Data & Backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedFileURL {
                ActivityView(items: [url])
            }
        }
        .sheet(isPresented: $showingDataIntegrityReport) {
            DataIntegrityReportView(report: dataIntegrityReport)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("Delete All Trip Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                deleteAllTripData()
            }
        } message: {
            Text("This will permanently delete all \(store.trips.count) trips from your device. This action cannot be undone!\n\nMake sure you have a backup first.")
        }
        .alert("Import Mode", isPresented: $showingImportModeChoice) {
            Button("Cancel", role: .cancel) {}
            Button("Merge with Existing") {
                forceReplaceMode = false
                showingImportPicker = true
            }
            Button("Replace All", role: .destructive) {
                forceReplaceMode = true
                showingImportPicker = true
            }
        } message: {
            Text("Merge: Add new trips from backup (keeps existing trips)\n\nReplace: Delete all current trips and restore from backup")
        }
    }
    
    // MARK: - iCloud Sync Section
    
    private var iCloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: cloudSync.iCloudAvailable ? "icloud" : "icloud.slash")
                    .font(.title2)
                    .foregroundColor(cloudSync.iCloudAvailable ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(cloudSync.iCloudAvailable ? "Connected & Active" : "Not Available")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status badge
                syncStatusBadge
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Last sync info
            if let lastSync = cloudSync.lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text("Last synced: \(timeAgo(lastSync))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Sync actions
            if cloudSync.iCloudAvailable {
                VStack(spacing: 12) {
                    // Manual sync button
                    Button {
                        Task {
                            await store.syncFromCloud()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(10)
                    }
                    
                    // Upload all button
                    Button {
                        Task {
                            await uploadAllTrips()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Upload All Trips to iCloud")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LogbookTheme.accentGreen)
                        .cornerRadius(10)
                    }
                }
            } else {
                // Not signed in
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in to iCloud to enable automatic sync across devices")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private var syncStatusBadge: some View {
        Text(cloudSync.syncStatus)
            .font(.caption.weight(.medium))
            .foregroundColor(cloudSync.iCloudAvailable ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)
    }
    
    // MARK: - Local Backup Section
    
    private var localBackupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.on.doc")
                    .font(.title2)
                    .foregroundColor(LogbookTheme.accentOrange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Backup")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Import/Export JSON files")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Trip count
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.gray)
                Text("\(store.trips.count) trips in logbook")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Actions
            VStack(spacing: 12) {
                // Import button
                Button {
                    forceReplaceMode = false
                    showingImportModeChoice = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Flight Data")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(10)
                }
                
                // Import from text button (alternative method)
                Button {
                    importFromPasteboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Import from Clipboard")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentBlue.opacity(0.8))
                    .cornerRadius(10)
                }
                
                // Export button
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Flight Data")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentGreen)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Advanced Tools")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Troubleshooting & data recovery")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                // CloudKit Advanced Settings
                NavigationLink(destination: CloudKitSettingsView()) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                        Text("iCloud Sync Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(10)
                }
                
                // Data Integrity Check
                Button {
                    runDataIntegrityCheck()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield")
                        Text("Check Data Health")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan.opacity(0.8))
                    .cornerRadius(10)
                }
                
                // Data Recovery
                Button {
                    attemptDataRecovery()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Recover Data")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(10)
                }
            }
            
            // Help text
            Text("💡 Use 'iCloud Sync Settings' to manage CloudKit sync and resolve conflicts")
                .font(.caption2)
                .foregroundColor(.cyan)
                .padding(.top, 4)
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Data Sync")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                DataBackupInfoRow(
                    icon: "icloud",
                    title: "Automatic Sync",
                    description: "Trips sync automatically to iCloud when connected"
                )
                
                DataBackupInfoRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Multi-Device",
                    description: "Access your logbook on iPhone, iPad, and Mac"
                )
                
                DataBackupInfoRow(
                    icon: "lock.shield",
                    title: "Private & Secure",
                    description: "Data stored in your personal iCloud account"
                )
                
                DataBackupInfoRow(
                    icon: "doc.text",
                    title: "JSON Export",
                    description: "Export to standard JSON format for backup"
                )
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func uploadAllTrips() async {
        for trip in store.trips {
            do {
                try await CloudKitManager.shared.saveTrip(trip)
            } catch {
                print("❌ Failed to upload trip \(trip.tripNumber): \(error)")
            }
        }
        
        alertTitle = "Upload Complete"
        alertMessage = "Successfully uploaded \(store.trips.count) trips to iCloud"
        showingAlert = true
    }
    
    private func importFromPasteboard() {
        print("📋 Clipboard import started")
        
        guard let pasteboardString = UIPasteboard.general.string else {
            print("❌ No string in pasteboard")
            alertTitle = "No Data Found"
            alertMessage = "No text found in clipboard. Copy your JSON export file content first."
            showingAlert = true
            return
        }
        
        print("✅ Clipboard contains string: \(pasteboardString.count) characters")
        print("📄 Preview (first 100 chars): \(String(pasteboardString.prefix(100)))...")
        
        guard let data = pasteboardString.data(using: .utf8) else {
            print("❌ Failed to convert string to UTF-8 data")
            alertTitle = "Invalid Format"
            alertMessage = "Unable to convert clipboard text to data"
            showingAlert = true
            return
        }
        
        print("✅ Converted to data: \(data.count) bytes")
        
        print("🔄 Calling store.importFromJSON...")
        let result = store.importFromJSON(data)
        print("📊 Import result: success=\(result.success), message=\(result.message)")
        
        alertTitle = result.success ? "Import Successful" : "Import Failed"
        alertMessage = result.message
        showingAlert = true
        
        print("🏁 Clipboard import completed")
    }
    
    private func exportData() {
        guard let data = store.exportToJSON() else {
            alertTitle = "Export Failed"
            alertMessage = "Unable to export flight data"
            showingAlert = true
            return
        }
        
        // 🧪 DEBUG: Show full JSON in console
        if let jsonString = String(data: data, encoding: .utf8) {
            let separator = String(repeating: "=", count: 60)
            print("\n" + separator)
            print("📄 FULL EXPORTED JSON:")
            print(separator)
            if jsonString.count < 10000 {
                print(jsonString)
            } else {
                print("First 2000 chars:")
                print(String(jsonString.prefix(2000)))
                print("\n... (\(jsonString.count - 4000) chars omitted) ...\n")
                print("Last 2000 chars:")
                print(String(jsonString.suffix(2000)))
            }
            print(separator + "\n")
        }
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: Date())
        let fileName = "TheProPilotApp_Export_\(dateString).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            exportedFileURL = tempURL
            showingExportSheet = true
        } catch {
            alertTitle = "Export Failed"
            alertMessage = "Error: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        print("🔍 Import Debug: handleImportResult called")
        
        switch result {
        case .success(let urls):
            print("✅ File picker success - URLs count: \(urls.count)")
            
            guard let url = urls.first else {
                print("❌ No URL in array")
                return
            }
            
            print("📁 Selected URL: \(url)")
            print("📁 URL path: \(url.path)")
            print("📁 URL isFileURL: \(url.isFileURL)")
            
            // 🔐 Start accessing security-scoped resource
            let didStartAccess = url.startAccessingSecurityScopedResource()
            print("🔐 Security-scoped access: \(didStartAccess ? "✅ Success" : "❌ Failed")")
            
            guard didStartAccess else {
                alertTitle = "Permission Denied"
                alertMessage = "Unable to access the selected file. Please ensure the file is accessible and try again."
                showingAlert = true
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
                print("🔐 Stopped accessing security-scoped resource")
            }
            
            do {
                // Check file existence
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                print("📂 File exists at path: \(fileExists ? "✅ Yes" : "❌ No")")
                
                // Check file attributes
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                    print("📊 File size: \(attributes[.size] ?? "unknown") bytes")
                    print("📊 File type: \(attributes[.type] ?? "unknown")")
                }
                
                // Copy file to temp directory first (works around iCloud/sandbox issues)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
                print("📋 Temp URL: \(tempURL.path)")
                
                print("📤 Attempting to copy file...")
                try FileManager.default.copyItem(at: url, to: tempURL)
                print("✅ File copied successfully")
                
                // Check temp file
                let tempExists = FileManager.default.fileExists(atPath: tempURL.path)
                print("📂 Temp file exists: \(tempExists ? "✅ Yes" : "❌ No")")
                
                if let tempAttributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path) {
                    print("📊 Temp file size: \(tempAttributes[.size] ?? "unknown") bytes")
                }
                
                // Read from temp copy
                print("📖 Reading data from temp file...")
                let data = try Data(contentsOf: tempURL)
                print("✅ Data read successfully - size: \(data.count) bytes")
                
                // Preview first 100 chars
                if let preview = String(data: data.prefix(100), encoding: .utf8) {
                    print("📄 Data preview: \(preview)...")
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                print("🗑️ Temp file removed")
                
                // Import the data
                print("🔄 Calling store.importFromJSON...")
                print("   Mode: \(forceReplaceMode ? "REPLACE ALL" : "MERGE")")
                let result = store.importFromJSON(data, mergeWithExisting: !forceReplaceMode)
                print("📊 Import result: success=\(result.success), message=\(result.message)")
                
                alertTitle = result.success ? "Import Successful" : "Import Failed"
                alertMessage = result.message
                showingAlert = true
                
            } catch let error as NSError {
                print("❌ Error occurred:")
                print("   Domain: \(error.domain)")
                print("   Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                print("   UserInfo: \(error.userInfo)")
                
                alertTitle = "Import Failed"
                if error.domain == NSCocoaErrorDomain && error.code == 260 {
                    alertMessage = "File not found. If importing from iCloud, please ensure the file is downloaded first (tap to download in Files app)."
                } else if error.domain == NSCocoaErrorDomain && error.code == 4 {
                    alertMessage = "File format error. Please ensure you're importing a valid ProPilot backup file."
                } else {
                    alertMessage = "Error: \(error.localizedDescription) (Code: \(error.code))"
                }
                showingAlert = true
            }
            
        case .failure(let error):
            print("❌ File picker failure: \(error.localizedDescription)")
            alertTitle = "Import Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        print("🏁 Import process completed")
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    
    // MARK: - 🆕 Data Management Functions
    
    private func runDataIntegrityCheck() {
        var report = "🔍 DATA INTEGRITY CHECK\n"
        report += "═══════════════════════════════════\n\n"
        
        var totalTrips = 0
        var totalLegs = 0
        var tripsWithZeroLegs = 0
        var legsMissingScheduledOut = 0
        var legsMissingScheduledIn = 0
        var legsMissingRosterId = 0
        
        for trip in store.trips {
            totalTrips += 1
            
            if trip.legs.isEmpty {
                tripsWithZeroLegs += 1
                report += "🚨 Trip #\(trip.tripNumber): ZERO LEGS\n"
                report += "   Logpages: \(trip.logpages.count)\n"
                for (idx, page) in trip.logpages.enumerated() {
                    report += "   Logpage \(idx+1): \(page.legs.count) legs\n"
                }
                report += "\n"
                continue
            }
            
            for leg in trip.legs {
                totalLegs += 1
                if leg.scheduledOut == nil { legsMissingScheduledOut += 1 }
                if leg.scheduledIn == nil { legsMissingScheduledIn += 1 }
                if leg.rosterSourceId == nil { legsMissingRosterId += 1 }
            }
        }
        
        report += "───────────────────────────────────\n"
        report += "📊 SUMMARY\n"
        report += "───────────────────────────────────\n"
        report += "Total Trips: \(totalTrips)\n"
        report += "Total Legs: \(totalLegs)\n"
        report += "🚨 Trips with ZERO legs: \(tripsWithZeroLegs)\n"
        report += "❌ Legs missing scheduled OUT: \(legsMissingScheduledOut)\n"
        report += "❌ Legs missing scheduled IN: \(legsMissingScheduledIn)\n"
        report += "❌ Legs missing roster ID: \(legsMissingRosterId)\n\n"
        
        if tripsWithZeroLegs > 0 {
            report += "🚨 CRITICAL ISSUES FOUND!\n\n"
            report += "Recommendations:\n"
            report += "1. Try 'Attempt Data Recovery' first\n"
            report += "2. If that fails, use 'Force Import (Replace All)'\n"
            report += "   with your most recent backup file\n"
        } else if legsMissingScheduledOut > 0 || legsMissingScheduledIn > 0 {
            report += "⚠️ Data quality issues detected.\n\n"
            report += "These may be legacy trips created before\n"
            report += "scheduled time tracking was added.\n"
        } else {
            report += "✅ All data looks good!\n"
        }
        
        dataIntegrityReport = report
        showingDataIntegrityReport = true
    }
    
    private func attemptDataRecovery() {
        let beforeCount = store.trips.filter { $0.legs.isEmpty }.count
        
        if beforeCount == 0 {
            alertTitle = "No Recovery Needed"
            alertMessage = "All trips have leg data. No recovery necessary."
            showingAlert = true
            return
        }
        
        // Force reload from disk with improved decode logic
        store.loadWithRecovery()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterCount = store.trips.filter { $0.legs.isEmpty }.count
            
            if afterCount == 0 {
                alertTitle = "Recovery Successful! 🎉"
                alertMessage = "Successfully recovered \(beforeCount) trips with zero legs."
            } else if afterCount < beforeCount {
                alertTitle = "Partial Recovery"
                alertMessage = "Recovered \(beforeCount - afterCount) of \(beforeCount) corrupted trips. \(afterCount) trips still need attention - try importing from a backup."
            } else {
                alertTitle = "Recovery Failed"
                alertMessage = "Unable to recover trips automatically. Please use 'Force Import (Replace All)' with a backup file that contains the complete trip data."
            }
            showingAlert = true
        }
    }
    
    private func deleteAllTripData() {
        let count = store.trips.count
        store.trips.removeAll()
        store.save()
        
        alertTitle = "Data Deleted"
        alertMessage = "Successfully deleted all \(count) trips from this device."
        showingAlert = true
    }
}

// MARK: - 🆕 Data Integrity Report View

struct DataIntegrityReportView: View {
    let report: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    Text(report)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .navigationTitle("Data Integrity Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Info Row Component

struct DataBackupInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Activity View for Share Sheet

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

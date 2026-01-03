//
//  CloudKitDiagnosticView.swift
//  TheProPilotApp
//
//  CloudKit connectivity and database diagnostic tool
//

import SwiftUI
import CloudKit

struct CloudKitDiagnosticView: View {
    @StateObject private var diagnostic = CloudKitDiagnostic()
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerCard
                    
                    // Test Results
                    if diagnostic.isRunning {
                        loadingView
                    } else if !diagnostic.testResults.isEmpty {
                        resultsSection
                    } else {
                        placeholderView
                    }
                    
                    // Actions
                    actionButtons
                }
                .padding()
            }
        }
        .navigationTitle("CloudKit Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if diagnostic.testResults.isEmpty {
                Task {
                    await diagnostic.runAllTests()
                }
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
                
                Text("CloudKit Diagnostic")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Tests iCloud connectivity, account status, and database access for ProPilot App.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Running tests...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(diagnostic.currentTest)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary
            HStack {
                Text("Test Results")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                summaryBadge
            }
            .padding(.horizontal)
            
            // Individual test results
            ForEach(diagnostic.testResults) { result in
                TestResultCard(result: result)
            }
        }
    }
    
    private var summaryBadge: some View {
        let passedCount = diagnostic.testResults.filter { $0.passed }.count
        let totalCount = diagnostic.testResults.count
        let allPassed = passedCount == totalCount
        
        return HStack(spacing: 4) {
            Image(systemName: allPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(allPassed ? .green : .orange)
            
            Text("\(passedCount)/\(totalCount)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(allPassed ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Ready to Test")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Tap 'Run Tests' to check CloudKit connectivity")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Download Airport Database button
            Button(action: {
                Task {
                    await diagnostic.downloadAirportDatabase()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("Download Airport Database")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentGreen)
                .cornerRadius(16)
            }
            .disabled(diagnostic.isRunning)
            
            // Run tests button
            Button(action: {
                Task {
                    await diagnostic.runAllTests()
                }
            }) {
                HStack(spacing: 12) {
                    if diagnostic.isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Text(diagnostic.isRunning ? "Testing..." : "Run Tests")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(diagnostic.isRunning ? Color.gray : LogbookTheme.accentBlue)
                .cornerRadius(16)
            }
            .disabled(diagnostic.isRunning)
            
            // Test airport lookup button
            Button(action: {
                Task {
                    await diagnostic.testAirportLookup()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Test Airport Lookup (Any Airport)")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LogbookTheme.accentGreen.opacity(0.8))
                .cornerRadius(16)
            }
            .disabled(diagnostic.isRunning)
            
            // Reset Airport Database button (troubleshooting)
            Button(action: {
                Task {
                    await diagnostic.resetAirportDatabase()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Airport Database")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.8))
                .cornerRadius(16)
            }
            .disabled(diagnostic.isRunning)
        }
    }
}

// MARK: - Test Result Card

struct TestResultCard: View {
    let result: DiagnosticTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(result.passed ? .green : .red)
                
                Text(result.testName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Message
            Text(result.message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            // Details (if any)
            if !result.details.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.details, id: \.self) { detail in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(result.passed ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Diagnostic Test Result Model

struct DiagnosticTestResult: Identifiable {
    let id = UUID()
    let testName: String
    let passed: Bool
    let message: String
    let details: [String]
}

// MARK: - CloudKit Diagnostic Manager

@MainActor
class CloudKitDiagnostic: ObservableObject {
    @Published var testResults: [DiagnosticTestResult] = []
    @Published var isRunning = false
    @Published var currentTest = ""
    
    private let container = CKContainer(identifier: "iCloud.com.jkadans.TheProPilotApp")
    
    // MARK: - Run All Tests
    
    func runAllTests() async {
        testResults = []
        isRunning = true
        
        // Test 1: iCloud Account Status
        await testiCloudAccountStatus()
        
        // Test 2: Container Access
        await testContainerAccess()
        
        // Test 3: Database Access
        await testDatabaseAccess()
        
        // Test 4: Airport Database (Public)
        await testPublicAirportDatabase()
        
        isRunning = false
        currentTest = ""
    }
    
    // MARK: - Test 1: iCloud Account Status
    
    private func testiCloudAccountStatus() async {
        currentTest = "Checking iCloud account..."
        
        do {
            let status = try await CKContainer.default().accountStatus()
            
            switch status {
            case .available:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: true,
                    message: "✅ iCloud account available",
                    details: ["User is signed in to iCloud", "CloudKit services accessible"]
                ))
                
            case .noAccount:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: false,
                    message: "❌ No iCloud account",
                    details: [
                        "User is not signed in to iCloud",
                        "Open Settings → Sign in to your iPhone",
                        "Make sure iCloud Drive is enabled"
                    ]
                ))
                
            case .restricted:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: false,
                    message: "❌ iCloud restricted",
                    details: [
                        "iCloud access is restricted on this device",
                        "Check parental controls or MDM restrictions"
                    ]
                ))
                
            case .couldNotDetermine:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: false,
                    message: "⚠️ iCloud status unknown",
                    details: ["Unable to determine iCloud status"]
                ))
                
            case .temporarilyUnavailable:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: false,
                    message: "⚠️ iCloud temporarily unavailable",
                    details: [
                        "iCloud services are temporarily unavailable",
                        "Check your internet connection",
                        "Try again in a few moments"
                    ]
                ))
                
            @unknown default:
                testResults.append(DiagnosticTestResult(
                    testName: "iCloud Account",
                    passed: false,
                    message: "⚠️ Unknown status",
                    details: ["Encountered unknown iCloud status"]
                ))
            }
        } catch {
            testResults.append(DiagnosticTestResult(
                testName: "iCloud Account",
                passed: false,
                message: "❌ Error checking iCloud",
                details: ["Error: \(error.localizedDescription)"]
            ))
        }
    }
    
    // MARK: - Test 2: Container Access
    
    private func testContainerAccess() async {
        currentTest = "Testing container access..."
        
        let containerID = container.containerIdentifier ?? "unknown"
        
        // Try to access container info
        do {
            let userRecordID = try await container.userRecordID()
            
            testResults.append(DiagnosticTestResult(
                testName: "Container Access",
                passed: true,
                message: "✅ Container accessible",
                details: [
                    "Container ID: \(containerID)",
                    "User Record ID: \(userRecordID.recordName)"
                ]
            ))
        } catch {
            testResults.append(DiagnosticTestResult(
                testName: "Container Access",
                passed: false,
                message: "❌ Container access failed",
                details: [
                    "Container ID: \(containerID)",
                    "Error: \(error.localizedDescription)"
                ]
            ))
        }
    }
    
    // MARK: - Test 3: Private Database Access
    
    private func testDatabaseAccess() async {
        currentTest = "Testing private database..."
        
        let privateDB = container.privateCloudDatabase
        
        do {
            // Try to query Trip records
            let query = CKQuery(recordType: "Trip", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDB.records(matching: query)
            
            let tripCount = matchResults.count
            
            testResults.append(DiagnosticTestResult(
                testName: "Private Database",
                passed: true,
                message: "✅ Private database accessible",
                details: [
                    "Found \(tripCount) Trip records",
                    "Database: Private CloudKit Database",
                    tripCount == 0 ? "No trips synced yet (this is normal)" : "Trips are syncing correctly"
                ]
            ))
        } catch let error as CKError {
            testResults.append(DiagnosticTestResult(
                testName: "Private Database",
                passed: false,
                message: "❌ Database access error",
                details: [
                    "CKError code: \(error.code.rawValue)",
                    "Description: \(error.localizedDescription)",
                    error.code == .networkUnavailable ? "Check internet connection" : "",
                    error.code == .notAuthenticated ? "Sign in to iCloud" : ""
                ].filter { !$0.isEmpty }
            ))
        } catch {
            testResults.append(DiagnosticTestResult(
                testName: "Private Database",
                passed: false,
                message: "❌ Database query failed",
                details: ["Error: \(error.localizedDescription)"]
            ))
        }
    }
    
    // MARK: - Test 4: Airport Database (Local)

    private func testPublicAirportDatabase() async {
        currentTest = "Testing airport database..."
        
        // ✅ Check LOCAL database instead of CloudKit
        let allAirports = AirportDatabaseManager.shared.getAllAirports()
        let count = allAirports.count
        
        if count == 0 {
            testResults.append(DiagnosticTestResult(
                testName: "Airport Database",
                passed: false,
                message: "❌ No airports loaded",
                details: [
                    "Local database is empty",
                    "CSV file may be missing",
                    "Tap 'Reset Airport Database' to reload"
                ]
            ))
        } else {
            var airportDetails: [String] = []
            airportDetails.append("✅ Found \(count) airports in local database!")
            airportDetails.append("✅ Source: CSV file (offline-capable)")
            airportDetails.append("")
            airportDetails.append("Sample airports:")
            
            for airport in allAirports.prefix(10) {
                airportDetails.append("• \(airport.icaoCode): \(airport.name)")
            }
            
            if count > 10 {
                airportDetails.append("... and \(count - 10) more")
            }
            
            testResults.append(DiagnosticTestResult(
                testName: "Airport Database",
                passed: true,
                message: "✅ Airport database operational! (\(count) airports)",
                details: airportDetails
            ))
        }
    }
    
    // MARK: - Test Airport Lookup (Standalone)

    func testAirportLookup() async {
        currentTest = "Testing airport lookup..."
        isRunning = true
        
        // ✅ Check LOCAL database (CSV + CloudKit merged)
        let allAirports = AirportDatabaseManager.shared.getAllAirports()
        let count = allAirports.count
        
        if count == 0 {
            testResults.insert(DiagnosticTestResult(
                testName: "Airport Lookup Test",
                passed: false,
                message: "❌ No airports in database",
                details: [
                    "Local database is empty",
                    "Tap 'Reset Airport Database' to reload from CSV"
                ]
            ), at: 0)
        } else {
            var details: [String] = []
            details.append("✅ Found \(count) airports in local database!")
            details.append("✅ Source: CSV file (offline-capable)")
            details.append("")
            details.append("Sample airports:")
            
            // Show first 10 airports
            for airport in allAirports.prefix(10) {
                details.append("• \(airport.icaoCode): \(airport.name)")
            }
            
            if count > 10 {
                details.append("... and \(count - 10) more")
            }
            
            // Test specific airport lookups
            details.append("")
            details.append("Lookup tests:")
            
            let testCodes = ["KDTW", "KLRD", "KPTK", "KYIP"]
            for code in testCodes {
                if let airport = AirportDatabaseManager.shared.getAirport(for: code) {
                    details.append("✅ \(code): \(airport.name)")
                } else {
                    details.append("⚠️ \(code): Not in database")
                }
            }
            
            testResults.insert(DiagnosticTestResult(
                testName: "Airport Lookup Test",
                passed: true,
                message: "✅ Airport database working! (\(count) airports)",
                details: details
            ), at: 0)
        }
        
        isRunning = false
        currentTest = ""
    }
    
    // MARK: - Download Airport Database
    
    func downloadAirportDatabase() async {
        currentTest = "Downloading airport database..."
        isRunning = true
        
        // 1. Get database status BEFORE doing anything
        let status = AirportDatabaseManager.shared.getDatabaseStatus()
        let csvExists = status.csvExists
        let countBefore = status.airportCount
        let cacheStatus = status.cacheStatus
        
        print("📊 Database Status:")
        print("   CSV file exists: \(csvExists)")
        print("   Airports loaded: \(countBefore)")
        print("   Cache status: \(cacheStatus)")
        
        // 2. If CSV exists but no airports loaded, force reload
        if csvExists && countBefore == 0 {
            print("🔄 CSV exists but no airports loaded - forcing reload...")
            await MainActor.run {
                AirportDatabaseManager.shared.forceReloadFromCSV()
            }
            
            // Wait for reload to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // 3. Get count after potential reload
        let countAfterReload = AirportDatabaseManager.shared.getAllAirports().count
        print("📊 Airports after reload: \(countAfterReload)")
        
        // 4. Try to fetch CloudKit updates
        await AirportDatabaseManager.shared.fetchCloudKitUpdates()
        
        // 5. Wait a moment for the fetch to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // 6. Check final count
        let countFinal = AirportDatabaseManager.shared.getAllAirports().count
        print("📊 Airports after CloudKit fetch: \(countFinal)")
        
        let cloudKitAdded = countFinal - countAfterReload
        
        // Prepare detailed results
        var details: [String] = []
        var message: String
        var passed: Bool
        
        // CSV File Status
        if csvExists {
            details.append("✅ CSV file found in bundle")
        } else {
            details.append("❌ CSV file NOT found in bundle")
            details.append("   → Add propilot_airports.csv to Xcode target")
        }
        
        // Initial Load Status
        if countBefore > 0 {
            details.append("✅ Had \(countBefore) airports from cache")
        } else {
            details.append("⚠️ No cached airports on startup")
        }
        
        // Reload Status (if it happened)
        if csvExists && countBefore == 0 && countAfterReload > 0 {
            details.append("✅ Force reload successful: \(countAfterReload) airports")
        } else if csvExists && countBefore == 0 && countAfterReload == 0 {
            details.append("❌ Force reload failed - CSV might be empty or corrupt")
        }
        
        // CloudKit Status
        if cloudKitAdded > 0 {
            details.append("✅ CloudKit added \(cloudKitAdded) airports")
        } else if countAfterReload > 0 {
            details.append("ℹ️ CloudKit added 0 airports (CSV is primary source)")
        } else {
            details.append("⚠️ CloudKit added 0 airports")
            details.append("   → Upload airports to Public Database in CloudKit Dashboard")
        }
        
        // Final Status
        details.append("")
        details.append("Final count: \(countFinal) airports")
        
        // Test passes if we have ANY airports
        if countFinal > 0 {
            passed = true
            message = "✅ Loaded \(countFinal) airports!"
            details.append("✅ App can calculate night hours")
            details.append("✅ Airport data available offline")
        } else {
            passed = false
            message = "❌ No airports loaded"
            details.append("")
            details.append("Troubleshooting:")
            if !csvExists {
                details.append("1. Add propilot_airports.csv to Xcode project")
                details.append("2. Select file → File Inspector → Target Membership")
                details.append("3. Check your app target")
                details.append("4. Build Phases → Copy Bundle Resources")
            } else {
                details.append("1. CSV file exists but failed to load")
                details.append("2. Check console for parsing errors")
                details.append("3. Verify CSV format is correct")
                details.append("4. Try 'Reset Airport Database' button")
            }
        }
        
        testResults.insert(DiagnosticTestResult(
            testName: "Airport Database Download",
            passed: passed,
            message: message,
            details: details
        ), at: 0)
        
        isRunning = false
        currentTest = ""
    }
    
    // MARK: - Reset Airport Database
    
    func resetAirportDatabase() async {
        currentTest = "Resetting airport database..."
        isRunning = true
        
        print("🔄 Resetting airport database...")
        
        // Reset the database manager
        await MainActor.run {
            AirportDatabaseManager.shared.resetDatabase()
        }
        
        // Give it a moment to reload
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Check results
        let count = AirportDatabaseManager.shared.getAllAirports().count
        let csvExists = Bundle.main.url(forResource: "propilot_airports", withExtension: "csv") != nil
        
        var details: [String] = []
        
        if csvExists {
            details.append("✅ CSV file found in bundle")
        } else {
            details.append("❌ CSV file NOT found in bundle")
            details.append("⚠️ Add propilot_airports.csv to Xcode target")
        }
        
        details.append("Airports loaded: \(count)")
        
        if count > 0 {
            details.append("✅ Database successfully reset and reloaded")
        } else {
            details.append("❌ Database reset but no airports loaded")
            details.append("Check console logs for errors")
        }
        
        testResults.insert(DiagnosticTestResult(
            testName: "Airport Database Reset",
            passed: count > 0,
            message: count > 0 ? "✅ Reset complete! Loaded \(count) airports" : "❌ Reset failed - no airports loaded",
            details: details
        ), at: 0)
        
        isRunning = false
        currentTest = ""
    }
}

// MARK: - Preview

struct CloudKitDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CloudKitDiagnosticView()
        }
    }
}

// MARK: - Alias for Legacy Code

/// Alias for backward compatibility - AirportManagementView now shows CloudKit diagnostics
typealias AirportManagementView = CloudKitDiagnosticView


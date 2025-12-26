//
//  SettingsIntegration.swift
//  TheProPilotApp
//
//  Created December 2025
//  How to integrate the diagnostic view into your settings/more menu
//

import SwiftUI

// MARK: - Option 1: Add to More Tab

/**
 Add this to your MoreTabView.swift or SettingsView.swift:
 */

struct MoreTabView_WithDiagnostics: View {
    @State private var showDiagnostics = false
    
    var body: some View {
        List {
            // ... your existing settings sections
            
            Section("Developer Tools") {
                Button(action: { showDiagnostics = true }) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CloudKit Diagnostics")
                                .foregroundColor(.white)
                            
                            Text("Test database connectivity")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                CloudKitDiagnosticView()
            }
        }
    }
}

// MARK: - Option 2: Hidden Developer Menu

/**
 Add a hidden developer menu (tap version number 5 times):
 */

struct SettingsView_WithHiddenDiagnostics: View {
    @State private var tapCount = 0
    @State private var showDiagnostics = false
    
    var body: some View {
        List {
            // ... existing sections
            
            Section {
                // App version - tap 5 times to show diagnostics
                Button(action: handleVersionTap) {
                    HStack {
                        Text("Version")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("1.0.2")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                CloudKitDiagnosticView()
            }
        }
        .alert("Developer Mode", isPresented: .constant(tapCount >= 5 && !showDiagnostics)) {
            Button("Open Diagnostics") {
                showDiagnostics = true
                tapCount = 0
            }
            Button("Cancel") {
                tapCount = 0
            }
        } message: {
            Text("You've unlocked developer diagnostics!")
        }
    }
    
    private func handleVersionTap() {
        tapCount += 1
        
        // Reset after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            if tapCount < 5 {
                tapCount = 0
            }
        }
    }
}

// MARK: - Option 3: Direct Navigation Link

/**
 Simple navigation link in settings:
 */

struct SettingsView_DirectLink: View {
    var body: some View {
        List {
            Section("Advanced") {
                NavigationLink(destination: CloudKitDiagnosticView()) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("System Diagnostics")
                    }
                }
            }
        }
    }
}

// MARK: - Option 4: Standalone Developer Tab (Debug Only)

/**
 Add a separate tab (can hide in production builds):
 */

struct MainTabView_WithDeveloperTab: View {
    var body: some View {
        TabView {
            // ... existing tabs
            
            #if DEBUG
            NavigationStack {
                CloudKitDiagnosticView()
            }
            .tabItem {
                Label("Debug", systemImage: "hammer.fill")
            }
            #endif
        }
    }
}

// MARK: - Option 5: Gesture-Based Access

/**
 Access diagnostics with a special gesture (triple tap):
 */

struct ContentView_WithGestureAccess: View {
    @State private var showDiagnostics = false
    @State private var tapCount = 0
    
    var body: some View {
        YourMainContent()
            .onTapGesture {
                tapCount += 1
                
                if tapCount >= 3 {
                    showDiagnostics = true
                    tapCount = 0
                }
                
                // Reset tap count after delay
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    tapCount = 0
                }
            }
            .sheet(isPresented: $showDiagnostics) {
                NavigationStack {
                    CloudKitDiagnosticView()
                }
            }
    }
    
    @ViewBuilder
    private func YourMainContent() -> some View {
        // Your main content here
        Text("Main Content")
    }
}

// MARK: - Recommended Integration

/**
 ✅ RECOMMENDED: Add to Airport Database Settings (Already Implemented!)
 
 The new AirportDatabaseView already has a settings button that opens
 CloudKitDiagnosticView. This is the cleanest integration because:
 
 1. Users can access it when they need to debug airport database
 2. It's contextually relevant (testing the database)
 3. It's not cluttering the main settings
 4. It's easily discoverable (gear icon in airport view)
 
 No additional code needed - it's already in AirportDatabaseView.swift!
 */

// MARK: - Additional: Add Test Shortcuts

/**
 NOTE: To add quick test buttons to CloudKitDiagnosticView, 
 add them directly inside CloudKitDiagnosticView.swift.
 
 Example code to add in CloudKitDiagnosticView body:
 
 Section("Quick Tests") {
     Button(action: {
         Task {
             let kdtw = AirportDatabaseManager.shared.getAirport(for: "KDTW")
             print("KDTW: \(kdtw?.name ?? "Not found")")
         }
     }) {
         Label("Test KDTW Airport", systemImage: "airplane.circle")
     }
     
     Button(action: {
         Task {
             await diagnostic.testContainerAccess()
         }
     }) {
         Label("Test CloudKit", systemImage: "icloud")
     }
 }
 */

// MARK: - Usage Examples

/**
 Example 1: Add to existing MoreTabView
 
 1. Open MoreTabView.swift
 2. Add @State private var showDiagnostics = false
 3. Add button to your list:
 
    Button("System Diagnostics") {
        showDiagnostics = true
    }
 
 4. Add sheet modifier:
 
    .sheet(isPresented: $showDiagnostics) {
        NavigationStack {
            CloudKitDiagnosticView()
        }
    }
 */

/**
 Example 2: Add to Settings gear menu
 
 1. Find your settings view
 2. Add a new section:
 
    Section("Developer") {
        NavigationLink("CloudKit Diagnostics") {
            CloudKitDiagnosticView()
        }
    }
 */

/**
 Example 3: Keep it in Airport Database only (Current Implementation)
 
 No code needed! Users can access diagnostics by:
 1. Opening Airport Database tab
 2. Tapping gear icon in top right
 3. Running all tests
 
 This is the recommended approach ✅
 */

// MARK: - Integration with Existing Settings

/**
 If you want to add diagnostics to your existing SettingsView.swift,
 here's a complete example section you can copy-paste:
 */

struct SettingsView_DiagnosticsSection: View {
    @State private var showDiagnostics = false
    
    var diagnosticsSection: some View {
        Section {
            Button(action: { showDiagnostics = true }) {
                HStack {
                    Image(systemName: "stethoscope")
                        .foregroundColor(LogbookTheme.accentBlue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Diagnostics")
                            .foregroundColor(.white)
                        
                        Text("CloudKit & Database Tests")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Developer Tools")
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                CloudKitDiagnosticView()
            }
        }
    }
    
    var body: some View {
        List {
            // Add this section to your existing settings
            diagnosticsSection
        }
    }
}

// MARK: - Conditional Display (Show only in Debug builds)

/**
 To only show diagnostics in DEBUG builds:
 */

struct SettingsView_DebugOnly: View {
    @State private var showDiagnostics = false
    
    var body: some View {
        List {
            // ... your existing sections
            
            #if DEBUG
            Section("Developer") {
                Button("CloudKit Diagnostics") {
                    showDiagnostics = true
                }
            }
            #endif
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                CloudKitDiagnosticView()
            }
        }
    }
}

// MARK: - Advanced: Add to Main Tab Bar (Conditional)

/**
 Add diagnostics as a conditional tab in your main TabView:
 */

struct MainTabView_ConditionalDiagnostics: View {
    @AppStorage("showDeveloperTab") private var showDeveloperTab = false
    
    var body: some View {
        TabView {
            // Your existing tabs...
            
            // Logbook Tab
            Text("Logbook")
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
            
            // Airport Database Tab
            NavigationStack {
                AirportDatabaseView()
            }
            .tabItem {
                Label("Airports", systemImage: "airplane")
            }
            
            // More Tab
            Text("More")
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
            
            // Developer Tab (conditional)
            if showDeveloperTab {
                NavigationStack {
                    CloudKitDiagnosticView()
                }
                .tabItem {
                    Label("Debug", systemImage: "hammer.fill")
                }
            }
        }
    }
}

// MARK: - Notes

/**
 IMPORTANT NOTES:
 
 1. LogbookTheme - Make sure you have access to LogbookTheme colors
 2. CloudKitDiagnostic - The diagnostic class must be imported
 3. AirportDatabaseManager - Required for airport tests
 
 BEST PRACTICES:
 
 1. ✅ Keep diagnostics accessible but not obtrusive
 2. ✅ Use conditional compilation (#if DEBUG) for development-only features
 3. ✅ Provide clear labeling and help text
 4. ✅ Consider user experience - don't overwhelm settings
 5. ✅ Use existing patterns in your app for consistency
 
 CURRENT STATE:
 
 The CloudKit diagnostic tool is already integrated into AirportDatabaseView
 via the gear icon in the top right. This provides contextual access right
 where users might need it most - when working with airport data.
 
 You can optionally add it to other locations using the examples above!
 */

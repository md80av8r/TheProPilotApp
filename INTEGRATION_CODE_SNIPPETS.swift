/*
 
 ═══════════════════════════════════════════════════════════════════════
 SEARCH & HELP INTEGRATION CODE SNIPPETS
 ═══════════════════════════════════════════════════════════════════════
 
 This file contains code snippets to copy into your ContentView.swift
 All code is commented to prevent compilation errors
 
 Follow the 3 steps below to integrate search functionality
 
 ═══════════════════════════════════════════════════════════════════════
 STEP 1: ADD STATE VARIABLE
 ═══════════════════════════════════════════════════════════════════════
 
 Location: ContentView.swift, line ~67 (with other @State variables)
 
 Add this line:
 
    @State private var showSearch = false  // ✅ NEW: Search sheet
 
 
 ═══════════════════════════════════════════════════════════════════════
 STEP 2: ADD SEARCH BUTTON TO LOGBOOK HEADER
 ═══════════════════════════════════════════════════════════════════════
 
 Location: ContentView.swift, line ~916-938 (logbook header HStack)
 Find: "// MARK: - Header Section with Zulu Clock & Weather Toggle"
 
 REPLACE the existing HStack with this version that includes search:
 
    HStack(alignment: .center) {
        ZuluClockView()
        
        Spacer()
        
        // ✅ NEW: Search button
        Button(action: {
            showSearch = true
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.clear)
                )
        }
        .padding(.trailing, 8)
        
        // Weather Toggle Button (existing)
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                showingWeatherBanner.toggle()
            }
        }) {
            Image(systemName: showingWeatherBanner ? "cloud.fill" : "cloud")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(showingWeatherBanner ? LogbookTheme.accentBlue : .gray)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(showingWeatherBanner ? LogbookTheme.accentBlue.opacity(0.2) : Color.clear)
                )
        }
        .padding(.trailing, 8)
        
        addTripButton
    }
 
 
 ═══════════════════════════════════════════════════════════════════════
 STEP 3: ADD SHEET PRESENTER
 ═══════════════════════════════════════════════════════════════════════
 
 Location: ContentView.swift, after your other sheet presenters
 
 Option A: If you have a sheetPresenters computed property, add this:
 
    .sheet(isPresented: $showSearch) {
        LogbookSearchView()
            .environmentObject(store)
    }
 
 Option B: Add directly to your body after other sheets:
 
    var body: some View {
        Group {
            // ... your content
        }
        // ... existing sheets
        .sheet(isPresented: $showSearch) {
            LogbookSearchView()
                .environmentObject(store)
        }
    }
 
 
 ═══════════════════════════════════════════════════════════════════════
 OPTIONAL: ADD HELP TO SETTINGS
 ═══════════════════════════════════════════════════════════════════════
 
 In your SettingsView.swift, add this section:
 
    Section("Support") {
        NavigationLink(destination: HelpView()) {
            Label("Help & Support", systemImage: "questionmark.circle")
        }
    }
 
 
 ═══════════════════════════════════════════════════════════════════════
 ALTERNATIVE: ADD TO TOOLBAR (Navigation Bar)
 ═══════════════════════════════════════════════════════════════════════
 
 If you prefer a navigation bar button instead of header button:
 
    .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showSearch = true }) {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
    }
 
 
 ═══════════════════════════════════════════════════════════════════════
 KEYBOARD SHORTCUT (Optional - iPad/Mac)
 ═══════════════════════════════════════════════════════════════════════
 
 Add Command+F support:
 
    .onAppear {
        // Your existing onAppear code
    }
    .keyboardShortcut("f", modifiers: .command)
 
 
 ═══════════════════════════════════════════════════════════════════════
 TESTING
 ═══════════════════════════════════════════════════════════════════════
 
 1. Build project (should compile without errors)
 2. Tap search button in logbook header  
 3. Search for an airport code (e.g., "KYIP")
 4. Search for a trip number (e.g., "7583")
 5. Try the filters (date range, aircraft, etc.)
 6. Tap a result to view trip details
 7. Close search and verify it returns to logbook
 
 
 ═══════════════════════════════════════════════════════════════════════
 TROUBLESHOOTING
 ═══════════════════════════════════════════════════════════════════════
 
 Search button not visible?
 → Check you added it to the correct HStack in logbook header
 
 Search not opening?
 → Verify @State private var showSearch = false is declared
 → Check .sheet(isPresented: $showSearch) is added
 
 No search results?
 → Make sure you have trips in your logbook
 → Try searching for known airports or trip numbers
 → Check that .environmentObject(store) is present
 
 Compilation errors?
 → Verify LogbookSearchView.swift is in your project
 → Check that all syntax is correct
 → Clean build folder (Shift+Cmd+K)
 
 
 ═══════════════════════════════════════════════════════════════════════
 SUMMARY
 ═══════════════════════════════════════════════════════════════════════
 
 Total changes needed: 3 small additions
 Time to integrate: 5 minutes
 Lines of code: ~25 lines
 
 ✅ LogbookSearchView.swift - Ready to use
 ✅ HelpView.swift - Ready to use
 ✅ All compilation errors fixed
 ✅ Compatible with your data model
 
 Happy flying! ✈️🔍
 
 */

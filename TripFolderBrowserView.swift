//
//  TripFolderBrowserView.swift
//  ProPilotApp
//
//  Scanner Pro-Inspired Document Browser
//

import SwiftUI

// MARK: - Main Trip Folder Browser
struct TripFolderBrowserView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var documentStore: TripDocumentManager
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var crewContactManager: CrewContactManager  // Added for shared crew contacts
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewMode: ViewMode = .grid
    @State private var sortOption: SortOption = .dateCreated
    @State private var selectedTrip: Trip?
    @State private var showingTripDocuments = false
    @State private var showingScanner = false
    @State private var showingCreateTripAlert = false
    @State private var showingCreateTripMenu = false
    
    enum ViewMode {
        case grid, list
    }
    
    enum SortOption: String, CaseIterable {
        case dateCreated = "Date Created"
        case dateModified = "Date Modified"
        case name = "Name"
        case documentCount = "Document Count"
        
        var icon: String {
            switch self {
            case .dateCreated: return "calendar.badge.plus"
            case .dateModified: return "calendar.badge.clock"
            case .name: return "textformat.abc"
            case .documentCount: return "doc.text"
            }
        }
    }
    
    // Get trips with documents
    private var tripsWithDocuments: [(trip: Trip, docCount: Int)] {
        let tripsWithDocs = store.trips.compactMap { trip -> (Trip, Int)? in
            let docs = documentStore.getDocuments(forTrip: trip.tripNumber)
            guard !docs.isEmpty else { return nil }
            return (trip, docs.count)
        }
        
        return tripsWithDocs.sorted(by: { first, second in
            switch sortOption {
            case .dateCreated, .dateModified:
                return first.0.date > second.0.date
            case .name:
                return first.0.tripNumber < second.0.tripNumber
            case .documentCount:
                return first.1 > second.1
            }
        })
    }
    
    // Check if there's an active trip (trip from today or most recent incomplete trip)
    private var hasActiveTrip: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check for trips from today
        let todaysTrips = store.trips.filter { trip in
            calendar.isDate(trip.date, inSameDayAs: today)
        }
        
        return !todaysTrips.isEmpty || !store.trips.isEmpty
    }
    
    // Get the most recent trip to use for scanning
    private var mostRecentTrip: Trip? {
        return store.trips.sorted(by: { $0.date > $1.date }).first
    }
    
    var body: some View {
        navigationContent
            .preferredColorScheme(.dark)
    }
    
    // MARK: - Navigation Content
    private var navigationContent: some View {
        NavigationView {
            mainViewWithOverlays
                .navigationTitle("My Scans")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    toolbarContent
                }
        }
        .sheet(isPresented: $showingTripDocuments) {
            tripDocumentsSheet
        }
        .sheet(isPresented: $showingScanner) {
            scannerSheet
        }
        .confirmationDialog("Create New Trip", isPresented: $showingCreateTripMenu, titleVisibility: .visible) {
            createTripDialogButtons
        } message: {
            Text("What type of trip would you like to create?")
        }
        .alert("No Active Trip", isPresented: $showingCreateTripAlert) {
            noTripAlertButtons
        } message: {
            Text("You need to create a trip before scanning documents. Would you like to create a trip now?")
        }
    }
    
    // MARK: - Main View with Overlays
    private var mainViewWithOverlays: some View {
        ZStack {
            mainContentView
            floatingActionButton
        }
    }
    
    // MARK: - Toolbar Content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Done") {
                dismiss()
            }
            .foregroundColor(LogbookTheme.accentBlue)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            toolbarButtons
        }
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    private var tripDocumentsSheet: some View {
        if let trip = selectedTrip {
            TripDocumentListView(
                trip: trip,
                documents: documentStore.getDocuments(forTrip: trip.tripNumber),
                documentStore: documentStore
            )
        }
    }
    
    @ViewBuilder
    private var scannerSheet: some View {
        TripScannerView(
            store: store,
            airlineSettings: airlineSettings,
            documentStore: documentStore,
            crewContactManager: crewContactManager,
            preselectedTrip: mostRecentTrip
        )
    }
    
    // MARK: - Dialog/Alert Buttons
    @ViewBuilder
    private var createTripDialogButtons: some View {
        Button("New Flight") {
            print("📝 Creating new operating flight")
            dismiss()
        }
        
        Button("New Deadhead") {
            print("📝 Creating new deadhead flight")
            dismiss()
        }
        
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var noTripAlertButtons: some View {
        Button("Create Trip", role: .none) {
            showingCreateTripMenu = true
        }
        Button("Cancel", role: .cancel) { }
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            if tripsWithDocuments.isEmpty {
                emptyStateView
            } else {
                contentScrollView
            }
        }
    }
    
    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                statsHeaderView
                
                if viewMode == .grid {
                    tripFoldersGridView
                } else {
                    tripFoldersListView
                }
            }
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Toolbar Buttons
    private var toolbarButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = viewMode == .grid ? .list : .grid
                }
            }) {
                Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 18))
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortOption = option
                    }) {
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18))
                    .foregroundColor(LogbookTheme.accentBlue)
            }
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            Button(action: handleScanButtonTap) {
                ZStack {
                    Circle()
                        .fill(LogbookTheme.accentOrange)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Handle Scan Button Tap
    private func handleScanButtonTap() {
        if hasActiveTrip {
            // Has active trip - open scanner for most recent trip
            print("📸 Opening scanner for trip: \(mostRecentTrip?.tripNumber ?? "Unknown")")
            showingScanner = true
        } else {
            // No active trip - show alert
            showingCreateTripAlert = true
        }
    }
    
    // MARK: - Stats Header
    private var statsHeaderView: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(tripsWithDocuments.count)",
                label: "Trip\(tripsWithDocuments.count == 1 ? "" : "s")",
                icon: "airplane",
                color: LogbookTheme.accentBlue
            )
            
            StatCard(
                value: "\(totalDocumentCount)",
                label: "Document\(totalDocumentCount == 1 ? "" : "s")",
                icon: "doc.text",
                color: LogbookTheme.accentGreen
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var totalDocumentCount: Int {
        tripsWithDocuments.reduce(0) { $0 + $1.docCount }
    }
    
    // MARK: - Grid View (Tighter Layout)
    private var tripFoldersGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(tripsWithDocuments, id: \.0.id) { item in
                TripFolderCard(
                    trip: item.0,
                    documentCount: item.1,
                    documentStore: documentStore
                )
                .onTapGesture {
                    selectedTrip = item.0
                    showingTripDocuments = true
                }
            }
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - List View
    private var tripFoldersListView: some View {
        VStack(spacing: 0) {
            ForEach(tripsWithDocuments, id: \.0.id) { item in
                TripFolderListRow(
                    trip: item.0,
                    documentCount: item.1
                )
                .onTapGesture {
                    selectedTrip = item.0
                    showingTripDocuments = true
                }
                
                if item.0.id != tripsWithDocuments.last?.0.id {
                    Divider()
                        .background(LogbookTheme.navyLight)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(LogbookTheme.textSecondary)
            
            VStack(spacing: 12) {
                Text("No Scans Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Scan documents using the Scanner tab to get started")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Stat Card (Compact)
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(LogbookTheme.navyLight)
        .cornerRadius(10)
    }
}

// MARK: - Trip Folder Card (Scanner Pro Style - Compact)
struct TripFolderCard: View {
    let trip: Trip
    let documentCount: Int
    @ObservedObject var documentStore: TripDocumentManager
    
    private var documents: [TripDocument] {
        documentStore.getDocuments(forTrip: trip.tripNumber)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Document preview grid - takes most of the space
            GeometryReader { geo in
                documentPreviewGrid
                    .frame(width: geo.size.width, height: geo.size.width * 1.15)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            }
            .aspectRatio(1/1.15, contentMode: .fit)
            
            // Trip info - compact
            VStack(alignment: .leading, spacing: 2) {
                Text(tripDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(documentCount) document\(documentCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
        .padding(6)
        .background(LogbookTheme.navyLight)
        .cornerRadius(10)
    }
    
    // Format trip name to fit better
    private var tripDisplayName: String {
        // Show month + aircraft for better identification
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: trip.date)
        return "\(dateStr) • \(trip.aircraft)"
    }
    
    // MARK: - Document Preview Grid
    @ViewBuilder
    private var documentPreviewGrid: some View {
        GeometryReader { geometry in
            if documents.isEmpty {
                // Empty state
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundColor(LogbookTheme.textSecondary)
                }
            } else if documents.count == 1 {
                // Single document - full width
                PDFThumbnailView(
                    fileURL: documents[0].fileURL,
                    size: CGSize(
                        width: geometry.size.width - 4,
                        height: geometry.size.height - 4
                    )
                )
                .padding(2)
            } else {
                // 2x2 grid for multiple documents
                let spacing: CGFloat = 3
                let itemWidth = (geometry.size.width - spacing * 3) / 2
                let itemHeight = (geometry.size.height - spacing * 3) / 2
                
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) {
                        // Top-left
                        PDFThumbnailView(
                            fileURL: documents[0].fileURL,
                            size: CGSize(width: itemWidth, height: itemHeight)
                        )
                        
                        // Top-right
                        if documents.count > 1 {
                            PDFThumbnailView(
                                fileURL: documents[1].fileURL,
                                size: CGSize(width: itemWidth, height: itemHeight)
                            )
                        } else {
                            emptySlot(width: itemWidth, height: itemHeight)
                        }
                    }
                    
                    HStack(spacing: spacing) {
                        // Bottom-left
                        if documents.count > 2 {
                            PDFThumbnailView(
                                fileURL: documents[2].fileURL,
                                size: CGSize(width: itemWidth, height: itemHeight)
                            )
                        } else {
                            emptySlot(width: itemWidth, height: itemHeight)
                        }
                        
                        // Bottom-right (or "+N more" overlay)
                        if documents.count > 4 {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black.opacity(0.8))
                                
                                Text("+\(documents.count - 3)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: itemWidth, height: itemHeight)
                            .cornerRadius(4)
                        } else if documents.count > 3 {
                            PDFThumbnailView(
                                fileURL: documents[3].fileURL,
                                size: CGSize(width: itemWidth, height: itemHeight)
                            )
                        } else {
                            emptySlot(width: itemWidth, height: itemHeight)
                        }
                    }
                }
                .padding(spacing)
            }
        }
    }
    
    // Empty slot placeholder
    private func emptySlot(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.2))
            .frame(width: width, height: height)
            .cornerRadius(4)
    }
}

// MARK: - Trip Folder List Row
struct TripFolderListRow: View {
    let trip: Trip
    let documentCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Trip \(trip.tripNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text(trip.aircraft)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Text("•")
                        .foregroundColor(LogbookTheme.textTertiary)
                    
                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.textTertiary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("\(documentCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("doc\(documentCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(LogbookTheme.textSecondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(LogbookTheme.textTertiary)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Document List Row
struct DocumentListRow: View {
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
            return .indigo
        case .other:
            return LogbookTheme.textSecondary
        }
    }
}

// MARK: - Preview
struct TripFolderBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TripFolderBrowserView(
            store: SwiftDataLogBookStore.preview,
            documentStore: TripDocumentManager(),
            airlineSettings: AirlineSettingsStore(),
            crewContactManager: CrewContactManager()
        )
    }
}

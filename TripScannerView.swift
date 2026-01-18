//
//  TripScannerView.swift
//  ProPilotApp
//
//  Complete Trip-Centric Scanner System - Updated with Document Email Settings
//

import SwiftUI
import VisionKit
import MessageUI

// MARK: - Main Trip Scanner View
struct TripScannerView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    @ObservedObject var airlineSettings: AirlineSettingsStore
    @ObservedObject var documentStore: TripDocumentManager
    @ObservedObject var crewContactManager: CrewContactManager  // Shared crew contacts
    var preselectedTrip: Trip? = nil
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var scannerSettings = ScannerSettings()
    @StateObject private var scannerCropCoordinator = CropCoordinator()
    
    @State private var showingScanner = false
    @State private var showingCreateTrip = false
    @State private var showingTripFiles = false
    @State private var showingRecentTripDocuments = false
    @State private var showingEmailComposer = false
    @State private var pendingScanType: ScanType = .logbookPage
    @State private var pendingDocumentType: TripDocumentType = .other  // Track document type for email
    @State private var selectedTrip: Trip?
    @State private var showingFileSavedFeedback = false
    @State private var showingScannerSettings = false
    @State private var showingEmailSettings = false
    @State private var showingDocumentEmailSettings = false  // For per-document email settings
    @State private var showingFolderBrowser = false
    
    // Email data for composer
    @State private var emailRecipients: [String] = []
    @State private var emailCCRecipients: [String] = []
    @State private var emailSubject: String = ""
    @State private var emailBody: String = ""
    @State private var emailAttachment: URL?
    
    @State private var quickTripNumber = ""
    @State private var quickAircraft = ""
    
    private var scannerPreferences: ScannerPreferences {
        ScannerPreferences(airlineSettings: airlineSettings)
    }
    
    private var activeTrip: Trip? {
        // First look for active trip
        if let active = store.trips.first(where: { $0.status == .active }) {
            return active
        }
        // Then look for planning trip
        if let planning = store.trips.first(where: { $0.status == .planning }) {
            return planning
        }
        return nil
    }
    
    private var recentTrips: [Trip] {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        return store.trips.filter { $0.date >= twoDaysAgo }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    currentTripSection
                    quickScanSection
                    if !documentsForSelectedTrip.isEmpty {
                        recentFilesSection
                    }
                    if !recentTrips.isEmpty {
                        recentTripsSection
                    }
                    fileManagementSection
                }
                .padding()
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Trip Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showingDocumentEmailSettings = true
                        } label: {
                            Label("Document Email Settings", systemImage: "envelope.badge")
                        }
                        
                        Button {
                            showingEmailSettings = true
                        } label: {
                            Label("Legacy Email Settings", systemImage: "envelope")
                        }
                        
                        Button {
                            showingScannerSettings = true
                        } label: {
                            Label("Scanner Settings", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerWithCrop(
                documentStore: documentStore,
                isPresented: $showingScanner,
                scanType: pendingScanType,
                settings: scannerSettings,
                preferences: scannerPreferences,
                tripId: selectedTrip?.id,
                tripNumber: selectedTrip?.tripNumber,
                isActiveTrip: selectedTrip?.status == .active,
                onError: { error in
                    print("Scanner error: \(error)")
                },
                onDocumentSaved: { scannedDocument in
                    handleScannedDocument(scannedDocument)
                },
                cropCoordinator: scannerCropCoordinator
            )
        }
        // Crop editor as SIBLING to scanner sheet
        .fullScreenCover(isPresented: $scannerCropCoordinator.showingCropEditor, onDismiss: {
            DebugLogger.log("📸 Crop editor dismissed from TripScannerView")
        }) {
            if scannerCropCoordinator.currentCropIndex < scannerCropCoordinator.imagesToCrop.count {
                AdvancedCropView(
                    isPresented: $scannerCropCoordinator.showingCropEditor,
                    image: scannerCropCoordinator.imagesToCrop[scannerCropCoordinator.currentCropIndex],
                    onCropComplete: { croppedImage in
                        scannerCropCoordinator.cropCompleted(image: croppedImage)
                    },
                    onCancel: {
                        scannerCropCoordinator.cropCancelled()
                    },
                    pageNumber: scannerCropCoordinator.currentCropIndex + 1,
                    totalPages: scannerCropCoordinator.imagesToCrop.count
                )
                .onAppear {
                    DebugLogger.log("📸 🎨 fullScreenCover builder executed in TripScannerView!")
                }
            }
        }
        .sheet(isPresented: $showingScannerSettings) {
            ScannerSettingsView(settings: scannerSettings, isPresented: $showingScannerSettings)
        }
        .sheet(isPresented: $showingCreateTrip) {
            NavigationView {
                DataEntryView(
                    tripNumber: $quickTripNumber,
                    aircraft: $quickAircraft,
                    date: .constant(Date()),
                    tatStart: .constant(""),
                    crew: .constant([
                        CrewMember(role: "Captain", name: ""),
                        CrewMember(role: "First Officer", name: "")
                    ]),
                    notes: .constant(""),
                    legs: .constant([FlightLeg()]),
                    tripType: .constant(.operating),
                    deadheadAirline: .constant(""),
                    deadheadFlightNumber: .constant(""),
                    pilotRole: .constant(.captain),
                    shouldAutoStartDuty: .constant(true),
                    simTotalMinutes: .constant(0),
                    isEditing: false,
                    onSave: {
                        let newTrip = Trip(
                            id: UUID(),
                            tripNumber: quickTripNumber,
                            aircraft: quickAircraft,
                            date: Date(),
                            tatStart: "",
                            crew: [CrewMember(role: "Captain", name: ""), CrewMember(role: "First Officer", name: "")],
                            notes: "",
                            legs: [FlightLeg()],
                            tripType: .operating,
                            status: .active,
                            pilotRole: .captain,
                            receiptCount: 0,
                            logbookPageSent: false,
                            perDiemStarted: nil,
                            perDiemEnded: nil
                        )
                        store.addTrip(newTrip)
                        selectedTrip = newTrip
                        showingCreateTrip = false
                    },
                    onEdit: {},
                    onScanLogPage: {},
                    documentManager: documentStore
                )
                .navigationTitle("Create Trip")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingCreateTrip = false
                })
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingTripFiles) {
            NavigationView {
                TripFilesListView(
                    documents: documentsForSelectedTrip,
                    tripNumber: selectedTrip?.tripNumber ?? "No Trip"
                )
                .navigationTitle("Trip Files")
                .navigationBarItems(trailing: Button("Done") {
                    showingTripFiles = false
                })
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingEmailComposer) {
            Group {
                if MFMailComposeViewController.canSendMail(),
                   let attachment = emailAttachment {
                    EmailComposerView(
                        recipients: emailRecipients,
                        ccRecipients: emailCCRecipients,
                        subject: emailSubject,
                        body: emailBody,
                        attachment: attachment,
                        isPresented: $showingEmailComposer
                    )
                } else if let trip = selectedTrip,
                          let firstDoc = documentsForSelectedTrip.first,
                          let fileURL = firstDoc.fileURL {
                    // Fallback to old behavior if no pending email data
                    EmailComposerView(
                        recipients: [airlineSettings.settings.generalEmail],
                        subject: "Documents - Trip \(trip.tripNumber)",
                        body: "Attached: \(documentsForSelectedTrip.count) document(s) for trip \(trip.tripNumber)",
                        attachment: fileURL,
                        isPresented: $showingEmailComposer
                    )
                } else {
                    // Fallback if fileURL is nil
                    NavigationView {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("Cannot Email Documents")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            if selectedTrip == nil {
                                Text("No trip selected")
                                    .foregroundColor(.gray)
                            } else if documentsForSelectedTrip.isEmpty {
                                Text("No documents found")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Document files not accessible")
                                    .foregroundColor(.gray)
                            }
                            
                            Button("Close") {
                                showingEmailComposer = false
                            }
                            .padding()
                            .background(LogbookTheme.accentBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(LogbookTheme.navy)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEmailSettings) {
            NavigationView {
                ScannerEmailConfigView(airlineSettings: airlineSettings)
                    .navigationTitle("Email Settings")
                    .navigationBarItems(trailing: Button("Done") {
                        showingEmailSettings = false
                    })
            }
            .preferredColorScheme(.dark)
        }
        // Document Email Settings sheet
        .sheet(isPresented: $showingDocumentEmailSettings) {
            DocumentEmailSettingsView()
        }
        .sheet(isPresented: $showingFolderBrowser) {
            TripFolderBrowserView(
                store: store,
                documentStore: documentStore,
                airlineSettings: airlineSettings,
                crewContactManager: crewContactManager
            )
        }
        .sheet(isPresented: $showingRecentTripDocuments) {
            if let trip = selectedTrip {
                NavigationView {
                    TripDocumentGridView(
                        trip: trip,
                        documents: documentStore.getDocuments(forTrip: trip.tripNumber),
                        documentStore: documentStore
                    )
                    .navigationTitle("Trip \(trip.tripNumber)")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showingRecentTripDocuments = false
                    })
                }
                .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            // Set selected trip to active trip on appear
            if selectedTrip == nil {
                selectedTrip = activeTrip
                print("📱 TripScannerView appeared - Active trip: \(activeTrip?.tripNumber ?? "none")")
            }
        }
        .onChange(of: store.trips) { oldValue, newValue in
            // React to changes in the trip list
            // If we don't have a selected trip, or the selected trip is no longer active, update it
            if selectedTrip == nil || selectedTrip?.status == .completed {
                selectedTrip = activeTrip
                print("📱 Trips changed - Updated selected trip to: \(activeTrip?.tripNumber ?? "none")")
            }
            // If the selected trip's status changed to completed, find new active trip
            if let selected = selectedTrip,
               let updatedTrip = store.trips.first(where: { $0.id == selected.id }),
               updatedTrip.status != selected.status {
                selectedTrip = updatedTrip.status == .completed ? activeTrip : updatedTrip
                print("📱 Selected trip status changed - Updated to: \(selectedTrip?.tripNumber ?? "none")")
            }
        }
    }
    
    // MARK: - Handle Scanned Document
    private func handleScannedDocument(_ scannedDoc: ScannedDocument) {
        guard let trip = selectedTrip else {
            print("⚠️ No trip selected for email")
            return
        }
        
        // Convert ScanType to TripDocumentType
        let documentType = convertToTripDocumentType(scannedDoc.documentType)
        
        // Get the file URL
        let fileURL: URL?
        if let pdfPath = scannedDoc.pdfPath, !pdfPath.isEmpty {
            fileURL = URL(fileURLWithPath: pdfPath)
        } else if !scannedDoc.imagePath.isEmpty {
            fileURL = URL(fileURLWithPath: scannedDoc.imagePath)
        } else {
            fileURL = scannedDoc.fileURL
        }
        
        // Generate email data using the new settings system
        let settings = DocumentEmailSettingsStore.shared
        let config = settings.getConfig(for: documentType)
        
        // Set email recipients
        emailRecipients = config.toEmail.isEmpty ? [] : [config.toEmail]
        emailCCRecipients = settings.getCCEmails(for: documentType, trip: trip, crewManager: crewContactManager)
        
        // Generate subject and body
        emailSubject = config.generateSubject(for: trip, documentType: documentType)
        emailBody = config.generateBody(for: trip, documentType: documentType, fileName: scannedDoc.filename, fileSize: scannedDoc.formattedFileSize)
        emailAttachment = fileURL
        
        print("📧 Prepared email for \(documentType.rawValue)")
        print("   To: \(emailRecipients)")
        print("   CC: \(emailCCRecipients)")
        print("   Subject: \(emailSubject)")
        
        // Show email composer if we can send mail
        if MFMailComposeViewController.canSendMail() && fileURL != nil {
            // Small delay to let scanner sheet dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingEmailComposer = true
            }
        }
    }
    
    // MARK: - Convert ScanType to TripDocumentType
    private func convertToTripDocumentType(_ scanType: ScanType) -> TripDocumentType {
        switch scanType {
        case .fuelReceipt:
            return .fuelReceipt
        case .logbookPage:
            return .logPage
        case .maintenanceLog:
            return .other
        case .general:
            return pendingDocumentType  // Use what was set when scan started
        }
    }
    
    // MARK: - Computed Properties
    private var documentsForSelectedTrip: [TripDocument] {
        guard let tripNumber = selectedTrip?.tripNumber else { return [] }
        return documentStore.getDocuments(forTrip: tripNumber)
    }
    
    // MARK: - View Sections
    private var currentTripSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Trip")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Debug info in development
                #if DEBUG
                Text("(\(store.trips.count) trips)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                #endif
                
                // Trip picker if we have trips to choose from
                if !store.trips.isEmpty && selectedTrip != nil {
                    Menu {
                        // Show active/planning trips first
                        let activeTrips = store.trips.filter { $0.status == .active || $0.status == .planning }
                        if !activeTrips.isEmpty {
                            Section("Active") {
                                ForEach(activeTrips) { trip in
                                    Button {
                                        selectedTrip = trip
                                    } label: {
                                        HStack {
                                            Text("Trip \(trip.tripNumber)")
                                            if trip.status == .active {
                                                Image(systemName: "circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Then show recent trips
                        if !recentTrips.isEmpty {
                            Section("Recent") {
                                ForEach(recentTrips.filter { $0.status != .active && $0.status != .planning }.prefix(5)) { trip in
                                    Button {
                                        selectedTrip = trip
                                    } label: {
                                        Text("Trip \(trip.tripNumber)")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Change")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            
            if let trip = selectedTrip {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Trip \(trip.tripNumber)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(trip.aircraft)
                                .font(.subheadline)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if trip.status == .active {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(LogbookTheme.accentGreen)
                                    .frame(width: 8, height: 8)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        } else {
                            Text(trip.status.rawValue)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Show route
                    if !trip.legs.isEmpty {
                        Text(trip.routeString)
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    // Show TAT if available
                    if !trip.tatStart.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("TAT: \(trip.formattedTATStart)")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                            
                            // Show final TAT if there are legs
                            if !trip.legs.isEmpty && !trip.formattedFinalTAT.isEmpty {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(trip.formattedFinalTAT)
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentGreen)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("\(documentsForSelectedTrip.count) document\(documentsForSelectedTrip.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.cardBackground)
                .cornerRadius(12)
            } else {
                // No trip selected - show options
                VStack(spacing: 16) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Active Trip")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Show recent trips to pick from, or create new
                    if !recentTrips.isEmpty {
                        VStack(spacing: 8) {
                            Text("Select a recent trip:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            ForEach(recentTrips.prefix(3)) { trip in
                                Button {
                                    selectedTrip = trip
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Trip \(trip.tripNumber)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(trip.routeString)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        if trip.status == .active {
                                            Circle()
                                                .fill(LogbookTheme.accentGreen)
                                                .frame(width: 8, height: 8)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .background(LogbookTheme.navyLight)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                    
                    Button {
                        showingCreateTrip = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Trip")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.cardBackground)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var quickScanSection: some View {
        VStack(spacing: 12) {
            Text("Quick Scan")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                QuickScanButton(
                    title: "Logbook",
                    icon: "book.pages",
                    color: LogbookTheme.accentBlue
                ) {
                    // Auto-select active trip if none selected
                    if selectedTrip == nil {
                        selectedTrip = activeTrip
                    }
                    pendingScanType = .logbookPage
                    pendingDocumentType = .logPage
                    showingScanner = true
                }
                
                QuickScanButton(
                    title: "Fuel",
                    icon: "fuelpump",
                    color: LogbookTheme.accentGreen
                ) {
                    // Auto-select active trip if none selected
                    if selectedTrip == nil {
                        selectedTrip = activeTrip
                    }
                    pendingScanType = .fuelReceipt
                    pendingDocumentType = .fuelReceipt
                    showingScanner = true
                }
                
                QuickScanButton(
                    title: "Document",
                    icon: "doc.text",
                    color: LogbookTheme.accentOrange
                ) {
                    // Auto-select active trip if none selected
                    if selectedTrip == nil {
                        selectedTrip = activeTrip
                    }
                    pendingScanType = .general
                    pendingDocumentType = .other
                    showingScanner = true
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Files")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    showingTripFiles = true
                }
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(documentsForSelectedTrip.prefix(5)) { document in
                        RecentFileCard(document: document)
                    }
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Trips")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(recentTrips) { trip in
                Button(action: {
                    selectedTrip = trip
                    showingRecentTripDocuments = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip \(trip.tripNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(trip.routeString)
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        let docCount = documentStore.getDocuments(forTrip: trip.tripNumber).count
                        if docCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.caption2)
                                Text("\(docCount)")
                                    .font(.caption)
                            }
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
    
    private var fileManagementSection: some View {
        VStack(spacing: 12) {
            Text("File Management")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button(action: { showingFolderBrowser = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundColor(LogbookTheme.accentOrange)
                        Text("Browse Folders")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    if !documentsForSelectedTrip.isEmpty {
                        // Use new email settings for selected trip
                        if let trip = selectedTrip,
                           let firstDoc = documentsForSelectedTrip.first {
                            let docType = firstDoc.documentType
                            let settings = DocumentEmailSettingsStore.shared
                            let config = settings.getConfig(for: docType)
                            
                            emailRecipients = config.toEmail.isEmpty ? [] : [config.toEmail]
                            emailCCRecipients = settings.getCCEmails(for: docType, trip: trip, crewManager: crewContactManager)
                            emailSubject = config.generateSubject(for: trip, documentType: docType)
                            emailBody = config.generateBody(for: trip, documentType: docType, fileName: firstDoc.fileName, fileSize: nil)
                            emailAttachment = firstDoc.fileURL
                        }
                        showingEmailComposer = true
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Email Documents")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)
                    .opacity(documentsForSelectedTrip.isEmpty ? 0.5 : 1.0)
                }
                .disabled(documentsForSelectedTrip.isEmpty)
            }
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// MARK: - Quick Scan Button
struct QuickScanButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Recent File Card
struct RecentFileCard: View {
    let document: TripDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // PDF Thumbnail
            if let fileURL = document.fileURL {
                PDFThumbnailView(
                    fileURL: fileURL,
                    size: CGSize(width: 100, height: 130)
                )
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            // Document info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: document.documentType.icon)
                        .font(.system(size: 10))
                        .foregroundColor(colorForDocumentType(document.documentType))
                    
                    Text(document.documentType.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text(document.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
        .padding(8)
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private func colorForDocumentType(_ type: TripDocumentType) -> Color {
        switch type {
        case .fuelReceipt: return LogbookTheme.accentGreen
        case .customsGendec: return LogbookTheme.accentBlue
        case .groundHandler: return LogbookTheme.accentOrange
        case .shipper: return .purple
        case .reweighForm: return .cyan
        case .loadManifest: return LogbookTheme.accentBlue
        case .weatherBriefing: return .yellow
        case .logPage: return .indigo
        case .other: return LogbookTheme.textSecondary
        }
    }
}

// MARK: - Document Row
struct DocumentRow: View {
    let document: TripDocument
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text(document.documentType.rawValue)
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Spacer()
                    
                    Text(document.createdDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip: Trip
    let isSelected: Bool
    let documentCount: Int
    let onTap: () -> Void
    
    private var routeString: String {
        let legs = trip.legs
        if legs.isEmpty {
            return "No route"
        } else if legs.count == 1 {
            return "\(legs[0].departure) → \(legs[0].arrival)"
        } else {
            let airports = [legs[0].departure] + legs.map { $0.arrival }
            return airports.joined(separator: " → ")
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trip")
                        .font(.system(size: 10))
                        .foregroundColor(LogbookTheme.textSecondary)
                    
                    Spacer()
                    
                    if trip.status == .active {
                        Circle()
                            .fill(LogbookTheme.accentGreen)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Text(trip.tripNumber)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text(routeString)
                    .font(.system(size: 11))
                    .foregroundColor(LogbookTheme.accentBlue)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 3) {
                    Text(trip.aircraft)
                        .font(.system(size: 10))
                        .foregroundColor(LogbookTheme.textSecondary)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(LogbookTheme.textTertiary)
                    
                    Text(trip.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 9))
                        .foregroundColor(LogbookTheme.textTertiary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9))
                    Text("\(documentCount)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(LogbookTheme.accentOrange)
            }
            .padding(10)
            .frame(width: 140)
            .frame(minHeight: 110)
            .background(isSelected ? LogbookTheme.accentBlue.opacity(0.2) : LogbookTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? LogbookTheme.accentBlue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Trip Document Grid View
struct TripDocumentGridView: View {
    let trip: Trip
    let documents: [TripDocument]
    @ObservedObject var documentStore: TripDocumentManager
    @State private var selectedDocument: TripDocument?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            if documents.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(documents) { document in
                            DocumentThumbnailCard(document: document)
                                .onTapGesture {
                                    selectedDocument = document
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            NavigationView {
                TripDocumentDetailView(document: document)
                    .navigationTitle(document.fileName)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(LogbookTheme.textSecondary)
            
            VStack(spacing: 8) {
                Text("No Documents")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Scan documents to add them to this trip")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Document Thumbnail Card
struct DocumentThumbnailCard: View {
    let document: TripDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PDFThumbnailView(
                fileURL: document.fileURL,
                size: CGSize(width: 100, height: 130)
            )
            .frame(height: 130)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: document.documentType.icon)
                        .font(.system(size: 10))
                        .foregroundColor(colorForDocumentType(document.documentType))
                    
                    Text(document.documentType.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text(document.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundColor(LogbookTheme.textSecondary)
            }
        }
        .padding(8)
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
    
    private func colorForDocumentType(_ type: TripDocumentType) -> Color {
        switch type {
        case .fuelReceipt: return LogbookTheme.accentGreen
        case .customsGendec: return LogbookTheme.accentBlue
        case .groundHandler: return LogbookTheme.accentOrange
        case .shipper: return .purple
        case .reweighForm: return .cyan
        case .loadManifest: return LogbookTheme.accentBlue
        case .weatherBriefing: return .yellow
        case .logPage: return .indigo
        case .other: return LogbookTheme.textSecondary
        }
    }
}

// MARK: - Trip Files List View
struct TripFilesListView: View {
    let documents: [TripDocument]
    let tripNumber: String
    @State private var selectedDocument: TripDocument?
    
    var body: some View {
        List {
            if documents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No documents yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(documents) { document in
                    Button(action: {
                        selectedDocument = document
                    }) {
                        DocumentRow(document: document)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            NavigationView {
                TripDocumentDetailView(document: document)
                    .navigationTitle(document.fileName)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Trip Document Detail View
struct TripDocumentDetailView: View {
    let document: TripDocument
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            if let fileURL = document.fileURL {
                PDFThumbnailView(
                    fileURL: fileURL,
                    size: CGSize(width: 300, height: 400)
                )
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .shadow(radius: 4)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Filename:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(document.fileName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Type:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(document.documentType.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Trip:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(document.tripNumber)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Created:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(document.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(LogbookTheme.cardBackground)
            .cornerRadius(12)
            
            Spacer()
            
            if let fileURL = document.fileURL {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Document")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(12)
                }
                .sheet(isPresented: $showingShareSheet) {
                    SimpleActivityView(activityItems: [fileURL])
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Simple Activity View
struct SimpleActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
struct TripScannerView_Previews: PreviewProvider {
    static var previews: some View {
        TripScannerView(
            store: SwiftDataLogBookStore.preview,
            airlineSettings: AirlineSettingsStore(),
            documentStore: TripDocumentManager(),
            crewContactManager: CrewContactManager()
        )
    }
}


// ContentView_Merged.swift - Universal iOS/iPadOS View
// BASE: Old ContentView (Nov 10) with proper @EnvironmentObject pattern
// CHERRY-PICKED: New features from current version (Nov 27)
import SwiftUI
import Combine
import Foundation
import CoreLocation
import CoreMotion
import ActivityKit
import ClockKit
import MessageUI

// MARK: - Main Content View (Universal for iPhone & iPad)
struct ContentView: View {
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // MARK: - Environment Objects (Injected from App) ✅ CRITICAL FIX
    @EnvironmentObject private var store: SwiftDataLogBookStore
    @EnvironmentObject private var activityManager: PilotActivityManager
    @EnvironmentObject private var nocSettings: NOCSettingsStore
    @EnvironmentObject private var scheduleStore: ScheduleStore  // ✅ From environment
    
    // MARK: - Stores (Created locally)
    @StateObject private var sharedEmailSettings = EmailSettingsStore()
    @StateObject private var airlineSettings = AirlineSettingsStore()
    @StateObject private var crewContactManager = CrewContactManager()
    @StateObject private var scannerCropCoordinator = CropCoordinator()
    @StateObject private var watchConnectivity = PhoneWatchConnectivity()
    @StateObject private var locationManager = PilotLocationManager()
    @StateObject private var opsManager = OPSCallingManager()
    @StateObject private var sharedDocumentStore = TripDocumentManager()
    @StateObject private var scannerSettings = ScannerSettings()
    @StateObject private var speedMonitor = GPSSpeedMonitor()
    @StateObject private var tabManager = CustomizableTabManager.shared
    @StateObject private var dutyTimerManager = DutyTimerManager.shared
    
    // 🆕 PAYWALL: Subscription status checker
    @StateObject private var trialChecker = SubscriptionStatusChecker.shared
    
    // MARK: - State Variables
    @State private var simTotalMinutes: Int = 120
    @State private var currentTripId: UUID? = nil
    @State private var isActiveTrip: Bool = false
    @State private var currentTripNumber: String = ""
    @State private var showingFileImport = false
    @State private var showTripSheet = false
    @State private var showingElectronicLogbook = false
    @State private var editingTripIndex: Int? = nil
    @State private var showLegsView = false
    @State private var showingAirportAlert = false
    @State private var currentAirport: (icao: String, name: String)?
    @State private var showingScanner = false
    @State private var showingScannerCompletionDialog = false
    @State private var completedScannerDocument: ScannedDocument?
    @State private var selectedScanType: ScanType = .fuelReceipt
    @State private var showingEmailComposer = false
    @State private var selectedTripForEditing: Trip?
    @State private var showingDataEntry = false
    @State private var showingTripDetail = false
    @State private var showingTimePicker = false
    @State private var editingTimeType = ""
    @State private var editingTimeValue = ""
    @State private var expandedSections: Set<String> = ["CURRENT DUTY PERIOD"]
    @State private var showingDuplicateTripAlert = false
    @State private var existingTripForDuplicate: Trip?
    @State private var showingFreightPaperwork = false
    @State private var showingWeatherBanner = false  // ✅ NEW: Weather banner toggle
    @State private var showingFBOBanner = false  // 🏢 FBO Banner toggle
    @State private var showWelcomeScreen = false  // ✅ NEW: Welcome screen for first-time users
    @State private var showingPaywall = false  // 🆕 PAYWALL: Show subscription paywall
    @State private var showingRaidoImportPicker = false  // RAIDO JSON import
    @State private var showingImportError = false  // Import error alert
    @State private var importErrorMessage: String?  // Import error message
    @State private var showingImportSuccess = false  // Import success alert
    @State private var importSuccessMessage: String?  // Import success message

    // Track if user has ever had trips (persisted)
    @AppStorage("hasEverHadTrips") private var hasEverHadTrips = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    // MARK: - Backup Prompt State
    @StateObject private var backupPromptManager = BackupPromptManager.shared
    @State private var showingBackupPrompt = false
    @State private var showingMonthlySummary = false
    
    // MARK: - Container Migration Warning State (temporarily disabled)
    // See FIX_MIGRATION_WARNING_SCOPE_ERROR.md for instructions
    // @StateObject private var migrationManager = MigrationWarningManager.shared
    // @State private var showingMigrationWarning = false
    
    // MARK: - iPad-Specific State
    @State private var selectedTab: String = "logbook"
    @State private var selectedTripId: UUID? = nil
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Cherry-picked from NEW version
    @State private var showingDeleteTimeConfirmation = false  // ✅ NEW: Delete time dialog
    @State private var selectedDocumentType: TripDocumentType = .other  // ✅ NEW: Document type for email
    @State private var showingFAR117Detail = false  // ✅ NEW: FAR117 detail sheet
    @State private var showingContinuationPrompt: ContinuationPrompt?  // ✅ NEW: Continuation prompt
    
    // Trip Form State
    @State private var tripNumber = ""
    @State private var aircraft = ""
    @State private var date: Date = TimeDisplayUtility.getCurrentTripDate()  // ✅ NEW: Use TimeDisplayUtility
    @State private var tatStart = ""
    @State private var crew: [CrewMember] = [
        CrewMember(role: "Captain", name: ""),
        CrewMember(role: "First Officer", name: "")
    ]
    @State private var notes = ""
    @State private var legs: [FlightLeg] = [FlightLeg()]
    @State private var tripType: TripType = .operating
    @State private var deadheadAirline = ""
    @State private var deadheadFlightNumber = ""
    @State private var pilotRole: PilotRole = .captain
    @State private var shouldAutoStartDuty = true
    
    private let airportDB = AirportDatabaseManager.shared
    
    
    // MARK: - Computed Properties
    var activeTrip: Trip? {
        store.trips.first { $0.status == .active || $0.status == .planning }
    }
    
    // MARK: - iPad Detection
    private var isPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    // Scanner preferences method using airline settings
    private func createScannerPreferences() -> ScannerPreferences {
        return ScannerPreferences(airlineSettings: airlineSettings)
    }
    
    // MARK: - Trip and Legs Counting Logic
    private var totalLegsCount: Int {
        store.trips.reduce(0) { $0 + $1.legs.count }
    }
    
    private var revenueTripsCount: Int {
        let count = store.trips.filter { trip in
            let isOperating = trip.tripType == .operating
            let hasNumber = !trip.tripNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return isOperating && hasNumber
        }.count
        return count
    }
    
    private var deadheadCount: Int {
        let count = store.trips.filter { trip in
            let isDeadhead = trip.tripType == .deadhead
            return isDeadhead
        }.count
        return count
    }
    
    private var tripStatisticsView: some View {
        let revenueTrips = revenueTripsCount
        let deadheads = deadheadCount
        let totalLegs = totalLegsCount
        
        let tripWord = revenueTrips == 1 ? "trip" : "trips"
        let legsText = "\(totalLegs) legs across \(revenueTrips) \(tripWord)"
        
        let deadheadWord = deadheads == 1 ? "deadhead" : "deadheads"
        let deadheadText = "+ \(deadheads) \(deadheadWord)"
        
        let deadheadColor = LogbookTheme.accentOrange.opacity(0.8)
        
        return HStack(spacing: 4) {
            Text(legsText)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            if deadheads > 0 {
                Text(deadheadText)
                    .font(.caption)
                    .foregroundColor(deadheadColor)
            }
        }
    }
    
    // MARK: - Scanner Completion Views
    private var scannerCompletionDialogView: some View {
        NavigationView {
            VStack(spacing: 24) {
                successIcon
                documentInfoSection
                Spacer()
                actionButtonsSection
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private var successIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.green)
    }
    
    private var documentInfoSection: some View {
        VStack(spacing: 8) {
            Text("Document Saved Successfully!")
                .font(.title)
                .foregroundColor(.white)
            
            if let document = completedScannerDocument {
                documentDetailsView(for: document)
            }
        }
    }
    
    private func documentDetailsView(for document: ScannedDocument) -> some View {
        VStack(spacing: 8) {
            Text(document.filename)
                .font(.headline)
                .foregroundColor(.gray)
            
            let formatAndSize = "\(document.fileFormat.rawValue) • \(document.formattedFileSize)"
            Text(formatAndSize)
                .font(.caption)
                .foregroundColor(.gray)
            
            if document.isActiveTrip {
                Text("Associated with active trip")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            emailDocumentButton
            doneButton
        }
        .padding()
    }
    
    private var emailDocumentButton: some View {
        Button("Email Document") {
            showingScannerCompletionDialog = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingEmailComposer = true
            }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.blue)
        .cornerRadius(12)
    }
    
    private var doneButton: some View {
        Button("Done") {
            showingScannerCompletionDialog = false
            completedScannerDocument = nil
        }
        .font(.headline)
        .foregroundColor(.blue)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1))
    }
    
    // MARK: - Sheet Presenters
    private var sheetPresenters: some View {
        EmptyView()
            .sheet(isPresented: $showingScanner) {
                DocumentScannerWithCrop(
                    documentStore: sharedDocumentStore,
                    isPresented: $showingScanner,
                    scanType: selectedScanType,
                    settings: scannerSettings,
                    preferences: createScannerPreferences(),
                    tripId: currentTripId,
                    tripNumber: activeTrip?.tripNumber,
                    isActiveTrip: isActiveTrip,
                    onError: { error in
                        print("Scanner error: \(error)")
                    },
                    onDocumentSaved: { document in
                        print("ContentView: Received document callback: \(document.filename)")
                        completedScannerDocument = document
                        showingScanner = false
                        showingScannerCompletionDialog = true
                    },
                    cropCoordinator: scannerCropCoordinator
                )
            }
            .fullScreenCover(isPresented: $scannerCropCoordinator.showingCropEditor, onDismiss: {
                DebugLogger.log("📸 Crop editor dismissed from ContentView")
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
                        DebugLogger.log("📸 🎨 fullScreenCover builder executed in ContentView!")
                    }
                }
            }
            .sheet(isPresented: $showingScannerCompletionDialog) {
                scannerCompletionDialogView
            }
            .sheet(isPresented: $showingEmailComposer) {
                emailComposerSheet
            }
            .sheet(isPresented: $showingDataEntry) {
                tripEditingSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingTripDetail) {
                tripDetailSheet
            }
            .sheet(isPresented: $showingTimePicker) {
                timePickerSheet
            }
            .sheet(isPresented: $showTripSheet) {
                newTripSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingElectronicLogbook) {
                SimpleElectronicLogbookView(mainStore: store)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $showingContinuationPrompt) { prompt in
                ContinuationPromptView(
                    prompt: prompt,
                    onAddLeg: {
                        TripGenerationService.shared.addLegToTrip(
                            flight: prompt.newFlight,
                            trip: prompt.existingTrip,
                            logbookStore: store
                        )
                        showingContinuationPrompt = nil
                    },
                    onNewTrip: {
                        TripGenerationService.shared.createTripFromContinuationPrompt(
                            prompt.newFlight,
                            logbookStore: store
                        )
                        showingContinuationPrompt = nil
                    },
                    onDismiss: {
                        DismissedRosterItemsManager.shared.dismiss(prompt.newFlight, reason: .notFlying)
                        showingContinuationPrompt = nil
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .continuationPromptsDetected)) { notification in
                if let prompts = notification.userInfo?["prompts"] as? [ContinuationPrompt],
                   let first = prompts.first {
                    showingContinuationPrompt = first
                }
            }
            // MARK: - Backup Prompt Sheet
            .sheet(isPresented: $showingBackupPrompt) {
                BackupPromptView(logbookStore: store)
            }
            // MARK: - Monthly Summary Sheet
            .sheet(isPresented: $showingMonthlySummary) {
                MonthlySummaryEmailView(logbookStore: store)
            }
    }
    
    // MARK: - Email Composer Sheet (✅ NEW: Uses DocumentEmailSettingsStore)
    private var emailComposerSheet: some View {
        Group {
            if let document = completedScannerDocument,
               let fileURL = document.fileURL,
               let trip = activeTrip ?? (currentTripId != nil ? store.trips.first(where: { $0.id == currentTripId }) : nil) {
                
                // ✅ NEW: Use DocumentEmailSettingsStore system
                let settings = DocumentEmailSettingsStore.shared
                let docType = selectedDocumentType
                let config = settings.getConfig(for: docType)
                
                let toRecipients = config.toEmail.isEmpty ? [getEmailForScanType(document.documentType)] : [config.toEmail]
                let ccRecipients = settings.getCCEmails(for: docType, trip: trip, crewManager: crewContactManager)
                let subject = config.generateSubject(for: trip, documentType: docType)
                let body = config.generateBody(for: trip, documentType: docType, fileName: document.filename, fileSize: document.formattedFileSize)
                
                EmailComposerView(
                    recipients: toRecipients,
                    ccRecipients: ccRecipients,
                    subject: subject,
                    body: body,
                    attachment: fileURL,
                    isPresented: $showingEmailComposer
                )
            } else if let document = completedScannerDocument,
                      let fileURL = document.fileURL {
                let docType = selectedDocumentType
                let settings = DocumentEmailSettingsStore.shared
                let config = settings.getConfig(for: docType)
                let recipient = config.toEmail.isEmpty ? getEmailForScanType(document.documentType) : config.toEmail
                
                EmailComposerView(
                    recipients: [recipient],
                    ccRecipients: [],
                    subject: "\(docType.rawValue) - \(document.filename)",
                    body: "Document Type: \(docType.rawValue)\nScanned: \(document.dateScanned.formatted())\nFilename: \(document.filename)\nSize: \(document.formattedFileSize)\n\n---\nSent from ProPilot App",
                    attachment: fileURL,
                    isPresented: $showingEmailComposer
                )
            }
        }
    }
    
    private var tripEditingSheet: some View {
        Group {
            if let trip = selectedTripForEditing {
                DataEntryView(
                    tripNumber: $tripNumber,
                    aircraft: $aircraft,
                    date: $date,
                    tatStart: $tatStart,
                    crew: $crew,
                    notes: $notes,
                    legs: $legs,
                    tripType: $tripType,
                    deadheadAirline: $deadheadAirline,
                    deadheadFlightNumber: $deadheadFlightNumber,
                    pilotRole: $pilotRole,
                    shouldAutoStartDuty: $shouldAutoStartDuty,
                    simTotalMinutes: $simTotalMinutes,
                    isEditing: true,
                    onSave: saveNewTripWithDuplicateCheck,
                    onEdit: saveEditedTrip,
                    onScanLogPage: {
                        selectedScanType = .logbookPage
                        selectedDocumentType = .logPage
                        currentTripId = trip.id
                        currentTripNumber = trip.tripNumber
                        isActiveTrip = (trip.status == .active || trip.status == .planning)
                        showingScanner = true
                        showingDataEntry = false
                    },
                    documentManager: sharedDocumentStore
                )
                .onAppear {
                    populateTripForEditing(trip)
                }
            }
        }
    }
    
    private var tripDetailSheet: some View {
        Group {
            if let trip = selectedTripForEditing {
                NavigationView {
                    VStack {
                        Text("Trip Details")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Trip #\(trip.tripNumber)")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Spacer()
                        Button("Close") {
                            showingTripDetail = false
                            selectedTripForEditing = nil
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LogbookTheme.navy.ignoresSafeArea())
                }
            }
        }
    }
    
    // MARK: - Time Picker Sheet (✅ NEW: Includes Delete Time feature)
    private var timePickerSheet: some View {
        VStack(spacing: 20) {
            Text("Edit \(editingTimeType) Time")
                .font(.title)
                .foregroundColor(.white)
            
            Text(editingTimeValue.isEmpty ? "----" : formatTimeDisplay(editingTimeValue))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(12)
            
            Text("Format: HHMM (24-hour)")
                .font(.caption)
                .foregroundColor(.gray)
            
            timePickerNumberPad
            
            Spacer()
            
            timePickerButtons
                // ✅ NEW: Delete time confirmation dialog
                .alert("Delete Time?", isPresented: $showingDeleteTimeConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        clearTimeFromActiveTrip()
                        showingTimePicker = false
                    }
                } message: {
                    Text("Are you sure you want to delete the \(editingTimeType) time? This cannot be undone.")
                }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LogbookTheme.navy.ignoresSafeArea())
    }
    
    private var timePickerNumberPad: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { number in
                    numberButton(String(number))
                }
            }
            HStack(spacing: 12) {
                ForEach(4...6, id: \.self) { number in
                    numberButton(String(number))
                }
            }
            HStack(spacing: 12) {
                ForEach(7...9, id: \.self) { number in
                    numberButton(String(number))
                }
            }
            HStack(spacing: 12) {
                clearButton()
                numberButton("0")
                backspaceButton()
            }
        }
    }
    
    // ✅ NEW: Updated time picker buttons with Delete option
    private var timePickerButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Cancel") {
                    showingTimePicker = false
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 1))
                
                Button("Save") {
                    saveTimeToActiveTrip(timeType: editingTimeType, timeValue: editingTimeValue)
                    showingTimePicker = false
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(editingTimeValue.count == 4 ? Color.blue : Color.gray)
                .cornerRadius(12)
                .disabled(editingTimeValue.count != 4)
            }
            
            // ✅ NEW: Delete button (only show if there's an existing time)
            if !editingTimeValue.isEmpty {
                Button(role: .destructive) {
                    showingDeleteTimeConfirmation = true
                } label: {
                    Label("Delete Time", systemImage: "trash")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var newTripSheet: some View {
        DataEntryView(
            tripNumber: $tripNumber,
            aircraft: $aircraft,
            date: $date,
            tatStart: $tatStart,
            crew: $crew,
            notes: $notes,
            legs: $legs,
            tripType: $tripType,
            deadheadAirline: $deadheadAirline,
            deadheadFlightNumber: $deadheadFlightNumber,
            pilotRole: $pilotRole,
            shouldAutoStartDuty: $shouldAutoStartDuty,
            simTotalMinutes: $simTotalMinutes,
            isEditing: editingTripIndex != nil,
            onSave: saveNewTripWithDuplicateCheck,
            onEdit: saveEditedTrip,
            onScanLogPage: {
                print("Scan LogPage action")
            },
            documentManager: sharedDocumentStore
        )
        .environmentObject(crewContactManager)
        .preferredColorScheme(.dark)
    }
    
    private var alertPresenters: some View {
        EmptyView()
            .alert("Duplicate Trip Number", isPresented: $showingDuplicateTripAlert) {
                Button("Broken Trip (Add as New)") {
                    saveNewTrip()
                }
                Button("Trip Continuation (Add to Existing)") {
                    addLegsToExistingTrip()
                }
                Button("Cancel") { }
                    .keyboardShortcut(.cancelAction)
            } message: {
                if let existing = existingTripForDuplicate {
                    Text("Trip #\(tripNumber) already exists (dated \(existing.date.formatted(date: .abbreviated, time: .omitted))).\n\nIs this a broken trip (separate entry) or a trip continuation (add to existing)?")
                }
            }
            .alert("Airport Arrival", isPresented: $showingAirportAlert) {
                Button("Yes, Start Trip & Duty") {
                    DutyTimerManager.shared.startDuty()
                    startTripFromAirportArrival()
                }
                .keyboardShortcut(.defaultAction)
                
                Button("Start Duty Only") {
                    DutyTimerManager.shared.startDuty()
                }
                
                Button("No") { }
                    .keyboardShortcut(.cancelAction)
            } message: {
                if let airport = currentAirport {
                    Text("You've arrived at \(airport.name). Would you like to start your duty timer?")
                }
            }
    }
    
    // MARK: - Setup
    private func setupContentView() {
        setupAutoTimeListener()
        setupClearTimesListener()  // ✅ NEW
        setupNotificationPermissions()
        setupNotificationObservers()
        setupWatchConnectivity()
        checkAndAutoStartDutyForActiveTrip()
        checkIfShouldShowWelcome()  // ✅ NEW: Check welcome screen status
        checkBackupAndMonthlySummary()  // Check backup prompts
    }

    // MARK: - Backup Prompt Check
    private func checkBackupAndMonthlySummary() {
        // Delay slightly to let the UI settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let totalLegs = store.trips.reduce(0) { $0 + $1.legs.count }
            backupPromptManager.checkOnAppLaunch(
                tripCount: store.trips.count,
                hasSignificantData: totalLegs > 5
            )

            // Bind manager state to local state
            if backupPromptManager.shouldShowBackupPrompt {
                showingBackupPrompt = true
            }

            // Check monthly summary after backup prompt is handled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if backupPromptManager.shouldShowMonthlySummary && !showingBackupPrompt {
                    showingMonthlySummary = true
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .startDutyFromWatch,
            object: nil,
            queue: .main
        ) { _ in
            if let active = self.activeTrip {
                self.selectedTripForEditing = active
                self.showingDataEntry = true
            } else {
                self.showTripSheet = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .callOPSFromWatch,
            object: nil,
            queue: .main
        ) { _ in
            self.opsManager.callOPS()
        }
    }
    
    private func setupWatchConnectivity() {
        watchConnectivity.setReferences(
            logBookStore: store,
            opsManager: opsManager,
            activityManager: activityManager,
            locationManager: locationManager
        )
    }
    
    var body: some View {
        Group {
            if isPad {
                iPadNavigationLayout
            } else {
                iPhoneTabLayout
            }
        }
        .accentColor(LogbookTheme.accentBlue)
        .environmentObject(airlineSettings)
        .environmentObject(nocSettings)
        .environmentObject(watchConnectivity)
        .environmentObject(locationManager)
        .environmentObject(opsManager)
        .environmentObject(activityManager)
        .preferredColorScheme(.dark)
        .onAppear {
            print("ContentView appeared - Device: \(isPad ? "iPad" : "iPhone")")
            setupContentView()
            
            // Check if migration warning should be shown (temporarily disabled)
            // See FIX_MIGRATION_WARNING_SCOPE_ERROR.md for instructions
            // if migrationManager.shouldShowWarning {
            //     // Delay slightly to ensure view is fully loaded
            //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //         showingMigrationWarning = true
            //     }
            // }
        }
        // .sheet(isPresented: $showingMigrationWarning) {
        //     ContainerMigrationWarningView()
        // }
        .onChange(of: activeTrip) { oldValue, newValue in
            if newValue != nil && AutoTimeSettings.shared.isEnabled {
                speedMonitor.startTracking()
                print("🛫 Started GPS monitoring for active trip")
            } else if newValue == nil {
                speedMonitor.stopTracking()
                print("🛬 Stopped GPS monitoring - no active trip")
            }
        }
        .onChange(of: store.trips) { _, newTrips in
            // Track if user ever has trips (for smart empty state logic)
            if !newTrips.isEmpty {
                hasEverHadTrips = true
            }
        }
        .onChange(of: aircraft) { _, newAircraft in
            if showTripSheet && editingTripIndex == nil {
                autoFillTATForAircraft(newAircraft)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .background(sheetPresenters)
        .background(alertPresenters)
        .overlay(welcomeScreenOverlay)
    }
    
    // MARK: - Welcome Screen Logic
    
    /// Check if we should show the welcome screen on app launch
    private func checkIfShouldShowWelcome() {
        let hasTripNow = !store.trips.isEmpty
        
        // Only show welcome if:
        // 1. User has no trips right now
        // 2. User has never had trips before
        // 3. User hasn't seen the welcome yet
        if !hasTripNow && !hasEverHadTrips && !hasSeenWelcome {
            // Small delay so the view hierarchy is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWelcomeScreen = true
                    hasSeenWelcome = true
                }
            }
        }
    }
    
    /// Welcome screen overlay (fullscreen for first-time users)
    @ViewBuilder
    private var welcomeScreenOverlay: some View {
        if showWelcomeScreen {
            LogbookWelcomeView(
                isPresented: $showWelcomeScreen,
                onAddTrip: {
                    // Show the trip creation sheet
                    showTripSheet = true
                },
                onImportNOC: {
                    // Navigate to NOC import - assuming you have schedule tab
                    selectedTab = "schedule"
                    // You might need to add additional navigation logic here
                },
                onImportCSV: {
                    // Show CSV import
                    showingFileImport = true
                },
                onImportRAIDO: {
                    // Show RAIDO JSON import picker
                    showingRaidoImportPicker = true
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(100)
        }
    }
    
    // MARK: - Empty State Views

    // State for recovery actions
    @State private var isRecovering = false
    @State private var recoveryMessage: String?
    @State private var showingRecoveryResult = false

    /// Data recovery view for users who HAD trips but lost them
    private var dataRecoveryView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(LogbookTheme.warningYellow)

                Text("No flight data found")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            Text("It looks like you might have lost your flight data when switching apps. Tap below to recover or import your flights.")
                .font(.callout)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Recovery buttons - first row
            HStack(spacing: 12) {
                Button(action: {
                    attemptDataRecovery()
                }) {
                    HStack(spacing: 6) {
                        if isRecovering {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                        Text(isRecovering ? "Recovering..." : "Attempt Recovery")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isRecovering ? Color.gray : LogbookTheme.warningYellow)
                    .cornerRadius(20)
                }
                .disabled(isRecovering)

                Button(action: {
                    showingFileImport = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                        Text("Import Backup")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(20)
                }
                .sheet(isPresented: $showingFileImport) {
                    NavigationView {
                        SimpleFileImportView { content, filename in
                            handleFileImport(content: content, filename: filename)
                        }
                        .padding()
                        .background(LogbookTheme.navy)
                        .navigationTitle("Import Flight Data")
                        .navigationBarItems(trailing: Button("Done") { showingFileImport = false })
                    }
                }

                Spacer()
            }

            // Second row - RAIDO import for USA Jet pilots
            HStack(spacing: 12) {
                Button(action: {
                    // Navigate to Data & Backup tab where RAIDO import is handled
                    // Or show file picker for RAIDO JSON
                    showingRaidoImportPicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplane.departure")
                        Text("Import from RAIDO")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LogbookTheme.accentGreen)
                    .cornerRadius(20)
                }

                Spacer()
            }

            // Recovery result message
            if let message = recoveryMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(message.contains("✅") ? .green : .orange)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Attempt to recover data from various sources
    private func attemptDataRecovery() {
        isRecovering = true
        recoveryMessage = nil

        Task {
            // Step 1: Try SwiftData CloudKit sync
            await store.syncFromCloud()

            if store.trips.count > 0 {
                await MainActor.run {
                    recoveryMessage = "✅ Recovered \(store.trips.count) trips from iCloud!"
                    isRecovering = false
                }
                return
            }

            // Step 2: Check for legacy CloudKit data
            await CloudKitMigrationHelper.shared.checkForLegacyData()

            if case .legacyDataFound(let count) = CloudKitMigrationHelper.shared.migrationStatus {
                // Found legacy data - migrate it
                await CloudKitMigrationHelper.shared.migrateLegacyData(to: store, mergeWithExisting: true)

                await MainActor.run {
                    if store.trips.count > 0 {
                        recoveryMessage = "✅ Migrated \(count) trips from legacy iCloud format!"
                    } else {
                        recoveryMessage = "⚠️ Found legacy data but migration failed. Try importing a backup."
                    }
                    isRecovering = false
                }
                return
            }

            // Step 3: Try JSON file recovery
            let jsonRecovered = store.recoverDataWithCrewMemberMigration()
            if jsonRecovered && store.trips.count > 0 {
                await MainActor.run {
                    recoveryMessage = "✅ Recovered trips from local backup!"
                    isRecovering = false
                }
                return
            }

            // No data found anywhere
            await MainActor.run {
                recoveryMessage = "⚠️ No recoverable data found. Import a backup or RAIDO export."
                isRecovering = false
            }
        }
    }
    
    /// Friendly empty state for NEW users (no scary warning)
    private var newUserEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(LogbookTheme.accentBlue.opacity(0.7))
            
            Text("No Flights Yet")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Tap the '+' button above to log your first flight")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            // Optional: Add a button to re-show welcome
            Button(action: {
                withAnimation {
                    showWelcomeScreen = true
                }
            }) {
                Text("Show Getting Started Guide")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.accentBlue.opacity(0.15))
                    .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.black.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Layout Variants

    // iPhone Layout (Tab bar at bottom)
    private var iPhoneTabLayout: some View {
        CustomizableTabView { tabId in
            contentForTab(tabId)
        }
    }

    // iPad Layout - Now uses bottom tab bar like iPhone!
    private var iPadNavigationLayout: some View {
        iPadCustomizableTabView { tabId in
            contentForTab(tabId)
        }
    }

    // MARK: - iPad Customizable Tab View (Bottom tabs + slide-out More panel)
    @ViewBuilder
    private func iPadCustomizableTabView<Content: View>(@ViewBuilder content: @escaping (String) -> Content) -> some View {
        iPadTabViewWrapper(content: content)
    }
    
    // Content Router (shared by both layouts)
    @ViewBuilder
    private func contentForTab(_ tabId: String) -> some View {
        switch tabId {
        case "logbook": logbookTab
        case "schedule": scheduleTab
        case "perDiem": perDiemTab
        case "scanner": scannerTab
        case "crewContacts": crewContactsTab
        case "clocks": clocksTab
        case "flightTracking": flightTrackingTab
        case "fleetTracker": fleetTrackerTab
        case "airportDatabase":
            AirportDatabaseView()
                .preferredColorScheme(.dark)
        case "gpsRaim": gpsRaimTab
        case "electronicLogbook": electronicLogbookTab
        case "weather": weatherTab
        case "areaGuide": AreaGuideView()
        case "jumpseat":
            // Option 1: Always show (current - for testing)
            JumpseatFinderView()
            
            // Option 2: Protected by subscription (uncomment when ready)
            // ProtectedJumpseatFinderView()
        case "notes": notesTab
        case "documents": documentsTab
        case "calculator": calculatorTab
        case "currency": currencyTab
        case "reports": legsReportTab
        case "flightOps": flightOpsTab
        case "operations": flightOpsTab
        
            
        // Settings tabs
        case "airlineConfig":
            AirlineConfigurationView(airlineSettings: airlineSettings)
                .preferredColorScheme(.dark)
            
        case "aircraftDatabase":
            UnifiedAircraftView()
                .preferredColorScheme(.dark)
            
        case "autoTimeLogging":
            AutoTimeLoggingSettingsView()
                .preferredColorScheme(.dark)
            
        case "scannerEmailSettings":
            ScannerEmailConfigView(airlineSettings: airlineSettings)
                .preferredColorScheme(.dark)
            
        case "appleWatch":
            AppleWatchStatusView(
                phoneWatchConnectivity: watchConnectivity,
                locationManager: locationManager,
                opsManager: opsManager,
                autoTimeSettings: AutoTimeSettings.shared
            )
            .environmentObject(store)
            .preferredColorScheme(.dark)

        case "nocSchedule":
            NOCSettingsView(nocSettings: nocSettings, scheduleStore: scheduleStore)
                .preferredColorScheme(.dark)

        case "nocAlertSettings":
            NOCAlertSettingsView()
                .environmentObject(nocSettings)
                .preferredColorScheme(.dark)

        case "tripGeneration":
            TripGenerationSettingsView()
                .preferredColorScheme(.dark)
            
        case "dataBackup":
            DataBackupSettingsView()
                .environmentObject(store)
                .preferredColorScheme(.dark)

        case "monthlySummary":
            MonthlyEmailSettingsView()
                .preferredColorScheme(.dark)

        case "nocTest":
            NOCTestView(store: store)
                .preferredColorScheme(.dark)
        
        case "gpxTesting":
            GPXTestingView(speedMonitor: speedMonitor)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)

        case "flightTracks":
            FlightTrackListView()
                .preferredColorScheme(.dark)

        case "airportTest":
            AirportDatabaseTestView()
                .preferredColorScheme(.dark)
        
        //case "jumpseat":
        //    JumpseatView()
        //        .preferredColorScheme(.dark)
        
        case "rolling30Day":
            Rolling30DayComplianceView(store: store)
                .preferredColorScheme(.dark)
            
        case "flightTimeLimits":
            DutyLimitSettingsView()
                .preferredColorScheme(.dark)
        
        case "far117Compliance":
            FAR121ComplianceView()
                .environmentObject(store)
                .preferredColorScheme(.dark)

        // ✅ NEW: Universal Search
        case "universalSearch":
            UniversalSearchView { tabId in
                // Navigate to the selected tab
                NotificationCenter.default.post(
                    name: .navigateToTab,
                    object: nil,
                    userInfo: ["tabId": tabId]
                )
            }
            .preferredColorScheme(.dark)

        // ✅ NEW: Help & Support
        case "help":
            HelpView()
                .preferredColorScheme(.dark)

        // ✅ NEW: Search Logbook
        case "search":
            LogbookSearchView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        
        // ✅ NEW: Subscription Debug (DEBUG only)
        #if DEBUG
        case "subscriptionDebug":
            SubscriptionDebugView()
                .preferredColorScheme(.dark)
        #endif

        case "settings":
            settingsTab
            
        default:
            // Fallback - show a placeholder instead of removed MoreTabView
            Text("View not found: \(tabId)")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Tab Views
    private var logbookTab: some View {
        // iPad now uses NavigationStack in iPadTabViewWrapper
        // iPhone uses NavigationView here
        // Both now get proper navigation - content is wrapped appropriately
        logbookContent
    }
    
    private var logbookContent: some View {
        VStack(spacing: 0) {
            // MARK: - Header Section with Zulu Clock & Weather Toggle
            HStack(alignment: .center) {
                ZuluClockView()
                
                Spacer()
                
                // ═══════════════════════════════════════════════════════════════
                // 🛡️ GPS Integrity Status Pill
                // ═══════════════════════════════════════════════════════════════
                GPSSpoofingStatusPill()
                    .padding(.trailing, 6)
                // ═══════════════════════════════════════════════════════════════

                // 🏢 FBO Contact Icon
                FBOIcon(
                    activeTrip: activeTrip,
                    isExpanded: showingFBOBanner,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            showingFBOBanner.toggle()
                        }
                    }
                )
                .padding(.trailing, 6)

                // Weather Condition Icon
                WeatherConditionIcon(
                    activeTrip: activeTrip,
                    isExpanded: showingWeatherBanner,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            showingWeatherBanner.toggle()
                        }
                    }
                )
                .padding(.trailing, 8)
                
                addTripButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // 🆕 PAYWALL: Trial Status Banner
            TrialStatusBanner()
             
            // MARK: - FAR 117 Real-Time Status (Collapsible)
            VStack(spacing: 0) {
                ConfigurableLimitsStatusView(store: store)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(LogbookTheme.navyDark)

            // MARK: - FBO Banner (Collapsible)
            if showingFBOBanner {
                FBOBannerView(activeTrip: activeTrip)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // MARK: - Weather Banner (Collapsible)
            if showingWeatherBanner {
                WeatherBannerView(activeTrip: activeTrip)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // MARK: - Active Trip Banner
            if let activeTrip = activeTrip,
               let tripIndex = store.trips.firstIndex(where: { $0.id == activeTrip.id }) {
                ActiveTripBanner(
                    trip: store.trips[tripIndex],
                    onScanFuel: {
                        selectedScanType = .fuelReceipt
                        selectedDocumentType = .fuelReceipt
                        currentTripId = activeTrip.id
                        currentTripNumber = activeTrip.tripNumber
                        isActiveTrip = true
                        showingScanner = true
                    },
                    onScanDocument: { documentType in
                        selectedDocumentType = documentType
                        selectedScanType = .general
                        currentTripId = activeTrip.id
                        currentTripNumber = activeTrip.tripNumber
                        isActiveTrip = true
                        showingScanner = true
                    },
                    onScanLogPage: {
                        selectedScanType = .logbookPage
                        selectedDocumentType = .logPage
                        currentTripId = activeTrip.id
                        currentTripNumber = activeTrip.tripNumber
                        isActiveTrip = true
                        showingScanner = true
                    },
                    onCompleteTrip: { completeTrip(activeTrip) },
                    onEditTime: { timeType, timeValue in
                        let digits = timeValue.filter { $0.isNumber }
                        if digits.count == 4 || timeValue.isEmpty {
                            var updatedTrip = store.trips[tripIndex]
                            
                            func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
                                return !leg.outTime.isEmpty &&
                                       !leg.offTime.isEmpty &&
                                       !leg.onTime.isEmpty &&
                                       !leg.inTime.isEmpty
                            }
                            
                            var currentLegIndex: Int? = nil
                            for (index, leg) in updatedTrip.legs.enumerated() {
                                switch leg.status {
                                case .completed:
                                    continue
                                case .active:
                                    if !isLegFullyCompleted(leg) {
                                        currentLegIndex = index
                                        break
                                    }
                                    continue
                                case .standby:
                                    currentLegIndex = index
                                    break
                                case .skipped:
                                    continue
                                }
                                if currentLegIndex != nil { break }
                            }
                            
                            guard let legIndex = currentLegIndex else {
                                print("❌ No current leg found for time edit")
                                return
                            }
                            
                            print("⏱️ Editing leg \(legIndex + 1) - \(timeType) = \(timeValue)")
                            
                            var flatIndex = 0
                            var foundPage = -1
                            var foundLegInPage = -1
                            
                            for (pageIndex, logpage) in updatedTrip.logpages.enumerated() {
                                for legInPageIndex in logpage.legs.indices {
                                    if flatIndex == legIndex {
                                        foundPage = pageIndex
                                        foundLegInPage = legInPageIndex
                                        break
                                    }
                                    flatIndex += 1
                                }
                                if foundPage >= 0 { break }
                            }
                            
                            guard foundPage >= 0, foundLegInPage >= 0 else {
                                print("❌ Could not locate leg \(legIndex) in logpages")
                                return
                            }
                            
                            switch timeType {
                            case "OUT":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].outTime = timeValue
                                if updatedTrip.status == .planning {
                                    updatedTrip.status = .active
                                }
                            case "OFF":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime = timeValue
                            case "ON":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime = timeValue
                            case "IN":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].inTime = timeValue
                            case "deadheadOutTime":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].deadheadOutTime = timeValue
                            case "deadheadInTime":
                                updatedTrip.logpages[foundPage].legs[foundLegInPage].deadheadInTime = timeValue
                            default:
                                break
                            }
                            
                            updatedTrip.checkAndAdvanceLeg(at: legIndex)
                            store.updateTrip(updatedTrip, at: tripIndex)
                            PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
                            print("⏱️ Direct time update: \(timeType) = \(timeValue)")
                        } else {
                            editingTimeType = timeType
                            editingTimeValue = timeValue
                            showingTimePicker = true
                        }
                    },
                    onAddLeg: {
                        var updatedTrip = store.trips[tripIndex]
                        var newLeg = FlightLeg(
                            departure: updatedTrip.legs.last?.arrival ?? "",
                            arrival: "",
                            outTime: "",
                            offTime: "",
                            onTime: "",
                            inTime: ""
                        )
                        
                        // ✅ NEW CODE HERE:
                        let allPreviousComplete = updatedTrip.legs.allSatisfy { leg in
                            !leg.outTime.isEmpty &&
                            !leg.offTime.isEmpty &&
                            !leg.onTime.isEmpty &&
                            !leg.inTime.isEmpty
                        }
                        
                        if allPreviousComplete {
                            newLeg.status = .active
                            print("✅ New leg set to ACTIVE (all previous legs fully complete)")
                        } else {
                            newLeg.status = .standby
                            print("⏸️ New leg set to STANDBY (previous legs have missing times)")
                        }
                        
                        updatedTrip.legs.append(newLeg)
                        
                        // ✅ Check if previous leg should advance
                        if updatedTrip.legs.count > 1 {
                            updatedTrip.checkAndAdvanceLeg(at: updatedTrip.legs.count - 2)
                        }
                        
                        store.updateTrip(updatedTrip, at: tripIndex)
                        
                        // ✅ Sync new leg to watch
                        PhoneWatchConnectivity.shared.currentLegIndex = updatedTrip.legs.count - 1
                        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
                        
                        selectedTripForEditing = store.trips[tripIndex]
                        showingDataEntry = true
                    },
                    onActivateTrip: {
                        // Activate the trip: change status from .planning to .active
                        var updatedTrip = store.trips[tripIndex]
                        updatedTrip.status = .active
                        
                        // Set first leg to active if it's in standby
                        if !updatedTrip.legs.isEmpty && updatedTrip.legs[0].status == .standby {
                            // Find first leg in logpages
                            if !updatedTrip.logpages.isEmpty && !updatedTrip.logpages[0].legs.isEmpty {
                                updatedTrip.logpages[0].legs[0].status = .active
                                print("✅ First leg activated")
                            }
                        }
                        
                        store.updateTrip(updatedTrip, at: tripIndex)
                        
                        // Start duty timer if enabled
                        if !DutyTimerManager.shared.isOnDuty {
                            DutyTimerManager.shared.startDuty()
                            print("⏱️ Duty timer started automatically")
                        }
                        
                        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
                        print("🚀 Trip #\(updatedTrip.tripNumber) activated!")
                    },
                    dutyStartTime: $dutyTimerManager.dutyStartTime,
                    airlineSettings: airlineSettings
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            // MARK: - Empty State (Smart Logic)
            if store.trips.isEmpty {
                if hasEverHadTrips {
                    // User HAD trips before - show recovery (data loss scenario)
                    dataRecoveryView
                } else {
                    // New user - show friendly empty state (no scary warning)
                    newUserEmptyStateView
                }
            }
            
            // MARK: - View All Legs Button
            Button(action: { showLegsView = true }) {
                HStack(spacing: 4) {
                    Text("View All Legs")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    tripStatisticsView
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .sheet(isPresented: $showLegsView) {
                FlightLegsView(store: store)
            }
            
            Divider()
                .background(LogbookTheme.accentBlue.opacity(0.2))
                .padding(.horizontal, 16)
            
            // MARK: - Trips List
            OrganizedLogbookView(store: store) { idx in
                populateForEdit(at: idx)
                showTripSheet = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LogbookTheme.navy.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showLegsView) {
            LegsReportView(store: store)
        }
        .sheet(isPresented: $showingFAR117Detail) {
            FAR117DetailView(status: calculateFAR117Limits(for: Date(), store: store), tripDate: Date())
        }
    }
    
    private var scheduleTab: some View {
        ScheduleCalendarView()
    }
    
    private var perDiemTab: some View {
        PerDiemTabView(store: store)
    }
    
    private var scannerTab: some View {
        TripScannerView(
            store: store,
            airlineSettings: airlineSettings,
            documentStore: sharedDocumentStore,
            crewContactManager: crewContactManager,
            preselectedTrip: activeTrip
        )
    }
    
    private var weatherTab: some View {
        WeatherView()
    }
    
    private var crewContactsTab: some View {
        Group {
            if isPad {
                CrewImportHelperView(contactManager: crewContactManager)
            } else {
                NavigationView {
                    CrewImportHelperView(contactManager: crewContactManager)
                }
            }
        }
    }
    
    // moreTab removed - now using TabManager slide-out panel
    //New Trip Button Below
    
    private var addTripButton: some View {
        HStack(spacing: 12) {
            Menu {
                flightTypeButtons
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: trialChecker.canCreateTrip ? "airplane.departure" : "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("New")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(trialChecker.canCreateTrip ? .white : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    trialChecker.canCreateTrip ? 
                    LogbookTheme.accentGreen.opacity(0.10) :
                    Color.white.opacity(0.05)
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(trialChecker.canCreateTrip ? LogbookTheme.accentGreen.opacity(0.5) : .gray, lineWidth: 1)
                )
            }
            .disabled(!trialChecker.canCreateTrip)
            .simultaneousGesture(TapGesture().onEnded {
                if !trialChecker.canCreateTrip {
                    showingPaywall = true
                }
            })
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        // RAIDO JSON file import
        .fileImporter(
            isPresented: $showingRaidoImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    RaidoImportHandler.shared.handleIncomingFile(url)
                }
            case .failure(let error):
                print("❌ RAIDO file selection failed: \(error)")
            }
        }
        // RAIDO import confirmation sheet
        .sheet(isPresented: .init(
            get: { RaidoImportHandler.shared.showingConfirmation },
            set: { RaidoImportHandler.shared.showingConfirmation = $0 }
        )) {
            RaidoImportConfirmationView(store: store)
        }
        // RAIDO import success alert
        .alert("Import Successful", isPresented: .init(
            get: { RaidoImportHandler.shared.importSuccess },
            set: { RaidoImportHandler.shared.importSuccess = $0 }
        )) {
            Button("OK") { }
        } message: {
            Text("Successfully imported \(RaidoImportHandler.shared.importedTripCount) trips from RAIDO!")
        }
        // General file import error alert
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage ?? "Unknown error occurred")
        }
        // General file import success alert
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK") { }
        } message: {
            Text(importSuccessMessage ?? "Import completed successfully")
        }
    }

    // MARK: - Flight Type Menu Buttons (Reusable)
    @ViewBuilder
    private var flightTypeButtons: some View {
        Button(action: {
            createNewTrip(type: .operating)
        }) {
            Label("New Flight", systemImage: "airplane.departure")
        }
        
        Button(action: {
            createNewTrip(type: .deadhead)
        }) {
            Label("New Deadhead", systemImage: "airplaneseat")
        }
        
        Button(action: {
            createNewTrip(type: .simulator)
        }) {
            Label("Sim Session", systemImage: "gauge.with.dots.needle.67percent")
        }
    }
    
    // MARK: - Create Trip Helper (DRY - Don't Repeat Yourself)
    private func createNewTrip(type: TripType) {
        guard trialChecker.canCreateTrip else {
            showingPaywall = true
            return
        }
        
        resetTripFields()
        tripType = type
        shouldAutoStartDuty = (type != .simulator)
        
        // Auto-fill departure for flights (not simulator)
        if type != .simulator {
            if let currentAirport = locationManager.currentAirport {
                if legs.isEmpty { legs = [FlightLeg()] }
                legs[0].departure = currentAirport
                print("✈️ Pre-filled departure: \(currentAirport)")
            } else if let nearestAirport = locationManager.nearbyAirports.first {
                if legs.isEmpty { legs = [FlightLeg()] }
                legs[0].departure = nearestAirport.icao
                print("✈️ Pre-filled departure with nearest: \(nearestAirport.icao)")
            }
        } else {
            // Simulator doesn't need legs
            legs = []
        }
        
        showTripSheet = true
    }
    
    private var clocksTab: some View {
        ClocksAndTimersView()
            .environmentObject(dutyTimerManager)
            .environmentObject(airlineSettings)
            .environmentObject(activityManager)
            .environmentObject(watchConnectivity)
    }
    
    private var flightTrackingTab: some View {
        FlightTrackingView()
            .preferredColorScheme(.dark)
    }
    
    private var fleetTrackerTab: some View {
        FlightTrackingView()
            .preferredColorScheme(.dark)
    }
    
    private var gpsRaimTab: some View {
        GPSRAIMView()
            .preferredColorScheme(.dark)
    }
    
    private var electronicLogbookTab: some View {
        SimpleElectronicLogbookView(mainStore: store)
            .preferredColorScheme(.dark)
    }
    
    private var dataBackupTab: some View {
        DataBackupView(
            store: store,
            airlineSettings: airlineSettings,
            nocSettings: nocSettings,
            scannerSettings: scannerSettings,
            documentStore: sharedDocumentStore
        )
        .preferredColorScheme(.dark)
    }
    
    private var settingsTab: some View {
        SettingsView(
            store: store,
            airlineSettings: airlineSettings,
            nocSettings: nocSettings
        )
        .preferredColorScheme(.dark)
    }
    
    private var notesTab: some View {
        NotesView()
    }
    
    private var documentsTab: some View {
        DocumentsView()
    }
    
    private var calculatorTab: some View {
        FlightCalculatorView()
    }
    
    private var currencyTab: some View {
        CurrencyTrackerView()
    }
    
    private var legsReportTab: some View {
        LegsReportView(store: store)
    }
    
    private var flightOpsTab: some View {
        FlightOperationsView(airlineSettings: airlineSettings)
    }
    
    // MARK: - Email Formatting Helpers
    private func getEmailForScanType(_ scanType: ScanType) -> String {
        switch scanType {
        case .logbookPage:
            return sharedEmailSettings.settings.logbookEmail.isEmpty ?
            sharedEmailSettings.settings.generalEmail :
            sharedEmailSettings.settings.logbookEmail
        case .fuelReceipt:
            return sharedEmailSettings.settings.receiptsEmail.isEmpty ?
            sharedEmailSettings.settings.generalEmail :
            sharedEmailSettings.settings.receiptsEmail
        case .maintenanceLog, .general:
            return sharedEmailSettings.settings.generalEmail
        }
    }
    
    private func formatEmailSubject(for document: ScannedDocument, trip: Trip) -> String {
        let tripNumber = trip.tripNumber.isEmpty ? "N/A" : trip.tripNumber
        let aircraft = trip.aircraft.isEmpty ? "N/A" : trip.aircraft
        let route = trip.legs.isEmpty ? "N/A" : "\(trip.legs.first?.departure ?? "???")-\(trip.legs.last?.arrival ?? "???")"
        
        switch document.documentType {
        case .logbookPage:
            return "Logbook Page - Trip \(tripNumber) - \(aircraft) - \(route)"
        case .fuelReceipt:
            return "Fuel Receipt - Trip \(tripNumber) - \(aircraft)"
        case .maintenanceLog:
            return "Maintenance Log - \(aircraft) - Trip \(tripNumber)"
        case .general:
            return "Document - Trip \(tripNumber) - \(aircraft)"
        }
    }
    
    private func formatEmailBody(for document: ScannedDocument, trip: Trip) -> String {
        var body = ""
        body += "TRIP INFORMATION\n"
        body += "================\n"
        body += "Trip Number: \(trip.tripNumber)\n"
        body += "Aircraft: \(trip.aircraft)\n"
        body += "Date: \(trip.date.formatted(date: .abbreviated, time: .omitted))\n"
        
        if !trip.legs.isEmpty {
            body += "\nROUTE\n"
            body += "=====\n"
            let route = trip.legs.map { "\($0.departure)-\($0.arrival)" }.joined(separator: " > ")
            body += route + "\n"
        }
        
        if !trip.crew.isEmpty {
            body += "\nCREW\n"
            body += "====\n"
            for crewMember in trip.crew where !crewMember.name.isEmpty {
                body += "\(crewMember.role): \(crewMember.name)\n"
            }
        }
        
        body += "\nDOCUMENT DETAILS\n"
        body += "================\n"
        body += "Type: \(document.documentType.rawValue)\n"
        body += "Filename: \(document.filename)\n"
        body += "Scanned: \(document.dateScanned.formatted(date: .abbreviated, time: .shortened))\n"
        body += "Format: \(document.fileFormat.rawValue)\n"
        body += "Size: \(document.formattedFileSize)\n"
        
        if !trip.notes.isEmpty {
            body += "\nNOTES\n"
            body += "=====\n"
            body += trip.notes + "\n"
        }
        
        body += "\n---\n"
        body += "Sent from ProPilot App\n"
        
        return body
    }
    
    // MARK: - Aircraft TAT Auto-fill Helper
    private func autoFillTATForAircraft(_ aircraft: String) {
        guard !aircraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let matchingTrips = store.trips
            .filter {
                $0.aircraft.uppercased() == aircraft.uppercased() &&
                $0.status == .completed &&
                !$0.formattedFinalTAT.isEmpty
            }
            .sorted { $0.date > $1.date }
        
        if let lastTrip = matchingTrips.first {
            tatStart = lastTrip.formattedFinalTAT
            print("✈️ Auto-filled TAT from last \(aircraft) flight: \(lastTrip.formattedFinalTAT)")
        }
    }
    
    // MARK: - Time Editing Helper
    private func saveTimeToActiveTrip(timeType: String, timeValue: String) {
        guard let activeTrip = activeTrip,
              let tripIndex = store.trips.firstIndex(where: { $0.id == activeTrip.id }) else {
            print("❌ No active trip found")
            return
        }
        
        var updatedTrip = store.trips[tripIndex]
        
        // ✅ FIXED: Use same smart leg detection as onEditTime handler
        func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
            return !leg.outTime.isEmpty &&
                   !leg.offTime.isEmpty &&
                   !leg.onTime.isEmpty &&
                   !leg.inTime.isEmpty
        }
        
        var currentLegIndex: Int? = nil
        for (index, leg) in updatedTrip.legs.enumerated() {
            switch leg.status {
            case .completed:
                continue
            case .active:
                // Only use this leg if it still has empty times
                if !isLegFullyCompleted(leg) {
                    currentLegIndex = index
                    break
                }
                continue
            case .standby:
                currentLegIndex = index
                break
            case .skipped:
                continue
            }
            if currentLegIndex != nil { break }
        }
        
        guard let legIndex = currentLegIndex else {
            print("❌ No current leg found for time edit")
            return
        }
        
        print("⏱️ saveTimeToActiveTrip - Editing leg \(legIndex + 1) - \(timeType) = \(timeValue)")
        
        // ✅ FIXED: Update through logpages directly (not computed property setter)
        // Find which logpage contains this leg
        var flatIndex = 0
        var foundPage = -1
        var foundLegInPage = -1
        
        for (pageIndex, logpage) in updatedTrip.logpages.enumerated() {
            for legInPageIndex in logpage.legs.indices {
                if flatIndex == legIndex {
                    foundPage = pageIndex
                    foundLegInPage = legInPageIndex
                    break
                }
                flatIndex += 1
            }
            if foundPage >= 0 { break }
        }
        
        guard foundPage >= 0, foundLegInPage >= 0 else {
            print("❌ Could not locate leg \(legIndex) in logpages")
            return
        }
        
        // Update the actual leg in logpages
        switch timeType {
        case "OUT":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].outTime = timeValue
            if updatedTrip.status == .planning {
                updatedTrip.status = .active
            }
        case "OFF":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime = timeValue
        case "ON":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime = timeValue
        case "IN":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].inTime = timeValue
        case "deadheadOutTime":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].deadheadOutTime = timeValue
        case "deadheadInTime":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].deadheadInTime = timeValue
        default:
            print("❌ Unknown time type: \(timeType)")
            return
        }
        
        // ✅ FIXED: Check if leg should be completed and advanced
        updatedTrip.checkAndAdvanceLeg(at: legIndex)
        
        store.updateTrip(updatedTrip, at: tripIndex)
        
        // Sync to watch
        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
        
        print("✅ Saved \(timeType): \(timeValue) to trip #\(updatedTrip.tripNumber) leg \(legIndex + 1)")
    }
    
    // ✅ NEW: Clear time from active trip
    private func clearTimeFromActiveTrip() {
        guard let activeTrip = activeTrip,
              let tripIndex = store.trips.firstIndex(where: { $0.id == activeTrip.id }) else {
            print("❌ No active trip found")
            return
        }
        
        var updatedTrip = store.trips[tripIndex]
        
        // ✅ FIXED: Use same smart leg detection
        func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
            return !leg.outTime.isEmpty &&
                   !leg.offTime.isEmpty &&
                   !leg.onTime.isEmpty &&
                   !leg.inTime.isEmpty
        }
        
        var currentLegIndex: Int? = nil
        for (index, leg) in updatedTrip.legs.enumerated() {
            switch leg.status {
            case .completed:
                continue
            case .active:
                if !isLegFullyCompleted(leg) {
                    currentLegIndex = index
                    break
                }
                continue
            case .standby:
                currentLegIndex = index
                break
            case .skipped:
                continue
            }
            if currentLegIndex != nil { break }
        }
        
        guard let legIndex = currentLegIndex else {
            print("❌ No current leg found for clear")
            return
        }
        
        // ✅ FIXED: Find actual location in logpages
        var flatIndex = 0
        var foundPage = -1
        var foundLegInPage = -1
        
        for (pageIndex, logpage) in updatedTrip.logpages.enumerated() {
            for legInPageIndex in logpage.legs.indices {
                if flatIndex == legIndex {
                    foundPage = pageIndex
                    foundLegInPage = legInPageIndex
                    break
                }
                flatIndex += 1
            }
            if foundPage >= 0 { break }
        }
        
        guard foundPage >= 0, foundLegInPage >= 0 else {
            print("❌ Could not locate leg \(legIndex) in logpages")
            return
        }
        
        // Update through logpages directly
        switch editingTimeType {
        case "OUT":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].outTime = ""
            print("🗑️ Cleared OUT time from trip #\(updatedTrip.tripNumber)")
        case "OFF":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime = ""
            print("🗑️ Cleared OFF time from trip #\(updatedTrip.tripNumber)")
        case "ON":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime = ""
            print("🗑️ Cleared ON time from trip #\(updatedTrip.tripNumber)")
        case "IN":
            updatedTrip.logpages[foundPage].legs[foundLegInPage].inTime = ""
            if updatedTrip.status == .completed {
                updatedTrip.status = .active
            }
            print("🗑️ Cleared IN time from trip #\(updatedTrip.tripNumber)")
        default:
            print("❌ Unknown time type: \(editingTimeType)")
            return
        }
        
        store.updateTrip(updatedTrip, at: tripIndex)
        editingTimeValue = ""
        
        // ✅ NEW: Re-evaluate ALL leg statuses after clearing a time
        reEvaluateLegStatuses(for: tripIndex)
        
        // Sync to watch
        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
        
        print("✅ Time deleted successfully")
    }
    
    // ✅ NEW FUNCTION: Re-evaluate all leg statuses after time changes
    private func reEvaluateLegStatuses(for tripIndex: Int) {
        var trip = store.trips[tripIndex]
        
        for index in 0..<trip.legs.count {
            // Check if ALL PREVIOUS legs are complete
            let allPreviousComplete = trip.legs[0..<index].allSatisfy { leg in
                !leg.outTime.isEmpty &&
                !leg.offTime.isEmpty &&
                !leg.onTime.isEmpty &&
                !leg.inTime.isEmpty
            }
            
            // Find location in logpages
            var flatIndex = 0
            var foundPage = -1
            var foundLegInPage = -1
            
            for (pageIndex, logpage) in trip.logpages.enumerated() {
                for legInPageIndex in logpage.legs.indices {
                    if flatIndex == index {
                        foundPage = pageIndex
                        foundLegInPage = legInPageIndex
                        break
                    }
                    flatIndex += 1
                }
                if foundPage >= 0 { break }
            }
            
            guard foundPage >= 0, foundLegInPage >= 0 else { continue }
            
            // Update status based on previous legs
            if allPreviousComplete {
                if trip.logpages[foundPage].legs[foundLegInPage].status != .active {
                    trip.logpages[foundPage].legs[foundLegInPage].status = .active
                    print("✅ Promoted leg \(index + 1) to ACTIVE (previous legs complete)")
                }
            } else {
                if trip.logpages[foundPage].legs[foundLegInPage].status == .active {
                    trip.logpages[foundPage].legs[foundLegInPage].status = .standby
                    print("⏸️ Demoted leg \(index + 1) to STANDBY (previous legs incomplete)")
                }
            }
        }
        
        store.updateTrip(trip, at: tripIndex)
        print("✅ Re-evaluated all leg statuses")
    }
    
    // MARK: - Number pad helper functions
    private func numberButton(_ number: String) -> some View {
        Button(action: {
            if editingTimeValue.count < 4 {
                editingTimeValue += number
            }
        }) {
            Text(number)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(LogbookTheme.accentBlue)
                .cornerRadius(35)
        }
    }
    
    private func clearButton() -> some View {
        Button(action: {
            editingTimeValue = ""
        }) {
            Text("Clear")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(LogbookTheme.accentOrange)
                .cornerRadius(35)
        }
    }
    
    private func backspaceButton() -> some View {
        Button(action: {
            if !editingTimeValue.isEmpty {
                editingTimeValue.removeLast()
            }
        }) {
            Image(systemName: "delete.left")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(LogbookTheme.accentOrange)
                .cornerRadius(35)
        }
    }
    
    private func formatTimeDisplay(_ input: String) -> String {
        let padded = input.padding(toLength: 4, withPad: "0", startingAt: 0)
        let hours = String(padded.prefix(2))
        let minutes = String(padded.suffix(2))
        return "\(hours):\(minutes)"
    }
    
    // MARK: - All helper functions
    
    private func handleFileImport(content: String, filename: String) {
        print("📁 Attempting to import and decode \(filename)...")

        guard let data = content.data(using: .utf8) else {
            print("Error: Could not convert file content to Data.")
            showingFileImport = false
            importErrorMessage = "Could not read file content."
            showingImportError = true
            return
        }

        // Step 1: Check if this is a RAIDO JSON file
        if isRaidoJSONFormat(data) {
            print("✅ Detected RAIDO JSON format - routing to RAIDO import handler")
            showingFileImport = false

            // Save content to temp file and route to RAIDO handler
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")

            do {
                try data.write(to: tempURL)
                RaidoImportHandler.shared.handleIncomingFile(tempURL)
            } catch {
                print("❌ Failed to save temp RAIDO file: \(error)")
                importErrorMessage = "Failed to process RAIDO file: \(error.localizedDescription)"
                showingImportError = true
            }
            return
        }

        // Step 2: Try to decode as ProPilot backup format using the store's import method
        // This handles multiple date formats and provides smart duplicate detection
        let result = store.importFromJSON(data, mergeWithExisting: true)

        if result.success {
            print("✅ Import complete: \(result.message)")
            importSuccessMessage = result.message
            showingImportSuccess = true
        } else {
            print("❌ Import failed: \(result.message)")
            // Provide helpful error message
            importErrorMessage = "This doesn't appear to be a valid ProPilot backup file or RAIDO export.\n\nSupported formats:\n• ProPilot JSON backup\n• RAIDO JSON export"
            showingImportError = true
        }

        showingFileImport = false
    }

    /// Detects if JSON data is in RAIDO format (has "Report" array with RaidoLab_ fields)
    private func isRaidoJSONFormat(_ data: Data) -> Bool {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let report = json["Report"] as? [[String: Any]], !report.isEmpty {
                    let firstRow = report[0]
                    let keys = Set(firstRow.keys)

                    // Check for RAIDO-specific key names
                    let hasDateField = keys.contains("RaidoLab_TimeMode") || keys.contains("RaidoLab_Name")
                    let hasFlightFields = keys.contains("RaidoLab_Code") &&
                                          keys.contains("RaidoLab_Dep") &&
                                          keys.contains("RaidoLab_Arr")

                    if hasDateField && hasFlightFields {
                        print("🔍 RAIDO format detected: has Report array with RaidoLab_ fields")
                        return true
                    }
                }
            }
        } catch {
            print("🔍 JSON parsing failed for format detection: \(error)")
        }
        return false
    }
    
    private func createTextImage(from text: String) -> UIImage {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            let rect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
    
    private func showAllLegs() {
        showLegsView = true
    }
    
    private func showFreightPaperwork(for trip: Trip) {
        selectedScanType = .general
        currentTripId = trip.id
        currentTripNumber = trip.tripNumber
        isActiveTrip = true
        showingScanner = true
    }
    
    private func checkForDuplicateTripNumber(_ tripNumber: String) -> Trip? {
        guard !tripNumber.isEmpty else { return nil }
        
        return store.trips.first { trip in
            trip.tripType == .operating &&
            trip.tripNumber.uppercased() == tripNumber.uppercased() &&
            (editingTripIndex == nil || trip.id != store.trips[editingTripIndex!].id)
        }
    }
    
    private func saveNewTripWithDuplicateCheck() {
        if tripType == .operating && !tripNumber.isEmpty {
            if let existingTrip = checkForDuplicateTripNumber(tripNumber) {
                showDuplicateTripAlert(existingTrip: existingTrip)
                return
            }
        }
        saveNewTrip()
    }
    
    private func showDuplicateTripAlert(existingTrip: Trip) {
        existingTripForDuplicate = existingTrip
        showingDuplicateTripAlert = true
    }
    
    private func addLegsToExistingTrip() {
        guard let existingTrip = existingTripForDuplicate,
              let tripIndex = store.trips.firstIndex(where: { $0.id == existingTrip.id }) else {
            return
        }
        
        var updatedTrip = existingTrip
        updatedTrip.legs.append(contentsOf: legs)
        store.updateTrip(updatedTrip, at: tripIndex)
        showTripSheet = false
        resetTripFields()
    }
    
    private func handleAirportArrival(_ airport: (icao: String, name: String)) {
        currentAirport = airport
        
        if activeTrip == nil {
            showingAirportAlert = true
        }
        
        if activeTrip == nil && shouldAutoStartDuty {
            startTripFromAirportArrival()
        }
    }
    
    private func setupFlightDetection() {
        print("🛫 Flight detection setup - add onAirportArrival to PilotLocationManager for full auto-trigger")
    }
    
    private func setupWatchIntegration() {
        print("⌚ Watch integration setup - add activate() and onMessageReceived to PhoneWatchConnectivity for full sync")
    }
    
    private func checkAndAutoStartDutyForActiveTrip() {
        print("🔍 checkAndAutoStartDutyForActiveTrip called")
        
        guard let activeTrip = activeTrip else {
            print("❌ No activeTrip - returning")
            return
        }
        
        print("🔍 activeTrip found: \(activeTrip.tripNumber)")
        print("🔍 tripType: \(activeTrip.tripType)")
        print("🔍 aircraft: '\(activeTrip.aircraft)'")
        print("🔍 legs count: \(activeTrip.legs.count)")
        
        if let firstLeg = activeTrip.legs.first {
            print("🔍 firstLeg.departure: '\(firstLeg.departure)'")
            print("🔍 firstLeg.arrival: '\(firstLeg.arrival)'")
        }
        
        startUnifiedDutyTimer()
        writeWidgetData(isOnDuty: true, dutyTime: "0:00", tripNumber: activeTrip.tripNumber)
        
        if activeTrip.tripType == .operating,
           let firstLeg = activeTrip.legs.first,
           !firstLeg.departure.isEmpty {
            
            // Use arrival if available, otherwise show "TBD"
            let arrivalCode = firstLeg.arrival.isEmpty ? "TBD" : firstLeg.arrival
            
            print("✅ Conditions met - starting Live Activity")
            
            Task {
                let airportInfo = await airportDB.getAirportInfo(firstLeg.departure)
                let attributes = PilotDutyAttributes(
                    tripNumber: activeTrip.tripNumber,
                    aircraftType: activeTrip.aircraft,
                    departure: firstLeg.departure,
                    arrival: firstLeg.arrival,
                    dutyStartTime: dutyTimerManager.dutyStartTime ?? Date()
                )
                let initialState = PilotDutyAttributes.ContentState.initial(
                    airport: firstLeg.departure,
                    airportName: airportInfo?.airportName ?? "Unknown Airport"
                )
                
                print("🧮 Attributes prepared: trip=\(attributes.tripNumber), acft=\(attributes.aircraftType), \(attributes.departure)→\(attributes.arrival)")
                print("🧮 Initial state: airport=\(initialState.currentAirport), name=\(initialState.currentAirportName)")
                
                activityManager.startActivity(
                    tripNumber: activeTrip.tripNumber,
                    aircraft: activeTrip.aircraft,
                    departure: firstLeg.departure,
                    arrival: arrivalCode,              // ← Use arrivalCode instead
                    currentAirport: firstLeg.departure,
                    currentAirportName: airportInfo?.airportName ?? "Unknown Airport",
                    dutyStartTime: dutyTimerManager.dutyStartTime ?? Date()
                )
                print("🛫 Auto-started Live Activity for trip \(activeTrip.tripNumber)")
            }
        } else {
            print("⚠️ Conditions NOT met for Live Activity start. tripType=.operating? \(activeTrip.tripType == .operating), hasFirstLeg=\(activeTrip.legs.first != nil)")
        }
    }
    
    private func startTripFromAirportArrival() {
        guard let airport = currentAirport else { return }
        
        let tripDate = TimeDisplayUtility.getCurrentTripDate()
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        if AutoTimeSettings.shared.useZuluTime {
            formatter.timeZone = TimeZone(identifier: "UTC")
        }
        
        let newTrip = Trip(
            id: UUID(),
            tripNumber: "AUTO-\(airport.icao)-\(formatter.string(from: tripDate))",
            aircraft: "N-UNKNOWN",
            date: tripDate,
            tatStart: "",
            crew: [CrewMember(role: "Captain", name: ""), CrewMember(role: "First Officer", name: "")],
            notes: "Auto-started from arrival at \(airport.name)",
            legs: [FlightLeg(departure: airport.icao, arrival: "")],
            tripType: .operating,
            status: .active,
            pilotRole: .captain,
            receiptCount: 0,
            logbookPageSent: false,
            perDiemStarted: nil,
            perDiemEnded: nil
        )
        
        store.addTrip(newTrip)
        checkAndAutoStartDutyForActiveTrip()
        print("🛬 Auto-created and started trip from \(airport.icao) with date: \(tripDate)")
    }
    
    private func startUnifiedDutyTimer() {
        DutyTimerManager.shared.startDuty()
        print("⏱️ Duty timer started via DutyTimerManager")
    }
    
    private func writeWidgetData(isOnDuty: Bool, dutyTime: String, tripNumber: String) {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
            sharedDefaults.set(isOnDuty, forKey: "isOnDuty")
            sharedDefaults.set(dutyTime, forKey: "dutyTimeRemaining")
            sharedDefaults.set(tripNumber, forKey: "currentTripNumber")
            sharedDefaults.synchronize()
            print("📱 Widget data updated: onDuty=\(isOnDuty), time=\(dutyTime), trip=\(tripNumber)")
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Deep link handling placeholder
    }
    
    private func resetTripFields() {
        tripNumber = ""
        aircraft = ""
        date = TimeDisplayUtility.getCurrentTripDate()
        tatStart = ""
        crew = [
            CrewMember(role: "Captain", name: ""),
            CrewMember(role: "First Officer", name: "")
        ]
        notes = ""
        legs = [FlightLeg()]
        editingTripIndex = nil
        simTotalMinutes = 120
    }
    
    private func populateForEdit(at idx: Int) {
        guard store.trips.indices.contains(idx) else { return }
        let trip = store.trips[idx]
        tripNumber = trip.tripNumber
        aircraft = trip.aircraft
        date = trip.date
        tatStart = trip.tatStart
        crew = trip.crew
        notes = trip.notes
        legs = trip.legs
        tripType = trip.tripType
        deadheadAirline = trip.deadheadAirline ?? ""
        deadheadFlightNumber = trip.deadheadFlightNumber ?? ""
        pilotRole = trip.pilotRole
        shouldAutoStartDuty = false
        editingTripIndex = idx
        
        if trip.tripType == .simulator {
            simTotalMinutes = trip.simulatorMinutes ?? 120
        }
    }
    
    private func populateTripForEditing(_ trip: Trip) {
        tripNumber = trip.tripNumber
        aircraft = trip.aircraft
        date = trip.date
        tatStart = trip.tatStart
        crew = trip.crew
        notes = trip.notes
        legs = trip.legs
        tripType = trip.tripType
        deadheadAirline = trip.deadheadAirline ?? ""
        deadheadFlightNumber = trip.deadheadFlightNumber ?? ""
        pilotRole = trip.pilotRole
        shouldAutoStartDuty = false
        
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            editingTripIndex = index
        }
        
        if trip.tripType == .simulator {
            simTotalMinutes = trip.simulatorMinutes ?? 120
        }
    }
    
    private func saveNewTrip() {
        let tripStatus: TripStatus = shouldAutoStartDuty ? .active : .planning
        
        let trip = Trip(
            id: UUID(),
            tripNumber: tripNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            aircraft: aircraft,
            date: date,
            tatStart: tatStart,
            crew: crew,
            notes: notes,
            legs: legs,
            tripType: tripType,
            deadheadAirline: tripType == .deadhead ? deadheadAirline : nil,
            deadheadFlightNumber: tripType == .deadhead ? deadheadFlightNumber : nil,
            status: tripStatus,
            pilotRole: pilotRole,
            receiptCount: 0,
            logbookPageSent: false,
            perDiemStarted: nil,
            perDiemEnded: nil,
            simulatorMinutes: tripType == .simulator ? simTotalMinutes : nil
        )
        
        // ✅ NEW: Initialize leg statuses if trip is being activated
        var finalTrip = trip
        if tripStatus == .active && legs.count > 1 {
            finalTrip.initializeLegStatuses()
        }
        
        store.addTrip(finalTrip)
        PhoneWatchConnectivity.shared.syncCurrentLegToWatch()

        // FlightAware integration - fetch route/ETA data
        fetchFlightAwareData(for: finalTrip)

        showTripSheet = false
        resetTripFields()

        if tripStatus == .active {
            checkAndAutoStartDutyForActiveTrip()
        }
    }
    
    private func saveEditedTrip() {
        guard let idx = editingTripIndex, store.trips.indices.contains(idx) else { return }
        var trip = store.trips[idx]
        
        trip.tripNumber = tripNumber
        trip.aircraft = aircraft
        trip.date = date
        trip.tatStart = tatStart
        trip.crew = crew
        trip.notes = notes
        trip.legs = legs
        trip.tripType = tripType
        trip.deadheadAirline = tripType == .deadhead ? deadheadAirline : nil
        trip.deadheadFlightNumber = tripType == .deadhead ? deadheadFlightNumber : nil
        trip.pilotRole = pilotRole
        trip.simulatorMinutes = tripType == .simulator ? simTotalMinutes : nil
        store.updateTrip(trip, at: idx)

        // FlightAware integration - fetch route/ETA data
        fetchFlightAwareData(for: trip)

        showTripSheet = false
        resetTripFields()

        if trip.status == .active {
            checkAndAutoStartDutyForActiveTrip()
        }
    }

    private func completeTrip(_ trip: Trip) {
        if let index = store.trips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = trip
            
            // 🆕 CAPTURE DUTY TIME from DutyTimerManager before ending
            if DutyTimerManager.shared.isOnDuty {
                print("📋 Capturing duty time before completing trip...")
                updatedTrip = DutyTimerManager.shared.applyDutyTimeToTrip(updatedTrip)
            } else {
                print("ℹ️ No active duty timer - trip will use auto-calculated duty times")
            }
            
            updatedTrip.status = TripStatus.completed
            store.updateTrip(updatedTrip, at: index)
            
            activityManager.endActivity()
            writeWidgetData(isOnDuty: false, dutyTime: "0:00", tripNumber: "------")
            
            // End duty timer AFTER capturing the data
            DutyTimerManager.shared.endDuty()
            
            print("✅ Trip #\(trip.tripNumber) completed with duty time saved")
        }
    }

    // MARK: - FlightAware Integration

    /// Fetch FlightAware data for a trip's legs
    private func fetchFlightAwareData(for trip: Trip) {
        // Check if FlightAware is configured and enabled
        guard FlightAwareRepository.shared.isReady,
              airlineSettings.settings.enableFlightAwareTracking else {
            return
        }

        let prefix = airlineSettings.settings.flightNumberPrefix
        guard !prefix.isEmpty else {
            print("[FlightAware] No airline prefix configured")
            return
        }

        // Check if trip has any legs with flight numbers
        let legsWithFlightNumbers = trip.legs.filter { !$0.flightNumber.isEmpty }
        guard !legsWithFlightNumbers.isEmpty else {
            print("[FlightAware] No flight numbers in trip")
            return
        }

        // Fetch data asynchronously
        Task {
            let results = await FlightAwareRepository.shared.lookupFlightsForTrip(trip, airlinePrefix: prefix)

            guard !results.isEmpty else {
                print("[FlightAware] No flights found for trip")
                return
            }

            print("[FlightAware] Found \(results.count) flight(s) for trip #\(trip.tripNumber)")

            // Send share notification for the first leg if enabled
            if airlineSettings.settings.autoShareFlightNotifications,
               let firstLeg = legsWithFlightNumbers.first,
               let flightData = results[firstLeg.id.uuidString] {
                await FlightAwareNotificationService.shared.sendFlightSharePrompt(
                    for: flightData,
                    leg: firstLeg
                )
            }

            // Post notification that FlightAware data is available
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .flightAwareDataUpdated,
                    object: nil,
                    userInfo: ["tripId": trip.id.uuidString, "flightData": results]
                )
            }
        }
    }

    // MARK: - Auto-Time Setup Methods (✅ NEW: Enhanced debug logging)
    private func setupAutoTimeListener() {
        NotificationCenter.default.addObserver(
            forName: .autoTimeTriggered,
            object: nil,
            queue: .main
        ) { notification in
            print("🔔 Auto-time notification received!")
            
            guard let userInfo = notification.userInfo,
                  let timeType = userInfo["timeType"] as? String,
                  let timeValue = userInfo["timeValue"] as? String,
                  let speed = userInfo["speedKts"] as? Double else {
                print("❌ Invalid auto-time notification - missing data")
                print("   UserInfo: \(notification.userInfo ?? [:])")
                return
            }
            
            print("✅ Received auto-time trigger: \(timeType) = \(timeValue) at \(Int(speed)) kts")
            
            guard let activeTrip = self.activeTrip else {
                print("❌ No active trip to update with auto-time")
                return
            }

            print("📋 Active trip found: \(activeTrip.tripNumber)")

            Task { @MainActor in
                guard let tripIndex = self.store.trips.firstIndex(where: { $0.id == activeTrip.id }) else {
                    print("❌ Could not find trip in store")
                    return
                }

                print("📍 Trip index: \(tripIndex)")

                var updatedTrip = self.store.trips[tripIndex]
            
                // ✅ FIXED: Use smart leg detection (same as other handlers)
                func isLegFullyCompleted(_ leg: FlightLeg) -> Bool {
                    return !leg.outTime.isEmpty &&
                           !leg.offTime.isEmpty &&
                           !leg.onTime.isEmpty &&
                           !leg.inTime.isEmpty
                }

                var currentLegIndex: Int? = nil
                for (index, leg) in updatedTrip.legs.enumerated() {
                    switch leg.status {
                    case .completed:
                        continue
                    case .active:
                        if !isLegFullyCompleted(leg) {
                            currentLegIndex = index
                            break
                        }
                        continue
                    case .standby:
                        currentLegIndex = index
                        break
                    case .skipped:
                        continue
                    }
                    if currentLegIndex != nil { break }
                }

                guard let legIndex = currentLegIndex else {
                    print("❌ No current leg found for auto-time. All legs:")
                    for (idx, leg) in updatedTrip.legs.enumerated() {
                        print("   Leg \(idx): \(leg.departure)-\(leg.arrival) OUT:\(leg.outTime) OFF:\(leg.offTime) ON:\(leg.onTime) IN:\(leg.inTime) status:\(leg.status)")
                    }
                    return
                }

                print("🎯 Target leg index: \(legIndex)")
                let currentLeg = updatedTrip.legs[legIndex]
                print("   Current state: OUT:\(currentLeg.outTime) OFF:\(currentLeg.offTime) ON:\(currentLeg.onTime) IN:\(currentLeg.inTime)")

                // ✅ FIXED: Find actual location in logpages
                var flatIndex = 0
                var foundPage = -1
                var foundLegInPage = -1

                for (pageIndex, logpage) in updatedTrip.logpages.enumerated() {
                    for legInPageIndex in logpage.legs.indices {
                        if flatIndex == legIndex {
                            foundPage = pageIndex
                            foundLegInPage = legInPageIndex
                            break
                        }
                        flatIndex += 1
                    }
                    if foundPage >= 0 { break }
                }

                guard foundPage >= 0, foundLegInPage >= 0 else {
                    print("❌ Could not locate leg \(legIndex) in logpages")
                    return
                }

                switch timeType {
                case "OFF":
                    if updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime.isEmpty {
                        updatedTrip.logpages[foundPage].legs[foundLegInPage].offTime = timeValue
                        print("✈️ Auto-logged OFF time: \(timeValue)")
                        self.showAutoTimeNotification(type: "OFF", time: timeValue, speed: speed)
                    } else {
                        print("⚠️ OFF time already set - not overwriting")
                    }
                case "ON":
                    if updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime.isEmpty {
                        updatedTrip.logpages[foundPage].legs[foundLegInPage].onTime = timeValue

                        // Auto-fill arrival airport if empty
                        if updatedTrip.logpages[foundPage].legs[foundLegInPage].arrival.isEmpty,
                           let currentAirport = self.locationManager.currentAirport {
                            updatedTrip.logpages[foundPage].legs[foundLegInPage].arrival = currentAirport
                            print("✈️ Auto-filled arrival airport: \(currentAirport)")
                        }

                        print("✈️ Auto-logged ON time: \(timeValue)")
                        self.showAutoTimeNotification(type: "ON", time: timeValue, speed: speed)
                    } else {
                        print("⚠️ ON time already set - not overwriting")
                    }
                default:
                    print("❌ Unknown time type: \(timeType)")
                    break
                }

                // ✅ FIXED: Check if leg should be completed and advanced
                updatedTrip.checkAndAdvanceLeg(at: legIndex)

                self.store.updateTrip(updatedTrip, at: tripIndex)
                print("💾 Trip updated in store")

                // Sync to watch
                PhoneWatchConnectivity.shared.syncCurrentLegToWatch()

                self.activityManager.syncWithTrip(updatedTrip)
            }
        }
    }
    
    // ✅ NEW: Clear times listener
    private func setupClearTimesListener() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("clearActiveFlightTimes"),
            object: nil,
            queue: .main
        ) { _ in
            guard let activeTrip = self.activeTrip else {
                print("❌ No active trip to clear times")
                return
            }

            Task { @MainActor in
                guard let tripIndex = self.store.trips.firstIndex(where: { $0.id == activeTrip.id }) else {
                    print("❌ Could not find trip in store")
                    return
                }

                var updatedTrip = self.store.trips[tripIndex]

                // ✅ FIXED: Clear through logpages directly
                for pageIndex in updatedTrip.logpages.indices {
                    for legIndex in updatedTrip.logpages[pageIndex].legs.indices {
                        updatedTrip.logpages[pageIndex].legs[legIndex].outTime = ""
                        updatedTrip.logpages[pageIndex].legs[legIndex].offTime = ""
                        updatedTrip.logpages[pageIndex].legs[legIndex].onTime = ""
                        updatedTrip.logpages[pageIndex].legs[legIndex].inTime = ""
                        updatedTrip.logpages[pageIndex].legs[legIndex].status = .active  // Reset to active
                    }
                }

                // Reset first leg to active, rest to standby
                if !updatedTrip.logpages.isEmpty && !updatedTrip.logpages[0].legs.isEmpty {
                    updatedTrip.logpages[0].legs[0].status = .active
                    var isFirst = true
                    for pageIndex in updatedTrip.logpages.indices {
                        for legIndex in updatedTrip.logpages[pageIndex].legs.indices {
                            if isFirst {
                                isFirst = false
                                continue
                            }
                            updatedTrip.logpages[pageIndex].legs[legIndex].status = .standby
                        }
                    }
                }

                self.store.updateTrip(updatedTrip, at: tripIndex)
                PhoneWatchConnectivity.shared.syncCurrentLegToWatch()
                print("🗑️ Cleared all flight times for trip \(updatedTrip.tripNumber)")
            }
        }
    }
    
    private func showAutoTimeNotification(type: String, time: String, speed: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Auto Time Logged"
        content.body = "\(type) time automatically logged: \(time) (\(Int(speed)) kts)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "autoTime.\(type).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }
    
    private func setupNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let nocSettings = NOCSettingsStore()
        let scheduleStore = ScheduleStore(settings: nocSettings)
        
        Group {
            ContentView()
                .environmentObject(LogBookStore())
                .environmentObject(PilotActivityManager.shared)
                .environmentObject(nocSettings)
                .environmentObject(scheduleStore)
                .previewDevice("iPhone 15 Pro")
                .previewDisplayName("iPhone")
            
            ContentView()
                .environmentObject(LogBookStore())
                .environmentObject(PilotActivityManager.shared)
                .environmentObject(nocSettings)
                .environmentObject(scheduleStore)
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad")
        }
    }
}

// MARK: - Zulu Clock View
struct ZuluClockView: View {
    @State private var currentTime = Date()
    @State private var timeZoneMode: TimeZoneMode = .zulu
    @EnvironmentObject private var airlineSettings: AirlineSettingsStore
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum TimeZoneMode {
        case zulu
        case local
        case homeBase
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(timeString)
                .font(.system(size: 30, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundColor(.white)
            
            Text(timeZoneLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(timeZoneColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap cycles through: Zulu -> Local -> Zulu
            withAnimation(.easeInOut(duration: 0.2)) {
                switch timeZoneMode {
                case .zulu:
                    timeZoneMode = .local
                case .local:
                    timeZoneMode = .zulu
                case .homeBase:
                    timeZoneMode = .zulu
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press goes to home base
            withAnimation(.easeInOut(duration: 0.2)) {
                timeZoneMode = .homeBase
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        
        switch timeZoneMode {
        case .zulu:
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: currentTime)
        case .local:
            formatter.timeZone = TimeZone.current
            return formatter.string(from: currentTime)
        case .homeBase:
            let homeBase = airlineSettings.settings.homeBaseAirport
            if !homeBase.isEmpty {
                formatter.timeZone = AirportDatabase.timeZone(for: homeBase)
                return formatter.string(from: currentTime)
            } else {
                // Fallback to local if no home base set
                formatter.timeZone = TimeZone.current
                return formatter.string(from: currentTime)
            }
        }
    }
    
    private var timeZoneLabel: String {
        switch timeZoneMode {
        case .zulu:
            return "Z"  // Standard aviation abbreviation
        case .local:
            // iOS provides worldwide timezone abbreviations automatically
            return TimeZone.current.abbreviation() ?? "LCL"
        case .homeBase:
            let homeBase = airlineSettings.settings.homeBaseAirport
            if !homeBase.isEmpty {
                let tz = AirportDatabase.timeZone(for: homeBase)
                return tz.abbreviation() ?? homeBase
            } else {
                return "---"
            }
        }
    }
    
    private var timeZoneColor: Color {
        switch timeZoneMode {
        case .zulu:
            return LogbookTheme.accentBlue
        case .local:
            return LogbookTheme.accentGreen
        case .homeBase:
            return LogbookTheme.accentOrange
        }
    }
}

// MARK: - Weather Condition Icon
struct WeatherConditionIcon: View {
    let activeTrip: Trip?
    let isExpanded: Bool
    let onTap: () -> Void

    @EnvironmentObject private var locationManager: PilotLocationManager
    @State private var currentWeather: RawMETAR?
    @State private var currentAirportCode: String?
    @State private var refreshTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Weather icon from WeatherIconHelper
                Image(systemName: WeatherIconHelper.icon(for: currentWeather, filled: true))
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(WeatherIconHelper.color(for: currentWeather))

                // Severe weather indicator
                if WeatherIconHelper.isSevereWeather(currentWeather) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -10)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(isExpanded ? WeatherIconHelper.color(for: currentWeather).opacity(0.2) : Color.clear)
            )
        }
        .onAppear {
            loadWeather()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when app becomes active (user glances at phone)
            if newPhase == .active {
                loadWeather()
            }
        }
        .onChange(of: locationManager.currentAirport) { _, _ in
            loadWeather()
        }
        .onChange(of: locationManager.nearbyAirports.first?.icao) { _, _ in
            loadWeather()
        }
        .onChange(of: activeTrip?.legs.first?.departure) { _, _ in
            loadWeather()
        }
    }

    // MARK: - Helpers

    private func startRefreshTimer() {
        // Refresh weather every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            loadWeather()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadWeather() {
        // Priority: Active trip departure -> Current airport -> Nearest airport
        let icao: String

        if let departure = activeTrip?.legs.first?.departure, !departure.isEmpty {
            icao = departure
        } else if let current = locationManager.currentAirport {
            icao = current
        } else if let nearest = locationManager.nearbyAirports.first {
            icao = nearest.icao
        } else {
            return
        }

        // Track which airport we're showing
        currentAirportCode = icao

        Task {
            do {
                let weather = try await BannerWeatherService.shared.fetchMETAR(for: icao)
                await MainActor.run {
                    currentWeather = weather
                }
            } catch {
                print("❌ Failed to fetch weather for \(icao): \(error)")
            }
        }
    }
}


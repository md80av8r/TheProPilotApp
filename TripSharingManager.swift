// TripSharingManager.swift
// Share trips with other ProPilot users via AirDrop, Messages, Mail, etc.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom File Type for ProPilot Trips
extension UTType {
    /// Custom file type for ProPilot trip files (.protrip)
    static var proTrip: UTType {
        UTType(exportedAs: "com.jkadans.ProPilotApp.protrip")
    }
}

// MARK: - Trip Sharing Manager
class TripSharingManager: ObservableObject {
    static let shared = TripSharingManager()
    
    @Published var importedTrip: Trip?
    @Published var showImportConfirmation = false
    @Published var importError: String?
    @Published var showImportError = false
    
    private init() {}
    
    // MARK: - Export Trip to Shareable File
    
    /// Creates a temporary file URL containing the trip data for sharing
    func createShareableFile(for trip: Trip) -> URL? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            // Wrap trip in a shareable container with metadata
            let shareData = SharedTripData(
                trip: trip,
                sharedDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
            
            let data = try encoder.encode(shareData)
            
            // Create a clean filename from the trip number and date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: trip.date)
            
            let cleanTripNumber = trip.tripNumber
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "#", with: "")
            
            let fileName = "Trip_\(cleanTripNumber)_\(dateString).protrip"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            // Remove existing file if present
            try? FileManager.default.removeItem(at: tempURL)
            
            try data.write(to: tempURL)
            print("✅ Created shareable trip file: \(tempURL.lastPathComponent)")
            return tempURL
            
        } catch {
            print("❌ Failed to create shareable file: \(error)")
            return nil
        }
    }
    
    // MARK: - Import Trip from File
    
    /// Imports a trip from a .protrip file URL
    func importTrip(from url: URL) -> Trip? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            // Start accessing the security-scoped resource if needed
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: url)
            
            // Try to decode as SharedTripData first (new format)
            if let shareData = try? decoder.decode(SharedTripData.self, from: data) {
                print("✅ Successfully imported trip: \(shareData.trip.tripNumber) (shared on \(shareData.sharedDate))")
                return shareData.trip
            }
            
            // Fall back to raw Trip decode (backwards compatibility)
            let trip = try decoder.decode(Trip.self, from: data)
            print("✅ Successfully imported trip (legacy format): \(trip.tripNumber)")
            return trip
            
        } catch {
            print("❌ Failed to import trip: \(error)")
            importError = "Could not read trip file: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Handles incoming file URL (called from onOpenURL in App)
    func handleIncomingFile(_ url: URL) {
        print("📥 Handling incoming file: \(url.lastPathComponent)")
        
        guard url.pathExtension.lowercased() == "protrip" else {
            importError = "Invalid file type. Expected .protrip file."
            showImportError = true
            return
        }
        
        if let trip = importTrip(from: url) {
            importedTrip = trip
            showImportConfirmation = true
        } else {
            showImportError = true
        }
    }
    
    /// Confirms import and adds trip to store
    func confirmImport(to store: LogBookStore) {
        guard let trip = importedTrip else { return }
        
        // Create a new trip with fresh ID to avoid conflicts
        var newTrip = trip
        newTrip.id = UUID()
        
        // Reset status to planning for the importing pilot
        newTrip.status = .planning
        
        // Clear receipt count (those were the other pilot's receipts)
        newTrip.receiptCount = 0
        newTrip.logbookPageSent = false
        
        // Regenerate IDs for all legs and logpages to avoid conflicts
        for logpageIndex in newTrip.logpages.indices {
            newTrip.logpages[logpageIndex].id = UUID()
            for legIndex in newTrip.logpages[logpageIndex].legs.indices {
                newTrip.logpages[logpageIndex].legs[legIndex].id = UUID()
            }
        }
        
        store.addTrip(newTrip)
        print("✅ Added imported trip #\(newTrip.tripNumber) to logbook")
        
        // Clear import state
        importedTrip = nil
        showImportConfirmation = false
        
        // Post notification so UI can navigate to the trip
        NotificationCenter.default.post(
            name: .tripImported,
            object: nil,
            userInfo: ["tripId": newTrip.id]
        )
    }
    
    /// Cancels the import
    func cancelImport() {
        importedTrip = nil
        showImportConfirmation = false
    }
}

// MARK: - Shared Trip Data Container
struct SharedTripData: Codable {
    let trip: Trip
    let sharedDate: Date
    let appVersion: String
}

// MARK: - Import Confirmation View
struct TripImportConfirmationView: View {
    let trip: Trip
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "airplane.arrival")
                            .font(.system(size: 50))
                            .foregroundColor(LogbookTheme.accentBlue)
                        
                        Text("Import Trip?")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("A crewmember shared this trip with you")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Trip Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Trip Number & Aircraft
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trip #\(trip.tripNumber)")
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Text(trip.aircraft)
                                    .font(.subheadline)
                                    .foregroundColor(LogbookTheme.accentBlue)
                            }
                            
                            Spacer()
                            
                            // Trip Type Badge
                            Text(trip.tripType.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(trip.tripType == .deadhead ? LogbookTheme.warningYellow : LogbookTheme.accentGreen)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                            Text(formatDate(trip.date))
                                .foregroundColor(.white)
                        }
                        .font(.subheadline)
                        
                        // Route
                        if !trip.legs.isEmpty {
                            HStack {
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundColor(.gray)
                                Text(trip.routeString)
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                        
                        // Legs Count
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.gray)
                            Text("\(trip.legs.count) leg\(trip.legs.count == 1 ? "" : "s")")
                                .foregroundColor(.white)
                        }
                        .font(.subheadline)
                        
                        // Total Time
                        if trip.totalBlockMinutes > 0 {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.gray)
                                Text("Block: \(formatTime(trip.totalBlockMinutes))")
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                        
                        // Crew
                        if !trip.crew.isEmpty {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Crew")
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)
                                
                                ForEach(trip.crew, id: \.id) { member in
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(LogbookTheme.accentBlue)
                                            .font(.caption)
                                        Text("\(member.role): \(member.name)")
                                            .foregroundColor(.white)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Note about import
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("This will add the trip to your logbook. You can edit it after importing.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onConfirm()
                    }
                    .foregroundColor(LogbookTheme.accentGreen)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - Import Handler View Modifier
struct TripImportHandlerModifier: ViewModifier {
    @ObservedObject var sharingManager = TripSharingManager.shared
    @ObservedObject var logbookStore: LogBookStore
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $sharingManager.showImportConfirmation) {
                if let trip = sharingManager.importedTrip {
                    TripImportConfirmationView(
                        trip: trip,
                        onConfirm: {
                            sharingManager.confirmImport(to: logbookStore)
                        },
                        onCancel: {
                            sharingManager.cancelImport()
                        }
                    )
                }
            }
            .alert("Import Error", isPresented: $sharingManager.showImportError) {
                Button("OK", role: .cancel) {
                    sharingManager.importError = nil
                }
            } message: {
                Text(sharingManager.importError ?? "Could not import trip file")
            }
    }
}

extension View {
    /// Adds trip import handling to any view
    func tripImportHandler(store: LogBookStore) -> some View {
        modifier(TripImportHandlerModifier(logbookStore: store))
    }
}

// MARK: - Notification Names Extension
extension Notification.Name {
    static let tripImported = Notification.Name("tripImported")
}

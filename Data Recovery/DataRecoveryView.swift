//
//  DataRecoveryView.swift
//  ProPilot
//
//  EMERGENCY DATA RECOVERY - Restore lost legs from JSON backup
//

import SwiftUI
import SwiftData

struct DataRecoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var logbookStore: SwiftDataLogBookStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var hasBackup = false
    @State private var backupFileSize: String = "Unknown"
    @State private var isRecovering = false
    @State private var recoveryStatus = ""
    @State private var recoveryComplete = false
    @State private var tripsRecovered = 0
    @State private var legsRecovered = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Warning Header
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("DATA RECOVERY")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Your flight legs are missing from the database. This tool will attempt to restore them from your JSON backup.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        
                        // Backup Status
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Backup Status", systemImage: "doc.fill")
                                .font(.headline)
                                .foregroundColor(LogbookTheme.accentBlue)
                            
                            HStack {
                                Text("Backup Found:")
                                Spacer()
                                Text(hasBackup ? "YES ✅" : "NO ❌")
                                    .foregroundColor(hasBackup ? LogbookTheme.accentGreen : .red)
                            }
                            
                            if hasBackup {
                                HStack {
                                    Text("File Size:")
                                    Spacer()
                                    Text(backupFileSize)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Location: App Group Container")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text("File: logbook_pre_swiftdata_backup.json")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Current State
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Current Database State", systemImage: "cylinder.fill")
                                .font(.headline)
                                .foregroundColor(LogbookTheme.accentOrange)
                            
                            HStack {
                                Text("Trips in Database:")
                                Spacer()
                                Text("\(logbookStore.trips.count)")
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                Text("Total Legs:")
                                Spacer()
                                let totalLegs = logbookStore.trips.reduce(0) { $0 + $1.legs.count }
                                Text("\(totalLegs)")
                                    .foregroundColor(totalLegs == 0 ? .red : LogbookTheme.accentGreen)
                            }
                            
                            HStack {
                                Text("Total Flight Hours:")
                                Spacer()
                                let totalMinutes = logbookStore.trips.reduce(0) { sum, trip in
                                    sum + trip.legs.reduce(0) { $0 + $1.blockMinutes() }
                                }
                                let hours = totalMinutes / 60
                                let mins = totalMinutes % 60
                                Text("\(hours):\(String(format: "%02d", mins))")
                                    .foregroundColor(totalMinutes == 0 ? .red : LogbookTheme.accentGreen)
                            }
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Recovery Status
                        if isRecovering || recoveryComplete {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(recoveryComplete ? "Recovery Complete" : "Recovery In Progress", 
                                      systemImage: recoveryComplete ? "checkmark.circle.fill" : "arrow.clockwise")
                                    .font(.headline)
                                    .foregroundColor(recoveryComplete ? LogbookTheme.accentGreen : LogbookTheme.accentBlue)
                                
                                Text(recoveryStatus)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                if recoveryComplete {
                                    Divider()
                                    
                                    HStack {
                                        Text("Trips Recovered:")
                                        Spacer()
                                        Text("\(tripsRecovered)")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                    
                                    HStack {
                                        Text("Legs Recovered:")
                                        Spacer()
                                        Text("\(legsRecovered)")
                                            .foregroundColor(LogbookTheme.accentGreen)
                                    }
                                }
                                
                                if isRecovering {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .padding()
                            .background(LogbookTheme.navyLight)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Recovery Button
                        if hasBackup && !isRecovering {
                            Button(action: performRecovery) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                    Text(recoveryComplete ? "Recover Again" : "Start Recovery")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(recoveryComplete ? LogbookTheme.accentBlue : LogbookTheme.accentGreen)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Label("How Recovery Works", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(LogbookTheme.accentBlue)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. Loads your JSON backup file")
                                Text("2. Matches trips by ID and trip number")
                                Text("3. Restores missing legs and logpages")
                                Text("4. Preserves existing trip data (dates, notes, etc.)")
                                Text("5. Saves everything to SwiftData")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Data Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(recoveryComplete ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        .onAppear {
            checkForBackup()
        }
    }
    
    private func checkForBackup() {
        hasBackup = MigrationManager.shared.hasBackup
        
        if hasBackup, let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.propilot.app"
        ) {
            let backupURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: backupURL.path),
               let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                backupFileSize = formatter.string(fromByteCount: fileSize)
            }
        }
    }
    
    private func performRecovery() {
        isRecovering = true
        recoveryStatus = "Loading backup file..."
        tripsRecovered = 0
        legsRecovered = 0
        
        Task {
            do {
                // Load JSON backup
                guard let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.propilot.app"
                ) else {
                    throw RecoveryError.noAppGroup
                }
                
                let backupURL = containerURL.appendingPathComponent("logbook_pre_swiftdata_backup.json")
                
                await MainActor.run {
                    recoveryStatus = "Reading backup file..."
                }
                
                let data = try Data(contentsOf: backupURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let jsonTrips = try decoder.decode([Trip].self, from: data)
                
                await MainActor.run {
                    recoveryStatus = "Found \(jsonTrips.count) trips in backup. Restoring legs..."
                }
                
                // Match and restore legs
                for jsonTrip in jsonTrips {
                    // Find matching SDTrip in database
                    let predicate = #Predicate<SDTrip> { $0.tripId == jsonTrip.id }
                    let descriptor = FetchDescriptor<SDTrip>(predicate: predicate)
                    
                    if let sdTrip = try modelContext.fetch(descriptor).first {
                        // Delete existing (empty) logpages
                        if let logpages = sdTrip.logpages {
                            for logpage in logpages {
                                modelContext.delete(logpage)
                            }
                        }
                        
                        // Recreate logpages with legs from JSON
                        for logpage in jsonTrip.logpages {
                            let sdLogpage = SDLogpage(from: logpage)
                            sdLogpage.owningTrip = sdTrip
                            modelContext.insert(sdLogpage)

                            for (order, leg) in logpage.legs.enumerated() {
                                let sdLeg = SDFlightLeg(from: leg, order: order)
                                sdLeg.parentLogpage = sdLogpage
                                modelContext.insert(sdLeg)
                                
                                await MainActor.run {
                                    legsRecovered += 1
                                }
                            }
                        }
                        
                        await MainActor.run {
                            tripsRecovered += 1
                            recoveryStatus = "Recovered \(tripsRecovered) trips, \(legsRecovered) legs..."
                        }
                    }
                }
                
                // Save everything
                await MainActor.run {
                    recoveryStatus = "Saving to database..."
                }
                
                try modelContext.save()
                
                // Reload trips in store
                await MainActor.run {
                    recoveryStatus = "Reloading trips..."
                }
                
                await logbookStore.loadTrips()
                
                await MainActor.run {
                    isRecovering = false
                    recoveryComplete = true
                    recoveryStatus = "Recovery complete! ✅"
                }
                
                print("✅ RECOVERY COMPLETE: \(tripsRecovered) trips, \(legsRecovered) legs")
                
            } catch {
                await MainActor.run {
                    isRecovering = false
                    recoveryStatus = "Recovery failed: \(error.localizedDescription)"
                }
                print("❌ RECOVERY FAILED: \(error)")
            }
        }
    }
}

enum RecoveryError: Error {
    case noAppGroup
    case noBackup
    case invalidJSON
}

// MARK: - View Extension for Easy Access
extension View {
    func dataRecoverySheet(isPresented: Binding<Bool>, logbookStore: SwiftDataLogBookStore) -> some View {
        sheet(isPresented: isPresented) {
            DataRecoveryView(logbookStore: logbookStore)
        }
    }
}

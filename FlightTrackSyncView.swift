//
//  FlightTrackSyncView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/1/26.
//

import SwiftUI

struct FlightTrackSyncView: View {
    @ObservedObject var recorder = FlightTrackRecorder.shared
    @ObservedObject var cloudKit = CloudKitManager.shared
    @State private var isSyncing = false
    @State private var syncMessage = ""
    @State private var showingSyncDetails = false
    
    var body: some View {
        List {
            // MARK: - iCloud Status
            Section("iCloud Status") {
                HStack {
                    Circle()
                        .fill(cloudKit.iCloudAvailable ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(cloudKit.iCloudAvailable ? "iCloud Available" : "iCloud Not Available")
                        .font(.headline)
                    
                    Spacer()
                    
                    if cloudKit.iCloudAvailable {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.icloud.fill")
                            .foregroundColor(.red)
                    }
                }
                
                if let lastSync = cloudKit.lastSyncTime {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            
            // MARK: - Track Recording Settings
            Section {
                Toggle("Enable GPS Track Recording", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "trackRecordingEnabled") },
                    set: { UserDefaults.standard.set($0, forKey: "trackRecordingEnabled") }
                ))
                
                Toggle("Sync Tracks to iCloud", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") },
                    set: { UserDefaults.standard.set($0, forKey: "iCloudSyncEnabled") }
                ))
                .disabled(!cloudKit.iCloudAvailable)
            } header: {
                Text("Track Recording")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GPS tracks record your flight path with altitude, speed, and position data.")
                    if cloudKit.iCloudAvailable {
                        Text("✅ Tracks sync privately across your devices via iCloud")
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ iCloud not available - tracks will only be stored locally")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }
            
            // MARK: - Local Tracks
            Section("Stored Tracks") {
                let trackCount = getAllLocalTracks().count
                
                HStack {
                    Image(systemName: "recordingtape")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("\(trackCount) Track\(trackCount == 1 ? "" : "s")")
                            .font(.headline)
                        if trackCount > 0 {
                            Text("Stored on this device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    
                    if trackCount > 0 {
                        Button("View All") {
                            showingSyncDetails = true
                        }
                        .font(.caption)
                    }
                }
            }
            
            // MARK: - Sync Actions
            if cloudKit.iCloudAvailable && UserDefaults.standard.bool(forKey: "trackRecordingEnabled") {
                Section {
                    Button(action: syncAllTracks) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            }
                            Text(isSyncing ? "Syncing..." : "Sync All Tracks to iCloud")
                            Spacer()
                        }
                    }
                    .disabled(isSyncing || getAllLocalTracks().isEmpty)
                    
                    if !syncMessage.isEmpty {
                        Text(syncMessage)
                            .font(.caption)
                            .foregroundColor(syncMessage.contains("✅") ? .green : .orange)
                    }
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    Text("Manually upload all local tracks to iCloud. Tracks are automatically synced when recording stops.")
                        .font(.caption)
                }
            }
            
            // MARK: - Privacy & Storage
            Section("Privacy & Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Private iCloud Sync Only")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Text("• Tracks sync only to your devices via your personal iCloud account")
                    Text("• No public sharing or cloud exposure")
                    Text("• Track data includes GPS coordinates, altitude, and speed")
                    Text("• Useful for post-flight review and device backup")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Flight Track Sync")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSyncDetails) {
            NavigationView {
                trackDetailsList
            }
        }
    }
    
    // MARK: - Track Details List
    private var trackDetailsList: some View {
        List {
            ForEach(getAllLocalTracks(), id: \.legId) { track in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(track.flightNumber): \(track.departure)-\(track.arrival)")
                        .font(.headline)
                    
                    HStack {
                        Text("\(track.trackPoints.count) points")
                        Text("•")
                        Text("\(String(format: "%.1f", track.totalDistanceNM)) NM")
                        Text("•")
                        Text(track.startTime, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        deleteTrack(track)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Stored Tracks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    showingSyncDetails = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAllLocalTracks() -> [RecordedFlightTrack] {
        return recorder.getAllTracks()
    }
    
    private func syncAllTracks() {
        isSyncing = true
        syncMessage = ""
        
        Task {
            let tracks = getAllLocalTracks()
            var successCount = 0
            
            for track in tracks {
                if let trackData = recorder.getTrackData(for: track.legId) {
                    do {
                        try await CloudKitManager.shared.saveFlightTrack(legId: track.legId, trackData: trackData)
                        successCount += 1
                    } catch {
                        print("❌ Failed to sync track \(track.legId): \(error)")
                    }
                }
            }
            
            await MainActor.run {
                isSyncing = false
                if successCount == tracks.count {
                    syncMessage = "✅ All \(tracks.count) tracks synced"
                } else {
                    syncMessage = "⚠️ Synced \(successCount)/\(tracks.count) tracks"
                }
            }
        }
    }
    
    private func deleteTrack(_ track: RecordedFlightTrack) {
        // Delete locally
        recorder.deleteTrack(for: track.legId)
        
        // Delete from iCloud
        Task {
            await recorder.deleteTrackFromiCloud(legId: track.legId)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        FlightTrackSyncView()
    }
}

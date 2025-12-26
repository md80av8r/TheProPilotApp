//
//  GPSSpoofingStatusPill.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/24/25.
//


//
//  GPSSpoofingStatusView.swift
//  ProPilot
//
//  GPS Spoofing status indicator and alert views
//

import SwiftUI
import CoreLocation

// MARK: - Compact Status Pill (for ActiveTripBanner or header)

struct GPSSpoofingStatusPill: View {
    @ObservedObject var monitor = GPSSpoofingMonitor.shared
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: monitor.currentAlertLevel == .alert ? 4 : 0)
                
                Text("GPS")
                    .font(.caption2)
                    .fontWeight(.medium)
                
                if monitor.currentAlertLevel != .normal {
                    Image(systemName: monitor.currentAlertLevel.systemImage)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            GPSSpoofingDetailView()
        }
    }
    
    private var statusColor: Color {
        switch monitor.currentAlertLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Larger Status Card (for dashboard or settings)

struct GPSSpoofingStatusCard: View {
    @ObservedObject var monitor = GPSSpoofingMonitor.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                Text("GPS Integrity")
                    .font(.headline)
                
                Spacer()
                
                GPSSpoofingStatusBadge(level: monitor.currentAlertLevel)
            }
            
            // Status Message
            Text(monitor.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Current Zone Warning
            if let zone = monitor.currentZone {
                ZoneWarningBanner(zone: zone)
            }
            
            // Quick Stats
            HStack(spacing: 20) {
                StatItem(
                    icon: "location.fill",
                    label: "Position",
                    value: positionStatus
                )
                
                StatItem(
                    icon: "clock.fill",
                    label: "Events",
                    value: "\(monitor.recentEvents.count)"
                )
                
                if monitor.isMonitoring {
                    StatItem(
                        icon: "shield.checkered",
                        label: "Monitor",
                        value: "Active"
                    )
                }
            }
            
            // View Details Button
            Button(action: { showingDetails = true }) {
                HStack {
                    Text("View Details")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.2), lineWidth: 2)
        )
        .sheet(isPresented: $showingDetails) {
            GPSSpoofingDetailView()
        }
    }
    
    private var statusColor: Color {
        switch monitor.currentAlertLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
    
    private var positionStatus: String {
        if let lastValid = monitor.lastValidPosition {
            let accuracy = Int(lastValid.horizontalAccuracy)
            return "±\(accuracy)m"
        }
        return "—"
    }
}

// MARK: - Status Badge

struct GPSSpoofingStatusBadge: View {
    let level: GPSSpoofingAlertLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
    }
    
    private var color: Color {
        switch level {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Zone Warning Banner

struct ZoneWarningBanner: View {
    let zone: GPSSpoofingZone
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(warningColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(zone.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(warningColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(warningColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var warningColor: Color {
        switch zone.riskLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Full Detail View

struct GPSSpoofingDetailView: View {
    @ObservedObject var monitor = GPSSpoofingMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Header
                statusHeader
                    .padding()
                    .background(Color(.secondarySystemBackground))
                
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Events").tag(0)
                    Text("Zones").tag(1)
                    Text("Settings").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    eventsListView.tag(0)
                    zonesListView.tag(1)
                    settingsView.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("GPS Spoofing Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingExportSheet = true }) {
                            Label("Export Report", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { monitor.clearEvents() }) {
                            Label("Clear Events", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Link(destination: URL(string: "https://gpsjam.org")!) {
                            Label("GPSJAM.org", systemImage: "globe")
                        }
                        
                        Link(destination: URL(string: "https://apps.apple.com/us/app/naviguard/id6475402907")!) {
                            Label("NaviGuard App", systemImage: "arrow.down.app")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(items: [monitor.exportEventsForReporting()])
            }
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack(spacing: 20) {
            // Status Circle
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: monitor.currentAlertLevel.systemImage)
                    .font(.title)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.currentAlertLevel.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(monitor.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let zone = monitor.currentZone {
                    Text("In: \(zone.name)")
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            // Monitoring Toggle
            VStack {
                Toggle("", isOn: $monitor.isMonitoring)
                    .labelsHidden()
                
                Text(monitor.isMonitoring ? "Active" : "Off")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Events List
    
    private var eventsListView: some View {
        Group {
            if monitor.recentEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("No Anomalies Detected")
                        .font(.headline)
                    
                    Text("GPS integrity monitoring is active.\nAnomalies will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(monitor.recentEvents) { event in
                        EventRow(event: event)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }
    
    // MARK: - Zones List
    
    private var zonesListView: some View {
        List {
            Section(header: Text("US-Mexico Border")) {
                ForEach(monitor.knownSpoofingZones.filter { $0.region.contains("Mexico") || $0.region.contains("Border") }) { zone in
                    ZoneRow(zone: zone)
                }
            }
            
            Section(header: Text("US Military Testing Areas")) {
                ForEach(monitor.knownSpoofingZones.filter { ["New Mexico", "California", "Nevada"].contains($0.region) }) { zone in
                    ZoneRow(zone: zone)
                }
            }
            
            Section(header: Text("International Hotspots")) {
                ForEach(monitor.knownSpoofingZones.filter { ["Middle East", "Eastern Europe", "Europe"].contains($0.region) }) { zone in
                    ZoneRow(zone: zone)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Settings
    
    private var settingsView: some View {
        Form {
            Section(header: Text("Detection Thresholds")) {
                HStack {
                    Text("Max Realistic Speed")
                    Spacer()
                    TextField("kts", value: $monitor.maxRealisticSpeedKts, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kts")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Position Jump Threshold")
                    Spacer()
                    TextField("NM", value: $monitor.positionJumpThresholdNM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("NM")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Min GPS Accuracy")
                    Spacer()
                    TextField("m", value: $monitor.minAccuracyThreshold, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Alerts")) {
                Toggle("Alert in Known Zones", isOn: $monitor.alertOnKnownZones)
            }
            
            Section(header: Text("Resources")) {
                Link(destination: URL(string: "https://gpsjam.org")!) {
                    HStack {
                        Image(systemName: "globe")
                        Text("GPSJAM.org - Live Interference Map")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://ops.group/blog/gps-spoofing-pilot-qrh/")!) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("OPSGROUP GPS Spoofing QRH")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://apps.apple.com/us/app/naviguard/id6475402907")!) {
                    HStack {
                        Image(systemName: "arrow.down.app")
                        Text("NaviGuard App (Free)")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("FAA Reporting")) {
                Text("Report GPS anomalies to ATC and file NASA ASRS reports for significant events.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link(destination: URL(string: "https://asrs.arc.nasa.gov")!) {
                    HStack {
                        Image(systemName: "paperplane")
                        Text("NASA ASRS Reporting")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch monitor.currentAlertLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: GPSSpoofingEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: event.alertLevel.systemImage)
                    .foregroundColor(alertColor)
                
                Text(event.anomalyType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(event.details)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                if let flight = event.flightNumber {
                    Label(flight, systemImage: "airplane")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(String(format: "%.3f", event.location.latitude)), \(String(format: "%.3f", event.location.longitude))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var alertColor: Color {
        switch event.alertLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Zone Row

struct ZoneRow: View {
    let zone: GPSSpoofingZone
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(riskColor)
                    .frame(width: 10, height: 10)
                
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(zone.radiusNM)) NM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(zone.notes)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var riskColor: Color {
        switch zone.riskLevel {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .alert: return .red
        }
    }
}

// MARK: - Share Sheet

struct GPSSpoofingShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    GPSSpoofingStatusCard()
        .padding()
}

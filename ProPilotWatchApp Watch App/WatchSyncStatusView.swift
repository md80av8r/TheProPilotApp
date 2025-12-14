//
//  WatchSyncStatusView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/16/25.
//


// WatchSyncStatusView.swift
// Simple, clear sync status indicator for watch screens

import SwiftUI

struct WatchSyncStatusView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Status indicator dot with animation
            ZStack {
                // Pulsing ring for syncing
                if connectivityManager.syncStatus == .syncing {
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                }
                
                // Main dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .onAppear {
                startAnimation()
            }
            .onChange(of: connectivityManager.syncStatus) { _, newStatus in
                if newStatus == .syncing {
                    startAnimation()
                } else {
                    isAnimating = false
                }
            }
            
            // Status text
            Text(connectivityManager.getSyncStatusText())
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Pending count badge
            if connectivityManager.pendingSyncCount > 0 {
                Text("\(connectivityManager.pendingSyncCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func startAnimation() {
        guard connectivityManager.syncStatus == .syncing else { return }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
    
    private var statusColor: Color {
        switch connectivityManager.syncStatus {
        case .disconnected, .error:
            return .red
        case .connected:
            return .yellow
        case .syncing, .pending:
            return .orange
        case .synced:
            return .green
        }
    }
}

// MARK: - Compact version for tab bar

struct WatchSyncStatusDot: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        ZStack {
            // Pulsing ring for syncing state
            if connectivityManager.syncStatus == .syncing {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }
            
            // Main status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Pending count overlay
            if connectivityManager.pendingSyncCount > 0 {
                Text("\(connectivityManager.pendingSyncCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 6, y: -6)
            }
        }
    }
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    
    private var statusColor: Color {
        switch connectivityManager.syncStatus {
        case .disconnected, .error:
            return .red
        case .connected:
            return .yellow
        case .syncing, .pending:
            return .orange
        case .synced:
            return .green
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
            pulseScale = 2.0
            pulseOpacity = 0.0
        }
    }
}

// MARK: - Detailed sync info view

struct WatchSyncDetailView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection status
            HStack {
                Image(systemName: connectionIcon)
                    .foregroundColor(connectionColor)
                Text(connectivityManager.isPhoneReachable ? "Connected to iPhone" : "iPhone Not Reachable")
                    .font(.caption)
                Spacer()
            }
            
            Divider()
            
            // Sync status
            HStack {
                Image(systemName: syncIcon)
                    .foregroundColor(syncColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Status")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(connectivityManager.getSyncStatusText())
                        .font(.caption)
                }
                Spacer()
            }
            
            // Last sync time
            if let lastSync = connectivityManager.lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Sync")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(timeAgoString(from: lastSync))
                            .font(.caption)
                    }
                    Spacer()
                }
            }
            
            // Pending messages
            if connectivityManager.pendingSyncCount > 0 {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("\(connectivityManager.pendingSyncCount) updates pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
            
            // Current leg info
            if connectivityManager.totalLegs > 0 {
                Divider()
                
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.blue)
                    Text("Leg \(connectivityManager.currentLegIndex + 1) of \(connectivityManager.totalLegs)")
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var connectionIcon: String {
        connectivityManager.isPhoneReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash"
    }
    
    private var connectionColor: Color {
        connectivityManager.isPhoneReachable ? .green : .red
    }
    
    private var syncIcon: String {
        switch connectivityManager.syncStatus {
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.arrow.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "circle"
        }
    }
    
    private var syncColor: Color {
        switch connectivityManager.syncStatus {
        case .disconnected, .error:
            return .red
        case .connected:
            return .yellow
        case .syncing, .pending:
            return .orange
        case .synced:
            return .green
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview

struct WatchSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WatchSyncStatusView()
            WatchSyncStatusDot()
            WatchSyncDetailView()
        }
        .padding()
        .environmentObject(WatchConnectivityManager.shared)
    }
}

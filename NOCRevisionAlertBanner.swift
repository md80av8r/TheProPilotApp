//
//  NOCRevisionAlertBanner.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/1/25.
//


import SwiftUI

// MARK: - NOC Revision Alert Banner
/// Drop this into your schedule view or settings to show pending revision status
struct NOCRevisionAlertBanner: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    @State private var isExpanded = false
    
    var body: some View {
        if nocSettings.hasPendingRevision {
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schedule Revision Pending")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            if let detectedAt = nocSettings.pendingRevisionDetectedAt {
                                Text("Detected \(detectedAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .padding()
                    .background(Color.yellow)
                }
                .buttonStyle(PlainButtonStyle())
                
                if isExpanded {
                    VStack(spacing: 12) {
                        Text("Your schedule has changed. Log in to NOC to review and confirm the revision.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                nocSettings.openNOCForConfirmation()
                            }) {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("Open NOC")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    nocSettings.markRevisionConfirmed()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("I Confirmed")
                                }
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.3))
                }
            }
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }
}

// MARK: - NOC Revision Badge
/// Small badge indicator for tab bar or navigation items
struct NOCRevisionBadge: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    
    var body: some View {
        if nocSettings.hasPendingRevision {
            Circle()
                .fill(Color.yellow)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}

// MARK: - NOC Settings Row for Revision Notifications
/// Add this to your NOC settings view
struct NOCRevisionNotificationToggle: View {
    @ObservedObject var nocSettings: NOCSettingsStore
    
    var body: some View {
        Toggle(isOn: $nocSettings.revisionNotificationsEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Revision Notifications")
                    .font(.body)
                Text("Get notified when your schedule changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct NOCRevisionAlertBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NOCRevisionAlertBanner(nocSettings: NOCSettingsStore())
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
//
//  DismissedRosterItemsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/30/25.
//


//
//  DismissedRosterItemsView.swift
//  ProPilotApp
//
//  UI for viewing and managing dismissed roster items
//

import SwiftUI

struct DismissedRosterItemsView: View {
    @StateObject private var dismissedManager = DismissedRosterItemsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: FilterType = .all
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case permanent = "Permanent"
        case temporary = "Temporary"
    }
    
    private var filteredItems: [DismissedRosterItem] {
        switch selectedFilter {
        case .all:
            return dismissedManager.getCurrentlyDismissed()
        case .permanent:
            return dismissedManager.getPermanentlyDismissed()
        case .temporary:
            return dismissedManager.getTemporarilyDismissed()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                filterPicker
                
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    // List of dismissed items
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                DismissedItemRow(
                                    item: item,
                                    onReactivate: {
                                        withAnimation {
                                            dismissedManager.reactivate(item)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Dismissed Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredItems.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                withAnimation {
                                    dismissedManager.clearAll()
                                }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Filter Picker
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(FilterType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(LogbookTheme.cardBackground)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(LogbookTheme.successGreen)
            
            Text("No Dismissed Trips")
                .font(.title2.bold())
                .foregroundColor(LogbookTheme.textPrimary)
            
            Text("Trips you dismiss will appear here. You can re-activate them anytime.")
                .font(.subheadline)
                .foregroundColor(LogbookTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Dismissed Item Row
struct DismissedItemRow: View {
    let item: DismissedRosterItem
    let onReactivate: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.tripNumber)
                        .font(.headline)
                        .foregroundColor(LogbookTheme.textPrimary)
                    
                    Text(item.route)
                        .font(.subheadline)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                Spacer()
                
                // Status Badge
                statusBadge
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "calendar", label: "Trip Date", value: dateFormatter.string(from: item.date))
                infoRow(icon: "clock.badge.xmark", label: "Dismissed", value: dateFormatter.string(from: item.dismissedAt))
                
                if let until = item.dismissedUntil {
                    infoRow(icon: "clock.arrow.circlepath", label: "Until", value: dateFormatter.string(from: until))
                }
                
                infoRow(icon: "tag", label: "Reason", value: item.reason.displayName)
            }
            
            // Re-activate Button
            Button(action: onReactivate) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    Text("Re-activate Trip")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LogbookTheme.accentGreen)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LogbookTheme.warningYellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: item.isPermanent ? "slash.circle.fill" : "clock.fill")
                .font(.caption)
            Text(item.isPermanent ? "Permanent" : "Temporary")
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(item.isPermanent ? Color.red : Color.orange)
        .cornerRadius(6)
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(LogbookTheme.textPrimary)
        }
    }
}

// MARK: - Preview
struct DismissedRosterItemsView_Previews: PreviewProvider {
    static var previews: some View {
        DismissedRosterItemsView()
    }
}
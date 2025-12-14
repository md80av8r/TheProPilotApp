//
//  SwipeableRosterItemRow.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/30/25.
//

import SwiftUI

struct SwipeableRosterItemRow<Content: View>: View {
    let item: BasicScheduleItem
    let content: Content
    let onDismiss: (DismissedRosterItem.DismissReason) -> Void
    var onAddToTrip: ((BasicScheduleItem) -> Void)? = nil  // NEW: Optional callback for add to trip
    
    @State private var offset: CGFloat = 0
    @State private var showingDismissSheet = false
    @GestureState private var dragState = false
    
    private let deleteThreshold: CGFloat = -80
    
    init(item: BasicScheduleItem,
         onDismiss: @escaping (DismissedRosterItem.DismissReason) -> Void,
         onAddToTrip: ((BasicScheduleItem) -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.item = item
        self.content = content()
        self.onDismiss = onDismiss
        self.onAddToTrip = onAddToTrip
    }
    
    var body: some View {
        ZStack {
            // Background dismiss actions
            HStack {
                Spacer()
                
                dismissActionsBackground
            }
            
            // Main content with context menu
            content
                .offset(x: offset)
                .contentShape(Rectangle()) // Ensure full area is tappable
                .contextMenu {
                    // Only show "Add to Trip" for flight items
                    if item.status == .activeTrip || item.status == .deadhead {
                        Button {
                            onAddToTrip?(item)
                        } label: {
                            Label("Add to Trip", systemImage: "plus.circle")
                        }
                        
                        Divider()
                    }
                    
                    // Dismiss options
                    Button(role: .destructive) {
                        showingDismissSheet = true
                    } label: {
                        Label("Dismiss", systemImage: "eye.slash")
                    }
                }
                .gesture(
                    DragGesture()
                        .updating($dragState) { value, state, _ in
                            state = true
                        }
                        .onChanged { gesture in
                            // Only allow left swipe (negative offset)
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            let velocity = gesture.predictedEndTranslation.width
                            
                            // Determine action based on swipe distance
                            if offset < deleteThreshold || velocity < -300 {
                                // Show dismiss options
                                withAnimation(.spring()) {
                                    offset = deleteThreshold
                                }
                                showingDismissSheet = true
                            } else {
                                // Reset
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .sheet(isPresented: $showingDismissSheet) {
            DismissRosterItemSheet(
                item: item,
                onDismiss: { reason in
                    onDismiss(reason)
                    withAnimation(.spring()) {
                        offset = 0
                    }
                },
                onCancel: {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                }
            )
        }
    }
    
    private var dismissActionsBackground: some View {
        HStack(spacing: 0) {
            Button {
                showingDismissSheet = true
            } label: {
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                    Text("Dismiss")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .frame(width: 80)
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
        }
    }
}

// MARK: - Dismiss Options Sheet
struct DismissRosterItemSheet: View {
    let item: BasicScheduleItem
    let onDismiss: (DismissedRosterItem.DismissReason) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: DismissedRosterItem.DismissReason = .notFlying
    @State private var dismissType: DismissType = .permanent
    @State private var dismissUntilDate = Date().addingTimeInterval(24 * 3600) // Tomorrow
    
    enum DismissType {
        case permanent
        case temporary
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Trip Info
                Section("Trip Information") {
                    HStack {
                        Text("Flight")
                        Spacer()
                        Text(item.tripNumber)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    HStack {
                        Text("Route")
                        Spacer()
                        Text("\(item.departure) → \(item.arrival)")
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formatDate(item.date))
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
                
                // Dismiss Type
                Section("Dismiss Type") {
                    Picker("Duration", selection: $dismissType) {
                        Text("Permanently").tag(DismissType.permanent)
                        Text("Temporarily").tag(DismissType.temporary)
                    }
                    .pickerStyle(.segmented)
                    
                    if dismissType == .temporary {
                        DatePicker(
                            "Dismiss Until",
                            selection: $dismissUntilDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // Reason
                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach([
                            DismissedRosterItem.DismissReason.cancelled,
                            .notFlying,
                            .duplicate,
                            .temporary,
                            .other
                        ], id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Warning
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(LogbookTheme.warningYellow)
                            Text("This trip will be hidden from your roster")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textSecondary)
                        }
                        
                        if dismissType == .permanent {
                            Text("You can re-activate it anytime from the Dismissed Trips view")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textTertiary)
                        } else {
                            Text("It will automatically reappear after \(formatDate(dismissUntilDate))")
                                .font(.caption)
                                .foregroundColor(LogbookTheme.textTertiary)
                        }
                    }
                }
                
                // Actions
                Section {
                    Button {
                        handleDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Dismiss Trip")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Dismiss Trip")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleDismiss() {
        if dismissType == .permanent {
            DismissedRosterItemsManager.shared.dismiss(item, reason: selectedReason)
        } else {
            DismissedRosterItemsManager.shared.dismiss(item, until: dismissUntilDate, reason: .temporary)
        }
        
        onDismiss(selectedReason)
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct SwipeableRosterItemRow_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = BasicScheduleItem(
            date: Date(),
            tripNumber: "UJ123",
            departure: "KYIP",
            arrival: "KORD",
            blockOut: Date(),
            blockOff: Date().addingTimeInterval(1800),
            blockOn: Date().addingTimeInterval(5400),
            blockIn: Date().addingTimeInterval(7200),
            summary: "Test Flight"
        )
        
        SwipeableRosterItemRow(item: sampleItem, onDismiss: { _ in }) {
            Text("Sample Row Content")
                .padding()
                .background(Color.blue)
        }
    }
}

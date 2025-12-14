// UnifiedAircraftView.swift
// Single unified view for all aircraft management
// Replaces: EnhancedAircraftManagementView + AircraftLibraryView
// Created December 2025

import SwiftUI

// MARK: - Main Aircraft Database View
struct UnifiedAircraftView: View {
    @StateObject private var database = UnifiedAircraftDatabase.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var selectedAircraft: Aircraft?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var aircraftToDelete: Aircraft?
    @State private var filterCategory: ForeFlightCategoryClass?
    
    var filteredAircraft: [Aircraft] {
        var result = database.aircraft
        
        if let category = filterCategory {
            result = result.filter { $0.categoryClass == category }
        }
        
        if !searchText.isEmpty {
            result = database.searchAircraft(matching: searchText)
        }
        
        return result.sorted { $0.tailNumber < $1.tailNumber }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sync status banner
                if database.isSyncing {
                    syncingBanner
                } else if let error = database.syncError {
                    errorBanner(error)
                }
                
                // Search bar
                searchBar
                
                // Filter pills
                filterPills
                
                // Aircraft list
                if filteredAircraft.isEmpty {
                    emptyState
                } else {
                    aircraftList
                }
            }
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Aircraft Database")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Sync button
                        Button {
                            Task { await database.syncFromCloudKit() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(database.isSyncing ? .gray : LogbookTheme.accentBlue)
                        }
                        .disabled(database.isSyncing)
                        
                        // Add button
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            UnifiedAircraftEditView(database: database, aircraft: nil, isNew: true)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let aircraft = selectedAircraft {
                UnifiedAircraftEditView(database: database, aircraft: aircraft, isNew: false)
            }
        }
        .confirmationDialog("Delete Aircraft", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let aircraft = aircraftToDelete {
                    database.deleteAircraft(aircraft)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let aircraft = aircraftToDelete {
                Text("Delete \(aircraft.tailNumber)? This will also remove it from iCloud.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var syncingBanner: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing with iCloud...")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(LogbookTheme.accentBlue.opacity(0.3))
    }
    
    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Sync error: \(error)")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Button("Retry") {
                Task { await database.syncFromCloudKit() }
            }
            .font(.caption.bold())
            .foregroundColor(LogbookTheme.accentBlue)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.2))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search aircraft...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(LogbookTheme.navyLight)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AircraftFilterPill(title: "All", isSelected: filterCategory == nil) {
                    filterCategory = nil
                }
                
                AircraftFilterPill(title: "ASEL", isSelected: filterCategory == .airplaneSingleEngineLand) {
                    filterCategory = .airplaneSingleEngineLand
                }
                
                AircraftFilterPill(title: "AMEL", isSelected: filterCategory == .airplaneMultiEngineLand) {
                    filterCategory = .airplaneMultiEngineLand
                }
                
                AircraftFilterPill(title: "Heli", isSelected: filterCategory == .rotorcraftHelicopter) {
                    filterCategory = .rotorcraftHelicopter
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Aircraft" : "No Results")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? "Add your first aircraft to get started" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if searchText.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Aircraft", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(LogbookTheme.accentGreen)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
    }
    
    private var aircraftList: some View {
        List {
            // Stats section
            Section {
                HStack {
                    AircraftStatBox(title: "Total", value: "\(database.aircraft.count)", color: LogbookTheme.accentBlue)
                    AircraftStatBox(title: "Multi", value: "\(database.aircraft.filter { $0.categoryClass.isMultiEngine }.count)", color: LogbookTheme.accentGreen)
                    AircraftStatBox(title: "Turbine", value: "\(database.aircraft.filter { $0.isTurbine }.count)", color: LogbookTheme.accentOrange)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            // Last sync info
            if let lastSync = database.lastSyncTime {
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                        Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(LogbookTheme.navyLight)
                }
            }
            
            // Aircraft list
            Section(header: Text("Your Aircraft (\(filteredAircraft.count))")) {
                ForEach(filteredAircraft) { aircraft in
                    UnifiedAircraftRow(aircraft: aircraft)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAircraft = aircraft
                            showingEditSheet = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                aircraftToDelete = aircraft
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Aircraft Filter Pill
struct AircraftFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? LogbookTheme.accentBlue : LogbookTheme.navyLight)
                .cornerRadius(20)
        }
    }
}

// MARK: - Aircraft Stat Box
struct AircraftStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LogbookTheme.navyLight)
        .cornerRadius(12)
    }
}

// MARK: - Aircraft Row
struct UnifiedAircraftRow: View {
    let aircraft: Aircraft
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(aircraft.tailNumber)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(aircraft.manufacturer) \(aircraft.model)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Tags
                HStack(spacing: 6) {
                    AircraftTag(text: aircraft.categoryClass.shortName, color: .blue)
                    
                    if aircraft.isComplex {
                        AircraftTag(text: "Complex", color: .orange)
                    }
                    if aircraft.isHighPerformance {
                        AircraftTag(text: "HP", color: .red)
                    }
                    if aircraft.isPressurized {
                        AircraftTag(text: "Press", color: .purple)
                    }
                    if aircraft.requiresTypeRating {
                        AircraftTag(text: aircraft.typeRatingDesignation ?? "Type", color: .cyan)
                    }
                }
            }
            
            Spacer()
            
            // Type code & sync status
            VStack(alignment: .trailing, spacing: 4) {
                Text(aircraft.typeCode)
                    .font(.caption.bold())
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text(aircraft.engineType.displayName)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if aircraft.lastSyncedAt != nil {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch aircraft.categoryClass {
        case .airplaneSingleEngineLand, .airplaneSingleEngineSea:
            return "airplane"
        case .airplaneMultiEngineLand, .airplaneMultiEngineSea:
            return "airplane.circle.fill"
        case .rotorcraftHelicopter, .rotorcraftGyroplane:
            return "helm"
        case .glider:
            return "wind"
        default:
            return "airplane"
        }
    }
    
    private var iconColor: Color {
        switch aircraft.engineType {
        case .turbofan, .turbojet:
            return .blue
        case .turboprop, .turboshaft:
            return .orange
        case .piston, .radial:
            return .green
        case .electric:
            return .cyan
        default:
            return .gray
        }
    }
}

// MARK: - Aircraft Tag
struct AircraftTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Edit/Add View
struct UnifiedAircraftEditView: View {
    @ObservedObject var database: UnifiedAircraftDatabase
    @Environment(\.dismiss) private var dismiss
    
    let aircraft: Aircraft?
    let isNew: Bool
    
    @State private var tailNumber = ""
    @State private var typeCode = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var yearString = ""
    @State private var categoryClass: ForeFlightCategoryClass = .airplaneMultiEngineLand
    @State private var gearType: ForeFlightGearType = .retractableTricycle
    @State private var engineType: ForeFlightEngineType = .turbofan
    @State private var engineCount = 2
    @State private var isComplex = true
    @State private var isHighPerformance = true
    @State private var isTAA = false
    @State private var isPressurized = true
    @State private var requiresTypeRating = false
    @State private var typeRatingDesignation = ""
    @State private var notes = ""
    
    @State private var showingTemplates = false
    @State private var showingCopySheet = false
    
    var body: some View {
        NavigationView {
            Form {
                // Quick start (only for new)
                if isNew {
                    Section(header: Text("Quick Start")) {
                        Button {
                            showingTemplates = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Start from Template")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if !database.aircraft.isEmpty {
                            Button {
                                showingCopySheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.green)
                                    Text("Copy from Existing")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                // Identification
                Section(header: Text("Identification")) {
                    HStack {
                        Text("Tail Number")
                        Spacer()
                        TextField("N12345", text: $tailNumber)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }
                    
                    HStack {
                        Text("Type Code")
                        Spacer()
                        TextField("C172", text: $typeCode)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }
                }
                
                // Details
                Section(header: Text("Aircraft Details")) {
                    HStack {
                        Text("Manufacturer")
                        Spacer()
                        TextField("Cessna", text: $manufacturer)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Model")
                        Spacer()
                        TextField("172 Skyhawk", text: $model)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Year")
                        Spacer()
                        TextField("1998", text: $yearString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Configuration
                Section(header: Text("Configuration")) {
                    Picker("Category/Class", selection: $categoryClass) {
                        ForEach(ForeFlightCategoryClass.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    
                    Picker("Gear Type", selection: $gearType) {
                        ForEach(ForeFlightGearType.allCases, id: \.self) { gear in
                            Text(gear.displayName).tag(gear)
                        }
                    }
                    
                    Picker("Engine Type", selection: $engineType) {
                        ForEach(ForeFlightEngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    
                    Stepper("Engines: \(engineCount)", value: $engineCount, in: 1...4)
                }
                
                // FAA Flags
                Section(header: Text("FAA Classifications")) {
                    Toggle("Complex Aircraft", isOn: $isComplex)
                    Toggle("High Performance (>200 HP)", isOn: $isHighPerformance)
                    Toggle("Technically Advanced (TAA)", isOn: $isTAA)
                    Toggle("Pressurized", isOn: $isPressurized)
                    Toggle("Requires Type Rating", isOn: $requiresTypeRating)
                    
                    if requiresTypeRating {
                        HStack {
                            Text("Type Rating")
                            Spacer()
                            TextField("B-737", text: $typeRatingDesignation)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // Notes
                Section(header: Text("Notes")) {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isNew ? "Add Aircraft" : "Edit Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAircraft() }
                        .disabled(tailNumber.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let aircraft = aircraft {
                loadAircraft(aircraft)
            }
        }
        .sheet(isPresented: $showingTemplates) {
            TemplatePickerView { template in
                applyTemplate(template)
            }
        }
        .sheet(isPresented: $showingCopySheet) {
            CopyFromAircraftView(database: database) { source in
                applyFromAircraft(source)
            }
        }
    }
    
    private func loadAircraft(_ ac: Aircraft) {
        tailNumber = ac.tailNumber
        typeCode = ac.typeCode
        manufacturer = ac.manufacturer
        model = ac.model
        yearString = ac.year != nil ? String(ac.year!) : ""
        categoryClass = ac.categoryClass
        gearType = ac.gearType
        engineType = ac.engineType
        engineCount = ac.engineCount
        isComplex = ac.isComplex
        isHighPerformance = ac.isHighPerformance
        isTAA = ac.isTAA
        isPressurized = ac.isPressurized
        requiresTypeRating = ac.requiresTypeRating
        typeRatingDesignation = ac.typeRatingDesignation ?? ""
        notes = ac.notes
    }
    
    private func applyTemplate(_ template: AircraftTemplate) {
        typeCode = template.typeCode
        manufacturer = template.manufacturer
        model = template.model
        categoryClass = template.categoryClass
        gearType = template.gearType
        engineType = template.engineType
        engineCount = template.engineCount
        isComplex = template.isComplex
        isHighPerformance = template.isHighPerformance
        isPressurized = template.isPressurized
        requiresTypeRating = template.requiresTypeRating
        typeRatingDesignation = template.typeRatingDesignation ?? ""
    }
    
    private func applyFromAircraft(_ source: Aircraft) {
        typeCode = source.typeCode
        manufacturer = source.manufacturer
        model = source.model
        categoryClass = source.categoryClass
        gearType = source.gearType
        engineType = source.engineType
        engineCount = source.engineCount
        isComplex = source.isComplex
        isHighPerformance = source.isHighPerformance
        isTAA = source.isTAA
        isPressurized = source.isPressurized
        requiresTypeRating = source.requiresTypeRating
        typeRatingDesignation = source.typeRatingDesignation ?? ""
    }
    
    private func saveAircraft() {
        var ac = Aircraft(
            id: aircraft?.id ?? UUID(),
            tailNumber: tailNumber,
            typeCode: typeCode,
            manufacturer: manufacturer,
            model: model,
            year: Int(yearString),
            categoryClass: categoryClass,
            gearType: gearType,
            engineType: engineType,
            engineCount: engineCount,
            isComplex: isComplex,
            isHighPerformance: isHighPerformance,
            isTAA: isTAA,
            isPressurized: isPressurized,
            requiresTypeRating: requiresTypeRating,
            typeRatingDesignation: requiresTypeRating ? typeRatingDesignation : nil,
            notes: notes
        )
        
        // Preserve existing data if editing
        if let existing = aircraft {
            ac.lastTATValue = existing.lastTATValue
            ac.dateAdded = existing.dateAdded
            ac.isUserAdded = existing.isUserAdded
        }
        
        if isNew {
            database.addAircraft(ac)
        } else {
            database.updateAircraft(ac)
        }
        
        dismiss()
    }
}

// MARK: - Template Picker
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AircraftTemplate) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AircraftTemplate.templates, id: \.typeCode) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(template.categoryClass.shortName) • \(template.engineType.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(template.typeCode)
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Copy From Aircraft
struct CopyFromAircraftView: View {
    @ObservedObject var database: UnifiedAircraftDatabase
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Aircraft) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(database.aircraft.sorted { $0.tailNumber < $1.tailNumber }) { aircraft in
                    Button {
                        onSelect(aircraft)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(aircraft.tailNumber)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(aircraft.manufacturer) \(aircraft.model)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(aircraft.typeCode)
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Copy From")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    UnifiedAircraftView()
}

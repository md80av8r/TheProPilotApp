// EnhancedAircraftManagementView.swift
// Full-featured Aircraft Database Management UI
// Created for ProPilot App

import SwiftUI

// MARK: - Main Aircraft Management View
struct EnhancedAircraftManagementView: View {
    @StateObject private var database = AircraftDatabaseManager.shared
    @State private var searchText = ""
    @State private var showingAddAircraft = false
    @State private var selectedAircraft: AircraftRecord?
    @State private var showingEditAircraft = false
    @State private var showingDeleteConfirmation = false
    @State private var aircraftToDelete: AircraftRecord?
    @State private var filterClass: AircraftClass?
    @Environment(\.dismiss) private var dismiss
    
    var filteredAircraft: [AircraftRecord] {
        var result = database.aircraft
        
        if let acClass = filterClass {
            result = result.filter { $0.aircraftClass == acClass }
        }
        
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { ac in
                ac.tailNumber.lowercased().contains(search) ||
                ac.typeDesignator.lowercased().contains(search) ||
                ac.manufacturer.lowercased().contains(search) ||
                ac.model.lowercased().contains(search)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                filterPills
                
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
                    Button {
                        showingAddAircraft = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(LogbookTheme.accentGreen)
                    }
                }
            }
            .sheet(isPresented: $showingAddAircraft) {
                AddEditAircraftView(mode: .add)
            }
            .sheet(isPresented: $showingEditAircraft) {
                if let aircraft = selectedAircraft {
                    AddEditAircraftView(mode: .edit(aircraft))
                }
            }
            .confirmationDialog(
                "Delete Aircraft",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let aircraft = aircraftToDelete {
                        database.deleteAircraft(aircraft)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let aircraft = aircraftToDelete {
                    Text("Delete \(aircraft.tailNumber)? This cannot be undone.")
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search aircraft...", text: $searchText)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(
                    title: "All",
                    isSelected: filterClass == nil,
                    count: database.aircraft.count
                ) {
                    filterClass = nil
                }
                
                ForEach(AircraftClass.allCases, id: \.self) { acClass in
                    let count = database.aircraft.filter { $0.aircraftClass == acClass }.count
                    if count > 0 {
                        FilterPill(
                            title: acClass.abbreviation,
                            isSelected: filterClass == acClass,
                            count: count
                        ) {
                            filterClass = acClass
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var aircraftList: some View {
        List {
            ForEach(filteredAircraft) { aircraft in
                AircraftRowView(aircraft: aircraft)
                    .listRowBackground(LogbookTheme.fieldBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAircraft = aircraft
                        showingEditAircraft = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            aircraftToDelete = aircraft
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            selectedAircraft = aircraft
                            showingEditAircraft = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(LogbookTheme.accentBlue)
                    }
            }
            
            Section {
                HStack {
                    Text("\(filteredAircraft.count) aircraft")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if let lastUsed = database.lastUsedTailNumber {
                        Text("Last used: \(lastUsed)")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
            
            Text(searchText.isEmpty ? "Tap + to add your first aircraft" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button {
                    showingAddAircraft = true
                } label: {
                    Label("Add Aircraft", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(LogbookTheme.accentGreen)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? LogbookTheme.accentBlue : LogbookTheme.fieldBackground)
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
        }
    }
}

// MARK: - Aircraft Row View
struct AircraftRowView: View {
    let aircraft: AircraftRecord
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Image(systemName: "airplane")
                    .font(.title2)
                    .foregroundColor(iconColor)
            }
            .frame(width: 44, height: 44)
            .background(iconColor.opacity(0.2))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(aircraft.tailNumber)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if aircraft.requiresTypeRating {
                        if let typeRating = aircraft.typeRatingDesignation {
                            Text(typeRating)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LogbookTheme.accentOrange.opacity(0.3))
                                .foregroundColor(LogbookTheme.accentOrange)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Text(aircraft.model.isEmpty ? aircraft.typeDesignator : aircraft.model)
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)
                
                Text(aircraft.shortDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if aircraft.isTurbine {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentOrange)
                }
                
                if !aircraft.lastTATValue.isEmpty {
                    Text("TAT: \(aircraft.lastTATValue)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    private var iconColor: Color {
        switch aircraft.engineType {
        case .piston: return .green
        case .turboprop: return .orange
        case .turbojet: return LogbookTheme.accentBlue
        case .turbofan: return LogbookTheme.accentBlue
        case .electric: return .purple
        }
    }
}

// MARK: - Add/Edit Aircraft View
struct AddEditAircraftView: View {
    enum Mode {
        case add
        case edit(AircraftRecord)
        
        var title: String {
            switch self {
            case .add: return "Add Aircraft"
            case .edit: return "Edit Aircraft"
            }
        }
        
        var aircraft: AircraftRecord? {
            switch self {
            case .add: return nil
            case .edit(let ac): return ac
            }
        }
    }
    
    let mode: Mode
    @StateObject private var database = AircraftDatabaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var tailNumber = ""
    @State private var typeDesignator = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var category: AircraftCategory = .airplane
    @State private var aircraftClass: AircraftClass = .multiEngineLand
    @State private var engineType: EngineType = .turbofan
    @State private var engineCount = 2
    @State private var gearType: GearType = .retractable
    @State private var isComplex = true
    @State private var isHighPerformance = true
    @State private var isTurbine = true
    @State private var isPressurized = true
    @State private var isTailwheel = false
    @State private var requiresTypeRating = false
    @State private var typeRatingDesignation = ""
    @State private var notes = ""
    @State private var lastTATValue = ""
    @State private var showingTypeSelector = false
    
    var isValidForm: Bool {
        !tailNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                quickSelectSection
                basicInfoSection
                configurationSection
                characteristicsSection
                typeRatingSection
                additionalSection
            }
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAircraft()
                        dismiss()
                    }
                    .disabled(!isValidForm)
                    .foregroundColor(isValidForm ? LogbookTheme.accentGreen : .gray)
                }
            }
            .onAppear { loadExistingAircraft() }
            .sheet(isPresented: $showingTypeSelector) {
                SimpleAircraftTypeSelector { template in
                    applyTemplate(template)
                }
            }
        }
    }
    
    private var quickSelectSection: some View {
        Section(header: Text("Quick Select")) {
            Button {
                showingTypeSelector = true
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text("Select from Common Types")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section(header: Text("Aircraft Info")) {
            HStack {
                Text("Tail Number").foregroundColor(.gray)
                Spacer()
                TextField("N123AB", text: $tailNumber)
                    .textCase(.uppercase)
                    .autocapitalization(.allCharacters)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }
            
            HStack {
                Text("Type Designator").foregroundColor(.gray)
                Spacer()
                TextField("DC93", text: $typeDesignator)
                    .textCase(.uppercase)
                    .autocapitalization(.allCharacters)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            
            HStack {
                Text("Manufacturer").foregroundColor(.gray)
                Spacer()
                TextField("McDonnell Douglas", text: $manufacturer)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Model").foregroundColor(.gray)
                Spacer()
                TextField("DC-9-30", text: $model)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    private var configurationSection: some View {
        Section(header: Text("Configuration")) {
            Picker("Category", selection: $category) {
                ForEach(AircraftCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            
            Picker("Class", selection: $aircraftClass) {
                ForEach(AircraftClass.allCases, id: \.self) { acClass in
                    Text(acClass.displayName).tag(acClass)
                }
            }
            
            Picker("Engine Type", selection: $engineType) {
                ForEach(EngineType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            
            Stepper("Engines: \(engineCount)", value: $engineCount, in: 1...4)
            
            Picker("Gear Type", selection: $gearType) {
                ForEach(GearType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        }
    }
    
    private var characteristicsSection: some View {
        Section(header: Text("Characteristics"), footer: Text("These affect logbook currency and requirements")) {
            Toggle("Complex", isOn: $isComplex)
            Toggle("High Performance (>200 HP)", isOn: $isHighPerformance)
            Toggle("Turbine Powered", isOn: $isTurbine)
            Toggle("Pressurized", isOn: $isPressurized)
            Toggle("Tailwheel", isOn: $isTailwheel)
        }
    }
    
    private var typeRatingSection: some View {
        Section(header: Text("Type Rating")) {
            Toggle("Requires Type Rating", isOn: $requiresTypeRating)
            
            if requiresTypeRating {
                HStack {
                    Text("Type Rating").foregroundColor(.gray)
                    Spacer()
                    TextField("DC-9", text: $typeRatingDesignation)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
        }
    }
    
    private var additionalSection: some View {
        Section(header: Text("Additional")) {
            HStack {
                Text("Last Known TAT").foregroundColor(.gray)
                Spacer()
                TextField("12345.6", text: $lastTATValue)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            
            VStack(alignment: .leading) {
                Text("Notes").foregroundColor(.gray)
                TextEditor(text: $notes)
                    .frame(height: 80)
            }
        }
    }
    
    private func loadExistingAircraft() {
        guard let ac = mode.aircraft else { return }
        tailNumber = ac.tailNumber
        typeDesignator = ac.typeDesignator
        manufacturer = ac.manufacturer
        model = ac.model
        category = ac.category
        aircraftClass = ac.aircraftClass
        engineType = ac.engineType
        engineCount = ac.engineCount
        gearType = ac.gearType
        isComplex = ac.isComplex
        isHighPerformance = ac.isHighPerformance
        isTurbine = ac.isTurbine
        isPressurized = ac.isPressurized
        isTailwheel = ac.isTailwheel
        requiresTypeRating = ac.requiresTypeRating
        typeRatingDesignation = ac.typeRatingDesignation ?? ""
        notes = ac.notes
        lastTATValue = ac.lastTATValue
    }
    
    private func applyTemplate(_ template: AircraftTypeTemplate) {
        typeDesignator = template.typeDesignator
        manufacturer = template.manufacturer
        model = template.model
        category = template.category
        aircraftClass = template.aircraftClass
        engineType = template.engineType
        engineCount = template.engineCount
        isComplex = template.isComplex
        isHighPerformance = template.isHighPerformance
        isTurbine = template.isTurbine
        isPressurized = template.isPressurized
        requiresTypeRating = template.requiresTypeRating
        typeRatingDesignation = template.typeRatingDesignation ?? ""
        gearType = template.isComplex ? .retractable : .tricycle
    }
    
    private func saveAircraft() {
        let newAircraft = AircraftRecord(
            id: mode.aircraft?.id ?? UUID(),
            tailNumber: tailNumber,
            typeDesignator: typeDesignator,
            manufacturer: manufacturer,
            model: model,
            category: category,
            aircraftClass: aircraftClass,
            engineType: engineType,
            engineCount: engineCount,
            gearType: gearType,
            isComplex: isComplex,
            isHighPerformance: isHighPerformance,
            isTurbine: isTurbine,
            isPressurized: isPressurized,
            isTailwheel: isTailwheel,
            requiresTypeRating: requiresTypeRating,
            typeRatingDesignation: typeRatingDesignation.isEmpty ? nil : typeRatingDesignation,
            notes: notes,
            lastTATValue: lastTATValue,
            dateAdded: mode.aircraft?.dateAdded ?? Date(),
            isUserAdded: true
        )
        
        switch mode {
        case .add:
            database.addAircraft(newAircraft)
        case .edit:
            database.updateAircraft(newAircraft)
        }
    }
}

// MARK: - Simple Aircraft Type Selector (Simplified to avoid compiler timeout)
struct SimpleAircraftTypeSelector: View {
    let onSelect: (AircraftTypeTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let typesList: [(String, AircraftTypeTemplate)]
    
    init(onSelect: @escaping (AircraftTypeTemplate) -> Void) {
        self.onSelect = onSelect
        self.typesList = Array(commonAircraftTypes).sorted { $0.key < $1.key }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(typesList, id: \.0) { key, template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(template.manufacturer + " " + template.model)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(template.aircraftClass.abbreviation)
                                    .font(.caption)
                                    .foregroundColor(LogbookTheme.accentBlue)
                                
                                Text(template.engineType.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listRowBackground(LogbookTheme.fieldBackground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Select Aircraft Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EnhancedAircraftManagementView()
}

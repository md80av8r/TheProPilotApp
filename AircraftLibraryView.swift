// AircraftLibraryView.swift
// UI for managing aircraft library
// Created December 2025

import SwiftUI

struct AircraftLibraryView: View {
    @ObservedObject var store: AircraftLibraryStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedAircraft: AircraftDefinition?
    @State private var searchText = ""
    
    var filteredAircraft: [AircraftDefinition] {
        if searchText.isEmpty {
            return store.aircraft.sorted { $0.registration < $1.registration }
        }
        return store.searchAircraft(matching: searchText).sorted { $0.registration < $1.registration }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Search bar
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search aircraft...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                }
                
                // Aircraft list
                Section(header: Text("Your Aircraft (\(filteredAircraft.count))")) {
                    ForEach(filteredAircraft) { aircraft in
                        AircraftLibraryRowView(aircraft: aircraft)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAircraft = aircraft
                                showingEditSheet = true
                            }
                    }
                    .onDelete { offsets in
                        deleteAircraft(at: offsets)
                    }
                }
                
                // Info section
                Section(header: Text("About Aircraft Library")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Aircraft definitions are used for ForeFlight exports", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Label("Tap an aircraft to edit, swipe to delete", systemImage: "hand.tap")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Label("New tail numbers will prompt to copy settings", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Aircraft Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AircraftEditView(
                store: store,
                aircraft: nil,
                isNewAircraft: true
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let aircraft = selectedAircraft {
                AircraftEditView(
                    store: store,
                    aircraft: aircraft,
                    isNewAircraft: false
                )
            }
        }
    }
    
    private func deleteAircraft(at offsets: IndexSet) {
        // Map offsets from filtered list to actual store indices
        let aircraftToDelete = offsets.map { filteredAircraft[$0] }
        for aircraft in aircraftToDelete {
            store.deleteAircraft(aircraft)
        }
    }
}

// MARK: - Aircraft Library Row View
struct AircraftLibraryRowView: View {
    let aircraft: AircraftDefinition
    
    var body: some View {
        HStack(spacing: 12) {
            // Aircraft icon
            ZStack {
                Circle()
                    .fill(aircraftColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: aircraftIcon)
                    .font(.system(size: 20))
                    .foregroundColor(aircraftColor)
            }
            
            // Aircraft info
            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.registration)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(aircraft.make) \(aircraft.model)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Tags
                HStack(spacing: 4) {
                    CategoryTag(text: aircraft.categoryClass.shortName, color: .blue)
                    
                    if aircraft.isComplex {
                        CategoryTag(text: "Complex", color: .orange)
                    }
                    if aircraft.isHighPerformance {
                        CategoryTag(text: "HP", color: .red)
                    }
                    if aircraft.isPressurized {
                        CategoryTag(text: "Press", color: .purple)
                    }
                }
            }
            
            Spacer()
            
            // Type code
            VStack(alignment: .trailing) {
                Text(aircraft.typeCode)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Text(aircraft.engineType.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private var aircraftIcon: String {
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
    
    private var aircraftColor: Color {
        switch aircraft.engineType {
        case .turbofan, .turbojet:
            return .blue
        case .turboprop, .turboshaft:
            return .orange
        case .piston, .radial:
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Category Tag
struct CategoryTag: View {
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

// MARK: - Aircraft Edit View
struct AircraftEditView: View {
    @ObservedObject var store: AircraftLibraryStore
    @Environment(\.dismiss) private var dismiss
    
    let aircraft: AircraftDefinition?
    let isNewAircraft: Bool
    
    @State private var registration: String = ""
    @State private var typeCode: String = ""
    @State private var yearString: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var gearType: AircraftGearType = .fixedTricycle
    @State private var engineType: AircraftEngineType = .piston
    @State private var categoryClass: AircraftCategoryClass = .airplaneSingleEngineLand
    @State private var equipmentType: AircraftEquipmentType = .aircraft
    @State private var isComplex: Bool = false
    @State private var isHighPerformance: Bool = false
    @State private var isPressurized: Bool = false
    @State private var isTAA: Bool = false
    
    @State private var showingTemplateSheet = false
    @State private var showingCopySheet = false
    
    var body: some View {
        NavigationView {
            Form {
                // Template/Copy section (only for new aircraft)
                if isNewAircraft {
                    Section(header: Text("Quick Start")) {
                        Button(action: { showingTemplateSheet = true }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Start from Template")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if !store.aircraft.isEmpty {
                            Button(action: { showingCopySheet = true }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.green)
                                    Text("Copy from Existing Aircraft")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                // Basic Info
                Section(header: Text("Aircraft Identification")) {
                    HStack {
                        Text("Registration")
                        Spacer()
                        TextField("N12345", text: $registration)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                            .autocapitalization(.allCharacters)
                    }
                    
                    HStack {
                        Text("Type Code")
                        Spacer()
                        TextField("C172", text: $typeCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                            .autocapitalization(.allCharacters)
                    }
                }
                
                // Make/Model
                Section(header: Text("Aircraft Details")) {
                    HStack {
                        Text("Make")
                        Spacer()
                        TextField("Cessna", text: $make)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Model")
                        Spacer()
                        TextField("172 Skyhawk", text: $model)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Year")
                        Spacer()
                        TextField("1998", text: $yearString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Configuration
                Section(header: Text("Configuration")) {
                    Picker("Category/Class", selection: $categoryClass) {
                        ForEach(AircraftCategoryClass.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    
                    Picker("Gear Type", selection: $gearType) {
                        ForEach(AircraftGearType.allCases, id: \.self) { gear in
                            Text(gear.displayName).tag(gear)
                        }
                    }
                    
                    Picker("Engine Type", selection: $engineType) {
                        ForEach(AircraftEngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    
                    Picker("Equipment Type", selection: $equipmentType) {
                        ForEach(AircraftEquipmentType.allCases, id: \.self) { equip in
                            Text(equip.displayName).tag(equip)
                        }
                    }
                }
                
                // FAA Flags
                Section(header: Text("FAA Classifications")) {
                    Toggle("Complex Aircraft", isOn: $isComplex)
                    Toggle("High Performance", isOn: $isHighPerformance)
                    Toggle("Pressurized", isOn: $isPressurized)
                    Toggle("Technically Advanced (TAA)", isOn: $isTAA)
                }
            }
            .navigationTitle(isNewAircraft ? "Add Aircraft" : "Edit Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAircraft() }
                        .disabled(registration.isEmpty || typeCode.isEmpty)
                }
            }
        }
        .onAppear {
            if let aircraft = aircraft {
                loadAircraft(aircraft)
            }
        }
        .sheet(isPresented: $showingTemplateSheet) {
            TemplateSelectionView { template in
                applyTemplate(template)
            }
        }
        .sheet(isPresented: $showingCopySheet) {
            CopyAircraftView(store: store) { source in
                applyTemplate(source)
            }
        }
    }
    
    private func loadAircraft(_ aircraft: AircraftDefinition) {
        registration = aircraft.registration
        typeCode = aircraft.typeCode
        yearString = aircraft.year != nil ? String(aircraft.year!) : ""
        make = aircraft.make
        model = aircraft.model
        gearType = aircraft.gearType
        engineType = aircraft.engineType
        categoryClass = aircraft.categoryClass
        equipmentType = aircraft.equipmentType
        isComplex = aircraft.isComplex
        isHighPerformance = aircraft.isHighPerformance
        isPressurized = aircraft.isPressurized
        isTAA = aircraft.isTAA
    }
    
    private func applyTemplate(_ template: AircraftDefinition) {
        typeCode = template.typeCode
        make = template.make
        model = template.model
        gearType = template.gearType
        engineType = template.engineType
        categoryClass = template.categoryClass
        equipmentType = template.equipmentType
        isComplex = template.isComplex
        isHighPerformance = template.isHighPerformance
        isPressurized = template.isPressurized
        isTAA = template.isTAA
        // Don't copy registration - user needs to enter their own
    }
    
    private func saveAircraft() {
        let newAircraft = AircraftDefinition(
            id: aircraft?.id ?? UUID(),
            registration: registration.uppercased(),
            typeCode: typeCode.uppercased(),
            year: Int(yearString),
            make: make,
            model: model,
            gearType: gearType,
            engineType: engineType,
            categoryClass: categoryClass,
            equipmentType: equipmentType,
            isComplex: isComplex,
            isHighPerformance: isHighPerformance,
            isPressurized: isPressurized,
            isTAA: isTAA
        )
        
        if isNewAircraft {
            store.addAircraft(newAircraft)
        } else {
            store.updateAircraft(newAircraft)
        }
        
        dismiss()
    }
}

// MARK: - Template Selection View
struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AircraftDefinition) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AircraftTemplates.allTemplates, id: \.name) { item in
                    Button(action: {
                        onSelect(item.template)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !item.template.typeCode.isEmpty {
                                    Text("\(item.template.categoryClass.shortName) • \(item.template.engineType.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
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

// MARK: - Copy Aircraft View
struct CopyAircraftView: View {
    @ObservedObject var store: AircraftLibraryStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AircraftDefinition) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(store.aircraft.sorted { $0.registration < $1.registration }) { aircraft in
                    Button(action: {
                        onSelect(aircraft)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(aircraft.registration)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(aircraft.make) \(aircraft.model)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(aircraft.typeCode)
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                            
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
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
    AircraftLibraryView(store: AircraftLibraryStore())
}

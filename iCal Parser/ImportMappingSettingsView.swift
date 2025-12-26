//
//  ImportMappingSettingsView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//

import SwiftUI

struct ImportMappingSettingsView: View {
    @EnvironmentObject var mappingStore: ImportMappingStore
    @State private var showNewMappingWizard = false
    @State private var mappingToEdit: ImportMapping?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(mappingStore.savedMappings) { mapping in
                        MappingRow(mapping: mapping, mappingStore: mappingStore)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMapping(mapping)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    mappingToEdit = mapping
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let mapping = mappingStore.savedMappings[index]
                            mappingStore.delete(mapping)
                        }
                    }
                } header: {
                    Text("Saved Import Templates")
                } footer: {
                    Text("Import templates define how to parse iCalendar files from different scheduling systems.")
                }
                
                Section {
                    Button {
                        showNewMappingWizard = true
                    } label: {
                        Label("Create New Mapping", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Import Templates")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNewMappingWizard) {
                ICalendarImportWizardView()
            }
            .sheet(item: $mappingToEdit) { mapping in
                // Could create a dedicated editing view here
                // For now, we'll just show the import wizard
                ICalendarImportWizardView()
            }
        }
    }
    
    private func deleteMapping(_ mapping: ImportMapping) {
        mappingStore.delete(mapping)
    }
}

struct MappingRow: View {
    let mapping: ImportMapping
    @ObservedObject var mappingStore: ImportMappingStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.name)
                    .font(.headline)
                
                Text("\(mapping.fieldMappings.count) field mappings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !mapping.activityFilters.flightKeywords.isEmpty {
                    Text("Keywords: \(mapping.activityFilters.flightKeywords.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if mapping.isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Button {
                    mappingStore.setDefault(mapping)
                } label: {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ImportMappingSettingsView()
        .environmentObject(ImportMappingStore())
}

// UserAirportCodeMappings.swift
// User-configurable IATA to ICAO airport code mappings
// Created for ProPilot App

import Foundation
import SwiftUI

/// Manages user-added IATA to ICAO airport code mappings
/// Users can add custom mappings for airports not in the built-in database
class UserAirportCodeMappings: ObservableObject {
    static let shared = UserAirportCodeMappings()
    
    @Published var mappings: [String: String] = [:] {
        didSet {
            saveMappings()
        }
    }
    
    /// Alias for backward compatibility with views
    var userMappings: [String: String] {
        return mappings
    }
    
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    private let mappingsKey = "UserAirportCodeMappings"
    
    private init() {
        loadMappings()
    }
    
    // MARK: - Public Methods
    
    /// Get ICAO code for an IATA code (returns nil if not found)
    func getICAO(for iataCode: String) -> String? {
        let clean = iataCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mappings[clean]
    }
    
    /// Add a new IATA to ICAO mapping
    func addMapping(iata: String, icao: String) {
        let cleanIATA = iata.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanICAO = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanIATA.count == 3, cleanICAO.count == 4 else {
            print("❌ Invalid airport code format: IATA=\(cleanIATA), ICAO=\(cleanICAO)")
            return
        }
        
        mappings[cleanIATA] = cleanICAO
        print("✅ Added user mapping: \(cleanIATA) → \(cleanICAO)")
    }
    
    /// Remove a mapping
    func removeMapping(iata: String) {
        let clean = iata.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        mappings.removeValue(forKey: clean)
        print("🗑️ Removed user mapping: \(clean)")
    }
    
    /// Check if a mapping exists
    func hasMapping(for iataCode: String) -> Bool {
        let clean = iataCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mappings[clean] != nil
    }
    
    /// Get all mappings sorted by IATA code
    var sortedMappings: [(iata: String, icao: String)] {
        mappings.map { (iata: $0.key, icao: $0.value) }
            .sorted { $0.iata < $1.iata }
    }
    
    // MARK: - Persistence
    
    private func saveMappings() {
        do {
            let data = try JSONEncoder().encode(mappings)
            userDefaults?.set(data, forKey: mappingsKey)
            userDefaults?.synchronize()
            print("💾 Saved \(mappings.count) user airport mappings")
        } catch {
            print("❌ Failed to save user airport mappings: \(error)")
        }
    }
    
    private func loadMappings() {
        guard let data = userDefaults?.data(forKey: mappingsKey) else {
            print("📋 No user airport mappings found")
            return
        }
        
        do {
            mappings = try JSONDecoder().decode([String: String].self, from: data)
            print("📋 Loaded \(mappings.count) user airport mappings")
        } catch {
            print("❌ Failed to load user airport mappings: \(error)")
        }
    }
}

// MARK: - User Airport Mappings Settings View
struct UserAirportMappingsView: View {
    @StateObject private var mappings = UserAirportCodeMappings.shared
    @State private var newIATA = ""
    @State private var newICAO = ""
    @State private var showingAddSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var mappingToDelete: String?
    
    var body: some View {
        List {
            // Add New Section
            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add Airport Code Mapping")
                            .foregroundColor(.white)
                    }
                }
            } header: {
                Text("Add New")
            } footer: {
                Text("Add custom IATA to ICAO mappings for airports not in the built-in database")
            }
            .listRowBackground(LogbookTheme.fieldBackground)
            
            // Current Mappings Section
            if !mappings.sortedMappings.isEmpty {
                Section {
                    ForEach(mappings.sortedMappings, id: \.iata) { mapping in
                        HStack {
                            Text(mapping.iata)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 50, alignment: .leading)
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                            
                            Text(mapping.icao)
                                .font(.headline)
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 60, alignment: .leading)
                            
                            Spacer()
                        }
                        .listRowBackground(LogbookTheme.fieldBackground)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                mappingToDelete = mapping.iata
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Your Custom Mappings (\(mappings.mappings.count))")
                }
            }
            
            // Help Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("How it works")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text("When NOC roster data uses 3-letter IATA codes (like CUU), ProPilot converts them to 4-letter ICAO codes (like MMCU).")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("If you encounter an airport code that isn't converting correctly, add it here.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(LogbookTheme.fieldBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LogbookTheme.navy.ignoresSafeArea())
        .navigationTitle("Airport Code Mappings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddAirportMappingSheet(
                iata: $newIATA,
                icao: $newICAO,
                onSave: {
                    if !newIATA.isEmpty && !newICAO.isEmpty {
                        mappings.addMapping(iata: newIATA, icao: newICAO)
                        newIATA = ""
                        newICAO = ""
                    }
                }
            )
        }
        .confirmationDialog(
            "Delete Mapping",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let iata = mappingToDelete {
                    mappings.removeMapping(iata: iata)
                }
                mappingToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                mappingToDelete = nil
            }
        } message: {
            if let iata = mappingToDelete {
                Text("Are you sure you want to delete the mapping for \(iata)?")
            }
        }
    }
}

// MARK: - Add Mapping Sheet
struct AddAirportMappingSheet: View {
    @Binding var iata: String
    @Binding var icao: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var isValidInput: Bool {
        iata.count == 3 && icao.count == 4 &&
        iata.allSatisfy { $0.isLetter } &&
        icao.allSatisfy { $0.isLetter }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("IATA (3-letter)")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., SLW", text: $iata)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("ICAO (4-letter)")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., MMIO", text: $icao)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("Airport Codes")
                } footer: {
                    Text("IATA codes are 3 letters (used by airlines). ICAO codes are 4 letters (used in aviation).")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Examples:")
                            .font(.headline)
                        
                        HStack {
                            Text("SLW → MMIO")
                                .font(.caption.monospaced())
                            Spacer()
                            Text("(Los Mochis, Mexico)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("HUF → KHUF")
                                .font(.caption.monospaced())
                            Spacer()
                            Text("(Terre Haute, IN)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("YQG → CYQG")
                                .font(.caption.monospaced())
                            Spacer()
                            Text("(Windsor, ON)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Add Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        UserAirportMappingsView()
    }
}

// EnhancedAirportCodeManager.swift
// Smart Airport Code Management with Auto-Detection of Unknown Codes
// Created for ProPilot App

import Foundation
import SwiftUI
import Combine

// MARK: - Unknown Airport Code Detection

/// Manages detection and resolution of unknown airport codes
class UnknownAirportCodeManager: ObservableObject {
    static let shared = UnknownAirportCodeManager()
    
    @Published var unknownCodes: Set<String> = []
    @Published var pendingCode: String?
    @Published var showingAddPrompt = false
    
    private let userDefaults = UserDefaults(suiteName: "group.com.propilot.app")
    private let unknownCodesKey = "UnknownAirportCodes"
    
    private init() {
        loadUnknownCodes()
    }
    
    // MARK: - Code Checking
    
    /// Check if a code is known (either built-in or user-added)
    func isKnownCode(_ code: String) -> Bool {
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Already ICAO format (4 letters)?
        if clean.count == 4 && clean.allSatisfy({ $0.isLetter }) {
            let firstChar = clean.first!
            if "KCMPTOELSW".contains(firstChar) {
                return true  // Assume valid ICAO
            }
        }
        
        // Check user mappings
        if UserAirportCodeMappings.shared.hasMapping(for: clean) {
            return true
        }
        
        // Check built-in IATA map (from RosterModels)
        // We'll check against a static reference
        return BuiltInAirportCodes.hasCode(clean)
    }
    
    /// Report an unknown code encountered during roster parsing
    func reportUnknownCode(_ code: String) {
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard clean.count == 3, clean.allSatisfy({ $0.isLetter }) else { return }
        guard !isKnownCode(clean) else { return }
        
        if !unknownCodes.contains(clean) {
            unknownCodes.insert(clean)
            saveUnknownCodes()
            print("⚠️ Unknown airport code encountered: \(clean)")
            
            // Post notification for UI to handle
            NotificationCenter.default.post(
                name: .unknownAirportCodeDetected,
                object: nil,
                userInfo: ["code": clean]
            )
        }
    }
    
    /// Prompt user to add a mapping for an unknown code
    func promptForMapping(_ code: String) {
        pendingCode = code.uppercased()
        showingAddPrompt = true
    }
    
    /// Mark a code as resolved (user added mapping or dismissed)
    func markResolved(_ code: String) {
        let clean = code.uppercased()
        unknownCodes.remove(clean)
        saveUnknownCodes()
        pendingCode = nil
        print("✅ Resolved unknown code: \(clean)")
    }
    
    /// Clear all unknown codes
    func clearAll() {
        unknownCodes.removeAll()
        saveUnknownCodes()
    }
    
    // MARK: - Persistence
    
    private func saveUnknownCodes() {
        let array = Array(unknownCodes)
        userDefaults?.set(array, forKey: unknownCodesKey)
    }
    
    private func loadUnknownCodes() {
        if let array = userDefaults?.stringArray(forKey: unknownCodesKey) {
            unknownCodes = Set(array)
        }
    }
}

// MARK: - Built-In Airport Codes Reference

/// Static reference to built-in IATA codes (mirrors RosterModels.iataToIcaoMap)
struct BuiltInAirportCodes {
    static let codes: Set<String> = [
        // USA - Major
        "YIP", "DTW", "ORD", "MDW", "LAX", "LAS", "PHX", "DEN", "ATL", "MIA",
        "JFK", "LGA", "EWR", "BOS", "DCA", "IAD", "BWI", "PHL", "CLT", "MSP",
        "SEA", "SFO", "PDX", "LRD", "ELP", "SAT", "AUS", "DFW", "DAL", "IAH",
        "HOU", "FLL", "MCO", "TPA", "SDF", "IND", "CVG", "CMH", "CLE", "PIT",
        "MEM", "BNA", "STL", "MCI", "OMA", "DSM", "MSN", "MKE", "GRR", "ABQ",
        "TUS", "SAN", "OAK", "SJC", "SMF", "RNO", "SLC", "BOI", "PSC", "GEG",
        "ANC", "HNL", "OGG", "CRP", "MFE", "BRO", "HRL", "MAF", "LBB", "AMA",
        "OKC", "TUL", "ICT", "LIT", "XNA", "SHV", "BTR", "MSY", "GPT", "MOB",
        "JAN", "BHM", "HSV", "CHA", "TYS", "GSO", "RDU", "RIC", "ORF", "JAX",
        "RSW", "PBI", "SRQ", "SAV", "CHS", "MYR", "CAE", "AGS", "HUF",
        
        // Mexico
        "MEX", "CUN", "GDL", "TIJ", "MTY", "PVR", "CZM", "MZT", "SJD", "QRO",
        "CUU", "BJX", "AGU", "SLP", "ZCL", "CUL", "HMO", "OAX", "PBC", "VER",
        "VSA", "MID", "CME", "TAM", "NLD", "REX", "MAM", "LAP", "ZLO", "ZIH",
        "ACA", "TAP", "SLW",
        
        // Canada
        "YYZ", "YVR", "YUL", "YYC", "YEG", "YOW", "YWG", "YHZ", "YQB", "YXE",
        "YQR", "YLW", "YXX", "YYJ", "YZF", "YXY", "YQG",
        
        // Caribbean
        "NAS", "SJU", "STT", "STX", "SXM", "CUR", "AUA", "BON", "POS", "BGI",
        "PUJ", "SDQ", "STI", "KIN", "MBJ", "HAV", "GCM", "BZE",
        
        // Central America
        "GUA", "SAL", "TGU", "MGA", "SJO", "PTY"
    ]
    
    static func hasCode(_ code: String) -> Bool {
        codes.contains(code.uppercased())
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let unknownAirportCodeDetected = Notification.Name("unknownAirportCodeDetected")
}

// MARK: - Enhanced User Airport Mappings View

struct EnhancedAirportMappingsView: View {
    @StateObject private var mappings = UserAirportCodeMappings.shared
    @StateObject private var unknownManager = UnknownAirportCodeManager.shared
    @State private var showingAddSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var mappingToDelete: String?
    @State private var editingMapping: (iata: String, icao: String)?
    @State private var showingEditSheet = false
    
    var body: some View {
        List {
            // Unknown Codes Alert Section
            if !unknownManager.unknownCodes.isEmpty {
                Section {
                    ForEach(Array(unknownManager.unknownCodes).sorted(), id: \.self) { code in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text(code)
                                .font(.headline.monospaced())
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Add Mapping") {
                                unknownManager.promptForMapping(code)
                                showingAddSheet = true
                            }
                            .font(.caption)
                            .foregroundColor(LogbookTheme.accentBlue)
                        }
                        .listRowBackground(LogbookTheme.warningYellow.opacity(0.2))
                    }
                } header: {
                    HStack {
                        Text("Unknown Codes Detected")
                        Spacer()
                        Button("Clear All") {
                            unknownManager.clearAll()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                } footer: {
                    Text("These codes were found in your roster but aren't in the database. Add mappings to convert them correctly.")
                }
            }
            
            // Add New Section
            Section {
                Button {
                    unknownManager.pendingCode = nil
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
            }
            .listRowBackground(LogbookTheme.fieldBackground)
            
            // Current Mappings Section
            if !mappings.sortedMappings.isEmpty {
                Section {
                    ForEach(mappings.sortedMappings, id: \.iata) { mapping in
                        HStack {
                            Text(mapping.iata)
                                .font(.headline.monospaced())
                                .foregroundColor(.white)
                                .frame(width: 50, alignment: .leading)
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                            
                            Text(mapping.icao)
                                .font(.headline.monospaced())
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 60, alignment: .leading)
                            
                            Spacer()
                            
                            // Edit button
                            Button {
                                editingMapping = mapping
                                showingEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.borderless)
                        }
                        .listRowBackground(LogbookTheme.fieldBackground)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                mappingToDelete = mapping.iata
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                editingMapping = mapping
                                showingEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(LogbookTheme.accentBlue)
                        }
                    }
                } header: {
                    Text("Your Custom Mappings (\(mappings.mappings.count))")
                }
            }
            
            // Built-In Stats
            Section {
                HStack {
                    Image(systemName: "building.columns")
                        .foregroundColor(.gray)
                    Text("Built-in mappings")
                    Spacer()
                    Text("\(BuiltInAirportCodes.codes.count)")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text("Your custom mappings")
                    Spacer()
                    Text("\(mappings.mappings.count)")
                        .foregroundColor(LogbookTheme.accentBlue)
                }
            } header: {
                Text("Database Stats")
            }
            .listRowBackground(LogbookTheme.fieldBackground)
            
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
                    
                    Text("When NOC roster data uses 3-letter IATA codes (like CUU), ProPilot converts them to 4-letter ICAO codes (like MMCU) for consistency.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Your custom mappings take priority over built-in ones, so you can correct any errors.")
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
            AddMappingSheet(
                prefilledIATA: unknownManager.pendingCode ?? "",
                onSave: { iata, icao in
                    mappings.addMapping(iata: iata, icao: icao)
                    unknownManager.markResolved(iata)
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let mapping = editingMapping {
                EditMappingSheet(
                    originalIATA: mapping.iata,
                    originalICAO: mapping.icao,
                    onSave: { iata, icao in
                        // Remove old mapping if IATA changed
                        if iata != mapping.iata {
                            mappings.removeMapping(iata: mapping.iata)
                        }
                        mappings.addMapping(iata: iata, icao: icao)
                    }
                )
            }
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
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let iata = mappingToDelete {
                Text("Delete the mapping for \(iata)?")
            }
        }
    }
}

// MARK: - Add Mapping Sheet
struct AddMappingSheet: View {
    let prefilledIATA: String
    let onSave: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var iata: String = ""
    @State private var icao: String = ""
    @State private var showingLookupHelp = false
    
    var isValidInput: Bool {
        let cleanIATA = iata.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanICAO = icao.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanIATA.count == 3 && cleanICAO.count == 4 &&
               cleanIATA.allSatisfy { $0.isLetter } &&
               cleanICAO.allSatisfy { $0.isLetter }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("IATA Code")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., SLW", text: $iata)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .font(.headline.monospaced())
                    }
                    
                    HStack {
                        Text("ICAO Code")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., MMIO", text: $icao)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .font(.headline.monospaced())
                    }
                } header: {
                    Text("Airport Codes")
                } footer: {
                    Text("IATA: 3-letter airline code • ICAO: 4-letter aviation code")
                }
                
                // Quick lookup help
                Section {
                    Button {
                        showingLookupHelp = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("How to find ICAO codes")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Preview
                if isValidInput {
                    Section {
                        HStack {
                            Text("Preview:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(iata.uppercased()) → \(icao.uppercased())")
                                .font(.headline.monospaced())
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Add Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(iata.uppercased(), icao.uppercased())
                        dismiss()
                    }
                    .disabled(!isValidInput)
                    .foregroundColor(isValidInput ? LogbookTheme.accentGreen : .gray)
                }
            }
            .onAppear {
                iata = prefilledIATA
            }
            .alert("Finding ICAO Codes", isPresented: $showingLookupHelp) {
                Button("OK") { }
            } message: {
                Text("You can find ICAO codes by:\n\n• Searching \"[airport name] ICAO code\"\n• Using SkyVector.com\n• Using AirNav.com\n\nUS airports start with K\nCanada starts with C\nMexico starts with MM")
            }
        }
    }
}

// MARK: - Edit Mapping Sheet
struct EditMappingSheet: View {
    let originalIATA: String
    let originalICAO: String
    let onSave: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var iata: String = ""
    @State private var icao: String = ""
    
    var isValidInput: Bool {
        let cleanIATA = iata.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanICAO = icao.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanIATA.count == 3 && cleanICAO.count == 4 &&
               cleanIATA.allSatisfy { $0.isLetter } &&
               cleanICAO.allSatisfy { $0.isLetter }
    }
    
    var hasChanges: Bool {
        iata.uppercased() != originalIATA || icao.uppercased() != originalICAO
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("IATA Code")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., SLW", text: $iata)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .font(.headline.monospaced())
                    }
                    
                    HStack {
                        Text("ICAO Code")
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("e.g., MMIO", text: $icao)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .font(.headline.monospaced())
                    }
                } header: {
                    Text("Edit Mapping")
                }
                
                // Show original values
                Section {
                    HStack {
                        Text("Original:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(originalIATA) → \(originalICAO)")
                            .font(.caption.monospaced())
                            .foregroundColor(.gray)
                    }
                    
                    if hasChanges && isValidInput {
                        HStack {
                            Text("New:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(iata.uppercased()) → \(icao.uppercased())")
                                .font(.caption.monospaced())
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Edit Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(iata.uppercased(), icao.uppercased())
                        dismiss()
                    }
                    .disabled(!isValidInput || !hasChanges)
                    .foregroundColor((isValidInput && hasChanges) ? LogbookTheme.accentGreen : .gray)
                }
            }
            .onAppear {
                iata = originalIATA
                icao = originalICAO
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        EnhancedAirportMappingsView()
    }
}

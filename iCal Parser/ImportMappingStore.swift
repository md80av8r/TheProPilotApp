//
//  ImportMappingStore.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//

import Foundation
import SwiftUI

class ImportMappingStore: ObservableObject {
    @Published var savedMappings: [ImportMapping] = []
    
    private let userDefaultsKey = "SavedImportMappings"
    
    init() {
        loadMappings()
    }
    
    func loadMappings() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let mappings = try? JSONDecoder().decode([ImportMapping].self, from: data) {
            savedMappings = mappings
        } else {
            // Start with USA Jet preset
            savedMappings = [.usaJetRAIDO]
        }
    }
    
    func save(_ mapping: ImportMapping) {
        if let index = savedMappings.firstIndex(where: { $0.id == mapping.id }) {
            savedMappings[index] = mapping
        } else {
            savedMappings.append(mapping)
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(savedMappings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func delete(_ mapping: ImportMapping) {
        savedMappings.removeAll { $0.id == mapping.id }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(savedMappings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func setDefault(_ mapping: ImportMapping) {
        // Remove default from all others
        for index in savedMappings.indices {
            savedMappings[index].isDefault = false
        }
        
        // Set the selected one as default
        if let index = savedMappings.firstIndex(where: { $0.id == mapping.id }) {
            savedMappings[index].isDefault = true
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(savedMappings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    var defaultMapping: ImportMapping? {
        savedMappings.first(where: { $0.isDefault })
    }
}

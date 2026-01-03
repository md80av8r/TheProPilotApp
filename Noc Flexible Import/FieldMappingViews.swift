//
//  FieldMappingViews.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 1/1/26.
//

import SwiftUI

// MARK: - Field Mapping Confirmation View
struct FieldMappingConfirmationView: View {
    let profile: SDImportProfile
    let onApprove: (SDImportProfile) -> Void
    let onEdit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Summary")) {
                    HStack {
                        Text("Airline")
                        Spacer()
                        Text(profile.airlineName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(profile.isBuiltIn ? "Built-in Template" : "Custom")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Field Mappings")) {
                    mappingRow(label: "Flight Number", rule: profile.flightNumberRule)
                    mappingRow(label: "Departure", rule: profile.departureRule)
                    mappingRow(label: "Arrival", rule: profile.arrivalRule)
                    mappingRow(label: "Scheduled Out", rule: profile.scheduledOutRule)
                    mappingRow(label: "Scheduled In", rule: profile.scheduledInRule)
                    mappingRow(label: "Aircraft", rule: profile.aircraftRule)
                    mappingRow(label: "Pilot Role", rule: profile.pilotRoleRule)
                    mappingRow(label: "Check In", rule: profile.checkInRule)
                    mappingRow(label: "Check Out", rule: profile.checkOutRule)
                    mappingRow(label: "Trip Number", rule: profile.tripNumberRule)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This profile will be used to parse your NOC schedule data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("You can edit the field mappings if the defaults don't match your airline's format.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Confirm Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Use This Profile") {
                        onApprove(profile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button(action: {
                        dismiss()
                        onEdit()
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Mappings")
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func mappingRow(label: String, rule: ParsingRule?) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let rule = rule {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rule.sourceField.rawValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                    if rule.extractionMethod == .regex {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            } else {
                Text("Not Mapped")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Field Mapping Editor View
struct FieldMappingEditorView: View {
    let profile: SDImportProfile
    let onSave: (SDImportProfile) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editableProfile: SDImportProfile
    
    init(profile: SDImportProfile, onSave: @escaping (SDImportProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        _editableProfile = State(initialValue: profile)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Airline Name", text: $editableProfile.airlineName)
                }
                
                Section(header: Text("Flight Information Fields")) {
                    NavigationLink("Flight Number") {
                        FieldRuleEditorView(
                            fieldName: "Flight Number",
                            rule: editableProfile.flightNumberRule,
                            onSave: { editableProfile.flightNumberRule = $0 }
                        )
                    }
                    
                    NavigationLink("Departure Airport") {
                        FieldRuleEditorView(
                            fieldName: "Departure",
                            rule: editableProfile.departureRule,
                            onSave: { editableProfile.departureRule = $0 }
                        )
                    }
                    
                    NavigationLink("Arrival Airport") {
                        FieldRuleEditorView(
                            fieldName: "Arrival",
                            rule: editableProfile.arrivalRule,
                            onSave: { editableProfile.arrivalRule = $0 }
                        )
                    }
                }
                
                Section(header: Text("Time Fields")) {
                    NavigationLink("Scheduled Out") {
                        FieldRuleEditorView(
                            fieldName: "Scheduled Out",
                            rule: editableProfile.scheduledOutRule,
                            onSave: { editableProfile.scheduledOutRule = $0 }
                        )
                    }
                    
                    NavigationLink("Scheduled In") {
                        FieldRuleEditorView(
                            fieldName: "Scheduled In",
                            rule: editableProfile.scheduledInRule,
                            onSave: { editableProfile.scheduledInRule = $0 }
                        )
                    }
                    
                    NavigationLink("Check In") {
                        FieldRuleEditorView(
                            fieldName: "Check In",
                            rule: editableProfile.checkInRule,
                            onSave: { editableProfile.checkInRule = $0 }
                        )
                    }
                    
                    NavigationLink("Check Out") {
                        FieldRuleEditorView(
                            fieldName: "Check Out",
                            rule: editableProfile.checkOutRule,
                            onSave: { editableProfile.checkOutRule = $0 }
                        )
                    }
                }
                
                Section(header: Text("Additional Fields")) {
                    NavigationLink("Aircraft") {
                        FieldRuleEditorView(
                            fieldName: "Aircraft",
                            rule: editableProfile.aircraftRule,
                            onSave: { editableProfile.aircraftRule = $0 }
                        )
                    }
                    
                    NavigationLink("Pilot Role") {
                        FieldRuleEditorView(
                            fieldName: "Pilot Role",
                            rule: editableProfile.pilotRoleRule,
                            onSave: { editableProfile.pilotRoleRule = $0 }
                        )
                    }
                    
                    NavigationLink("Trip Number") {
                        FieldRuleEditorView(
                            fieldName: "Trip Number",
                            rule: editableProfile.tripNumberRule,
                            onSave: { editableProfile.tripNumberRule = $0 }
                        )
                    }
                }
            }
            .navigationTitle("Edit Field Mappings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editableProfile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Field Rule Editor View
struct FieldRuleEditorView: View {
    let fieldName: String
    let rule: ParsingRule?
    let onSave: (ParsingRule?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var sourceField: ParsingRule.ICalField
    @State private var extractionMethod: ParsingRule.ExtractionMethod
    @State private var regexPattern: String
    @State private var fallbackValue: String
    @State private var isEnabled: Bool
    
    init(fieldName: String, rule: ParsingRule?, onSave: @escaping (ParsingRule?) -> Void) {
        self.fieldName = fieldName
        self.rule = rule
        self.onSave = onSave
        
        _sourceField = State(initialValue: rule?.sourceField ?? .summary)
        _extractionMethod = State(initialValue: rule?.extractionMethod ?? .direct)
        _regexPattern = State(initialValue: rule?.regex ?? "")
        _fallbackValue = State(initialValue: rule?.fallbackValue ?? "")
        _isEnabled = State(initialValue: rule != nil)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Field Mapping", isOn: $isEnabled)
            }
            
            if isEnabled {
                Section(header: Text("Source Field")) {
                    Picker("iCal Field", selection: $sourceField) {
                        ForEach([ParsingRule.ICalField.summary, .description, .dtstart, .dtend, .location, .uid, .categories, .status], id: \.self) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                }
                
                Section(header: Text("Extraction Method")) {
                    Picker("Method", selection: $extractionMethod) {
                        Text("Direct").tag(ParsingRule.ExtractionMethod.direct)
                        Text("Regex Pattern").tag(ParsingRule.ExtractionMethod.regex)
                        Text("Split").tag(ParsingRule.ExtractionMethod.split)
                        Text("Multi-line").tag(ParsingRule.ExtractionMethod.multiLine)
                    }
                    .pickerStyle(.menu)
                }
                
                if extractionMethod == .regex {
                    Section(header: Text("Regex Pattern")) {
                        TextField("Pattern", text: $regexPattern)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("Use parentheses () to capture the value you want to extract.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Fallback Value (Optional)")) {
                    TextField("Default Value", text: $fallbackValue)
                }
            }
        }
        .navigationTitle(fieldName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isEnabled {
                        let newRule = ParsingRule(
                            sourceField: sourceField,
                            extractionMethod: extractionMethod,
                            regex: regexPattern.isEmpty ? nil : regexPattern,
                            fallbackValue: fallbackValue.isEmpty ? nil : fallbackValue
                        )
                        onSave(newRule)
                    } else {
                        onSave(nil)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

//
//  DocumentCropSettingsView.swift
//  TheProPilotApp
//
//  Settings view for document side cropping
//

import SwiftUI

struct DocumentCropSettingsView: View {
    @Binding var cropSettings: DocumentCropProcessor.CropSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Automatically crop sides of scanned documents to remove edges")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Side Cropping")
                }
                
                Section {
                    HStack {
                        Text("Left")
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $cropSettings.leftCropPercentage, in: 0...15, step: 0.5)
                        Text("\(cropSettings.leftCropPercentage, specifier: "%.1f")%")
                            .frame(width: 50, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Right")
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $cropSettings.rightCropPercentage, in: 0...15, step: 0.5)
                        Text("\(cropSettings.rightCropPercentage, specifier: "%.1f")%")
                            .frame(width: 50, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Top")
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $cropSettings.topCropPercentage, in: 0...15, step: 0.5)
                        Text("\(cropSettings.topCropPercentage, specifier: "%.1f")%")
                            .frame(width: 50, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bottom")
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $cropSettings.bottomCropPercentage, in: 0...15, step: 0.5)
                        Text("\(cropSettings.bottomCropPercentage, specifier: "%.1f")%")
                            .frame(width: 50, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Crop Amount per Side")
                } footer: {
                    Text("Adjust how much to crop from each side (0-15%)")
                        .font(.caption)
                }
                
                Section {
                    Button("Reset to Default") {
                        cropSettings = DocumentCropProcessor.CropSettings()
                    }
                    .foregroundColor(.red)
                    
                    Button("Set Quick Presets") {
                        // Do nothing - just a header for the buttons below
                    }
                    .disabled(true)
                    .hidden()
                    
                    HStack {
                        Button("Light (2%)") {
                            cropSettings.leftCropPercentage = 2
                            cropSettings.rightCropPercentage = 2
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Medium (5%)") {
                            cropSettings.leftCropPercentage = 5
                            cropSettings.rightCropPercentage = 5
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Heavy (8%)") {
                            cropSettings.leftCropPercentage = 8
                            cropSettings.rightCropPercentage = 8
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Quick Actions")
                }
                
                if cropSettings.isEnabled {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Side cropping is active")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Document Cropping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save settings
                        UserDefaults.standard.documentCropSettings = cropSettings
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct DocumentCropSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentCropSettingsView(cropSettings: .constant(DocumentCropProcessor.CropSettings()))
    }
}

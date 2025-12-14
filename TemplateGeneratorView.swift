// TemplateGeneratorView.swift - FIXED for H:MM Format
import SwiftUI

struct TemplateGeneratorView: View {
    let format: LogbookFormat
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = UnifiedLogbookManager()
    @State private var showingShareSheet = false
    @State private var templateData: String = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: format.iconName)
                        .font(.system(size: 50))
                        .foregroundColor(format.color)
                    
                    Text("\(format.displayName) Template")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Download a PropilotApp-compatible template with H:MM time format")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Template Info - UPDATED for H:MM format
                VStack(alignment: .leading, spacing: 12) {
                    Text("Template Features:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        TemplateFeatureRow(icon: "checkmark.circle", text: "All \(format.exportHeaders.count) columns for \(format.displayName)")
                        TemplateFeatureRow(icon: "checkmark.circle", text: "H:MM time format (2:30 not 2.5)")
                        TemplateFeatureRow(icon: "checkmark.circle", text: "Sample flight data for reference")
                        TemplateFeatureRow(icon: "checkmark.circle", text: "Proper date formatting (MM/DD/YYYY)")
                        TemplateFeatureRow(icon: "checkmark.circle", text: "Clean field formatting (no complex data)")
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                
                // Format-specific notes
                formatSpecificNotes
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Use:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionStep(number: 1, text: "Download the template below")
                        InstructionStep(number: 2, text: "Open in Excel, Numbers, or Google Sheets")
                        InstructionStep(number: 3, text: "Replace sample data with your flights")
                        InstructionStep(number: 4, text: "Keep H:MM format for times (2:30 not 2.5)")
                        InstructionStep(number: 5, text: "Save as CSV and import back into PropilotApp")
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                
                Spacer()
                
                // Generate & Share Button
                Button(action: {
                    generateTemplate()
                }) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Label(isGenerating ? "Generating..." : "Download \(format.displayName) Template",
                              systemImage: "arrow.down.doc.fill")
                            .font(.title3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isGenerating ? Color.gray : format.color)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isGenerating)
            }
            .padding()
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Template Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(items: [createTemplateFile()])
        }
        .onAppear {
            // Pre-generate template for faster sharing
            if templateData.isEmpty {
                generateTemplate()
            }
        }
    }
    
    @ViewBuilder
    private var formatSpecificNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: format == .foreFlight ? "star.fill" : "info.circle")
                    .foregroundColor(format == .foreFlight ? .yellow : format.color)
                
                Text(format == .foreFlight ? "ForeFlight Gold Standard" : "LogTen Pro Format")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            switch format {
            case .foreFlight:
                VStack(alignment: .leading, spacing: 4) {
                    Text("• All 63 ForeFlight fields included")
                    Text("• Uses H:MM time format (2:30 hours)")
                    Text("• Date format: MM/DD/YYYY (01/15/2024)")
                    Text("• Compatible with ForeFlight import/export")
                    Text("• PropilotApp's native format")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
            case .logTenPro:
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Simplified field set for LogTen Pro")
                    Text("• Uses H:MM time format (2:30 hours)")
                    Text("• Date format: YYYY-MM-DD (2024-01-15)")
                    Text("• Professional pilot logbook standard")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(format == .foreFlight ? Color.yellow.opacity(0.1) : format.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(format == .foreFlight ? Color.yellow.opacity(0.3) : format.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private func generateTemplate() {
        isGenerating = true
        
        // Use the fixed UnifiedLogbookManager to generate template
        templateData = manager.generateTemplate(for: format)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isGenerating = false
            if !templateData.isEmpty {
                showingShareSheet = true
            }
        }
    }
    
    private func createTemplateFile() -> URL {
        let fileName = "PropilotApp_\(format.displayName)_Template_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try templateData.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create template file: \(error)")
        }
        
        return tempURL
    }
}

struct TemplateFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(LogbookTheme.accentGreen)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(LogbookTheme.accentBlue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview
struct TemplateGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateGeneratorView(format: .foreFlight)
    }
}

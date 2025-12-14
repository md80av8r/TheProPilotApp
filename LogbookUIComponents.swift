// LogbookUIComponents.swift
// Complete UI components for SimpleElectronicLogbookView - Updated to remove duplicates
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Summary Card
struct LogbookSummaryCard: View {
    let tripCount: Int
    let legCount: Int
    let totalMinutes: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("Current Data")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                SummaryItem(value: "\(tripCount)", label: "Trips")
                SummaryItem(value: "\(legCount)", label: "Legs")
                SummaryItem(value: formatMinutes(totalMinutes), label: "Total Time")
            }
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

struct SummaryItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Action Section
struct LogbookActionSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
}

// MARK: - Button Styles
struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(LogbookTheme.accentBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LogbookTheme.accentBlue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Status Message View
struct LogbookStatusMessageView: View {
    let message: String
    let isProcessing: Bool
    
    var body: some View {
        HStack {
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(isProcessing ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Document Picker (Fixed - no dependencies)
struct LogbookDocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                UTType.commaSeparatedText,
                UTType.text,
                UTType.plainText
            ]
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: LogbookDocumentPicker
        
        init(_ parent: LogbookDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onFileSelected(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled - no action needed
        }
    }
}

// MARK: - Help Row Component
struct LogbookHelpRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(LogbookTheme.accentBlue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI
import MessageUI

struct EmailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    var ccRecipients: [String] = [] // Add this
    let subject: String
    let body: String
    let attachment: URL?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setCcRecipients(ccRecipients) // Add this
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        
        if let attachment = attachment {
            do {
                let data = try Data(contentsOf: attachment)
                let filename = attachment.lastPathComponent
                let mimeType = attachment.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
                composer.addAttachmentData(data, mimeType: mimeType, fileName: filename)
                print("Email attachment added: \(filename)")
            } catch {
                print("Error attaching file: \(error)")
            }
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposerView
        
        init(_ parent: EmailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                print("Mail composer error: \(error)")
            }
            
            switch result {
            case .sent:
                print("Email sent successfully")
            case .saved:
                print("Email saved as draft")
            case .cancelled:
                print("Email cancelled")
            case .failed:
                print("Email failed to send")
            @unknown default:
                print("Unknown mail result")
            }
            
            parent.isPresented = false
        }
    }
}

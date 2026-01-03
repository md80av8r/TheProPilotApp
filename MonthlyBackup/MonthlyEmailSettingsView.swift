//
//  MonthlyEmailSettingsView.swift
//  TheProPilotApp
//
//  Settings view for monthly email summary configuration
//

import SwiftUI

struct MonthlyEmailSettingsView: View {
    @ObservedObject var backupManager = BackupPromptManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isEnabled: Bool = false
    @State private var backupIntervalDays: Int = 7
    @State private var showingTestEmail = false

    var body: some View {
        Form {
            // Monthly Email Section
            Section {
                Toggle("Enable Monthly Summaries", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        backupManager.monthlyEmailEnabled = newValue
                    }

                if isEnabled {
                    TextField("Your Email Address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onChange(of: email) { _, newValue in
                            backupManager.userEmail = newValue
                        }

                    Button("Send Test Email") {
                        showingTestEmail = true
                    }
                    .disabled(email.isEmpty || !isValidEmail(email))
                }
            } header: {
                Text("Monthly Flight Summary")
            } footer: {
                Text("Receive a monthly email summary of your flight hours, including an Excel export of your logbook data. Emails are sent during the first few days of each month.")
            }

            // Backup Reminder Section
            Section {
                Picker("Remind Every", selection: $backupIntervalDays) {
                    Text("3 Days").tag(3)
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                }
                .onChange(of: backupIntervalDays) { _, newValue in
                    backupManager.backupPromptIntervalDays = newValue
                }

                HStack {
                    Text("Last Backup")
                    Spacer()
                    Text(backupManager.backupStatusText)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
            } header: {
                Text("Backup Reminders")
            } footer: {
                Text("You'll be prompted to backup your data if you haven't backed up within the selected interval.")
            }

            // Preview Section
            Section {
                NavigationLink {
                    MonthlyEmailPreviewView()
                } label: {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Preview Email Format")
                    }
                }
            } header: {
                Text("Preview")
            }

            // About Section
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(LogbookTheme.accentBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email Contents")
                            .font(.subheadline.bold())
                        Text("Total Time, PIC Time, Total Flights, Date of Last Flight, and Night Operations summary. Includes an Excel file attachment with detailed leg data.")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
            }
        }
        .navigationTitle("Monthly Summary")
        .onAppear {
            email = backupManager.userEmail
            isEnabled = backupManager.monthlyEmailEnabled
            backupIntervalDays = backupManager.backupPromptIntervalDays
        }
        .sheet(isPresented: $showingTestEmail) {
            TestEmailView(email: email)
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Preview View

struct MonthlyEmailPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Email Preview")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Subject: ProPilot Monthly Summary - December 2024")
                    .font(.subheadline)
                    .foregroundColor(LogbookTheme.accentBlue)

                Divider()

                Text(sampleEmailBody)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .background(LogbookTheme.cardBackground)
                    .cornerRadius(12)

                Text("Attachment: ProPilot_Logbook_December_2024.csv")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(8)
            }
            .padding()
        }
        .background(LogbookTheme.navy.ignoresSafeArea())
        .navigationTitle("Email Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sampleEmailBody: String {
        """
        ProPilot Monthly Flight Summary
        December 2024

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        FLIGHT STATISTICS

        Total Time:          45:30 (45.5 hours)
        Total PIC Time:      38:15 (38.3 hours)
        Total Flights:       24
        Trips Completed:     8
        Date of Last Flight: Dec 28, 2024

        NIGHT OPERATIONS

        Night Takeoffs:      6
        Night Landings:      8

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        This summary was automatically generated
        by ProPilot.

        View your complete logbook in the app or
        download the attached Excel file for
        detailed records.

        Fly safe!

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Generated by ProPilot
        The Professional Pilot App
        """
    }
}

// MARK: - Test Email View

struct TestEmailView: View {
    let email: String
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var showingMailComposer = false

    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LogbookTheme.accentBlue)

                    Text("Send Test Email")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("A sample monthly summary will be sent to:")
                        .foregroundColor(LogbookTheme.textSecondary)

                    Text(email)
                        .font(.headline)
                        .foregroundColor(LogbookTheme.accentBlue)

                    Spacer()

                    Button(action: {
                        showingMailComposer = true
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Test")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LogbookTheme.accentBlue)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            TestMailComposerView(email: email) {
                dismiss()
            }
        }
    }
}

// MARK: - Test Mail Composer

import MessageUI

struct TestMailComposerView: UIViewControllerRepresentable {
    let email: String
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([email])
        composer.setSubject("ProPilot Monthly Summary - Test Email")

        let body = """
        This is a test email from ProPilot.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        If you received this email, your monthly summary
        settings are configured correctly!

        You will receive your actual monthly summary during
        the first few days of each month.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Fly safe!

        - ProPilot
        """

        composer.setMessageBody(body, isHTML: false)

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: TestMailComposerView

        init(_ parent: TestMailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.parent.onComplete()
            }
        }
    }
}

// MARK: - Settings Row for Integration

struct MonthlyEmailSettingsRow: View {
    @ObservedObject var backupManager = BackupPromptManager.shared

    var body: some View {
        NavigationLink {
            MonthlyEmailSettingsView()
        } label: {
            HStack {
                Image(systemName: "envelope.badge.fill")
                    .foregroundColor(LogbookTheme.accentBlue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Summary")
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(LogbookTheme.textSecondary)
                }
            }
        }
    }

    private var statusText: String {
        if backupManager.monthlyEmailEnabled {
            if backupManager.userEmail.isEmpty {
                return "Enabled - No email set"
            } else {
                return "Enabled"
            }
        } else {
            return "Disabled"
        }
    }
}

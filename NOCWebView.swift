import SwiftUI
import WebKit

/// Simple SwiftUI wrapper for WKWebView
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op; URL changes would recreate the view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // handle finished loading if needed
        }
    }
}

// MARK: - Legacy Simple Web Portal View (DEPRECATED - Use NOCWebPortalView.swift instead)
// This was replaced by a full-featured authenticated version
/*
/// View for displaying the NOC web portal
struct NOCWebPortalView_Legacy: View {
    @ObservedObject var settings: NOCSettingsStore
    @State private var showLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                if let url = URL(string: settings.webPortalURL) {
                    WebView(url: url)
                        .ignoresSafeArea()
                        .onAppear { showLoading = true }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            showLoading = false
                        }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "globe.badge.chevron.backward")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Invalid Portal URL")
                            .font(.headline)
                        
                        Text("Please configure the NOC web portal URL in settings")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Open Settings") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if showLoading {
                    ProgressView("Loading NOC Portal…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("NOC Web Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
*/

/// View for displaying the raw roster calendar URL (for debugging)
struct NOCCalendarWebView: View {
    @ObservedObject var settings: NOCSettingsStore
    @State private var showLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                if let url = URL(string: settings.rosterURL) {
                    WebView(url: url)
                        .onAppear { showLoading = true }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            showLoading = false
                        }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Invalid URL")
                            .font(.headline)
                        Text(settings.rosterURL)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                if showLoading {
                    ProgressView("Loading…")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .navigationTitle("Roster Calendar Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NOCWebView_Previews: PreviewProvider {
    static var previews: some View {
        let store = NOCSettingsStore()
        NOCWebPortalView(settings: store)
    }
}

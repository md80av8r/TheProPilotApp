//  NOCWebPortalView.swift
//  TheProPilotApp
//
//  Authenticated web view for accessing NOC web portal
//

import SwiftUI
import WebKit

// MARK: - NOC Web Portal View
struct NOCWebPortalView: View {
    @ObservedObject var settings: NOCSettingsStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = NOCWebCoordinator()
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                }
                
                // WebView
                NOCWebView(
                    url: settings.webPortalURL,
                    username: settings.webUsername.isEmpty ? settings.username : settings.webUsername,
                    password: settings.webPassword.isEmpty ? settings.password : settings.webPassword,
                    coordinator: coordinator
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation Controls
                navigationControls
            }
            .navigationTitle("NOC Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            coordinator.reload()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                        
                        Button {
                            if let url = URL(string: settings.webPortalURL) {
                                coordinator.load(url: url)
                            }
                        } label: {
                            Label("Go to Home", systemImage: "house")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            coordinator.clearCookies()
                        } label: {
                            Label("Clear Cookies", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onReceive(coordinator.$isLoading) { loading in
                isLoading = loading
            }
            .onReceive(coordinator.$canGoBack) { canGo in
                canGoBack = canGo
            }
            .onReceive(coordinator.$canGoForward) { canGo in
                canGoForward = canGo
            }
            .onReceive(coordinator.$currentURL) { url in
                currentURL = url
            }
            .onReceive(coordinator.$errorMessage) { error in
                if let error = error {
                    errorMessage = error
                    showingError = true
                }
            }
            .alert("Web Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: 20) {
            Button {
                coordinator.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .disabled(!canGoBack)
            
            Button {
                coordinator.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(!canGoForward)
            
            Spacer()
            
            // URL Display
            Text(displayURL)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button {
                coordinator.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(uiColor: .separator)),
            alignment: .top
        )
    }
    
    private var displayURL: String {
        guard let url = URL(string: currentURL) else { return currentURL }
        if let host = url.host {
            return host + (url.path.isEmpty ? "" : "/...")
        }
        return currentURL
    }
}

// MARK: - NOC Web Coordinator
class NOCWebCoordinator: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURL = ""
    @Published var errorMessage: String?
    
    weak var webView: WKWebView?
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        webView?.reload()
    }
    
    func load(url: URL) {
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    func clearCookies() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = Set([WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage])
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                DispatchQueue.main.async {
                    self.reload()
                }
            }
        }
    }
}

// MARK: - NOC WebView (UIViewRepresentable)
struct NOCWebView: UIViewRepresentable {
    let url: String
    let username: String
    let password: String
    @ObservedObject var coordinator: NOCWebCoordinator
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Allow inline media playback
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Store reference
        coordinator.webView = webView
        
        // Load initial URL
        if let url = URL(string: url) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            
            // Add basic auth if we have credentials
            if !username.isEmpty && !password.isEmpty {
                let loginString = "\(username):\(password)"
                if let loginData = loginString.data(using: .utf8) {
                    let base64LoginString = loginData.base64EncodedString()
                    request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                }
            }
            
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update if URL changes
        if let currentURL = webView.url?.absoluteString, currentURL != url {
            if let newURL = URL(string: url) {
                var request = URLRequest(url: newURL)
                
                // Add basic auth
                if !username.isEmpty && !password.isEmpty {
                    let loginString = "\(username):\(password)"
                    if let loginData = loginString.data(using: .utf8) {
                        let base64LoginString = loginData.base64EncodedString()
                        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                    }
                }
                
                webView.load(request)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: NOCWebView
        
        init(parent: NOCWebView) {
            self.parent = parent
        }
        
        // Handle authentication challenges
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            // Handle basic auth
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
                let credential = URLCredential(
                    user: parent.username,
                    password: parent.password,
                    persistence: .forSession
                )
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
        
        // Track loading state
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.coordinator.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.coordinator.isLoading = false
                self.parent.coordinator.canGoBack = webView.canGoBack
                self.parent.coordinator.canGoForward = webView.canGoForward
                self.parent.coordinator.currentURL = webView.url?.absoluteString ?? ""
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.coordinator.isLoading = false
                self.parent.coordinator.errorMessage = error.localizedDescription
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.coordinator.isLoading = false
                
                // Don't show cancelled errors (user navigation)
                if (error as NSError).code != NSURLErrorCancelled {
                    self.parent.coordinator.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview
struct NOCWebPortalView_Previews: PreviewProvider {
    static var previews: some View {
        NOCWebPortalView(settings: NOCSettingsStore())
    }
}

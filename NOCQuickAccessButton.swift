//  NOCQuickAccessButton.swift
//  TheProPilotApp
//
//  Quick access button for NOC web portal - can be added anywhere in the app
//

import SwiftUI

/// A reusable button that opens the NOC web portal
/// Can be placed in toolbars, sheets, or any view
struct NOCQuickAccessButton: View {
    @ObservedObject var settings: NOCSettingsStore
    @State private var showingWebPortal = false
    
    let style: ButtonStyle
    
    enum ButtonStyle {
        case toolbar    // Icon only for toolbar
        case card       // Full card for main views
        case compact    // Small inline button
        
        var icon: String {
            "globe"
        }
    }
    
    init(settings: NOCSettingsStore, style: ButtonStyle = .compact) {
        self.settings = settings
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .toolbar:
                toolbarButton
            case .card:
                cardButton
            case .compact:
                compactButton
            }
        }
        .sheet(isPresented: $showingWebPortal) {
            NOCWebPortalView(settings: settings)
        }
    }
    
    // MARK: - Toolbar Style
    private var toolbarButton: some View {
        Button {
            showingWebPortal = true
        } label: {
            Image(systemName: "globe")
        }
        .disabled(settings.webPortalURL.isEmpty)
    }
    
    // MARK: - Card Style
    private var cardButton: some View {
        Button {
            showingWebPortal = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LogbookTheme.accentBlue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOC Web Portal")
                        .font(.headline)
                        .foregroundColor(LogbookTheme.textPrimary)
                    
                    if settings.webPortalURL.isEmpty {
                        Text("Configure in Settings")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.errorRed)
                    } else if settings.webUsername.isEmpty && settings.username.isEmpty {
                        Text("Login Required")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.warningYellow)
                    } else {
                        Text("View Full Roster Online")
                            .font(.caption)
                            .foregroundColor(LogbookTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LogbookTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LogbookTheme.accentBlue.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(settings.webPortalURL.isEmpty)
    }
    
    // MARK: - Compact Style
    private var compactButton: some View {
        Button {
            showingWebPortal = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text("NOC Portal")
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LogbookTheme.accentBlue.opacity(0.2))
            .foregroundColor(LogbookTheme.accentBlue)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LogbookTheme.accentBlue.opacity(0.5), lineWidth: 1)
            )
        }
        .disabled(settings.webPortalURL.isEmpty)
    }
}

// MARK: - Preview
struct NOCQuickAccessButton_Previews: PreviewProvider {
    static var previews: some View {
        let settings = NOCSettingsStore()
        
        VStack(spacing: 20) {
            // Toolbar style
            HStack {
                Spacer()
                NOCQuickAccessButton(settings: settings, style: .toolbar)
                    .padding()
            }
            .background(Color.gray.opacity(0.2))
            
            // Card style
            NOCQuickAccessButton(settings: settings, style: .card)
                .padding()
            
            // Compact style
            NOCQuickAccessButton(settings: settings, style: .compact)
                .padding()
            
            Spacer()
        }
        .background(LogbookTheme.navy)
        .previewLayout(.sizeThatFits)
    }
}

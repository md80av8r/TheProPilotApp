//
//  SubscriptionService.swift
//  TheProPilotApp
//
//  Subscription management for Pro features
//  Recommended: Use RevenueCat for production (https://www.revenuecat.com)
//

import Foundation
import StoreKit

// MARK: - Subscription Tiers

enum SubscriptionTier {
    case free
    case pro
    case enterprise
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro Pilot"
        case .enterprise: return "Enterprise"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$4.99"
        case .enterprise: return "$9.99"
        }
    }
}

// MARK: - Pro Features

enum ProFeature {
    case jumpseatFinder
    case liveTracking
    case cloudSync
    case weatherRadar
    case unlimitedScans
    case crewSharing
    
    var displayName: String {
        switch self {
        case .jumpseatFinder: return "Jumpseat Finder"
        case .liveTracking: return "Live Flight Tracking"
        case .cloudSync: return "CloudKit Sync"
        case .weatherRadar: return "Weather Radar"
        case .unlimitedScans: return "Unlimited Document Scans"
        case .crewSharing: return "Crew Contact Sharing"
        }
    }
    
    var icon: String {
        switch self {
        case .jumpseatFinder: return "airplane.departure"
        case .liveTracking: return "location.fill"
        case .cloudSync: return "icloud.fill"
        case .weatherRadar: return "cloud.sun.rain.fill"
        case .unlimitedScans: return "doc.viewfinder"
        case .crewSharing: return "person.3.fill"
        }
    }
}

// MARK: - Subscription Service

class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    // For development: Toggle this to test Pro features without payment
    @Published var isDevelopmentMode: Bool = true
    
    // User's current subscription status
    @Published var currentTier: SubscriptionTier = .free
    @Published var isProMember: Bool = false
    
    private init() {
        // Load subscription status
        loadSubscriptionStatus()
    }
    
    // MARK: - Feature Access Checks
    
    /// Check if user has access to a Pro feature
    func hasAccess(to feature: ProFeature) -> Bool {
        // Development mode: Grant all features
        if isDevelopmentMode {
            return true
        }
        
        // Pro or Enterprise: Grant all features
        if currentTier == .pro || currentTier == .enterprise {
            return true
        }
        
        // Free tier: No Pro features
        return false
    }
    
    /// Check if jumpseat finder is accessible
    var canUseJumpseatFinder: Bool {
        return hasAccess(to: .jumpseatFinder)
    }
    
    // MARK: - Subscription Management
    
    func loadSubscriptionStatus() {
        // TODO: Implement actual subscription check
        // Recommended: Use RevenueCat SDK
        //
        // Example with RevenueCat:
        // Purchases.shared.getCustomerInfo { (customerInfo, error) in
        //     if customerInfo?.entitlements["pro"]?.isActive == true {
        //         self.currentTier = .pro
        //         self.isProMember = true
        //     }
        // }
        
        // For now, check UserDefaults (development only)
        let isProStored = UserDefaults.standard.bool(forKey: "isProMember")
        if isProStored {
            currentTier = .pro
            isProMember = true
        } else {
            currentTier = .free
            isProMember = false
        }
    }
    
    func upgradeToProForTesting() {
        currentTier = .pro
        isProMember = true
        UserDefaults.standard.set(true, forKey: "isProMember")
    }
    
    func resetToFreeForTesting() {
        currentTier = .free
        isProMember = false
        UserDefaults.standard.set(false, forKey: "isProMember")
    }
    
    // MARK: - Paywall Display
    
    func shouldShowPaywall(for feature: ProFeature) -> Bool {
        return !hasAccess(to: feature) && !isDevelopmentMode
    }
}

// MARK: - Paywall View

import SwiftUI

struct ProPaywallView: View {
    let feature: ProFeature
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            
                            Text("Upgrade to Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Unlock \(feature.displayName) and more")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                        
                        // Features List
                        VStack(spacing: 16) {
                            proFeatureRow(.jumpseatFinder)
                            proFeatureRow(.liveTracking)
                            proFeatureRow(.cloudSync)
                            proFeatureRow(.weatherRadar)
                            proFeatureRow(.unlimitedScans)
                            proFeatureRow(.crewSharing)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(16)
                        
                        // Pricing
                        VStack(spacing: 16) {
                            Text("Just $4.99/month")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Cancel anytime • 7-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Subscribe Button
                        Button(action: handleSubscribe) {
                            Text("Start Free Trial")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LogbookTheme.accentBlue)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // Restore Purchases
                        Button(action: handleRestore) {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Terms
                        Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func proFeatureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 24))
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 40)
            
            Text(feature.displayName)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(12)
    }
    
    private func handleSubscribe() {
        // TODO: Implement actual subscription flow
        // Recommended: Use RevenueCat
        //
        // Example:
        // Purchases.shared.getOfferings { (offerings, error) in
        //     if let package = offerings?.current?.availablePackages.first {
        //         Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
        //             if customerInfo?.entitlements["pro"]?.isActive == true {
        //                 // Success!
        //             }
        //         }
        //     }
        // }
        
        // For testing: Grant Pro access
        subscriptionService.upgradeToProForTesting()
        dismiss()
    }
    
    private func handleRestore() {
        // TODO: Implement restore purchases
        // Example:
        // Purchases.shared.restorePurchases { (customerInfo, error) in
        //     // Handle restoration
        // }
    }
}

// MARK: - Feature Gate Modifier

struct ProFeatureGate: ViewModifier {
    let feature: ProFeature
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showingPaywall = false
    
    func body(content: Content) -> some View {
        Group {
            if subscriptionService.hasAccess(to: feature) {
                content
            } else {
                Button(action: { showingPaywall = true }) {
                    ZStack {
                        content
                            .blur(radius: 5)
                            .disabled(true)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                            
                            Text("Pro Feature")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Upgrade to unlock")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(32)
                        .background(LogbookTheme.navyLight.opacity(0.95))
                        .cornerRadius(16)
                    }
                }
                .sheet(isPresented: $showingPaywall) {
                    ProPaywallView(feature: feature)
                }
            }
        }
    }
}

extension View {
    func requiresPro(_ feature: ProFeature) -> some View {
        modifier(ProFeatureGate(feature: feature))
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Check access before showing feature
 if SubscriptionService.shared.canUseJumpseatFinder {
     JumpseatFinderView()
 } else {
     ProPaywallView(feature: .jumpseatFinder)
 }
 
 // Example 2: Use .requiresPro() modifier
 NavigationLink(destination: JumpseatFinderView().requiresPro(.jumpseatFinder)) {
     Text("Jumpseat Finder")
 }
 
 // Example 3: Manual paywall check
 Button("Open Jumpseat Finder") {
     if SubscriptionService.shared.shouldShowPaywall(for: .jumpseatFinder) {
         showingPaywall = true
     } else {
         showJumpseatFinder = true
     }
 }
 
 // Example 4: Access debug view (only in DEBUG builds)
 #if DEBUG
 NavigationLink("Subscription Debug") {
     SubscriptionDebugView()  // Defined in SubscriptionDebugView.swift
 }
 #endif
 
 */


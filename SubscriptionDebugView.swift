//
//  SubscriptionDebugView.swift
//  USA Jet Calc
//
//  Debug tools for testing subscription and paywall
//

import SwiftUI

#if DEBUG
struct SubscriptionDebugView: View {
    @ObservedObject private var trialChecker = SubscriptionStatusChecker.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        List {
            // MARK: - Current Status
            Section("Current Status") {
                HStack {
                    Text("Trial Status")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                
                HStack {
                    Text("Trips Created")
                    Spacer()
                    Text("\(trialChecker.totalTripsCreated)/5")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Trips Remaining")
                    Spacer()
                    Text("\(trialChecker.tripsRemaining)")
                        .foregroundColor(trialChecker.tripsRemaining > 0 ? .green : .red)
                }
                
                HStack {
                    Text("Days Remaining")
                    Spacer()
                    Text("\(trialChecker.daysRemaining)")
                        .foregroundColor(trialChecker.daysRemaining > 0 ? .green : .red)
                }
                
                HStack {
                    Text("Can Create Trip?")
                    Spacer()
                    Image(systemName: trialChecker.canCreateTrip ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(trialChecker.canCreateTrip ? .green : .red)
                }
                
                HStack {
                    Text("Should Show Paywall?")
                    Spacer()
                    Image(systemName: trialChecker.shouldShowPaywall ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(trialChecker.shouldShowPaywall ? .orange : .green)
                }
                
                HStack {
                    Text("Install Date")
                    Spacer()
                    Text(trialChecker.installDate, style: .date)
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Subscription Status
            Section("Subscription") {
                HStack {
                    Text("Is Subscribed?")
                    Spacer()
                    Image(systemName: subscriptionManager.isSubscribed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(subscriptionManager.isSubscribed ? .green : .gray)
                }
                
                HStack {
                    Text("Products Loaded")
                    Spacer()
                    Text("\(subscriptionManager.availableProducts.count)")
                        .foregroundColor(.blue)
                }
                
                if !subscriptionManager.availableProducts.isEmpty {
                    ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                        HStack {
                            Text(product.displayName)
                                .font(.caption)
                            Spacer()
                            Text(product.displayPrice)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // MARK: - Test Actions
            Section("Test Actions") {
                Button("Show Paywall") {
                    showPaywall = true
                }
                
                Button("Refresh Subscription Status") {
                    Task {
                        await subscriptionManager.checkSubscriptionStatus()
                        trialChecker.updateTrialStatus()
                    }
                }
                
                Button("Reload Products") {
                    Task {
                        await subscriptionManager.loadProducts()
                    }
                }
            }
            
            // MARK: - Trial Manipulation
            Section("Modify Trial (Testing Only)") {
                Button("Reset Trial (Fresh Start)") {
                    trialChecker.resetTrial()
                }
                .foregroundColor(.blue)
                
                Button("Set 4 Trips (1 Remaining)") {
                    trialChecker.setTripCount(4)
                }
                .foregroundColor(.orange)
                
                Button("Exhaust Trial (5 Trips)") {
                    trialChecker.exhaustTrial()
                }
                .foregroundColor(.red)
                
                Button("Increment Trip Count") {
                    trialChecker.incrementTripCount()
                }
                .foregroundColor(.purple)
            }
            
            // MARK: - Sandbox Tools
            Section("StoreKit Sandbox") {
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                
                Link("Manage Subscriptions (Settings)", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .foregroundColor(.blue)
                
                Text("Note: Clear Purchase History in Settings → StoreKit Testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Warnings
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Debug Mode Active")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    
                    Text("These tools are only available in DEBUG builds and will not appear in production.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Subscription Debug")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    private var statusText: String {
        switch trialChecker.trialStatus {
        case .active:
            return "Active"
        case .tripsExhausted:
            return "Trips Exhausted"
        case .timeExpired:
            return "Time Expired"
        case .subscribed:
            return "Subscribed"
        }
    }
    
    private var statusColor: Color {
        switch trialChecker.trialStatus {
        case .active:
            return .green
        case .tripsExhausted, .timeExpired:
            return .red
        case .subscribed:
            return .blue
        }
    }
}

#Preview {
    NavigationView {
        SubscriptionDebugView()
    }
}
#endif

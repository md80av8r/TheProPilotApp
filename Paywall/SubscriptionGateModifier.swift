//
//  SubscriptionGateModifier.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import SwiftUI

/// ViewModifier that shows paywall when trial limits are reached
struct SubscriptionGateModifier: ViewModifier {
    @StateObject private var trialChecker = SubscriptionStatusChecker.shared
    @State private var showingPaywall = false
    
    let action: GateAction
    
    enum GateAction {
        case createTrip
        case deleteTrip
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trialChecker.shouldShowPaywall) { _, shouldShow in
                if shouldShow {
                    showingPaywall = true
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
    }
}

extension View {
    /// Apply subscription gate to a button action
    func requiresSubscription(for action: SubscriptionGateModifier.GateAction) -> some View {
        self.modifier(SubscriptionGateModifier(action: action))
    }
}

/// Banner that shows trial status in the app
struct TrialStatusBanner: View {
    @StateObject private var trialChecker = SubscriptionStatusChecker.shared
    @State private var showingPaywall = false
    
    var body: some View {
        if trialChecker.trialStatus == .active {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(trialChecker.trialStatusMessage)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Tap to upgrade")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Upgrade") {
                    showingPaywall = true
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(6)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

/// Overlay that blocks interaction when trial expires
struct TrialExpiredOverlay: View {
    @StateObject private var trialChecker = SubscriptionStatusChecker.shared
    @State private var showingPaywall = false
    
    var body: some View {
        if trialChecker.shouldShowPaywall {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text(trialChecker.trialStatusMessage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(trialChecker.trialInfoDetail)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingPaywall = true
                    }) {
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(radius: 20)
                )
                .padding(40)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}
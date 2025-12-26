//
//  JumpseatFinderView+Subscription.swift
//  TheProPilotApp
//
//  Example: How to gate Jumpseat Finder behind Pro subscription
//

import SwiftUI

// MARK: - Protected Jumpseat Finder (with subscription check)

struct ProtectedJumpseatFinderView: View {
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showingPaywall = false
    
    var body: some View {
        Group {
            if subscriptionService.canUseJumpseatFinder {
                // User has Pro access - show full feature
                JumpseatFinderView()
            } else {
                // User is on Free tier - show paywall
                jumpseatLockedView
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(feature: .jumpseatFinder)
        }
    }
    
    private var jumpseatLockedView: some View {
        ZStack {
            LogbookTheme.navy.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Feature Preview
                VStack(spacing: 16) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 80))
                        .foregroundColor(LogbookTheme.accentBlue)
                    
                    Text("Jumpseat Finder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Find commute flights between any two airports with real-time schedules, gate info, and load predictions.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Feature Benefits
                VStack(spacing: 16) {
                    benefitRow(icon: "clock.fill", title: "Real-Time Schedules", description: "Live flight times from major airlines")
                    benefitRow(icon: "mappin.circle.fill", title: "Gate & Terminal Info", description: "Know exactly where to go")
                    benefitRow(icon: "chart.bar.fill", title: "Load Predictions", description: "Estimate seat availability")
                    benefitRow(icon: "bookmark.fill", title: "Saved Routes", description: "Quick access to frequent commutes")
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Lock Icon
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    
                    Text("Pro Feature")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Upgrade to Pro Pilot for $4.99/month")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(24)
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(16)
                
                // Upgrade Button
                Button(action: { showingPaywall = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LogbookTheme.accentBlue)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationTitle("Jumpseat Finder")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(LogbookTheme.accentBlue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - How to Update ContentView

/*
 
 In ContentView.swift, replace the jumpseat case:
 
 // OLD (no subscription check):
 case "jumpseat": JumpseatFinderView()
 
 // NEW (with subscription check):
 case "jumpseat": ProtectedJumpseatFinderView()
 
 */

// MARK: - Alternative: Inline Subscription Check

extension ContentView {
    // Add this computed property if you want inline checking
    @ViewBuilder
    var jumpseatTabWithProtection: some View {
        if SubscriptionService.shared.canUseJumpseatFinder {
            JumpseatFinderView()
        } else {
            ProtectedJumpseatFinderView()
        }
    }
}

// MARK: - Preview (Testing)

struct ProtectedJumpseatFinderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with Pro access
            ProtectedJumpseatFinderView()
                .onAppear {
                    SubscriptionService.shared.upgradeToProForTesting()
                }
                .previewDisplayName("Pro Member")
            
            // Preview without Pro access
            ProtectedJumpseatFinderView()
                .onAppear {
                    SubscriptionService.shared.resetToFreeForTesting()
                }
                .previewDisplayName("Free Member")
        }
    }
}

// MARK: - Revenue Calculation Reference

/*
 
 BUSINESS MODEL (from your document):
 
 Free Tier:
 - Airport database access
 - Manual flight logging
 - Basic logbook features
 - Cost: $0
 
 Pro Tier ($4.99/month):
 - ✅ Jumpseat Finder (real-time schedules)
 - ✅ Flight tracking
 - ✅ CloudKit sync
 - ✅ Weather radar
 - ✅ Unlimited scans
 - Cost to you: ~$0.31/user/month (API costs)
 
 Revenue Math:
 - API Cost: $50/month (10,000 requests)
 - Supports: 160 active users (60 searches/month each)
 - Revenue: $4.99 × 160 = $798/month
 - Apple's Cut (15% after year 1): ~$120/month
 - Net Profit: ~$628/month
 
 Breakeven: 11 paid subscribers
 
 */

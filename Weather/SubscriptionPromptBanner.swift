//
//  SubscriptionPromptBanner.swift
//  TheProPilotApp
//
//  Created on 12/26/25.
//

import SwiftUI

/// Banner that appears when user has exceeded trial limits
struct SubscriptionPromptBanner: View {
    @ObservedObject var trialChecker = SubscriptionStatusChecker.shared
    @State private var showPaywall = false
    @State private var isTemporarilyDismissed = false
    
    var body: some View {
        if trialChecker.shouldShowPaywall && !isTemporarilyDismissed {
            VStack(spacing: 0) {
                bannerContent
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .interactiveDismissDisabled(trialChecker.shouldShowPaywall) // ✅ Can't swipe away if trial exhausted
            }
            .onAppear {
                // ✅ FIXED: Reset dismissal when banner reappears (e.g., after navigation)
                isTemporarilyDismissed = false
            }
        }
    }
    
    private var bannerContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: bannerIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(bannerIconColor)
                
                // Message
                VStack(alignment: .leading, spacing: 4) {
                    Text(bannerTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(bannerMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // ✅ FIXED: Only show dismiss if they still have trips/days left (warning mode)
                if trialChecker.tripsRemaining > 0 || trialChecker.daysRemaining > 0 {
                    Button(action: {
                        withAnimation {
                            isTemporarilyDismissed = true
                        }
                        // ✅ Auto un-dismiss after 1 hour
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) {
                            isTemporarilyDismissed = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Subscribe button
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("Subscribe to Pro")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundColor(bannerBackgroundColor)
                    .cornerRadius(10)
                }
                
                // Learn more button
                Button(action: {
                    showPaywall = true
                }) {
                    Text("Learn More")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [bannerBackgroundColor, bannerBackgroundColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Dynamic Content Based on Trial Status
    
    private var bannerIcon: String {
        switch trialChecker.trialStatus {
        case .tripsExhausted:
            return "airplane.circle.fill"
        case .timeExpired:
            return "clock.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var bannerIconColor: Color {
        switch trialChecker.trialStatus {
        case .tripsExhausted:
            return .yellow
        case .timeExpired:
            return .orange
        default:
            return .red
        }
    }
    
    private var bannerTitle: String {
        switch trialChecker.trialStatus {
        case .tripsExhausted:
            return "Free Trial Limit Reached"
        case .timeExpired:
            return "Free Trial Expired"
        default:
            return "Upgrade Required"
        }
    }
    
    private var bannerMessage: String {
        switch trialChecker.trialStatus {
        case .tripsExhausted:
            return "You've created 5 trips. Subscribe to ProPilot Pro for unlimited flight logging."
        case .timeExpired:
            return "Your 7-day trial has ended. Subscribe to continue logging flights."
        default:
            return "Subscribe to unlock all features and unlimited trips."
        }
    }
    
    private var bannerBackgroundColor: Color {
        switch trialChecker.trialStatus {
        case .tripsExhausted:
            return Color.blue
        case .timeExpired:
            return Color.purple
        default:
            return Color.orange
        }
    }
}

/// Compact version for use in navigation bars or small spaces
struct CompactSubscriptionPromptBanner: View {
    @ObservedObject var trialChecker = SubscriptionStatusChecker.shared
    @State private var showPaywall = false
    
    var body: some View {
        if trialChecker.shouldShowPaywall {
            Button(action: {
                showPaywall = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    
                    Text("Upgrade to Pro")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

/// View modifier to add subscription banner to any view
struct SubscriptionBannerModifier: ViewModifier {
    @ObservedObject var trialChecker = SubscriptionStatusChecker.shared
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Banner at top
            SubscriptionPromptBanner()
            
            // Original content
            content
        }
    }
}

extension View {
    /// Adds a subscription prompt banner to the top of the view when trial is exceeded
    func withSubscriptionBanner() -> some View {
        modifier(SubscriptionBannerModifier())
    }
}

// MARK: - Trial Warning Banner (Shows before limit is reached)
struct TrialWarningBanner: View {
    @ObservedObject var trialChecker = SubscriptionStatusChecker.shared
    @State private var showPaywall = false
    @State private var isDismissed = false
    
    var body: some View {
        if shouldShowWarning && !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trial Ending Soon")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(warningMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: {
                    showPaywall = true
                }) {
                    Text("Upgrade")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Button(action: {
                    withAnimation {
                        isDismissed = true
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.3))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    private var shouldShowWarning: Bool {
        guard trialChecker.trialStatus == .active else { return false }
        
        // Show warning if 1 trip or 1 day remaining
        return trialChecker.tripsRemaining <= 1 || trialChecker.daysRemaining <= 1
    }
    
    private var warningMessage: String {
        if trialChecker.tripsRemaining <= 1 {
            return "\(trialChecker.tripsRemaining) trip remaining"
        } else {
            return "\(trialChecker.daysRemaining) day\(trialChecker.daysRemaining == 1 ? "" : "s") remaining"
        }
    }
}

// MARK: - Preview
#Preview("Full Banner") {
    VStack {
        SubscriptionPromptBanner()
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Compact Banner") {
    VStack {
        CompactSubscriptionPromptBanner()
        Spacer()
    }
}

#Preview("Warning Banner") {
    VStack {
        TrialWarningBanner()
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

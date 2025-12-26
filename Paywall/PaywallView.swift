//
//  PaywallView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var trialChecker = SubscriptionStatusChecker.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerSection
                        
                        // Trial Status
                        trialStatusCard
                        
                        // Subscription Options
                        subscriptionOptionsSection
                        
                        // Features List
                        featuresSection
                        
                        // Purchase Button
                        purchaseButton
                        
                        // Restore & Terms
                        footerSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ✅ FIXED: Only show cancel if they still have trial time/trips left
                if trialChecker.canCreateTrip {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(subscriptionManager.purchaseError ?? "An error occurred")
            }
            .onAppear {
                // ✅ FIXED: Auto-select the annual plan (best value)
                if selectedProduct == nil, !subscriptionManager.availableProducts.isEmpty {
                    selectedProduct = subscriptionManager.annualProduct ?? subscriptionManager.availableProducts.first
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("ProPilot Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Professional Flight Logging")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Trial Status Card
    private var trialStatusCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: trialChecker.trialStatus == .active ? "clock.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(trialChecker.trialStatus == .active ? .blue : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trialChecker.trialStatusMessage)
                        .font(.headline)
                    
                    Text(trialChecker.trialInfoDetail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Subscription Options
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 15) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else {
                ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                    SubscriptionOptionCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pro Features")
                .font(.title3)
                .fontWeight(.semibold)
            
            FeatureRow(icon: "infinity", text: "Unlimited flight logging")
            FeatureRow(icon: "icloud.fill", text: "CloudKit sync across devices")
            FeatureRow(icon: "applewatch", text: "Apple Watch companion app")
            FeatureRow(icon: "doc.fill", text: "PDF logbook export")
            FeatureRow(icon: "calendar.badge.clock", text: "FAR 121 compliance tracking")
            FeatureRow(icon: "airplane.departure", text: "GPS auto-time logging")
            FeatureRow(icon: "person.3.fill", text: "Crew contact management")
            FeatureRow(icon: "dollarsign.circle.fill", text: "Per diem tracking")
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button(action: {
            Task {
                await handlePurchase()
            }
        }) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                selectedProduct != nil ? Color.blue : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(selectedProduct == nil || isPurchasing)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 10) {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            
            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://thepropilotapp.com/terms")!)
                Text("•")
                    .foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://thepropilotapp.com/privacy")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.bottom)
    }
    
    // MARK: - Handle Purchase
    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await subscriptionManager.purchase(product)
            
            // ✅ FIXED: Refresh trial status immediately after successful purchase
            await MainActor.run {
                trialChecker.updateTrialStatus()
            }
            
            // Success - close paywall
            if subscriptionManager.isSubscribed {
                dismiss()
            }
        } catch {
            showingError = true
        }
    }
}

// MARK: - Subscription Option Card
struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    
    private var isAnnual: Bool {
        product.subscription?.subscriptionPeriod.unit == .year
    }
    
    private var savingsText: String? {
        if isAnnual {
            return "Save $40 per year"
        }
        return nil
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName)
                        .font(.headline)
                    
                    if let savings = savingsText {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                
                if isAnnual {
                    Text("$6.67/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
}
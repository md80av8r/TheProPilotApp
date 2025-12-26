//
//  SubscriptionManager.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import Foundation
import StoreKit

/// Manages subscription purchases and status using StoreKit 2
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var availableProducts: [Product] = []
    @Published var purchaseError: String?
    @Published var isLoading = false
    
    // MARK: - Product IDs (must match App Store Connect)
    private let monthlyProductID = "TheProPilotApp"
    private let annualProductID = "TheProPilotAppAnnual"
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Subscription Status
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expirationDate: Date?)
        case inFreeTrial
        case expired
    }
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Check if User is Subscribed
    var isSubscribed: Bool {
        switch subscriptionStatus {
        case .subscribed:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Load Products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: [monthlyProductID, annualProductID])
            
            // Sort by price (annual first, then monthly)
            self.availableProducts = products.sorted { $0.price > $1.price }
            
            print("✅ Loaded \(products.count) subscription products")
            for product in products {
                print("  - \(product.displayName): \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error.localizedDescription)")
            purchaseError = "Failed to load subscription options. Please try again."
        }
    }
    
    // MARK: - Purchase Subscription
    func purchase(_ product: Product) async throws {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Update subscription status
                await checkSubscriptionStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                print("✅ Purchase successful: \(product.displayName)")
                
            case .userCancelled:
                print("⚠️ User cancelled purchase")
                
            case .pending:
                print("⏳ Purchase pending approval")
                purchaseError = "Purchase is pending approval"
                
            @unknown default:
                print("❌ Unknown purchase result")
                purchaseError = "An unknown error occurred"
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ Purchases restored")
        } catch {
            print("❌ Restore failed: \(error.localizedDescription)")
            purchaseError = "Failed to restore purchases. Please try again."
        }
    }
    
    // MARK: - Check Current Subscription Status
    func checkSubscriptionStatus() async {
        var highestTransaction: Transaction?
        var highestProduct: Product?
        
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Find the product for this transaction
                if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
                    if highestTransaction == nil || transaction.purchaseDate > (highestTransaction?.purchaseDate ?? Date.distantPast) {
                        highestTransaction = transaction
                        highestProduct = product
                    }
                }
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }
        
        // Update status based on highest transaction
        if let transaction = highestTransaction, let product = highestProduct {
            // User has an active subscription
            let expirationDate = transaction.expirationDate
            subscriptionStatus = .subscribed(expirationDate: expirationDate)
            
            print("✅ Active subscription: \(product.displayName)")
            if let expiration = expirationDate {
                print("   Expires: \(expiration)")
            }
            
            // ✅ FIXED: Notify trial checker that subscription is active
            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        } else {
            // No active subscription
            subscriptionStatus = .notSubscribed
            print("⚠️ No active subscription")
            
            // ✅ FIXED: Notify trial checker that subscription ended
            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
        }
    }
    
    // MARK: - Listen for Transaction Updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update subscription status
                    await self.checkSubscriptionStatus()
                    
                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verify Transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Get Product by ID
    func product(for id: String) -> Product? {
        return availableProducts.first { $0.id == id }
    }
    
    var monthlyProduct: Product? {
        return product(for: monthlyProductID)
    }
    
    var annualProduct: Product? {
        return product(for: annualProductID)
    }
}

// MARK: - Subscription Error
enum SubscriptionError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

//
//  SubscriptionStatusChecker.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//


import Foundation
import SwiftUI

/// Tracks trial limits: 5 trips ever created OR 7 days since install
@MainActor
class SubscriptionStatusChecker: ObservableObject {
    static let shared = SubscriptionStatusChecker()
    
    // MARK: - Published Properties
    @Published var trialStatus: TrialStatus = .active
    @Published var totalTripsCreated: Int = 0
    @Published var daysRemaining: Int = 7
    @Published var tripsRemaining: Int = 5
    
    // MARK: - UserDefaults Keys
    private let installDateKey = "app_install_date"
    private let totalTripsCreatedKey = "total_trips_ever_created"
    
    // MARK: - Trial Limits
    private let maxFreeTrips = 5
    private let trialDays = 7
    
    // MARK: - Trial Status
    enum TrialStatus {
        case active           // Still in trial
        case tripsExhausted   // Hit 5 trips limit
        case timeExpired      // Hit 7 days limit
        case subscribed       // Has active subscription
    }
    
    private init() {
        setupInstallDate()
        loadTotalTripsCreated()
        updateTrialStatus()
        
        // ✅ FIXED: Listen for subscription changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionStatusChanged),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func subscriptionStatusChanged() {
        print("📢 Subscription status changed - updating trial status")
        updateTrialStatus()
    }
    
    // MARK: - Install Date Setup
    private func setupInstallDate() {
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            // First launch - save install date
            UserDefaults.standard.set(Date(), forKey: installDateKey)
            print("📅 First launch - install date saved: \(Date())")
        }
    }
    
    var installDate: Date {
        return UserDefaults.standard.object(forKey: installDateKey) as? Date ?? Date()
    }
    
    // MARK: - Trip Counting
    private func loadTotalTripsCreated() {
        totalTripsCreated = UserDefaults.standard.integer(forKey: totalTripsCreatedKey)
        print("📊 Total trips ever created: \(totalTripsCreated)")
    }
    
    /// Call this when user creates a new trip
    func incrementTripCount() {
        totalTripsCreated += 1
        UserDefaults.standard.set(totalTripsCreated, forKey: totalTripsCreatedKey)
        updateTrialStatus()
        print("➕ Trip count incremented: \(totalTripsCreated)/\(maxFreeTrips)")
    }
    
    // MARK: - Trial Status Check
    func updateTrialStatus() {
        // Check if subscribed first
        if SubscriptionManager.shared.isSubscribed {
            trialStatus = .subscribed
            daysRemaining = 0
            tripsRemaining = 0
            return
        }
        
        // Calculate days since install
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        daysRemaining = max(0, trialDays - daysSinceInstall)
        
        // Calculate trips remaining
        tripsRemaining = max(0, maxFreeTrips - totalTripsCreated)
        
        // Determine trial status
        if totalTripsCreated >= maxFreeTrips {
            trialStatus = .tripsExhausted
            print("🚫 Trial exhausted: Hit trip limit (\(totalTripsCreated)/\(maxFreeTrips))")
        } else if daysSinceInstall >= trialDays {
            trialStatus = .timeExpired
            print("🚫 Trial expired: Hit time limit (\(daysSinceInstall)/\(trialDays) days)")
        } else {
            trialStatus = .active
            print("✅ Trial active: \(tripsRemaining) trips, \(daysRemaining) days remaining")
        }
    }
    
    // MARK: - Permission Checks
    
    /// Can user create a new trip?
    var canCreateTrip: Bool {
        return trialStatus == .active || trialStatus == .subscribed
    }
    
    /// Can user delete a trip?
    var canDeleteTrip: Bool {
        return trialStatus == .active || trialStatus == .subscribed
    }
    
    /// Should show paywall?
    var shouldShowPaywall: Bool {
        return trialStatus == .tripsExhausted || trialStatus == .timeExpired
    }
    
    // MARK: - Trial Info Strings
    
    var trialStatusMessage: String {
        switch trialStatus {
        case .active:
            if tripsRemaining < trialDays - Calendar.current.dateComponents([.day], from: installDate, to: Date()).day! {
                // Trips will expire first
                return "\(tripsRemaining) free trips remaining"
            } else {
                // Days will expire first
                return "\(daysRemaining) days of trial remaining"
            }
            
        case .tripsExhausted:
            return "Free trial ended - 5 trip limit reached"
            
        case .timeExpired:
            return "Free trial ended - 7 day period expired"
            
        case .subscribed:
            return "ProPilot Pro Active"
        }
    }
    
    var trialInfoDetail: String {
        switch trialStatus {
        case .active:
            return "Trial includes \(tripsRemaining) more trips or \(daysRemaining) more days - whichever comes first"
            
        case .tripsExhausted:
            return "You've created \(maxFreeTrips) trips. Subscribe to continue logging flights."
            
        case .timeExpired:
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
            return "Your \(trialDays)-day trial ended \(daysSinceInstall - trialDays) days ago. Subscribe to continue."
            
        case .subscribed:
            if case .subscribed(let expirationDate) = SubscriptionManager.shared.subscriptionStatus,
               let expiration = expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Renews \(formatter.string(from: expiration))"
            }
            return "Unlimited trips and full access to all features"
        }
    }
    
    // MARK: - Reset (For Testing Only)
    #if DEBUG
    func resetTrial() {
        UserDefaults.standard.removeObject(forKey: installDateKey)
        UserDefaults.standard.removeObject(forKey: totalTripsCreatedKey)
        setupInstallDate()
        loadTotalTripsCreated()
        updateTrialStatus()
        print("🔄 Trial reset for testing")
    }
    
    /// Force trial exhaustion for testing paywall
    func exhaustTrial() {
        totalTripsCreated = maxFreeTrips
        UserDefaults.standard.set(totalTripsCreated, forKey: totalTripsCreatedKey)
        updateTrialStatus()
        print("🚫 Trial forcibly exhausted for testing")
    }
    
    /// Set specific trip count for testing
    func setTripCount(_ count: Int) {
        totalTripsCreated = count
        UserDefaults.standard.set(totalTripsCreated, forKey: totalTripsCreatedKey)
        updateTrialStatus()
        print("📊 Trip count set to \(count) for testing")
    }
    #endif
}
//
//  DismissedRosterItem.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/30/25.
//


//
//  DismissedRosterItemsManager.swift
//  ProPilotApp
//
//  Manages roster items that user has dismissed/hidden
//

import Foundation
import Combine

// MARK: - Dismissed Item Model
struct DismissedRosterItem: Codable, Identifiable {
    let id: UUID                    // Original roster item ID
    let tripNumber: String
    let date: Date
    let route: String
    let dismissedAt: Date
    let dismissedUntil: Date?       // nil = dismissed permanently
    let reason: DismissReason
    
    enum DismissReason: String, Codable {
        case cancelled = "Cancelled"
        case notFlying = "Not Flying"
        case duplicate = "Duplicate"
        case temporary = "Remind Later"
        case other = "Other"
        
        var displayName: String { rawValue }
    }
    
    var isPermanent: Bool {
        dismissedUntil == nil
    }
    
    var isExpired: Bool {
        guard let until = dismissedUntil else { return false }
        return Date() > until
    }
}

// MARK: - Dismissed Roster Items Manager
class DismissedRosterItemsManager: ObservableObject {
    static let shared = DismissedRosterItemsManager()
    
    @Published var dismissedItems: [DismissedRosterItem] = []
    
    private let userDefaults: UserDefaults
    private let dismissedItemsKey = "DismissedRosterItems"
    
    private init() {
        if let groupDefaults = UserDefaults(suiteName: "group.com.propilot.app") {
            self.userDefaults = groupDefaults
        } else {
            self.userDefaults = .standard
        }
        
        loadDismissedItems()
        cleanupExpiredItems()
    }
    
    // MARK: - Dismiss Operations
    
    /// Dismiss a roster item permanently
    func dismiss(_ item: BasicScheduleItem, reason: DismissedRosterItem.DismissReason = .other) {
        let dismissed = DismissedRosterItem(
            id: item.id,
            tripNumber: item.tripNumber,
            date: item.date,
            route: "\(item.departure) → \(item.arrival)",
            dismissedAt: Date(),
            dismissedUntil: nil,  // Permanent
            reason: reason
        )
        
        dismissedItems.append(dismissed)
        saveDismissedItems()
        
        print("🚫 Dismissed roster item: \(item.tripNumber) on \(formatDate(item.date)) - Reason: \(reason.displayName)")
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .rosterItemDismissed,
            object: nil,
            userInfo: ["item": item, "reason": reason]
        )
    }
    
    /// Dismiss a roster item until a specific date
    func dismiss(_ item: BasicScheduleItem, until: Date, reason: DismissedRosterItem.DismissReason = .temporary) {
        let dismissed = DismissedRosterItem(
            id: item.id,
            tripNumber: item.tripNumber,
            date: item.date,
            route: "\(item.departure) → \(item.arrival)",
            dismissedAt: Date(),
            dismissedUntil: until,
            reason: reason
        )
        
        dismissedItems.append(dismissed)
        saveDismissedItems()
        
        print("⏰ Dismissed roster item until \(formatDate(until)): \(item.tripNumber)")
        
        NotificationCenter.default.post(
            name: .rosterItemDismissed,
            object: nil,
            userInfo: ["item": item, "until": until]
        )
    }
    
    // MARK: - Query Operations
    
    /// Check if a roster item is dismissed
    func isDismissed(_ item: BasicScheduleItem) -> Bool {
        return dismissedItems.contains { dismissed in
            dismissed.id == item.id && !dismissed.isExpired
        }
    }
    
    /// Check if a roster item ID is dismissed
    func isDismissed(id: UUID) -> Bool {
        return dismissedItems.contains { dismissed in
            dismissed.id == id && !dismissed.isExpired
        }
    }
    
    /// Get all currently dismissed items (excluding expired)
    func getCurrentlyDismissed() -> [DismissedRosterItem] {
        return dismissedItems.filter { !$0.isExpired }
    }
    
    /// Get permanently dismissed items
    func getPermanentlyDismissed() -> [DismissedRosterItem] {
        return dismissedItems.filter { $0.isPermanent }
    }
    
    /// Get temporarily dismissed items
    func getTemporarilyDismissed() -> [DismissedRosterItem] {
        return dismissedItems.filter { !$0.isPermanent && !$0.isExpired }
    }
    
    // MARK: - Re-activation Operations
    
    /// Re-activate a dismissed item (remove from dismissed list)
    func reactivate(_ dismissedItem: DismissedRosterItem) {
        dismissedItems.removeAll { $0.id == dismissedItem.id }
        saveDismissedItems()
        
        print("✅ Re-activated roster item: \(dismissedItem.tripNumber)")
        
        NotificationCenter.default.post(
            name: .rosterItemReactivated,
            object: nil,
            userInfo: ["item": dismissedItem]
        )
    }
    
    /// Re-activate by roster item ID
    func reactivate(id: UUID) {
        if let dismissed = dismissedItems.first(where: { $0.id == id }) {
            reactivate(dismissed)
        }
    }
    
    /// Clear all dismissed items
    func clearAll() {
        dismissedItems.removeAll()
        saveDismissedItems()
        print("🗑️ Cleared all dismissed roster items")
    }
    
    /// Clear expired temporary dismissals
    func cleanupExpiredItems() {
        let beforeCount = dismissedItems.count
        dismissedItems.removeAll { $0.isExpired }
        
        if dismissedItems.count < beforeCount {
            saveDismissedItems()
            print("🧹 Cleaned up \(beforeCount - dismissedItems.count) expired dismissals")
        }
    }
    
    // MARK: - Persistence
    
    private func saveDismissedItems() {
        if let data = try? JSONEncoder().encode(dismissedItems) {
            userDefaults.set(data, forKey: dismissedItemsKey)
            userDefaults.synchronize()
        }
    }
    
    private func loadDismissedItems() {
        guard let data = userDefaults.data(forKey: dismissedItemsKey),
              let items = try? JSONDecoder().decode([DismissedRosterItem].self, from: data) else {
            return
        }
        
        dismissedItems = items
        print("📋 Loaded \(items.count) dismissed roster items")
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let rosterItemDismissed = Notification.Name("rosterItemDismissed")
    static let rosterItemReactivated = Notification.Name("rosterItemReactivated")
}
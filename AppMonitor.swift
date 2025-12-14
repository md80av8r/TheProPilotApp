//
//  MonitoringClaude.swift
//  BlockCalcv2
//
//  Created by Jeffrey Kadans on 6/25/25.
//

import Foundation
import SwiftUI
import os.log

// MARK: - App Performance Monitor
class AppMonitor: ObservableObject {
    static let shared = AppMonitor()
    
    private let logger = Logger(subsystem: "com.yourapp.logbook", category: "AppMonitor")
    
    @Published var isMonitoring = true
    @Published var performanceMetrics: [PerformanceMetric] = []
    @Published var userActions: [UserAction] = []
    @Published var appErrors: [AppError] = []
    
    private var startTime: Date?
    private var memoryUsageTimer: Timer?
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Setup
    private func setupMonitoring() {
        startTime = Date()
        startMemoryMonitoring()
        logger.info("App monitoring started")
    }
    
    // MARK: - Performance Monitoring
    func trackAppLaunch() {
        let launchTime = Date().timeIntervalSince(startTime ?? Date())
        let metric = PerformanceMetric(
            type: .appLaunch,
            value: launchTime,
            timestamp: Date(),
            details: "App launched in \(String(format: "%.2f", launchTime))s"
        )
        performanceMetrics.append(metric)
        logger.info("App launch tracked: \(launchTime)s")
    }
    
    func trackDataOperation(_ operation: String, duration: TimeInterval) {
        let metric = PerformanceMetric(
            type: .dataOperation,
            value: duration,
            timestamp: Date(),
            details: "\(operation) completed in \(String(format: "%.3f", duration))s"
        )
        performanceMetrics.append(metric)
        logger.info("Data operation tracked: \(operation) - \(duration)s")
    }
    
    func trackViewLoad(_ viewName: String, duration: TimeInterval) {
        let metric = PerformanceMetric(
            type: .viewLoad,
            value: duration,
            timestamp: Date(),
            details: "\(viewName) loaded in \(String(format: "%.3f", duration))s"
        )
        performanceMetrics.append(metric)
        logger.info("View load tracked: \(viewName) - \(duration)s")
    }
    
    private func startMemoryMonitoring() {
        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            let memoryUsage = self.getCurrentMemoryUsage()
            let metric = PerformanceMetric(
                type: .memoryUsage,
                value: memoryUsage,
                timestamp: Date(),
                details: "Memory usage: \(String(format: "%.1f", memoryUsage))MB"
            )
            self.performanceMetrics.append(metric)
            
            // Keep only last 50 memory readings
            if self.performanceMetrics.filter({ $0.type == .memoryUsage }).count > 50 {
                self.performanceMetrics.removeAll { $0.type == .memoryUsage }
                self.performanceMetrics.append(metric)
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0.0
    }
    
    // MARK: - User Action Tracking
    func trackUserAction(_ action: UserActionType, details: String = "") {
        let userAction = UserAction(
            type: action,
            timestamp: Date(),
            details: details
        )
        userActions.append(userAction)
        logger.info("User action tracked: \(action.rawValue) - \(details)")
        
        // Keep only last 100 actions
        if userActions.count > 100 {
            userActions.removeFirst()
        }
    }
    
    // MARK: - Error Tracking
    func trackError(_ error: Error, context: String = "") {
        let appError = AppError(
            error: error,
            context: context,
            timestamp: Date()
        )
        appErrors.append(appError)
        logger.error("Error tracked: \(error.localizedDescription) in \(context)")
        
        // Keep only last 50 errors
        if appErrors.count > 50 {
            appErrors.removeFirst()
        }
    }
    
    // MARK: - Data Export
    func exportMonitoringData() -> String {
        var report = "Flight Logbook App - Monitoring Report\n"
        report += "Generated: \(Date())\n\n"
        
        // Performance Summary
        report += "=== PERFORMANCE METRICS ===\n"
        let avgLaunchTime = performanceMetrics.filter { $0.type == .appLaunch }.map { $0.value }.reduce(0, +) / Double(max(1, performanceMetrics.filter { $0.type == .appLaunch }.count))
        report += "Average Launch Time: \(String(format: "%.2f", avgLaunchTime))s\n"
        
        let recentMemory = performanceMetrics.filter { $0.type == .memoryUsage }.suffix(10).map { $0.value }
        let avgMemory = recentMemory.reduce(0, +) / Double(max(1, recentMemory.count))
        report += "Average Memory Usage: \(String(format: "%.1f", avgMemory))MB\n\n"
        
        // User Actions Summary
        report += "=== USER ACTIONS (Last 20) ===\n"
        for action in userActions.suffix(20) {
            report += "\(action.timestamp): \(action.type.rawValue) - \(action.details)\n"
        }
        
        // Errors Summary
        if !appErrors.isEmpty {
            report += "\n=== ERRORS ===\n"
            for error in appErrors {
                report += "\(error.timestamp): \(error.description) in \(error.context)\n"
            }
        }
        
        return report
    }
    
    deinit {
        memoryUsageTimer?.invalidate()
    }
}

// MARK: - Data Models
struct PerformanceMetric: Identifiable {
    let id = UUID()
    let type: MetricType
    let value: Double
    let timestamp: Date
    let details: String
    
    enum MetricType {
        case appLaunch
        case dataOperation
        case viewLoad
        case memoryUsage
    }
}

struct UserAction: Identifiable {
    let id = UUID()
    let type: UserActionType
    let timestamp: Date
    let details: String
}

enum UserActionType: String, CaseIterable {
    case tripAdded = "Trip Added"
    case tripEdited = "Trip Edited"
    case tripDeleted = "Trip Deleted"
    case viewSwitched = "View Switched"
    case dataExported = "Data Exported"
    case settingsChanged = "Settings Changed"
    case perDiemCalculated = "Per Diem Calculated"
}

struct AppError: Identifiable {
    let id = UUID()
    let error: Error
    let context: String
    let timestamp: Date
    
    var description: String {
        return error.localizedDescription
    }
}

// MARK: - Monitoring Extensions for Your Existing Classes
extension LogBookStore {
    func addTripWithMonitoring(_ trip: Trip) {
        let startTime = Date()
        addTrip(trip)
        let duration = Date().timeIntervalSince(startTime)
        
        AppMonitor.shared.trackDataOperation("Add Trip", duration: duration)
        AppMonitor.shared.trackUserAction(.tripAdded, details: "Trip #\(trip.tripNumber)")
    }
    
    func updateTripWithMonitoring(_ trip: Trip, at index: Int) {
        let startTime = Date()
        updateTrip(trip, at: index)
        let duration = Date().timeIntervalSince(startTime)
        
        AppMonitor.shared.trackDataOperation("Update Trip", duration: duration)
        AppMonitor.shared.trackUserAction(.tripEdited, details: "Trip #\(trip.tripNumber)")
    }
    
    func deleteTripWithMonitoring(at offsets: IndexSet) {
        let startTime = Date()
        deleteTrip(at: offsets)
        let duration = Date().timeIntervalSince(startTime)
        
        AppMonitor.shared.trackDataOperation("Delete Trip", duration: duration)
        AppMonitor.shared.trackUserAction(.tripDeleted, details: "\(offsets.count) trip(s)")
    }
    
    func saveWithMonitoring() {
        let startTime = Date()
        save()
        let duration = Date().timeIntervalSince(startTime)
        
        AppMonitor.shared.trackDataOperation("Save Data", duration: duration)
    }
    
    func loadWithMonitoring() {
        let startTime = Date()
        load()
        let duration = Date().timeIntervalSince(startTime)
        
        AppMonitor.shared.trackDataOperation("Load Data", duration: duration)
    }
}

// MARK: - View Performance Wrapper
struct MonitoredView<Content: View>: View {
    let viewName: String
    let content: Content
    @State private var loadTime: Date = Date()
    
    init(_ viewName: String, @ViewBuilder content: () -> Content) {
        self.viewName = viewName
        self.content = content()
    }
    
    var body: some View {
        content
            .onAppear {
                let duration = Date().timeIntervalSince(loadTime)
                AppMonitor.shared.trackViewLoad(viewName, duration: duration)
            }
            .onDisappear {
                AppMonitor.shared.trackUserAction(.viewSwitched, details: "Left \(viewName)")
            }
    }
}

// MARK: - Monitoring Dashboard View
struct MonitoringDashboardView: View {
    @ObservedObject private var monitor = AppMonitor.shared
    @State private var showingExport = false
    @State private var exportedData = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Performance") {
                    if let lastMemory = monitor.performanceMetrics.filter({ $0.type == .memoryUsage }).last {
                        HStack {
                            Text("Memory Usage")
                            Spacer()
                            Text("\(String(format: "%.1f", lastMemory.value))MB")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    let launchMetrics = monitor.performanceMetrics.filter { $0.type == .appLaunch }
                    if !launchMetrics.isEmpty {
                        let avgLaunch = launchMetrics.map { $0.value }.reduce(0, +) / Double(launchMetrics.count)
                        HStack {
                            Text("Avg Launch Time")
                            Spacer()
                            Text("\(String(format: "%.2f", avgLaunch))s")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section("Recent Actions") {
                    ForEach(monitor.userActions.suffix(10).reversed(), id: \.id) { action in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.type.rawValue)
                                .font(.headline)
                            if !action.details.isEmpty {
                                Text(action.details)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(action.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                if !monitor.appErrors.isEmpty {
                    Section("Recent Errors") {
                        ForEach(monitor.appErrors.suffix(5).reversed(), id: \.id) { error in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.description)
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text(error.context)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(error.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("App Monitor")
            .toolbar {
                Button("Export") {
                    exportedData = monitor.exportMonitoringData()
                    showingExport = true
                }
            }
            .sheet(isPresented: $showingExport) {
                NavigationView {
                    ScrollView {
                        Text(exportedData)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle("Monitoring Report")
                    .toolbar {
                        Button("Done") { showingExport = false }
                    }
                }
            }
        }
    }
}

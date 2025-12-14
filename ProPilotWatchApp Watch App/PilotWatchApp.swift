// PilotWatchApp.swift - Watch App Only
import SwiftUI
import WatchKit
import HealthKit

@main
struct ProPilotWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var delegate
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(connectivityManager)
                .onAppear {
                    setupWatchApp()
                }
        }
    }
    
    private func setupWatchApp() {
        print("⌚ Watch app setup starting...")
        
        // Keep the app active when it appears
        WKExtension.shared().isAutorotating = false
        
        // Request extended runtime session for pilot operations
        requestExtendedRuntimeSession()
        
        // Schedule background refresh if not active
        if WKExtension.shared().applicationState != .active {
            scheduleBackgroundRefresh()
        }
        
        print("⌚ Watch app setup complete")
    }
    
    private func requestExtendedRuntimeSession() {
        let session = WKExtendedRuntimeSession()
        session.delegate = ExtensionDelegate.shared
        session.start()
        print("⌚ Extended runtime session started")
    }
    
    private func scheduleBackgroundRefresh() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(30),
            userInfo: nil
        ) { error in
            if let error = error {
                print("⌚ Background refresh scheduling error: \(error)")
            } else {
                print("⌚ Background refresh scheduled successfully")
            }
        }
    }
}

// MARK: - Enhanced Extension Delegate
class ExtensionDelegate: NSObject, WKExtensionDelegate, WKExtendedRuntimeSessionDelegate {
    static let shared = ExtensionDelegate()
    private var extendedSession: WKExtendedRuntimeSession?
    
    func applicationDidFinishLaunching() {
        print("⌚ Watch app finished launching")
        
        // Initialize connectivity manager
        let _ = WatchConnectivityManager.shared
        
        // Schedule background processing
        scheduleNextBackgroundRefresh()
        
        // Request health authorization if needed
        requestHealthAuthorization()
    }
    
    func applicationDidBecomeActive() {
        print("⌚ Watch app became active")
        
        // Check connectivity status
        let connectivityManager = WatchConnectivityManager.shared
        if !connectivityManager.isPhoneReachable {
            print("⌚ Phone not reachable")
        } else {
            print("⌚ Phone is reachable")
        }
        
        // Only start extended session if there is truly an active trip/duty timer
        if connectivityManager.isDutyTimerRunning {
            startExtendedSession()
        } else {
            print("⌚ Skipping extended session start: no active trip")
            // Ensure any previous session is stopped if state changed while inactive
            performStopExtendedSession()
        }
    }
    
    func applicationWillResignActive() {
        print("⌚ Watch app will resign active")
        scheduleNextBackgroundRefresh()
    }
    
    func applicationDidEnterBackground() {
        print("⌚ Watch app entered background")
        scheduleNextBackgroundRefresh()
    }
    
    // MARK: - Background Task Handling
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        print("⌚ Handling \(backgroundTasks.count) background tasks")
        
        for task in backgroundTasks {
            switch task {
            case let backgroundRefreshTask as WKApplicationRefreshBackgroundTask:
                handleApplicationRefreshTask(backgroundRefreshTask)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                handleSnapshotTask(snapshotTask)
                
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                handleConnectivityTask(connectivityTask)
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                handleURLSessionTask(urlSessionTask)
                
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                handleRelevantShortcutTask(relevantShortcutTask)
                
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                handleIntentDidRunTask(intentDidRunTask)
                
            default:
                print("⌚ Handling unknown background task: \(type(of: task))")
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    private func handleApplicationRefreshTask(_ task: WKApplicationRefreshBackgroundTask) {
        print("⌚ Handling application refresh task")
        
        // Keep connectivity manager active
        let _ = WatchConnectivityManager.shared
        
        // Schedule next refresh
        scheduleNextBackgroundRefresh()
        
        // Complete the task
        task.setTaskCompletedWithSnapshot(false)
    }
    
    private func handleSnapshotTask(_ task: WKSnapshotRefreshBackgroundTask) {
        print("⌚ Handling snapshot task")
        task.setTaskCompleted(
            restoredDefaultState: true,
            estimatedSnapshotExpiration: Date.distantFuture,
            userInfo: nil
        )
    }
    
    private func handleConnectivityTask(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        print("⌚ Handling connectivity task")
        
        // Keep connectivity manager active
        let _ = WatchConnectivityManager.shared
        
        task.setTaskCompletedWithSnapshot(false)
    }
    
    private func handleURLSessionTask(_ task: WKURLSessionRefreshBackgroundTask) {
        print("⌚ Handling URL session task")
        task.setTaskCompletedWithSnapshot(false)
    }
    
    private func handleRelevantShortcutTask(_ task: WKRelevantShortcutRefreshBackgroundTask) {
        print("⌚ Handling relevant shortcut task")
        task.setTaskCompletedWithSnapshot(false)
    }
    
    private func handleIntentDidRunTask(_ task: WKIntentDidRunRefreshBackgroundTask) {
        print("⌚ Handling intent did run task")
        task.setTaskCompletedWithSnapshot(false)
    }
    
    // MARK: - Extended Runtime Session
    private func startExtendedSession() {
        // Only start if not already running and there's active work
        guard extendedSession == nil else { return }
        guard WatchConnectivityManager.shared.isDutyTimerRunning else {
            print("⌚ Not starting extended session: no active trip")
            return
        }
        
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
        print("⌚ Extended session started for pilot operations")
    }
    
    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
        print("⌚ Extended session stopped")
    }
    
    // Public wrapper to allow other components (e.g., connectivity) to stop the session
    func performStopExtendedSession() {
        stopExtendedSession()
    }
    
    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("⌚ Extended session invalidated: \(reason)")
        if let error = error {
            print("⌚ Session error: \(error)")
        }
        extendedSession = nil
        
        // Try to restart if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if WatchConnectivityManager.shared.isDutyTimerRunning {
                self.startExtendedSession()
            }
        }
    }
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⌚ Extended session did start successfully")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⌚ Extended session will expire - scheduling refresh")
        scheduleNextBackgroundRefresh()
    }
    
    // MARK: - Background Refresh Scheduling
    private func scheduleNextBackgroundRefresh() {
        // Only schedule background refreshes when there is active work (e.g., an ongoing trip)
        let isActive = WatchConnectivityManager.shared.isDutyTimerRunning
        guard isActive else {
            print("⌚ Skipping background refresh scheduling: no active trip")
            return
        }
        
        // Schedule refresh every 1 minute for pilot operations
        let refreshDate = Date().addingTimeInterval(60)
        
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: refreshDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("⌚ Failed to schedule background refresh: \(error)")
            } else {
                print("⌚ Scheduled next background refresh for \(refreshDate)")
            }
        }
    }
    
    // MARK: - Health Authorization
    private func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let healthStore = HKHealthStore()
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("⌚ Health authorization granted")
            } else if let error = error {
                print("⌚ Health authorization error: \(error)")
            }
        }
    }
}


//
//  NotificationNames.swift
//  ProPilotApp
//
//  Centralized notification names for the entire app
//
//  TARGET MEMBERSHIP:
//  ✅ ProPilotApp
//  ✅ ProPilotWidget
//  ✅ ProPilot Watch App
//

import Foundation

// MARK: - Notification.Name Extension
// Note: Notification.Name and NSNotification.Name are the same type in Swift
// Only define once to avoid redeclaration errors

extension Notification.Name {
    // MARK: - Watch Integration
    static let startDutyFromWatch = Notification.Name("startDutyFromWatch")
    static let endDutyFromWatch = Notification.Name("endDutyFromWatch")
    static let callOPSFromWatch = Notification.Name("callOPSFromWatch")
    static let setOutTimeFromWatch = Notification.Name("setOutTimeFromWatch")
    static let setInTimeFromWatch = Notification.Name("setInTimeFromWatch")
    static let flightTimeUpdatedFromWatch = Notification.Name("flightTimeUpdatedFromWatch")
    
    // MARK: - Duty Timer
    static let dutyTimerStarted = Notification.Name("dutyTimerStarted")
    static let dutyTimerEnded = Notification.Name("dutyTimerEnded")
    
    // MARK: - Location & Geofencing
    static let arrivedAtAirport = Notification.Name("arrivedAtAirport")
    static let departedAirport = Notification.Name("departedAirport")
    static let refreshGeofences = Notification.Name("refreshGeofences")
    
    // MARK: - Speed-Based Flight Triggers
    static let takeoffRollStarted = Notification.Name("takeoffRollStarted")
    static let landingRollDecel = Notification.Name("landingRollDecel")
    
    // MARK: - Flight Operations
    static let autoOffTime = Notification.Name("autoOffTime")
    static let autoOnTime = Notification.Name("autoOnTime")
    static let flightPhaseChanged = Notification.Name("flightPhaseChanged")
    
    // MARK: - Live Activities
    static let startLiveActivity = Notification.Name("startLiveActivity")
    static let updateLiveActivity = Notification.Name("updateLiveActivity")
    static let endLiveActivity = Notification.Name("endLiveActivity")
    static let liveActivityStarted = Notification.Name("liveActivityStarted")
    static let liveActivityUpdated = Notification.Name("liveActivityUpdated")
    static let liveActivityEnded = Notification.Name("liveActivityEnded")
    
    // MARK: - Data Sync
    static let dataExported = Notification.Name("dataExported")
    static let dataImported = Notification.Name("dataImported")
    static let scheduleUpdated = Notification.Name("scheduleUpdated")
    static let syncStateChanged = Notification.Name("syncStateChanged")
    
    // MARK: - Trip Management
    static let tripStatusChanged = Notification.Name("tripStatusChanged")
    
    // MARK: - Auto Time
    static let autoTimeTriggered = Notification.Name("autoTimeTriggered")
    
    // MARK: - Widget Actions
    static let nextLegFromWidget = Notification.Name("nextLegFromWidget")
    static let quickLogFromWidget = Notification.Name("quickLogFromWidget")
    static let weatherCheckFromWidget = Notification.Name("weatherCheckFromWidget")
    
    // MARK: - Data Management
    static let showDataImport = Notification.Name("showDataImport")
    static let showDataExport = Notification.Name("showDataExport")
    static let createBackupFromWidget = Notification.Name("createBackupFromWidget")
    static let dataRecoveryAvailable = Notification.Name("dataRecoveryAvailable")
    
    // MARK: - Location Permissions
    static let locationPermissionGranted = Notification.Name("locationPermissionGranted")
    static let showLocationPermissionAlert = Notification.Name("showLocationPermissionAlert")
    
    // MARK: - NOC Sync
    static let nocAutoSyncSettingChanged = Notification.Name("nocAutoSyncSettingChanged")
    static let nocSyncCompleted = Notification.Name("nocSyncCompleted")
    
    // MARK: - Leg Sync (Watch/Phone)
    static let legSyncConflictDetected = Notification.Name("legSyncConflictDetected")
    static let legSyncForced = Notification.Name("legSyncForced")
    static let newLegAddedOnPhone = Notification.Name("newLegAddedOnPhone")
    static let newLegAddedOnWatch = Notification.Name("newLegAddedOnWatch")
}

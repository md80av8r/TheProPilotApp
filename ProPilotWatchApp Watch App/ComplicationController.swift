// ComplicationController.swift
// Handles Watch Face Complications with proper data types
import ClockKit
import SwiftUI
import WatchKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "ProPilotComplication", displayName: "ProPilot", supportedFamilies: CLKComplicationFamily.allCases)
        ]
        handler(descriptors)
    }
    
    // MARK: - Complication Data Structure
    struct ComplicationData {
        let isOnDuty: Bool
        let dutyTime: String
        let tripNumber: String
        let aircraft: String
        let outTime: String
        let offTime: String
        let onTime: String
        let inTime: String
        let nextAction: String
        let statusText: String
    }
    
    // MARK: - Timeline Population
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let flightData = loadSharedFlightData()
        let template = createTemplate(for: complication.family, flightData: flightData)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date().addingTimeInterval(3600)) // Update every hour
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let flightData = ComplicationData(
            isOnDuty: true,
            dutyTime: "2:45",
            tripNumber: "123456",
            aircraft: "B737",
            outTime: "08:00",
            offTime: "08:15",
            onTime: "10:45",
            inTime: "11:00",
            nextAction: "Set OUT",
            statusText: "Pre-Flight"
        )
        let template = createTemplate(for: complication.family, flightData: flightData)
        handler(template)
    }
    
    // MARK: - Helper Methods
    
    /// Load shared flight data from UserDefaults
    private func loadSharedFlightData() -> ComplicationData {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.propilot.app") else {
            print("⚠️ Failed to access shared UserDefaults - using default data")
            return getDefaultComplicationData()
        }
        
        // Load duty status
        let isOnDuty = sharedDefaults.bool(forKey: "isOnDuty")
        let dutyStartTime = sharedDefaults.object(forKey: "dutyStartTime") as? Date
        
        // Calculate duty time
        let dutyTimeString: String
        if let startTime = dutyStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            dutyTimeString = String(format: "%d:%02d", hours, minutes)
        } else {
            dutyTimeString = "0:00"
        }
        
        // Load trip data
        let tripNumber = sharedDefaults.string(forKey: "currentTripNumber") ?? "No Trip"
        let aircraft = sharedDefaults.string(forKey: "currentAircraft") ?? "----"
        
        // Load flight times
        let outTime = sharedDefaults.string(forKey: "outTime") ?? "--:--"
        let offTime = sharedDefaults.string(forKey: "offTime") ?? "--:--"
        let onTime = sharedDefaults.string(forKey: "onTime") ?? "--:--"
        let inTime = sharedDefaults.string(forKey: "inTime") ?? "--:--"
        
        // Determine next action
        let nextAction: String
        let statusText: String
        
        if !isOnDuty {
            nextAction = "Start Duty"
            statusText = "Off Duty"
        } else if outTime == "--:--" {
            nextAction = "Set OUT"
            statusText = "Pre-Flight"
        } else if offTime == "--:--" {
            nextAction = "Set OFF"
            statusText = "Taxi Out"
        } else if onTime == "--:--" {
            nextAction = "Set ON"
            statusText = "Enroute"
        } else if inTime == "--:--" {
            nextAction = "Set IN"
            statusText = "Taxi In"
        } else {
            nextAction = "Complete"
            statusText = "At Gate"
        }
        
        return ComplicationData(
            isOnDuty: isOnDuty,
            dutyTime: dutyTimeString,
            tripNumber: tripNumber,
            aircraft: aircraft,
            outTime: outTime,
            offTime: offTime,
            onTime: onTime,
            inTime: inTime,
            nextAction: nextAction,
            statusText: statusText
        )
    }
    
    /// Get current flight data from WatchConnectivityManager
    private func getCurrentFlightData() -> FlightData {
        // Access the WatchConnectivityManager to get actual flight data
        let connectivityManager = WatchConnectivityManager.shared
        
        if let currentFlight = connectivityManager.currentFlight {
            return currentFlight
        } else {
            // Return default flight data if none available
            return FlightData(
                flightNumber: "",
                departureAirport: "---",
                arrivalAirport: "---",
                outTime: nil,
                offTime: nil,
                onTime: nil,
                inTime: nil
            )
        }
    }
    
    /// Provide default complication data when UserDefaults is unavailable
    private func getDefaultComplicationData() -> ComplicationData {
        return ComplicationData(
            isOnDuty: false,
            dutyTime: "0:00",
            tripNumber: "No Trip",
            aircraft: "----",
            outTime: "--:--",
            offTime: "--:--",
            onTime: "--:--",
            inTime: "--:--",
            nextAction: "Start Duty",
            statusText: "Off Duty"
        )
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for family: CLKComplicationFamily, flightData: ComplicationData) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            return createModularSmallTemplate(flightData: flightData)
        case .modularLarge:
            return createModularLargeTemplate(flightData: flightData)
        case .utilitarianSmall, .utilitarianSmallFlat:
            return createUtilitarianSmallTemplate(flightData: flightData)
        case .utilitarianLarge:
            return createUtilitarianLargeTemplate(flightData: flightData)
        case .circularSmall:
            return createCircularSmallTemplate(flightData: flightData)
        case .extraLarge:
            return createExtraLargeTemplate(flightData: flightData)
        case .graphicCorner:
            return createGraphicCornerTemplate(flightData: flightData)
        case .graphicCircular:
            return createGraphicCircularTemplate(flightData: flightData)
        case .graphicRectangular:
            return createGraphicRectangularTemplate(flightData: flightData)
        case .graphicBezel:
            return createGraphicBezelTemplate(flightData: flightData)
        case .graphicExtraLarge:
            if #available(watchOS 7.0, *) {
                return createGraphicExtraLargeTemplate(flightData: flightData)
            } else {
                return createExtraLargeTemplate(flightData: flightData)
            }
        @unknown default:
            return createModularSmallTemplate(flightData: flightData)
        }
    }
    
    // MARK: - Specific Template Creators
    
    private func createModularSmallTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let line1 = CLKTextProvider(format: flightData.tripNumber)
        let line2 = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "OFF")
        let template = CLKComplicationTemplateModularSmallStackText(line1TextProvider: line1, line2TextProvider: line2)
        return template
    }
    
    private func createModularLargeTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let headerText = flightData.isOnDuty ? "✈️ \(flightData.tripNumber)" : "✈️ Off Duty"
        let headerProvider = CLKTextProvider(format: headerText)
        let body1Provider = CLKTextProvider(format: flightData.statusText)
        
        let body2Text: String
        if flightData.isOnDuty {
            body2Text = "OUT: \(flightData.outTime) OFF: \(flightData.offTime)"
        } else {
            body2Text = "Tap to Start Duty"
        }
        let body2Provider = CLKTextProvider(format: body2Text)
        
        let template = CLKComplicationTemplateModularLargeStandardBody(
            headerTextProvider: headerProvider,
            body1TextProvider: body1Provider,
            body2TextProvider: body2Provider
        )
        
        return template
    }
    
    private func createUtilitarianSmallTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let text = flightData.isOnDuty ? "✈️ \(flightData.dutyTime)" : "✈️ OFF"
        let textProvider = CLKTextProvider(format: text)
        let template = CLKComplicationTemplateUtilitarianSmallFlat(textProvider: textProvider)
        return template
    }
    
    private func createUtilitarianLargeTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let text: String
        if flightData.isOnDuty {
            text = "✈️ \(flightData.tripNumber) • \(flightData.statusText) • \(flightData.dutyTime)"
        } else {
            text = "✈️ Off Duty • Tap to Start"
        }
        let textProvider = CLKTextProvider(format: text)
        let template = CLKComplicationTemplateUtilitarianLargeFlat(textProvider: textProvider)
        return template
    }
    
    private func createCircularSmallTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let line1Provider = CLKTextProvider(format: "✈️")
        let line2Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "OFF")
        let template = CLKComplicationTemplateCircularSmallStackText(
            line1TextProvider: line1Provider,
            line2TextProvider: line2Provider
        )
        return template
    }
    
    private func createExtraLargeTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let line1Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.tripNumber : "Off Duty")
        let line2Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "✈️")
        let template = CLKComplicationTemplateExtraLargeStackText(
            line1TextProvider: line1Provider,
            line2TextProvider: line2Provider
        )
        return template
    }
    
    private func createGraphicCornerTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let outerProvider = CLKTextProvider(format: "✈️")
        let innerText: String
        if flightData.isOnDuty {
            innerText = "\(flightData.tripNumber)\n\(flightData.dutyTime)"
        } else {
            innerText = "Off Duty"
        }
        let innerProvider = CLKTextProvider(format: innerText)
        
        let template = CLKComplicationTemplateGraphicCornerStackText(
            innerTextProvider: innerProvider,
            outerTextProvider: outerProvider
        )
        return template
    }
    
    private func createGraphicCircularTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let line1Provider = CLKTextProvider(format: "✈️")
        let line2Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "OFF")
        let template = CLKComplicationTemplateGraphicCircularStackText(
            line1TextProvider: line1Provider,
            line2TextProvider: line2Provider
        )
        return template
    }
    
    private func createGraphicRectangularTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let headerText = flightData.isOnDuty ? "✈️ \(flightData.tripNumber)" : "✈️ ProPilot"
        let headerProvider = CLKTextProvider(format: headerText)
        
        let body1Text: String
        let body2Text: String
        if flightData.isOnDuty {
            body1Text = "\(flightData.statusText) • \(flightData.dutyTime)"
            body2Text = "Next: \(flightData.nextAction)"
        } else {
            body1Text = "Off Duty"
            body2Text = "Tap to Start Duty"
        }
        let body1Provider = CLKTextProvider(format: body1Text)
        let body2Provider = CLKTextProvider(format: body2Text)
        
        let template = CLKComplicationTemplateGraphicRectangularStandardBody(
            headerTextProvider: headerProvider,
            body1TextProvider: body1Provider,
            body2TextProvider: body2Provider
        )
        return template
    }
    
    private func createGraphicBezelTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        // Create the circular template first
        let line1Provider = CLKTextProvider(format: "✈️")
        let line2Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "OFF")
        let circularTemplate = CLKComplicationTemplateGraphicCircularStackText(
            line1TextProvider: line1Provider,
            line2TextProvider: line2Provider
        )
        
        // Create bezel text
        let bezelText: String
        if flightData.isOnDuty {
            bezelText = "\(flightData.tripNumber) • \(flightData.statusText)"
        } else {
            bezelText = "Off Duty • Tap to Start"
        }
        let textProvider = CLKTextProvider(format: bezelText)
        
        let template = CLKComplicationTemplateGraphicBezelCircularText(
            circularTemplate: circularTemplate,
            textProvider: textProvider
        )
        return template
    }
    
    @available(watchOS 7.0, *)
    private func createGraphicExtraLargeTemplate(flightData: ComplicationData) -> CLKComplicationTemplate {
        let line1Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.tripNumber : "ProPilot")
        let line2Provider = CLKTextProvider(format: flightData.isOnDuty ? flightData.dutyTime : "Off Duty")
        let template = CLKComplicationTemplateGraphicExtraLargeCircularStackText(
            line1TextProvider: line1Provider,
            line2TextProvider: line2Provider
        )
        return template
    }
}

//
//  ScheduleDataAnalyzer.swift
//  ProPilotApp
//
//  Created by Jeffrey Kadans on 7/27/25.
//


// Schedule Data Analysis Script
// Run this to see what data we have and fix the terminology

import SwiftUI

struct ScheduleDataAnalyzer: View {
    @ObservedObject var scheduleStore: ScheduleStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Schedule Data Analysis")
                    .font(.title.bold())
                    .foregroundColor(LogbookTheme.textPrimary)
                
                // Basic data overview
                dataOverviewSection
                
                // Sample items detailed breakdown
                sampleItemsSection
                
                // Available properties analysis
                propertiesAnalysisSection
                
                // Terminology suggestions
                terminologySuggestionsSection
            }
            .padding()
        }
        .background(LogbookTheme.navy)
    }
    
    private var dataOverviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Overview")
                .font(.headline)
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("Total Items: \(scheduleStore.items.count)")
            Text("Date Range: \(getDateRange())")
            
            if !scheduleStore.items.isEmpty {
                let sortedItems = scheduleStore.items.sorted { $0.date < $1.date }
                Text("First Entry: \(formatDate(sortedItems.first!.date))")
                Text("Last Entry: \(formatDate(sortedItems.last!.date))")
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(8)
    }
    private func getDateRange() -> String {
        guard !scheduleStore.items.isEmpty else { return "No items" }
        
        let sortedItems = scheduleStore.items.sorted { $0.date < $1.date }
        let firstDate = sortedItems.first!.date
        let lastDate = sortedItems.last!.date
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "Range: \(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate))"
    }
    private var sampleItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sample Items (First 5)")
                .font(.headline)
                .foregroundColor(LogbookTheme.accentBlue)
            
            ForEach(Array(scheduleStore.items.prefix(5).enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Item \(index + 1):")
                        .font(.subheadline.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                    
                    Group {
                        Text("Trip Number: \(item.tripNumber)")
                        Text("Date: \(formatDate(item.date))")
                        Text("Departure: \(item.departure)")
                        Text("Arrival: \(item.arrival)")
                        Text("Block Out: \(formatDateTime(item.blockOut))")
                        Text("Block In: \(formatDateTime(item.blockIn))")
                        Text("Total Block Time: \(Int(item.totalBlockTime)) seconds (\(formatDuration(item.totalBlockTime)))")
                        Text("ID: \(item.id.uuidString)")
                        
                        // Check if there are additional properties we can access
                        Text("ID: \(item.id)")
                    }
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textSecondary)
                }
                .padding()
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(6)
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(8)
    }
    
    private var propertiesAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BasicScheduleItem Properties Analysis")
                .font(.headline)
                .foregroundColor(LogbookTheme.accentBlue)
            
            Text("Available Properties:")
                .font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("• id: UUID")
                Text("• tripNumber: String")
                Text("• date: Date")
                Text("• departure: String")
                Text("• arrival: String")
                Text("• blockOut: Date") 
                Text("• blockIn: Date")
                Text("• totalBlockTime: TimeInterval")
                Text("• status: FlightStatus")
            }
            .font(.caption)
            .foregroundColor(LogbookTheme.textSecondary)
            
            Text("❓ Questions:")
                .font(.subheadline.bold())
                .foregroundColor(LogbookTheme.warningYellow)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("1. Is 'blockOut' actually your duty start time?")
                Text("2. Do you have separate report/duty times?")
                Text("3. Are these reserve/on-call days or actual trips?")
                Text("4. Do we need to distinguish between:")
                Text("   - Reserve duty (on-call)")
                Text("   - Actual flights (block times)")
                Text("   - Training/ground duty")
            }
            .font(.caption)
            .foregroundColor(LogbookTheme.textTertiary)
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(8)
    }
    
    private var terminologySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminology Suggestions")
                .font(.headline)
                .foregroundColor(LogbookTheme.accentBlue)
            
            VStack(alignment: .leading, spacing: 8) {
                terminologyOption(
                    title: "Option 1: Reserve/On-Call Days",
                    description: "If these are reserve duties:",
                    terms: [
                        "On Call: 6:00 AM",
                        "Off Duty: 6:00 PM",
                        "Status: Reserve/Available"
                    ]
                )
                
                terminologyOption(
                    title: "Option 2: Actual Trips",
                    description: "If these are real flights:",
                    terms: [
                        "Report: 5:30 AM (crew report time)",
                        "Block Out: 6:30 AM (pushback)",
                        "Block In: 8:45 AM (arrival at gate)",
                        "Duty End: 9:15 AM"
                    ]
                )
                
                terminologyOption(
                    title: "Option 3: Mixed Duties",
                    description: "Smart detection based on data:",
                    terms: [
                        "If trip number exists → Show as flight",
                        "If no route → Show as reserve duty",
                        "If departure == arrival → Training/positioning"
                    ]
                )
            }
        }
        .padding()
        .background(LogbookTheme.cardBackground)
        .cornerRadius(8)
    }
    
    private func terminologyOption(title: String, description: String, terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(LogbookTheme.successGreen)
            
            Text(description)
                .font(.caption)
                .foregroundColor(LogbookTheme.textSecondary)
            
            ForEach(terms, id: \.self) { term in
                Text("• \(term)")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.textTertiary)
                    .padding(.leading, 8)
            }
        }
        .padding(8)
        .background(LogbookTheme.fieldBackground)
        .cornerRadius(4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Better Terminology Handler
struct SmartTerminologyHandler {
    
    enum DutyType {
        case reserve        // On-call/standby duty
        case flight        // Actual trip with route
        case training      // Same departure/arrival
        case positioning   // Deadhead/ferry
        case groundDuty    // Training, meetings, etc.
    }
    
    static func detectDutyType(for item: BasicScheduleItem) -> DutyType {
        // No route = reserve duty
        if item.departure.isEmpty || item.arrival.isEmpty {
            return .reserve
        }
        
        // Same departure and arrival = training
        if item.departure == item.arrival {
            return .training
        }
        
        // Trip number patterns (you might need to adjust these)
        if item.tripNumber.contains("TRN") || item.tripNumber.contains("SIM") {
            return .training
        }
        
        if item.tripNumber.contains("DH") || item.tripNumber.contains("POS") {
            return .positioning
        }
        
        // Has route and trip number = actual flight
        if !item.departure.isEmpty && !item.arrival.isEmpty && !item.tripNumber.isEmpty {
            return .flight
        }
        
        return .reserve
    }
    
    static func getDisplayTerms(for item: BasicScheduleItem) -> (startLabel: String, endLabel: String, dutyDescription: String) {
        let dutyType = detectDutyType(for: item)
        
        switch dutyType {
        case .reserve:
            return (
                startLabel: "On Call",
                endLabel: "Off Duty", 
                dutyDescription: "Reserve Duty"
            )
            
        case .flight:
            return (
                startLabel: "Report",
                endLabel: "Block In",
                dutyDescription: "Flight \(item.tripNumber)"
            )
            
        case .training:
            return (
                startLabel: "Report",
                endLabel: "Training End",
                dutyDescription: "Training"
            )
            
        case .positioning:
            return (
                startLabel: "Report", 
                endLabel: "Arrival",
                dutyDescription: "Positioning"
            )
            
        case .groundDuty:
            return (
                startLabel: "Report",
                endLabel: "Duty End",
                dutyDescription: "Ground Duty"
            )
        }
    }
}

// Usage example in your schedule row:
/*
let terms = SmartTerminologyHandler.getDisplayTerms(for: item)

Text("\(terms.startLabel): \(timeFormatter.string(from: item.blockOut))")
Text("\(terms.dutyDescription)")

if terms.startLabel == "Report" {
    Text("Block Out: \(timeFormatter.string(from: item.blockOut))")
    Text("Block In: \(timeFormatter.string(from: item.blockIn))")
}
*/

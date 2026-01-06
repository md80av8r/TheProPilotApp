//
//  FlowDelayView.swift
//  TheProPilotApp
//
//  Displays FAA NAS flow delays, ground stops, and airport closures.
//  Professional pilot-focused view for pre-departure briefing.
//

import SwiftUI

// MARK: - Airport Flow Status Banner (for AirportDetailView)

struct AirportFlowStatusBanner: View {
    let airportCode: String
    @State private var flowStatus: AirportFlowStatus?
    @State private var isLoading = true
    @State private var showDetails = false

    var body: some View {
        Group {
            if isLoading {
                flowLoadingView
            } else if let status = flowStatus, status.hasAnyDelay {
                flowAlertBanner(status: status)
            } else {
                flowClearBanner
            }
        }
        .task {
            await fetchFlowStatus()
        }
    }

    private var flowLoadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Checking flow status...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var flowClearBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("No Flow Delays")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.15))
        .cornerRadius(8)
    }

    private func flowAlertBanner(status: AirportFlowStatus) -> some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 10) {
                Image(systemName: status.statusIcon)
                    .font(.title3)
                    .foregroundColor(status.statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.statusText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(status.statusColor)

                    if let gdp = status.groundDelayProgram {
                        Text(gdp.reason.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let gs = status.groundStop {
                        Text(gs.reason.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(status.statusColor.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            FlowDelayDetailSheet(airportCode: airportCode, flowStatus: status)
        }
    }

    private func fetchFlowStatus() async {
        do {
            let status = try await NASStatusService.shared.getAirportStatus(for: airportCode)
            await MainActor.run {
                flowStatus = status
                isLoading = false
            }
        } catch {
            await MainActor.run {
                flowStatus = AirportFlowStatus(airportCode: airportCode, groundDelayProgram: nil, groundStop: nil, closure: nil)
                isLoading = false
            }
        }
    }
}

// MARK: - Flow Delay Detail Sheet

struct FlowDelayDetailSheet: View {
    let airportCode: String
    let flowStatus: AirportFlowStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Airport Header
                    airportHeader

                    // Status Cards
                    if let closure = flowStatus.closure {
                        closureCard(closure)
                    }

                    if let groundStop = flowStatus.groundStop {
                        groundStopCard(groundStop)
                    }

                    if let gdp = flowStatus.groundDelayProgram {
                        gdpCard(gdp)
                    }

                    // Pilot Notes
                    pilotNotesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Flow Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var airportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(airportCode)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("FAA NAS Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: flowStatus.statusIcon)
                .font(.system(size: 44))
                .foregroundColor(flowStatus.statusColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func closureCard(_ closure: AirportClosure) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.purple)
                Text("AIRPORT CLOSED")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }

            Divider()

            detailRow(label: "Reason", value: closure.reason.capitalized)
            detailRow(label: "Start", value: closure.startTime)
            detailRow(label: "Reopen", value: closure.reopenTime)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    private func groundStopCard(_ groundStop: GroundStop) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.red)
                Text("GROUND STOP")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }

            Divider()

            detailRow(label: "Reason", value: groundStop.reason.capitalized)

            if let endTime = groundStop.endTime {
                detailRow(label: "Expected End", value: endTime)
            }

            Text("All departures to this airport are halted until further notice.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func gdpCard(_ gdp: GroundDelayProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.orange)
                Text("GROUND DELAY PROGRAM")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            Divider()

            detailRow(label: "Reason", value: gdp.reason.capitalized)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Delay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(gdp.averageDelay)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Divider()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum Delay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(gdp.maxDelay)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding(.top, 4)

            Text("Expect EDCT assignment. Contact dispatch for your assigned departure time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var pilotNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pilot Notes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                bulletPoint("Monitor ATIS for updates")
                bulletPoint("Contact dispatch/flight following for EDCT")
                bulletPoint("Consider fuel for holding")
                bulletPoint("Brief alternate airport options")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Full NAS Status View (System-wide view)

struct NASStatusView: View {
    @StateObject private var nasService = NASStatusService.shared
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Last Updated
                    if let lastUpdated = nasService.lastUpdated {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Updated: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { Task { await refresh() } }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if nasService.isLoading {
                        ProgressView("Loading NAS Status...")
                            .padding(.top, 40)
                    } else if let status = nasService.currentStatus {
                        // Ground Stops (highest priority)
                        if !status.groundStops.isEmpty {
                            delaySection(
                                title: "Ground Stops",
                                icon: "stop.circle.fill",
                                color: .red,
                                count: status.groundStops.count
                            ) {
                                ForEach(status.groundStops) { stop in
                                    groundStopRow(stop)
                                }
                            }
                        }

                        // Ground Delay Programs
                        if !status.groundDelayPrograms.isEmpty {
                            delaySection(
                                title: "Ground Delay Programs",
                                icon: "clock.badge.exclamationmark.fill",
                                color: .orange,
                                count: status.groundDelayPrograms.count
                            ) {
                                ForEach(status.groundDelayPrograms) { gdp in
                                    gdpRow(gdp)
                                }
                            }
                        }

                        // Airspace Flow Programs
                        if !status.airspaceFlowPrograms.isEmpty {
                            delaySection(
                                title: "Airspace Flow Programs",
                                icon: "airplane",
                                color: .yellow,
                                count: status.airspaceFlowPrograms.count
                            ) {
                                ForEach(status.airspaceFlowPrograms) { afp in
                                    afpRow(afp)
                                }
                            }
                        }

                        // Airport Closures
                        if !status.airportClosures.isEmpty {
                            delaySection(
                                title: "Airport Closures",
                                icon: "xmark.circle.fill",
                                color: .purple,
                                count: status.airportClosures.count
                            ) {
                                ForEach(status.airportClosures) { closure in
                                    closureRow(closure)
                                }
                            }
                        }

                        // All Clear
                        if status.groundStops.isEmpty &&
                           status.groundDelayPrograms.isEmpty &&
                           status.airspaceFlowPrograms.isEmpty &&
                           status.airportClosures.isEmpty {
                            allClearView
                        }
                    } else {
                        noDataView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("NAS Flow Status")
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
        }
    }

    private func delaySection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(10)
            }

            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func groundStopRow(_ stop: GroundStop) -> some View {
        HStack {
            Text(stop.airportCode)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.reason.capitalized)
                    .font(.subheadline)
                if let endTime = stop.endTime {
                    Text("Until: \(endTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func gdpRow(_ gdp: GroundDelayProgram) -> some View {
        HStack {
            Text(gdp.airportCode)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(gdp.reason.capitalized)
                    .font(.subheadline)
                Text("Avg: \(gdp.averageDelay) | Max: \(gdp.maxDelay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func afpRow(_ afp: AirspaceFlowProgram) -> some View {
        HStack {
            Text(afp.controlElement)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(afp.reason.capitalized)
                    .font(.subheadline)
                Text("\(afp.activeTimeRange) | Avg: \(afp.averageDelay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func closureRow(_ closure: AirportClosure) -> some View {
        HStack {
            Text(closure.airportCode)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(closure.reason.capitalized)
                    .font(.subheadline)
                    .lineLimit(2)
                Text("Reopen: \(closure.reopenTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var allClearView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("NAS Operating Normally")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No ground stops, delays, or flow programs currently in effect.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Unable to Load Status")
                .font(.headline)

            Button("Try Again") {
                Task { await refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }

    private func refresh() async {
        isRefreshing = true
        do {
            _ = try await NASStatusService.shared.fetchStatus(forceRefresh: true)
        } catch {
            print("NAS Status refresh error: \(error)")
        }
        isRefreshing = false
    }
}

// MARK: - Compact Flow Status Badge (for lists)

struct FlowStatusBadge: View {
    let airportCode: String
    @State private var hasDelay = false
    @State private var status: AirportFlowStatus?

    var body: some View {
        Group {
            if let status = status, status.hasAnyDelay {
                HStack(spacing: 4) {
                    Image(systemName: status.statusIcon)
                        .font(.caption2)
                    if let gdp = status.groundDelayProgram, let mins = gdp.averageMinutes {
                        Text("\(mins)m")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(status.statusColor)
                .cornerRadius(6)
            }
        }
        .task {
            await checkStatus()
        }
    }

    private func checkStatus() async {
        do {
            let flowStatus = try await NASStatusService.shared.getAirportStatus(for: airportCode)
            await MainActor.run {
                status = flowStatus
                hasDelay = flowStatus.hasAnyDelay
            }
        } catch {
            // Silently fail for badge
        }
    }
}

// MARK: - Preview

#Preview {
    NASStatusView()
}

#Preview("Flow Banner") {
    VStack {
        AirportFlowStatusBanner(airportCode: "KJFK")
        AirportFlowStatusBanner(airportCode: "KLAX")
    }
    .padding()
}

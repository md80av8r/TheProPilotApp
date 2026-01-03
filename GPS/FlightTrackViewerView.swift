// FlightTrackViewerView.swift - Track Viewer UI
// Displays recorded flight tracks with map and statistics

import SwiftUI
import MapKit

// MARK: - Track List View
struct FlightTrackListView: View {
    @StateObject private var recorder = FlightTrackRecorder.shared
    @ObservedObject private var autoTimeSettings = AutoTimeSettings.shared
    @State private var tracks: [RecordedFlightTrack] = []
    @State private var selectedTrack: RecordedFlightTrack?
    @State private var showingTrackDetail = false

    var body: some View {
        NavigationView {
            List {
                // Recording Status Section (active recording indicator)
                if recorder.isRecording {
                    Section("Active Recording") {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                        .scaleEffect(1.5)
                                )

                            VStack(alignment: .leading) {
                                if let track = recorder.currentTrack {
                                    Text("\(track.flightNumber.isEmpty ? "Flight" : track.flightNumber): \(track.departure)-\(track.arrival)")
                                        .font(.headline)
                                }
                                Text("\(recorder.recordedPointsCount) points recorded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Manual stop button (in case auto-stop fails)
                            Button("Stop") {
                                _ = recorder.stopRecording()
                                loadTracks()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }

                // Recording Status Info (when not recording)
                if !recorder.isRecording {
                    Section {
                        HStack {
                            Image(systemName: autoTimeSettings.trackRecordingEnabled ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(autoTimeSettings.trackRecordingEnabled ? .green : .gray)

                            VStack(alignment: .leading) {
                                Text(autoTimeSettings.trackRecordingEnabled ? "Auto-Recording Enabled" : "Auto-Recording Disabled")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(autoTimeSettings.trackRecordingEnabled ?
                                     "Recording will start automatically on takeoff" :
                                     "Enable in Auto Time Logging settings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }

                // Recorded Tracks Section
                if tracks.isEmpty && !recorder.isRecording {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "map.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)

                            Text("No Recorded Tracks")
                                .font(.headline)

                            Text("Flight tracks will appear here after recording. Enable track recording in Auto Time Logging settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                } else if !tracks.isEmpty {
                    Section("Recorded Tracks (\(tracks.count))") {
                        ForEach(tracks) { track in
                            TrackRowView(track: track)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTrack = track
                                    showingTrackDetail = true
                                }
                        }
                        .onDelete(perform: deleteTracks)
                    }
                }
            }
            .navigationTitle("Flight Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadTracks) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear(perform: loadTracks)
            .sheet(isPresented: $showingTrackDetail) {
                if let track = selectedTrack {
                    FlightTrackDetailView(track: track)
                }
            }
        }
    }

    private func loadTracks() {
        tracks = recorder.getAllTracks()
    }

    private func deleteTracks(at offsets: IndexSet) {
        for index in offsets {
            let track = tracks[index]
            recorder.deleteTrack(for: track.legId)
        }
        tracks.remove(atOffsets: offsets)
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: RecordedFlightTrack

    var body: some View {
        HStack(spacing: 12) {
            // Route indicator
            VStack(spacing: 2) {
                Text(track.departure)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))

                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(track.arrival)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .frame(width: 50)

            // Flight info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.flightNumber.isEmpty ? "Flight" : track.flightNumber)
                    .font(.headline)

                Text(formatDate(track.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.0f", track.totalDistanceNM)) NM")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(track.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(track.trackPoints.count) pts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Track Detail View
struct FlightTrackDetailView: View {
    let track: RecordedFlightTrack
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var showingExportOptions = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var selectedExportFormat: ExportFormat = .gpx

    enum ExportFormat: String, CaseIterable {
        case gpx = "GPX"
        case kml = "KML"

        var icon: String {
            switch self {
            case .gpx: return "doc.text"
            case .kml: return "globe"
            }
        }

        var description: String {
            switch self {
            case .gpx: return "Standard GPS exchange format"
            case .kml: return "Google Earth format with 3D view"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Map View
                    TrackMapView(track: track)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    // Flight Info Card
                    GroupBox("Flight Info") {
                        VStack(spacing: 12) {
                            TrackInfoRow(label: "Route", value: "\(track.departure) → \(track.arrival)")
                            TrackInfoRow(label: "Flight", value: track.flightNumber.isEmpty ? "—" : track.flightNumber)
                            TrackInfoRow(label: "Date", value: formatDate(track.startTime))
                            TrackInfoRow(label: "Duration", value: track.durationFormatted)

                            // Detected times
                            if let offTime = track.detectedTakeoffTimeString {
                                TrackInfoRow(label: "Takeoff (OFF)", value: offTime)
                            }
                            if let onTime = track.detectedLandingTimeString {
                                TrackInfoRow(label: "Landing (ON)", value: onTime)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Statistics Card
                    GroupBox("Statistics") {
                        VStack(spacing: 12) {
                            TrackInfoRow(label: "Distance", value: "\(String(format: "%.1f", track.totalDistanceNM)) NM")
                            TrackInfoRow(label: "Track Points", value: "\(track.trackPoints.count)")
                            TrackInfoRow(label: "Max Altitude", value: "\(Int(track.maxAltitude)) ft")
                            TrackInfoRow(label: "Max Speed", value: "\(Int(track.maxSpeed)) kts")
                            TrackInfoRow(label: "Avg Speed", value: "\(Int(track.averageSpeed)) kts")
                        }
                    }
                    .padding(.horizontal)

                    // Altitude/Speed Profile (simplified)
                    if track.trackPoints.count > 10 {
                        GroupBox("Altitude Profile") {
                            AltitudeProfileView(trackPoints: track.trackPoints)
                                .frame(height: 100)
                        }
                        .padding(.horizontal)
                    }

                    // Export & Viewing Options
                    GroupBox("Export & View") {
                        VStack(spacing: 12) {
                            // Format selector
                            HStack {
                                ForEach(ExportFormat.allCases, id: \.self) { format in
                                    Button(action: { selectedExportFormat = format }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: format.icon)
                                                .font(.title2)
                                            Text(format.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedExportFormat == format ? Color.blue : Color.gray.opacity(0.2))
                                        )
                                        .foregroundColor(selectedExportFormat == format ? .white : .primary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            Text(selectedExportFormat.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            // Export/Share Button
                            Button(action: exportAndShare) {
                                Label("Share \(selectedExportFormat.rawValue) File", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            // Open in Google Earth (for KML)
                            if selectedExportFormat == .kml {
                                Button(action: openInGoogleEarth) {
                                    Label("Open in Google Earth", systemImage: "globe.americas.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                            }

                            // Open in Maps (for both formats)
                            Button(action: openInMaps) {
                                Label("View in Apple Maps", systemImage: "map.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // Show error if export failed
                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { selectedExportFormat = .gpx; exportAndShare() }) {
                            Label("Share GPX", systemImage: "doc.text")
                        }
                        Button(action: { selectedExportFormat = .kml; exportAndShare() }) {
                            Label("Share KML", systemImage: "globe")
                        }
                        Divider()
                        Button(action: openInGoogleEarth) {
                            Label("Open in Google Earth", systemImage: "globe.americas.fill")
                        }
                        Button(action: openInMaps) {
                            Label("Open in Apple Maps", systemImage: "map")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    TrackShareSheet(items: [url])
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to create file")
                            .font(.headline)
                        Button("Dismiss") {
                            showingShareSheet = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportAndShare() {
        exportError = nil
        let recorder = FlightTrackRecorder.shared

        let url: URL?
        switch selectedExportFormat {
        case .gpx:
            url = recorder.exportTrackToGPX(track)
        case .kml:
            url = recorder.exportTrackToKML(track)
        }

        if let validURL = url {
            exportURL = validURL
            showingShareSheet = true
        } else {
            exportError = "Failed to export \(selectedExportFormat.rawValue) file. Please try again."
        }
    }

    private func openInGoogleEarth() {
        // Export KML first
        guard let kmlURL = FlightTrackRecorder.shared.exportTrackToKML(track) else {
            exportError = "Failed to create KML file"
            return
        }

        // Try Google Earth app URL scheme
        if let googleEarthURL = URL(string: "comgoogleearth://kml?url=\(kmlURL.absoluteString)") {
            if UIApplication.shared.canOpenURL(googleEarthURL) {
                UIApplication.shared.open(googleEarthURL)
                return
            }
        }

        // Fallback: share the KML file so user can open in Google Earth
        exportURL = kmlURL
        showingShareSheet = true
    }

    private func openInMaps() {
        // Get center point and show route in Apple Maps
        guard let firstPoint = track.trackPoints.first,
              let lastPoint = track.trackPoints.last else {
            return
        }

        // Create a maps URL that shows the route
        let departureLat = firstPoint.latitude
        let departureLon = firstPoint.longitude
        let arrivalLat = lastPoint.latitude
        let arrivalLon = lastPoint.longitude

        // Apple Maps URL with directions
        if let mapsURL = URL(string: "maps://?saddr=\(departureLat),\(departureLon)&daddr=\(arrivalLat),\(arrivalLon)") {
            UIApplication.shared.open(mapsURL)
        }
    }
}

// MARK: - Track Info Row
struct TrackInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Track Map View
struct TrackMapView: View {
    let track: RecordedFlightTrack

    private var departurePoint: RecordedTrackPoint? {
        track.trackPoints.first
    }

    private var arrivalPoint: RecordedTrackPoint? {
        track.trackPoints.last
    }

    var body: some View {
        Map {
            // Track line using MapPolyline
            MapPolyline(coordinates: track.trackPoints.map { $0.coordinate })
                .stroke(.blue, lineWidth: 3)

            // Departure marker
            if let departure = departurePoint {
                Annotation(track.departure, coordinate: departure.coordinate) {
                    Image(systemName: "airplane.departure")
                        .foregroundColor(.green)
                        .padding(4)
                        .background(Circle().fill(.white))
                }
            }

            // Arrival marker
            if let arrival = arrivalPoint {
                Annotation(track.arrival, coordinate: arrival.coordinate) {
                    Image(systemName: "airplane.arrival")
                        .foregroundColor(.red)
                        .padding(4)
                        .background(Circle().fill(.white))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private func calculateRegion() -> MKCoordinateRegion {
        guard !track.trackPoints.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.0, longitude: -95.0),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }

        let lats = track.trackPoints.map { $0.latitude }
        let lons = track.trackPoints.map { $0.longitude }

        let minLat = lats.min() ?? 40.0
        let maxLat = lats.max() ?? 40.0
        let minLon = lons.min() ?? -95.0
        let maxLon = lons.max() ?? -95.0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.05, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.05, (maxLon - minLon) * 1.3)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Altitude Profile View
struct AltitudeProfileView: View {
    let trackPoints: [RecordedTrackPoint]

    private var sampledPoints: [RecordedTrackPoint] {
        // Sample every Nth point for smooth display
        let step = max(1, trackPoints.count / 50)
        return stride(from: 0, to: trackPoints.count, by: step).map { trackPoints[$0] }
    }

    private var maxAlt: Double {
        trackPoints.map { $0.altitudeFeet }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard sampledPoints.count > 1 else { return }

                let width = geometry.size.width
                let height = geometry.size.height
                let xStep = width / CGFloat(sampledPoints.count - 1)

                path.move(to: CGPoint(
                    x: 0,
                    y: height - CGFloat(sampledPoints[0].altitudeFeet / maxAlt) * height
                ))

                for (index, point) in sampledPoints.enumerated() {
                    let x = CGFloat(index) * xStep
                    let y = height - CGFloat(point.altitudeFeet / maxAlt) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

// MARK: - Track Share Sheet
struct TrackShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Recording Control View (for embedding in other views)
struct TrackRecordingControlView: View {
    @ObservedObject var recorder = FlightTrackRecorder.shared
    let legId: UUID
    let departure: String
    let arrival: String
    let flightNumber: String

    var body: some View {
        GroupBox {
            HStack {
                if recorder.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading) {
                        Text("Recording Track")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(recorder.recordedPointsCount) points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Stop") {
                        _ = recorder.stopRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Image(systemName: "location.circle")
                        .foregroundColor(.blue)

                    Text("Track Recording")
                        .font(.subheadline)

                    Spacer()

                    Button("Start") {
                        recorder.startRecording(
                            for: legId,
                            departure: departure,
                            arrival: arrival,
                            flightNumber: flightNumber
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// MARK: - Previews
struct FlightTrackListView_Previews: PreviewProvider {
    static var previews: some View {
        FlightTrackListView()
    }
}

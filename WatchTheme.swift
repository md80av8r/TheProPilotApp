// WatchTheme.swift
// Modern, consistent design system for Apple Watch app

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchTheme {
    // MARK: - Colors
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let accentOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let accentRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let accentPurple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let accentCyan = Color(red: 0.2, green: 0.78, blue: 0.85)
    static let accentYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    
    // Background colors
    static let background = Color.black
    static let cardBackground = Color(white: 0.1)
    static let secondaryBackground = Color(white: 0.15)
    
    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    static let tertiaryText = Color(white: 0.6)
    
    // Status colors
    static let success = accentGreen
    static let warning = accentOrange
    static let error = accentRed
    static let info = primaryBlue
    
    // MARK: - Typography
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 24, weight: .semibold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let callout = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let caption2 = Font.system(size: 11, weight: .regular)
    
    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
    
    // MARK: - Corner Radius
    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 14
    
    // MARK: - Shadow
    static func cardShadow() -> some View {
        EmptyView()
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Card Style
struct WatchCardStyle: ViewModifier {
    var backgroundColor: Color = WatchTheme.cardBackground
    var padding: CGFloat = WatchTheme.spacingM
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(WatchTheme.radiusM)
    }
}

extension View {
    func watchCardStyle(backgroundColor: Color = WatchTheme.cardBackground, padding: CGFloat = WatchTheme.spacingM) -> some View {
        modifier(WatchCardStyle(backgroundColor: backgroundColor, padding: padding))
    }
}

// MARK: - Status Badge
struct WatchStatusBadge: View {
    let text: String
    let color: Color
    let icon: String?
    
    init(text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .cornerRadius(6)
    }
}

// MARK: - Icon Button
struct WatchIconButton: View {
    let icon: String
    let title: String?
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String? = nil, color: Color = WatchTheme.primaryBlue, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action()
            #if os(watchOS)
            WKInterfaceDevice.current().play(.click)
            #endif
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                if let title = title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WatchTheme.spacingM)
            .background(color)
            .cornerRadius(WatchTheme.radiusM)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Metric Display
struct WatchMetricDisplay: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(WatchTheme.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(WatchTheme.caption2)
                .foregroundColor(WatchTheme.secondaryText)
        }
    }
}

// MARK: - Info Row
struct WatchInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(WatchTheme.callout)
                .foregroundColor(WatchTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(WatchTheme.callout)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Section Header
struct WatchSectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    init(icon: String, title: String, color: Color = WatchTheme.primaryBlue) {
        self.icon = icon
        self.title = title
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(WatchTheme.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, WatchTheme.spacingS)
    }
}

// MARK: - Loading View
struct WatchLoadingView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            if let message = message {
                Text(message)
                    .font(WatchTheme.caption)
                    .foregroundColor(WatchTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct WatchEmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(WatchTheme.secondaryText)
            
            Text(title)
                .font(WatchTheme.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if let message = message {
                Text(message)
                    .font(WatchTheme.caption)
                    .foregroundColor(WatchTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    action()
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }) {
                    Text(actionTitle)
                        .font(WatchTheme.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(WatchTheme.primaryBlue)
                        .cornerRadius(WatchTheme.radiusS)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Timer Display
struct WatchTimerDisplay: View {
    let timeString: String
    let isRunning: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(timeString)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                
                Text(isRunning ? "Running" : "Stopped")
                    .font(WatchTheme.caption)
                    .foregroundColor(WatchTheme.secondaryText)
            }
        }
    }
}

// MARK: - Divider with Label
struct WatchLabeledDivider: View {
    let label: String
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text(label)
                .font(WatchTheme.caption2)
                .foregroundColor(WatchTheme.secondaryText)
                .padding(.horizontal, 8)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, WatchTheme.spacingS)
    }
}

// MARK: - Alert Card
struct WatchAlertCard: View {
    let icon: String
    let title: String
    let message: String
    let type: AlertType
    
    enum AlertType {
        case info, warning, error, success
        
        var color: Color {
            switch self {
            case .info: return WatchTheme.info
            case .warning: return WatchTheme.warning
            case .error: return WatchTheme.error
            case .success: return WatchTheme.success
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(type.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WatchTheme.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(WatchTheme.caption)
                    .foregroundColor(WatchTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WatchTheme.spacingM)
        .background(type.color.opacity(0.2))
        .cornerRadius(WatchTheme.radiusM)
    }
}

// MARK: - Flight Time Entry Grid
struct WatchFlightTimeEntry: View {
    @Binding var outTime: Date?
    @Binding var offTime: Date?
    @Binding var onTime: Date?
    @Binding var inTime: Date?
    
    let onAddLeg: () -> Void
    let onEndTrip: () -> Void
    
    @State private var showingEndTripConfirmation = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Row 1: OUT and OFF
            HStack(spacing: 8) {
                TimeEntryButton(
                    label: "OUT",
                    time: $outTime,
                    color: .blue
                )
                
                TimeEntryButton(
                    label: "OFF",
                    time: $offTime,
                    color: .green
                )
            }
            
            // Row 2: ON and IN
            HStack(spacing: 8) {
                TimeEntryButton(
                    label: "ON",
                    time: $onTime,
                    color: .orange
                )
                
                TimeEntryButton(
                    label: "IN",
                    time: $inTime,
                    color: .purple
                )
            }
            
            // Row 3: Flight and Block Time (shown when leg complete)
            if isLegComplete {
                HStack(spacing: 8) {
                    TimeDisplayBox(
                        label: "FLT",
                        duration: flightMinutes,
                        color: .green
                    )
                    
                    TimeDisplayBox(
                        label: "BLK",
                        duration: blockMinutes,
                        color: .blue
                    )
                }
            }
            
            // Row 4: Action Buttons
            if isLegComplete {
                HStack(spacing: 8) {
                    Button(action: onAddLeg) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Leg")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(WatchTheme.accentGreen)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingEndTripConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("End Trip")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(WatchTheme.accentRed)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .alert("End Trip?", isPresented: $showingEndTripConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Trip", role: .destructive) {
                onEndTrip()
            }
        } message: {
            Text("Are you sure you want to end this trip? All times will be synced to your iPhone.")
        }
    }
    
    // MARK: - Computed Properties
    private var isLegComplete: Bool {
        outTime != nil && offTime != nil && onTime != nil && inTime != nil
    }
    
    private var flightMinutes: Int {
        guard let off = offTime, let on = onTime else { return 0 }
        return Int(on.timeIntervalSince(off) / 60)
    }
    
    private var blockMinutes: Int {
        guard let out = outTime, let in_ = inTime else { return 0 }
        return Int(in_.timeIntervalSince(out) / 60)
    }
}

// MARK: - Time Entry Button
private struct TimeEntryButton: View {
    let label: String
    @Binding var time: Date?
    let color: Color
    
    @State private var showingPicker = false
    @State private var tempTime = Date()
    
    var body: some View {
        Button(action: {
            // Tap to set current time
            time = Date()
            #if os(watchOS)
            WKInterfaceDevice.current().play(.click)
            #endif
        }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if let time = time {
                    Text(formatTime(time))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                } else {
                    Text("--:--")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(time != nil ? color.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    tempTime = time ?? Date()
                    showingPicker = true
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }
        )
        .sheet(isPresented: $showingPicker) {
            VStack(spacing: 16) {
                Text("Edit \(label)")
                    .font(.headline)
                
                DatePicker(
                    "",
                    selection: $tempTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingPicker = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Set") {
                        time = tempTime
                        showingPicker = false
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.success)
                        #endif
                    }
                    .foregroundColor(.green)
                }
            }
            .padding()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Time Display Box
private struct TimeDisplayBox: View {
    let label: String
    let duration: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(formatDuration(duration))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}

// MARK: - Preview
struct WatchTheme_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Badges
                HStack {
                    WatchStatusBadge(text: "Active", color: WatchTheme.success, icon: "checkmark")
                    WatchStatusBadge(text: "Warning", color: WatchTheme.warning, icon: "exclamationmark.triangle")
                }
                
                // Icon Buttons
                HStack {
                    WatchIconButton(icon: "play.fill", title: "Start", color: WatchTheme.success) {}
                    WatchIconButton(icon: "stop.fill", title: "Stop", color: WatchTheme.error) {}
                }
                
                // Metric Display
                WatchMetricDisplay(
                    icon: "clock.fill",
                    label: "Duty Time",
                    value: "8:45",
                    color: WatchTheme.primaryBlue
                )
                .watchCardStyle()
                
                // Info Rows
                VStack(spacing: 8) {
                    WatchInfoRow(icon: "airplane", label: "Flight", value: "AA1234", color: WatchTheme.primaryBlue)
                    WatchInfoRow(icon: "location.fill", label: "Route", value: "DFW-LAX", color: WatchTheme.accentGreen)
                }
                .watchCardStyle()
                
                // Timer Display
                WatchTimerDisplay(timeString: "02:34:56", isRunning: true, color: WatchTheme.primaryBlue)
                    .watchCardStyle()
                
                // Alert Cards
                WatchAlertCard(
                    icon: "checkmark.circle.fill",
                    title: "Success",
                    message: "Trip completed successfully",
                    type: .success
                )
                
                WatchAlertCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Warning",
                    message: "Phone connection lost",
                    type: .warning
                )
            }
            .padding()
        }
        .background(Color.black)
    }
}

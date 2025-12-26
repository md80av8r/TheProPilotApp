//
//  FlightCalculatorView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//

import SwiftUI

// MARK: - Main Calculator View
struct FlightCalculatorView: View {
    @State private var selectedCalculator: CalculatorType = .crosswind // Default to crosswind to show changes
    
    // Detect if running on iPad
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    enum CalculatorType: String, CaseIterable {
        case fuelConversion = "Fuel Conversion"
        case fuelUplift = "Fuel Uplift Check"
        case temperature = "Temperature"
        case crosswind = "Crosswind"
        
        var icon: String {
            switch self {
            case .fuelConversion: return "fuelpump.fill"
            case .fuelUplift: return "checkmark.circle.fill"
            case .temperature: return "thermometer"
            case .crosswind: return "wind"
            }
        }
        
        var color: Color {
            switch self {
            case .fuelConversion: return LogbookTheme.accentGreen
            case .fuelUplift: return LogbookTheme.accentBlue
            case .temperature: return LogbookTheme.accentOrange
            case .crosswind: return Color.purple
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isPad {
                    // MARK: iPad Layout (Content Top, Icons Bottom)
                    mainContent
                    
                    Divider()
                        .background(LogbookTheme.navyLight)
                    
                    calculatorSelector
                        .padding(.bottom, 10) // Extra padding for home indicator
                } else {
                    // MARK: iPhone Layout (Icons Top, Content Bottom)
                    calculatorSelector
                    
                    mainContent
                    
                    Spacer()
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Flight Calculators")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack) // Forces full screen on iPad instead of SplitView
    }
    
    // MARK: - Subviews
    
    private var calculatorSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CalculatorType.allCases, id: \.self) { type in
                    CalculatorTypeButton(
                        type: type,
                        isSelected: selectedCalculator == type,
                        action: { selectedCalculator = type }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            // On iPad, center the icons. On iPhone, left align for scrolling.
            .frame(maxWidth: isPad ? .infinity : nil, alignment: isPad ? .center : .leading)
        }
        .background(LogbookTheme.navyLight)
    }
    
    private var mainContent: some View {
        Group {
            switch selectedCalculator {
            case .fuelConversion:
                FuelConversionCalculator()
            case .fuelUplift:
                FuelUpliftCalculator()
            case .temperature:
                TemperatureCalculator()
            case .crosswind:
                CrosswindCalculator()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LogbookTheme.navy)
    }
}

// MARK: - Calculator Type Button
struct CalculatorTypeButton: View {
    let type: FlightCalculatorView.CalculatorType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(width: 110, height: 90)
            .background(isSelected ? type.color : LogbookTheme.fieldBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(type.color, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Crosswind Calculator (Redesigned)
struct CrosswindCalculator: View {
    // Changed to Int/Double for Pickers
    @State private var runwayHeading: String = "360" // Keep as string for text input
    @State private var windDirection: Int = 330
    @State private var windSpeed: Int = 20
    
    // Derived values
    private var rwyHeadingDouble: Double { Double(runwayHeading) ?? 0 }
    private var windDirDouble: Double { Double(windDirection) }
    private var windSpdDouble: Double { Double(windSpeed) }
    
    private var headwindComponent: Double {
        let angleDiff = windDirDouble - rwyHeadingDouble
        let angleRad = angleDiff * .pi / 180.0
        return windSpdDouble * cos(angleRad)
    }
    
    private var crosswindComponent: Double {
        let angleDiff = windDirDouble - rwyHeadingDouble
        let angleRad = angleDiff * .pi / 180.0
        return windSpdDouble * sin(angleRad)
    }
    
    // Wind Direction options (10 deg increments)
    private let windDirections = Array(stride(from: 10, through: 360, by: 10))
    // Wind Speed options
    private let windSpeeds = Array(0...99)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // MARK: Input Section
                VStack(spacing: 0) {
                    // Runway Input (Text Field)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "airplane.departure")
                                    .foregroundColor(.white)
                                Text("Runway Heading")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            TextField("360", text: $runwayHeading)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    
                    Divider().background(LogbookTheme.navy)
                    
                    // Wind Pickers (Wheel Style)
                    HStack(spacing: 0) {
                        // Wind Direction Picker
                        VStack(spacing: 5) {
                            Text("Wind Direction")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.top, 8)
                            
                            Picker("Direction", selection: $windDirection) {
                                ForEach(windDirections, id: \.self) { dir in
                                    Text(String(format: "%03d°", dir))
                                        .foregroundColor(.white)
                                        .tag(dir)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                        .frame(maxWidth: .infinity)
                        .background(LogbookTheme.navyLight)
                        
                        // Separator
                        Rectangle()
                            .fill(LogbookTheme.navy)
                            .frame(width: 1)
                            .frame(height: 100)
                        
                        // Wind Speed Picker
                        VStack(spacing: 5) {
                            Text("Wind Speed")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.top, 8)
                            
                            Picker("Speed", selection: $windSpeed) {
                                ForEach(windSpeeds, id: \.self) { speed in
                                    Text("\(speed) kts")
                                        .foregroundColor(.white)
                                        .tag(speed)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                        .frame(maxWidth: .infinity)
                        .background(LogbookTheme.navyLight)
                    }
                }
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: Visualization (North Up Map)
                ZStack {
                    // 1. Background Compass Rose
                    CompassRoseView()
                        .frame(height: 300)
                    
                    // 2. Animated Wind Layer (Organic Flow)
                    // The masking circle keeps particles inside the compass
                    WindParticlesView(speed: windSpdDouble)
                        .id("wind-\(windDirection)-\(windSpeed)") // Force reset on change for smooth transition
                        .mask(Circle().padding(4))
                        .rotationEffect(.degrees(windDirDouble)) // Rotates the whole flow field
                        .frame(height: 300)
                        .opacity(windSpdDouble > 0 ? 1.0 : 0)

                    // 3. The Runway (Rotated to Heading)
                    RunwayGraphic(heading: rwyHeadingDouble)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(rwyHeadingDouble))
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    // 4. Wind Arrow (Vector)
                    WindArrowGraphic(direction: windDirDouble, speed: windSpdDouble)
                        .frame(width: 260, height: 260)
                }
                .padding(.vertical)
                
                // MARK: Pilot Control Input (Yoke Visualization)
                PilotYokeView(crosswind: crosswindComponent)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                // MARK: Data Cards
                VStack(spacing: 12) {
                    // Headwind/Tailwind
                    ComponentCard(
                        title: headwindComponent >= 0 ? "HEADWIND" : "TAILWIND",
                        value: abs(headwindComponent),
                        color: headwindComponent >= 0 ? LogbookTheme.accentGreen : .red,
                        icon: headwindComponent >= 0 ? "arrow.down.to.line" : "arrow.up.to.line",
                        subtext: headwindComponent >= 0 ? "Favorable for takeoff/landing" : "Increases ground roll"
                    )
                    
                    // Crosswind
                    ComponentCard(
                        title: "CROSSWIND",
                        value: abs(crosswindComponent),
                        color: LogbookTheme.accentOrange,
                        icon: "arrow.left.and.right",
                        subtext: crosswindComponent > 0 ? "From the RIGHT" : (crosswindComponent < 0 ? "From the LEFT" : "No Crosswind"),
                        isWarning: abs(crosswindComponent) > 15
                    )
                }
                .padding(.horizontal)
                
                // MARK: Reference Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wind Components")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    HStack(spacing: 0) {
                        ComponentAngleVisual(angle: 30, pct: "50%")
                        ComponentAngleVisual(angle: 45, pct: "70%")
                        ComponentAngleVisual(angle: 60, pct: "87%")
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .background(LogbookTheme.navy)
        .onTapGesture {
            hideKeyboard()
        }
    }
}

// MARK: - Pilot Yoke Visualization
struct PilotYokeView: View {
    let crosswind: Double
    
    // Animation properties
    // Max rotation (90 degrees) at a "strong" crosswind (e.g., 30kts)
    var rotationAngle: Double {
        let maxRotation: Double = 80
        let maxCrosswindRef: Double = 30
        
        // Clamp the ratio between -1 and 1
        let ratio = max(-1.0, min(1.0, crosswind / maxCrosswindRef))
        
        // If crosswind is positive (Right), we turn RIGHT (Positive Angle) to correct
        // If crosswind is negative (Left), we turn LEFT (Negative Angle) to correct
        return ratio * maxRotation
    }
    
    var body: some View {
        HStack {
            // Yoke Graphic
            ZStack {
                // Background Circle (Panel)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(white: 0.15), Color(white: 0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                // The Control Yoke
                YokeShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(white: 0.3), Color(white: 0.15)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 50)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    // Center Hub
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "airplane")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 10, height: 10)
                                    .foregroundColor(.gray)
                            )
                    )
                    // The Rotation Logic
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: rotationAngle)
            }
            .padding(.trailing, 12)
            
            // Text Instructions
            VStack(alignment: .leading, spacing: 4) {
                Text("Crosswind Correction")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    if abs(crosswind) < 2 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Controls Neutral")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: crosswind > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left")
                            .foregroundColor(.orange)
                        
                        Text("Turn \(crosswind > 0 ? "RIGHT" : "LEFT") into wind")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                }
                
                Text("Apply aileron into the wind during takeoff/landing roll.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
    }
}

// A simple shape approximating a Pilot Yoke/Wheel
struct YokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // Center Hub Area
        let centerRect = CGRect(x: w*0.35, y: h*0.3, width: w*0.3, height: h*0.4)
        path.addEllipse(in: centerRect)
        
        // Left Handle (Curved path)
        path.move(to: CGPoint(x: w*0.35, y: h*0.5)) // Start at hub left
        path.addCurve(
            to: CGPoint(x: 0, y: h*0.2), // Top left tip
            control1: CGPoint(x: w*0.1, y: h*0.5),
            control2: CGPoint(x: 0, y: h*0.4)
        )
        // Thickness for handle
        path.addLine(to: CGPoint(x: w*0.1, y: h*0.2))
        path.addCurve(
            to: CGPoint(x: w*0.38, y: h*0.4),
            control1: CGPoint(x: w*0.15, y: h*0.4),
            control2: CGPoint(x: w*0.2, y: h*0.45)
        )
        
        // Right Handle (Mirrored)
        path.move(to: CGPoint(x: w*0.65, y: h*0.5)) // Start at hub right
        path.addCurve(
            to: CGPoint(x: w, y: h*0.2), // Top right tip
            control1: CGPoint(x: w*0.9, y: h*0.5),
            control2: CGPoint(x: w, y: h*0.4)
        )
        path.addLine(to: CGPoint(x: w*0.9, y: h*0.2))
        path.addCurve(
            to: CGPoint(x: w*0.62, y: h*0.4),
            control1: CGPoint(x: w*0.85, y: h*0.4),
            control2: CGPoint(x: w*0.8, y: h*0.45)
        )
        
        return path
    }
}

// MARK: - Visualization Components

struct CompassRoseView: View {
    var body: some View {
        ZStack {
            // Dark Background
            Circle()
                .fill(LogbookTheme.navyLight)
            
            // Ticks
            ForEach(0..<72) { tick in
                Rectangle()
                    .fill(tick % 18 == 0 ? Color.white : (tick % 6 == 0 ? Color.gray : Color.gray.opacity(0.3)))
                    .frame(width: tick % 18 == 0 ? 3 : 1, height: tick % 18 == 0 ? 15 : (tick % 6 == 0 ? 10 : 5))
                    .offset(y: -135)
                    .rotationEffect(.degrees(Double(tick) * 5))
            }
            
            // Labels (N, S, E, W)
            ForEach(0..<4) { i in
                VStack {
                    Text(["N", "E", "S", "W"][i])
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(i == 0 ? LogbookTheme.accentOrange : .gray)
                        .offset(y: -115)
                    Spacer()
                }
                .rotationEffect(.degrees(Double(i) * 90))
            }
        }
    }
}

struct RunwayGraphic: View {
    let heading: Double
    
    // Calculate runway numbers (reciprocals)
    var runwayNum: String {
        let num = Int(round(heading / 10.0))
        return String(format: "%02d", num == 0 ? 36 : num)
    }
    
    var reciprocalNum: String {
        var num = Int(round(heading / 10.0)) - 18
        if num <= 0 { num += 36 }
        return String(format: "%02d", num)
    }
    
    var body: some View {
        ZStack {
            // Asphalt
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.2)) // Dark asphalt color
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2) // Runway side stripes
                )
                .frame(width: 40, height: 240)
            
            // Centerline (Dashed)
            VStack(spacing: 12) {
                ForEach(0..<6) { _ in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 20)
                }
            }
            
            // Threshold Markings ("Piano Keys") & Numbers
            VStack {
                // Top (Reciprocal)
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        ForEach(0..<4) { _ in Rectangle().fill(.white).frame(width: 2, height: 10) }
                    }
                    Text(runwayNum) // Actually displayed at top, visuals are rotated by parent
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(180)) // Flip text so it reads correctly when looking "down"
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Bottom (Selected Heading)
                VStack(spacing: 2) {
                    Text(reciprocalNum)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    HStack(spacing: 3) {
                        ForEach(0..<4) { _ in Rectangle().fill(.white).frame(width: 2, height: 10) }
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }
}

struct WindArrowGraphic: View {
    let direction: Double
    let speed: Double
    
    var body: some View {
        ZStack {
            // Only show if we have wind
            if speed > 0 {
                // The Arrow
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 60)
                    
                    // Wind Speed Label Bubble
                    Text("\(Int(speed))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.blue))
                }
                .offset(y: -80) // Push it out to the edge of the circle
                .rotationEffect(.degrees(direction)) // Rotate around center
            }
        }
    }
}

// MARK: - New ForeFlight-Style Wind
struct WindParticlesView: View {
    let speed: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Create a field of "Comet" particles
                // We use random offsets and delays to create the "organic" non-parallel look
                ForEach(0..<25, id: \.self) { i in
                    WindParticle(
                        speed: speed,
                        delay: Double.random(in: 0...2.0),
                        width: geo.size.width,
                        height: geo.size.height,
                        xOffset: CGFloat.random(in: -geo.size.width/2...geo.size.width/2)
                    )
                }
            }
        }
    }
}

struct WindParticle: View {
    let speed: Double
    let delay: Double
    let width: CGFloat
    let height: CGFloat
    let xOffset: CGFloat
    
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        // "Comet" Shape: A line with a tapered opacity and width
        // Head is at the bottom (movement direction), Tail at top
        CometShape()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.5)]),
                    startPoint: .top, // Tail (faded)
                    endPoint: .bottom // Head (solid)
                )
            )
            .frame(width: 4, height: 80) // Comet dimensions
            .position(x: width/2 + xOffset, y: -100 + (height + 200) * progress)
            .onAppear {
                // Calculate animation duration based on speed
                // Faster wind = shorter duration (quicker movement)
                let baseDuration = 3.0
                let speedFactor = max(0.2, 1.0 - (speed / 100.0)) // Cap speed effect
                let duration = baseDuration * speedFactor
                
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    progress = 1.0
                }
            }
    }
}

// Custom Shape for the "Comet" look (Tapered Tail)
struct CometShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Head (Bottom) - Wider
        let headWidth = rect.width
        let tailWidth = rect.width * 0.2 // Tail is 20% of head width
        
        // Points
        let headLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let headRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let tailLeft = CGPoint(x: rect.midX - tailWidth/2, y: rect.minY)
        let tailRight = CGPoint(x: rect.midX + tailWidth/2, y: rect.minY)
        
        // Draw trapezoid/comet
        path.move(to: headLeft)
        path.addLine(to: headRight)
        path.addLine(to: tailRight) // Taper to tail
        path.addLine(to: tailLeft)
        path.closeSubpath()
        
        // Add a rounded cap at the head for that "droplet" look
        path.addArc(center: CGPoint(x: rect.midX, y: rect.maxY),
                    radius: headWidth/2,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false)
        
        return path
    }
}

struct ComponentAngleVisual: View {
    let angle: Int
    let pct: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(LogbookTheme.navyLight, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                // Runway line (vertical)
                Rectangle().fill(Color.gray).frame(width: 2, height: 30)
                
                // Wind line (angled)
                Rectangle().fill(LogbookTheme.accentOrange).frame(width: 2, height: 30)
                    .rotationEffect(.degrees(Double(angle)))
            }
            
            Text("\(angle)° Off")
                .font(.caption2)
                .foregroundColor(.gray)
            Text(pct)
                .font(.caption.bold())
                .foregroundColor(.white)
            Text("Crosswind")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(LogbookTheme.navyLight.opacity(0.3))
        .cornerRadius(8)
        .padding(4)
    }
}

// MARK: - Input & Display Components

struct ComponentCard: View {
    let title: String
    let value: Double
    let color: Color
    let icon: String
    let subtext: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack {
            // Value
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 0) {
                    Text("\(Int(round(value)))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text("kts")
                        .font(.caption2)
                        .foregroundColor(color.opacity(0.8))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Text(subtext)
                        .font(.subheadline)
                        .foregroundColor(isWarning ? .orange : .gray)
                }
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color.opacity(0.5))
        }
        .padding()
        .background(LogbookTheme.navyLight)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isWarning ? Color.orange : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Runway-Centric Wind Visualization
struct RunwayCentricWindView: View {
    let runwayHeading: Double
    let windDirection: Double
    let windSpeed: Double
    let crosswindComponent: Double
    let headwindComponent: Double
    
    // Calculate the relative wind angle (wind direction relative to runway)
    private var relativeWindAngle: Double {
        var angle = windDirection - runwayHeading
        // Normalize to -180 to 180
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        return angle
    }
    
    // Runway numbers
    private var runwayNum: String {
        let num = Int(round(runwayHeading / 10.0))
        return String(format: "%02d", num == 0 ? 36 : num)
    }
    
    private var reciprocalNum: String {
        var num = Int(round(runwayHeading / 10.0)) - 18
        if num <= 0 { num += 36 }
        return String(format: "%02d", num)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.05),
                                Color(white: 0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // MARK: The Vertical Runway
                VStack(spacing: 0) {
                    // Top Runway Number (Reciprocal)
                    Text(reciprocalNum)
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 8)
                    
                    // Runway surface
                    ZStack {
                        // Asphalt
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.2))
                            .frame(width: 80, height: geo.size.height * 0.6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        
                        // Centerline dashes
                        VStack(spacing: 16) {
                            ForEach(0..<8) { _ in
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 3, height: 30)
                            }
                        }
                        
                        // Threshold markings
                        VStack {
                            HStack(spacing: 4) {
                                ForEach(0..<4) { _ in
                                    Rectangle().fill(.white).frame(width: 3, height: 15)
                                }
                            }
                            .padding(.top, 20)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                ForEach(0..<4) { _ in
                                    Rectangle().fill(.white).frame(width: 3, height: 15)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(height: geo.size.height * 0.6)
                    }
                    
                    // Bottom Runway Number (Active)
                    Text(runwayNum)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                
                // MARK: Wind Flow Visualization
                if windSpeed > 0 {
                    // Multiple wind streams flowing across
                    ForEach(0..<5, id: \.self) { index in
                        WindStreamLine(
                            angle: relativeWindAngle,
                            speed: windSpeed,
                            yOffset: CGFloat(index) * (geo.size.height / 6) - geo.size.height / 3,
                            delay: Double(index) * 0.3
                        )
                    }
                    
                    // Large wind arrow showing direction
                    WindDirectionArrow(
                        angle: relativeWindAngle,
                        speed: windSpeed
                    )
                    .frame(width: 200, height: 200)
                    .position(x: geo.size.width * 0.75, y: geo.size.height * 0.2)
                }
                
                // MARK: Crosswind Component Display
                VStack {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // Crosswind badge
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: crosswindComponent > 0 ? "arrow.right" : "arrow.left")
                                    .font(.caption)
                                Text("\(Int(abs(crosswindComponent))) kt")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(crosswindColor)
                            
                            Text("CROSSWIND")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            Text(crosswindComponent > 0 ? "from RIGHT" : "from LEFT")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        .background(crosswindColor.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(crosswindColor, lineWidth: 2)
                        )
                        
                        // Headwind badge
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: headwindComponent >= 0 ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                Text("\(Int(abs(headwindComponent))) kt")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(headwindComponent >= 0 ? .green : .red)
                            
                            Text(headwindComponent >= 0 ? "HEADWIND" : "TAILWIND")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var crosswindColor: Color {
        let xw = abs(crosswindComponent)
        if xw <= 5 { return .green }
        else if xw <= 10 { return .yellow }
        else if xw <= 15 { return .orange }
        else { return .red }
    }
}

// MARK: - Wind Stream Line (Animated flow across runway)
struct WindStreamLine: View {
    let angle: Double
    let speed: Double
    let yOffset: CGFloat
    let delay: Double
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            // Calculate start and end points based on wind angle
            let radians = angle * .pi / 180.0
            let length = geo.size.width * 1.2
            
            // Wind flows from upwind side to downwind side
            let startX = geo.size.width / 2 - cos(radians) * length / 2
            let endX = geo.size.width / 2 + cos(radians) * length / 2
            let startY = geo.size.height / 2 + yOffset - sin(radians) * length / 2
            let endY = geo.size.height / 2 + yOffset + sin(radians) * length / 2
            
            // Animated particle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .cyan.opacity(0.3),
                            .blue.opacity(0.6),
                            .cyan.opacity(0.3)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 8)
                .blur(radius: 2)
                .position(
                    x: startX + (endX - startX) * progress,
                    y: startY + (endY - startY) * progress
                )
                .opacity(Double(1.0 - abs(progress - 0.5) * 2))
                .onAppear {
                    let duration = max(1.5, 4.0 - (speed / 30.0))
                    withAnimation(
                        Animation.linear(duration: duration)
                            .repeatForever(autoreverses: false)
                            .delay(delay)
                    ) {
                        progress = 1.0
                    }
                }
        }
    }
}

// MARK: - Wind Direction Arrow
struct WindDirectionArrow: View {
    let angle: Double
    let speed: Double
    
    var body: some View {
        ZStack {
            // Arrow shaft
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .cyan]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 100)
                .offset(y: 30)
            
            // Arrow head
            Image(systemName: "arrowtriangle.down.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.cyan)
                .offset(y: 80)
            
            // Speed label
            VStack(spacing: 2) {
                Text("\(Int(speed))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("kts")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(8)
            .background(
                Circle()
                    .fill(Color.blue)
                    .shadow(color: .cyan, radius: 10)
            )
            .offset(y: -20)
        }
        .rotationEffect(.degrees(angle))
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Legacy Views (Fuel, Temp, etc) are preserved below

struct FuelConversionCalculator: View {
    @State private var conversionType: FuelConversionType = .litersToGallons
    @State private var inputValue: String = ""
    @State private var temperature: String = "15" // Standard temp in Celsius
    @State private var useTempCorrection: Bool = false
    
    enum FuelConversionType: String, CaseIterable {
        case litersToGallons = "Liters → Gallons"
        case gallonsToLiters = "Gallons → Liters"
        case gallonsToPounds = "Gallons → Pounds"
        case poundsToGallons = "Pounds → Gallons"
        
        var inputLabel: String {
            switch self {
            case .litersToGallons: return "Liters"
            case .gallonsToLiters: return "US Gallons"
            case .gallonsToPounds: return "US Gallons"
            case .poundsToGallons: return "Pounds"
            }
        }
        
        var outputLabel: String {
            switch self {
            case .litersToGallons: return "US Gallons"
            case .gallonsToLiters: return "Liters"
            case .gallonsToPounds: return "Pounds (Jet A)"
            case .poundsToGallons: return "US Gallons"
            }
        }
    }
    
    private var convertedValue: Double? {
        guard let input = Double(inputValue), input > 0 else { return nil }
        
        switch conversionType {
        case .litersToGallons:
            return input * 0.264172 // 1 liter = 0.264172 US gallons
        case .gallonsToLiters:
            return input * 3.78541 // 1 US gallon = 3.78541 liters
        case .gallonsToPounds:
            return gallonsToPoundsWithTemp(input)
        case .poundsToGallons:
            return poundsToGallonsWithTemp(input)
        }
    }
    
    // Jet A density varies with temperature
    // Standard density: 6.75 lbs/gal at 15°C (59°F)
    // Temperature coefficient: approximately 0.0035 lbs/gal per °C
    private func gallonsToPoundsWithTemp(_ gallons: Double) -> Double {
        let standardDensity = 6.75 // lbs/gallon at 15°C
        
        guard useTempCorrection, let temp = Double(temperature) else {
            return gallons * standardDensity
        }
        
        // Adjust density based on temperature
        let tempDifference = temp - 15.0 // Difference from standard temp
        let densityAdjustment = -0.0035 * tempDifference // Density decreases with higher temp
        let adjustedDensity = standardDensity + densityAdjustment
        
        return gallons * adjustedDensity
    }
    
    private func poundsToGallonsWithTemp(_ pounds: Double) -> Double {
        let standardDensity = 6.75 // lbs/gallon at 15°C
        
        guard useTempCorrection, let temp = Double(temperature) else {
            return pounds / standardDensity
        }
        
        let tempDifference = temp - 15.0
        let densityAdjustment = -0.0035 * tempDifference
        let adjustedDensity = standardDensity + densityAdjustment
        
        return pounds / adjustedDensity
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Conversion type picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Conversion Type")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(FuelConversionType.allCases, id: \.self) { type in
                        Button(action: { conversionType = type }) {
                            HStack {
                                Image(systemName: conversionType == type ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(conversionType == type ? LogbookTheme.accentGreen : .gray)
                                Text(type.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(conversionType == type ? LogbookTheme.accentGreen.opacity(0.2) : LogbookTheme.fieldBackground)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text(conversionType.inputLabel)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter value", text: $inputValue)
                        .font(.title)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Temperature correction (for Jet A conversions only)
                if conversionType == .gallonsToPounds || conversionType == .poundsToGallons {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Use Temperature Correction", isOn: $useTempCorrection)
                            .foregroundColor(.white)
                        
                        if useTempCorrection {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fuel Temperature (°C)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                TextField("Temperature °C", text: $temperature)
                                    .keyboardType(.numbersAndPunctuation)
                                    .padding()
                                    .background(LogbookTheme.fieldBackground)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                
                                Text("Standard: 15°C (59°F)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(LogbookTheme.navyLight)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Result display
                if let result = convertedValue {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down")
                            .font(.title)
                            .foregroundColor(LogbookTheme.accentGreen)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conversionType.outputLabel)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(String(format: "%.2f", result))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(LogbookTheme.accentGreen)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LogbookTheme.fieldBackground)
                                .cornerRadius(10)
                        }
                        
                        // Density info for Jet A conversions
                        if (conversionType == .gallonsToPounds || conversionType == .poundsToGallons) && useTempCorrection {
                            if let temp = Double(temperature) {
                                let tempDiff = temp - 15.0
                                let densityAdj = -0.0035 * tempDiff
                                let density = 6.75 + densityAdj
                                
                                VStack(spacing: 4) {
                                    Text("Density: \(String(format: "%.3f", density)) lbs/gal")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("at \(temperature)°C (\(String(format: "%.0f", celsiusToFahrenheit(temp)))°F)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Reference info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reference")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        FuelInfoRow(label: "Jet A Density (std):", value: "6.75 lbs/gal @ 15°C")
                        FuelInfoRow(label: "Temp Coefficient:", value: "-0.0035 lbs/gal per °C")
                        FuelInfoRow(label: "1 US Gallon:", value: "3.78541 Liters")
                        FuelInfoRow(label: "1 Liter:", value: "0.264172 US Gallons")
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }
    
    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9/5 + 32
    }
}

// MARK: - Fuel Uplift Calculator (GOM 70.05 COMPLIANT)
struct FuelUpliftCalculator: View {
    // Input fields
    @State private var arrivalFuel: String = ""
    @State private var fuelUplift: String = ""
    @State private var displayedFOB: String = ""
    
    // Unit selection
    @State private var arrivalUnit: FuelUnit = .pounds
    @State private var upliftUnit: FuelUnit = .gallons
    @State private var fobUnit: FuelUnit = .pounds
    
    // Results
    @State private var calculatedTotal: Double = 0
    @State private var discrepancy: Double = 0
    @State private var discrepancyPercent: Double = 0
    @State private var checkResult: CheckResult = .notChecked
    
    enum FuelUnit: String, CaseIterable {
        case pounds = "lbs"
        case gallons = "gal"
    }
    
    enum CheckResult {
        case notChecked
        case pass
        case fail
        
        var color: Color {
            switch self {
            case .notChecked: return .gray
            case .pass: return .green
            case .fail: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .notChecked: return "questionmark.circle"
            case .pass: return "checkmark.circle.fill"
            case .fail: return "exclamationmark.triangle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .notChecked: return "Enter values to check"
            case .pass: return "✅ PASS - Within 5% tolerance"
            case .fail: return "⚠️ FAIL - Exceeds 5% tolerance"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - GOM 70.05 Instructions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(LogbookTheme.accentBlue)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GOM 70.05 - Fuel Reasonableness Check")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Verify fuel uplift matches displayed FOB within 5%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Formula:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text("Arrival Fuel + Uplift = Expected Total")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Compare:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text("Expected Total vs Displayed FOB")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Tolerance:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text("Discrepancy must be ≤ 5%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Density:")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text("6.7 lbs/gal (Standard Jet A)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: - Input Fields
                VStack(spacing: 20) {
                    // Arrival Fuel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "airplane.arrival")
                                .foregroundColor(LogbookTheme.accentGreen)
                            Text("Arrival Fuel (Previous Leg)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 12) {
                            TextField("0", text: $arrivalFuel)
                                .keyboardType(.decimalPad)
                                .font(.title2)
                                .padding()
                                .background(LogbookTheme.fieldBackground)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            
                            Picker("Unit", selection: $arrivalUnit) {
                                ForEach(FuelUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 100)
                        }
                    }
                    
                    // Fuel Uplift
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "fuelpump.fill")
                                .foregroundColor(LogbookTheme.accentOrange)
                            Text("Fuel Uplift Added")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 12) {
                            TextField("0", text: $fuelUplift)
                                .keyboardType(.decimalPad)
                                .font(.title2)
                                .padding()
                                .background(LogbookTheme.fieldBackground)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            
                            Picker("Unit", selection: $upliftUnit) {
                                ForEach(FuelUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 100)
                        }
                    }
                    
                    // Displayed FOB
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "gauge.high")
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text("Displayed FOB (Fuel Totalizer)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 12) {
                            TextField("0", text: $displayedFOB)
                                .keyboardType(.decimalPad)
                                .font(.title2)
                                .padding()
                                .background(LogbookTheme.fieldBackground)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            
                            Picker("Unit", selection: $fobUnit) {
                                ForEach(FuelUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 100)
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Check Button
                Button(action: {
                    performCheck()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Perform Reasonableness Check")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canPerformCheck ? LogbookTheme.accentBlue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canPerformCheck)
                .padding(.horizontal)
                
                // MARK: - Results Display
                if checkResult != .notChecked {
                    VStack(spacing: 16) {
                        // Status Badge
                        HStack {
                            Image(systemName: checkResult.icon)
                                .font(.title)
                                .foregroundColor(checkResult.color)
                            
                            Text(checkResult.message)
                                .font(.headline)
                                .foregroundColor(checkResult.color)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(checkResult.color.opacity(0.2))
                        .cornerRadius(12)
                        
                        // Calculation Details
                        VStack(spacing: 12) {
                            ResultRow(
                                label: "Expected Total",
                                value: String(format: "%.0f lbs", calculatedTotal),
                                icon: "equal.circle",
                                color: .white
                            )
                            
                            ResultRow(
                                label: "Displayed FOB",
                                value: String(format: "%.0f lbs", convertToLbs(Double(displayedFOB) ?? 0, unit: fobUnit)),
                                icon: "gauge.high",
                                color: .white
                            )
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            ResultRow(
                                label: "Discrepancy",
                                value: String(format: "%.0f lbs (%.1f%%)", discrepancy, discrepancyPercent),
                                icon: checkResult == .pass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                color: checkResult.color
                            )
                        }
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .cornerRadius(12)
                        
                        // GOM Guidance
                        if checkResult == .fail {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Required Actions (GOM 70.05)")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ActionItem(text: "Investigate cause of discrepancy")
                                    ActionItem(text: "Check for APU use during fueling")
                                    ActionItem(text: "Verify no maintenance engine run-ups")
                                    ActionItem(text: "Contact Maintenance Control if cause cannot be determined")
                                    ActionItem(text: "Consider drip stick verification of fuel tanks")
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Clear Button
                if checkResult != .notChecked {
                    Button(action: {
                        clearAll()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Clear & Start New Check")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LogbookTheme.navyLight)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Reference Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reference")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        FuelInfoRow(label: "Standard Jet A Density:", value: "6.7 lbs/gal")
                        FuelInfoRow(label: "Tolerance:", value: "±5% maximum")
                        FuelInfoRow(label: "GOM Reference:", value: "Section 70.05")
                        FuelInfoRow(label: "Check Timing:", value: "After fueling, before takeoff")
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helper Properties & Functions
    
    private var canPerformCheck: Bool {
        guard let arrival = Double(arrivalFuel),
              let uplift = Double(fuelUplift),
              let fob = Double(displayedFOB) else {
            return false
        }
        return arrival > 0 && uplift > 0 && fob > 0
    }
    
    private func performCheck() {
        guard let arrival = Double(arrivalFuel),
              let uplift = Double(fuelUplift),
              let fob = Double(displayedFOB) else {
            return
        }
        
        // Convert all values to pounds for calculation
        let arrivalLbs = convertToLbs(arrival, unit: arrivalUnit)
        let upliftLbs = convertToLbs(uplift, unit: upliftUnit)
        let fobLbs = convertToLbs(fob, unit: fobUnit)
        
        // Calculate expected total (Arrival + Uplift)
        calculatedTotal = arrivalLbs + upliftLbs
        
        // Calculate discrepancy (FOB - Expected)
        discrepancy = fobLbs - calculatedTotal
        
        // Calculate percentage discrepancy
        discrepancyPercent = (abs(discrepancy) / calculatedTotal) * 100
        
        // Determine pass/fail (5% tolerance per GOM 70.05)
        checkResult = discrepancyPercent <= 5.0 ? .pass : .fail
        
        // Provide haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: checkResult == .pass ? .light : .heavy)
        generator.impactOccurred()
        #endif
    }
    
    private func convertToLbs(_ value: Double, unit: FuelUnit) -> Double {
        switch unit {
        case .pounds:
            return value
        case .gallons:
            return value * 6.7  // Standard Jet A density per GOM
        }
    }
    
    private func clearAll() {
        arrivalFuel = ""
        fuelUplift = ""
        displayedFOB = ""
        calculatedTotal = 0
        discrepancy = 0
        discrepancyPercent = 0
        checkResult = .notChecked
    }
}

// MARK: - Supporting Views

struct ResultRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ActionItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

// MARK: - Temperature Calculator
struct TemperatureCalculator: View {
    @State private var celsiusInput: String = ""
    @State private var fahrenheitInput: String = ""
    @State private var lastEdited: TemperatureUnit = .celsius
    
    enum TemperatureUnit {
        case celsius, fahrenheit
    }
    
    private var celsius: Double? {
        if lastEdited == .celsius {
            return Double(celsiusInput)
        } else if let f = Double(fahrenheitInput) {
            return (f - 32) * 5/9
        }
        return nil
    }
    
    private var fahrenheit: Double? {
        if lastEdited == .fahrenheit {
            return Double(fahrenheitInput)
        } else if let c = Double(celsiusInput) {
            return c * 9/5 + 32
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temperature Conversion")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Enter temperature in either Celsius or Fahrenheit for instant conversion")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Celsius input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(LogbookTheme.accentBlue)
                        Text("Celsius (°C)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    TextField("Enter °C", text: $celsiusInput)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .keyboardType(.numbersAndPunctuation)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .onChange(of: celsiusInput) { oldValue, newValue in
                            lastEdited = .celsius
                            if let c = celsius {
                                fahrenheitInput = String(format: "%.1f", c * 9/5 + 32)
                            } else {
                                fahrenheitInput = ""
                            }
                        }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Conversion indicator
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title)
                    .foregroundColor(LogbookTheme.accentOrange)
                
                // Fahrenheit input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(LogbookTheme.accentOrange)
                        Text("Fahrenheit (°F)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    TextField("Enter °F", text: $fahrenheitInput)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .keyboardType(.numbersAndPunctuation)
                        .padding()
                        .background(LogbookTheme.fieldBackground)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .onChange(of: fahrenheitInput) { oldValue, newValue in
                            lastEdited = .fahrenheit
                            if let f = fahrenheit {
                                celsiusInput = String(format: "%.1f", (f - 32) * 5/9)
                            } else {
                                celsiusInput = ""
                            }
                        }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Quick reference
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Reference")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 8) {
                        TempReferenceRow(celsius: 0, fahrenheit: 32, label: "Freezing Point")
                        TempReferenceRow(celsius: 15, fahrenheit: 59, label: "Standard Day")
                        TempReferenceRow(celsius: 25, fahrenheit: 77, label: "Room Temperature")
                        TempReferenceRow(celsius: 37, fahrenheit: 98.6, label: "Body Temperature")
                        TempReferenceRow(celsius: 100, fahrenheit: 212, label: "Boiling Point")
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Conversion formulas
                VStack(alignment: .leading, spacing: 8) {
                    Text("Formulas")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("°F = (°C × 9/5) + 32")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .monospaced()
                        Text("°C = (°F - 32) × 5/9")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .monospaced()
                    }
                }
                .padding()
                .background(LogbookTheme.navyLight)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Helper Views for Temperature
private struct FuelInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct TempReferenceRow: View {
    let celsius: Int
    let fahrenheit: Double
    let label: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            HStack(spacing: 12) {
                Text("\(celsius)°C")
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("=")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(String(format: "%.1f°F", fahrenheit))
                    .font(.caption)
                    .foregroundColor(LogbookTheme.accentOrange)
            }
        }
        .padding(.vertical, 4)
    }
}

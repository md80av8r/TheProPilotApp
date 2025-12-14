//
//  GradientGlowButton.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/18/25.
//


// JazzyButtonStyles.swift
// Multiple enhanced button designs for your New Trip button

import SwiftUI

// MARK: - Option 1: Gradient Glow Effect
struct GradientGlowButton: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.cyan.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("New Trip")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.cyan.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 8)
                
                // Main button background
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.25),
                                Color.cyan.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Glass overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.6),
                                Color.blue.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color.cyan.opacity(0.3), radius: 12, x: 0, y: 6)
        .shadow(color: Color.blue.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Option 2: Animated Shimmer Effect
struct ShimmerButton: View {
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white)
            
            Text("New Trip")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Base gradient
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1E3A8A"), // Deep blue
                                Color(hex: "2563EB")  // Bright blue
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Shimmer effect
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .mask(RoundedRectangle(cornerRadius: 15))
                
                // Top highlight
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 30)
                    .offset(y: -15)
                
                // Border
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .shadow(color: Color.blue.opacity(0.4), radius: 20, x: 0, y: 10)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
}

// MARK: - Option 3: Neon Glow Style
struct NeonGlowButton: View {
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .symbolEffect(.pulse.byLayer, options: .repeating)
            
            Text("New Trip")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(
            LinearGradient(
                colors: [Color.white, Color.cyan],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.horizontal, 28)
        .padding(.vertical, 15)
        .background(
            ZStack {
                // Outer neon glow
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.cyan, lineWidth: 2)
                    .blur(radius: 10)
                    .opacity(0.8)
                
                // Middle glow
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .blur(radius: 5)
                    .opacity(0.6)
                
                // Main background
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.blue.opacity(0.3),
                                Color.black.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Inner border
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// MARK: - Option 4: Aviation-Themed Premium Button
struct AviationPremiumButton: View {
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated plane icon
            ZStack {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .symbolEffect(.bounce.up, options: .speed(0.5).repeat(1), value: isHovering)
                
                // Rotating ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .cyan, .clear],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(isHovering ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isHovering)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("NEW TRIP")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                Text("Start Flying")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "0F172A"), location: 0),
                                .init(color: Color(hex: "1E293B"), location: 0.5),
                                .init(color: Color(hex: "0F172A"), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Animated gradient overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.4),
                                Color.cyan.opacity(0.3),
                                Color.blue.opacity(0.4)
                            ],
                            startPoint: isHovering ? .topLeading : .bottomTrailing,
                            endPoint: isHovering ? .bottomTrailing : .topLeading
                        )
                    )
                    .animation(.easeInOut(duration: 1), value: isHovering)
                
                // Glass effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .offset(y: -12)
                
                // Premium border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.8),
                                Color.blue.opacity(0.6),
                                Color.cyan.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .shadow(color: Color.cyan.opacity(isHovering ? 0.6 : 0.3), radius: 15, x: 0, y: 5)
        .onAppear {
            isHovering = true
        }
    }
}

// MARK: - Option 5: Minimal Elegant Style
struct MinimalElegantButton: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
            
            Text("NEW TRIP")
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .tracking(2)
            
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 0)
    }
}

// MARK: - Helper Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Usage Examples
struct ButtonShowcase: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose Your Style")
                .font(.title2)
                .foregroundColor(.white)
            
            // Option 1
            GradientGlowButton()
            
            // Option 2
            ShimmerButton()
            
            // Option 3
            NeonGlowButton()
            
            // Option 4
            AviationPremiumButton()
            
            // Option 5
            MinimalElegantButton()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

//
//  NewTripButton.swift
//  TheProPilotApp
//
//  Clean, professional New Trip button
//

import SwiftUI

struct NewTripButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("New Trip")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alternative: Outline Style
struct NewTripButtonOutline: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                
                Text("New Trip")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alternative: Subtle Dark Style
struct NewTripButtonDark: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                
                Text("New Trip")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        Text("Simple Options")
            .font(.headline)
            .foregroundColor(.gray)
        
        NewTripButton { }
        
        NewTripButtonOutline { }
        
        NewTripButtonDark { }
    }
    .padding(40)
    .background(Color.black)
}

struct NewTripButton1: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
            
            Text("New Trip")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(10)
    }
}

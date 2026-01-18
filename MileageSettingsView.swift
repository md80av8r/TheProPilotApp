import SwiftUI

// MARK: - Mileage Settings View
/// Configuration view for mileage tracking and payment settings
struct MileageSettingsView: View {
    @ObservedObject var settings = MileageSettings.shared
    @Environment(\.dismiss) private var dismiss

    // Local state for dollar input
    @State private var dollarInputText: String = ""
    @FocusState private var isDollarInputFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.05)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: - Header
                        VStack(spacing: 8) {
                            Image(systemName: "road.lanes")
                                .font(.system(size: 50))
                                .foregroundColor(LogbookTheme.accentOrange)

                            Text("Mileage Tracking")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Track distance and calculate mileage pay")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // MARK: - Enable Mileage Toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $settings.showMileage) {
                                HStack {
                                    Image(systemName: "gauge.medium")
                                        .foregroundColor(LogbookTheme.accentOrange)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Show Mileage")
                                            .font(.headline)
                                            .foregroundColor(.white)

                                        Text("Display distance in nautical miles for trips and legs")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: LogbookTheme.accentOrange))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.15))
                        )

                        // MARK: - Mileage Pay Rate
                        if settings.showMileage {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundColor(LogbookTheme.accentOrange)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Mileage Pay Rate")
                                            .font(.headline)
                                            .foregroundColor(.white)

                                        Text("Optional: Enter dollar amount per nautical mile")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()
                                }

                                // Dollar per mile input
                                HStack {
                                    Text("$")
                                        .font(.title2)
                                        .foregroundColor(.white)

                                    TextField("0.00", text: $dollarInputText)
                                        .keyboardType(.decimalPad)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .focused($isDollarInputFocused)
                                        .onChange(of: dollarInputText) { newValue in
                                            // Update settings when valid number entered
                                            if let value = Double(newValue) {
                                                settings.dollarsPerMile = value
                                            }
                                        }

                                    Text("per NM")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(white: 0.1))
                                )

                                // Info text
                                if settings.dollarsPerMile > 0 {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Mileage pay will be calculated and displayed in trip statistics")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Leave at $0.00 to only track distance without pay calculations")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.15))
                            )
                            .transition(.opacity)
                        }

                        // MARK: - Example Calculation
                        if settings.showMileage && settings.dollarsPerMile > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "function")
                                        .foregroundColor(LogbookTheme.accentOrange)
                                    Text("Example Calculation")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }

                                Divider()
                                    .background(Color.gray.opacity(0.3))

                                // Example: KVNY to KORD
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("KVNY → KORD")
                                        .font(.subheadline)
                                        .foregroundColor(.white)

                                    if let distance = MileageSettings.shared.calculateDistance(from: "KVNY", to: "KORD") {
                                        HStack {
                                            Text("Distance:")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(MileageSettings.shared.formatMileage(distance))
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)
                                        }

                                        let pay = MileageSettings.shared.calculateMileagePay(nauticalMiles: distance)
                                        HStack {
                                            Text("Mileage Pay:")
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(MileageSettings.shared.formatMileagePay(pay))
                                                .foregroundColor(LogbookTheme.accentOrange)
                                                .fontWeight(.bold)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(white: 0.1))
                                )
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.15))
                            )
                            .transition(.opacity)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Mileage Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Initialize text field with current value
            if settings.dollarsPerMile > 0 {
                dollarInputText = String(format: "%.2f", settings.dollarsPerMile)
            }
        }
    }
}

#Preview {
    MileageSettingsView()
}

//
//  TripCountingSettingsView.swift
//  ProPilot App
//
//  Settings UI for trip counting configuration
//

import SwiftUI

struct TripCountingSettingsView: View {
    @ObservedObject var settings = TripCountingSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Counting Method Section
                Section {
                    ForEach(TripCountingSettings.CountingMethod.allCases, id: \.self) { method in
                        Button(action: {
                            withAnimation {
                                settings.countingMethod = method
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(method.displayName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(method.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if settings.countingMethod == method {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                } header: {
                    Text("Counting Method")
                        .foregroundColor(.white)
                } footer: {
                    Text("Choose how trips are counted in your statistics. This affects the trip count displayed throughout the app.")
                        .foregroundColor(.gray)
                }
                .listRowBackground(LogbookTheme.navyLight)
                .textCase(nil)

                // MARK: - Deadhead Handling Section
                Section {
                    Toggle(isOn: $settings.includeDeadheadsInCount) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include Deadheads in Trip Count")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("When enabled, deadhead trips will be included in your total trip count")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(LogbookTheme.accentGreen)
                    .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Deadhead Trips")
                        .foregroundColor(.white)
                } footer: {
                    Text("Deadhead trips are non-revenue positioning flights. Most airlines don't count these as paid trips.")
                        .foregroundColor(.gray)
                }
                .textCase(nil)

                // MARK: - Example Section
                Section {
                    exampleView
                        .listRowBackground(LogbookTheme.navyLight)
                } header: {
                    Text("Example")
                        .foregroundColor(.white)
                }
                .textCase(nil)
            }
            .scrollContentBackground(.hidden)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .navigationTitle("Trip Counting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }

    // MARK: - Example View
    private var exampleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Settings")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            HStack {
                Image(systemName: "airplane.departure")
                    .foregroundColor(LogbookTheme.accentBlue)
                Text("Method:")
                    .foregroundColor(.gray)
                Spacer()
                Text(settings.countingMethod.displayName)
                    .foregroundColor(.white)
                    .font(.subheadline.bold())
            }

            HStack {
                Image(systemName: "person.fill.turn.right")
                    .foregroundColor(LogbookTheme.accentOrange)
                Text("Deadheads:")
                    .foregroundColor(.gray)
                Spacer()
                Text(settings.includeDeadheadsInCount ? "Included" : "Excluded")
                    .foregroundColor(settings.includeDeadheadsInCount ? LogbookTheme.accentGreen : .gray)
                    .font(.subheadline.bold())
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Example scenario
            VStack(alignment: .leading, spacing: 8) {
                Text("Example Scenario")
                    .font(.caption.bold())
                    .foregroundColor(.gray)

                Group {
                    Text("• Trip 123: KVNY → KORD")
                    Text("• Trip 123: KORD → KCLE")
                    Text("• Trip 456: KCLE → KVNY")
                    Text("• Deadhead: KVNY → KORD")
                }
                .font(.caption)
                .foregroundColor(.white)

                HStack {
                    Text("Your count:")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Text(exampleCount)
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentGreen)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var exampleCount: String {
        switch settings.countingMethod {
        case .byTripNumber:
            // 2 unique trip numbers (123, 456) + maybe 1 deadhead
            let baseCount = 2
            let total = settings.includeDeadheadsInCount ? baseCount + 1 : baseCount
            return "\(total) trip\(total == 1 ? "" : "s")"
        case .byDutyPeriod:
            // All in one duty period
            return "1 duty period"
        case .byCalendarDay:
            // Assume all on same day
            return "1 trip (1 day)"
        }
    }
}

#if DEBUG
struct TripCountingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TripCountingSettingsView()
            .preferredColorScheme(.dark)
    }
}
#endif

import SwiftUI

struct HorizontalLogView: View {
    var date: Date
    var tripNumber: String
    var legs: [FlightLeg]
    var totalFlight: Int
    var totalBlock: Int
    var tatFinal: String
    var tatStart: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Date: \(formattedDate(date))")
                Spacer()
                Text("Starting TAT: \(formatTATStart(tatStart))")
            }
            .font(.headline)

            HStack {
                Spacer()
                Text(tripNumber)
                    .font(.title3)
                    .bold()
                Spacer()
            }

            Divider()

            VStack(spacing: 0) {
                HStack {
                    Text("FROM").bold().frame(minWidth: 80)
                    Text("TO").bold().frame(minWidth: 80)
                    Text("OUT").bold().frame(minWidth: 80)
                    Text("OFF").bold().frame(minWidth: 80)
                    Text("ON").bold().frame(minWidth: 80)
                    Text("IN").bold().frame(minWidth: 80)
                    Spacer()
                    Text("Flight").bold().frame(minWidth: 80)
                    Text("Block").bold().frame(minWidth: 80)
                }
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))

                ForEach(legs.indices, id: \.self) { index in
                    let leg = legs[index]
                    VStack(spacing: 4) {
                        HStack {
                            Text(leg.departure).frame(minWidth: 80)
                            Text(leg.arrival).frame(minWidth: 80)
                            Text(leg.outTime).frame(minWidth: 80)
                            Text(leg.offTime).frame(minWidth: 80)
                            Text(leg.onTime).frame(minWidth: 80)
                            Text(leg.inTime).frame(minWidth: 80)
                            Spacer()
                            Text(leg.formattedFlightTime.replacingOccurrences(of: "+", with: "+"))
                                .frame(minWidth: 80)
                                .foregroundColor(LogbookTheme.accentBlue)
                            Text(leg.formattedBlockTime.replacingOccurrences(of: "+", with: "+"))
                                .frame(minWidth: 80)
                                .foregroundColor(LogbookTheme.accentGreen)
                        }
                        Divider()
                    }
                    .font(.caption)
                }

                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                    .padding(.top, 4)

                HStack {
                    Spacer().frame(minWidth: 80 * 6)
                    Text(TimeUtils.formatCompactMinutes(totalFlight))
                        .frame(minWidth: 80)
                        .foregroundColor(LogbookTheme.accentBlue)
                    Text(TimeUtils.formatCompactMinutes(totalBlock))
                        .frame(minWidth: 80)
                        .foregroundColor(LogbookTheme.accentGreen)
                }
                .font(.subheadline)
            }

            HStack {
                Spacer()
                Text("Ending TAT: ")
                    .foregroundColor(.orange)
                Text(formatFullTAT(tatFinal))
                    .foregroundColor(.orange)
                    .frame(minWidth: 80, alignment: .leading)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTATStart(_ input: String) -> String {
        // Extract only digits
        let digits = input.filter(\.isWholeNumber)
        
        // Need at least 3 digits to format with + separator
        guard digits.count >= 3 else {
            return digits
        }
        
        // Last 2 digits are minutes, everything before is hours
        let hours = String(digits.dropLast(2))
        let minutes = String(digits.suffix(2))
        
        return "\(hours)+\(minutes)"
    }

    private func formatFullTAT(_ raw: String) -> String {
        let parts = raw.split(separator: "+")
        guard let hourPart = parts.first else { return raw }
        let hourString = String(hourPart).padding(toLength: 5, withPad: "0", startingAt: 0)
        let minuteString = parts.count > 1 ? String(format: "%02d", Int(parts[1]) ?? 0) : "00"
        return "\(hourString)+\(minuteString)"
    }
}

extension TimeUtils {
    static func formatCompactMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d+%02d", h, m)
    }
}

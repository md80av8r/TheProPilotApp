import SwiftUI

struct LogPageTableView: View {
    var trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trip #\(trip.tripNumber)  \(trip.date, formatter: dateFormatter)")
                .font(.headline)
            Text("Aircraft: \(trip.aircraft)")

            ForEach(trip.crew) { member in
                if !member.name.isEmpty {
                    Text("\(member.role): \(member.name)")
                }
            }

            if !trip.notes.isEmpty {
                Text("Notes: \(trip.notes)").font(.caption).foregroundColor(.gray)
            }

            Text("Legs: \(trip.legs.count)").font(.caption)

            // You can add more details here for each leg as desired
        }
        .padding()
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .short
    return df
}()

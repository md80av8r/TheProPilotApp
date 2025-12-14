import SwiftUI

struct LandscapeDataEntryView: View {
    @Binding var tripNumber: String
    @Binding var aircraft: String
    @Binding var legs: [FlightLeg]
    @Binding var crew: [CrewMember]
    @Binding var notes: String
    @Binding var tatStart: String

    var totalFlightMinutes: Int {
        legs.map { $0.calculateFlightMinutes() }.reduce(0, +)
    }

    var totalBlockMinutes: Int {
        legs.map { $0.blockMinutes() }.reduce(0, +)
    }

    var tatFinal: String {
        guard let start = TimeUtils.parseTAT(tatStart) else { return "" }
        let final = start + totalFlightMinutes
        return TimeUtils.formatTAT(final)
    }

    var firstOutTime: String {
        legs.first(where: { !$0.outTime.isEmpty })?.outTime ?? ""
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 8) {
                // Header Row 1
                HStack {
                    Text("Date: \(firstOutTime)")
                    Spacer()
                    Text("Trip #: \(tripNumber)")
                }
                .font(.headline)

                // Header Row 2
                HStack {
                    Text("DEP").bold().frame(width: 60)
                    Text("ARR").bold().frame(width: 60)
                    Text("OUT").bold().frame(width: 60)
                    Text("OFF").bold().frame(width: 60)
                    Text("ON").bold().frame(width: 60)
                    Text("IN").bold().frame(width: 60)
                    Text("FLIGHT").bold().frame(width: 80)
                    Text("BLOCK").bold().frame(width: 80)
                }

                // Legs Rows
                ForEach(legs.indices, id: \.self) { index in
                    HStack {
                        TextField("DEP", text: $legs[index].departure).frame(width: 60)
                        TextField("ARR", text: $legs[index].arrival).frame(width: 60)
                        TextField("OUT", text: $legs[index].outTime).frame(width: 60)
                        TextField("OFF", text: $legs[index].offTime).frame(width: 60)
                        TextField("ON", text: $legs[index].onTime).frame(width: 60)
                        TextField("IN", text: $legs[index].inTime).frame(width: 60)
                        Text(legs[index].formattedFlightTime).frame(width: 80)
                        Text(legs[index].formattedBlockTime).frame(width: 80)
                    }
                    .font(.caption)
                }

                Divider()

                // Totals Row
                HStack {
                    Spacer().frame(width: 360)
                    Text("Total:").bold()
                    Text(TimeUtils.formatMinutes(totalFlightMinutes)).frame(width: 80)
                    Text(TimeUtils.formatMinutes(totalBlockMinutes)).frame(width: 80)
                }

                // TAT Final
                HStack {
                    Text("NEW TAT:").bold()
                    Text(tatFinal)
                    Spacer()
                }

                // Crew
                ForEach(crew.indices, id: \.self) { i in
                    TextField("Captain/FO/LM", text: $crew[i].name)
                }
            }
            .padding()
        }
    }
}

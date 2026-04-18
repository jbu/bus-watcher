import SwiftUI

struct StopCardView: View {
    let stop: StopConfig
    let arrivals: [Arrival]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(stop.routeLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(routeColor, in: RoundedRectangle(cornerRadius: 8))
                Text(stop.stopName)
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if arrivals.isEmpty {
                Text("No upcoming buses")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(Array(arrivals.enumerated()), id: \.element.id) { index, arrival in
                    ArrivalRowView(arrival: arrival)
                    if index < arrivals.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var routeColor: Color {
        switch stop.routeLabel {
        case "11A": return .blue
        case "35":  return .green
        case "11C": return .orange
        default:    return .gray
        }
    }
}

struct ArrivalRowView: View {
    let arrival: Arrival

    private var countdownColor: Color {
        let mins = arrival.minutesAway
        if mins <= 1 { return .red }
        if mins <= 4 { return .orange }
        return .green
    }

    private var timeLabel: String {
        if arrival.timeToStation <= 30 { return "Due" }
        let mins = arrival.minutesAway
        return mins == 1 ? "1 min" : "\(mins) mins"
    }

    private var arrivalTimeString: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: arrival.expectedArrival) else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    var body: some View {
        HStack {
            Text(arrivalTimeString)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            if let dest = arrival.destinationName, !dest.isEmpty {
                Text(dest)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()

            Text(timeLabel)
                .font(.body.bold())
                .foregroundStyle(countdownColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

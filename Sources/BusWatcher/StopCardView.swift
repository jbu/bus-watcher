import SwiftUI

struct StopCardView: View {
    let stop: StopConfig
    let arrivals: [Arrival]
    let isStarred: Bool
    let onToggleStar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(stop.routeLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(stop.colorToken.color, in: RoundedRectangle(cornerRadius: 8))
                Text(stop.stopName)
                    .font(.headline)
                Spacer()
                Button(action: onToggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .foregroundStyle(isStarred ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if arrivals.isEmpty {
                Text("No upcoming buses")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(arrivals.indices, id: \.self) { i in
                    ArrivalRowView(arrival: arrivals[i])
                    if i < arrivals.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

struct ArrivalRowView: View {
    let arrival: Arrival

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var arrivalTimeString: String {
        guard let date = isoFormatter.date(from: arrival.displayArrival) else { return "—" }
        return ArrivalRowView.timeFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            Text(arrivalTimeString)
                .font(.body.monospacedDigit())
                .foregroundStyle(arrival.isLive ? .secondary : .tertiary)
                .frame(width: 48, alignment: .leading)

            if let dest = arrival.destinationName, !dest.isEmpty {
                Text(dest)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()

            Text(countdownText(arrival.minutesAway))
                .font(.body.bold())
                .foregroundStyle(arrival.isLive ? countdownColor(arrival.minutesAway) : .secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

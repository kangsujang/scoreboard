import SwiftUI

struct EventListView: View {
    let events: [ScoreEvent]
    let homeTeamName: String
    let awayTeamName: String

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                "まだ得点がありません",
                systemImage: "soccerball",
                description: Text("ゴールボタンで得点を記録しましょう")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(sortedEventsWithScore, id: \.event.id) { item in
                    HStack {
                        Text(TimeFormatting.format(seconds: item.event.timestamp))
                            .monospacedDigit()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        Image(systemName: "soccerball")
                            .foregroundStyle(item.event.team == .home ? .blue : .red)

                        Text(item.event.team == .home ? homeTeamName : awayTeamName)
                            .font(.subheadline)

                        Spacer()

                        Text("\(item.homeScore) - \(item.awayScore)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var sortedEventsWithScore: [EventWithScore] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        var home = 0
        var away = 0
        return sorted.map { event in
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
            return EventWithScore(event: event, homeScore: home, awayScore: away)
        }
    }
}

private struct EventWithScore {
    let event: ScoreEvent
    let homeScore: Int
    let awayScore: Int
}

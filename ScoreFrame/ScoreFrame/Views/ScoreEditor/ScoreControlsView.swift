import SwiftUI

struct ScoreControlsView: View {
    let match: Match
    let currentTime: TimeInterval
    let onGoal: (Team) -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(match.homeTeamName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Spacer()
                Text(match.awayTeamName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal)

            Text(TimeFormatting.format(seconds: currentTime))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                GoalButton(teamName: match.homeTeamName, color: .blue) {
                    onGoal(.home)
                }

                Button {
                    onUndo()
                } label: {
                    Label("取消", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(match.scoreEvents.isEmpty)

                GoalButton(teamName: match.awayTeamName, color: .red) {
                    onGoal(.away)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct GoalButton: View {
    let teamName: String
    let color: Color
    let action: () -> Void
    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "soccerball")
                    .font(.title3)
                Text("ゴール+")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }
}
